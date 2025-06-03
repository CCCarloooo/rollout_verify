#!/bin/bash
set -e

# ---------- 读取 YAML 配置 ----------
CONFIG_FILE="$1"
if [ -z "$CONFIG_FILE" ] || [ ! -f "$CONFIG_FILE" ]; then
    echo "用法: $0 <config.yaml>"
    echo "示例: $0 run.yaml"
    exit 1
fi

echo "=== 读取配置文件: $CONFIG_FILE ==="

# 使用 Python 将 YAML 扁平化为环境变量
eval "$(python3 - "$CONFIG_FILE" <<'PY'
import sys, yaml, re
try:
    cfg = yaml.safe_load(open(sys.argv[1]))
except Exception as e:
    print(f"错误: 无法解析YAML文件: {e}", file=sys.stderr)
    sys.exit(1)

def flatten(prefix, node):
    if isinstance(node, dict):
        for k, v in node.items():
            name = f"{prefix}_{k}" if prefix else k
            flatten(name, v)
    else:
        key = re.sub(r'\W', '_', prefix).upper()
        print(f'{key}="{node}"')

flatten("", cfg)
PY
)"

# 检查必要的配置是否存在
required_vars=("TASK_NAME_PREFIX" "TASK_OUTPUT_ROOT" "MODELS_MARCO" "MODELS_ROLLOUT" "MODELS_EVAL" "DATA_INPUT_JSONL")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "错误: 配置文件中缺少必要参数: $var"
        exit 1
    fi
done

# ---------- 将 YAML 变量映射到脚本变量 ----------
TASK_NAME="${TASK_NAME_PREFIX}_$(date +%m%d_%H%M)"
BASE_OUTPUT_DIR="$TASK_OUTPUT_ROOT/$TASK_NAME"

# 模型路径
MarcoModelPath="$MODELS_MARCO"
RolloutModelPath="$MODELS_ROLLOUT"
EVAL_MODEL_PATH="$MODELS_EVAL"

# 输入输出路径
GenMarcoInput="$DATA_INPUT_JSONL"
GenMarcoOutput="$BASE_OUTPUT_DIR/Gen/GenMarco.jsonl"
RolloutOutput="$BASE_OUTPUT_DIR/Rollout"
EVAL_OUTPUT_DIR="$BASE_OUTPUT_DIR/Eval"

# 运行时参数
COPY="${RUNTIME_COPY:-1}"
PREROLLOUT_MODE="${RUNTIME_PREROLLOUT_MODE:-plan}"
SERVICE_MODE="${RUNTIME_SERVICE_MODE:-local}"
BATCH_SIZE="${RUNTIME_BATCH_SIZE:-8}"
SGLANG_CUDA="${RUNTIME_SGLANG_CUDA:-0,1,2,3}"
VLLM_CUDA="${RUNTIME_VLLM_CUDA:-4,5,6,7}"

# 环境配置
CONDA_ENV="${ENVIRONMENT_CONDA_ENV:-/opt/conda/envs/vllmqw25}"
SESSION_NAME="${ENVIRONMENT_SESSION_NAME:-0}"

# 脚本路径
RUN_SGLANG_SCRIPT="${SCRIPTS_RUN_SGLANG:-/mnt/new_pfs/liming_team/auroraX/mxd/a_x1/RunSglang/run_sglang.sh}"
PREROLLOUT_SCRIPT="${SCRIPTS_PREROLLOUT:-/mnt/new_pfs/liming_team/auroraX/mxd/a_x1/RolloutVerify/PreRollout.py}"
ASYNC_CLIENT_SCRIPT="${SCRIPTS_ASYNC_CLIENT:-/mnt/new_pfs/liming_team/auroraX/mxd/a_x1/RolloutVerify/async_client_sglang.py}"
PROCESSED_ROLLOUT_SCRIPT="${SCRIPTS_PROCESSED_ROLLOUT:-/mnt/new_pfs/liming_team/auroraX/mxd/a_x1/RolloutVerify/scripts/ProcessedRollout.py}"
EVAL_SCRIPT="${SCRIPTS_EVALUATE_EQUIV:-/mnt/new_pfs/liming_team/auroraX/mxd/a_x1/RolloutVerify/evaluate_2_equiv.py}"

