"""Generate one hand-sheet candidate with OpenAI's Image API.

Uses OPENAI_API_KEY from the environment. Saves the source image, prompt and
non-secret response metadata inside this project. No automatic paid retries.
"""
import argparse
import base64
import json
import os
from pathlib import Path
import sys
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--model', default='gpt-image-2.5-flare')
    parser.add_argument('--name', default='hands_v001')
    args = parser.parse_args()
    if Path(args.name).name != args.name or not args.name:
        parser.error('--name must be a plain filename stem')
    key = os.environ.get('OPENAI_API_KEY', '').strip()
    if not key:
        sys.exit('OPENAI_API_KEY is not configured in this process.')
    destination = ROOT / 'art_sources' / (args.name + '.png')
    if destination.exists():
        sys.exit(f'{destination.name} already exists; use a new --name to keep the original.')
    prompt = (ROOT / 'tools/prompts/hands.txt').read_text()
    payload = dict(model=args.model, prompt=prompt, n=1, size='1536x1024',
                   quality='medium', background='transparent', output_format='png')
    request = urllib.request.Request(
        'https://api.openai.com/v1/images/generations',
        data=json.dumps(payload).encode(),
        headers={'Authorization': 'Bearer ' + key, 'Content-Type': 'application/json'},
        method='POST',
    )
    print(f'Requesting one transparent hand sheet with {args.model}...', flush=True)
    try:
        with urllib.request.urlopen(request, timeout=240) as response:
            result = json.load(response)
            request_id = response.headers.get('x-request-id')
    except urllib.error.HTTPError as error:
        detail = error.read().decode(errors='replace').replace(key, '[REDACTED]')
        sys.exit(f'Image API returned HTTP {error.code}: {detail}')
    except (urllib.error.URLError, TimeoutError) as error:
        sys.exit(f'Request did not complete: {error}. No automatic retry was made.')
    image = base64.b64decode(result['data'][0]['b64_json'], validate=True)
    if not image.startswith(b'\x89PNG\r\n\x1a\n'):
        sys.exit('Response was not a PNG; no image saved.')
    destination.write_bytes(image)
    metadata = {'request': payload, 'request_id': request_id,
                'created': result.get('created'), 'usage': result.get('usage'),
                'revised_prompt': result['data'][0].get('revised_prompt')}
    destination.with_suffix('.json').write_text(json.dumps(metadata, indent=2) + '\n')
    print(f'Saved {destination.relative_to(ROOT)} ({len(image):,} bytes).')
    if result.get('usage'):
        print('Reported usage:', json.dumps(result['usage']))


if __name__ == '__main__':
    main()
