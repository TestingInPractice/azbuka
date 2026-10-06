class_name WebFilePicker
extends RefCounted
## Выбор файла на устройстве: скрытый <input type="file"> через JavaScriptBridge.
##
## В веб-сборке у Godot нет доступа к файловой системе, поэтому единственный
## способ показать родителю системный выбор файла — создать в DOM скрытый
## <input type="file"> и прочитать выбранный файл как data URL через FileReader.
##
## Слой разделён намеренно:
##   - чистое ядро (kind_for_mime, decode_data_url) не знает про JS и
##     тестируется headless;
##   - pick() — тонкая обёртка над мостом, проверяется только в браузере.
##
## Статический класс: состояния нет, кроме флагов ожидания ответа моста.
##
## Лимит звука 10 МБ — решение этой задачи: запись слова с mikrofona короткая,
## а iPhone отдаёт .m4a, который заметно крупнее WAV той же длительности.

## Разрешённые MIME-типы картинок (квадратная иконка/фото предмета).
const IMAGE_MIME_TYPES := [
	"image/png",
	"image/jpeg",
	"image/webp",
]

## Разрешённые MIME-типы звука. Список НЕ широкий, хотя раньше был таким, и
## добавлять сюда формат «на всякий случай» не надо: он обязан совпадать ровно
## с тем, что CustomSetsStore.extension_for_mime() умеет назвать.
##   - Ложное отвержение. .ogg браузер отдаёт и как audio/ogg, и как
##     audio/vorbis (так его называет часть Linux- и мобильных сборок), и
##     audio/oga. Без этих псевдонимов легальный .ogg уходил в unsupported_type,
##     хотя весь проект озвучивает именно им (*_sound_new.ogg).
##   - Файл без расширения. Принять audio/aac или audio/webm — значит получить
##     в user:// файл, которому нечем дать имя: extension_for_mime() для них
##     возвращает "", и audio_file_name() сохранит его как aud_x. без суффикса.
##     Про них это неважно — контракт проекта WAV/OGG/MP3/M4A, остальное нечем
##     проигрывать.
## Инвариант «каждый тип отсюда даёт непустое расширение, и набор расширений
## ровно {wav, ogg, mp3, m4a}» проверяет tests/validate_web_file_picker.gd.
## Если он падает — не чините таблицу, а приводите её к этому инварианту.
const AUDIO_MIME_TYPES := [
	"audio/wav",
	"audio/x-wav",
	"audio/wave",
	"audio/ogg",
	"audio/vorbis",
	"audio/oga",
	"audio/mpeg",
	"audio/mp3",
	"audio/mp4",
	"audio/x-m4a",
]

## Предельный размер картинки: 5 МБ.
const MAX_IMAGE_BYTES := 5 * 1024 * 1024
## Предельный размер звукового файла: 10 МБ.
const MAX_AUDIO_BYTES := 10 * 1024 * 1024
## Сколько ждём ответа файлового диалога, пока пользователь не выбрал файл.
## Событие change не приходит при отмене, поэтому без таймаута метод бы завис.
const PICK_TIMEOUT_SECONDS := 120.0

## Результат последнего pick(): заполняется JS-колбэком.
static var _pending_result: Dictionary = {}
## Есть ли незакрытый запрос файла. Пока true, pick() ждёт в цикле кадров.
static var _awaiting: bool = false
## Ссылки на JS-объекты текущего запроса. Godot не управляет памятью JS, поэтому
## ссылку на колбэк обязано удерживать поле: браузерный GC снимет её, и
## колбэк просто не вызовется.
##
## create_callback() возвращает JavaScriptObject, а не имя функции. Его
## присваивают обработчику напрямую (input.onchange = _callback_ref) — так
## делают все рабочие реализации. Подставлять его в строку для eval() нельзя:
## это отрендерилось бы в мусор вида "[Object:JavaScriptObject](['',''])".
static var _input_ref: JavaScriptObject = null
static var _callback_ref: JavaScriptObject = null
static var _reader_callback_ref: JavaScriptObject = null
## Созданный на время чтения FileReader. Держится по той же причине, что и
## колбэки: без ссылки JS-объект соберётся до конца async-чтения.
static var _reader_ref: JavaScriptObject = null


