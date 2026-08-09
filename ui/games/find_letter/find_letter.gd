extends Control
## Игра «Найди букву»: соотнесение звука буквы с её начертанием.
##
## Экран «Готовы играть?» запускает серию из N карточек (N настраивается в
## настройках, 5-30). На карточке картинка слова: нажатие на неё озвучивает
## правильную букву, а под ней четыре квадрата: одна правильная буква и три
## случайные. Правильный выбор подсвечивает квадрат зелёным, звучит
## «Молодец!», игра переходит к следующей карточке. Ошибочный выбор
## блокирует квадрат, звучит короткий сигнал и подсказка «Попробуй ещё!».
## После N карточек - экран завершения серии с кнопками «Да» и «Нет».

const ANSWER_COUNT := 4
## Пауза после правильного ответа перед переходом к следующей карточке.
const FEEDBACK_DELAY := 1.2
## Частота звука ошибки в герцах.
const ERROR_BEEP_FREQ := 300.0
## Длительность звука ошибки в секундах.
const ERROR_BEEP_DURATION := 0.15
## Частота дискретизации звука ошибки.
const ERROR_BEEP_SAMPLE_RATE := 22050

const STATE_READY := 0
const STATE_PLAYING := 1
const STATE_COMPLETED := 2

## Цвет подсветки правильного квадрата.
const COLOR_CORRECT := Color(0.2, 0.7, 0.2)
## Цвет подсветки ошибочного квадрата.
const COLOR_WRONG := Color(0.7, 0.2, 0.2)

## Путь к сцене главного меню.
const MAIN_MENU_SCENE := "res://ui/main_menu/main_menu.tscn"
## Путь к звуку «Молодец!».
const PROMPT_CORRECT_PATH := "res://assets/audio/prompt_correct.wav"

@onready var _background: ColorRect = %Background
@onready var _title_label: Label = %TitleLabel
@onready var _hint_label: Label = %HintLabel
@onready var _back_button: Button = %FindLetterBackButton
@onready var _ready_panel: VBoxContainer = %ReadyPanel
@onready var _ready_start_button: Button = %ReadyStartButton
@onready var _card_panel: VBoxContainer = %CardPanel
@onready var _card_number_label: Label = %CardNumberLabel
@onready var _word_image: TextureRect = %WordImage
@onready var _completion_panel: VBoxContainer = %CompletionPanel
@onready var _completion_yes_button: Button = %CompletionYesButton
@onready var _completion_no_button: Button = %CompletionNoButton
@onready var _prev_card_button: Button = %PrevCardButton
@onready var _next_card_button: Button = %NextCardButton

var _square_buttons: Array[Button] = []

var _state: int = STATE_READY
## Серия карточек текущей игры (записи из AlphabetData).
var _series: Array[Dictionary] = []
## Отмечены ли карточки решёнными.
var _solved: Array[bool] = []
var _card_index: int = 0
## Буквы на четырёх квадратах текущей карточки.
var _answers: Array[String] = []
## Правильная буква текущей карточки.
var _correct_letter: String = ""
## Блокировка ввода во время паузы после правильного ответа.
var _input_blocked: bool = false

var _error_beep: AudioStreamWAV


func _ready() -> void:
	_square_buttons = [
		%SquareLetter_1 as Button,
		%SquareLetter_2 as Button,
		%SquareLetter_3 as Button,
		%SquareLetter_4 as Button,
	]
	ThemeManager.theme_changed.connect(_apply_theme)
	_back_button.pressed.connect(_on_back_button_pressed)
	_ready_start_button.pressed.connect(_on_ready_start_pressed)
	_word_image.gui_input.connect(_on_word_image_input)
	for index in _square_buttons.size():
		_square_buttons[index].pressed.connect(_on_square_pressed.bind(index))
	_prev_card_button.pressed.connect(_on_prev_card_pressed)
	_next_card_button.pressed.connect(_on_next_card_pressed)
	_completion_yes_button.pressed.connect(_on_completion_yes_pressed)
	_completion_no_button.pressed.connect(_on_completion_no_pressed)
	_error_beep = _build_error_beep()
	_show_ready()
	_apply_theme()


## Возвращает состояние игры: "ready", "playing" или "completed".
func get_game_state() -> String:
	match _state:
		STATE_READY:
			return "ready"
		STATE_COMPLETED:
			return "completed"
		_:
			return "playing"


## Возвращает правильную букву текущей карточки ("" вне игры).
func get_current_letter() -> String:
	return _correct_letter


## Возвращает длину серии карточек текущей игры.
func get_series_length() -> int:
	return _series.size()


## Возвращает индекс текущей карточки (0-based).
func get_current_card_index() -> int:
	return _card_index


## Показывает экран «Готовы играть?».
func _show_ready() -> void:
	_state = STATE_READY
	_correct_letter = ""
	_hint_label.visible = false
	_ready_panel.visible = true
	_card_panel.visible = false
	_completion_panel.visible = false
	_prev_card_button.get_parent().visible = false
	_back_button.disabled = false


