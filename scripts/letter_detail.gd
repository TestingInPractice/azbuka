extends Control

const LETTERS := [
	"А", "Б", "В", "Г", "Д", "Е", "Ё", "Ж", "З", "И", "Й",
	"К", "Л", "М", "Н", "О", "П", "Р", "С", "Т", "У", "Ф",
	"Х", "Ц", "Ч", "Ш", "Щ", "Ъ", "Ы", "Ь", "Э", "Ю", "Я",
]

var letter: String = ""
var letter_name: String = ""
var _current_index: int = 0
var _is_transitioning: bool = false
var _word_letter_buttons: Array[Button] = []
var _game_solved: bool = false
var _game_input_blocked: bool = false
var _record_pulse_tween: Tween = null

@onready var back_button := $BackButton
@onready var content_wrapper := $ContentWrapper
@onready var letter_label := $ContentWrapper/VBoxContainer/LetterContent/LetterLabel
@onready var word_image := $ContentWrapper/VBoxContainer/LetterContent/WordImage
@onready var word_sound_button := $ContentWrapper/VBoxContainer/AudioButtons/WordSoundButton
@onready var letter_sound_button := $ContentWrapper/VBoxContainer/AudioButtons/LetterSoundButton
@onready var prev_button := $ContentWrapper/VBoxContainer/NavButtons/PrevButton
@onready var next_button := $ContentWrapper/VBoxContainer/NavButtons/NextButton
@onready var word_game_container := $ContentWrapper/VBoxContainer/WordGameContainer
@onready var game_feedback_label := $ContentWrapper/VBoxContainer/GameFeedbackLabel
@onready var hint_label := $ContentWrapper/VBoxContainer/HintLabel
@onready var voice_recorder := $VoiceRecorder
@onready var record_button := $ContentWrapper/VBoxContainer/AudioButtons/RecordButton
@onready var play_button := $ContentWrapper/VBoxContainer/AudioButtons/PlayButton

func _ready():
	var data := AlphabetData.get_letter_data(letter)
	_current_index = LETTERS.find(letter)
	if _current_index == -1:
		_current_index = 0

	var viewport_h = get_viewport().get_visible_rect().size.y
	var viewport_w = get_viewport().get_visible_rect().size.x
	var fs := max(80, viewport_h / 4)
	letter_label.add_theme_font_size_override("font_size", fs)
	letter_label.offset_left = -viewport_w * 0.4
	letter_label.offset_right = viewport_w * 0.4
	var label_h := fs * 1.4
	letter_label.offset_top = -(fs + label_h * 0.5)
	letter_label.offset_bottom = -(fs - label_h * 0.5)

	_update_content(data)
	_update_nav_buttons()
	_connect_signals()
	apply_theme()
	ThemeManager.theme_changed.connect(_on_theme_changed)
	_play_appear_animation()

func _update_content(data: Dictionary):
	var ltr = data.get("letter", letter)
	letter_label.text = ltr + ltr.to_lower()
	var img_path = data.get("image_path", "")
	if not img_path.is_empty():
		var tex := load(img_path) as Texture2D
		word_image.texture = tex
	else:
		word_image.texture = null
	_reset_word_game()

func _connect_signals():
	back_button.pressed.connect(_on_back_pressed)
	letter_sound_button.pressed.connect(_on_letter_sound_pressed)
	word_sound_button.pressed.connect(_on_word_sound_pressed)
	prev_button.pressed.connect(_on_prev_pressed)
	next_button.pressed.connect(_on_next_pressed)
	record_button.pressed.connect(_on_record_pressed)
	play_button.pressed.connect(_on_play_pressed)

func _update_nav_buttons():
	prev_button.disabled = _current_index <= 0
	next_button.disabled = _current_index >= LETTERS.size() - 1

func _on_letter_sound_pressed():
	if AudioManager.is_playing():
		AudioManager.stop_all()
	AudioManager.play_letter(letter)

func _on_word_sound_pressed():
	if AudioManager.is_playing():
		AudioManager.stop_all()
	AudioManager.play_word(letter)

func _on_record_pressed():
	if voice_recorder.is_recording():
		voice_recorder.stop_recording()
		_stop_pulse_animation()
		record_button.text = "🎤"
		play_button.disabled = not voice_recorder.has_recording()
	else:
		voice_recorder.start_recording()
		record_button.text = "🔴"
		_start_pulse_animation()
		play_button.disabled = true

