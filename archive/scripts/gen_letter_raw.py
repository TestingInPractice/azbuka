#!/usr/bin/env python3
"""Generate pure letter sound RAW PCM data for all 33 Russian letters.
Saves as .raw files (no WAV header) — Godot AudioStreamWAV reads raw PCM."""

import struct, math, os, random

AUDIO_DIR = "/Users/halapinvv/azbuka-pwa/assets/audio"

LETTERS = [
    "А","Б","В","Г","Д","Е","Ё","Ж","З","И","Й",
    "К","Л","М","Н","О","П","Р","С","Т","У","Ф",
    "Х","Ц","Ч","Ш","Щ","Ъ","Ы","Ь","Э","Ю","Я",
]

def gen_pcm(freq, duration, sample_rate=22050, noise=0.0, harmonics=None):
    n = int(sample_rate * duration)
    data = bytearray()
    rng = random.Random(str(freq))
    for i in range(n):
        t = i / sample_rate
        env = 1.0
        if t < 0.006:
            env = t / 0.006
        elif t > duration - 0.05:
            env = (duration - t) / 0.05
        s = math.sin(2 * math.pi * freq * t) * 0.35
        if harmonics:
            for h_ratio, h_amp in harmonics:
                s += math.sin(2 * math.pi * freq * h_ratio * t) * h_amp
        s += rng.uniform(-1, 1) * noise * env
        val = int(s * env * 14000)
        data.extend(struct.pack('<h', val))
    return bytes(data)

VOWELS = set("АЕЁИОУЫЭЮЯ")
SONORANTS = set("ЙЛМНР")
VOICED = set("БВГДЖЗ")
VOICELESS = set("КПСТФХЦЧШЩ")
SPECIAL = set("ЪЬ")

print("Generating raw PCM letter sounds...")
for letter in LETTERS:
    idx = LETTERS.index(letter)
    freq = 440.0 + idx * 18.0

    if letter in VOWELS:
        pcm = gen_pcm(freq, 0.40, harmonics=[(1.5, 0.12), (2.0, 0.06)])
    elif letter in SONORANTS:
        pcm = gen_pcm(freq, 0.35, harmonics=[(2.0, 0.10)])
    elif letter in VOICED:
        pcm = gen_pcm(freq, 0.25, noise=0.05, harmonics=[(1.5, 0.08)])
    elif letter in VOICELESS:
        pcm = gen_pcm(freq, 0.18, noise=0.10)
    elif letter in SPECIAL:
        pcm = gen_pcm(freq * 2, 0.08, noise=0.02)
    else:
        pcm = gen_pcm(freq, 0.30)

    path = os.path.join(AUDIO_DIR, letter.lower() + "_letter.raw")
    with open(path, 'wb') as f:
        f.write(pcm)
    print(f"  {letter}: {len(pcm)} bytes PCM raw")

print("\nDone! All 33 letter RAW PCM files generated.")
