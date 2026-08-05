extends Control
class_name DonateOverlay
## Попап доната.
##
## Затемнённый фон и карточка с двумя способами оплаты (СБП и ЮMoney).
## СБП показывает панель с QR-кодом и номером телефона: можно открыть
## приложение Сбербанка или скопировать номер. ЮMoney открывает платёжную
## форму. Закрытие возвращает на сцену, указанную в return_scene
## (по умолчанию — главное меню).

## Сцена, в которую возвращаться при закрытии (устанавливается перед переходом).
static var return_scene: String = "res://ui/main_menu/main_menu.tscn"

## Затемнение фона.
const BACKDROP_COLOR := Color(0.0, 0.0, 0.0, 0.65)
## Радиус скругления углов карточки.
const CARD_RADIUS := 32

## Платёжная форма ЮMoney (реквизиты автора проекта).
const YOOMONEY_URL := "https://yoomoney.ru/quickpay/confirm?receiver=4100117104887151&quickpay-form=button&sum=100&successURL=https://azbuka.app/spasibo"
## Номер телефона для перевода по СБП.
const SBP_PHONE := "+79044091470"
## Ссылка на приложение Сбербанка с предзаполненным номером СБП.
const SBERBANK_URL := "https://www.sberbank.com/sms/pbpn?requisiteNumber=79044091470"

@onready var _backdrop: Button = %Backdrop
@onready var _donate_card: PanelContainer = %DonateCard
@onready var _title_label: Label = %TitleLabel
@onready var _sbp_button: Button = %SbPButton
@onready var _yumoney_button: Button = %YuMoneyButton
@onready var _close_button: Button = %CloseButton
@onready var _sbp_panel: PanelContainer = %SbpPanel
@onready var _sbp_title_label: Label = %SbpTitleLabel
@onready var _phone_label: Label = %PhoneLabel
@onready var _open_bank_button: Button = %OpenBankButton
@onready var _copy_button: Button = %CopyButton
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	ThemeManager.theme_changed.connect(_apply_theme)
	_backdrop.pressed.connect(_on_backdrop_pressed)
	_sbp_button.pressed.connect(_on_sbp_button_pressed)
	_yumoney_button.pressed.connect(_on_yumoney_button_pressed)
	_close_button.pressed.connect(_on_close_pressed)
	_open_bank_button.pressed.connect(_on_open_bank_pressed)
	_copy_button.pressed.connect(_on_copy_pressed)
	_back_button.pressed.connect(_on_back_pressed)
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
	_sbp_panel.add_theme_stylebox_override("panel", card_style)
	_title_label.add_theme_color_override("font_color", ThemeManager.get_text())
	_sbp_title_label.add_theme_color_override("font_color", ThemeManager.get_text())
	_phone_label.add_theme_color_override("font_color", ThemeManager.get_text())
	var colors: Dictionary = ThemeManager.COLORS[ThemeManager.current_theme]
	var button_bg := colors["button_bg"] as Color
	var button_text := colors["button_text"] as Color
	ThemeManager.style_button(_sbp_button, button_bg, button_text)
	ThemeManager.style_button(_yumoney_button, button_bg, button_text)
	ThemeManager.style_button(_close_button, button_bg, button_text)
	ThemeManager.style_button(_open_bank_button, button_bg, button_text)
	ThemeManager.style_button(_copy_button, button_bg, button_text)
	ThemeManager.style_button(_back_button, button_bg, button_text)


## Открывает панель СБП с QR-кодом и номером телефона.
func _on_sbp_button_pressed() -> void:
	GameLogger.info("DonateOverlay", "sbp_button_pressed", {})
	_donate_card.visible = false
	_sbp_panel.visible = true


## Открывает платёжную форму ЮMoney.
func _on_yumoney_button_pressed() -> void:
	GameLogger.info("DonateOverlay", "yumoney_button_pressed", {})
	_open_url(YOOMONEY_URL)


## Копирует номер в буфер обмена и открывает приложение Сбербанка.
func _on_open_bank_pressed() -> void:
	GameLogger.info("DonateOverlay", "open_bank_pressed", {})
	DisplayServer.clipboard_set(SBP_PHONE)
	_open_url(SBERBANK_URL)


## Копирует номер телефона в буфер обмена.
func _on_copy_pressed() -> void:
	GameLogger.info("DonateOverlay", "copy_pressed", {})
	DisplayServer.clipboard_set(SBP_PHONE)


## Возвращает к выбору способа оплаты.
func _on_back_pressed() -> void:
	GameLogger.info("DonateOverlay", "sbp_back_pressed", {})
	_sbp_panel.visible = false
	_donate_card.visible = true


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
