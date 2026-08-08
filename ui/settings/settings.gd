extends Control
## Экран настроек.
##
## Управляет включёнными режимами игр (минимум один включён), сбросом
## прогресса, темой оформления и возвратом в главное меню. Также открывает
## экраны доната и обратной связи, указывая им сцену возврата — этот экран.

## Сцена настроек (для возврата из попапов доната и обратной связи).
const SETTINGS_SCENE := "res://ui/settings/settings.tscn"
## Минимальное число включённых режимов игр.
const MIN_ENABLED_MODES := 1
## Цвет текста предупреждения.
const WARNING_COLOR := Color("#E53935")
## Ключи режимов игр в порядке чекбоксов.
const MODE_KEYS := ["azbuka", "find_letter", "collect_word", "guess_picture"]
## Названия режимов игр.
const MODE_TITLES := {
	"azbuka": "Азбука",
	"find_letter": "Найди букву",
	"collect_word": "Собери слово",
	"guess_picture": "Угадай картинку",
}

## Размер квадратного индикатора чекбокса в пикселях.
const CHECKBOX_ICON_SIZE := 64
## Радиус скругления углов индикатора чекбокса.
const CHECKBOX_ICON_RADIUS := 18

@onready var _background: ColorRect = %Background
@onready var _title_label: Label = %TitleLabel
@onready var _warning_label: Label = %WarningLabel
@onready var _mode_checkbox_azbuka: CheckBox = %ModeCheckboxAzbuka
@onready var _mode_checkbox_find_letter: CheckBox = %ModeCheckboxFindLetter
@onready var _mode_checkbox_collect_word: CheckBox = %ModeCheckboxCollectWord
@onready var _mode_checkbox_guess_picture: CheckBox = %ModeCheckboxGuessPicture
@onready var _series_length_spinbox: SpinBox = %SeriesLengthSpinBox
@onready var _series_length_label: Label = %SeriesLengthLabel
@onready var _reset_button: Button = %ResetButton
@onready var _theme_toggle_button: Button = %ThemeToggleButton
@onready var _donate_button: Button = %DonateButton
@onready var _feedback_button: Button = %FeedbackButton
@onready var _back_button: Button = %BackButton
@onready var _confirm_reset_dialog: ConfirmationDialog = %ConfirmResetDialog
@onready var _warning_timer: Timer = %WarningTimer
## Карточки-строки, перекрашиваются в _apply_theme.
@onready var _mode_card_azbuka: PanelContainer = %ModeCardAzbuka
@onready var _mode_card_find_letter: PanelContainer = %ModeCardFindLetter
@onready var _mode_card_collect_word: PanelContainer = %ModeCardCollectWord
@onready var _mode_card_guess_picture: PanelContainer = %ModeCardGuessPicture
@onready var _series_card: PanelContainer = %SeriesCard

var _checkboxes: Dictionary = {}
var _updating: bool = false


func _ready() -> void:
	_checkboxes["azbuka"] = _mode_checkbox_azbuka
	_checkboxes["find_letter"] = _mode_checkbox_find_letter
	_checkboxes["collect_word"] = _mode_checkbox_collect_word
	_checkboxes["guess_picture"] = _mode_checkbox_guess_picture
	for key: String in _checkboxes:
		var checkbox := _checkboxes[key] as CheckBox
		checkbox.toggled.connect(_on_mode_checkbox_toggled.bind(key))
	ProgressManager.enabled_modes_changed.connect(_on_enabled_modes_changed)
	ProgressManager.progress_reset.connect(_on_progress_reset)
	ThemeManager.theme_changed.connect(_apply_theme)
	_reset_button.pressed.connect(_on_reset_button_pressed)
	_theme_toggle_button.pressed.connect(_on_theme_toggle_button_pressed)
	_donate_button.pressed.connect(_on_donate_button_pressed)
	_feedback_button.pressed.connect(_on_feedback_button_pressed)
	_back_button.pressed.connect(_on_back_button_pressed)
	_confirm_reset_dialog.confirmed.connect(_on_reset_confirmed)
	_confirm_reset_dialog.canceled.connect(_on_reset_cancelled)
	_warning_timer.timeout.connect(_on_warning_timer_timeout)
	_series_length_spinbox.min_value = ProgressManager.SERIES_LENGTH_MIN
	_series_length_spinbox.max_value = ProgressManager.SERIES_LENGTH_MAX
	_series_length_spinbox.value = ProgressManager.get_series_length()
	_series_length_spinbox.value_changed.connect(_on_series_length_value_changed)
	_sync_checkboxes()
	_update_theme_button_text()
	_apply_theme()


## Синхронизирует состояние чекбоксов с включёнными режимами.
func _sync_checkboxes() -> void:
	_updating = true
	for key: String in _checkboxes:
		var checkbox := _checkboxes[key] as CheckBox
		checkbox.button_pressed = ProgressManager.is_mode_enabled(key)
	_updating = false


