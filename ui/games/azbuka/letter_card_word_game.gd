extends Node
class_name LetterCardWordGame
## Мини-игра «найди букву в слове» и автозапись правильного ответа.
##
## Компонент строит квадраты слова из SetRepository, проверяет нажатия,
## показывает подсказки и после правильного ответа запускает запись голоса.

const COLOR_WORD_SQUARE := ThemeManager.ACCENT_TEAL
const RECORD_DURATION := 10.0
const LEVEL_SIZE := 11
const LEVEL_COUNT := 3

var _owner: Control
var _word_squares: HBoxContainer
var _hint_label: Label
var _play_button: Button
var _recording: LetterCardRecording
var _on_activity: Callable
var _is_transitioning: Callable
var _letter := ""
var _game_solved := false
var _game_input_blocked := false
var _word_letter_buttons: Array[Button] = []


func setup(
	owner: Control,
	word_squares: HBoxContainer,
	hint_label: Label,
	play_button: Button,
	recording: LetterCardRecording,
	on_activity: Callable,
	is_transitioning: Callable
) -> void:
	_owner = owner
	_word_squares = word_squares
	_hint_label = hint_label
	_play_button = play_button
	_recording = recording
	_on_activity = on_activity
	_is_transitioning = is_transitioning


func reset(letter: String) -> void:
	_letter = letter
	_game_solved = false
	_game_input_blocked = false
	_clear_word_buttons()
	_play_button.disabled = true
	_hint_label.text = "Найди букву «%s» в слове" % letter
	_hint_label.scale = Vector2.ONE
	_hint_label.show()
	var data := SetRepository.get_word_data(letter)
	var word: String = str(data.get("word", ""))
	if word.is_empty():
		return
	_setup_word_buttons(word)
	_recording.play_hint_sound()


func is_solved() -> bool:
	return _game_solved


func is_input_blocked() -> bool:
	return _game_input_blocked


func _clear_word_buttons() -> void:
	for btn in _word_letter_buttons:
		btn.queue_free()
	_word_letter_buttons.clear()


func _setup_word_buttons(word: String) -> void:
	var letters := _word_letters_without_combining(word)
	if letters.is_empty():
		return
	var vp_w: float = _owner.get_viewport_rect().size.x
	# Тап-таргеты >=190px (детская норма 10-12 мм на базе 1080x2340).
	var padding: float = 40.0
	var separation: float = 24.0
	var max_btn_w := 190.0
	var min_btn_w := 95.0
	var available: float = vp_w - padding * 2.0
	var btn_w: float = clampf(
		(available - separation * float(letters.size() - 1)) / float(letters.size()),
		min_btn_w, max_btn_w
	)
	var btn_size := Vector2(btn_w, btn_w)
	var font_size: int = maxi(28, mini(56, int(btn_w * 0.5)))
	for i in letters.size():
		var btn := Button.new()
		btn.name = "WordSquare_%d" % (i + 1)
		btn.accessibility_name = "WordSquare %d" % (i + 1)
		btn.unique_name_in_owner = true
		btn.text = letters[i]
		btn.add_theme_font_size_override("font_size", font_size)
		btn.custom_minimum_size = btn_size
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ThemeManager.style_button(btn, COLOR_WORD_SQUARE, ThemeManager.INK)
		btn.pressed.connect(_on_word_square_pressed.bind(i))
		_word_squares.add_child(btn)
		btn.owner = _owner
		_word_letter_buttons.append(btn)


## Возвращает буквы слова без комбинируемых диакритических знаков (U+0300-U+036F).
func _word_letters_without_combining(word: String) -> Array[String]:
	var letters: Array[String] = []
	for i in word.length():
		var cp: int = word.unicode_at(i)
		if cp >= 0x0300 and cp <= 0x036F:
			continue
		letters.append(word[i])
	return letters


