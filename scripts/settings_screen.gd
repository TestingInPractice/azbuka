extends Control

@onready var theme_button := $VBoxContainer/ThemeButton
@onready var theme_label := $VBoxContainer/ThemeLabel
@onready var back_button := $VBoxContainer/BackButton

func _ready():
	update_ui()
	theme_button.pressed.connect(_on_theme_toggled)
	back_button.pressed.connect(_on_back_pressed)
	ThemeManager.theme_changed.connect(_on_theme_changed)

func _on_theme_changed(_theme_name: String):
	update_ui()

func update_ui():
	var is_light = ThemeManager.current_theme == "light"
	theme_button.text = "☀️ Светлая тема" if is_light else "🌙 Тёмная тема"
	theme_label.text = "Текущая: " + ("Светлая" if is_light else "Тёмная")
	theme_label.add_theme_color_override("font_color", ThemeManager.get_text())

func _on_theme_toggled():
	ThemeManager.toggle_theme()

func _on_back_pressed():
	Global.go_to_alphabet_screen()
