extends Control
## Игра «Собери слово»: сборка слова из отдельных букв.
##
## В центре экрана слово показано квадратами-слотами (по одному на букву).
## Ниже расположены перемешанные буквы этого слова: нажатие на букву ставит
## её в ближайший пустой слот слева направо. Правильная буква закрепляется
## в слоте и убирается из пула, неправильная возвращается в пул с подсказкой
## «Попробуй ещё!». Когда слово собрано полностью, последняя буква озвучивается,
## затем слово прочитывается ещё раз. Стрелки «влево» и «вправо» показывают
## случайное другое слово и пересобирают пазл. Все подсказки и сообщения
## находятся в одном месте: в StatusLabel.

## Путь к сцене главного меню.
const MAIN_MENU_SCENE := "res://ui/main_menu/main_menu.tscn"
## Начальная подсказка в статусе.
const STATUS_HINT := "Собери слово из букв"
## Текст при неверной букве.
const STATUS_WRONG := "Попробуй ещё!"

## Ширина рабочей области под ряды слотов и пула.
const WORK_AREA_WIDTH := 900.0
## Отступ между слотами в ряду.
const SLOT_SEPARATION := 20.0
## Минимальный размер слота.
const SLOT_MIN_SIZE := 140.0
## Максимальный размер слота.
const SLOT_MAX_SIZE := 190.0
## Задержка перед озвучиванием слова при показе пазла (секунды).
const WORD_INTRO_DELAY := 0.8
## Задержка перед повтором слова после сборки (секунды).
const WORD_REPLAY_DELAY := 1.5
## Задержка перед переходом к следующему слову (секунды).
const NEXT_WORD_DELAY := 3.5

## Буква текущего слова.
var current_letter: String = ""
## Текущее слово.
var current_word: String = ""
## Буквы текущего слова в правильном порядке слева направо.
var word_letters: Array[String] = []
## Буквы, оставшиеся в пуле (порядок не важен).
var pool_letters: Array[String] = []
## Индекс следующего пустого слота.
var slot_index: int = 0
## Слово полностью собрано.
var is_word_complete: bool = false

var _slot_buttons: Array[Button] = []
var _pool_buttons: Array[Button] = []
var _puzzle_id: int = 0
var _completion_pending: bool = false
var _error_stream: AudioStreamWAV = null

@onready var _background: ColorRect = %Background
@onready var _header_label: Label = %HeaderLabel
@onready var _word_squares: VBoxContainer = %WordSquares
@onready var _pool_container: VBoxContainer = %PoolContainer
@onready var _status_label: Label = %StatusLabel
@onready var _back_button: Button = %CollectWordBackButton
@onready var _prev_word_button: Button = %PrevWordButton
@onready var _next_word_button: Button = %NextWordButton
@onready var _word_image: TextureRect = %WordImage


func _ready() -> void:
	_error_stream = _make_error_stream()
	ThemeManager.theme_changed.connect(_apply_theme)
	_back_button.pressed.connect(_on_back_button_pressed)
	_prev_word_button.pressed.connect(_on_prev_word_button_pressed)
	_next_word_button.pressed.connect(_on_next_word_button_pressed)
	_word_image.gui_input.connect(_on_word_image_input)
	_apply_theme()
	ProgressManager.mark_game_played()
	GameLogger.info("CollectWordGame", "game_entered", {"games_played": ProgressManager.games_played_count})
	_show_random_word()


## Показывает случайное слово из набора, отличное от текущего.
func _show_random_word() -> void:
	var letters: Array[Dictionary] = AlphabetData.get_letters()
	var total := letters.size()
	if total == 0:
		return
	var letter := current_letter
	var guard := 0
	while letter == current_letter and guard < total:
		var candidate: Dictionary = letters[randi_range(0, total - 1)]
		letter = str(candidate["letter"])
		guard += 1
	_build_puzzle(letter)


