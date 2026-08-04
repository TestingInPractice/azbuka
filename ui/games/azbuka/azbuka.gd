extends Control
class_name AzbukaGame
## Экран «Азбука»: змейка из 33 букв, по которой бежит Киса.
##
## Буквы разложены серпантином. По нажатию на кружок Киса пробегает по
## маршруту до выбранной буквы и открывает карточку буквы.

const MAIN_MENU_SCENE := "res://ui/main_menu/main_menu.tscn"
const LETTER_CARD_SCENE := "res://ui/games/azbuka/letter_card.tscn"

const LETTERS := [
	"А", "Б", "В", "Г", "Д", "Е", "Ё", "Ж", "З", "И", "Й",
	"К", "Л", "М", "Н", "О", "П", "Р", "С", "Т", "У", "Ф",
	"Х", "Ц", "Ч", "Ш", "Щ", "Ъ", "Ы", "Ь", "Э", "Ю", "Я",
]

const DOTS_PER_LINE := 4
const LINE_HEIGHT := 110.0
const DOT_RADIUS := 33.0
const LINE_WIDTH := 6.0
const VBOX_TOP := 60.0
const RUN_SPEED := 420.0

const PATH_COLOR := Color("#5B8C5A")
const DOT_NORMAL := Color("#6B9B6A")
const DOT_COMPLETED := Color("#FFD700")
const DOT_CURRENT := Color("#F4D03F")

## Смещение Киски внутри её Control: лапы стоят в точке маршрута.
const KISA_ANCHOR := Vector2.ZERO

@onready var _background_overlay: ColorRect = %BackgroundOverlay
@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %TitleLabel
@onready var _snake_area: Control = %SnakeArea
@onready var _snake_path: Line2D = %SnakePath
@onready var _kisa: KisaCat = %KisaCat

var dot_buttons: Array[Button] = []
var dot_positions: Array[Vector2] = []
var current_letter_idx := 0
var is_animating := false
var _dot_r: float = DOT_RADIUS
var _dot_styles: Dictionary = {}
var _building := false


func _ready() -> void:
	ProgressManager.mark_game_played()
	ThemeManager.theme_changed.connect(_apply_theme)
	_back_button.pressed.connect(_on_back_button_pressed)
	_kisa.set_kisa_moving(false)
	_apply_theme()
	_snake_area.resized.connect(_on_snake_area_resized)
	_setup_snake()


## Перестраивает змейку при изменении размера области, чтобы путь, кружки и
## Киса оставались отцентрированы при расширении/сжатии окна.
func _on_snake_area_resized() -> void:
	if not is_node_ready() or is_animating or _building:
		return
	for btn in dot_buttons:
		_snake_area.remove_child(btn)
		btn.queue_free()
	dot_buttons.clear()
	dot_positions.clear()
	_setup_snake()


func _setup_snake() -> void:
	_building = true
	await get_tree().process_frame
	_build_path()
	_place_kisa_at_start()
	_update_dot_states()
	_building = false


func _build_path() -> void:
	var area_size: Vector2 = _snake_area.size
	var spacing: float = (area_size.x - 2.0 * maxf(60.0, area_size.x * 0.08)) / float(DOTS_PER_LINE - 1)
	spacing *= 0.5
	var total_snake_width: float = spacing * float(DOTS_PER_LINE - 1)
	var margin_x: float = (area_size.x - total_snake_width) / 2.0
	_dot_r = clampf(spacing * 0.44, 28.0, DOT_RADIUS)
	_make_dot_styles()

	var total_lines: int = int(ceil(LETTERS.size() / float(DOTS_PER_LINE)))
	var snake_content_height: float = float(total_lines - 1) * LINE_HEIGHT + _dot_r * 2.0
	var scroll_height: float = area_size.y - VBOX_TOP
	var y_start: float = 20.0
	if snake_content_height < scroll_height:
		y_start = (scroll_height - snake_content_height) / 2.0 + _dot_r - 100.0

	for i in LETTERS.size():
		var line: int = i / DOTS_PER_LINE
		var pos_in_line: int = i % DOTS_PER_LINE
		var col: int = pos_in_line if line % 2 == 0 else (DOTS_PER_LINE - 1 - pos_in_line)
		var x: float = margin_x + float(col) * spacing
		var y: float = y_start + float(line) * LINE_HEIGHT
		dot_positions.append(Vector2(x, y))

	_snake_path.points = dot_positions
	_snake_path.default_color = PATH_COLOR
	_snake_path.width = LINE_WIDTH

	for i in LETTERS.size():
		var btn := Button.new()
		btn.name = "SnakeCircle_" + LETTERS[i]
		btn.accessibility_name = "SnakeCircle " + LETTERS[i]
		btn.unique_name_in_owner = true
		btn.text = LETTERS[i]
		btn.size = Vector2(_dot_r * 2.0, _dot_r * 2.0)
		btn.position = dot_positions[i] - Vector2(_dot_r, _dot_r)
		btn.pivot_offset = Vector2(_dot_r, _dot_r)
		btn.add_theme_font_size_override("font_size", maxi(12, int(_dot_r * 0.77)))
		btn.add_theme_constant_override("separation", 0)
		btn.mouse_entered.connect(_on_dot_mouse_entered.bind(i))
		btn.mouse_exited.connect(_on_dot_mouse_exited.bind(i))
		btn.pressed.connect(_on_dot_pressed.bind(i))
		_style_dot(btn, 0)
		_snake_area.add_child(btn)
		btn.owner = self
		dot_buttons.append(btn)

	# Киса бежит поверх кружков.
	_snake_area.move_child(_kisa, -1)