func _on_play_pressed():
	if voice_recorder.is_playing():
		voice_recorder.stop_playback()
	else:
		voice_recorder.play_recording()

func _start_pulse_animation():
	_stop_pulse_animation()
	_record_pulse_tween = create_tween().set_loops()
	_record_pulse_tween.tween_property(record_button, "modulate:a", 0.4, 0.4)
	_record_pulse_tween.tween_property(record_button, "modulate:a", 1.0, 0.4)

func _stop_pulse_animation():
	if _record_pulse_tween:
		_record_pulse_tween.kill()
		_record_pulse_tween = null
	record_button.modulate.a = 1.0

func _stop_recording_if_active():
	if voice_recorder.is_recording():
		voice_recorder.stop_recording()
		_stop_pulse_animation()
		record_button.text = "🎤"
		play_button.disabled = not voice_recorder.has_recording()

func _on_back_pressed():
	AudioManager.stop_all()
	Global.go_to_alphabet_screen()

func _on_prev_pressed():
	if _is_transitioning or _current_index <= 0:
		return
	_stop_recording_if_active()
	_navigate_to(_current_index - 1, -1)

func _on_next_pressed():
	if _is_transitioning or _current_index >= LETTERS.size() - 1:
		return
	_stop_recording_if_active()
	_navigate_to(_current_index + 1, 1)

func _navigate_to(target_idx: int, direction: int):
	_is_transitioning = true

	var new_letter = LETTERS[target_idx]
	var new_data := AlphabetData.get_letter_data(new_letter)
	var screen_w = get_viewport().size.x

	var slide_target = -direction * screen_w
	var slide_start = direction * screen_w

	var tween_out = create_tween().set_parallel(true)
	tween_out.tween_method(_set_content_offset, 0.0, slide_target, 0.3)
	tween_out.tween_property(content_wrapper, "modulate:a", 0.0, 0.3)
	await tween_out.finished

	_current_index = target_idx
	letter = new_letter
	letter_name = Global.letter_names.get(new_letter, new_letter)
	_update_content(new_data)
	apply_theme()

	_set_content_offset(slide_start)
	content_wrapper.modulate.a = 0.0

	var tween_in = create_tween().set_parallel(true)
	tween_in.tween_method(_set_content_offset, slide_start, 0.0, 0.3)
	tween_in.tween_property(content_wrapper, "modulate:a", 1.0, 0.3)
	await tween_in.finished

	_set_content_offset(0.0)

	_is_transitioning = false

func _set_content_offset(v: float):
	content_wrapper.offset_left = v
	content_wrapper.offset_right = v

func _play_appear_animation():
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	letter_label.scale = Vector2.ZERO
	tween.tween_property(letter_label, "scale", Vector2.ONE, 0.5)

func _on_theme_changed(_theme_name: String):
	apply_theme()

func apply_theme():
	var text = ThemeManager.get_text()
	var bg = ThemeManager.get_bg()

	var style := StyleBoxFlat.new()
	style.bg_color = bg
	add_theme_stylebox_override("panel", style)

	letter_label.add_theme_color_override("font_color", text)

	ThemeManager.style_button(letter_sound_button, Color("#4ECDC4"))
	ThemeManager.style_button(word_sound_button, Color("#45B7D1"))
	ThemeManager.style_button(record_button, Color("#FF6B6B"))
	ThemeManager.style_button(play_button, Color("#96CEB4"))
	ThemeManager.style_button(back_button, Color("#E8A87C"), Color("#2D2D2D"))
	ThemeManager.style_button(prev_button, Color("#96CEB4"), Color("#2D2D2D"))
	ThemeManager.style_button(next_button, Color("#96CEB4"), Color("#2D2D2D"))

	_style_disabled_button(prev_button)
	_style_disabled_button(next_button)

func _style_disabled_button(btn: Button):
	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Color(0.5, 0.5, 0.5, 0.3)
	disabled.set_corner_radius_all(20)
	disabled.content_margin_left = 20
	disabled.content_margin_right = 20
	disabled.content_margin_top = 12
	disabled.content_margin_bottom = 12
	btn.add_theme_stylebox_override("disabled", disabled)

func _reset_word_game():
	_game_solved = false
	_game_input_blocked = false
	_clear_word_buttons()
	game_feedback_label.hide()
	game_feedback_label.text = ""
	hint_label.show()

	var data: Dictionary = AlphabetData.get_letter_data(letter)
	var word: String = data.get("word", "")
	if word.is_empty():
		return

	_setup_word_buttons(word)
	_play_hint_sound()

