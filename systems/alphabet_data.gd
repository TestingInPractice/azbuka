extends Node
## AlphabetData: доступ к данным алфавита.
##
## Читает content/alphabet_data.json (33 буквы, слова по наборам, пути к
## аудио) и отдаёт данные через статически типизированные методы. Каждая
## запись: letter, letter_audio (общий для всех наборов) и sets —
## словарь наборов слов: {word, word_audio, image}. Сейчас заполнен только
## набор "1". Не ссылается на другие автолоады: потребители берут пути к
## аудио здесь и передают их в AudioManager (инъекция зависимостей на
## месте вызова).

const DATA_PATH := "res://content/alphabet_data.json"

## Данные загружены. letter_count - число букв в наборе.
signal data_loaded(letter_count: int)

var _letters: Array[Dictionary] = []
var _by_letter: Dictionary = {}


func _ready() -> void:
	load_data()


func load_data() -> bool:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("AlphabetData: не удалось открыть " + DATA_PATH)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed == null or not (parsed is Dictionary):
		push_error("AlphabetData: некорректный JSON в " + DATA_PATH)
		return false
	var root: Dictionary = parsed as Dictionary
	if not root.has("letters"):
		push_error("AlphabetData: в JSON отсутствует поле letters")
		return false
	_letters.clear()
	_by_letter.clear()
	for raw in root["letters"] as Array:
		if not (raw is Dictionary):
			continue
		var entry := raw as Dictionary
		if not entry.has("letter") or not entry.has("sets"):
			continue
		var letter := str(entry["letter"])
		_letters.append(entry)
		_by_letter[letter] = entry
	data_loaded.emit(_letters.size())
	return true


func get_letter_count() -> int:
	return _letters.size()


func get_letters() -> Array[Dictionary]:
	return _letters.duplicate()


func get_letter_data(letter: String) -> Dictionary:
	# Ключи в JSON только в верхнем регистре, а слова (например «Банан»)
	# разбиваются на буквы с сохранением регистра: Б, а, н, а, н.
	# Нормализуем ключ, чтобы строчные буквы тоже находили запись.
	var key := letter.to_upper()
	if not _by_letter.has(key):
		return {}
	var entry: Dictionary = _by_letter[key] as Dictionary
	# Старые потребители (guess_picture, collect_word) ожидают плоскую
	# структуру: word и word_audio берём из набора "1", вложенный sets
	# не возвращаем. Самой записи не мутируем.
	var result: Dictionary = entry.duplicate()
	result.erase("sets")
	var set1 := get_word_data(letter)
	if not set1.is_empty():
		result["word"] = set1.get("word", "")
		result["word_audio"] = set1.get("word_audio", "")
	return result


## Данные слова из набора set_id: {word, word_audio, image}.
## Если запрошенный набор отсутствует или пуст — фолбэк на набор "1".
## Если буква неизвестна и набор "1" тоже пуст — {}.
func get_word_data(letter: String, set_id: int = 1) -> Dictionary:
	var key := letter.to_upper()
	if not _by_letter.has(key):
		return {}
	var entry: Dictionary = _by_letter[key] as Dictionary
	var sets: Variant = entry.get("sets")
	if not (sets is Dictionary):
		return {}
	var set_dict: Dictionary = sets as Dictionary
	var data := _set_data(set_dict, set_id)
	if data.is_empty() and set_id != 1:
		data = _set_data(set_dict, 1)
	# Возвращаем копию, чтобы вызывающий код не мог мутировать хранимые данные.
	return data.duplicate()


func get_letter_audio_path(letter: String) -> String:
	var entry := get_letter_data(letter)
	if entry.has("letter_audio"):
		return str(entry["letter_audio"])
	return ""


func get_word_audio_path(letter: String, set_id: int = 1) -> String:
	var data := get_word_data(letter, set_id)
	if data.has("word_audio"):
		return str(data["word_audio"])
	return ""


## Возвращает словарь набора по id или {} если набор отсутствует/пуст.
func _set_data(set_dict: Dictionary, set_id: int) -> Dictionary:
	var data: Variant = set_dict.get(str(set_id))
	if data is Dictionary:
		return data as Dictionary
	return {}
