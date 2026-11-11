extends Node
## Валидатор локального аналитического журнала: событие дописывается в JSONL,
## содержит время, имя события и данные, пустое событие игнорируется,
## выключенная аналитика не пишет строки.
## Путь уводится в тестовый файл: реальный журнал ребёнка не читается и не меняется.
## Запуск: godot --headless --path . res://tests/validate_analytics.tscn

const TEST_PATH := "user://analytics_test/events.jsonl"

var checks := 0
var failures := 0
var _saved_path := ""
var _saved_enabled := true


func _ready() -> void:
	await get_tree().process_frame
	_saved_path = GameLogger.analytics_path
	_saved_enabled = GameLogger.analytics_enabled
	GameLogger.analytics_path = TEST_PATH
	GameLogger.analytics_enabled = true
	_remove_test_file()

	_check_initial_write()
	_check_empty_event_ignored()
	_check_append()
	_check_product_events()
	_check_source_integration()
	_check_disabled()

	GameLogger.analytics_path = _saved_path
	GameLogger.analytics_enabled = _saved_enabled
	_remove_test_file()
	_finish()


func _check_initial_write() -> void:
	GameLogger.analytics("app_open", {"scene": "test"})
	_check(FileAccess.file_exists(TEST_PATH), "аналитика создаёт файл журнала")
	_check(_line_count() == 1, "после первого события в журнале одна строка")
	var entry := _entry_at(0)
	_check(entry.get("event", "") == "app_open", "первое событие называется app_open")
	var data: Dictionary = entry.get("data", {})
	_check(data.get("scene", "") == "test", "данные события сохраняются")
	_check(str(entry.get("ts", "")).length() >= 19, "у события есть отметка времени")


func _check_empty_event_ignored() -> void:
	GameLogger.analytics("", {"scene": "ignored"})
	_check(_line_count() == 1, "пустое имя события не пишет строку")


func _check_append() -> void:
	GameLogger.analytics("game_start", {"game": "azbuka", "level": 2})
	_check(_line_count() == 2, "второе событие дописывается в конец файла")
	var entry := _entry_at(1)
	_check(entry.get("event", "") == "game_start", "второе событие называется game_start")
	var data: Dictionary = entry.get("data", {})
	_check(data.get("game", "") == "azbuka", "ключ игры сохраняется")
	_check(int(data.get("level", 0)) == 2, "уровень сохраняется числом")


func _check_product_events() -> void:
	GameLogger.analytics("round_complete", {
		"game": "guess_picture", "round": 3, "total": 10, "duration_ms": 1200,
	})
	var round_entry := _entry_at(2)
	var round_data: Dictionary = round_entry.get("data", {})
	_check(round_entry.get("event", "") == "round_complete", "событие раунда называется round_complete")
	_check(int(round_data.get("round", 0)) == 3, "номер раунда сохраняется")
	_check(int(round_data.get("duration_ms", -1)) >= 0, "длительность раунда неотрицательна")

	GameLogger.analytics("game_complete", {
		"game": "find_letter", "completed": 10, "total": 10, "duration_ms": 9000,
	})
	var complete_entry := _entry_at(3)
	var complete_data: Dictionary = complete_entry.get("data", {})
	_check(complete_entry.get("event", "") == "game_complete", "финал игры называется game_complete")
	_check(int(complete_data.get("completed", 0)) == 10, "game_complete хранит число завершённых шагов")

	GameLogger.analytics("game_abandon", {
		"game": "collect_word", "reason": "back", "completed": 2, "duration_ms": 4500,
	})
	var abandon_entry := _entry_at(4)
	var abandon_data: Dictionary = abandon_entry.get("data", {})
	_check(abandon_entry.get("event", "") == "game_abandon", "отвал называется game_abandon")
	_check(abandon_data.get("reason", "") == "back", "причина отвала сохраняется")

	GameLogger.analytics("level_complete", {
		"game": "azbuka", "level": 1, "letters": 11, "total_levels": 3,
	})
	var level_entry := _entry_at(5)
	var level_data: Dictionary = level_entry.get("data", {})
	_check(level_entry.get("event", "") == "level_complete", "уровень азбуки называется level_complete")
	_check(int(level_data.get("letters", 0)) == 11, "level_complete хранит число букв уровня")


## Проверяет, что события не только описаны в логгере, но и реально
## вызываются из игровых экранов. Это ловит забытый call site при рефакторинге.
func _check_source_integration() -> void:
	_check_source_has("res://ui/games/guess_picture/guess_picture.gd", [
		'analytics("round_complete"', 'analytics("game_complete"', 'analytics("game_abandon"',
	], "guess_picture")
	_check_source_has("res://ui/games/find_letter/find_letter.gd", [
		'analytics("round_complete"', 'analytics("game_complete"', 'analytics("game_abandon"',
	], "find_letter")
	_check_source_has("res://ui/games/collect_word/collect_word.gd", [
		'analytics("round_complete"', 'analytics("game_abandon"',
	], "collect_word")
	_check_source_has("res://ui/games/azbuka/letter_card_word_game.gd", [
		'analytics("level_complete"',
	], "level_complete")


func _check_source_has(path: String, needles: Array[String], label: String) -> void:
	var source := FileAccess.get_file_as_string(path)
	if source.is_empty():
		_check(false, "%s: исходник не читается" % label)
		return
	for needle in needles:
		_check(source.contains(needle), "%s: есть вызов %s" % [label, needle])


func _check_disabled() -> void:
	var before := _line_count()
	GameLogger.analytics_enabled = false
	GameLogger.analytics("app_open", {"scene": "disabled"})
	_check(_line_count() == before, "выключенная аналитика не пишет строки")
	GameLogger.analytics_enabled = true


func _line_count() -> int:
	if not FileAccess.file_exists(TEST_PATH):
		return 0
	var file := FileAccess.open(TEST_PATH, FileAccess.READ)
	if file == null:
		return 0
	var count := 0
	while not file.eof_reached():
		if not file.get_line().is_empty():
			count += 1
	return count


func _entry_at(index: int) -> Dictionary:
	if not FileAccess.file_exists(TEST_PATH):
		return {}
	var file := FileAccess.open(TEST_PATH, FileAccess.READ)
	if file == null:
		return {}
	var current := 0
	while not file.eof_reached():
		var line := file.get_line()
		if line.is_empty():
			continue
		if current == index:
			var parsed: Variant = JSON.parse_string(line)
			if parsed is Dictionary:
				return parsed
			return {}
		current += 1
	return {}


func _remove_test_file() -> void:
	var absolute_path := ProjectSettings.globalize_path(TEST_PATH)
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(absolute_path)
	var dir := absolute_path.get_base_dir()
	if DirAccess.dir_exists_absolute(dir):
		DirAccess.remove_absolute(dir)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("[analytics_validate] OK: %s" % message)
	else:
		failures += 1
		printerr("[analytics_validate] FAIL: %s" % message)


func _finish() -> void:
	if failures > 0:
		printerr("FAILED: %d из %d проверок" % [failures, checks])
		get_tree().quit(1)
	else:
		print("[analytics_validate] PASSED: %d проверок" % checks)
		get_tree().quit(0)