## Собирает пазл: слоты слова и перемешанный пул букв.
func _build_puzzle(letter: String) -> void:
	_puzzle_id += 1
	_completion_pending = false
	is_word_complete = false
	var data: Dictionary = AlphabetData.get_letter_data(letter)
	if data.is_empty():
		GameLogger.warning("CollectWordGame", "word_not_found", {"letter": letter})
		return
	current_letter = letter
	current_word = str(data["word"])
	_update_word_image()
	word_letters = _split_word(current_word)
	pool_letters = word_letters.duplicate()
	pool_letters.shuffle()
	slot_index = 0
	_clear_puzzle_nodes()
	var count := word_letters.size()
	var slot_size := _compute_slot_size(count)
	var font_size := int(clampf(slot_size * 0.5, 30.0, 72.0))
	var rows := _compute_rows(count)
	var letter_index := 0
	for row_index in rows.size():
		var row_size := rows[row_index]
		var row := HBoxContainer.new()
		row.name = "Row_%d" % row_index
		row.add_theme_constant_override("separation", int(SLOT_SEPARATION))
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		_word_squares.add_child(row)
		for j in row_size:
			var slot := Button.new()
			slot.name = "WordSlot_%d" % (letter_index + 1)
			slot.custom_minimum_size = Vector2(slot_size, slot_size)
			slot.disabled = true
			slot.focus_mode = Control.FOCUS_NONE
			slot.text = ""
			slot.add_theme_font_size_override("font_size", font_size)
			slot.accessibility_name = "Слот слова %d" % (letter_index + 1)
			row.add_child(slot)
			_slot_buttons.append(slot)
			letter_index += 1
	letter_index = 0
	for row_index in rows.size():
		var row_size := rows[row_index]
		var row := HBoxContainer.new()
		row.name = "PoolRow_%d" % row_index
		row.add_theme_constant_override("separation", int(SLOT_SEPARATION))
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		_pool_container.add_child(row)
		for j in row_size:
			var pool := Button.new()
			pool.name = "PoolLetter_%d" % (letter_index + 1)
			pool.custom_minimum_size = Vector2(slot_size, slot_size)
			pool.text = pool_letters[letter_index]
			pool.add_theme_font_size_override("font_size", font_size)
			pool.accessibility_name = "Буква " + pool_letters[letter_index]
			pool.pressed.connect(_on_pool_button_pressed.bind(pool))
			row.add_child(pool)
			_pool_buttons.append(pool)
			letter_index += 1
	_apply_theme()
	_status_label.text = STATUS_HINT
	AudioManager.stop_all()
	var id := _puzzle_id
	get_tree().create_timer(WORD_INTRO_DELAY).timeout.connect(func() -> void:
		if id != _puzzle_id:
			return
		AudioManager.stop_all()
		AudioManager.play_audio(AlphabetData.get_word_audio_path(current_letter))
	)
	GameLogger.info("CollectWordGame", "word_shown", {"letter": current_letter, "word": current_word, "letter_count": count})


## Удаляет слоты и кнопки пула предыдущего пазла.
func _clear_puzzle_nodes() -> void:
	for child in _word_squares.get_children():
		_word_squares.remove_child(child)
		child.queue_free()
	for child in _pool_container.get_children():
		_pool_container.remove_child(child)
		child.queue_free()
	_slot_buttons.clear()
	_pool_buttons.clear()


## Разбивает слово на отдельные буквы.
func _split_word(word: String) -> Array[String]:
	var chars: Array[String] = []
	for i in word.length():
		chars.append(word[i])
	return chars


## Вычисляет размер слота под заданное число букв.
func _compute_slot_size(count: int) -> float:
	if count <= 0:
		return SLOT_MAX_SIZE
	var size := (WORK_AREA_WIDTH - (count - 1) * SLOT_SEPARATION) / count
	return clampf(size, SLOT_MIN_SIZE, SLOT_MAX_SIZE)


## Возвращает сбалансированный список количества букв по рядам.
## Если слово помещается в один ряд — возвращает [count]. Иначе раскладывает
## буквы на несколько рядов, равномерно распределяя остаток (10 -> [5, 5],
## 9 -> [5, 4]) так, чтобы каждый ряд не превышал максимально возможное
## число слотов минимального размера в рабочей области.
func _compute_rows(count: int) -> Array[int]:
	if count <= 0:
		return [0]
	var size := _compute_slot_size(count)
	if count * size + (count - 1) * SLOT_SEPARATION <= WORK_AREA_WIDTH:
		return [count]
	var max_per_row := floori((WORK_AREA_WIDTH + SLOT_SEPARATION) / (SLOT_MIN_SIZE + SLOT_SEPARATION))
	var rows := ceili(float(count) / float(max_per_row))
	var base := count / rows
	var remainder := count % rows
	var result: Array[int] = []
	for i in rows:
		result.append(base + (1 if i < remainder else 0))
	return result


