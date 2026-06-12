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

func _pressed():
	letter_clicked.emit(letter)
	Global.go_to_letter_detail(letter)

func _update_completed_state():
	if letter in Global.visited_letters:
		modulate = Color(0.75, 0.75, 0.75, 1.0)
		add_theme_color_override("font_color", Color(0.35, 0.35, 0.35, 1.0))
