class_name SetList
extends Control
## Список пользовательских наборов: создать, открыть, удалить.
##
## Встроенные наборы здесь не показываются — родитель создаёт только свои.
##
## Экран сам хостит редактор набора: Settings открывает SetList сменой сцены,
## и принимать сигнал open_editor было некому. Поэтому нажатие строки не
## только эмитит сигнал, но и открывает встроенный SetEditor поверх списка.

## Родитель хочет открыть набор в редакторе.
signal open_editor(set_id: String)
## Список изменился: создали, удалили, переименовали.
signal sets_changed()

## Экран открывает SetList сменой сцены (Settings), а редактор встроен в сцену
## списка, поэтому open_editor и sets_changed никому извне не нужны: сигналы
## оставлены как публичный контракт, на них подписан сам список в тестах.
const ROW_SCENE := preload("res://ui/constructor/set_list/set_list_row.tscn")
## Сцена настроек: «Назад» из списка возвращает туда, откуда пришли.
const SETTINGS_SCENE := "res://ui/settings/settings.tscn"

@onready var _new_button: Button = %NewButton
@onready var _scroll: VBoxContainer = %Scroll
@onready var _empty_label: Label = %EmptyLabel
@onready var _editor: SetEditor = %SetEditor
@onready var _back_button: Button = %BackButton
@onready var _layout: VBoxContainer = $Layout

var _rows: Array[SetListRow] = []
## true, когда поверх списка открыт редактор. По флагу кнопка списка знает,
## куда возвращать: из списка — в настройки, из редактора назад ведёт уже
## собственная кнопка редактора (close_requested).
var _editor_open: bool = false


func _ready() -> void:
	_new_button.pressed.connect(_on_new_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	# Редактор встроен в сцену, поэтому его сигналы доступны сразу. set_saved
	# закрывает редактор и перечитывает список: имя набора могло измениться,
	# а счётчик букв — пополниться.
	_editor.set_saved.connect(_on_editor_set_saved)
	_editor.close_requested.connect(_on_editor_close_requested)
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
	_show_editor(set_id)


func _on_row_pressed(set_id: String) -> void:
	open_editor.emit(set_id)
	_show_editor(set_id)


func _on_row_delete(set_id: String) -> void:
	CustomSetsStore.delete_set(set_id)
	sets_changed.emit()


## Показывает редактор набора поверх списка. Сначала add_child-а не нужно —
## редактор уже в сцене, его достаточно показать.
##
## Кнопка списка на это время прячется: у редактора есть своя «Назад», которая
## эмитит close_requested, и две кнопки «Назад» на экране означали бы два
## маршрута к одному результату.
func _show_editor(set_id: String) -> void:
	_editor_open = true
	_layout.visible = false
	_back_button.visible = false
	_editor.visible = true
	# Порядок именно такой: сначала видимость, потом open_set(). Наоборот
	# нельзя — refresh() редактора при invisible-узле всё равно отработал бы,
	# но родительский Margin мог бы не успеть пересчитать раскладку.
	_editor.open_set(set_id)
	GameLogger.info("SetList", "editor_opened", {"set_id": set_id})


## Возвращает список наверх. Редактор скрывается, а не удаляется: набор
## может открываться много раз подряд, и пересоздавать 33 слота каждый раз
## незачем. Сюда приходят оба пути назад — «Готово» (set_saved) и «Назад»
## редактора (close_requested), — и оба обязаны привести к одному состоянию.
func _show_list() -> void:
	_editor_open = false
	_editor.visible = false
	_layout.visible = true
	_back_button.visible = true
	_back_button.text = "Назад"


## «Готово» в редакторе: возвращаемся к списку и перечитываем его, потому
## что имя набора и число заполненных букв как раз изменились.
func _on_editor_set_saved(_set_id: String) -> void:
	_show_list()
	refresh()


func _on_editor_close_requested() -> void:
	_show_list()


## Одна кнопка списка на два состояния: из списка — в настройки, откуда
## пришли. Из редактора она спрятана (_show_editor), и назад ведёт кнопка
## самого редактора через close_requested: один путь назад, а не два.
func _on_back_pressed() -> void:
	if _editor_open:
		# Страховка от двойной навигации: состояние могло разъехаться
		# (например, open_set() снаружи), и тогда лучше закрыть редактор
		# напрямую, чем нажать на скрытую кнопку, которая ничего не нажмётся.
		_show_list()
		return
	get_tree().change_scene_to_file(SETTINGS_SCENE)


func _apply_theme(_mode: int = 0) -> void:
	var colors: Dictionary = ThemeManager.COLORS[ThemeManager.current_theme]
	var button_bg := colors["button_bg"] as Color
	var button_text := colors["button_text"] as Color
	ThemeManager.style_button(_new_button, button_bg, button_text)
	ThemeManager.style_button(_back_button, button_bg, button_text)
	_empty_label.add_theme_color_override("font_color", ThemeManager.get_text())
