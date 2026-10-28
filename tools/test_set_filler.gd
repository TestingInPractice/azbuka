class_name TestSetFiller
extends RefCounted
## Наполняет пользовательский набор встроенными медиа для ручной проверки.
##
## Зачем: конструктор проверяется руками, а 33 буквы через нативные диалоги
## занимают вечер. Инструмент берёт те же слово, картинку и звук, что игра
## показывает в наборе 1, и раскладывает их в user:// так же, как редактор.
##
## Почему не через UI: SetEditor применяет картинку и звук по одному и ждёт
## сигналов диалога. Здесь нужен пакетный прогон, поэтому используются те же
## низкоуровневые контракты (ImageSaver, CustomSetsStore), а не кнопки.
##
## Прогресс не читается: чтобы записать файлы, активный набор не нужен.
## В метаданные пути пишутся относительными (без user://), потому что именно
## такой вид CustomSetsStore хранит и возвращает из get_entry().

const DEFAULT_SET_NAME := "Тестовый набор"

const Files := preload("res://tools/test_set_files.gd")
const Writer := preload("res://tools/test_set_letter_writer.gd")


## Результат: {ok, error, set_id, set_name, created, requested, complete, failed,
## export_dir, export_files}. options: name, set_id, letters (пустой массив
## означает все буквы), reset, export_dir.
func fill(options: Dictionary) -> Dictionary:
	var requested_name := str(options.get("name", "")).strip_edges()
	var wanted_id := str(options.get("set_id", "")).strip_edges()
	var reset := bool(options.get("reset", false))
	var export_dir := ""
	var export_raw := str(options.get("export_dir", "")).strip_edges()
	if not export_raw.is_empty():
		export_dir = Files.resolve_path(export_raw)
		if not Files.ensure_dir(export_dir):
			return _error("не удалось создать каталог выгрузки: " + export_dir)

	var target := _resolve_target(wanted_id, requested_name, reset)
	if target.has("error"):
		return _error(str(target["error"]))
	var set_name := str(target.get("name", ""))
	if set_name.is_empty():
		set_name = requested_name if not requested_name.is_empty() else DEFAULT_SET_NAME

	if reset and not target.get("record", {}).is_empty():
		var old_id := str(target["record"].get("id", ""))
		if not CustomSetsStore.delete_set(old_id):
			return _error("не удалось удалить набор: " + old_id)
		target["record"] = {}
	if target.get("record", {}).is_empty():
		target["record"] = CustomSetsStore.create_set(set_name)
		if target["record"].is_empty():
			return _error("не удалось создать набор: " + set_name)
		target["created"] = true
	var created := bool(target.get("created", false))
	var set_id := str(target["record"].get("id", ""))
	if set_id.is_empty():
		return _error("набор создан без id")

	if not Files.ensure_dir(CustomSetsStore.set_dir(set_id)):
		return _error("не удалось создать каталог набора: " + CustomSetsStore.set_dir(set_id))

	var requested := _requested_letters(options.get("letters", []))
	var complete: Array[String] = []
	var failed: Array[Dictionary] = []
	var export_files := 0
	var writer := Writer.new()
	for letter: String in requested:
		var written := writer.write(set_id, letter, export_dir)
		if not str(written.get("error", "")).is_empty():
			var reason := str(written["error"])
			push_warning("fill_test_set: буква %s пропущена: %s" % [letter, reason])
			failed.append({"letter": letter, "reason": reason})
			continue
		export_files += int(written.get("exported", 0))
		# Проверка идёт по хранилищу, а не по факту записи: is_entry_complete()
		# и наличие файлов это ровно то, что увидит игра.
		var check := writer.verify(set_id, letter)
		if not check.is_empty():
			push_warning("fill_test_set: буква %s не прошла проверку: %s" % [letter, check])
			failed.append({"letter": letter, "reason": check})
			continue
		complete.append(letter)

	return {
		"ok": failed.is_empty(),
		"error": "",
		"set_id": set_id,
		"set_name": set_name,
		"created": created,
		"requested": requested,
		"complete": complete,
		"failed": failed,
		"export_dir": export_dir,
		"export_files": export_files,
	}


## Ищет набор по id или имени. При --reset набора может не быть: это не ошибка,
## потому что сброс пустого имени означает "создать заново".
func _resolve_target(wanted_id: String, requested_name: String, reset: bool) -> Dictionary:
	if not wanted_id.is_empty():
		var record := CustomSetsStore.get_set_by_id(wanted_id)
		if record.is_empty() and not reset:
			return {"error": "набор не найден: " + wanted_id}
		return {"record": record, "name": str(record.get("name", "")), "created": false}
	var lookup_name := requested_name if not requested_name.is_empty() else DEFAULT_SET_NAME
	var matches := _find_by_name(lookup_name)
	if matches.size() > 1:
		# Дубликаты имён мог создать только внешний сценарий. Инструмент обновляет
		# первый набор, чтобы не удалить чужую работу молча.
		push_warning("fill_test_set: наборов с именем '%s' несколько, беру первый" % lookup_name)
	var record := matches[0] if not matches.is_empty() else {}
	return {"record": record, "name": lookup_name, "created": false}


func _find_by_name(set_name: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for record: Dictionary in CustomSetsStore.get_sets():
		if str(record.get("name", "")) == set_name:
			found.append(record)
	return found


## Пустой список означает весь алфавит. Порядок аргумента сохраняется, дубли
## убираются: повторная буква записала бы те же файлы второй раз впустую.
func _requested_letters(raw: Variant) -> Array[String]:
	var requested: Array[String] = []
	if raw is Array and not (raw as Array).is_empty():
		for value: Variant in raw:
			var letter := str(value).strip_edges().to_upper()
			if letter.is_empty() or requested.has(letter):
				continue
			requested.append(letter)
		return requested
	for record: Dictionary in AlphabetData.get_letters():
		requested.append(str(record.get("letter", "")))
	return requested


func _error(message: String) -> Dictionary:
	return {
		"ok": false, "error": message, "set_id": "", "set_name": "", "created": false,
		"requested": [], "complete": [], "failed": [], "export_dir": "", "export_files": 0,
	}
