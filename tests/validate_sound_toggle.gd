extends Node
## Валидатор кнопки звука: состояние по умолчанию, выключение и включение,
## молчание play_stream при выключенном звуке, запись выбора в progress.json,
## восстановление после перезапуска, вид кнопки главного меню, двойное нажатие
## и старые файлы без ключа или с небулевым значением.
## Путь прогресса уводится на тестовый файл: данные ребёнка не читаются и не меняются.
## Запуск: godot --headless --path . res://tests/validate_sound_toggle.tscn

const TEST_PATH := "user://progress_sound_toggle_test.json"
const MAIN_MENU_SCENE := "res://ui/main_menu/main_menu.tscn"

var checks := 0
var failures := 0
var _saved_progress_path := ""
var _saved_sound := true
var _stream: AudioStreamWAV


func _ready() -> void:
	await get_tree().process_frame
	_saved_progress_path = ProgressManager.save_path
	_saved_sound = AudioManager.sound_enabled
	ProgressManager.save_path = TEST_PATH
	_remove_test_file()
	_stream = _make_wav()

	_check_default_on()
	_check_turn_off()
	_check_persisted_off()
	_check_restore_off()
	_check_turn_on()
	await _check_menu_reflects_state()
	await _check_press_twice()
	_check_legacy_file()
	_check_non_bool()

	AudioManager.set_sound_enabled(_saved_sound)
	ProgressManager.save_path = _saved_progress_path
	_remove_test_file()
	_finish()


## Новый менеджер прогресса без файла обязан считать звук включённым.
func _check_default_on() -> void:
	# given: свежий ProgressManager, который ещё ничего не загружал
	var fresh: Node = load("res://systems/progress_manager.gd").new()
	# when: спрашиваем состояние звука
	# then: поле говорит «включён»
	_check(fresh.sound_enabled, "новый ProgressManager: sound_enabled по умолчанию true")
	fresh.free()


## Выключение гасит и прогресс, и AudioManager, а play_stream молчит.
func _check_turn_off() -> void:
	# given: звук включён в обоих менеджерах
	ProgressManager.set_sound_enabled(true)
	AudioManager.set_sound_enabled(true)

	# when: пользователь выключает звук
	ProgressManager.set_sound_enabled(false)
	AudioManager.set_sound_enabled(false)

	# then: оба менеджера видят выключенный звук
	_check(not ProgressManager.is_sound_enabled(), "set_sound_enabled(false) выключил звук в прогрессе")
	_check(not AudioManager.sound_enabled, "AudioManager выключил звук")

	# when: код пытается проиграть поток
	AudioManager._player.stream = null
	AudioManager._player.stop()
	AudioManager.play_stream(_stream)

	# then: потока нет и плеер не запущен
	_check(AudioManager._player.stream == null, "при выключенном звуке play_stream не назначает поток")
	_check(not AudioManager._player.playing, "при выключенном звуке play_stream не запускает плеер")


## Выбор сохраняется в progress.json сразу, а не только в памяти.
func _check_persisted_off() -> void:
	# given: звук только что выключен через set_sound_enabled
	# when: читаем файл прогресса
	var saved := _read_file()
	# then: в файле лежит именно false
	_check(saved.has("sound_enabled") and saved["sound_enabled"] == false,
			"progress.json хранит sound_enabled=false")


## Свежая загрузка из файла возвращает выключенный звук.
func _check_restore_off() -> void:
	# given: в памяти звук включён, а на диске сохранён выключенный
	ProgressManager.sound_enabled = true

	# when: прогресс загружается заново
	ProgressManager.load_progress()

	# then: выбор с диска побеждает
	_check(not ProgressManager.is_sound_enabled(), "load_progress восстановил выключенный звук")

	# when: состояние применяется к AudioManager, как при старте приложения
	AudioManager.set_sound_enabled(ProgressManager.is_sound_enabled())
	AudioManager._player.stream = null
	AudioManager.play_stream(_stream)

	# then: звук по-прежнему молчит
	_check(AudioManager._player.stream == null, "после загрузки выключенный звук не назначает поток")


## Включение возвращает и состояние, и реальное воспроизведение.
func _check_turn_on() -> void:
	# given: звук выключен после загрузки
	# when: пользователь включает звук
	ProgressManager.set_sound_enabled(true)
	AudioManager.set_sound_enabled(true)

	# then: оба менеджера включены
	_check(ProgressManager.is_sound_enabled(), "set_sound_enabled(true) включил звук в прогрессе")
	_check(AudioManager.sound_enabled, "AudioManager включил звук")

	# when: проигрывается поток
	AudioManager._player.stream = null
	AudioManager.play_stream(_stream)

	# then: поток назначен и плеер запущен
	_check(AudioManager._player.stream == _stream, "при включённом звуке play_stream назначает поток")
	_check(AudioManager._player.playing, "при включённом звуке play_stream запускает плеер")
	AudioManager._player.stop()


