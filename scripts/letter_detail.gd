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

func _on_back_pressed():
	AudioManager.stop_all()
	Global.go_to_alphabet_screen()

func _on_prev_pressed():
	if _is_transitioning or _current_index <= 0:
		return
	_navigate_to(_current_index - 1, -1)

func _on_next_pressed():
	if _is_transitioning or _current_index >= LETTERS.size() - 1:
		return
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
	ThemeManager.style_button(back_button, Color("#E8A87C"), Color("#2D2D2D"))
	ThemeManager.style_button(prev_button, Color("#96CEB4"), Color("#2D2D2D"))
	ThemeManager.style_button(next_button, Color("#96CEB4"), Color("#2D2D2D"))

	_style_click_zone(letter_button)
	_style_click_zone(image_button)
	_style_disabled_button(prev_button)
	_style_disabled_button(next_button)

func _exit_tree():
	AudioManager.stop_all()
