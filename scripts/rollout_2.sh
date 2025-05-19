eval "$(conda shell.bash hook)"
conda activate /AuroraX-00/share_v3/mengxiangdi/anaconda3/envs/vllmqw25

DATA_DIR="/mnt/new_pfs/liming_team/auroraX/mxd/a_x1/new_0513/data/v1_50_32_xg"
FILE_NAMES=($(ls $DATA_DIR))
echo "目录下的文件名有："
for file in "${FILE_NAMES[@]}"
do
    python /mnt/new_pfs/liming_team/auroraX/mxd/a_x1/new_0513/preprocess_data_chat.py \
    --data_path $DATA_DIR/$file
done

MODEL="/mnt/new_pfs/liming_team/auroraX/LLM/ZYH-LLM-Qwen2.5-14B-V3"

ALL_CUDA_VISIBLE_DEVICES="2,3,4,5,7"
CUDA_DEVICES_ARRAY=(${ALL_CUDA_VISIBLE_DEVICES//,/ })

for idx in "${!FILE_NAMES[@]}"
do
    file=${FILE_NAMES[$idx]}
    device=${CUDA_DEVICES_ARRAY[$((idx % ${#CUDA_DEVICES_ARRAY[@]}))]}
    CUDA_VISIBLE_DEVICES=$device \
    python /mnt/new_pfs/liming_team/auroraX/mxd/a_x1/new_0513/vllm_offline.py \
        --data_path $DATA_DIR/$(echo $file | sed 's/\.jsonl$/_chat.jsonl/') \
        --output_path $DATA_DIR/$(echo $file | sed 's/\.jsonl$/_chat_output.jsonl/') \
        --model $MODEL &
done