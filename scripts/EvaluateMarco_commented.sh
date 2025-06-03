#!/bin/bash
# =============================================================================
# Shell语法解释和详细注释版本的EvaluateMarco.sh
# =============================================================================

# 【语法1】shebang行 - 指定脚本解释器
# 语法: #!/bin/bash
# 说明: 告诉系统使用bash来执行这个脚本
#!/bin/bash

# 【语法2】set命令 - 设置shell选项
# 语法: set -e
# 说明: 遇到任何命令返回非0退出码时立即退出脚本
# 例子: 
#   set -e        # 开启错误退出
#   set +e        # 关闭错误退出
#   set -x        # 显示执行的命令（调试用）
set -e

# =============================================================================
# 【语法3】位置参数和变量赋值
# =============================================================================

# 【语法3.1】位置参数 - 获取脚本参数
# 语法: $1, $2, $3... 或 ${1}, ${2}...
# 说明: $1是第一个参数，$2是第二个参数，以此类推
# 例子:
#   ./script.sh config.yaml debug  # $1="config.yaml", $2="debug"
CONFIG_FILE="$1"

# 【语法3.2】条件判断 - 检查参数和文件
# 语法: [ condition ] 或 [[ condition ]]
# 说明: [ ]是test命令的简写，[[ ]]是bash扩展，功能更强
# 常用条件:
#   -z "string"     # 字符串为空
#   -n "string"     # 字符串非空  
#   -f "file"       # 文件存在且是普通文件
#   -d "dir"        # 目录存在
#   -e "path"       # 路径存在
if [ -z "$CONFIG_FILE" ] || [ ! -f "$CONFIG_FILE" ]; then
    # 【语法3.3】echo命令 - 输出文本
    echo "用法: $0 <config.yaml>"     # $0是脚本名称
    echo "示例: $0 run.yaml"
    # 【语法3.4】exit命令 - 退出脚本
    # 语法: exit [退出码]
    # 说明: 0表示成功，非0表示失败
    exit 1
fi

echo "=== 读取配置文件: $CONFIG_FILE ==="

# =============================================================================
# 【语法4】Here Document - 多行输入
# =============================================================================

# 【语法4.1】Here Document语法
# 语法: command <<EOF 或 command <<'EOF'  
# 说明: <<EOF允许变量替换，<<'EOF'不允许变量替换
# 例子:
#   cat <<EOF
#   Hello $USER    # 会替换$USER变量
#   EOF
#   
#   cat <<'EOF'  
#   Hello $USER    # 不会替换，原样输出$USER
#   EOF

# 【语法4.2】eval命令 - 执行动态命令
# 语法: eval "command"
# 说明: 先进行变量替换，然后执行结果命令
# 例子:
#   cmd="ls -l"
#   eval $cmd      # 等同于执行 ls -l
# 【部分python】
# key = re.sub(r'\W', '_', prefix).upper() # 设置环境变量的key，让所有的字母都大写
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

# =============================================================================
# 【语法5】数组操作
# =============================================================================

# 【语法5.1】数组定义
# 语法: array=(元素1 元素2 元素3)
# 说明: 用圆括号定义数组，元素用空格分隔
# 例子:
#   fruits=("apple" "banana" "orange")
#   numbers=(1 2 3 4 5)
required_vars=("TASK_NAME_PREFIX" "TASK_OUTPUT_ROOT" "MODELS_MARCO" "MODELS_ROLLOUT" "MODELS_EVAL" "DATA_INPUT_JSONL")

# 【语法5.2】数组遍历
# 语法: "${array[@]}" 展开所有元素
# 说明: [@]表示所有元素，"${array[@]}"保持元素的完整性
# 例子:
#   for item in "${fruits[@]}"; do
#       echo $item
#   done
for var in "${required_vars[@]}"; do
    # 【语法5.3】间接变量引用
    # 语法: ${!var} 
    # 说明: 当var="name"时，${!var}等同于$name
    # 例子:
    #   name="John"
    #   var="name"
    #   echo ${!var}    # 输出: John
    if [ -z "${!var}" ]; then
        echo "错误: 配置文件中缺少必要参数: $var"
        exit 1
    fi
done

# =============================================================================
# 【语法6】命令替换和字符串操作
# =============================================================================

