extends Node
## Валидатор ImageSaver: декодирование, ресайз, сохранение WebP в user://,
## отказ на мусоре и на битых файлах. Запуск:
## godot --headless --path . res://tests/validate_image_saver.tscn
##
## Отличия от кода из плана (документированы, ничего не ослаблено):
## 1. Добавлен _class_loaded() и счётчик checks — страховка от ложного
##    «всё прошло» (урок Task 5: валидатор печатал PASSED при нуле assert'ов).
## 2. Проверки кодов ошибок сверяют ПРЕФИКС ответа, а не всю строку. План
##    требовал `error == "bad_target"`, но его же реализация отдаёт
##    `"bad_target: <текст для родителя>"` — а следующая же проверка в том же
##    плане требовала `error.contains("user://")`. Обе сразу быть не могут.
##    Авторитетна реализация: по её же контракту («Текст ошибки показывается
##    родителю») ответ обязан нести человеческий текст.
## 3. Добавлены инварианты уровня множества, а не только поштучные проверки:
##    весь набор принимаемых форматов (PNG/JPEG/WebP), весь набор правил
##    ресайза (все ориентации + сама граница), замкнутое множество кодов
##    ошибок и согласованность с WebFilePicker/CustomSetsStore. Причина та же,
##    что и в Task 1: поштучные проверки были зелёные при коллизии имён Е/Э.

const TEST_PATH := "user://image_saver_test.webp"

var failures := 0
## Счётчик выполненных проверок: страховка от ложного «всё прошло» (урок Task 5 —
## валидатор печатал PASSED при нуле выполненных assert'ов).
var checks := 0


func _ready() -> void:
	await get_tree().process_frame

	_remove_test_file()

	# Страховка от ложного «всё прошло». Если скрипт ImageSaver не скомпилился,
	# Godot всё равно создаст объект класса, но без методов: каждая проверка
	# тогда падает с runtime-ошибкой на первой строке, счётчик остаётся нулевым
	# и валидатор завершился бы с exit 0. Поэтому сначала убеждаемся, что
	# статические методы и константы реально есть.
	if not _class_loaded():
		_fail("ImageSaver не загрузился: статические методы недоступны")
		_finish()
		return

	_check_happy_path()
	_check_written_file_is_really_webp()
	_check_transparent_image_keeps_alpha()
	_check_resize()
	_check_resize_rule_set()
	_check_accepted_formats()
	_check_store_path_is_accepted()
	_check_rejects_garbage()
	_check_rejects_empty()
	_check_non_square_is_allowed()
	_check_bad_target_path()
	_check_error_vocabulary()
	_check_does_not_touch_existing_on_failure()

	_remove_test_file()
	_finish()


## Публичные статические члены ImageSaver, на которые опирается конструктор.
func _class_loaded() -> bool:
	var required := ["save_image", "decode_and_resize"]
	# ImageSaver — статический класс (class_name), а не автозагрузка, поэтому
	# идентификатор приводится к Script (в другую сторону Godot ругается
	# STATIC_CALLED_ON_INSTANCE).
	var script := ImageSaver as Script
	if script == null:
		_fail("ImageSaver не является Script")
		return false
	var present := {}
	for method: Dictionary in script.get_script_method_list():
		present[method.get("name", "")] = true
	for name: String in required:
		if not present.has(name):
			_fail("у ImageSaver нет метода %s" % name)
			return false
	var constants := script.get_script_constant_map() as Dictionary
	for constant: String in ["MAX_SIDE", "WEBP_QUALITY"]:
		if not constants.has(constant):
			_fail("у ImageSaver нет константы %s" % constant)
			return false
	return true


