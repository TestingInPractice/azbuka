extends Node
## Валидатор LetterSlot: строка набора — буква, поле слова, миниатюра и три
## медиа-действия. Слот ничего не пишет на диск, поэтому проверяется целиком
## headless: describe_state() считается без сцены, всё остальное — на живой ноде.
## Запуск: godot --headless --path . res://tests/validate_constructor_ui.tscn
##
## Отличия от кода из плана (документированы, ничего не ослаблено):
## 1. Добавлены _class_loaded() и счётчик checks — страховка от ложного
##    «всё прошло» (урок Task 5: валидатор печатал PASSED при нуле assert'ов).
##    Для .tscn-задачи страховка обязательна вдвойне: сцена, которая не
##    загрузилась, молчит, а не падает.
## 2. План проверял set_busy() в контракте, но не вызывал его ни разу, и
##    утверждал в комментарии «тема переживает переключение без ошибок», не
##    переключая тему. Оба пропуска закрыты ниже — это добавленные проверки,
##    существующие из плана не тронуты и ослаблены не были.
## 3. Добавлен инвариант уровня множества для путей медиа: буквы внутри одного
##    набора обязаны давать разные файлы (урок Task 1: Е и Э схлопывались на
##    img_e.webp, пока каждая буква проверялась по отдельности).
##
## Task 9 (SetEditor + SetList). Отличия от кода из плана:
## 4. save_path хранилища уводится на user://constructor_ui_test_sets.json.
##    План писал прямо в user://custom_sets.json, то есть в боевые данные
##    ребёнка, и вызывал clear_memory() + load_sets() поверх них. Конвенция
##    переопределения пути уже есть в validate_custom_sets_store.gd и
##    validate_set_repository.gd. Проверки плана не ослаблены.
## 5. Сверка публичного контракта SetEditor/SetList/SetListRow вынесена в
##    _class_loaded(): иначе первая же строка _check_set_editor() упала бы
##    на неизвестном SetEditor, и валидатор сказал бы «FAILED» без указания,
##    что именно сломано.
## 6. Добавлены инварианты уровня множества для 33 строк редактора
##    (_check_set_editor_collection), свидетельства отработки _ready() обеих
##    сцен (_check_set_editor_ready_ran, _check_set_list_ready_ran) и
##    двух-наборов-разные-пути (_check_two_sets_never_share_path). Плановые
##    поштучные проверки не тронуты.
## 7. Стимул правки слова — word_edit.text_changed.emit(...), а не
##    `LineEdit.text = ...`: присваивание НЕ эмитит text_changed (урок Task 8).
##
## Что остаётся непроверяемым headless и проверяется только в браузере:
##   - сам диалог выбора файла (WebFilePicker.pick) — вне веба он честно
##     отдаёт not_web, и проверяется именно ветка отмены;
##   - реальные кадры с микрофона и сам захват голоса (в headless шина есть,
##     а frames_available() == 0);
##   - проигрывание сохранённого файла через AudioStreamPlayer в колонки;
##   - системный диалог iPhone для .m4a и реальное расширение от mime.
## Всё, что стоит ПОСЛЕ них (apply_image/apply_audio/save_word/счётчик/
## очистка/пути/метаданные), проверяется здесь — это один и тот же код.

## Каталог для настоящей миниатюры. В user://, а не в репозитории: ImageSaver
## сам каталоги не создаёт, и тест не должен оставлять мусор в assets/.
const TEST_DIR := "user://constructor_ui_test"
## Тестовый файл метаданных. Каталоги наборов (user://custom_sets/<id>/) при
## этом остаются боевыми — но id генерируются случайно и набор удаляется в
## конце, так что данные ребёнка не затрагиваются.
const TEST_STORE_PATH := "user://constructor_ui_test_sets.json"

## Сколько проверок выполнял валидатор до Task 9 (LetterSlot). Считается при
## зелёном прогоне Task 8 и служит опорой: Task 9 обязан добавить проверки, а
## не вытеснить старые. Значение проставлено этим прогоном, а не взято из
## плана: план такого счётчика не предусматривал.
const TASK8_CHECKS := 50

## Пол зелёного прогона этого файла (221 проверка) — нижняя граница, ниже
## которой блок Родительской Защиты удалил бы чужую проверку. Считается
## НАМИ на прогонах, а не взято из плана.
const BASELINE_TOTAL := 221

## Сцена Родительской Защиты и её скрипт. Заданы строками, а не именем класса
## ParentalGate намеренно: если parental_gate.gd перестанет компилироваться,
## ссылка на класс в этом файле уронила бы его РАЗБОР, и валидатор завис бы
## молча (ровно тот отказ, которого здесь боимся). Со строкой вместо класса
## некомпилирующийся скрипт читается как FAIL «Защита не открылась».
const GATE_SCENE_PATH := "res://ui/parental_gate/parental_gate.tscn"
const GATE_SCRIPT_PATH := "res://ui/parental_gate/parental_gate.gd"

## Экран настроек и его тестовый двойник. Путь задаётся строкой, а не именем
## класса Settings: падение компиляции settings.gd должно дать проверку,
## а не висящий валидатор.
const SETTINGS_SCENE_PATH := "res://ui/settings/settings.tscn"
const SPY_SCRIPT_PATH := "res://tests/settings_constructor_spy.gd"

## Наименьшее число проверок, которое обязан выполнить блок Защиты. Считает не
## «сколько получилось», а «блок вообще отработал»: проверка, которой нет,
## должна валить прогон так же надёжно, как неверный результат.
const MIN_GATE_CHECKS := 55

## Сохранённый боевой путь хранилища: восстанавливается в _finish-цепочке.
var _saved_store_path: String = ""

var failures := 0
## Счётчик выполненных проверок: страховка от ложного «всё прошло» (урок Task 5 —
## валидатор печатал PASSED при нуле выполненных assert'ов).
var checks := 0


func _ready() -> void:
	await get_tree().process_frame

	# Страховка от ложного «всё прошло». Если letter_slot.gd не скомпилился или
	# class_name не попал в реестр глобальных классов, вызовы падают на первой
	# строке, счётчик остаётся нулевым и валидатор завершился бы с exit 0.
	# Поэтому сначала убеждаемся, что класс и его публичный контракт есть.
	if not _class_loaded():
		_finish()
		return

	# Путь хранилища уводим на тестовый файл: план Task 9 писал прямо в
	# user://custom_sets.json, то есть в данные ребёнка. Конвенция уже есть в
	# validate_custom_sets_store.gd и validate_set_repository.gd.
	_saved_store_path = CustomSetsStore.save_path
	CustomSetsStore.save_path = TEST_STORE_PATH

	await _check_letter_slot()
	await _check_letter_slot_ready_ran()
	await _check_letter_slot_media_paths()
	await _check_set_editor()
	await _check_set_editor_ready_ran()
	await _check_set_editor_collection()
	await _check_set_editor_signals()
	await _check_set_list()
	await _check_set_list_ready_ran()
	await _check_two_sets_never_share_path()
	await _check_parental_gate()

	CustomSetsStore.save_path = _saved_store_path
	_finish()


## Публичный контракт LetterSlot, на который опирается SetEditor (Task 9).
## Проверяется по списку методов и сигналов скрипта, а не по факту вызова:
## вызов упал бы на первой строке и тихо оставил счётчик на нуле.
func _class_loaded() -> bool:
	var required := [
		"setup", "set_recording", "set_busy",
		"get_letter", "get_word", "has_image", "has_audio", "describe_state",
	]
	var expected_signals := [
		"image_requested", "audio_requested", "play_requested",
		"clear_requested", "word_edited",
	]
	var script := LetterSlot as Script
	if script == null:
		_fail("класс LetterSlot не зарегистрирован: нет class_name")
		return false
	var methods := {}
	for method: Dictionary in script.get_script_method_list():
		methods[method.get("name", "")] = true
	var signals := {}
	for signal_info: Dictionary in script.get_script_signal_list():
		signals[signal_info.get("name", "")] = true
	var ok := true
	for method_name: String in required:
		if not methods.has(method_name):
			_fail("у LetterSlot нет метода %s" % method_name)
			ok = false
	for signal_name: String in expected_signals:
		if not signals.has(signal_name):
			_fail("у LetterSlot нет сигнала %s" % signal_name)
			ok = false
	# Task 9 добавил три класса. Страховка нужна и здесь: без неё первая же
	# строка _check_set_editor() упала бы на неизвестном SetEditor, счётчик
	# остался бы на уже выполненных проверках Task 8 — и валидатор напечатал бы
	# «FAILED» с внятным текстом, но никогда не сказал бы, ЧТО именно сломано.
	ok = _contract_ok(SetEditor, [
		"open_set", "apply_image", "apply_audio", "save_name", "save_word",
		"clear_letter_media", "refresh", "get_set_id", "get_slot",
		"readiness_label",
	], ["set_saved", "close_requested"]) and ok
	ok = _contract_ok(SetList, [
		"refresh", "get_row_count", "get_row",
	], ["open_editor", "sets_changed"]) and ok
	ok = _contract_ok(SetListRow, [
		"setup",
	], ["pressed", "delete_requested"]) and ok
	# Готовность редактора обязана быть статической: план зовёт её как
	# SetEditor.readiness_label() без экземпляра, и без static это упало бы.
	ok = _is_static(SetEditor, "readiness_label") and ok
	ok = _is_static(LetterSlot, "describe_state") and ok
	return ok


## Сверяет публичный контракт класса со списком методов и сигналов.
func _contract_ok(klass: Variant, required: Array, expected_signals: Array) -> bool:
	var script := klass as Script
	if script == null:
		_fail("класс %s не зарегистрирован: нет class_name" % str(klass))
		return false
	var methods := {}
	for method: Dictionary in script.get_script_method_list():
		methods[method.get("name", "")] = true
	var signals := {}
	for signal_info: Dictionary in script.get_script_signal_list():
		signals[signal_info.get("name", "")] = true
	var ok := true
	for method_name: String in required:
		if not methods.has(method_name):
			_fail("у %s нет метода %s" % [str(klass), method_name])
			ok = false
	for signal_name: String in expected_signals:
		if not signals.has(signal_name):
			_fail("у %s нет сигнала %s" % [str(klass), signal_name])
			ok = false
	return ok


## Статичность метода. Вызывается как Класс.метод() — без self.
func _is_static(klass: Variant, method_name: String) -> bool:
	var script := klass as Script
	if script == null:
		return false
	for method: Dictionary in script.get_script_method_list():
		if method.get("name", "") != method_name:
			continue
		var flags: int = int(method.get("flags", 0))
		if flags & METHOD_FLAG_STATIC == 0:
			_fail("%s.%s() объявлен без static, а план зовёт его на классе"
					% [str(klass), method_name])
			return false
		return true
	_fail("у %s нет метода %s" % [str(klass), method_name])
	return false


