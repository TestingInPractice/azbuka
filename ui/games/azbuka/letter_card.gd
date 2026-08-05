extends Control
class_name LetterCard
## Карточка буквы: слово, звуки, микрофон и автозапись.
##
## Слева вверху - кнопка назад, в центре - большая буква и картинка слова,
## ниже - квадраты букв слова (мини-игра "найди букву"), кнопки навигации
## по алфавиту, звуки буквы/слова, микрофон и воспроизведение записи.
## Рекордер встроен в этот скрипт (нет отдельного автолоада): шина
## VoiceRecord с AudioEffectCapture, запись 10 секунд, автонормализация
## при воспроизведении, сохранение в user://recordings.

const AZBUKA_SCENE := "res://ui/games/azbuka/azbuka.tscn"
const RECORD_BUS := "VoiceRecord"

const LETTERS := [
	"А", "Б", "В", "Г", "Д", "Е", "Ё", "Ж", "З", "И", "Й",
	"К", "Л", "М", "Н", "О", "П", "Р", "С", "Т", "У", "Ф",
	"Х", "Ц", "Ч", "Ш", "Щ", "Ъ", "Ы", "Ь", "Э", "Ю", "Я",
]

const RECORD_DURATION := 10.0
const SLIDE_DURATION := 0.3

const PROMPT_CORRECT := "res://assets/audio/prompt_correct.wav"
const PROMPT_FORWARD := "res://assets/audio/prompt_forward.wav"
const HINT_SOUND := "res://assets/audio/hint_find_letter.wav"

const COLOR_WORD_SQUARE := Color("#4ECDC4")
const COLOR_LETTER_BTN := Color("#4ECDC4")
const COLOR_WORD_BTN := Color("#45B7D1")
const COLOR_MIC_BTN := Color("#FF6B6B")
const COLOR_PLAY_BTN := Color("#96CEB4")
const COLOR_BACK_BTN := Color("#E8A87C")
const COLOR_LEVEL_HIGH := Color("#FF6B6B")
const COLOR_LEVEL_MID := Color("#FFD93D")
const COLOR_LEVEL_LOW := Color("#4ECDC4")

## Слово -> имя файла картинки (без расширения) в res://assets/images.
## 1:1 со старым alphabet_data.gd (английские имена файлов).
const WORD_IMAGE := {
	"А": "Bus",
	"Б": "Banana",
	"В": "Water",
	"Г": "Goose",
	"Д": "House",
	"Е": "Christmas_Tree",
	"Ё": "Hedgehog",
	"Ж": "Beetle",
	"З": "Hare",
	"И": "Toy",
	"Й": "Yogurt",
	"К": "Cat",
	"Л": "Moon",
	"М": "Ball",
	"Н": "Nose",
	"О": "Window",
	"П": "Gift",
	"Р": "Mouth",
	"С": "Juice",
	"Т": "Cake",
	"У": "Duck",
	"Ф": "Fountain",
	"Х": "Bread",
	"Ц": "Chicken",
	"Ч": "Tea",
	"Ш": "Hat",
	"Щ": "Puppy",
	"Ъ": "announcement",
	"Ы": "Soap",
	"Ь": "Horse",
	"Э": "Screen",
	"Ю": "Spinning_Top",
	"Я": "Apple",
}

## Буква, с которой открывается карточка. Устанавливает экран «Азбука»
## перед переключением сцены.
static var from_letter: String = ""

var letter: String = ""
var _current_index: int = 0
var _is_transitioning := false
var _game_solved := false
var _game_input_blocked := false
var _word_letter_buttons: Array[Button] = []
var _level_meter: ColorRect = null
var _level_fill: ColorRect = null

# Рекордер.
var _capture_effect: AudioEffectCapture = null
var _mic_player: AudioStreamPlayer = null
var _playback_player: AudioStreamPlayer = null
var _prompt_player: AudioStreamPlayer = null
var _accumulated_frames := PackedVector2Array()
var _recorded_data := PackedByteArray()
var _is_recording := false
var _mic_prepared := false
var _current_level := 0.0

@onready var _background_overlay: ColorRect = %BackgroundOverlay
@onready var _content_wrapper: Control = %ContentWrapper
@onready var _letter_label: Label = %LetterLabel
@onready var _word_image: TextureRect = %WordImage
@onready var _word_squares: HBoxContainer = %WordSquares
@onready var _hint_label: Label = %HintLabel
@onready var _prev_button: Button = %PrevLetterButton
@onready var _next_button: Button = %NextLetterButton
@onready var _button_letter: Button = %ButtonLetter
@onready var _button_word: Button = %ButtonWord
@onready var _mic_button: Button = %MicButton
@onready var _play_button: Button = %RecordPlaybackButton
@onready var _back_button: Button = %LetterBackButton


