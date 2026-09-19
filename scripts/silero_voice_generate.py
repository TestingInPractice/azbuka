#!/usr/bin/env python3
"""
Генерация новой озвучки Азбуки голосом kseniya (Silero TTS, второй ПК).

Читает content/alphabet_data.json, для каждой буквы (33) и каждого слова
из всех наборов (33*5=165) генерирует речь через http://192.168.0.224:8000/tts
(speaker=kseniya, sample_rate=24000), замедляет темп до 0.8 (ffmpeg atempo —
настройки логопеда) и сохраняет в assets/audio/ как {имя}_new.ogg.

Имя файла получается заменой суффикса _tts.wav -> _new.ogg из пути JSON
(а_letter_tts.wav -> а_letter_new.ogg, автобус_tts.wav -> автобус_new.ogg).

Идемпотентный: уже существующие *_new.ogg пропускаются (resume).
"""
import json
import os
import subprocess
import sys
import time
import urllib.request

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # azbuka-src
JSON_PATH = os.path.join(PROJECT, "content", "alphabet_data.json")
AUDIO_DIR = os.path.join(PROJECT, "assets", "audio")
TTS_URL = "http://192.168.0.224:8000/tts"
SPEAKER = "kseniya"
SAMPLE_RATE = 24000
TEMPO = 0.8  # настройки логопеда: замедленный темп
FFMPEG = "/opt/homebrew/bin/ffmpeg"

# Произношение названий букв (из VOICES.md, таблица 1).
LETTER_PRONUNCIATION = {
    "А": "А", "Б": "Бэ", "В": "Вэ", "Г": "Гэ", "Д": "Дэ",
    "Е": "Е", "Ё": "Ё", "Ж": "Жэ", "З": "Зэ", "И": "И",
    "Й": "И краткое", "К": "Ка", "Л": "Эль", "М": "Эм", "Н": "Эн",
    "О": "О", "П": "Пэ", "Р": "Эр", "С": "Эс", "Т": "Тэ",
    "У": "У", "Ф": "Эф", "Х": "Ха", "Ц": "Цэ", "Ч": "Чэ",
    "Ш": "Ша", "Щ": "Ща", "Ъ": "Твёрдый знак", "Ы": "Ы",
    "Ь": "Мягкий знак", "Э": "Э", "Ю": "Ю", "Я": "Я",
}


def tts(text: str, tries: int = 5) -> bytes | None:
    """Вызывает Silero TTS, возвращает wav-байты. Ретраи с паузой."""
    body = json.dumps({
        "text": text,
        "speaker": SPEAKER,
        "sample_rate": SAMPLE_RATE,
    }).encode("utf-8")
    req = urllib.request.Request(
        TTS_URL, data=body, headers={"Content-Type": "application/json"}
    )
    last_err = None
    for attempt in range(1, tries + 1):
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                return resp.read()
        except Exception as e:  # noqa: BLE001 — сеть/HTTP, ретраим
            last_err = e
            time.sleep(2 * attempt)
    print(f"  FAIL текст={text!r}: {last_err}", flush=True)
    return None


def slow_to_ogg(wav_bytes: bytes, out_path: str) -> bool:
    """wav -> ogg 24000 Hz mono c atempo (с сохранением высоты тона)."""
    tmp_wav = out_path + ".tmp.wav"
    with open(tmp_wav, "wb") as f:
        f.write(wav_bytes)
    try:
        cmd = [
            FFMPEG, "-y", "-i", tmp_wav,
            "-filter:a", f"atempo={TEMPO}",
            "-ar", str(SAMPLE_RATE), "-ac", "1",
            "-c:a", "libvorbis", "-q:a", "4",
            out_path,
        ]
        subprocess.run(cmd, capture_output=True, check=True)
        return True
    except subprocess.CalledProcessError as e:
        print(f"  FAIL ffmpeg {out_path}: {e.stderr.decode(errors='replace')[-400:]}", flush=True)
        return False
    finally:
        if os.path.exists(tmp_wav):
            os.remove(tmp_wav)


def collect_tasks() -> list[tuple[str, str]]:
    """Возвращает [(out_file_name, text)] — имя файла *_new.ogg и текст озвучки."""
    with open(JSON_PATH, encoding="utf-8") as f:
        data = json.load(f)
    tasks: list[tuple[str, str]] = []
    for entry in data["letters"]:
        letter = entry["letter"]
        pron = LETTER_PRONUNCIATION.get(letter)
        if pron is None:
            print(f"  WARN нет произношения для буквы {letter!r}, пропускаю", flush=True)
            continue
        letter_audio = entry.get("letter_audio", "")
        # а_letter_tts.wav -> а_letter_new.ogg
        if letter_audio.endswith("_tts.wav"):
            tasks.append((os.path.basename(letter_audio).replace("_tts.wav", "_new.ogg"), pron))
        for _set_id, set_data in entry.get("sets", {}).items():
            word = set_data.get("word", "")
            word_audio = set_data.get("word_audio", "")
            if not word or not word_audio.endswith("_tts.wav"):
                continue
            tasks.append((os.path.basename(word_audio).replace("_tts.wav", "_new.ogg"), word))
    # Убираем дубли (одинаковое имя файла и текст).
    seen: set[str] = set()
    uniq: list[tuple[str, str]] = []
    for name, text in tasks:
        if name in seen:
            continue
        seen.add(name)
        uniq.append((name, text))
    return uniq


def main() -> int:
    os.makedirs(AUDIO_DIR, exist_ok=True)
    tasks = collect_tasks()
    print(f"Всего задач: {len(tasks)} (ожидается 198: 33 буквы + 165 слов)", flush=True)

    ok, skipped, failed = 0, 0, 0
    for i, (name, text) in enumerate(tasks, 1):
        out_path = os.path.join(AUDIO_DIR, name)
        if os.path.exists(out_path) and os.path.getsize(out_path) > 0:
            skipped += 1
            continue
        print(f"[{i}/{len(tasks)}] {name} <- {text!r}", flush=True)
        wav = tts(text)
        if wav is None:
            failed += 1
            continue
        if slow_to_ogg(wav, out_path):
            ok += 1
        else:
            failed += 1

    print(f"\nГотово: {ok} создано, {skipped} пропущено, {failed} ошибок", flush=True)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())