## Начинает новую серию карточек.
func _start_series() -> void:
	var count := ProgressManager.get_series_length()
	var letters := AlphabetData.get_letters()
	letters.shuffle()
	_series = letters.slice(0, min(count, letters.size()))
	_solved.clear()
	_solved.resize(_series.size())
	for index in _solved.size():
		_solved[index] = false
	_card_index = 0
	ProgressManager.mark_game_played()
	GameLogger.info("FindLetterGame", "series_started", {"length": _series.size()})
	_show_card(_card_index)


## Показывает карточку с указанным индексом.
func _show_card(index: int) -> void:
	_state = STATE_PLAYING
	_card_index = clampi(index, 0, _series.size() - 1)
	_input_blocked = false
	_correct_letter = str(_series[_card_index]["letter"])
	_card_number_label.text = "Карточка %d из %d" % [_card_index + 1, _series.size()]
	_build_answers()
	_update_squares()
	_update_word_image()
	_hint_label.visible = true
	_hint_label.text = "Нажми на картинку и выбери букву"
	_ready_panel.visible = false
	_card_panel.visible = true
	_completion_panel.visible = false
	_prev_card_button.get_parent().visible = true
	GameLogger.info("FindLetterGame", "card_shown", {
		"index": _card_index + 1,
		"total": _series.size(),
		"letter": _correct_letter,
	})


## Собирает варианты ответов: правильная буква и три случайные.
func _build_answers() -> void:
	_answers = [_correct_letter]
	var distractors: Array[String] = []
	for letter_data: Dictionary in AlphabetData.get_letters():
		var letter := str(letter_data["letter"])
		if letter != _correct_letter:
			distractors.append(letter)
	distractors.shuffle()
	_answers.append_array(distractors.slice(0, ANSWER_COUNT - 1))
	_answers.shuffle()


## Обновляет квадраты: текст букв, доступность и подсветку.
func _update_squares() -> void:
	var solved := _solved[_card_index]
	var button_bg := _get_button_bg()
	var button_text := _get_button_text()
	for index in _square_buttons.size():
		var button := _square_buttons[index]
		button.text = _answers[index]
		button.disabled = solved
		button.rotation_degrees = 0.0
		button.scale = Vector2.ONE
		button.modulate = Color.WHITE
		button.accessibility_name = "Буква " + _answers[index]
		if solved:
			var is_correct := _answers[index] == _correct_letter
			_set_square_color(button, COLOR_CORRECT if is_correct else button_bg)
		else:
			ThemeManager.style_button(button, button_bg, button_text)


## Перекрашивает квадрат в указанный цвет фона.
func _set_square_color(button: Button, bg_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(24)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)


## Анимация правильного ответа: зелёная подсветка + подпрыгивание (как в азбуке).
func _play_square_correct_anim(button: Button) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BOUNCE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.3, 1.3), 0.15)
	tween.tween_property(button, "scale", Vector2.ONE, 0.25)
	tween.tween_property(button, "scale", Vector2(1.1, 1.1), 0.2)
	tween.tween_property(button, "scale", Vector2.ONE, 0.2)
	tween.tween_property(button, "scale", Vector2(1.08, 1.08), 0.15)
	tween.tween_property(button, "scale", Vector2.ONE, 0.15)


## Анимация ошибочного ответа: красная подсветка + тряска, затем возврат
## (как в азбуке). Квадрат снова доступен для выбора.
func _play_square_wrong_anim(button: Button) -> void:
	button.modulate = Color.RED
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	var orig: float = button.rotation_degrees
	for _k in 3:
		tween.tween_property(button, "rotation_degrees", orig - 8.0, 0.04)
		tween.tween_property(button, "rotation_degrees", orig + 8.0, 0.04)
	tween.tween_property(button, "rotation_degrees", orig, 0.04)
	var reset := create_tween()
	reset.tween_interval(0.3)
	reset.tween_property(button, "modulate", Color.WHITE, 0.2)


## Обновляет картинку слова текущей карточки. Если файл не найден, показывает
## цветной placeholder, цвет которого вычислен из HSV-хэша буквы.
func _update_word_image() -> void:
	var img_path := _image_path_for(_correct_letter)
	var tex: Texture2D = null
	if not img_path.is_empty():
		tex = load(img_path) as Texture2D
	if tex:
		_word_image.texture = tex
	else:
		_word_image.texture = _make_placeholder_texture(_correct_letter)
		if not img_path.is_empty():
			GameLogger.warning("FindLetterGame", "word_image_missing", {"letter": _correct_letter, "path": img_path})


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


func _on_ready_start_pressed() -> void:
	GameLogger.info("FindLetterGame", "ready_start_pressed", {})
	_start_series()


