extends Node

var _player: AudioStreamPlayer2D
var _is_playing: bool = false

var _stream_cache: Dictionary = {}

const AUDIO_DIR := "res://assets/audio/"

func _ready():
	_player = AudioStreamPlayer2D.new()
	add_child(_player)
	_player.finished.connect(_on_player_finished)

func _on_player_finished():
	_is_playing = false

func is_playing() -> bool:
	return _is_playing

func _load_raw(path: String) -> AudioStream:
	if _stream_cache.has(path):
		return _stream_cache[path]
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	var bytes := file.get_buffer(file.get_length())
	file.close()
	var wav = AudioStreamWAV.new()
	wav.data = bytes
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.stereo = false
	_stream_cache[path] = wav
	return wav

func _load_stream(path: String) -> AudioStream:
	if _stream_cache.has(path):
		return _stream_cache[path]
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	var bytes := file.get_buffer(file.get_length())
	file.close()
	var data_start := 44
	if bytes.size() > 4 and bytes[0] == 0x52 and bytes[1] == 0x49 and bytes[2] == 0x46 and bytes[3] == 0x46:
		for i in range(12, bytes.size() - 8):
			if bytes[i] == 0x64 and bytes[i+1] == 0x61 and bytes[i+2] == 0x74 and bytes[i+3] == 0x61:
				data_start = i + 8
				break
	var pcm_data := bytes.slice(data_start, bytes.size())
	var wav = AudioStreamWAV.new()
	wav.data = pcm_data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.stereo = false
	_stream_cache[path] = wav
	return wav

func play_letter(letter_id: String):
	stop_all()
	var path: String = AUDIO_DIR + letter_id.to_lower() + "_letter.raw"
	var stream: AudioStream = _load_raw(path)
	if stream:
		_player.stream = stream
		_player.play()
		_is_playing = true

func play_word(letter_id: String):
	stop_all()
	var data: Dictionary = AlphabetData.get_letter_data(letter_id)
	var word_lower: String = data.get("word_lower", "")
	if word_lower.is_empty():
		return
	var path: String = AUDIO_DIR + word_lower + ".wav"
	var stream: AudioStream = _load_stream(path)
	if stream:
		_player.stream = stream
		_player.play()
		_is_playing = true

func stop_all():
	if _player and _player.playing:
		_player.stop()
	if _player:
		_player.stream = null
	_is_playing = false
