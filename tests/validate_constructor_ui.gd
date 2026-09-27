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

## Каталог для настоящей миниатюры. В user://, а не в репозитории: ImageSaver
## сам каталоги не создаёт, и тест не должен оставлять мусор в assets/.
const TEST_DIR := "user://constructor_ui_test"

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

	await _check_letter_slot()
	await _check_letter_slot_ready_ran()
	await _check_letter_slot_media_paths()

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
	return ok


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


func _cleanup() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/thumb.png" % TEST_DIR))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DIR))


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
	if checks == 0:
		printerr("FAILED: не выполнено ни одной проверки — валидатор не отработал")
		get_tree().quit(1)
		return
	if failures > 0:
		printerr("FAILED: %d проверок из %d" % [failures, checks])
		get_tree().quit(1)
	else:
		print("[constructor_ui_validate] PASSED: %d проверок успешны" % checks)
		get_tree().quit(0)
