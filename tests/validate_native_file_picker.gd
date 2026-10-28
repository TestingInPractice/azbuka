extends Node
## Валидатор NativeFilePicker/FilePicker: фильтры, mime, чтение файла, бэкенд-диспетчер.
## Запуск: godot --headless --path . res://tests/validate_native_file_picker.tscn

const CustomSetsStoreScript := preload("res://systems/custom_sets_store.gd")

var failures := 0
var scratch_dir := "user://native_picker_test/"


func _ready() -> void:
	await get_tree().process_frame

	if not _class_loaded():
		_fail("NativeFilePicker/FilePicker не загрузились: статические методы недоступны")
		_finish()
		return

	_check_filters()
	_check_mime_mapping()
	_check_backend_dispatch()
	await _check_read_file_success()
	await _check_read_file_missing()
	await _check_read_file_m4a_unsupported()
	await _check_read_file_oversized()
	await _check_read_file_bad_kind()
	await _check_pick_resumes_on_selection()
	await _check_pick_returns_cancelled()
	_cleanup_scratch()

	_finish()


func _class_loaded() -> bool:
	var required := ["filters_for", "mime_for_extension", "read_file", "read_file_with_limit", "pick"]
	var script := NativeFilePicker as Script
	if script == null:
		return false
	var present := {}
	for method: Dictionary in script.get_script_method_list():
		present[method.get("name", "")] = true
	for name: String in required:
		if not present.has(name):
			return false
	var fp_script := FilePicker as Script
	if fp_script == null:
		return false
	var fp_present := {}
	for method: Dictionary in fp_script.get_script_method_list():
		fp_present[method.get("name", "")] = true
	if not fp_present.has("backend_for") or not fp_present.has("pick"):
		return false
	return true


func _check_filters() -> void:
	var img := NativeFilePicker.filters_for("image")
	_check(img.size() == 4, "фильтры картинки: 4 элемента")
	_check(img.has("*.png"), "фильтр картинки содержит *.png")
	_check(img.has("*.jpg"), "фильтр картинки содержит *.jpg")
	_check(img.has("*.jpeg"), "фильтр картинки содержит *.jpeg")
	_check(img.has("*.webp"), "фильтр картинки содержит *.webp")

	var aud := NativeFilePicker.filters_for("audio")
	_check(aud.size() == 3, "фильтры звука: 3 элемента")
	_check(aud.has("*.wav"), "фильтр звука содержит *.wav")
	_check(aud.has("*.ogg"), "фильтр звука содержит *.ogg")
	_check(aud.has("*.mp3"), "фильтр звука содержит *.mp3")

	var unknown := NativeFilePicker.filters_for("video")
	_check(unknown.is_empty(), "неизвестный вид -> пустые фильтры")


func _check_mime_mapping() -> void:
	_check(NativeFilePicker.mime_for_extension("png") == "image/png", "png -> image/png")
	_check(NativeFilePicker.mime_for_extension("jpg") == "image/jpeg", "jpg -> image/jpeg")
	_check(NativeFilePicker.mime_for_extension("jpeg") == "image/jpeg", "jpeg -> image/jpeg")
	_check(NativeFilePicker.mime_for_extension("webp") == "image/webp", "webp -> image/webp")
	_check(NativeFilePicker.mime_for_extension("wav") == "audio/wav", "wav -> audio/wav")
	_check(NativeFilePicker.mime_for_extension("ogg") == "audio/ogg", "ogg -> audio/ogg")
	_check(NativeFilePicker.mime_for_extension("mp3") == "audio/mpeg", "mp3 -> audio/mpeg")
	_check(NativeFilePicker.mime_for_extension(".PNG") == "image/png", "регистр и точка игнорируются")
	_check(NativeFilePicker.mime_for_extension("m4a") == "", "m4a -> пустой mime")
	_check(NativeFilePicker.mime_for_extension("txt") == "", "неподдерживаемое расширение -> пустой mime")


func _check_backend_dispatch() -> void:
	_check(FilePicker.backend_for(true) == "web", "backend_for(true) == web")
	_check(FilePicker.backend_for(false) == "native", "backend_for(false) == native")


func _ensure_scratch() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	dir.make_dir_recursive("native_picker_test")


func _cleanup_scratch() -> void:
	var base := ProjectSettings.globalize_path(scratch_dir)
	if DirAccess.dir_exists_absolute(base):
		var dir := DirAccess.open(base)
		if dir != null:
			dir.list_dir_begin()
			var name := dir.get_next()
			while name != "":
				if name != "." and name != "..":
					var path := base.path_join(name)
					if dir.current_is_dir():
						_remove_dir_recursive(path)
					else:
						DirAccess.remove_absolute(path)
				name = dir.get_next()
			dir.list_dir_end()
		DirAccess.remove_absolute(base)


func _remove_dir_recursive(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		DirAccess.remove_absolute(path)
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name != "." and name != "..":
			var sub := path.path_join(name)
			if dir.current_is_dir():
				_remove_dir_recursive(sub)
			else:
				DirAccess.remove_absolute(sub)
		name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)


func _write_test_file(name: String, bytes: PackedByteArray) -> String:
	_ensure_scratch()
	var path := scratch_dir + name
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_buffer(bytes)
	file.close()
	return ProjectSettings.globalize_path(path)


