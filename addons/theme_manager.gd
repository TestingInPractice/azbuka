extends Node
## ThemeManager: управление темой оформления (светлая / тёмная).
##
## Хранит текущую тему, отдаёт цвета через геттеры get_bg / get_text /
## get_card_bg и раскрашивает кнопки через style_button. Изменение темы
## рассылается сигналом theme_changed. Синглтон-автолоад, не зависит от
## других сервисов проекта.

enum ThemeMode { LIGHT, DARK }

## Тема изменилась. Слушатели перекрашивают свой UI.
signal theme_changed(mode: ThemeMode)

const THEME_LIGHT := "light"
const THEME_DARK := "dark"

## Текущая тема: "light" или "dark".
var current_theme: String = THEME_LIGHT

const COLORS := {
	"light": {
		"bg": Color("#F5F0E8"),
		"card_bg": Color("#FFFFFF"),
		"text": Color("#2D2D2D"),
		"button_bg": Color("#4ECDC4"),
		"button_text": Color("#FFFFFF"),
	},
	"dark": {
		"bg": Color("#2D2D2D"),
		"card_bg": Color("#3A3A3A"),
		"text": Color("#F5F0E8"),
		"button_bg": Color("#45B7D1"),
		"button_text": Color("#1A1A1A"),
	},
}


func get_current_mode() -> ThemeMode:
	return ThemeMode.DARK if current_theme == THEME_DARK else ThemeMode.LIGHT


func set_theme(mode: ThemeMode) -> void:
	var theme := THEME_LIGHT
	if mode == ThemeMode.DARK:
		theme = THEME_DARK
	if theme == current_theme:
		return
	current_theme = theme
	theme_changed.emit(mode)


func toggle_theme() -> void:
	if current_theme == THEME_LIGHT:
		set_theme(ThemeMode.DARK)
	else:
		set_theme(ThemeMode.LIGHT)


func get_bg() -> Color:
	return _color("bg")


func get_text() -> Color:
	return _color("text")


func get_card_bg() -> Color:
	return _color("card_bg")


func style_button(button: Button, bg_color: Color, text_color: Color = Color.WHITE) -> void:
	button.add_theme_stylebox_override("normal", _make_stylebox(bg_color))
	button.add_theme_stylebox_override("hover", _make_stylebox(bg_color.lightened(0.08)))
	button.add_theme_stylebox_override("pressed", _make_stylebox(bg_color.darkened(0.08)))
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)


func _color(key: String) -> Color:
	var theme_colors: Dictionary = COLORS[current_theme]
	return theme_colors[key] as Color


func _make_stylebox(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(24)
	box.content_margin_left = 32
	box.content_margin_right = 32
	box.content_margin_top = 24
	box.content_margin_bottom = 24
	return box
