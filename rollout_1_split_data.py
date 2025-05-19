import json
import os
# target_dir = "/mnt/new_pfs/liming_team/auroraX/mxd/a_x1/new_0513/data/v1_50_32"
target_dir = "/mnt/new_pfs/liming_team/auroraX/mxd/a_x1/new_0513/data/v1_50_32_xg"
source_path = "/mnt/new_pfs/liming_team/auroraX/mxd/a_x1/new_0513/data/v1_50_32.jsonl"

ori = [json.loads(line) for line in open(source_path, 'r')]
print(f"读取到{len(ori)}条数据")
batch_size = 5
batch_num = len(ori) // batch_size

for i in range(batch_size):
    start = i * batch_num
    end = start + batch_num
    batch = ori[start:end]
    with open(os.path.join(target_dir, f"batch_{i}.jsonl"), 'w') as f:
        for item in batch:
            f.write(json.dumps(item, ensure_ascii=False) + "\n")
