extends Node

# Верификация интеграции KisaCat: проверяет, что спрайт-анимации
# переключаются через публичный API (set_kisa_moving / set_facing).

func _ready() -> void:
	var kisa := KisaCat.new()
	add_child(kisa)
	await get_tree().process_frame

	var sprite := kisa.get_node_or_null("KisaSprite") as AnimatedSprite2D
	assert(sprite != null, "KisaSprite не создан")
	assert(sprite.sprite_frames != null, "sprite_frames не заданы")

	var failures := 0
	# idle по умолчанию
	if sprite.animation != "idle":
		failures += 1
		push_error("Ожидался idle, получен " + sprite.animation)

	# walk_right при движении вправо
	kisa.set_kisa_moving(true)
	kisa.set_facing(true)
	await get_tree().process_frame
	if sprite.animation != "walk_right":
		failures += 1
		push_error("Ожидался walk_right, получен " + sprite.animation)

	# walk_left при движении влево
	kisa.set_facing(false)
	await get_tree().process_frame
	if sprite.animation != "walk_left":
		failures += 1
		push_error("Ожидался walk_left, получен " + sprite.animation)

	# idle при остановке
	kisa.set_kisa_moving(false)
	await get_tree().process_frame
	if sprite.animation != "idle":
		failures += 1
		push_error("Ожидался idle после остановки, получен " + sprite.animation)

	# Смена направления без движения не меняет анимацию (остаётся idle)
	kisa.set_facing(false)
	await get_tree().process_frame
	if sprite.animation != "idle":
		failures += 1
		push_error("Idle не должен меняться при set_facing")

	# Кадры анимаций непустые
	for anim_name in ["idle", "walk_right", "walk_left"]:
		var count := sprite.sprite_frames.get_frame_count(anim_name)
		if count == 0:
			failures += 1
			push_error("Анимация %s без кадров" % anim_name)

	print("KisaCatIntegrationCheck: failures=", failures)
	if failures == 0:
		print("KisaCatIntegrationCheck: PASS")
	else:
		print("KisaCatIntegrationCheck: FAIL")
	get_tree().quit(failures)