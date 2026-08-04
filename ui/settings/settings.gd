extends Control
## Экран настроек.
##
## Управляет включёнными режимами игр (минимум один включён), сбросом
## прогресса, темой оформления и возвратом в главное меню.

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
@onready var _back_button: Button = %BackButton
@onready var _confirm_reset_dialog: ConfirmationDialog = %ConfirmResetDialog
@onready var _warning_timer: Timer = %WarningTimer

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
	_series_length_label.add_theme_color_override("font_color", ThemeManager.get_text())
	_series_length_spinbox.add_theme_color_override("font_color", ThemeManager.get_text())
	var colors: Dictionary = ThemeManager.COLORS[ThemeManager.current_theme]
	var button_bg := colors["button_bg"] as Color
	var button_text := colors["button_text"] as Color
	ThemeManager.style_button(_reset_button, button_bg, button_text)
	ThemeManager.style_button(_theme_toggle_button, button_bg, button_text)
	ThemeManager.style_button(_back_button, button_bg, button_text)
	_update_theme_button_text()


func _on_back_button_pressed() -> void:
	GameLogger.info("Settings", "back_button_pressed", {})
	get_tree().change_scene_to_file("res://ui/main_menu/main_menu.tscn")
