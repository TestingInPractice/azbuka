class_name SetPackageArchive
extends RefCounted
## Чтение и запись ZIP-контейнера .azset.
##
## Архив не проверяет manifest: это делает SetPackageFormat. Здесь только
## байты, ZIP-записи и временные файлы.

const TEMP_DIR := "user://package_tmp"


## Записывает manifest и файлы в ZIP. Пути файлов уже относительные.
static func write_package(output_path: String, manifest: Dictionary, files: Dictionary) -> Dictionary:
	if output_path.strip_edges().is_empty():
		return _failure("write_failed")
	_ensure_dir(output_path.get_base_dir())
	var packer := ZIPPacker.new()
	var open_error := packer.open(output_path)
	if open_error != OK:
		return _failure("write_failed")
	var manifest_error := packer.start_file(SetPackageFormat.MANIFEST_NAME)
	if manifest_error != OK:
		packer.close()
		return _failure("write_failed")
	var manifest_bytes := JSON.stringify(manifest, "  ").to_utf8_buffer()
	var manifest_write := packer.write_file(manifest_bytes)
	packer.close_file()
	if manifest_write != OK:
		packer.close()
		return _failure("write_failed")
	var paths := files.keys()
	paths.sort()
	for raw_path in paths:
		var path := str(raw_path)
		var blob: Variant = files[raw_path]
		if typeof(blob) != TYPE_PACKED_BYTE_ARRAY:
			continue
		var start_error := packer.start_file(path)
		if start_error != OK:
			packer.close()
			return _failure("write_failed")
		var write_error := packer.write_file(blob as PackedByteArray)
		packer.close_file()
		if write_error != OK:
			packer.close()
			return _failure("write_failed")
	var close_error := packer.close()
	if close_error != OK:
		return _failure("write_failed")
	return {"ok": true, "error": ""}


## Читает ZIP и возвращает {ok, error, manifest, files}.
static func read_package(package_path: String) -> Dictionary:
	var reader := ZIPReader.new()
	var open_error := reader.open(package_path)
	if open_error != OK:
		return _failure("bad_archive")
	var names := reader.get_files()
	if names.size() > SetPackageFormat.MAX_FILES:
		reader.close()
		return _failure("too_many_files")
	if not names.has(SetPackageFormat.MANIFEST_NAME):
		reader.close()
		return _failure("missing_manifest")
	var manifest_bytes := reader.read_file(SetPackageFormat.MANIFEST_NAME)
	if manifest_bytes.size() > SetPackageFormat.MAX_MANIFEST_BYTES:
		reader.close()
		return _failure("too_large")
	var parsed: Variant = JSON.parse_string(manifest_bytes.get_string_from_utf8())
	if not (parsed is Dictionary):
		reader.close()
		return _failure("bad_manifest")
	var files := {}
	var total_bytes := 0
	for name in names:
		if name == SetPackageFormat.MANIFEST_NAME or name.ends_with("/"):
			continue
		var bytes := reader.read_file(name)
		total_bytes += bytes.size()
		if total_bytes > SetPackageFormat.MAX_TOTAL_UNCOMPRESSED_BYTES:
			reader.close()
			return _failure("too_large")
		files[name] = bytes
	reader.close()
	return {
		"ok": true,
		"error": "",
		"manifest": parsed as Dictionary,
		"files": files,
	}


## Кладёт байты пакета во временный файл. Нужно, потому что ZIPReader умеет
## открывать только путь, а не PackedByteArray.
static func read_bytes_to_temp(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty():
		return _failure("bad_archive")
	_ensure_dir(TEMP_DIR)
	var path := "%s/import_%d.azset" % [TEMP_DIR, Time.get_ticks_usec()]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _failure("write_failed")
	file.store_buffer(bytes)
	file.close()
	return {"ok": true, "error": "", "path": path}


## Удаляет временный файл. Отсутствие файла не считается ошибкой.
static func cleanup_temp(path: String) -> void:
	if path.is_empty():
		return
	if not FileAccess.file_exists(path):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _ensure_dir(path: String) -> void:
	if path.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "error": code}
