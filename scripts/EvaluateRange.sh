#!/bin/bash

eval "$(conda shell.bash hook)"
conda activate vllmqw25

cd /mnt/new_pfs/liming_team/auroraX/mxd/a_x1/RolloutVerify

ALL_CUDA_VISIBLE_DEVICES="0,1,2,3,4,5,6,7"
CUDA_DEVICES_ARRAY=(${ALL_CUDA_VISIBLE_DEVICES//,/ })

BASE_DIR="/mnt/new_pfs/liming_team/auroraX/mxd/a_x1/data/v2/processed"
SPLIT_PREFIX="${BASE_DIR}/processed"
OUTPUT_PREFIX="${BASE_DIR}/equiv_acc_split"
MODEL_PATH="/mnt/new_pfs/liming_team/auroraX/LLM/Qwen3-4B"


# 参数：起始编号 终止编号（包含）
START_IDX=$1
END_IDX=$2
if [ -z "$START_IDX" ] || [ -z "$END_IDX" ]; then
    echo "用法: bash Evaluate_range.sh <start_idx> <end_idx>"
    exit 1
fi

echo "起始编号: ${START_IDX}, 终止编号: ${END_IDX}"
GPU_NUM=${#CUDA_DEVICES_ARRAY[@]}
CUR_GPU=0

for idx in $(seq -f "%02g" $START_IDX $END_IDX)
do
    split_file="${SPLIT_PREFIX}_${idx}.jsonl"
    output_file="${OUTPUT_PREFIX}_${idx}"
    echo "正在读取数据: ${split_file}"
    if [ -f "$split_file" ]; then
        echo "正在执行: CUDA_VISIBLE_DEVICES=${CUDA_DEVICES_ARRAY[$CUR_GPU]} python evaluate_2_equiv.py --input ${split_file} --output ${output_file} --model_path ${MODEL_PATH} --k 32"
        CUDA_VISIBLE_DEVICES=${CUDA_DEVICES_ARRAY[$CUR_GPU]} \
        python evaluate_2_equiv.py \
            --input "$split_file" \
            --output "$output_file" \
            --model_path "$MODEL_PATH" \
            --k 32 &
        CUR_GPU=$(( (CUR_GPU+1) % GPU_NUM ))
    fi
done

wait