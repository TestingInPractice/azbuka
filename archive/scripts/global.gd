extends Node

var current_letter_data: Dictionary = {}
var last_visited_letter: String = ""

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
	GameLogger.info("global", "go_to_letter_detail", {"letter": letter})
	current_letter_data = AlphabetData.get_letter_data(letter)
	GameLogger.info("global", "letter_data", {
		"letter": letter,
		"image_path": current_letter_data.get("image_path", ""),
		"word": current_letter_data.get("word_lower", ""),
	})
	var scene := preload("res://scenes/letter_detail.tscn")
	var detail: Node = scene.instantiate() if scene else null
	GameLogger.info("global", "instantiate_letter_detail", {"ok": detail != null})
	if detail == null:
		GameLogger.error("global", "letter_detail instantiate FAILED — сцена не создалась (вероятно, не загрузился ext_resource)")
		return
	detail.letter = letter
	detail.letter_name = letter_names.get(letter, letter)
	switch_scene(detail)

func go_to_main_menu():
	switch_scene(preload("res://scenes/main_menu.tscn").instantiate())


func go_to_game_find_letter():
	switch_scene(preload("res://scenes/game_find_letter.tscn").instantiate())

func go_to_collect_word():
	switch_scene(preload("res://scenes/game_collect_word.tscn").instantiate())

func go_to_game_guess_picture():
	switch_scene(preload("res://scenes/game_guess_picture.tscn").instantiate())

func go_to_roadmap():
	switch_scene(preload("res://scenes/roadmap_screen.tscn").instantiate())

func go_to_settings():
	switch_scene(preload("res://scenes/settings_screen.tscn").instantiate())

func go_to_start_screen():
	switch_scene(preload("res://scenes/start_screen.tscn").instantiate())

func sparkle_at(pos: Vector2, parent: Node):
	var symbols := ["✦", "★", "●", "♥", "♦"]
	var colors := [
		Color(1, 0.8, 0, 1), Color(1, 0.4, 0.4, 1),
		Color(0.4, 0.8, 1, 1), Color(0.4, 1, 0.6, 1),
		Color(1, 0.6, 0.9, 1),
	]
	for i in 6:
		var label := Label.new()
		label.text = symbols[i % symbols.size()]
		label.modulate = colors[i % colors.size()]
		label.add_theme_font_size_override("font_size", 24 + (i % 3) * 12)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var spread := Vector2(
			randf_range(-80, 80),
			randf_range(-100, -20)
		)
		label.position = pos + spread * 0.3
		parent.add_child(label)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(label, "position", pos + spread, 0.6).set_trans(Tween.TRANS_BACK)
		tw.tween_property(label, "scale", Vector2(2.0, 2.0), 0.3)
		tw.tween_property(label, "modulate:a", 0, 0.6)
		tw.tween_callback(label.queue_free).set_delay(0.7)


func switch_scene(new_scene: Node):
	GameLogger.debug("global", "switch_scene", {"to": new_scene.name if new_scene else "null"})
	var current = get_tree().current_scene
	if current:
		current.visible = false  # Hide before adding new to prevent flickering
	get_tree().root.add_child(new_scene)
	get_tree().current_scene = new_scene
	if current:
		current.queue_free()
