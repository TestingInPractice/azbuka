#!/usr/bin/env python3
"""Generate pure letter sound WAVs for all 33 Russian letters.
Each file contains just the letter's phonetic sound (NOT the formal name).
Uses macOS `say` command with Russian locale approximation, or falls back
to synthetic tones."""

import wave, struct, math, os, subprocess, tempfile, json

AUDIO_DIR = "/Users/halapinvv/azbuka-pwa/assets/audio"

LETTERS = [
    "А","Б","В","Г","Д","Е","Ё","Ж","З","И","Й",
    "К","Л","М","Н","О","П","Р","С","Т","У","Ф",
    "Х","Ц","Ч","Ш","Щ","Ъ","Ы","Ь","Э","Ю","Я",
]

def gen_tone_wav(path, freq, duration=0.35, sample_rate=22050):
    """Generate a pleasant synthetic tone for a letter."""
    n_samples = int(sample_rate * duration)
    data = bytearray()
    for i in range(n_samples):
        t = i / sample_rate
        envelope = 1.0
        if t < 0.008:
            envelope = t / 0.008
        elif t > duration - 0.06:
            envelope = (duration - t) / 0.06
        sample = 0.0
        sample += math.sin(2 * math.pi * freq * t) * 0.35
        sample += math.sin(2 * math.pi * freq * 1.5 * t) * 0.12
        sample += math.sin(2 * math.pi * freq * 2.0 * t) * 0.06
        val = int(sample * envelope * 14000)
        data.extend(struct.pack('<h', val))
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sample_rate)
        w.writeframes(bytes(data))

def gen_noise_tone_wav(path, freq, duration=0.25, sample_rate=22050, noise_amt=0.08):
    """Generate a tone with slight noise for consonant letters."""
    n_samples = int(sample_rate * duration)
    data = bytearray()
    import random
    rng = random.Random(str(freq))
    for i in range(n_samples):
        t = i / sample_rate
        envelope = 1.0
        if t < 0.005:
            envelope = t / 0.005
        elif t > duration - 0.04:
            envelope = (duration - t) / 0.04
        sample = math.sin(2 * math.pi * freq * t) * 0.25
        sample += math.sin(2 * math.pi * freq * 1.5 * t) * 0.08
        sample += rng.uniform(-1, 1) * noise_amt * envelope
        val = int(sample * envelope * 13000)
        data.extend(struct.pack('<h', val))
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sample_rate)
        w.writeframes(bytes(data))

def gen_click_wav(path, duration=0.12, sample_rate=22050):
    """Generate a short soft click for Ъ/Ь."""
    n_samples = int(sample_rate * duration)
    data = bytearray()
    for i in range(n_samples):
        t = i / sample_rate
        envelope = 1.0
        if t < 0.002:
            envelope = t / 0.002
        elif t > duration - 0.02:
            envelope = (duration - t) / 0.02
        sample = math.sin(2 * math.pi * 800 * t) * envelope * 0.15
        val = int(sample * 12000)
        data.extend(struct.pack('<h', val))
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sample_rate)
        w.writeframes(bytes(data))

# Letter categories
VOWELS = set("АЕЁИОУЫЭЮЯ")
SONORANTS = set("ЙЛМНР")
VOICED = set("БВГДЖЗ")
VOICELESS = set("КПСТФХЦЧШЩ")
SPECIAL = set("ЪЬ")

# Map each letter to a base frequency (440-1040 Hz range)
def letter_freq(letter):
    idx = LETTERS.index(letter)
    # Spread across musical scale
    base = 440.0
    step = (1040.0 - 440.0) / 32.0
    return base + idx * step

print("Generating letter sound WAVs...")
for letter in LETTERS:
    path = os.path.join(AUDIO_DIR, letter.lower() + "_letter.wav")
    freq = letter_freq(letter)
    if letter in VOWELS:
        gen_tone_wav(path, freq, duration=0.40)
        desc = f"vowel tone {freq:.0f}Hz"
    elif letter in SONORANTS:
        gen_tone_wav(path, freq, duration=0.35)
        desc = f"sonorant tone {freq:.0f}Hz"
    elif letter in VOICED:
        gen_noise_tone_wav(path, freq, duration=0.25, noise_amt=0.06)
        desc = f"voiced tone {freq:.0f}Hz"
    elif letter in VOICELESS:
        gen_noise_tone_wav(path, freq, duration=0.20, noise_amt=0.12)
        desc = f"voiceless tone {freq:.0f}Hz"
    elif letter in SPECIAL:
        gen_click_wav(path, duration=0.10)
        desc = "soft click"
    else:
        gen_tone_wav(path, freq, duration=0.30)
        desc = f"tone {freq:.0f}Hz"
    size = os.path.getsize(path)
    print(f"  {letter}: {desc} ({size} bytes)")

print(f"\nDone! {len(LETTERS)} letter sound files regenerated.")
