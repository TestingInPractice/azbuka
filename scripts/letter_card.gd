extends Button

signal letter_clicked(letter: String)

var letter: String = "":
	set(value):
		letter = value
		if text != value:
			text = value

func _ready():
	text = letter
	_update_completed_state()
	ThemeManager.theme_changed.connect(_on_theme_changed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_theme_changed(_theme_name: String):
	_update_completed_state()

func _on_mouse_entered():
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.08, 1.08), 0.15)

func _on_mouse_exited():
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.12)

func _pressed():
	letter_clicked.emit(letter)
	Global.go_to_letter_detail(letter)

func _update_completed_state():
	if ProgressManager.is_letter_completed(letter):
		modulate = Color(0.75, 0.75, 0.75, 1.0)
		add_theme_color_override("font_color", ThemeManager.get_text())
	else:
		modulate = Color.WHITE
		add_theme_color_override("font_color", ThemeManager.get_text())
