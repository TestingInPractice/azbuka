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

func _ready():
	var viewport_width = get_viewport().get_visible_rect().size.x
	grid_container.columns = 4 if viewport_width < 600 else 6
	populate_grid()

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

func _on_letter_clicked(letter: String):
	Global.go_to_letter_detail(letter)
