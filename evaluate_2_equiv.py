import json
import argparse
from vllm import LLM, SamplingParams

def load_data(jsonl_path):
    with open(jsonl_path, 'r') as f:
        return [json.loads(line) for line in f]

def build_messages_eval(ori, prompt_cot):
    """构造EVAL模式的messages"""
    return [
        [{"role": "user", "content": prompt_cot.replace('<gt>', meta['answer']).replace('<ca>', meta['final_answer'])}]
        for meta in ori
    ]

def build_messages_marco(ori, prompt_template):
    """构造MARCO模式的messages"""
    return [
        [{"role": "user", "content": prompt_template.replace('{question}', meta.get('question', ''))}]
        for meta in ori
    ]

def extract_answer_eval(tripo_out):
    """提取EVAL模式的答案"""
    ans = []
    for item in tripo_out:
        try:
            cur = item.text.split('</think>\n\n')[1]
        except Exception:
            cur = 'error'
        ans.append(cur)
    return ans

def extract_answer_marco(out):
    """提取MARCO模式的答案"""
    return out.outputs[0].text.strip()

def verify2judge_eval(tripo):
    """EVAL模式的判断逻辑"""
    if 'false' in tripo:
        return False
    elif all(item == 'error' for item in tripo):
        return False
    return True

def verify2judge_marco(tripo):
    """MARCO模式的判断逻辑 - 这里可以根据具体需求调整"""
    # 简单示例：检查是否包含关键词或长度
    if all(item == 'error' for item in tripo):
        return False
    # 可以添加更复杂的评判逻辑，比如检查回答质量
    return any(len(item.strip()) > 50 for item in tripo if item != 'error')

def compute_avg_k(ori, k, mode):
    """计算平均准确率"""
    if mode == 'EVAL':
        _pre = [verify2judge_eval(item) for item in ori]
    elif mode == 'MARCO':
        _pre = [verify2judge_marco(item) for item in ori]
    else:
        raise ValueError(f"不支持的模式: {mode}")
    
    batches = [_pre[i:i+k] for i in range(0, len(_pre), k)]
    accs = []
    for batch in batches:
        if len(batch) == 0:
            accs.append(0)
        else:
            accs.append(sum(batch) / len(batch))
    return accs

def get_eval_prompt():
    """获取EVAL模式的prompt"""
    return """你是一名"数学表达式等价性判定专家"。

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

def get_marco_prompt():
    """获取MARCO模式的prompt"""
    return """# Role Definition

You are a professional "Mathematical Problem Analysis Expert," specializing in dissecting mathematical problems and outlining solution strategies. Your strength lies in identifying the core mathematical concepts and appropriate techniques, and providing users with a clear breakdown of the reasoning process rather than computing the final answer.

# Task Definition

Whenever a user presents a mathematical problem, you should:
1. Identify the key mathematical concepts, formulas, or theorems required to solve the problem.
2. Analyze the direction and strategy for approaching the problem.
3. Offer a clear sequence of thought steps and methodological guidance.
4. Explain how to decompose a complex problem into simpler, manageable parts.
5. Handle various types of mathematical questions—such as trigonometric simplification, calculus, algebraic equations, and more—by focusing exclusively on analysis and strategy rather than on performing calculations or providing the final result.

Note: Do not include any calculation steps or final numeric answers; only supply the analysis methodology.

# Output Format Requirements

Your response should be concise and presented in coherent paragraphs (without structured headings), including:

- The essential mathematical knowledge points and identities needed.
- How to break the problem into easier-to-handle components.
- The key steps and reasoning pathways for solving the problem.
- General methodological tips applicable to this category of problems.
{question}
"""

def main(args):
    print(f"正在读取数据: {args.input}")
    print(f"使用模式: {args.mode}")
    
    # 1. 读取数据
    ori = load_data(args.input)
    print(f"正在构造prompt")
    
    # 2. 根据模式构造prompt和messages
    if args.mode == 'EVAL':
        prompt = get_eval_prompt()
        messages = build_messages_eval(ori, prompt)
        extract_func = extract_answer_eval
        max_tokens = 10000
        sampling_params = SamplingParams(temperature=0.6, top_p=0.95, top_k=20, max_tokens=max_tokens, n=3)
    elif args.mode == 'MARCO':
        prompt = get_marco_prompt()
        messages = build_messages_marco(ori, prompt)
        extract_func = extract_answer_marco
        max_tokens = 1024
        sampling_params = SamplingParams(temperature=1, top_p=0.95, top_k=20, max_tokens=max_tokens)
    else:
        raise ValueError(f"不支持的模式: {args.mode}. 支持的模式: EVAL, MARCO")

    # 3. 加载模型
    model_path = args.model_path
    llm = LLM(model=model_path, max_model_len=max_tokens)

    # 4. 推理
    outputs = llm.chat(messages, sampling_params)

    # 5. 处理输出
    if args.mode == 'EVAL':
        # EVAL模式：解析输出并计算准确率
        model_res = [extract_func(item.outputs) for item in outputs]
        ultra_acc = compute_avg_k(model_res, args.k, args.mode)
        
        # 保存准确率结果
        with open(args.output, 'w') as f:
            for item in ultra_acc:
                f.write(str(item) + '\n')
        print(f"EVAL模式评测完成，准确率结果已保存到 {args.output}")
        
    elif args.mode == 'MARCO':
        # MARCO模式：直接保存生成结果
        results = []
        for i, output in enumerate(outputs):
            result = {
                'index': i,
                'question': ori[i].get('question', ''),
                'sub_questions': extract_func(output),
                'answer': ori[i].get('answer', '')
            }
            results.append(result)
        
        # 保存生成结果到jsonl文件
        with open(args.output, 'w', encoding='utf-8') as f:
            for result in results:
                f.write(json.dumps(result, ensure_ascii=False) + '\n')
        print(f"MARCO模式生成完成，结果已保存到 {args.output}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', type=str, required=True, help='待评测数据集（jsonl）路径')
    parser.add_argument('--output', type=str, required=True, help='输出文件名')
    parser.add_argument('--model_path', type=str, default='/mnt/new_pfs/liming_team/auroraX/LLM/Qwen3-4B', help='模型路径')
    parser.add_argument('--mode', type=str, choices=['EVAL', 'MARCO'], default='EVAL', help='评测模式: EVAL(等价性判定) 或 MARCO(数学问题分析)')
    parser.add_argument('--k', type=int, default=32, help='计算平均准确率时使用的k值')
    args = parser.parse_args()
    main(args) 

# 使用示例:
# EVAL模式（等价性判定）- 输出准确率结果:
# python evaluate_2_equiv.py \
#   --input /mnt/new_pfs/liming_team/auroraX/mxd/a_x1/new_0513/data/v1_50_32_xg/post_res.jsonl \
#   --output /mnt/new_pfs/liming_team/auroraX/mxd/a_x1/new_0513/data/v1_50_32_xg/equiv_acc.txt \
#   --model_path /mnt/new_pfs/liming_team/auroraX/LLM/Qwen3-4B \
#   --mode EVAL

# MARCO模式（数学问题分析）- 输出生成结果的jsonl文件:
# python evaluate_2_equiv.py \
#   --input /path/to/marco_data.jsonl \
#   --output /path/to/marco_results.jsonl \
#   --model_path /mnt/new_pfs/liming_team/auroraX/LLM/Qwen3-4B \
#   --mode MARCO

# 输出格式说明:
# EVAL模式: 输出文本文件，每行一个准确率数值
# MARCO模式: 输出jsonl文件，每行包含 {"index": 序号, "question": "原始问题", "generated_response": "生成的分析"}