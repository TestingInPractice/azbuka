class_name AudioTranscoder
extends RefCounted
## Перекодирование m4a (AAC) в wav при загрузке звука в конструкторе.
##
## Godot не умеет читать AAC: в user:// такой файл сохранялся, но ни редактор,
## ни игры не могли его проиграть — родитель видел «звук есть», а слышал тишину.
## Декодер AAC есть только в браузере (Web Audio), поэтому конвертация живёт
## в JS-мосте: AudioContext.decodeAudioData → моно 16-бит PCM → WAV-контейнер.
##
## Разделение намеренное:
##   - чистое ядро (is_convertible, wav_name, parse_result) тестируется headless;
##   - сам декодер проверяется в браузере: headless Web Audio не существует.
##
## Мост не принимает байты из GDScript: файл до 10 МБ в base64 — это 13 МБ
## строки на каждом вызове. Вместо этого FileReader-колбэк оборачивается
## stash(): data URL остаётся в JS, через границу едет только результат.

## MIME-типы, которые браузер умеет декодировать, а Godot — нет.
const CONVERTIBLE_MIME_TYPES := [
	"audio/mp4",
	"audio/m4a",
	"audio/x-m4a",
	"audio/aac",
]

## Сколько ждём декодирования. Файл до 10 МБ на телефоне декодируется секунды,
## но зависший AudioContext не должен держать диалог вечно.
const CONVERT_TIMEOUT_SECONDS := 20.0

## Имя функции моста в window. Проверяется в install_bridge().
const BRIDGE_NAME := "omoAudio"

## Сам мост. Живёт строкой, а не отдельным .js: так он попадает в сборку без
## правки include_filter у экспорт-пресета, а тест в браузере извлекает его
## из этого же файла — второй копии нет.
##
## encodeWav() суммирует каналы в моно: игра проигрывает одну дорожку, а
## стерео удваивало бы размер файла без пользы.
const BRIDGE_JS := """
window.omoAudio = {
	_url: "",
	_name: "",
	stash: function (cb) {
		return function (event) {
			try {
				window.omoAudio._url = event.target.result;
				window.omoAudio._name = event.target.name;
			} catch (e) {
				window.omoAudio._url = "";
			}
			cb(event);
		};
	},
	encodeWav: function (buffer) {
		var channels = buffer.numberOfChannels;
		var frames = buffer.length;
		var mono = new Float32Array(frames);
		for (var c = 0; c < channels; c++) {
			var data = buffer.getChannelData(c);
			for (var i = 0; i < frames; i++) {
				mono[i] += data[i] / channels;
			}
		}
		var bytes = new Uint8Array(44 + frames * 2);
		var view = new DataView(bytes.buffer);
		var writeText = function (offset, text) {
			for (var i = 0; i < text.length; i++) {
				bytes[offset + i] = text.charCodeAt(i);
			}
		};
		writeText(0, "RIFF");
		view.setUint32(4, 36 + frames * 2, true);
		writeText(8, "WAVEfmt ");
		view.setUint32(16, 16, true);
		view.setUint16(20, 1, true);
		view.setUint16(22, 1, true);
		view.setUint32(24, buffer.sampleRate, true);
		view.setUint32(28, buffer.sampleRate * 2, true);
		view.setUint16(32, 2, true);
		view.setUint16(34, 16, true);
		writeText(36, "data");
		view.setUint32(40, frames * 2, true);
		for (var s = 0; s < frames; s++) {
			var sample = Math.max(-1, Math.min(1, mono[s]));
			view.setInt16(44 + s * 2, sample < 0 ? sample * 0x8000 : sample * 0x7fff, true);
		}
		return bytes;
	},
	toBase64: function (bytes) {
		var binary = "";
		var step = 0x8000;
		for (var i = 0; i < bytes.length; i += step) {
			binary += String.fromCharCode.apply(null, bytes.subarray(i, i + step));
		}
		return btoa(binary);
	},
	convert: function (cb) {
		var finish = function (payload) {
			cb(JSON.stringify(payload));
		};
		var url = window.omoAudio._url;
		if (!url) {
			finish({ok: false, error: "no_data"});
			return;
		}
		var Ctx = window.AudioContext || window.webkitAudioContext;
		if (!Ctx) {
			finish({ok: false, error: "no_audio_context"});
			return;
		}
		fetch(url).then(function (response) {
			return response.arrayBuffer();
		}).then(function (data) {
			var ctx = new Ctx();
			return ctx.decodeAudioData(data).then(function (audio) {
				var wav = window.omoAudio.encodeWav(audio);
				var payload = {
					ok: true,
					base64: window.omoAudio.toBase64(wav),
					sampleRate: audio.sampleRate,
					duration: audio.duration,
					name: window.omoAudio._name
				};
				window.omoAudio._url = "";
				try { ctx.close(); } catch (e) {}
				finish(payload);
			}, function () {
				try { ctx.close(); } catch (e) {}
				finish({ok: false, error: "decode_failed"});
			});
		}).catch(function () {
			finish({ok: false, error: "decode_failed"});
		});
	}
};
"""

