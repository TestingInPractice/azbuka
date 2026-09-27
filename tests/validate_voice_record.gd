extends Node
## Валидатор VoiceRecord: чистое ядро (стерео→PCM, WAV-заголовок, нормализация)
## плюс безопасное поведение без микрофона. Захват с реального устройства в
## headless невозможен — там Dummy-драйвер, проверяется в браузере.
## Запуск: godot --headless --path . res://tests/validate_voice_record.tscn

var failures := 0
## Счётчик выполненных проверок: страховка от ложного «всё прошло» (урок Task 5 —
## валидатор печатал PASSED при нуле выполненных assert'ов).
var checks := 0


func _ready() -> void:
	await get_tree().process_frame

	# Страховка от ложного «всё прошло». Если скрипт VoiceRecord не скомпилился,
	# Godot всё равно создаёт объект класса, но без методов: каждая проверка
	# тогда падает с runtime-ошибкой на первой строке, счётчик остаётся нулевым
	# и валидатор завершился бы с exit 0. Поэтому сначала убеждаемся, что
	# методы реально есть.
	if not _class_loaded():
		_fail("VoiceRecord не загрузился: методы автолоада недоступны")
		_finish()
		return

	_check_frames_to_pcm()
	_check_wav_header()
	_check_normalize()
	await _check_no_microphone_is_safe()
	await _check_letter_card_still_loads()

	_finish()


## Публичные методы и сигналы, на которые LetterCard и конструктор опираются.
func _class_loaded() -> bool:
	var required := [
		"stereo_frames_to_pcm", "pcm_to_wav_bytes", "normalize_pcm",
		"prepare_microphone", "start_recording", "stop_recording",
		"is_recording", "has_data", "get_data", "get_wav_bytes",
		"get_level", "clear", "release_microphone",
	]
	# VoiceRecord — автозагрузка, а не class_name: идентификатор указывает на
	# инстанс ноды, и приводить его к Script нельзя (STATIC_CALLED_ON_INSTANCE
	# в другую сторону). Скрипт достаём через get_script().
	var script := VoiceRecord.get_script() as Script
	if script == null:
		return false
	var present := {}
	for method: Dictionary in script.get_script_method_list():
		present[method.get("name", "")] = true
	for method_name: String in required:
		if not present.has(method_name):
			_fail("у VoiceRecord нет метода %s" % method_name)
			return false
	return true


## Регрессия на сам рефакторинг: LetterCard больше не владеет рекордером, и
## единственная существенная сцена, которую он проверяет, — что сцена карточки
## и её %Node-пути всё ещё грузятся. Шаг 6 плана ошибочно считал, что этим
## занимается validate_ui_changes: тот инстанцирует main_menu, settings,
## feedback и donate, а letter_card.tscn не трогает вообще.
func _check_letter_card_still_loads() -> void:
	var scene: PackedScene = load("res://ui/games/azbuka/letter_card.tscn")
	_check(scene != null, "letter_card.tscn загружается")
	if scene == null:
		return
	var card := scene.instantiate()
	add_child(card)
	await get_tree().process_frame
	# %Node-пути из @onready: битый путь падает на _ready() при add_child.
	for unique: String in [
		"BackgroundOverlay", "ContentWrapper", "LetterLabel", "WordImage",
		"WordSquares", "HintLabel", "PrevLetterButton", "NextLetterButton",
		"ButtonLetter", "ButtonWord", "MicButton", "RecordPlaybackButton",
		"LetterBackButton", "HomeButton",
	]:
		_check(card.get_node_or_null("%" + unique) != null,
				"letter_card: %%-%s на месте" % unique)
	# Запись в LetterCard теперь делегирована, а не хранится в нём.
	_check(card.has_recording() == false, "новая карточка без записи")
	_check(card.is_recording() == false, "новая карточка не записывает")
	card.free()


