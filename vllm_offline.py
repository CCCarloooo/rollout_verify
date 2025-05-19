from vllm import LLM, SamplingParams
from vllm.sampling_params import GuidedDecodingParams
from pydantic import BaseModel
import argparse
import json
import os

from vllm import LLM, SamplingParams
from vllm.sampling_params import GuidedDecodingParams

# 定义枚举类型和Pydantic模型
class SolveDict(BaseModel):
    analysis: str
    final_answer: str

def main(data_path, output_path, model):
    # 从Pydantic模型获取JSON模式
    json_schema = SolveDict.model_json_schema()
    # 配置引导解码参数
    guided_decoding_params = GuidedDecodingParams(json=json_schema)
    sample_params = {
        "temperature": 1,
        "top_p": 0.97,
        "max_tokens": 2048,
    }
    sampling_params = SamplingParams(guided_decoding=guided_decoding_params, **sample_params)

    with open(data_path, 'r') as f:
        messages = [json.loads(line) for line in f]

    llm = LLM(model=model, 
            max_model_len=2048, 
            max_num_seqs=1,
            tensor_parallel_size=1,
            # guided_decoding_backend="outlines",
            gpu_memory_utilization=0.95)  # 根据需要设置模型

    outputs = llm.chat(messages,
                    sampling_params)

    with open(output_path, 'w') as f:
        for output in outputs:
            cur = output.outputs[0].text
            if '\n' in cur:
                cur = cur.replace('\n', '')
            f.write(cur + "\n")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('--data_path', type=str, default='', help='输入数据')
    parser.add_argument('--output_path', type=str, default='', help='输出数据')
    parser.add_argument('--model', type=str, default='', help='模型')
    args = parser.parse_args()
    main(args.data_path, args.output_path, args.model)