func _ready() -> void:
	if from_letter.is_empty():
		from_letter = "А"
	letter = from_letter
	_current_index = LETTERS.find(letter)
	if _current_index < 0:
		_current_index = 0
		letter = LETTERS[0]
	_setup_players()
	_setup_capture_bus()
	_create_level_meter()
	_connect_signals()
	_apply_theme()
	ThemeManager.theme_changed.connect(_apply_theme)
	_update_content()
	_update_nav_buttons()
	set_process(true)
	GameLogger.info("letter_card", "ready", {"letter": letter, "index": _current_index})


func _process(_delta: float) -> void:
	if _is_recording and _capture_effect:
		var available: int = _capture_effect.get_frames_available()
		if available > 0:
			var frames: PackedVector2Array = _capture_effect.get_buffer(available)
			_accumulated_frames.append_array(frames)
			var sum_sq := 0.0
			for f in frames:
				var s: float = (f.x + f.y) * 0.5
				sum_sq += s * s
			var rms: float = sqrt(sum_sq / float(frames.size()))
			_current_level = lerpf(_current_level, rms, 0.25)
	if _level_meter != null and _level_meter.visible:
		var level: float = _current_level
		_level_fill.size.x = _level_meter.size.x * minf(level * 10.0, 1.0)
		if level > 0.5:
			_level_fill.color = COLOR_LEVEL_HIGH
		elif level > 0.2:
			_level_fill.color = COLOR_LEVEL_MID
		else:
			_level_fill.color = COLOR_LEVEL_LOW


func _setup_players() -> void:
	_playback_player = AudioStreamPlayer.new()
	_playback_player.bus = &"Master"
	add_child(_playback_player)
	_prompt_player = AudioStreamPlayer.new()
	_prompt_player.bus = &"Master"
	add_child(_prompt_player)


func _setup_capture_bus() -> void:
	var bus_index: int = AudioServer.get_bus_index(RECORD_BUS)
	if bus_index == -1:
		AudioServer.add_bus()
		bus_index = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(bus_index, RECORD_BUS)
	if AudioServer.get_bus_effect_count(bus_index) == 0:
		_capture_effect = AudioEffectCapture.new()
		_capture_effect.set_buffer_length(6.0)
		AudioServer.add_bus_effect(bus_index, _capture_effect)
	else:
		_capture_effect = AudioServer.get_bus_effect(bus_index, 0) as AudioEffectCapture
	AudioServer.set_bus_volume_db(bus_index, -80.0)


func prepare_microphone() -> void:
	if _mic_prepared:
		return
	_mic_player = AudioStreamPlayer.new()
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.bus = RECORD_BUS
	add_child(_mic_player)
	_mic_player.play()
	_mic_prepared = true
	GameLogger.info("letter_card", "mic_prepared", {"letter": letter})


func start_recording() -> bool:
	if _is_recording:
		return false
	if _capture_effect == null:
		push_error("LetterCard: AudioEffectCapture is null - cannot record")
		return false
	if not _mic_prepared:
		prepare_microphone()
	_accumulated_frames.clear()
	_recorded_data.clear()
	_capture_effect.clear_buffer()
	_capture_effect.set_buffer_length(5.0)
	_is_recording = true
	set_process(true)
	return true


func stop_recording() -> void:
	if not _is_recording:
		return
	_is_recording = false
	set_process(false)
	_current_level = 0.0
	if _capture_effect and _capture_effect.get_frames_available() > 0:
		_accumulated_frames.append_array(_capture_effect.get_buffer(_capture_effect.get_frames_available()))
	_capture_effect.clear_buffer()
	if _accumulated_frames.is_empty():
		_recorded_data = PackedByteArray()
		_play_button.disabled = true
		push_warning("LetterCard: no frames captured - microphone may be silent or permissions denied")
		return
	var mix_rate: float = AudioServer.get_mix_rate()
	_recorded_data.resize(_accumulated_frames.size() * 2)
	for i in _accumulated_frames.size():
		var sample := (_accumulated_frames[i].x + _accumulated_frames[i].y) * 0.5
		sample = clampf(sample, -1.0, 1.0)
		var val := int(sample * 32767)
		_recorded_data[i * 2] = val & 0xFF
		_recorded_data[i * 2 + 1] = (val >> 8) & 0xFF
	_accumulated_frames.clear()
	_play_button.disabled = false


