extends Node
## CustomSetsStore: хранение пользовательских наборов букв.
##
## Владеет CRUD наборов и их персистентностью. Метаданные лежат в
## user://custom_sets.json, файлы букв — в user://custom_sets/<set_id>/.
## Ключ записи — буква, а не набор: набор всегда разреженный, родитель сам
## выбирал буквы. Не ссылается на другие автолоады: пути и содержимое файлов
## передаются снаружи (store ничего не декодирует и не грузит).
## Возвращает копии словарей, чтобы вызывающий не мог мутировать хранилище.

const SCHEMA_VERSION := 1
const DEFAULT_SAVE_PATH := "user://custom_sets.json"
const SETS_DIR := "user://custom_sets"
## Число букв русского алфавита — критерий полноты набора.
const FULL_SET_SIZE := 33
## Порядок русского алфавита — для сортировки букв в списках.
const LETTER_ORDER := "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ"

## Метаданты наборов изменились (создание, переименование, удаление, правка букв).
signal sets_changed

## Путь к JSON с метаданными. Тесты переопределяют, чтобы не трогать данные ребёнка.
var save_path: String = DEFAULT_SAVE_PATH

var _sets: Array[Dictionary] = []


func _ready() -> void:
	load_sets()


## Очищает хранилище в памяти без обращения к диску. Для тестов и сброса.
func clear_memory() -> void:
	_sets.clear()


## Загружает метаданные из save_path. Отсутствующий файл — не ошибка:
## возвращается true с пустым хранилищем (первый запуск).
func load_sets() -> bool:
	if not FileAccess.file_exists(save_path):
		clear_memory()
		sets_changed.emit()
		return true
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_error("CustomSetsStore: не удалось открыть " + save_path)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed == null or not (parsed is Dictionary):
		push_error("CustomSetsStore: некорректный JSON в " + save_path)
		return false
	var root: Dictionary = parsed as Dictionary
	clear_memory()
	var raw_sets: Variant = root.get("sets")
	if raw_sets is Array:
		for raw in raw_sets as Array:
			if not (raw is Dictionary):
				continue
			var entry: Dictionary = raw as Dictionary
			if not entry.has("id") or not entry.has("letters"):
				continue
			if not (entry["letters"] is Dictionary):
				continue
			_sets.append(entry)
	sets_changed.emit()
	return true


## Сохраняет метаданты в save_path. false, если файл не открылся.
func save_sets() -> bool:
	var root := {
		"version": SCHEMA_VERSION,
		"sets": _sets,
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("CustomSetsStore: не удалось открыть файл для записи " + save_path)
		return false
	file.store_string(JSON.stringify(root))
	file.close()
	sets_changed.emit()
	return true


## Все наборы (глубокая копия).
func get_sets() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in _sets:
		out.append((entry as Dictionary).duplicate(true))
	return out


## Набор по id или {} если нет.
func get_set_by_id(set_id: String) -> Dictionary:
	for entry in _sets:
		if str(entry.get("id", "")) == set_id:
			return (entry as Dictionary).duplicate(true)
	return {}


## Создаёт набор. Пустое имя (в т.ч. из пробелов) отклоняется — возвращает {}.
func create_set(set_name: String) -> Dictionary:
	var trimmed := set_name.strip_edges()
	if trimmed.is_empty():
		return {}
	var entry := {
		"id": make_set_id(),
		"name": trimmed,
		"letters": {},
	}
	_sets.append(entry)
	if not save_sets():
		_sets.pop_back()
		return {}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(set_dir(str(entry["id"]))))
	return entry.duplicate(true)


## Переименовывает набор. false если набора нет или имя пустое.
func rename_set(set_id: String, new_name: String) -> bool:
	var trimmed := new_name.strip_edges()
	if trimmed.is_empty():
		return false
	for entry in _sets:
		if str(entry.get("id", "")) == set_id:
			(entry as Dictionary)["name"] = trimmed
			return save_sets()
	return false