## Прямое доказательство, что в headless-сборке WebP действительно пишется, а
## не «создаётся пустой файл»: сигнатура RIFF/WEBP, согласованность размера в
## заголовке, ненулевой размер, обратная загрузка и совпадение размеров.
## Проверка «файл появился» сама по себе ничего не доказывает — FileAccess
## создаст файл и при пустом содержимом.
func _check_written_file_is_really_webp() -> void:
	var image := Image.create(120, 80, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.8, 0.2, 0.6, 1.0))
	_remove_test_file()
	var result := ImageSaver.save_image(image.save_png_to_buffer(), TEST_PATH)
	_check(bool(result.get("ok", false)), "не-квадратная 120x80 сохранена")
	var bytes := FileAccess.get_file_as_bytes(TEST_PATH)
	_check(not bytes.is_empty(), "файл не пуст (%d байт)" % bytes.size())
	if bytes.size() >= 12:
		var riff := bytes.slice(0, 4).get_string_from_ascii()
		var webp := bytes.slice(8, 12).get_string_from_ascii()
		_check(riff == "RIFF", "сигнатура RIFF (получено: %s)" % riff)
		_check(webp == "WEBP", "сигнатура WEBP (получено: %s)" % webp)
		_check(bytes.decode_u32(4) + 8 == bytes.size(),
				"размер в RIFF-заголовке сходится с файлом (файл %d, заголовок %d)"
				% [bytes.size(), bytes.decode_u32(4) + 8])
	var back := Image.new()
	var err := back.load(TEST_PATH)
	_check(err == OK, "файл читается обратно штатным Image.load() (err=%d)" % err)
	if err == OK:
		_check(back.get_width() == 120 and back.get_height() == 80,
				"размеры после кругосхорота 120x80 (получено: %dx%d)"
				% [back.get_width(), back.get_height()])
		var probe := back.get_pixel(60, 40)
		_check(probe.r > 0.6 and probe.b > 0.4 and probe.g < 0.4,
				"цвет выжил после WebP-сжатия (r=%.2f g=%.2f b=%.2f)"
				% [probe.r, probe.g, probe.b])


## Инвариант всего множества принимаемых форматов, а не только PNG. План
## проверял один формат поштучно — ровно тем приёмом, которым в LetterTranslit
## проскочила коллизия имён Е/Э: поштучно «есть», а множество неверно.
## Контракт картинки — PNG/JPEG/WebP, те же три MIME, что принимает
## WebFilePicker.IMAGE_MIME_TYPES, и decode_and_resize() держит на них ОДИН
## разбор: опечатка в любой из трёх веток сделала бы формат молча
## недостижимым. Собираем настоящие байты каждого формата и сверяем множество
## целиком, а не по одной строке.
func _check_accepted_formats() -> void:
	var accepted := PackedStringArray(WebFilePicker.IMAGE_MIME_TYPES)
	_check(accepted.size() == 3,
			"пикер принимает 3 формата картинки (получено: %d)" % accepted.size())

	var reachable := 0
	for mime: String in accepted:
		var format := _format_for_mime(mime)
		_check(not format.is_empty(), "%s: MIME отображается в формат" % mime)
		if format.is_empty():
			continue
		var bytes := _fixture(48, format, Color(0.2, 0.7, 0.4, 1.0))
		_check(not bytes.is_empty(), "%s (%s): кодировщик выдал непустой буфер" % [mime, format])
		if bytes.is_empty():
			continue
		var decoded := ImageSaver.decode_and_resize(bytes)
		_check(bool(decoded.get("ok", false)), "%s (%s) декодируется" % [mime, format])
		_check(int(decoded.get("width", 0)) == 48 and int(decoded.get("height", 0)) == 48,
				"%s (%s) декодирован в 48x48 (получено: %dx%d)" % [mime, format,
				int(decoded.get("width", 0)), int(decoded.get("height", 0))])
		# Формат на выходе может стать RGBA8/RGB8 — важно лишь, что это Image.
		_check(decoded.get("image", null) is Image,
				"%s (%s) отдал объект Image для предпросмотра" % [mime, format])
		if bool(decoded.get("ok", false)):
			reachable += 1
	_check(reachable == accepted.size(),
			"ни один принятый пикером формат не недостижим (%d из %d)"
			% [reachable, accepted.size()])


