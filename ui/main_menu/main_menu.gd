extends Control
## Главное меню «Азбука»: экран выбора игр.
##
## Показывает заголовок и кнопки четырёх игр, каждая со своим цветом фона,
## чтобы ребёнку было проще различать игры. Навигация выполняется через
## get_tree().change_scene_to_file.

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

## Цвет фона кнопки каждой игры — разный, чтобы ребёнок различал игры.
const GAME_BUTTON_COLORS := {
	"azbuka": Color("#45B7D1"),
	"find_letter": Color("#FF6B6B"),
	"collect_word": Color("#96CEB4"),
	"guess_picture": Color("#FFD93D"),
}

## Цвет текста на кнопках игр (тёмный — читается на любом ярком фоне).
const GAME_BUTTON_TEXT_COLOR := Color("#2D2D2D")

@onready var _background: ColorRect = %Background
@onready var _title_label: Label = %TitleLabel
@onready var _games_button_azbuka: Button = %GamesButtonAzbuka
@onready var _games_button_find_letter: Button = %GamesButtonFindLetter
@onready var _games_button_collect_word: Button = %GamesButtonCollectWord
@onready var _games_button_guess_picture: Button = %GamesButtonGuessPicture
@onready var _settings_button: Button = %SettingsButton

## Кнопки игр по ключу игры.
var _game_buttons: Dictionary = {}


func _ready() -> void:
	ProgressManager.enabled_modes_changed.connect(_update_game_buttons_visibility)
	ThemeManager.theme_changed.connect(_apply_theme)
	_games_button_azbuka.pressed.connect(_on_game_button_pressed.bind("azbuka"))
	_games_button_find_letter.pressed.connect(_on_game_button_pressed.bind("find_letter"))
	_games_button_collect_word.pressed.connect(_on_game_button_pressed.bind("collect_word"))
	_games_button_guess_picture.pressed.connect(_on_game_button_pressed.bind("guess_picture"))
	_settings_button.pressed.connect(_on_settings_button_pressed)
	_game_buttons = {
		"azbuka": _games_button_azbuka,
		"find_letter": _games_button_find_letter,
		"collect_word": _games_button_collect_word,
		"guess_picture": _games_button_guess_picture,
	}
	_apply_theme()
	_update_game_buttons_visibility()


## Показывает только включённые в настройках игры, скрывая выключенные.
func _update_game_buttons_visibility(_modes: Dictionary = {}) -> void:
	_games_button_azbuka.visible = ProgressManager.is_mode_enabled("azbuka")
	_games_button_find_letter.visible = ProgressManager.is_mode_enabled("find_letter")
	_games_button_collect_word.visible = ProgressManager.is_mode_enabled("collect_word")
	_games_button_guess_picture.visible = ProgressManager.is_mode_enabled("guess_picture")


## Применяет цвета: кнопки игр получают свои постоянные цвета, остальное — из темы.
func _apply_theme(_mode: int = 0) -> void:
	_background.color = ThemeManager.get_bg()
	_title_label.add_theme_color_override("font_color", ThemeManager.get_text())
	var colors: Dictionary = ThemeManager.COLORS[ThemeManager.current_theme]
	var button_bg := colors["button_bg"] as Color
	var button_text := colors["button_text"] as Color
	for game_key: String in GAME_BUTTON_COLORS:
		var button: Button = _game_buttons[game_key]
		ThemeManager.style_button(button, GAME_BUTTON_COLORS[game_key], GAME_BUTTON_TEXT_COLOR)
	ThemeManager.style_button(_settings_button, button_bg, button_text)
	_settings_button.add_theme_color_override("icon_normal_color", button_text)
	_settings_button.add_theme_color_override("icon_hover_color", button_text)
	_settings_button.add_theme_color_override("icon_pressed_color", button_text)
	# Уменьшаем внутренние отступы шестерёнки, чтобы иконка занимала ~80% кнопки.
	var icon_margin := 8
	for style_state: StringName in ["normal", "hover", "pressed"]:
		var box := _settings_button.get_theme_stylebox(style_state) as StyleBoxFlat
		if box != null:
			box.content_margin_left = icon_margin
			box.content_margin_right = icon_margin
			box.content_margin_top = icon_margin
			box.content_margin_bottom = icon_margin


func _on_game_button_pressed(game_key: String) -> void:
	var scene_path: String = GAME_SCENES[game_key]
	var title: String = GAME_TITLES[game_key]
	GameLogger.info("MainMenu", "game_button_pressed", {"game": game_key, "title": title})
	get_tree().change_scene_to_file(scene_path)


func _on_settings_button_pressed() -> void:
	GameLogger.info("MainMenu", "settings_button_pressed", {})
	get_tree().change_scene_to_file("res://ui/settings/settings.tscn")
