extends Control

const MODES := [
	["alphabet", "ModeAlphabet"],
	["find_letter", "ModeFindLetter"],
	["collect_word", "ModeCollectWord"],
	["guess_picture", "ModeGuessPicture"],
]

@onready var theme_button := $VBoxContainer/ThemeSection/ThemeButton
@onready var theme_label := $VBoxContainer/ThemeSection/ThemeLabel
@onready var reset_button := $VBoxContainer/ResetProgressButton
@onready var back_button := $VBoxContainer/BackButton

func _ready():
	update_ui()
	theme_button.pressed.connect(_on_theme_toggled)
	reset_button.pressed.connect(_on_reset_pressed)
	back_button.pressed.connect(_on_back_pressed)
	ThemeManager.theme_changed.connect(_on_theme_changed)
	ThemeManager.style_button(back_button, Color("#E8A87C"), Color("#2D2D2D"))
	ThemeManager.style_button(theme_button, Color("#DDA0DD"))
	_setup_mode_checkboxes()

func _on_theme_changed(_theme_name: String):
	update_ui()

func update_ui():
	var is_light = ThemeManager.current_theme == "light"
	theme_button.text = "☀️ Светлая тема" if is_light else "🌙 Тёмная тема"
	theme_label.text = "Текущая: " + ("Светлая" if is_light else "Тёмная")
	theme_label.add_theme_color_override("font_color", ThemeManager.get_text())
	ThemeManager.style_button(theme_button, Color("#DDA0DD"))

func _setup_mode_checkboxes():
	for m in MODES:
		var key := m[0] as String
		var node_name := m[1] as String
		var cb := $VBoxContainer/GameModesSection.get_node(node_name) as CheckBox
		cb.button_pressed = ProgressManager.is_mode_enabled(key)
		cb.toggled.connect(_on_mode_toggled.bind(key, cb))

func _on_mode_toggled(value: bool, key: String, cb: CheckBox):
	if not value and ProgressManager.get_enabled_modes_count() <= 1:
		cb.button_pressed = true
		var dialog := AcceptDialog.new()
		dialog.dialog_text = "Должен быть включён хотя бы 1 режим игры."
		dialog.title = "Внимание"
		dialog.ok_button_text = "OK"
		dialog.close_requested.connect(dialog.queue_free)
		add_child(dialog)
		dialog.popup_centered()
		return
	ProgressManager.set_mode_enabled(key, value)

func _on_theme_toggled():
	ThemeManager.toggle_theme()

func _on_reset_pressed():
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "Сбросить весь прогресс по азбуке?\nБуквы перестанут быть зелёными."
	dialog.ok_button_text = "Сбросить"
	dialog.cancel_button_text = "Отмена"
	dialog.confirmed.connect(_on_reset_confirmed)
	dialog.canceled.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()

func _on_reset_confirmed():
	ProgressManager.reset_progress()
	Global.go_to_alphabet_screen()

func _on_back_pressed():
	Global.go_to_main_menu()
