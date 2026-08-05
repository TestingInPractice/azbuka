extends Node
## Валидатор фикса «Найди букву»: граммофон → картинка слова.
## Проверяет: загрузку картинки по букве, звук при клике, разные карточки.
## Запуск: godot --headless --path . res://tests/validate_find_letter.tscn

var failures := 0


func _ready() -> void:
	await get_tree().process_frame
	var scene: PackedScene = load("res://ui/games/find_letter/find_letter.tscn")
	var game: Node = scene.instantiate()
	add_child(game)
	await get_tree().process_frame

	var word_image: TextureRect = game.get_node("%WordImage")
	if word_image == null:
		_fail("WordImage не найден в сцене")
		_finish()
		return

	# Кнопки-граммофона больше нет.
	if game.get_node_or_null("%GramophoneButton") != null:
		_fail("GramophoneButton всё ещё существует в сцене")

	# Старт серии.
	game._start_series()
	await get_tree().process_frame

	var letter1: String = game.get_current_letter()
	_check_image(word_image, letter1, "карточка 1")

	# Аудио-файл для буквы существует.
	var audio_path := AlphabetData.get_letter_audio_path(letter1)
	if audio_path.is_empty() or not ResourceLoader.exists(audio_path):
		_fail("Аудио-файл для буквы %s не найден: %s" % [letter1, audio_path])
	else:
		_print("audio для %s существует: %s" % [letter1, audio_path])

	# Следующая карточка — буква должна отличаться (перемешивание).
	game._on_next_card_pressed()
	await get_tree().process_frame
	var letter2: String = game.get_current_letter()
	_check_image(word_image, letter2, "карточка 2")
	if letter1 == letter2:
		_fail("Буквы карточек 1 и 2 совпадают: %s" % letter1)
	else:
		_print("карточка 1: %s, карточка 2: %s — разные" % [letter1, letter2])

	# Клик по картинке через gui_input — без ошибок.
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	word_image.gui_input.emit(click)
	await get_tree().process_frame
	_print("gui_input клик по картинке обработан")

	_finish()


func _check_image(word_image: TextureRect, letter: String, label: String) -> void:
	var tex: Texture2D = word_image.texture
	if tex == null:
		_fail("%s (%s): текстура не установлена" % [label, letter])
		return
	var is_placeholder := tex.get_width() == 64 and tex.get_height() == 64
	var image_name: String = LetterCard.WORD_IMAGE.get(letter, "")
	_print("%s (%s): текстура %dx%d, файл=%s.png, placeholder=%s" % [
		label, letter, tex.get_width(), tex.get_height(), image_name, is_placeholder])
	if image_name.is_empty():
		_fail("%s (%s): буквы нет в LetterCard.WORD_IMAGE" % [label, letter])
	elif is_placeholder:
		_fail("%s (%s): показан placeholder вместо картинки %s.png" % [label, letter, image_name])


func _fail(msg: String) -> void:
	failures += 1
	printerr("FAIL: " + msg)


func _print(msg: String) -> void:
	print("[find_letter_validate] " + msg)


func _finish() -> void:
	if failures > 0:
		printerr("FAILED: %d проверок" % failures)
		get_tree().quit(1)
	else:
		print("[find_letter_validate] PASSED: все проверки успешны")
		get_tree().quit(0)

