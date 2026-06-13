extends Control

const LETTERS := [
	"А", "Б", "В", "Г", "Д", "Е", "Ё", "Ж", "З", "И", "Й",
	"К", "Л", "М", "Н", "О", "П", "Р", "С", "Т", "У", "Ф",
	"Х", "Ц", "Ч", "Ш", "Щ", "Ъ", "Ы", "Ь", "Э", "Ю", "Я",
]

const DOTS_PER_LINE := 4
const LINE_HEIGHT := 130
const DOT_RADIUS := 26
const LINE_WIDTH := 6.0

const PATH_COLOR := Color("#5B8C5A")
const DOT_NORMAL := Color("#6B9B6A")
const DOT_COMPLETED := Color("#A0C4A0")
const DOT_CURRENT := Color("#F4D03F")

@onready var back_button := $VBoxContainer/TopBar/BackButton
@onready var title_label := $VBoxContainer/TopBar/TitleLabel
@onready var scroll_container := $VBoxContainer/ScrollContainer
@onready var path_container := $VBoxContainer/ScrollContainer/PathContainer
@onready var character := $VBoxContainer/ScrollContainer/PathContainer/Character
@onready var down_button := $VBoxContainer/ButtonBar/DownButton
@onready var up_button := $VBoxContainer/ButtonBar/UpButton

var dot_buttons: Array[Button] = []
var dot_positions: Array[Vector2] = []
var current_letter_idx := 0
var is_animating := false
var _dot_r: float = DOT_RADIUS
var _bob_tween: Tween

func _ready():
	_build_path()
	_setup_character()
	_connect_signals()
	apply_theme()
	ThemeManager.theme_changed.connect(_on_theme_changed)
	_update_dot_states()

func _build_path():
	var viewport_width = get_viewport().get_visible_rect().size.x
	var margin_x = max(60, viewport_width * 0.08)
	var spacing = (viewport_width - 2 * margin_x) / (DOTS_PER_LINE - 1)
	_dot_r = min(DOT_RADIUS, spacing * 0.25)

	for i in LETTERS.size():
		var line = i / DOTS_PER_LINE
		var pos_in_line = i % DOTS_PER_LINE
		var col = pos_in_line if line % 2 == 0 else (DOTS_PER_LINE - 1 - pos_in_line)
		var x = margin_x + col * spacing
		var y = 70 + line * LINE_HEIGHT
		dot_positions.append(Vector2(x, y))

	var last_pos = dot_positions[dot_positions.size() - 1]
	var container_height = last_pos.y + 80
	path_container.custom_minimum_size = Vector2(viewport_width, container_height)

	path_container.points = dot_positions
	path_container.line_color = PATH_COLOR
	path_container.line_width = LINE_WIDTH
	path_container.queue_redraw()

	for i in LETTERS.size():
		var btn = Button.new()
		btn.text = LETTERS[i]
		btn.size = Vector2(_dot_r * 2, _dot_r * 2)
		btn.position = dot_positions[i] - Vector2(_dot_r, _dot_r)
		btn.pivot_offset = Vector2(_dot_r, _dot_r)
		btn.add_theme_font_size_override("font_size", 20)
		btn.theme_override_constants/separation = 0
		btn.mouse_entered.connect(_on_dot_mouse_entered.bind(i))
		btn.mouse_exited.connect(_on_dot_mouse_exited.bind(i))
		btn.pressed.connect(_on_dot_pressed.bind(i))
		_style_dot(btn, 0)
		path_container.add_child(btn)
		dot_buttons.append(btn)

func _setup_character():
	character.text = "🐱"
	character.add_theme_font_size_override("font_size", 44)
	character.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var last_letter = ProgressManager.last_played
	if last_letter and last_letter in LETTERS:
		current_letter_idx = LETTERS.find(last_letter)
	character.position = dot_positions[current_letter_idx] - Vector2(22, 55)
	_start_idle_bob()

func _start_idle_bob():
	if _bob_tween and _bob_tween.is_valid():
		_bob_tween.kill()
	var base_y = character.position.y
	_bob_tween = create_tween().set_loops()
	_bob_tween.tween_property(character, "position:y", base_y - 6, 0.7).set_ease(Tween.EASE_IN_OUT)
	_bob_tween.tween_property(character, "position:y", base_y, 0.7).set_ease(Tween.EASE_IN_OUT)

func _connect_signals():
	back_button.pressed.connect(_on_back_pressed)
	down_button.pressed.connect(_on_down_pressed)
	up_button.pressed.connect(_on_up_pressed)

func _on_back_pressed():
	Global.go_to_main_menu()

