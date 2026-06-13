extends Node

signal theme_changed(theme_name: String)

const LIGHT_BG := Color("#FFF5E6")
const LIGHT_CARD_BG := Color("#FFFFFF")
const LIGHT_TEXT := Color("#333333")

const DARK_BG := Color("#1A1A2E")
const DARK_CARD_BG := Color("#16213E")
const DARK_TEXT := Color("#E0E0E0")

var current_theme: String = "light"

func _ready():
	load_settings()
	apply_theme()

func toggle_theme():
	current_theme = "dark" if current_theme == "light" else "light"
	apply_theme()
	save_settings()

func get_bg() -> Color:
	return LIGHT_BG if current_theme == "light" else DARK_BG

func get_card_bg() -> Color:
	return LIGHT_CARD_BG if current_theme == "light" else DARK_CARD_BG

func get_text() -> Color:
	return LIGHT_TEXT if current_theme == "light" else DARK_TEXT

func apply_theme():
	var bg := StyleBoxFlat.new()
	bg.bg_color = get_bg()
	if get_tree() and get_tree().root:
		get_tree().root.add_theme_stylebox_override("panel", bg)
	theme_changed.emit(current_theme)

func load_settings():
	var config := ConfigFile.new()
	var err := config.load("user://settings.json")
	if err == OK:
		var saved = config.get_value("theme", "current", "light")
		if saved in ["light", "dark"]:
			current_theme = saved

func save_settings():
	var config := ConfigFile.new()
	config.set_value("theme", "current", current_theme)
	config.save("user://settings.json")


func style_button(btn: Button, bg_color: Color, font_color: Color = Color.WHITE, corner_radius: float = 20) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg_color
	normal.set_corner_radius_all(corner_radius)
	normal.shadow_size = 6
	normal.shadow_color = Color(0, 0, 0, 0.2)
	normal.content_margin_left = 20
	normal.content_margin_right = 20
	normal.content_margin_top = 12
	normal.content_margin_bottom = 12
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = bg_color.lightened(0.15)
	hover.set_corner_radius_all(corner_radius)
	hover.shadow_size = 8
	hover.shadow_color = Color(0, 0, 0, 0.3)
	hover.content_margin_left = 20
	hover.content_margin_right = 20
	hover.content_margin_top = 12
	hover.content_margin_bottom = 12
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = bg_color.darkened(0.15)
	pressed.set_corner_radius_all(corner_radius)
	pressed.shadow_size = 3
	pressed.shadow_color = Color(0, 0, 0, 0.15)
	pressed.content_margin_left = 20
	pressed.content_margin_right = 20
	pressed.content_margin_top = 12
	pressed.content_margin_bottom = 12
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_hover_color", font_color)
	btn.add_theme_color_override("font_pressed_color", font_color)
	btn.add_theme_color_override("font_focus_color", font_color)
