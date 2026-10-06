class_name SetEditor
extends Control
## Экран работы над одним набором: имя, счётчик готовности и 33 слота
## LetterSlot в алфавитном порядке.
##
## Редактор — единственный, кто пишет файлы и метаданные. LetterSlot только
## сообщает намерение сигналом, поэтому пикер и микрофон живут здесь, а слот
## остаётся проверяемым headless.
##
## apply_image() и apply_audio() — проверяемые швы. Сигнальные обработчики
## лишь добывают байты (пикером или записью) и зовут их, поэтому браузерный и
## тестовый пути — это один и тот же код.

## Алфавит набора. 33 буквы, порядок определяет и порядок слотов.
const LETTERS := [
	"А", "Б", "В", "Г", "Д", "Е", "Ё", "Ж", "З", "И", "Й", "К", "Л", "М",
	"Н", "О", "П", "Р", "С", "Т", "У", "Ф", "Х", "Ц", "Ч", "Ш", "Щ", "Ъ",
	"Ы", "Ь", "Э", "Ю", "Я",
]
const LETTER_SLOT_SCENE := preload("res://ui/constructor/letter_slot/letter_slot.tscn")

## Автостоп: запись, которую никто не остановил, выключается сама через 10
## секунд. Без этого уход со экрана или пропущенный «Стоп» оставляли микрофон
## открытым навсегда. Зеркалит RECORD_DURATION из letter_card.gd.
const RECORD_DURATION := 10.0

## Ширина design-экрана, начиная которой сетка слотов идёт в три колонки.
## Телефон (~1080 design px) получает одну колонку и листается сверху вниз;
## трём колонкам нужно ~2500 design px (4 кнопки в строку + поля слота),
## широкий десктоп (~4889 при stretch canvas_items/expand) — их и получает.
const WIDE_COLUMNS_WIDTH := 2560

## Набор сохранился целиком — можно идти играть.
signal set_saved(set_id: String)
## Родитель нажал «Назад».
signal close_requested()

@onready var _name_edit: LineEdit = %NameEdit
@onready var _save_button: Button = %SaveButton
@onready var _readiness_label: Label = %ReadinessLabel
@onready var _slots: GridContainer = %Slots
@onready var _back_button: Button = %BackButton

var _set_id := ""
var _slots_by_letter: Dictionary = {}
## Буква, для которой сейчас идёт запись, чтобы слоты не мешали друг другу.
var _recording_letter := ""
## Токен автостопа: каждый старт записи увеличивает счётчик, и таймер со
## старым токеном при срабатывании молча выходит — иначе таймер первой
## записи мог остановить уже вторую.
var _record_guard_token := 0
## true, когда запись остановлена по кнопке «Стоп» или автостопом. Запись,
## пришедшая не от нас (сырой сигнал в тесте), не должна навешивать
## «ничего не записалось» поверх подписи состояния.
var _record_stop_requested := false
## Пока true, правки поля имени не эмитятся наружу: refresh() и open_set()
## заполняют поле программно, и без флага каждый чтение набора помечало бы
## его сохранённым и рассылало бы set_saved без причины.
var _updating := false