func _on_mode_checkbox_toggled(toggled_on: bool, mode_key: String) -> void:
	if _updating:
		return
	if not toggled_on and ProgressManager.get_enabled_modes_count() <= MIN_ENABLED_MODES:
		_updating = true
		var checkbox := _checkboxes[mode_key] as CheckBox
		checkbox.button_pressed = true
		_updating = false
		_show_warning()
		GameLogger.warning("Settings", "mode_disable_blocked", {"mode": mode_key})
		return
	ProgressManager.set_mode_enabled(mode_key, toggled_on)
	GameLogger.info("Settings", "mode_toggled", {"mode": mode_key, "enabled": toggled_on})


## Обрабатывает изменение длины серии карточек игры «Найди букву».
func _on_series_length_value_changed(value: float) -> void:
	var int_value := int(value)
	ProgressManager.set_series_length(int_value)
	GameLogger.info("Settings", "series_length_changed", {"value": int_value})


func _on_enabled_modes_changed(_modes: Dictionary) -> void:
	_sync_checkboxes()


func _show_warning() -> void:
	_warning_label.visible = true
	_warning_timer.start()


func _on_warning_timer_timeout() -> void:
	_warning_label.visible = false


func _on_reset_button_pressed() -> void:
	GameLogger.info("Settings", "reset_button_pressed", {})
	_confirm_reset_dialog.popup_centered()


func _on_reset_confirmed() -> void:
	ProgressManager.reset_progress()
	GameLogger.info("Settings", "reset_confirmed", {})


func _on_reset_cancelled() -> void:
	GameLogger.info("Settings", "reset_cancelled", {})


func _on_progress_reset() -> void:
	GameLogger.info("Settings", "progress_reset_applied", {})


func _on_theme_toggle_button_pressed() -> void:
	ThemeManager.toggle_theme()
	GameLogger.info("Settings", "theme_toggle_pressed", {"theme": ThemeManager.current_theme})


## Обновляет подпись кнопки переключения темы.
func _update_theme_button_text() -> void:
	var theme_name := "светлая"
	if ThemeManager.current_theme == ThemeManager.THEME_DARK:
		theme_name = "тёмная"
	_theme_toggle_button.text = "Тема: " + theme_name


## Применяет цвета текущей темы.
func _apply_theme(_mode: int = 0) -> void:
	_background.color = ThemeManager.get_bg()
	_title_label.add_theme_color_override("font_color", ThemeManager.get_text())
	_warning_label.add_theme_color_override("font_color", WARNING_COLOR)
	for key: String in _checkboxes:
		var checkbox := _checkboxes[key] as CheckBox
		checkbox.add_theme_color_override("font_color", ThemeManager.get_text())
		checkbox.add_theme_color_override("font_hover_color", ThemeManager.get_text())
		checkbox.add_theme_color_override("font_pressed_color", ThemeManager.get_text())
		checkbox.add_theme_color_override("font_focus_color", ThemeManager.get_text())
		checkbox.add_theme_color_override("font_hover_pressed_color", ThemeManager.get_text())
	_series_length_label.add_theme_color_override("font_color", ThemeManager.get_text())
	_series_length_spinbox.add_theme_color_override("font_color", ThemeManager.get_text())
	var colors: Dictionary = ThemeManager.COLORS[ThemeManager.current_theme]
	var button_bg := colors["button_bg"] as Color
	var button_text := colors["button_text"] as Color
	# Видимые hover/focus-стили чекбоксов: белое выделение на белой
	# карточке в светлой теме не читается, поэтому добавляем подложку
	# и рамку акцентного цвета.
	for key: String in _checkboxes:
		var checkbox := _checkboxes[key] as CheckBox
		var hover_box := StyleBoxFlat.new()
		hover_box.bg_color = button_bg
		hover_box.bg_color.a = 0.15
		hover_box.set_border_width_all(3)
		hover_box.set_border_color(button_bg)
		hover_box.set_corner_radius_all(12)
		checkbox.add_theme_stylebox_override("hover", hover_box)
		var focus_box := StyleBoxFlat.new()
		focus_box.bg_color = button_bg
		focus_box.bg_color.a = 0.1
		focus_box.set_border_width_all(3)
		focus_box.set_border_color(button_bg)
		focus_box.set_corner_radius_all(12)
		checkbox.add_theme_stylebox_override("focus", focus_box)
	ThemeManager.style_button(_reset_button, button_bg, button_text)
	# Компактная кнопка «Сбросить» внутри строки «Азбука».
	for sb_name: String in ["normal", "hover", "pressed"]:
		var sb := _reset_button.get_theme_stylebox(sb_name) as StyleBoxFlat
		if sb:
			sb.content_margin_top = 10
			sb.content_margin_bottom = 10
	ThemeManager.style_button(_theme_toggle_button, button_bg, button_text)
	ThemeManager.style_button(_donate_button, button_bg, button_text)
	ThemeManager.style_button(_feedback_button, button_bg, button_text)
	ThemeManager.style_button(_back_button, button_bg, button_text)
	_style_card(_mode_card_azbuka)
	_style_card(_mode_card_find_letter)
	_style_card(_mode_card_collect_word)
	_style_card(_mode_card_guess_picture)
	_style_card(_series_card)
	_apply_checkbox_icons()
	_update_theme_button_text()


