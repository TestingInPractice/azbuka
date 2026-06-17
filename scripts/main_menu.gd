extends Control

@onready var _bg_rect: ColorRect = $BackgroundRect

func _ready():
	_update_background()
	ThemeManager.theme_changed.connect(_on_theme_changed)
	_setup_background_decorations()
	_connect_buttons()
	_update_progress()
	_style_buttons()
	_animate_title()
	_update_mode_buttons()
	ProgressManager.enabled_modes_changed.connect(_update_mode_buttons)

func _update_mode_buttons():
	var mode_map := {
		"alphabet": "AlphabetButton",
		"find_letter": "FindLetterButton",
		"collect_word": "CollectWordButton",
		"guess_picture": "GuessPictureButton",
	}
	for key in mode_map:
		var btn := $VBoxContainer/ButtonGrid.get_node(mode_map[key]) as Button
		if btn:
			btn.visible = ProgressManager.is_mode_enabled(key)

func _on_theme_changed(_theme_name: String):
	_update_background()

func _update_background():
	_bg_rect.color = ThemeManager.get_bg()

func _setup_background_decorations():
	var viewport_width = get_viewport().get_visible_rect().size.x
	for i in 8:
		var lbl := Label.new()
		lbl.text = ["★", "✦", "●", "♥", "♦", "✦", "★", "◆"][i]
		lbl.modulate = Color(1, 1, 1, 0.12 + i * 0.025)
		lbl.add_theme_font_size_override("font_size", 20 + (i % 3) * 12)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.position = Vector2(randf_range(30, viewport_width - 30), randf_range(30, 400))
		add_child(lbl)
		var tw := create_tween()
		tw.set_loops()
		var target_y = lbl.position.y + 50 + i * 10
		var origin_y = lbl.position.y
		tw.tween_property(lbl, "position", Vector2(lbl.position.x, target_y), 2.5 + i * 0.3)
		tw.tween_property(lbl, "position", Vector2(lbl.position.x, origin_y), 2.5 + i * 0.3)

func _connect_buttons():
	$VBoxContainer/ButtonGrid/AlphabetButton.pressed.connect(_on_alphabet_pressed)
	$VBoxContainer/ButtonGrid/FindLetterButton.pressed.connect(_on_find_letter_pressed)
	$VBoxContainer/ButtonGrid/CollectWordButton.pressed.connect(_on_collect_word_pressed)
	$VBoxContainer/ButtonGrid/GuessPictureButton.pressed.connect(_on_guess_picture_pressed)
	$VBoxContainer/RoadmapButton.pressed.connect(_on_roadmap_pressed)
	$SettingsButton.pressed.connect(_on_settings_pressed)

func _on_alphabet_pressed():
	Global.go_to_alphabet_screen()

func _on_find_letter_pressed():
	Global.go_to_game_find_letter()

func _on_collect_word_pressed():
	Global.go_to_collect_word()

func _on_guess_picture_pressed():
	Global.go_to_game_guess_picture()

func _on_roadmap_pressed():
	Global.go_to_roadmap()

func _on_settings_pressed():
	Global.go_to_settings()

func _animate_title():
	var title = $VBoxContainer/TitleLabel
	title.modulate = Color(0.2, 0.2, 0.4, 0)
	var tw = create_tween()
	tw.tween_property(title, "modulate", Color(0.2, 0.2, 0.4, 1), 0.8)
	tw.parallel().tween_property(title, "scale", Vector2(1.1, 1.1), 0.4).from(Vector2(0.5, 0.5))
	tw.tween_property(title, "scale", Vector2.ONE, 0.3)

	var sub = $VBoxContainer/SubtitleLabel
	sub.modulate = Color(0.5, 0.5, 0.6, 0)
	var tw2 = create_tween()
	tw2.tween_interval(0.4)
	tw2.tween_property(sub, "modulate", Color(0.5, 0.5, 0.6, 1), 0.5)

	# Animate buttons in
	for btn in $VBoxContainer/ButtonGrid.get_children():
		btn.modulate = Color(1, 1, 1, 0)
		btn.scale = Vector2(0.8, 0.8)
		var tb = create_tween()
		tb.set_parallel(true)
		tb.tween_interval(0.5 + btn.get_index() * 0.08)
		tb.tween_property(btn, "modulate", Color.WHITE, 0.3)
		tb.tween_property(btn, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)

func _style_buttons():
	var alphabet = $VBoxContainer/ButtonGrid/AlphabetButton
	var find_letter = $VBoxContainer/ButtonGrid/FindLetterButton
	var collect_word = $VBoxContainer/ButtonGrid/CollectWordButton
	var guess_picture = $VBoxContainer/ButtonGrid/GuessPictureButton
	var roadmap = $VBoxContainer/RoadmapButton
	var settings = $SettingsButton

	ThemeManager.style_button(alphabet, Color("#4ECDC4"))
	ThemeManager.style_button(find_letter, Color("#FF6B6B"))
	ThemeManager.style_button(collect_word, Color("#45B7D1"))
	ThemeManager.style_button(guess_picture, Color("#96CEB4"), Color("#2D2D2D"))
	ThemeManager.style_button(roadmap, Color("#5B8C5A"))
	ThemeManager.style_button(settings, Color("#DDA0DD"))


func _update_progress():
	var count = ProgressManager.get_completed_count()
	var total = ProgressManager.get_total_letters()
	var games = ProgressManager.games_played
	$VBoxContainer/ProgressContainer/ProgressLabel.text = "Букв: " + str(count) + "/" + str(total) + "  |  Заданий: " + str(games)
	$VBoxContainer/ProgressContainer/ProgressBar.max_value = total
	$VBoxContainer/ProgressContainer/ProgressBar.value = count
