"""Original 32-bar chiptune arrangements with editable General MIDI sources.

No soundfonts or dependencies. WAV playback uses synthesized chip instruments;
MIDI files preserve the notes, tempo, instrument suggestions and percussion.
"""
from array import array
import math
from pathlib import Path
import random
import struct
import sys
from typing import TypedDict
import wave

SR = 22050
PPQ = 480
ASSETS = Path(__file__).resolve().parents[1] / "assets"

class Song(TypedDict):
    file: str
    bpm: int
    instrument: str
    program: int
    chords: list[tuple[int, int, int]]
    melody: list[list[int]]


SONGS: list[Song] = [
    Song(file="sunny_side_up", bpm=112, instrument="bell", program=10,
         chords=[(48,52,55),(55,59,62),(57,60,64),(53,57,60),
                 (48,52,55),(52,55,59),(53,57,60),(55,59,62)],
         melody=[[76,79,81,79,76,-1,74,72], [74,79,83,81,79,-1,74,71],
                 [76,81,84,83,81,79,76,-1], [77,81,84,81,79,77,76,72],
                 [84,-1,83,79,81,79,76,74], [76,79,83,86,83,-1,79,76],
                 [77,81,79,77,76,74,72,-1], [74,79,83,81,79,74,71,72]]),
    Song(file="goofy_whiskers", bpm=144, instrument="pluck", program=80,
         chords=[(53,57,60),(50,53,57),(55,58,62),(48,52,55),
                 (53,57,60),(58,62,65),(55,59,62),(48,52,55)],
         melody=[[77,-1,89,84,81,-1,77,76], [77,81,-1,86,81,77,-1,74],
                 [79,-1,82,86,82,79,78,79], [76,79,84,-1,83,84,79,-1],
                 [81,77,84,81,89,-1,88,89], [82,-1,86,89,86,82,81,82],
                 [79,83,86,-1,85,86,83,79], [84,83,84,79,76,-1,72,77]]),
    Song(file="nugget_quest", bpm=132, instrument="pulse", program=81,
         chords=[(50,54,57),(47,50,54),(43,47,50),(45,49,52),
                 (50,54,57),(54,57,61),(43,47,50),(45,49,52)],
         melody=[[74,78,81,-1,86,85,81,78], [78,81,83,86,90,-1,86,83],
                 [79,83,86,83,81,79,78,74], [76,81,85,-1,88,85,81,76],
                 [86,-1,85,81,83,81,78,74], [78,81,85,88,85,-1,81,78],
                 [79,83,86,90,88,86,83,79], [81,85,88,85,81,76,73,74]]),
    Song(file="nugget_battle", bpm=152, instrument="pulse", program=81,
         chords=[(52,55,59),(48,52,55),(45,48,52),(47,51,54),
                 (52,55,59),(55,59,62),(48,52,55),(47,51,54)],
         melody=[[76,76,79,83,81,79,78,76], [76,79,84,-1,83,79,76,72],
                 [81,81,84,88,86,84,83,81], [83,78,75,78,83,-1,87,83],
                 [88,83,79,83,88,86,83,79], [83,86,91,86,83,81,79,78],
                 [84,83,79,76,79,84,83,79], [83,87,90,87,83,78,75,76]]),
]


def vlq(value):
    result = [value & 127]
    value >>= 7
    while value:
        result.insert(0, 128 | (value & 127))
        value >>= 7
    return bytes(result)


def midi_track(events, end):
    payload = bytearray()
    previous = 0
    for tick, message in sorted(events, key=lambda event: event[0]):
        payload.extend(vlq(tick - previous))
        payload.extend(message)
        previous = tick
    payload.extend(vlq(max(0, end - previous)) + b'\xff\x2f\x00')
    return b'MTrk' + struct.pack('>I', len(payload)) + payload


def write_midi(path, song, notes):
    tempo = round(60_000_000 / song['bpm'])
    end = 128 * PPQ
    conductor = [(0, b'\xff\x51\x03' + tempo.to_bytes(3, 'big')),
                 (0, b'\xff\x58\x04\x04\x02\x18\x08')]
    tracks = [midi_track(conductor, end)]
    for channel, name, program in [(0, 'Melody', song['program']), (1, 'Bouncy bass', 38),
                                   (2, 'Arpeggios', 80), (3, 'Harmony', 89), (9, 'Drums', 0)]:
        encoded = name.encode()
        events = [(0, b'\xff\x03' + vlq(len(encoded)) + encoded),
                  (0, bytes([0xC0 | channel, program]))]
        for start, duration, pitch, velocity, track in notes:
            if track != channel:
                continue
            events.append((round(start * PPQ), bytes([0x90 | channel, pitch, velocity])))
            events.append((round((start + duration) * PPQ), bytes([0x80 | channel, pitch, 0])))
        tracks.append(midi_track(events, end))
    path.write_bytes(b'MThd' + struct.pack('>IHHH', 6, 1, len(tracks), PPQ) + b''.join(tracks))


