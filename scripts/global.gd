extends Node

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

func go_to_letter_detail(letter: String):
	ProgressManager.mark_letter_completed(letter)
	current_letter_data = AlphabetData.get(letter)
	var detail = preload("res://scenes/letter_detail.tscn").instantiate()
	detail.letter = letter
	detail.letter_name = letter_names.get(letter, letter)
	switch_scene(detail)

func go_to_alphabet_screen():
	switch_scene(preload("res://scenes/alphabet_screen.tscn").instantiate())

func go_to_game_find_letter():
	switch_scene(preload("res://scenes/game_find_letter.tscn").instantiate())

func go_to_collect_word():
	switch_scene(preload("res://scenes/game_collect_word.tscn").instantiate())

func go_to_game_guess_picture():
	switch_scene(preload("res://scenes/game_guess_picture.tscn").instantiate())

func go_to_settings():
	switch_scene(preload("res://scenes/settings_screen.tscn").instantiate())

func switch_scene(new_scene: Node):
	var current = get_tree().current_scene
	get_tree().root.add_child(new_scene)
	get_tree().current_scene = new_scene
	if current:
		current.queue_free()
