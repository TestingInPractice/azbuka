extends Node
## Валидатор UI-структуры: инстанцирует изменённые сцены после
## регистрации автолоадов и проверяет структуру (кнопки «Назад», донат,
## отзыв, цвета игровых кнопок). Запуск: godot --headless --path . res://tests/validate_ui_changes.tscn

var failures := 0


func _ready() -> void:
	await get_tree().process_frame
	_check_project_settings()
	_check_main_menu()
	_check_settings()
	_check_feedback()
	_check_donate()
	if failures > 0:
		printerr("FAILED: %d проверок" % failures)
		get_tree().quit(1)
	else:
		print("[ui_validate] PASSED: все проверки успешны")
		get_tree().quit(0)


func _check_project_settings() -> void:
	var vw: int = ProjectSettings.get_setting("display/window/size/viewport_width")
	var vh: int = ProjectSettings.get_setting("display/window/size/viewport_height")
	if vw != 1080 or vh != 2340:
		_fail("project: viewport должен быть 1080x2340 (19.5:9), сейчас %dx%d" % [vw, vh])
	if ProjectSettings.get_setting("display/window/stretch/aspect") != "keep":
		_fail("project: stretch/aspect должен быть keep")


func _check_main_menu() -> void:
	var scene: PackedScene = load("res://ui/main_menu/main_menu.tscn")
	var menu: Node = scene.instantiate()
	add_child(menu)
	await get_tree().process_frame
	if menu.get_node_or_null("%ProgressLabel") != null:
		_fail("main_menu: ProgressLabel не должен существовать")
	if menu.get_node_or_null("%SnakePreview") != null:
		_fail("main_menu: SnakePreview не должен существовать")
	if menu.get_node_or_null("%DonateButton") != null:
		_fail("main_menu: DonateButton не должен существовать")
	if menu.get_node_or_null("%FeedbackButton") != null:
		_fail("main_menu: FeedbackButton не должен существовать")
	var settings_btn := menu.get_node_or_null("%SettingsButton") as Button
	if settings_btn == null:
		_fail("main_menu: SettingsButton отсутствует")
	else:
		var layout := menu.get_node_or_null("%MainLayout")
		if layout != null and settings_btn.get_parent() == layout:
			_fail("main_menu: SettingsButton должен быть в корне, а не внутри MainLayout")
		if settings_btn.icon == null:
			_fail("main_menu: SettingsButton должен иметь иконку (шестерёнку)")
	var colors: Dictionary = menu.GAME_BUTTON_COLORS
	if colors.size() != 4:
		_fail("main_menu: GAME_BUTTON_COLORS должен содержать 4 цвета, найдено %d" % colors.size())
	else:
		var unique := {}
		for c: Color in colors.values():
			unique[c.to_html()] = true
		if unique.size() != 4:
			_fail("main_menu: цвета кнопок игр не уникальны")
	menu.queue_free()
	await get_tree().process_frame
	_print("main_menu: OK")


func _check_settings() -> void:
	var scene: PackedScene = load("res://ui/settings/settings.tscn")
	var settings: Node = scene.instantiate()
	add_child(settings)
	await get_tree().process_frame
	var layout: VBoxContainer = settings.get_node("%MainLayout")
	if layout == null:
		_fail("settings: MainLayout отсутствует")
	elif layout.alignment != 0:
		_fail("settings: alignment должен быть 0 (заголовок вверху), сейчас %d" % layout.alignment)
	if settings.get_node_or_null("%BackButton") == null:
		_fail("settings: BackButton (компонент) отсутствует")
	elif settings.get_node("%BackButton").get_parent() != settings:
		_fail("settings: BackButton должен быть в корне сцены")
	if settings.get_node_or_null("%DonateButton") == null:
		_fail("settings: DonateButton отсутствует")
	if settings.get_node_or_null("%FeedbackButton") == null:
		_fail("settings: FeedbackButton отсутствует")
	settings.queue_free()
	await get_tree().process_frame
	_print("settings: OK")


func _check_feedback() -> void:
	var scene: PackedScene = load("res://ui/feedback/feedback.tscn")
	var feedback: Node = scene.instantiate()
	add_child(feedback)
	await get_tree().process_frame
	var back := feedback.get_node_or_null("%BackButton")
	if back == null:
		_fail("feedback: BackButton (компонент) отсутствует")
	elif back.get_parent() != feedback:
		_fail("feedback: BackButton должен быть в корне сцены")
	feedback.queue_free()
	await get_tree().process_frame
	_print("feedback: OK")


func _check_donate() -> void:
	var scene: PackedScene = load("res://ui/donate/donate_overlay.tscn")
	var donate: Node = scene.instantiate()
	add_child(donate)
	await get_tree().process_frame
	if not donate is DonateOverlay:
		_fail("donate: сцена не привязана к классу DonateOverlay")
	if DonateOverlay.return_scene.is_empty():
		_fail("donate: return_scene не задан")
	donate.queue_free()
	await get_tree().process_frame
	_print("donate: OK")


func _fail(msg: String) -> void:
	failures += 1
	printerr("FAIL: " + msg)


func _print(msg: String) -> void:
	print("[ui_validate] " + msg)