func _ready() -> void:
	_build_slots()
	_save_button.pressed.connect(_on_save_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_name_edit.text_submitted.connect(_on_name_submitted)
	ThemeManager.theme_changed.connect(_apply_theme)
	_apply_theme()
	_update_columns()
	get_viewport().size_changed.connect(_update_columns)
	refresh()


## Число колонок сетки слотов для ширины design-экрана. Статик, чтобы тест
## проверял правило без инстанциирования сцены.
static func columns_for_width(width: int) -> int:
	if width >= WIDE_COLUMNS_WIDTH:
		return 3
	return 1


## Подгоняет колонки под текущую ширину окна: телефон — одна колонка
## сверху вниз, широкий десктоп — три.
func _update_columns() -> void:
	if _slots == null:
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	_slots.columns = columns_for_width(int(viewport.size.x))


## Подпись готовности. Считаются только полные записи: буква со словом и
## картинкой, но без звука, в играх не заиграет.
static func readiness_label(filled: int, total: int) -> String:
	if filled >= total:
		return "набор готов к играм"
	return "заполнено %d из %d" % [filled, total]


## Открывает набор на редактирование. Пустой или неизвестный id очищает экран.
func open_set(set_id: String) -> void:
	_set_id = set_id
	var record := CustomSetsStore.get_set_by_id(_set_id)
	_updating = true
	_name_edit.text = str(record.get("name", ""))
	_updating = false
	for letter: String in LETTERS:
		var entry := CustomSetsStore.get_entry(_set_id, letter)
		_slot(letter).setup(letter, str(entry.get("word", "")),
				_set_path(str(entry.get("image", ""))),
				_set_path(str(entry.get("audio", ""))))
	_update_readiness()
	GameLogger.info("SetEditor", "set_opened", {"set_id": _set_id})


## Сохраняет картинку буквы и пишет путь в метаданные. bytes — то, что отдал
## пикер; декодирование и сжатие делает ImageSaver.
##
## Отличие от плана — добавлена проверка открытого набора. План её не имел, и
## это стоило реальных файлов: при пустом _set_id путь
## CustomSetsStore.set_dir("") + image_file_name(буква) схлопывался в
## user://custom_sets/img_a.webp, то есть в корень КАТАЛОГА наборов, минуя
## подкаталог набора (ровно та ошибка, что Task 7 починил в своём тесте).
## Проверено на прогооне: apply_image() и apply_audio() отчитывались об успехе,
## писали мусор в корень, а set_entry() на пустом id возвращал false — и его
## возврат никто не смотрел, то есть родитель получал «сохранено» без записи.
## Авторитетна та же осторожность, что в save_name() этого же файла: там
## проверка _set_id.is_empty() есть. Каталог набора, как и положено, создаёт
## create_set(), и до первой записи он уже существует.
func apply_image(letter: String, bytes: PackedByteArray) -> Dictionary:
	if _set_id.is_empty():
		return _apply_fail(letter, "no_set", "не удалось сохранить картинку")
	if not _has_slot(letter):
		return _apply_error("bad_letter")
	var target := CustomSetsStore.set_dir(_set_id) + CustomSetsStore.image_file_name(letter)
	var saved := ImageSaver.save_image(bytes, target)
	if not bool(saved.get("ok", false)):
		var code := str(saved.get("error", "save_failed"))
		GameLogger.warning("SetEditor", "image_save_failed",
				{"letter": letter, "error": code})
		return _apply_fail(letter, code, "не удалось сохранить картинку")
	var entry := CustomSetsStore.get_entry(_set_id, letter)
	CustomSetsStore.set_entry(_set_id, letter, str(entry.get("word", "")), target,
			str(entry.get("audio", "")))
	_refresh_slot(letter)
	_update_readiness()
	return _apply_ok()


## Сохраняет аудиофайл буквы целиком, без перекодирования. [param extension]
## приходит от источника: запись с микрофона даёт WAV, загруженный файл
## сохраняет своё настоящее расширение. Переименовывать mp3 в .wav нельзя —
## Godot выбирает загрузчик по расширению, и файл просто не откроется.
func apply_audio(letter: String, bytes: PackedByteArray,
		extension: String = "wav") -> Dictionary:
	if _set_id.is_empty():
		return _apply_fail(letter, "no_set", "не удалось сохранить звук")
	if not _has_slot(letter):
		return _apply_error("bad_letter")
	if bytes.is_empty():
		return _apply_fail(letter, "no_bytes", "не удалось сохранить звук")
	var target := CustomSetsStore.set_dir(_set_id) \
			+ CustomSetsStore.audio_file_name(letter, extension)
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		GameLogger.warning("SetEditor", "audio_write_failed", {"letter": letter})
		return _apply_fail(letter, "write_failed", "не удалось сохранить звук")
	file.store_buffer(bytes)
	file.close()
	var entry := CustomSetsStore.get_entry(_set_id, letter)
	CustomSetsStore.set_entry(_set_id, letter, str(entry.get("word", "")),
			str(entry.get("image", "")), target)
	_refresh_slot(letter)
	_update_readiness()
	return _apply_ok()


## Сохраняет слово буквы. Запись остаётся неполной, пока нет медиа, —
## именно поэтому set_entry() и принимает частичные записи.
func save_word(letter: String, word: String) -> bool:
	if not _has_slot(letter):
		return false
	var trimmed := word.strip_edges()
	if trimmed.is_empty():
		return false
	var entry := CustomSetsStore.get_entry(_set_id, letter)
	return CustomSetsStore.set_entry(_set_id, letter, trimmed,
			str(entry.get("image", "")), str(entry.get("audio", "")))


## Переименовывает набор. Пустое имя отвергается.
func save_name(new_name: String) -> bool:
	if _set_id.is_empty():
		return false
	return CustomSetsStore.rename_set(_set_id, new_name.strip_edges())


## Убирает медиа буквы: файлы и ссылки в метаданных. Слово остаётся — родитель
## мог опечататься и хочет поправить текст, а не начинать букву заново.
func clear_letter_media(letter: String) -> bool:
	if not _has_slot(letter):
		return false
	var entry := CustomSetsStore.get_entry(_set_id, letter)
	for key: String in ["image", "audio"]:
		var stored := str(entry.get(key, ""))
		if stored.is_empty():
			continue
		var absolute := _set_path(stored)
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(absolute))
	CustomSetsStore.set_entry(_set_id, letter, str(entry.get("word", "")), "", "")
	_refresh_slot(letter)
	_update_readiness()
	return true


