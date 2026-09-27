extends Node
## Валидатор WebFilePicker: MIME-таблицы, декодирование data URL, отказ на
## неподдерживаемых данных. JS-мост проверить headless нельзя — он проверяется
## в браузере в финальной задаче.
## Запуск: godot --headless --path . res://tests/validate_web_file_picker.tscn

## Настоящий base64 1x1 PNG: сигнатура 89 50 4E 47 0D 0A 1A 0A.
const PNG_DATA_URL := "data:image/png;base64," + \
		"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="

## Скрипт хранилища грузится напрямую, а не через автозагрузку: нужна только
## статическая extension_for_mime(), а у node-инстанса Godot ругается на вызов
## статического метода (STATIC_CALLED_ON_INSTANCE).
const CustomSetsStoreScript := preload("res://systems/custom_sets_store.gd")

var failures := 0


func _ready() -> void:
	await get_tree().process_frame

	# Страховка от ложного «всё прошло». Если скрипт WebFilePicker не скомпилился,
	# Godot всё равно создаёт объект класса, но без методов: каждая проверка
	# тогда падает с runtime-ошибкой на первой строке, счётчик остаётся нулевым
	# и валидатор завершился бы с exit 0. Поэтому сначала убеждаемся, что
	# статические методы реально есть.
	if not _class_loaded():
		_fail("WebFilePicker не загрузился: статические методы недоступны")
		_finish()
		return

	_check_kind_tables()
	_check_table_invariants()
	_check_audio_extensions()
	_check_data_url_decoding()
	await _check_bad_input()
	await _check_pick_off_web()

	_finish()


func _class_loaded() -> bool:
	var required := ["kind_for_mime", "max_bytes_for_kind", "decode_data_url", "pick"]
	var script := WebFilePicker as Script
	if script == null:
		return false
	var present := {}
	for method: Dictionary in script.get_script_method_list():
		present[method.get("name", "")] = true
	for name: String in required:
		if not present.has(name):
			return false
	return true


func _check_kind_tables() -> void:
	_check(WebFilePicker.kind_for_mime("image/png") == "image", "image/png -> image")
	_check(WebFilePicker.kind_for_mime("image/jpeg") == "image", "image/jpeg -> image")
	_check(WebFilePicker.kind_for_mime("image/webp") == "image", "image/webp -> image")
	_check(WebFilePicker.kind_for_mime("audio/wav") == "audio", "audio/wav -> audio")
	_check(WebFilePicker.kind_for_mime("audio/mpeg") == "audio", "audio/mpeg -> audio")
	_check(WebFilePicker.kind_for_mime("audio/mp4") == "audio", "audio/mp4 -> audio (iPhone)")
	# .ogg приходит и под псевдонимами: без них легальный файл уходил в отказ.
	_check(WebFilePicker.kind_for_mime("audio/vorbis") == "audio", "audio/vorbis -> audio (.ogg)")
	_check(WebFilePicker.kind_for_mime("audio/oga") == "audio", "audio/oga -> audio (.oga)")
	# Форматов вне контракта (WAV/OGG/MP3/M4A) пикер не принимает: им нечем
	# дать имя при сохранении — extension_for_mime() вернёт пустую строку.
	_check(WebFilePicker.kind_for_mime("audio/aac") == "", "audio/aac -> пусто (нет расширения)")
	_check(WebFilePicker.kind_for_mime("audio/webm") == "", "audio/webm -> пусто (нет расширения)")
	_check(WebFilePicker.kind_for_mime("application/pdf") == "", "application/pdf -> пусто")
	_check(WebFilePicker.kind_for_mime("") == "", "пустой mime -> пусто")
	# Регистр и параметры после mime не должны ломать распознавание.
	_check(WebFilePicker.kind_for_mime("IMAGE/PNG") == "image", "верхний регистр mime")
	_check(WebFilePicker.kind_for_mime("audio/wav;codec=1") == "audio", "mime с параметрами")

	_check(WebFilePicker.max_bytes_for_kind("image") == 5 * 1024 * 1024, "лимит картинки 5 МБ")
	_check(WebFilePicker.max_bytes_for_kind("audio") == 10 * 1024 * 1024, "лимит звука 10 МБ")
	_check(WebFilePicker.max_bytes_for_kind("") == 0, "неизвестный вид -> лимит 0")


## Инварианты самих таблиц, а не только отдельных строк. kind_for_mime()
## сравнивает с таблицей ровно (после to_lower), поэтому запись в верхнем
## регистре или с параметром после ";" сделала бы элемент недостижимым
## молча — ровно тот класс тихих поломок, что был в LetterTranslit.
func _check_table_invariants() -> void:
	var tables := {
		"IMAGE_MIME_TYPES": WebFilePicker.IMAGE_MIME_TYPES,
		"AUDIO_MIME_TYPES": WebFilePicker.AUDIO_MIME_TYPES,
	}
	_check(int(tables["IMAGE_MIME_TYPES"].size()) == 3, "в таблице картинок 3 типа")
	_check(int(tables["AUDIO_MIME_TYPES"].size()) == 10, "в таблице звука 10 типов")
	for table_name: String in tables:
		var seen := {}
		var entries: PackedStringArray = PackedStringArray(tables[table_name])
		for mime: String in entries:
			_check(not mime.is_empty(), "%s: нет пустых записей" % table_name)
			_check(mime == mime.to_lower(), "%s: %s в нижнем регистре" % [table_name, mime])
			_check(not mime.contains(";"), "%s: %s без параметров" % [table_name, mime])
			_check(not seen.has(mime), "%s: %s не повторяется" % [table_name, mime])
			seen[mime] = true
			_check(WebFilePicker.kind_for_mime(mime) != "",
					"%s: %s достижим через kind_for_mime" % [table_name, mime])