func play_recording() -> void:
	if _recorded_data.is_empty():
		return
	var playback_data: PackedByteArray = _recorded_data
	var max_abs: int = 0
	for i in range(0, _recorded_data.size(), 2):
		var sample: int = _recorded_data[i] | (_recorded_data[i + 1] << 8)
		if sample > 32767:
			sample -= 65536
		var abs_sample: int = -sample if sample < 0 else sample
		if abs_sample > max_abs:
			max_abs = abs_sample
	if max_abs > 0 and max_abs < 26214:
		var scale: float = 26214.0 / max_abs
		playback_data = PackedByteArray()
		playback_data.resize(_recorded_data.size())
		for i in range(0, _recorded_data.size(), 2):
			var sample: int = _recorded_data[i] | (_recorded_data[i + 1] << 8)
			if sample > 32767:
				sample -= 65536
			var scaled: int = clampi(int(sample * scale), -32768, 32767)
			var uscaled: int = scaled + 65536 if scaled < 0 else scaled
			playback_data[i] = uscaled & 0xFF
			playback_data[i + 1] = (uscaled >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = AudioServer.get_mix_rate()
	wav.stereo = false
	wav.data = playback_data
	_playback_player.stream = wav
	_playback_player.play()


func save_recording(path: String) -> bool:
	if _recorded_data.is_empty():
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return false
	var data_size: int = _recorded_data.size()
	var file_size: int = 36 + data_size
	var sample_rate: float = AudioServer.get_mix_rate()
	var header := PackedByteArray()
	header.resize(44)
	header.encode_u32(0, 0x46464952)
	header.encode_u32(4, file_size)
	header.encode_u32(8, 0x45564157)
	header.encode_u32(12, 0x20746D66)
	header.encode_u32(16, 16)
	header.encode_u16(20, 1)
	header.encode_u16(22, 1)
	header.encode_u32(24, sample_rate)
	header.encode_u32(28, sample_rate * 2)
	header.encode_u16(32, 2)
	header.encode_u16(34, 16)
	header.encode_u32(36, 0x61746164)
	header.encode_u32(40, data_size)
	file.store_buffer(header)
	file.store_buffer(_recorded_data)
	file.close()
	return true


func is_recording() -> bool:
	return _is_recording


func has_recording() -> bool:
	return not _recorded_data.is_empty()


func _on_mic_pressed() -> void:
	if _is_recording:
		_stop_recording()
		_mic_button.text = "Микрофон"
		_level_meter.hide()
		GameLogger.info("letter_card", "record_stop", {"letter": letter})
	else:
		prepare_microphone()
		if start_recording():
			_mic_button.text = "Запись…"
			_level_meter.show()
			GameLogger.info("letter_card", "record_start", {"letter": letter})
		else:
			GameLogger.warning("letter_card", "record_start_failed", {"letter": letter})


func _stop_recording() -> void:
	stop_recording()


func _stop_recording_if_active() -> void:
	if _is_recording:
		_stop_recording()
		_mic_button.text = "Микрофон"
		_level_meter.hide()
	if _playback_player and _playback_player.playing:
		_playback_player.stop()


func _on_play_pressed() -> void:
	if _recorded_data.is_empty():
		return
	if _playback_player.playing:
		_playback_player.stop()
		GameLogger.info("letter_card", "play_stop", {"letter": letter})
		return
	play_recording()
	GameLogger.info("letter_card", "play_start", {"letter": letter, "bytes": _recorded_data.size()})


func _connect_signals() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_button_letter.pressed.connect(_on_letter_sound_pressed)
	_button_word.pressed.connect(_on_word_sound_pressed)
	_prev_button.pressed.connect(_on_prev_pressed)
	_next_button.pressed.connect(_on_next_pressed)
	_mic_button.pressed.connect(_on_mic_pressed)
	_play_button.pressed.connect(_on_play_pressed)


func _on_letter_sound_pressed() -> void:
	GameLogger.info("letter_card", "letter_sound", {"letter": letter})
	AudioManager.stop_all()
	AudioManager.play_audio(AlphabetData.get_letter_audio_path(letter))


func _on_word_sound_pressed() -> void:
	GameLogger.info("letter_card", "word_sound", {"letter": letter})
	AudioManager.stop_all()
	AudioManager.play_audio(AlphabetData.get_word_audio_path(letter))


func _update_content() -> void:
	_letter_label.text = letter + letter.to_lower()
	var img_path := _image_path_for(letter)
	var tex: Texture2D = null
	if not img_path.is_empty():
		tex = load(img_path) as Texture2D
	if tex:
		_word_image.texture = tex
		_word_image.visible = true
		var vp: Vector2 = get_viewport_rect().size
		var img_w: float = vp.x * 0.5
		_word_image.custom_minimum_size = Vector2(img_w, img_w * float(tex.get_height()) / float(tex.get_width()))
	else:
		_word_image.texture = null
		_word_image.visible = false
		if not img_path.is_empty():
			GameLogger.warning("letter_card", "word_image_missing", {"letter": letter, "path": img_path})
	_reset_word_game()


func _image_path_for(ltr: String) -> String:
	var image_name: String = WORD_IMAGE.get(ltr, "")
	if image_name.is_empty():
		return ""
	return "res://assets/images/" + image_name + ".png"


func _reset_word_game() -> void:
	_game_solved = false
	_game_input_blocked = false
	_clear_word_buttons()
	_play_button.disabled = true
	_hint_label.text = "Найди букву «%s» в слове" % letter
	_hint_label.scale = Vector2.ONE
	_hint_label.show()
	var data: Dictionary = AlphabetData.get_letter_data(letter)
	var word: String = str(data.get("word", ""))
	if word.is_empty():
		return
	_setup_word_buttons(word)
	_play_hint_sound()


func _clear_word_buttons() -> void:
	for btn in _word_letter_buttons:
		btn.queue_free()
	_word_letter_buttons.clear()


func _setup_word_buttons(word: String) -> void:
	var vp_w: float = get_viewport_rect().size.x
	var padding: float = 80.0
	var separation: float = 24.0
	var max_btn_w := 110.0
	var min_btn_w := 56.0
	var available: float = vp_w - padding * 2.0
	var btn_w: float = clampf((available - separation * float(word.length() - 1)) / float(word.length()), min_btn_w, max_btn_w)
	var btn_size := Vector2(btn_w, btn_w)
	var font_size: int = maxi(28, mini(56, int(btn_w * 0.5)))
	for i in word.length():
		var btn := Button.new()
		btn.name = "WordSquare_%d" % (i + 1)
		btn.accessibility_name = "WordSquare %d" % (i + 1)
		btn.unique_name_in_owner = true
		btn.text = word[i]
		btn.add_theme_font_size_override("font_size", font_size)
		btn.custom_minimum_size = btn_size
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ThemeManager.style_button(btn, COLOR_WORD_SQUARE)
		btn.pressed.connect(_on_word_square_pressed.bind(i))
		_word_squares.add_child(btn)
		btn.owner = self
		_word_letter_buttons.append(btn)


func _on_word_square_pressed(index: int) -> void:
	if _game_solved or _game_input_blocked or _is_transitioning:
		return
	var btn: Button = _word_letter_buttons[index]
	var btn_letter: String = btn.text
	if btn_letter.to_lower() == letter.to_lower():
		_game_solved = true
		_game_input_blocked = true
		_hint_label.text = "Скажи всё слово!"
		_show_feedback_anim()
		_play_word_correct_anim(btn)
		for b in _word_letter_buttons:
			if b.text.to_lower() == letter.to_lower():
				b.modulate = Color.GREEN
		GameLogger.info("letter_card", "word_correct", {"letter": letter, "index": index})
		ProgressManager.mark_letter_completed(letter)
		prepare_microphone()
		_auto_record_correct()
	else:
		_game_input_blocked = true
		GameLogger.warning("letter_card", "word_wrong", {"letter": letter, "pressed": btn_letter})
		_play_word_error_beep()
		_play_word_wrong_anim(btn)
		_hint_label.text = "Попробуй ещё!"
		_show_feedback_anim()
		await get_tree().create_timer(0.6).timeout
		if not is_inside_tree():
			return
		_game_input_blocked = false
		_hint_label.text = "Найди букву «%s» в слове" % letter


func _auto_record_correct() -> void:
	var record_letter: String = letter
	_play_prompt(PROMPT_CORRECT)
	await _await_prompt_finished()
	if not is_inside_tree() or letter != record_letter:
		return
	if start_recording():
		_mic_button.text = "Запись…"
		_level_meter.show()
		await get_tree().create_timer(RECORD_DURATION).timeout
		if not is_inside_tree() or letter != record_letter:
			return
		_stop_recording()
		_mic_button.text = "Микрофон"
		_level_meter.hide()
		if _recorded_data.is_empty():
			_hint_label.text = "Запись не получилась. Проверь микрофон."
			GameLogger.warning("letter_card", "auto_record_empty", {"letter": letter})
			return
		var saved: bool = _save_auto_recording()
		GameLogger.info("letter_card", "auto_record_saved", {"letter": letter, "saved": saved})
		_hint_label.text = "Молодец! Нажми ›"
		_show_feedback_anim()
		_play_prompt(PROMPT_FORWARD)
	else:
		push_warning("LetterCard: auto-record start failed - microphone may be unavailable")
		GameLogger.warning("letter_card", "auto_record_failed", {"letter": letter})


func _save_auto_recording() -> bool:
	# TODO: ИндексDB/локальное хранение записей - в отдельной фазе.
	if _recorded_data.is_empty():
		return false
	var data: Dictionary = AlphabetData.get_letter_data(letter)
	var word: String = str(data.get("word", "unknown")).to_lower()
	DirAccess.make_dir_recursive_absolute("user://recordings")
	var ts: String = Time.get_datetime_string_from_system().replace("T", "_").replace(":", "-")
	var path := "user://recordings/%s_%s_%s.wav" % [letter.to_lower(), word, ts]
	return save_recording(path)


func _play_prompt(path: String) -> void:
	if not AudioManager.sound_enabled:
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	_prompt_player.stream = stream
	_prompt_player.play()


func _await_prompt_finished() -> void:
	if _prompt_player == null or not _prompt_player.playing:
		return
	await _prompt_player.finished


func _play_hint_sound() -> void:
	_play_prompt(HINT_SOUND)


func _play_word_error_beep() -> void:
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


func _show_feedback_anim() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	_hint_label.scale = Vector2.ZERO
	tween.tween_property(_hint_label, "scale", Vector2.ONE, 0.5)


func _play_word_correct_anim(btn: Button) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BOUNCE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(1.3, 1.3), 0.15)
	tween.tween_property(btn, "scale", Vector2.ONE, 0.25)
	tween.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.2)
	tween.tween_property(btn, "scale", Vector2.ONE, 0.2)
	tween.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.15)
	tween.tween_property(btn, "scale", Vector2.ONE, 0.15)