## Перечитывает набор из хранилища и обновляет все слоты и счётчик.
func refresh() -> void:
	if _set_id.is_empty():
		_readiness_label.text = readiness_label(0, LETTERS.size())
		return
	var record := CustomSetsStore.get_set_by_id(_set_id)
	_updating = true
	_name_edit.text = str(record.get("name", ""))
	_updating = false
	for letter: String in LETTERS:
		var entry := CustomSetsStore.get_entry(_set_id, letter)
		_slot(letter).setup(letter, str(entry.get("word", "")),
				_set_path(str(entry.get("image", ""))),
				_set_path(str(entry.get("audio", ""))))
	_update_readiness()


func get_set_id() -> String:
	return _set_id


## Слот буквы. Для неизвестной буквы — null, чтобы вызывающий не работал
## со случайным слотом.
func get_slot(letter: String) -> LetterSlot:
	return _slots_by_letter.get(letter) as LetterSlot


## Создаёт 33 слота и подписывает их на сигналы намерений.
func _build_slots() -> void:
	_slots_by_letter.clear()
	for child in _slots.get_children():
		child.queue_free()
	for letter: String in LETTERS:
		var slot: LetterSlot = LETTER_SLOT_SCENE.instantiate()
		_slots.add_child(slot)
		_slots_by_letter[letter] = slot
		slot.image_requested.connect(_on_image_requested)
		slot.audio_requested.connect(_on_audio_requested)
		slot.play_requested.connect(_on_play_requested)
		slot.clear_requested.connect(_on_clear_requested)
		slot.word_edited.connect(_on_word_edited)


## Абсолютный путь файла набора. Метаданные хранят путь относительно user://,
## а слотам и ImageSaver нужен абсолютный — иначе файл не найдётся.
func _set_path(relative: String) -> String:
	if relative.is_empty() or relative.begins_with("user://"):
		return relative
	return "user://" + relative


func _has_slot(letter: String) -> bool:
	return _slots_by_letter.has(letter)


func _slot(letter: String) -> LetterSlot:
	return _slots_by_letter[letter] as LetterSlot


## Перезаливает один слот из метаданных.
func _refresh_slot(letter: String) -> void:
	var entry := CustomSetsStore.get_entry(_set_id, letter)
	_slot(letter).setup(letter, str(entry.get("word", "")),
			_set_path(str(entry.get("image", ""))),
			_set_path(str(entry.get("audio", ""))))


## Считает полные записи и обновляет подпись.
func _update_readiness() -> void:
	var filled := 0
	for letter: String in LETTERS:
		if CustomSetsStore.is_entry_complete(_set_id, letter):
			filled += 1
	_readiness_label.text = readiness_label(filled, LETTERS.size())


