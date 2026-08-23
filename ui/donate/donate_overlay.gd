extends Control
class_name DonateOverlay
## Попап доната.
##
## Затемнённый фон и карточка с кнопкой CloudTips — единственным способом
## поддержки. Кнопка открывает платёжную страницу cloudtips.ru (в вебе — в
## новой вкладке, нативно — в системном браузере). Закрытие возвращает на
## сцену, указанную в return_scene (по умолчанию — главное меню).

## Сцена, в которую возвращаться при закрытии (устанавливается перед переходом).
static var return_scene: String = "res://ui/main_menu/main_menu.tscn"

## Затемнение фона.
const BACKDROP_COLOR := Color(0.0, 0.0, 0.0, 0.65)
## Радиус скругления углов карточки.
const CARD_RADIUS := 32

## Страница CloudTips — способ поддержки проекта.
const CLOUDTIPS_URL := "https://pay.cloudtips.ru/p/e21e29f5"

@onready var _backdrop: Button = %Backdrop
@onready var _donate_card: PanelContainer = %DonateCard
@onready var _title_label: Label = %TitleLabel
@onready var _cloudtips_button: Button = %CloudTipsButton
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	ThemeManager.theme_changed.connect(_apply_theme)
	_backdrop.pressed.connect(_on_backdrop_pressed)
	_cloudtips_button.pressed.connect(_on_cloudtips_button_pressed)
	_close_button.pressed.connect(_on_close_pressed)
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
	var colors: Dictionary = ThemeManager.COLORS[ThemeManager.current_theme]
	var button_bg := colors["button_bg"] as Color
	var button_text := colors["button_text"] as Color
	ThemeManager.style_button(_cloudtips_button, button_bg, button_text)
	ThemeManager.style_button(_close_button, button_bg, button_text)


## Открывает страницу CloudTips.
func _on_cloudtips_button_pressed() -> void:
	GameLogger.info("DonateOverlay", "cloudtips_button_pressed", {})
	_open_url(CLOUDTIPS_URL)


## Открывает URL в новой вкладке (в вебе) или в системном браузере.
func _open_url(url: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.open('%s', '_blank')" % url)
	else:
		OS.shell_open(url)


func _on_backdrop_pressed() -> void:
	GameLogger.info("DonateOverlay", "backdrop_pressed", {})
	_close_overlay()


func _on_close_pressed() -> void:
	GameLogger.info("DonateOverlay", "close_button_pressed", {})
	_close_overlay()


func _close_overlay() -> void:
	get_tree().change_scene_to_file(return_scene)