def render_note(buf, start, duration, midi, volume, instrument, rng):
    first = round(start * SR)
    count = round(duration * SR)
    frequency = 440 * 2 ** ((midi - 69) / 12)
    for j in range(min(count, len(buf) - first)):
        t = j / SR
        phase = frequency * t
        if instrument == 'bell':
            value = (math.sin(2 * math.pi * phase) + .12 * math.sin(4 * math.pi * phase)) * math.exp(-5*t)
        elif instrument == 'pluck':
            value = (math.sin(2*math.pi*phase) + .16*math.sin(6*math.pi*phase)) * math.exp(-10*t)
        elif instrument == 'pulse':
            # A rounded chip lead: retain a little odd-harmonic character,
            # without the bright/aliased harmonics of a hard square wave.
            value = (math.sin(2*math.pi*phase) + .20*math.sin(6*math.pi*phase)) * .8
        elif instrument == 'triangle':
            value = 4*abs(phase % 1-.5)-1
        elif instrument == 'pad':
            value = math.sin(2*math.pi*phase) * .7
        elif instrument == 'kick':
            value = math.sin(2*math.pi*(65*t-90*t*t)) * math.exp(-25*t)
        else:
            value = rng.uniform(-1, 1) * math.exp(-t*(65 if instrument == 'hat' else 28))
        envelope = min(1, j / 180) * min(1, (count-j) / 350)
        buf[first+j] += value * volume * envelope


def warm_filter(data, cutoff=3200):
    """Two gentle low-pass stages; prime from the loop tail to avoid a seam."""
    amount = 1 - math.exp(-2*math.pi*cutoff/SR)
    first = second = 0.0
    for value in data[-512:]:
        first += amount * (value-first)
        second += amount * (first-second)
    output = array('f')
    for value in data:
        first += amount * (value-first)
        second += amount * (first-second)
        output.append(second)
    return output


def save_wav(path, data):
    data = warm_filter(data)
    peak = max(abs(value) for value in data)
    gain = .68 / max(.001, peak)
    pcm = array('h', (round(value * gain * 32767) for value in data))
    if sys.byteorder != 'little':
        pcm.byteswap()
    with wave.open(str(path), 'wb') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SR)
        wav.writeframes(pcm.tobytes())


def compose_all():
    ASSETS.mkdir(exist_ok=True)
    for song in SONGS:
        rng = random.Random(song['file'])
        beat = 60 / song['bpm']
        mix = array('f', [0]) * round(128*beat*SR)
        panic = array('f', [0]) * len(mix)
        notes = []
        battle = song['file'] == 'nugget_battle'

        def note(start, duration, pitch, volume, instrument, channel, velocity=85):
            if channel == 0:
                pitch -= 12 # Warm lead register; the MIDI source matches playback.
            render_note(mix, start*beat, duration*beat, pitch, volume, instrument, rng)
            notes.append((start, duration, pitch, velocity, channel))

        for bar in range(32):
            chord = song['chords'][bar % 8]
            melody = song['melody'][bar % 8]
            section = bar // 8
            for step in range(8):
                # A little offbeat bounce for the comedy track.
                swing = .09 if song['file'] == 'goofy_whiskers' and step % 2 else 0
                start = bar*4 + step*.5 + swing
                pitch = melody[step]
                if pitch >= 0:
                    # Second half answers the original motif in a lower register.
                    if section == 2 and not battle:
                        pitch -= 12
                    duration = .36 if song['instrument'] != 'pluck' else .24
                    if step < 7 and melody[step+1] == -1:
                        duration += .35
                    note(start, duration, pitch, .16, song['instrument'], 0)
                    if section == 3 and step in (0, 4):
                        note(start, .7, chord[1]+12, .045, 'bell', 3, 55)
                if step % 2 == 0:
                    bass = chord[0]-12 + (7 if step == 4 else 0)
                    note(start, .38 if battle else .75, bass, .27 if battle else .23, 'triangle', 1, 95)
                    note(start, .19, 36, .29 if battle else .24, 'kick', 9)
                else:
                    note(start, .10, 42, .05, 'hat', 9, 55)
                    if battle:
                        note(start, .36, chord[0]-12 + (7 if step == 7 else 0), .24, 'pluck', 1, 95)
                        if step == 7:
                            note(start, .18, 36, .22, 'kick', 9)
                if step in (2, 6):
                    note(start, .17, 38, .19 if battle else .11, 'snare', 9, 85 if battle else 75)
                if section != 0 or step % 2:
                    note(start, .26, chord[step%3]+12, .065, 'pulse', 2, 55)
                # End-of-phrase fills make the tune feel performed, not just repeated.
                if bar % 8 == 7 and step >= 6:
                    note(start+.25, .1, 38, .09, 'snare', 9, 65)
                for sub in range(2):
                    render_note(panic, (start+sub*.25)*beat, .15*beat,
                                chord[(step*2+sub)%3]+12, .09, 'pluck', rng)
            if section in (1, 3):
                for pitch in chord:
                    note(bar*4, 3.7, pitch+12, .035, 'pad', 3, 45)

        save_wav(ASSETS / (song['file'] + '.wav'), mix)
        save_wav(ASSETS / (song['file'] + '_panic.wav'), panic)
        write_midi(ASSETS / (song['file'] + '.mid'), song, notes)
        print(f"Composed {song['file']}: {song['bpm']} BPM, {128*beat:.1f}s, WAV + panic layer + MIDI")


if __name__ == '__main__':
    compose_all()
