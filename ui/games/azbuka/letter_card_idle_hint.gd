extends Node
class_name LetterCardIdleHint
## Таймер подсказки после долгой паузы.
##
## Карточка сообщает компоненту, когда ребёнок занят, а компонент сам решает,
## можно ли запускать таймер и проигрывать звук подсказки.

const IDLE_HINT_DELAY := 6.0

var _owner: Control
var _is_busy: Callable
var _play_hint: Callable
var _letter_provider: Callable
var _timer: Timer


func setup(
	owner: Control,
	is_busy: Callable,
	play_hint: Callable,
	letter_provider: Callable
) -> void:
	_owner = owner
	_is_busy = is_busy
	_play_hint = play_hint
	_letter_provider = letter_provider
	_timer = Timer.new()
	_timer.name = "IdleTimer"
	_timer.wait_time = IDLE_HINT_DELAY
	_timer.one_shot = true
	_timer.autostart = false
	_timer.timeout.connect(_on_timeout)
	_owner.add_child(_timer)
	_timer.owner = _owner
	_timer.unique_name_in_owner = true


func reset() -> void:
	if _is_busy.call():
		return
	_timer.stop()
	_timer.start()


func stop() -> void:
	_timer.stop()


func _on_timeout() -> void:
	if _is_busy.call():
		return
	_play_hint.call()
	var letter: String = str(_letter_provider.call())
	GameLogger.info("letter_card", "idle_hint", {"letter": letter})
	reset()
