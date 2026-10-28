class_name FilePicker
extends RefCounted
## Диспетчер выбора файла: в вебе использует WebFilePicker, иначе NativeFilePicker.
##
## Единый контракт для обоих бэкендов: {ok: bool, bytes: PackedByteArray, mime: String, name: String, error: String}.
## Статический класс без состояния.

## Возвращает имя бэкенда для текущей платформы.
static func backend_for(is_web: bool) -> String:
	if is_web:
		return "web"
	return "native"


## Выбирает файл нужного вида через подходящий бэкенд.
static func pick(kind: String) -> Dictionary:
	if OS.has_feature("web"):
		return await WebFilePicker.pick(kind)
	return await NativeFilePicker.pick(kind)
