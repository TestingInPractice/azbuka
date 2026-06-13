extends Control

var points: Array[Vector2] = []
var line_color := Color(0.357, 0.549, 0.353)
var line_width := 6.0

func _draw():
	if points.size() < 2:
		return
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], line_color, line_width, true)
