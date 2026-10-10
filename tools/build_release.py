"""Sync release.json, verify the pinned Godot, test, and export local platform builds.

Uses matching templates installed through Godot's Export Template Manager.
No signing credentials or publishing services are used by this baseline builder.
"""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
TARGETS = {
    'macos': ('macOS', 'Nugget Cat.zip'),
    'windows': ('Windows', 'Nugget Cat.exe'),
    'web': ('Web', 'index.html'),
}


def sync_versions(check=False):
    release = json.loads((ROOT / 'release.json').read_text())
    version, engine = release['version'], release['godot']
    for value in (version, engine):
        if not re.fullmatch(r'\d+\.\d+\.\d+', value):
            raise ValueError('release.json versions must use major.minor.patch')
    replacements = {
        'README.md': [(r'^# Nugget Cat · .+$', f'# Nugget Cat · {version}')],
        'project.godot': [(r'^config/version="[^"]*"$', f'config/version="{version}"')],
        'export_presets.cfg': [
            (rf'^{key}="[^"]*"$', f'{key}="{value}"')
            for key, value in (
                ('application/short_version', version), ('application/version', version),
                ('application/file_version', version + '.0'),
                ('application/product_version', version + '.0'),
            )
        ],
    }
    for name, rules in replacements.items():
        path = ROOT / name
        original = updated = path.read_text()
        for pattern, replacement in rules:
            updated, count = re.subn(pattern, replacement, updated, flags=re.MULTILINE)
            if count != 1:
                raise ValueError(f'{name}: expected exactly one {pattern}')
        if updated != original:
            if check:
                raise ValueError(f'{name} is out of sync; run tools/build_release.py --sync-only')
            path.write_text(updated)
            print(f'Synced {name}', flush=True)
    return release


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=os.environ.get('GODOT', '/Applications/Godot.app/Contents/MacOS/Godot'))
    parser.add_argument('--targets', nargs='+', choices=TARGETS, default=list(TARGETS))
    parser.add_argument('--sync-only', action='store_true')
    parser.add_argument('--check-version', action='store_true')
    args = parser.parse_args()
    release = sync_versions(check=args.check_version)
    if args.sync_only or args.check_version:
        print(f'Release metadata aligned: {release["version"]}; Godot {release["godot"]}')
        return
    actual = subprocess.check_output([args.godot, '--version'], cwd=ROOT, text=True).strip()
    if not actual.startswith(release['godot'] + '.stable.'):
        raise ValueError(f'Expected Godot {release["godot"]}.stable; found {actual}')
    build = ROOT / 'build'
    logs = build / 'logs'
    logs.mkdir(parents=True, exist_ok=True)
    (build / '.gdignore').touch()

    def run(label, command, timeout=180):
        log = logs / (label + '.log')
        print(f'{label}...', flush=True)
        with log.open('w') as output:
            result = subprocess.run(command, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, timeout=timeout)
        text = log.read_text()
        # Godot can report script/assertion/export errors despite a zero exit code.
        if result.returncode or 'SCRIPT ERROR:' in text or 'ERROR:' in text:
            # A local editor preference does not affect imports or exports.
            errors = [line for line in text.splitlines() if 'ERROR:' in line
                      and "Couldn't open external text editor" not in line]
            if result.returncode or errors:
                raise RuntimeError(f'{label} failed; see {log.relative_to(ROOT)}\n{text[-6000:]}')
        print(f'  passed ({log.relative_to(ROOT)})', flush=True)

    base = [args.godot, '--headless', '--path', '.']
    run('import', base + ['--editor', '--import', '--quit'])
    run('smoke', base + ['--', '--smoke-test'])
    run('nuggets', base + ['--script', 'tools/test_nuggets.gd'])
    run('audio', [sys.executable, 'tools/check_audio.py'])
    for target in dict.fromkeys(args.targets):
        preset, filename = TARGETS[target]
        folder = build / target
        folder.mkdir(exist_ok=True)
        artifact = folder / filename
        run('export-' + target, base + ['--export-release', preset, str(artifact)], timeout=300)
        if not artifact.is_file():
            raise RuntimeError(f'Missing exported artifact: {artifact}')
        if target == 'macos' and sys.platform == 'darwin':
            run('unpack-macos', ['ditto', '-x', '-k', str(artifact), str(folder)])
            run('verify-macos', ['codesign', '--verify', '--deep', '--strict', str(folder / 'Nugget Cat.app')])
        if target == 'windows':
            with zipfile.ZipFile(folder / 'Nugget Cat-windows.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
                archive.write(artifact, artifact.name)
        print(f'Built {release["version"]}: {artifact.relative_to(ROOT)}', flush=True)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        sys.exit(str(error))
