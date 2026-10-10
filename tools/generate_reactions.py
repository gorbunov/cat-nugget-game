"""Prepare selected CC0 recordings offline; requires macOS afconvert.

Source details and licenses: art_sources/reactions.json. No pitch/time shifting.
"""
from array import array
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import wave

ROOT = Path(__file__).resolve().parents[1]
SR = 22050


def main():
    build = ROOT / 'build'
    build.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='reactions_', dir=build) as temporary:
        for reaction in json.loads((ROOT / 'art_sources/reactions.json').read_text()):
            name = reaction['key']
            source = ROOT / 'art_sources' / reaction['file']
            converted = Path(temporary) / (name + '.wav')
            subprocess.run(['afconvert', '-f', 'WAVE', '-d', f'LEI16@{SR}',
                            '-c', '1', str(source), str(converted)], check=True)
            with wave.open(str(converted), 'rb') as wav:
                assert (wav.getnchannels(), wav.getsampwidth(), wav.getframerate()) == (1, 2, SR)
                samples = array('h', wav.readframes(wav.getnframes()))
            if sys.byteorder != 'little':
                samples.byteswap()
            if reaction['end_seconds'] is not None:
                samples = samples[:round(reaction['end_seconds'] * SR)]
            peak = max(abs(value) for value in samples)
            assert peak > 0, f'{name}: empty recording'
            count = len(samples)
            output = array('h')
            for i, value in enumerate(samples):
                envelope = min(1, i / 110, (count - 1 - i) / 220)
                output.append(round(value * (.75 * 32767 / peak) * envelope))
            if sys.byteorder != 'little':
                output.byteswap()
            destination = ROOT / 'assets' / f'reaction_{name}.wav'
            with wave.open(str(destination), 'wb') as wav:
                wav.setnchannels(1)
                wav.setsampwidth(2)
                wav.setframerate(SR)
                wav.writeframes(output.tobytes())
            print(f'{destination.name}: {count / SR:.2f}s')


if __name__ == '__main__':
    main()
