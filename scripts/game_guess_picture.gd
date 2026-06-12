extends Control

const TOTAL_ROUNDS := 10

var _current_round := 0
var _score := 0
var _correct_letter := ""
var _correct_word := ""
var _is_waiting := false

@onready var letter_label := $CenterContainer/VBoxContainer/LetterLabel
@onready var round_label := $CenterContainer/VBoxContainer/RoundLabel
@onready var feedback_label := $CenterContainer/VBoxContainer/FeedbackLabel
@onready var score_label := $CenterContainer/VBoxContainer/ScoreLabel
@onready var options_grid := $CenterContainer/VBoxContainer/OptionsGrid
@onready var result_screen := $ResultScreen
@onready var result_score_label := $ResultScreen/ResultScoreLabel
@onready var play_again_button := $ResultScreen/PlayAgainButton
@onready var back_button := $BackButton


func _ready():
	back_button.pressed.connect(_on_back_pressed)
	play_again_button.pressed.connect(_on_play_again_pressed)
	_start_game()


func _start_game():
	_current_round = 0
	_score = 0
	_is_waiting = false
	result_screen.hide()
	options_grid.show()
	_next_round()


func _next_round():
	if _current_round >= TOTAL_ROUNDS:
		_show_results()
		return

	_current_round += 1
	round_label.text = "Раунд %d / %d" % [_current_round, TOTAL_ROUNDS]
	feedback_label.text = ""
	score_label.text = "Счёт: %d" % _score
	_is_waiting = false

	var all_data = AlphabetData.DATA
	var entry = all_data[randi() % all_data.size()]
	_correct_letter = entry.letter
	_correct_word = entry.word
	letter_label.text = entry.letter

	var options_pool = all_data.duplicate()
	var correct_idx = -1
	for i in options_pool.size():
		if options_pool[i].letter == entry.letter and options_pool[i].word == entry.word:
			correct_idx = i
			break
	if correct_idx >= 0:
		options_pool.remove_at(correct_idx)
	options_pool.shuffle()
	var options = [entry] + options_pool.slice(0, 3)
	options.shuffle()

	_clear_options()
	for opt in options:
		options_grid.add_child(_create_option_button(opt))


func _clear_options():
	for child in options_grid.get_children():
		child.queue_free()


func _create_option_button(data: Dictionary) -> Button:
	var btn = Button.new()
	btn.text = data.word
	btn.custom_minimum_size = Vector2(240, 180)
	btn.size_flags_horizontal = 4
	btn.size_flags_vertical = 4
	btn.add_theme_font_size_override("font_size", 28)

	var style = StyleBoxFlat.new()
	style.bg_color = _color_for_letter(data.letter)
	style.set_corner_radius_all(16)
	style.shadow_size = 4
	style.shadow_color = Color(0, 0, 0, 0.15)
	btn.add_theme_stylebox_override("normal", style)

	btn.pressed.connect(_on_option_pressed.bind(btn, data.word))
	return btn


func _color_for_letter(letter: String) -> Color:
	var hue = float(letter.unicode_at(0) % 10) / 10.0
	return Color.from_hsv(hue, 0.35, 0.88)


func _on_option_pressed(btn: Button, word: String):
	if _is_waiting:
		return
	_is_waiting = true

	var style = (btn.get_theme_stylebox("normal") as StyleBoxFlat).duplicate()
	if word == _correct_word:
		_score += 1
		feedback_label.text = "Молодец!"
		style.bg_color = Color(0.2, 0.7, 0.2)
		AudioManager.play_letter(_correct_letter)
	else:
		feedback_label.text = "Попробуй ещё!"
		style.bg_color = Color(0.7, 0.2, 0.2)
		AudioManager.play_letter("Э")

	btn.add_theme_stylebox_override("normal", style)
	score_label.text = "Счёт: %d" % _score

	await get_tree().create_timer(1.2).timeout
	_next_round()


func _show_results():
	letter_label.text = "Игра окончена!"
	round_label.text = ""
	feedback_label.text = ""
	score_label.text = ""
	options_grid.hide()
	result_screen.show()
	result_score_label.text = "Ваш счёт: %d / %d" % [_score, TOTAL_ROUNDS]


func _on_play_again_pressed():
	result_screen.hide()
	_start_game()


func _on_back_pressed():
	AudioManager.stop_all()
	Global.go_to_alphabet_screen()


func _exit_tree():
	AudioManager.stop_all()
