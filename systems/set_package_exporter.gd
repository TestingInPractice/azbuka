class_name SetPackageExporter
extends RefCounted
## Экспорт набора в .azset.
##
## На web файл скачивается через JavaScriptBridge, на desktop открывается
## FileDialog сохранения. Для тестов есть export_to_path() без диалогов.

const EXPORT_TEMP_DIR := "user://package_exports"


## Экспорт набора с выбором места сохранения.
static func export_set(set_id: String) -> Dictionary:
	var built := build_package_bytes(set_id)
	if not bool(built.get("ok", false)):
		return built
	var file_name := str(built.get("file_name", ""))
	var bytes: PackedByteArray = built.get("bytes", PackedByteArray())
	var skipped := int(built.get("skipped", 0))
	if OS.has_feature("web"):
		var downloaded := download_bytes(bytes, file_name)
		if not bool(downloaded.get("ok", false)):
			return downloaded
		return {
			"ok": true,
			"error": "",
			"path": "",
			"name": file_name,
			"skipped": skipped,
			"message": "файл скачивается",
		}
	var saved := await save_native(bytes, file_name)
	if not bool(saved.get("ok", false)):
		return saved
	return {
		"ok": true,
		"error": "",
		"path": str(saved.get("path", "")),
		"name": file_name,
		"skipped": skipped,
		"message": "файл сохранён",
	}


## Экспорт в конкретный путь без диалогов. Для тестов.
static func export_to_path(set_id: String, output_path: String) -> Dictionary:
	if output_path.strip_edges().is_empty():
		return _failure("write_failed")
	var collected := _collect(set_id)
	if not bool(collected.get("ok", false)):
		return collected
	var written := SetPackageArchive.write_package(
			output_path,
			collected.get("manifest", {}) as Dictionary,
			collected.get("files", {}) as Dictionary)
	if not bool(written.get("ok", false)):
		return written
	var written_size := _file_size(output_path)
	if written_size > SetPackageFormat.MAX_PACKAGE_BYTES:
		SetPackageArchive.cleanup_temp(output_path)
		return _failure("too_large")
	return {
		"ok": true,
		"error": "",
		"path": output_path,
		"name": output_path.get_file(),
		"skipped": int(collected.get("skipped", 0)),
	}


## Собирает ZIP в памяти и возвращает его байты.
static func build_package_bytes(set_id: String) -> Dictionary:
	var collected := _collect(set_id)
	if not bool(collected.get("ok", false)):
		return collected
	var file_name := default_file_name(
			str(CustomSetsStore.get_set_by_id(set_id).get("name", "")))
	var temp_path := "%s/export_%d.azset" % [EXPORT_TEMP_DIR, Time.get_ticks_usec()]
	var written := SetPackageArchive.write_package(
			temp_path,
			collected.get("manifest", {}) as Dictionary,
			collected.get("files", {}) as Dictionary)
	if not bool(written.get("ok", false)):
		return written
	var bytes := _read_file_bytes(temp_path)
	SetPackageArchive.cleanup_temp(temp_path)
	if bytes.is_empty():
		return _failure("write_failed")
	if bytes.size() > SetPackageFormat.MAX_PACKAGE_BYTES:
		return _failure("too_large")
	return {
		"ok": true,
		"error": "",
		"bytes": bytes,
		"file_name": file_name,
		"skipped": int(collected.get("skipped", 0)),
	}


## Имя файла для сохранения. Запрещённые символы заменяются на "_".
static func default_file_name(set_name: String) -> String:
	var safe := set_name.strip_edges()
	for forbidden in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		safe = safe.replace(forbidden, "_")
	if safe.is_empty():
		safe = "набор"
	if safe.length() > SetPackageFormat.MAX_NAME_LENGTH:
		safe = safe.substr(0, SetPackageFormat.MAX_NAME_LENGTH)
	return safe + "." + SetPackageFormat.EXTENSION


## Скачивает байты в браузере. Вне web возвращает not_web.
static func download_bytes(bytes: PackedByteArray, file_name: String) -> Dictionary:
	if not OS.has_feature("web"):
		return _failure("not_web")
	if bytes.is_empty():
		return _failure("write_failed")
	var base64 := Marshalls.raw_to_base64(bytes)
	if base64.is_empty():
		return _failure("write_failed")
	var quoted_name := JSON.stringify(file_name)
	var script := "(function(){var raw=atob('%s');var data=new Uint8Array(raw.length);for(var i=0;i<raw.length;i++){data[i]=raw.charCodeAt(i);}var blob=new Blob([data],{type:'application/zip'});var url=URL.createObjectURL(blob);var link=document.createElement('a');link.href=url;link.download=%s;document.body.appendChild(link);link.click();link.remove();setTimeout(function(){URL.revokeObjectURL(url);},1500);return true;})()" % [base64, quoted_name]
	JavaScriptBridge.eval(script)
	return {"ok": true, "error": ""}


