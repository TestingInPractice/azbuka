extends Control
## Игра «Угадай букву»: подбор слова к показанной букве.
##
## Игра состоит из 10 раундов. В каждом раунде по центру показывается буква,
## звучит её название, а ниже четыре большие кнопки со словами: три случайных
## слова и одно правильное (слово текущей буквы из активного набора через
## SetRepository). За
## правильный ответ начисляется очко, звучит «Молодец!», кнопка подсвечивается
## зелёным. За неправильный ответ кнопка блокируется и подсвечивается красным,
## показывается подсказка «Попробуй ещё!». После 10 раундов показывается финал
## со счётом и кнопками «Играть ещё» и «Назад».

## Число раундов в одной игре.
const TOTAL_ROUNDS := 10
## Путь к фразе «Молодец!».
const PROMPT_CORRECT_PATH := "res://assets/audio/prompt_correct.wav"
## Цвет подсветки правильного ответа.
const CORRECT_COLOR := Color("#43A047")
## Цвет подсветки неправильного ответа.
const WRONG_COLOR := Color("#E53935")
## Текст подсказки при правильном ответе.
const HINT_CORRECT := "Молодец!"
## Текст подсказки при неправильном ответе.
const HINT_WRONG := "Попробуй ещё!"
## Текст подсказки, когда активный набор ещё не заполнен ни одной буквой.
const HINT_EMPTY_SET := "В этом наборе пока нет букв. Заполни его в настройках."
## Частота программного звука ошибки в герцах.
const ERROR_BEEP_FREQUENCY := 300.0
## Длительность программного звука ошибки в секундах.
const ERROR_BEEP_DURATION := 0.18
## Число дистракторов в раунде.
const DISTRACTOR_COUNT := 3
## Задержка перед автоподсказкой при простое (секунды).
const IDLE_HINT_DELAY := 6.0

@onready var _background: ColorRect = %Background
@onready var _round_label: Label = %RoundLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _letter_panel: PanelContainer = %LetterPanel
@onready var _letter_label: Label = %LetterLabel
@onready var _status_label: Label = %StatusLabel
@onready var _main_layout: VBoxContainer = %MainLayout
@onready var _answer_button_1: Button = %AnswerButton_1
@onready var _answer_button_2: Button = %AnswerButton_2
@onready var _answer_button_3: Button = %AnswerButton_3
@onready var _answer_button_4: Button = %AnswerButton_4
@onready var _finale_panel: VBoxContainer = %FinalePanel
@onready var _finale_label: Label = %FinaleLabel
@onready var _finale_score_label: Label = %FinaleScoreLabel
@onready var _play_again_button: Button = %PlayAgainButton
@onready var _back_button: Button = %BackButton
@onready var _home_button: Button = %HomeButton

## Кнопки ответов в порядке AnswerButton_1..4.
var _answer_buttons: Array[Button] = []
## Текущий счёт игры.
var _score := 0
## Число завершённых раундов (0..TOTAL_ROUNDS).
var _rounds_played := 0
## Буква текущего раунда.
var _current_letter := ""
## Индекс кнопки с правильным словом в текущем раунде.
var _correct_button_index := -1
## Можно ли отвечать в текущем раунде.
var _round_active := false
var _navigating := false
## Программный звук ошибки. Файла звука ошибки в assets/audio нет, поэтому
## генерируем короткий тон 300 Гц (как задумано в SPEC-REWRITE, error_beep).
var _error_beep: AudioStreamWAV
var _idle_timer: Timer = null


func _ready() -> void:
	ThemeManager.theme_changed.connect(_apply_theme)
	_back_button.pressed.connect(_on_back_button_pressed)
	_home_button.pressed.connect(_on_home_button_pressed)
	_play_again_button.pressed.connect(_on_play_again_button_pressed)
	_answer_buttons = [_answer_button_1, _answer_button_2, _answer_button_3, _answer_button_4]
	for button: Button in _answer_buttons:
		button.pressed.connect(_on_answer_button_pressed.bind(button))
	_error_beep = _make_error_beep()
	_setup_idle_timer()
	ProgressManager.mark_game_played()
	GameLogger.info("GuessPictureGame", "game_entered", {"games_played": ProgressManager.games_played_count})
	_apply_theme()
	_start_new_game()


