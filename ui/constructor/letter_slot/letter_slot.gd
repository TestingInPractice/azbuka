class_name LetterSlot
extends PanelContainer
## Слот одной буквы в конструкторе набора: буква, поле слова, миниатюра и
## кнопки выбора картинки, записи звука, прослушивания и очистки.
##
## Слот ничего не пишет на диск и не открывает пикер — только показывает
## состояние и отдаёт намерение сигналом. Файлами занимается SetEditor.
## Так слот тестируется headless: сцена инстанцируется, сигналы проверяются,
## а микрофон и файловый диалог в тест не попадают.

@onready var _letter_label: Label = %LetterLabel
@onready var _word_edit: LineEdit = %WordEdit
@onready var _status_label: Label = %StatusLabel
@onready var _thumbnail: TextureRect = %Thumbnail
@onready var _image_button: Button = %ImageButton
@onready var _audio_button: Button = %AudioButton
@onready var _play_button: Button = %PlayButton
@onready var _clear_button: Button = %ClearButton

## Нажата «Картинка» — SetEditor откроет пикер.
signal image_requested(letter: String)
## Нажата «Записать» — SetEditor запустит VoiceRecord.
signal audio_requested(letter: String)
## Нажато «Слушать» — SetEditor проиграет записанный WAV.
signal play_requested(letter: String)
## Нажата «Очистить» — SetEditor удалит медиа буквы.
signal clear_requested(letter: String)
## Родитель изменил слово в поле — SetEditor сохранит его в метаданные.
signal word_edited(letter: String, word: String)

var _letter := ""
var _word := ""
var _has_image := false
var _has_audio := false
var _recording := false
## Пока true, сигнал word_edited не отправляется: setup() заполняет поле
## программно, и без этого флага каждый refresh() пересохранял бы набор.
var _updating := false


func _ready() -> void:
	_image_button.pressed.connect(_on_image_pressed)
	_audio_button.pressed.connect(_on_audio_pressed)
	_play_button.pressed.connect(_on_play_pressed)
	_clear_button.pressed.connect(_on_clear_pressed)
	_word_edit.text_changed.connect(_on_word_text_changed)
	_word_edit.text_submitted.connect(_on_word_text_changed)
	ThemeManager.theme_changed.connect(_apply_theme)
	_apply_theme()
	_refresh()


## Человекочитаемое состояние медиа. Вынесено в static, чтобы тест проверял
## подпись без сцены: строки состояния — это то, что читает родитель.
static func describe_state(has_image: bool, has_audio: bool) -> String:
	if has_image and has_audio:
		return "картинка и звук на месте"
	if has_image:
		return "картинка есть, звука нет"
	if has_audio:
		return "картинки нет, звук есть"
	return "нет картинки и звука"


## Заполняет слот данными буквы. Пустой image_path/audio_path означает,
## что медиа для этой буквы ещё не задано.
func setup(letter: String, word: String, image_path: String, audio_path: String) -> void:
	_updating = true
	_letter = letter
	_word = word
	_has_image = not image_path.is_empty()
	_has_audio = not audio_path.is_empty()
	_letter_label.text = letter
	_word_edit.text = word
	_updating = false
	_thumbnail.texture = _load_thumbnail(image_path)
	_refresh()


## Показывает или снимает состояние записи. Пока идёт запись, кнопки
## блокируются: вторая запись поверх первой затёрла бы первую.
func set_recording(active: bool) -> void:
	_recording = active
	_refresh()


## Блокирует все действия на время сохранения файла.
func set_busy(busy: bool) -> void:
	_image_button.disabled = busy
	_audio_button.disabled = busy
	_play_button.disabled = busy or not _has_audio
	_clear_button.disabled = busy or not (_has_image or _has_audio)


func get_letter() -> String:
	return _letter


func get_word() -> String:
	return _word


func has_image() -> bool:
	return _has_image


func has_audio() -> bool:
	return _has_audio


## Загружает миниатюру картинки буквы. Пустой путь — плейсхолдер, ошибка
## чтения — тоже плейсхолдер, слот не должен падать из-за одной картинки.
func _load_thumbnail(image_path: String) -> Texture2D:
	if image_path.is_empty():
		return null
	var texture := ImageTexture.create_from_image(Image.load_from_file(image_path)) if FileAccess.file_exists(image_path) else null
	if texture == null:
		GameLogger.warning("LetterSlot", "thumbnail_missing", {"path": image_path})
	return texture


## Пересчитывает подписи и доступность кнопок из текущего состояния.
func _refresh() -> void:
	if _recording:
		_status_label.text = "запись…"
	else:
		_status_label.text = describe_state(_has_image, _has_audio)
	_image_button.disabled = false
	_audio_button.disabled = _recording
	_play_button.disabled = _recording or not _has_audio
	_clear_button.disabled = _recording or not (_has_image or _has_audio)


func _on_image_pressed() -> void:
	GameLogger.info("LetterSlot", "image_requested", {"letter": _letter})
	image_requested.emit(_letter)


func _on_audio_pressed() -> void:
	GameLogger.info("LetterSlot", "audio_requested", {"letter": _letter})
	audio_requested.emit(_letter)


func _on_play_pressed() -> void:
	GameLogger.info("LetterSlot", "play_requested", {"letter": _letter})
	play_requested.emit(_letter)


func _on_clear_pressed() -> void:
	GameLogger.info("LetterSlot", "clear_requested", {"letter": _letter})
	clear_requested.emit(_letter)


## Карточка слоя и кнопки красятся под текущую тему.
func _apply_theme(_mode: int = 0) -> void:
	var colors: Dictionary = ThemeManager.COLORS[ThemeManager.current_theme]
	var button_bg := colors["button_bg"] as Color
	var button_text := colors["button_text"] as Color
	var box := StyleBoxFlat.new()
	box.bg_color = ThemeManager.get_card_bg()
	box.set_corner_radius_all(24)
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	add_theme_stylebox_override("panel", box)
	_letter_label.add_theme_color_override("font_color", ThemeManager.get_text())
	_word_edit.add_theme_color_override("font_color", ThemeManager.get_text())
	_word_edit.add_theme_stylebox_override("normal", _edit_box(0.0))
	_word_edit.add_theme_stylebox_override("focus", _edit_box(0.15))
	_status_label.add_theme_color_override("font_color", _status_color())
	for button: Button in [_image_button, _audio_button, _play_button, _clear_button]:
		ThemeManager.style_button(button, button_bg, button_text)


## Фон поля ввода слова: полупрозрачная подложка темы, чтобы поле читалось
## как поле, а не как обычный текст.
func _edit_box(alpha: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = ThemeManager.get_card_bg()
	box.bg_color.a = 0.6 + alpha
	box.set_corner_radius_all(12)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box


## Родитель изменил слово в поле. Пустое слово не отправляем: буква без слова
## бессмысленна, и SetEditor решит, что это незавершённая запись.
func _on_word_text_changed(new_text: String) -> void:
	if _updating:
		return
	var trimmed := new_text.strip_edges()
	if trimmed.is_empty():
		return
	_word = trimmed
	GameLogger.info("LetterSlot", "word_edited", {"letter": _letter, "word": trimmed})
	word_edited.emit(_letter, trimmed)


## Цвет подписи состояния: зелёный, когда всё на месте, иначе обычный текст.
## Не красный: незаполненная буква — обычное состояние набора, а не ошибка.
func _status_color() -> Color:
	if _has_image and _has_audio:
		return Color("#43A047")
	return ThemeManager.get_text()
