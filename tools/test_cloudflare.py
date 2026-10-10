"""Offline checks for Cloudflare's size limit and browser-decodable WASM payload."""
import gzip
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest
import urllib.error
import urllib.request

from prepare_cloudflare import ROOT, REQUIRED, prepare_assets

SERVE_CHECK = '--serve-check' in sys.argv
if SERVE_CHECK:
    sys.argv.remove('--serve-check')


class PackagingTests(unittest.TestCase):
    def setUp(self):
        (ROOT / 'build').mkdir(exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=ROOT / 'build', prefix='test-cloudflare-')
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        self.source = self.folder / 'web'
        self.source.mkdir()
        self.destination = self.folder / 'assets'
        for name in REQUIRED:
            (self.source / name).write_bytes(b'export')
        self.wasm = b'\x00asm\x01\x00\x00\x00' + b'compressible engine bytes' * 1000
        (self.source / 'index.wasm').write_bytes(self.wasm)

    def test_wasm_round_trip_headers_and_source_unchanged(self):
        prepare_assets(self.source, self.destination, limit=1024)
        packed = (self.destination / 'index.wasm.gz').read_bytes()
        self.assertLess(len(packed), 1024)
        self.assertEqual(gzip.decompress(packed), self.wasm)
        self.assertEqual((self.source / 'index.wasm').read_bytes(), self.wasm)
        headers = (self.destination / '_headers').read_text()
        self.assertNotIn('Content-Encoding', headers) # Worker handles precompressed bytes.
        self.assertFalse((self.destination / 'index.wasm').exists())
        self.assertIn('max-age=0, must-revalidate', headers)
        self.assertEqual((self.destination / 'index.html').read_bytes(), b'export')
        (self.destination / 'stale.js').write_text('stale')
        prepare_assets(self.source, self.destination, limit=1024)
        self.assertFalse((self.destination / 'stale.js').exists())
        self.assertEqual((self.destination / 'index.wasm.gz').read_bytes(), packed)

    def test_oversized_asset_preserves_previous_payload(self):
        prepare_assets(self.source, self.destination, limit=1024)
        (self.source / 'index.pck').write_bytes(b'large' * 1024)
        with self.assertRaisesRegex(ValueError, 'Cloudflare limit'):
            prepare_assets(self.source, self.destination, limit=1024)
        self.assertEqual((self.destination / 'index.pck').read_bytes(), b'export')
        self.assertFalse((self.folder / 'assets-staging').exists())

    def test_missing_export_rejected(self):
        (self.source / 'index.js').unlink()
        with self.assertRaisesRegex(ValueError, 'Missing Web export'):
            prepare_assets(self.source, self.destination)
        self.assertFalse(self.destination.exists())


@unittest.skipUnless(SERVE_CHECK, 'Use --serve-check after the Wrangler dry-run')
class ServingTests(unittest.TestCase):
    def test_real_wrangler_headers_and_decoded_bytes(self):
        with tempfile.TemporaryDirectory(dir=ROOT / 'build', prefix='test-cloudflare-server-') as folder:
            folder = Path(folder)
            config = json.loads((ROOT / 'tools/cloudflare/wrangler.jsonc').read_text())
            config.pop('build')
            config.pop('routes')
            config['main'] = str(ROOT / 'tools/cloudflare/worker.js')
            config['assets']['directory'] = str(ROOT / 'build/cloudflare/assets')
            config_path = folder / 'wrangler.json'
            config_path.write_text(json.dumps(config))
            env = {**os.environ, 'WRANGLER_SEND_METRICS': 'false',
                   'WRANGLER_LOG_PATH': str(folder / 'wrangler.log')}
            with (folder / 'server.log').open('w+') as log:
                server = subprocess.Popen([
                    str(ROOT / 'tools/cloudflare/node_modules/.bin/wrangler'),
                    'dev', '--config', str(config_path), '--local', '--port', '8799',
                    '--inspector-port', '0', '--show-interactive-dev-session=false',
                ], cwd=folder, env=env, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
                try:
                    for attempt in range(100):
                        if server.poll() is not None:
                            log.seek(0)
                            self.fail(log.read())
                        try:
                            with urllib.request.urlopen('http://127.0.0.1:8799/', timeout=1) as response:
                                self.assertIn(b'Nugget Cat', response.read())
                            break
                        except urllib.error.URLError:
                            time.sleep(0.1)
                    else:
                        log.seek(0)
                        self.fail('Wrangler server timed out:\n' + log.read())
                    request = urllib.request.Request('http://127.0.0.1:8799/index.wasm', headers={'Accept-Encoding': 'gzip'})
                    with urllib.request.urlopen(request, timeout=30) as response:
                        self.assertEqual(response.headers['Content-Type'], 'application/wasm')
                        self.assertEqual(response.headers['Content-Encoding'], 'gzip')
                        self.assertIn('must-revalidate', response.headers['Cache-Control'])
                        decoded = gzip.decompress(response.read())
                    self.assertEqual(decoded, (ROOT / 'build/cloudflare/build/web/index.wasm').read_bytes())
                    request = urllib.request.Request('http://127.0.0.1:8799/index.wasm', method='HEAD', headers={'Accept-Encoding': 'gzip'})
                    with urllib.request.urlopen(request, timeout=30) as response:
                        self.assertEqual(response.headers['Content-Encoding'], 'gzip')
                        self.assertEqual(response.read(), b'')
                    with urllib.request.urlopen('http://127.0.0.1:8799/index.pck', timeout=30) as response:
                        self.assertEqual(response.read(), (ROOT / 'build/cloudflare/build/web/index.pck').read_bytes())
                    with self.assertRaises(urllib.error.HTTPError) as error:
                        urllib.request.urlopen('http://127.0.0.1:8799/missing.wasm')
                    self.assertEqual(error.exception.code, 404)
                    error.exception.close()
                finally:
                    os.killpg(server.pid, signal.SIGTERM)
                    server.wait(timeout=15)


if __name__ == '__main__':
    unittest.main()
