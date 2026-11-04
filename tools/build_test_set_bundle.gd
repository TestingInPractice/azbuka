extends SceneTree
## Собирает tools/test_set_bundle.res из tools/test_set_assets.
##
## Запуск:
##   godot --headless --path . --script tools/build_test_set_bundle.gd
## Пересобирать после изменения картинок, озвучки или слов.

const Data := preload("res://tools/test_set_data.gd")
const BundleScript := preload("res://tools/test_set_bundle.gd")
## Дублируем константы ImageSaver: его скрипт ссылается на автолоад
## GameLogger, а --script автолоады не поднимает, и preload падал.
const MAX_SIDE := 1024
const WEBP_QUALITY := 0.9
const TARGET := "res://tools/test_set_bundle.res"


func _init() -> void:
	var bundle: Resource = BundleScript.new()
	bundle.words = Data.WORDS.duplicate(true)
	var missing: Array[String] = []
	for letter: String in Data.WORDS.keys():
		var png_bytes := FileAccess.get_file_as_bytes(Data.image_path(letter))
		var audio_bytes := FileAccess.get_file_as_bytes(Data.audio_path(letter))
		if png_bytes.is_empty():
			missing.append(letter + ".png")
			continue
		if audio_bytes.is_empty():
			missing.append(letter + ".wav")
			continue
		# Кодируем WebP СЕЙЧАС, на нативной сборке. Если оставить PNG и звать
		# ImageSaver в браузере, первый запуск кодирует 33 картинки 1024x1024
		# на WASM и блокирует главный поток на минуты.
		var image := Image.new()
		if image.load_png_from_buffer(png_bytes) != OK:
			missing.append(letter + ".png (decode)")
			continue
		var long_side := maxi(image.get_width(), image.get_height())
		if long_side > MAX_SIDE:
			var scale := float(MAX_SIDE) / float(long_side)
			image.resize(maxi(1, int(round(image.get_width() * scale))),
					maxi(1, int(round(image.get_height() * scale))),
					Image.INTERPOLATE_LANCZOS)
		var webp_bytes := image.save_webp_to_buffer(true, WEBP_QUALITY)
		if webp_bytes.is_empty():
			missing.append(letter + ".webp (encode)")
			continue
		bundle.images[letter] = webp_bytes
		bundle.audios[letter] = audio_bytes
		bundle.audio_extensions[letter] = Data.audio_path(letter).get_extension()
	if not missing.is_empty():
		printerr("[build_test_set_bundle] нет файлов: " + ", ".join(missing))
		quit(1)
		return
	var err := ResourceSaver.save(bundle, TARGET)
	if err != OK:
		printerr("[build_test_set_bundle] не сохранилось (err=%d)" % err)
		quit(1)
		return
	print("[build_test_set_bundle] %s: %d букв, %.1f МБ" % [
		TARGET, bundle.images.size(),
		float(FileAccess.get_file_as_bytes(TARGET).size()) / 1048576.0,
	])
	quit(0)