## Вид файла по MIME-типу: "image", "audio" или "" для неподдерживаемого.
## Параметры после ";" и регистр игнорируются: браузер отдаёт "audio/wav;codec=1".
static func kind_for_mime(mime: String) -> String:
	var clean := mime.strip_edges().to_lower()
	var semicolon := clean.find(";")
	if semicolon >= 0:
		clean = clean.substr(0, semicolon)
	if IMAGE_MIME_TYPES.has(clean):
		return "image"
	if AUDIO_MIME_TYPES.has(clean):
		return "audio"
	return ""


## Предельный размер файла для вида. 0 — вид неизвестен, любой файл отклонён.
static func max_bytes_for_kind(kind: String) -> int:
	match kind:
		"image":
			return MAX_IMAGE_BYTES
		"audio":
			return MAX_AUDIO_BYTES
		_:
			return 0


## Декодирует "data:<mime>;base64,<данные>" в байты.
## Возвращает {ok, bytes, mime, error}. Percent-encoded (без ";base64")
## отклоняется: браузер отдаёт так только при сбое FileReader.
static func decode_data_url(data_url: String) -> Dictionary:
	var separator := data_url.find(",")
	if separator < 0:
		return _decode_error("bad_data_url")
	var header := data_url.substr(0, separator)
	if not header.begins_with("data:") or not header.contains(";base64"):
		return _decode_error("bad_data_url")
	var mime := header.substr(5, header.length() - 5 - ";base64".length())
	var payload := data_url.substr(separator + 1)
	if mime.is_empty() or payload.is_empty():
		return _decode_error("bad_data_url")
	var bytes := Marshalls.base64_to_raw(payload)
	if bytes.is_empty():
		return _decode_error("bad_data_url")
	return {"ok": true, "bytes": bytes, "mime": mime, "error": ""}


## Показывает системный выбор файла и возвращает его содержимое.
## kind — "image" или "audio". Результат: {ok, bytes, mime, name, error}.
## Вне веба возвращает ошибку "not_web": файлового диалога там нет.
## Отмена пользователем и молчание диалога оба дают "cancelled" по таймауту:
## событие change при отмене не приходит, ждать бессмысленно.
static func pick(kind: String) -> Dictionary:
	if max_bytes_for_kind(kind) == 0:
		return _pick_error(kind, "bad_kind")
	if _awaiting:
		# Мобильный симптом: пока системный диалог открыт, повторное нажатие
		# возвращало already_open и навсегда заклинивало _awaiting на 120 с —
		# новый выбор был невозможен до перезагрузки. Повторный click() по
		# уже открытому input — best effort разбудить тот же системный диалог,
		# после чего отдаём already_open вызывающему, чтобы тот показал
		# сообщение, а не молчал.
		if _input_ref != null:
			_input_ref.click()
		return _pick_error(kind, "already_open")
	if not OS.has_feature("web"):
		return _pick_error(kind, "not_web")
	_pending_result = {}
	_awaiting = true
	if not _open_input(kind):
		_awaiting = false
		_cleanup_input()
		return _pick_error(kind, "no_bridge")
	# Engine.get_main_loop() типизирован как MainLoop, а create_timer и
	# process_frame есть только у SceneTree — без приведения к SceneTree
	# статический анализатор не может вывести тип timer.
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_awaiting = false
		_cleanup_input()
		return _pick_error(kind, "no_bridge")
	var timer := tree.create_timer(PICK_TIMEOUT_SECONDS)
	while _awaiting and timer.time_left > 0.0:
		await tree.process_frame
	if _awaiting:
		# Пользователь не выбрал файл и не отменил диалог — считаем отменой.
		_awaiting = false
		_cleanup_input()
		return _pick_error(kind, "cancelled")
	_cleanup_input()
	return _pending_result


## Создаёт скрытый <input type="file"> и навешивает колбэк выбора файла.
## Элемент создаётся вызовом document.createElement, а не строкой для eval():
## так колбэк передаётся в JS объектом и не зависит от того, как Godot
## назовёт сгенерированную функцию.
static func _open_input(kind: String) -> bool:
	var document := JavaScriptBridge.get_interface("document")
	if document == null:
		return false
	_callback_ref = JavaScriptBridge.create_callback(_on_input_changed)
	_reader_callback_ref = JavaScriptBridge.create_callback(_on_file_read)
	_input_ref = document.createElement("input")
	if _input_ref == null:
		return false
	_input_ref.type = "file"
	_input_ref.accept = _accept_attribute(kind)
	_input_ref.style.display = "none"
	_input_ref.onchange = _callback_ref
	document.body.appendChild(_input_ref)
	_input_ref.click()
	return true