## Нативный диалог сохранения и запись файла.
static func save_native(bytes: PackedByteArray, default_name: String) -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return _failure("no_tree")
	var dialog := FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.use_native_dialog = true
	dialog.filters = PackedStringArray(["*.azset"])
	dialog.title = "Сохранить набор"
	dialog.current_file = default_name
	var outcome := {"path": "", "cancelled": false}
	dialog.file_selected.connect(func(path: String) -> void:
		outcome["path"] = path
	)
	dialog.canceled.connect(func() -> void:
		outcome["cancelled"] = true
	)
	dialog.close_requested.connect(func() -> void:
		outcome["cancelled"] = true
	)
	tree.root.add_child(dialog)
	dialog.popup_centered_ratio(0.8)
	while str(outcome["path"]).is_empty() and not bool(outcome["cancelled"]):
		await tree.process_frame
	dialog.hide()
	dialog.queue_free()
	if bool(outcome["cancelled"]) or str(outcome["path"]).is_empty():
		return _failure("cancelled")
	var path := str(outcome["path"])
	if not path.to_lower().ends_with("." + SetPackageFormat.EXTENSION):
		path += "." + SetPackageFormat.EXTENSION
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _failure("write_failed")
	file.store_buffer(bytes)
	file.close()
	return {"ok": true, "error": "", "path": path}


## Собирает manifest и файлы набора. Пропущенные медиа считаются.
static func _collect(set_id: String) -> Dictionary:
	var record := CustomSetsStore.get_set_by_id(set_id)
	if record.is_empty():
		return _failure("no_set")
	var manifest_entries := {}
	var files := {}
	var skipped := 0
	for letter in CustomSetsStore.get_set_letters(set_id):
		var entry := CustomSetsStore.get_entry(set_id, letter)
		if entry.is_empty():
			continue
		var item := {}
		var word := str(entry.get("word", "")).strip_edges()
		if not word.is_empty():
			item["word"] = word
		var image_rel := str(entry.get("image", ""))
		if not image_rel.is_empty():
			var image_abs := _user_path(image_rel)
			var image_ext := image_abs.get_extension().to_lower()
			if SetPackageFormat.IMAGE_EXTENSIONS.has(image_ext):
				var image_bytes := _read_file_bytes(image_abs)
				if not image_bytes.is_empty():
					var image_zip := "images/" + image_abs.get_file()
					files[image_zip] = image_bytes
					item["image"] = image_zip
				else:
					skipped += 1
			else:
				skipped += 1
		var audio_rel := str(entry.get("audio", ""))
		if not audio_rel.is_empty():
			var audio_abs := _user_path(audio_rel)
			var audio_ext := audio_abs.get_extension().to_lower()
			if SetPackageFormat.AUDIO_EXTENSIONS.has(audio_ext):
				var audio_bytes := _read_file_bytes(audio_abs)
				if not audio_bytes.is_empty():
					var audio_zip := "audio/" + audio_abs.get_file()
					files[audio_zip] = audio_bytes
					item["audio"] = audio_zip
				else:
					skipped += 1
			else:
				skipped += 1
		if not item.is_empty():
			manifest_entries[letter] = item
	if manifest_entries.is_empty():
		return _failure("no_entries")
	var manifest := SetPackageFormat.build_manifest(
			str(record.get("name", "")), manifest_entries)
	var checked := SetPackageFormat.validate_manifest(manifest, files)
	if not bool(checked.get("ok", false)):
		return _failure(str(checked.get("error", "bad_manifest")))
	var total_bytes := 0
	for raw_path in files.keys():
		total_bytes += (files[raw_path] as PackedByteArray).size()
	var total_error := SetPackageFormat.check_uncompressed_size(total_bytes)
	if not total_error.is_empty():
		return _failure(total_error)
	return {
		"ok": true,
		"error": "",
		"manifest": checked.get("manifest", {}) as Dictionary,
		"files": files,
		"skipped": skipped,
	}


static func _user_path(relative: String) -> String:
	if relative.begins_with("user://"):
		return relative
	return "user://" + relative


static func _file_size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0
	var size := file.get_length()
	file.close()
	return size


static func _read_file_bytes(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var bytes := file.get_buffer(file.get_length())
	file.close()
	return bytes


static func _failure(code: String) -> Dictionary:
	return {
		"ok": false,
		"error": code,
		"path": "",
		"name": "",
		"skipped": 0,
	}
