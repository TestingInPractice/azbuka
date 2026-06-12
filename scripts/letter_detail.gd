extends Control

var letter: String = ""
var letter_name: String = ""

@onready var letter_label := $CenterContainer/VBoxContainer/LetterLabel
@onready var name_label := $CenterContainer/VBoxContainer/NameLabel
@onready var back_button := $CenterContainer/VBoxContainer/BackButton

func _ready():
	letter_label.text = letter
	name_label.text = "Буква «%s»" % letter_name
	back_button.pressed.connect(_on_back_pressed)

func _on_back_pressed():
	Global.go_to_alphabet_screen()
