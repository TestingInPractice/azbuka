extends Node
## Валидатор звука кнопки буквы: на одно нажатие играет ровно один файл, и это
## название буквы из выбранного в настройках варианта озвучки. Фонема из набора
## RU-alfavit больше не подмешивается, иначе ребёнок слышал мужской голос, а
## сразу за ним женский, и переключатель озвучки на этот звук не влиял.
## Путь прогресса уводится на тестовый файл: данные ребёнка не читаются.
## Запуск: godot --headless --path . res://tests/validate_letter_voice.tscn

const TEST_PROGRESS_PATH := "user://progress_letter_voice_test.json"
const LETTER_CARD_SCENE := "res://ui/games/azbuka/letter_card.tscn"
const WAIT_AFTER_PHONEME := 0.6

var checks := 0
var failures := 0
var _saved_progress_path := ""
var _saved_variant := ""
var _saved_sound := true


func _ready() -> void:
	await get_tree().process_frame
	_saved_progress_path = ProgressManager.save_path
	_saved_variant = ProgressManager.get_voice_variant()
	_saved_sound = AudioManager.sound_enabled
	ProgressManager.save_path = TEST_PROGRESS_PATH
	_remove_test_file()
	ProgressManager.set_voice_variant(ProgressManager.VOICE_VARIANT_NEW)
	AudioManager.set_sound_enabled(true)

	await _check_variant_new()
	await _check_variant_old()
	await _check_soft_sign_fallback()
	await _check_sound_off()

	ProgressManager.set_voice_variant(_saved_variant)
	AudioManager.set_sound_enabled(_saved_sound)
	ProgressManager.save_path = _saved_progress_path
	_remove_test_file()
	_finish()


## Вариант "new": одно нажатие — один файл Silero, без фонемы.
func _check_variant_new() -> void:
	# given: в настройках выбрана новая озвучка
	ProgressManager.set_voice_variant(ProgressManager.VOICE_VARIANT_NEW)
	var card := await _spawn_card("А")

	# when: ребёнок жмёт кнопку буквы
	_press_letter(card)
	var played := _played_path()

	# then: играет название из нового набора, а не фонема
	var expected := AlphabetData.get_letter_audio_path("А", ProgressManager.VOICE_VARIANT_NEW)
	_check(played == expected, "вариант new: играет название буквы (получено: %s)" % played)
	_check(not played.contains("_sound.") and not played.contains("_sound_"),
			"вариант new: фонема не подмешивается")

	# when: фонема успела бы закончиться
	await get_tree().create_timer(WAIT_AFTER_PHONEME).timeout

	# then: второй звук не запускался — трек тот же
	_check(_played_path() == expected or not _player_playing(),
			"вариант new: после нажатия не играет второй голос")

	await _free(card)


## Вариант "old": переключатель в настройках слышен.
func _check_variant_old() -> void:
	# given: в настройках выбрана старая озвучка
	ProgressManager.set_voice_variant(ProgressManager.VOICE_VARIANT_OLD)
	var card := await _spawn_card("А")

	# when: ребёнок жмёт кнопку буквы
	_press_letter(card)
	var played := _played_path()

	# then: играет файл старой озвучки, отличный от нового
	var expected := AlphabetData.get_letter_audio_path("А", ProgressManager.VOICE_VARIANT_OLD)
	_check(played == expected, "вариант old: играет название старой озвучки (получено: %s)" % played)
	_check(played != AlphabetData.get_letter_audio_path("А", ProgressManager.VOICE_VARIANT_NEW),
			"варианты озвучки различаются на слух")
	await _free(card)


## У Ъ/Ь нет фонемы — звук всё равно должен быть.
func _check_soft_sign_fallback() -> void:
	# given: вариант new и открыта карточка Ъ
	ProgressManager.set_voice_variant(ProgressManager.VOICE_VARIANT_NEW)
	var card := await _spawn_card("Ъ")

	# when: ребёнок жмёт кнопку буквы
	_press_letter(card)

	# then: звук есть и это название буквы
	_check(not _played_path().is_empty(), "у Ъ кнопка буквы звучит")
	await _free(card)


## При выключенном звуке кнопка молчит.
func _check_sound_off() -> void:
	# given: звук выключен
	AudioManager.stop_all()
	var card := await _spawn_card("А")
	AudioManager.set_sound_enabled(false)

	# when: ребёнок жмёт кнопку буквы
	_press_letter(card)

	# then: плеер не запущен
	_check(not _player_playing(), "выключенный звук: кнопка буквы молчит")
	AudioManager.set_sound_enabled(true)
	await _free(card)


func _spawn_card(letter: String) -> Node:
	LetterCard.from_letter = letter
	var scene: PackedScene = load(LETTER_CARD_SCENE)
	var instance: Node = scene.instantiate()
	add_child(instance)
	await get_tree().process_frame
	await get_tree().process_frame
	return instance


func _press_letter(card: Node) -> void:
	var button := card.get_node_or_null("%ButtonLetter") as Button
	if button == null:
		_check(false, "у карточки есть кнопка буквы")
		return
	button.pressed.emit()


## Путь потока, который сейчас стоит в плеере. Плеер общий на приложение.
func _played_path() -> String:
	var player: AudioStreamPlayer = AudioManager._player
	if player == null or player.stream == null:
		return ""
	return player.stream.resource_path


func _player_playing() -> bool:
	var player: AudioStreamPlayer = AudioManager._player
	return player != null and player.playing


func _remove_test_file() -> void:
	var abs_path := ProjectSettings.globalize_path(TEST_PROGRESS_PATH)
	if FileAccess.file_exists(abs_path):
		DirAccess.remove_absolute(abs_path)


func _free(node: Node) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame


func _check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("[letter_voice_validate] OK: " + message)
	else:
		failures += 1
		printerr("[letter_voice_validate] FAIL: " + message)


func _finish() -> void:
	if failures > 0:
		printerr("[letter_voice_validate] FAILED: %d из %d проверок" % [failures, checks])
		get_tree().quit(1)
	else:
		print("[letter_voice_validate] PASSED: %d проверок" % checks)
		get_tree().quit(0)
