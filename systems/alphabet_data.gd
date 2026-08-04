extends Node
## AlphabetData: доступ к данным алфавита.
##
## Читает content/alphabet_data.json (33 буквы, слова, пути к аудио) и отдаёт
## данные через статически типизированные методы. Не ссылается на другие
## автолоады: потребители берут пути к аудио здесь и передают их в
## AudioManager (инъекция зависимостей на месте вызова).

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
		if not entry.has("letter") or not entry.has("word"):
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
	if _by_letter.has(letter):
		return (_by_letter[letter] as Dictionary).duplicate()
	return {}


func get_letter_audio_path(letter: String) -> String:
	var entry := get_letter_data(letter)
	if entry.has("letter_audio"):
		return str(entry["letter_audio"])
	return ""


func get_word_audio_path(letter: String) -> String:
	var entry := get_letter_data(letter)
	if entry.has("word_audio"):
		return str(entry["word_audio"])
	return ""
