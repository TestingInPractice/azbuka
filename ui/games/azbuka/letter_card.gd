extends Control
class_name LetterCard
## Карточка буквы: слово, звуки, микрофон и автозапись.
##
## Слева вверху - кнопка назад, в центре - большая буква и картинка слова,
## ниже - квадраты букв слова (мини-игра "найди букву"), кнопки навигации
## по алфавиту. Главное действие - широкая кнопка «Слушать букву», под ней
## компактный ряд второстепенных действий: слово, микрофон и запись.
## Запись, мини-игра, листание, таймер подсказки, звуки и раскраска вынесены
## в компоненты, а экран только собирает их и хранит текущую букву.

const LETTERS: Array[String] = [
	"А", "Б", "В", "Г", "Д", "Е", "Ё", "Ж", "З", "И", "Й",
	"К", "Л", "М", "Н", "О", "П", "Р", "С", "Т", "У", "Ф",
	"Х", "Ц", "Ч", "Ш", "Щ", "Ъ", "Ы", "Ь", "Э", "Ю", "Я",
]

## Буква, с которой открывается карточка. Устанавливает экран «Азбука»
## перед переключением сцены.
static var from_letter: String = ""

var letter: String = ""
var _current_index: int = 0
var _recording: LetterCardRecording
var _navigation: LetterCardNavigation
var _word_game: LetterCardWordGame
var _idle_hint: LetterCardIdleHint
var _content: LetterCardContent
var _actions: LetterCardActions

@onready var _content_wrapper: Control = %ContentWrapper
@onready var _word_squares: HBoxContainer = %WordSquares
@onready var _hint_label: Label = %HintLabel
@onready var _prev_button: Button = %PrevLetterButton
@onready var _next_button: Button = %NextLetterButton
@onready var _button_letter: Button = %ButtonLetter
@onready var _button_word: Button = %ButtonWord
@onready var _mic_button: Button = %MicButton
@onready var _play_button: Button = %RecordPlaybackButton
@onready var _back_button: Button = %LetterBackButton
@onready var _home_button: Button = %HomeButton


func _ready() -> void:
	if from_letter.is_empty():
		from_letter = "А"
	letter = from_letter
	_current_index = LETTERS.find(letter)
	if _current_index < 0:
		_current_index = 0
		letter = LETTERS[0]
	_setup_components()
	_apply_theme()
	ThemeManager.theme_changed.connect(_apply_theme)
	_content.update()
	_navigation.update_buttons()
	GameLogger.analytics("letter_view", {"letter": letter, "index": _current_index})
	GameLogger.info("letter_card", "ready", {"letter": letter, "index": _current_index})


func _setup_components() -> void:
	_recording = LetterCardRecording.new()
	_recording.name = "Recording"
	add_child(_recording)
	_recording.setup(self, _mic_button, _play_button)

	_actions = LetterCardActions.new()
	_actions.name = "Actions"
	add_child(_actions)
	_actions.setup(
		self, _back_button, _home_button, _button_letter, _button_word,
		_mic_button, _play_button, _recording, _current_letter,
		_reset_idle_timer, _stop_idle_timer
	)

	_navigation = LetterCardNavigation.new()
	_navigation.name = "Navigation"
	add_child(_navigation)
	_navigation.setup(
		self, _content_wrapper, _prev_button, _next_button, LETTERS,
		_current_index, letter, _on_navigation_changed, _reset_idle_timer,
		_recording.stop_if_active, _actions.is_navigating
	)

	_word_game = LetterCardWordGame.new()
	_word_game.name = "WordGame"
	add_child(_word_game)
	_word_game.setup(
		self, _word_squares, _hint_label, _play_button, _recording,
		_reset_idle_timer, _navigation.is_transitioning
	)

	_idle_hint = LetterCardIdleHint.new()
	_idle_hint.name = "IdleHint"
	add_child(_idle_hint)
	_idle_hint.setup(self, _is_idle_busy, _recording.play_hint_sound, _current_letter)

	_content = LetterCardContent.new()
	_content.name = "Content"
	add_child(_content)
	_content.setup(self, _word_game, _reset_idle_timer, _current_letter)


## Публичный шов для тестов и конструктора: запись делегирована компоненту.
func prepare_microphone() -> bool:
	return _recording.prepare_microphone()


func start_recording() -> bool:
	return _recording.start_recording()


func stop_recording() -> void:
	_recording.stop_recording()


func play_recording() -> void:
	_recording.play_recording()


func save_recording(path: String) -> bool:
	return _recording.save_recording(path)


func is_recording() -> bool:
	return _recording.is_recording()


func has_recording() -> bool:
	return _recording.has_recording()


func _on_navigation_changed(new_letter: String, new_index: int) -> void:
	letter = new_letter
	_current_index = new_index
	GameLogger.analytics("letter_view", {"letter": new_letter, "index": new_index})
	# Синхронизация статической переменной, чтобы котик на экране «Азбука»
	# вернулся на последнюю просмотренную букву, а не на букву открытия.
	LetterCard.from_letter = new_letter
	_content.update()
	_apply_theme()


func _apply_theme(_mode: int = 0) -> void:
	LetterCardTheme.apply(self)


func _reset_idle_timer() -> void:
	if _idle_hint != null:
		_idle_hint.reset()


func _stop_idle_timer() -> void:
	if _idle_hint != null:
		_idle_hint.stop()


func _is_idle_busy() -> bool:
	if _actions != null and _actions.is_navigating():
		return true
	if not AudioManager.sound_enabled:
		return true
	if _navigation != null and _navigation.is_transitioning():
		return true
	if _word_game == null:
		return false
	return _word_game.is_solved() or _word_game.is_input_blocked()


func _current_letter() -> String:
	return letter


func _exit_tree() -> void:
	VoiceRecord.release_microphone()
	if _recording != null:
		_recording.release()
	AudioManager.stop_all()
