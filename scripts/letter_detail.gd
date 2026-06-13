extends Control

const LETTERS := [
	"А", "Б", "В", "Г", "Д", "Е", "Ё", "Ж", "З", "И", "Й",
	"К", "Л", "М", "Н", "О", "П", "Р", "С", "Т", "У", "Ф",
	"Х", "Ц", "Ч", "Ш", "Щ", "Ъ", "Ы", "Ь", "Э", "Ю", "Я",
]

var letter: String = ""
var letter_name: String = ""
var _current_index: int = 0
var _image_texture_rect: TextureRect = null
var _is_transitioning: bool = false
var _word_letter_buttons: Array[Button] = []
var _game_solved: bool = false
var _game_input_blocked: bool = false
var _record_pulse_tween: Tween = null

@onready var back_button := $BackButton
@onready var content_wrapper := $ContentWrapper
@onready var letter_button := $ContentWrapper/VBoxContainer/MainHBox/LetterButton
@onready var letter_label := $ContentWrapper/VBoxContainer/MainHBox/LetterButton/LetterLabel
@onready var image_button := $ContentWrapper/VBoxContainer/MainHBox/ImageButton
@onready var image_center := $ContentWrapper/VBoxContainer/MainHBox/ImageButton/ImageCenter
@onready var placeholder_rect := $ContentWrapper/VBoxContainer/MainHBox/ImageButton/ImageCenter/PlaceholderRect
@onready var placeholder_label := $ContentWrapper/VBoxContainer/MainHBox/ImageButton/ImageCenter/PlaceholderLabel
@onready var word_label := $ContentWrapper/VBoxContainer/WordLabel
@onready var letter_sound_button := $ContentWrapper/VBoxContainer/AudioButtons/LetterSoundButton
@onready var word_sound_button := $ContentWrapper/VBoxContainer/AudioButtons/WordSoundButton
@onready var prev_button := $ContentWrapper/VBoxContainer/NavButtons/PrevButton
@onready var next_button := $ContentWrapper/VBoxContainer/NavButtons/NextButton
@onready var word_game_container := $ContentWrapper/VBoxContainer/WordGameContainer
@onready var game_feedback_label := $ContentWrapper/VBoxContainer/GameFeedbackLabel
@onready var voice_recorder := $VoiceRecorder
@onready var record_button := $ContentWrapper/VBoxContainer/AudioButtons/RecordButton
@onready var play_button := $ContentWrapper/VBoxContainer/AudioButtons/PlayButton

func _ready():
	var data := AlphabetData.get_letter_data(letter)
	_current_index = LETTERS.find(letter)
	if _current_index == -1:
		_current_index = 0

	_update_content(data)
	_connect_signals()
	apply_theme()
	ThemeManager.theme_changed.connect(_on_theme_changed)
	_play_appear_animation()

func _update_content(data: Dictionary):
	var ltr = data.get("letter", letter)
	letter_label.text = ltr
	word_label.text = data.get("word", "")
	placeholder_label.text = data.get("word_lower", "")

	_clear_image()
	var path = data.get("image_path", "")
	if not path.is_empty():
		_load_image(path)

	_update_nav_buttons()
	_update_placeholder_color(data)
	_reset_word_game()

func _clear_image():
	if _image_texture_rect:
		_image_texture_rect.queue_free()
		_image_texture_rect = null
	placeholder_rect.show()
	placeholder_label.show()

func _load_image(path: String):
	var img := Image.new()
	if img.load(path) != OK:
		return
	var tex := ImageTexture.create_from_image(img)
	_image_texture_rect = TextureRect.new()
	_image_texture_rect.texture = tex
	_image_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image_texture_rect.custom_minimum_size = placeholder_rect.custom_minimum_size
	_image_texture_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_image_texture_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_image_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	placeholder_rect.hide()
	placeholder_label.hide()
	image_center.add_child(_image_texture_rect)

func _update_placeholder_color(data: Dictionary):
	var ltr = data.get("letter", letter)
	var hue = float(ltr.unicode_at(0) % 10) / 10.0
	if ThemeManager.current_theme == "dark":
		placeholder_rect.color = Color.from_hsv(hue, 0.25, 0.25)
	else:
		var c = Color.from_hsv(hue, 0.35, 0.92)
		c.s = 0.35
		placeholder_rect.color = c