func _apply_ok() -> Dictionary:
	return {"ok": true, "error": ""}


func _apply_error(code: String) -> Dictionary:
	return {"ok": false, "error": code}


## Ошибка применения, видимая человеку: код ошибки пишем в лог, а слот
## показывает понятное сообщение. Для несуществующей буквы слота нет —
## тогда остаётся только лог.
func _apply_fail(letter: String, code: String, message: String) -> Dictionary:
	if _has_slot(letter):
		_slot(letter).show_message(message)
	return _apply_error(code)


## Понятный текст для отказа пикера. cancelled — не ошибка, а обычный
## возврат без выбора; остальные коды означают, что файл не добрали.
func _pick_message(kind: String, error: String) -> String:
	if error == "cancelled":
		return "выбор отменён"
	if kind == "audio" and error == "unsupported_type":
		return "формат звука не поддерживается"
	if kind == "image":
		return "не удалось выбрать картинку"
	return "не удалось выбрать звук"


## Родитель нажал «Картинка»: берём файл и сразу отдаём его apply_image().
## Пока пикер открыт, слот показывает «выберите файл…», после отказа —
## причину. Молчание здесь выглядело как зависание на телефоне.
func _on_image_requested(letter: String) -> void:
	if not _has_slot(letter):
		return
	_slot(letter).show_message("выберите файл…")
	var picked := await WebFilePicker.pick("image")
	if not bool(picked.get("ok", false)):
		var error := str(picked.get("error", ""))
		GameLogger.info("SetEditor", "image_pick_failed",
				{"letter": letter, "error": error})
		_slot(letter).show_message(_pick_message("image", error))
		return
	_slot(letter).set_busy(true)
	apply_image(letter, picked.get("bytes", PackedByteArray()))
	_slot(letter).set_busy(false)


## Родитель нажал «Записать» или «Стоп»: кнопка звука — тумблер. Пока идёт
## запись этой же буквы, останавливаем; запись другой буквы игнорируем
## (вторая запись поверх первой затёрла бы первую); в обычном состоянии
## пробуем микрофон, при отказе — файл. Так работает и на телефоне, и на
## настольном браузере без разрешения.
func _on_audio_requested(letter: String) -> void:
	if _recording_letter == letter:
		_stop_recording_for(letter)
		return
	if _recording_letter != "":
		return
	var slot := _slot(letter)
	if VoiceRecord.prepare_microphone():
		if not VoiceRecord.start_recording():
			GameLogger.warning("SetEditor", "recording_start_failed",
					{"letter": letter})
			slot.show_message("не удалось записать звук")
			return
		_recording_letter = letter
		_record_stop_requested = false
		slot.set_recording(true)
		VoiceRecord.recording_finished.connect(_on_recording_finished, CONNECT_ONE_SHOT)
		GameLogger.info("SetEditor", "recording_started", {"letter": letter})
		_record_guard_token += 1
		var token := _record_guard_token
		await get_tree().create_timer(RECORD_DURATION).timeout
		if token == _record_guard_token and _recording_letter == letter \
				and VoiceRecord.is_recording():
			GameLogger.info("SetEditor", "recording_auto_stopped", {"letter": letter})
			_stop_recording_for(letter)
		return
	slot.show_message("выберите файл…")
	var picked := await WebFilePicker.pick("audio")
	if not bool(picked.get("ok", false)):
		var error := str(picked.get("error", ""))
		GameLogger.info("SetEditor", "audio_pick_failed",
				{"letter": letter, "error": error})
		slot.show_message(_pick_message("audio", error))
		return
	# Формат берём из mime браузера. iPhone отдаёт .m4a, и если сохранить его
	# под .wav, Godot не найдёт для него загрузчик и звук не заиграет.
	var extension := CustomSetsStore.extension_for_mime(str(picked.get("mime", "")))
	if extension.is_empty():
		GameLogger.info("SetEditor", "audio_mime_unsupported",
				{"letter": letter, "mime": str(picked.get("mime", ""))})
		slot.show_message("формат звука не поддерживается")
		return
	slot.set_busy(true)
	apply_audio(letter, picked.get("bytes", PackedByteArray()), extension)
	slot.set_busy(false)