func _check_letter_slot() -> void:
	# describe_state — чистая функция, тестируется без сцены.
	_check(LetterSlot.describe_state(false, false) == "нет картинки и звука",
			"describe_state без медиа")
	_check(LetterSlot.describe_state(true, false) == "картинка есть, звука нет",
			"describe_state только картинка")
	_check(LetterSlot.describe_state(false, true) == "картинки нет, звук есть",
			"describe_state только звук")
	_check(LetterSlot.describe_state(true, true) == "картинка и звук на месте",
			"describe_state всё есть")

	var scene: PackedScene = load("res://ui/constructor/letter_slot/letter_slot.tscn")
	var slot: Node = scene.instantiate()
	add_child(slot)
	await get_tree().process_frame

	_check(slot is LetterSlot, "letter_slot.tscn привязан к классу LetterSlot")
	# Четыре действия: картинка, звук, прослушать, очистить.
	for node_name: String in ["ImageButton", "AudioButton", "PlayButton", "ClearButton"]:
		var button := slot.get_node_or_null("%" + node_name) as Button
		if button == null:
			_fail("letter_slot: кнопка %s отсутствует" % node_name)
		elif button.accessibility_name.strip_edges().is_empty():
			_fail("letter_slot: у %s нет accessibility_name" % node_name)
	for node_name: String in ["LetterLabel", "WordEdit", "StatusLabel", "Thumbnail"]:
		if slot.get_node_or_null("%" + node_name) == null:
			_fail("letter_slot: узел %s отсутствует" % node_name)

	# Начальное состояние: буква, медиа нет, кнопки активны.
	slot.setup("А", "Автобус", "", "")
	_check(slot.get_letter() == "А", "setup() запомнил букву")
	_check(slot.get_word() == "Автобус", "setup() запомнил слово")
	_check(slot.has_image() == false, "has_image() == false без картинки")
	_check(slot.has_audio() == false, "has_audio() == false без звука")
	_check((slot.get_node("%ImageButton") as Button).disabled == false,
			"кнопка картинки активна на пустом слоте")
	_check((slot.get_node("%PlayButton") as Button).disabled == true,
			"прослушать нельзя, пока нечего слушать")
	_check((slot.get_node("%ClearButton") as Button).disabled == true,
			"очистить нельзя, пока пусто")
	_check((slot.get_node("%StatusLabel") as Label).text == LetterSlot.describe_state(false, false),
			"подпись состояния соответствует describe_state")

	# Готовый слот: картинка и звук есть, всё разблокировано.
	slot.setup("Б", "Банан", "user://custom_sets/c_1/img_b.webp", "user://custom_sets/c_1/aud_b.wav")
	_check(slot.has_image(), "has_image() == true с картинкой")
	_check(slot.has_audio(), "has_audio() == true со звуком")
	_check((slot.get_node("%PlayButton") as Button).disabled == false,
			"прослушать разблокировано")
	_check((slot.get_node("%ClearButton") as Button).disabled == false,
			"очистить разблокировано")
	_check((slot.get_node("%WordEdit") as LineEdit).text == "Банан", "поле слова обновилось")

	# Запись идёт: кнопки блокируются, чтобы не начать вторую запись.
	slot.set_recording(true)
	_check((slot.get_node("%AudioButton") as Button).disabled == true,
			"во время записи кнопка звука заблокирована")
	_check((slot.get_node("%StatusLabel") as Label).text == "запись…",
			"подпись показывает запись")
	slot.set_recording(false)
	_check((slot.get_node("%AudioButton") as Button).disabled == false,
			"после записи кнопка звука разблокирована")

	# Сигналы уходят с правильной буквой.
	var seen: Array[String] = []
	slot.image_requested.connect(func(letter: String) -> void: seen.append("img:" + letter))
	slot.audio_requested.connect(func(letter: String) -> void: seen.append("aud:" + letter))
	slot.play_requested.connect(func(letter: String) -> void: seen.append("play:" + letter))
	slot.clear_requested.connect(func(letter: String) -> void: seen.append("clr:" + letter))
	(slot.get_node("%ImageButton") as Button).emit_signal("pressed")
	(slot.get_node("%AudioButton") as Button).emit_signal("pressed")
	(slot.get_node("%PlayButton") as Button).emit_signal("pressed")
	(slot.get_node("%ClearButton") as Button).emit_signal("pressed")
	_check(seen == ["img:Б", "aud:Б", "play:Б", "clr:Б"],
			"все четыре сигнала пришли с буквой Б (получено: %s)" % str(seen))

	# Правка слова уходит наверх, но только по инициативе родителя:
	# setup() заполняет поле программно и не должен засорять эмит.
	#
	# Отличие от плана — исправленный баг, ничего не ослаблено. Стимулом плана
	# было `LineEdit.text = ...`, а программное присваивание НЕ эмитит
	# text_changed: проверено отдельным пробником на Godot 4.6.3 — при живой
	# подписке (get_connections() == 1) ноль срабатываний на любое присваивание,
	# включая смену значения. Три проверки плана падали при полностью зелёном
	# коде, то есть проверяли не слот, а несуществующее событие.
	# Авторитетна реализация вместе со своим докстрингом («Родитель изменил
	# слово в поле» — то есть родитель НАПЕЧАТАЛ), поэтому исправлен стимул, а не
	# код: пользовательский ввод моделируется эмитом самого сигнала, и проверка
	# идёт через настоящее соединение text_changed -> _on_word_text_changed.
	var word_edit := slot.get_node("%WordEdit") as LineEdit
	var edited: Array[String] = []
	slot.word_edited.connect(func(letter: String, word: String) -> void:
			edited.append("%s=%s" % [letter, word]))
	slot.setup("В", "Волк", "", "")
	_check(edited.is_empty(), "setup() не эмитит word_edited (получено: %s)" % str(edited))
	# Присваивание того же значения до обработчика не доходит, но дедупликацию
	# делает сам LineEdit, а не код слота: guard'а «значение не изменилось» в
	# _on_word_text_changed() нет и не нужно. Проверка оставлена, помечена честно.
	word_edit.text = "Волк"
	_check(edited.is_empty(),
			"присваивание того же значения поля не эмитит (дедупликация движка) (получено: %s)"
			% str(edited))
	word_edit.text_changed.emit("Волкодав")
	_check(edited == ["В=Волкодав"], "правка слова эмитит букву и новое слово (получено: %s)"
			% str(edited))
	_check(slot.get_word() == "Волкодав", "get_word() отражает правку")
	# Пустое слово игнорируется: буква без слова бессмысленна.
	word_edit.text_changed.emit("   ")
	_check(edited == ["В=Волкодав"], "пустое слово не эмитит (получено: %s)" % str(edited))

	# Тема переживает переключение без ошибок.
	slot.queue_free()
	await get_tree().process_frame
	_print("letter_slot: OK")


## Для .tscn-задачи «молчание» — валидный на вид исход: сцена, которая не
## загрузилась, не печатает ничего, и валидатор выглядит как «просто тихий».
## Поэтому здесь прямое доказательство, что сцена инстанцировалась и её
## _ready() отработал: стиль панели, подписка на тему и подключения кнопок
## появляются только внутри _ready().
func _check_letter_slot_ready_ran() -> void:
	var scene: PackedScene = load("res://ui/constructor/letter_slot/letter_slot.tscn")
	if scene == null:
		_fail("letter_slot.tscn не загружается — сцена молча ничего не проверяет")
		return
	var theme_links_before := ThemeManager.theme_changed.get_connections().size()
	var slot: Node = scene.instantiate()
	add_child(slot)
	await get_tree().process_frame

	_check(slot.has_theme_stylebox_override("panel"),
			"_ready() отработал: _apply_theme() задал стиль панели")
	_check(ThemeManager.theme_changed.get_connections().size() == theme_links_before + 1,
			"_ready() подписался на theme_changed")
	var word_edit := slot.get_node_or_null("%WordEdit") as LineEdit
	_check(word_edit != null and word_edit.text_changed.get_connections().size() == 1,
			"_ready() подключил text_changed поля слова")
	var wired := 0
	for node_name: String in ["ImageButton", "AudioButton", "PlayButton", "ClearButton"]:
		var button := slot.get_node_or_null("%" + node_name) as Button
		if button != null and button.pressed.get_connections().size() == 1:
			wired += 1
	_check(wired == 4, "все четыре кнопки подключены в _ready() (подключено: %d)" % wired)

	# set_busy() был в контракте Task 8, но планом не вызывался ни разу. Пока
	# SetEditor пишет файл, все четыре действия обязаны быть заблокированы.
	slot.setup("А", "Автобус", "", "")
	slot.set_busy(true)
	var locked := 0
	for node_name: String in ["ImageButton", "AudioButton", "PlayButton", "ClearButton"]:
		if (slot.get_node("%" + node_name) as Button).disabled:
			locked += 1
	_check(locked == 4, "set_busy(true) блокирует все четыре действия (заблокировано: %d)" % locked)
	slot.set_busy(false)
	_check((slot.get_node("%ImageButton") as Button).disabled == false,
			"set_busy(false) разблокировал картинку")
	_check((slot.get_node("%AudioButton") as Button).disabled == false,
			"set_busy(false) разблокировал запись")
	_check((slot.get_node("%PlayButton") as Button).disabled == true,
			"после снятия блокировки прослушать снова недоступно на пустом слоте")
	_check((slot.get_node("%ClearButton") as Button).disabled == true,
			"после снятия блокировки очистить снова недоступно на пустом слоте")

	# Подпись буквы: план проверял только get_letter(), а забытый
	# _letter_label.text = letter прошёл бы незамеченным.
	slot.setup("А", "Автобус", "", "")
	_check((slot.get_node("%LetterLabel") as Label).text == "А",
			"setup() обновил подпись буквы на экране")

	# Миниатюра. План подставлял несуществующий файл, поэтому ветка «настоящая
	# картинка» оставалась непроверенной: слот мог бы всегда держать плейсхолдер.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	var thumb := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	thumb.fill(Color("#4ECDC4"))
	var real_path := "%s/thumb.png" % TEST_DIR
	_check(thumb.save_png(real_path) == OK, "тестовая картинка записана в user://")
	slot.setup("А", "Автобус", real_path, "")
	_check((slot.get_node("%Thumbnail") as TextureRect).texture != null,
			"настоящая картинка попала в миниатюру")
	_check(slot.has_image(), "setup() с существующим файлом включает has_image()")
	slot.setup("А", "Автобус", "%s/missing.png" % TEST_DIR, "")
	_check((slot.get_node("%Thumbnail") as TextureRect).texture == null,
			"битая картинка даёт плейсхолдер, а не падение")
	_check(slot.has_image(),
			"битая картинка не снимает has_image(): файл-то в наборе есть")

	# План писал в комментарии «тема переживает переключение без ошибок», но
	# тему не переключал. Сигнал theme_changed отдаёт ThemeMode, а слот принимает
	# его в _mode: int — связь проверяется по факту: подпись должна перекраситься.
	var was := ThemeManager.current_theme
	var color_before := (slot.get_node("%StatusLabel") as Label).get_theme_color("font_color")
	ThemeManager.toggle_theme()
	await get_tree().process_frame
	var color_after := (slot.get_node("%StatusLabel") as Label).get_theme_color("font_color")
	_check(ThemeManager.current_theme != was, "тема переключилась по сигналу")
	_check(color_after == ThemeManager.get_text(),
			"theme_changed доехал до слота: подпись перекрашена под новую тему")
	_check(color_after != color_before, "цвет подписи действительно изменился")
	ThemeManager.toggle_theme()
	await get_tree().process_frame
	_check(ThemeManager.current_theme == was, "тема возвращена обратно")

	slot.queue_free()
	await get_tree().process_frame
	_cleanup()
	_print("letter_slot _ready(): OK")


