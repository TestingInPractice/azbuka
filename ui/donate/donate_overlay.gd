extends Control
## Попап доната: заглушка.
##
## Затемнённый фон и карточка с двумя способами оплаты (СБП и ЮMoney).
## Оплата ещё не подключена: кнопки только логируют нажатие и показывают
## подсказку «Скоро». Закрытие возвращает в главное меню.

## Затемнение фона.
const BACKDROP_COLOR := Color(0.0, 0.0, 0.0, 0.65)
## Цвет текста подсказки «Скоро».
const SOON_COLOR := Color("#FFD54F")
## Радиус скругления углов карточки.
const CARD_RADIUS := 32

@onready var _backdrop: Button = %Backdrop
@onready var _donate_card: PanelContainer = %DonateCard
@onready var _title_label: Label = %TitleLabel
@onready var _sbp_button: Button = %SbPButton
@onready var _yumoney_button: Button = %YuMoneyButton
@onready var _soon_label: Label = %SoonLabel
@onready var _close_button: Button = %CloseButton
@onready var _soon_timer: Timer = %SoonTimer


func _ready() -> void:
	ThemeManager.theme_changed.connect(_apply_theme)
	_backdrop.pressed.connect(_on_backdrop_pressed)
	_sbp_button.pressed.connect(_on_sbp_button_pressed)
	_yumoney_button.pressed.connect(_on_yumoney_button_pressed)
	_close_button.pressed.connect(_on_close_pressed)
	_soon_timer.timeout.connect(_on_soon_timer_timeout)
	_apply_theme()


## Применяет цвета текущей темы.
func _apply_theme(_mode: int = 0) -> void:
	var backdrop_style := StyleBoxFlat.new()
	backdrop_style.bg_color = BACKDROP_COLOR
	_backdrop.add_theme_stylebox_override("normal", backdrop_style)
	_backdrop.add_theme_stylebox_override("hover", backdrop_style)
	_backdrop.add_theme_stylebox_override("pressed", backdrop_style)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = ThemeManager.get_card_bg()
	card_style.set_corner_radius_all(CARD_RADIUS)
	card_style.content_margin_left = 48
	card_style.content_margin_right = 48
	card_style.content_margin_top = 48
	card_style.content_margin_bottom = 48
	_donate_card.add_theme_stylebox_override("panel", card_style)
	_title_label.add_theme_color_override("font_color", ThemeManager.get_text())
	_soon_label.add_theme_color_override("font_color", SOON_COLOR)
	var colors: Dictionary = ThemeManager.COLORS[ThemeManager.current_theme]
	var button_bg := colors["button_bg"] as Color
	var button_text := colors["button_text"] as Color
	ThemeManager.style_button(_sbp_button, button_bg, button_text)
	ThemeManager.style_button(_yumoney_button, button_bg, button_text)
	ThemeManager.style_button(_close_button, button_bg, button_text)


func _on_sbp_button_pressed() -> void:
	GameLogger.info("DonateOverlay", "sbp_button_pressed", {})
	_show_soon_hint()


func _on_yumoney_button_pressed() -> void:
	GameLogger.info("DonateOverlay", "yumoney_button_pressed", {})
	_show_soon_hint()


## Показывает подсказку «Скоро» на три секунды.
func _show_soon_hint() -> void:
	_soon_label.visible = true
	_soon_timer.start()


func _on_soon_timer_timeout() -> void:
	_soon_label.visible = false


func _on_backdrop_pressed() -> void:
	GameLogger.info("DonateOverlay", "backdrop_pressed", {})
	_close_overlay()


func _on_close_pressed() -> void:
	GameLogger.info("DonateOverlay", "close_button_pressed", {})
	_close_overlay()


func _close_overlay() -> void:
	get_tree().change_scene_to_file("res://ui/main_menu/main_menu.tscn")
