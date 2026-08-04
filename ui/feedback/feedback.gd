extends Control
## Экран обратной связи.
##
## Показывает краткое описание и кнопку «Отправить отзыв», которая открывает
## форму Google Sheets в браузере. Возврат в главное меню через кнопку
## «Назад».

## Ссылка на форму обратной связи.
## TODO: заменить на реальную ссылку формы Google Sheets.
const FEEDBACK_FORM_URL := "https://forms.gle/placeholder"

@onready var _background: ColorRect = %Background
@onready var _title_label: Label = %TitleLabel
@onready var _description_label: Label = %DescriptionLabel
@onready var _send_feedback_button: Button = %SendFeedbackButton
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	ThemeManager.theme_changed.connect(_apply_theme)
	_send_feedback_button.pressed.connect(_on_send_feedback_pressed)
	_back_button.pressed.connect(_on_back_button_pressed)
	_apply_theme()


## Применяет цвета текущей темы.
func _apply_theme(_mode: int = 0) -> void:
	_background.color = ThemeManager.get_bg()
	_title_label.add_theme_color_override("font_color", ThemeManager.get_text())
	_description_label.add_theme_color_override("font_color", ThemeManager.get_text())
	var colors: Dictionary = ThemeManager.COLORS[ThemeManager.current_theme]
	var button_bg := colors["button_bg"] as Color
	var button_text := colors["button_text"] as Color
	ThemeManager.style_button(_send_feedback_button, button_bg, button_text)
	ThemeManager.style_button(_back_button, button_bg, button_text)


func _on_send_feedback_pressed() -> void:
	GameLogger.info("Feedback", "send_feedback_pressed", {"url": FEEDBACK_FORM_URL})
	var error := OS.shell_open(FEEDBACK_FORM_URL)
	if error != OK:
		GameLogger.error("Feedback", "shell_open_failed", {"url": FEEDBACK_FORM_URL, "error": error})


func _on_back_button_pressed() -> void:
	GameLogger.info("Feedback", "back_button_pressed", {})
	get_tree().change_scene_to_file("res://ui/main_menu/main_menu.tscn")
