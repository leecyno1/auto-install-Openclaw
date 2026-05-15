#!/usr/bin/env python3
import argparse
import json
import pathlib
import re
from typing import Dict, Iterable, List, Tuple


TEXT_SLOTS = ("minimax", "deepseek", "glm", "gpt")
MEDIA_SLOTS = ("image", "video")
ALL_SLOTS = TEXT_SLOTS + MEDIA_SLOTS


def load_json(path: pathlib.Path) -> dict:
    try:
        return json.loads(path.read_text())
    except Exception:
        return {}


def save_json(path: pathlib.Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def parse_spec(raw: str) -> dict:
    result = {}
    for part in raw.split(','):
        part = part.strip()
        if not part or '=' not in part:
            continue
        key, value = part.split('=', 1)
        result[key.strip().lower().replace('-', '_')] = value.strip()
    return result


def safe_id(value: str) -> str:
    value = value.strip()
    return re.sub(r'[^A-Za-z0-9_.-]+', '-', value).strip('-')


def split_modes(raw: str) -> List[str]:
    modes = [item.strip() for item in re.split(r'[,+]', raw or '') if item.strip()]
    return modes or ["text"]


def bool_value(raw: str) -> bool:
    return str(raw).lower() in ("1", "true", "yes", "y", "on")


def infer_slot(item: dict, provider_id: str, model: str) -> str:
    explicit = (item.get('slot') or item.get('family') or '').lower().strip()
    if explicit in ALL_SLOTS:
        return explicit

    media = (item.get('media') or item.get('capability') or item.get('type') or '').lower()
    if media in MEDIA_SLOTS:
        return media

    haystack = ' '.join([
        provider_id,
        item.get('provider', ''),
        item.get('name', ''),
        model,
        item.get('image_model', ''),
    ]).lower()
    if 'minimax' in haystack:
        return 'minimax'
    if 'deepseek' in haystack:
        return 'deepseek'
    if 'glm' in haystack or 'zai' in haystack or 'zhipu' in haystack:
        return 'glm'
    if 'gpt' in haystack or 'openai' in haystack:
        return 'gpt'
    if 'video' in haystack or item.get('video_endpoint') or item.get('video_model'):
        return 'video'
    if 'image' in haystack or item.get('image_endpoint') or item.get('image_generation'):
        return 'image'
    return provider_id or 'custom'


def normalize_spec(raw: str) -> dict:
    item = parse_spec(raw)
    provider_id = safe_id(item.get('id') or item.get('provider_id') or item.get('provider') or '')
    model = item.get('model') or item.get('model_id') or ''
    base_url = item.get('base_url') or item.get('url') or ''
    api_key = item.get('api_key') or item.get('key') or ''
    if not provider_id or not model or not base_url or not api_key:
        raise SystemExit(f"invalid model spec, required id/base_url/api_key/model: {raw}")

    item['provider_id'] = provider_id
    item['model'] = model
    item['base_url'] = base_url
    item['api_key'] = api_key
    item['name'] = item.get('name') or item.get('display_name') or model
    item['api_type'] = item.get('api_type') or item.get('api') or 'openai-completions'
    item['slot'] = infer_slot(item, provider_id, model)
    return item


def choose_active_by_slot(items: Iterable[dict]) -> Tuple[Dict[str, dict], Dict[str, dict]]:
    active = {}
    archived = {}
    for item in items:
        slot = item['slot']
        previous = active.get(slot)
        if previous:
            archived[previous['provider_id']] = archive_entry(previous, 'replaced_by_later_spec')
        active[slot] = item
    return active, archived


def archive_entry(item: dict, reason: str) -> dict:
    return {
        'slot': item.get('slot', ''),
        'model': item.get('model', ''),
        'baseUrl': item.get('base_url', ''),
        'apiType': item.get('api_type', ''),
        'reason': reason,
    }


def model_entry(item: dict) -> dict:
    input_modes = split_modes(item.get('input') or 'text,image')
    return {
        'id': item['model'],
        'name': item['name'],
        'api': item['api_type'],
        'input': input_modes,
        'contextWindow': int(item.get('context_window') or item.get('context') or 200000),
        'maxTokens': int(item.get('max_tokens') or item.get('max_output_tokens') or 8192),
        'reasoning': bool_value(item.get('reasoning', 'false')),
        'cost': {'input': 0, 'output': 0, 'cacheRead': 0, 'cacheWrite': 0},
    }


def provider_entry(item: dict) -> dict:
    return {
        'baseUrl': item['base_url'],
        'apiKey': item['api_key'],
        'models': [model_entry(item)],
    }


def capability_entry(item: dict) -> dict:
    input_modes = split_modes(item.get('input') or 'text,image')
    capability = {
        'provider': item['provider_id'],
        'model': item['model'],
        'slot': item['slot'],
        'text': item['slot'] not in MEDIA_SLOTS,
        'visionInput': 'image' in input_modes,
    }
    image_tool = item.get('image_tool') or item.get('image_generation') or ''
    if image_tool:
        capability['mediaTool'] = True
        capability['imageGeneration'] = {
            'type': image_tool,
            'endpoint': item.get('image_endpoint') or '/v1/responses',
            'tool': item.get('image_tool_type') or 'image_generation',
            'model': item.get('image_model') or 'gpt-image-2',
            'testedWith': item.get('tested_with') or 'responses image_generation tool',
            'fallbacks': {
                'available': [item.get('image_endpoint') or '/v1/responses'],
                'unavailable': ['/v1/images/generations'],
            },
            'notes': item.get('image_notes') or 'Use Responses API with tools:[{"type":"image_generation"}]. Direct /v1/images/generations may be unavailable on this gateway.',
        }
    if item['slot'] == 'image':
        capability['text'] = False
        capability['imageGeneration'] = capability.get('imageGeneration') or {
            'type': item.get('image_tool') or 'provider-image-api',
            'endpoint': item.get('image_endpoint') or item.get('endpoint') or '/v1/images/generations',
            'model': item.get('image_model') or item['model'],
            'fallbacks': {'available': [], 'unavailable': []},
        }
    if item['slot'] == 'video':
        capability['text'] = False
        capability['videoGeneration'] = {
            'endpoint': item.get('video_endpoint') or item.get('endpoint') or '/v1/video_generation',
            'model': item.get('video_model') or item['model'],
        }
    return capability


def apply_registry(specs: str, openclaw_path: pathlib.Path, agent_path: pathlib.Path, capabilities_path: pathlib.Path) -> List[str]:
    raw_specs = [raw for raw in specs.split('|||') if raw.strip()]
    items = [normalize_spec(raw) for raw in raw_specs]
    active, archived = choose_active_by_slot(items)

    openclaw_cfg = load_json(openclaw_path)
    agent_cfg = load_json(agent_path)
    capabilities = load_json(capabilities_path)
    providers = openclaw_cfg.setdefault('models', {}).setdefault('providers', {})
    agent_providers = agent_cfg.setdefault('providers', {})
    model_aliases = openclaw_cfg.setdefault('agents', {}).setdefault('defaults', {}).setdefault('models', {})

    existing_registry = capabilities.get('registry', {}).get('slots', {})
    for slot, slot_entry in existing_registry.items():
        provider_id = slot_entry.get('provider')
        if provider_id and slot in active and provider_id != active[slot]['provider_id']:
            archived.setdefault(provider_id, {
                'slot': slot,
                'model': slot_entry.get('model', ''),
                'reason': 'replaced_existing_slot_provider',
            })

    active_provider_ids = {item['provider_id'] for item in active.values()}
    for provider_id in list(providers.keys()):
        if provider_id not in active_provider_ids:
            slot = existing_registry.get(provider_id, {}).get('slot') if isinstance(existing_registry.get(provider_id), dict) else ''
            if any(provider_id == entry.get('provider') for entry in existing_registry.values()):
                providers.pop(provider_id, None)
                agent_providers.pop(provider_id, None)

    capabilities.setdefault('models', {})
    capabilities.setdefault('providers', {})
    capabilities.setdefault('archivedProviders', {}).update(archived)
    capabilities['registry'] = {
        'version': 1,
        'dedupe': 'family-slot-unique',
        'slots': {},
    }
    capabilities['router'] = {
        'backend': 'embedded',
        'strategy': 'rules',
        'routes': {
            'primary': {'slot': next((slot for slot in TEXT_SLOTS if slot in active), ''), 'use': 'main tasks'},
            'summary': {'slot': 'minimax' if 'minimax' in active else next((slot for slot in TEXT_SLOTS if slot in active), ''), 'use': 'summary/classification/rewrite'},
            'codingReview': {'slot': 'gpt' if 'gpt' in active else next((slot for slot in TEXT_SLOTS if slot in active), ''), 'use': 'code review and complex reasoning'},
            'image': {'slot': 'image' if 'image' in active else ('gpt' if any(item.get('image_tool') for item in active.values()) else ''), 'use': 'image generation'},
            'video': {'slot': 'video' if 'video' in active else '', 'use': 'video generation'},
        },
        'backends': ['embedded', 'litellm', 'bifrost', 'portkey'],
    }

    applied = []
    for slot, item in active.items():
        provider_id = item['provider_id']
        entry = provider_entry(item)
        providers[provider_id] = entry
        agent_providers[provider_id] = entry
        ref = f"{provider_id}/{item['model']}"
        model_aliases[ref] = {'alias': item['name'], 'slot': slot}
        capabilities['providers'][provider_id] = {
            'baseUrl': item['base_url'],
            'models': [item['model']],
            'apiType': item['api_type'],
            'slot': slot,
        }
        capabilities['models'][ref] = capability_entry(item)
        capabilities['registry']['slots'][slot] = {
            'provider': provider_id,
            'model': item['model'],
            'ref': ref,
            'apiType': item['api_type'],
        }
        applied.append(ref)

    openclaw_cfg.setdefault('models', {})['registry'] = capabilities['registry']
    openclaw_cfg['models']['router'] = capabilities['router']
    agent_cfg['registry'] = capabilities['registry']
    agent_cfg['router'] = capabilities['router']

    save_json(openclaw_path, openclaw_cfg)
    save_json(agent_path, agent_cfg)
    save_json(capabilities_path, capabilities)
    return applied


def main() -> None:
    parser = argparse.ArgumentParser(description='Apply OpenClaw model registry specs')
    parser.add_argument('--specs', required=True)
    parser.add_argument('--openclaw-json', required=True, type=pathlib.Path)
    parser.add_argument('--agent-models-json', required=True, type=pathlib.Path)
    parser.add_argument('--capabilities-json', required=True, type=pathlib.Path)
    args = parser.parse_args()
    print('\n'.join(apply_registry(args.specs, args.openclaw_json, args.agent_models_json, args.capabilities_json)))


if __name__ == '__main__':
    main()
