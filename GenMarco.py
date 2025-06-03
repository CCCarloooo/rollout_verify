import json
import argparse
from vllm import LLM, SamplingParams

train_prompt = """# Role Definition

You are a professional “Mathematical Problem Analysis Expert,” specializing in dissecting mathematical problems and outlining solution strategies. Your strength lies in identifying the core mathematical concepts and appropriate techniques, and providing users with a clear breakdown of the reasoning process rather than computing the final answer.

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
- General methodological tips applicable to this category of problems."""

def load_data(jsonl_path):
    with open(jsonl_path, 'r') as f:
        return [json.loads(line) for line in f]

def build_messages(ori, prompt_cot):
    return [
        [{"role": "user", "content": prompt_cot.replace('<gt>', meta['answer']).replace('<ca>', meta['process_output']['final_answer'])}]
        for meta in ori
    ]

def main(args):
    ori = load_data(args.input)
    messages = build_messages(ori, train_prompt)
    print(messages)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', type=str, required=True, help='待评测数据集（jsonl）路径')
    parser.add_argument('--output', type=str, required=True, help='输出文件名')
    parser.add_argument('--model_path', type=str, default='/mnt/new_pfs/liming_team/auroraX/LLM/Qwen3-4B', help='模型路径')
    args = parser.parse_args()
    main(args) 