## Кросс-табличный инвариант AUDIO_MIME_TYPES <-> extension_for_mime().
## Каждый принятый MIME-тип обязан получить расширение, иначе файл сохранится
## без него; набор полученных расширений обязан быть ровно аудиоконтрактом
## проекта. Проверять поштучно бессмысленно — поштучно баг и жил: audio/aac и
## audio/webm проходили как «есть в таблице и распознаётся», пока давали пустое
## расширение, а audio/vorbis не было в таблице вовсе, хотя .ogg — основной
## формат проекта. Это тот же урок, что с коллизией имён Е/Э: поштучные
## проверки зелёные, коллекция неверная. Поэтому сверяем множество целиком.
func _check_audio_extensions() -> void:
	var extensions := {}
	for mime: String in PackedStringArray(WebFilePicker.AUDIO_MIME_TYPES):
		var extension := str(CustomSetsStoreScript.extension_for_mime(mime))
		_check(not extension.is_empty(),
				"AUDIO_MIME_TYPES: %s даёт расширение для сохранения" % mime)
		if not extension.is_empty():
			extensions[extension] = true
	var actual := extensions.keys()
	actual.sort()
	var expected := ["m4a", "mp3", "ogg", "wav"]
	_check(actual == expected,
			"набор расширений AUDIO_MIME_TYPES = %s, ожидалось %s" % [actual, expected])


func _check_data_url_decoding() -> void:
	var result := WebFilePicker.decode_data_url(PNG_DATA_URL)
	_check(bool(result.get("ok", false)), "data URL распознан")
	_check(str(result.get("mime", "")) == "image/png", "mime извлечён из data URL")
	var bytes := result.get("bytes", PackedByteArray()) as PackedByteArray
	_check(bytes.size() > 0, "данные декодированы в непустой массив")
	_check(bytes.size() >= 8, "данные длиннее PNG-сигнатуры (8 байт)")
	if bytes.size() >= 8:
		var expected := PackedByteArray([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
		_check(bytes.slice(0, 8) == expected, "первые 8 байт — сигнатура PNG")
	_check(str(result.get("error", "")).is_empty(), "успешный результат без текста ошибки")

	# Пустой data URL без запятой.
	var no_comma := WebFilePicker.decode_data_url("data:image/png;base64")
	_check(not bool(no_comma.get("ok", true)), "data URL без запятой отклонён")
	_check(not str(no_comma.get("error", "")).is_empty(), "у отклонения есть текст ошибки")

	# Не-base64 (percent-encoded) — браузер отдаёт так только при ошибке чтения.
	var percent := WebFilePicker.decode_data_url("data:text/plain,hello%20world")
	_check(not bool(percent.get("ok", true)), "percent-encoded data URL отклонён")

	_check(not bool(WebFilePicker.decode_data_url("").get("ok", true)), "пустая строка отклонена")
	_check(not bool(WebFilePicker.decode_data_url("не base64").get("ok", true)), "мусор отклонён")

	# Данные без base64-маркера, но валидный base64 после запятой.
	var no_marker := WebFilePicker.decode_data_url("data:image/png,iVBORw0KGgo=")
	_check(not bool(no_marker.get("ok", true)), "data URL без ;base64 отклонён")


func _check_bad_input() -> void:
	# pick() — корутина: она ждёт файловый диалог браузера, поэтому вызывается
	# через await. С kind="video" до моста дело не доходит: проверка вида первая.
	var bad := await WebFilePicker.pick("video")
	_check(not bool(bad.get("ok", true)), "неизвестный вид файла отклонён")
	_check(not str(bad.get("error", "")).is_empty(),
			"у неизвестного вида есть текст ошибки")


## Вне веба файлового диалога нет: метод обязан завершиться ошибкой, а не висеть.
func _check_pick_off_web() -> void:
	if OS.has_feature("web"):
		_print("SKIP: проверка pick() вне web неприменима в веб-сборке")
		return
	# Вне веба pick() выходит по проверке OS.has_feature("web") до _open_input(),
	# поэтому JavaScriptBridge в headless-проверке не вызывается вовсе.
	var result := await WebFilePicker.pick("image")
	_check(not bool(result.get("ok", true)), "pick() вне web возвращает ошибку")
	_check(str(result.get("error", "")) == "not_web", "код ошибки not_web")
	_check((result.get("bytes", PackedByteArray()) as PackedByteArray).is_empty(),
			"вне web байтов нет")


func _check(ok: bool, msg: String) -> void:
	if ok:
		_print("OK: " + msg)
	else:
		_fail(msg)


func _fail(msg: String) -> void:
	failures += 1
	printerr("FAIL: " + msg)


func _print(msg: String) -> void:
	print("[web_file_picker_validate] " + msg)


func _finish() -> void:
	if failures > 0:
		printerr("FAILED: %d проверок" % failures)
		get_tree().quit(1)
	else:
		print("[web_file_picker_validate] PASSED: все проверки успешны")
		get_tree().quit(0)
