import argparse
import json
import io_tools


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('--input_file', type=str, default='/mnt/new_pfs/liming_team/auroraX/mxd/a_x1/TestRes/Marco/Rollout/Rollout0529/Rollout0529.jsonl')
    args = parser.parse_args()
    
    input_file = args.input_file

    ori = io_tools.read_jsonl(input_file)
    for item in ori:
        try:
            tmp = json.loads(item['llm_output'])
        except:
            tmp = {
                'final_answer': 'json error'
            }
        item['llm_output_processed'] = tmp
    
    new = [{
        'question': item['question'],
        'answer': item['answer'],
        'final_answer': item['llm_output_processed']['final_answer']
    } for item in ori]
    
    io_tools.write_jsonl(input_file.replace('.jsonl', '_processed.jsonl'), new)




