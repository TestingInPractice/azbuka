extends Node
class_name LetterCardNavigation
## Листание букв влево/вправо со слайдом контента.
##
## Компонент держит текущий индекс, состояние перехода и кнопки навигации.
## Карточка сообщает ему список букв и колбэк, который обновляет контент.

const SLIDE_DURATION := 0.3

var _owner: Control
var _content_wrapper: Control
var _prev_button: Button
var _next_button: Button
var _letters: Array[String]
var _index := 0
var _letter := ""
var _on_changed: Callable
var _on_activity: Callable
var _stop_recording: Callable
var _is_navigating: Callable
var _is_transitioning := false


func setup(
	owner: Control,
	content_wrapper: Control,
	prev_button: Button,
	next_button: Button,
	letters: Array[String],
	index: int,
	letter: String,
	on_changed: Callable,
	on_activity: Callable,
	stop_recording: Callable,
	is_navigating: Callable
) -> void:
	_owner = owner
	_content_wrapper = content_wrapper
	_prev_button = prev_button
	_next_button = next_button
	_letters = letters
	_index = index
	_letter = letter
	_on_changed = on_changed
	_on_activity = on_activity
	_stop_recording = stop_recording
	_is_navigating = is_navigating
	_prev_button.pressed.connect(_on_prev_pressed)
	_next_button.pressed.connect(_on_next_pressed)


func update_buttons() -> void:
	_prev_button.disabled = _index <= 0
	_next_button.disabled = _index >= _letters.size() - 1


func is_transitioning() -> bool:
	return _is_transitioning


func _on_prev_pressed() -> void:
	if _is_transitioning or _is_navigating.call() or _index <= 0:
		return
	GameLogger.info("letter_card", "prev", {"from": _letter})
	_stop_recording.call()
	_navigate_to(_index - 1, -1)
	_on_activity.call()


func _on_next_pressed() -> void:
	if _is_transitioning or _is_navigating.call() or _index >= _letters.size() - 1:
		return
	GameLogger.info("letter_card", "next", {"from": _letter})
	_stop_recording.call()
	_navigate_to(_index + 1, 1)
	_on_activity.call()


func _navigate_to(target_idx: int, direction: int) -> void:
	_is_transitioning = true
	var new_letter: String = _letters[target_idx]
	var screen_w: float = _owner.get_viewport_rect().size.x
	var slide_target: float = -direction * screen_w
	var slide_start: float = direction * screen_w

	var tween_out := create_tween().set_parallel(true)
	tween_out.tween_method(_set_content_offset, 0.0, slide_target, SLIDE_DURATION)
	tween_out.tween_property(_content_wrapper, "modulate:a", 0.0, SLIDE_DURATION)
	await tween_out.finished

	_index = target_idx
	_letter = new_letter
	_on_changed.call(new_letter, target_idx)

	_set_content_offset(slide_start)
	_content_wrapper.modulate.a = 0.0

	var tween_in := create_tween().set_parallel(true)
	tween_in.tween_method(_set_content_offset, slide_start, 0.0, SLIDE_DURATION)
	tween_in.tween_property(_content_wrapper, "modulate:a", 1.0, SLIDE_DURATION)
	await tween_in.finished

	_set_content_offset(0.0)
	update_buttons()
	_is_transitioning = false


func _set_content_offset(v: float) -> void:
	_content_wrapper.offset_left = v
	_content_wrapper.offset_right = v
