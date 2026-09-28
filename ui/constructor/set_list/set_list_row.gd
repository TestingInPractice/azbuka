class_name SetListRow
extends PanelContainer
## Строка списка наборов: имя, счётчик букв и кнопка удаления.

## Родитель нажал на строку целиком.
signal pressed
## Родитель нажал «Удалить».
signal delete_requested

@onready var _name_label: Label = %NameLabel
@onready var _count_label: Label = %CountLabel
@onready var _open_button: Button = %OpenButton
@onready var _delete_button: Button = %DeleteButton


## Заполняет строку данными набора. is_complete меняет подпись счётчика.
func setup(name: String, letter_count: int, is_complete: bool) -> void:
	_name_label.text = name
	_count_label.text = "набор готов к играм" if is_complete \
			else "заполнено %d из 33" % letter_count


func _ready() -> void:
	_open_button.pressed.connect(func() -> void: pressed.emit())
	_delete_button.pressed.connect(func() -> void: delete_requested.emit())
	ThemeManager.theme_changed.connect(_apply_theme)
	_apply_theme()


func _apply_theme(_mode: int = 0) -> void:
	var colors: Dictionary = ThemeManager.COLORS[ThemeManager.current_theme]
	_name_label.add_theme_color_override("font_color", ThemeManager.get_text())
	_count_label.add_theme_color_override("font_color", ThemeManager.get_text())
	ThemeManager.style_button(_open_button, colors["button_bg"] as Color,
			colors["button_text"] as Color)
	ThemeManager.style_button(_delete_button, colors["button_bg"] as Color,
			colors["button_text"] as Color)