func _check_frames_to_pcm() -> void:
	# Пустой вход — пустой выход, без ошибок.
	_check(VoiceRecord.stereo_frames_to_pcm(PackedVector2Array()).is_empty(),
			"пустые кадры -> пустой PCM")

	# Стерео усредняется в моно: (1.0 + 0.0) / 2 = 0.5 -> 16383.
	var frames := PackedVector2Array([Vector2(1.0, 0.0)])
	var pcm := VoiceRecord.stereo_frames_to_pcm(frames)
	_check(pcm.size() == 2, "один кадр -> 2 байта (получено: %d)" % pcm.size())
	var value: int = pcm[0] | (pcm[1] << 8)
	_check(value == 16383, "усреднение стерео в моно (получено: %d, ожидалось 16383)" % value)

	# Противоположные каналы усредняются в ноль.
	var cancel := VoiceRecord.stereo_frames_to_pcm(PackedVector2Array([Vector2(1.0, -1.0)]))
	_check(cancel[0] | (cancel[1] << 8) == 0, "каналы +1/-1 усредняются в 0")

	# Выход за диапазон обрезается, а не переполняется.
	var loud := VoiceRecord.stereo_frames_to_pcm(PackedVector2Array([Vector2(4.0, 4.0)]))
	_check(loud[0] | (loud[1] << 8) == 32767, "перегруз обрезан до 32767")

	# Порядок байтов little-endian: младший байт первым.
	var half := VoiceRecord.stereo_frames_to_pcm(PackedVector2Array([Vector2(0.5, 0.5)]))
	_check(half[0] == 0xFF and half[1] == 0x3F, "little-endian порядок байтов")

	# Два кадра дают четыре байта.
	var pair := VoiceRecord.stereo_frames_to_pcm(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0, 0.0)]))
	_check(pair.size() == 4, "два кадра -> 4 байта (получено: %d)" % pair.size())


func _check_wav_header() -> void:
	# Пустой PCM даёт пустой WAV: заголовок без данных бессмыслен.
	_check(VoiceRecord.pcm_to_wav_bytes(PackedByteArray(), 22050).is_empty(),
			"пустой PCM -> пустой WAV")

	var pcm := PackedByteArray()
	pcm.resize(400)
	var wav := VoiceRecord.pcm_to_wav_bytes(pcm, 22050)
	_check(wav.size() == 44 + 400, "размер WAV = 44 + данные (получено: %d)" % wav.size())
	_check(wav.slice(0, 4).get_string_from_ascii() == "RIFF", "сигнатура RIFF")
	_check(wav.slice(8, 12).get_string_from_ascii() == "WAVE", "сигнатура WAVE")
	_check(wav.slice(12, 16).get_string_from_ascii() == "fmt ", "чанк fmt")
	_check(wav.decode_u32(16) == 16, "размер чанка fmt = 16")
	_check(wav.decode_u16(20) == 1, "формат PCM (1)")
	_check(wav.decode_u16(22) == 1, "один моно-канал")
	_check(wav.decode_u32(24) == 22050, "частота дискретизации")
	_check(wav.decode_u32(28) == 22050 * 2, "байт в секунду = частота * 2")
	_check(wav.decode_u16(32) == 2, "выравнивание блока = 2")
	_check(wav.decode_u16(34) == 16, "16 бит на сэмпл")
	_check(wav.slice(36, 40).get_string_from_ascii() == "data", "чанк data")
	_check(wav.decode_u32(40) == 400, "размер данных в заголовке")
	_check(wav.decode_u32(4) == 36 + 400, "размер файла в заголовке")
	# Данные скопированы без изменений.
	_check(wav.slice(44) == pcm, "данные WAV совпадают с исходным PCM")


