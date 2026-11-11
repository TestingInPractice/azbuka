extends Control
## Главное меню «Азбука»: экран выбора игр.
##
## Показывает заголовок, большую кнопку азбуки и три плитки других игр,
## каждая со своим цветом фона, чтобы ребёнку было проще различать игры.
## Навигация выполняется через get_tree().change_scene_to_file.

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
	"guess_picture": "Подбери слово",
}

## Путь к сцене главного меню.
const MAIN_MENU_SCENE := "res://ui/main_menu/main_menu.tscn"

## Максимальная ширина колонки меню в design-пикселях. На телефоне при
## ширине 1080 это оставляет по 90 px с каждой стороны, на широком экране
## меню остаётся читаемой колонкой по центру.
const MAX_CONTENT_WIDTH := 900.0
const SIDE_MARGIN_RATIO := 0.08
const MIN_SIDE_MARGIN := 24.0
const MAX_SIDE_MARGIN := 90.0

## Фоновая музыка главного меню (зацикленная).
const MENU_MUSIC := "res://assets/audio/music/menu_theme.ogg"

## Цвет фона кнопки каждой игры — разный, чтобы ребёнок различал игры.
const GAME_BUTTON_COLORS := {
	"azbuka": ThemeManager.ACCENT_BLUE,
	"find_letter": ThemeManager.ACCENT_RED,
	"collect_word": ThemeManager.ACCENT_GREEN,
	"guess_picture": ThemeManager.ACCENT_YELLOW,
}

## Цвет текста на кнопках игр (тёмный — читается на любом ярком фоне).
const GAME_BUTTON_TEXT_COLOR := ThemeManager.INK

## Иконки кнопки звука: громкоговоритель включён или перечёркнут.
const SOUND_ICON_ON := preload("res://assets/icons/sound_on.svg")
const SOUND_ICON_OFF := preload("res://assets/icons/sound_off.svg")
## Имя кнопки звука для экранных дикторов.
const SOUND_ACCESSIBLE_ON := "Звук включён"
const SOUND_ACCESSIBLE_OFF := "Звук выключен"

@onready var _background_overlay: ColorRect = %BackgroundOverlay
@onready var _main_layout: VBoxContainer = %MainLayout
@onready var _title_label: Label = %TitleLabel
@onready var _primary_game_label: Label = %PrimaryGameLabel
@onready var _other_games_label: Label = %OtherGamesLabel
@onready var _games_button_azbuka: Button = %GamesButtonAzbuka
@onready var _games_button_find_letter: Button = %GamesButtonFindLetter
@onready var _games_button_collect_word: Button = %GamesButtonCollectWord
@onready var _games_button_guess_picture: Button = %GamesButtonGuessPicture
@onready var _settings_button: Button = %SettingsButton
@onready var _sound_button: Button = %SoundButton

## Кнопки игр по ключу игры.
var _game_buttons: Dictionary = {}


func _ready() -> void:
	GameLogger.analytics("app_open", {"scene": "main_menu"})
	ProgressManager.enabled_modes_changed.connect(_update_game_buttons_visibility)
	ThemeManager.theme_changed.connect(_apply_theme)
	_games_button_azbuka.pressed.connect(_on_game_button_pressed.bind("azbuka"))
	_games_button_find_letter.pressed.connect(_on_game_button_pressed.bind("find_letter"))
	_games_button_collect_word.pressed.connect(_on_game_button_pressed.bind("collect_word"))
	_games_button_guess_picture.pressed.connect(_on_game_button_pressed.bind("guess_picture"))
	_settings_button.pressed.connect(_on_settings_button_pressed)
	_sound_button.pressed.connect(_on_sound_button_pressed)
	_game_buttons = {
		"azbuka": _games_button_azbuka,
		"find_letter": _games_button_find_letter,
		"collect_word": _games_button_collect_word,
		"guess_picture": _games_button_guess_picture,
	}
	_update_content_width()
	get_viewport().size_changed.connect(_update_content_width)
	_apply_theme()
	_update_sound_button()
	_update_game_buttons_visibility()
	AudioManager.play_music(MENU_MUSIC)


## Держит колонку меню в читаемой ширине: на узком экране оставляет
## адаптивные боковые поля, на широком не даёт кнопкам растянуться на всю
## ширину монитора.
func _update_content_width() -> void:
	if _main_layout == null:
		return
	var viewport_width := get_viewport_rect().size.x
	var side_margin := clampf(viewport_width * SIDE_MARGIN_RATIO, MIN_SIDE_MARGIN, MAX_SIDE_MARGIN)
	var available_width := maxf(0.0, viewport_width - side_margin * 2.0)
	_main_layout.custom_minimum_size.x = minf(available_width, MAX_CONTENT_WIDTH)


