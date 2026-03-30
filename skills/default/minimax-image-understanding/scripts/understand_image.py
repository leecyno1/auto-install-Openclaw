#!/usr/bin/env python3
import json
import os
import subprocess
import sys


def load_api_key():
    cfg_path = os.path.expanduser('~/.openclaw/config/minimax.json')
    key = os.environ.get('MINIMAX_API_KEY')
    if key:
        return key
    try:
        with open(cfg_path, 'r') as f:
            cfg = json.load(f)
            return cfg.get('api_key')
    except (FileNotFoundError, json.JSONDecodeError):
        return None


def call_mcp(prompt: str, image_source: str) -> int:
    api_key = load_api_key()
    if not api_key:
        print('Error: API Key not found.', file=sys.stderr)
        return 1

    env = {
        'MINIMAX_API_KEY': api_key,
        'MINIMAX_API_HOST': os.environ.get('MINIMAX_API_HOST', 'https://api.minimaxi.com'),
        'MINIMAX_MCP_BASE_PATH': os.path.expanduser('~/.openclaw/workspace/minimax-output'),
        'MINIMAX_API_RESOURCE_MODE': os.environ.get('MINIMAX_API_RESOURCE_MODE', 'local'),
    }

    requests = [
        {
            'jsonrpc': '2.0',
            'id': 1,
            'method': 'initialize',
            'params': {
                'protocolVersion': '2024-11-05',
                'capabilities': {},
                'clientInfo': {'name': 'openclaw', 'version': '1.0'},
            },
        },
        {
            'jsonrpc': '2.0',
            'id': 2,
            'method': 'tools/call',
            'params': {
                'name': 'understand_image',
                'arguments': {
                    'prompt': prompt,
                    'image_source': image_source,
                },
            },
        },
    ]

    try:
        proc = subprocess.Popen(
            ['uvx', 'minimax-coding-plan-mcp'],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env={**os.environ, **env},
            text=True,
        )
        input_data = '\n'.join(json.dumps(r) for r in requests) + '\n'
        stdout, stderr = proc.communicate(input_data, timeout=120)
        if stderr:
            print(f'Stderr: {stderr}', file=sys.stderr)

        lines = [ln.strip() for ln in stdout.strip().split('\n') if ln.strip()]
        if not lines:
            print('Error: empty MCP response', file=sys.stderr)
            return 1

        response = json.loads(lines[-1])
        if 'error' in response:
            print(f"Error: {response['error']}", file=sys.stderr)
            return 1
        result = response.get('result')

        text_out = None
        if isinstance(result, dict):
            content = result.get('content')
            if isinstance(content, list) and content:
                first = content[0]
                if isinstance(first, dict):
                    text_out = first.get('text')
            if text_out is None and 'data' in result:
                text_out = json.dumps(result['data'], ensure_ascii=False, indent=2)

        if text_out is None:
            text_out = json.dumps(result, ensure_ascii=False, indent=2)

        print(text_out)
        return 0

    except subprocess.TimeoutExpired:
        proc.kill()
        print('Error: Request timed out', file=sys.stderr)
        return 1
    except Exception as exc:
        print(f'Error: {exc}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print('Usage: python3 understand_image.py <prompt> <image_source>', file=sys.stderr)
        raise SystemExit(1)
    raise SystemExit(call_mcp(sys.argv[1], sys.argv[2]))