## Начинает новую игру: счёт и раунды сбрасываются, финал скрывается.
func _start_new_game() -> void:
	_score = 0
	_rounds_played = 0
	_finale_panel.visible = false
	_main_layout.visible = true
	GameLogger.info("GuessPictureGame", "game_start", {"total_rounds": TOTAL_ROUNDS})
	_start_round()


## Начинает очередной раунд: выбирает букву, собирает четыре разных слова
## (правильное и три дистрактора) и раскладывает их по кнопкам в случайном
## порядке.
func _start_round() -> void:
	_round_active = true
	_correct_button_index = -1
	_current_letter = _pick_random_letter()
	# Набор создан, но родитель ещё ничего не заполнил: букв в нём нет, и
	# раунд из одной кнопки без текста ребёнку бессмыслен. Это не подмена
	# данных набора, а отказ играть в незаполненный набор, поэтому пишем в
	# лог и не начинаем раунд вовсе.
	if _current_letter.is_empty():
		_round_active = false
		_status_label.text = HINT_EMPTY_SET
		_round_label.text = "Раунд %d / %d" % [_rounds_played + 1, TOTAL_ROUNDS]
		_score_label.text = "Счёт: %d" % _score
		_letter_label.text = ""
		_apply_theme()
		for button: Button in _answer_buttons:
			button.disabled = true
			button.text = ""
		GameLogger.warning("GuessPictureGame", "active_set_empty", {
			"set_id": SetRepository.get_active_set_id(),
		})
		_reset_idle_timer()
		return
	var correct_word := _get_word(_current_letter)
	var distractor_letters := _pick_distractor_letters(_current_letter)
	var words: Array[String] = [correct_word]
	for letter: String in distractor_letters:
		# Именно _distractor_word, а не _get_word: слово, по которому буква
		# отобрана как неповторяющаяся, и слово на кнопке должны быть одним и
		# тем же. Иначе две кнопки в раунде окажутся с одинаковым текстом.
		words.append(_distractor_word(letter))
	words.shuffle()
	for index in range(words.size()):
		var button := _answer_buttons[index]
		button.text = words[index]
		button.disabled = false
		button.accessibility_name = "Ответ: " + words[index]
		if words[index] == correct_word:
			_correct_button_index = index
	_round_label.text = "Раунд %d / %d" % [_rounds_played + 1, TOTAL_ROUNDS]
	_score_label.text = "Счёт: %d" % _score
	_letter_label.text = _current_letter
	_status_label.text = ""
	_apply_theme()
	# Звук буквы звучит в начале раунда, пока буква перед глазами.
	AudioManager.play_stream(SetRepository.get_letter_audio(_current_letter))
	GameLogger.info("GuessPictureGame", "round_start", {
		"round": _rounds_played + 1,
		"letter": _current_letter,
		"correct_word": correct_word,
		"answers": words,
	})
	_reset_idle_timer()


## Возвращает случайную букву из активного набора. Свой набор из двух букв
## обязан крутить эти две, а не весь алфавит.
func _pick_random_letter() -> String:
	var letters := SetRepository.get_active_letters()
	if letters.is_empty():
		return ""
	return letters[randi_range(0, letters.size() - 1)]


## Буквы-дистракторы. Основной источник — буквы активного набора: их слова
## обязаны прийти из своего набора, это и смысл игры. Но три дистрактора
## набрать из них можно не всегда: в своём наборе родитель заполнил, скажем,
## две буквы, а кнопок на экране четыре. Нехватку добираем из полного
## алфавита — это шум, а не данные буквы: слово такой буквы в своём наборе
## отсутствует, и SetRepository для неё ничего не вернёт (откат на встроенный
## набор там намеренно запрещён). Поэтому слово дистрактора берётся отдельной
## функцией _distractor_word(), которая честно говорит, откуда оно.
func _pick_distractor_letters(excluded: String) -> Array[String]:
	var correct_word := _get_word(excluded)
	var pool: Array[String] = []
	for letter: String in SetRepository.get_active_letters():
		if letter == excluded or _distractor_word(letter) == correct_word:
			continue
		pool.append(letter)
	if pool.size() < DISTRACTOR_COUNT:
		for entry: Dictionary in AlphabetData.get_letters():
			var letter := str(entry.get("letter", ""))
			if letter == excluded or pool.has(letter) or _distractor_word(letter) == correct_word:
				continue
			pool.append(letter)
	pool.shuffle()
	var result: Array[String] = []
	for index in range(mini(DISTRACTOR_COUNT, pool.size())):
		result.append(pool[index])
	return result


