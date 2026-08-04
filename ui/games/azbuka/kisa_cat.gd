extends Control
class_name KisaCat
## Киса: персонаж-кот, который бежит по змейке.
##
## Рисуется кодом, чтобы анимировать обязательные элементы из раздела 9
## спецификации: движение лап при беге и покачивание хвоста.

## Основной оранжевый цвет шерсти.
const BODY_COLOR := Color("#F5A623")
## Тёмный оттенок для лап.
const LEG_COLOR := Color("#D98E1B")
## Светлый цвет живота.
const BELLY_COLOR := Color("#F9C98A")
## Цвет внутренней части ушей.
const INNER_EAR_COLOR := Color("#E86A6A")
## Цвет носа.
const NOSE_COLOR := Color("#C95B4E")
## Цвет глаз и усов.
const DARK_COLOR := Color("#2D2D2D")

## Бежит ли Киса (влияет на амплитуду анимации лап и хвоста).
var is_moving := false
## Направлен ли Киса вправо.
var facing_right := true

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## Включает и выключает анимацию бега.
func set_kisa_moving(value: bool) -> void:
	is_moving = value


## Задаёт направление взгляда.
func set_facing(value: bool) -> void:
	facing_right = value


func _draw() -> void:
	var scale_x := 1.0 if facing_right else -1.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(scale_x, 1.0))
	_draw_tail()
	_draw_legs()
	_draw_body()
	_draw_head()
	_draw_face()


## Хвост с покачиванием.
func _draw_tail() -> void:
	var amplitude := 20.0 if is_moving else 12.0
	var wag := sin(_time * 3.0) * amplitude
	var points := PackedVector2Array([
		Vector2(42, -48),
		Vector2(66, -64),
		Vector2(80, -82),
		Vector2(78, -98 + wag),
	])
	draw_polyline(points, BODY_COLOR, 15.0, true)


## Лапы с анимацией бега.
func _draw_legs() -> void:
	var lift := 5.0
	var shift := sin(_time * 9.0) * lift if is_moving else 0.0
	# Задняя пара лап.
	draw_rect(Rect2(-38, -14 + shift, 12, 14 - shift), LEG_COLOR)
	draw_rect(Rect2(-22, -14 - shift, 12, 14 + shift), LEG_COLOR)
	# Передняя пара лап.
	draw_rect(Rect2(10, -14 - shift, 12, 14 + shift), LEG_COLOR)
	draw_rect(Rect2(26, -14 + shift, 12, 14 - shift), LEG_COLOR)


## Туловище с животом.
func _draw_body() -> void:
	draw_circle(Vector2(-4, -48), 44.0, BODY_COLOR)
	draw_circle(Vector2(-8, -40), 28.0, BELLY_COLOR)


## Голова с ушами.
func _draw_head() -> void:
	draw_circle(Vector2(16, -106), 34.0, BODY_COLOR)
	var left_ear := PackedVector2Array([Vector2(-12, -128), Vector2(2, -154), Vector2(10, -126)])
	var right_ear := PackedVector2Array([Vector2(24, -128), Vector2(40, -152), Vector2(44, -124)])
	draw_colored_polygon(left_ear, BODY_COLOR)
	draw_colored_polygon(right_ear, BODY_COLOR)
	var left_inner := PackedVector2Array([Vector2(-6, -130), Vector2(2, -146), Vector2(8, -129)])
	var right_inner := PackedVector2Array([Vector2(26, -130), Vector2(38, -145), Vector2(40, -127)])
	draw_colored_polygon(left_inner, INNER_EAR_COLOR)
	draw_colored_polygon(right_inner, INNER_EAR_COLOR)


## Мордочка: глаза, нос, усы.
func _draw_face() -> void:
	draw_circle(Vector2(4, -112), 5.0, DARK_COLOR)
	draw_circle(Vector2(28, -112), 5.0, DARK_COLOR)
	var nose := PackedVector2Array([Vector2(16, -98), Vector2(10, -92), Vector2(22, -92)])
	draw_colored_polygon(nose, NOSE_COLOR)
	draw_line(Vector2(6, -94), Vector2(-10, -98), DARK_COLOR, 2.0)
	draw_line(Vector2(6, -90), Vector2(-10, -90), DARK_COLOR, 2.0)
	draw_line(Vector2(6, -86), Vector2(-10, -82), DARK_COLOR, 2.0)
	draw_line(Vector2(26, -94), Vector2(42, -98), DARK_COLOR, 2.0)
	draw_line(Vector2(26, -90), Vector2(42, -90), DARK_COLOR, 2.0)
	draw_line(Vector2(26, -86), Vector2(42, -82), DARK_COLOR, 2.0)
