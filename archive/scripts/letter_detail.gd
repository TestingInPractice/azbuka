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
var _level_bar: ColorRect = null
var _level_fill: ColorRect = null

@onready var back_button := $BackButton
@onready var content_wrapper := $ContentWrapper
@onready var letter_label := $ContentWrapper/VBoxContainer/LetterLabel
@onready var word_image := $ContentWrapper/ImageCenter/WordImage
@onready var word_sound_button := $WordSoundButton
@onready var letter_sound_button := $LetterSoundButton
@onready var prev_button := $PrevButton
@onready var next_button := $NextButton
@onready var word_game_container := $ContentWrapper/WordGameContainer
@onready var game_feedback_label := $ContentWrapper/GameFeedbackLabel
@onready var hint_label := $ContentWrapper/HintLabel
@onready var voice_recorder := $VoiceRecorder
@onready var record_button := $RecordButton
@onready var play_button := $PlayButton

func _ready():
	var data := AlphabetData.get_letter_data(letter)
	_current_index = LETTERS.find(letter)
	if _current_index == -1:
		_current_index = 0

	var viewport_h = get_viewport().get_visible_rect().size.y
	var fs: float = max(80.0, viewport_h / 4.0)
	letter_label.custom_minimum_size = Vector2(0, fs * 1.5)

	var ls = LabelSettings.new()
	ls.font_color = Color.WHITE
	ls.outline_color = ThemeManager.get_text()
	ls.outline_size = 4
	ls.font_size = int(fs)
	letter_label.label_settings = ls

	_update_content(data)
	GameLogger.info("letter_detail", "ready", {"letter": letter, "letter_name": letter_name, "index": _current_index})
	var bg_image := $ForestBackground/BgImage
	GameLogger.info("letter_detail", "bg_image_node", {"texture": str(bg_image.texture)})
	GameLogger.texture_diag("letter_detail", "background fone4", "res://assets/images/fone4.jpg")
	_update_nav_buttons()
	_connect_signals()
	_create_level_bar()
	apply_theme()
	ThemeManager.theme_changed.connect(_on_theme_changed)
	_play_appear_animation()
	set_process(true)

func _process(_delta):
	if _level_bar and _level_bar.visible:
		var level: float = voice_recorder.get_current_level()
		_level_fill.size.x = _level_bar.size.x * minf(level * 10.0, 1.0)
		if level > 0.5:
			_level_fill.color = Color("#FF6B6B")
		elif level > 0.2:
			_level_fill.color = Color("#FFD93D")
		else:
			_level_fill.color = Color("#4ECDC4")

func _create_level_bar():
	_level_bar = ColorRect.new()
	_level_bar.name = "LevelBar"
	_level_bar.mouse_filter = MOUSE_FILTER_IGNORE
	_level_bar.z_index = 100
	_level_bar.anchor_left = 0.0
	_level_bar.anchor_top = 1.0
	_level_bar.anchor_right = 1.0
	_level_bar.anchor_bottom = 1.0
	_level_bar.offset_left = 20.0
	_level_bar.offset_top = -46.0
	_level_bar.offset_right = -20.0
	_level_bar.offset_bottom = -20.0
	_level_bar.color = Color(0, 0, 0, 0.3)
	add_child(_level_bar)

	_level_fill = ColorRect.new()
	_level_fill.name = "LevelBarFill"
	_level_fill.mouse_filter = MOUSE_FILTER_IGNORE
	_level_fill.anchor_top = 0.0
	_level_fill.anchor_bottom = 1.0
	_level_fill.color = Color("#4ECDC4")
	_level_bar.add_child(_level_fill)

	var label := Label.new()
	label.name = "LevelBarLabel"
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.anchor_left = 0.0
	label.anchor_top = 0.0
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	label.text = "MIC"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.modulate.a = 0.5
	_level_bar.add_child(label)

	_level_bar.hide()

func _update_content(data: Dictionary):
	var ltr = data.get("letter", letter)
	letter_label.text = ltr + ltr.to_lower()
	var img_path = data.get("image_path", "")
	if not img_path.is_empty():
		var tex := load(img_path) as Texture2D
		word_image.texture = tex
		GameLogger.info("letter_detail", "word_image_load", {"path": img_path, "ok": tex != null})
		if tex:
			var vp = get_viewport().size
			var img_w: float = vp.x * 0.55
			var img_h: float = img_w * tex.get_height() / tex.get_width()
			word_image.custom_minimum_size = Vector2(img_w, img_h)
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
		record_button.text = "MIC"
		_level_bar.hide()
	else:
		voice_recorder.prepare_microphone()
		voice_recorder.start_recording()
		record_button.text = "REC"
		_level_bar.show()

func _on_play_pressed():
	if not voice_recorder.has_recording():
		print("Play: no recording")
		var tween = create_tween()
		tween.tween_property(play_button, "modulate:a", 0.4, 0.08)
		tween.tween_property(play_button, "modulate:a", 1.0, 0.08)
		return
	var size: int = voice_recorder.get_recorded_data().size()
	print("Play: has recording, data size=", size, " bytes (", size / 2.0 / AudioServer.get_mix_rate(), "s)")
	if voice_recorder.is_playing():
		voice_recorder.stop_playback()
	else:
		voice_recorder.play_recording()
		await get_tree().create_timer(0.1).timeout
		print("Play: player.playing=", voice_recorder.is_playing())

func _stop_recording_if_active():
	if voice_recorder.is_recording():
		voice_recorder.stop_recording()
		record_button.text = "MIC"
		_level_bar.hide()

