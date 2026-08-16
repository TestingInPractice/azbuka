extends Control
class_name KisaCat
## Киса: персонаж-кот, который бежит по змейке.
##
## Анимируется спрайтом: кадры нарезаны из сгенерированного спрайт-шита и
## собраны в kisa_sprite_frames.tres (idle / walk_right / walk_left).
## API совместим с прежней кодовой Кисой: set_kisa_moving(), set_facing().

const SPRITE_FRAMES := preload("res://assets/images/sprites/kisa_sprite_frames.tres")
## Масштаб спрайта: кадр 128x170, прежняя кодовая Киса была ~110x154.
const SPRITE_SCALE := 0.9

## Бежит ли Киса (выбор анимации walk или idle).
var is_moving := false
## Направлен ли Киса вправо.
var facing_right := true

var _sprite: AnimatedSprite2D


func _ready() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "KisaSprite"
	_sprite.sprite_frames = SPRITE_FRAMES
	_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	# Спрайт отцентрован: низ кадра (ступни) стоит в точке маршрута (0,0) Control.
	var frame_height := SPRITE_FRAMES.get_frame_texture("walk_right", 0).get_height()
	_sprite.position = Vector2(0.0, -frame_height * SPRITE_SCALE / 2.0)
	add_child(_sprite)
	_update_animation()


## Включает и выключает анимацию бега.
func set_kisa_moving(value: bool) -> void:
	is_moving = value
	_update_animation()


## Задаёт направление взгляда.
func set_facing(value: bool) -> void:
	facing_right = value
	_update_animation()


func _update_animation() -> void:
	if not is_node_ready():
		return
	if is_moving:
		_sprite.play("walk_right" if facing_right else "walk_left")
	else:
		_sprite.play("idle")