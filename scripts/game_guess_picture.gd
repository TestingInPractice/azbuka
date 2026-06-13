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

	ThemeManager.style_button(back_button, Color("#E8A87C"), Color("#2D2D2D"))
	ThemeManager.style_button(play_again_button, Color("#4ECDC4"))

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

	var base_color = _color_for_letter(data.letter)

	var normal = StyleBoxFlat.new()
	normal.bg_color = base_color
	normal.set_corner_radius_all(20)
	normal.shadow_size = 6
	normal.shadow_color = Color(0, 0, 0, 0.2)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 12
	normal.content_margin_bottom = 12
	btn.add_theme_stylebox_override("normal", normal)

	var hover = StyleBoxFlat.new()
	hover.bg_color = base_color.lightened(0.15)
	hover.set_corner_radius_all(20)
	hover.shadow_size = 8
	hover.shadow_color = Color(0, 0, 0, 0.3)
	hover.content_margin_left = 16
	hover.content_margin_right = 16
	hover.content_margin_top = 12
	hover.content_margin_bottom = 12
	btn.add_theme_stylebox_override("hover", hover)

	var pressed = StyleBoxFlat.new()
	pressed.bg_color = base_color.darkened(0.15)
	pressed.set_corner_radius_all(20)
	pressed.shadow_size = 3
	pressed.shadow_color = Color(0, 0, 0, 0.15)
	pressed.content_margin_left = 16
	pressed.content_margin_right = 16
	pressed.content_margin_top = 12
	pressed.content_margin_bottom = 12
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_color_override("font_color", Color("#2D2D2D"))
	btn.add_theme_color_override("font_hover_color", Color("#2D2D2D"))
	btn.add_theme_color_override("font_pressed_color", Color("#2D2D2D"))
	btn.add_theme_color_override("font_focus_color", Color("#2D2D2D"))

	btn.pressed.connect(_on_option_pressed.bind(btn, data.word))
	return btn


func _color_for_letter(letter: String) -> Color:
	var hue = float(letter.unicode_at(0) % 10) / 10.0
	return Color.from_hsv(hue, 0.35, 0.88)


func _on_option_pressed(btn: Button, word: String):
	if _is_waiting:
		return

	if word == _correct_word:
		_is_waiting = true
		_score += 1
		feedback_label.text = "Молодец!"
		score_label.text = "Счёт: %d" % _score
		var style = (btn.get_theme_stylebox("normal") as StyleBoxFlat).duplicate()
		style.bg_color = Color(0.2, 0.7, 0.2)
		btn.add_theme_stylebox_override("normal", style)
		AudioManager.play_letter(_correct_letter)
		Global.sparkle_at(btn.global_position + btn.size * 0.5, get_parent())
		await get_tree().create_timer(1.2).timeout
		_next_round()
	else:
		var style = (btn.get_theme_stylebox("normal") as StyleBoxFlat).duplicate()
		style.bg_color = Color(0.7, 0.2, 0.2)
		btn.add_theme_stylebox_override("normal", style)
		btn.disabled = true
		feedback_label.text = "Попробуй ещё!"
		AudioManager.play_letter("Э")


func _show_results():
	ProgressManager.mark_game_played()
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
	Global.go_to_main_menu()


func _exit_tree():
	AudioManager.stop_all()
