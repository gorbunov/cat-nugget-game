"""Original Nugget Cat pixel art + chiptune. Python standard library only."""
from pathlib import Path
import math
import random
import struct
import wave
import zlib
import sys
from compose_music import compose_all, warm_filter

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
ASSETS.mkdir(exist_ok=True)


class Image:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.data = bytearray(w * h * 4)

    def pixel(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.data[(y * self.w + x) * 4:(y * self.w + x) * 4 + 4] = bytes(c)

    def rect(self, x, y, w, h, c):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.pixel(xx, yy, c)

    def ellipse(self, x, y, w, h, c):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                if ((xx + .5 - x - w / 2) / (w / 2)) ** 2 + ((yy + .5 - y - h / 2) / (h / 2)) ** 2 <= 1:
                    self.pixel(xx, yy, c)

    def png(self, name):
        def chunk(kind, data):
            return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
        rows = b''.join(b'\0' + self.data[y*self.w*4:(y+1)*self.w*4] for y in range(self.h))
        (ASSETS / name).write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', self.w, self.h, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(rows)) + chunk(b'IEND', b''))


INK = (66, 43, 62, 255)
ORANGE = (240, 151, 74, 255)
LIGHT = (255, 195, 112, 255)
CREAM = (255, 231, 184, 255)
PINK = (238, 125, 144, 255)
WHITE = (255, 247, 228, 255)

# 8 expressive 48px frames: idle, blink, chomp, chew, happy, offended, wild, sleepy.
im = Image(48 * 8, 48)
for frame in range(8):
    x = frame * 48
    im.ellipse(x+31, 29, 15, 12, INK)
    im.ellipse(x+33, 29, 11, 9, ORANGE)
    im.ellipse(x+10, 20, 29, 24, INK)
    im.ellipse(x+12, 21, 25, 21, ORANGE)
    im.ellipse(x+17, 26, 15, 16, CREAM)
    im.rect(x+9, 6, 9, 18, INK)
    im.rect(x+30, 6, 9, 18, INK)
    im.rect(x+11, 9, 6, 13, ORANGE)
    im.rect(x+31, 9, 6, 13, ORANGE)
    im.rect(x+12, 11, 3, 6, PINK)
    im.rect(x+33, 11, 3, 6, PINK)
    im.ellipse(x+6, 12, 36, 25, INK)
    im.ellipse(x+8, 13, 32, 22, LIGHT)
    im.rect(x+20, 13, 3, 5, ORANGE)
    im.rect(x+26, 13, 3, 4, ORANGE)
    im.ellipse(x+8, 26, 8, 5, PINK)
    im.ellipse(x+33, 26, 7, 5, PINK)
    if frame in (1, 7):
        im.rect(x+14, 22, 6, 2, INK)
        im.rect(x+29, 22, 6, 2, INK)
    elif frame == 5:
        im.rect(x+13, 21, 7, 3, INK)
        im.rect(x+29, 21, 7, 3, INK)
        im.rect(x+15, 24, 3, 3, INK)
        im.rect(x+31, 24, 3, 3, INK)
    elif frame == 6:
        im.ellipse(x+11, 17, 11, 12, WHITE)
        im.ellipse(x+27, 17, 11, 12, WHITE)
        im.rect(x+17, 19, 3, 7, INK)
        im.rect(x+29, 21, 3, 7, INK)
    else:
        im.ellipse(x+13, 19, 8, 9, INK)
        im.ellipse(x+28, 19, 8, 9, INK)
        im.rect(x+15, 20, 2, 3, WHITE)
        im.rect(x+30, 20, 2, 3, WHITE)
    if frame in (2, 6):
        im.ellipse(x+17, 26, 15, 11, INK)
        im.ellipse(x+20, 32, 10, 4, PINK)
        im.rect(x+20, 27, 3, 3, WHITE)
        im.rect(x+27, 27, 3, 3, WHITE)
    elif frame == 3:
        im.ellipse(x+16, 28, 17, 7, CREAM)
        im.rect(x+21, 29, 6, 2, INK)
    else:
        im.rect(x+22, 27, 4, 2, PINK)
        im.rect(x+23, 29, 2, 3, INK)
        im.rect(x+20, 31, 8, 1, INK)
    im.rect(x+5, 28, 6, 1, INK)
    im.rect(x+37, 28, 6, 1, INK)
    im.ellipse(x+10, 38, 11, 7, INK)
    im.ellipse(x+28, 38, 11, 7, INK)
    im.ellipse(x+11, 38, 9, 5, LIGHT)
    im.ellipse(x+29, 38, 9, 5, LIGHT)
im.png('cat.png')
icon = Image(128, 128)
icon.rect(0, 0, 128, 128, (103, 139, 131, 255))
for y in range(48):
    for x in range(48):
        p = tuple(im.data[(y*im.w+x)*4:(y*im.w+x)*4+4])
        if p[3]:
            icon.rect(16+x*2, 16+y*2, 2, 2, p)
icon.png('icon.png')

n = Image(16, 16)
n.ellipse(1, 2, 14, 12, INK)
n.ellipse(2, 3, 12, 10, (208, 119, 52, 255))
n.ellipse(3, 3, 10, 8, (255, 190, 74, 255))
n.rect(5, 4, 5, 2, (255, 225, 125, 255))
for x, y in [(4, 8), (9, 9), (11, 6), (6, 11)]:
    n.rect(x, y, 2, 1, (203, 120, 49, 255))
n.png('nugget.png')

# Right-facing hand, three poses; rotated in-game for each edge.
h = Image(48*3, 32)
for f in range(3):
    x = f*48
    h.rect(x, 10, 20, 17, INK)
    h.rect(x, 12, 19, 13, (116, 159, 152, 255))
    h.rect(x+14, 11, 5, 15, WHITE)
    h.ellipse(x+17, 9, 24, 18, INK)
    h.ellipse(x+18, 10, 22, 15, (240, 176, 144, 255))
    if f == 0:
        h.ellipse(x+26, 4, 12, 17, INK)
        h.ellipse(x+27, 5, 10, 14, (255, 199, 158, 255))
    else:
        h.rect(x+29, 9-f*2, 16, 5, INK)
        h.rect(x+29, 10-f*2, 15, 3, (255, 199, 158, 255))
    h.rect(x+24, 18, 12, 1, (203, 128, 120, 255))
h.png('hands.png')

# Tiny custom bitmap typeface, uppercase with deliberately chunky glyphs.
glyphs = {
'A':['01110','10001','10001','11111','10001','10001','10001'],
'B':['11110','10001','10001','11110','10001','10001','11110'],
'C':['01111','10000','10000','10000','10000','10000','01111'],
'D':['11110','10001','10001','10001','10001','10001','11110'],
'E':['11111','10000','10000','11110','10000','10000','11111'],
'F':['11111','10000','10000','11110','10000','10000','10000'],
'G':['01111','10000','10000','10111','10001','10001','01111'],
'H':['10001','10001','10001','11111','10001','10001','10001'],
'I':['111','010','010','010','010','010','111'],
'J':['00111','00010','00010','00010','10010','10010','01100'],
'K':['10001','10010','10100','11000','10100','10010','10001'],
'L':['10000','10000','10000','10000','10000','10000','11111'],
'M':['10001','11011','10101','10101','10001','10001','10001'],
'N':['10001','11001','11001','10101','10011','10011','10001'],
'O':['01110','10001','10001','10001','10001','10001','01110'],
'P':['11110','10001','10001','11110','10000','10000','10000'],
'Q':['01110','10001','10001','10001','10101','10010','01101'],
'R':['11110','10001','10001','11110','10100','10010','10001'],
'S':['01111','10000','10000','01110','00001','00001','11110'],
'T':['11111','00100','00100','00100','00100','00100','00100'],
'U':['10001','10001','10001','10001','10001','10001','01110'],
'V':['10001','10001','10001','10001','10001','01010','00100'],
'W':['10001','10001','10001','10101','10101','11011','10001'],
'X':['10001','10001','01010','00100','01010','10001','10001'],
'Y':['10001','10001','01010','00100','00100','00100','00100'],
'Z':['11111','00001','00010','00100','01000','10000','11111'],
'0':['01110','10001','10011','10101','11001','10001','01110'],
'1':['010','110','010','010','010','010','111'],
'2':['01110','10001','00001','00110','01000','10000','11111'],
'3':['11110','00001','00001','01110','00001','00001','11110'],
'4':['10010','10010','10010','11111','00010','00010','00010'],
'5':['11111','10000','10000','11110','00001','00001','11110'],
'6':['01110','10000','10000','11110','10001','10001','01110'],
'7':['11111','00001','00010','00100','01000','01000','01000'],
'8':['01110','10001','10001','01110','10001','10001','01110'],
'9':['01110','10001','10001','01111','00001','00001','01110'],
'!':['1','1','1','1','1','0','1'], '?':['01110','10001','00001','00110','00100','00000','00100'],
'.':['0','0','0','0','0','1','1'], ':':['0','1','1','0','1','1','0'],
'-':['000','000','000','111','000','000','000'], '+':['00000','00100','00100','11111','00100','00100','00000'],
'/':['00001','00001','00010','00100','01000','10000','10000'],
'>':['100','010','001','001','001','010','100'], '<':['001','010','100','100','100','010','001'],
' ':['000']*7,
"'":['1','1','0','0','0','0','0'],
'%':['11001','11010','00100','00100','01000','10110','00110'],
}
font_image = Image(16*8, 6*10)
lines = ['info face="SnackPixel" size=8 bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1', 'common lineHeight=10 base=8 scaleW=128 scaleH=60 pages=1 packed=0', 'page id=0 file="pixel_font.png"', f'chars count={len(glyphs)}']
for i, (char, pattern) in enumerate(glyphs.items()):
    x, y = (i % 16)*8, (i//16)*10
    w = len(pattern[0])
    for yy, row in enumerate(pattern):
        for xx, bit in enumerate(row):
            if bit == '1':
                font_image.pixel(x+xx, y+yy, WHITE)
    lines.append(f'char id={ord(char)} x={x} y={y} width={w} height=7 xoffset=0 yoffset=0 xadvance={w+1} page=0 chnl=15')
font_image.png('pixel_font.png')
(ASSETS/'pixel_font.fnt').write_text('\n'.join(lines)+'\n')

if '--art-only' in sys.argv:
    print(f'Generated procedural art and bitmap font in {ASSETS}')
    sys.exit(0)

SR = 22050
random.seed(24)


def write_audio(name, data):
    peak = max(1, max(abs(v) for v in data))
    with wave.open(str(ASSETS/name), 'wb') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SR)
        wav.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, v / peak * .8))*32767)) for v in data))


