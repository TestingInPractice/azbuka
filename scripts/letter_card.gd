extends Button

signal letter_clicked(letter: String)

var letter: String = "":
	set(value):
		letter = value
		if text != value:
			text = value

func _ready():
	text = letter

func _pressed():
	letter_clicked.emit(letter)