func _on_word_image_input(event: InputEvent) -> void:
	if _state != STATE_PLAYING:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var audio_path := AlphabetData.get_letter_audio_path(_correct_letter)
		AudioManager.play_audio(audio_path)
		GameLogger.info("FindLetterGame", "word_image_pressed", {"letter": _correct_letter})


func _on_square_pressed(index: int) -> void:
	if _state != STATE_PLAYING or _input_blocked or _solved[_card_index]:
		return
	var selected := _answers[index]
	var button := _square_buttons[index]
	if selected == _correct_letter:
		_input_blocked = true
		_solved[_card_index] = true
		button.disabled = true
		_set_square_color(button, COLOR_CORRECT)
		_play_square_correct_anim(button)
		AudioManager.play_audio(PROMPT_CORRECT_PATH)
		_hint_label.text = "Молодец!"
		GameLogger.info("FindLetterGame", "answer_correct", {"letter": selected})
		await get_tree().create_timer(FEEDBACK_DELAY).timeout
		if not is_inside_tree():
			return
		_input_blocked = false
		if _card_index + 1 >= _series.size():
			_show_completion()
		else:
			_show_card(_card_index + 1)
	else:
		_play_square_wrong_anim(button)
		AudioManager.play_stream(_error_beep)
		_hint_label.text = "Попробуй ещё!"
		GameLogger.info("FindLetterGame", "answer_wrong", {"letter": selected})


func _on_prev_card_pressed() -> void:
	if _state != STATE_PLAYING:
		return
	if _card_index > 0:
		_show_card(_card_index - 1)


func _on_next_card_pressed() -> void:
	if _state != STATE_PLAYING:
		return
	if _card_index + 1 < _series.size():
		_show_card(_card_index + 1)


## Показывает экран завершения серии.
func _show_completion() -> void:
	_state = STATE_COMPLETED
	_correct_letter = ""
	_hint_label.visible = false
	_card_panel.visible = false
	_prev_card_button.get_parent().visible = false
	_completion_panel.visible = true
	GameLogger.info("FindLetterGame", "series_completed", {"length": _series.size()})


func _on_completion_yes_pressed() -> void:
	GameLogger.info("FindLetterGame", "completion_yes_pressed", {})
	_start_series()


func _on_completion_no_pressed() -> void:
	GameLogger.info("FindLetterGame", "completion_no_pressed", {})
	_go_to_main_menu()


func _on_back_button_pressed() -> void:
	GameLogger.info("FindLetterGame", "back_button_pressed", {})
	_go_to_main_menu()


## Возвращает в главное меню.
func _go_to_main_menu() -> void:
	AudioManager.stop_all()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


## Применяет цвета текущей темы.
func _apply_theme(_mode: int = 0) -> void:
	_background.color = ThemeManager.get_bg()
	_title_label.add_theme_color_override("font_color", ThemeManager.get_text())
	_hint_label.add_theme_color_override("font_color", ThemeManager.get_text())
	_card_number_label.add_theme_color_override("font_color", ThemeManager.get_text())
	var button_bg := _get_button_bg()
	var button_text := _get_button_text()
	ThemeManager.style_button(_back_button, button_bg, button_text)
	ThemeManager.style_button(_ready_start_button, button_bg, button_text)
	ThemeManager.style_button(_prev_card_button, button_bg, button_text)
	ThemeManager.style_button(_next_card_button, button_bg, button_text)
	ThemeManager.style_button(_completion_yes_button, button_bg, button_text)
	ThemeManager.style_button(_completion_no_button, button_bg, button_text)
	if _state == STATE_PLAYING:
		_update_squares()


## Возвращает цвет фона кнопок текущей темы.
func _get_button_bg() -> Color:
	var colors: Dictionary = ThemeManager.COLORS[ThemeManager.current_theme]
	return colors["button_bg"] as Color


## Возвращает цвет текста кнопок текущей темы.
func _get_button_text() -> Color:
	var colors: Dictionary = ThemeManager.COLORS[ThemeManager.current_theme]
	return colors["button_text"] as Color


## Создаёт короткий звуковой сигнал ошибки.
func _build_error_beep() -> AudioStreamWAV:
	var num_samples := int(ERROR_BEEP_SAMPLE_RATE * ERROR_BEEP_DURATION)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	for index in num_samples:
		var time := float(index) / ERROR_BEEP_SAMPLE_RATE
		var envelope := 1.0
		if time < 0.005:
			envelope = time / 0.005
		elif time > ERROR_BEEP_DURATION - 0.01:
			envelope = (ERROR_BEEP_DURATION - time) / 0.01
		var sample := sin(2.0 * PI * ERROR_BEEP_FREQ * time) * envelope * 0.3
		var value := int(sample * 16384)
		data[index * 2] = value & 0xFF
		data[index * 2 + 1] = (value >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(ERROR_BEEP_SAMPLE_RATE)
	wav.stereo = false
	return wav
