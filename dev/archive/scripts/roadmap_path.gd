extends Control

var points: Array[Vector2] = []
var line_color := Color(0.357, 0.549, 0.353)
var line_width := 6.0

var corner_radius := 30.0

func _draw():
	if points.size() < 2:
		return

	var smooth := _build_smooth_path()
	for i in range(smooth.size() - 1):
		draw_line(smooth[i], smooth[i + 1], line_color, line_width, true)

func _build_smooth_path() -> Array[Vector2]:
	if points.size() < 3:
		return points.duplicate()

	var result: Array[Vector2] = []
	result.append(points[0])

	for i in range(1, points.size() - 1):
		var prev = points[i - 1]
		var curr = points[i]
		var next = points[i + 1]

		var d1 = curr - prev
		var d2 = next - curr

		var dy = abs(d2.y)

		if dy < 10:
			result.append(curr)
			continue

		var seg_r = min(corner_radius, d1.length() * 0.45, d2.length() * 0.45)
		if seg_r < 2:
			result.append(curr)
			continue

		var dir_in = d1.normalized()
		var dir_out = d2.normalized()

		var arc_center = curr
		var arc_start = curr - dir_in * seg_r
		var arc_end = curr + dir_out * seg_r

		result.append(arc_start)

		var start_angle = dir_in.angle() + PI
		var end_angle = dir_out.angle()

		var steps = 12
		var sweep = end_angle - start_angle
		if sweep > PI:
			sweep -= 2 * PI
		elif sweep < -PI:
			sweep += 2 * PI

		for j in range(1, steps + 1):
			var t = float(j) / steps
			var a = start_angle + sweep * t
			result.append(arc_center + Vector2(cos(a), sin(a)) * seg_r)

		result.append(arc_end)

	result.append(points[points.size() - 1])
	return result
