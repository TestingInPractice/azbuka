extends Control

@export var overlay_color: Color = Color(0, 0, 0, 0.4)

func _ready():
	resized.connect(queue_redraw)
	ThemeManager.theme_changed.connect(queue_redraw)

func _draw():
	if ThemeManager.current_theme == "dark":
		draw_rect(Rect2(Vector2.ZERO, size), overlay_color)