def tone(buf, start, duration, midi, volume=.15, kind='square', slide=0):
    freq = 440 * 2**((midi-69)/12)
    count = int(duration * SR)
    for j in range(count):
        index = int(start*SR)+j
        if index >= len(buf):
            break
        t = j/SR
        phase = freq*(t+slide*t*t/2)
        if kind == 'square':
            value = 1 if phase % 1 < .25 else -1/3
        elif kind == 'soft':
            value = (math.sin(2*math.pi*phase) + .18*math.sin(6*math.pi*phase)) * .8
        elif kind == 'triangle':
            value = 4*abs(phase % 1-.5)-1
        else:
            value = random.uniform(-1, 1)
        env = min(1, j/90) * min(1, (count-j)/180)
        if kind == 'soft':
            env = min(1, j/180) * min(1, (count-j)/350)
        if kind == 'noise':
            env *= (1-j/count)**3
        buf[index] += value * volume * env


# 16 bars, 128 BPM, exact loop boundary. Melody, bouncing bass, arpeggios, drums.
beat = 60/128
music = [0.] * round(16*4*beat*SR)
chords = [(48, 52, 55), (53, 57, 60), (57, 60, 64), (55, 59, 62)]
melodies = [[72,76,79,76,81,79,76,74], [77,81,84,81,79,77,76,72], [76,79,84,83,81,79,76,74], [74,79,83,86,84,83,79,71]]
for bar in range(16):
    chord = chords[bar % 4]
    for step in range(8):
        t = (bar*4+step*.5)*beat
        note = melodies[bar % 4][step] - 12
        tone(music, t, beat*.34, note, .16, 'soft')
        tone(music, t, beat*.25, chord[step%3]+12, .06, 'triangle')
        if step % 2 == 0:
            tone(music, t, beat*.7, chord[0] + (7 if step == 4 else 0)-12, .24, 'triangle')
            tone(music, t, .09, 37, .16, 'triangle', -5)
        else:
            tone(music, t, .045, 90, .07, 'noise')
        if step in (2,6):
            tone(music, t, .10, 60, .13, 'noise')
write_audio('snack_time.wav', warm_filter(music))
panic = [0.] * round(4*4*beat*SR)
for step in range(64):
    tone(panic, step*beat*.25, beat*.15, [72,76,79,84][step%4], .09, 'soft')
write_audio('panic.wav', warm_filter(panic))
for name, notes, kind in [('catch',[79,84,88],'square'), ('combo',[72,76,79,84,88,91],'square'), ('miss',[55,51,46],'triangle'), ('throw',[60,72],'noise'), ('tick',[84],'square'), ('finish',[84,79,76,79,84,88,91,96],'square')]:
    audio = [0.] * int((len(notes)*.055+.12)*SR)
    for i, note in enumerate(notes):
        tone(audio, i*.055, .09, note, .3, kind)
    write_audio(name+'.wav', audio)
print(f'Generated sprites, bitmap font and 8 original audio files in {ASSETS}')
compose_all()
