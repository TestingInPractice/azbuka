extends Node
## Валидатор AudioTranscoder: таблица MIME, имя wav-файла, разбор ответа моста
## и честный отказ вне браузера.
## Сам декодер AAC проверяется в браузере: headless Web Audio не существует,
## поэтому здесь проверяется только то, что от него не зависит.
## Запуск: godot --headless --path . res://tests/validate_audio_transcoder.tscn

var failures := 0


func _ready() -> void:
	await get_tree().process_frame

	# Страховка от ложного «всё прошло»: если скрипт не скомпилировался, Godot
	# создаёт объект класса без методов, все проверки падают на первой строке,
	# счётчик остаётся нулевым и валидатор завершился бы с exit 0.
	if not _class_loaded():
		_fail("AudioTranscoder не загрузился: статические методы недоступны")
		_finish()
		return

	_check_convertible_table()
	_check_wav_name()
	_check_parse_success()
	_check_parse_failures()
	await _check_convert_off_web()

	_finish()


func _class_loaded() -> bool:
	var required := ["is_convertible", "wav_name", "parse_result", "convert", \
			"install_bridge", "stash_reader_callback"]
	var script := AudioTranscoder as Script
	if script == null:
		return false
	var present := {}
	for method: Dictionary in script.get_script_method_list():
		present[method.get("name", "")] = true
	for name: String in required:
		if not present.has(name):
			return false
	return true


## MIME с параметрами и в верхнем регистре должен распознаваться: браузер
## отдаёт "audio/mp4; codecs=..." на части Android-устройств.
func _check_convertible_table() -> void:
	_check(AudioTranscoder.is_convertible("audio/mp4"), "audio/mp4 конвертируется")
	_check(AudioTranscoder.is_convertible("audio/x-m4a"), "audio/x-m4a конвертируется")
	_check(AudioTranscoder.is_convertible("audio/m4a"), "audio/m4a конвертируется")
	_check(AudioTranscoder.is_convertible("audio/aac"), "audio/aac конвертируется")
	_check(AudioTranscoder.is_convertible("AUDIO/MP4;codecs=mp4a.40.2"),
			"MIME с параметрами и в верхнем регистре конвертируется")
	_check(not AudioTranscoder.is_convertible("audio/wav"), "audio/wav не конвертируется")
	_check(not AudioTranscoder.is_convertible("audio/ogg"), "audio/ogg не конвертируется")
	_check(not AudioTranscoder.is_convertible("audio/mpeg"), "audio/mpeg не конвертируется")
	_check(not AudioTranscoder.is_convertible(""), "пустой MIME не конвертируется")
	_check(not AudioTranscoder.is_convertible("image/png"), "картинка не конвертируется")


## Имя результата: тот же базис и .wav, иначе extension_for_mime и содержимое
## файла разойдутся, и плеер снова получит чужой формат.
func _check_wav_name() -> void:
	_check(AudioTranscoder.wav_name("Запись.m4a") == "Запись.wav",
			"имя m4a меняет расширение: %s" % AudioTranscoder.wav_name("Запись.m4a"))
	_check(AudioTranscoder.wav_name("rec") == "rec.wav",
			"имя без расширения получает .wav")
	_check(AudioTranscoder.wav_name("a.b.m4a") == "a.b.wav",
			"точки в базисе сохраняются: %s" % AudioTranscoder.wav_name("a.b.m4a"))
	_check(AudioTranscoder.wav_name("/tmp/x/voice.M4A") == "voice.wav",
			"путь отбрасывается, регистр расширения не важен: %s"
					% AudioTranscoder.wav_name("/tmp/x/voice.M4A"))
	_check(AudioTranscoder.wav_name(".m4a") == ".m4a.wav" or
			AudioTranscoder.wav_name(".m4a") == "audio.wav",
			"скрытое имя не остаётся без базиса: %s" % AudioTranscoder.wav_name(".m4a"))


## Успешный ответ моста: байты из base64, mime ровно audio/wav (его
## extension_for_mime переводит в wav), длительность прокидывается.
func _check_parse_success() -> void:
	var payload := '{"ok":true,"base64":"UklGRg==","duration":1.5}'
	var result := AudioTranscoder.parse_result(payload)
	_check(bool(result.get("ok", false)), "успешный ответ моста разобран")
	var bytes: PackedByteArray = result.get("bytes", PackedByteArray())
	_check(bytes.size() == 4 and bytes[0] == 82 and bytes[1] == 73 and bytes[2] == 70
			and bytes[3] == 70, "base64 разобран в байты RIFF: %d" % bytes.size())
	_check(str(result.get("mime", "")) == "audio/wav",
			"после конвертации mime ровно audio/wav")
	_check(abs(float(result.get("duration", 0.0)) - 1.5) < 0.001,
			"длительность перенесена из ответа")


## Любой сбой моста обязан стать ошибкой, а не пустым «успехом»: иначе
## apply_audio() запишет ноль байт и слот покажет «заполнено».
func _check_parse_failures() -> void:
	_check_failure("не JSON", AudioTranscoder.parse_result("not json"), "bad_response")
	_check_failure("JSON без словаря", AudioTranscoder.parse_result("[1,2]"),
			"bad_response")
	_check_failure("ok=false", AudioTranscoder.parse_result('{"ok":false,"error":"decode_failed"}'),
			"decode_failed")
	_check_failure("пустой base64",
			AudioTranscoder.parse_result('{"ok":true,"base64":""}'), "bad_payload")
	var empty_bytes: PackedByteArray = AudioTranscoder.parse_result(
			'{"ok":true,"base64":""}').get("bytes", PackedByteArray())
	_check(empty_bytes.is_empty(), "у неуспешного разбора нет байтов")


func _check_failure(what: String, result: Dictionary, expected: String) -> void:
	_check(not bool(result.get("ok", true)), "%s: не выдаётся за успех" % what)
	_check(str(result.get("error", "")) == expected,
			"%s: код ошибки %s (получен %s)" % [what, expected,
					str(result.get("error", ""))])


## Вне веба Web Audio нет: конвертация обязана вернуть ошибку, а не висеть.
func _check_convert_off_web() -> void:
	if OS.has_feature("web"):
		_print("SKIP: проверка convert() вне web неприменима в веб-сборке")
		return
	var result := await AudioTranscoder.convert()
	_check(not bool(result.get("ok", true)), "convert() вне web возвращает ошибку")
	_check(str(result.get("error", "")) == "not_web", "код ошибки not_web")
	_check(not AudioTranscoder.install_bridge(), "мост вне web не устанавливается")


func _check(ok: bool, msg: String) -> void:
	if ok:
		_print("OK: " + msg)
	else:
		_fail(msg)


func _fail(msg: String) -> void:
	failures += 1
	printerr("FAIL: " + msg)


func _print(msg: String) -> void:
	print("[audio_transcoder_validate] " + msg)


func _finish() -> void:
	if failures > 0:
		printerr("FAILED: %d проверок" % failures)
		get_tree().quit(1)
	else:
		print("[audio_transcoder_validate] PASSED: все проверки успешны")
		get_tree().quit(0)
