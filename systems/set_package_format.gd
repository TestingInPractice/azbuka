class_name SetPackageFormat
extends RefCounted
## Формат пакета набора .azset: manifest, пути, расширения и лимиты.
##
## Класс чистый: не читает файлы и не знает про UI. Все проверки возвращают
## коды ошибок, а человеческий текст собирает user_message().

const FORMAT := "azbuka-set"
const VERSION := 1
const EXTENSION := "azset"
const MANIFEST_NAME := "manifest.json"

const LETTER_ORDER := "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ"
const IMAGE_EXTENSIONS := ["webp", "png", "jpg", "jpeg"]
const AUDIO_EXTENSIONS := ["wav", "ogg", "mp3"]

const MAX_PACKAGE_BYTES := 25 * 1024 * 1024
const MAX_MANIFEST_BYTES := 256 * 1024
const MAX_IMAGE_BYTES := 5 * 1024 * 1024
const MAX_AUDIO_BYTES := 10 * 1024 * 1024
const MAX_TOTAL_UNCOMPRESSED_BYTES := 60 * 1024 * 1024
const MAX_WORD_LENGTH := 40
const MAX_NAME_LENGTH := 60
const MAX_FILES := 80


## Собирает manifest из записей набора. Порядок букв стабилен.
static func build_manifest(set_name: String, entries: Dictionary) -> Dictionary:
	var normalized_name := set_name.strip_edges()
	if normalized_name.length() > MAX_NAME_LENGTH:
		normalized_name = normalized_name.substr(0, MAX_NAME_LENGTH)
	var letters := {}
	for letter_index in LETTER_ORDER.length():
		var letter := LETTER_ORDER[letter_index]
		var source_key := ""
		for raw_key in entries.keys():
			if normalize_letter(str(raw_key)) == letter:
				source_key = str(raw_key)
				break
		if source_key.is_empty():
			continue
		var source_value: Variant = entries[source_key]
		if not (source_value is Dictionary):
			continue
		var source: Dictionary = source_value
		var item := {}
		var word := str(source.get("word", "")).strip_edges()
		if not word.is_empty():
			item["word"] = word.substr(0, MAX_WORD_LENGTH)
		var image := str(source.get("image", "")).strip_edges()
		if not image.is_empty():
			item["image"] = image
		var audio := str(source.get("audio", "")).strip_edges()
		if not audio.is_empty():
			item["audio"] = audio
		if not item.is_empty():
			letters[letter] = item
	return {
		"format": FORMAT,
		"version": VERSION,
		"name": normalized_name,
		"letters": letters,
	}


## Проверяет manifest и файлы архива. Возвращает {ok, error, manifest}.
static func validate_manifest(raw: Variant, files: Dictionary) -> Dictionary:
	if not (raw is Dictionary):
		return _failure("bad_manifest")
	var manifest: Dictionary = raw
	if str(manifest.get("format", "")) != FORMAT:
		return _failure("bad_format")
	if int(manifest.get("version", -1)) != VERSION:
		return _failure("bad_version")
	var set_name := str(manifest.get("name", "")).strip_edges()
	if set_name.is_empty():
		return _failure("empty_name")
	if set_name.length() > MAX_NAME_LENGTH:
		return _failure("name_too_long")
	var raw_letters: Variant = manifest.get("letters", null)
	if not (raw_letters is Dictionary):
		return _failure("bad_letters")
	var source_letters: Dictionary = raw_letters
	if source_letters.is_empty():
		return _failure("bad_letters")
	if source_letters.size() > LETTER_ORDER.length():
		return _failure("too_many_letters")
	var letters := {}
	for raw_key in source_letters.keys():
		var letter := normalize_letter(str(raw_key))
		if letter.length() != 1 or not LETTER_ORDER.contains(letter):
			return _failure("unknown_letter")
		if letters.has(letter):
			return _failure("duplicate_letter")
		var raw_entry: Variant = source_letters[raw_key]
		if not (raw_entry is Dictionary):
			return _failure("bad_entry")
		var entry: Dictionary = raw_entry
		var word := str(entry.get("word", "")).strip_edges()
		if word.length() > MAX_WORD_LENGTH:
			return _failure("word_too_long")
		var item := {}
		if not word.is_empty():
			item["word"] = word
		var image := str(entry.get("image", "")).strip_edges()
		if not image.is_empty():
			var image_check := safe_relative_path(image, "images/")
			if not bool(image_check.get("ok", false)):
				return _failure(str(image_check.get("error", "bad_path")))
			var normalized_image := str(image_check.get("path", ""))
			if not IMAGE_EXTENSIONS.has(extension_of(normalized_image)):
				return _failure("bad_extension")
			if not files.has(normalized_image):
				return _failure("missing_media")
			var image_blob: Variant = files[normalized_image]
			if typeof(image_blob) != TYPE_PACKED_BYTE_ARRAY:
				return _failure("empty_media")
			var image_bytes: PackedByteArray = image_blob
			if image_bytes.is_empty():
				return _failure("empty_media")
			if image_bytes.size() > MAX_IMAGE_BYTES:
				return _failure("too_large")
			item["image"] = normalized_image
		var audio := str(entry.get("audio", "")).strip_edges()
		if not audio.is_empty():
			var audio_check := safe_relative_path(audio, "audio/")
			if not bool(audio_check.get("ok", false)):
				return _failure(str(audio_check.get("error", "bad_path")))
			var normalized_audio := str(audio_check.get("path", ""))
			if not AUDIO_EXTENSIONS.has(extension_of(normalized_audio)):
				return _failure("bad_extension")
			if not files.has(normalized_audio):
				return _failure("missing_media")
			var audio_blob: Variant = files[normalized_audio]
			if typeof(audio_blob) != TYPE_PACKED_BYTE_ARRAY:
				return _failure("empty_media")
			var audio_bytes: PackedByteArray = audio_blob
			if audio_bytes.is_empty():
				return _failure("empty_media")
			if audio_bytes.size() > MAX_AUDIO_BYTES:
				return _failure("too_large")
			item["audio"] = normalized_audio
		if item.is_empty():
			return _failure("empty_entry")
		letters[letter] = item
	return {
		"ok": true,
		"error": "",
		"manifest": {
			"format": FORMAT,
			"version": VERSION,
			"name": set_name,
			"letters": letters,
		},
	}


