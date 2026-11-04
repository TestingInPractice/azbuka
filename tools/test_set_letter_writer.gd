class_name TestSetLetterWriter
extends RefCounted
## Запись одной буквы тестового набора: картинка, звук, метаданные.
##
## Отдельный модуль, чтобы orchestrator (test_set_filler.gd) оставался коротким.
## Здесь живут только операции над буквой, поэтому правила хранения медиа
## (WebP через ImageSaver, звук байт в байт, относительные пути) читаются в
## одном месте и не размазаны по разбору аргументов и поиску набора.
##
## Источник медиа — собственный датасет tools/test_set_data.gd, а не встроенные
## наборы. Копия набора 1 делала тестовый набор неотличимым от встроенного, и
## родитель не понимал, применился ли его набор.

const Files := preload("res://tools/test_set_files.gd")
const Data := preload("res://tools/test_set_data.gd")
## Байты набора — обычная зависимость скрипта, поэтому попадают в веб-PCK.
## Исходные .png/.wav экспорт в PCK не кладёт, и сидер в браузере их не видел.
const Bundle := preload("res://tools/test_set_bundle.res")


## Пишет картинку и звук буквы. Возвращает {error, exported}: пустой error
## означает успех, exported считает скопированные для ручной проверки файлы.
## PNG-байты под именем .webp недопустимы, поэтому картинка идёт через
## ImageSaver, который декодирует и записывает настоящий WebP.
func write(set_id: String, letter: String, export_dir: String) -> Dictionary:
	var key := letter.to_upper()
	var word := str(Bundle.words.get(key, Data.get_word(key)))
	if word.is_empty():
		return _error("нет слова для буквы: " + key)
	var image_bytes := PackedByteArray()
	var audio_bytes := PackedByteArray()
	var extension := "wav"
	if Bundle.images.has(key) and Bundle.audios.has(key):
		image_bytes = Bundle.images[key]
		audio_bytes = Bundle.audios[key]
		extension = str(Bundle.audio_extensions.get(key, "wav"))
	else:
		# Резерв для правки ассетов без пересборки ресурса.
		var image_src := Data.image_path(key)
		var audio_src := Data.audio_path(key)
		if not FileAccess.file_exists(image_src):
			return _error("нет картинки: " + image_src)
		if not FileAccess.file_exists(audio_src):
			return _error("нет звука: " + audio_src)
		image_bytes = FileAccess.get_file_as_bytes(image_src)
		audio_bytes = FileAccess.get_file_as_bytes(audio_src)
		extension = audio_src.get_extension()
	if image_bytes.is_empty():
		return _error("картинка не читается: " + key)
	if audio_bytes.is_empty():
		return _error("звук не читается: " + key)

	var image_target := CustomSetsStore.set_dir(set_id) + CustomSetsStore.image_file_name(key)
	if Bundle.images.has(key):
		# В ресурсе уже готовый WebP: декодировать и перекодировать его в
		# браузере незачем, а на WASM это ещё и минуты блокировки.
		if not Files.write_bytes(image_target, image_bytes):
			return _error("картинка не записалась: " + image_target)
	else:
		var saved := ImageSaver.save_image(image_bytes, image_target)
		if not bool(saved.get("ok", false)):
			return _error("картинка не сохранилась: " + str(saved.get("error", "")))
	var audio_target := CustomSetsStore.set_dir(set_id) \
			+ CustomSetsStore.audio_file_name(key, extension)
	if not Files.write_bytes(audio_target, audio_bytes):
		return _error("звук не записался: " + audio_target)

	var rel_image := Files.relative_user_path(image_target)
	var rel_audio := Files.relative_user_path(audio_target)
	if not CustomSetsStore.set_entry(set_id, key, word, rel_image, rel_audio):
		return _error("set_entry отклонил запись")
	return _export_originals(export_dir, key, word, extension, image_bytes, audio_bytes)


## Копирует исходные PNG и звук под человеческими именами, чтобы родитель мог
## прогнать нативный диалог руками. Копируются оригиналы, а не WebP набора.
func _export_originals(export_dir: String, letter: String, word: String,
		extension: String, image_bytes: PackedByteArray,
		audio_bytes: PackedByteArray) -> Dictionary:
	if export_dir.is_empty():
		return {"error": "", "exported": 0}
	var stem := "%s_%s" % [letter, word]
	if not Files.write_bytes(export_dir.path_join(stem + ".png"), image_bytes):
		return _error("картинка не выгрузилась в " + export_dir)
	if not Files.write_bytes(export_dir.path_join("%s.%s" % [stem, extension]), audio_bytes):
		return _error("звук не выгрузился в " + export_dir)
	return {"error": "", "exported": 2}


## Проверяет запись так, как её увидит игра: полнота и реальные файлы.
## Абсолютный путь в метаданных сломал бы и веб-сборку, и перенос данных.
func verify(set_id: String, letter: String) -> String:
	if not CustomSetsStore.is_entry_complete(set_id, letter):
		return "запись неполная после сохранения"
	var entry := CustomSetsStore.get_entry(set_id, letter)
	var set_prefix := Files.relative_user_path(CustomSetsStore.set_dir(set_id))
	for field: String in ["image", "audio"]:
		var rel := str(entry.get(field, ""))
		if rel.begins_with("user://") or rel.begins_with("/"):
			return "путь %s не относительный: %s" % [field, rel]
		if not rel.begins_with(set_prefix):
			return "путь %s вне каталога набора: %s" % [field, rel]
		if not FileAccess.file_exists("user://" + rel):
			return "файл %s не найден: %s" % [field, rel]
	return ""


func _error(message: String) -> Dictionary:
	return {"error": message, "exported": 0}