## Кросс-компонентный инвариант: путь, который CustomSetsStore запрашивает у
## ImageSaver, обязан быть тем, который ImageSaver принимает. Иначе
## конструктор писал бы не туда и получал bad_target/write_failed на каждой
## букве — и заметил бы это только на устройстве родителя.
##
## Проверяется НАСТОЯЩИЙ путь набора, а не «user:// + имя файла». Имя файла,
## которое даёт хранилище, — голое ("img_a.webp"); путь на диске это
## set_dir(set_id) + image_file_name(letter), то есть
## user://custom_sets/<set_id>/img_a.webp. Префикс user:// в set_dir() уже
## стоит, а подстановка его ещё раз дала бы путь в корне user://, которого
## нет ни в одном реальном вызове. Папку набора создаёт create_set(), а не
## ImageSaver, поэтому валидатор создаёт её сам — иначе save_image() честно
## вернул бы write_failed (см. _check_bad_target_path).
func _check_store_path_is_accepted() -> void:
	var set_id := CustomSetsStore.make_set_id()
	var set_dir := CustomSetsStore.set_dir(set_id)
	var name := CustomSetsStore.image_file_name("А")
	var path := set_dir + name
	_check(name == "img_a.webp",
			"хранилище просит img_a.webp (получено: %s)" % name)
	# Обе половины пути проверяются по отдельности: префикс — что это каталог
	# наборов, суффикс — что это имя файла буквы. Проверка только одной из них
	# пропустила бы и запись в корень user://, и потерю подкаталога набора.
	_check(path.begins_with("user://custom_sets/"),
			"путь набора лежит в user://custom_sets/ (получено: %s)" % path)
	_check(path.ends_with("img_a.webp"),
			"путь набора оканчивается именем файла буквы (получено: %s)" % path)
	_check(path.get_extension() == "webp",
			"путь хранилища оканчивается .webp (получено: %s)" % path)

	# Два разных набора обязаны давать два разных пути для ОДНОЙ буквы. Иначе
	# картинка «А» второго набора затёрла бы картинку «А» первого. Это тот же
	# урок Task 1 (Е/Э схлопывались в одно имя), перенесённый на измерение
	# набора: filename одинаков по построению, различает только подкаталог.
	var other := CustomSetsStore.set_dir("c_bbbbbb") + CustomSetsStore.image_file_name("А")
	_check(path != other,
			"два набора дают разные пути для одной буквы (%s против %s)" % [path, other])

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(set_dir))
	var saved := ImageSaver.save_image(
			_fixture(32, "png", Color(0.1, 0.1, 0.8, 1.0)), path)
	_check(bool(saved.get("ok", false)),
			"ImageSaver принимает и пишет ровно тот путь, который даёт хранилище: %s" % path)
	_check(FileAccess.file_exists(path), "файл по пути хранилища появился: %s" % path)

	# Убираем и файл, и подкаталог набора: оставшийся пустой
	# user://custom_sets/<id>/ в пользовательских данных — тоже баг.
	_remove_path(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(set_dir))


