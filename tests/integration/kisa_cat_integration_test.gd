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

	# walk при движении вправо: кадры walk, flip_h=true (поворот по змейке)
	kisa.set_kisa_moving(true)
	kisa.set_facing(true)
	await get_tree().process_frame
	if sprite.animation != "walk":
		failures += 1
		push_error("Ожидался walk, получен " + sprite.animation)
	if not sprite.flip_h:
		failures += 1
		push_error("Ожидался flip_h=true при беге вправо")

	# walk при движении влево: те же кадры walk, flip_h=false
	kisa.set_facing(false)
	await get_tree().process_frame
	if sprite.animation != "walk":
		failures += 1
		push_error("Ожидался walk, получен " + sprite.animation)
	if sprite.flip_h:
		failures += 1
		push_error("Ожидался flip_h=false при беге влево")

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
	for anim_name in ["idle", "walk"]:
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