extends Control

const LETTERS := [
	"А", "Б", "В", "Г", "Д", "Е", "Ё", "Ж", "З", "И", "Й",
	"К", "Л", "М", "Н", "О", "П", "Р", "С", "Т", "У", "Ф",
	"Х", "Ц", "Ч", "Ш", "Щ", "Ъ", "Ы", "Ь", "Э", "Ю", "Я",
]

const COLS := 5
const ROW_H := 200
const DOT_R := 32

var _dot_positions: Array[Vector2] = []
var _dot_buttons: Array[Button] = []

@onready var back_button := $VBoxContainer/TopBar/BackButton
@onready var title_label := $VBoxContainer/TopBar/TitleLabel
@onready var scroll_container := $VBoxContainer/ScrollContainer
@onready var snake_container := $VBoxContainer/ScrollContainer/SnakeContainer
@onready var settings_button := $SettingsButton

func _ready():
	_build_snake()
	_connect_signals()
	apply_theme()
	ThemeManager.theme_changed.connect(_on_theme_changed)

func _connect_signals():
	back_button.pressed.connect(_on_back_pressed)
	settings_button.pressed.connect(_on_settings_pressed)

func _build_snake():
	var viewport_w = get_viewport().get_visible_rect().size.x
	var margin_x = max(40, viewport_w * 0.06)
	var spacing_x = (viewport_w - 2 * margin_x) / (COLS - 1)

	for i in LETTERS.size():
		var row = i / COLS
		var col = i % COLS
		var is_rtl = row % 2 == 1
		var actual_col = (COLS - 1 - col) if is_rtl else col
		var x = margin_x + actual_col * spacing_x
		var y = 80 + row * ROW_H
		_dot_positions.append(Vector2(x, y))

	var total_h = 80 + (LETTERS.size() / COLS) * ROW_H + 160
	snake_container.custom_minimum_size = Vector2(viewport_w, total_h)
	snake_container.points = _dot_positions
	snake_container.line_width = 4.0

	for i in LETTERS.size():
		var btn = Button.new()
		btn.text = LETTERS[i]
		btn.size = Vector2(DOT_R * 2, DOT_R * 2)
		btn.position = _dot_positions[i] - Vector2(DOT_R, DOT_R)
		btn.pivot_offset = Vector2(DOT_R, DOT_R)
		btn.add_theme_font_size_override("font_size", 26)
		btn.pressed.connect(_on_dot_pressed.bind(i))
		btn.mouse_entered.connect(_on_dot_mouse_entered.bind(i))
		btn.mouse_exited.connect(_on_dot_mouse_exited.bind(i))
		snake_container.add_child(btn)
		_dot_buttons.append(btn)
		_animate_entrance(btn, i)

	_update_all_dots()

func _animate_entrance(btn: Button, index: int):
	btn.scale = Vector2.ZERO
	var tw = create_tween()
	tw.set_trans(Tween.TRANS_BACK)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.02 * index)
	tw.tween_property(btn, "scale", Vector2.ONE, 0.3)

func _on_dot_mouse_entered(index: int):
	var tw = create_tween()
	tw.set_trans(Tween.TRANS_BACK)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(_dot_buttons[index], "scale", Vector2(1.12, 1.12), 0.15)

func _on_dot_mouse_exited(index: int):
	var tw = create_tween()
	tw.set_trans(Tween.TRANS_BACK)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(_dot_buttons[index], "scale", Vector2.ONE, 0.12)

func _on_dot_pressed(index: int):
	Global.go_to_letter_detail(LETTERS[index])

func _on_back_pressed():
	Global.go_to_main_menu()

func _on_settings_pressed():
	Global.go_to_settings()

func _on_theme_changed(_theme_name: String):
	apply_theme()

func apply_theme():
	var bg = ThemeManager.get_bg()
	var text = ThemeManager.get_text()

	var panel := StyleBoxFlat.new()
	panel.bg_color = bg
	add_theme_stylebox_override("panel", panel)
	title_label.add_theme_color_override("font_color", text)

	ThemeManager.style_button(back_button, Color("#E8A87C"), Color("#2D2D2D"))
	ThemeManager.style_button(settings_button, Color("#DDA0DD"))

	if ThemeManager.current_theme == "dark":
		snake_container.line_color = Color("#4A7A49")
	else:
		snake_container.line_color = Color("#5B8C5A")
	snake_container.queue_redraw()

	_update_all_dots()

func _update_all_dots():
	for i in LETTERS.size():
		var btn = _dot_buttons[i]
		var letter = LETTERS[i]
		var is_completed = ProgressManager.is_letter_completed(letter)

		var base_color: Color
		if is_completed:
			base_color = Color("#4CAF50") if ThemeManager.current_theme == "light" else Color("#388E3C")
		else:
			base_color = Color("#9E9E9E") if ThemeManager.current_theme == "light" else Color("#616161")

		btn.text = letter
		btn.add_theme_color_override("font_color", Color.WHITE)

		var normal := StyleBoxFlat.new()
		normal.bg_color = base_color
		normal.set_corner_radius_all(DOT_R)
		normal.content_margin_left = 0
		normal.content_margin_right = 0
		normal.content_margin_top = 0
		normal.content_margin_bottom = 0

		if is_completed:
			normal.shadow_size = 2
			normal.shadow_color = Color(0, 0, 0, 0.15)

		var hover := StyleBoxFlat.new()
		hover.bg_color = base_color.lightened(0.15)
		hover.set_corner_radius_all(DOT_R)
		hover.content_margin_left = 0
		hover.content_margin_right = 0
		hover.content_margin_top = 0
		hover.content_margin_bottom = 0

		btn.add_theme_stylebox_override("normal", normal)
		btn.add_theme_stylebox_override("hover", hover)
