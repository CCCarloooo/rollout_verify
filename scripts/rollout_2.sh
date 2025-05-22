eval "$(conda shell.bash hook)"
conda activate /AuroraX-00/share_v3/mengxiangdi/anaconda3/envs/vllmqw25
cd /mnt/new_pfs/liming_team/auroraX/mxd/a_x1/rollout_verify

DATA_DIR="/mnt/new_pfs/liming_team/auroraX/mxd/a_x1/rollout_verify/tmp1"
FILE_NAMES=($(ls $DATA_DIR/batch*))

for file in "${FILE_NAMES[@]}"
do
    python rollout_2_preprocess_data_chat.py \
    --data_path $file
done

MODEL="/mnt/new_pfs/liming_team/auroraX/LLM/ZYH-LLM-Qwen2.5-14B-V3"

ALL_CUDA_VISIBLE_DEVICES="2,3,4,5,7"
CUDA_DEVICES_ARRAY=(${ALL_CUDA_VISIBLE_DEVICES//,/ })

for idx in "${!FILE_NAMES[@]}"
do
    file=${FILE_NAMES[$idx]}
    device=${CUDA_DEVICES_ARRAY[$((idx % ${#CUDA_DEVICES_ARRAY[@]}))]}
    CUDA_VISIBLE_DEVICES=$device \
    python /mnt/new_pfs/liming_team/auroraX/mxd/a_x1/rollout_verify/vllm_offline.py \
        --data_path $(echo $file | sed 's/\.jsonl$/_chat.jsonl/') \
        --output_path $(echo $file | sed 's/\.jsonl$/_chat_output.jsonl/') \
        --model $MODEL &
done