func _check_normalize() -> void:
	# Пустой вход — пустой выход.
	_check(VoiceRecord.normalize_pcm(PackedByteArray()).is_empty(), "нормализация пустого PCM")

	# Тихий сигнал усиливается до целевого пика 26214.
	var quiet := PackedByteArray()
	quiet.resize(200)
	for i in range(0, 200, 2):
		quiet[i] = 1000 & 0xFF
		quiet[i + 1] = (1000 >> 8) & 0xFF
	var loud := VoiceRecord.normalize_pcm(quiet)
	var peak := 0
	for i in range(0, loud.size(), 2):
		var sample: int = loud[i] | (loud[i + 1] << 8)
		if sample > 32767:
			sample -= 65536
		peak = maxi(peak, -sample if sample < 0 else sample)
	_check(peak == 26214, "тихий сигнал выровнен до пика 26214 (получено: %d)" % peak)
	_check(loud.size() == quiet.size(), "нормализация не меняет длину")

	# Уже громкий сигнал не трогаем.
	var already := PackedByteArray()
	already.resize(200)
	for i in range(0, 200, 2):
		already[i] = 30000 & 0xFF
		already[i + 1] = (30000 >> 8) & 0xFF
	_check(VoiceRecord.normalize_pcm(already) == already, "громкий сигнал не изменяется")

	# Нулевой сигнал не делит на ноль.
	var silence := PackedByteArray()
	silence.resize(200)
	_check(VoiceRecord.normalize_pcm(silence) == silence, "тишина не изменяется")

	# Отрицательные значения нормализуются без переполнения.
	#
	# В плане здесь стояло `if sample < 0: neg_ok = false` — то есть требование
	# «после нормализации нет отрицательных сэмплов», что противоречит собственному
	# тексту проверки («не даёт положительных пиков») и поведению функции: постоянный
	# сигнал -1000 обязан выровняться в -26214, а не в положительное число. Математика
	# normalize_pcm() побайтово совпадает с той, что годами работала в
	# LetterCard.play_recording(), — сломана была проверка, а не код. Поэтому
	# проверяем ровно то, что обещано: переноса нет (сэмпл == -26214) и положительных
	# пиков не появилось.
	var negative := PackedByteArray()
	negative.resize(200)
	for i in range(0, 200, 2):
		var v := -1000
		negative[i] = v & 0xFF
		negative[i + 1] = (v >> 8) & 0xFF
	var normalized_neg := VoiceRecord.normalize_pcm(negative)
	var neg_ok := true
	var neg_scaled := true
	for i in range(0, normalized_neg.size(), 2):
		var sample: int = normalized_neg[i] | (normalized_neg[i + 1] << 8)
		if sample > 32767:
			sample -= 65536
		if sample > 0:
			neg_ok = false
		if sample != -26214:
			neg_scaled = false
	_check(neg_scaled, "отрицательный сигнал выровнен до -26214 без переполнения")
	_check(neg_ok, "нормализация отрицательного сигнала не даёт положительных пиков")


## Без микрофона (headless, Dummy-драйвер) вызовы не падают и не блокируют.
func _check_no_microphone_is_safe() -> void:
	VoiceRecord.clear()
	_check(VoiceRecord.get_data().is_empty(), "после clear() данных нет")
	_check(VoiceRecord.has_data() == false, "has_data() == false после clear()")
	_check(VoiceRecord.is_recording() == false, "is_recording() == false в покое")
	_check(VoiceRecord.get_level() == 0.0, "уровень в покое равен 0")

	# Старт без микрофона обязан вернуть false, а не упасть.
	var started := VoiceRecord.start_recording()
	_check(started is bool, "start_recording() возвращает bool, а не падает")
	if started:
		VoiceRecord.stop_recording()
		_print("SKIP: микрофон доступен в headless, ветка отказа не проверена")
	else:
		_print("OK: start_recording() без микрофона вернул false")
	_check(VoiceRecord.get_data().is_empty(), "неудачная запись не оставила данных")
	VoiceRecord.release_microphone()


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
	print("[voice_record_validate] " + msg)


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
		print("[voice_record_validate] PASSED: %d проверок успешны" % checks)
		get_tree().quit(0)