func _play_word_wrong_anim(btn: Button) -> void:
	btn.modulate = Color.RED
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	var orig: float = btn.rotation_degrees
	for _k in 3:
		tween.tween_property(btn, "rotation_degrees", orig - 8.0, 0.04)
		tween.tween_property(btn, "rotation_degrees", orig + 8.0, 0.04)
	tween.tween_property(btn, "rotation_degrees", orig, 0.04)
	var reset := create_tween()
	reset.tween_interval(0.3)
	reset.tween_property(btn, "modulate", Color.WHITE, 0.2)


func _update_nav_buttons() -> void:
	_prev_button.disabled = _current_index <= 0
	_next_button.disabled = _current_index >= LETTERS.size() - 1


func _on_prev_pressed() -> void:
	if _is_transitioning or _current_index <= 0:
		return
	GameLogger.info("letter_card", "prev", {"from": letter})
	_stop_recording_if_active()
	_navigate_to(_current_index - 1, -1)


func _on_next_pressed() -> void:
	if _is_transitioning or _current_index >= LETTERS.size() - 1:
		return
	GameLogger.info("letter_card", "next", {"from": letter})
	_stop_recording_if_active()
	_navigate_to(_current_index + 1, 1)


func _navigate_to(target_idx: int, direction: int) -> void:
	_is_transitioning = true
	var new_letter: String = LETTERS[target_idx]
	var screen_w: float = get_viewport_rect().size.x
	var slide_target: float = -direction * screen_w
	var slide_start: float = direction * screen_w

	var tween_out := create_tween().set_parallel(true)
	tween_out.tween_method(_set_content_offset, 0.0, slide_target, SLIDE_DURATION)
	tween_out.tween_property(_content_wrapper, "modulate:a", 0.0, SLIDE_DURATION)
	await tween_out.finished

	_current_index = target_idx
	letter = new_letter
	# Синхронизация статической переменной, чтобы котик на экране «Азбука»
	# вернулся на последнюю просмотренную букву, а не на букву открытия.
	LetterCard.from_letter = new_letter
	_update_content()
	_apply_theme()

	_set_content_offset(slide_start)
	_content_wrapper.modulate.a = 0.0

	var tween_in := create_tween().set_parallel(true)
	tween_in.tween_method(_set_content_offset, slide_start, 0.0, SLIDE_DURATION)
	tween_in.tween_property(_content_wrapper, "modulate:a", 1.0, SLIDE_DURATION)
	await tween_in.finished

	_set_content_offset(0.0)
	_update_nav_buttons()
	_is_transitioning = false