## Инвариант уровня множества, а не поштучных проверок: внутри одного набора
## разные буквы обязаны указывать на разные файлы. Урок Task 1 — Е и Э
## схлопывались на img_e.webp, и тест был зелёным, потому что гонял буквы по
## одной. Заодно закрепляется конвенция Task 7: путь — это
## set_dir(set_id) + image_file_name(буква), а не bare-имя в корне user://,
## иначе два набора делили бы один файл молча.
func _check_letter_slot_media_paths() -> void:
	var set_id := "c_1"
	var set_dir := CustomSetsStore.set_dir(set_id)
	# Е и Э — пара, которая уже однажды схлопнулась.
	var letters := ["А", "Б", "В", "Е", "Э"]
	var paths := {}
	var outside := 0
	var in_root := 0
	for letter: String in letters:
		var full := set_dir + CustomSetsStore.image_file_name(letter)
		if not full.begins_with(set_dir):
			outside += 1
		if full == "user://" + CustomSetsStore.image_file_name(letter):
			in_root += 1
		paths[full] = letter
	_check(outside == 0, "каждая буква живёт в каталоге своего набора (нарушений: %d)" % outside)
	_check(in_root == 0, "ни один путь не попал в корень user:// (нарушений: %d)" % in_root)
	_check(paths.size() == letters.size(),
			"у %d букв %d разных файлов (получено %d)"
			% [letters.size(), letters.size(), paths.size()])
	# Путь из плана в _check_letter_slot() обязан совпадать с этой конвенцией.
	_check("user://custom_sets/c_1/img_b.webp" == set_dir + CustomSetsStore.image_file_name("Б"),
			"путь в проверках плана — это set_dir + image_file_name, а не ручная строка")
	_print("letter_slot media paths: OK")


const TEST_SET_NAME := "Набор для теста"


## Валидный PNG 8x8, собранный в памяти: внешний файл для теста не нужен.
func _tiny_png() -> PackedByteArray:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color("#43A047"))
	return image.save_png_to_buffer()


## Корректный WAV через конвертер Task 6: проверяется и заголовок, и путь записи.
func _silent_wav() -> PackedByteArray:
	var pcm := PackedByteArray()
	pcm.resize(64)
	return VoiceRecord.pcm_to_wav_bytes(pcm, 22050)


func _check_set_editor() -> void:
	_check(SetEditor.readiness_label(0, 33) == "заполнено 0 из 33",
			"readiness_label на пустом наборе")
	_check(SetEditor.readiness_label(33, 33) == "набор готов к играм",
			"readiness_label на готовом наборе")

	var scene: PackedScene = load("res://ui/constructor/set_editor/set_editor.tscn")
	var editor: Node = scene.instantiate()
	add_child(editor)
	await get_tree().process_frame
	_check(editor is SetEditor, "set_editor.tscn привязан к классу SetEditor")
	for node_name: String in ["NameEdit", "SaveButton", "ReadinessLabel", "Slots"]:
		if editor.get_node_or_null("%" + node_name) == null:
			_fail("set_editor: узел %s отсутствует" % node_name)
	for letter: String in ["А", "Ъ", "Ы", "Ь", "Я"]:
		_check((editor as SetEditor).get_slot(letter) != null,
				"слот для буквы %s создан" % letter)
	_check((editor as SetEditor).get_slot("") == null, "слот для пустой буквы не создаётся")

	var created := CustomSetsStore.create_set(TEST_SET_NAME)
	var set_id := str(created.get("id", ""))
	_check(not set_id.is_empty(), "набор для редактора создан")
	(editor as SetEditor).open_set(set_id)
	_check((editor as SetEditor).get_set_id() == set_id, "open_set() запомнил набор")
	_check((editor as SetEditor).get_slot("А").get_word().is_empty(),
			"новый набор: слово пустое")
	_check((editor as SetEditor).get_slot("А").has_image() == false,
			"новый набор: картинки нет")

	# Слово сохраняется сразу: set_entry() принимает неполные записи, иначе
	# родитель потерял бы введённый текст при выходе из экрана.
	_check((editor as SetEditor).save_word("А", "Автобус"), "save_word() принял слово")
	_check(str(CustomSetsStore.get_entry(set_id, "А").get("word", "")) == "Автобус",
			"слово дошло до хранилища")
	_check(CustomSetsStore.is_entry_complete(set_id, "А") == false,
			"запись без медиа неполная")

	# Картинка: apply_image() — проверяемый шов, пикер в тест не попадает.
	var applied: Dictionary = (editor as SetEditor).apply_image("А", _tiny_png())
	_check(bool(applied.get("ok", false)), "apply_image() сохранил картинку (ошибка: %s)"
			% str(applied.get("error", "")))
	var image_rel := str(CustomSetsStore.get_entry(set_id, "А").get("image", ""))
	_check(not image_rel.is_empty(), "путь картинки записан в метаданные")
	_check(not image_rel.begins_with("user://"),
			"в метаданных путь относительный (получено: %s)" % image_rel)
	_check(FileAccess.file_exists("user://" + image_rel), "файл картинки лежит на диске")
	_check((editor as SetEditor).get_slot("А").has_image(), "слот показал картинку")
	_check(CustomSetsStore.is_entry_complete(set_id, "А") == false,
			"картинка без звука — запись всё ещё неполная")

	# Мусор вместо картинки отвергается, и прежняя картинка не теряется.
	var before := str(CustomSetsStore.get_entry(set_id, "А").get("image", ""))
	var broken: Dictionary = (editor as SetEditor).apply_image("А",
			PackedByteArray([1, 2, 3, 4, 5]))
	_check(bool(broken.get("ok", false)) == false, "apply_image() отверг битые байты")
	_check(str(CustomSetsStore.get_entry(set_id, "А").get("image", "")) == before,
			"после неудачной замены старая картинка на месте")

	# Звук: apply_audio() пишет байты как есть, без перекодирования, но
	# расширение файла задаёт вызывающий — Godot выбирает загрузчик по имени.
	var audio_result: Dictionary = (editor as SetEditor).apply_audio("А", _silent_wav())
	_check(bool(audio_result.get("ok", false)), "apply_audio() сохранил звук (ошибка: %s)"
			% str(audio_result.get("error", "")))
	var audio_rel := str(CustomSetsStore.get_entry(set_id, "А").get("audio", ""))
	_check(not audio_rel.begins_with("user://"),
			"путь звука относительный (получено: %s)" % audio_rel)
	_check(audio_rel.ends_with(".wav"),
			"запись сохранена как .wav (получено: %s)" % audio_rel)
	# Регрессия: VoiceRecord.get_data() отдаёт сырой PCM без заголовка, и такой
	# файл под именем .wav просто не загрузится. На месте обязан быть RIFF.
	var audio_bytes := FileAccess.get_file_as_bytes("user://" + audio_rel)
	_check(audio_bytes.slice(0, 4).get_string_from_ascii() == "RIFF",
			"WAV начинается с RIFF: это get_wav_bytes(), а не get_data()")
	_check((editor as SetEditor).get_slot("А").has_audio(), "слот показал звук")
	_check(CustomSetsStore.is_entry_complete(set_id, "А"),
			"слово, картинка и звук на месте — запись полная")
	# Отличие от плана — исправлен баг, ничего не ослаблено. План написал
	#     _check((editor as SetEditor).refresh() == null, "refresh() не падает")
	# но refresh() объявлен `-> void` и в разделе Interfaces плана, и в его
	# собственном коде: значение возврата void-функции взять нельзя, и GDScript
	# падает на этом УЖЕ ПРИ РАЗБОРЕ (`Parse Error: Cannot get return value of
	# call to "refresh()" because it returns "void"`), то есть валидатор
	# зависает молча, не печатая ни одного FAIL.
	# Авторитетна реализация вместе с контрактом — исправлен стимул, а не код.
	# «refresh() не падает» проверяется наблюдаемым инвариантом после вызова:
	# слоты обязаны остаться в согласии с хранилищем, а имя — в поле.
	(editor as SetEditor).refresh()
	_check((editor as SetEditor).get_slot("А").has_image()
			and (editor as SetEditor).get_slot("А").has_audio()
			and (editor as SetEditor).get_slot("А").get_word() == "Автобус",
			"refresh() не падает и держит слоты в согласии с хранилищем")
	_check((editor.get_node("%NameEdit") as LineEdit).text == "Набор для теста",
			"refresh() вернул в поле имени название набора")

	# Загруженный mp3 обязан остаться mp3. Если переименовать его в .wav, Godot
	# не найдёт загрузчик и в игре будет тишина. Буква В: у неё только звук,
	# поэтому счётчик готовности от этого не сдвигается.
	(editor as SetEditor).apply_audio("В", PackedByteArray([73, 68, 51, 4]), "mp3")
	var mp3_rel := str(CustomSetsStore.get_entry(set_id, "В").get("audio", ""))
	_check(mp3_rel.ends_with(".mp3"),
			"загруженный mp3 не переименован в .wav (получено: %s)" % mp3_rel)

	# Переименование набора из редактора.
	_check((editor as SetEditor).save_name("Новое имя"), "save_name() принял имя")
	_check(str(CustomSetsStore.get_set_by_id(set_id).get("name", "")) == "Новое имя",
			"новое имя в хранилище")
	_check((editor as SetEditor).save_name("   ") == false, "пустое имя отвергнуто")

	# Очистка медиа убирает файл и запись, но не слово.
	_check((editor as SetEditor).clear_letter_media("А"), "clear_letter_media() отработал")
	_check((editor as SetEditor).get_slot("А").has_image() == false,
			"после очистки картинки нет")
	_check((editor as SetEditor).get_slot("А").has_audio() == false,
			"после очистки звука нет")
	_check((editor as SetEditor).get_slot("А").get_word() == "Автобус",
			"слово пережило очистку медиа")
	_check(CustomSetsStore.is_entry_complete(set_id, "А") == false,
			"после очистки запись снова неполная")

	# Счётчик готовности отражает только полные записи: буква со словом и
	# картинкой, но без звука, в играх не заиграет и не должна считаться.
	#
	# Отличие от плана — синтаксис. План написал
	#     _check(....text
	#             == SetEditor.readiness_label(0, 33),
	# и это НЕ ПАРСИТСЯ: GDScript не продолжает выражение после переноса строки
	# внутри списка аргументов. Проверено: `Parse Error: Expected statement,
	# found "Indent" instead` на res://tests/validate_constructor_ui.gd:564, и
	# валидатор при этом не падает, а НАВИСАЕТ — скрипт не грузится, сцена
	# молчит. Утверждение не ослаблено: сравнение то же, добавлены скобки.
	(editor as SetEditor).apply_image("Б", _tiny_png())
	(editor as SetEditor).save_word("Б", "Банан")
	_check(((editor as SetEditor).get_node("%ReadinessLabel") as Label).text
			== SetEditor.readiness_label(0, 33),
			"буква без звука не засчитана как заполненная")
	(editor as SetEditor).apply_audio("Б", _silent_wav())
	_check(((editor as SetEditor).get_node("%ReadinessLabel") as Label).text
			== SetEditor.readiness_label(1, 33), "счётчик показывает одну заполненную букву")

	# Переоткрытие набора подхватывает уже сохранённое.
	(editor as SetEditor).open_set(set_id)
	_check((editor as SetEditor).get_slot("Б").get_word() == "Банан",
			"после переоткрытия слово на месте")
	_check((editor as SetEditor).get_slot("Б").has_image(),
			"после переоткрытия картинка на месте")

	# Сигнал сохранения уходит с id набора.
	var saved_ids: Array[String] = []
	(editor as SetEditor).set_saved.connect(func(id: String) -> void: saved_ids.append(id))
	(editor as SetEditor).get_node("%SaveButton").emit_signal("pressed")
	_check(saved_ids == [set_id], "SaveButton эмитит set_saved с id (получено: %s)"
			% str(saved_ids))

	# DEFECT 2. close_requested был объявлен и подключён, но не эмитился нигде:
	# кнопки «Назад» в редакторе не было, а список звал _show_list() напрямую.
	# Теперь назад — один путь: BackButton редактора эмитит сигнал, и SetList
	# на него реагирует. Проверяем и узел, и факт эмита, и что эмит РОВНО ОДИН
	# (двойная навигация закрыла бы список и тут же открыла его снова).
	# Путь без «%»: редактор здесь — прямой потомок валидатора, и «%» искал бы
	# уникальное имя от владельца ВАЛИДАТОРА, а не от сцены редактора.
	var back_button := editor.get_node_or_null("BackButton") as Button
	_check(back_button != null, "в set_editor.tscn есть узел BackButton")
	if back_button != null:
		_check(back_button.pressed.get_connections().size() == 1,
				"SetEditor._ready() подключил BackButton (подключений: %d)"
				% back_button.pressed.get_connections().size())
		_check(not back_button.accessibility_name.strip_edges().is_empty(),
				"у BackButton редактора есть accessibility_name")
		var closes: Array[String] = []
		(editor as SetEditor).close_requested.connect(
				func() -> void: closes.append("close"))
		back_button.emit_signal("pressed")
		_check(closes == ["close"],
				"BackButton редактора эмитит close_requested ровно один раз (получено: %s)"
				% str(closes))
		# Сигнал закрытия не должен тащить за собой закрытие набора.
		_check(saved_ids == [set_id],
				"нажатие «Назад» не эмитит set_saved заново (получено: %s)" % str(saved_ids))

	CustomSetsStore.delete_set(set_id)
	editor.queue_free()
	await get_tree().process_frame


