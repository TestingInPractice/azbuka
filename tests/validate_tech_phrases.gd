extends Node
## Валидатор переключателя технических фраз: дефолт, сохранение, загрузка,
## молчание служебных фраз и независимость слов/звуков карточек.
## Путь прогресса уводится на тестовый файл: данные ребёнка не читаются.
## Запуск: godot --headless --path . res://tests/validate_tech_phrases.tscn

const TEST_PATH := "user://progress_tech_phrases_test.json"
const PROMPT_PATH := "res://assets/audio/prompt_correct.wav"

var checks := 0
var failures := 0
var _saved_progress_path := ""
var _saved_tech_enabled := true
var _saved_sound := true


func _ready() -> void:
	await get_tree().process_frame

	_saved_progress_path = ProgressManager.save_path
	_saved_tech_enabled = ProgressManager.tech_phrases_enabled
	_saved_sound = AudioManager.sound_enabled
	ProgressManager.save_path = TEST_PATH
	_remove_test_file()

	_check_default_on()
	_check_turn_off_persists()
	_check_restore_off()
	_check_gate_blocks_phrase()
	_check_content_audio_still_plays()
	_check_turn_on_allows_phrase()
	_check_sound_off_still_blocks()
	_check_legacy_file_defaults_on()
	_check_non_bool_defaults_on()
	await _check_settings_toggle()

	ProgressManager.save_path = _saved_progress_path
	ProgressManager.tech_phrases_enabled = _saved_tech_enabled
	AudioManager.set_sound_enabled(_saved_sound)
	_remove_test_file()
	_finish()


## Новый менеджер прогресса без файла обязан считать фразы включёнными.
func _check_default_on() -> void:
	# given: свежий ProgressManager, который ещё ничего не загружал
	var fresh: Node = load("res://systems/progress_manager.gd").new()
	# when: спрашиваем состояние фраз
	# then: по умолчанию они включены
	_check(fresh.tech_phrases_enabled, "новый ProgressManager: фразы по умолчанию включены")
	fresh.free()


## Выключение сохраняется сразу, а не только в памяти.
func _check_turn_off_persists() -> void:
	# given: фразы включены
	ProgressManager.set_tech_phrases_enabled(true)

	# when: пользователь выключает фразы
	ProgressManager.set_tech_phrases_enabled(false)

	# then: состояние и файл согласованы
	_check(not ProgressManager.are_tech_phrases_enabled(), "set_tech_phrases_enabled(false) выключил фразы")
	var saved := _read_file()
	_check(saved.has("tech_phrases_enabled") and saved["tech_phrases_enabled"] == false,
			"progress.json хранит tech_phrases_enabled=false")


## Загрузка из файла возвращает сохранённое выключенное состояние.
func _check_restore_off() -> void:
	# given: в памяти фразы включены, на диске сохранено false
	ProgressManager.tech_phrases_enabled = true

	# when: прогресс загружается заново
	ProgressManager.load_progress()

	# then: с диска приходит false
	_check(not ProgressManager.are_tech_phrases_enabled(), "load_progress восстановил выключенные фразы")


## При выключенных фразах служебный звук не назначается и не играет.
func _check_gate_blocks_phrase() -> void:
	# given: звук включён, фразы выключены
	AudioManager.set_sound_enabled(true)
	ProgressManager.set_tech_phrases_enabled(false)
	AudioManager._player.stream = null
	AudioManager._player.stop()

	# when: игра пытается проиграть техническую фразу
	AudioManager.play_tech_phrase(PROMPT_PATH)

	# then: плеер остаётся пустым
	_check(AudioManager._player.stream == null, "выключенные фразы не назначают поток")
	_check(not AudioManager._player.playing, "выключенные фразы не запускают плеер")


## Слова и звуки карточек играют через обычный путь и переключателем не глушатся.
func _check_content_audio_still_plays() -> void:
	# given: фразы выключены, но общий звук включён
	ProgressManager.set_tech_phrases_enabled(false)
	AudioManager.set_sound_enabled(true)
	AudioManager._player.stream = null
	AudioManager._player.stop()

	# when: играет обычный звук карточки, а не служебная фраза
	AudioManager.play_audio(PROMPT_PATH)

	# then: обычный путь не заблокирован переключателем фраз
	_check(AudioManager._player.stream != null, "обычный play_audio не зависит от фраз")
	_check(AudioManager._player.playing, "обычный play_audio продолжает играть")
	AudioManager._player.stop()


