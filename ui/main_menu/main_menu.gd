extends Control
## Главное меню «Азбука»: экран выбора игр.
##
## Показывает заголовок, счётчик прогресса «Прогресс: N / 33», компактную
## змейку из 33 кружков букв (изученные жёлтые, остальные серые) и кнопки
## четырёх игр. Дополнительно доступны кнопки настроек, доната и обратной
## связи. Навигация выполняется через get_tree().change_scene_to_file.

const MAIN_MENU_TITLE := "Азбука"

## Соответствие ключа игры пути к сцене-заглушке.
const GAME_SCENES := {
	"azbuka": "res://ui/games/azbuka/azbuka.tscn",
	"find_letter": "res://ui/games/find_letter/find_letter.tscn",
	"collect_word": "res://ui/games/collect_word/collect_word.tscn",
	"guess_picture": "res://ui/games/guess_picture/guess_picture.tscn",
}

## Соответствие ключа игры названию для логов.
const GAME_TITLES := {
	"azbuka": "Азбука",
	"find_letter": "Найди букву",
	"collect_word": "Собери слово",
	"guess_picture": "Угадай картинку",
}

## Путь к сцене главного меню.
const MAIN_MENU_SCENE := "res://ui/main_menu/main_menu.tscn"

## Цвет кружка изученной буквы.
const LETTER_LEARNED_COLOR := Color("#FFD54F")
## Цвет кружка ещё не изученной буквы.
const LETTER_PENDING_COLOR := Color("#B0BEC5")
## Цвет текста буквы внутри кружка.
const LETTER_TEXT_COLOR := Color("#2D2D2D")
## Размер стороны кружка буквы в пикселях.
const LETTER_CIRCLE_SIZE := 48
## Радиус скругления кружка буквы.
const LETTER_CIRCLE_RADIUS := 24

@onready var _background: ColorRect = %Background
@onready var _title_label: Label = %TitleLabel
@onready var _progress_label: Label = %ProgressLabel
@onready var _snake_preview: GridContainer = %SnakePreview
@onready var _games_button_azbuka: Button = %GamesButtonAzbuka
@onready var _games_button_find_letter: Button = %GamesButtonFindLetter
@onready var _games_button_collect_word: Button = %GamesButtonCollectWord
@onready var _games_button_guess_picture: Button = %GamesButtonGuessPicture
@onready var _settings_button: Button = %SettingsButton
@onready var _donate_button: Button = %DonateButton
@onready var _feedback_button: Button = %FeedbackButton

var _letter_circles: Array[Button] = []


func _ready() -> void:
	ProgressManager.progress_changed.connect(_on_progress_changed)
	ThemeManager.theme_changed.connect(_apply_theme)
	_games_button_azbuka.pressed.connect(_on_game_button_pressed.bind("azbuka"))
	_games_button_find_letter.pressed.connect(_on_game_button_pressed.bind("find_letter"))
	_games_button_collect_word.pressed.connect(_on_game_button_pressed.bind("collect_word"))
	_games_button_guess_picture.pressed.connect(_on_game_button_pressed.bind("guess_picture"))
	_settings_button.pressed.connect(_on_settings_button_pressed)
	_donate_button.pressed.connect(_on_donate_button_pressed)
	_feedback_button.pressed.connect(_on_feedback_button_pressed)
	_build_snake_preview()
	_update_progress_label(ProgressManager.get_learned_count())
	_apply_theme()


