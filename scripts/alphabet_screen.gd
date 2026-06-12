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
@onready var game_collect_button := $VBoxContainer/GameButton

func _ready():
	var viewport_width = get_viewport().get_visible_rect().size.x
	grid_container.columns = 4 if viewport_width < 600 else 6
	populate_grid()
	_add_game_button()
	game_collect_button.pressed.connect(_on_collect_word_pressed)
	apply_theme()
	ThemeManager.theme_changed.connect(_on_theme_changed)
	settings_button.pressed.connect(_on_settings_pressed)

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
	settings_button.icon = null
	var icon_text = "⚙️"
	if is_dark:
		settings_button.add_theme_color_override("font_color", text)
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

func _add_game_button():
	var btn = Button.new()
	btn.text = "🎮 Угадай по картинке"
	btn.theme_override_font_sizes/font_size = 24
	btn.size_flags_horizontal = 2
	btn.custom_minimum_size = Vector2(300, 50)
	btn.pressed.connect(_on_game_pressed)
	$VBoxContainer.add_child(btn)
	$VBoxContainer.move_child(btn, 1)

func _on_game_pressed():
	Global.go_to_game_guess_picture()

func _on_collect_word_pressed():
	Global.go_to_collect_word()

func _on_letter_clicked(letter: String):
	Global.go_to_letter_detail(letter)

func _on_settings_pressed():
	Global.go_to_settings()
