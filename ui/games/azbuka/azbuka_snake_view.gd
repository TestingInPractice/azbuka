extends Node
class_name AzbukaSnakeView
## Раскладка змейки: считает позиции кружков, создаёт кнопки и красит их.
##
## Компонент не знает про анимацию кисы и уровни. Экран «Азбука» передаёт ему
## список букв и колбэки, а он держит геометрию и визуальные состояния точек.

const DOTS_PER_LINE := 4
const LINE_HEIGHT_MAX := 240.0
const DOT_RADIUS := 95.0
const LINE_WIDTH := 6.0
const VBOX_TOP := 60.0
const BUTTON_BAND_MIN := 150.0
const KISA_ANCHOR := Vector2.ZERO
const ARROW_SIZE := 128.0
const ARROW_GAP := 12.0
const ARROW_EDGE_MARGIN := 8.0

var dot_buttons: Array[Button] = []
var dot_positions: Array[Vector2] = []
var dot_radius: float = DOT_RADIUS
var prev_arrow_position := Vector2.ZERO
var next_arrow_position := Vector2.ZERO

var _spacing := 0.0
var _margin_x := 0.0
var _y_start := 0.0
var _line_height := 0.0

var _dot_styles: Dictionary = {}
var _owner: Control
var _snake_area: Control
var _snake_path: Line2D
var _kisa: KisaCat
var _home_button: Button
var _on_dot_pressed: Callable
var _on_dot_entered: Callable
var _on_dot_exited: Callable


func setup(
	owner: Control,
	snake_area: Control,
	snake_path: Line2D,
	kisa: KisaCat,
	home_button: Button,
	on_dot_pressed: Callable,
	on_dot_entered: Callable,
	on_dot_exited: Callable
) -> void:
	_owner = owner
	_snake_area = snake_area
	_snake_path = snake_path
	_kisa = kisa
	_home_button = home_button
	_on_dot_pressed = on_dot_pressed
	_on_dot_entered = on_dot_entered
	_on_dot_exited = on_dot_exited


func clear() -> void:
	for btn in dot_buttons:
		_snake_area.remove_child(btn)
		btn.queue_free()
	dot_buttons.clear()
	dot_positions.clear()
	prev_arrow_position = Vector2.ZERO
	next_arrow_position = Vector2.ZERO


func build(letters: Array[String]) -> void:
	var area_size: Vector2 = _snake_area.size
	_spacing = (area_size.x - 2.0 * maxf(60.0, area_size.x * 0.06)) / float(DOTS_PER_LINE - 1)
	var total_snake_width: float = _spacing * float(DOTS_PER_LINE - 1)
	_margin_x = (area_size.x - total_snake_width) / 2.0
	dot_radius = clampf(_spacing * 0.38, 95.0, DOT_RADIUS)
	_make_dot_styles()

	var total_lines: int = int(ceil(letters.size() / float(DOTS_PER_LINE)))
	var band: float = maxf(
		BUTTON_BAND_MIN,
		_home_button.get_global_rect().end.y - _snake_area.get_global_rect().position.y + 12.0
	)
	var available_height: float = maxf(0.0, area_size.y - VBOX_TOP - band)
	_line_height = clampf(
		(available_height - dot_radius * 2.0) / float(total_lines - 1),
		dot_radius * 1.8,
		LINE_HEIGHT_MAX
	)
	var snake_content_height: float = float(total_lines - 1) * _line_height + dot_radius * 2.0
	_y_start = band + (available_height - snake_content_height) / 2.0 + dot_radius
	if snake_content_height >= available_height:
		_y_start = band + dot_radius

	for i in letters.size():
		var line: int = i / DOTS_PER_LINE
		var pos_in_line: int = i % DOTS_PER_LINE
		var col: int = pos_in_line if line % 2 == 0 else (DOTS_PER_LINE - 1 - pos_in_line)
		var x: float = _margin_x + float(col) * _spacing
		var y: float = _y_start + float(line) * _line_height
		dot_positions.append(Vector2(x, y))

	if dot_positions.is_empty():
		return
	var next_slot := _slot_center(letters.size())
	next_arrow_position = _clamp_arrow_center(next_slot, area_size)
	prev_arrow_position = _clamp_arrow_center(
		Vector2(
			dot_positions[0].x,
			dot_positions[0].y - dot_radius - ARROW_GAP - ARROW_SIZE * 0.5
		),
		area_size
	)

	# Линия змейки ведёт к месту следующего кружка, где стоит правая стрелка.
	var path_points: Array[Vector2] = dot_positions.duplicate()
	path_points.append(next_arrow_position)
	_snake_path.points = path_points
	_snake_path.default_color = ThemeManager.PATH_GREEN
	_snake_path.width = LINE_WIDTH

	for i in letters.size():
		var btn := Button.new()
		btn.name = "SnakeCircle_" + letters[i]
		btn.accessibility_name = "SnakeCircle " + letters[i]
		btn.unique_name_in_owner = true
		btn.text = letters[i]
		btn.size = Vector2(dot_radius * 2.0, dot_radius * 2.0)
		btn.position = dot_positions[i] - Vector2(dot_radius, dot_radius)
		btn.pivot_offset = Vector2(dot_radius, dot_radius)
		btn.add_theme_font_size_override("font_size", maxi(16, int(dot_radius * 0.85)))
		btn.add_theme_constant_override("separation", 0)
		btn.mouse_entered.connect(_on_dot_entered.bind(i))
		btn.mouse_exited.connect(_on_dot_exited.bind(i))
		btn.pressed.connect(_on_dot_pressed.bind(i))
		style_dot(btn, 0)
		_snake_area.add_child(btn)
		btn.owner = _owner
		dot_buttons.append(btn)

	# Киса бежит поверх кружков.
	_snake_area.move_child(_kisa, -1)


