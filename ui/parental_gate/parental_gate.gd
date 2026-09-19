extends CanvasLayer
class_name ParentalGate
## Родительская Защита (Parental Gate): экран для взрослых.
##
## Показывает простой арифметический пример (сложение чисел 2..9) с тремя
## вариантами ответа (правильный + 2 дистрактора). Новый пример при каждой
## ошибке. При правильном ответе вызывается callback on_success один раз
## и узел удаляется из дерева.
## Используется как CanvasLayer-оверлей поверх текущей сцены.

const SCENE_PATH := "res://ui/parental_gate/parental_gate.tscn"
const MIN_OPERAND := 2
const MAX_OPERAND := 9

@onready var _title_label: Label = %TitleLabel
@onready var _question_label: Label = %QuestionLabel
@onready var _buttons_container: HBoxContainer = %ButtonsContainer
@onready var _answer_button_1: Button = %AnswerButton1
@onready var _answer_button_2: Button = %AnswerButton2
@onready var _answer_button_3: Button = %AnswerButton3
@onready var _result_card: PanelContainer = %ResultCard
@onready var _result_label: Label = %ResultLabel
@onready var _overlay: ColorRect = $Overlay
@onready var _cancel_button: Button = %CancelButton

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _correct_answer: int = 0
var _on_success_callback: Callable = Callable()
var _callback_fired: bool = false
var _answer_buttons: Array[Button] = []


## Создаёт и показывает ParentalGate поверх текущей сцены.
##
## [caller] — Control-узел, вызывающий gate (нужен для добавления в дерево).
## [on_success] — Callable, вызывается один раз при правильном ответе.
##
## Пример использования:
##   ParentalGate.open(self, func(): get_tree().change_scene_to_file(...))
static func open(caller: Control, on_success: Callable) -> void:
	var gate: CanvasLayer = load(SCENE_PATH).instantiate()
	caller.get_tree().current_scene.get_parent().add_child(gate)
	gate._on_success_callback = on_success
	gate._setup_gate()
	GameLogger.info("ParentalGate", "opened", {})


func _ready() -> void:
	_answer_buttons = [_answer_button_1, _answer_button_2, _answer_button_3]
	_answer_button_1.pressed.connect(_on_answer_pressed.bind(0))
	_answer_button_2.pressed.connect(_on_answer_pressed.bind(1))
	_answer_button_3.pressed.connect(_on_answer_pressed.bind(2))
	_cancel_button.pressed.connect(_on_cancel_button_pressed)
	ThemeManager.theme_changed.connect(_apply_theme)
	_apply_theme()


## Генерирует новый пример и обновляет UI.
func _setup_gate() -> void:
	_callback_fired = false
	_result_card.visible = false
	_generate_problem()
	_apply_theme()


## Генерирует случайный пример a + b, вычисляет ответ и расставляет
## дистракторы по кнопкам в случайном порядке.
func _generate_problem() -> void:
	_rng.randomize()
	var a: int = _rng.randi_range(MIN_OPERAND, MAX_OPERAND)
	var b: int = _rng.randi_range(MIN_OPERAND, MAX_OPERAND)
	_correct_answer = a + b
	_question_label.text = "Сколько будет %d + %d?" % [a, b]
	var options: Array[int] = _generate_distractors(_correct_answer)
	options.shuffle()
	for i: int in range(_answer_buttons.size()):
		_answer_buttons[i].text = str(options[i])


## Генерирует 2 уникальных дистрактора к правильному ответу.
## Дистракторы: ±1, ±2, +10-сдвиг. Без дубликатов, без отрицательных,
## не равны правильному ответу.
func _generate_distractors(answer: int) -> Array[int]:
	var distractors: Array[int] = []
	var pool: Array[int] = [
		answer - 2, answer - 1,
		answer + 1, answer + 2,
		answer + 8, answer + 10, answer + 12,
	]
	# Убираем отрицательные, дубликаты и сам ответ.
	var unique: Array[int] = []
	for val: int in pool:
		if val > 0 and val != answer and val not in unique:
			unique.append(val)
	unique.shuffle()
	for val: int in unique:
		if distractors.size() >= 2:
			break
		distractors.append(val)
	# Если по какой-то причине не набралось 2 дистракторов — добавляем
	# запасные варианты (ответ + 100, ответ + 200).
	if distractors.size() < 2:
		var extra: int = answer + 100
		while extra in distractors or extra == answer:
			extra += 1
		distractors.append(extra)
	if distractors.size() < 2:
		var extra2: int = answer + 200
		while extra2 in distractors or extra2 == answer:
			extra2 += 1
		distractors.append(extra2)
	return [answer, distractors[0], distractors[1]]


## Обработчик нажатия кнопки ответа.
func _on_answer_pressed(button_index: int) -> void:
	var pressed_value: int = int(_answer_buttons[button_index].text)
	if pressed_value == _correct_answer:
		GameLogger.info("ParentalGate", "passed", {})
		_show_success()
		if not _callback_fired:
			_callback_fired = true
			_on_success_callback.call_deferred()
			_free_gate.call_deferred()
	else:
		GameLogger.info("ParentalGate", "failed", {"attempt": pressed_value})
		_generate_problem()


## Показывает сообщение об успехе.
func _show_success() -> void:
	_result_card.visible = true
	_result_label.text = "Верно!"
	_result_label.add_theme_color_override("font_color", Color("#4CAF50"))


## Удаляет gate из дерева.
func _free_gate() -> void:
	queue_free()


## Обработчик кнопки «Закрыть» — закрывает gate без вызова callback.
func _on_cancel_button_pressed() -> void:
	GameLogger.info("ParentalGate", "cancelled", {})
	queue_free()


## Применяет цвета текущей темы ко всем элементам UI.
func _apply_theme(_mode: int = 0) -> void:
	if not is_inside_tree():
		return
	_title_label.add_theme_color_override("font_color", ThemeManager.get_text())
	_question_label.add_theme_color_override("font_color", ThemeManager.get_text())
	# ResultCard.
	var result_box := StyleBoxFlat.new()
	result_box.bg_color = ThemeManager.get_card_bg()
	result_box.set_corner_radius_all(24)
	result_box.content_margin_left = 32
	result_box.content_margin_right = 32
	result_box.content_margin_top = 16
	result_box.content_margin_bottom = 16
	_result_card.add_theme_stylebox_override("panel", result_box)
	# Кнопки ответов: яркий акцентный фон.
	var colors: Dictionary = ThemeManager.COLORS[ThemeManager.current_theme]
	var button_bg := colors["button_bg"] as Color
	var button_text := colors["button_text"] as Color
	for btn: Button in _answer_buttons:
		ThemeManager.style_button(btn, button_bg, button_text)
	# Кнопка «Закрыть»: серый фон.
	ThemeManager.style_button(_cancel_button, button_bg.darkened(0.3), button_text)
