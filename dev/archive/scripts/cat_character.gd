extends Node2D

enum Anim { IDLE, WALK }

var anim: Anim = Anim.IDLE:
	set(v):
		if v != anim:
			anim = v
			_anim_time = 0.0

var facing_right: bool = true:
	set(v):
		if v != facing_right:
			facing_right = v
			scale.x = 1.0 if v else -1.0

var _anim_time: float = 0.0

func _ready() -> void:
	queue_redraw()

func _process(delta: float) -> void:
	_anim_time += delta
	queue_redraw()

func _draw() -> void:
	var t = _anim_time

	# Body
	draw_circle(Vector2(0, -10), 12, Color("#E8853D"))

	# Tail
	var tail_wag = sin(t * 3.0) * 0.4 if anim == Anim.IDLE else 0.6
	var tail_angle = PI * 0.4 + tail_wag * 0.6
	var tx := cos(-tail_angle + PI) * 18.0 + 12.0
	var ty := sin(-tail_angle + PI) * 18.0 - 10.0
	draw_line(Vector2(12, -10), Vector2(tx, ty), Color("#E8853D"), 5.0)

	# Head
	draw_circle(Vector2(0, -28), 10, Color("#E8853D"))
	draw_circle(Vector2(0, -28), 10, Color("#8B3020"), false, 1.5)

	# Eyes
	draw_circle(Vector2(-3, -30), 2, Color("#6AB84C"))
	draw_circle(Vector2(3, -30), 2, Color("#6AB84C"))

	# Front legs
	var leg_cycle := 0.0
	if anim == Anim.WALK:
		leg_cycle = sin(t * PI * 8.0) * 4.0
	draw_rect(Rect2(-7 + leg_cycle, -2, 4, 8), Color("#E8853D"))
	draw_rect(Rect2(3 - leg_cycle, -2, 4, 8), Color("#E8853D"))