## Обработчик нажатия на букву в пуле.
func _on_pool_button_pressed(button: Button) -> void:
	try_place_letter(button.text, button)


## Пытается поставить букву в текущий слот. Возвращает true, если буква подошла.
func try_place_letter(letter: String, source_button: Button = null) -> bool:
	if is_word_complete or _completion_pending:
		return false
	if slot_index >= word_letters.size():
		return false
	var expected := word_letters[slot_index]
	if letter != expected:
		_play_error_sound()
		_status_label.text = STATUS_WRONG
		_flash_wrong(source_button)
		GameLogger.info("CollectWordGame", "letter_tap_wrong", {"letter": letter, "expected": expected, "word": current_word})
		return false
	var slot: Button = _slot_buttons[slot_index]
	slot.text = letter
	_style_slot_button(slot, ThemeManager.get_card_bg(), ThemeManager.get_text(), true)
	slot_index += 1
	pool_letters.erase(letter)
	if source_button != null and is_instance_valid(source_button):
		var row: Node = source_button.get_parent()
		row.remove_child(source_button)
		_pool_buttons.erase(source_button)
		source_button.queue_free()
		if row.get_child_count() == 0:
			_pool_container.remove_child(row)
			row.queue_free()
	_flash_correct(slot)
	GameLogger.info("CollectWordGame", "letter_tap_correct", {"letter": letter, "slot": slot_index, "word": current_word})
	AudioManager.stop_all()
	AudioManager.play_audio(AlphabetData.get_letter_audio_path(letter))
	if slot_index >= word_letters.size():
		_on_word_completed()
	return true


## Короткая зелёная вспышка слота при правильной букве.
func _flash_correct(slot: Button) -> void:
	slot.self_modulate = Color(0.6, 1.0, 0.7)
	var tween := create_tween()
	tween.tween_property(slot, "self_modulate", Color.WHITE, 0.35)


## Короткая красная вспышка кнопки пула при неверной букве.
func _flash_wrong(button: Button) -> void:
	if button == null:
		return
	button.self_modulate = Color(1.0, 0.55, 0.55)
	var tween := create_tween()
	tween.tween_property(button, "self_modulate", Color.WHITE, 0.5)


## Слово собрано: статус остаётся словом, затем слово повторяется
## и происходит переход к следующему слову.
func _on_word_completed() -> void:
	is_word_complete = true
	_completion_pending = true
	GameLogger.info("CollectWordGame", "word_completed", {"word": current_word, "letter": current_letter})
	var id := _puzzle_id
	get_tree().create_timer(WORD_REPLAY_DELAY).timeout.connect(func() -> void:
		if id != _puzzle_id:
			return
		AudioManager.stop_all()
		AudioManager.play_audio(AlphabetData.get_word_audio_path(current_letter))
		GameLogger.info("CollectWordGame", "word_audio_replayed", {"word": current_word})
	)
	get_tree().create_timer(NEXT_WORD_DELAY).timeout.connect(func() -> void:
		if id != _puzzle_id:
			return
		_show_random_word()
	)


func _on_prev_word_button_pressed() -> void:
	GameLogger.info("CollectWordGame", "prev_word_button_pressed", {})
	show_prev_word()


func _on_next_word_button_pressed() -> void:
	GameLogger.info("CollectWordGame", "next_word_button_pressed", {})
	show_next_word()


## Показывает случайное другое слово при нажатии «влево».
func show_prev_word() -> void:
	_show_random_word()


## Показывает случайное другое слово при нажатии «вправо».
func show_next_word() -> void:
	_show_random_word()


func _on_back_button_pressed() -> void:
	_puzzle_id += 1
	_completion_pending = false
	AudioManager.stop_all()
	GameLogger.info("CollectWordGame", "back_button_pressed", {"word": current_word})
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


## Обновляет картинку слова текущей буквы. Если файл не найден, показывает
## цветной placeholder, цвет которого вычислен из HSV-хэша буквы.
func _update_word_image() -> void:
	var img_path := _image_path_for(current_letter)
	var tex: Texture2D = null
	if not img_path.is_empty():
		tex = load(img_path) as Texture2D
	if tex:
		_word_image.texture = tex
	else:
		_word_image.texture = _make_placeholder_texture(current_letter)
		if not img_path.is_empty():
			GameLogger.warning("CollectWordGame", "word_image_missing", {"letter": current_letter, "path": img_path})