func _check_read_file_success() -> void:
	var bytes := PackedByteArray([1, 2, 3, 4, 5])
	var path := _write_test_file("test.png", bytes)
	_check(not path.is_empty(), "тестовый файл создан")
	var result := NativeFilePicker.read_file_with_limit(path, "image", 1024)
	_check(bool(result.get("ok", false)), "read_file_with_limit успешен для png")
	_check(str(result.get("error", "")) == "", "успешный результат без ошибки")
	_check(str(result.get("name", "")) == "test.png", "имя файла из пути")
	_check(str(result.get("mime", "")) == "image/png", "mime по расширению")
	var got: PackedByteArray = result.get("bytes", PackedByteArray())
	_check(got.size() == bytes.size(), "байты прочитаны полностью")


func _check_read_file_missing() -> void:
	var result := NativeFilePicker.read_file("/no/such/file.png", "image")
	_check(not bool(result.get("ok", true)), "отсутствующий файл отклонён")
	_check(str(result.get("error", "")) == "read_failed", "код ошибки read_failed")


func _check_read_file_m4a_unsupported() -> void:
	var bytes := PackedByteArray([0, 1, 2])
	var path := _write_test_file("test.m4a", bytes)
	_check(not path.is_empty(), "тестовый m4a создан")
	var result := NativeFilePicker.read_file(path, "audio")
	_check(not bool(result.get("ok", true)), ".m4a отклонён")
	_check(str(result.get("error", "")) == "unsupported_type", "код ошибки unsupported_type")


func _check_read_file_oversized() -> void:
	var bytes := PackedByteArray([1, 2, 3, 4, 5, 6])
	var path := _write_test_file("big.png", bytes)
	_check(not path.is_empty(), "тестовый файл для лимита создан")
	var result := NativeFilePicker.read_file_with_limit(path, "image", 3)
	_check(not bool(result.get("ok", true)), "файл больше лимита отклонён")
	_check(str(result.get("error", "")) == "too_large", "код ошибки too_large")


func _check_read_file_bad_kind() -> void:
	var bytes := PackedByteArray([1, 2, 3])
	var path := _write_test_file("test.png", bytes)
	var empty := NativeFilePicker.read_file(path, "")
	_check(not bool(empty.get("ok", true)), "пустой вид отклонён")
	_check(str(empty.get("error", "")) == "bad_kind", "пустой вид -> bad_kind")
	var unknown := NativeFilePicker.read_file(path, "video")
	_check(not bool(unknown.get("ok", true)), "неизвестный вид отклонён")
	_check(str(unknown.get("error", "")) == "bad_kind", "неизвестный вид -> bad_kind")


## Выбор файла проверяем без человека: диалог появляется в дереве, эмулируем
## его сигнал и убеждаемся, что pick() вернул байты. Ровно этот путь ломался,
## когда результат колбэка складывали в локальную строку: лямбда в GDScript
## захватывает её по значению, и pick() висел вечно.
func _check_pick_resumes_on_selection() -> void:
	var bytes := PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10])
	var path := _write_test_file("pick.png", bytes)
	_check(not path.is_empty(), "файл для проверки pick создан")
	var state := {"done": false, "result": {}}
	_run_pick(state)
	var emitted := false
	for i in range(0, 300):
		await get_tree().process_frame
		var dialog := _find_dialog()
		if dialog != null and not emitted:
			dialog.file_selected.emit(path)
			emitted = true
		if bool(state["done"]):
			break
	_check(emitted, "диалог появился в дереве")
	_check(bool(state["done"]), "pick() завершился после сигнала выбора")
	var result: Dictionary = state["result"]
	_check(bool(result.get("ok", false)), "pick() вернул ok")
	var got: PackedByteArray = result.get("bytes", PackedByteArray())
	_check(got.size() == bytes.size(), "pick() вернул байты файла")
	_check(str(result.get("mime", "")) == "image/png", "pick() вернул mime")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_find_dialog() == null, "диалог удалён из дерева")


func _check_pick_returns_cancelled() -> void:
	var state := {"done": false, "result": {}}
	_run_pick(state)
	var emitted := false
	for i in range(0, 300):
		await get_tree().process_frame
		var dialog := _find_dialog()
		if dialog != null and not emitted:
			dialog.canceled.emit()
			emitted = true
		if bool(state["done"]):
			break
	_check(emitted, "диалог для отмены появился в дереве")
	_check(bool(state["done"]), "pick() завершился после отмены")
	var result: Dictionary = state["result"]
	_check(not bool(result.get("ok", true)), "отмена не даёт ok")
	_check(str(result.get("error", "")) == "cancelled", "отмена -> cancelled")


func _run_pick(state: Dictionary) -> void:
	state["result"] = await NativeFilePicker.pick("image")
	state["done"] = true


func _find_dialog() -> FileDialog:
	for child in get_tree().root.get_children():
		if child is FileDialog:
			return child as FileDialog
	return null


func _check(ok: bool, msg: String) -> void:
	if ok:
		_print("OK: " + msg)
	else:
		_fail(msg)


func _fail(msg: String) -> void:
	failures += 1
	printerr("FAIL: " + msg)


func _print(msg: String) -> void:
	print("[native_file_picker_validate] " + msg)


func _finish() -> void:
	if failures > 0:
		printerr("FAILED: %d проверок" % failures)
		get_tree().quit(1)
	else:
		print("[native_file_picker_validate] PASSED: все проверки успешны")
		get_tree().quit(0)
