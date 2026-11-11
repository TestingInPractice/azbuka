extends Control
class_name AzbukaGame
## Экран «Азбука»: змейка из 33 букв, по которой бежит Киса.
##
## Буквы разложены серпантином. По нажатию на кружок Киса пробегает по
## маршруту до выбранной буквы и открывает карточку буквы. Геометрия змейки
## живёт в AzbukaSnakeView, а бег кисы - в AzbukaKisaRunner.

const MAIN_MENU_SCENE := "res://ui/main_menu/main_menu.tscn"
const LETTER_CARD_SCENE := "res://ui/games/azbuka/letter_card.tscn"

const LETTERS := [
	"А", "Б", "В", "Г", "Д", "Е", "Ё", "Ж", "З", "И", "Й",
	"К", "Л", "М", "Н", "О", "П", "Р", "С", "Т", "У", "Ф",
	"Х", "Ц", "Ч", "Ш", "Щ", "Ъ", "Ы", "Ь", "Э", "Ю", "Я",
]

## Буквы делятся на уровни, чтобы на экране не было всех 33 кружков сразу.
const LEVEL_SIZE := 11
const LEVEL_COUNT := 3

@onready var _background_overlay: ColorRect = %BackgroundOverlay
@onready var _back_button: Button = %BackButton
@onready var _home_button: Button = %HomeButton
@onready var _title_label: Label = %TitleLabel
@onready var _set_label: Label = %SetLabel
@onready var _level_button_1: Button = %LevelButton1
@onready var _level_button_2: Button = %LevelButton2
@onready var _level_button_3: Button = %LevelButton3
@onready var _prev_level_button: Button = %PrevLevelButton
@onready var _next_level_button: Button = %NextLevelButton
@onready var _snake_area: Control = %SnakeArea
@onready var _snake_path: Line2D = %SnakePath
@onready var _kisa: KisaCat = %KisaCat

var current_letter_idx := 0
var _level := 0
var _level_buttons: Array[Button] = []
var _building := false
var _navigating := false
var _snake: AzbukaSnakeView
var _runner: AzbukaKisaRunner

var dot_buttons: Array[Button]:
	get:
		return _snake.dot_buttons
var dot_positions: Array[Vector2]:
	get:
		return _snake.dot_positions
var is_animating: bool:
	get:
		return _runner.is_animating


func _ready() -> void:
	ProgressManager.mark_game_played()
	ThemeManager.theme_changed.connect(_apply_theme)
	_back_button.pressed.connect(_on_back_button_pressed)
	_home_button.pressed.connect(_on_home_button_pressed)
	_level_buttons = [_level_button_1, _level_button_2, _level_button_3]
	for i in _level_buttons.size():
		_level_buttons[i].pressed.connect(_on_level_pressed.bind(i))
	_prev_level_button.pressed.connect(_on_level_arrow_pressed.bind(-1))
	_next_level_button.pressed.connect(_on_level_arrow_pressed.bind(1))

	_snake = AzbukaSnakeView.new()
	_snake.name = "SnakeView"
	add_child(_snake)
	_snake.setup(
		self, _snake_area, _snake_path, _kisa, _home_button,
		_on_dot_pressed, _on_dot_mouse_entered, _on_dot_mouse_exited
	)

	_runner = AzbukaKisaRunner.new()
	_runner.name = "KisaRunner"
	add_child(_runner)

	var start_idx := LETTERS.find(LetterCard.from_letter)
	if start_idx >= 0:
		_level = int(start_idx / LEVEL_SIZE)
	GameLogger.analytics("game_start", {"game": "azbuka", "level": _level + 1})
	_kisa.set_kisa_moving(false)
	_apply_theme()
	_update_set_label()
	_snake_area.resized.connect(_on_snake_area_resized)
	_setup_snake()


## Тап по пустому месту во время бега ускоряет оставшийся путь, а не ждёт.
func _unhandled_input(event: InputEvent) -> void:
	if not is_animating:
		return
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_LEFT:
			_runner.request_skip()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_runner.request_skip()


## Перестраивает змейку при изменении размера области.
func _on_snake_area_resized() -> void:
	if not is_node_ready() or is_animating or _building:
		return
	_snake.clear()
	_setup_snake()


func _setup_snake() -> void:
	_building = true
	await get_tree().process_frame
	var letters: Array[String] = _letters_for_level(_level)
	_snake.build(letters)
	_position_level_arrows()
	current_letter_idx = _snake.place_kisa_at_start(LetterCard.from_letter)
	_snake.update_states(letters, current_letter_idx)
	_building = false


func _on_dot_pressed(index: int) -> void:
	if _navigating or _building:
		return
	if is_animating:
		_runner.request_skip()
		return
	var letters: Array[String] = _letters_for_level(_level)
	if index < 0 or index >= letters.size():
		return
	GameLogger.info("AzbukaGame", "letter_pressed",
		{"letter": letters[index], "level": _level + 1})
	if index == current_letter_idx:
		_open_letter_card(index)
		return
	_animate_kisa_to(index)


## Ведёт Кису по маршруту змейки до выбранной буквы и открывает карточку.
func _animate_kisa_to(target_idx: int) -> void:
	var letters: Array[String] = _letters_for_level(_level)
	if target_idx < 0 or target_idx >= letters.size():
		return
	if target_idx == current_letter_idx:
		_open_letter_card(target_idx)
		return
	var positions: Array[Vector2] = _snake.get_path_positions(current_letter_idx, target_idx)
	_runner.run(_kisa, positions, target_idx, letters[target_idx], _level, _on_kisa_run_finished)


func _on_kisa_run_finished(target_idx: int) -> void:
	current_letter_idx = target_idx
	_snake.update_states(_letters_for_level(_level), current_letter_idx)
	_open_letter_card(target_idx)