func _place_kisa_at_start() -> void:
	var start_letter: String = LetterCard.from_letter
	if start_letter.is_empty() or not start_letter in LETTERS:
		start_letter = LETTERS[0]
	current_letter_idx = LETTERS.find(start_letter)
	if current_letter_idx < 0:
		current_letter_idx = 0
	_kisa.position = dot_positions[current_letter_idx] - KISA_ANCHOR
	_kisa.set_facing(true)


func _on_dot_pressed(index: int) -> void:
	if is_animating:
		return
	GameLogger.info("AzbukaGame", "letter_pressed", {"letter": LETTERS[index]})
	if index == current_letter_idx:
		_open_letter_card(index)
		return
	_animate_kisa_to(index)


func _animate_kisa_to(target_idx: int) -> void:
	is_animating = true
	_kisa.set_kisa_moving(true)
	var positions: Array[Vector2] = _get_path_positions(current_letter_idx, target_idx)
	var dx: float = positions[positions.size() - 1].x - positions[0].x
	_kisa.set_facing(dx >= 0.0)

	var tw := create_tween()
	for i in range(1, positions.size()):
		var dist: float = positions[i - 1].distance_to(positions[i])
		var seg_time: float = maxf(0.05, dist / RUN_SPEED)
		tw.tween_property(_kisa, "position", positions[i] - KISA_ANCHOR, seg_time)
	await tw.finished

	var final_pos: Vector2 = positions[positions.size() - 1] - KISA_ANCHOR
	var bounce := create_tween()
	bounce.tween_property(_kisa, "position:y", final_pos.y - 10.0, 0.08).set_ease(Tween.EASE_OUT)
	bounce.tween_property(_kisa, "position:y", final_pos.y, 0.12).set_ease(Tween.EASE_IN)
	await bounce.finished

	current_letter_idx = target_idx
	_update_dot_states()
	_kisa.set_kisa_moving(false)
	is_animating = false
	_open_letter_card(target_idx)


func _get_path_positions(from_idx: int, to_idx: int) -> Array[Vector2]:
	var result: Array[Vector2] = [dot_positions[from_idx]]
	var step: int = 1 if to_idx >= from_idx else -1
	var i: int = from_idx + step
	while i != to_idx:
		result.append(dot_positions[i])
		i += step
	result.append(dot_positions[to_idx])
	return result


func _open_letter_card(index: int) -> void:
	LetterCard.from_letter = LETTERS[index]
	GameLogger.info("nav", "to_letter_card", {"from": "azbuka", "letter": LETTERS[index]})
	AudioManager.stop_all()
	get_tree().change_scene_to_file(LETTER_CARD_SCENE)


func _on_dot_mouse_entered(index: int) -> void:
	dot_buttons[index].scale = Vector2(1.12, 1.12)


func _on_dot_mouse_exited(index: int) -> void:
	dot_buttons[index].scale = Vector2.ONE


func _update_dot_states() -> void:
	for i in LETTERS.size():
		var is_completed: bool = ProgressManager.is_letter_completed(LETTERS[i])
		if i == current_letter_idx:
			_style_dot(dot_buttons[i], 2)
		elif is_completed:
			_style_dot(dot_buttons[i], 1)
		else:
			_style_dot(dot_buttons[i], 0)


func _make_dot_styles() -> void:
	_dot_styles.clear()
	var colors: Array[Color] = [DOT_NORMAL, DOT_COMPLETED, DOT_CURRENT]
	for state in colors.size():
		var color: Color = colors[state]
		var styles: Dictionary = {}

		var normal := StyleBoxFlat.new()
		normal.bg_color = color
		normal.set_corner_radius_all(int(_dot_r))
		normal.content_margin_left = 0
		normal.content_margin_right = 0
		normal.content_margin_top = 0
		normal.content_margin_bottom = 0
		if state == 2:
			normal.shadow_size = 12
			normal.shadow_color = Color(1, 0.84, 0, 0.5)
		styles["normal"] = normal

		var hover := StyleBoxFlat.new()
		hover.bg_color = color.lightened(0.15)
		hover.set_corner_radius_all(int(_dot_r))
		hover.content_margin_left = 0
		hover.content_margin_right = 0
		hover.content_margin_top = 0
		hover.content_margin_bottom = 0
		styles["hover"] = hover

		var pressed := StyleBoxFlat.new()
		pressed.bg_color = color.darkened(0.15)
		pressed.set_corner_radius_all(int(_dot_r))
		pressed.content_margin_left = 0
		pressed.content_margin_right = 0
		pressed.content_margin_top = 0
		pressed.content_margin_bottom = 0
		styles["pressed"] = pressed

		_dot_styles[state] = styles


func _style_dot(btn: Button, state: int) -> void:
	var font_colors: Array[Color] = [Color.WHITE, Color("#444444"), Color("#2D2D2D")]
	var fg: Color = font_colors[state]
	var styles: Dictionary = _dot_styles.get(state, {})
	if not styles.is_empty():
		btn.add_theme_stylebox_override("normal", styles["normal"])
		btn.add_theme_stylebox_override("hover", styles["hover"])
		btn.add_theme_stylebox_override("pressed", styles["pressed"])
	btn.add_theme_color_override("font_color", fg)


func _apply_theme(_mode: int = 0) -> void:
	_background_overlay.visible = ThemeManager.current_theme == ThemeManager.THEME_DARK
	_title_label.add_theme_color_override("font_color", ThemeManager.get_text())
	ThemeManager.style_button(_back_button, Color("#E8A87C"), Color("#2D2D2D"))


func _on_back_button_pressed() -> void:
	GameLogger.info("nav", "to_main_menu", {"from": "azbuka"})
	AudioManager.stop_all()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
