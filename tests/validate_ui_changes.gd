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
	await _check_parental_gate()
	_check_feedback()
	_check_donate()
	await _check_level_arrows()
	await _check_kisa_run()
	await _check_image_screen_overlay()
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
	# expand — канвас масштабируется на весь экран без letterbox-полос
	# (решение 79acec0; keep оставлял серые полосы по бокам на 19.5:9).
	if ProjectSettings.get_setting("display/window/stretch/aspect") != "expand":
		_fail("project: stretch/aspect должен быть expand (без полос), сейчас %s"
				% ProjectSettings.get_setting("display/window/stretch/aspect"))


func _check_main_menu() -> void:
	var scene: PackedScene = load("res://ui/main_menu/main_menu.tscn")
	var menu: Node = scene.instantiate()
	add_child(menu)
	await get_tree().process_frame
	ThemeManager.set_theme(ThemeManager.ThemeMode.LIGHT)
	await get_tree().process_frame
	var background := menu.get_node_or_null("%Background") as TextureRect
	if background == null:
		_fail("main_menu: Background должен быть TextureRect")
	elif background.texture == null:
		_fail("main_menu: Background должен иметь текстуру")
	elif background.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_COVERED:
		_fail("main_menu: Background должен заполнять экран без полос")
	var menu_overlay := menu.get_node_or_null("%BackgroundOverlay") as ColorRect
	_check_overlay(menu_overlay, "main_menu")
	if menu.get_node_or_null("%ProgressLabel") != null:
		_fail("main_menu: ProgressLabel не должен существовать")
	if menu.get_node_or_null("%SnakePreview") != null:
		_fail("main_menu: SnakePreview не должен существовать")
	if menu.get_node_or_null("%DonateButton") != null:
		_fail("main_menu: DonateButton не должен существовать")
	if menu.get_node_or_null("%FeedbackButton") != null:
		_fail("main_menu: FeedbackButton не должен существовать")
	var layout := menu.get_node_or_null("%MainLayout") as VBoxContainer
	if layout == null:
		_fail("main_menu: MainLayout отсутствует")
	elif layout.custom_minimum_size.x > 900.5 or layout.size.x > 900.5:
		_fail("main_menu: MainLayout шире 900 px, сейчас %.1f" % layout.size.x)
	var settings_btn := menu.get_node_or_null("%SettingsButton") as Button
	if settings_btn == null:
		_fail("main_menu: SettingsButton отсутствует")
	else:
		if layout != null and settings_btn.get_parent() == layout:
			_fail("main_menu: SettingsButton должен быть в корне, а не внутри MainLayout")
		if settings_btn.icon == null:
			_fail("main_menu: SettingsButton должен иметь иконку (шестерёнку)")
		elif settings_btn.icon.get_width() < 190 or settings_btn.icon.get_height() < 190:
			_fail("main_menu: иконка настроек должна быть минимум 190x190, сейчас %dx%d"
					% [settings_btn.icon.get_width(), settings_btn.icon.get_height()])
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
	ThemeManager.set_theme(ThemeManager.ThemeMode.LIGHT)
	var scene: PackedScene = load("res://ui/settings/settings.tscn")
	var settings: Node = scene.instantiate()
	add_child(settings)
	await get_tree().process_frame
	var tabs := settings.get_node_or_null("%SettingsTabs") as TabContainer
	if tabs == null:
		_fail("settings: SettingsTabs отсутствует")
	else:
		if tabs.get_tab_count() != 3:
			_fail("settings: ожидалось 3 вкладки, сейчас %d" % tabs.get_tab_count())
		else:
			var expected_titles := ["Игры", "Контент", "Приложение"]
			for index in range(expected_titles.size()):
				if tabs.get_tab_title(index) != expected_titles[index]:
					_fail("settings: вкладка %d должна называться %s, сейчас %s"
							% [index, expected_titles[index], tabs.get_tab_title(index)])
		if tabs.current_tab != 0:
			_fail("settings: по умолчанию должна открываться первая вкладка, сейчас %d" % tabs.current_tab)
		if tabs.get_theme_font_size("font_size") != 36:
			_fail("settings: размер шрифта вкладок должен быть 36, сейчас %d"
					% tabs.get_theme_font_size("font_size"))
		if tabs.get_theme_color("font_selected_color").get_luminance() >= 0.5:
			_fail("settings: текст выбранной вкладки должен быть тёмным на бирюзовом, сейчас %s"
					% tabs.get_theme_color("font_selected_color").to_html())
		if tabs.get_theme_color("font_unselected_color").get_luminance() >= 0.5:
			_fail("settings: текст невыбранной вкладки должен быть тёмным на светлом, сейчас %s"
					% tabs.get_theme_color("font_unselected_color").to_html())
	var back := settings.get_node_or_null("%BackButton") as Button
	if back == null:
		_fail("settings: BackButton (компонент) отсутствует")
	elif back.get_parent() != settings:
		_fail("settings: BackButton должен быть в корне сцены")
	var title := settings.get_node_or_null("%TitleLabel") as Label
	if title == null:
		_fail("settings: TitleLabel отсутствует")
	elif back != null and title.get_global_rect().intersects(back.get_global_rect()):
		_fail("settings: заголовок пересекается с кнопкой Назад")
	if settings.get_node_or_null("%DonateButton") == null:
		_fail("settings: DonateButton отсутствует")
	if settings.get_node_or_null("%FeedbackButton") == null:
		_fail("settings: FeedbackButton отсутствует")
	settings.queue_free()
	await get_tree().process_frame
	_print("settings: OK")