## Инвариант всего правила ресайза, а не одной удачной пары чисел. Правило
## ровно одно — длинная сторона ≤ MAX_SIDE, пропорции целы, увеличения нет —
## и оно обязано вести себя одинаково на всех ориентациях и на самой границе.
## Поштучная проверка «2000x1000 ужался до 1024x512» покрывает одну точку:
## сломайся правило на портретной картинке или на границе — родитель увидит
## это только на своей.
func _check_resize_rule_set() -> void:
	_check(ImageSaver.MAX_SIDE == 1024,
			"MAX_SIDE = 1024 (получено: %d)" % ImageSaver.MAX_SIDE)
	_check(ImageSaver.WEBP_QUALITY > 0.0 and ImageSaver.WEBP_QUALITY <= 1.0,
			"WEBP_QUALITY в (0, 1] (получено: %.2f)" % ImageSaver.WEBP_QUALITY)

	var cases: Array[Vector2i] = [
		Vector2i(2000, 1000),  # альбомная сильно больше лимита
		Vector2i(1000, 2000),  # портретная сильно больше лимита
		Vector2i(2000, 2000),  # квадрат больше лимита
		Vector2i(1025, 1024),  # на байт за границей
		Vector2i(1024, 1024),  # ровно граница — не трогаем
		Vector2i(1023, 1023),  # на байт внутрь — не трогаем
		Vector2i(50, 40),      # заметно меньше лимита
		Vector2i(1, 1),        # крошечная — не увеличивать
	]
	for size: Vector2i in cases:
		var decoded := ImageSaver.decode_and_resize(_fixture_png(size.x, size.y))
		var width := int(decoded.get("width", 0))
		var height := int(decoded.get("height", 0))
		_check(bool(decoded.get("ok", false)), "%dx%d декодирована" % [size.x, size.y])
		_check(maxi(width, height) <= ImageSaver.MAX_SIDE,
				"%dx%d: длинная сторона ≤ MAX_SIDE (получено: %dx%d)"
				% [size.x, size.y, width, height])
		_check(mini(width, height) >= 1,
				"%dx%d: ни одна сторона не схлопнулась в ноль (получено: %dx%d)"
				% [size.x, size.y, width, height])
		if maxi(size.x, size.y) <= ImageSaver.MAX_SIDE:
			_check(Vector2i(width, height) == size,
					"%dx%d: картинка в пределах лимита не тронута (получено: %dx%d)"
					% [size.x, size.y, width, height])
		else:
			var expected_ratio := float(size.x) / float(size.y)
			var actual_ratio := float(width) / float(height)
			_check(absf(expected_ratio - actual_ratio) <= 0.01,
					"%dx%d: пропорции сохранены (%.4f против %.4f)"
					% [size.x, size.y, expected_ratio, actual_ratio])


func _check_happy_path() -> void:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.9, 0.3, 0.1, 1.0))
	var bytes := image.save_png_to_buffer()
	_check(not bytes.is_empty(), "тестовая картинка сохранилась в PNG-буфер")

	var result := ImageSaver.save_image(bytes, TEST_PATH)
	_check(bool(result.get("ok", false)), "save_image принял валидный PNG")
	_check(int(result.get("width", 0)) == 64, "ширина прочитана (получено: %d)" % int(result.get("width", 0)))
	_check(int(result.get("height", 0)) == 64, "высота прочитана")
	_check(FileAccess.file_exists(TEST_PATH), "файл появился в user://")

	# Файл действительно WebP и читается обратно без потерь формата.
	var written := Image.new()
	var err := written.load(TEST_PATH)
	_check(err == OK, "сохранённый файл читается обратно (err=%d)" % err)
	_check(written.get_width() == 64, "прочитанная ширина 64")
	_check(written.get_width() == written.get_height(), "квадрат остался квадратом")

	# Пиксель совпадает с исходным в пределах потерь WebP.
	if err == OK:
		var probe := written.get_pixel(32, 32)
		_check(probe.r > 0.7 and probe.g < 0.5 and probe.b < 0.3,
				"цвет выжил после сжатия (r=%.2f g=%.2f b=%.2f)" % [probe.r, probe.g, probe.b])


func _check_transparent_image_keeps_alpha() -> void:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var path := "user://image_saver_alpha_test.webp"
	# План писал здесь `_remove_test_file(path)`, но определял `_remove_test_file()`
	# без аргументов — жёсткая ошибка разбора, не зависящая от ImageSaver. Правильную
	# функцию для произвольного пути добавляем ниже как _remove_path().
	_remove_path(path)
	var result := ImageSaver.save_image(image.save_png_to_buffer(), path)
	_check(bool(result.get("ok", false)), "прозрачная картинка сохранена")

	var written := Image.new()
	if written.load(path) == OK:
		var alpha: float = written.get_pixel(16, 16).a
		_check(alpha < 0.1, "прозрачность сохранена (alpha=%.2f)" % alpha)
	else:
		_fail("прозрачную картинку не удалось прочитать обратно")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Большая картинка ужимается до MAX_SIDE по длинной стороне, пропорции целы.