func _set_content_offset(v: float) -> void:
	_content_wrapper.offset_left = v
	_content_wrapper.offset_right = v


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
	_level_meter.color = Color(0, 0, 0, 0.3)
	add_child(_level_meter)
	_level_meter.owner = self

	_level_fill = ColorRect.new()
	_level_fill.name = "LevelMeterFill"
	_level_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level_fill.anchor_top = 0.0
	_level_fill.anchor_bottom = 1.0
	_level_fill.color = COLOR_LEVEL_LOW
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


func _play_appear_animation() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	_letter_label.scale = Vector2.ZERO
	tween.tween_property(_letter_label, "scale", Vector2.ONE, 0.5)


func _apply_theme(_mode: int = 0) -> void:
	var text: Color = ThemeManager.get_text()
	_background_overlay.visible = ThemeManager.current_theme == ThemeManager.THEME_DARK
	var ls := _letter_label.label_settings
	if ls == null:
		ls = LabelSettings.new()
		_letter_label.label_settings = ls
	ls.outline_color = text
	ls.font_color = Color.WHITE
	ls.outline_size = 4
	var fs: float = maxf(80.0, get_viewport_rect().size.y / 4.0)
	ls.font_size = int(fs)
	_hint_label.add_theme_color_override("font_color", Color.WHITE)
	ThemeManager.style_button(_button_letter, COLOR_LETTER_BTN)
	ThemeManager.style_button(_button_word, COLOR_WORD_BTN)
	ThemeManager.style_button(_mic_button, COLOR_MIC_BTN)
	ThemeManager.style_button(_play_button, COLOR_PLAY_BTN)
	ThemeManager.style_button(_back_button, COLOR_BACK_BTN, Color("#2D2D2D"))
	_style_nav_button(_prev_button)
	_style_nav_button(_next_button)


