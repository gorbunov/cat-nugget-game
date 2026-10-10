"""Build/check Web, then prepare Workers static assets (invoked by Wrangler).

Godot's WASM exceeds Cloudflare's 25 MiB per-file limit uncompressed. Store its
gzip representation as index.wasm.gz; a small Worker returns these bytes at the
original URL with manual gzip encoding. The browser decodes it before Godot.
"""
import gzip
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'build/cloudflare'
ASSET_LIMIT = 25 * 1024 * 1024
REQUIRED = ('index.html', 'index.js', 'index.wasm', 'index.pck')


def prepare_assets(source, destination, limit=ASSET_LIMIT):
    for name in REQUIRED:
        if not (source / name).is_file():
            raise ValueError(f'Missing Web export: {source / name}')
    # Prepare separately so a failed packaging attempt cannot leave mixed files.
    staging = destination.with_name(destination.name + '-staging')
    if staging.exists():
        shutil.rmtree(staging)
    staging.mkdir(parents=True)
    headers = ['/*', '  Cache-Control: public, max-age=0, must-revalidate', '']
    try:
        for path in sorted(source.rglob('*')):
            if not path.is_file() or any(part.startswith('.') for part in path.relative_to(source).parts):
                continue
            relative = path.relative_to(source)
            target = staging / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            data = path.read_bytes()
            if path.suffix == '.wasm':
                data = gzip.compress(data, compresslevel=9, mtime=0)
                target = target.with_name(target.name + '.gz')
            if len(data) > limit:
                raise ValueError(f'{relative} is {len(data):,} bytes; Cloudflare limit is {limit:,}')
            target.write_bytes(data)
            print(f'Cloudflare asset: {target.relative_to(staging)} ({len(data):,} bytes)', flush=True)
        (staging / '_headers').write_text('\n'.join(headers))
        if destination.exists():
            shutil.rmtree(destination)
        staging.rename(destination)
    finally:
        if staging.exists():
            shutil.rmtree(staging)


def main():
    subprocess.run([
        sys.executable, str(ROOT / 'tools/build_release.py'),
        '--targets', 'web', '--output-dir', str(OUTPUT / 'build'),
    ], cwd=ROOT, check=True)
    prepare_assets(OUTPUT / 'build/web', OUTPUT / 'assets')
    print('Cloudflare assets ready: build/cloudflare/assets', flush=True)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        sys.exit(str(error))