func _check_resize() -> void:
	var image := Image.create(2000, 1000, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.1, 0.8, 0.4, 1.0))
	var decoded := ImageSaver.decode_and_resize(image.save_png_to_buffer())
	_check(bool(decoded.get("ok", false)), "большая картинка декодирована")
	_check(int(decoded.get("width", 0)) == 1024, "длинная сторона ужата до 1024 (получено: %d)"
			% int(decoded.get("width", 0)))
	_check(int(decoded.get("height", 0)) == 512, "пропорции сохранены (получено: %d)"
			% int(decoded.get("height", 0)))
	_check(decoded.get("image", null) is Image, "декодированное изображение доступно")

	# Маленькая картинка не увеличивается.
	var small := Image.create(50, 40, false, Image.FORMAT_RGBA8)
	var small_result := ImageSaver.decode_and_resize(small.save_png_to_buffer())
	_check(int(small_result.get("width", 0)) == 50, "маленькая картинка не увеличена")
	_check(int(small_result.get("height", 0)) == 40, "маленькая высота не увеличена")


func _check_rejects_garbage() -> void:
	var result := ImageSaver.save_image(PackedByteArray([1, 2, 3, 4, 5]), TEST_PATH)
	_check(not bool(result.get("ok", true)), "мусорные байты отклонены")
	_check(_error_code(result) == "decode_failed", "код ошибки decode_failed (получено: %s)"
			% str(result.get("error", "")))

	# Текст вместо картинки.
	var text := PackedByteArray()
	text.resize(64)
	for i in 64:
		text[i] = 65
	_check(not bool(ImageSaver.save_image(text, TEST_PATH).get("ok", true)), "текст отклонён")

	# Обрезанный PNG: заголовок есть, данных нет.
	var truncated := PackedByteArray()
	truncated.resize(10)
	_check(not bool(ImageSaver.save_image(truncated, TEST_PATH).get("ok", true)),
			"обрезанный файл отклонён")


func _check_rejects_empty() -> void:
	var result := ImageSaver.save_image(PackedByteArray(), TEST_PATH)
	_check(not bool(result.get("ok", true)), "пустой массив байтов отклонён")
	_check(_error_code(result) == "decode_failed", "пустой массив -> decode_failed (получено: %s)"
			% str(result.get("error", "")))


## Не-square допускается: ограничение 1024x1024 в требованиях — пожелание,
## а не повод отказывать родителю. Игра вписывает картинку в квадрат сам.
func _check_non_square_is_allowed() -> void:
	var image := Image.create(300, 100, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.5, 0.5, 0.5, 1.0))
	_remove_test_file()
	var result := ImageSaver.save_image(image.save_png_to_buffer(), TEST_PATH)
	_check(bool(result.get("ok", false)), "не-квадратная картинка принята")
	_check(int(result.get("width", 0)) == 300 and int(result.get("height", 0)) == 100,
			"размеры не-квадратной картинки сохранены")


