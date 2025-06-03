import io_tools
import argparse
from pydantic import BaseModel

# 设置命令行参数
def parse_args():
    parser = argparse.ArgumentParser(description='处理数学竞赛题目数据集')
    parser.add_argument('--input_path', '-i', 
                       default='/mnt/new_pfs/liming_team/auroraX/mxd/a_x1/data/Test/comp-math-24-25.txt',
                       help='输入文件路径 (默认: comp-math-24-25.txt)')
    parser.add_argument('--output_path', '-o',
                       default='/mnt/new_pfs/liming_team/auroraX/mxd/a_x1/data/Test/comp-math-24-25-rollout.jsonl',
                       help='输出文件路径 (默认: comp-math-24-25-rollout.jsonl)')
    parser.add_argument('--mode', '-m',
                       choices=['base', 'plan'],
                       default='base',
                       help='处理模式: base 或 plan (默认: base)')
    parser.add_argument('--expand_count', '-e',
                       type=int,
                       default=32,
                       help='每个题目的扩展数量 (默认: 32)')
    return parser.parse_args()

# 常量定义
SAMPLE_SOLVE_PROMPT_EN_JSON = """# Task Introduction
Please reason through the problem step by step, and put your final answer within \\boxed{{}}

For your answer:
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

VERIFY_PROMPT = """# Task Introduction
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

class SolveDict(BaseModel):
    analysis: str
    final_answer: str

def GenSimplePrompt(item):
    return SAMPLE_SOLVE_PROMPT_EN_JSON.replace('<problem>', item['question'])

def GenVerifyPrompt(item):
    if type(item['sub_questions']) == str:
        sub_questions = item['sub_questions']
    else:
        sub_questions = '\n'.join(item['sub_questions'])
    return VERIFY_PROMPT.format(problem=item['question'], sub_questions=sub_questions)

def get_config(mode):
    """根据模式返回相应的配置"""
    if mode == 'base':
        return {
            'prompt': SAMPLE_SOLVE_PROMPT_EN_JSON,
            'method': GenSimplePrompt
        }
    else:
        return {
            'prompt': VERIFY_PROMPT,
            'method': GenVerifyPrompt
        }

def generate_and_process_data(data, config):
    """使用生成器处理大数据集"""
    for item in data:
        processed_item = item
        processed_item['user_prompt'] = config['method'](processed_item)
        processed_item['schema'] = SolveDict.model_json_schema()
        yield processed_item

def main():
    """主函数"""
    # 获取命令行参数
    args = parse_args()
    INPUT_PATH = args.input_path
    OUTPUT_PATH = args.output_path
    MODE = args.mode
    EXPAND_COUNT = args.expand_count
    
    # 读取原始数据
    ori = io_tools.read_jsonl(INPUT_PATH)
    
    # 获取配置
    config = get_config(MODE)
    
    # 处理数据
    processed = generate_and_process_data(ori, config)
    expended = [item for item in processed for _ in range(EXPAND_COUNT)]
    
    # 保存结果
    io_tools.write_jsonl(OUTPUT_PATH, expended)
    
    # 输出统计信息
    print(f'已保存到 {OUTPUT_PATH}')
    print(f'模式: {MODE}')
    print(f'每个题目扩展了 {EXPAND_COUNT} 次')
    print(f'总共处理了 {len(expended)} 个项目')

if __name__ == "__main__":
    main()