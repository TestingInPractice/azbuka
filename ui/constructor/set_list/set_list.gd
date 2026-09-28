class_name SetList
extends Control
## Список пользовательских наборов: создать, открыть, удалить.
##
## Встроенные наборы здесь не показываются — родитель создаёт только свои.

## Родитель хочет открыть набор в редакторе.
signal open_editor(set_id: String)
## Список изменился: создали, удалили, переименовали.
signal sets_changed()

const ROW_SCENE := preload("res://ui/constructor/set_list/set_list_row.tscn")

@onready var _new_button: Button = %NewButton
@onready var _scroll: VBoxContainer = %Scroll
@onready var _empty_label: Label = %EmptyLabel

var _rows: Array[SetListRow] = []


func _ready() -> void:
	_new_button.pressed.connect(_on_new_pressed)
	ThemeManager.theme_changed.connect(_apply_theme)
	_apply_theme()
	CustomSetsStore.sets_changed.connect(refresh)
	refresh()


## Пересобирает список из хранилища. Строки создаются заново: их мало
## (единицы), зато не нужно синхронизировать удалённые узлы.
##
## Отличие от плана — add_child() идёт ПЕРЕД setup(). План звал setup() на
## ненадписанной в дерево строке, где @onready-поля ещё nil, и каждая строка
## падала с «Invalid assignment of property or key 'text' ... on a base object
## of type 'Nil'» — то есть имя и счётчик букв не показывались вообще.
## Авторитетен порядок из _build_slots() SetEditor в этом же плане:
## сначала add_child(), потом обращение к слоту.
func refresh() -> void:
	for child in _scroll.get_children():
		child.queue_free()
	_rows.clear()
	for record: Dictionary in CustomSetsStore.get_sets():
		var set_id := str(record.get("id", ""))
		var row: SetListRow = ROW_SCENE.instantiate()
		_scroll.add_child(row)
		var open_count := CustomSetsStore.get_set_letter_count(set_id)
		row.setup(str(record.get("name", "")), open_count,
				CustomSetsStore.is_set_complete(set_id))
		row.pressed.connect(_on_row_pressed.bind(set_id))
		row.delete_requested.connect(_on_row_delete.bind(set_id))
		_rows.append(row)
	_empty_label.visible = _rows.is_empty()
	GameLogger.info("SetList", "refreshed", {"rows": _rows.size()})


## Количество строк списка.
func get_row_count() -> int:
	return _rows.size()


## Строка по индексу. Вне диапазона — null, чтобы тест и вызывающий
## получали предсказуемый ответ. Тип именно SetListRow, а не Button: строка
## это PanelContainer с тремя кнопками внутри, и Button здесь не подойдёт.
func get_row(index: int) -> SetListRow:
	if index < 0 or index >= _rows.size():
		return null
	return _rows[index]


## Создание и удаление набора — работа хранилища, экран только вызывает его.
func _on_new_pressed() -> void:
	var record := CustomSetsStore.create_set("Новый набор")
	var set_id := str(record.get("id", ""))
	if set_id.is_empty():
		return
	sets_changed.emit()
	open_editor.emit(set_id)


func _on_row_pressed(set_id: String) -> void:
	open_editor.emit(set_id)


func _on_row_delete(set_id: String) -> void:
	CustomSetsStore.delete_set(set_id)
	sets_changed.emit()


func _apply_theme(_mode: int = 0) -> void:
	var colors: Dictionary = ThemeManager.COLORS[ThemeManager.current_theme]
	ThemeManager.style_button(_new_button, colors["button_bg"] as Color,
			colors["button_text"] as Color)
	_empty_label.add_theme_color_override("font_color", ThemeManager.get_text())