## Удаляет набор вместе с папкой его файлов. false если набора нет.
func delete_set(set_id: String) -> bool:
	for i in _sets.size():
		if str(_sets[i].get("id", "")) != set_id:
			continue
		_sets.remove_at(i)
		_remove_set_dir(set_id)
		return save_sets()
	return false


## Запись буквы: {word, image, audio}. Пути хранятся относительно корня
## user:// (без префикса "user://"), и лишний префикс срезается на входе —
## иначе вызывающий, сложивший путь через set_dir(), получил бы в метаданных
## "user://user://custom_sets/...".
##
## Запись может быть НЕПОЛНОЙ: родитель печатает слово раньше, чем выберет
## картинку и запишет звук, и незавершённая работа не должна теряться при
## перезапуске. Полноту проверяет отдельный is_entry_complete().
##
## Регистр буквы не важен — "а" пишет в запись "А".
## false если набора нет, буква пустая или все три поля пустые.
func set_entry(set_id: String, letter: String, word: String, image: String, audio: String) -> bool:
	var key := letter.to_upper()
	var clean_word := word.strip_edges()
	var clean_image := _relative_to_user_root(image)
	var clean_audio := _relative_to_user_root(audio)
	if key.is_empty():
		return false
	if clean_word.is_empty() and clean_image.is_empty() and clean_audio.is_empty():
		return false
	for entry in _sets:
		if str(entry.get("id", "")) != set_id:
			continue
		var letters: Dictionary = entry["letters"] as Dictionary
		letters[key] = {
			"word": clean_word,
			"image": clean_image,
			"audio": clean_audio,
		}
		return save_sets()
	return false


## Убирает префикс "user://" из пути: в метаданных пути хранятся
## относительно корня user://, а вызывающий может передать как относительный
## путь, так и уже готовый абсолютный.
static func _relative_to_user_root(path: String) -> String:
	var trimmed := path.strip_edges()
	if trimmed.begins_with("user://"):
		trimmed = trimmed.trim_prefix("user://")
	while trimmed.begins_with("/"):
		trimmed = trimmed.trim_prefix("/")
	return trimmed


## Запись буквы или {}.
func get_entry(set_id: String, letter: String) -> Dictionary:
	var key := letter.to_upper()
	for entry in _sets:
		if str(entry.get("id", "")) != set_id:
			continue
		var letters: Dictionary = entry.get("letters", {}) as Dictionary
		if letters.has(key):
			return (letters[key] as Dictionary).duplicate(true)
		return {}
	return {}


## Удаляет user://-файлы буквы (картинка и аудио). Метаданные не трогает.
## Отсутствие файлов не считается ошибкой.
func clear_entry_files(set_id: String, letter: String) -> void:
	var key := letter.to_upper()
	var entry := get_entry(set_id, key)
	if entry.is_empty():
		return
	for field: String in ["image", "audio"]:
		var rel := str(entry.get(field, ""))
		if rel.is_empty():
			continue
		var abs_path := ProjectSettings.globalize_path("user://" + rel)
		if FileAccess.file_exists(abs_path):
			DirAccess.remove_absolute(abs_path)


## Запись полная — есть слово, картинка и аудио.
func is_entry_complete(set_id: String, letter: String) -> bool:
	var entry := get_entry(set_id, letter)
	if entry.is_empty():
		return false
	return not str(entry.get("word", "")).is_empty() \
			and not str(entry.get("image", "")).is_empty() \
			and not str(entry.get("audio", "")).is_empty()


## Буквы набора по русскому алфавиту.
func get_set_letters(set_id: String) -> Array[String]:
	var raw := PackedStringArray()
	for entry in _sets:
		if str(entry.get("id", "")) != set_id:
			continue
		var dict: Dictionary = entry.get("letters", {}) as Dictionary
		for key: String in dict.keys():
			raw.append(key)
		break
	var out: Array[String] = []
	for letter in raw:
		out.append(letter)
	out.sort_custom(_sort_letters)
	return out