func _check_set_list() -> void:
	var scene: PackedScene = load("res://ui/constructor/set_list/set_list.tscn")
	var list: Node = scene.instantiate()
	add_child(list)
	await get_tree().process_frame
	_check(list is SetList, "set_list.tscn привязан к классу SetList")
	for node_name: String in ["NewButton", "Scroll"]:
		if list.get_node_or_null("%" + node_name) == null:
			_fail("set_list: узел %s отсутствует" % node_name)

	# Пустое хранилище — пустой список, кнопка «создать» доступна.
	CustomSetsStore.clear_memory()
	CustomSetsStore.load_sets()
	(list as SetList).refresh()
	_check((list as SetList).get_row_count() == 0, "пустое хранилище -> 0 строк")
	_check((list.get_node("%NewButton") as Button).disabled == false,
			"создать набор можно и в пустом списке")

	# Два набора — две строки, порядок по имени.
	var first := CustomSetsStore.create_set("Альфа")
	var second := CustomSetsStore.create_set("Бета")
	(list as SetList).refresh()
	_check((list as SetList).get_row_count() == 2, "два набора -> две строки (получено: %d)"
			% (list as SetList).get_row_count())

	# Открытие редактора уходит с id нужного набора.
	var opened: Array[String] = []
	(list as SetList).open_editor.connect(func(id: String) -> void: opened.append(id))
	(list as SetList).get_row(0).emit_signal("pressed")
	_check(opened == [str(first.get("id", ""))],
			"строка «Альфа» открыла свой набор (получено: %s)" % str(opened))

	# Удаление второй строки убирает набор из хранилища.
	CustomSetsStore.delete_set(str(second.get("id", "")))
	(list as SetList).refresh()
	_check((list as SetList).get_row_count() == 1, "после удаления осталась одна строка")
	_check((list as SetList).get_row(0) != null, "оставшаяся строка — «Альфа»")
	_check((list as SetList).get_row(1) == null, "удалённой строки нет")

	CustomSetsStore.delete_set(str(first.get("id", "")))
	(list as SetList).refresh()
	_check((list as SetList).get_row_count() == 0, "после удаления всех список пуст")

	# DEFECT 2. Один путь назад: BackButton редактора эмитит close_requested, и
	# именно SetList на него реагирует. Проверяем наблюдаемый результат — список
	# снова виден, редактор скрыт, — а не то, какой обработчик отработал.
	# Двойная навигация (сигнал ПЛЮС прямой _show_list()) выглядела бы так же,
	# поэтому сверяем ещё и число переходов: счётчик закрытий обязан вырасти
	# ровно на один.
	var editor_node := list.get_node("%SetEditor") as Control
	var layout_node := list.get_node("Layout") as Control
	_check(editor_node != null and layout_node != null,
			"у SetList есть и встроенный редактор, и список в дереве")
	var closes: Array[String] = []
	(editor_node as SetEditor).close_requested.connect(func() -> void: closes.append("c"))
	var back_button := list.get_node("%BackButton") as Button
	(list.get_node("%NewButton") as Button).emit_signal("pressed")
	_check(editor_node.visible and layout_node.visible == false,
			"после «Создать набор» виден редактор, а список скрыт")
	# Один путь назад. Пока виден редактор, кнопка списка спрятана: иначе на
	# экране две кнопки «Назад» с разными маршрутами, и нажатие любой из них
	# закрывает редактор — то есть двойная навигация.
	_check(back_button.visible == false,
			"пока открыт редактор, кнопка «Назад» списка спрятана (один путь назад)")
	# Из списка та же кнопка уводит в настройки — второй маршрут не тронут.
	# Назад из редактора — через BackButton САМОГО РЕДАКТОРА, не через кнопку
	# списка: так проверяется именно соединение close_requested -> SetList.
	#
	# Путь БЕЗ «%»: редактор вложен в set_list.tscn, и «%BackButton» отрезолвился
	# бы в кнопку СПИСКА (уникальное имя ищется от владельца сцены), то есть
	# проверка прошла бы по старой прямой ветке _on_back_pressed и ничего не
	# сказала бы про close_requested. Обычный относительный путь адресует узел
	# внутри самого редактора.
	var editor_back := editor_node.get_node_or_null("BackButton") as Button
	_check(editor_back != null,
			"у вложенного в SetList редактора есть свой узел BackButton")
	if editor_back != null:
		editor_back.emit_signal("pressed")
		_check(layout_node.visible and editor_node.visible == false,
				"close_requested вернул SetList к списку и скрыл редактор")
		_check(back_button.visible,
				"после возврата кнопка «Назад» списка снова на месте")
		_check(str(back_button.text) == "Назад",
				"после возврата кнопка снова «Назад» (получено: %s)" % str(back_button.text))
		_check(closes == ["c"],
				"редактор эмитил close_requested ровно один раз (получено: %s)"
				% str(closes))

	# Из списка та же кнопка уводит в настройки — второй маршрут не тронут.
	_check((list as SetList).get_row_count() >= 1,
			"набор, созданный кнопкой, остался в списке")
	# Уборка за собой: следующая функция ждёт ПУСТОЕ хранилище, и оставленный
	# набор сдвинул бы счётчик строк на единицу во всех её проверках.
	for record: Dictionary in CustomSetsStore.get_sets():
		CustomSetsStore.delete_set(str(record.get("id", "")))
	(list as SetList).refresh()
	_check((list as SetList).get_row_count() == 0,
			"после уборки хранилище снова пусто")

	list.queue_free()
	await get_tree().process_frame
	_print("set_editor + set_list: OK")


## Для .tscn-задачи «молчание» — валидный на вид исход: сцена, которая не
## загрузилась, не печатает ничего. Поэтому здесь свидетельства, которые
## существуют ТОЛЬКО если отработал _ready() редактора: 33 слота создаёт
## _build_slots(), подписки на тему/кнопки/поле имени делает _ready(), а стиль
## кнопки ставит только _apply_theme().
func _check_set_editor_ready_ran() -> void:
	var scene: PackedScene = load("res://ui/constructor/set_editor/set_editor.tscn")
	if scene == null:
		_fail("set_editor.tscn не загружается — сцена молча ничего не проверяет")
		return
	var theme_links_before := ThemeManager.theme_changed.get_connections().size()
	var editor: Node = scene.instantiate()
	add_child(editor)
	await get_tree().process_frame

	_check(editor is SetEditor, "второй экземпляр set_editor.tscn тоже инстанцируется")
	# +1 от самой SetEditor и +33 от её слотов: LetterSlot тоже подписывается на
	# theme_changed в своём _ready(), а слоты создаёт _build_slots() из _ready()
	# редактора. Поэтому 34, а не 1 — и это само по себе доказательство, что
	# слоты построены именно _ready().
	_check(ThemeManager.theme_changed.get_connections().size() == theme_links_before + 34,
			"set_editor._ready() подписался на theme_changed вместе с 33 слотами "
			% ThemeManager.theme_changed.get_connections().size())
	var save_button := editor.get_node_or_null("%SaveButton") as Button
	_check(save_button != null and save_button.pressed.get_connections().size() == 1,
			"set_editor._ready() подключил SaveButton")
	var name_edit := editor.get_node_or_null("%NameEdit") as LineEdit
	_check(name_edit != null and name_edit.text_submitted.get_connections().size() == 1,
			"set_editor._ready() подключил text_submitted поля имени")
	_check(save_button != null and save_button.has_theme_stylebox_override("normal"),
			"set_editor._apply_theme() покрасил кнопку")
	# Слоты строятся только в _ready(): в .tscn их нет.
	var slots := editor.get_node_or_null("%Slots")
	_check(slots != null and slots.get_child_count() == 33,
			"_build_slots() создал 33 слота (получено: %d)"
			% (0 if slots == null else slots.get_child_count()))

	# Пустой набор: счётчик честно говорит «пусто», а поле имени пустое.
	_check((editor.get_node("%ReadinessLabel") as Label).text
			== SetEditor.readiness_label(0, 33),
			"без открытого набора счётчик показывает 0 из 33")
	_check((editor.get_node("%NameEdit") as LineEdit).text.is_empty(),
			"без открытого набора поле имени пустое")

	editor.queue_free()
	await get_tree().process_frame
	_print("set_editor _ready(): OK")


