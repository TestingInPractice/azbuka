extends Node
class_name LetterCardRecording
## Микрофон, прослушивание записи, подсказки и индикатор уровня.
##
## Сам захват и WAV-конвертация живут в автозагрузке VoiceRecord. Этот
## компонент держит плееры, кнопки записи/проигрывания и полосу уровня,
## чтобы карточка буквы не разрасталась.

const RECORD_DURATION := 10.0
const PROMPT_CORRECT := "res://assets/audio/prompt_correct.wav"
const PROMPT_FORWARD := "res://assets/audio/prompt_forward.wav"
const HINT_SOUND := "res://assets/audio/hint_find_letter.wav"

var _owner: Control
var _mic_button: Button
var _play_button: Button
var _level_meter: ColorRect
var _level_fill: ColorRect
var _playback_player: AudioStreamPlayer
var _prompt_player: AudioStreamPlayer


func setup(owner: Control, mic_button: Button, play_button: Button) -> void:
	_owner = owner
	_mic_button = mic_button
	_play_button = play_button
	_setup_players()
	_create_level_meter()
	set_process(true)


func _process(_delta: float) -> void:
	var level: float = VoiceRecord.get_level()
	if _level_meter != null and _level_meter.visible:
		_level_fill.size.x = _level_meter.size.x * minf(level * 10.0, 1.0)
		if level > 0.5:
			_level_fill.color = ThemeManager.ACCENT_RED
		elif level > 0.2:
			_level_fill.color = ThemeManager.ACCENT_YELLOW
		else:
			_level_fill.color = ThemeManager.ACCENT_TEAL


func prepare_microphone() -> bool:
	return VoiceRecord.prepare_microphone()


func start_recording() -> bool:
	return VoiceRecord.start_recording()


func stop_recording() -> void:
	if not VoiceRecord.is_recording():
		return
	var has_data := VoiceRecord.stop_recording()
	_play_button.disabled = not has_data


func play_recording() -> void:
	if not VoiceRecord.has_data():
		return
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = AudioServer.get_mix_rate()
	wav.stereo = false
	wav.data = VoiceRecord.normalize_pcm(VoiceRecord.get_data())
	_playback_player.stream = wav
	_playback_player.play()


func save_recording(path: String) -> bool:
	var bytes := VoiceRecord.get_wav_bytes()
	if bytes.is_empty():
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	file.close()
	return true


func is_recording() -> bool:
	return VoiceRecord.is_recording()


func has_recording() -> bool:
	return VoiceRecord.has_data()


func set_mic_text(text: String) -> void:
	_mic_button.text = text


func show_meter() -> void:
	_level_meter.show()


func hide_meter() -> void:
	_level_meter.hide()


func handle_mic_pressed(letter: String) -> void:
	if VoiceRecord.is_recording():
		stop_recording()
		set_mic_text("Микрофон")
		hide_meter()
		GameLogger.info("letter_card", "record_stop", {"letter": letter})
		return
	prepare_microphone()
	if start_recording():
		set_mic_text("Запись…")
		show_meter()
		GameLogger.info("letter_card", "record_start", {"letter": letter})
	else:
		GameLogger.warning("letter_card", "record_start_failed", {"letter": letter})


func handle_play_pressed(letter: String) -> void:
	if not VoiceRecord.has_data():
		return
	if _playback_player.playing:
		_playback_player.stop()
		GameLogger.info("letter_card", "play_stop", {"letter": letter})
		return
	play_recording()
	GameLogger.info("letter_card", "play_start", {"letter": letter, "bytes": VoiceRecord.get_data().size()})


func stop_if_active() -> void:
	if VoiceRecord.is_recording():
		stop_recording()
		set_mic_text("Микрофон")
		hide_meter()
	if _playback_player != null and _playback_player.playing:
		_playback_player.stop()


func play_prompt(path: String) -> void:
	if not AudioManager.sound_enabled or not ProgressManager.are_tech_phrases_enabled():
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	_prompt_player.stream = stream
	_prompt_player.play()


## То же, но для уже загруженного потока. Звуки буквы приходят из
## SetRepository готовыми AudioStream, а load() по пути здесь не годится:
## у файлов из user:// в веб-сборке нет импорта.
func play_prompt_stream(stream: AudioStream) -> void:
	if not AudioManager.sound_enabled or stream == null:
		return
	_prompt_player.stream = stream
	_prompt_player.play()


func await_prompt_finished() -> void:
	if _prompt_player == null or not _prompt_player.playing:
		return
	await _prompt_player.finished


func play_hint_sound() -> void:
	play_prompt(HINT_SOUND)


func play_word_error_beep() -> void:
	if not AudioManager.sound_enabled:
		return
	var duration := 0.12
	var sample_rate := 22050
	var freq := 300.0
	var num_samples: int = int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	for i in num_samples:
		var t := float(i) / sample_rate
		var envelope := 1.0
		if t < 0.005:
			envelope = t / 0.005
		elif t > duration - 0.01:
			envelope = (duration - t) / 0.01
		var sample: float = sin(2.0 * PI * freq * t) * envelope * 0.3
		var val: int = int(sample * 16384)
		data[i * 2] = val & 0xFF
		data[i * 2 + 1] = (val >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	var player := AudioStreamPlayer.new()
	player.stream = wav
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


func release() -> void:
	if _prompt_player:
		_prompt_player.stop()
	if _playback_player:
		_playback_player.stop()


func _setup_players() -> void:
	_playback_player = AudioStreamPlayer.new()
	_playback_player.bus = &"Master"
	add_child(_playback_player)
	_prompt_player = AudioStreamPlayer.new()
	_prompt_player.bus = &"Master"
	add_child(_prompt_player)


func _create_level_meter() -> void:
	_level_meter = ColorRect.new()
	_level_meter.name = "LevelMeter"
	_level_meter.unique_name_in_owner = true
	_level_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level_meter.z_index = 100
	_level_meter.anchor_left = 0.0
	_level_meter.anchor_top = 1.0
	_level_meter.anchor_right = 1.0
	_level_meter.anchor_bottom = 1.0
	_level_meter.offset_left = 20.0
	_level_meter.offset_top = -46.0
	_level_meter.offset_right = -20.0
	_level_meter.offset_bottom = -20.0
	_level_meter.color = ThemeManager.OVERLAY_DARK
	add_child(_level_meter)
	_level_meter.owner = _owner

	_level_fill = ColorRect.new()
	_level_fill.name = "LevelMeterFill"
	_level_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level_fill.anchor_top = 0.0
	_level_fill.anchor_bottom = 1.0
	_level_fill.color = ThemeManager.ACCENT_TEAL
	_level_meter.add_child(_level_fill)

	var label := Label.new()
	label.name = "LevelMeterLabel"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	label.text = "MIC"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.modulate.a = 0.5
	_level_meter.add_child(label)
	_level_meter.hide()
