extends Control

@onready var alphabet_button := $VBoxContainer/AlphabetButton
@onready var find_letter_button := $VBoxContainer/FindLetterButton
@onready var collect_word_button := $VBoxContainer/CollectWordButton
@onready var guess_picture_button := $VBoxContainer/GuessPictureButton
@onready var settings_button := $SettingsButton
@onready var donate_button := $DonateButton
@onready var donate_overlay := $DonateOverlay
@onready var donate_dialog := $DonateOverlay/DonateDialog
@onready var sbp_dialog := $DonateOverlay/SbpDialog
@onready var sbp_button := $DonateOverlay/DonateDialog/VBox/SbpButton
@onready var yoomoney_button := $DonateOverlay/DonateDialog/VBox/YoomoneyButton
@onready var cancel_button := $DonateOverlay/DonateDialog/VBox/CancelButton
@onready var open_bank_button := $DonateOverlay/SbpDialog/VBox/OpenBankButton
@onready var copy_button := $DonateOverlay/SbpDialog/VBox/CopyButton
@onready var back_button := $DonateOverlay/SbpDialog/VBox/BackButton

const YOOMONEY_URL := "https://yoomoney.ru/quickpay/confirm?receiver=4100117104887151&quickpay-form=button&sum=100&successURL=https://azbuka.app/spasibo"
const SBP_PHONE := "+79044091470"
const SBERBANK_URL := "https://www.sberbank.com/sms/pbpn?requisiteNumber=79044091470"

