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
@onready var word_label: Label = $VBoxContainer/CardContainer/WordLabel
@onready var placeholder_rect: ColorRect = $VBoxContainer/CardContainer/PlaceholderRect
@onready var round_label: Label = $VBoxContainer/RoundLabel
@onready var answers_container: GridContainer = $VBoxContainer/AnswersContainer
@onready var results_container: VBoxContainer = $VBoxContainer/ResultsContainer
@onready var results_label: Label = $VBoxContainer/ResultsContainer/ResultsLabel
@onready var play_again_button: Button = $VBoxContainer/ResultsContainer/PlayAgainButton
@onready var back_button: Button = $VBoxContainer/ResultsContainer/BackButton

@onready var answer_buttons: Array[Button] = []

func _ready():
	for child in answers_container.get_children():
		if child is Button:
			answer_buttons.append(child)
	for i in answer_buttons.size():
		answer_buttons[i].pressed.connect(_on_answer_pressed.bind(i))
	play_again_button.pressed.connect(_on_play_again_pressed)
	back_button.pressed.connect(_on_back_pressed)
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
	round_label.text = "Найди букву:"

	var hue = float(_current_correct_letter.unicode_at(0) % 10) / 10.0
	placeholder_rect.color = Color.from_hsv(hue, 0.35, 0.92)

	for i in answer_buttons.size():
		answer_buttons[i].text = _answers[i]
		answer_buttons[i].disabled = false

	_play_round_start_anim()

func _play_round_start_anim():
	card_container.modulate.a = 0.0
	card_container.scale = Vector2(0.3, 0.3)
	for btn in answer_buttons:
		btn.modulate.a = 0.0
		btn.scale = Vector2(0.5, 0.5)
		btn.modulate = Color.WHITE
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
		AudioManager.play_word(_current_correct_letter)
		_play_wrong_anim(btn)

func _play_correct_anim(btn: Button):
	btn.modulate = Color.GREEN
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
	Global.go_to_alphabet_screen()