func _check_bad_target_path() -> void:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var bytes := image.save_png_to_buffer()
	var result := ImageSaver.save_image(bytes, "res://assets/images/constructor_test.webp")
	_check(not bool(result.get("ok", true)), "запись в res:// отклонена")
	_check(_error_code(result) == "bad_target", "код ошибки bad_target (получено: %s)"
			% str(result.get("error", "")))
	_check(str(result.get("error", "")).contains("user://"),
			"текст ошибки объясняет, что писать можно только в user://")

	var wrong_ext := ImageSaver.save_image(bytes, "user://image_saver_test.png")
	_check(not bool(wrong_ext.get("ok", true)), "расширение не .webp отклонено")
	_check(_error_code(wrong_ext) == "bad_target", "png -> bad_target (получено: %s)"
			% str(wrong_ext.get("error", "")))
	_check(not FileAccess.file_exists("user://image_saver_test.png"),
			"png-файл не создан на диске")

	# Недоступная папка внутри user://.
	var missing_dir := ImageSaver.save_image(bytes, "user://no_such_dir/x.webp")
	_check(not bool(missing_dir.get("ok", true)), "несуществующая папка отклонена")
	_check(_error_code(missing_dir) == "write_failed", "код ошибки write_failed (получено: %s)"
			% str(missing_dir.get("error", "")))


## Инварианты множества кодов ошибок. Код — это начало строки, а не вся строка:
## по контраклу реализации («Текст ошибки показывается родителю») ответ несёт
## ещё и человеческий текст, поэтому требовать точного равенства коду нельзя.
## Зато можно и нужно проверить, что множество кодов замкнуто, у каждого отказа
## есть сообщение, размеры отказа нулевые и код отказа декодирования виден в
## ответе save_image() без искажения: конструктор различает «родитель принёс не
## картинку» и «диск недоступен» именно по коду.
func _check_error_vocabulary() -> void:
	var good := _fixture(32, "png", Color(0.4, 0.4, 0.4, 1.0))
	var expected := ["bad_target", "decode_failed", "write_failed"]
	var cases := {
		"decode_failed": [
			[PackedByteArray(), TEST_PATH, "пустой буфер"],
			[PackedByteArray([1, 2, 3, 4, 5]), TEST_PATH, "мусорные байты"],
		],
		"bad_target": [
			[good, "res://assets/images/constructor_test.webp", "запись в res://"],
			[good, "user://image_saver_test.png", "расширение .png"],
		],
		"write_failed": [
			[good, "user://no_such_dir/x.webp", "нет папки"],
		],
	}
	var produced := {}
	for code: String in cases:
		for entry: Array in cases[code]:
			var path := str(entry[1])
			var label := str(entry[2])
			var result := ImageSaver.save_image(entry[0] as PackedByteArray, path)
			_check(not bool(result.get("ok", true)),
					"%s (%s, %s) отклонён" % [code, label, path])
			var error := str(result.get("error", ""))
			produced[_error_code(result)] = true
			_check(_error_code(result) == code,
					"%s (%s, %s): код отказа = %s" % [code, label, path, _error_code(result)])
			var parts := error.split(": ", true, 1)
			_check(parts.size() == 2 and not parts[1].is_empty(),
					"%s (%s): у отказа есть текст для родителя" % [code, label])
			_check(int(result.get("width", 0)) == 0 and int(result.get("height", 0)) == 0,
					"%s (%s): размеры отказа нулевые" % [code, label])

	# Множество кодов, которые saver реально возвращает, совпадает с
	# объявленным: новый код не появится молча.
	var actual := produced.keys()
	actual.sort()
	_check(actual == expected,
			"множество кодов отказа = %s, ожидалось %s" % [actual, expected])

	# Отказ декодирования виден в ответе save_image() тем же кодом, что и в
	# ответе декодиратора: иначе конструктор не отличит битый файл от отказа
	# записи.
	var decoded := ImageSaver.decode_and_resize(PackedByteArray([1, 2, 3]))
	var saved := ImageSaver.save_image(PackedByteArray([1, 2, 3]), TEST_PATH)
	_check(str(decoded.get("error", "")) == "decode_failed",
			"декодер отдаёт голый код decode_failed (получено: %s)"
			% str(decoded.get("error", "")))
	_check(_error_code(saved) == str(decoded.get("error", "")),
			"save_image наследует код декодера без искажения (%s против %s)"
			% [_error_code(saved), str(decoded.get("error", ""))])
	_check(decoded.get("image", null) == null,
			"у отказа декодирования нет картинки для предпросмотра")


