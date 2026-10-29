extends Node
## Валидатор подписи активного набора: имя своего набора на экране «Азбука» и
## на карточке буквы, скрытие для встроенного и удалённого набора, обновление
## после переименования, отсутствие утечки узлов при повторном открытии сцен и
## читаемость после переключения темы.
## Пути хранилища и прогресса уводятся на тестовые файлы: данные ребёнка не
## читаются и не меняются.
## Запуск: godot --headless --path . res://tests/validate_active_set_label.tscn

const TEST_STORE_PATH := "user://custom_sets_active_label_test.json"
const TEST_PROGRESS_PATH := "user://progress_active_label_test.json"
const AZBUKA_SCENE := "res://ui/games/azbuka/azbuka.tscn"
const LETTER_CARD_SCENE := "res://ui/games/azbuka/letter_card.tscn"
const SET_NAME := "Тестовый набор"
const RENAMED_NAME := "Новый тестовый набор"
const LONG_NAME := "Очень длинное имя набора для проверки переноса строки"
const EXPECTED_TEXT := "Набор: Тестовый набор"

var checks := 0
var failures := 0
var _saved_store_path := ""
var _saved_progress_path := ""
var _saved_word_set_id := ""


func _ready() -> void:
	await get_tree().process_frame

	_saved_store_path = CustomSetsStore.save_path
	_saved_progress_path = ProgressManager.save_path
	_saved_word_set_id = ProgressManager.get_word_set_id()
	CustomSetsStore.save_path = TEST_STORE_PATH
	ProgressManager.save_path = TEST_PROGRESS_PATH
	_remove_file(TEST_STORE_PATH)
	_remove_file(TEST_PROGRESS_PATH)
	CustomSetsStore.clear_memory()
	CustomSetsStore.load_sets()

	await _check_builtin_sets()

	var created := CustomSetsStore.create_set(SET_NAME)
	var set_id := str(created.get("id", ""))
	_check(not set_id.is_empty(), "тестовый набор создан")
	ProgressManager.set_word_set_id(set_id)
	await _check_custom_set()

	await _check_rename(set_id)
	await _check_deleted_set(set_id)
	await _check_reentry_without_leak()
	await _check_theme_toggle()
	await _check_long_name_layout()

	ProgressManager.set_word_set_id(_saved_word_set_id)
	CustomSetsStore.clear_memory()
	CustomSetsStore.save_path = _saved_store_path
	ProgressManager.save_path = _saved_progress_path
	_remove_file(TEST_STORE_PATH)
	_remove_file(TEST_PROGRESS_PATH)
	_remove_empty_sets_dir()
	_finish()


## Встроенные наборы 1..5 номера, но не имени: подпись обязана молчать.
func _check_builtin_sets() -> void:
	for number in range(1, ProgressManager.WORD_SET_COUNT + 1):
		# given: активен встроенный набор номером
		ProgressManager.set_word_set_id(str(number))
		# when: спрашиваем имя активного набора
		var name := SetRepository.get_active_set_name()
		# then: имени нет ни у одного встроенного набора
		_check(name.is_empty(), "встроенный набор %d не имеет имени" % number)

	# given: активен встроенный набор 1
	ProgressManager.set_word_set_id("1")

	# when: открыт экран «Азбука»
	var azbuka := await _spawn(AZBUKA_SCENE)
	var azbuka_label: Label = azbuka.get_node_or_null("%SetLabel") as Label
	# then: узел подписи есть, но скрыт и пуст
	_check(azbuka_label != null, "на экране «Азбука» есть узел SetLabel")
	if azbuka_label != null:
		_check(not azbuka_label.visible, "подпись «Азбука» скрыта для встроенного набора")
		_check(azbuka_label.text.is_empty(), "текст подписи «Азбука» пуст для встроенного набора")
	await _free(azbuka)

	# when: открыта карточка буквы на встроенном наборе
	LetterCard.from_letter = "А"
	var card := await _spawn(LETTER_CARD_SCENE)
	var card_label: Label = card.get_node_or_null("%SetLabel") as Label
	# then: подпись тоже скрыта и пуста
	_check(card_label != null, "на карточке буквы есть узел SetLabel")
	if card_label != null:
		_check(not card_label.visible, "подпись карточки скрыта для встроенного набора")
		_check(card_label.text.is_empty(), "текст подписи карточки пуст для встроенного набора")
	await _free(card)