## Снимает input с DOM и отпускает ссылки на колбэки. Без этого следующий
## pick() не откроет диалог, а в document останутся мёртвые узлы.
static func _cleanup_input() -> void:
	if _input_ref != null:
		var document := JavaScriptBridge.get_interface("document")
		if document != null and document.body != null:
			document.body.removeChild(_input_ref)
	_input_ref = null
	_callback_ref = null
	_reader_callback_ref = null
	_reader_ref = null


## Приём файлов для accept-атрибута. Для неизвестного вида пустая строка:
## тогда input не ограничивает выбор, а pick() всё равно отклонит результат.
static func _accept_attribute(kind: String) -> String:
	match kind:
		"image":
			return ",".join(PackedStringArray(IMAGE_MIME_TYPES))
		"audio":
			return ",".join(PackedStringArray(AUDIO_MIME_TYPES))
		_:
			return ""


## Колбэк события change у скрытого input. args[0] — DOM-событие, сам файл
## лежит в args[0].target.files[0]. У пустого files[0] бывает и у отмены:
## браузер отдаёт change с пустым списком, а на некоторых мобильных не
## отдаёт ничего вовсе — отмену ловит таймаут в pick().
static func _on_input_changed(args: Array) -> void:
	if not _awaiting or args.is_empty():
		return
	var event: JavaScriptObject = args[0]
	if event == null or event.target == null:
		return
	var files: JavaScriptObject = event.target.files
	if files == null or files.length == 0:
		_finish_with_error("cancelled")
		return
	var file: JavaScriptObject = files.item(0)
	if file == null:
		_finish_with_error("cancelled")
		return
	# Ссылка на FileReader держится в _reader_ref: JS собирает мусор сам, и
	# без поля сборщик успеет снять объект до конца async-чтения.
	_reader_ref = JavaScriptBridge.create_object("FileReader")
	_reader_ref.onload = _reader_callback_ref
	_reader_ref.onerror = _reader_callback_ref
	_reader_ref.readAsDataURL(file)


## Колбэк FileReader. args[0] — ProgressEvent, у него target.result
## (прочитанный data URL) и target.name (имя файла).
static func _on_file_read(args: Array) -> void:
	if not _awaiting or args.is_empty():
		return
	var event: JavaScriptObject = args[0]
	if event == null or event.target == null:
		_finish_with_error("bad_data_url")
		return
	var file_name := str(event.target.name)
	var data_url := str(event.target.result)
	if file_name.is_empty() or data_url.is_empty():
		_finish_with_error("cancelled")
		return
	var decoded := decode_data_url(data_url)
	if not bool(decoded.get("ok", false)):
		_finish_with_error(str(decoded.get("error", "bad_data_url")))
		return
	var mime := str(decoded.get("mime", ""))
	var kind := kind_for_mime(mime)
	var bytes: PackedByteArray = decoded.get("bytes", PackedByteArray())
	if kind.is_empty():
		_finish_with_error("unsupported_type")
		return
	if bytes.size() > max_bytes_for_kind(kind):
		_finish_with_error("too_large")
		return
	_pending_result = {
		"ok": true,
		"bytes": bytes,
		"mime": mime,
		"name": file_name,
		"error": "",
	}
	_awaiting = false
	_reader_ref = null


## Завершает ожидание ответом с ошибкой. Общая точка выхода для всех
## неуспешных ветвей, чтобы сброс _awaiting не дублировался.
static func _finish_with_error(code: String) -> void:
	_pending_result = _pick_error("any", code)
	_awaiting = false


## Ответ decode_data_url с ошибкой. Байтов нет, mime пустой.
static func _decode_error(code: String) -> Dictionary:
	return {"ok": false, "bytes": PackedByteArray(), "mime": "", "error": code}


## Ответ pick с ошибкой. name и mime пустые, байтов нет.
static func _pick_error(kind: String, code: String) -> Dictionary:
	return {
		"ok": false,
		"bytes": PackedByteArray(),
		"mime": "",
		"name": "",
		"error": code,
	}