## Установлен ли мост. Один eval на сессию: повторный перезаписал бы _url
## посреди чужой конвертации.
static var _installed: bool = false
## Последний ответ моста (JSON-строка) и флаг завершения.
static var _payload: String = ""
static var _done: bool = false
## Ссылки на JS-объекты: без поля их снимет браузерный GC.
static var _callback_ref: JavaScriptObject = null
static var _stash_ref: JavaScriptObject = null


## MIME, который декодирует браузер, но не Godot.
static func is_convertible(mime: String) -> bool:
	var clean := mime.strip_edges().to_lower()
	var semicolon := clean.find(";")
	if semicolon >= 0:
		clean = clean.substr(0, semicolon)
	return CONVERTIBLE_MIME_TYPES.has(clean)


## Имя файла после конвертации: тот же базис, расширение .wav.
## Пустой базис («.m4a») отдаём как «audio.wav», чтобы имя не начиналось с точки.
static func wav_name(original_name: String) -> String:
	var base := original_name.strip_edges()
	var slash := base.rfind("/")
	if slash >= 0:
		base = base.substr(slash + 1)
	var dot := base.rfind(".")
	if dot > 0:
		base = base.substr(0, dot)
	if base.is_empty():
		base = "audio"
	return base + ".wav"


## Разбирает ответ моста. Возвращает {ok, bytes, mime, duration, error}.
## Ошибка моста (не JSON, пустые байты) не должна выдаваться за успех.
static func parse_result(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return _failure("bad_response")
	var data: Dictionary = json.data
	if not bool(data.get("ok", false)):
		return _failure(str(data.get("error", "convert_failed")))
	var bytes := Marshalls.base64_to_raw(str(data.get("base64", "")))
	if bytes.is_empty():
		return _failure("bad_payload")
	return {
		"ok": true,
		"bytes": bytes,
		"mime": "audio/wav",
		"duration": float(data.get("duration", 0.0)),
		"error": "",
	}


## Оборачивает FileReader-колбэк так, чтобы data URL остался в JS.
## Возвращает JS-функцию для onload; вне веба — исходный колбэк.
static func stash_reader_callback(callback: JavaScriptObject) -> JavaScriptObject:
	if not install_bridge():
		return callback
	var win := JavaScriptBridge.get_interface("window")
	# JavaScriptObject.call() принимает имя JS-метода, а не сам объект-функцию:
	# поэтому вызов идёт через omoAudio.call("stash", ...), не stash.call(...).
	var wrapper: JavaScriptObject = win.omoAudio.call("stash", callback)
	_stash_ref = wrapper
	return _stash_ref


## Загружает мост в window один раз. false — моста нет (вне веба или без JS).
static func install_bridge() -> bool:
	if _installed:
		return true
	if not OS.has_feature("web"):
		return false
	if JavaScriptBridge.get_interface("window") == null:
		return false
	JavaScriptBridge.eval(BRIDGE_JS, true)
	var win := JavaScriptBridge.get_interface("window")
	if win == null or win.omoAudio == null:
		return false
	_installed = true
	return true


## Конвертирует ранее сохранённый в мосте файл. Требует stash_reader_callback().
## Возвращает {ok, bytes, mime, duration, error}.
static func convert() -> Dictionary:
	if not OS.has_feature("web"):
		return _failure("not_web")
	if not install_bridge():
		return _failure("no_bridge")
	var win := JavaScriptBridge.get_interface("window")
	_payload = ""
	_done = false
	_callback_ref = JavaScriptBridge.create_callback(_on_bridge_result)
	win.omoAudio.call("convert", _callback_ref)
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return _failure("no_bridge")
	var timer := tree.create_timer(CONVERT_TIMEOUT_SECONDS)
	while not _done and timer.time_left > 0.0:
		await tree.process_frame
	if not _done:
		return _failure("timeout")
	return parse_result(_payload)


## Колбэк моста: единственный аргумент — JSON-строка с результатом.
static func _on_bridge_result(args: Array) -> void:
	_payload = str(args[0]) if not args.is_empty() else ""
	_done = true


## Ответ моста с ошибкой. Байтов нет, mime пустой.
static func _failure(code: String) -> Dictionary:
	return {"ok": false, "bytes": PackedByteArray(), "mime": "", "duration": 0.0, "error": code}