## Свой набор имеет имя, и обе сцены показывают его дословно.
func _check_custom_set() -> void:
	# given: активен пользовательский набор «Тестовый набор»
	# when: спрашиваем имя активного набора
	var name := SetRepository.get_active_set_name()
	# then: репозиторий отдаёт имя набора, а не его id
	_check(name == SET_NAME, "пользовательский набор отдаёт своё имя")

	# when: открыт экран «Азбука»
	var azbuka := await _spawn(AZBUKA_SCENE)
	var azbuka_label: Label = azbuka.get_node_or_null("%SetLabel") as Label
	# then: подпись видна и содержит точный текст
	_check(azbuka_label != null and azbuka_label.visible,
			"подпись «Азбука» видна для пользовательского набора")
	if azbuka_label != null:
		_check(azbuka_label.text == EXPECTED_TEXT,
				"текст подписи «Азбука»: ожидали «%s», получили «%s»"
				% [EXPECTED_TEXT, azbuka_label.text])
	await _free(azbuka)

	# when: открыта карточка буквы
	LetterCard.from_letter = "А"
	var card := await _spawn(LETTER_CARD_SCENE)
	var card_label: Label = card.get_node_or_null("%SetLabel") as Label
	# then: подпись видна и содержит тот же текст
	_check(card_label != null and card_label.visible,
			"подпись карточки видна для пользовательского набора")
	if card_label != null:
		_check(card_label.text == EXPECTED_TEXT,
				"текст подписи карточки: ожидали «%s», получили «%s»"
				% [EXPECTED_TEXT, card_label.text])
	await _free(card)


## Переименование меняет подпись: имя читается заново, а не кэшируется.
func _check_rename(set_id: String) -> void:
	# given: пользовательский набор с прежним именем
	# when: набор переименован
	var renamed := CustomSetsStore.rename_set(set_id, RENAMED_NAME)
	# then: хранилище и репозиторий видят новое имя
	_check(renamed, "набор переименован")
	_check(SetRepository.get_active_set_name() == RENAMED_NAME,
			"репозиторий отдаёт новое имя набора")

	# when: экран «Азбука» открыт заново после переименования
	var azbuka := await _spawn(AZBUKA_SCENE)
	var azbuka_label: Label = azbuka.get_node_or_null("%SetLabel") as Label
	# then: подпись содержит новое имя
	_check(azbuka_label != null and azbuka_label.text == ("Набор: " + RENAMED_NAME),
			"подпись «Азбука» обновилась после переименования")
	await _free(azbuka)

	# when: карточка буквы открыта заново после переименования
	LetterCard.from_letter = "А"
	var card := await _spawn(LETTER_CARD_SCENE)
	var card_label: Label = card.get_node_or_null("%SetLabel") as Label
	# then: подпись карточки тоже содержит новое имя
	_check(card_label != null and card_label.text == ("Набор: " + RENAMED_NAME),
			"подпись карточки обновилась после переименования")
	await _free(card)


## Удалённый набор перестаёт быть активным по имени, хотя id остался в прогрессе.
func _check_deleted_set(set_id: String) -> void:
	# given: активный пользовательский набор
	# when: набор удалён, а id в прогрессе остался
	var deleted := CustomSetsStore.delete_set(set_id)
	# then: репозиторий уже не находит имя
	_check(deleted, "тестовый набор удалён")
	_check(SetRepository.get_active_set_name().is_empty(),
			"удалённый набор не отдаёт имя")

	# when: открыт экран «Азбука» с удалённым набором
	var azbuka := await _spawn(AZBUKA_SCENE)
	var azbuka_label: Label = azbuka.get_node_or_null("%SetLabel") as Label
	# then: подпись скрыта и пуста, как у встроенного набора
	_check(azbuka_label != null and not azbuka_label.visible,
			"подпись «Азбука» скрыта для удалённого набора")
	if azbuka_label != null:
		_check(azbuka_label.text.is_empty(), "текст подписи «Азбука» пуст для удалённого набора")
	await _free(azbuka)

	# when: открыта карточка буквы с удалённым набором
	LetterCard.from_letter = "А"
	var card := await _spawn(LETTER_CARD_SCENE)
	var card_label: Label = card.get_node_or_null("%SetLabel") as Label
	# then: подпись карточки тоже скрыта и пуста
	_check(card_label != null and not card_label.visible,
			"подпись карточки скрыта для удалённого набора")
	if card_label != null:
		_check(card_label.text.is_empty(), "текст подписи карточки пуст для удалённого набора")
	await _free(card)


## Две сцены подряд не должны оставлять лишних подписей в дереве.
func _check_reentry_without_leak() -> void:
	# given: активен встроенный набор
	ProgressManager.set_word_set_id("1")

	# when: экран «Азбука» открыт дважды подряд
	var first := await _spawn(AZBUKA_SCENE)
	var second := await _spawn(AZBUKA_SCENE)
	# then: у каждого экземпляра ровно одна подпись
	_check(first.find_children("SetLabel", "Label", true, false).size() == 1,
			"первый экземпляр «Азбуки» содержит одну подпись")
	_check(second.find_children("SetLabel", "Label", true, false).size() == 1,
			"второй экземпляр «Азбуки» содержит одну подпись")
	await _free(first)
	await _free(second)
	# then: после закрытия подписей не осталось
	_check(find_children("SetLabel", "Label", true, false).is_empty(),
			"после закрытия «Азбуки» подписи не остались в дереве")

	# when: карточка буквы открыта дважды подряд
	LetterCard.from_letter = "А"
	var card_one := await _spawn(LETTER_CARD_SCENE)
	var card_two := await _spawn(LETTER_CARD_SCENE)
	# then: у каждого экземпляра ровно одна подпись
	_check(card_one.find_children("SetLabel", "Label", true, false).size() == 1,
			"первый экземпляр карточки содержит одну подпись")
	_check(card_two.find_children("SetLabel", "Label", true, false).size() == 1,
			"второй экземпляр карточки содержит одну подпись")
	await _free(card_one)
	await _free(card_two)
	# then: после закрытия подписей не осталось
	_check(find_children("SetLabel", "Label", true, false).is_empty(),
			"после закрытия карточек подписи не остались в дереве")


