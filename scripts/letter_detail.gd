extends Control

var letter: String = ""
var letter_name: String = ""

@onready var letter_label := $CenterContainer/VBoxContainer/LetterLabel
@onready var image_container := $CenterContainer/VBoxContainer/ImageContainer
@onready var placeholder_rect := $CenterContainer/VBoxContainer/ImageContainer/PlaceholderRect
@onready var placeholder_label := $CenterContainer/VBoxContainer/ImageContainer/PlaceholderLabel
@onready var word_label := $CenterContainer/VBoxContainer/WordLabel
@onready var letter_sound_button := $CenterContainer/VBoxContainer/ButtonContainer/LetterSoundButton
@onready var word_sound_button := $CenterContainer/VBoxContainer/ButtonContainer/WordSoundButton
@onready var back_button := $BackButton

var _image_texture_rect: TextureRect = null

func _ready():
	var data := AlphabetData.get_letter_data(letter)
	letter_label.text = letter
	word_label.text = data.get("word", "")
	placeholder_label.text = data.get("word_lower", "")

	var hue = float(letter.unicode_at(0) % 10) / 10.0
	var bg_color = Color.from_hsv(hue, 0.35, 0.92)
	bg_color.s = 0.35
	placeholder_rect.color = bg_color

	letter_sound_button.pressed.connect(_on_letter_sound_pressed)
	word_sound_button.pressed.connect(_on_word_sound_pressed)
	back_button.pressed.connect(_on_back_pressed)

	ThemeManager.style_button(letter_sound_button, Color("#4ECDC4"))
	ThemeManager.style_button(word_sound_button, Color("#45B7D1"))
	ThemeManager.style_button(back_button, Color("#E8A87C"), Color("#2D2D2D"))

	apply_theme()
	ThemeManager.theme_changed.connect(_on_theme_changed)

	_load_image(data.get("image_path", ""))

	_play_appear_animation()

func _load_image(path: String):
	if path.is_empty():
		return
	var img := Image.new()
	if img.load(path) != OK:
		return
	var tex := ImageTexture.create_from_image(img)
	_image_texture_rect = TextureRect.new()
	_image_texture_rect.texture = tex
	_image_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image_texture_rect.custom_minimum_size = placeholder_rect.custom_minimum_size
	_image_texture_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_image_texture_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_image_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	placeholder_rect.hide()
	placeholder_label.hide()
	image_container.add_child(_image_texture_rect)

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

func _on_letter_sound_pressed():
	if AudioManager.is_playing():
		AudioManager.stop_all()
	AudioManager.play_letter(letter)

func _on_word_sound_pressed():
	if AudioManager.is_playing():
		AudioManager.stop_all()
	AudioManager.play_word(letter)

func _on_back_pressed():
	AudioManager.stop_all()
	Global.go_to_alphabet_screen()

func _exit_tree():
	AudioManager.stop_all()