func _ready():
	alphabet_button.pressed.connect(_on_alphabet_pressed)
	find_letter_button.pressed.connect(_on_find_letter_pressed)
	collect_word_button.pressed.connect(_on_collect_word_pressed)
	guess_picture_button.pressed.connect(_on_guess_picture_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	donate_button.pressed.connect(_on_donate_pressed)
	sbp_button.pressed.connect(_on_sbp_pressed)
	yoomoney_button.pressed.connect(_on_yoomoney_pressed)
	cancel_button.pressed.connect(_on_donate_cancel)
	open_bank_button.pressed.connect(_on_sbp_open_bank)
	copy_button.pressed.connect(_on_sbp_copy)
	back_button.pressed.connect(_on_sbp_back)
	_style_button()
	_style_donate_button()
	_style_dialog()
	_update_mode_buttons()
	ProgressManager.enabled_modes_changed.connect(_update_mode_buttons)

func _on_alphabet_pressed():
	Global.go_to_roadmap()

func _on_find_letter_pressed():
	Global.go_to_game_find_letter()

func _on_collect_word_pressed():
	Global.go_to_collect_word()

func _on_guess_picture_pressed():
	Global.go_to_game_guess_picture()

func _on_settings_pressed():
	Global.go_to_settings()

func _on_donate_pressed():
	donate_overlay.visible = true
	donate_dialog.visible = true
	sbp_dialog.visible = false

func _on_donate_cancel():
	donate_overlay.visible = false

func _on_sbp_pressed():
	donate_dialog.visible = false
	sbp_dialog.visible = true

func _on_sbp_open_bank():
	DisplayServer.clipboard_set(SBP_PHONE)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.open('%s', '_blank')" % SBERBANK_URL)
	else:
		OS.shell_open(SBERBANK_URL)

func _on_sbp_copy():
	DisplayServer.clipboard_set(SBP_PHONE)

func _on_sbp_back():
	sbp_dialog.visible = false
	donate_dialog.visible = true

func _on_yoomoney_pressed():
	donate_overlay.visible = false
	var url = YOOMONEY_URL
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.open('%s', '_blank')" % url)
	else:
		OS.shell_open(url)

func _style_button():
	ThemeManager.style_button(alphabet_button, Color("#4ECDC4"))
	ThemeManager.style_button(find_letter_button, Color("#FF6B6B"))
	ThemeManager.style_button(collect_word_button, Color("#45B7D1"))
	ThemeManager.style_button(guess_picture_button, Color("#96CEB4"), Color("#2D2D2D"))

func _style_donate_button():
	ThemeManager.style_button(donate_button, Color("#FF6B6B"))

func _style_dialog():
	var bg := StyleBoxFlat.new()
	bg.bg_color = ThemeManager.get_card_bg()
	bg.set_corner_radius_all(20)

	var dlg = donate_dialog
	dlg.add_theme_stylebox_override("panel", bg)

	for btn in [sbp_button, yoomoney_button]:
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color("#4ECDC4")
		normal.set_corner_radius_all(20)
		normal.shadow_size = 6
		normal.shadow_color = Color(0, 0, 0, 0.2)
		normal.content_margin_left = 24
		normal.content_margin_right = 24
		normal.content_margin_top = 16
		normal.content_margin_bottom = 16
		btn.add_theme_stylebox_override("normal", normal)
		var hover := StyleBoxFlat.new()
		hover.bg_color = Color("#4ECDC4").lightened(0.15)
		hover.set_corner_radius_all(20)
		hover.shadow_size = 8
		hover.shadow_color = Color(0, 0, 0, 0.3)
		hover.content_margin_left = 24
		hover.content_margin_right = 24
		hover.content_margin_top = 16
		hover.content_margin_bottom = 16
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_hover_color", Color.WHITE)

	var cn := StyleBoxFlat.new()
	cn.bg_color = Color("#E8A87C")
	cn.set_corner_radius_all(20)
	cn.content_margin_left = 24
	cn.content_margin_right = 24
	cn.content_margin_top = 12
	cn.content_margin_bottom = 12
	cancel_button.add_theme_stylebox_override("normal", cn)
	cancel_button.add_theme_color_override("font_color", Color("#2D2D2D"))

	var sbp_bg := StyleBoxFlat.new()
	sbp_bg.bg_color = ThemeManager.get_card_bg()
	sbp_bg.set_corner_radius_all(20)
	sbp_dialog.add_theme_stylebox_override("panel", sbp_bg)

	var sbp_green := StyleBoxFlat.new()
	sbp_green.bg_color = Color("#4ECDC4")
	sbp_green.set_corner_radius_all(20)
	sbp_green.shadow_size = 6
	sbp_green.shadow_color = Color(0, 0, 0, 0.2)
	sbp_green.content_margin_left = 24
	sbp_green.content_margin_right = 24
	sbp_green.content_margin_top = 16
	sbp_green.content_margin_bottom = 16
	for btn in [open_bank_button, copy_button]:
		btn.add_theme_stylebox_override("normal", sbp_green)
		var h := StyleBoxFlat.new()
		h.bg_color = Color("#4ECDC4").lightened(0.15)
		h.set_corner_radius_all(20)
		h.shadow_size = 8
		h.shadow_color = Color(0, 0, 0, 0.3)
		h.content_margin_left = 24
		h.content_margin_right = 24
		h.content_margin_top = 16
		h.content_margin_bottom = 16
		btn.add_theme_stylebox_override("hover", h)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_hover_color", Color.WHITE)

	var sbp_back := StyleBoxFlat.new()
	sbp_back.bg_color = Color("#E8A87C")
	sbp_back.set_corner_radius_all(20)
	sbp_back.content_margin_left = 24
	sbp_back.content_margin_right = 24
	sbp_back.content_margin_top = 12
	sbp_back.content_margin_bottom = 12
	back_button.add_theme_stylebox_override("normal", sbp_back)
	back_button.add_theme_color_override("font_color", Color("#2D2D2D"))

func _update_mode_buttons():
	find_letter_button.visible = ProgressManager.is_mode_enabled("find_letter")
	collect_word_button.visible = ProgressManager.is_mode_enabled("collect_word")
	guess_picture_button.visible = ProgressManager.is_mode_enabled("guess_picture")