## Слово буквы из активного набора. Отдельного отката на
## AlphabetData.get_letter_data() больше нет намеренно: у своего набора
## заполнены не все буквы, и тихий откат на встроенный набор показал бы
## ребёнку слово из чужого набора вместо его собственного.
func _get_word(letter: String) -> String:
	return str(SetRepository.get_word_data(letter).get("word", ""))


## Слово для буквы-дистрактора. Если буква есть в активном наборе — слово
## оттуда же. Если нет (она набрана из полного алфавита, чтобы добрать
## варианты) — из встроенного набора 1, и это осознанный шум, а не содержимое
## набора. Ключ set1 обоснован контрактом: по validate_word_sets
## get_letter_data() — это ровно данные набора 1.
func _distractor_word(letter: String) -> String:
	if SetRepository.has_letter(letter):
		return _get_word(letter)
	return str(AlphabetData.get_letter_data(letter).get("word", ""))


func _on_answer_button_pressed(button: Button) -> void:
	if not _round_active or _navigating:
		return
	_reset_idle_timer()
	var index := _answer_buttons.find(button)
	if index < 0:
		return
	if index == _correct_button_index:
		_handle_correct_answer(button, button.text)
	else:
		_handle_wrong_answer(button, button.text)


## Обрабатывает правильный ответ: зелёная подсветка, «Молодец!», увеличение
## счёта и переход к следующему раунду (или к финалу).
func _handle_correct_answer(button: Button, word: String) -> void:
	_round_active = false
	_score += 1
	_score_label.text = "Счёт: %d" % _score
	for b: Button in _answer_buttons:
		b.disabled = true
	_style_button_flat(button, CORRECT_COLOR)
	_status_label.text = HINT_CORRECT
	GameLogger.info("GuessPictureGame", "answer", {
		"correct": true,
		"letter": _current_letter,
		"word": word,
		"score": _score,
	})
	AudioManager.play_audio(PROMPT_CORRECT_PATH)
	await get_tree().create_timer(0.7).timeout
	if not is_inside_tree():
		return
	_rounds_played += 1
	if _rounds_played >= TOTAL_ROUNDS:
		_show_finale()
	else:
		_start_round()


## Обрабатывает неправильный ответ: красная подсветка, блокировка кнопки,
## подсказка «Попробуй ещё!» и звук ошибки.
func _handle_wrong_answer(button: Button, word: String) -> void:
	button.disabled = true
	_style_button_flat(button, WRONG_COLOR)
	_status_label.text = HINT_WRONG
	GameLogger.info("GuessPictureGame", "answer", {
		"correct": false,
		"letter": _current_letter,
		"word": word,
		"score": _score,
	})
	AudioManager.play_stream(_error_beep)


## Показывает финальный экран с итоговым счётом.
func _show_finale() -> void:
	_main_layout.visible = false
	_finale_panel.visible = true
	_finale_label.text = "Игра окончена!"
	_finale_score_label.text = "Ваш счёт: %d / %d" % [_score, TOTAL_ROUNDS]
	GameLogger.info("GuessPictureGame", "game_over", {"score": _score, "total": TOTAL_ROUNDS})


func _on_play_again_button_pressed() -> void:
	if _navigating:
		return
	GameLogger.info("GuessPictureGame", "play_again_pressed", {"score": _score})
	_start_new_game()


func _on_back_button_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	_stop_idle_timer()
	GameLogger.info("GuessPictureGame", "back_button_pressed", {})
	AudioManager.stop_all()
	get_tree().change_scene_to_file("res://ui/main_menu/main_menu.tscn")


func _on_home_button_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	_stop_idle_timer()
	GameLogger.info("GuessPictureGame", "home_button_pressed", {})
	AudioManager.stop_all()
	get_tree().change_scene_to_file("res://ui/main_menu/main_menu.tscn")