## Ошибка декодирования не должна затирать уже сохранённый файл.
func _check_does_not_touch_existing_on_failure() -> void:
	var good := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	good.fill(Color(0.2, 0.6, 0.9, 1.0))
	_check(bool(ImageSaver.save_image(good.save_png_to_buffer(), TEST_PATH).get("ok", false)),
			"эталонный файл сохранён")
	var before := FileAccess.get_file_as_bytes(TEST_PATH)

	ImageSaver.save_image(PackedByteArray([9, 9, 9]), TEST_PATH)
	var after := FileAccess.get_file_as_bytes(TEST_PATH)
	_check(after == before, "неудачное сохранение не затёрло предыдущий файл")

	# Отказ записи по незаписываемому пути тоже не должен трогать эталон.
	ImageSaver.save_image(good.save_png_to_buffer(), "user://no_such_dir/x.webp")
	_check(FileAccess.get_file_as_bytes(TEST_PATH) == before,
			"неудачная запись по чужому пути не затёрла эталон")


## Код ошибки из ответа ImageSaver: ответ несёт «код: текст для родителя»,
## поэтому код — это префикс до первого двоеточия, а не вся строка.
func _error_code(result: Dictionary) -> String:
	return str(result.get("error", "")).split(":")[0]


## MIME пикера -> имя формата, которым этот MIME кодируется. Ровно одна ветка на
## каждый MIME из WebFilePicker.IMAGE_MIME_TYPES: неизвестный MIME обязан дать
## пустую строку, иначе проверка выше считала бы несуществующий формат и
## рапортовала бы «всё хорошо».
func _format_for_mime(mime: String) -> String:
	match mime.to_lower():
		"image/png":
			return "png"
		"image/jpeg":
			return "jpeg"
		"image/webp":
			return "webp"
	return ""


## Настоящие байты картинки в заданном формате. Нужен штатный кодировщик, а не
## рукописный заголовок: иначе проверка принятых форматов проверяла бы сама
## себя. Для webp берём lossless (lossy=false), чтобы фикстура не зависела от
## настроек сжатия и оставалась точной.
func _fixture(size: int, format: String, color: Color) -> PackedByteArray:
	var image := Image.create(maxi(size, 1), maxi(size, 1), false, Image.FORMAT_RGBA8)
	image.fill(color)
	match format:
		"png":
			return image.save_png_to_buffer()
		"jpeg":
			return image.save_jpg_to_buffer(0.9)
		"webp":
			return image.save_webp_to_buffer(false, 0.9)
	return PackedByteArray()


## Квадратная PNG-фикстура произвольного размера — для набора правил ресайза.
func _fixture_png(width: int, height: int) -> PackedByteArray:
	var image := Image.create(maxi(width, 1), maxi(height, 1), false, Image.FORMAT_RGBA8)
	image.fill(Color(0.1, 0.8, 0.4, 1.0))
	return image.save_png_to_buffer()


func _remove_test_file() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


## Удалить произвольный тестовый файл из user://.
func _remove_path(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _check(ok: bool, msg: String) -> void:
	checks += 1
	if ok:
		_print("OK: " + msg)
	else:
		_fail(msg)


func _fail(msg: String) -> void:
	failures += 1
	printerr("FAIL: " + msg)


func _print(msg: String) -> void:
	print("[image_saver_validate] " + msg)


func _finish() -> void:
	# Ноль выполненных проверок при нуле ошибок — это не успех, а сломанный
	# валидатор: печатать PASSED в таком случае нельзя.
	if checks == 0:
		printerr("FAILED: не выполнено ни одной проверки — валидатор не отработал")
		get_tree().quit(1)
		return
	if failures > 0:
		printerr("FAILED: %d проверок из %d" % [failures, checks])
		get_tree().quit(1)
	else:
		print("[image_saver_validate] PASSED: %d проверок успешны" % checks)
		get_tree().quit(0)
