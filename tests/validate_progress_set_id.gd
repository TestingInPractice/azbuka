extends Node
## Валидатор миграции выбора набора: word_set_id рядом со старым word_set.
## Переопределяет save_path на тестовый, чтобы не портить прогресс ребёнка.
## Запуск: godot --headless --path . res://tests/validate_progress_set_id.tscn

const TEST_PATH := "user://progress_set_id_test.json"

var failures := 0


func _ready() -> void:
	await get_tree().process_frame

	# Старый файл сохранения: word_set есть, word_set_id нет.
	_write_legacy_file(3)
	ProgressManager.save_path = TEST_PATH
	ProgressManager.load_progress()

	_check(ProgressManager.get_word_set() == 3, "старый word_set=3 прочитан")
	_check(ProgressManager.get_word_set_id() == "3",
			"миграция вывела word_set_id из word_set (получено: \"%s\")" % ProgressManager.get_word_set_id())
	_check(ProgressManager.get_learned_count() == 2, "изученные буквы не потеряны при миграции")
	_check(ProgressManager.get_series_length() == 7, "series_length не потеряна при миграции")
	_check(ProgressManager.get_voice_variant() == "old", "вариант озвучки не потерян при миграции")
	_check(not ProgressManager.is_mode_enabled("find_letter"), "выключенный режим не потерян")

	# Переключение встроенными номерами синхронизирует оба поля.
	ProgressManager.set_word_set(2)
	_check(ProgressManager.get_word_set() == 2, "set_word_set(2) -> word_set=2")
	_check(ProgressManager.get_word_set_id() == "2", "set_word_set синхронизировал word_set_id")

	# Пользовательский набор.
	ProgressManager.set_word_set_id("c_0a1b2c")
	_check(ProgressManager.get_word_set_id() == "c_0a1b2c", "пользовательский id принят")
	_check(ProgressManager.get_word_set() == ProgressManager.DEFAULT_WORD_SET,
			"int-поле вернулось к DEFAULT_WORD_SET при выборе пользовательского набора")

	# Цифровой id delegирует в set_word_set.
	ProgressManager.set_word_set_id("4")
	_check(ProgressManager.get_word_set_id() == "4", "цифровой id принят как '4'")
	_check(ProgressManager.get_word_set() == 4, "цифровой id выставил word_set=4")

	# Пустой id очищает выбор. get_word_set_id() по контракту всегда непустая,
	# поэтому очистку проверяем на самом поле, а getter — на откате к номеру.
	ProgressManager.set_word_set_id("")
	_check(ProgressManager.word_set_id.is_empty(), "пустой id очистил word_set_id")
	_check(ProgressManager.get_word_set_id() == "4", "после очистки getter вернул номер word_set")

	# reset_progress() НЕ должен сбрасывать выбор набора.
	ProgressManager.mark_letter_completed("А")
	ProgressManager.set_word_set(5)
	ProgressManager.set_word_set_id("c_deadbe")
	ProgressManager.reset_progress()
	_check(ProgressManager.get_learned_count() == 0, "reset_progress очистил изученные буквы")
	_check(ProgressManager.get_word_set_id() == "c_deadbe", "reset_progress НЕ сбросил word_set_id")
	_check(ProgressManager.get_word_set() == ProgressManager.DEFAULT_WORD_SET,
			"reset_progress НЕ оставил word_set=5 в неконсистентном состоянии")

	# Новое поле переживает сохранение/загрузку.
	ProgressManager.set_word_set_id("c_feed01")
	# save_progress() возвращает void, поэтому успех проверяем по наличию файла.
	ProgressManager.save_progress()
	_check(FileAccess.file_exists(TEST_PATH), "save_progress успешен")
	ProgressManager.load_progress()
	_check(ProgressManager.get_word_set_id() == "c_feed01", "word_set_id сохранён на диск")
	_check(ProgressManager.get_word_set() == ProgressManager.DEFAULT_WORD_SET, "word_set сохранён на диск")

	# Инвариант уровня записи, а не отдельного значения: в файле обязаны быть
	# оба ключа, и они обязаны описывать один и тот же выбор.
	var saved := _read_test_file()
	_check(saved.has("word_set") and saved.has("word_set_id"),
			"в файле сохранения есть оба ключа выбора набора")
	_check(str(saved.get("word_set_id", "")) == ProgressManager.get_word_set_id()
			and int(saved.get("word_set", -1)) == ProgressManager.get_word_set(),
			"оба ключа файла согласованы между собой")

	# Отсутствие файла — не ошибка.
	_remove_test_file()
	ProgressManager.load_progress()
	_check(ProgressManager.get_learned_count() == 0, "отсутствие файла не ломает загрузку")

	ProgressManager.save_path = ProgressManager.SAVE_PATH
	_remove_test_file()
	_finish()


## Пишет файл сохранения в старом формате: word_set есть, word_set_id нет.
func _write_legacy_file(word_set_value: int) -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"learned_letters": ["А", "Б"],
		"games_played_count": 3,
		"enabled_modes": {"azbuka": true, "find_letter": false, "collect_word": true, "guess_picture": true},
		"series_length": 7,
		"word_set": word_set_value,
		"voice_variant": "old",
	}))
	file.close()


## Читает файл тестового сохранения целиком ({} если недоступен).
func _read_test_file() -> Dictionary:
	var file := FileAccess.open(TEST_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


func _remove_test_file() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func _check(ok: bool, msg: String) -> void:
	if ok:
		_print("OK: " + msg)
	else:
		_fail(msg)


func _fail(msg: String) -> void:
	failures += 1
	printerr("FAIL: " + msg)


func _print(msg: String) -> void:
	print("[progress_set_id_validate] " + msg)


func _finish() -> void:
	if failures > 0:
		printerr("FAILED: %d проверок" % failures)
		get_tree().quit(1)
	else:
		print("[progress_set_id_validate] PASSED: все проверки успешны")
		get_tree().quit(0)
