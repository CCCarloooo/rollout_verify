import json
import argparse
from vllm import LLM, SamplingParams

def load_data(jsonl_path):
    with open(jsonl_path, 'r') as f:
        return [json.loads(line) for line in f]

def build_messages(ori, prompt_cot):
    return [
        [{"role": "user", "content": prompt_cot.replace('<gt>', meta['answer']).replace('<ca>', meta['final_answer'])}]
        for meta in ori
    ]

def extract_answer(tripo_out):
    ans = []
    for item in tripo_out:
        try:
            cur = item.text.split('</think>\n\n')[1]
        except Exception:
            cur = 'error'
        ans.append(cur)
    return ans

def verify2judge(tripo):
    if 'false' in tripo:
        return False
    elif all(item == 'error' for item in tripo):
        return False
    return True

def compute_avg_k(ori, k):
    _pre = [verify2judge(item) for item in ori]
    batches = [_pre[i:i+k] for i in range(0, len(_pre), k)]
    accs = []
    for batch in batches:
        if len(batch) == 0:
            accs.append(0)
        else:
            accs.append(sum(batch) / len(batch))
    return accs

def main(args):
    # 1. 读取数据
    ori = load_data(args.input)

    # 2. 构造prompt
    prompt_cot = """你是一名"数学表达式等价性判定专家"。

系统一次性给出两段 LaTeX 表达式：
# ground truth
<gt>

# current answer
<ca>

请按下面 3 步操作，仅输出 `true` 或 `false`：

1. **解析含义**  
   把每段表达式转成内部语义结构，忽略排版、空格、`\\left…\\right`、可选的 `+` 号等格式差异。

2. **归一化表示**  
   - 统一区间写法，确定端点与开闭；  
   - 统一集合元素顺序并去重；  
   - 统一符号：`∞`、`\\infty`、`+∞` 视为同一对象；  
   - 如有省略符号，按常规数学约定补全。

3. **比较**  
   - 若两个归一化结果完全一致，输出 `true`；  
   - 否则输出 `false`。  

除 `true` / `false` 外不要输出任何文字。
"""
    messages = build_messages(ori, prompt_cot)

    # 3. 加载模型
    model_path = args.model_path
    llm = LLM(model=model_path, max_model_len=10000)

    # 4. 推理
    sampling_params = SamplingParams(temperature=0.6, top_p=0.95, top_k=20, max_tokens=10000, n=3)
    outputs = llm.chat(messages, sampling_params)

    # 5. 解析输出
    qw3_vf_res = [extract_answer(item.outputs) for item in outputs]

    # 6. 计算准确率
    ultra_acc = compute_avg_k(qw3_vf_res, 32)

    # 7. 保存结果
    with open(args.output, 'w') as f:
        for item in ultra_acc:
            f.write(str(item) + '\n')

    print(f"评测完成，结果已保存到 {args.output}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', type=str, required=True, help='待评测数据集（jsonl）路径')
    parser.add_argument('--output', type=str, required=True, help='输出文件名')
    parser.add_argument('--model_path', type=str, default='/mnt/new_pfs/liming_team/auroraX/LLM/Qwen3-4B', help='模型路径')
    args = parser.parse_args()
    main(args) 

# python evaluate_equiv.py \
#   --input /mnt/new_pfs/liming_team/auroraX/mxd/a_x1/new_0513/data/v1_50_32_xg/post_res.jsonl \
#   --output /mnt/new_pfs/liming_team/auroraX/mxd/a_x1/new_0513/data/v1_50_32_xg/equiv_acc.json \
#   --model_path /mnt/new_pfs/liming_team/auroraX/LLM/Qwen3-4B