## Переключение темы не прячет подпись и перекрашивает её вместе с заголовком.
func _check_theme_toggle() -> void:
	# given: активен пользовательский набор и включена тёмная тема
	var created := CustomSetsStore.create_set(SET_NAME)
	var set_id := str(created.get("id", ""))
	_check(not set_id.is_empty(), "набор для проверки темы создан")
	ProgressManager.set_word_set_id(set_id)
	ThemeManager.set_theme(ThemeManager.ThemeMode.DARK)

	# when: экран «Азбука» открыт в тёмной теме
	var azbuka := await _spawn(AZBUKA_SCENE)
	var label: Label = azbuka.get_node_or_null("%SetLabel") as Label
	# then: подпись видна и использует цвет текста темы
	_check(label != null and label.visible, "подпись видна в тёмной теме")
	if label != null:
		_check(label.get_theme_color("font_color") == ThemeManager.get_text(),
				"цвет подписи совпадает с цветом текста тёмной темы")

	# when: тема переключена на светлую при открытом экране
	ThemeManager.set_theme(ThemeManager.ThemeMode.LIGHT)
	await get_tree().process_frame
	# then: подпись осталась видимой
	_check(label != null and label.visible, "подпись пережила переключение темы")
	await _free(azbuka)

	ThemeManager.set_theme(ThemeManager.ThemeMode.LIGHT)
	CustomSetsStore.delete_set(set_id)


## Длинное имя на узком портретном экране переносится, а змейка остаётся целой.
func _check_long_name_layout() -> void:
	# given: активен набор с длинным именем
	var created := CustomSetsStore.create_set(LONG_NAME)
	var set_id := str(created.get("id", ""))
	_check(not set_id.is_empty(), "набор с длинным именем создан")
	ProgressManager.set_word_set_id(set_id)

	# when: экран «Азбука» открыт в портретном проекте
	var azbuka := await _spawn(AZBUKA_SCENE)
	var label: Label = azbuka.get_node_or_null("%SetLabel") as Label
	var snake: Control = azbuka.get_node_or_null("%SnakeArea") as Control
	# then: подпись переносится по словам, а змейка построена и имеет высоту
	_check(label != null and label.autowrap_mode != TextServer.AUTOWRAP_OFF,
			"подпись с длинным именем переносится по словам")
	_check(azbuka.dot_buttons.size() == 33, "змейка построила все 33 кружка")
	_check(snake != null and snake.size.y > 0.0,
			"у области змейки осталась положительная высота")
	await _free(azbuka)

	# when: карточка буквы открыта с тем же длинным именем
	LetterCard.from_letter = "А"
	var card := await _spawn(LETTER_CARD_SCENE)
	var card_label: Label = card.get_node_or_null("%SetLabel") as Label
	# then: подпись карточки видна, содержит полное имя и переносится
	_check(card_label != null and card_label.visible,
			"подпись карточки видна для длинного имени")
	_check(card_label != null and card_label.text == ("Набор: " + LONG_NAME),
			"подпись карточки содержит полное длинное имя")
	_check(card_label != null and card_label.autowrap_mode != TextServer.AUTOWRAP_OFF,
			"подпись карточки с длинным именем переносится")
	await _free(card)

	CustomSetsStore.delete_set(set_id)


## Загружает сцену, ждёт два кадра и возвращает корень.
func _spawn(scene_path: String) -> Node:
	var scene: PackedScene = load(scene_path)
	var instance: Node = scene.instantiate()
	add_child(instance)
	await get_tree().process_frame
	await get_tree().process_frame
	return instance


## Освобождает сцену и даёт дереву два кадра на фактическое удаление.
func _free(node: Node) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame


func _remove_file(path: String) -> void:
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(abs_path):
		DirAccess.remove_absolute(abs_path)


## Удаляет пустой общий каталог наборов, не трогая чужие данные.
func _remove_empty_sets_dir() -> void:
	var abs_path := ProjectSettings.globalize_path(CustomSetsStore.SETS_DIR)
	var dir := DirAccess.open(abs_path)
	if dir == null:
		return
	if dir.get_files().is_empty() and dir.get_directories().is_empty():
		DirAccess.remove_absolute(abs_path)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("[active_set_label_validate] OK: " + message)
	else:
		failures += 1
		printerr("[active_set_label_validate] FAIL: " + message)


func _finish() -> void:
	if failures > 0:
		printerr("[active_set_label_validate] FAILED: %d из %d проверок" % [failures, checks])
		get_tree().quit(1)
	else:
		print("[active_set_label_validate] PASSED: %d проверок" % checks)
		get_tree().quit(0)