# 检查参数
MAX_CHECKS="${CHECKS_MAX_GEN_CHECKS:-30}"
CHECK_INTERVAL="${CHECKS_GEN_CHECK_INTERVAL:-20}"
MAX_WAIT_TIME="${CHECKS_MAX_WAIT_TIME:-300}"
WAIT_INTERVAL="${CHECKS_WAIT_INTERVAL:-10}"
MAX_BATCH_CHECKS="${CHECKS_MAX_BATCH_CHECKS:-20}"
BATCH_CHECK_INTERVAL="${CHECKS_BATCH_CHECK_INTERVAL:-30}"
EVAL_MAX_CHECKS="${CHECKS_MAX_EVAL_CHECKS:-30}"
EVAL_CHECK_INTERVAL="${CHECKS_EVAL_CHECK_INTERVAL:-10}"

# SGLANG 地址配置
if [ "$SERVICE_MODE" = "remote" ]; then
    SGLANG_URL="${RUNTIME_SGLANG_URL:-http://10.202.4.81:8001}"
else
    SGLANG_PORT="${RUNTIME_SGLANG_PORT:-7373}"
    SGLANG_URL="http://0.0.0.0:$SGLANG_PORT"
fi

echo "=== 配置信息 ==="
echo "任务名称: $TASK_NAME"
echo "基础输出目录: $BASE_OUTPUT_DIR"
echo "Marco模型: $MarcoModelPath"
echo "Rollout模型: $RolloutModelPath"
echo "评测模型: $EVAL_MODEL_PATH"
echo "输入数据: $GenMarcoInput"
echo "预滚动模式: $PREROLLOUT_MODE"
echo "服务模式: $SERVICE_MODE"
echo "批处理大小: $BATCH_SIZE"
echo "SGLang GPU: $SGLANG_CUDA"
echo "VLLM GPU: $VLLM_CUDA"
echo "服务URL: $SGLANG_URL"
echo ""

# ---------- 创建目录结构 ----------
echo "=== 创建任务目录结构 ==="
mkdir -p "$BASE_OUTPUT_DIR"
mkdir -p "$(dirname $GenMarcoOutput)"  # 创建Gen目录
mkdir -p "$RolloutOutput"              # 创建Rollout目录  
mkdir -p "$EVAL_OUTPUT_DIR"            # 创建Eval目录

echo "✓ 目录结构创建完成:"
echo "  - Gen输出: $GenMarcoOutput"
echo "  - Rollout输出: $RolloutOutput"
echo "  - 评测输出: $EVAL_OUTPUT_DIR"
echo ""

# ---------- 启动服务 ----------
if [ "$SERVICE_MODE" = "local" ]; then
    echo "=== 使用本地模式，启动sglang服务 ==="
    tmux new-session -d -s $SESSION_NAME
    tmux send-keys -t $SESSION_NAME:0 "bash $RUN_SGLANG_SCRIPT $SGLANG_CUDA $RolloutModelPath $SGLANG_PORT" Enter
    NEED_WAIT_SERVICE=true
else
    echo "=== 使用远程模式，直接使用外部服务 ==="
    echo "服务URL: $SGLANG_URL"
    NEED_WAIT_SERVICE=true
fi

# ---------- 激活环境 ----------
eval "$(conda shell.bash hook)"
conda activate $CONDA_ENV

# ---------- GPU配置 ----------
TOTAL_GPUS=$(echo ${VLLM_CUDA} | tr ',' ' ' | wc -w)
echo "可用GPU数量: $TOTAL_GPUS"

