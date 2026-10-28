class_name TestSetFiles
extends RefCounted
## Файловые операции инструмента наполнения набора.
##
## Вынесены отдельно, потому что у инструмента два вида путей: user:// для
## файлов набора и произвольный абсолютный путь для выгрузки. Смешивать их с
## логикой набора в одном файле тяжело читать, а тесты проверяют обе ветки.

## Разворачивает "~" и "~/..." в домашний каталог, остальное возвращает как есть.
## Оболочка не раскрывает "~" внутри "--export-dir=~/out", поэтому это делает
## сам инструмент.
static func expand_home(path: String) -> String:
	var home := OS.get_environment("HOME")
	if path == "~":
		return home
	if path.begins_with("~/") and not home.is_empty():
		return home.path_join(path.substr(2))
	return path


## Приводит путь к абсолютному: раскрывает "~", а относительный путь считает
## от корня проекта, потому что запуск идёт с --path и текущий каталог процесса
## не обязан совпадать с проектом.
static func resolve_path(path: String) -> String:
	var expanded := expand_home(path)
	if expanded.is_relative_path():
		expanded = ProjectSettings.globalize_path("res://").path_join(expanded)
	return ProjectSettings.globalize_path(expanded)


## Создаёт каталог вместе с родителями. Уже существующий каталог считается успехом.
static func ensure_dir(path: String) -> bool:
	var abs_path := resolve_path(path)
	if DirAccess.dir_exists_absolute(abs_path):
		return true
	return DirAccess.make_dir_recursive_absolute(abs_path) == OK


## Пишет байты целиком. Ошибка открытия или записи даёт false: молча потерять
## медиа нельзя, иначе набор будет выглядеть заполненным без файла.
static func write_bytes(path: String, bytes: PackedByteArray) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	var err := file.get_error()
	file.close()
	return err == OK


## Убирает префикс user://, чтобы путь совпал с тем, что CustomSetsStore
## хранит в метаданных и возвращает из get_entry().
static func relative_user_path(path: String) -> String:
	return path.trim_prefix("user://")
