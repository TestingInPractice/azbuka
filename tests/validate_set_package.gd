extends Node
## Валидатор .azset: формат manifest, ZIP-архив, импорт, экспорт и пикеры.
## Запуск: godot --headless --path . res://tests/validate_set_package.tscn

const TEST_STORE_PATH := "user://set_package_test_store.json"
const TEST_SETS_DIR := "user://set_package_test_sets"
const TEST_PACKAGE := "user://set_package_test.azset"
const TEST_EXPORT := "user://set_package_export_test.azset"
const TEMP_PACKAGE := "user://set_package_temp_test.azset"
const SetsDirIsolation := preload("res://tests/test_sets_dir.gd")
var PNG_BYTES := PackedByteArray([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
var OGG_BYTES := PackedByteArray([0x4F, 0x67, 0x67, 0x53, 0x00, 0x02])

var failures := 0
var checks := 0
var _saved_store_path := ""
var _saved_sets_dir := ""


func _ready() -> void:
	await get_tree().process_frame
	if not _class_loaded():
		_fail("SetPackage* не загрузились: статические методы недоступны")
		_finish()
		return
	_setup_store()
	_check_format()
	_check_paths()
	_check_manifest_errors()
	_check_archive()
	_check_importer()
	_check_exporter()
	await _check_pickers()
	_check_ui_nodes()
	_cleanup()
	_finish()


func _class_loaded() -> bool:
	var required := {
		"SetPackageFormat": ["build_manifest", "validate_manifest", "safe_relative_path"],
		"SetPackageArchive": ["write_package", "read_package", "read_bytes_to_temp"],
		"SetPackageImporter": ["import_path", "import_bytes", "import_from_picker"],
		"SetPackageExporter": ["export_to_path", "build_package_bytes", "default_file_name"],
	}
	for class_name_text: String in required:
		var script: Script = null
		match class_name_text:
			"SetPackageFormat":
				script = SetPackageFormat as Script
			"SetPackageArchive":
				script = SetPackageArchive as Script
			"SetPackageImporter":
				script = SetPackageImporter as Script
			"SetPackageExporter":
				script = SetPackageExporter as Script
		if script == null:
			return false
		var present := {}
		for method: Dictionary in script.get_script_method_list():
			present[str(method.get("name", ""))] = true
		for method_name: String in required[class_name_text]:
			if not present.has(method_name):
				return false
	return true


func _setup_store() -> void:
	_saved_store_path = CustomSetsStore.save_path
	_saved_sets_dir = SetsDirIsolation.begin(TEST_SETS_DIR)
	CustomSetsStore.save_path = TEST_STORE_PATH
	if FileAccess.file_exists(TEST_STORE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_STORE_PATH))
	CustomSetsStore.clear_memory()
	CustomSetsStore.load_sets()


func _check_format() -> void:
	var entries := {
		"а": {"word": "  Арбуз  ", "image": "images/a.png", "audio": "audio/a.ogg"},
		"Б": {"word": "Банан"},
	}
	var manifest := SetPackageFormat.build_manifest("  Мой набор  ", entries)
	_check(str(manifest.get("format", "")) == "azbuka-set", "format = azbuka-set")
	_check(int(manifest.get("version", 0)) == 1, "version = 1")
	_check(str(manifest.get("name", "")) == "Мой набор", "имя обрезано по краям")
	var letters: Dictionary = manifest.get("letters", {}) as Dictionary
	_check(letters.has("А") and letters.has("Б"), "строчная буква нормализована")
	_check(str((letters["А"] as Dictionary).get("word", "")) == "Арбуз",
			"слово обрезано по краям")
	_check(not (letters["Б"] as Dictionary).has("image"),
			"необязательная картинка не попала в manifest")

	var long_name := "Н".repeat(SetPackageFormat.MAX_NAME_LENGTH + 10)
	var long_word := "С".repeat(SetPackageFormat.MAX_WORD_LENGTH + 10)
	var truncated := SetPackageFormat.build_manifest(long_name, {
		"А": {"word": long_word},
	})
	_check(str(truncated.get("name", "")).length() == SetPackageFormat.MAX_NAME_LENGTH,
			"длинное имя обрезано до лимита")
	_check(str(((truncated.get("letters", {}) as Dictionary)["А"] as Dictionary)
			.get("word", "")).length() == SetPackageFormat.MAX_WORD_LENGTH,
			"длинное слово обрезано до лимита")

	_check(SetPackageFormat.normalize_letter("  я ") == "Я",
			"normalize_letter поднимает регистр и режет пробелы")
	_check(SetPackageFormat.extension_of("images/A.PNG") == "png",
			"extension_of приводит к нижнему регистру")
	_check(SetPackageFormat.check_package_size(SetPackageFormat.MAX_PACKAGE_BYTES).is_empty(),
			"пакет на лимите допустим")
	_check(SetPackageFormat.check_package_size(SetPackageFormat.MAX_PACKAGE_BYTES + 1) == "too_large",
			"пакет сверх лимита отклонён")
	_check(SetPackageFormat.check_uncompressed_size(
			SetPackageFormat.MAX_TOTAL_UNCOMPRESSED_BYTES + 1) == "too_large",
			"распакованный размер сверх лимита отклонён")


func _check_paths() -> void:
	var valid := SetPackageFormat.safe_relative_path("images/sub/a.webp", "images/")
	_check(bool(valid.get("ok", false)), "вложенный путь внутри images/ допустим")
	_check(str(valid.get("path", "")) == "images/sub/a.webp", "валидный путь не меняется")
	for bad_path: String in [
		"", "/images/a.png", "\\images\\a.png", "images\\a.png", "../images/a.png",
		"images/../a.png", "images//a.png", "user://images/a.png", "res://images/a.png",
		"C:/images/a.png", "audio/a.ogg",
	]:
		var result := SetPackageFormat.safe_relative_path(bad_path, "images/")
		_check(not bool(result.get("ok", true)), "недопустимый путь отклонён: " + bad_path)
	_check(not str(SetPackageFormat.safe_relative_path("", "images/")
			.get("error", "")).is_empty(), "пустой путь даёт код ошибки")


func _check_manifest_errors() -> void:
	var files := {
		"images/a.png": PNG_BYTES,
		"audio/a.ogg": OGG_BYTES,
	}
	var good := SetPackageFormat.build_manifest("Набор", {
		"А": {"word": "Арбуз", "image": "images/a.png", "audio": "audio/a.ogg"},
	})
	var valid := SetPackageFormat.validate_manifest(good, files)
	_check(bool(valid.get("ok", false)), "валидный manifest принят")
	_check(str((valid.get("manifest", {}) as Dictionary).get("name", "")) == "Набор",
			"валидный manifest возвращает имя")
	_check(not SetPackageFormat.validate_manifest(null, files).get("ok", true),
			"null manifest отклонён")
	_check(_manifest_error(good, files, "format", "other") == "bad_format",
			"чужой format отклонён")
	_check(_manifest_error(good, files, "version", 2) == "bad_version",
			"чужая версия отклонена")
	_check(_manifest_error(good, files, "name", "  ") == "empty_name",
			"пустое имя отклонено")
	_check(_manifest_error(good, files, "name", "Н".repeat(61)) == "name_too_long",
			"длинное имя отклонено")
	_check(_manifest_error(good, files, "letters", {}) == "bad_letters",
			"пустые letters отклонены")
	var many := {}
	for index in 34:
		many["X%d" % index] = {"word": "x"}
	_check(_manifest_error(good, files, "letters", many) == "too_many_letters",
			"34 буквы отклонены")
	_check(_manifest_error(good, files, "letters", {"X": {"word": "x"}}) == "unknown_letter",
			"неизвестная буква отклонена")
	_check(_manifest_error(good, files, "letters",
			{"А": {"word": "a"}, "а": {"word": "b"}}) == "duplicate_letter",
			"дубликат после нормализации отклонён")
	_check(_manifest_error(good, files, "letters", {"А": "not a dictionary"}) == "bad_entry",
			"не-Dictionary запись отклонена")
	_check(_manifest_error(good, files, "letters", {"А": {}}) == "empty_entry",
			"пустая запись отклонена")
	_check(_manifest_error(good, files, "letters",
			{"А": {"word": "С".repeat(41)}}) == "word_too_long",
			"длинное слово отклонено")
	_check(_manifest_error(good, files, "letters",
			{"А": {"image": "../a.png"}}) == "bad_path",
			"опасный путь картинки отклонён")
	_check(_manifest_error(good, files, "letters",
			{"А": {"image": "images/a.bmp"}}) == "bad_extension",
			"неподдерживаемое расширение отклонено")
	_check(_manifest_error(good, files, "letters",
			{"А": {"image": "images/missing.png"}}) == "missing_media",
			"отсутствующий файл отклонён")
	_check(_manifest_error(good, files, "letters",
			{"А": {"image": "images/a.png"}}) == "",
			"существующий файл принят")
	var empty_files := files.duplicate()
	empty_files["images/a.png"] = PackedByteArray()
	_check(_manifest_error(good, empty_files, "letters",
			{"А": {"image": "images/a.png"}}) == "empty_media",
			"пустой файл отклонён")


func _manifest_error(base: Dictionary, files: Dictionary, key: String, value: Variant) -> String:
	var manifest := base.duplicate(true)
	manifest[key] = value
	var result := SetPackageFormat.validate_manifest(manifest, files)
	return str(result.get("error", ""))


func _check_archive() -> void:
	_remove(TEST_PACKAGE)
	var manifest := SetPackageFormat.build_manifest("Архив", {
		"А": {"word": "Арбуз", "image": "images/a.png", "audio": "audio/a.ogg"},
	})
	var written := SetPackageArchive.write_package(TEST_PACKAGE, manifest, {
		"images/a.png": PNG_BYTES,
		"audio/a.ogg": OGG_BYTES,
	})
	_check(bool(written.get("ok", false)), "ZIP записан")
	_check(FileAccess.file_exists(TEST_PACKAGE), "файл пакета существует")
	var read := SetPackageArchive.read_package(TEST_PACKAGE)
	_check(bool(read.get("ok", false)), "ZIP прочитан")
	var read_files: Dictionary = read.get("files", {}) as Dictionary
	_check(read_files.has("images/a.png"), "картинка прочитана из ZIP")
	_check(read_files.has("audio/a.ogg"), "звук прочитан из ZIP")
	_check((read_files["images/a.png"] as PackedByteArray) == PNG_BYTES,
			"байты картинки совпали")
	_check(str((read.get("manifest", {}) as Dictionary).get("name", "")) == "Архив",
			"manifest прочитан из ZIP")

	var bad := SetPackageArchive.read_package("user://no_such_package.azset")
	_check(str(bad.get("error", "")) == "bad_archive", "несуществующий архив отклонён")
	_write_raw_zip("user://set_package_no_manifest.azset", {
		"readme.txt": PackedByteArray([1]),
	})
	_check(str(SetPackageArchive.read_package("user://set_package_no_manifest.azset")
			.get("error", "")) == "missing_manifest", "ZIP без manifest отклонён")
	_remove("user://set_package_no_manifest.azset")

	var many := {}
	for index in SetPackageFormat.MAX_FILES + 1:
		many["file_%d.bin" % index] = PackedByteArray([1])
	_write_raw_zip("user://set_package_too_many.azset", many)
	_check(str(SetPackageArchive.read_package("user://set_package_too_many.azset")
			.get("error", "")) == "too_many_files", "ZIP с лишними файлами отклонён")
	_remove("user://set_package_too_many.azset")

	var temp := SetPackageArchive.read_bytes_to_temp(PNG_BYTES)
	_check(bool(temp.get("ok", false)), "байты положены во временный файл")
	var temp_path := str(temp.get("path", ""))
	_check(FileAccess.file_exists(temp_path), "временный файл существует")
	SetPackageArchive.cleanup_temp(temp_path)
	_check(not FileAccess.file_exists(temp_path), "временный файл удалён")


func _check_importer() -> void:
	var manifest := SetPackageFormat.build_manifest("Импорт", {
		"а": {"word": "Арбуз", "image": "images/arbuz.png", "audio": "audio/arbuz.ogg"},
		"Б": {"word": "Банан"},
	})
	var written := SetPackageArchive.write_package(TEST_PACKAGE, manifest, {
		"images/arbuz.png": PNG_BYTES,
		"audio/arbuz.ogg": OGG_BYTES,
	})
	_check(bool(written.get("ok", false)), "пакет для импорта записан")
	var imported := SetPackageImporter.import_path(TEST_PACKAGE)
	_check(bool(imported.get("ok", false)), "импорт пути успешен")
	var set_id := str(imported.get("set_id", ""))
	_check(not set_id.is_empty(), "импорт вернул set_id")
	_check(str(imported.get("name", "")) == "Импорт", "импорт вернул имя")
	_check(int(imported.get("letters", 0)) == 2, "импорт вернул число букв")
	_check(not CustomSetsStore.get_set_by_id(set_id).is_empty(), "набор появился в хранилище")
	var entry_a := CustomSetsStore.get_entry(set_id, "А")
	_check(str(entry_a.get("word", "")) == "Арбуз", "слово импортировано")
	_check(str(entry_a.get("image", "")).ends_with("img_a.png"),
			"картинка импортирована с исходным расширением")
	_check(str(entry_a.get("audio", "")).ends_with("aud_a.ogg"),
			"звук импортирован с исходным расширением")
	_check(FileAccess.file_exists("user://" + str(entry_a.get("image", ""))),
			"файл картинки существует")
	_check(FileAccess.file_exists("user://" + str(entry_a.get("audio", ""))),
			"файл звука существует")

	var imported_again := SetPackageImporter.import_path(TEST_PACKAGE)
	_check(bool(imported_again.get("ok", false)), "повторный импорт успешен")
	_check(str(imported_again.get("set_id", "")) != set_id,
			"повторный импорт создаёт новый набор")

	var bytes := _read_bytes(TEST_PACKAGE)
	var imported_bytes := SetPackageImporter.import_bytes(bytes)
	_check(bool(imported_bytes.get("ok", false)), "импорт из байтов успешен")
	_check(str(imported_bytes.get("set_id", "")) != set_id,
			"импорт из байтов создаёт новый набор")

	var set_count := CustomSetsStore.get_sets().size()
	var bad_manifest := manifest.duplicate(true)
	bad_manifest["format"] = "other"
	SetPackageArchive.write_package("user://set_package_bad_manifest.azset", bad_manifest, {})
	var bad_import := SetPackageImporter.import_path("user://set_package_bad_manifest.azset")
	_check(not bool(bad_import.get("ok", true)), "плохой manifest не импортируется")
	_check(str(bad_import.get("error", "")) == "bad_format", "код ошибки bad_format")
	_check(CustomSetsStore.get_sets().size() == set_count, "плохой импорт не создал набор")
	_remove("user://set_package_bad_manifest.azset")


func _check_exporter() -> void:
	var created := CustomSetsStore.create_set("Экспорт")
	var set_id := str(created.get("id", ""))
	_check(not set_id.is_empty(), "набор для экспорта создан")
	var image_path := CustomSetsStore.set_dir(set_id) + CustomSetsStore.image_file_name("А", "png")
	var audio_path := CustomSetsStore.set_dir(set_id) + CustomSetsStore.audio_file_name("А", "ogg")
	_write_bytes(image_path, PNG_BYTES)
	_write_bytes(audio_path, OGG_BYTES)
	_check(CustomSetsStore.set_entries(set_id, {
		"А": {"word": "Арбуз", "image": image_path, "audio": audio_path},
		"Б": {"word": "Банан"},
	}), "set_entries сохранил две буквы одним вызовом")
	_check(str(CustomSetsStore.get_entry(set_id, "А").get("image", ""))
			.ends_with("img_a.png"), "set_entries сохранил расширение картинки")

	_remove(TEST_EXPORT)
	var exported := SetPackageExporter.export_to_path(set_id, TEST_EXPORT)
	_check(bool(exported.get("ok", false)), "export_to_path успешен")
	_check(FileAccess.file_exists(TEST_EXPORT), "экспортированный файл существует")
	var read := SetPackageArchive.read_package(TEST_EXPORT)
	_check(bool(read.get("ok", false)), "экспортированный ZIP читается")
	var read_files: Dictionary = read.get("files", {}) as Dictionary
	_check(read_files.has("images/img_a.png"), "картинка попала в экспорт")
	_check(read_files.has("audio/aud_a.ogg"), "звук попал в экспорт")
	var read_manifest: Dictionary = read.get("manifest", {}) as Dictionary
	var read_letters: Dictionary = read_manifest.get("letters", {}) as Dictionary
	_check(read_letters.has("А") and read_letters.has("Б"), "обе буквы в manifest")
	_check(str((read_letters["А"] as Dictionary).get("word", "")) == "Арбуз",
			"слово в экспортированном manifest")
	_check(not (read_letters["Б"] as Dictionary).has("image"),
			"буква без медиа экспортирована без image")

	var built := SetPackageExporter.build_package_bytes(set_id)
	_check(bool(built.get("ok", false)), "build_package_bytes успешен")
	_check(not (built.get("bytes", PackedByteArray()) as PackedByteArray).is_empty(),
			"build_package_bytes вернул байты")
	_check(str(built.get("file_name", "")).ends_with(".azset"),
			"имя файла оканчивается на .azset")
	_check(str(SetPackageExporter.default_file_name("Мой/набор: 1")) == "Мой_набор_ 1.azset",
			"default_file_name заменяет запрещённые символы")

	var empty := CustomSetsStore.create_set("Пустой экспорт")
	var empty_id := str(empty.get("id", ""))
	var empty_export := SetPackageExporter.export_to_path(empty_id,
			"user://set_package_empty_export.azset")
	_check(str(empty_export.get("error", "")) == "no_entries",
			"экспорт пустого набора отклонён")
	_check(str(SetPackageExporter.export_to_path("nope",
			"user://set_package_missing_export.azset").get("error", "")) == "no_set",
			"экспорт несуществующего набора отклонён")
	var big := CustomSetsStore.create_set("Большой экспорт")
	var big_id := str(big.get("id", ""))
	var big_image := CustomSetsStore.set_dir(big_id) \
			+ CustomSetsStore.image_file_name("А", "png")
	var big_bytes := PackedByteArray()
	big_bytes.resize(SetPackageFormat.MAX_IMAGE_BYTES + 1)
	_write_bytes(big_image, big_bytes)
	CustomSetsStore.set_entries(big_id, {
		"А": {"word": "Арбуз", "image": big_image},
	})
	var big_export := SetPackageExporter.export_to_path(big_id,
			"user://set_package_big_export.azset")
	_check(str(big_export.get("error", "")) == "too_large",
			"слишком большая картинка не экспортируется")
	_remove("user://set_package_big_export.azset")
	var not_web := SetPackageExporter.download_bytes(PNG_BYTES, "a.azset")
	_check(str(not_web.get("error", "")) == "not_web", "download_bytes вне web отклонён")
	_remove(TEST_EXPORT)
	_remove("user://set_package_empty_export.azset")
	_remove("user://set_package_missing_export.azset")


func _check_pickers() -> void:
	_check(WebFilePicker.kind_for_mime("application/zip") == "package",
			"application/zip -> package")
	_check(WebFilePicker.kind_for_mime("application/x-zip-compressed") == "package",
			"application/x-zip-compressed -> package")
	_check(WebFilePicker.kind_for_mime("application/octet-stream") == "package",
			"application/octet-stream -> package")
	_check(WebFilePicker.max_bytes_for_kind("package") == 25 * 1024 * 1024,
			"лимит пакета 25 МБ")
	_check(not bool(WebFilePicker.decode_data_url("data:;base64,AAAA").get("ok", true)),
			"пустой mime без разрешения отклонён")
	var empty_mime := WebFilePicker.decode_data_url("data:;base64,AAAA", true)
	_check(bool(empty_mime.get("ok", false)), "пустой mime разрешён для пакета")
	_check(str(empty_mime.get("mime", "")) == "", "пустой mime остаётся пустым")

	var filters := NativeFilePicker.filters_for("package")
	_check(filters.has("*.azset") and filters.has("*.zip"),
			"NativeFilePicker знает .azset и .zip")
	_check(NativeFilePicker.mime_for_extension("azset") == "application/zip",
			"azset -> application/zip")
	_check(NativeFilePicker.mime_for_extension("zip") == "application/zip",
			"zip -> application/zip")
	_check(NativeFilePicker.read_file_with_limit("user://x.azset", "package", 10)
			.get("error", "") == "read_failed", "несуществующий azset даёт read_failed")

	if not OS.has_feature("web"):
		var result := await WebFilePicker.pick("package")
		_check(str(result.get("error", "")) == "not_web",
				"WebFilePicker.pick(package) вне web даёт not_web")


func _check_ui_nodes() -> void:
	var list_scene := load("res://ui/constructor/set_list/set_list.tscn") as PackedScene
	_check(list_scene != null, "сцена SetList загрузилась")
	if list_scene != null:
		var list := list_scene.instantiate()
		_check(list.find_child("ImportButton", true, false) != null,
				"в SetList есть ImportButton")
		_check(list.find_child("MessageDialog", true, false) != null,
				"в SetList есть MessageDialog")
		list.free()
	var editor_scene := load("res://ui/constructor/set_editor/set_editor.tscn") as PackedScene
	_check(editor_scene != null, "сцена SetEditor загрузилась")
	if editor_scene != null:
		var editor := editor_scene.instantiate()
		_check(editor.find_child("ExportButton", true, false) != null,
				"в SetEditor есть ExportButton")
		_check(editor.find_child("MessageDialog", true, false) != null,
				"в SetEditor есть MessageDialog")
		editor.free()


func _write_raw_zip(path: String, files: Dictionary) -> void:
	_remove(path)
	var packer := ZIPPacker.new()
	packer.open(path)
	for file_name: String in files.keys():
		packer.start_file(file_name)
		packer.write_file(files[file_name] as PackedByteArray)
		packer.close_file()
	packer.close()


func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_buffer(bytes)
		file.close()


func _read_bytes(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var bytes := file.get_buffer(file.get_length())
	file.close()
	return bytes


func _remove(path: String) -> void:
	if path.is_empty() or not FileAccess.file_exists(path):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _cleanup() -> void:
	CustomSetsStore.save_path = _saved_store_path
	SetsDirIsolation.end(_saved_sets_dir, TEST_SETS_DIR)
	_remove(TEST_STORE_PATH)
	_remove(TEST_PACKAGE)
	_remove(TEST_EXPORT)
	_remove(TEMP_PACKAGE)


func _check(ok: bool, msg: String) -> void:
	checks += 1
	if ok:
		print("[set_package_validate] OK: " + msg)
	else:
		_fail(msg)


func _fail(msg: String) -> void:
	failures += 1
	printerr("FAIL: " + msg)


func _finish() -> void:
	if checks == 0:
		printerr("FAILED: ни одна проверка не выполнена")
		get_tree().quit(1)
		return
	if failures > 0:
		printerr("FAILED: %d проверок" % failures)
		get_tree().quit(1)
	else:
		print("[set_package_validate] PASSED: все %d проверок успешны" % checks)
		get_tree().quit(0)
