class_name NativeFilePicker
extends RefCounted
## Нативный выбор файла для десктопа (редактор/экспорт). Работает через FileDialog с use_native_dialog.
##
## Контракт совпадает с WebFilePicker.pick(): {ok, bytes, mime, name, error}.
## Статический класс без состояния.

## Фильтры по виду файла.
static func filters_for(kind: String) -> PackedStringArray:
	match kind:
		"image":
			return PackedStringArray(["*.png", "*.jpg", "*.jpeg", "*.webp"])
		"audio":
			return PackedStringArray(["*.wav", "*.ogg", "*.mp3"])
		_:
			return PackedStringArray()


## MIME по расширению файла.
static func mime_for_extension(extension: String) -> String:
	var ext := extension.strip_edges().to_lower().trim_prefix(".")
	match ext:
		"png":
			return "image/png"
		"jpg", "jpeg":
			return "image/jpeg"
		"webp":
			return "image/webp"
		"wav":
			return "audio/wav"
		"ogg":
			return "audio/ogg"
		"mp3":
			return "audio/mpeg"
		_:
			return ""


## Читает файл с проверками по виду.
static func read_file(path: String, kind: String) -> Dictionary:
	return read_file_with_limit(path, kind, WebFilePicker.max_bytes_for_kind(kind))


## Читает файл с проверками по виду и явным лимитом.
static func read_file_with_limit(path: String, kind: String, limit_bytes: int) -> Dictionary:
	if kind != "image" and kind != "audio":
		return _read_error("bad_kind")
	var filters := filters_for(kind)
	if filters.is_empty():
		return _read_error("bad_kind")
	var extension := path.get_extension()
	if extension.is_empty():
		return _read_error("unsupported_type")
	var ext_lower := extension.to_lower()
	var allowed := false
	for filter: String in filters:
		var pattern := filter.trim_prefix("*.")
		if ext_lower == pattern:
			allowed = true
			break
	if not allowed:
		return _read_error("unsupported_type")
	if limit_bytes <= 0:
		return _read_error("bad_kind")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _read_error("read_failed")
	var bytes := file.get_buffer(file.get_length())
	file.close()
	if bytes.size() > limit_bytes:
		return _read_error("too_large")
	var mime := mime_for_extension(ext_lower)
	if mime.is_empty():
		return _read_error("unsupported_type")
	return {
		"ok": true,
		"bytes": bytes,
		"mime": mime,
		"name": path.get_file(),
		"error": "",
	}


## Открывает нативный диалог выбора файла.
static func pick(kind: String) -> Dictionary:
	if kind != "image" and kind != "audio":
		return _read_error("bad_kind")
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return _read_error("no_tree")
	var dialog := FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.use_native_dialog = true
	var filters := filters_for(kind)
	if not filters.is_empty():
		dialog.filters = PackedStringArray([",".join(filters)])
	if kind == "image":
		dialog.title = "Выберите картинку"
	else:
		dialog.title = "Выберите звук"
	tree.root.add_child(dialog)
	dialog.popup_centered_ratio(0.8)
	var selected_path := ""
	var cancelled := false
	dialog.file_selected.connect(func(path: String) -> void:
		selected_path = path
	)
	dialog.canceled.connect(func() -> void:
		cancelled = true
	)
	while dialog.visible:
		await tree.process_frame
	dialog.queue_free()
	if cancelled or selected_path.is_empty():
		return _read_error("cancelled")
	return read_file(selected_path, kind)


static func _read_error(code: String) -> Dictionary:
	return {
		"ok": false,
		"bytes": PackedByteArray(),
		"mime": "",
		"name": "",
		"error": code,
	}