func _auto_record_correct():
	while AudioManager.is_playing():
		await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	AudioManager.play_prompt("res://assets/audio/prompt_correct.wav")
	while AudioManager.is_playing():
		await get_tree().process_frame
	if voice_recorder.start_recording():
		record_button.text = "REC"
		_level_bar.show()
		await get_tree().create_timer(10.0).timeout
		voice_recorder.stop_recording()
		var rec_size: int = voice_recorder.get_recorded_data().size() if voice_recorder.has_recording() else 0
		print("Auto-record done: has_recording=", voice_recorder.has_recording(), " data_size=", rec_size)
		record_button.text = "MIC"
		_level_bar.hide()
		if rec_size > 0:
			_save_auto_recording()
			game_feedback_label.text = "Молодец! Нажми →"
			_show_correct_feedback_anim()
			AudioManager.play_prompt("res://assets/audio/prompt_forward.wav")
	else:
		push_warning("Auto-record: start_recording() returned false — microphone may be unavailable")

func _save_auto_recording():
	if not voice_recorder.has_recording():
		return
	var data: Dictionary = AlphabetData.get_letter_data(letter)
	var word: String = data.get("word_lower", "unknown")
	DirAccess.make_dir_recursive_absolute("user://recordings")
	var timestamp := Time.get_unix_time_from_system()
	var path := "user://recordings/%s_%s_%d.wav" % [letter.to_lower(), word, int(timestamp)]
	var ok: bool = voice_recorder.save_recording(path)
	print("Save recording to ", path, ": ", "OK" if ok else "FAILED")

func _on_back_pressed():
	AudioManager.stop_all()
	Global.last_visited_letter = letter
	Global.go_to_roadmap()

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
	_update_nav_buttons()

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

	var ls = letter_label.label_settings
	if not ls:
		ls = LabelSettings.new()
		letter_label.label_settings = ls
	ls.outline_color = text
	ls.font_color = Color.WHITE
	ls.outline_size = 4

	ThemeManager.style_button(letter_sound_button, Color("#4ECDC4"))
	ThemeManager.style_button(word_sound_button, Color("#45B7D1"))
	ThemeManager.style_button(record_button, Color("#FF6B6B"))
	ThemeManager.style_button(play_button, Color("#96CEB4"))
	ThemeManager.style_button(back_button, Color("#E8A87C"), Color("#2D2D2D"))
	_style_nav_button(prev_button, true)
	_style_nav_button(next_button, false)

	_style_disabled_button(prev_button)
	_style_disabled_button(next_button)

func _style_nav_button(btn: Button, is_left: bool):
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
	
	btn.add_theme_color_override("font_color", ThemeManager.get_text())
	btn.add_theme_color_override("font_hover_color", ThemeManager.get_text())
	btn.add_theme_color_override("font_pressed_color", ThemeManager.get_text())

func _style_disabled_button(btn: Button):
	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Color(0.5, 0.5, 0.5, 0.3)
	disabled.set_corner_radius_all(180)
	disabled.content_margin_left = 0
	disabled.content_margin_right = 0
	disabled.content_margin_top = 0
	disabled.content_margin_bottom = 0
	btn.add_theme_stylebox_override("disabled", disabled)

func _reset_word_game():
	_game_solved = false
	_game_input_blocked = false
	_clear_word_buttons()
	game_feedback_label.hide()
	game_feedback_label.text = ""
	hint_label.show()

	var data: Dictionary = AlphabetData.get_letter_data(letter)
	var word: String = data.get("word_lower", "")
	if word.is_empty():
		return

	_setup_word_buttons(word)
	_play_hint_sound()

func _clear_word_buttons():
	for btn in _word_letter_buttons:
		btn.queue_free()
	_word_letter_buttons.clear()

func _setup_word_buttons(word: String):
	var vp_w: float = get_viewport().get_visible_rect().size.x
	var padding: float = 80.0
	var separation: float = 24.0
	var max_btn_w: float = 110.0
	var min_btn_w: float = 56.0
	var available: float = vp_w - padding * 2
	var btn_w: float = clamp((available - separation * (word.length() - 1)) / word.length(), min_btn_w, max_btn_w)
	var btn_size := Vector2(btn_w, btn_w)
	var font_size: int = int(clamp(btn_w * 0.5, 28, 56))
	for i in word.length():
		var btn := Button.new()
		btn.text = word[i]
		btn.add_theme_font_size_override("font_size", font_size)
		btn.custom_minimum_size = btn_size
		btn.size_flags_horizontal = 0
		btn.size_flags_vertical = 0
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
		game_feedback_label.text = "Скажи всё слово!"
		game_feedback_label.show()
		_show_correct_feedback_anim()
		ProgressManager.mark_letter_completed(letter)
		for b in _word_letter_buttons:
			if b.text.to_lower() == letter.to_lower():
				b.modulate = Color.GREEN
		voice_recorder.prepare_microphone()
		_auto_record_correct()
	else:
		_game_input_blocked = true
		ProgressManager.mark_letter_errored(letter)
		_play_word_error_beep()
		_play_word_wrong_anim(btn)
		hint_label.hide()
		game_feedback_label.text = "Попробуй ещё!"
		game_feedback_label.show()
		await get_tree().create_timer(0.6).timeout
		_game_input_blocked = false
		game_feedback_label.hide()
		hint_label.show()

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
	if not ThemeManager.sound_enabled:
		return
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
	if not ThemeManager.sound_enabled:
		return
	var path := "res://assets/audio/hint_find_letter.wav"
	var wav := load(path) as AudioStream
	if not wav:
		return
	var player := AudioStreamPlayer2D.new()
	add_child(player)
	player.stream = wav
	player.play()
	player.finished.connect(player.queue_free)

func _exit_tree():
	AudioManager.stop_all()
