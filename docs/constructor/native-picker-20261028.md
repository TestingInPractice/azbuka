# Нативный выбор файла для конструктора наборов (2026-10-28)

## Проблема
В десктопном редакторе/экспорте Godot кнопки «Картинка» и «Звук из файла» в конструкторе наборов вызывали `WebFilePicker.pick()`, который вне веба сразу возвращал `not_web`. Из-за этого прикрепить файл было невозможно.

## Решение
Добавлен диспетчер `systems/file_picker.gd` (`FilePicker`) с единым контрактом результата. В вебе он делегирует в `WebFilePicker`, в десктопе — в `systems/native_file_picker.gd` (`NativeFilePicker`) через `FileDialog` с `use_native_dialog = true`.

## Изменения
- `systems/file_picker.gd`: `backend_for(is_web) -> "web"/"native"`, `pick(kind)` с ожиданием через `await`.
- `systems/native_file_picker.gd`: фильтры по виду, маппинг расширения в mime, чтение с проверками `bad_kind/unsupported_type/too_large/read_failed`, `pick()` с `FileDialog` (заголовки «Выберите картинку»/«Выберите звук»), отмена -> `cancelled`, отсутствие `SceneTree` -> `no_tree`. Диалог всегда удаляется из дерева.
- `ui/constructor/set_editor/set_editor.gd`: `_on_image_requested()` и `_on_audio_requested()` используют `FilePicker.pick(kind)`. Логика сообщений, busy-состояния и сохранения не менялась.
- `tests/validate_native_file_picker.gd` + `tests/validate_native_file_picker.tscn`: проверки фильтров, mime, бэкенд-диспетчера, успешного чтения из `user://native_picker_test/` с последующей очисткой, `read_failed`, `.m4a` -> `unsupported_type`, превышение лимита через малый лимит, `bad_kind` для пустого/неизвестного вида.

## Проверка изоляции
Валидаторы запускались только в изолированной копии `/tmp/azbuka-native-picker/` с изменённым `config/name` в `project.godot`. Реальный `~/Library/Application Support/Godot/app_userdata/Азбука` не изменялся (см. логи в `docs/constructor/native-picker-20261028/`).

## Результаты прогонов
См. файлы логов в папке `docs/constructor/native-picker-20261028/`.