func _connect_signals():
	back_button.pressed.connect(_on_back_pressed)
	letter_button.pressed.connect(_on_letter_clicked)
	image_button.pressed.connect(_on_image_clicked)
	letter_sound_button.pressed.connect(_on_letter_sound_pressed)
	word_sound_button.pressed.connect(_on_word_sound_pressed)
	prev_button.pressed.connect(_on_prev_pressed)
	next_button.pressed.connect(_on_next_pressed)
	record_button.pressed.connect(_on_record_pressed)
	play_button.pressed.connect(_on_play_pressed)

func _update_nav_buttons():
	prev_button.disabled = _current_index <= 0
	next_button.disabled = _current_index >= LETTERS.size() - 1

func _on_letter_clicked():
	if _is_transitioning:
		return
	AudioManager.play_letter(letter)

func _on_image_clicked():
	if _is_transitioning:
		return
	AudioManager.play_word(letter)

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

	ProgressManager.mark_letter_completed(new_letter)
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

func _style_click_zone(btn: Button, normal_alpha: float = 0.0, hover_alpha: float = 0.12):
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1, 1, 1, normal_alpha)
	normal.set_corner_radius_all(16)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(1, 1, 1, hover_alpha)
	hover.set_corner_radius_all(16)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(1, 1, 1, hover_alpha * 1.5)
	pressed.set_corner_radius_all(16)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)

func _style_disabled_button(btn: Button):
	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Color(0.5, 0.5, 0.5, 0.3)
	disabled.set_corner_radius_all(20)
	disabled.content_margin_left = 20
	disabled.content_margin_right = 20
	disabled.content_margin_top = 12
	disabled.content_margin_bottom = 12
	btn.add_theme_stylebox_override("disabled", disabled)

func apply_theme():
	var text = ThemeManager.get_text()
	var bg = ThemeManager.get_bg()

	var style := StyleBoxFlat.new()
	style.bg_color = bg
	add_theme_stylebox_override("panel", style)

	letter_label.add_theme_color_override("font_color", text)
	word_label.add_theme_color_override("font_color", text)
	placeholder_label.add_theme_color_override("font_color", ThemeManager.get_text())

	if ThemeManager.current_theme == "dark":
		var hue = float(letter.unicode_at(0) % 10) / 10.0
		placeholder_rect.color = Color.from_hsv(hue, 0.25, 0.25)
	else:
		var hue = float(letter.unicode_at(0) % 10) / 10.0
		var c = Color.from_hsv(hue, 0.35, 0.92)
		c.s = 0.35
		placeholder_rect.color = c

	ThemeManager.style_button(letter_sound_button, Color("#4ECDC4"))
	ThemeManager.style_button(word_sound_button, Color("#45B7D1"))
	ThemeManager.style_button(record_button, Color("#FF6B6B"))
	ThemeManager.style_button(play_button, Color("#96CEB4"))
	ThemeManager.style_button(back_button, Color("#E8A87C"), Color("#2D2D2D"))
	ThemeManager.style_button(prev_button, Color("#96CEB4"), Color("#2D2D2D"))
	ThemeManager.style_button(next_button, Color("#96CEB4"), Color("#2D2D2D"))

	_style_click_zone(letter_button)
	_style_click_zone(image_button)
	_style_disabled_button(prev_button)
	_style_disabled_button(next_button)

func _reset_word_game():
	_game_solved = false
	_game_input_blocked = false
	_clear_word_buttons()
	game_feedback_label.hide()
	game_feedback_label.text = ""

	var data := AlphabetData.get_letter_data(letter)
	var word := data.get("word", "")
	if word.is_empty():
		return

	_setup_word_buttons(word)

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
		AudioManager.play_letter(letter)
		_play_word_correct_anim(btn)
		game_feedback_label.text = "Молодец! ✨"
		game_feedback_label.show()
		_show_correct_feedback_anim()
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


func _exit_tree():
	AudioManager.stop_all()
