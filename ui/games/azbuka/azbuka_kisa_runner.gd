extends Node
class_name AzbukaKisaRunner
## Бег кисы по готовым точкам змейки.
##
## Компонент получает массив позиций и целевой индекс, ведёт tween по сегментам,
## поворачивает кису по направлению и ускоряет остаток пути по тапу. Экран
## «Азбука» отвечает только за то, что делать после финиша.

const RUN_SPEED := 420.0
const MAX_RUN_TIME := 3.2
const MIN_SEGMENT_TIME := 0.03
const SKIP_SPEED_SCALE := 1.8
const KISA_ANCHOR := Vector2.ZERO

var is_animating := false

var _run_tween: Tween
var _bounce_tween: Tween
var _skip_requested := false


func run(
	kisa: KisaCat,
	positions: Array[Vector2],
	target_idx: int,
	target_letter: String,
	level: int,
	on_finish: Callable
) -> void:
	if positions.size() <= 1:
		on_finish.call(target_idx)
		return

	is_animating = true
	_skip_requested = false
	kisa.set_kisa_moving(true)

	var segment_times: Array[float] = []
	var total_time := 0.0
	for i in range(1, positions.size()):
		var dist: float = positions[i - 1].distance_to(positions[i])
		var seg_time: float = maxf(MIN_SEGMENT_TIME, dist / RUN_SPEED)
		segment_times.append(seg_time)
		total_time += seg_time

	var time_scale := 1.0
	if total_time > MAX_RUN_TIME:
		time_scale = MAX_RUN_TIME / total_time

	_run_tween = create_tween()
	for i in range(1, positions.size()):
		var seg_dx: float = positions[i].x - positions[i - 1].x
		if not is_equal_approx(seg_dx, 0.0):
			_run_tween.tween_callback(kisa.set_facing.bind(seg_dx > 0.0))
			GameLogger.info("AzbukaGame", "kisa_turn",
				{"to": target_letter, "level": level + 1,
				"seg_dx": seg_dx, "facing_right": seg_dx > 0.0})
		var move_tween := _run_tween.tween_property(
			kisa, "position", positions[i] - KISA_ANCHOR, segment_times[i - 1] * time_scale
		)
		if i == 1:
			move_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		if i == positions.size() - 1:
			move_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _run_tween.finished
	_run_tween = null

	var final_pos: Vector2 = positions[positions.size() - 1] - KISA_ANCHOR
	var bounce_up: float = 0.03 if _skip_requested else 0.08
	var bounce_down: float = 0.04 if _skip_requested else 0.12
	_bounce_tween = create_tween()
	_bounce_tween.tween_property(kisa, "position:y", final_pos.y - 10.0, bounce_up).set_ease(Tween.EASE_OUT)
	_bounce_tween.tween_property(kisa, "position:y", final_pos.y, bounce_down).set_ease(Tween.EASE_IN)
	await _bounce_tween.finished
	_bounce_tween = null

	is_animating = false
	_skip_requested = false
	kisa.set_kisa_moving(false)
	on_finish.call(target_idx)


## Ускоряет оставшийся бег по тапу: ребёнок не ждёт, но киса не телепортируется.
func request_skip() -> void:
	if not is_animating or _skip_requested:
		return
	_skip_requested = true
	if _run_tween != null and _run_tween.is_valid() and _run_tween.is_running():
		_run_tween.set_speed_scale(SKIP_SPEED_SCALE)
	if _bounce_tween != null and _bounce_tween.is_valid() and _bounce_tween.is_running():
		_bounce_tween.set_speed_scale(SKIP_SPEED_SCALE)


func stop() -> void:
	if _run_tween != null and _run_tween.is_valid():
		_run_tween.kill()
	if _bounce_tween != null and _bounce_tween.is_valid():
		_bounce_tween.kill()
	_run_tween = null
	_bounce_tween = null
	is_animating = false
	_skip_requested = false
