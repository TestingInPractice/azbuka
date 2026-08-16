extends Node2D

# Тестовая сцена: показывает анимации Киса (idle / walk_right / walk_left)
# Запуск: godot --path . assets/images/sprites/kisa_anim_test.tscn

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
var anim_names := ["idle", "walk_right", "walk_left"]
var idx := 0
var timer := 0.0

func _ready() -> void:
	anim.play(anim_names[idx])
	print("KisaAnimTest: playing ", anim_names[idx], " frames=", anim.sprite_frames.get_frame_count(anim_names[idx]))

func _process(delta: float) -> void:
	timer += delta
	if timer > 2.0:
		timer = 0.0
		idx = (idx + 1) % anim_names.size()
		anim.play(anim_names[idx])
		print("KisaAnimTest: playing ", anim_names[idx], " frames=", anim.sprite_frames.get_frame_count(anim_names[idx]))