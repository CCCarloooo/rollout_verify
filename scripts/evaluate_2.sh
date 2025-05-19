eval "$(conda shell.bash hook)"
conda activate /AuroraX-00/share_v3/mengxiangdi/anaconda3/envs/vllmqw25

ALL_CUDA_VISIBLE_DEVICES="2,3,4,5,7"
CUDA_DEVICES_ARRAY=(${ALL_CUDA_VISIBLE_DEVICES//,/ })

BASE_DIR="/mnt/new_pfs/liming_team/auroraX/mxd/a_x1/data/v1_scale"
INPUT_PATH="${BASE_DIR}/processed_res.jsonl"

SPLIT_PREFIX="${BASE_DIR}/post_res_split"
OUTPUT_PREFIX="${BASE_DIR}/equiv_acc_split"
MODEL_PATH="/mnt/new_pfs/liming_team/auroraX/LLM/Qwen3-4B"

# 计算总行数和每份的行数
total_lines=$(wc -l < "$INPUT_PATH")
num_devices=${#CUDA_DEVICES_ARRAY[@]}
lines_per_file=$(( (total_lines + num_devices - 1) / num_devices ))

# 分割jsonl文件
split -d -l $lines_per_file "$INPUT_PATH" "${SPLIT_PREFIX}_"
echo "split done, every file has $lines_per_file lines"

# 启动多卡并行评测
for idx in "${!CUDA_DEVICES_ARRAY[@]}"
do
    split_file=$(printf "${SPLIT_PREFIX}_%02d" $idx)
    output_file=$(printf "${OUTPUT_PREFIX}_%02d" $idx)
    if [ -f "$split_file" ]; then
        CUDA_VISIBLE_DEVICES=${CUDA_DEVICES_ARRAY[$idx]} \
        python /mnt/new_pfs/liming_team/auroraX/mxd/a_x1/new_0513/evaluate_2_equiv.py \
            --input "$split_file" \
            --output "$output_file" \
            --model_path "$MODEL_PATH" \
            --k 32 &
    fi
done