func _on_back_button_pressed() -> void:
	GameLogger.info("Settings", "back_button_pressed", {})
	get_tree().change_scene_to_file("res://ui/main_menu/main_menu.tscn")


## Открывает попап доната, указав ему сцену возврата — этот экран.
func _on_donate_button_pressed() -> void:
	GameLogger.info("Settings", "donate_button_pressed", {})
	DonateOverlay.return_scene = SETTINGS_SCENE
	get_tree().change_scene_to_file("res://ui/donate/donate_overlay.tscn")


## Открывает экран обратной связи, указав ему сцену возврата — этот экран.
func _on_feedback_button_pressed() -> void:
	GameLogger.info("Settings", "feedback_button_pressed", {})
	FeedbackScreen.return_scene = SETTINGS_SCENE
	get_tree().change_scene_to_file("res://ui/feedback/feedback.tscn")


## Окрашивает карточку PanelContainer цветом фона карточек текущей темы.
func _style_card(panel: PanelContainer) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = ThemeManager.get_card_bg()
	box.set_corner_radius_all(24)
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", box)
	# Фокусный стиль: рамка акцентного цвета, чтобы выделение строки
	# читалось даже на белой карточке в светлой теме.
	var colors: Dictionary = ThemeManager.COLORS[ThemeManager.current_theme]
	var accent := colors["button_bg"] as Color
	var box_focus := StyleBoxFlat.new()
	box_focus.bg_color = ThemeManager.get_card_bg()
	box_focus.set_border_width_all(4)
	box_focus.set_border_color(accent)
	box_focus.set_corner_radius_all(24)
	panel.add_theme_stylebox_override("focus", box_focus)


## Пересоздаёт крупные индикаторы чекбоксов под текущую тему.
func _apply_checkbox_icons() -> void:
	var checked_tex := _make_checkbox_icon(true)
	var unchecked_tex := _make_checkbox_icon(false)
	for key: String in _checkboxes:
		var checkbox := _checkboxes[key] as CheckBox
		checkbox.add_theme_icon_override("checked", checked_tex)
		checkbox.add_theme_icon_override("unchecked", unchecked_tex)


## Создаёт текстуру индикатора чекбокса: закрашенный скруглённый квадрат
## с галочкой (включено) или контурный квадрат (выключено).
func _make_checkbox_icon(checked: bool) -> ImageTexture:
	var icon_size := CHECKBOX_ICON_SIZE
	var radius := CHECKBOX_ICON_RADIUS
	var colors: Dictionary = ThemeManager.COLORS[ThemeManager.current_theme]
	var text_color := colors["text"] as Color
	var img := Image.create(icon_size, icon_size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	if checked:
		var accent_color := colors["button_bg"] as Color
		for y in range(icon_size):
			for x in range(icon_size):
				if _inside_rounded(x, y, icon_size, icon_size, radius):
					img.set_pixel(x, y, accent_color)
		var mark := colors["button_text"] as Color
		_draw_thick_line(img, Vector2i(17, 34), Vector2i(27, 44), mark, 8)
		_draw_thick_line(img, Vector2i(27, 44), Vector2i(47, 21), mark, 8)
	else:
		var border := text_color
		border.a = 0.85
		var fill := text_color
		fill.a = 0.25
		for y in range(icon_size):
			for x in range(icon_size):
				if _inside_rounded(x, y, icon_size, icon_size, radius) and not _inside_rounded(x, y, icon_size, icon_size, radius - 5):
					img.set_pixel(x, y, border)
				elif _inside_rounded(x, y, icon_size, icon_size, radius):
					img.set_pixel(x, y, fill)
	return ImageTexture.create_from_image(img)


## Проверяет, лежит ли точка внутри скруглённого прямоугольника.
func _inside_rounded(px: int, py: int, w: int, h: int, r: int) -> bool:
	if px < 0 or py < 0 or px >= w or py >= h:
		return false
	var cx := px
	var cy := py
	if px < r:
		cx = r
	elif px >= w - r:
		cx = w - 1 - r
	if py < r:
		cy = r
	elif py >= h - r:
		cy = h - 1 - r
	var dx := px - cx
	var dy := py - cy
	return dx * dx + dy * dy <= r * r


## Рисует толстую линию по алгоритму Брезенхэма.
func _draw_thick_line(img: Image, from_p: Vector2i, to_p: Vector2i, color: Color, width: int) -> void:
	var dx := absi(to_p.x - from_p.x)
	var dy := -absi(to_p.y - from_p.y)
	var sx := 1 if from_p.x < to_p.x else -1
	var sy := 1 if from_p.y < to_p.y else -1
	var err := dx + dy
	var half := width / 2
	var x := from_p.x
	var y := from_p.y
	while true:
		for ox in range(-half, half + 1):
			for oy in range(-half, half + 1):
				var px := x + ox
				var py := y + oy
				if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
					img.set_pixel(px, py, color)
		if x == to_p.x and y == to_p.y:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