## Возвращает точки змейки от текущей буквы до целевой включительно.
func _get_path_positions(from_idx: int, to_idx: int) -> Array[Vector2]:
	return _snake.get_path_positions(from_idx, to_idx)


func _on_level_pressed(level: int) -> void:
	if level == _level or is_animating or _navigating or _building:
		return
	_level = clampi(level, 0, LEVEL_COUNT - 1)
	GameLogger.info("AzbukaGame", "level_changed", {"level": _level + 1})
	_snake.clear()
	_update_level_buttons()
	_setup_snake()


## Крупные нижние стрелки дублируют верхние кнопки уровней: взрослый
## выбирает номер, ребёнок листает понятными стрелками.
func _on_level_arrow_pressed(direction: int) -> void:
	var target := _level + direction
	if target < 0 or target >= LEVEL_COUNT:
		return
	if is_animating or _navigating or _building:
		return
	GameLogger.info("AzbukaGame", "level_arrow_pressed",
		{"direction": direction, "from": _level + 1, "to": target + 1})
	_on_level_pressed(target)


func _letters_for_level(level: int) -> Array[String]:
	var start := level * LEVEL_SIZE
	var end := mini(start + LEVEL_SIZE, LETTERS.size())
	var letters: Array[String] = []
	for i in range(start, end):
		letters.append(LETTERS[i])
	return letters


func _update_level_buttons() -> void:
	for i in _level_buttons.size():
		var active := i == _level
		var color := ThemeManager.DOT_ACTIVE_GOLD if active else ThemeManager.DOT_GREEN
		var text_color := ThemeManager.INK if active else ThemeManager.WHITE
		ThemeManager.style_button(_level_buttons[i], color, text_color)
	for arrow: Button in [_prev_level_button, _next_level_button]:
		ThemeManager.style_button(arrow, ThemeManager.ACCENT_ORANGE, ThemeManager.INK)
	_prev_level_button.disabled = _level <= 0
	_next_level_button.disabled = _level >= LEVEL_COUNT - 1
	_prev_level_button.modulate.a = 0.35 if _prev_level_button.disabled else 1.0
	_next_level_button.modulate.a = 0.35 if _next_level_button.disabled else 1.0
	_position_level_arrows()


## Стрелки стоят на краях змейки: правая там, где был бы следующий кружок,
## левая над первым кружком. Так ребёнок видит продолжение маршрута, а не
## отдельную панель управления внизу экрана.
func _position_level_arrows() -> void:
	if _snake == null or _snake.dot_positions.is_empty():
		return
	var arrow_size := Vector2(AzbukaSnakeView.ARROW_SIZE, AzbukaSnakeView.ARROW_SIZE)
	var origin := _snake_area.global_position
	for arrow: Button in [_prev_level_button, _next_level_button]:
		var min_size := arrow.get_combined_minimum_size()
		var actual_size := Vector2(
			maxf(arrow_size.x, min_size.x),
			maxf(arrow_size.y, min_size.y)
		)
		arrow.size = actual_size
		arrow.pivot_offset = actual_size * 0.5
	var prev_center := origin + _snake.prev_arrow_position
	var next_center := origin + _snake.next_arrow_position
	_prev_level_button.global_position = prev_center - _prev_level_button.size * 0.5
	_next_level_button.global_position = next_center - _next_level_button.size * 0.5


func _open_letter_card(index: int) -> void:
	if _navigating:
		return
	var letters: Array[String] = _letters_for_level(_level)
	if index < 0 or index >= letters.size():
		return
	_navigating = true
	LetterCard.from_letter = letters[index]
	GameLogger.analytics("letter_open",
		{"game": "azbuka", "letter": letters[index], "level": _level + 1})
	GameLogger.info("nav", "to_letter_card",
		{"from": "azbuka", "letter": letters[index], "level": _level + 1})
	AudioManager.stop_all()
	get_tree().change_scene_to_file(LETTER_CARD_SCENE)


func _on_dot_mouse_entered(index: int) -> void:
	_snake.dot_buttons[index].scale = Vector2(1.12, 1.12)


func _on_dot_mouse_exited(index: int) -> void:
	_snake.dot_buttons[index].scale = Vector2.ONE


func _apply_theme(_mode: int = 0) -> void:
	ThemeManager.style_screen_overlay(_background_overlay)
	_title_label.add_theme_color_override("font_color", ThemeManager.get_text())
	_set_label.add_theme_color_override("font_color", ThemeManager.get_text())
	ThemeManager.style_button(_back_button, ThemeManager.ACCENT_ORANGE, ThemeManager.INK)
	ThemeManager.style_button(_home_button, ThemeManager.ACCENT_ORANGE, ThemeManager.INK)
	_update_level_buttons()


## Подпись активного набора. У встроенных набора 1..5 имени нет, и подпись
## «Набор: 1» ничего не сообщает родителю, поэтому она скрыта и не занимает
## места в VBox. Название берётся из репозитория на входе в экран: после смены
## набора экран открывается заново, а удалённый набор даёт пустую строку.
func _update_set_label() -> void:
	var set_name := SetRepository.get_active_set_name()
	_set_label.visible = not set_name.is_empty()
	_set_label.text = ("Набор: " + set_name) if not set_name.is_empty() else ""


func _on_back_button_pressed() -> void:
	if is_animating or _navigating or _building:
		return
	_navigating = true
	GameLogger.info("nav", "to_main_menu", {"from": "azbuka"})
	AudioManager.stop_all()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_home_button_pressed() -> void:
	if is_animating or _navigating or _building:
		return
	_navigating = true
	GameLogger.info("nav", "to_main_menu", {"from": "azbuka_home"})
	AudioManager.stop_all()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