# 【语法6.1】命令替换
# 语法: $(command) 或 `command`
# 说明: 执行命令并返回结果，推荐使用$()
# 例子:
#   current_time=$(date)
#   file_count=$(ls | wc -l)
TASK_NAME="${TASK_NAME_PREFIX}_$(date +%m%d_%H%M)"
BASE_OUTPUT_DIR="$TASK_OUTPUT_ROOT/$TASK_NAME"

# 【语法6.2】变量的默认值
# 语法: ${var:-default} 如果var为空或未定义，使用default
# 语法: ${var:=default} 如果var为空或未定义，设置var=default并返回
# 语法: ${var:+value}   如果var非空，返回value，否则返回空
# 例子:
#   name=${1:-"默认姓名"}        # 如果$1为空，使用"默认姓名"
#   port=${PORT:=8080}          # 如果PORT未设置，设置为8080
#   debug=${DEBUG:+"--debug"}   # 如果DEBUG非空，返回"--debug"
COPY="${RUNTIME_COPY:-1}"
PREROLLOUT_MODE="${RUNTIME_PREROLLOUT_MODE:-plan}"
SERVICE_MODE="${RUNTIME_SERVICE_MODE:-local}"
BATCH_SIZE="${RUNTIME_BATCH_SIZE:-8}"
SGLANG_CUDA="${RUNTIME_SGLANG_CUDA:-0,1,2,3}"
VLLM_CUDA="${RUNTIME_VLLM_CUDA:-4,5,6,7}"

# 模型路径赋值
MarcoModelPath="$MODELS_MARCO"
RolloutModelPath="$MODELS_ROLLOUT"
EVAL_MODEL_PATH="$MODELS_EVAL"

# 输入输出路径
GenMarcoInput="$DATA_INPUT_JSONL"
GenMarcoOutput="$BASE_OUTPUT_DIR/Gen/GenMarco.jsonl"
RolloutOutput="$BASE_OUTPUT_DIR/Rollout"
EVAL_OUTPUT_DIR="$BASE_OUTPUT_DIR/Eval"

# 环境配置
CONDA_ENV="${ENVIRONMENT_CONDA_ENV:-/opt/conda/envs/vllmqw25}"
SESSION_NAME="${ENVIRONMENT_SESSION_NAME:-0}"

# 脚本路径配置
RUN_SGLANG_SCRIPT="${SCRIPTS_RUN_SGLANG:-/mnt/new_pfs/liming_team/auroraX/mxd/a_x1/RunSglang/run_sglang.sh}"
PREROLLOUT_SCRIPT="${SCRIPTS_PREROLLOUT:-/mnt/new_pfs/liming_team/auroraX/mxd/a_x1/RolloutVerify/PreRollout.py}"
ASYNC_CLIENT_SCRIPT="${SCRIPTS_ASYNC_CLIENT:-/mnt/new_pfs/liming_team/auroraX/mxd/a_x1/RolloutVerify/async_client_sglang.py}"
PROCESSED_ROLLOUT_SCRIPT="${SCRIPTS_PROCESSED_ROLLOUT:-/mnt/new_pfs/liming_team/auroraX/mxd/a_x1/RolloutVerify/scripts/ProcessedRollout.py}"
EVAL_SCRIPT="${SCRIPTS_EVALUATE_EQUIV:-/mnt/new_pfs/liming_team/auroraX/mxd/a_x1/RolloutVerify/evaluate_2_equiv.py}"

# 检查参数配置
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

# =============================================================================
# 【语法7】文件和目录操作
# =============================================================================

echo "=== 创建任务目录结构 ==="

# 【语法7.1】mkdir命令 - 创建目录
# 语法: mkdir [-p] 目录路径
# 说明: -p参数表示递归创建父目录，如果目录已存在不报错
# 例子:
#   mkdir dir1                    # 创建dir1目录
#   mkdir -p path/to/deep/dir     # 递归创建多层目录
mkdir -p "$BASE_OUTPUT_DIR"
mkdir -p "$(dirname $GenMarcoOutput)"  # dirname获取文件的目录部分
mkdir -p "$RolloutOutput"              
mkdir -p "$EVAL_OUTPUT_DIR"            

echo "✓ 目录结构创建完成:"
echo "  - Gen输出: $GenMarcoOutput"
echo "  - Rollout输出: $RolloutOutput"
echo "  - 评测输出: $EVAL_OUTPUT_DIR"
echo ""

# =============================================================================
# 【语法8】tmux会话管理
# =============================================================================

