import json
import os
res_dir = '/mnt/new_pfs/liming_team/auroraX/mxd/a_x1/new_0513/data/v1_50_32_xg'
all_res_name = [f for f in os.listdir(res_dir) if f.endswith('output.jsonl')]
all_res_name.sort()

reduce_res = []
cnt = 0
for i in range(len(all_res_name)):
    with open(os.path.join(res_dir, all_res_name[i]), 'r') as f:
        for line in f:
            try:reduce_res.append(json.loads(line))
            except:
                cnt += 1
                reduce_res.append({
                    'final_answer': 'error'
                })
ori = [json.loads(line) for line in open('/mnt/new_pfs/liming_team/auroraX/mxd/a_x1/new_0513/data/v1_50_32.jsonl')]
post_res = []
for i in range(len(reduce_res)):
    post_res.append({
        'answer':"$"+ori[i]['answer']+"$",
        'final_answer':reduce_res[i]['final_answer'],
        # 'from_mv': verify(parse(ori[i]['answer']), parse(reduce_res[i]['final_answer']))
    })

output_path = '/mnt/new_pfs/liming_team/auroraX/mxd/a_x1/new_0513/data/v1_50_32_xg/post_res.jsonl'
with open(output_path, 'w') as f:
    for item in post_res:
        f.write(json.dumps(item, ensure_ascii=False) + '\n')

print(f'{output_path} saved, cnt: {len(post_res)}')