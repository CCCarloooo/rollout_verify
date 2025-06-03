import json
import asyncio
import aiohttp
from typing import Dict, List, Any, Optional
import traceback
from aiohttp import ClientTimeout
import time
from tqdm import tqdm
import argparse

# 异步调用API接口，发送结构化JSON请求
async def call_api_json_async(url: str, model_name: str, system_prompt: str, user_prompt: str, schema: str, session: aiohttp.ClientSession) -> Dict[str, Any]:
    """
    Args:
        url: API端点URL
        model_name: 模型名称
        system_prompt: 系统提示词
        user_prompt: 用户提示词
        schema: JSON schema格式的输出结构定义
        session: aiohttp会话对象
        
    Returns:
        API的JSON响应或错误信息
    """
    headers = {
        "Content-Type": "application/json"
    }
    
    data = {
        "model": model_name,
        "messages": [
            {
                "role": "system",
                "content": system_prompt
            },
            {
                "role": "user",
                "content": user_prompt
            }
        ],
        'response_format': {
            "type": "json_schema",
            "json_schema": {
                "name": "test",
                # 将pydantic模型转换为json schema
                "schema": schema
            },
        },
        "temperature": 1,
        "top_p": 0.7,
        "max_tokens": 4096,
        "stream": False,
        "n": 1
    }

    if not schema:
        del data['response_format']
   
    async with session.post(url, headers=headers, json=data) as response:
        if response.status == 200:
            try:
                json_data = await response.json()  # 尝试获取.json(), 否则手动解析接口返回结果
                return json_data
            except aiohttp.ContentTypeError:
                text = await response.text()  # 处理内容类型错误，尝试手动解析
                try:
                    json_data = json.loads(text)
                    return json_data
                except json.JSONDecodeError as e:
                    return f"请求结果JSON解析错误: {e}, 响应内容: {text}"
        else:
            text = await response.text()
            return f"请求结果错误: {response.status}, 响应内容: {text}"

# 异步批处理请求，单条请求返回结果后处理，超时设置
async def process_async_batch(input_list: List[Dict[str, Any]], concurrency: int, url: str, model_name: str) -> List[Dict[str, Any]]:
    """
    Args:
        input_list: 输入数据列表
        concurrency: 并发限制
        url: API端点URL
        model_name: 模型名称
        
    Returns:
        处理结果列表
    """
        
    results = []
    semaphore = asyncio.Semaphore(concurrency)  # 使用信号量限制并发数
    
    # 单条请求调用+后处理
    async def process_single_item(row: Dict[str, Any], session: aiohttp.ClientSession) -> Dict[str, Any]:
        """处理单个项目"""
        user_prompt = row['user_prompt']
        system_prompt = row.get('system_prompt', '')
        schema = row.get('schema', '')
        
        async with semaphore:
            try:
                result = await call_api_json_async(
                    url=url,
                    model_name=model_name,
                    system_prompt=system_prompt,
                    user_prompt=user_prompt,
                    schema=schema,
                    session=session
                )
                try:
                    return {
                        'content': result['choices'][0]['message']['content'],
                        'error_str': ''
                    }
                except Exception as e:
                    return {
                        'content': '',
                        'error_str': f'{e}**\n{traceback.format_exc()}**\n{str(result)}'
                    }

            except Exception as e:
                return {
                    'content': '',
                    'error_str': f'{e}**\n{traceback.format_exc()}'
                }
    
    # 创建自定义超时设置
    timeout = ClientTimeout(
        total=10*60,  # 总超时时间（秒）
        connect=10*60,  # 连接超时（秒）
        sock_connect=10*60,  # 套接字连接超时（秒）
        sock_read=10*60  # 套接字读取超时（秒）
    )
    async with aiohttp.ClientSession(timeout=timeout) as session:
        # 创建所有任务
        tasks = [process_single_item(item, session) for item in input_list]
        # 等待所有任务完成
        results = await asyncio.gather(*tasks)
        
    return results

