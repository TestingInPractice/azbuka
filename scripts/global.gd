extends Node

var is_dark_mode := false
var visited_letters: Array[String] = []
var current_letter_data: Dictionary = {}

var letter_names := {
	"А": "А",
	"Б": "Бэ",
	"В": "Вэ",
	"Г": "Гэ",
	"Д": "Дэ",
	"Е": "Е",
	"Ё": "Ё",
	"Ж": "Жэ",
	"З": "Зэ",
	"И": "И",
	"Й": "И краткое",
	"К": "Ка",
	"Л": "Эль",
	"М": "Эм",
	"Н": "Эн",
	"О": "О",
	"П": "Пэ",
	"Р": "Эр",
	"С": "Эс",
	"Т": "Тэ",
	"У": "У",
	"Ф": "Эф",
	"Х": "Ха",
	"Ц": "Цэ",
	"Ч": "Чэ",
	"Ш": "Ша",
	"Щ": "Ща",
	"Ъ": "Твёрдый знак",
	"Ы": "Ы",
	"Ь": "Мягкий знак",
	"Э": "Э",
	"Ю": "Ю",
	"Я": "Я",
}

func _ready():
	apply_light_theme()

func go_to_letter_detail(letter: String):
	if not letter in visited_letters:
		visited_letters.append(letter)
	current_letter_data = AlphabetData.get(letter)
	var detail = preload("res://scenes/letter_detail.tscn").instantiate()
	detail.letter = letter
	detail.letter_name = letter_names.get(letter, letter)
	switch_scene(detail)

func go_to_alphabet_screen():
	switch_scene(preload("res://scenes/alphabet_screen.tscn").instantiate())

func switch_scene(new_scene: Node):
	var current = get_tree().current_scene
	get_tree().root.add_child(new_scene)
	get_tree().current_scene = new_scene
	if current:
		current.queue_free()

func apply_light_theme():
	is_dark_mode = false
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color("#F0F0F5")
	get_tree().root.add_theme_stylebox_override("panel", bg)

func apply_dark_theme():
	is_dark_mode = true
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color("#1A1A2E")
	get_tree().root.add_theme_stylebox_override("panel", bg)

func toggle_theme():
	if is_dark_mode:
		apply_light_theme()
	else:
		apply_dark_theme()
