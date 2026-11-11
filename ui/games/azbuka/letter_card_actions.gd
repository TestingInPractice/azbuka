extends Node
class_name LetterCardActions
## Кнопки карточки: звуки буквы и слова, микрофон, прослушивание, выход.
##
## Компонент сам подключает сигналы и держит флаг перехода между сценами,
## чтобы основной экран занимался только сборкой компонентов и данными.

const AZBUKA_SCENE := "res://ui/games/azbuka/azbuka.tscn"
const MAIN_MENU_SCENE := "res://ui/main_menu/main_menu.tscn"

var _owner: Control
var _recording: LetterCardRecording
var _letter_provider: Callable
var _reset_idle: Callable
var _stop_idle: Callable
var _navigating := false


func setup(
	owner: Control,
	back_button: Button,
	home_button: Button,
	letter_button: Button,
	word_button: Button,
	mic_button: Button,
	play_button: Button,
	recording: LetterCardRecording,
	letter_provider: Callable,
	reset_idle: Callable,
	stop_idle: Callable
) -> void:
	_owner = owner
	_recording = recording
	_letter_provider = letter_provider
	_reset_idle = reset_idle
	_stop_idle = stop_idle
	back_button.pressed.connect(_on_back_pressed)
	home_button.pressed.connect(_on_home_pressed)
	letter_button.pressed.connect(_on_letter_sound_pressed)
	word_button.pressed.connect(_on_word_sound_pressed)
	mic_button.pressed.connect(_on_mic_pressed)
	play_button.pressed.connect(_on_play_pressed)


func is_navigating() -> bool:
	return _navigating


func _letter() -> String:
	return str(_letter_provider.call())


func _on_letter_sound_pressed() -> void:
	var letter := _letter()
	GameLogger.info("letter_card", "letter_sound", {"letter": letter})
	AudioManager.stop_all()
	# В обучении ребёнок должен слышать фонему, а не название буквы. У Ъ/Ь
	# отдельной фонемы нет, поэтому get_letter_sound() отдаёт название как
	# осознанный фолбэк.
	AudioManager.play_stream(SetRepository.get_letter_sound(letter))
	_reset_idle.call()


func _on_word_sound_pressed() -> void:
	var letter := _letter()
	GameLogger.info("letter_card", "word_sound", {"letter": letter})
	AudioManager.stop_all()
	AudioManager.play_stream(SetRepository.get_word_audio(letter))
	_reset_idle.call()


func _on_mic_pressed() -> void:
	_recording.handle_mic_pressed(_letter())


func _on_play_pressed() -> void:
	_recording.handle_play_pressed(_letter())


func _on_back_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	_stop_idle.call()
	GameLogger.info("nav", "to_azbuka", {"from": "letter_card", "letter": _letter()})
	AudioManager.stop_all()
	_owner.get_tree().change_scene_to_file(AZBUKA_SCENE)


func _on_home_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	_stop_idle.call()
	GameLogger.info("nav", "to_main_menu", {"from": "letter_card_home", "letter": _letter()})
	AudioManager.stop_all()
	_owner.get_tree().change_scene_to_file(MAIN_MENU_SCENE)