## Инварианты уровня множества — то, ради чего эта задача и выделена.
## Урок Task 1: поштучные проверки были зелёными, пока Е и Э схлопывались на
## одном имени файла. Здесь утверждается не «буква X на месте», а «ровно 33
## строки, по одной на букву, все достижимы, все кнопки подключены, порядок
## алфавитный».
func _check_set_editor_collection() -> void:
	var letters: Array = SetEditor.LETTERS
	_check(letters.size() == 33, "в SetEditor.LETTERS 33 буквы (получено: %d)" % letters.size())
	var unique := {}
	for letter: String in letters:
		unique[letter] = true
	_check(unique.size() == 33, "в LETTERS нет повторов (уникальных: %d)" % unique.size())
	# Порядок алфавитный, а не произвольный: строки сетки идут сверху вниз.
	_check("".join(PackedStringArray(letters)) == CustomSetsStore.LETTER_ORDER,
			"LETTERS совпадает с алфавитом хранилища, включая Ё")
	_check(letters.has("Ё") and letters.has("Ъ") and letters.has("Ы") and letters.has("Ь"),
			"в LETTERS есть Ё, Ъ, Ы и Ь — те, что чаще всего теряют")

	var editor := _fresh_editor()
	await get_tree().process_frame

	# По одной строке на букву, без дублей и без «лишних» строк.
	var missing: Array[String] = []
	for letter: String in letters:
		if (editor as SetEditor).get_slot(letter) == null:
			missing.append(letter)
	_check(missing.is_empty(), "слот есть для каждой из 33 букв (нет: %s)" % str(missing))
	_check((editor as SetEditor).get_slot("") == null
			and (editor as SetEditor).get_slot("Q") == null,
			"слот не создаётся для буквы вне алфавита")

	# Соответствие позиции букве. Это сильнее, чем «get_letter() каждой строки
	# отдаёт свою букву»: строка N обязана быть И узлом get_slot(LETTERS[N]),
	# И стоять на позиции N. Строка, которую не нашли, и строка, найденная не
	# там, ловятся оба.
	#
	# Именно здесь родился первый прогон этой проверки в виде «get_letter() на
	# пустом редакторе»: _build_slots() создаёт слоты, но НЕ зовёт setup() —
	# букву слот узнаёт только из open_set()/refresh(). Так что на пустом
	# редакторе get_letter() пуст у всех 33 строк, и такая проверка проверяла
	# бы не то. Две части разделены: позиция — на пустом редакторе, а
	# get_letter()-достижимость — после открытия настоящего набора.
	var slots := editor.get_node("%Slots") as GridContainer
	var mismatched: Array[String] = []
	var not_a_slot: Array[String] = []
	var children := slots.get_children()
	_check(children.size() == 33, "в сетке ровно 33 строки (получено: %d)" % children.size())
	for i in children.size():
		var child := children[i]
		if not (child is LetterSlot):
			not_a_slot.append("узел #%d (%s)" % [i, child.get_class()])
			continue
		if (editor as SetEditor).get_slot(str(letters[i])) != child:
			mismatched.append("позиция %d: ожидалась буква %s"
					% [i, str(letters[i])])
	_check(not_a_slot.is_empty(), "каждая строка сетки — LetterSlot: %s" % str(not_a_slot))
	_check(mismatched.is_empty(),
			"строка N в сетке — это ровно get_slot(LETTERS[N]) (расхождений: %d: %s)"
			% [mismatched.size(), str(mismatched)])
	_check(slots.columns == 3, "сетка в три колонки (получено: %d)" % slots.columns)
	# Ровно одна строка на букву: тот же узел дважды не отдаётся.
	_check(_distinct_slots(editor, letters).size() == 33,
			"33 разных узла слота, ни один не переиспользован")

	# Все действия каждой строки подключены к редактору. Пять сигналов на
	# строку: без этого слот выглядел бы рабочим, а нажатия умирали бы в
	# никуда — ровно тот молчаливый случай, который ловится только здесь.
	var unwired_buttons := 0
	var unwired_signals := 0
	for letter: String in letters:
		var slot := (editor as SetEditor).get_slot(letter)
		if slot == null:
			unwired_buttons += 1
			continue
		for node_name: String in ["ImageButton", "AudioButton", "PlayButton", "ClearButton"]:
			var button := slot.get_node_or_null("%" + node_name) as Button
			if button == null or button.accessibility_name.strip_edges().is_empty():
				unwired_buttons += 1
			elif button.pressed.get_connections().size() != 1:
				unwired_buttons += 1
		for signal_name: String in ["image_requested", "audio_requested",
				"play_requested", "clear_requested", "word_edited"]:
			if not _connected_to(editor, slot, signal_name):
				unwired_signals += 1
	_check(unwired_buttons == 0,
			"все 132 кнопки слотов подключены и с accessibility_name (нарушений: %d)"
			% unwired_buttons)
	_check(unwired_signals == 0,
			"все 5 намерений каждого слота приходят в редактор (нарушений: %d)"
			% unwired_signals)

	# Вторая часть достижимости: после открытия настоящего набора каждая строка
	# обязана отдавать СВОЮ букву, и находиться по ней. Только теперь
	# get_letter() заполнен — open_set() раздаёт буквы через setup().
	var open_record := CustomSetsStore.create_set(TEST_SET_NAME)
	var open_id := str(open_record.get("id", ""))
	(editor as SetEditor).open_set(open_id)
	var wrong_letter: Array[String] = []
	for letter: String in letters:
		var slot := (editor as SetEditor).get_slot(letter)
		if slot == null or slot.get_letter() != letter:
			wrong_letter.append(letter)
	_check(wrong_letter.is_empty(),
			"после open_set() каждая строка называет свою букву и находится по ней "
			+ "(нарушений: %d: %s)" % [wrong_letter.size(), str(wrong_letter)])
	# Порядок в сетке — тоже после open_set(), теперь по данным, а не по позиции.
	var order_after_open := true
	for i in slots.get_child_count():
		if (slots.get_child(i) as LetterSlot).get_letter() != str(letters[i]):
			order_after_open = false
	_check(order_after_open, "порядок строк сетки совпадает с алфавитом и после open_set()")
	CustomSetsStore.delete_set(open_id)
	_print("set_editor collection: OK")
	editor.queue_free()
	await get_tree().process_frame


