extends Control

var letter: String = ""
var letter_name: String = ""

@onready var letter_label := $CenterContainer/VBoxContainer/LetterLabel
@onready var placeholder_rect := $CenterContainer/VBoxContainer/ImageContainer/PlaceholderRect
@onready var placeholder_label := $CenterContainer/VBoxContainer/ImageContainer/PlaceholderLabel
@onready var word_label := $CenterContainer/VBoxContainer/WordLabel
@onready var sound_button := $CenterContainer/VBoxContainer/SoundButton
@onready var back_button := $BackButton

func _ready():
	var data := AlphabetData.get_letter_data(letter)
	letter_label.text = letter
	word_label.text = data.get("word", "")
	placeholder_label.text = data.get("word_lower", "")

	var hue = float(letter.unicode_at(0) % 10) / 10.0
	var bg_color = Color.from_hsv(hue, 0.35, 0.92)
	bg_color.s = 0.35
	placeholder_rect.color = bg_color

	sound_button.pressed.connect(_on_sound_pressed)
	back_button.pressed.connect(_on_back_pressed)

	apply_theme()
	ThemeManager.theme_changed.connect(_on_theme_changed)

	_play_appear_animation()
	AudioManager.play_letter(letter)

func _on_theme_changed(_theme_name: String):
	apply_theme()

func apply_theme():
	var text = ThemeManager.get_text()
	var bg = ThemeManager.get_bg()

	var style := StyleBoxFlat.new()
	style.bg_color = bg
	add_theme_stylebox_override("panel", style)

	letter_label.add_theme_color_override("font_color", text)
	word_label.add_theme_color_override("font_color", text)
	sound_button.add_theme_color_override("font_color", text)
	back_button.add_theme_color_override("font_color", text)

	placeholder_label.add_theme_color_override("font_color", ThemeManager.get_text())

	if ThemeManager.current_theme == "dark":
		placeholder_rect.color = Color.from_hsv(
			float(letter.unicode_at(0) % 10) / 10.0,
			0.25, 0.25
		)
	else:
		var hue = float(letter.unicode_at(0) % 10) / 10.0
		placeholder_rect.color = Color.from_hsv(hue, 0.35, 0.92)
		placeholder_rect.color.s = 0.35

func _play_appear_animation():
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	letter_label.scale = Vector2.ZERO
	tween.tween_property(letter_label, "scale", Vector2.ONE, 0.5)

func _on_sound_pressed():
	if AudioManager.is_playing():
		AudioManager.stop_all()
	AudioManager.play_word(letter)

func _on_back_pressed():
	AudioManager.stop_all()
	Global.go_to_alphabet_screen()

func _exit_tree():
	AudioManager.stop_all()