func _check_parental_gate() -> void:
	ThemeManager.set_theme(ThemeManager.ThemeMode.LIGHT)
	var scene: PackedScene = load("res://ui/parental_gate/parental_gate.tscn")
	var gate: Node = scene.instantiate()
	add_child(gate)
	await get_tree().process_frame
	var title := gate.get_node_or_null("%TitleLabel") as Label
	var question := gate.get_node_or_null("%QuestionLabel") as Label
	if title == null:
		_fail("parental_gate: TitleLabel отсутствует")
	elif title.get_theme_color("font_color").get_luminance() < 0.5:
		_fail("parental_gate: заголовок должен быть светлым на затемнении, сейчас %s"
				% title.get_theme_color("font_color").to_html())
	if question == null:
		_fail("parental_gate: QuestionLabel отсутствует")
	elif question.get_theme_color("font_color").get_luminance() < 0.5:
		_fail("parental_gate: вопрос должен быть светлым на затемнении, сейчас %s"
				% question.get_theme_color("font_color").to_html())
	gate.queue_free()
	await get_tree().process_frame
	_print("parental_gate: OK")


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


func _check_level_arrows() -> void:
	var scene: PackedScene = load("res://ui/games/azbuka/azbuka.tscn")
	var game := scene.instantiate() as AzbukaGame
	add_child(game)
	await _wait_for_snake(game)
	var prev := game.get_node_or_null("%PrevLevelButton") as Button
	var next := game.get_node_or_null("%NextLevelButton") as Button
	if prev == null or next == null:
		_fail("azbuka: нижние стрелки уровней отсутствуют")
		game.queue_free()
		await get_tree().process_frame
		return
	if prev.size.x < 120.0 or prev.size.y < 120.0:
		_fail("azbuka: левая стрелка должна быть крупной, сейчас %.0fx%.0f"
				% [prev.size.x, prev.size.y])
	if next.size.x < 120.0 or next.size.y < 120.0:
		_fail("azbuka: правая стрелка должна быть крупной, сейчас %.0fx%.0f"
				% [next.size.x, next.size.y])
	var area_rect := game._snake_area.get_global_rect().grow(1.0)
	if not area_rect.encloses(prev.get_global_rect()):
		_fail("azbuka: левая стрелка должна быть внутри области змейки")
	if not area_rect.encloses(next.get_global_rect()):
		_fail("azbuka: правая стрелка должна быть внутри области змейки")
	var first_dot := game.dot_buttons[0]
	var last_dot := game.dot_buttons[game.dot_buttons.size() - 1]
	if prev.get_global_rect().intersects(first_dot.get_global_rect()):
		_fail("azbuka: левая стрелка не должна перекрывать первый кружок")
	if next.get_global_rect().intersects(last_dot.get_global_rect()):
		_fail("azbuka: правая стрелка не должна перекрывать последний кружок")
	var prev_center := prev.get_global_rect().get_center() - game._snake_area.global_position
	if prev_center.distance_to(game._snake.prev_arrow_position) > 0.5:
		_fail("azbuka: левая стрелка должна стоять над первым кружком")
	var next_center := next.get_global_rect().get_center() - game._snake_area.global_position
	if next_center.distance_to(game._snake.next_arrow_position) > 0.5:
		_fail("azbuka: правая стрелка должна стоять на месте следующего кружка")
	if prev.get_global_rect().end.y > first_dot.get_global_rect().position.y + 1.0:
		_fail("azbuka: левая стрелка должна быть над первым кружком, а не сбоку")
	if game._snake_path.points.size() != game.dot_positions.size() + 1:
		_fail("azbuka: линия змейки должна вести к правой стрелке")
	elif not game._snake_path.points[game._snake_path.points.size() - 1].is_equal_approx(game._snake.next_arrow_position):
		_fail("azbuka: линия змейки должна заканчиваться на месте следующего кружка")
	if not prev.disabled:
		_fail("azbuka: на первом уровне левая стрелка должна быть неактивна")
	if next.disabled:
		_fail("azbuka: на первом уровне правая стрелка должна быть активна")
	if next.modulate.a < 0.9:
		_fail("azbuka: активная стрелка не должна быть приглушена")
	next.pressed.emit()
	await _wait_for_snake(game)
	if game._level != 1:
		_fail("azbuka: правая стрелка не переключила на второй уровень")
	if prev.disabled:
		_fail("azbuka: на втором уровне левая стрелка должна быть активна")
	if next.disabled:
		_fail("azbuka: на втором уровне правая стрелка должна быть активна")
	next.pressed.emit()
	await _wait_for_snake(game)
	if game._level != 2:
		_fail("azbuka: правая стрелка не переключила на третий уровень")
	if not next.disabled:
		_fail("azbuka: на третьем уровне правая стрелка должна быть неактивна")
	if prev.disabled:
		_fail("azbuka: на третьем уровне левая стрелка должна быть активна")
	prev.pressed.emit()
	await _wait_for_snake(game)
	if game._level != 1:
		_fail("azbuka: левая стрелка не вернула на второй уровень")
	game.queue_free()
	await get_tree().process_frame
	_print("azbuka: level arrows OK")


