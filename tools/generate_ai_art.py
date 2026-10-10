"""Generate one sprite or room-sheet candidate with OpenAI's Image API.

Uses OPENAI_API_KEY or the project's macOS Keychain entry. Saves the source image, prompt and
non-secret response metadata inside this project. No automatic paid retries.
"""
import argparse
import base64
import json
import getpass
import os
from pathlib import Path
import sys
import subprocess
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
KEYCHAIN_SERVICE = 'CatNuggetGame.OpenAI'


def read_api_key():
    key = os.environ.get('OPENAI_API_KEY', '').strip()
    if key:
        return key, 'OPENAI_API_KEY environment variable'
    if sys.platform == 'darwin':
        try:
            result = subprocess.run(
                ['security', 'find-generic-password', '-a', os.environ.get('USER', getpass.getuser()),
                 '-s', KEYCHAIN_SERVICE, '-w'],
                capture_output=True, text=True, timeout=30, check=False,
            )
            if result.returncode == 0 and result.stdout.strip():
                return result.stdout.strip(), 'macOS Keychain (' + KEYCHAIN_SERVICE + ')'
        except (OSError, subprocess.TimeoutExpired):
            pass
    return '', 'not configured'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--model', default='gpt-image-2.5-flare')
    parser.add_argument('--asset', choices=['hands', 'cat', 'cat_dance', 'nuggets', 'rooms', 'profile_banner', 'profile_banner_blend', 'profile_background', 'profile_stars'], default='hands')
    parser.add_argument('--name', default=None)
    parser.add_argument('--quality', choices=['low', 'medium', 'high'], default='medium')
    parser.add_argument('--room', choices=['kitchen', 'cafe', 'sunroom', 'study'], help='Generate one detailed room rather than a four-room sheet')
    parser.add_argument('--check-key', action='store_true', help='Check credential availability without displaying the key or making an API request')
    args = parser.parse_args()
    if args.room and args.asset != 'rooms':
        parser.error('--room requires --asset rooms')
    args.name = args.name or args.asset + '_v001'
    if Path(args.name).name != args.name or not args.name:
        parser.error('--name must be a plain filename stem')
    key, key_source = read_api_key()
    if args.check_key:
        print('Image API credentials: ' + key_source)
        sys.exit(0 if key else 1)
    if not key:
        sys.exit('Set OPENAI_API_KEY or save a macOS Keychain entry with service CatNuggetGame.OpenAI and your login account name. See README.md.')
    destination = ROOT / 'art_sources' / (args.name + '.png')
    if destination.exists():
        sys.exit(f'{destination.name} already exists; use a new --name to keep the original.')
    prompt = (ROOT / 'tools' / 'prompts' / (args.asset + '.txt')).read_text()
    if args.room:
        prompt = (ROOT / 'tools' / 'prompts' / 'rooms_hd.txt').read_text() + '\n\n' + (ROOT / 'tools' / 'prompts' / ('room_' + args.room + '.txt')).read_text()
    background = 'opaque' if args.asset in ('rooms', 'profile_banner', 'profile_background', 'profile_stars') else 'transparent'
    payload = dict(model=args.model, prompt=prompt, n=1, size='1536x1024',
                   quality=args.quality, background=background, output_format='png')
    request = urllib.request.Request(
        'https://api.openai.com/v1/images/generations',
        data=json.dumps(payload).encode(),
        headers={'Authorization': 'Bearer ' + key, 'Content-Type': 'application/json'},
        method='POST',
    )
    print(f'Requesting one {background} {args.asset} sheet with {args.model}...', flush=True)
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
