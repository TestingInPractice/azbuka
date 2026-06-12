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