## Возвращает путь к картинке слова для буквы ("" если буквы нет в словаре).
func _image_path_for(ltr: String) -> String:
	var image_name: String = LetterCard.WORD_IMAGE.get(ltr, "")
	if image_name.is_empty():
		return ""
	return "res://assets/images/" + image_name + ".png"


## Создаёт цветную текстуру-заглушку по HSV-хэшу буквы.
func _make_placeholder_texture(ltr: String) -> Texture2D:
	var hue := fmod(float(abs(ltr.hash())) / 1000.0, 1.0)
	var color := Color.from_hsv(hue, 0.5, 0.85)
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


## Нажатие на картинку слова озвучивает текущее слово.
func _on_word_image_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		AudioManager.play_audio(AlphabetData.get_word_audio_path(current_letter))
		GameLogger.info("CollectWordGame", "word_image_pressed", {"letter": current_letter, "word": current_word})


## Создаёт короткий низкий гудок для звука ошибки.
## Готового файла ошибки в assets/audio и в archive/assets/audio нет,
## поэтому звук генерируется программно: синусоида 200 Гц с затуханием.
func _make_error_stream() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	var duration := 0.22
	var sample_count := int(22050.0 * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in sample_count:
		var t := float(i) / 22050.0
		var fade := 1.0 - t / duration
		var sample := sin(2.0 * PI * 200.0 * t) * 0.5 * fade
		var value := int(clampf(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, value)
	stream.data = data
	return stream


## Проигрывает звук ошибки.
func _play_error_sound() -> void:
	if _error_stream == null:
		return
	AudioManager.stop_all()
	AudioManager.play_stream(_error_stream)


## Применяет цвета текущей темы.
func _apply_theme(_mode: int = 0) -> void:
	_background.color = ThemeManager.get_bg()
	var text_color := ThemeManager.get_text()
	var card_bg := ThemeManager.get_card_bg()
	_header_label.add_theme_color_override("font_color", text_color)
	_status_label.add_theme_color_override("font_color", text_color)
	var colors: Dictionary = ThemeManager.COLORS[ThemeManager.current_theme]
	var button_bg := colors["button_bg"] as Color
	var button_text := colors["button_text"] as Color
	ThemeManager.style_button(_back_button, button_bg, button_text)
	ThemeManager.style_button(_prev_word_button, button_bg, button_text)
	ThemeManager.style_button(_next_word_button, button_bg, button_text)
	for i in _slot_buttons.size():
		_style_slot_button(_slot_buttons[i], card_bg, text_color, i < slot_index)
	for pool in _pool_buttons:
		_style_pool_button(pool, button_bg, button_text)


## Оформляет слот слова: заполненный слот непрозрачный, пустой полупрозрачный.
func _style_slot_button(button: Button, card_bg: Color, text_color: Color, filled: bool) -> void:
	var bg := card_bg
	if not filled:
		bg = Color(card_bg.r, card_bg.g, card_bg.b, 0.4)
	button.add_theme_stylebox_override("normal", _square_stylebox(bg))
	button.add_theme_stylebox_override("hover", _square_stylebox(bg))
	button.add_theme_stylebox_override("pressed", _square_stylebox(bg))
	button.add_theme_stylebox_override("disabled", _square_stylebox(bg))
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_disabled_color", text_color)


## Оформляет кнопку буквы в пуле.
func _style_pool_button(button: Button, bg: Color, fg: Color) -> void:
	button.add_theme_stylebox_override("normal", _square_stylebox(bg))
	button.add_theme_stylebox_override("hover", _square_stylebox(bg.lightened(0.08)))
	button.add_theme_stylebox_override("pressed", _square_stylebox(bg.darkened(0.08)))
	button.add_theme_color_override("font_color", fg)
	button.add_theme_color_override("font_hover_color", fg)
	button.add_theme_color_override("font_pressed_color", fg)


## Создаёт скруглённый стиль квадратной кнопки.
func _square_stylebox(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(12)
	return box


## Возвращает букву в слоте по индексу (начиная с 0). Пусто, если слот пуст.
func get_slot_letter(index: int) -> String:
	if index < 0 or index >= _slot_buttons.size():
		return ""
	return _slot_buttons[index].text


## Возвращает текущий текст статуса.
func get_status_text() -> String:
	return _status_label.text
