extends Node
## ProgressManager: прогресс изучения букв, включённые режимы игр и набор слов.
##
## Хранит изученные буквы, счётчик сыгранных игр, список включённых режимов
## и номер активного набора слов. Состояние сохраняется в user://progress.json.
## Не ссылается на другие автолоады: потребители слушают сигналы
## progress_changed, progress_reset и enabled_modes_changed.

const SAVE_PATH := "user://progress.json"

const DEFAULT_MODES := {
	"azbuka": true,
	"find_letter": true,
	"collect_word": true,
	"guess_picture": true,
}

## Минимальная длина серии карточек в игре «Найди букву».
const SERIES_LENGTH_MIN := 5
## Максимальная длина серии карточек в игре «Найди букву».
const SERIES_LENGTH_MAX := 30
## Длина серии карточек в игре «Найди букву» по умолчанию.
const DEFAULT_SERIES_LENGTH := 10

## Число наборов слов (пока реализован только набор 1).
const WORD_SET_COUNT := 5
## Номер набора слов по умолчанию.
const DEFAULT_WORD_SET := 1

## Число изученных букв изменилось.
signal progress_changed(learned_count: int)

## Прогресс сброшен.
signal progress_reset()

## Набор включённых режимов изменился.
signal enabled_modes_changed(modes: Dictionary)

var learned_letters: Array[String] = []
var games_played_count: int = 0
var enabled_modes: Dictionary = DEFAULT_MODES.duplicate()
## Длина серии карточек в игре «Найди букву» (5-30).
var series_length: int = DEFAULT_SERIES_LENGTH
## Номер активного набора слов (1-WORD_SET_COUNT).
var word_set: int = DEFAULT_WORD_SET


func _ready() -> void:
	load_progress()


func is_letter_completed(letter: String) -> bool:
	return learned_letters.has(letter)


func mark_letter_completed(letter: String) -> void:
	if is_letter_completed(letter):
		return
	learned_letters.append(letter)
	save_progress()
	progress_changed.emit(learned_letters.size())


func get_learned_count() -> int:
	return learned_letters.size()


func reset_progress() -> void:
	learned_letters.clear()
	games_played_count = 0
	save_progress()
	progress_reset.emit()
	progress_changed.emit(0)


func mark_game_played() -> void:
	games_played_count += 1
	save_progress()


func is_mode_enabled(mode_key: String) -> bool:
	return enabled_modes.has(mode_key) and enabled_modes[mode_key] == true


func get_enabled_modes_count() -> int:
	var count := 0
	for mode_key: String in enabled_modes:
		if enabled_modes[mode_key] == true:
			count += 1
	return count


func set_mode_enabled(mode_key: String, enabled: bool) -> void:
	if not enabled_modes.has(mode_key):
		return
	if is_mode_enabled(mode_key) == enabled:
		return
	enabled_modes[mode_key] = enabled
	save_progress()
	enabled_modes_changed.emit(enabled_modes.duplicate())


## Возвращает длину серии карточек в игре «Найди букву».
func get_series_length() -> int:
	return series_length


## Устанавливает длину серии карточек с ограничением 5-30.
func set_series_length(value: int) -> void:
	var clamped := clampi(value, SERIES_LENGTH_MIN, SERIES_LENGTH_MAX)
	if series_length == clamped:
		return
	series_length = clamped
	save_progress()


## Возвращает номер активного набора слов.
func get_word_set() -> int:
	return word_set


## Устанавливает номер набора слов с ограничением 1-WORD_SET_COUNT.
func set_word_set(value: int) -> void:
	var clamped := clampi(value, 1, WORD_SET_COUNT)
	if word_set == clamped:
		return
	word_set = clamped
	save_progress()


func load_progress() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return
	var root := parsed as Dictionary
	if root.has("learned_letters") and root["learned_letters"] is Array:
		learned_letters.clear()
		for raw in root["learned_letters"] as Array:
			learned_letters.append(str(raw))
	if root.has("games_played_count"):
		games_played_count = int(root["games_played_count"])
	if root.has("enabled_modes") and root["enabled_modes"] is Dictionary:
		var saved_modes := root["enabled_modes"] as Dictionary
		for mode_key: String in DEFAULT_MODES:
			if saved_modes.has(mode_key):
				enabled_modes[mode_key] = bool(saved_modes[mode_key])
	if root.has("series_length"):
		series_length = clampi(int(root["series_length"]), SERIES_LENGTH_MIN, SERIES_LENGTH_MAX)
	if root.has("word_set"):
		word_set = clampi(int(root["word_set"]), 1, WORD_SET_COUNT)


func save_progress() -> void:
	var root := {
		"learned_letters": learned_letters,
		"games_played_count": games_played_count,
		"enabled_modes": enabled_modes,
		"series_length": series_length,
		"word_set": word_set,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("ProgressManager: не удалось открыть файл для записи " + SAVE_PATH)
		return
	file.store_string(JSON.stringify(root))