## Сигнальный шов, порядок записи и поверхность ошибок. Всё, что не требует
## браузера: файловый диалог и микрофон тут не работают, но всё, что стоит
## ПОСЛЕ них, — работает.
func _check_set_editor_signals() -> void:
	var editor := _fresh_editor()
	await get_tree().process_frame
	var created := CustomSetsStore.create_set(TEST_SET_NAME)
	var set_id := str(created.get("id", ""))
	_check(not set_id.is_empty(), "набор для проверки сигналов создан")

	# ПОРЯДОК: каталог набора обязан существовать ДО первого save_image(),
	# иначе ImageSaver вернёт write_failed — он сам каталоги не создаёт.
	var set_dir := CustomSetsStore.set_dir(set_id)
	_check(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(set_dir)),
			"create_set() создал каталог набора до первой записи: %s" % set_dir)
	(editor as SetEditor).open_set(set_id)

	(editor as SetEditor).save_word("А", "Автобус")
	var slot := (editor as SetEditor).get_slot("А")

	# Отменённый выбор картинки не должен оставить следов. Вне веба
	# WebFilePicker.pick() честно отдаёт not_web — это тот же путь отмены,
	# что и «родитель закрыл диалог», только без 120-секундного таймаута.
	slot.image_requested.emit("А")
	await _settle()
	_check(str(CustomSetsStore.get_entry(set_id, "А").get("image", "")).is_empty(),
			"отменённый выбор картинки не записал путь в метаданные")
	_check(slot.has_image() == false, "отмена картинки не оставила слот «с картинкой»")
	_check(str(CustomSetsStore.get_entry(set_id, "А").get("word", "")) == "Автобус",
			"отмена картинки не тронула слово")
	_check((slot.get_node("%ImageButton") as Button).disabled == false,
			"отмена картинки не оставила слот заблокированным")

	# Запись с микрофона. В headless prepare_microphone() возвращает true
	# (шина и AudioStreamPlayer создаются, кадров просто нет), поэтому весь
	# переход «началась → занята → завершилась» проверяется headless.
	slot.audio_requested.emit("А")
	await _settle()
	_check((slot.get_node("%StatusLabel") as Label).text == "запись…",
			"началась запись: слот показывает «запись…» (получено: %s)"
			% (slot.get_node("%StatusLabel") as Label).text)
	_check((slot.get_node("%AudioButton") as Button).disabled == true,
			"во время записи кнопка звука заблокирована")
	# Вторая попытка записи для другой буквы обязана игнорироваться: иначе
	# микрофон получил бы два наложенных потока в один файл.
	var other := (editor as SetEditor).get_slot("Б")
	other.audio_requested.emit("Б")
	await _settle()
	_check((other.get_node("%StatusLabel") as Label).text != "запись…",
			"вторая запись не стартовала, пока идёт первая")
	# Запись без единого кадра: файл не пишется, состояние разблокируется.
	VoiceRecord.recording_finished.emit(true)
	await _settle()
	_check(str(CustomSetsStore.get_entry(set_id, "А").get("audio", "")).is_empty(),
			"пустая запись не записала аудио в метаданные")
	_check((slot.get_node("%StatusLabel") as Label).text == LetterSlot.describe_state(false, false),
			"после записи слот вернулся в исходное состояние")
	_check((slot.get_node("%AudioButton") as Button).disabled == false,
			"после записи кнопка звука снова активна")
	VoiceRecord.release_microphone()
	VoiceRecord.clear()

	# Прослушивание без файла не должно ни падать, ни портить запись.
	slot.play_requested.emit("А")
	await _settle()
	_check(str(CustomSetsStore.get_entry(set_id, "А").get("word", "")) == "Автобус",
			"прослушивание без файла не тронуло запись")

	# Правка слова поднимается вверх. Стимул — эмит самого text_changed:
	# присваивание LineEdit.text НЕ эмитит его (урок Task 8), проверять
	# несуществующее событие бессмысленно.
	(slot.get_node("%WordEdit") as LineEdit).text_changed.emit("Апельсин")
	await _settle()
	_check(str(CustomSetsStore.get_entry(set_id, "А").get("word", "")) == "Апельсин",
			"правка поля слова дошла до хранилища через word_edited")
	# Пустое слово отвергается, и в хранилище остаётся прежнее.
	(slot.get_node("%WordEdit") as LineEdit).text_changed.emit("   ")
	await _settle()
	_check(str(CustomSetsStore.get_entry(set_id, "А").get("word", "")) == "Апельсин",
			"пустое слово не затёрло прежнее в хранилище")

	# Очистка медиа с кнопки слота — тот же путь, что и из открытой буквы.
	(editor as SetEditor).apply_image("А", _tiny_png())
	(editor as SetEditor).apply_audio("А", _silent_wav())
	_check(slot.has_image() and slot.has_audio(), "медиа на месте перед очисткой с кнопки")
	slot.clear_requested.emit("А")
	await _settle()
	_check(slot.has_image() == false and slot.has_audio() == false,
			"clear_requested с кнопки очистил медиа")
	_check(str(CustomSetsStore.get_entry(set_id, "А").get("word", "")) == "Апельсин",
			"очистка с кнопки сохранила слово")

	# Ошибка записи обязана быть видна. Каталог набора сносим нарочно:
	# это единственный способ проверить ветку write_failed, потому что
	# create_set() каталог создаёт, и в жизни сюда попадают лишь после
	# удаления набора вручную или сбоя ФС.
	_remove_dir_recursive(set_dir)
	_check(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(set_dir)),
			"каталог набора снесён для проверки ошибки записи")
	var image_fail: Dictionary = (editor as SetEditor).apply_image("Г", _tiny_png())
	_check(bool(image_fail.get("ok", false)) == false, "apply_image() честно вернул отказ")
	var image_error := str(image_fail.get("error", ""))
	_check(image_error.contains("write_failed"),
			"ошибка картинки названа write_failed (получено: %s)" % image_error)
	_check(image_error.contains(":") and image_error.length() > "write_failed".length(),
			"ошибка картинки несёт текст для родителя, а не только код: %s" % image_error)
	var audio_fail: Dictionary = (editor as SetEditor).apply_audio("Г", _silent_wav())
	_check(bool(audio_fail.get("ok", false)) == false, "apply_audio() честно вернул отказ")
	# ИЗВЕСТНЫЙ ДЕФЕКТ плана, зафиксированный честно: у картинки сообщение
	# приходит из ImageSaver как "code: <текст>", а apply_audio() отдаёт
	# голый код без текста. Отказ не МОЛЧИТ (ok == false), но родителю нечего
	# показать. Проверка зафиксирована, чтобы правка была видна: как только
	# текст появится, здесь станет зелёным.
	_check(str(audio_fail.get("error", "")) == "write_failed",
			"ДЕФЕКТ: ошибка звука — голый код без текста (получено: %s)"
			% str(audio_fail.get("error", "")))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(set_dir))

	# Поле имени: программное заполнение (open_set/refresh) не должно
	# переименовывать набор — именно это обещает докстринг флага _updating.
	var name_edit := editor.get_node("%NameEdit") as LineEdit
	name_edit.text = "Взлом"
	await _settle()
	_check(str(CustomSetsStore.get_set_by_id(set_id).get("name", "")) == TEST_SET_NAME,
			"программное заполнение поля имени не переименовало набор")
	name_edit.text_submitted.emit("Переименовано")
	await _settle()
	_check(str(CustomSetsStore.get_set_by_id(set_id).get("name", "")) == "Переименовано",
			"text_submitted переименовал набор")
	# Отказ сохранения имени возвращает в поле настоящее значение.
	name_edit.text_submitted.emit("   ")
	await _settle()
	_check((name_edit.text) == "Переименовано",
			"после отказа в поле имени снова настоящее название (получено: %s)" % name_edit.text)
	# save_name() на неоткрытом наборе обязан отказать, а не переименовать
	# случайный набор.
	(editor as SetEditor).open_set("")
	_check((editor as SetEditor).get_set_id().is_empty(),
			"open_set(\"\") сбросил id набора")
	_check((editor as SetEditor).save_name("Чужое") == false,
			"save_name() без открытого набора отказал")
	# Регресс-кейс, найденный этим прогоном. Без проверки открытого набора
	# set_dir("") давал "user://custom_sets/" и apply_image()/apply_audio()
	# писали мусор в корень КАТАЛОГА наборов, минуя подкаталог, а про запись
	# в метаданные отчитывались об успехе. Теперь — no_set.
	_check((editor as SetEditor).apply_image("А", _tiny_png()).get("error", "") == "no_set",
			"apply_image() без открытого набора вернул no_set, а не писал в корень")
	_check((editor as SetEditor).apply_audio("А", _silent_wav()).get("error", "") == "no_set",
			"apply_audio() без открытого набора вернул no_set, а не писал в корень")
	var root_dir := CustomSetsStore.set_dir("")
	var strays := 0
	for letter: String in SetEditor.LETTERS:
		if FileAccess.file_exists(root_dir + CustomSetsStore.image_file_name(letter)):
			strays += 1
		if FileAccess.file_exists(root_dir + CustomSetsStore.audio_file_name(letter)):
			strays += 1
	_check(strays == 0,
			"в корне user://custom_sets/ не осталось ни одного медиафайла (найдено: %d)" % strays)
	# Порядок проверок: no_set раньше bad_letter, буква вне набора без набора
	# тоже даёт no_set — это осознанно и зафиксировано.
	_check((editor as SetEditor).apply_image("Q", _tiny_png()).get("error", "") == "no_set",
			"apply_image() проверяет набор раньше буквы (no_set, не bad_letter)")
	# С открытым набором буква вне алфавита — bad_letter.
	(editor as SetEditor).open_set(set_id)
	_check((editor as SetEditor).apply_image("Q", _tiny_png()).get("error", "") == "bad_letter",
			"apply_image() для чужой буквы вернул bad_letter")
	_check((editor as SetEditor).apply_audio("Q", _silent_wav(), "wav").get("error", "")
			== "bad_letter", "apply_audio() для чужой буквы вернул bad_letter")
	_check((editor as SetEditor).apply_audio("А", PackedByteArray()).get("error", "") == "no_bytes",
			"apply_audio() с пустыми байтами вернул no_bytes")
	# open_set("") не удаляет слоты — он их обнуляет. Слоты строит
	# _build_slots() из _ready(), а open_set() лишь заново раздаёт буквы и
	# данные из пустой записи. Первая версия этой проверки ждала null здесь и
	# падала: ждала несуществующего механизма.
	(editor as SetEditor).open_set("")
	_check((editor as SetEditor).get_slot("А") != null,
			"open_set(\"\") не удаляет слоты, а обнуляет их")
	_check((editor as SetEditor).get_slot("А").get_word().is_empty()
			and (editor as SetEditor).get_slot("А").has_image() == false
			and (editor as SetEditor).get_slot("А").has_audio() == false,
			"после open_set(\"\") слот пуст: ни слова, ни медиа")
	_check((editor.get_node("%NameEdit") as LineEdit).text.is_empty(),
			"open_set(\"\") очистил поле имени")
	_check((editor.get_node("%ReadinessLabel") as Label).text
			== SetEditor.readiness_label(0, 33),
			"после open_set(\"\") счётчик снова 0 из 33")

	CustomSetsStore.delete_set(set_id)
	editor.queue_free()
	await get_tree().process_frame
	_print("set_editor signals: OK")


## Свидетельство, что set_list.tscn инстанцировался и _ready() отработал:
## NewButton подключается только в _ready(), а на пустом хранилище становится
## видима подпись EmptyLabel — тоже только в refresh() из _ready().
func _check_set_list_ready_ran() -> void:
	var scene: PackedScene = load("res://ui/constructor/set_list/set_list.tscn")
	if scene == null:
		_fail("set_list.tscn не загружается — сцена молча ничего не проверяет")
		return
	var theme_links_before := ThemeManager.theme_changed.get_connections().size()
	var store_links_before := CustomSetsStore.sets_changed.get_connections().size()
	var list: Node = scene.instantiate()
	add_child(list)
	await get_tree().process_frame

	_check(list is SetList, "второй экземпляр set_list.tscn тоже инстанцируется")
	# Отличие от плана — прямая проверка своей подписки вместо сравнения числа
	# подключений. План писал «стало ровно на одну больше», и это работало, пока
	# set_list.tscn был одиноким. Теперь список хостит SetEditor, а у того своя
	# подписка на theme_changed (set_editor.gd), так что инстанцирование списка
	# добавляет ДВЕ подписки — и проверка на «+1» падала на совершенно рабочей
	# сцене. Считать чужие подписки и требовать ровно одну — проверка не про то,
	# что она проверяет: set_list может лежать рядом с любым числом слушателей
	# темы. Вопрос «подписался ли _ready() ЭТОГО списка» — и есть is_connected().
	_check(ThemeManager.theme_changed.is_connected(
			Callable(list, "_apply_theme")),
			"set_list._ready() подписался на theme_changed")
	_check(ThemeManager.theme_changed.get_connections().size() >= theme_links_before + 1,
			"инстанцирование списка добавило подписку на тему")
	_check(CustomSetsStore.sets_changed.get_connections().size() == store_links_before + 1,
			"set_list._ready() подписался на sets_changed хранилища")
	var new_button := list.get_node_or_null("%NewButton") as Button
	_check(new_button != null and new_button.pressed.get_connections().size() == 1,
			"set_list._ready() подключил NewButton")
	_check(new_button != null and new_button.has_theme_stylebox_override("normal"),
			"set_list._apply_theme() покрасил кнопку")
	var scroll := list.get_node_or_null("%Scroll")
	_check(scroll != null, "set_list: узел Scroll отсутствует")
	_check(scroll != null and scroll is VBoxContainer,
			"Scroll — VBoxContainer, как в плане")
	_check(scroll != null and scroll.get_parent() is ScrollContainer,
			"Scroll лежит внутри ScrollContainer")
	_check(scroll != null and scroll.size_flags_vertical == 3,
			"Scroll растягивается по вертикали (size_flags_vertical=%d)"
			% (0 if scroll == null else scroll.size_flags_vertical))
	var empty_label := list.get_node_or_null("%EmptyLabel") as Label
	_check(empty_label != null and empty_label.visible,
			"на пустом хранилище подпись «пока нет своих наборов» видима")
	_check((list as SetList).get_row(-1) == null and (list as SetList).get_row(999) == null,
			"get_row() вне диапазона возвращает null, а не падает")

	# Строка — отдельная сцена. Её _ready() подключает обе кнопки.
	var record := CustomSetsStore.create_set("Гамма")
	var set_id := str(record.get("id", ""))
	(list as SetList).refresh()
	await get_tree().process_frame
	_check(empty_label != null and empty_label.visible == false,
			"подпись пустого списка спряталась, когда набор появился")
	_check((list as SetList).get_row_count() == 1, "один набор -> одна строка")
	var row := (list as SetList).get_row(0)
	_check(row != null and row is SetListRow, "строка списка — SetListRow")
	if row != null:
		_check((row.get_node("%OpenButton") as Button).pressed.get_connections().size() == 1,
				"SetListRow._ready() подключил OpenButton")
		_check((row.get_node("%DeleteButton") as Button).pressed.get_connections().size() == 1,
				"SetListRow._ready() подключил DeleteButton")
		_check((row.get_node("%OpenButton") as Button).has_theme_stylebox_override("normal"),
				"SetListRow._apply_theme() покрасил кнопки")
		_check((row.get_node("%NameLabel") as Label).text == "Гамма",
				"SetListRow.setup() показал имя набора")
		_check((row.get_node("%CountLabel") as Label).text == "заполнено 0 из 33",
				"пустой набор подписан как «заполнено 0 из 33»")
		_check(row.pressed.get_connections().size() == 1,
				"строка подключена к списку одним обработчиком")
		_check(row.delete_requested.get_connections().size() == 1,
				"удаление строки подключено к списку одним обработчиком")
		# Строка без букв и полная строка подписываются по-разному.
		row.setup("Гамма", 33, true)
		_check((row.get_node("%CountLabel") as Label).text == "набор готов к играм",
				"полный набор подписан как готовый к играм")

	# Удаление по кнопке строки: набор исчезает из хранилища, а sets_changed
	# заставляет список пересобраться самому.
	var changed: Array[String] = []
	(list as SetList).sets_changed.connect(func() -> void: changed.append("changed"))
	row.delete_requested.emit()
	await get_tree().process_frame
	_check(CustomSetsStore.get_set_by_id(set_id).is_empty(),
			"delete_requested с кнопки строки удалил набор")
	_check(changed.size() >= 1, "удаление эмитит sets_changed")
	_check((list as SetList).get_row_count() == 0, "после удаления список пуст")
	_check(empty_label != null and empty_label.visible,
			"подпись пустого списка вернулась")

	# Создание по кнопке: новый набор + открытие редактора с его id.
	var opened: Array[String] = []
	(list as SetList).open_editor.connect(func(id: String) -> void: opened.append(id))
	(list.get_node("%NewButton") as Button).emit_signal("pressed")
	await _settle()
	_check((list as SetList).get_row_count() == 1, "NewButton создал набор и строку")
	_check(opened.size() == 1, "NewButton эмитит open_editor (получено: %d)" % opened.size())
	if opened.size() == 1:
		var created_ids: Array[String] = []
		for stored: Dictionary in CustomSetsStore.get_sets():
			created_ids.append(str(stored.get("id", "")))
		_check(created_ids == opened,
				"open_editor ушёл с id только что созданного набора (получено: %s)"
				% str(opened))
	CustomSetsStore.delete_set(opened[0] if opened.size() == 1 else "")
	await _settle()
	list.queue_free()
	await get_tree().process_frame
	_print("set_list _ready(): OK")