func _style_nav_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(ThemeManager.get_card_bg(), 0.7)
	normal.set_corner_radius_all(180)
	normal.shadow_size = 4
	normal.shadow_color = Color(0, 0, 0, 0.25)
	normal.content_margin_left = 0
	normal.content_margin_right = 0
	normal.content_margin_top = 0
	normal.content_margin_bottom = 0
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(ThemeManager.get_card_bg(), 0.85)
	hover.set_corner_radius_all(180)
	hover.shadow_size = 6
	hover.shadow_color = Color(0, 0, 0, 0.3)
	hover.content_margin_left = 0
	hover.content_margin_right = 0
	hover.content_margin_top = 0
	hover.content_margin_bottom = 0
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(ThemeManager.get_card_bg(), 0.9)
	pressed.set_corner_radius_all(180)
	pressed.shadow_size = 2
	pressed.shadow_color = Color(0, 0, 0, 0.2)
	pressed.content_margin_left = 0
	pressed.content_margin_right = 0
	pressed.content_margin_top = 0
	pressed.content_margin_bottom = 0
	btn.add_theme_stylebox_override("pressed", pressed)

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Color(0.5, 0.5, 0.5, 0.3)
	disabled.set_corner_radius_all(180)
	disabled.content_margin_left = 0
	disabled.content_margin_right = 0
	disabled.content_margin_top = 0
	disabled.content_margin_bottom = 0
	btn.add_theme_stylebox_override("disabled", disabled)

	var text: Color = ThemeManager.get_text()
	btn.add_theme_color_override("font_color", text)
	btn.add_theme_color_override("font_hover_color", text)
	btn.add_theme_color_override("font_pressed_color", text)


func _on_back_pressed() -> void:
	GameLogger.info("nav", "to_azbuka", {"from": "letter_card", "letter": letter})
	AudioManager.stop_all()
	get_tree().change_scene_to_file(AZBUKA_SCENE)


func _exit_tree() -> void:
	set_process(false)
	if _is_recording and _mic_player:
		_mic_player.stop()
	if _prompt_player:
		_prompt_player.stop()
	if _playback_player:
		_playback_player.stop()
	AudioManager.stop_all()
