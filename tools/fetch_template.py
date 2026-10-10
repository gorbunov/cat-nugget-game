"""Fetch only macos.zip from the official template archive using HTTP ranges.

Keeps the matching template in this project rather than installing globally.
"""
from pathlib import Path
import struct
import urllib.request
import zlib

ROOT = Path(__file__).resolve().parents[1]
VERSION = "4.7.2-stable"
URL = f"https://github.com/godotengine/godot-builds/releases/download/{VERSION}/Godot_v{VERSION}_export_templates.tpz"


def fetch(url, start, end):
    req = urllib.request.Request(url, headers={"Range": f"bytes={start}-{end}", "User-Agent": "NuggetCat-build"})
    with urllib.request.urlopen(req, timeout=120) as response:
        if response.status != 206:
            raise RuntimeError(f"Server ignored byte range: HTTP {response.status}")
        return response.read()


def main():
    dest = ROOT / "build" / "templates"
    dest.mkdir(parents=True, exist_ok=True)
    (ROOT / "build" / ".gdignore").touch()
    target = dest / "macos.zip"
    if target.exists():
        print(f"Already available: {target}")
        return
    with urllib.request.urlopen(urllib.request.Request(URL, method="HEAD"), timeout=30) as response:
        url = response.url
        length = int(response.headers["Content-Length"])
    tail = fetch(url, length - 65536, length - 1)
    eocd = tail.rfind(b'PK\x05\x06')
    _, _, _, _, count, size, offset, _ = struct.unpack_from('<4s4H2IH', tail, eocd)
    directory = fetch(url, offset, offset + size - 1)
    position = 0
    for _ in range(count):
        fields = struct.unpack_from('<4s6H3I5H2I', directory, position)
        method, crc, compressed, uncompressed = fields[4], fields[7], fields[8], fields[9]
        name_len, extra_len, comment_len, local_offset = fields[10], fields[11], fields[12], fields[16]
        name = directory[position + 46:position + 46 + name_len].decode()
        position += 46 + name_len + extra_len + comment_len
        if name != 'templates/macos.zip':
            continue
        header = fetch(url, local_offset, local_offset + 29)
        local_name_len, local_extra_len = struct.unpack_from('<HH', header, 26)
        start = local_offset + 30 + local_name_len + local_extra_len
        print(f"Downloading macOS template only ({compressed / 1024**2:.1f} MiB)...", flush=True)
        parts = []
        for chunk_start in range(start, start + compressed, 8 * 1024 * 1024):
            parts.append(fetch(url, chunk_start, min(chunk_start + 8*1024*1024, start+compressed)-1))
        data = b''.join(parts)
        if method == 8:
            data = zlib.decompress(data, -15)
        elif method != 0:
            raise RuntimeError(f"Unexpected compression: {method}")
        assert len(data) == uncompressed and zlib.crc32(data) == crc, "Template checksum mismatch"
        target.write_bytes(data)
        print(f"Verified and saved {target}")
        return
    raise RuntimeError("macos.zip was not present in official export templates")


if __name__ == '__main__':
    main()
