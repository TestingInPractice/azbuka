extends Control

const TOTAL_ROUNDS := 10
const ANSWER_COUNT := 4

var _round := 0
var _score := 0
var _current_correct_letter := ""
var _answers: Array[String] = []
var _input_blocked := false

@onready var score_label: Label = $VBoxContainer/ScoreLabel
@onready var card_container: CenterContainer = $VBoxContainer/CardContainer
@onready var word_label: Label = $VBoxContainer/WordLabel
@onready var placeholder_rect: ColorRect = $VBoxContainer/CardContainer/PlaceholderRect
@onready var round_label: Label = $VBoxContainer/RoundLabel
@onready var answers_container: GridContainer = $VBoxContainer/AnswersContainer
@onready var results_container: VBoxContainer = $VBoxContainer/ResultsContainer
@onready var results_label: Label = $VBoxContainer/ResultsContainer/ResultsLabel
@onready var play_again_button: Button = $VBoxContainer/ResultsContainer/PlayAgainButton
@onready var back_button: Button = $BackButton

@onready var answer_buttons: Array[Button] = []

var _image_texture_rect: TextureRect = null

func _ready():
	for child in answers_container.get_children():
		if child is Button:
			answer_buttons.append(child)
	for i in answer_buttons.size():
		answer_buttons[i].pressed.connect(_on_answer_pressed.bind(i))
	play_again_button.pressed.connect(_on_play_again_pressed)
	back_button.pressed.connect(_on_back_pressed)

	for btn in answer_buttons:
		ThemeManager.style_button(btn, Color("#96CEB4"), Color("#2D2D2D"))
	ThemeManager.style_button(play_again_button, Color("#4ECDC4"))
	ThemeManager.style_button(back_button, Color("#E8A87C"), Color("#2D2D2D"))
	ThemeManager.style_button($BackButton, Color("#E8A87C"), Color("#2D2D2D"))

	_start_game()

func _start_game():
	_round = 0
	_score = 0
	score_label.text = "0 / %d" % TOTAL_ROUNDS
	results_container.hide()
	answers_container.show()
	card_container.show()
	round_label.show()
	_start_round()

func _start_round():
	_input_blocked = true
	_round += 1

	var data = AlphabetData.DATA
	var correct_idx = randi() % data.size()
	_current_correct_letter = data[correct_idx].letter

	var distractors: Array[String] = []
	var available: Array[int] = []
	for i in data.size():
		if data[i].letter != _current_correct_letter:
			available.append(i)
	available.shuffle()
	for i in range(min(ANSWER_COUNT - 1, available.size())):
		distractors.append(data[available[i]].letter)

	_answers = [_current_correct_letter] + distractors
	_answers.shuffle()

	var entry = AlphabetData.get_letter_data(_current_correct_letter)
	word_label.text = entry.get("word", "")
	round_label.text = "Найди букву: " + _current_correct_letter

	_load_word_image(entry)
	var hue = float(_current_correct_letter.unicode_at(0) % 10) / 10.0
	placeholder_rect.color = Color.from_hsv(hue, 0.35, 0.92)

	for i in answer_buttons.size():
		answer_buttons[i].text = _answers[i]
		answer_buttons[i].disabled = false

	_play_round_start_anim()

func _load_word_image(data: Dictionary):
	if _image_texture_rect:
		_image_texture_rect.queue_free()
		_image_texture_rect = null
	placeholder_rect.show()
	var path: String = data.get("image_path", "")
	if path.is_empty():
		return
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
	card_container.add_child(_image_texture_rect)


func _play_round_start_anim():
	card_container.modulate.a = 0.0
	card_container.scale = Vector2(0.3, 0.3)
	for btn in answer_buttons:
		btn.modulate = Color(1, 1, 1, 0)
		btn.scale = Vector2(0.5, 0.5)
		btn.rotation_degrees = 0.0
		btn.disabled = false

	var card_tween := create_tween()
	card_tween.set_trans(Tween.TRANS_BACK)
	card_tween.set_ease(Tween.EASE_OUT)
	card_tween.parallel().tween_property(card_container, "modulate:a", 1.0, 0.4)
	card_tween.parallel().tween_property(card_container, "scale", Vector2.ONE, 0.4)

	for i in answer_buttons.size():
		var btn_tween := create_tween()
		btn_tween.set_trans(Tween.TRANS_BACK)
		btn_tween.set_ease(Tween.EASE_OUT)
		btn_tween.tween_interval(0.06 * (i + 1))
		btn_tween.parallel().tween_property(answer_buttons[i], "modulate:a", 1.0, 0.3)
		btn_tween.parallel().tween_property(answer_buttons[i], "scale", Vector2.ONE, 0.3)

	var duration = 0.06 * answer_buttons.size() + 0.3 + 0.05
	await get_tree().create_timer(duration).timeout
	_input_blocked = false

func _on_answer_pressed(index: int):
	if _input_blocked:
		return

	var btn = answer_buttons[index]
	var selected = _answers[index]

	if selected == _current_correct_letter:
		_input_blocked = true
		_score += 1
		score_label.text = "%d / %d" % [_score, TOTAL_ROUNDS]
		AudioManager.play_letter(_current_correct_letter)
		_play_correct_anim(btn)
		await get_tree().create_timer(0.6).timeout
		if _round >= TOTAL_ROUNDS:
			_show_results()
		else:
			_start_round()
	else:
		btn.disabled = true
		_play_error_beep()
		_play_wrong_anim(btn)

func _play_error_beep():
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


func _play_correct_anim(btn: Button):
	btn.modulate = Color.GREEN
	Global.sparkle_at(btn.global_position + btn.size * 0.5, get_parent())
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BOUNCE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(1.2, 1.2), 0.15)
	tween.tween_property(btn, "scale", Vector2.ONE, 0.25)

func _play_wrong_anim(btn: Button):
	btn.modulate = Color.RED
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	var orig = btn.rotation_degrees
	for _k in 3:
		tween.tween_property(btn, "rotation_degrees", orig - 6, 0.04)
		tween.tween_property(btn, "rotation_degrees", orig + 6, 0.04)
	tween.tween_property(btn, "rotation_degrees", orig, 0.04)

func _show_results():
	ProgressManager.mark_game_played()
	answers_container.hide()
	card_container.hide()
	round_label.hide()
	results_container.show()
	results_label.text = "Результат: %d / %d" % [_score, TOTAL_ROUNDS]
	if _score == TOTAL_ROUNDS:
		results_label.text += "\nИдеально!"
	elif _score >= TOTAL_ROUNDS * 0.7:
		results_label.text += "\nОтлично!"
	else:
		results_label.text += "\nПопробуй ещё!"

func _on_play_again_pressed():
	_start_game()

func _on_back_pressed():
	AudioManager.stop_all()
	Global.go_to_main_menu()