## Показывает только включённые в настройках игры, скрывая выключенные.
## Подписи групп тоже скрываются, если в группе не осталось ни одной игры.
func _update_game_buttons_visibility(_modes: Dictionary = {}) -> void:
	var azbuka_enabled := ProgressManager.is_mode_enabled("azbuka")
	var find_enabled := ProgressManager.is_mode_enabled("find_letter")
	var collect_enabled := ProgressManager.is_mode_enabled("collect_word")
	var guess_enabled := ProgressManager.is_mode_enabled("guess_picture")
	_games_button_azbuka.visible = azbuka_enabled
	_games_button_find_letter.visible = find_enabled
	_games_button_collect_word.visible = collect_enabled
	_games_button_guess_picture.visible = guess_enabled
	_primary_game_label.visible = azbuka_enabled
	_other_games_label.visible = find_enabled or collect_enabled or guess_enabled


## Применяет цвета: кнопки игр получают свои постоянные цвета, остальное — из темы.
func _apply_theme(_mode: int = 0) -> void:
	ThemeManager.style_screen_overlay(_background_overlay)
	var text_color := ThemeManager.get_text()
	_title_label.add_theme_color_override("font_color", text_color)
	_primary_game_label.add_theme_color_override("font_color", text_color)
	_other_games_label.add_theme_color_override("font_color", text_color)
	var colors: Dictionary = ThemeManager.COLORS[ThemeManager.current_theme]
	var button_bg := colors["button_bg"] as Color
	var button_text := colors["button_text"] as Color
	for game_key: String in GAME_BUTTON_COLORS:
		var button: Button = _game_buttons[game_key]
		ThemeManager.style_button(button, GAME_BUTTON_COLORS[game_key], GAME_BUTTON_TEXT_COLOR)
		if button.icon != null:
			# Иконки игровых плиток нарисованы белыми, поэтому красим их в цвет
			# текста кнопки: на ярком фоне плитки тёмный значок читается лучше.
			for icon_color_name: StringName in [
				&"icon_normal_color", &"icon_hover_color", &"icon_pressed_color"
			]:
				button.add_theme_color_override(icon_color_name, GAME_BUTTON_TEXT_COLOR)
	ThemeManager.style_button(_settings_button, button_bg, button_text)
	ThemeManager.style_button(_sound_button, button_bg, button_text)
	# Иконки шестерёнки и звука получают цвет текста темы.
	for icon_button: Button in [_settings_button, _sound_button]:
		icon_button.add_theme_color_override("icon_normal_color", button_text)
		icon_button.add_theme_color_override("icon_hover_color", button_text)
		icon_button.add_theme_color_override("icon_pressed_color", button_text)
		# Уменьшаем внутренние отступы, чтобы иконка занимала ~80% кнопки.
		var icon_margin := 8
		for style_state: StringName in ["normal", "hover", "pressed"]:
			var box := icon_button.get_theme_stylebox(style_state) as StyleBoxFlat
			if box != null:
				box.content_margin_left = icon_margin
				box.content_margin_right = icon_margin
				box.content_margin_top = icon_margin
				box.content_margin_bottom = icon_margin


func _on_game_button_pressed(game_key: String) -> void:
	var scene_path: String = GAME_SCENES[game_key]
	var title: String = GAME_TITLES[game_key]
	GameLogger.info("MainMenu", "game_button_pressed", {"game": game_key, "title": title})
	# Меню-музыка играет только на экране выбора игры.
	AudioManager.stop_music()
	get_tree().change_scene_to_file(scene_path)


func _on_settings_button_pressed() -> void:
	GameLogger.info("MainMenu", "settings_button_pressed", {})
	ParentalGate.open(self, func() -> void:
		get_tree().change_scene_to_file("res://ui/settings/settings.tscn")
	)


## Переключает звук и сразу сохраняет выбор, чтобы он пережил перезапуск.
func _on_sound_button_pressed() -> void:
	var enabled := not AudioManager.sound_enabled
	AudioManager.set_sound_enabled(enabled)
	ProgressManager.set_sound_enabled(enabled)
	GameLogger.info("MainMenu", "sound_button_pressed", {"enabled": enabled})
	_update_sound_button()
	# set_sound_enabled(false) останавливает музыку, поэтому при включении
	# возвращаем её вручную: иначе кнопка «включить» оставляет меню молчащим.
	if enabled:
		AudioManager.play_music(MENU_MUSIC)


## Показывает на кнопке текущее состояние звука: иконку и имя для диктора.
func _update_sound_button() -> void:
	var enabled := AudioManager.sound_enabled
	_sound_button.icon = SOUND_ICON_ON if enabled else SOUND_ICON_OFF
	_sound_button.accessibility_name = SOUND_ACCESSIBLE_ON if enabled else SOUND_ACCESSIBLE_OFF
