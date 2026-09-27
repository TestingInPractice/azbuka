extends Node
## Валидатор транслитерации букв в ASCII для имён файлов в user://.
## Запуск: godot --headless --path . res://tests/validate_letter_translit.tscn

var failures := 0


func _ready() -> void:
	await get_tree().process_frame

	_check(LetterTranslit.to_ascii("А") == "a", "А -> a")
	_check(LetterTranslit.to_ascii("а") == "a", "а -> a (регистр не важен)")
	_check(LetterTranslit.to_ascii("Ъ") == "q", "Ъ -> q")
	_check(LetterTranslit.to_ascii("Ы") == "y", "Ы -> y")
	_check(LetterTranslit.to_ascii("Ь") == "soft", "Ь -> soft")
	_check(LetterTranslit.to_ascii("Е") == "e", "Е -> e")
	_check(LetterTranslit.to_ascii("Э") == "eh", "Э -> eh (не e, как у Е)")
	_check(LetterTranslit.to_ascii("Й") == "j", "Й -> j (не y, как у Ы)")
	_check(LetterTranslit.to_ascii("Я") == "ya", "Я -> ya")
	_check(LetterTranslit.to_ascii("Ю") == "yu", "Ю -> yu")
	_check(LetterTranslit.to_ascii("Ё") == "yo", "Ё -> yo")
	_check(LetterTranslit.to_ascii("Ж") == "zh", "Ж -> zh")
	# Небуквенный вход не должен ломать имя файла.
	_check(LetterTranslit.to_ascii("1") == "_", "небуквенный символ -> _")
	_check(LetterTranslit.to_ascii("") == "_", "пустая строка -> _")
	_check(LetterTranslit.to_ascii("АБ") == "_", "две буквы -> _")
	# Результат всегда безопасен как имя файла.
	_check(LetterTranslit.to_ascii("Ж").is_valid_filename(), "Ж -> валидное имя файла")

	# Все 33 буквы обязаны давать РАЗНЫЕ имена. Набор может быть заполнен
	# целиком, и две буквы с одинаковым ASCII-именем записали бы файл
	# друг на друга: img_e.webp от Е и от Э — вторая молча перетирает первую.
	# Раньше здесь были Е/Э -> "e" и Й/Ы -> "y", и тест этого не ловил,
	# потому что проверял буквы по одной.
	var seen := {}
	for letter: String in "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ":
		var ascii := LetterTranslit.to_ascii(letter)
		if seen.has(ascii):
			_fail("коллизия имён: %s и %s дают одинаковое %s"
					% [str(seen[ascii]), letter, ascii])
		seen[ascii] = letter
	_check(seen.size() == 33, "уникальных имён ровно 33 (получено: %d)" % seen.size())

	_finish()


func _check(ok: bool, msg: String) -> void:
	if ok:
		_print("OK: " + msg)
	else:
		_fail(msg)


func _fail(msg: String) -> void:
	failures += 1
	printerr("FAIL: " + msg)


func _print(msg: String) -> void:
	print("[letter_translit_validate] " + msg)


func _finish() -> void:
	if failures > 0:
		printerr("FAILED: %d проверок" % failures)
		get_tree().quit(1)
	else:
		print("[letter_translit_validate] PASSED: все проверки успешны")
		get_tree().quit(0)
