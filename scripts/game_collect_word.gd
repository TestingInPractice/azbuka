extends Control

const TOTAL_ROUNDS := 5

var _round_words: Array[Dictionary] = []
var _current_word: Dictionary = {}
var _word_lower: String = ""
var _shuffled_letters: Array[String] = []
var _selected_letters: Array[String] = []
var _current_round: int = 0
var _is_animating: bool = false
var _letter_buttons: Array[Button] = []

@onready var rounds_label: Label = $CenterContainer/VBoxContainer/RoundsLabel
@onready var image_container: CenterContainer = $CenterContainer/VBoxContainer/ImageContainer
@onready var placeholder_rect: ColorRect = $CenterContainer/VBoxContainer/ImageContainer/PlaceholderRect
@onready var placeholder_label: Label = $CenterContainer/VBoxContainer/ImageContainer/PlaceholderLabel
@onready var word_builder: HBoxContainer = $CenterContainer/VBoxContainer/WordBuilderContainer/WordBuilder
@onready var feedback_label: Label = $CenterContainer/VBoxContainer/FeedbackLabel
@onready var letters_container: HBoxContainer = $CenterContainer/VBoxContainer/LettersCenterer/LettersContainer
@onready var back_button: Button = $BackButton


func _ready():
	_pick_round_words()
	_start_round()
	back_button.pressed.connect(_on_back_pressed)


func _pick_round_words():
	var pool: Array[Dictionary] = []
	for entry in AlphabetData.DATA:
		if entry.word_lower.length() >= 3:
			pool.append(entry.duplicate())

	pool.shuffle()
	_round_words = pool.slice(0, TOTAL_ROUNDS)

	while _round_words.size() < TOTAL_ROUNDS and pool.size() > 0:
		pool.shuffle()
		var extra = pool.slice(0, TOTAL_ROUNDS - _round_words.size())
		_round_words.append_array(extra)


func _start_round():
	_is_animating = false
	_current_word = _round_words[_current_round]
	_word_lower = _current_word.word_lower
	_selected_letters.clear()
	_letter_buttons.clear()

	rounds_label.text = "Раунд %d/%d" % [_current_round + 1, TOTAL_ROUNDS]

	var hue = float(_word_lower.unicode_at(0) % 10) / 10.0
	placeholder_rect.color = Color.from_hsv(hue, 0.35, 0.92)
	placeholder_label.text = _current_word.word

	for child in word_builder.get_children():
		child.queue_free()

	feedback_label.text = ""
	feedback_label.modulate = Color(1, 1, 1, 0)

	_shuffled_letters = _shuffle_word_letters(_word_lower)

	for child in letters_container.get_children():
		child.queue_free()

	for i in _shuffled_letters.size():
		var btn := Button.new()
		btn.text = _shuffled_letters[i]
		btn.theme_override_font_sizes["font_size"] = 36
		btn.custom_minimum_size = Vector2(64, 64)

		var style := StyleBoxFlat.new()
		style.bg_color = Color("#4ECDC4")
		style.set_corner_radius_all(10)
		btn.add_theme_stylebox_override("normal", style)

		var hover_style := StyleBoxFlat.new()
		hover_style.bg_color = Color("#4ECDC4").lightened(0.2)
		hover_style.set_corner_radius_all(10)
		btn.add_theme_stylebox_override("hover", hover_style)

		btn.pressed.connect(_on_letter_pressed.bind(btn))
		letters_container.add_child(btn)
		_letter_buttons.append(btn)

	_play_appear_animation()


func _shuffle_word_letters(word: String) -> Array[String]:
	var letters: Array[String] = []
	for c in word:
		letters.append(c)
	letters.shuffle()

	var original: Array[String] = []
	for c in word:
		original.append(c)

	if letters == original:
		letters.reverse()

	return letters


func _play_appear_animation():
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	image_container.scale = Vector2.ZERO
	tween.tween_property(image_container, "scale", Vector2.ONE, 0.5)

	rounds_label.modulate = Color(1, 1, 1, 0)
	var tw2 := create_tween()
	tw2.tween_property(rounds_label, "modulate", Color(0.4, 0.4, 0.5, 1), 0.3)


func _on_letter_pressed(btn: Button):
	if _is_animating:
		return

	var expected_index = _selected_letters.size()
	var expected_letter = _word_lower[expected_index]

	if btn.text == expected_letter:
		_selected_letters.append(btn.text)
		btn.disabled = true
		btn.modulate = Color(0.5, 0.5, 0.5, 0.4)

		var letter_label := Label.new()
		letter_label.text = btn.text
		letter_label.theme_override_font_sizes["font_size"] = 44
		word_builder.add_child(letter_label)

		AudioManager.play_letter(btn.text)

		if _selected_letters.size() == _word_lower.length():
			_on_word_complete()
	else:
		_is_animating = true
		AudioManager.play_letter(btn.text)
		_play_wrong_animation()


func _play_wrong_animation():
	for btn in _letter_buttons:
		if btn.disabled:
			continue
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_SINE)
		tw.tween_property(btn, "rotation", deg_to_rad(8), 0.04)
		tw.tween_property(btn, "rotation", deg_to_rad(-8), 0.04)
		tw.tween_property(btn, "rotation", deg_to_rad(5), 0.03)
		tw.tween_property(btn, "rotation", 0.0, 0.03)

		var tf := create_tween()
		tf.tween_property(btn, "modulate", Color(1, 0.2, 0.2, 1), 0.08)
		tf.tween_property(btn, "modulate", Color(1, 1, 1, 1), 0.25)

	await get_tree().create_timer(0.4).timeout

	for child in word_builder.get_children():
		child.queue_free()
	_selected_letters.clear()

	for btn in _letter_buttons:
		btn.disabled = false
		btn.modulate = Color(1, 1, 1, 1)

	_is_animating = false


func _on_word_complete():
	_is_animating = true
	feedback_label.text = "Молодец!"
	feedback_label.modulate = Color(1, 1, 1, 1)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	feedback_label.scale = Vector2.ZERO
	tween.tween_property(feedback_label, "scale", Vector2.ONE, 0.5)

	AudioManager.play_word(_current_word.letter)

	await get_tree().create_timer(1.5).timeout

	_current_round += 1
	if _current_round < _round_words.size():
		_start_round()
	else:
		_on_game_complete()


func _on_game_complete():
	feedback_label.text = "Отлично! Все слова собраны!"
	feedback_label.modulate = Color(1, 1, 1, 1)
	feedback_label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.1, 1))

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	feedback_label.scale = Vector2.ZERO
	tween.tween_property(feedback_label, "scale", Vector2.ONE, 0.5)

	await get_tree().create_timer(2.0).timeout
	Global.go_to_alphabet_screen()


func _on_back_pressed():
	AudioManager.stop_all()
	Global.go_to_alphabet_screen()


func _exit_tree():
	AudioManager.stop_all()
