class_name SetPackageImporter
extends RefCounted
## Импорт .azset в пользовательские наборы.
##
## Импорт всегда создаёт новый набор. Ошибка на любом шаге удаляет набор и
## записанные файлы, поэтому неудачный импорт не оставляет мусора.

## Импорт из байтов, полученных пикером.
static func import_bytes(package_bytes: PackedByteArray) -> Dictionary:
	var size_error := SetPackageFormat.check_package_size(package_bytes.size())
	if not size_error.is_empty():
		return _failure(size_error)
	var temp := SetPackageArchive.read_bytes_to_temp(package_bytes)
	if not bool(temp.get("ok", false)):
		return _failure(str(temp.get("error", "bad_archive")))
	var temp_path := str(temp.get("path", ""))
	var result := import_path(temp_path)
	SetPackageArchive.cleanup_temp(temp_path)
	return result


## Импорт из пути. Используется тестами и импортом из байтов.
static func import_path(package_path: String) -> Dictionary:
	var probe := FileAccess.open(package_path, FileAccess.READ)
	if probe == null:
		return _failure("read_failed")
	var package_size := probe.get_length()
	probe.close()
	var size_error := SetPackageFormat.check_package_size(package_size)
	if not size_error.is_empty():
		return _failure(size_error)
	var archive := SetPackageArchive.read_package(package_path)
	if not bool(archive.get("ok", false)):
		return _failure(str(archive.get("error", "bad_archive")))
	var validated := SetPackageFormat.validate_manifest(
			archive.get("manifest", null), archive.get("files", {}) as Dictionary)
	if not bool(validated.get("ok", false)):
		return _failure(str(validated.get("error", "bad_manifest")))
	var manifest: Dictionary = validated.get("manifest", {}) as Dictionary
	var files: Dictionary = archive.get("files", {}) as Dictionary
	var record := CustomSetsStore.create_set(str(manifest.get("name", "")))
	if record.is_empty():
		return _failure("create_failed")
	var set_id := str(record.get("id", ""))
	var stored := {}
	var written_paths: Array[String] = []
	var letters: Dictionary = manifest.get("letters", {}) as Dictionary
	for raw_letter in letters.keys():
		var letter := str(raw_letter)
		var source: Dictionary = letters[raw_letter] as Dictionary
		var target_entry := {}
		var word := str(source.get("word", ""))
		if not word.is_empty():
			target_entry["word"] = word
		var image_rel := str(source.get("image", ""))
		if not image_rel.is_empty():
			var image_ext := SetPackageFormat.extension_of(image_rel)
			var image_target := CustomSetsStore.set_dir(set_id) \
					+ CustomSetsStore.image_file_name(letter, image_ext)
			var image_bytes: PackedByteArray = files[image_rel] as PackedByteArray
			if not _write_bytes(image_target, image_bytes):
				_rollback(set_id, written_paths)
				return _failure("write_failed")
			written_paths.append(image_target)
			target_entry["image"] = image_target
		var audio_rel := str(source.get("audio", ""))
		if not audio_rel.is_empty():
			var audio_ext := SetPackageFormat.extension_of(audio_rel)
			var audio_target := CustomSetsStore.set_dir(set_id) \
					+ CustomSetsStore.audio_file_name(letter, audio_ext)
			var audio_bytes: PackedByteArray = files[audio_rel] as PackedByteArray
			if not _write_bytes(audio_target, audio_bytes):
				_rollback(set_id, written_paths)
				return _failure("write_failed")
			written_paths.append(audio_target)
			target_entry["audio"] = audio_target
		stored[letter] = target_entry
	if not CustomSetsStore.set_entries(set_id, stored):
		_rollback(set_id, written_paths)
		return _failure("write_failed")
	return {
		"ok": true,
		"error": "",
		"set_id": set_id,
		"name": str(manifest.get("name", "")),
		"letters": stored.size(),
	}


## Импорт из результата FilePicker.pick("package").
static func import_from_picker(picked: Dictionary) -> Dictionary:
	if not bool(picked.get("ok", false)):
		var error := str(picked.get("error", ""))
		if error.is_empty():
			error = "unsupported_type"
		return _failure(error)
	var bytes: PackedByteArray = picked.get("bytes", PackedByteArray())
	return import_bytes(bytes)


static func _write_bytes(path: String, bytes: PackedByteArray) -> bool:
	if bytes.is_empty():
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	file.close()
	return true


static func _rollback(set_id: String, written_paths: Array[String]) -> void:
	CustomSetsStore.delete_set(set_id)
	for path in written_paths:
		if path.is_empty() or not FileAccess.file_exists(path):
			continue
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _failure(code: String) -> Dictionary:
	return {
		"ok": false,
		"error": code,
		"set_id": "",
		"name": "",
		"letters": 0,
	}
