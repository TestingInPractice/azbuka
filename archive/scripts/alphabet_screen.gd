extends Control

const LETTERS := [
	"А", "Б", "В", "Г", "Д", "Е", "Ё", "Ж", "З", "И", "Й",
	"К", "Л", "М", "Н", "О", "П", "Р", "С", "Т", "У", "Ф",
	"Х", "Ц", "Ч", "Ш", "Щ", "Ъ", "Ы", "Ь", "Э", "Ю", "Я",
]

const CARD_COLORS := [
	Color("#FF6B6B"), Color("#4ECDC4"), Color("#45B7D1"), Color("#96CEB4"),
	Color("#FFEAA7"), Color("#DDA0DD"), Color("#98D8C8"), Color("#F7DC6F"),
	Color("#BB8FCE"), Color("#85C1E9"), Color("#F0B27A"), Color("#82E0AA"),
	Color("#F1948A"), Color("#85929E"), Color("#73C6B6"), Color("#E59866"),
	Color("#AED6F1"), Color("#D2B4DE"), Color("#A3E4D7"), Color("#FAD7A0"),
	Color("#ABEBC6"), Color("#F5B7B1"), Color("#A9CCE3"), Color("#D5F5E3"),
	Color("#FCF3CF"), Color("#D6EAF8"), Color("#E8DAEF"), Color("#FDEBD0"),
	Color("#D5F5E3"), Color("#FADBD8"), Color("#D4E6F1"), Color("#F9E79F"),
	Color("#D2B4DE"),
]

@onready var grid_container := $VBoxContainer/ScrollContainer/GridContainer
@onready var scroll_container := $VBoxContainer/ScrollContainer
@onready var title_label := $VBoxContainer/TitleLabel
@onready var settings_button := $SettingsButton
@onready var back_button := $VBoxContainer/BackButton

func _ready():
	var viewport_width = get_viewport().get_visible_rect().size.x
	grid_container.columns = 4 if viewport_width < 600 else 6
	_spawn_floating_decorations()
	populate_grid()
	back_button.pressed.connect(_on_back_pressed)
	apply_theme()
	ThemeManager.theme_changed.connect(_on_theme_changed)
	settings_button.pressed.connect(_on_settings_pressed)
	ThemeManager.style_button(back_button, Color("#E8A87C"), Color("#2D2D2D"))
	ThemeManager.style_button(settings_button, Color("#DDA0DD"))

func _on_theme_changed(_theme_name: String):
	apply_theme()
	_update_card_colors()

func apply_theme():
	var bg = ThemeManager.get_bg()
	var text = ThemeManager.get_text()
	var card_bg = ThemeManager.get_card_bg()

	var style := StyleBoxFlat.new()
	style.bg_color = bg
	add_theme_stylebox_override("panel", style)

	title_label.add_theme_color_override("font_color", text)

	var is_dark = ThemeManager.current_theme == "dark"
	var icon_text = "⚙️"
	if !is_dark:
		settings_button.add_theme_color_override("font_color", Color("#2D2D2D"))
	settings_button.text = icon_text

func _update_card_colors():
	for card in grid_container.get_children():
		var i = card.get_index()
		var color = CARD_COLORS[i % CARD_COLORS.size()]
		var bg_color = color
		if ThemeManager.current_theme == "dark":
			bg_color = color.darkened(0.3)

		var style := StyleBoxFlat.new()
		style.bg_color = bg_color
		style.set_corner_radius_all(12)
		style.shadow_size = 4
		style.shadow_color = Color(0, 0, 0, 0.15)
		card.add_theme_stylebox_override("normal", style)

		var hover_style := StyleBoxFlat.new()
		hover_style.bg_color = bg_color.lightened(0.2)
		hover_style.set_corner_radius_all(12)
		hover_style.shadow_size = 6
		hover_style.shadow_color = Color(0, 0, 0, 0.25)
		card.add_theme_stylebox_override("hover", hover_style)

		card.add_theme_color_override("font_color", ThemeManager.get_text())

func populate_grid():
	var card_scene := preload("res://scenes/letter_card.tscn")
	for i in LETTERS.size():
		var card := card_scene.instantiate()
		card.letter = LETTERS[i]

		var style := StyleBoxFlat.new()
		style.bg_color = CARD_COLORS[i % CARD_COLORS.size()]
		style.set_corner_radius_all(12)
		style.shadow_size = 4
		style.shadow_color = Color(0, 0, 0, 0.15)
		card.add_theme_stylebox_override("normal", style)

		var hover_style := StyleBoxFlat.new()
		hover_style.bg_color = CARD_COLORS[i % CARD_COLORS.size()].lightened(0.25)
		hover_style.set_corner_radius_all(12)
		hover_style.shadow_size = 6
		hover_style.shadow_color = Color(0, 0, 0, 0.25)
		card.add_theme_stylebox_override("hover", hover_style)

		card.letter_clicked.connect(_on_letter_clicked)
		grid_container.add_child(card)
		_animate_card_entrance(card, i)

func _animate_card_entrance(card: Button, index: int):
	card.scale = Vector2.ZERO
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.03 * index)
	tween.tween_property(card, "scale", Vector2.ONE, 0.35)


func _spawn_floating_decorations():
	var symbols := ["★", "✦", "●", "♦", "♥", "✦", "★", "●"]
	for i in 8:
		var label := Label.new()
		label.text = symbols[i % symbols.size()]
		label.modulate = Color(0.6, 0.6, 0.8, 0.12)
		label.add_theme_font_size_override("font_size", 48 + (i % 4) * 16)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.position = Vector2(
			30 + (i % 4) * 120 + (i * 17) % 60,
			-50 - (i * 37) % 80
		)
		add_child(label)
		var tw := create_tween()
		tw.set_loops()
		tw.tween_interval(0.5 * i)
		tw.tween_property(label, "position:y", label.position.y + 600 + (i % 3) * 100, 12.0 + i * 1.5)
		tw.parallel().tween_property(label, "modulate:a", 0.05, 6.0)
		tw.tween_property(label, "modulate:a", 0.12, 6.0)


func _on_back_pressed():
	Global.go_to_main_menu()

func _on_letter_clicked(letter: String):
	Global.go_to_letter_detail(letter)

func _on_settings_pressed():
	Global.go_to_settings()
