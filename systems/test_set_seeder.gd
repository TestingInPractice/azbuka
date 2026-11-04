extends Node
## Одноразовый сидер тестового пользовательского набора для веб-сборки.
##
## Зачем: показать конструктор в проде на реальном наборе, а не на пустом
## списке. Набор создаётся как ОБЫЧНЫЙ пользовательский (CustomSetsStore),
## а не как встроенный, и не выбирается активным: родитель сам решает,
## играть ли им.
##
## Почему только web: настольная сборка уже имеет локальный набор, и повторный
## сид при каждом запуске мешал бы ручной проверке. Для QA на настольной
## сборке есть явный флаг AZBUKA_SEED_TEST_SET=1.
##
## Почему флаг, а не проверка имени: если родитель удалит набор, он не должен
## воскресать на следующем запуске. Флаг пишется один раз после успеха.

const Filler := preload("res://tools/test_set_filler.gd")
const SET_NAME := "Тестовый набор"
const SEEDED_FLAG := "user://test_set_seeded_v1.flag"
const FORCE_ENV := "AZBUKA_SEED_TEST_SET"


func _ready() -> void:
	if not _should_seed():
		return
	# Сид не должен задерживать первый кадр: 33 картинки декодируются и
	# перекодируются в WebP. Откладываем на следующий цикл, чтобы главное
	# меню успело появиться.
	call_deferred("_seed_if_needed")


func _should_seed() -> bool:
	if OS.get_environment(FORCE_ENV) == "1":
		return true
	return OS.has_feature("web")


func _seed_if_needed() -> void:
	if FileAccess.file_exists(SEEDED_FLAG):
		return
	if _find_existing().size() > 0:
		_mark_seeded()
		return
	var started := Time.get_ticks_msec()
	var result: Dictionary = Filler.new().fill({"name": SET_NAME})
	var elapsed := Time.get_ticks_msec() - started
	if bool(result.get("ok", false)):
		_mark_seeded()
		GameLogger.info("TestSetSeeder", "seeded", {
			"set_id": str(result.get("set_id", "")),
			"letters": (result.get("complete", []) as Array).size(),
			"ms": elapsed,
		})
		return
	GameLogger.error("TestSetSeeder", "seed_failed", {
		"failed": (result.get("failed", []) as Array).size(),
		"error": str(result.get("error", "")),
		"ms": elapsed,
	})
	push_warning("TestSetSeeder: набор не создан, повтор при следующем запуске")


func _find_existing() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for record: Dictionary in CustomSetsStore.get_sets():
		if str(record.get("name", "")) == SET_NAME:
			found.append(record)
	return found


func _mark_seeded() -> void:
	var file := FileAccess.open(SEEDED_FLAG, FileAccess.WRITE)
	if file != null:
		file.store_string("1")
		file.close()