## Останавливает запись конкретной буквы по кнопке «Стоп» или автостопом.
## stop_recording() синхронно эмитит recording_finished, и дальше состояние
## приводит _on_recording_finished(). Если запись уже не идёт (сбой шины),
## чистим состояние сами, чтобы слот не навсегда остался в «запись…».
func _stop_recording_for(letter: String) -> void:
	_record_stop_requested = true
	if VoiceRecord.is_recording():
		VoiceRecord.stop_recording()
		return
	_on_recording_finished(VoiceRecord.has_data())


## Запись закончилась: сохраняем WAV, если микрофон что-то услышал.
func _on_recording_finished(_has_data: bool) -> void:
	var letter := _recording_letter
	var stop_requested := _record_stop_requested
	_recording_letter = ""
	_record_stop_requested = false
	if letter.is_empty() or not _has_slot(letter):
		return
	_slot(letter).set_recording(false)
	if not VoiceRecord.has_data():
		GameLogger.info("SetEditor", "recording_empty", {"letter": letter})
		# «Ничего не записалось» показываем только когда запись остановили мы:
		# тестовый сигнал без нашего стопа не должен затирать подпись состояния.
		if stop_requested:
			_slot(letter).show_message("ничего не записалось, попробуйте снова")
		return
	# Именно get_wav_bytes(), а не get_data(): второй отдаёт сырой PCM без
	# заголовка, и такой файл с расширением .wav не загрузится.
	apply_audio(letter, VoiceRecord.get_wav_bytes(), "wav")
	VoiceRecord.clear()


## Прослушивание: играем файл набора через общий аудиоплеер.
func _on_play_requested(letter: String) -> void:
	var entry := CustomSetsStore.get_entry(_set_id, letter)
	var path := _set_path(str(entry.get("audio", "")))
	if path.is_empty() or not FileAccess.file_exists(path):
		GameLogger.info("SetEditor", "play_missing", {"letter": letter})
		return
	var stream := AudioStreamWAV.new()
	stream.data = FileAccess.get_file_as_bytes(path)
	AudioManager.play_stream(stream)


func _on_clear_requested(letter: String) -> void:
	clear_letter_media(letter)


func _on_word_edited(letter: String, word: String) -> void:
	save_word(letter, word)
	_update_readiness()


func _on_name_submitted(new_name: String) -> void:
	if not save_name(new_name):
		# Имя не принято — возвращаем в поле то, что реально сохранено.
		_updating = true
		_name_edit.text = str(CustomSetsStore.get_set_by_id(_set_id).get("name", ""))
		_updating = false


func _on_save_pressed() -> void:
	save_name(_name_edit.text)
	set_saved.emit(_set_id)
	GameLogger.info("SetEditor", "set_saved", {"set_id": _set_id})


## Родитель нажал «Назад»: единственный путь выхода из редактора. Редактор
## сам не знает, куда возвращать, поэтому объявляет намерение сигналом, а
## навигацией занимается SetList. Раньше сигнал был объявлен и подключён, но
## не эмитился нигде, и список звал _show_list() напрямую — объявленный API
## был мёртвым, а путь назад был неявным.
func _on_back_pressed() -> void:
	close_requested.emit()
	GameLogger.info("SetEditor", "close_requested", {"set_id": _set_id})


## Карточка и кнопки красятся под тему, как в LetterSlot.
func _apply_theme(_mode: int = 0) -> void:
	var colors: Dictionary = ThemeManager.COLORS[ThemeManager.current_theme]
	_name_edit.add_theme_color_override("font_color", ThemeManager.get_text())
	_readiness_label.add_theme_color_override("font_color", ThemeManager.get_text())
	ThemeManager.style_button(_save_button, colors["button_bg"] as Color,
			colors["button_text"] as Color)
	ThemeManager.style_button(_back_button, colors["button_bg"] as Color,
			colors["button_text"] as Color)