## Применяет цвета текущей темы ко всем элементам экрана.
func _apply_theme(_mode: int = 0) -> void:
	_background.color = ThemeManager.get_bg()
	var text_color := ThemeManager.get_text()
	_round_label.add_theme_color_override("font_color", text_color)
	_score_label.add_theme_color_override("font_color", text_color)
	_letter_label.add_theme_color_override("font_color", text_color)
	_status_label.add_theme_color_override("font_color", text_color)
	_finale_label.add_theme_color_override("font_color", text_color)
	_finale_score_label.add_theme_color_override("font_color", text_color)
	_letter_panel.add_theme_stylebox_override("panel", _make_card_stylebox(ThemeManager.get_card_bg()))
	var colors: Dictionary = ThemeManager.COLORS[ThemeManager.current_theme]
	var button_bg := colors["button_bg"] as Color
	var button_text := colors["button_text"] as Color
	ThemeManager.style_button(_back_button, button_bg, button_text)
	ThemeManager.style_button(_home_button, button_bg, button_text)
	ThemeManager.style_button(_play_again_button, button_bg, button_text)
	for button: Button in _answer_buttons:
		if button.disabled:
			_style_button_flat(button, WRONG_COLOR)
		else:
			ThemeManager.style_button(button, button_bg, button_text)
			# Сброс устаревших flat-оверрайдов (disabled-стиль и белый шрифт),
			# оставшихся от прошлых раундов: иначе при блокировке кнопки
			# всплывал зелёный/красный цвет чужого ответа.
			button.remove_theme_stylebox_override("disabled")
			button.remove_theme_color_override("font_disabled_color")
	if _correct_button_index >= 0 and not _round_active:
		_style_button_flat(_answer_buttons[_correct_button_index], CORRECT_COLOR)


## Создаёт скруглённый стиль карточки буквы.
func _make_card_stylebox(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(36)
	box.content_margin_left = 48
	box.content_margin_right = 48
	box.content_margin_top = 40
	box.content_margin_bottom = 40
	return box


## Раскрашивает кнопку целиком одним цветом с белым текстом (normal, hover,
## pressed и disabled).
func _style_button_flat(button: Button, color: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(24)
	box.content_margin_left = 32
	box.content_margin_right = 32
	box.content_margin_top = 24
	box.content_margin_bottom = 24
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", box)
	button.add_theme_stylebox_override("disabled", box)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color.WHITE)


func _setup_idle_timer() -> void:
	_idle_timer = Timer.new()
	_idle_timer.name = "IdleTimer"
	_idle_timer.wait_time = IDLE_HINT_DELAY
	_idle_timer.one_shot = true
	_idle_timer.autostart = false
	_idle_timer.timeout.connect(_on_idle_timeout)
	add_child(_idle_timer)
	_idle_timer.owner = self
	_idle_timer.unique_name_in_owner = true


func _reset_idle_timer() -> void:
	if _navigating or not AudioManager.sound_enabled or not _round_active:
		return
	_idle_timer.stop()
	_idle_timer.start()


func _stop_idle_timer() -> void:
	_idle_timer.stop()


func _on_idle_timeout() -> void:
	if _navigating or not AudioManager.sound_enabled or not _round_active:
		return
	AudioManager.play_stream(SetRepository.get_letter_audio(_current_letter))
	GameLogger.info("GuessPictureGame", "idle_hint", {"letter": _current_letter})
	_reset_idle_timer()


## Создаёт программный звук ошибки: короткий тон 300 Гц с затуханием.
## Отдельного файла звука ошибки в assets/audio и archive/assets/audio нет
## (проверено поиском), поэтому используем синтезированный тон.
func _make_error_beep() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	var sample_rate := 22050
	var sample_count := int(sample_rate * ERROR_BEEP_DURATION)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for index in range(sample_count):
		var time := float(index) / sample_rate
		var envelope := 1.0 - float(index) / sample_count
		var sample := sin(TAU * ERROR_BEEP_FREQUENCY * time) * 0.4 * envelope
		var value := int(clampf(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(index * 2, value)
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream
