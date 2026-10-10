"""Serve the single-threaded build/web locally over HTTP for browser playtesting.

Run after tools/build_release.py --targets web, then open the printed URL.
"""
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class GameHandler(SimpleHTTPRequestHandler):
    extensions_map = {**SimpleHTTPRequestHandler.extensions_map, '.wasm': 'application/wasm'}

    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=8060)
    args = parser.parse_args()
    folder = ROOT / 'build' / 'web'
    if not (folder / 'index.html').is_file():
        parser.error('Export Web first: python3 tools/build_release.py --targets web')
    handler = partial(GameHandler, directory=str(folder))
    with ThreadingHTTPServer(('127.0.0.1', args.port), handler) as server:
        print(f'Open http://127.0.0.1:{server.server_port}/ (Ctrl+C to stop)', flush=True)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass


if __name__ == '__main__':
    main()
