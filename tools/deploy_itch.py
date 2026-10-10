"""Build, test and upload selected platforms to itch.io using Butler.

Each invocation builds into a fresh retained directory under build/itch/.
--dry-run runs the full build and Butler's local payload check without uploading.
macOS builds are notarized with Apple even during --dry-run.
Authenticate once with `build/butler/butler login`, or set BUTLER_API_KEY in CI.
"""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys

from notarize_macos import digest, notarize

ROOT = Path(__file__).resolve().parents[1]
PAYLOADS = {
    'macos': 'macos/Nugget Cat.zip',
    'windows': 'windows/Nugget Cat-windows.zip',
    'web': 'web',
}


def load_config():
    config = json.loads((ROOT / 'itch.json').read_text())
    slug = r'[a-z0-9]+(?:-[a-z0-9]+)*'
    if not re.fullmatch(f'{slug}/{slug}', config['project']):
        raise ValueError('itch.json project must be account/game-slug')
    channels = config['channels']
    if set(channels) != set(PAYLOADS) or any(
            not re.fullmatch(slug, channel) for channel in channels.values()):
        raise ValueError('itch.json must define macos/windows/web channel names')
    if len(set(channels.values())) != len(channels):
        raise ValueError('Each platform needs a distinct itch.io channel')
    return config


def upload_commands(butler, config, folder, targets, version, dry_run=False):
    commands = []
    for target in targets:
        payload = folder / PAYLOADS[target]
        if target == 'web':
            for name in ('index.html', 'index.js', 'index.wasm', 'index.pck'):
                if not (payload / name).is_file():
                    raise ValueError(f'Missing web export: {payload / name}')
        elif not payload.is_file():
            raise ValueError(f'Missing desktop archive: {payload}')
        if target == 'macos':
            receipt = json.loads((folder / 'macos/notarization.json').read_text())
            if (receipt['status'] != 'Accepted' or not receipt['stapled']
                    or receipt['archive_sha256'] != digest(payload)):
                raise ValueError('Mac upload requires an accepted, stapled, unmodified notarized archive')
        command = [butler, 'push', str(payload),
                   f'{config["project"]}:{config["channels"][target]}',
                   '--userversion', version]
        if dry_run:
            command.append('--dry-run')
        commands.append(command)
    return commands


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--targets', nargs='+', choices=PAYLOADS)
    parser.add_argument('--resume', type=Path, help='Finish notarization/upload from a retained build directory')
    parser.add_argument('--butler', default=os.environ.get('BUTLER'))
    parser.add_argument('--godot', default=os.environ.get('GODOT', '/Applications/Godot.app/Contents/MacOS/Godot'))
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    config = load_config()
    butler = args.butler or shutil.which('butler') or str(ROOT / 'build/butler/butler')
    subprocess.run([butler, 'version'], cwd=ROOT, check=True)
    if args.resume:
        folder = args.resume.resolve()
        if not folder.is_relative_to(ROOT / 'build'):
            raise ValueError('--resume must refer to a directory inside build/')
        built = json.loads((folder / 'build.json').read_text())
        if built['checks_passed'] is not True:
            raise ValueError('Cannot resume a build whose tests/exports did not pass')
        version = built['version']
        targets = list(dict.fromkeys(args.targets or built['targets']))
        if not set(targets).issubset(built['targets']):
            raise ValueError('Selected targets were not exported in this build')
    else:
        version = json.loads((ROOT / 'release.json').read_text())['version']
        targets = list(dict.fromkeys(args.targets or PAYLOADS))
        stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
        folder = ROOT / 'build' / 'itch' / f'{version}-{stamp}'
    if not re.fullmatch(r'\d+\.\d+\.\d+', version):
        raise ValueError('release.json version must use major.minor.patch')
    build_command = [sys.executable, str(ROOT / 'tools/build_release.py'),
                    '--godot', args.godot, '--output-dir', str(folder),
                    '--targets', *targets]
    if 'macos' in targets:
        build_command.append('--notarize')
    if args.resume:
        if 'macos' in targets:
            notarize(folder, resume=True)
    else:
        subprocess.run(build_command, cwd=ROOT, check=True)
    # Validate ALL payloads before the first remote mutation.
    commands = upload_commands(butler, config, folder, targets, version, args.dry_run)
    receipt = {'project': config['project'], 'version': version,
               'dry_run': args.dry_run, 'targets': targets, 'completed': []}
    receipt_path = folder / 'deployment.json'
    receipt_path.write_text(json.dumps(receipt, indent=2) + '\n')
    for target, command in zip(targets, commands):
        print(shlex.join(command), flush=True)
        # Stream Butler output directly; never include credentials in arguments/logs.
        subprocess.run(command, cwd=ROOT, check=True)
        receipt['completed'].append(target)
        receipt_path.write_text(json.dumps(receipt, indent=2) + '\n')
    print(f'{"Payload checks passed" if args.dry_run else "Uploaded"}: {config["project"]} {version}')
    print(f'Artifacts, build logs and deployment receipt: {folder.relative_to(ROOT)}')
    if not args.dry_run:
        subprocess.run([butler, 'status', config['project']], cwd=ROOT, check=True)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError, RuntimeError, subprocess.SubprocessError) as error:
        sys.exit(str(error))