## Пересобирает полосу-змейку из кружков всех букв алфавита.
func _build_snake_preview() -> void:
	for child in _snake_preview.get_children():
		_snake_preview.remove_child(child)
		child.queue_free()
	_letter_circles.clear()
	for letter_data: Dictionary in AlphabetData.get_letters():
		var letter := str(letter_data["letter"])
		var circle := Button.new()
		circle.name = "LetterCircle" + letter
		circle.text = letter
		circle.custom_minimum_size = Vector2(LETTER_CIRCLE_SIZE, LETTER_CIRCLE_SIZE)
		circle.add_theme_font_size_override("font_size", 24)
		circle.add_theme_color_override("font_color", LETTER_TEXT_COLOR)
		circle.add_theme_color_override("font_hover_color", LETTER_TEXT_COLOR)
		circle.add_theme_color_override("font_pressed_color", LETTER_TEXT_COLOR)
		circle.tooltip_text = "Буква " + letter
		circle.accessibility_name = "Буква " + letter
		circle.pressed.connect(_on_letter_circle_pressed.bind(letter))
		_snake_preview.add_child(circle)
		_letter_circles.append(circle)
	_update_snake_colors()


## Перекрашивает кружки змейки по текущему прогрессу.
func _update_snake_colors() -> void:
	for circle: Button in _letter_circles:
		var letter := circle.text
		var color := LETTER_LEARNED_COLOR if ProgressManager.is_letter_completed(letter) else LETTER_PENDING_COLOR
		circle.add_theme_stylebox_override("normal", _make_circle_stylebox(color))
		circle.add_theme_stylebox_override("hover", _make_circle_stylebox(color.lightened(0.08)))
		circle.add_theme_stylebox_override("pressed", _make_circle_stylebox(color.darkened(0.08)))


## Создаёт круглый стиль для кружка буквы.
func _make_circle_stylebox(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(LETTER_CIRCLE_RADIUS)
	return box


## Обновляет счётчик прогресса.
func _update_progress_label(learned_count: int) -> void:
	var total := AlphabetData.get_letter_count()
	_progress_label.text = "Прогресс: %d / %d" % [learned_count, total]


## Применяет цвета текущей темы.
func _apply_theme(_mode: int = 0) -> void:
	_background.color = ThemeManager.get_bg()
	_title_label.add_theme_color_override("font_color", ThemeManager.get_text())
	_progress_label.add_theme_color_override("font_color", ThemeManager.get_text())
	var colors: Dictionary = ThemeManager.COLORS[ThemeManager.current_theme]
	var button_bg := colors["button_bg"] as Color
	var button_text := colors["button_text"] as Color
	ThemeManager.style_button(_games_button_azbuka, button_bg, button_text)
	ThemeManager.style_button(_games_button_find_letter, button_bg, button_text)
	ThemeManager.style_button(_games_button_collect_word, button_bg, button_text)
	ThemeManager.style_button(_games_button_guess_picture, button_bg, button_text)
	ThemeManager.style_button(_settings_button, button_bg, button_text)
	ThemeManager.style_button(_donate_button, button_bg, button_text)
	ThemeManager.style_button(_feedback_button, button_bg, button_text)


func _on_progress_changed(learned_count: int) -> void:
	_update_progress_label(learned_count)
	_update_snake_colors()
	GameLogger.info("MainMenu", "progress_updated", {"learned_count": learned_count})


func _on_game_button_pressed(game_key: String) -> void:
	var scene_path: String = GAME_SCENES[game_key]
	var title: String = GAME_TITLES[game_key]
	GameLogger.info("MainMenu", "game_button_pressed", {"game": game_key, "title": title})
	get_tree().change_scene_to_file(scene_path)


func _on_letter_circle_pressed(letter: String) -> void:
	GameLogger.info("MainMenu", "letter_circle_pressed", {"letter": letter})


func _on_settings_button_pressed() -> void:
	GameLogger.info("MainMenu", "settings_button_pressed", {})
	get_tree().change_scene_to_file("res://ui/settings/settings.tscn")


func _on_donate_button_pressed() -> void:
	GameLogger.info("MainMenu", "donate_button_pressed", {})
	get_tree().change_scene_to_file("res://ui/donate/donate_overlay.tscn")


func _on_feedback_button_pressed() -> void:
	GameLogger.info("MainMenu", "feedback_button_pressed", {})
	get_tree().change_scene_to_file("res://ui/feedback/feedback.tscn")