## Кнопка главного меню показывает сохранённое состояние, в том числе после
## имитации перезапуска с выключенным звуком.
func _check_menu_reflects_state() -> void:
	# given: звук включён
	ProgressManager.set_sound_enabled(true)
	AudioManager.set_sound_enabled(true)

	# when: открыто главное меню
	var menu := await _spawn(MAIN_MENU_SCENE)
	var button := menu.get_node_or_null("%SoundButton") as Button

	# then: кнопка на месте, в корне сцены, по заданным координатам и с нужным видом
	_check(button != null, "в главном меню есть SoundButton")
	if button == null:
		await _free(menu)
		return
	_check(button.get_parent() == menu, "SoundButton лежит в корне сцены, а не в MainLayout")
	_check(button.offset_left == 16.0 and button.offset_top == 170.0
			and button.offset_right == 206.0 and button.offset_bottom == 360.0,
			"SoundButton стоит по координатам 16/170/206/360")
	_check(button.custom_minimum_size == Vector2(190, 190)
			and button.get_theme_font_size("font_size") == 40,
			"SoundButton не меньше 190x190 и шрифт 40")
	_check(button.text == "🔊", "при включённом звуке кнопка показывает 🔊")
	_check(button.accessibility_name == "Звук включён", "имя кнопки при включённом звуке")
	await _free(menu)

	# given: в файле сохранён выключенный звук
	ProgressManager.set_sound_enabled(false)
	ProgressManager.sound_enabled = true
	ProgressManager.load_progress()
	AudioManager.set_sound_enabled(ProgressManager.is_sound_enabled())

	# when: открыто меню после перезапуска
	var restarted := await _spawn(MAIN_MENU_SCENE)
	var restarted_button := restarted.get_node_or_null("%SoundButton") as Button

	# then: надпись и имя говорят о выключенном звуке
	_check(restarted_button != null and restarted_button.text == "🔇",
			"после перезапуска с выключенным звуком кнопка показывает 🔇")
	_check(restarted_button != null and restarted_button.accessibility_name == "Звук выключен",
			"после перезапуска имя кнопки «Звук выключен»")
	await _free(restarted)


## Два нажатия подряд возвращают исходное состояние и обновляют файл.
func _check_press_twice() -> void:
	# given: звук включён и меню открыто
	ProgressManager.set_sound_enabled(true)
	AudioManager.set_sound_enabled(true)
	var menu := await _spawn(MAIN_MENU_SCENE)
	var button := menu.get_node_or_null("%SoundButton") as Button
	_check(button != null, "кнопка звука доступна для нажатия")
	if button == null:
		await _free(menu)
		return

	# when: первое нажатие
	button.pressed.emit()
	await get_tree().process_frame

	# then: звук выключен, надпись, имя и файл обновились
	_check(not AudioManager.sound_enabled, "первое нажатие выключило AudioManager")
	_check(not ProgressManager.is_sound_enabled(), "первое нажатие выключило прогресс")
	_check(button.text == "🔇", "после первого нажатия кнопка показывает 🔇")
	_check(button.accessibility_name == "Звук выключен", "после первого нажатия имя «Звук выключен»")
	_check(_read_file().get("sound_enabled") == false, "первое нажатие записало false в progress.json")

	# when: второе нажатие
	button.pressed.emit()
	await get_tree().process_frame

	# then: звук вернулся, надпись, имя и файл тоже
	_check(AudioManager.sound_enabled, "второе нажатие включило AudioManager")
	_check(ProgressManager.is_sound_enabled(), "второе нажатие включило прогресс")
	_check(button.text == "🔊", "после второго нажатия кнопка показывает 🔊")
	_check(button.accessibility_name == "Звук включён", "после второго нажатия имя «Звук включён»")
	_check(_read_file().get("sound_enabled") == true, "второе нажатие записало true в progress.json")
	await _free(menu)


## Старый файл без ключа sound_enabled продолжает работать со включённым звуком.
func _check_legacy_file() -> void:
	# given: файл, сохранённый до появления ключа
	_write_file({"learned_letters": ["А"], "games_played_count": 2})
	ProgressManager.sound_enabled = false

	# when: прогресс загружается
	ProgressManager.load_progress()

	# then: звук включён, а остальной прогресс не потерян
	_check(ProgressManager.is_sound_enabled(), "файл без sound_enabled загружается со звуком")
	_check(ProgressManager.get_learned_count() == 1, "остальной прогресс из старого файла прочитан")


## Небулево значение не должно трактоваться как «выключено».
func _check_non_bool() -> void:
	# given: строка вместо bool
	_write_file({"sound_enabled": "no"})
	ProgressManager.sound_enabled = false

	# when: прогресс загружается
	ProgressManager.load_progress()

	# then: звук включён
	_check(ProgressManager.is_sound_enabled(), "строковое sound_enabled даёт включённый звук")

	# given: число вместо bool
	_write_file({"sound_enabled": 0})
	ProgressManager.sound_enabled = false

	# when: прогресс загружается
	ProgressManager.load_progress()

	# then: звук снова включён
	_check(ProgressManager.is_sound_enabled(), "числовое sound_enabled даёт включённый звук")


## Короткий тихий WAV: достаточно, чтобы плеер получил настоящий поток.
func _make_wav() -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.stereo = false
	var samples := PackedByteArray()
	samples.resize(4410)
	for i in samples.size():
		samples[i] = 0x20 if i % 2 == 1 else 0x00
	wav.data = samples
	return wav


## Загружает сцену, ждёт два кадра и возвращает корень.
func _spawn(scene_path: String) -> Node:
	var scene: PackedScene = load(scene_path)
	var instance: Node = scene.instantiate()
	add_child(instance)
	await get_tree().process_frame
	await get_tree().process_frame
	return instance


## Освобождает сцену и даёт дереву два кадра на удаление.
func _free(node: Node) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()
		await get_tree().process_frame
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
		print("[sound_toggle_validate] OK: " + message)
	else:
		failures += 1
		printerr("[sound_toggle_validate] FAIL: " + message)


func _finish() -> void:
	if failures > 0:
		printerr("[sound_toggle_validate] FAILED: %d из %d проверок" % [failures, checks])
		get_tree().quit(1)
	else:
		print("[sound_toggle_validate] PASSED: %d проверок" % checks)
		get_tree().quit(0)
