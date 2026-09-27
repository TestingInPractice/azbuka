class_name ImageSaver
extends RefCounted
## Сохранение картинки буквы в user:// в формате WebP.
##
## Родитель отдаёт PNG/JPEG/WebP из WebFilePicker, здесь байты превращаются в
## Image, ужимаются до MAX_SIDE по длинной стороне и пишутся в user://.
##
## Три решения, зафиксированные здесь:
##   1. Пишем ТОЛЬКО в user://. Ресурсы игры лежат в res:// и в веб-сборке
##      запечатаны в PCK — запись туда невозможна, а попытка всё равно
##      испортила бы экспортированную сборку.
##   2. Требуем .webp на выходе: один формат вместо трёх, Godot 4.6 умеет
##      и читать, и писать WebP, альфа-канал сохраняется.
##   3. Не-квадратные картинки НЕ отклоняем. 1024x1024 в требованиях — это
##      пожелание родителя, а игра вписывает картинку в квадрат сама. Отказ
##      родителю из-за пропорций — плохой UX.
##
## Статический класс: состояния нет, только чистые функции.

## Максимальная длинная сторона сохраняемой картинки.
const MAX_SIDE := 1024
## Качество WebP: 0.9 — глазом незаметно, файл заметно меньше 1.0.
const WEBP_QUALITY := 0.9


## Декодирует байты и ужимает до MAX_SIDE по длинной стороне.
## Возвращает {ok, image, width, height, error}. Малые картинки не увеличиваются.
static func decode_and_resize(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty():
		return _decode_error("decode_failed")
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK \
			and image.load_jpg_from_buffer(bytes) != OK \
			and image.load_webp_from_buffer(bytes) != OK:
		return _decode_error("decode_failed")
	var long_side: int = maxi(image.get_width(), image.get_height())
	if long_side > MAX_SIDE:
		var scale := float(MAX_SIDE) / float(long_side)
		var new_size := Vector2i(
			maxi(1, int(round(image.get_width() * scale))),
			maxi(1, int(round(image.get_height() * scale))))
		# Ланцоша — единственный фильтр, дающий гладкие края на уменьшении.
		image.resize(new_size.x, new_size.y, Image.INTERPOLATE_LANCZOS)
	return {
		"ok": true,
		"image": image,
		"width": image.get_width(),
		"height": image.get_height(),
		"error": "",
	}


## Сохраняет картинку в target_path (user://..., расширение .webp).
## Возвращает {ok, width, height, error}.
static func save_image(bytes: PackedByteArray, target_path: String) -> Dictionary:
	if not target_path.begins_with("user://"):
		return _save_error("bad_target", "Сохранять можно только в user://: " + target_path)
	if target_path.get_extension().to_lower() != "webp":
		return _save_error("bad_target", "Ожидается расширение .webp: " + target_path)
	var decoded := decode_and_resize(bytes)
	if not bool(decoded.get("ok", false)):
		return _save_error(str(decoded.get("error", "decode_failed")), "Не удалось прочитать картинку")
	var image: Image = decoded["image"] as Image
	# Сигнатура Godot 4.6 — save_webp(path, lossy, quality), а не (path, quality).
	# Двухаргументный вызов из плана молча подставлял lossy = 0.9 (то есть true)
	# и оставлял quality на умолчании 0.75, то есть константа WEBP_QUALITY := 0.9
	# была бы ложью. Проверено пробой в headless: 92 байта при quality 0.75 против
	# 100 байт при quality 0.9. Сжатие с потерями — оно и задумано (см. WEBP_QUALITY),
	# альфа-канал libwebp при этом сохраняет.
	var err := image.save_webp(target_path, true, WEBP_QUALITY)
	if err != OK:
		return _save_error("write_failed", "Не удалось записать %s (err=%d)" % [target_path, err])
	GameLogger.info("ImageSaver", "image_saved", {
		"path": target_path,
		"width": image.get_width(),
		"height": image.get_height(),
	})
	return {
		"ok": true,
		"width": image.get_width(),
		"height": image.get_height(),
		"error": "",
	}


## Ответ декодирования с ошибкой.
static func _decode_error(code: String) -> Dictionary:
	return {"ok": false, "image": null, "width": 0, "height": 0, "error": code}


## Ответ сохранения с ошибкой. Текст ошибки показывается родителю.
static func _save_error(code: String, message: String) -> Dictionary:
	return {"ok": false, "width": 0, "height": 0, "error": "%s: %s" % [code, message]}
