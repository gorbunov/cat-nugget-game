"""Validate music renders: format, headroom, loop seams and paired stem lengths."""
from array import array
import math
import sys
import wave

from compose_music import ASSETS, SONGS, SR


def inspect(name):
    with wave.open(str(ASSETS / (name + '.wav')), 'rb') as wav:
        assert (wav.getnchannels(), wav.getsampwidth(), wav.getframerate()) == (1, 2, SR)
        samples = array('h', wav.readframes(wav.getnframes()))
    if sys.byteorder != 'little':
        samples.byteswap()
    peak = max(abs(value) for value in samples) / 32768
    rms = math.sqrt(sum(float(value)**2 for value in samples) / len(samples)) / 32768
    seam = abs(samples[-1] - samples[0]) / 32768
    assert 0.001 < rms and peak < .95, f'{name}: silent or insufficient headroom'
    assert seam < .02, f'{name}: abrupt loop boundary ({seam})'
    print(f'{name}: {len(samples)/SR:.2f}s, peak {peak:.3f}, RMS {rms:.3f}, seam {seam:.5f}')
    return len(samples)


if __name__ == '__main__':
    inspect('snack_time')
    inspect('panic')
    for song in SONGS:
        assert inspect(song['file']) == inspect(song['file'] + '_panic'), 'Stem durations differ'
        assert (ASSETS / (song['file'] + '.mid')).read_bytes().startswith(b'MThd')
    for reaction, minimum, maximum in [('eww', 1.99, 2.01), ('yay', 1.7, 2.0), ('nom', .2, .4)]:
        frames = inspect('reaction_' + reaction)
        assert minimum < frames / SR < maximum, f'{reaction}: unexpected selected clip duration'
    print('AUDIO CHECK PASSED: music, finale layers, reactions, headroom, loop seams and MIDI headers.')