func _on_word_square_pressed(index: int) -> void:
	if _game_solved or _game_input_blocked or _is_transitioning.call():
		return
	_on_activity.call()
	var btn: Button = _word_letter_buttons[index]
	var btn_letter: String = btn.text
	if btn_letter.to_lower() == _letter.to_lower():
		_game_solved = true
		_game_input_blocked = true
		_hint_label.text = "Скажи всё слово!"
		_show_feedback_anim()
		_play_word_correct_anim(btn)
		for b in _word_letter_buttons:
			if b.text.to_lower() == _letter.to_lower():
				b.modulate = ThemeManager.SUCCESS_MODULATE
		GameLogger.info("letter_card", "word_correct",
			{"letter": _letter, "index": index})
		var was_completed := ProgressManager.is_letter_completed(_letter)
		ProgressManager.mark_letter_completed(_letter)
		if not was_completed:
			_log_level_complete_if_needed()
		_recording.prepare_microphone()
		_auto_record_correct()
	else:
		_game_input_blocked = true
		GameLogger.warning("letter_card", "word_wrong",
			{"letter": _letter, "pressed": btn_letter})
		_recording.play_word_error_beep()
		_play_word_wrong_anim(btn)
		_hint_label.text = "Попробуй ещё!"
		_show_feedback_anim()
		await get_tree().create_timer(0.6).timeout
		if not is_inside_tree():
			return
		_game_input_blocked = false
		_hint_label.text = "Найди букву «%s» в слове" % _letter


func _auto_record_correct() -> void:
	var record_letter: String = _letter
	_recording.play_prompt(LetterCardRecording.PROMPT_CORRECT)
	await _recording.await_prompt_finished()
	if not is_inside_tree() or _letter != record_letter:
		return
	if _recording.start_recording():
		_recording.set_mic_text("Запись…")
		_recording.show_meter()
		await get_tree().create_timer(RECORD_DURATION).timeout
		if not is_inside_tree() or _letter != record_letter:
			return
		_recording.stop_recording()
		_recording.set_mic_text("Микрофон")
		_recording.hide_meter()
		if not _recording.has_recording():
			_hint_label.text = "Запись не получилась. Проверь микрофон."
			GameLogger.warning("letter_card", "auto_record_empty", {"letter": _letter})
			return
		var saved: bool = _save_auto_recording()
		GameLogger.info("letter_card", "auto_record_saved",
			{"letter": _letter, "saved": saved})
		_hint_label.text = "Молодец! Нажми ›"
		_show_feedback_anim()
		_recording.play_prompt(LetterCardRecording.PROMPT_FORWARD)
	else:
		push_warning("LetterCard: auto-record start failed - microphone may be unavailable")
		GameLogger.warning("letter_card", "auto_record_failed", {"letter": _letter})


func _save_auto_recording() -> bool:
	if not _recording.has_recording():
		return false
	var word_set := SetRepository.get_active_set_id()
	var data := SetRepository.get_word_data(_letter)
	var word: String = str(data.get("word", "unknown")).to_lower()
	DirAccess.make_dir_recursive_absolute("user://recordings")
	var ts: String = Time.get_datetime_string_from_system().replace("T", "_").replace(":", "-")
	var path := "user://recordings/%s_%s_set%s_%s.wav" % [
		_letter.to_lower(), word, word_set, ts
	]
	return _recording.save_recording(path)


func _show_feedback_anim() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	_hint_label.scale = Vector2.ZERO
	tween.tween_property(_hint_label, "scale", Vector2.ONE, 0.5)


func _log_level_complete_if_needed() -> void:
	var index := LetterCard.LETTERS.find(_letter)
	if index < 0:
		return
	var level := int(index / LEVEL_SIZE)
	var start := level * LEVEL_SIZE
	var end := mini(start + LEVEL_SIZE, LetterCard.LETTERS.size())
	for letter_index in range(start, end):
		if not ProgressManager.is_letter_completed(LetterCard.LETTERS[letter_index]):
			return
	GameLogger.analytics("level_complete", {
		"game": "azbuka",
		"level": level + 1,
		"letters": end - start,
		"total_levels": LEVEL_COUNT,
	})
	GameLogger.info("letter_card", "level_complete", {"level": level + 1})


func _play_word_correct_anim(btn: Button) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BOUNCE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(1.3, 1.3), 0.15)
	tween.tween_property(btn, "scale", Vector2.ONE, 0.25)
	tween.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.2)
	tween.tween_property(btn, "scale", Vector2.ONE, 0.2)
	tween.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.15)
	tween.tween_property(btn, "scale", Vector2.ONE, 0.15)


func _play_word_wrong_anim(btn: Button) -> void:
	btn.modulate = ThemeManager.ERROR_MODULATE
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	var orig: float = btn.rotation_degrees
	for _k in 3:
		tween.tween_property(btn, "rotation_degrees", orig - 8.0, 0.04)
		tween.tween_property(btn, "rotation_degrees", orig + 8.0, 0.04)
	tween.tween_property(btn, "rotation_degrees", orig, 0.04)
	var reset := create_tween()
	reset.tween_interval(0.3)
	reset.tween_property(btn, "modulate", ThemeManager.WHITE, 0.2)