## Сколько букв заполнено в наборе.
func get_set_letter_count(set_id: String) -> int:
	return get_set_letters(set_id).size()


## Набор полон — все 33 буквы заполнены.
func is_set_complete(set_id: String) -> bool:
	return get_set_letter_count(set_id) >= FULL_SET_SIZE


## Доступно ли хранилище для записи. Вне web (тесты, десктоп) — всегда true.
## В вебе — спрашиваем IDB: при false данные могут не пережить перезапуск.
func is_storage_available() -> bool:
	if not OS.has_feature("web"):
		return true
	return OS.is_userfs_persistent()


## Генерирует уникальный id набора: "c_" + 6 hex-символов.
func make_set_id() -> String:
	for _attempt in 32:
		var candidate := "c_%06x" % (randi() & 0xFFFFFF)
		var clash := false
		for entry in _sets:
			if str(entry.get("id", "")) == candidate:
				clash = true
				break
		if not clash:
			return candidate
	return "c_%06x" % (Time.get_ticks_usec() & 0xFFFFFF)


## Папка набора с файлами букв.
func set_dir(set_id: String) -> String:
	return "%s/%s/" % [SETS_DIR, set_id]


## Имя файла картинки буквы: "img_<ascii>.webp".
func image_file_name(letter: String) -> String:
	return "img_%s.webp" % LetterTranslit.to_ascii(letter)


## Имя файла озвучки буквы: "aud_<ascii>.<extension>". Расширение приходит
## от источника и по умолчанию wav: запись с микрофона всегда WAV, а
## загруженный файл сохраняет своё. Расширение обязано быть настоящим —
## Godot определяет формат аудио по имени файла, а не по содержимому, и mp3,
## названный .wav, просто не загрузится.
func audio_file_name(letter: String, extension: String = "wav") -> String:
	var ext := extension.strip_edges().to_lower().trim_prefix(".")
	if ext.is_empty() or not ext.is_valid_filename():
		ext = "wav"
	return "aud_%s.%s" % [LetterTranslit.to_ascii(letter), ext]


## Расширение аудиофайла из mime-типа браузера. Всё, чего здесь нет,
## отвергается: неизвестный формат всё равно нечем будет проиграть.
static func extension_for_mime(mime: String) -> String:
	match mime.to_lower().split(";")[0].strip_edges():
		"audio/wav", "audio/wave", "audio/x-wav":
			return "wav"
		"audio/ogg", "audio/vorbis", "audio/oga":
			return "ogg"
		"audio/mpeg", "audio/mp3":
			return "mp3"
		"audio/mp4", "audio/x-m4a":
			return "m4a"
	return ""


## Порядок русского алфавита для сортировки букв набора.
func _sort_letters(a: String, b: String) -> bool:
	return LETTER_ORDER.find(a) < LETTER_ORDER.find(b)


## Удаляет папку набора и её содержимое. Отсутствие — не ошибка.
func _remove_set_dir(set_id: String) -> void:
	var base := ProjectSettings.globalize_path(SETS_DIR)
	var abs_path := base.path_join(set_id)
	if not DirAccess.dir_exists_absolute(abs_path):
		return
	var dir := DirAccess.open(abs_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var sub_name := dir.get_next()
	while sub_name != "":
		var sub_path := abs_path.path_join(sub_name)
		if dir.current_is_dir():
			_remove_absolute_dir(sub_path)
		else:
			DirAccess.remove_absolute(sub_path)
		sub_name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(abs_path)


## Рекурсивное удаление произвольной папки по абсолютному пути.
func _remove_absolute_dir(abs_path: String) -> void:
	var dir := DirAccess.open(abs_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var sub_name := dir.get_next()
	while sub_name != "":
		var sub_path := abs_path.path_join(sub_name)
		if dir.current_is_dir():
			_remove_absolute_dir(sub_path)
		else:
			DirAccess.remove_absolute(sub_path)
		sub_name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(abs_path)