## Нормализует букву: обрезает пробелы и поднимает регистр.
static func normalize_letter(letter: String) -> String:
	return letter.strip_edges().to_upper()


## Проверяет относительный путь внутри images/ или audio/.
static func safe_relative_path(path: String, prefix: String) -> Dictionary:
	var clean := path.strip_edges()
	if clean.is_empty():
		return _failure("empty_path")
	if clean.begins_with("/") or clean.begins_with("\\"):
		return _failure("bad_path")
	if clean.contains("\\") or clean.contains("://"):
		return _failure("bad_path")
	if clean.length() >= 2 and clean.substr(1, 1) == ":":
		return _failure("bad_path")
	var expected_prefix := prefix.trim_suffix("/") + "/"
	if not clean.begins_with(expected_prefix):
		return _failure("bad_path")
	var parts := clean.split("/", true)
	if parts.size() < 2:
		return _failure("bad_path")
	for part in parts:
		if part.is_empty() or part == "." or part == "..":
			return _failure("bad_path")
		if not part.is_valid_filename():
			return _failure("bad_path")
	return {"ok": true, "error": "", "path": clean}


## Расширение пути в нижнем регистре, без точки.
static func extension_of(path: String) -> String:
	return path.get_extension().to_lower()


## Пустая строка, если размер пакета допустим, иначе код ошибки.
static func check_package_size(size_bytes: int) -> String:
	if size_bytes > MAX_PACKAGE_BYTES:
		return "too_large"
	return ""


## Пустая строка, если распакованный размер допустим, иначе код ошибки.
static func check_uncompressed_size(size_bytes: int) -> String:
	if size_bytes > MAX_TOTAL_UNCOMPRESSED_BYTES:
		return "too_large"
	return ""


## Человеческий текст по коду ошибки.
static func user_message(code: String) -> String:
	match code:
		"cancelled":
			return "выбор отменён"
		"bad_archive":
			return "не удалось прочитать файл набора"
		"missing_manifest":
			return "в файле нет manifest.json"
		"bad_manifest":
			return "manifest.json повреждён"
		"bad_format":
			return "это не файл набора Азбуки"
		"bad_version":
			return "версия файла не поддерживается"
		"empty_name":
			return "в наборе нет названия"
		"name_too_long":
			return "название набора слишком длинное"
		"bad_letters":
			return "в наборе нет букв"
		"too_many_letters":
			return "в наборе слишком много букв"
		"unknown_letter":
			return "в наборе есть неизвестная буква"
		"duplicate_letter":
			return "в наборе повторяется буква"
		"bad_entry":
			return "запись буквы повреждена"
		"empty_entry":
			return "у буквы нет ни слова, ни картинки, ни звука"
		"word_too_long":
			return "слишком длинное слово"
		"bad_path", "empty_path":
			return "в наборе недопустимый путь к файлу"
		"bad_extension":
			return "неподдерживаемый формат файла"
		"missing_media":
			return "в наборе нет файла, указанного в manifest.json"
		"empty_media":
			return "файл в наборе пустой"
		"too_large":
			return "файл набора слишком большой"
		"too_many_files":
			return "в наборе слишком много файлов"
		"no_set":
			return "набор не найден"
		"no_entries":
			return "в наборе нет заполненных букв"
		"write_failed", "read_failed":
			return "не удалось сохранить файл набора"
		"unsupported_type":
			return "формат файла не поддерживается"
		_:
			return "не удалось обработать набор"


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "error": code, "manifest": {}}
