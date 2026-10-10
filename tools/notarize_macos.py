"""Sign, notarize, staple and repackage an exported macOS app inside build/.

Pass the build output directory (containing macos/ and logs/).
Use --resume to finish an existing submission without signing/submitting again.
Credentials are read by notarytool from Keychain, never from this repository.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def digest(path):
    hasher = hashlib.sha256()
    with path.open('rb') as source:
        for block in iter(lambda: source.read(1024 * 1024), b''):
            hasher.update(block)
    return hasher.hexdigest()


def notarize(folder, resume=False):
    folder = folder.resolve()
    if sys.platform != 'darwin' or not folder.is_relative_to(ROOT / 'build'):
        raise ValueError('Notarization requires macOS and an output directory inside build/')
    app = folder / 'macos/Nugget Cat.app'
    archive = folder / 'macos/Nugget Cat.zip'
    logs = folder / 'logs'
    logs.mkdir(parents=True, exist_ok=True)
    receipt_path = folder / 'macos/notarization.json'
    config = json.loads((ROOT / 'release.json').read_text())['macos']
    identity = os.environ.get('MACOS_SIGNING_IDENTITY') or str(config['signing_identity'])
    profile = os.environ.get('NOTARY_KEYCHAIN_PROFILE') or str(config['notary_profile'])

    def run(label, command, timeout=180):
        print(f'{label}...', flush=True)
        log = logs / (label + '.log')
        with log.open('w') as output:
            result = subprocess.run(command, cwd=ROOT, stdout=output,
                                    stderr=subprocess.STDOUT, timeout=timeout)
        if result.returncode:
            raise RuntimeError(f'{label} failed; see {log.relative_to(ROOT)}\n{log.read_text()[-6000:]}')
        return log.read_text()

    def save_receipt():
        receipt_path.write_text(json.dumps(receipt, indent=2) + '\n')

    def package(label):
        # Never update an existing ZIP in place: it may retain old ticket entries.
        temporary = archive.with_name('Nugget Cat-packaging.zip')
        temporary.unlink(missing_ok=True)
        run(label, ['ditto', '-c', '-k', '--sequesterRsrc', '--keepParent',
                    str(app), str(temporary)])
        temporary.replace(archive)

    if resume:
        receipt = json.loads(receipt_path.read_text())
        if digest(archive) != receipt['archive_sha256']:
            raise ValueError('Archive changed since submission; rebuild and submit a fresh release')
        profile = receipt['notary_profile']
    else:
        if receipt_path.exists():
            raise ValueError('Submission receipt already exists; use --resume or a fresh build directory')
        if not identity.startswith('Developer ID Application:'):
            raise ValueError('Public releases require a Developer ID Application identity')
        run('sign-macos', ['codesign', '--force', '--sign', identity, '--timestamp',
                          '--options', 'runtime', '--entitlements',
                          str(ROOT / 'tools/macos_entitlements.plist'), str(app)])
        run('verify-developer-id', ['codesign', '--verify', '--deep', '--strict', str(app)])
        run('signing-details', ['codesign', '--display', '--verbose=4', str(app)])
        package('package-notary-submission')
        result = json.loads(run('notary-submit', [
            'xcrun', 'notarytool', 'submit', str(archive),
            '--keychain-profile', profile, '--output-format', 'json'], timeout=600))
        receipt = {'submission_id': result['id'], 'notary_profile': profile,
                   'signing_identity': identity, 'archive_sha256': digest(archive),
                   'status': 'Submitted', 'stapled': False}
        save_receipt()

    submission = receipt['submission_id']
    print(f'Apple submission: {submission}', flush=True)
    try:
        result = json.loads(run('notary-wait', [
            'xcrun', 'notarytool', 'wait', submission, '--keychain-profile', profile,
            '--output-format', 'json', '--timeout', '10m'], timeout=630))
    except (RuntimeError, subprocess.TimeoutExpired):
        print(f'To check/finish this submission without resubmitting:\n'
              f'  python3 tools/notarize_macos.py {folder.relative_to(ROOT)} --resume', flush=True)
        raise
    receipt['status'] = result['status']
    save_receipt()
    run('notary-log', ['xcrun', 'notarytool', 'log', submission,
                      '--keychain-profile', profile])
    if result['status'] != 'Accepted':
        raise RuntimeError(f'Apple returned {result["status"]}; see logs/notary-log.log. No upload allowed.')
    # Restore exactly the submitted bundle before stapling, also when resuming.
    with tempfile.TemporaryDirectory(prefix='notary-verify-', dir=folder) as temp:
        extracted = Path(temp)
        run('extract-accepted-app', ['ditto', '-x', '-k', str(archive), str(extracted)])
        accepted_app = extracted / app.name
        run('staple-macos', ['xcrun', 'stapler', 'staple', str(accepted_app)])
        run('validate-ticket', ['xcrun', 'stapler', 'validate', str(accepted_app)])
        run('verify-stapled-signature', ['codesign', '--verify', '--deep', '--strict', str(accepted_app)])
        run('gatekeeper', ['spctl', '--assess', '--type', 'execute', '--verbose=2', str(accepted_app)])
        # Package the verified bundle, not any independently modified local app.
        app = accepted_app
        package('package-notarized-macos')
    run('unpack-notarized-macos', ['ditto', '-x', '-k', str(archive), str(folder / 'macos')])
    receipt['stapled'] = True
    receipt['archive_sha256'] = digest(archive)
    save_receipt()
    print(f'Notarized and stapled: {archive.relative_to(ROOT)}', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output_dir', type=Path)
    parser.add_argument('--resume', action='store_true')
    args = parser.parse_args()
    try:
        notarize(args.output_dir, args.resume)
    except (OSError, ValueError, KeyError, RuntimeError, subprocess.SubprocessError) as error:
        sys.exit(str(error))