func _clear_word_buttons():
	for btn in _word_letter_buttons:
		btn.queue_free()
	_word_letter_buttons.clear()

func _setup_word_buttons(word: String):
	for i in word.length():
		var btn := Button.new()
		btn.text = word[i]
		btn.add_theme_font_size_override("font_size", 44)
		btn.custom_minimum_size = Vector2(72, 72)
		ThemeManager.style_button(btn, Color("#4ECDC4"))
		btn.pressed.connect(_on_word_letter_pressed.bind(i))
		word_game_container.add_child(btn)
		_word_letter_buttons.append(btn)

func _on_word_letter_pressed(index: int):
	if _game_solved or _game_input_blocked or _is_transitioning:
		return

	var btn := _word_letter_buttons[index]
	var btn_letter := btn.text

	if btn_letter.to_lower() == letter.to_lower():
		_game_solved = true
		_game_input_blocked = true
		hint_label.hide()
		AudioManager.play_letter(letter)
		_play_word_correct_anim(btn)
		game_feedback_label.text = "Молодец! ✨"
		game_feedback_label.show()
		_show_correct_feedback_anim()
		ProgressManager.mark_letter_completed(letter)
		for b in _word_letter_buttons:
			if b.text.to_lower() == letter.to_lower():
				b.modulate = Color.GREEN
	else:
		_game_input_blocked = true
		_play_word_error_beep()
		_play_word_wrong_anim(btn)
		game_feedback_label.text = "Попробуй ещё!"
		game_feedback_label.show()
		await get_tree().create_timer(0.6).timeout
		_game_input_blocked = false
		game_feedback_label.hide()

func _play_word_correct_anim(btn: Button):
	Global.sparkle_at(btn.global_position + btn.size * 0.5, get_parent())
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BOUNCE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(1.3, 1.3), 0.15)
	tween.tween_property(btn, "scale", Vector2.ONE, 0.25)
	tween.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.2)
	tween.tween_property(btn, "scale", Vector2.ONE, 0.2)
	tween.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.15)
	tween.tween_property(btn, "scale", Vector2.ONE, 0.15)

func _show_correct_feedback_anim():
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	game_feedback_label.scale = Vector2.ZERO
	tween.tween_property(game_feedback_label, "scale", Vector2.ONE, 0.5)

func _play_word_wrong_anim(btn: Button):
	btn.modulate = Color.RED
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	var orig = btn.rotation_degrees
	for _k in 3:
		tween.tween_property(btn, "rotation_degrees", orig - 8, 0.04)
		tween.tween_property(btn, "rotation_degrees", orig + 8, 0.04)
	tween.tween_property(btn, "rotation_degrees", orig, 0.04)
	var reset := create_tween()
	reset.tween_interval(0.3)
	reset.tween_property(btn, "modulate", Color.WHITE, 0.2)

func _play_word_error_beep():
	var duration := 0.12
	var sample_rate := 22050
	var freq := 300.0
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	for i in num_samples:
		var t := float(i) / sample_rate
		var envelope := 1.0
		if t < 0.005:
			envelope = t / 0.005
		elif t > duration - 0.01:
			envelope = (duration - t) / 0.01
		var sample := sin(2.0 * PI * freq * t) * envelope * 0.3
		var val := int(sample * 16384)
		data[i * 2] = val & 0xFF
		data[i * 2 + 1] = (val >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	var player := AudioStreamPlayer2D.new()
	add_child(player)
	player.stream = wav
	player.play()
	player.finished.connect(player.queue_free)


func _play_hint_sound():
	var path := "res://assets/audio/hint_find_letter.wav"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var bytes := file.get_buffer(file.get_length())
	file.close()
	var data_start := 44
	for i in range(12, bytes.size() - 8):
		if bytes[i] == 0x64 and bytes[i+1] == 0x61 and bytes[i+2] == 0x74 and bytes[i+3] == 0x61:
			data_start = i + 8
			break
	var pcm := bytes.slice(data_start, bytes.size())
	var wav := AudioStreamWAV.new()
	wav.data = pcm
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.stereo = false
	var player := AudioStreamPlayer2D.new()
	add_child(player)
	player.stream = wav
	player.play()
	player.finished.connect(player.queue_free)

func _exit_tree():
	AudioManager.stop_all()
