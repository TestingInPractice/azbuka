extends Node

var _player: AudioStreamPlayer2D
var _freq_map: Dictionary = {}
var _is_playing: bool = false
var _play_pending: bool = false

const SAMPLE_RATE := 44100
const LETTERS := "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ"

func _ready():
	_player = AudioStreamPlayer2D.new()
	add_child(_player)
	_player.finished.connect(_on_player_finished)
	_build_freq_map()

func _on_player_finished():
	_is_playing = false
	_play_pending = false

func is_playing() -> bool:
	return _is_playing

func _build_freq_map():
	var count = LETTERS.length()
	for i in count:
		var freq = 200.0 + (float(i) / max(count - 1, 1)) * 600.0
		_freq_map[LETTERS[i]] = freq

func _get_frequency(letter_id: String) -> float:
	return _freq_map.get(letter_id, 440.0)

func _generate_wav(frequency: float, duration: float, sweep: float = 1.0) -> AudioStreamWAV:
	var num_samples = max(int(SAMPLE_RATE * duration), 1)
	var data := PackedByteArray()
	data.resize(num_samples * 2)

	for i in range(num_samples):
		var t = float(i) / SAMPLE_RATE
		var progress = float(i) / num_samples
		var freq = frequency * (1.0 + (sweep - 1.0) * progress)
		var sample = sin(2.0 * PI * freq * t) * 0.3
		var val = int(clamp(sample * 32767.0, -32768.0, 32767.0))
		var idx = i * 2
		data[idx] = val & 0xFF
		data[idx + 1] = (val >> 8) & 0xFF

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.data = data
	wav.stereo = false
	return wav

func play_letter(letter_id: String):
	stop_all()
	_play_pending = true
	var wav = _generate_wav(_get_frequency(letter_id), 0.5)
	_player.stream = wav
	_player.play()
	_is_playing = true

func play_word(letter_id: String):
	stop_all()
	_play_pending = true
	var wav = _generate_wav(_get_frequency(letter_id), 1.0, 1.5)
	_player.stream = wav
	_player.play()
	_is_playing = true

func stop_all():
	_play_pending = false
	if _player and _player.playing:
		_player.stop()
	if _player:
		_player.stream = null
	_is_playing = false
