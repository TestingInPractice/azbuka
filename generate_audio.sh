#!/bin/bash
set -e

AUDIO_DIR="/Users/halapinvv/azbuka-pwa/assets/audio"
mkdir -p "$AUDIO_DIR"

voice="Milena"

gen() {
  local text="$1"
  local out="$2"
  local tmp_aiff=$(mktemp /tmp/azbuka_audio_XXXXXX.aiff)
  echo "  Generating: $text -> $(basename $out)"
  say -v "$voice" -o "$tmp_aiff" "$text"
  ffmpeg -y -i "$tmp_aiff" -codec:a libvorbis -q:a 3 "$out" 2>/dev/null
  rm -f "$tmp_aiff"
}

LETTERS=("А" "Б" "В" "Г" "Д" "Е" "Ё" "Ж" "З" "И" "Й" "К" "Л" "М" "Н" "О" "П" "Р" "С" "Т" "У" "Ф" "Х" "Ц" "Ч" "Ш" "Щ" "Ъ" "Ы" "Ь" "Э" "Ю" "Я")
LETTER_NAMES=("А" "Бэ" "Вэ" "Гэ" "Дэ" "Е" "Ё" "Жэ" "Зэ" "И" "И краткое" "Ка" "Эль" "Эм" "Эн" "О" "Пэ" "Эр" "Эс" "Тэ" "У" "Эф" "Ха" "Цэ" "Чэ" "Ша" "Ща" "Твёрдый знак" "Ы" "Мягкий знак" "Э" "Ю" "Я")
WORDS=("Арбуз" "Банан" "Волк" "Гриб" "Дом" "Енот" "Ёж" "Жук" "Зебра" "Ириска" "Йогурт" "Кот" "Лиса" "Медведь" "Носорог" "Окно" "Пингвин" "Рыба" "Сова" "Тигр" "Утка" "Филин" "Хлеб" "Цыпленок" "Черепаха" "Шапка" "Щенок" "Подъезд" "Сыр" "Лось" "Эскимо" "Юла" "Яблоко")

echo "=== Generating letter sounds (33 files) ==="
for i in "${!LETTERS[@]}"; do
  letter="${LETTERS[$i]}"
  name="${LETTER_NAMES[$i]}"
  lc=$(python3 -c "print('$letter'.lower())")
  outfile="$AUDIO_DIR/${lc}_letter.ogg"
  if [ ! -f "$outfile" ]; then
    gen "$name" "$outfile"
  else
    echo "  SKIP: ${lc}_letter.ogg"
  fi
  echo "  [$((i+1))/33] $letter"
done

echo ""
echo "=== Generating word sounds (33 files) ==="
for i in "${!LETTERS[@]}"; do
  letter="${LETTERS[$i]}"
  word="${WORDS[$i]}"
  word_lc=$(python3 -c "print('$word'.lower())")
  outfile="$AUDIO_DIR/${word_lc}.ogg"
  if [ ! -f "$outfile" ]; then
    gen "$word" "$outfile"
  else
    echo "  SKIP: ${word_lc}.ogg"
  fi
  echo "  [$((i+1))/33] $word"
done

echo ""
echo "=== Verification ==="
echo "Expected: 66 files"
actual=$(ls "$AUDIO_DIR"/*.ogg 2>/dev/null | wc -l | xargs)
echo "Generated: $actual files"
ls -la "$AUDIO_DIR"/