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