# ---------- GenMarco阶段 ----------
if [ "$PREROLLOUT_MODE" = "plan" ]; then
    echo "=== 使用plan模式，开始GenMarco步骤 ==="
    echo "将数据集分成${TOTAL_GPUS}份处理"
    
    # 创建临时目录
    TEMP_DIR=$(dirname $GenMarcoInput)/temp_split
    mkdir -p $TEMP_DIR
    
    # 计算总行数并平均分配
    TOTAL_LINES=$(wc -l < $GenMarcoInput)
    LINES_PER_GPU=$((TOTAL_LINES / TOTAL_GPUS))
    echo "总行数: $TOTAL_LINES, 每GPU处理: $LINES_PER_GPU 行"
    
    # 分割数据集
    split -l $LINES_PER_GPU $GenMarcoInput $TEMP_DIR/split_

    # 为每个GPU并行处理数据
    GPU_IDX=0
    for i in ${VLLM_CUDA//,/ }
    do
        SPLIT_FILE=$(ls $TEMP_DIR/split_* | sed -n "$((GPU_IDX+1))p")
        OUTPUT_FILE="${GenMarcoOutput%.jsonl}_part${GPU_IDX}.jsonl"
        
        echo "GPU $i 处理: $SPLIT_FILE -> $OUTPUT_FILE"
        CUDA_VISIBLE_DEVICES=$i python $EVAL_SCRIPT \
            --input $SPLIT_FILE \
            --output $OUTPUT_FILE \
            --model_path $MarcoModelPath \
            --mode MARCO &
        
        GPU_IDX=$((GPU_IDX+1))
    done

    # 等待所有后台任务完成
    wait
    
    # 合并结果
    cat ${GenMarcoOutput%.jsonl}_part*.jsonl > $GenMarcoOutput
    
    # 检查生成文件的总条数
    EXPECTED_LINES=$TOTAL_LINES
    echo "开始检查生成情况..."
    for i in $(seq 1 $MAX_CHECKS); do
        ACTUAL_LINES=$(wc -l < $GenMarcoOutput)
        echo "[$(date +%H:%M:%S)] 检查 $i/$MAX_CHECKS: 预期条数 $EXPECTED_LINES, 实际条数 $ACTUAL_LINES"
        
        if [ $ACTUAL_LINES -eq $EXPECTED_LINES ]; then
            echo "✓ 生成完成！文件条数正确。"
            break
        elif [ $i -eq $MAX_CHECKS ]; then
            echo "! 达到最大检查次数。最终条数: $ACTUAL_LINES/$EXPECTED_LINES"
        else
            echo "继续等待生成完成，${CHECK_INTERVAL}秒后重新检查..."
            sleep $CHECK_INTERVAL
            cat ${GenMarcoOutput%.jsonl}_part*.jsonl > $GenMarcoOutput
        fi
    done

    echo "所有部分处理完成，结果已合并到 $GenMarcoOutput"
    PREROLLOUT_INPUT=$GenMarcoOutput
    
    # 清理临时文件
    rm -rf $TEMP_DIR
    rm -f ${GenMarcoOutput%.jsonl}_part*.jsonl
else
    echo "=== 使用base模式，跳过GenMarco步骤 ==="
    PREROLLOUT_INPUT=$GenMarcoInput
fi

# ---------- 检查sglang服务 ----------
if [ "$NEED_WAIT_SERVICE" = true ]; then
    echo "=== 检查sglang服务状态 ==="
    ELAPSED_TIME=0

    if [ "$SERVICE_MODE" = "local" ]; then
        echo "等待本地sglang服务启动完成..."
    else
        echo "检查远程sglang服务是否可用..."
    fi

    while [ $ELAPSED_TIME -lt $MAX_WAIT_TIME ]; do
        if curl -s --connect-timeout 5 "$SGLANG_URL/health" > /dev/null 2>&1; then
            echo "✓ sglang服务可用！"
            break
        elif curl -s --connect-timeout 5 "$SGLANG_URL/v1/models" > /dev/null 2>&1; then
            echo "✓ sglang服务可用！"
            break
        else
            if [ "$SERVICE_MODE" = "local" ]; then
                echo "[$(date +%H:%M:%S)] 等待本地服务启动... (${ELAPSED_TIME}s/${MAX_WAIT_TIME}s)"
            else
                echo "[$(date +%H:%M:%S)] 检查远程服务连接... (${ELAPSED_TIME}s/${MAX_WAIT_TIME}s)"
            fi
            sleep $WAIT_INTERVAL
            ELAPSED_TIME=$((ELAPSED_TIME + WAIT_INTERVAL))
        fi
    done

    if [ $ELAPSED_TIME -ge $MAX_WAIT_TIME ]; then
        echo "❌ sglang服务不可用！请检查服务状态。"
        exit 1
    fi

    echo "sglang服务已就绪，继续执行后续步骤..."
fi

# ---------- PreRollout阶段 ----------
echo "=== 开始PreRollout步骤 ==="
python $PREROLLOUT_SCRIPT \
    --mode $PREROLLOUT_MODE \
    --expand_count $COPY \
    --input_path $PREROLLOUT_INPUT \
    --output_path $GenMarcoOutput.plan

# ---------- Rollout阶段 ----------
echo "=== 开始Rollout步骤 ==="
python $ASYNC_CLIENT_SCRIPT \
    --input_file $GenMarcoOutput.plan \
    --output_dir $RolloutOutput \
    --batch_size $BATCH_SIZE \
    --llm_url $SGLANG_URL/v1/chat/completions

# 检查Rollout输出文件数量和完整性
echo "开始检查Rollout生成结果..."
EXPECTED_BATCHES=$BATCH_SIZE

for i in $(seq 1 $MAX_BATCH_CHECKS); do
    echo "[$(date +%H:%M:%S)] 检查Rollout结果 $i/$MAX_BATCH_CHECKS..."
    ACTUAL_BATCHES=$(ls $RolloutOutput/batch_*.jsonl 2>/dev/null | wc -l)
    echo "当前已生成 $ACTUAL_BATCHES/$EXPECTED_BATCHES 个batch文件"
    
    if [ $ACTUAL_BATCHES -eq $EXPECTED_BATCHES ]; then
        echo "✓ 所有Rollout批次文件已生成！"
        break
    elif [ $i -eq $MAX_BATCH_CHECKS ]; then
        echo "! 达到最大检查次数。最终生成的batch数量: $ACTUAL_BATCHES/$EXPECTED_BATCHES"
    else
        echo "继续等待Rollout生成完成，${BATCH_CHECK_INTERVAL}秒后重新检查..."
        sleep $BATCH_CHECK_INTERVAL
    fi
done

cat $RolloutOutput/batch_*.jsonl > $RolloutOutput/merged.jsonl

python $PROCESSED_ROLLOUT_SCRIPT \
    --input_file $RolloutOutput/merged.jsonl

# ---------- 评测阶段 ----------
echo "=== 开始评测流程 ==="

EVAL_INPUT="$RolloutOutput/merged_processed.jsonl"
EVAL_OUTPUT_FILE="$EVAL_OUTPUT_DIR/equiv_results.txt"
EVAL_MODE="EVAL"

echo "=== 评测配置信息 ==="
echo "评测输入: $EVAL_INPUT"
echo "评测输出: $EVAL_OUTPUT_FILE"
echo "评测模型: $EVAL_MODEL_PATH"
echo "评测模式: $EVAL_MODE"
echo "使用GPU: $VLLM_CUDA"

# 检查文件
if [ ! -f "$EVAL_INPUT" ]; then
    echo "错误: 评测输入文件不存在: $EVAL_INPUT"
    exit 1
fi

if [ ! -f "$EVAL_SCRIPT" ]; then
    echo "错误: 评测脚本不存在: $EVAL_SCRIPT"
    exit 1
fi

# 评测数据分割处理
echo "=== 开始评测数据分割 ==="
EVAL_TEMP_DIR="$EVAL_OUTPUT_DIR/temp_split"
mkdir -p $EVAL_TEMP_DIR

EVAL_TOTAL_LINES=$(wc -l < $EVAL_INPUT)
EVAL_LINES_PER_GPU=$((EVAL_TOTAL_LINES / TOTAL_GPUS))
echo "评测总行数: $EVAL_TOTAL_LINES, 每GPU处理: $EVAL_LINES_PER_GPU 行"

split -l $EVAL_LINES_PER_GPU $EVAL_INPUT $EVAL_TEMP_DIR/eval_split_

# 并行评测处理
echo "=== 开始并行评测 ==="
EVAL_GPU_IDX=0
for i in ${VLLM_CUDA//,/ }
do
    EVAL_SPLIT_FILE=$(ls $EVAL_TEMP_DIR/eval_split_* | sed -n "$((EVAL_GPU_IDX+1))p")
    EVAL_PART_OUTPUT="${EVAL_OUTPUT_FILE%.txt}_part${EVAL_GPU_IDX}.txt"
    
    echo "GPU $i 评测处理: $EVAL_SPLIT_FILE -> $EVAL_PART_OUTPUT"
    
    CUDA_VISIBLE_DEVICES=$i python $EVAL_SCRIPT \
        --input $EVAL_SPLIT_FILE \
        --output $EVAL_PART_OUTPUT \
        --model_path $EVAL_MODEL_PATH \
        --mode EVAL \
        --k $COPY &
    
    EVAL_GPU_IDX=$((EVAL_GPU_IDX+1))
done

# 等待评测完成并合并结果
echo "=== 等待评测完成 ==="
wait
echo "所有GPU评测任务完成"

cat ${EVAL_OUTPUT_FILE%.txt}_part*.txt > $EVAL_OUTPUT_FILE

# 检测评测生成情况
echo "=== 检测评测生成情况 ==="
EVAL_EXPECTED_LINES=$EVAL_TOTAL_LINES

for i in $(seq 1 $EVAL_MAX_CHECKS); do
    EVAL_ACTUAL_LINES=$(wc -l < $EVAL_OUTPUT_FILE 2>/dev/null || echo 0)
    echo "[$(date +%H:%M:%S)] 评测检查 $i/$EVAL_MAX_CHECKS: 预期条数 $EVAL_EXPECTED_LINES, 实际条数 $EVAL_ACTUAL_LINES"
    
    if [ $EVAL_ACTUAL_LINES -eq $EVAL_EXPECTED_LINES ]; then
        echo "✓ 评测完成！文件条数正确。"
        break
    elif [ $i -eq $EVAL_MAX_CHECKS ]; then
        echo "! 达到评测最大检查次数。最终条数: $EVAL_ACTUAL_LINES/$EVAL_EXPECTED_LINES"
    else
        echo "继续等待评测完成，${EVAL_CHECK_INTERVAL}秒后重新检查..."
        sleep $EVAL_CHECK_INTERVAL
        cat ${EVAL_OUTPUT_FILE%.txt}_part*.txt > $EVAL_OUTPUT_FILE
    fi
done

# ---------- 评测结果统计 ----------
echo "=== 评测结果统计 ==="

if [ -f "$EVAL_OUTPUT_FILE" ]; then
    # 计算平均准确率
    TOTAL_ACC=$(awk '{sum+=$1; count++} END {if(count>0) printf "%.4f", sum/count; else print "0"}' $EVAL_OUTPUT_FILE)
    echo "平均准确率: $TOTAL_ACC"
    echo "详细评测结果已保存到: $EVAL_OUTPUT_FILE"
    
    # 显示准确率分布统计
    echo "--- 准确率分布统计 ---"
    awk '{
        if ($1 == 1) true_count++;
        else if ($1 == 0) false_count++;
        total++
    } END {
        printf "True (准确): %d (%.2f%%)\n", true_count, true_count/total*100;
        printf "False (错误): %d (%.2f%%)\n", false_count, false_count/total*100;
        printf "总数: %d\n", total
    }' $EVAL_OUTPUT_FILE
else
    echo "错误: 评测结果文件不存在"
    TOTAL_ACC="0"
fi

# ---------- 保存 summary.yaml ----------
SUMMARY_FILE="$EVAL_OUTPUT_DIR/summary.yaml"
echo "=== 生成汇总报告 ==="
cat > "$SUMMARY_FILE" << EOF
# ========================================
# 流水线执行汇总报告
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')
# ========================================

# 最终结果
result:
  accuracy: $TOTAL_ACC
  task_name: "$TASK_NAME"
  execution_time: "$(date '+%Y-%m-%d %H:%M:%S')"

# 输出文件路径
outputs:
  base_dir: "$BASE_OUTPUT_DIR"
  gen_marco: "$GenMarcoOutput"
  rollout_dir: "$RolloutOutput"
  eval_dir: "$EVAL_OUTPUT_DIR"
  eval_results: "$EVAL_OUTPUT_FILE"

# 原始配置信息
original_config:
EOF

# 将原始配置追加到summary文件
sed 's/^/  /' "$CONFIG_FILE" >> "$SUMMARY_FILE"

echo "✓ 汇总报告已保存到: $SUMMARY_FILE"
echo ""
echo "=== 任务执行完成 ==="
echo "最终准确率: $TOTAL_ACC"
echo "完整结果保存在: $BASE_OUTPUT_DIR"
echo ""

# ---------- 清理临时文件 ----------
echo "=== 清理临时文件 ==="
rm -rf $EVAL_TEMP_DIR
rm -f ${EVAL_OUTPUT_FILE%.txt}_part*.txt

# 最后的清理，只在本地模式下执行
if [ "$SERVICE_MODE" = "local" ]; then
    trap 'tmux send-keys -t $SESSION_NAME:0 C-c; sleep 2; tmux kill-session -t $SESSION_NAME' EXIT
fi