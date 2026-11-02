# Кнопка буквы: один голос вместо двух

## Проблема

На экране карточки буквы одно нажатие на кнопку буквы звучало двумя голосами:
сначала мужской, сразу за ним женский. Переключатель озвучки в настройках
(«старая»/«новая») на этот звук не влиял, хотя задумывался именно как выбор
голоса.

## Причина

`ui/games/azbuka/letter_card.gd`, `_on_letter_sound_pressed()` играл два файла
подряд:

1. фонему `<буква>_sound_new.ogg` из набора RU-alfavit (Kneiphof, мужской
   голос), затем
2. название буквы `<буква>_letter_new.ogg` из Silero TTS (женский голос).

`AlphabetData.get_letter_sound_path()` не принимает вариант озвучки, поэтому
переключатель в настройках действовал только на название и слова. Оба файла
настоящие и каждый по отдельности верный — ошибка была в их склейке.

## Решение

Кнопка буквы играет ровно один файл — название из выбранного варианта озвучки:

```gdscript
AudioManager.play_stream(SetRepository.get_letter_audio(letter))
```

`SetRepository.get_letter_audio()` уже учитывает
`ProgressManager.get_voice_variant()`, поэтому переключатель в настройках
теперь слышен: «новая» — Silero, «старая» — `*_tts.wav`. У Ъ/Ь фонемы не было и
раньше, они звучат как прежде — названием.

Фонемный API (`SetRepository.get_letter_sound()`) оставлен: он нужен другим
экранам и валидаторам, и удаление сломало бы их контракт.

## Что изменено

| Файл | Изменение |
|------|-----------|
| ui/games/azbuka/letter_card.gd | `_on_letter_sound_pressed()` играет один поток вместо двух |
| tests/validate_letter_voice.gd | Новый валидатор: один файл на нажатие, вариант слышен, Ъ звучит, выключенный звук молчит |
| tests/validate_letter_voice.tscn | Сцена валидатора |

## Как проверено

Все 18 сцен `tests/validate_*.tscn` прогнаны в изолированной копии проекта
(`HOME` на временный каталог, `config/name` копии отличается от настоящего,
реальные данные ребёнка не читаются и не меняются):

| Сцена | Проверок |
|-------|----------|
| validate_letter_voice | 7 |
| validate_test_set_fill | 1249 |
| validate_constructor_ui | 347 |
| validate_custom_sets_integration | 130 |
| validate_image_saver | 126 |
| validate_custom_sets_store | все проверки успешны |
| validate_set_repository | 74 |
| validate_voice_record | 53 |
| validate_active_set_label | 44 |
| validate_sound_toggle | 35 |
| validate_progress_set_id, validate_word_sets, validate_find_letter, validate_ui_changes, validate_letter_translit, validate_audio_transcoder, validate_native_file_picker, validate_web_file_picker | все проверки успешны |

Логи: `suite/`.

## Деплой и проверка live (2026-11-02)

- Экспорт: `godot --headless --path <копия> --export-release "Web" /tmp/azbuka-web/index.html`,
  exit 0. Сборка 36 260 844 байта `index.pck`.
- gh-pages: коммит `b7d4d77` (`deploy: один голос на кнопке буквы и свои данные
  тестового набора; SW cache bump`), изменены `index.html`,
  `index.pck`, `index.service.worker.js`.
- Live: `index.html` 200; `index.pck` 36 260 844 байта; новый
  `CACHE_VERSION = '1793638774|8899297'` (прежний `1791314893|3406668`).
- Playwright, свежая сессия, live-страница: 0 ошибок в консоли, Godot
  загрузился (`canvas` 2214x1814), Service Worker активен с новым именем кэша
  `Азбука-sw-cache-1793638774|8899297`, `__godotAudioCtx` = `running`, 48000 Гц.
  Скриншот: `screens/live-azbuka.png`.

На телефоне после этого достаточно полностью закрыть PWA и открыть заново:
новый `CACHE_VERSION` заставит Service Worker скачать свежие файлы.
Переустановка не нужна, если только старая версия не залипла в кэше.

## Не проверено
- Живое прослушивание на телефоне и отрисовка на Android/в браузере: правка
  меняет только выбор файла, но сам факт «один голос» проверяется ухом.
- В старой озвучке четыре файла названий аномально длинные: `а` 16.1 с,
  `ы` 9.5 с, `п` 9.3 с, `у` 8.6 с (остальные 0.5-0.8 с). Это дефект данных
  старого варианта, а не этой правки; при переключении на «старую» озвучку
  буквы будут звучать долго. Отдельная задача.
- Известный остаточный риск из прошлой работы не изменился: после включения
  звука кнопкой музыка меню не возобновляется до повторного входа на экран.