# 异步主函数，控制并发数量
async def async_main(data_list: List[Dict[str, Any]], url: str, model_name: str, concurrency: int):

    messages = [{'user_prompt': item['user_prompt'], 'schema': item.get('schema', ''), 'system_prompt': item.get('system_prompt', '')} for item in data_list]  # get ori question
    
    # print(f'--------------------------------   one sample  --------------------------------')
    # print(json.dumps(messages[0], indent=4, ensure_ascii=False))

    # 使用异步处理批量请求
    results = await process_async_batch(
        input_list=messages,
        concurrency=concurrency,
        url=url,
        model_name=model_name
    )

    # print(f'--------------------------------   one sample output  --------------------------------')
    # print(json.dumps(results[0], indent=4, ensure_ascii=False))

    # 保存结果
    for item, result in zip(data_list, results):
        item['llm_output'] = result['content']
        item['error_info'] = result['error_str']
    
    return data_list


"""
interface function

Args:
    data_list: 输入数据列表
        [{
            'user_prompt': '你是谁，多大了？',
            'system_prompt': '',  # 可选
            'schema': SolveDict.model_json_schema()  # 可选
        }]
    url: API端点URL
    model_name: 模型名称，默认''
"""
def get_llm_outputs(data_list: List[Dict[str, Any]], url: str='http://10.202.2.46:7373/v1/chat/completions', model_name: str='', concurrency: int = 500):
    return asyncio.run(async_main(data_list, url, model_name, concurrency))

if __name__ == "__main__":
    from async_client_sglang import get_llm_outputs
    import json

    parser = argparse.ArgumentParser()
    parser.add_argument('--input_file', type=str, default='/mnt/new_pfs/liming_team/auroraX/mxd/a_x1/data/Test/comp-math-24-25-rollout.jsonl')
    parser.add_argument('--output_dir', type=str, default='/mnt/new_pfs/liming_team/auroraX/mxd/a_x1/TestRes/Merge14BBase0528')
    parser.add_argument('--batch_size', type=int, default=8)
    parser.add_argument('--llm_url', type=str, default='http://10.204.23.16:7373/v1/chat/completions')
    args = parser.parse_args()
    
    INPUT_FILE = args.input_file
    LLM_URL = args.llm_url
    OUTPUT_DIR = args.output_dir

    with open(INPUT_FILE, 'r') as f:
        data_list = [json.loads(line) for line in f]

    
    batch_size = args.batch_size
    total_items = len(data_list)
    
    # 按照最大500条进行分批
    max_batch_size = 500
    
    # 计算每批的数量
    batches = []
    for i in range(batch_size):
        start = i * max_batch_size
        end = min((i + 1) * max_batch_size, total_items)
        
        # 如果start已经超过总数据量，则为空批次
        if start >= total_items:
            batches.append((0, 0))
        else:
            batches.append((start, end))
    
    # 输出批次分配信息
    non_empty_batches = [(i, start, end) for i, (start, end) in enumerate(batches) if start != end]
    empty_batches = [i for i, (start, end) in enumerate(batches) if start == end]
    
    print(f"总数据量：{total_items}条，最大批次大小：{max_batch_size}条")
    print(f"分配到{len(non_empty_batches)}个非空批次，{len(empty_batches)}个空批次")
    for i, start, end in non_empty_batches:
        print(f"  批次{i+1}: {start}-{end} ({end-start}条)")
    if empty_batches:
        print(f"  空批次: {[i+1 for i in empty_batches]}")
    
    for i, (start, end) in enumerate(batches):
        if start == end:
            # 处理空批次
            print(f"第{i+1}批为空批次，跳过处理...")
            output_file = f'{OUTPUT_DIR}/batch_{i}.jsonl'
            # 创建空文件
            with open(output_file, 'w') as f:
                pass  # 创建空文件
            continue
            
        # 执行多进程处理
        print(f"开始多进程处理第{i+1}批数据...({start}到{end}，共{end-start}条)")
        start_time = time.time()
        cur_batch = data_list[start:end]
        tmp_res = get_llm_outputs(cur_batch, url=LLM_URL)
        end_time = time.time()
        print(f"多进程处理完成，耗时：{end_time - start_time:.2f}秒")
        
        print("保存结果...")
        output_file = f'{OUTPUT_DIR}/batch_{i}.jsonl'
        with open(output_file, 'w') as f:
            for item in tqdm(tmp_res, desc="保存进度", ncols=100):
                f.write(json.dumps(item, ensure_ascii=False) + '\n')