func _on_down_pressed():
	if dot_positions.size() > 16:
		var target_y = int(max(0, dot_positions[16].y - 80))
		var tw = create_tween()
		tw.tween_property(scroll_container, "scroll_vertical", target_y, 0.4).set_ease(Tween.EASE_OUT)

func _on_up_pressed():
	var tw = create_tween()
	tw.tween_property(scroll_container, "scroll_vertical", 0, 0.4).set_ease(Tween.EASE_OUT)

func _on_dot_pressed(index: int):
	if is_animating or index == current_letter_idx:
		return
	animate_character_to(index)

func _on_dot_mouse_entered(index: int):
	dot_buttons[index].scale = Vector2(1.12, 1.12)

func _on_dot_mouse_exited(index: int):
	dot_buttons[index].scale = Vector2.ONE

func animate_character_to(target_idx: int):
	is_animating = true
	if _bob_tween and _bob_tween.is_valid():
		_bob_tween.kill()

	var scroll_target_y = int(max(0, dot_positions[target_idx].y - 100))
	var scroll_tw = create_tween()
	scroll_tw.tween_property(scroll_container, "scroll_vertical", scroll_target_y, 0.4)

	var positions = _get_path_positions(current_letter_idx, target_idx)
	var char_offset = Vector2(22, 55)
	var speed = 350.0

	var tw = create_tween()
	tw.set_parallel(false)
	for i in range(1, positions.size()):
		var dist = positions[i - 1].distance_to(positions[i])
		var seg_time = max(0.05, dist / speed)
		tw.tween_property(character, "position", positions[i] - char_offset, seg_time)

	await tw.finished

	var final_pos = positions[positions.size() - 1] - char_offset
	var bounce_tw = create_tween()
	bounce_tw.tween_property(character, "position:y", final_pos.y - 10, 0.08).set_ease(Tween.EASE_OUT)
	bounce_tw.tween_property(character, "position:y", final_pos.y, 0.12).set_ease(Tween.EASE_IN)
	await bounce_tw.finished

	current_letter_idx = target_idx
	_update_dot_states()
	is_animating = false
	_start_idle_bob()

	Global.go_to_letter_detail(LETTERS[current_letter_idx])

func _get_path_positions(from_idx: int, to_idx: int) -> Array[Vector2]:
	var result: Array[Vector2] = [dot_positions[from_idx]]
	var step = 1 if to_idx >= from_idx else -1
	var i = from_idx + step
	while i != to_idx:
		result.append(dot_positions[i])
		i += step
	result.append(dot_positions[to_idx])
	return result

func _update_dot_states():
	for i in LETTERS.size():
		var btn = dot_buttons[i]
		var letter = LETTERS[i]
		var is_completed = ProgressManager.is_letter_completed(letter)
		var is_current = i == current_letter_idx

		if is_current:
			_style_dot(btn, 2)
		elif is_completed:
			_style_dot(btn, 1)
		else:
			_style_dot(btn, 0)

		if is_completed and not is_current:
			btn.text = "✓"
		else:
			btn.text = letter

func _style_dot(btn: Button, state: int):
	var colors = [DOT_NORMAL, DOT_COMPLETED, DOT_CURRENT]
	var font_colors = [Color.WHITE, Color("#444444"), Color("#2D2D2D")]
	var color = colors[state]
	var fg = font_colors[state]

	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.set_corner_radius_all(_dot_r)
	normal.content_margin_left = 0
	normal.content_margin_right = 0
	normal.content_margin_top = 0
	normal.content_margin_bottom = 0

	if state == 2:
		normal.shadow_size = 12
		normal.shadow_color = Color(1, 0.84, 0, 0.5)

	var hover := StyleBoxFlat.new()
	hover.bg_color = color.lightened(0.15)
	hover.set_corner_radius_all(_dot_r)
	hover.content_margin_left = 0
	hover.content_margin_right = 0
	hover.content_margin_top = 0
	hover.content_margin_bottom = 0

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = color.darkened(0.15)
	pressed.set_corner_radius_all(_dot_r)
	pressed.content_margin_left = 0
	pressed.content_margin_right = 0
	pressed.content_margin_top = 0
	pressed.content_margin_bottom = 0

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", fg)

func _on_theme_changed(_theme_name: String):
	apply_theme()

func apply_theme():
	var bg = ThemeManager.get_bg()
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	add_theme_stylebox_override("panel", style)
	title_label.add_theme_color_override("font_color", ThemeManager.get_text())
	ThemeManager.style_button(back_button, Color("#E8A87C"), Color("#2D2D2D"))
	ThemeManager.style_button(down_button, Color("#5B8C5A"))
	ThemeManager.style_button(up_button, Color("#5B8C5A"))
