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
		"button_text": Color("#2D2D2D"),
	},
	"dark": {
		"bg": Color("#2D2D2D"),
		"card_bg": Color("#3A3A3A"),
		"text": Color("#F5F0E8"),
		"button_bg": Color("#45B7D1"),
		"button_text": Color("#1A1A1A"),
	},
}

## Общая палитра акцентов и статусов. Семантические цвета не зависят от темы:
## они задают смысл (успех, ошибка, игра), а не фон. Все экраны берут их
## отсюда, чтобы одинаковые элементы не расходились по оттенкам.
const ACCENT_TEAL := Color("#4ECDC4")
const ACCENT_BLUE := Color("#45B7D1")
const ACCENT_RED := Color("#FF6B6B")
const ACCENT_GREEN := Color("#96CEB4")
const ACCENT_ORANGE := Color("#E8A87C")
const ACCENT_YELLOW := Color("#FFD93D")
const SUCCESS := Color("#43A047")
const ERROR := Color("#E53935")
const WARNING := Color("#E53935")
const INK := Color("#2D2D2D")
const INK_SOFT := Color("#444444")
const PATH_GREEN := Color("#5B8C5A")
const DOT_GREEN := Color("#6B9B6A")
const DOT_GOLD := Color("#FFD700")
const DOT_ACTIVE_GOLD := Color("#F4D03F")
const DOT_ACTIVE_SHADOW := Color(1, 0.84, 0, 0.5)

## Нейтральные цвета и состояния, которые повторяются на разных экранах.
## Держим их здесь, чтобы эффекты успеха/ошибки и тени не расходились.
const WHITE := Color.WHITE
const SUCCESS_MODULATE := Color.GREEN
const ERROR_MODULATE := Color.RED
const SUCCESS_FLASH := Color(0.6, 1.0, 0.7)
const ERROR_FLASH := Color(1.0, 0.55, 0.55)
const OVERLAY_DARK := Color(0, 0, 0, 0.3)
const DISABLED_BG := Color(0.5, 0.5, 0.5, 0.3)
const SHADOW_SOFT := Color(0, 0, 0, 0.2)
const SHADOW_MEDIUM := Color(0, 0, 0, 0.25)
const SHADOW_STRONG := Color(0, 0, 0, 0.3)

## Общий слой поверх иллюстрированных фонов. Он привязывает фотоэкраны
## к палитре темы, чтобы меню, азбука и карточка буквы не выглядели
## как разные приложения.
const SCREEN_OVERLAY_ALPHA_LIGHT := 0.28
const SCREEN_OVERLAY_ALPHA_DARK := 0.58
const CARD_RADIUS := 24


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


func get_card_bg_with_alpha(alpha: float) -> Color:
	return Color(get_card_bg(), alpha)


## Цвет общего затемнения поверх иллюстрированного фона. Светлая тема
## оставляет картинку читаемой, тёмная сильнее приглушает её под светлый текст.
func get_screen_overlay_color() -> Color:
	var alpha := SCREEN_OVERLAY_ALPHA_LIGHT
	if current_theme == THEME_DARK:
		alpha = SCREEN_OVERLAY_ALPHA_DARK
	return Color(get_bg(), alpha)


func style_screen_overlay(overlay: ColorRect) -> void:
	overlay.visible = true
	overlay.color = get_screen_overlay_color()


## Общая поверхность карточки: один цвет из темы и общий радиус.
func make_card_stylebox(radius: int = CARD_RADIUS) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = get_card_bg()
	box.set_corner_radius_all(radius)
	return box


## Общая плоская поверхность для квадратов и статусных кнопок.
func make_flat_stylebox(color: Color, radius: int = CARD_RADIUS) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	return box


func style_button(button: Button, bg_color: Color, text_color: Color = WHITE) -> void:
	button.add_theme_stylebox_override("normal", _make_stylebox(bg_color))
	button.add_theme_stylebox_override("hover", _make_stylebox(bg_color.lightened(0.08)))
	button.add_theme_stylebox_override("pressed", _make_stylebox(bg_color.darkened(0.08)))
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_focus_color", text_color)
	button.add_theme_color_override("font_hover_pressed_color", text_color)


## Кнопка целиком одного цвета: нужна для правильного/ошибочного ответа,
## где состояние важнее обычной hover-палитры.
func style_flat_button(button: Button, color: Color, text_color: Color = WHITE) -> void:
	button.add_theme_stylebox_override("normal", _make_stylebox(color))
	button.add_theme_stylebox_override("hover", _make_stylebox(color))
	button.add_theme_stylebox_override("pressed", _make_stylebox(color))
	button.add_theme_stylebox_override("disabled", _make_stylebox(color))
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_disabled_color", text_color)
	button.add_theme_color_override("font_focus_color", text_color)


func style_round_nav_button(button: Button) -> void:
	button.add_theme_stylebox_override(
		"normal", _make_round_stylebox(get_card_bg_with_alpha(0.7), 4, SHADOW_MEDIUM)
	)
	button.add_theme_stylebox_override(
		"hover", _make_round_stylebox(get_card_bg_with_alpha(0.85), 6, SHADOW_STRONG)
	)
	button.add_theme_stylebox_override(
		"pressed", _make_round_stylebox(get_card_bg_with_alpha(0.9), 2, SHADOW_SOFT)
	)
	button.add_theme_stylebox_override(
		"disabled", _make_round_stylebox(DISABLED_BG, 0, SHADOW_SOFT)
	)
	var text: Color = get_text()
	button.add_theme_color_override("font_color", text)
	button.add_theme_color_override("font_hover_color", text)
	button.add_theme_color_override("font_pressed_color", text)


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


func _make_round_stylebox(
	bg_color: Color, shadow_size: int, shadow_color: Color
) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg_color
	box.set_corner_radius_all(180)
	box.shadow_size = shadow_size
	box.shadow_color = shadow_color
	box.content_margin_left = 0
	box.content_margin_right = 0
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	return box
