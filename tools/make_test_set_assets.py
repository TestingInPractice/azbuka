#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Генератор медиа собственного тестового набора.

Зачем: тестовый набор раньше копировал слова, картинки и звуки встроенного
набора 1, поэтому родитель не мог отличить свой набор от встроенного. Здесь
создаются НОВЫЕ карточки и НОВАЯ озвучка для 33 своих слов.

Всё детерминировано: цвет карточки выводится из sha256 буквы, поэтому
повторный запуск без --force ничего не перезаписывает, а с --force даёт
побайтово те же PNG.

Запуск:
    python3 tools/make_test_set_assets.py [--force]

Выход: tools/test_set_assets/<БУКВА>.png и <БУКВА>.wav.
Код возврата 1, если хотя бы одна буква не собралась.
"""

from __future__ import annotations

import colorsys
import hashlib
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

PROJECT_ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = PROJECT_ROOT / "tools" / "test_set_assets"
FONT_PATH = PROJECT_ROOT / "assets" / "fonts" / "NotoSans-Regular.ttf"

# Слова с ударением живут в данных набора. На картинке и в TTS ударение
# убирается: комбинирующий U+0301 ломает перенос и звучит как пауза.
STRESS = "\u0301"
WORDS = {
    "А": "Альбо́м",
    "Б": "Бу́блик",
    "В": "Ви́шня",
    "Г": "Гнездо́",
    "Д": "Ды́ня",
    "Е": "Единоро́г",
    "Ё": "Ё́мкость",
    "Ж": "Жасми́н",
    "З": "Зе́ркало",
    "И": "Имби́рь",
    "Й": "Йо́га",
    "К": "Коза́",
    "Л": "Ло́дка",
    "М": "Моро́женое",
    "Н": "Но́ра",
    "О": "О́блако",
    "П": "Помидо́р",
    "Р": "Ре́па",
    "С": "Су́мка",
    "Т": "Ту́ча",
    "У": "Укро́п",
    "Ф": "Фона́рь",
    "Х": "Хо́бот",
    "Ц": "Ци́фра",
    "Ч": "Чесно́к",
    "Ш": "Шмель",
    "Щ": "Щаве́ль",
    "Ъ": "Разъе́зд",
    "Ы": "Бык",
    "Ь": "Лось",
    "Э": "Эта́ж",
    "Ю": "Ю́нга",
    "Я": "Я́ма",
}

LETTERS = list(WORDS.keys())
CANVAS = 1024
CARD_INSET = 32
CARD_RADIUS = 72
TEXT_COLOR = (31, 36, 48, 255)
BADGE_TEXT_COLOR = (31, 36, 48, 255)
LETTER_FONT_SIZE = 560
LETTER_CENTER_Y = 340
WORD_CENTER_Y = 800
WORD_FONT_SIZE = 112
MIN_WORD_FONT_SIZE = 72
BADGE_FONT_SIZE = 36
MIN_CONTRAST = 4.5


def plain(word: str) -> str:
    return word.replace(STRESS, "")


def letter_color(letter: str) -> tuple[int, int, int]:
    digest = hashlib.sha256(letter.encode("utf-8")).digest()
    hue = int.from_bytes(digest[:2], "big") / 65535.0
    lightness = 0.80 + (digest[2] / 255.0) * 0.08
    saturation = 0.48 + (digest[3] / 255.0) * 0.14
    # Пастель: высокая светлота держит тёмный текст читаемым на любом тоне.
    red, green, blue = colorsys.hls_to_rgb(hue, lightness, saturation)
    return (round(red * 255), round(green * 255), round(blue * 255))


def relative_luminance(color: tuple[int, int, int]) -> float:
    channels = []
    for value in color[:3]:
        norm = value / 255.0
        channels.append(norm / 12.92 if norm <= 0.03928 else ((norm + 0.055) / 1.055) ** 2.4)
    return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]


def contrast_ratio(first: tuple[int, int, int], second: tuple[int, int, int]) -> float:
    high = max(relative_luminance(first), relative_luminance(second))
    low = min(relative_luminance(first), relative_luminance(second))
    return (high + 0.05) / (low + 0.05)


def load_font(size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONT_PATH), size)


def text_size(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.FreeTypeFont) -> tuple[int, int]:
    left, top, right, bottom = draw.textbbox((0, 0), text, font=font)
    return right - left, bottom - top


def wrap_word(draw: ImageDraw.ImageDraw, word: str, font: ImageFont.FreeTypeFont,
              max_width: int) -> list[str]:
    """Переносит слово по пробелам. Одно длинное слово не рвётся: его ужимает
    вызывающий код, потому что рваное слово на детской карточке читать нельзя."""
    if text_size(draw, word, font)[0] <= max_width:
        return [word]
    lines: list[str] = []
    current = ""
    for chunk in word.split(" "):
        candidate = chunk if not current else current + " " + chunk
        if text_size(draw, candidate, font)[0] <= max_width:
            current = candidate
            continue
        if current:
            lines.append(current)
        current = chunk
    if current:
        lines.append(current)
    return lines


def draw_card(letter: str) -> Image.Image:
    word = plain(WORDS[letter])
    background = letter_color(letter)
    if contrast_ratio(background, TEXT_COLOR) < MIN_CONTRAST:
        raise ValueError("низкий контраст %s: %.2f" % (letter, contrast_ratio(background, TEXT_COLOR)))

    image = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle(
        (CARD_INSET, CARD_INSET, CANVAS - CARD_INSET, CANVAS - CARD_INSET),
        radius=CARD_RADIUS,
        fill=background + (255,),
    )

    card_left = CARD_INSET
    card_right = CANVAS - CARD_INSET
    card_width = card_right - card_left
    margin = 56
    max_text_width = card_width - margin * 2

    letter_font = load_font(LETTER_FONT_SIZE)
    # anchor="mm" ставит центр глифа ровно в точку, без поправки на ascent:
    # у NotoSans верхний отступ bbox почти 0.35 em, и рисование от левого
    # верхнего угла уводило букву в нижнюю половину карточки.
    draw.text((CANVAS // 2, LETTER_CENTER_Y), letter, font=letter_font,
              fill=TEXT_COLOR, anchor="mm")

    word_font = load_font(WORD_FONT_SIZE)
    lines = wrap_word(draw, word, word_font, max_text_width)
    widest = max(text_size(draw, line, word_font)[0] for line in lines)
    size = WORD_FONT_SIZE
    while widest > max_text_width and size > MIN_WORD_FONT_SIZE:
        size -= 4
        word_font = load_font(size)
        lines = wrap_word(draw, word, word_font, max_text_width)
        widest = max(text_size(draw, line, word_font)[0] for line in lines)
    line_height = size + 18
    first_center = WORD_CENTER_Y - (len(lines) - 1) * line_height // 2
    for index, line in enumerate(lines):
        draw.text((CANVAS // 2, first_center + index * line_height), line,
                  font=word_font, fill=TEXT_COLOR, anchor="mm")

    badge_font = load_font(BADGE_FONT_SIZE)
    badge_text = "ТЕСТ"
    badge_width, badge_height = text_size(draw, badge_text, badge_font)
    pad_x, pad_y = 22, 12
    pill_width = badge_width + pad_x * 2
    pill_height = badge_height + pad_y * 2
    pill_left = card_right - margin - pill_width
    pill_top = CARD_INSET + 40
    draw.rounded_rectangle(
        (pill_left, pill_top, pill_left + pill_width, pill_top + pill_height),
        radius=pill_height // 2,
        fill=(255, 255, 255, 235),
    )
    draw.text(
        (pill_left + pill_width // 2, pill_top + pill_height // 2),
        badge_text,
        font=badge_font,
        fill=BADGE_TEXT_COLOR,
        anchor="mm",
    )

    if contrast_ratio((255, 255, 255), BADGE_TEXT_COLOR) < MIN_CONTRAST:
        raise ValueError("низкий контраст бейджа: %s" % letter)
    return image


def png_is_valid(path: Path) -> bool:
    if not path.exists():
        return False
    try:
        with Image.open(path) as image:
            return image.size == (CANVAS, CANVAS) and image.mode == "RGBA"
    except Exception:
        return False


def wav_is_valid(path: Path) -> bool:
    if not path.exists() or path.stat().st_size == 0:
        return False
    try:
        with wave.open(str(path), "rb") as handle:
            if handle.getframerate() != 24000 or handle.getnchannels() != 1 \
                    or handle.getsampwidth() != 2:
                return False
            return handle.getnframes() / handle.getframerate() > 0.2
    except Exception:
        return False


def make_png(letter: str, force: bool) -> str:
    target = OUT_DIR / (letter + ".png")
    if target.exists() and not force and png_is_valid(target):
        return "png оставлен (%d байт)" % target.stat().st_size
    draw_card(letter).save(target, format="PNG", optimize=True)
    if not png_is_valid(target):
        raise RuntimeError("PNG не прошёл проверку: " + str(target))
    return "png создан (%d байт)" % target.stat().st_size


def make_wav(letter: str, force: bool) -> str:
    target = OUT_DIR / (letter + ".wav")
    if target.exists() and not force and wav_is_valid(target):
        return "wav оставлен (%d байт)" % target.stat().st_size
    with tempfile.TemporaryDirectory() as tmp:
        aiff = Path(tmp) / "word.aiff"
        spoken = subprocess.run(
            ["say", "-v", "Milena", plain(WORDS[letter]), "-o", str(aiff)],
            capture_output=True,
            text=True,
        )
        if spoken.returncode != 0:
            raise RuntimeError("say: " + spoken.stderr.strip())
        converted = subprocess.run(
            [
                "ffmpeg", "-y", "-loglevel", "error", "-i", str(aiff),
                "-ar", "24000", "-ac", "1", "-c:a", "pcm_s16le", str(target),
            ],
            capture_output=True,
            text=True,
        )
        if converted.returncode != 0:
            raise RuntimeError("ffmpeg: " + converted.stderr.strip())
    if not wav_is_valid(target):
        raise RuntimeError("WAV не прошёл проверку: " + str(target))
    return "wav создан (%d байт)" % target.stat().st_size


def main(argv: list[str]) -> int:
    force = "--force" in argv
    unknown = [arg for arg in argv if arg not in ("--force",)]
    if unknown:
        print("неизвестный аргумент: " + unknown[0], file=sys.stderr)
        return 1
    if not FONT_PATH.exists():
        print("нет шрифта: " + str(FONT_PATH), file=sys.stderr)
        return 1

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    failures = 0
    for letter in LETTERS:
        try:
            png_state = make_png(letter, force)
            wav_state = make_wav(letter, force)
            print("[test_set_assets] %s: %s, %s" % (letter, plain(WORDS[letter]), png_state + ", " + wav_state))
        except Exception as error:  # noqa: BLE001 - инструмент обязан пережить одну букву
            failures += 1
            print("[test_set_assets] %s: ОШИБКА %s" % (letter, error), file=sys.stderr)

    print("[test_set_assets] букв: %d, ошибок: %d, каталог: %s" % (len(LETTERS), failures, OUT_DIR))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
