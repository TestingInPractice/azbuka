extends Node

var completed_letters: Array[String] = []
var games_played: int = 0
var last_played: String = ""

var enabled_modes := {
	"alphabet": true,
	"find_letter": true,
	"collect_word": true,
	"guess_picture": true,
}

signal enabled_modes_changed

const SAVE_PATH := "user://progress.json"
const TOTAL_LETTERS := 33

func _ready():
	load_progress()

func load_progress():
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var data = JSON.parse_string(file.get_as_text())
		if data is Dictionary:
			var raw = data.get("completed_letters", [])
			if raw is Array:
				completed_letters.clear()
				for c in raw:
					if c is String:
						completed_letters.append(c)
			games_played = data.get("games_played", 0)
			last_played = data.get("last_played", "")
			var modes = data.get("enabled_modes", {})
			if modes is Dictionary:
				for key in enabled_modes:
					if key in modes and modes[key] is bool:
						enabled_modes[key] = modes[key]
		file.close()

func save_progress():
	var data := {
		"completed_letters": completed_letters,
		"games_played": games_played,
		"last_played": last_played,
		"enabled_modes": enabled_modes.duplicate(),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func mark_letter_completed(letter_id: String):
	if not letter_id in completed_letters:
		completed_letters.append(letter_id)
		games_played += 1
		last_played = Time.get_date_string_from_system()
		save_progress()

func mark_game_played():
	games_played += 1
	last_played = Time.get_date_string_from_system()
	save_progress()

func is_letter_completed(letter_id: String) -> bool:
	return letter_id in completed_letters

func get_completed_count() -> int:
	return completed_letters.size()

func is_mode_enabled(mode: String) -> bool:
	return enabled_modes.get(mode, true)

func set_mode_enabled(mode: String, value: bool):
	enabled_modes[mode] = value
	save_progress()
	enabled_modes_changed.emit()

func get_enabled_modes_count() -> int:
	var count := 0
	for key in enabled_modes:
		if enabled_modes[key]:
			count += 1
	return count

func reset_progress():
	completed_letters.clear()
	games_played = 0
	last_played = ""
	save_progress()

func get_total_letters() -> int:
	return TOTAL_LETTERS
