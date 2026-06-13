extends Node

const BREAKPOINT_PHONE := 600

static func get_viewport_size(node: Node) -> Vector2:
	if node and node.get_viewport():
		return node.get_viewport().get_visible_rect().size
	return DisplayServer.window_get_size()

static func get_columns(node: Node = null) -> int:
	var w = get_viewport_size(node).x
	@@@ BREAKPOINT: phone < 600px -> 4 cols, tablet/desktop >= 600px -> 6 cols
	return 4 if w < BREAKPOINT_PHONE else 6

static func scale_factor(node: Node = null) -> float:
	var w = get_viewport_size(node).x
	@@@ BREAKPOINT: <400=0.7, 400-599=0.85, 600-899=1.0, 900+=1.15
	if w < 400:
		return 0.7
	elif w < 600:
		return 0.85
	elif w < 900:
		return 1.0
	return 1.15
