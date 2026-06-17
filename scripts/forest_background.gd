extends Control

@export var zoom := 1.0
@export var focus := Vector2(0.5, 0.5)

var _texture: Texture2D = null

func _ready():
	_load_texture()
	resized.connect(queue_redraw)
	ThemeManager.theme_changed.connect(queue_redraw)

func _load_texture():
	if ResourceLoader.exists("res://assets/images/fone.jpg"):
		_texture = ResourceLoader.load("res://assets/images/fone.jpg") as Texture2D

func _draw():
	if not _texture:
		return
	var rect := Rect2(Vector2.ZERO, size)
	draw_texture_rect(_texture, rect, false)
	if ThemeManager.current_theme == "dark":
		draw_rect(rect, Color(0, 0, 0, 0.4))