if [ "$SERVICE_MODE" = "local" ]; then
    echo "=== 使用本地模式，启动sglang服务 ==="
    
    # 【语法8.1】tmux命令 - 终端复用器
    # 语法: tmux new-session -d -s session_name
    # 说明: -d表示后台运行，-s指定会话名称
    # 例子:
    #   tmux new-session -d -s mysession    # 创建名为mysession的后台会话
    #   tmux list-sessions                  # 列出所有会话
    #   tmux attach -t mysession           # 连接到mysession会话
    tmux new-session -d -s $SESSION_NAME
    
    # 【语法8.2】tmux send-keys - 向会话发送命令
    # 语法: tmux send-keys -t session:window "command" Enter
    # 说明: 向指定会话窗口发送键盘输入
    tmux send-keys -t $SESSION_NAME:0 "bash $RUN_SGLANG_SCRIPT $SGLANG_CUDA $RolloutModelPath $SGLANG_PORT" Enter
    NEED_WAIT_SERVICE=true
else
    echo "=== 使用远程模式，直接使用外部服务 ==="
    echo "服务URL: $SGLANG_URL"
    NEED_WAIT_SERVICE=true
fi

# =============================================================================
# 【语法9】conda环境激活
# =============================================================================

# 【语法9.1】eval命令配合conda - 激活conda环境
# 语法: eval "$(conda shell.bash hook)"
# 说明: 初始化conda命令，使conda activate可用
eval "$(conda shell.bash hook)"
conda activate $CONDA_ENV

# =============================================================================
# 【语法10】字符串处理和算术运算
# =============================================================================

# 【语法10.1】字符串替换和分割
# 语法: ${string//pattern/replacement} 全局替换
# 语法: ${string/pattern/replacement}  单次替换
# 语法: echo string | tr 'char1' 'char2' 字符转换
# 例子:
#   text="hello world world"
#   echo ${text//world/WORLD}    # 输出: hello WORLD WORLD
#   echo ${text/world/WORLD}     # 输出: hello WORLD world
#   echo "a,b,c" | tr ',' ' '    # 输出: a b c
TOTAL_GPUS=$(echo ${VLLM_CUDA} | tr ',' ' ' | wc -w)
echo "可用GPU数量: $TOTAL_GPUS"

# =============================================================================
# 【语法11】GenMarco阶段 - 复杂的条件和循环处理
# =============================================================================