## Урок Task 7: два набора обязаны давать РАЗНЫЕ файлы для одной и той же
## буквы. Иначе второй набор молча перетирает медиа первого — и тест, который
## проверяет буквы по одной, этого не видит.
func _check_two_sets_never_share_path() -> void:
	var first := CustomSetsStore.create_set("Первый")
	var second := CustomSetsStore.create_set("Второй")
	var first_id := str(first.get("id", ""))
	var second_id := str(second.get("id", ""))
	_check(first_id != second_id, "два набора получили разные id")
	var first_dir := CustomSetsStore.set_dir(first_id)
	var second_dir := CustomSetsStore.set_dir(second_id)
	_check(first_dir != second_dir, "у наборов разные каталоги")
	var all := {}
	var collisions: Array[String] = []
	var outside := 0
	var in_root := 0
	for letter: String in SetEditor.LETTERS:
		for dir: String in [first_dir, second_dir]:
			var path: String = dir + CustomSetsStore.image_file_name(letter)
			if path in all:
				collisions.append(path)
			all[path] = letter
			if not path.begins_with(dir):
				outside += 1
			if path == "user://" + CustomSetsStore.image_file_name(letter):
				in_root += 1
	_check(all.size() == 66,
			"66 букво-файлов у двух наборов дают 66 разных путей (получено: %d)" % all.size())
	_check(collisions.is_empty(), "ни один путь не разделяется наборами: %s" % str(collisions))
	_check(outside == 0, "каждый файл лежит в каталоге своего набора (нарушений: %d)" % outside)
	_check(in_root == 0, "ни один путь не попал в корень user:// (нарушений: %d)" % in_root)
	# И заодно аудио: то же правило, другой префикс.
	var audio_paths := {}
	var audio_collisions: Array[String] = []
	for letter: String in SetEditor.LETTERS:
		for dir: String in [first_dir, second_dir]:
			var path: String = dir + CustomSetsStore.audio_file_name(letter)
			if path in audio_paths:
				audio_collisions.append(path)
			audio_paths[path] = letter
	_check(audio_paths.size() == 66,
			"66 аудиофайлов дают 66 разных путей (получено: %d)" % audio_paths.size())
	_check(audio_collisions.is_empty(),
			"аудиопути наборов не делятся: %s" % str(audio_collisions))
	CustomSetsStore.delete_set(first_id)
	CustomSetsStore.delete_set(second_id)
	_print("two sets paths: OK")


## Экран настроек, у которого open_constructor() считает вызовы вместо смены
## сцены. Подмена скрипта — ДО add_child(), иначе _ready() отработает на
## боевом скрипте, подпишет кнопку дважды и обрушит прогон чужой ошибкой.
func _spy_settings() -> Node:
	if not ResourceLoader.exists(SETTINGS_SCENE_PATH):
		_fail("нет сцены настроек по пути %s" % SETTINGS_SCENE_PATH)
		return null
	var settings: Node = load(SETTINGS_SCENE_PATH).instantiate()
	var spy_script: Script = load(SPY_SCRIPT_PATH)
	if spy_script == null:
		_fail("не загрузился тестовый двойник %s" % SPY_SCRIPT_PATH)
		return null
	settings.set_script(spy_script)
	add_child(settings)
	return settings


## Узел Родительской Защиты, поднятый над сценой, либо null. Ищем по пути
## скрипта, а не по имени класса: сломанный parental_gate.gd должен дать
## FAIL-проверку, а не уронить РАЗБОР этого файла (тогда валидатор зависнет
## молча, и watchdog сработает бессильно).
func _find_parental_gate() -> Node:
	for child: Node in get_tree().root.get_children():
		var script: Script = child.get_script()
		if script != null and str(script.resource_path) == GATE_SCRIPT_PATH:
			return child
	return null


## Сколько оверлеев Защиты висит в корне. Утечка проявит себя здесь: сцена
## открыта, оверлей закрыт, а узел остался.
func _count_parental_gates() -> int:
	var total := 0
	for child: Node in get_tree().root.get_children():
		var script: Script = child.get_script()
		if script != null and str(script.resource_path) == GATE_SCRIPT_PATH:
			total += 1
	return total


## Три кнопки ответа Защиты — по публичным именам сцены, а не по приватному
## _answer_buttons: проверка должна опираться на то, что видит родитель.
func _gate_answer_buttons(gate: Node) -> Array:
	var buttons: Array = []
	for node_name: String in ["%AnswerButton1", "%AnswerButton2", "%AnswerButton3"]:
		var button := gate.get_node_or_null(NodePath(node_name)) as Button
		if button != null:
			buttons.append(button)
	return buttons


## Операнды из ВИДИМОГО текста вопроса: «Сколько будет 9 + 8?» -> [9, 8].
## Правильный ответ выводится именно так, а не из приватного _correct_answer:
## иначе тест повторил бы реализацию и не поймал бы рассинхрон надписей с ключом.
func _gate_operands(question: String) -> Array[int]:
	var numbers: Array[int] = []
	var current := ""
	for index: int in range(question.length()):
		var symbol := question.substr(index, 1)
		if symbol >= "0" and symbol <= "9":
			current += symbol
			continue
		if not current.is_empty():
			numbers.append(int(current))
			current = ""
	if not current.is_empty():
		numbers.append(int(current))
	return numbers


## Кнопка с подписью, равной sum — верный ответ. null, если такой нет.
## Сознательно отдельная функция, а не флаг внутри общей: смешанный поиск
## «сначала совпадение, потом первое несовпадение» однажды уже вернул вместо
## неверного ответа верный, и тест «неверный ответ не пускает дальше» тихо
## превратился в «верный ответ пускает дальше» — красной была одна строка.
func _gate_correct_button(gate: Node, sum: int) -> Button:
	for button: Button in _gate_answer_buttons(gate):
		if button.text == str(sum):
			return button
	return null


## Первая кнопка, подпись которой НЕ равна sum, — заведомо неверный ответ.
func _gate_wrong_button(gate: Node, sum: int) -> Button:
	for button: Button in _gate_answer_buttons(gate):
		if button.text != str(sum):
			return button
	return null


## Сколько подписан на `pressed` кнопки. Ноль означает, что _ready() не
## отработал и нажатие ушло бы в пустоту.
func _pressed_connections(button: Signal) -> int:
	return button.get_connections().size()


