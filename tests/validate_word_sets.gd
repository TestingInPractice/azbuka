extends Node
## Валидатор нового формата alphabet_data.json (наборы слов) и API
## AlphabetData.get_word_data: фолбэк набора "1", старый get_letter_data,
## пути к аудио слова. Автолоады AlphabetData/ProgressManager доступны,
## т.к. сцена запускается как корневая через --path.
## Запуск: godot --headless --path . res://tests/validate_word_sets.tscn

var failures := 0


func _ready() -> void:
	await get_tree().process_frame

	# 1. Слово из набора 1.
	var data1: Dictionary = AlphabetData.get_word_data("А", 1)
	_check(data1.get("word", "") == "Автобус",
			"get_word_data(\"А\", 1)[\"word\"] == \"Автобус\" (получено: %s)" % str(data1.get("word", "")))

	# 2. Слово из набора 2 (заполнен: генерация второго набора).
	var data2: Dictionary = AlphabetData.get_word_data("А", 2)
	_check(data2.get("word", "") == "Арбуз",
			"get_word_data(\"А\", 2)[\"word\"] == \"Арбуз\" (получено: %s)" % str(data2.get("word", "")))
	_check(str(data2.get("image", "")) == "generated/Watermelon",
			"get_word_data(\"А\", 2)[\"image\"] == \"generated/Watermelon\" (получено: %s)" % str(data2.get("image", "")))
	_check(data2.get("word_audio", "") == "res://assets/audio/автобус_tts.wav",
			"набор 2 использует общий звук-заглушку (получено: %s)" % str(data2.get("word_audio", "")))

	# 3. Путь к аудио слова по умолчанию (set_id = 1).
	var audio: String = AlphabetData.get_word_audio_path("А")
	_check(audio == "res://assets/audio/автобус_tts.wav",
			"get_word_audio_path(\"А\") (получено: %s)" % audio)

	# 4. Старое поведение get_letter_data сохранено: word из набора 1,
	#    вложенный sets наружу не отдаём.
	var legacy: Dictionary = AlphabetData.get_letter_data("А")
	_check(legacy.get("word", "") == "Автобус",
			"get_letter_data(\"А\")[\"word\"] == \"Автобус\" (получено: %s)" % str(legacy.get("word", "")))
	_check(not legacy.has("sets"),
			"get_letter_data(\"А\") не содержит вложенный sets")

	# 5. Картинка из набора 1.
	_check(str(data1.get("image", "")) == "Bus",
			"get_word_data(\"А\", 1)[\"image\"] == \"Bus\" (получено: %s)" % str(data1.get("image", "")))

	_finish()


func _check(ok: bool, msg: String) -> void:
	if ok:
		_print("OK: " + msg)
	else:
		_fail(msg)


func _fail(msg: String) -> void:
	failures += 1
	printerr("FAIL: " + msg)


func _print(msg: String) -> void:
	print("[word_sets_validate] " + msg)


func _finish() -> void:
	if failures > 0:
		printerr("FAILED: %d проверок" % failures)
		get_tree().quit(1)
	else:
		print("[word_sets_validate] PASSED: все проверки успешны")
		get_tree().quit(0)
