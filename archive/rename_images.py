#!/usr/bin/env python3
import os, json

img_dir = "/Users/halapinvv/azbuka-pwa/assets/images"

# Map: Cyrillic filename -> desired Latin filename
mapping = {
    "арбуз.png": "arbuz.png", "банан.png": "banan.png", "волк.png": "volk.png",
    "гриб.png": "grib.png", "дом.png": "dom.png", "енот.png": "enot.png",
    "ёж.png": "yozh.png", "жук.png": "zhuk.png", "зебра.png": "zebra.png",
    "ириска.png": "iriska.png", "йогурт.png": "yogurt.png", "кот.png": "kot.png",
    "лиса.png": "lisa.png", "медведь.png": "medved.png", "носорог.png": "nosorog.png",
    "окно.png": "okno.png", "пингвин.png": "pingvin.png", "рыба.png": "ryba.png",
    "сова.png": "sova.png", "тигр.png": "tigr.png", "утка.png": "utka.png",
    "филин.png": "filin.png", "хлеб.png": "hleb.png", "цыпленок.png": "cyplenok.png",
    "черепаха.png": "cherepaha.png", "шапка.png": "shapka.png", "щенок.png": "shenok.png",
    "подъезд.png": "podjezd.png", "сыр.png": "syr.png", "лось.png": "los.png",
    "эскимо.png": "eskimo.png", "юла.png": "yula.png", "яблоко.png": "yabloko.png",
}

for src, dst in mapping.items():
    src_path = os.path.join(img_dir, src)
    dst_path = os.path.join(img_dir, dst)
    if os.path.exists(src_path) and not os.path.exists(dst_path):
        os.rename(src_path, dst_path)
        print(f"  {src} -> {dst}")
    elif os.path.exists(dst_path):
        print(f"  SKIP (exists): {dst}")

# Verify all files present
expected = list(mapping.values())
actual = [f for f in os.listdir(img_dir) if f.endswith(".png")]
missing = set(expected) - set(actual)
if missing:
    print(f"\nMISSING: {missing}")
else:
    print(f"\nAll {len(expected)} images ready")