func _wait_for_snake(game: AzbukaGame) -> void:
	for i in 30:
		await get_tree().process_frame
		if not game._building:
			return


func _check_kisa_run() -> void:
	if AzbukaKisaRunner.MAX_RUN_TIME < 3.0:
		_fail("azbuka: длинный пробег кисы должен занимать не меньше 3 секунд")
	if AzbukaKisaRunner.SKIP_SPEED_SCALE > 2.0:
		_fail("azbuka: ускорение по тапу не должно превышать 2x")
	var scene: PackedScene = load("res://ui/games/azbuka/azbuka.tscn")
	var game := scene.instantiate() as AzbukaGame
	add_child(game)
	for i in 20:
		await get_tree().process_frame
		if not game._building:
			break
	if game._building:
		_fail("azbuka: змейка не построилась за 20 кадров")
		game.queue_free()
		await get_tree().process_frame
		return
	if game.dot_positions.size() != 11:
		_fail("azbuka: ожидалось 11 точек уровня, сейчас %d" % game.dot_positions.size())
		game.queue_free()
		await get_tree().process_frame
		return
	var path: Array[Vector2] = game._get_path_positions(0, 2)
	if path.size() != 3:
		_fail("azbuka: путь 0→2 должен содержать 3 точки, сейчас %d" % path.size())
	var reverse_path: Array[Vector2] = game._get_path_positions(2, 0)
	if reverse_path.size() != 3:
		_fail("azbuka: путь 2→0 должен содержать 3 точки, сейчас %d" % reverse_path.size())
	var kisa := game.get_node_or_null("%KisaCat") as KisaCat
	if kisa != null and kisa.get_index() != game._snake_area.get_child_count() - 1:
		_fail("azbuka: KisaCat должен быть последним child SnakeArea, чтобы бежать поверх кружков")
	if kisa == null:
		_fail("azbuka: KisaCat отсутствует")
	else:
		var start_pos := kisa.position
		game._on_dot_pressed(2)
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		if not game.is_animating:
			_fail("azbuka: is_animating должен быть true после выбора буквы")
		if not kisa.is_moving:
			_fail("azbuka: KisaCat должен перейти в walk")
		if kisa.position.is_equal_approx(start_pos):
			_fail("azbuka: Киса не сдвинулась с места")
	game.queue_free()
	await get_tree().process_frame
	_print("azbuka: Kisa run OK")


## Проверяет, что обе сцены с иллюстрированным фоном получают один и тот же
## слой темы: он видим и в светлой, и в тёмной теме, а оттенок совпадает с
## ThemeManager. Это и есть общий визуальный стиль пункта #7.
func _check_image_screen_overlay() -> void:
	ThemeManager.set_theme(ThemeManager.ThemeMode.LIGHT)
	var azbuka_scene: PackedScene = load("res://ui/games/azbuka/azbuka.tscn")
	var azbuka: Node = azbuka_scene.instantiate()
	add_child(azbuka)
	await get_tree().process_frame
	var azbuka_overlay := azbuka.get_node_or_null("%BackgroundOverlay") as ColorRect
	_check_overlay(azbuka_overlay, "azbuka light")
	ThemeManager.set_theme(ThemeManager.ThemeMode.DARK)
	await get_tree().process_frame
	_check_overlay(azbuka_overlay, "azbuka dark")
	azbuka.queue_free()
	await get_tree().process_frame

	var card_scene: PackedScene = load("res://ui/games/azbuka/letter_card.tscn")
	var card: Node = card_scene.instantiate()
	add_child(card)
	await get_tree().process_frame
	var card_overlay := card.get_node_or_null("%BackgroundOverlay") as ColorRect
	_check_overlay(card_overlay, "letter_card dark")
	ThemeManager.set_theme(ThemeManager.ThemeMode.LIGHT)
	await get_tree().process_frame
	_check_overlay(card_overlay, "letter_card light")
	card.queue_free()
	await get_tree().process_frame
	_print("theme: image screens share overlay")


func _check_overlay(overlay: ColorRect, label: String) -> void:
	if overlay == null:
		_fail("%s: %%BackgroundOverlay отсутствует" % label)
		return
	if not overlay.visible:
		_fail("%s: затемнение фона должно быть видимым" % label)
		return
	if not overlay.color.is_equal_approx(ThemeManager.get_screen_overlay_color()):
		_fail("%s: цвет затемнения не совпадает с ThemeManager" % label)


func _fail(msg: String) -> void:
	failures += 1
	printerr("FAIL: " + msg)


func _print(msg: String) -> void:
	print("[ui_validate] " + msg)
