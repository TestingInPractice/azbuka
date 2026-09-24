#!/usr/bin/env python3
"""Перегенерация всей новой озвучки «Азбуки» голосом kseniya (локальный Silero).

Отличие от scripts/silero_voice_generate.py:
  * ходит на локальный сервис (http://localhost:8000), а не на выключенный второй ПК;
  * ПЕРЕЗАПИСЫВАЕТ существующие *_new.ogg (а не пропускает их, как resume-версия);
  * берёт названия букв из content/alphabet_data.json (letter_name, с ударениями U+0301),
    а не из внутреннего словаря;
  * обходит баг Silero на одиночном символе «ё» (см. PRONUNCIATION_OVERRIDES);
  * темп 0.7 вместо 0.8 — «логопед для детей 2 лет» (regen 2026-09-21);
  * TTS-запрос на 48000 Hz (как в регене 21.09 — громкость), ogg на выходе 24000 Hz;
  * текст БЕЗ знаков препинания: точка делает Silero тише и длиннее (диагноз 22.09).

Файлы _tts.wav («Старая озвучка») НЕ трогаются: перегенерация только _new.ogg.

Использование:
    python3 scripts/silero_regenerate_new_ogg.py --dry-run   # показать 198 задач
    python3 scripts/silero_regenerate_new_ogg.py             # перегенерировать всё
    python3 scripts/silero_regenerate_new_ogg.py --only-missing  # только отсутствующие
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
import urllib.request

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # azbuka-src
JSON_PATH = os.path.join(PROJECT, "content", "alphabet_data.json")
AUDIO_DIR = os.path.join(PROJECT, "assets", "audio")

TTS_URL = "http://localhost:8000/tts"
SPEAKER = "kseniya"
# ВАЖНО (диагноз 2026-09-22): локальный Silero на sample_rate=48000 отдаёт
# аудио примерно на 4 dB громче, чем на 24000 (проверено volumedetect:
# Вэ@48000 max=-2.7 dB vs Вэ@24000 max=-6.7 dB). Все «хорошие» *_new.ogg
# (21.09) были сделаны через запрос @48000, поэтому TTS_SAMPLE_RATE=48000,
# а итоговый ogg всё равно ресемплится до 24000 Hz в slow_to_ogg().
TTS_SAMPLE_RATE = 48000
SAMPLE_RATE = 24000  # выходной ogg (как у всех существующих *_new.ogg)
TEMPO = 0.7  # логопедический темп: медленно и раздельно (для детей 2 лет)
FFMPEG = "/opt/homebrew/bin/ffmpeg"
MIN_DURATION = 0.15  # сек; короче — считаем файл битым
MIN_BYTES = 1000
# Точку НЕ добавляем (диагноз 2026-09-22): с завершающей «точкой» Silero
# резко тише («Бэ.» max=-20.3 dB vs «Бэ» max=-6.9 dB) и длиннее. Все «хорошие»
# *_new.ogg (21.09) сгенерированы БЕЗ знаков препинания (bare text).
APPEND_PERIOD = False

# Silero падает с HTTP 500 на одиночном символе «ё» (проверено: все голоса, все флаги,
# варианты «Ё!», «Ё.», «Ёё»). Декомпозированное «е + U+0308» читается как «е».
# «Йо» = /jo/ — ровно то, как произносится буква «Ё».
PRONUNCIATION_OVERRIDES = {"Ё": "Йо"}

# Фолбэк, если в JSON почему-то нет letter_name (актуальный источник — сам JSON).
LETTER_FALLBACK = {
    "А": "А", "Б": "Бэ", "В": "Вэ", "Г": "Гэ", "Д": "Дэ",
    "Е": "Е", "Ё": "Йо", "Ж": "Жэ", "З": "Зэ", "И": "И",
    "Й": "И́ кра́ткое", "К": "Ка", "Л": "Эль", "М": "Эм", "Н": "Эн",
    "О": "О", "П": "Пэ", "Р": "Эр", "С": "Эс", "Т": "Тэ",
    "У": "У", "Ф": "Эф", "Х": "Ха", "Ц": "Цэ", "Ч": "Чэ",
    "Ш": "Ша", "Щ": "Ща", "Ъ": "Твёрдый знак", "Ы": "Ы",
    "Ь": "Мя́гкий знак", "Э": "Э", "Ю": "Ю", "Я": "Я",
}


def tts(text: str, tries: int = 5) -> bytes | None:
    """POST /tts -> wav-байты. Ретраи с линейной паузой."""
    body = json.dumps({
        "text": text,
        "speaker": SPEAKER,
        "sample_rate": TTS_SAMPLE_RATE,
    }).encode("utf-8")
    last_err = None
    for attempt in range(1, tries + 1):
        req = urllib.request.Request(
            TTS_URL, data=body, headers={"Content-Type": "application/json"}
        )
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                return resp.read()
        except Exception as e:  # noqa: BLE001 — сеть/HTTP, ретраим
            last_err = e
            time.sleep(2 * attempt)
    print(f"  FAIL текст={text!r}: {last_err}", flush=True)
    return None


def slow_to_ogg(wav_bytes: bytes, out_path: str) -> bool:
    """wav -> ogg 24000 Hz mono, atempo=TEMPO (высота тона сохраняется)."""
    tmp_wav = out_path + ".tmp.wav"
    with open(tmp_wav, "wb") as f:
        f.write(wav_bytes)
    try:
        subprocess.run(
            [
                FFMPEG, "-y", "-i", tmp_wav,
                "-filter:a", f"atempo={TEMPO}",
                "-ar", str(SAMPLE_RATE), "-ac", "1",
                "-c:a", "libvorbis", "-q:a", "4",
                out_path,
            ],
            capture_output=True,
            check=True,
        )
        return True
    except subprocess.CalledProcessError as e:
        print(f"  FAIL ffmpeg {out_path}: {e.stderr.decode(errors='replace')[-400:]}", flush=True)
        return False
    finally:
        if os.path.exists(tmp_wav):
            os.remove(tmp_wav)


def duration_of(path: str) -> float:
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "default=noprint_wrappers=1:nokey=1", path],
        capture_output=True, text=True,
    ).stdout.strip()
    try:
        return float(out)
    except ValueError:
        return 0.0


def _final_text(text: str) -> str:
    """Текст для TTS с завершающей «точкой» (APPEND_PERIOD), если её ещё нет."""
    if APPEND_PERIOD and not text.endswith((".", "!", "?", "…")):
        return text.strip() + "."
    return text


def collect_tasks() -> list[tuple[str, str]]:
    """[(имя *_new.ogg, текст озвучки)] из content/alphabet_data.json."""
    with open(JSON_PATH, encoding="utf-8") as f:
        data = json.load(f)
    tasks: list[tuple[str, str]] = []
    for entry in data["letters"]:
        letter = entry["letter"]
        pron = PRONUNCIATION_OVERRIDES.get(letter) or entry.get("letter_name") or LETTER_FALLBACK.get(letter)
        if not pron:
            print(f"  WARN нет произношения для буквы {letter!r}, пропускаю", flush=True)
            continue
        letter_audio = entry.get("letter_audio", "")
        if letter_audio.endswith("_tts.wav"):
            tasks.append((os.path.basename(letter_audio).replace("_tts.wav", "_new.ogg"), _final_text(pron)))
        for set_data in entry.get("sets", {}).values():
            word = set_data.get("word", "")
            word_audio = set_data.get("word_audio", "")
            if word and word_audio.endswith("_tts.wav"):
                tasks.append((os.path.basename(word_audio).replace("_tts.wav", "_new.ogg"), _final_text(word)))
    seen: set[str] = set()
    uniq: list[tuple[str, str]] = []
    for name, text in tasks:
        if name not in seen:
            seen.add(name)
            uniq.append((name, text))
    return uniq


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true", help="только показать задачи")
    ap.add_argument("--only-missing", action="store_true", help="не трогать существующие файлы")
    args = ap.parse_args()

    tasks = collect_tasks()
    print(f"Задач: {len(tasks)} (ожидается 198 = 33 буквы + 165 слов)", flush=True)
    if args.dry_run:
        for name, text in tasks:
            mark = "есть" if os.path.exists(os.path.join(AUDIO_DIR, name)) else "нет "
            print(f"  [{mark}] {name:<28} <- {text!r}")
        return 0

    ok = skipped = failed = 0
    for i, (name, text) in enumerate(tasks, 1):
        out_path = os.path.join(AUDIO_DIR, name)
        if args.only_missing and os.path.exists(out_path) and os.path.getsize(out_path) >= MIN_BYTES:
            skipped += 1
            continue
        print(f"[{i}/{len(tasks)}] {name} <- {text!r}", flush=True)
        wav = tts(text)
        if wav is None:
            failed += 1
            continue
        if not slow_to_ogg(wav, out_path):
            failed += 1
            continue
        dur = duration_of(out_path)
        if os.path.getsize(out_path) < MIN_BYTES or dur < MIN_DURATION:
            print(f"  FAIL битый результат: {dur:.3f}s", flush=True)
            failed += 1
            continue
        ok += 1

    print(f"\nГотово: {ok} создано, {skipped} пропущено, {failed} ошибок", flush=True)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