if [ "$PREROLLOUT_MODE" = "plan" ]; then
    echo "=== 使用plan模式，开始GenMarco步骤 ==="
    echo "将数据集分成${TOTAL_GPUS}份处理"
    
    # 【语法11.1】dirname命令 - 获取路径的目录部分
    # 语法: dirname /path/to/file
    # 说明: 返回文件路径的目录部分
    # 例子:
    #   dirname /home/user/file.txt    # 输出: /home/user
    TEMP_DIR=$(dirname $GenMarcoInput)/temp_split
    mkdir -p $TEMP_DIR
    
    # 【语法11.2】wc命令 - 统计文件内容
    # 语法: wc [选项] 文件
    # 说明: -l统计行数，-w统计单词数，-c统计字符数
    # 例子:
    #   wc -l file.txt              # 统计行数
    #   echo "hello world" | wc -w  # 统计单词数，输出2
    TOTAL_LINES=$(wc -l < $GenMarcoInput)
    
    # 【语法11.3】算术运算
    # 语法: $((表达式))
    # 说明: 进行整数算术运算
    # 例子:
    #   result=$((5 + 3))           # result=8
    #   count=$((count + 1))        # 自增
    #   half=$((total / 2))         # 除法
    LINES_PER_GPU=$((TOTAL_LINES / TOTAL_GPUS))
    echo "总行数: $TOTAL_LINES, 每GPU处理: $LINES_PER_GPU 行"
    
    # 【语法11.4】split命令 - 分割文件
    # 语法: split [选项] 输入文件 输出前缀
    # 说明: -l指定每个文件的行数
    # 例子:
    #   split -l 100 big_file.txt part_    # 每100行分割一次，生成part_aa, part_ab等
    split -l $LINES_PER_GPU $GenMarcoInput $TEMP_DIR/split_

    # 【语法11.5】复杂的for循环和字符串处理
    # 语法: for var in ${string//,/ }
    # 说明: 将逗号分隔的字符串转换为空格分隔，然后遍历
    # 例子:
    #   gpus="0,1,2,3"
    #   for gpu in ${gpus//,/ }; do echo $gpu; done    # 输出0 1 2 3
    GPU_IDX=0
    for i in ${VLLM_CUDA//,/ }
    do
        # 【语法11.6】sed命令 - 流编辑器
        # 语法: sed 'n p' 打印第n行，sed 's/pattern/replacement/' 替换
        # 说明: -n抑制默认输出，p打印匹配行
        # 例子:
        #   sed -n '5p' file.txt           # 打印第5行
        #   sed 's/old/new/g' file.txt     # 全局替换old为new
        SPLIT_FILE=$(ls $TEMP_DIR/split_* | sed -n "$((GPU_IDX+1))p")
        
        # 【语法11.7】字符串截取和替换
        # 语法: ${string%pattern}  从右边删除匹配的最短部分
        # 语法: ${string%%pattern} 从右边删除匹配的最长部分  
        # 语法: ${string#pattern}  从左边删除匹配的最短部分
        # 语法: ${string##pattern} 从左边删除匹配的最长部分
        # 例子:
        #   file="test.tar.gz"
        #   echo ${file%.*}      # 输出: test.tar (删除最后一个.及后面内容)
        #   echo ${file%%.*}     # 输出: test (删除第一个.及后面内容)
        OUTPUT_FILE="${GenMarcoOutput%.jsonl}_part${GPU_IDX}.jsonl"
        
        echo "GPU $i 处理: $SPLIT_FILE -> $OUTPUT_FILE"
        
        # 【语法11.8】环境变量设置和后台进程
        # 语法: VARIABLE=value command  临时设置环境变量
        # 语法: command &               后台运行命令
        # 说明: &使命令在后台运行，不阻塞脚本继续执行
        # 例子:
        #   PATH=/tmp:$PATH ls &          # 临时修改PATH并后台运行ls
        #   sleep 60 &                    # 后台睡眠60秒
        CUDA_VISIBLE_DEVICES=$i python $EVAL_SCRIPT \
            --input $SPLIT_FILE \
            --output $OUTPUT_FILE \
            --model_path $MarcoModelPath \
            --mode MARCO &
        
        GPU_IDX=$((GPU_IDX+1))
    done

    # 【语法11.9】wait命令 - 等待后台进程
    # 语法: wait [进程ID]
    # 说明: 等待所有后台进程完成，如果指定进程ID则只等待该进程
    # 例子:
    #   command1 &
    #   pid=$!              # $!获取最后一个后台进程的PID
    #   command2 &
    #   wait                # 等待所有后台进程
    #   wait $pid           # 只等待指定进程
    wait
    
    # 【语法11.10】cat命令 - 连接和显示文件
    # 语法: cat 文件1 文件2 > 输出文件
    # 说明: 将多个文件内容连接起来
    # 例子:
    #   cat file1.txt file2.txt > merged.txt    # 合并文件
    cat ${GenMarcoOutput%.jsonl}_part*.jsonl > $GenMarcoOutput
    
    # 检查生成文件的总条数
    EXPECTED_LINES=$TOTAL_LINES
    echo "开始检查生成情况..."
    
    # 【语法11.11】seq命令 - 生成数字序列
    # 语法: seq [开始] [步长] 结束
    # 说明: 生成数字序列，默认从1开始，步长为1
    # 例子:
    #   seq 5           # 输出: 1 2 3 4 5
    #   seq 2 8         # 输出: 2 3 4 5 6 7 8  
    #   seq 0 2 10      # 输出: 0 2 4 6 8 10
    for i in $(seq 1 $MAX_CHECKS); do
        ACTUAL_LINES=$(wc -l < $GenMarcoOutput)
        
        # 【语法11.12】date命令 - 日期时间格式化
        # 语法: date +格式
        # 说明: +%H:%M:%S表示时:分:秒格式
        # 例子:
        #   date +%Y-%m-%d          # 输出: 2024-01-15
        #   date +"%H:%M:%S"        # 输出: 14:30:25
        echo "[$(date +%H:%M:%S)] 检查 $i/$MAX_CHECKS: 预期条数 $EXPECTED_LINES, 实际条数 $ACTUAL_LINES"
        
        if [ $ACTUAL_LINES -eq $EXPECTED_LINES ]; then
            echo "✓ 生成完成！文件条数正确。"
            break
        elif [ $i -eq $MAX_CHECKS ]; then
            echo "! 达到最大检查次数。最终条数: $ACTUAL_LINES/$EXPECTED_LINES"
        else
            echo "继续等待生成完成，${CHECK_INTERVAL}秒后重新检查..."
            
            # 【语法11.13】sleep命令 - 暂停执行
            # 语法: sleep 时间
            # 说明: 暂停指定时间，可以是秒、分钟等
            # 例子:
            #   sleep 5        # 暂停5秒
            #   sleep 1m       # 暂停1分钟
            #   sleep 0.5      # 暂停0.5秒
            sleep $CHECK_INTERVAL
            cat ${GenMarcoOutput%.jsonl}_part*.jsonl > $GenMarcoOutput
        fi
    done

    echo "所有部分处理完成，结果已合并到 $GenMarcoOutput"
    PREROLLOUT_INPUT=$GenMarcoOutput
    
    # 【语法11.14】rm命令 - 删除文件
    # 语法: rm [选项] 文件/目录
    # 说明: -r递归删除目录，-f强制删除不询问
    # 例子:
    #   rm file.txt           # 删除文件
    #   rm -r directory/      # 递归删除目录
    #   rm -rf temp/          # 强制递归删除，不询问
    rm -rf $TEMP_DIR
    rm -f ${GenMarcoOutput%.jsonl}_part*.jsonl
else
    echo "=== 使用base模式，跳过GenMarco步骤 ==="
    PREROLLOUT_INPUT=$GenMarcoInput
fi

# =============================================================================
# 【语法12】网络服务检查
# =============================================================================

if [ "$NEED_WAIT_SERVICE" = true ]; then
    echo "=== 检查sglang服务状态 ==="
    ELAPSED_TIME=0

    if [ "$SERVICE_MODE" = "local" ]; then
        echo "等待本地sglang服务启动完成..."
    else
        echo "检查远程sglang服务是否可用..."
    fi

    while [ $ELAPSED_TIME -lt $MAX_WAIT_TIME ]; do
        # 【语法12.1】curl命令 - HTTP客户端
        # 语法: curl [选项] URL
        # 说明: -s静默模式，--connect-timeout设置连接超时
        # 例子:
        #   curl -s http://example.com                    # 静默获取网页
        #   curl --connect-timeout 5 http://example.com  # 5秒连接超时
        
        # 【语法12.2】重定向 - 输出重定向
        # 语法: command > file 标准输出重定向到文件
        # 语法: command 2> file 标准错误重定向到文件  
        # 语法: command > file 2>&1 标准输出和错误都重定向到文件
        # 语法: command > /dev/null 2>&1 丢弃所有输出
        # 例子:
        #   ls > files.txt 2>&1          # 输出和错误都写入files.txt
        #   command > /dev/null 2>&1     # 静默执行，不显示任何输出
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

# =============================================================================
# 【语法13】Python脚本调用
# =============================================================================

echo "=== 开始PreRollout步骤 ==="
# 【语法13.1】python命令调用 - 带参数的脚本执行
# 语法: python script.py --参数名 参数值
# 说明: 使用反斜杠\可以将长命令分行写
python $PREROLLOUT_SCRIPT \
    --mode $PREROLLOUT_MODE \
    --expand_count $COPY \
    --input_path $PREROLLOUT_INPUT \
    --output_path $GenMarcoOutput.plan

echo "=== 开始Rollout步骤 ==="
python $ASYNC_CLIENT_SCRIPT \
    --input_file $GenMarcoOutput.plan \
    --output_dir $RolloutOutput \
    --batch_size $BATCH_SIZE \
    --llm_url $SGLANG_URL/v1/chat/completions

# =============================================================================
# 【语法14】文件检查和批处理
# =============================================================================

echo "开始检查Rollout生成结果..."
EXPECTED_BATCHES=$BATCH_SIZE

for i in $(seq 1 $MAX_BATCH_CHECKS); do
    echo "[$(date +%H:%M:%S)] 检查Rollout结果 $i/$MAX_BATCH_CHECKS..."
    
    # 【语法14.1】ls命令配合通配符和错误处理
    # 语法: ls 文件模式 2>/dev/null
    # 说明: 2>/dev/null将错误输出重定向到/dev/null，避免错误信息显示
    # 通配符: * 匹配任意字符，? 匹配单个字符，[] 匹配字符集合
    # 例子:
    #   ls *.txt 2>/dev/null | wc -l     # 统计txt文件数量，不显示错误
    #   ls file?.log                     # 匹配file1.log, fileA.log等
    #   ls file[0-9].txt                 # 匹配file0.txt到file9.txt
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

# 合并所有batch文件
cat $RolloutOutput/batch_*.jsonl > $RolloutOutput/merged.jsonl

# 处理合并后的rollout数据
python $PROCESSED_ROLLOUT_SCRIPT \
    --input_file $RolloutOutput/merged.jsonl

# =============================================================================
# 【语法15】评测阶段 - 复杂的并行处理
# =============================================================================

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

# 检查文件存在性
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
    # 【语法15.1】复合命令和错误处理
    # 语法: command 2>/dev/null || echo default
    # 说明: 如果command失败，执行||后面的命令作为默认值
    # 例子:
    #   count=$(wc -l < file.txt 2>/dev/null || echo 0)  # 文件不存在时返回0
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

# =============================================================================
# 【语法16】awk文本处理
# =============================================================================

echo "=== 评测结果统计 ==="

if [ -f "$EVAL_OUTPUT_FILE" ]; then
    # 【语法16.1】awk命令 - 强大的文本处理工具
    # 语法: awk '条件 {动作}' 文件
    # 内置变量: $1,$2..第1,2列; NR行号; NF列数; $0整行
    # 例子:
    #   awk '{sum+=$1} END {print sum}' file.txt           # 计算第1列总和
    #   awk 'NR>1 {print $2}' file.csv                    # 跳过第1行，打印第2列
    #   awk '{if($1>10) print $0}' file.txt               # 打印第1列大于10的行
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

# =============================================================================
# 【语法17】Here Document写入文件
# =============================================================================

SUMMARY_FILE="$EVAL_OUTPUT_DIR/summary.yaml"
echo "=== 生成汇总报告 ==="

# 【语法17.1】Here Document重定向到文件
# 语法: cat > 文件 << EOF
# 说明: 将Here Document的内容写入文件
# 例子:
#   cat > config.txt << EOF
#   name=test
#   value=123
#   EOF
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

# 【语法17.2】sed文本处理 - 添加缩进
# 语法: sed 's/^/前缀/' 文件
# 说明: 在每行开头添加前缀，^表示行开头
# 例子:
#   sed 's/^/  /' file.txt        # 每行开头添加2个空格
#   sed 's/^/# /' file.txt        # 每行开头添加"# "
sed 's/^/  /' "$CONFIG_FILE" >> "$SUMMARY_FILE"

echo "✓ 汇总报告已保存到: $SUMMARY_FILE"
echo ""
echo "=== 任务执行完成 ==="
echo "最终准确率: $TOTAL_ACC"
echo "完整结果保存在: $BASE_OUTPUT_DIR"
echo ""

# =============================================================================
# 【语法18】陷阱处理和清理
# =============================================================================

echo "=== 清理临时文件 ==="
rm -rf $EVAL_TEMP_DIR
rm -f ${EVAL_OUTPUT_FILE%.txt}_part*.txt

# 【语法18.1】trap命令 - 信号陷阱
# 语法: trap '命令' 信号
# 说明: 当收到指定信号时执行命令，EXIT表示脚本退出时
# 常用信号: EXIT, INT(Ctrl+C), TERM, HUP
# 例子:
#   trap 'echo "清理中..."; rm -f temp_*' EXIT    # 脚本退出时清理临时文件
#   trap 'echo "收到中断信号"' INT              # Ctrl+C时执行
if [ "$SERVICE_MODE" = "local" ]; then
    # 设置陷阱：脚本退出时自动停止tmux会话
    trap 'tmux send-keys -t $SESSION_NAME:0 C-c; sleep 2; tmux kill-session -t $SESSION_NAME' EXIT
fi

# =============================================================================
# Shell语法总结:
# =============================================================================
# 1. 变量: $var, ${var}, ${var:-default}, ${!var}
# 2. 条件: [ ], [[ ]], if-then-else-fi
# 3. 循环: for-do-done, while-do-done
# 4. 数组: arr=(), ${arr[@]}, ${#arr[@]}
# 5. 字符串: ${string%pattern}, ${string//old/new}
# 6. 算术: $((expression))
# 7. 命令替换: $(command), `command`
# 8. 重定向: >, >>, <, 2>, 2>&1, |
# 9. 后台进程: &, wait, jobs
# 10. 函数: function name() { commands; }
# 11. Here Document: <<EOF, <<'EOF'
# 12. 通配符: *, ?, [], {}
# 13. 引号: "双引号", '单引号', `反引号`
# 14. 特殊变量: $0, $1-$9, $@, $#, $$, $?, $!
# 15. 测试: -f, -d, -e, -z, -n, -eq, -ne, -lt, -gt
# ============================================================================= 