## Включённые фразы снова проигрываются.
func _check_turn_on_allows_phrase() -> void:
	# given: пользователь включает фразы
	ProgressManager.set_tech_phrases_enabled(true)
	AudioManager.set_sound_enabled(true)
	AudioManager._player.stream = null
	AudioManager._player.stop()

	# when: игра просит служебную фразу
	AudioManager.play_tech_phrase(PROMPT_PATH)

	# then: поток назначен и запущен
	_check(AudioManager._player.stream != null, "включённые фразы назначают поток")
	_check(AudioManager._player.playing, "включённые фразы запускают плеер")
	AudioManager._player.stop()


## Общий выключатель звука по-прежнему сильнее переключателя фраз.
func _check_sound_off_still_blocks() -> void:
	# given: фразы включены, но звук выключен
	ProgressManager.set_tech_phrases_enabled(true)
	AudioManager.set_sound_enabled(false)
	AudioManager._player.stream = null
	AudioManager._player.stop()

	# when: игра просит служебную фразу
	AudioManager.play_tech_phrase(PROMPT_PATH)

	# then: тишина
	_check(AudioManager._player.stream == null, "выключенный звук сильнее переключателя фраз")
	AudioManager.set_sound_enabled(true)


## Старый файл без ключа не должен внезапно выключить фразы.
func _check_legacy_file_defaults_on() -> void:
	# given: файл прогресса старого формата
	_write_file({"sound_enabled": true})

	# when: прогресс загружается
	ProgressManager.load_progress()

	# then: фразы включены по умолчанию
	_check(ProgressManager.are_tech_phrases_enabled(), "старый файл без ключа оставляет фразы включёнными")


## Небулево значение не должно трактоваться как выключение.
func _check_non_bool_defaults_on() -> void:
	# given: файл с испорченным значением
	_write_file({"tech_phrases_enabled": "off"})

	# when: прогресс загружается
	ProgressManager.load_progress()

	# then: включаем фразы, а не гасим их случайно
	_check(ProgressManager.are_tech_phrases_enabled(), "небулево значение оставляет фразы включёнными")


## Живая сцена настроек: чекбокс читает состояние и переключает его кликом.
func _check_settings_toggle() -> void:
	# given: фразы выключены, экран настроек создаётся с нуля
	ProgressManager.set_tech_phrases_enabled(false)
	var scene := load("res://ui/settings/settings.tscn") as PackedScene
	_check(scene != null, "сцена настроек загружается после правки")
	if scene == null:
		return
	var screen := scene.instantiate()
	add_child(screen)
	await get_tree().process_frame

	# when: смотрим на чекбокс технических фраз
	var checkbox := screen.get_node_or_null("%TechPhrasesCheckBox") as CheckBox
	_check(checkbox != null, "в настройках есть %TechPhrasesCheckBox")
	if checkbox == null:
		screen.queue_free()
		return
	_check(not checkbox.button_pressed, "чекбокс показывает выключенные фразы")

	# then: включение чекбокса доходит до ProgressManager
	checkbox.button_pressed = true
	await get_tree().process_frame
	_check(ProgressManager.are_tech_phrases_enabled(), "чекбокс включает технические фразы")
	_check(_read_file().get("tech_phrases_enabled", false) == true,
			"включение чекбокса сразу сохраняется")
	screen.queue_free()
	await get_tree().process_frame


func _read_file() -> Dictionary:
	var file := FileAccess.open(TEST_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


func _write_file(data: Dictionary) -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))
	file.close()


func _remove_test_file() -> void:
	var abs_path := ProjectSettings.globalize_path(TEST_PATH)
	if FileAccess.file_exists(abs_path):
		DirAccess.remove_absolute(abs_path)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("[tech_phrases_validate] OK: " + message)
	else:
		failures += 1
		printerr("[tech_phrases_validate] FAIL: " + message)


func _finish() -> void:
	if failures > 0:
		printerr("[tech_phrases_validate] FAILED: %d из %d проверок" % [failures, checks])
		get_tree().quit(1)
	else:
		print("[tech_phrases_validate] PASSED: %d проверок" % checks)
		get_tree().quit(0)