func place_kisa_at_start(start_letter: String) -> int:
	var idx: int = dot_positions.find(_letter_position(start_letter))
	if idx < 0:
		idx = 0
	_kisa.position = dot_positions[idx] - KISA_ANCHOR
	_kisa.set_kisa_moving(false)
	_kisa.set_facing(true)
	return idx


func update_states(letters: Array[String], current_idx: int) -> void:
	for i in letters.size():
		var is_completed: bool = ProgressManager.is_letter_completed(letters[i])
		if i == current_idx:
			style_dot(dot_buttons[i], 2)
		elif is_completed:
			style_dot(dot_buttons[i], 1)
		else:
			style_dot(dot_buttons[i], 0)


func get_path_positions(from_idx: int, to_idx: int) -> Array[Vector2]:
	var result: Array[Vector2] = [dot_positions[from_idx]]
	var step: int = 1 if to_idx >= from_idx else -1
	var i: int = from_idx + step
	while i != to_idx:
		result.append(dot_positions[i])
		i += step
	result.append(dot_positions[to_idx])
	return result


func style_dot(btn: Button, state: int) -> void:
	var font_colors: Array[Color] = [ThemeManager.WHITE, ThemeManager.INK_SOFT, ThemeManager.INK]
	var fg: Color = font_colors[state]
	var styles: Dictionary = _dot_styles.get(state, {})
	if not styles.is_empty():
		btn.add_theme_stylebox_override("normal", styles["normal"])
		btn.add_theme_stylebox_override("hover", styles["hover"])
		btn.add_theme_stylebox_override("pressed", styles["pressed"])
	btn.add_theme_color_override("font_color", fg)


func _slot_center(index: int) -> Vector2:
	var line: int = index / DOTS_PER_LINE
	var pos_in_line: int = index % DOTS_PER_LINE
	var col: int = pos_in_line if line % 2 == 0 else (DOTS_PER_LINE - 1 - pos_in_line)
	return Vector2(_margin_x + float(col) * _spacing, _y_start + float(line) * _line_height)


func _clamp_arrow_center(pos: Vector2, area_size: Vector2) -> Vector2:
	var min_xy := Vector2.ONE * (ARROW_SIZE * 0.5 + ARROW_EDGE_MARGIN)
	var max_xy := area_size - min_xy
	return Vector2(
		clampf(pos.x, min_xy.x, max_xy.x),
		clampf(pos.y, min_xy.y, max_xy.y)
	)


func _letter_position(start_letter: String) -> Vector2:
	var letters: Array[String] = []
	for btn in dot_buttons:
		letters.append(btn.text)
	var idx: int = letters.find(start_letter)
	return dot_positions[idx] if idx >= 0 else Vector2.ZERO


func _make_dot_styles() -> void:
	_dot_styles.clear()
	var colors: Array[Color] = [
		ThemeManager.DOT_GREEN, ThemeManager.DOT_GOLD, ThemeManager.DOT_ACTIVE_GOLD
	]
	for state in colors.size():
		var color: Color = colors[state]
		var styles: Dictionary = {}

		var normal := StyleBoxFlat.new()
		normal.bg_color = color
		normal.set_corner_radius_all(int(dot_radius))
		normal.content_margin_left = 0
		normal.content_margin_right = 0
		normal.content_margin_top = 0
		normal.content_margin_bottom = 0
		if state == 2:
			normal.shadow_size = 12
			normal.shadow_color = ThemeManager.DOT_ACTIVE_SHADOW
		styles["normal"] = normal

		var hover := StyleBoxFlat.new()
		hover.bg_color = color.lightened(0.15)
		hover.set_corner_radius_all(int(dot_radius))
		hover.content_margin_left = 0
		hover.content_margin_right = 0
		hover.content_margin_top = 0
		hover.content_margin_bottom = 0
		styles["hover"] = hover

		var pressed := StyleBoxFlat.new()
		pressed.bg_color = color.darkened(0.15)
		pressed.set_corner_radius_all(int(dot_radius))
		pressed.content_margin_left = 0
		pressed.content_margin_right = 0
		pressed.content_margin_top = 0
		pressed.content_margin_bottom = 0
		styles["pressed"] = pressed

		_dot_styles[state] = styles
