extends RefCounted
class_name LetterCardTheme
## Раскраска карточки буквы. Узлы ищутся по уникальным именам сцены,
## чтобы сам экран не разрастался повторяющимися add_theme_* вызовами.

const COLOR_LETTER_BTN := ThemeManager.ACCENT_TEAL
const COLOR_WORD_BTN := ThemeManager.ACCENT_BLUE
const COLOR_MIC_BTN := ThemeManager.ACCENT_RED
const COLOR_PLAY_BTN := ThemeManager.ACCENT_GREEN
const COLOR_BACK_BTN := ThemeManager.ACCENT_ORANGE


static func apply(owner: Control) -> void:
	var background_overlay: ColorRect = owner.get_node("%BackgroundOverlay")
	var letter_label: Label = owner.get_node("%LetterLabel")
	var hint_label: Label = owner.get_node("%HintLabel")
	var button_letter: Button = owner.get_node("%ButtonLetter")
	var button_word: Button = owner.get_node("%ButtonWord")
	var mic_button: Button = owner.get_node("%MicButton")
	var play_button: Button = owner.get_node("%RecordPlaybackButton")
	var back_button: Button = owner.get_node("%LetterBackButton")
	var home_button: Button = owner.get_node("%HomeButton")
	var prev_button: Button = owner.get_node("%PrevLetterButton")
	var next_button: Button = owner.get_node("%NextLetterButton")

	var text: Color = ThemeManager.get_text()
	ThemeManager.style_screen_overlay(background_overlay)
	var ls := letter_label.label_settings
	if ls == null:
		ls = LabelSettings.new()
		letter_label.label_settings = ls
	ls.outline_color = text
	ls.font_color = ThemeManager.WHITE
	ls.outline_size = 4
	var fs: float = maxf(80.0, owner.get_viewport_rect().size.y / 4.0)
	ls.font_size = int(fs)
	hint_label.add_theme_color_override("font_color", ThemeManager.WHITE)
	ThemeManager.style_button(button_letter, COLOR_LETTER_BTN, ThemeManager.INK)
	ThemeManager.style_button(button_word, COLOR_WORD_BTN, ThemeManager.INK)
	ThemeManager.style_button(mic_button, COLOR_MIC_BTN, ThemeManager.INK)
	ThemeManager.style_button(play_button, COLOR_PLAY_BTN, ThemeManager.INK)
	button_letter.add_theme_font_size_override("font_size", 42)
	button_word.add_theme_font_size_override("font_size", 28)
	mic_button.add_theme_font_size_override("font_size", 28)
	play_button.add_theme_font_size_override("font_size", 28)
	ThemeManager.style_button(back_button, COLOR_BACK_BTN, ThemeManager.INK)
	ThemeManager.style_button(home_button, COLOR_BACK_BTN, ThemeManager.INK)
	ThemeManager.style_round_nav_button(prev_button)
	ThemeManager.style_round_nav_button(next_button)
