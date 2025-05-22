# 输入就是 单纯的problem
# 输出则是 prompt 并且是chat 版本的

import json
import argparse

verify_prompt = """# Task Introduction
Please solve the sub-problems step by step based on the provided sub-questions, and then solve the original problem.

# Output Format Requirements
Output a dictionary with two keys: analysis, final_answer
Please put your analysis of the problem under the analysis key.
Please put your final answer to the problem under the final_answer key.

# Input
Original problem: {problem}
Sub-questions: {sub_questions}

# Output
"""
SAMPLE_SOLVE_PROMPT_EN_JSON = """# Task Introduction
Please reason through the problem step by step, and place your final answer under the final_answer key.

# Output Format Requirements
Output a dictionary with two keys: analysis and final_answer.
Please provide your analysis of the problem under the analysis key.

For your final_answer:
1. Use strict mathematical notation in LaTeX format, enclosed within '$' symbols.
2. Avoid natural language within mathematical expressions.
3. ALWAYS use the most standard mathematical notation for your answer type:
   - For equations: $x = 5$
   - For ranges/bounds: Use interval notation like $[a,b]$, $(a,b)$, $[a,\\infty)$ INSTEAD OF inequality notation
   - For sets: $\\{x : P(x)\\}$ or $\\{1,2,3\\}$
   - For systems: Use multiple equations like $\\begin{cases} x + y = 1 \\\\ x - y = 3 \\end{cases}$
   - For vectors: $\\vec{v} = (1, 2, 3)$ or $\\begin{pmatrix} 1 \\\\ 2 \\\\ 3 \\end{pmatrix}$
   - For matrices: $\\begin{pmatrix} 1 & 2 \\\\ 3 & 4 \\end{pmatrix}$

IMPORTANT FOR CORRECT NOTATION AND FORMATTING:
- When expressing ranges (like "x is greater than or equal to 3/4"):
  * CORRECT: $[\\frac{3}{4},\\infty)$ (interval notation)
  * AVOID: $x \\geq \\frac{3}{4}$ (inequality notation)
- For proper JSON escaping in LaTeX:
  * Use double backslashes (\\\\) for all LaTeX commands
  * Example: Write $[\\\\frac{3}{4},\\\\infty)$ instead of $[\\frac{3}{4},\\infty)$

# Input
<problem>

# Output
"""
def main(data_path):
    data = [json.loads(line) for line in open(data_path, "r")]
    print(f"读取到{len(data)}条数据")

    if 'sub_questions' in data[0]:
        prompts = [verify_prompt.format(problem=item['question'], sub_questions=item['sub_questions']) for item in data]
    else:
        prompts = [SAMPLE_SOLVE_PROMPT_EN_JSON.replace('<problem>', item['question']) for item in data]
    print(f"生成{len(prompts)}条prompt")

    messages = [[
        {"role": "user", "content": prompt}]
        for prompt in prompts
    ]
    print(f"生成{len(messages)}条messages")
    
    with open(data_path.replace('.jsonl', '_chat.jsonl'), 'w') as f:
        for message in messages:
            f.write(json.dumps(message, ensure_ascii=False) + "\n")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('--data_path', type=str, default='', help='输入数据')
    args = parser.parse_args()
    main(args.data_path)
