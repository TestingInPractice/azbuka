# Нативный выбор файла для конструктора наборов (2026-10-28)

## Проблема
В десктопном редакторе и в десктопном экспорте Godot кнопки «Картинка» и «Звук из файла» в конструкторе наборов вызывали `WebFilePicker.pick()`, который вне веба сразу возвращал `not_web`. Из-за этого прикрепить файл было невозможно, а игрок видел сообщение «не удалось выбрать картинку».

Лог с устройства: `[INFO] SetEditor: image_pick_failed data={"error":"not_web","letter":"А"}` (см. `logs/godot2026-10-28T19.18.25.log` в user://).

## Решение
Добавлен диспетчер `systems/file_picker.gd` (`FilePicker`) с единым контрактом результата. В вебе он делегирует в `WebFilePicker`, вне веба в `systems/native_file_picker.gd` (`NativeFilePicker`), который открывает `FileDialog` с `use_native_dialog = true`, то есть системное окно выбора файла macOS/Windows/Linux.

## Изменения
- `systems/file_picker.gd`: `backend_for(is_web) -> "web"/"native"`, `pick(kind)` через `await`.
- `systems/native_file_picker.gd`: фильтры по виду файла, маппинг расширения в mime, чтение с проверками `bad_kind/unsupported_type/too_large/read_failed`, `pick()` с заголовками «Выберите картинку»/«Выберите звук», отмена даёт `cancelled`, отсутствие `SceneTree` даёт `no_tree`. Диалог всегда скрывается и удаляется из дерева.
- `ui/constructor/set_editor/set_editor.gd`: `_on_image_requested()` и `_on_audio_requested()` используют `FilePicker.pick(kind)`. Логика сообщений, busy-состояния, `extension_for_mime`, `apply_image`, `apply_audio` не менялась.
- `tests/validate_native_file_picker.gd` и `tests/validate_native_file_picker.tscn`: проверки фильтров, mime, диспетчера бэкендов, успешного чтения из `user://native_picker_test/` с последующей очисткой, `read_failed`, `.m4a` -> `unsupported_type`, превышения лимита через малый внедрённый лимит, `bad_kind` для пустого и неизвестного вида. Отдельно проверяется сам `pick()`: диалог появляется в дереве, эмулируется его сигнал `file_selected`, `pick()` возвращает байты и mime, диалог удаляется из дерева; отмена даёт `cancelled`. Это ровно тот путь, который висел из-за захвата лямбды по значению.

## Почему после выбора файла ничего не происходило
Первая версия складывала выбранный путь в обычную локальную строку и присваивала её из лямбды. В GDScript лямбда захватывает локальные переменные по значению, поэтому запись оставалась внутри копии, внешняя строка всегда была пустой, и `pick()` висел в цикле ожидания вечно. Внешне это выглядело так: системное окно открылось, файл выбран, и дальше ничего.

Проверка (лог `probe_lambda_capture.log`):

```
[probe] scalar='' dict='x.png'
```

Строка осталась пустой, а `Dictionary` изменился, потому что он ссылочный. Поэтому результат пикера теперь живёт в `Dictionary`, и цикл ожидания завершается.

Плюс проверка на настоящих файлах (`probe_real_image.log`): интернет-jpg, jpg с рабочего стола, webp с рабочего стола и png-скриншот прошли `NativeFilePicker.read_file` -> `SetEditor.apply_image`, каждый дал валидный webp нужного размера (800x600, 767x1024, 1024x1024, 1024x211).

## Две правки после первой ревизии
1. Размер файла проверяется до `get_buffer()`. Раньше файл читался целиком и только потом сравнивался с лимитом, из-за чего выбор видеофайла на сотни мегабайт загружал его в память.
2. Ожидание выбора построено на сигналах `file_selected`/`canceled`/`close_requested`, а не на `dialog.visible`. У нативного диалога окном владеет ОС, и цикл по `visible` мог завершиться сразу после `popup()`, вернув `cancelled` без всякого выбора.

## Почему на десктопе нет m4a
AAC на десктопе декодировать нечем: браузерного `AudioContext` там нет, а Godot m4a не читает. Поэтому `.m4a` в фильтры не входит и при прямом вызове чтения даёт `unsupported_type`. Переименовывать m4a в wav нельзя, это дало бы битый файл. Запись с микрофона на десктопе работает как раньше через `VoiceRecord`.

## Проверка изоляции
Все валидаторы запускались только в изолированной копии `/tmp/azbuka-native-picker/` с изменённым `config/name` в `project.godot` (`Азбука-native-picker`), поэтому копия получает собственный `user://`.

Реальный `~/Library/Application Support/Godot/app_userdata/Азбука` не изменился по содержимому: `custom_sets.json` от 19:19, `custom_sets/c_8c3b33` от 19:18, свежайший файл в `logs/` от 19:19, новых записей в каталоге нет.

## Результаты прогонов
Все 14 сцен из `tests/*.tscn` в изолированной копии, логи в `docs/constructor/native-picker-20261028/`:

| Валидатор | Результат |
|---|---|
| `validate_native_file_picker` | PASSED |
| `validate_constructor_ui` | PASSED, 347 проверок |
| `validate_web_file_picker` | PASSED |
| `validate_audio_transcoder` | PASSED |
| `validate_custom_sets_integration` | PASSED, 130 проверок |
| `validate_image_saver` | PASSED, 126 проверок |
| `validate_custom_sets_store` | PASSED |
| `validate_set_repository` | PASSED, 74 проверки |
| `validate_find_letter` | PASSED |
| `validate_letter_translit` | PASSED |
| `validate_progress_set_id` | PASSED |
| `validate_ui_changes` | PASSED |
| `validate_voice_record` | PASSED, 53 проверки |
| `validate_word_sets` | PASSED |

Сообщения `resources still in use at exit` и `RID allocations leaked` в конце части логов относятся к завершению процесса Godot, скрипт к этому моменту уже напечатал `PASSED`.

## Что осталось проверить руками
1. Открыть проект в редакторе, зайти в «Свои наборы» -> набор -> «Картинка», убедиться, что открылось системное окно и выбранный png/jpg/webp появился в слоте.
2. То же для «Звук» -> «Из файла» с wav/ogg/mp3.
3. Нажать «Отмена» в системном окне: должно вернуться «выбор отменён», без зависания.
4. На телефоне в браузере путь остался прежним (`WebFilePicker`), регрессии не ожидается.