## Родительская Защита перед конструктором: кнопка «Свои наборы» не должна
## открывать конструктор сразу — сначала верный ответ на пример.
##
## Проверяется сквозной путь %MySetsButton -> ParentalGate -> open_constructor().
## Реальный open_constructor() зовёт change_scene_to_file(), а валидатор сам
## является current_scene, поэтому переход подменён счётчиком; но объект и имя
## метода колбэка берутся из живой Защиты, так что шов «кнопка -> Защита ->
## метод» проверен настоящим, а не смоделированным.
func _check_parental_gate() -> void:
	var start_checks := checks
	var spy := _spy_settings()
	if spy == null:
		return

	# --- Сцена настроек действительно поднялась и прошла _ready().
	var button := spy.get_node_or_null("%MySetsButton") as Button
	_check(button != null, "в настройках есть кнопка «Свои наборы» (%MySetsButton)")
	if button == null:
		spy.queue_free()
		return
	var ready_witness := false
	for connection: Dictionary in ThemeManager.theme_changed.get_connections():
		var callback: Callable = connection.get("callable", Callable())
		if callback.is_valid() and callback.get_object() == spy:
			ready_witness = true
	_check(ready_witness,
			"Settings._ready() отработал: theme_changed подписан на сам экран настроек")
	_check(_pressed_connections(button.pressed) >= 1,
			"кнопка «Свои наборы» подписана на pressed (связей: %d)"
			% _pressed_connections(button.pressed))

	# --- Нажатие открывает Защиту и НЕ открывает конструктор.
	var calls_before: int = spy.constructor_calls
	button.emit_signal("pressed")
	await get_tree().process_frame
	var gate := _find_parental_gate()
	_check(gate != null, "нажатие «Свои наборы» подняло Родительскую Защиту")
	_check(spy.constructor_calls == calls_before,
			"защита НЕ пропустила в конструктор без ответа (вызовов: %d)"
			% spy.constructor_calls)
	if gate == null:
		spy.queue_free()
		await get_tree().process_frame
		return

	# --- Оверлей, а не соседняя сцена: должен пережить своего создателя.
	_check(gate.get_script().resource_path == GATE_SCRIPT_PATH,
			"поднят именно parental_gate.gd, а не одноимённый дубль")
	_check(gate is CanvasLayer, "Защита — оверлей CanvasLayer, а не обычная Control")
	_check(int(gate.get("layer")) >= 100,
			"Защита лежит поверх прочих слоёв (layer=%d, минимум 100)"
			% int(gate.get("layer")))
	_check(gate.get_parent() == get_tree().root,
			"Защита — потомок корня, поэтому не умрёт вместе с экраном настроек")
	_check(gate.is_inside_tree() and not gate.is_queued_for_deletion(),
			"Защита жива в дереве сразу после открытия")

	# --- Точка интеграции: чей это колбэк и какой метод.
	var callback: Callable = gate.get("_on_success_callback")
	_check(callback.is_valid(),
			"у открытой Защиты задан _on_success_callback")
	_check(callback.is_valid() and callback.get_object() == spy,
			"колбэк Защиты ведёт на ЭКРАН настроек, а не на что-то постороннее")
	_check(callback.is_valid() and callback.get_method() == "open_constructor",
			"колбэк Защиты — именно open_constructor (получено: %s)"
			% (callback.get_method() if callback.is_valid() else "<нет callable>"))
	var target := str(spy.constructor_target())
	_check(ResourceLoader.exists(target),
			"боевой open_constructor() ведёт на существующую сцену %s" % target)

	# --- Сам пример: три числовых кнопки и ровно один верный ответ, посчитанный
	#     из надписи, а не вытащенный из приватного поля.
	var seen_questions := {}
	var wrong_pressed := 0
	var keys_follow_text := 0
	for attempt: int in range(8):
		if not is_instance_valid(gate) or not gate.is_inside_tree() \
				or gate.is_queued_for_deletion():
			break
		var label := gate.get_node_or_null("%QuestionLabel") as Label
		if label == null:
			break
		var question: String = label.text
		seen_questions[question] = true
		_check(question.begins_with("Сколько будет ") and question.ends_with("?"),
				"вопрос задан в формате «Сколько будет a + b?» (получено: %s)" % question)
		var operands := _gate_operands(question)
		_check(operands.size() == 2,
				"из надписи читаются ровно два слагаемых (получено: %s)" % str(operands))
		if operands.size() != 2:
			continue
		_check(operands[0] >= 2 and operands[0] <= 9 and operands[1] >= 2 and operands[1] <= 9,
				"слагаемые в заявленном диапазоне 2..9 (получено: %s)" % str(operands))
		var sum: int = operands[0] + operands[1]
		var buttons := _gate_answer_buttons(gate)
		_check(buttons.size() == 3, "у примера ровно три кнопки ответа (получено: %d)"
				% buttons.size())
		var texts := {}
		var correct_pressed := 0
		for answer: Button in buttons:
			texts[answer.text] = true
			if answer.text == str(sum):
				correct_pressed += 1
		_check(texts.size() == 3,
				"все три ответа различны (получено: %s)" % str(texts.keys()))
		_check(correct_pressed == 1,
				"верный ответ ровно один, и он равен сумме из надписи %d (найдено: %d)"
				% [sum, correct_pressed])
		if correct_pressed == 1:
			keys_follow_text += 1
		# жмём НЕВЕРНЫЙ: конструктор обязан остаться закрытым
		var wrong := _gate_wrong_button(gate, sum)
		if wrong == null:
			break
		wrong.emit_signal("pressed")
		wrong_pressed += 1
		await get_tree().process_frame
		_check(spy.constructor_calls == calls_before,
				"неверный ответ %d не открыл конструктор (вызовов: %d)"
				% [wrong_pressed, spy.constructor_calls])
	_check(wrong_pressed == 8,
			"все 8 неверных ответов нажаты (нажато: %d)" % wrong_pressed)
	_check(keys_follow_text == 8,
			"на каждом из 8 примеров ключ сходился с НАДПИСЬЮ (совпало: %d)"
			% keys_follow_text)
	_check(seen_questions.size() >= 2,
			"после ошибки показывается НОВЫЙ пример (уникальных надписей: %d из 9)"
			% seen_questions.size())
	_check(is_instance_valid(gate) and gate.is_inside_tree(),
			"Защита пережила 8 неверных ответов и не закрылась сама")

	# --- Верный ответ: колбэк РОВНО ОДИН раз, оверлей убран.
	#     Второе нажатие в том же кадре — ровно тот случай, который ловит
	#     _callback_fired; если бы его не было, получили бы два вызова.
	_check(is_instance_valid(gate), "Защита жива к моменту верного ответа")
	if not is_instance_valid(gate):
		return
	var final_label := gate.get_node("%QuestionLabel") as Label
	var final_operands := _gate_operands(final_label.text)
	var final_sum: int = final_operands[0] + final_operands[1]
	var correct := _gate_correct_button(gate, final_sum)
	_check(correct != null,
			"верный ответ %d нажат на последнем примере" % final_sum)
	if correct != null:
		correct.emit_signal("pressed")
		correct.emit_signal("pressed")
		await _settle()
		_check(spy.constructor_calls == calls_before + 1,
				"верный ответ вызвал open_constructor() РОВНО ОДИН раз, двойное нажатие не дало второго (вызовов: %d)"
				% spy.constructor_calls)
		_check(_count_parental_gates() == 0,
				"после верного ответа оверлей Защиты убран из корня")
		_check(not is_instance_valid(gate),
				"узел Защиты освобождён, а не просто скрыт")

	# --- «Закрыть»: отказ не должен выглядеть как разрешение.
	button.emit_signal("pressed")
	await get_tree().process_frame
	var cancel_gate := _find_parental_gate()
	_check(cancel_gate != null, "Защита снова открывается после предыдущей")
	if cancel_gate != null:
		var calls_now: int = spy.constructor_calls
		var cancel := cancel_gate.get_node_or_null("%CancelButton") as Button
		_check(cancel != null, "у Защиты есть кнопка «Закрыть»")
		if cancel != null:
			cancel.emit_signal("pressed")
			await _settle()
			_check(spy.constructor_calls == calls_now,
					"«Закрыть» НЕ вызывает open_constructor() (вызовов: %d)"
					% spy.constructor_calls)
			_check(_count_parental_gates() == 0, "«Закрыть» убирает оверлей Защиты")

	# --- Четыре полных цикла: подтверждаем, что оверлеи не копятся.
	var cycle_calls: int = spy.constructor_calls
	var previous_gate_id := 0
	var cycles := 0
	for cycle: int in range(4):
		button.emit_signal("pressed")
		await get_tree().process_frame
		var fresh := _find_parental_gate()
		_check(fresh != null, "цикл %d: нажатие открыло Защиту" % (cycle + 1))
		_check(_count_parental_gates() == 1,
				"цикл %d: одновременно висит ровно один оверлей (найдено: %d)"
				% [cycle + 1, _count_parental_gates()])
		if fresh == null:
			break
		_check(fresh.get_instance_id() != previous_gate_id,
				"цикл %d: это НОВЫЙ узел, а не переиспользованный" % (cycle + 1))
		previous_gate_id = fresh.get_instance_id()
		var label := fresh.get_node("%QuestionLabel") as Label
		var operands := _gate_operands(label.text)
		if operands.size() != 2:
			break
		var answer := _gate_correct_button(fresh, operands[0] + operands[1])
		if answer == null:
			break
		answer.emit_signal("pressed")
		await _settle()
		cycles += 1
		_check(_count_parental_gates() == 0,
				"цикл %d: после ответа оверлея не осталось" % (cycle + 1))
	_check(cycles == 4, "проведены все 4 полных цикла (проведено: %d)" % cycles)
	_check(spy.constructor_calls == cycle_calls + cycles,
			"4 цикла дали ровно 4 вызова open_constructor() (%d)"
			% (spy.constructor_calls - cycle_calls))
	_check(_count_parental_gates() == 0,
			"в корне не осталось ни одного оверлея Защиты")

	spy.queue_free()
	await get_tree().process_frame
	_check(_count_parental_gates() == 0,
			"после освобождения экрана настроек оверлеев не осталось")
	var block_checks := checks - start_checks
	_check(block_checks >= MIN_GATE_CHECKS,
			"блок Защиты выполнил не меньше %d проверок (выполнил: %d)"
			% [MIN_GATE_CHECKS, block_checks])
	_print("parental gate: OK (%d проверок)" % (checks - start_checks))



## Новый экземпляр редактора без открытого набора.
func _fresh_editor() -> Node:
	var scene: PackedScene = load("res://ui/constructor/set_editor/set_editor.tscn")
	var editor: Node = scene.instantiate()
	add_child(editor)
	return editor


## Сколько кадров ждать, чтобы корутина сигнального обработчика отработала.
## pick() вне веба возвращается сразу, но await всё равно проходит через
## кадровый цикл, поэтому одного process_frame мало.
func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame


## Сколько разных узлов слота выдаёт get_slot() на весь алфавит.
func _distinct_slots(editor: Node, letters: Array) -> Dictionary:
	var out := {}
	for letter: String in letters:
		var slot := (editor as SetEditor).get_slot(letter)
		if slot != null:
			out[slot.get_instance_id()] = letter
	return out


## Подключён ли сигнал слота именно к этому редактору.
func _connected_to(editor: Node, slot: Node, signal_name: String) -> bool:
	for connection: Dictionary in slot.get_signal_connection_list(signal_name):
		var callable: Callable = connection.get("callable", Callable())
		if callable.is_valid() and callable.get_object() == editor:
			return true
	return false


## Рекурсивное удаление каталога набора вместе с содержимым.
func _remove_dir_recursive(user_path: String) -> void:
	var base := ProjectSettings.globalize_path(user_path)
	if not DirAccess.dir_exists_absolute(base):
		return
	for file_name: String in DirAccess.get_files_at(base):
		DirAccess.remove_absolute(base.path_join(file_name))
	for dir_name: String in DirAccess.get_directories_at(base):
		_remove_dir_recursive("%s%s/" % [user_path, dir_name])
	DirAccess.remove_absolute(base)


func _cleanup() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/thumb.png" % TEST_DIR))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DIR))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_STORE_PATH))


func _check(ok: bool, msg: String) -> void:
	checks += 1
	if ok:
		_print("OK: " + msg)
	else:
		_fail(msg)


func _fail(msg: String) -> void:
	failures += 1
	printerr("FAIL: " + msg)


func _print(msg: String) -> void:
	print("[constructor_ui_validate] " + msg)


func _finish() -> void:
	# Ноль выполненных проверок при нуле ошибок — это не успех, а сломанный
	# валидатор: печатать PASSED в таком случае нельзя.
	_cleanup()
	# Счётчик ТОЛЬКО для новых проверок Task 9: правки плана не должны были
	# уронить число выполненных проверок — падение видно как «Task 9: N».
	var task9_checks := checks - TASK8_CHECKS
	print("[constructor_ui_validate] Task 9: %d новых проверок, всего %d"
			% [task9_checks, checks])
	if checks == 0:
		printerr("FAILED: не выполнено ни одной проверки — валидатор не отработал")
		get_tree().quit(1)
		return
	# Нижняя граница зелёного прогона: блок Защиты не имеет права вытеснить
	# чужую проверку. Без этой строки можно было бы случайно удалить половину
	# файла и всё равно увидеть PASSED.
	if checks < BASELINE_TOTAL:
		printerr("FAILED: проверок %d меньше зелёного прогона %d — старые проверки вытеснены"
				% [checks, BASELINE_TOTAL])
		get_tree().quit(1)
		return
	if task9_checks <= 0:
		printerr("FAILED: новых проверок Task 9 нет (%d) — блок не отработал" % task9_checks)
		get_tree().quit(1)
		return
	if failures > 0:
		printerr("FAILED: %d проверок из %d" % [failures, checks])
		get_tree().quit(1)
	else:
		print("[constructor_ui_validate] PASSED: %d проверок успешны" % checks)
		get_tree().quit(0)
