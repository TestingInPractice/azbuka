extends Node

var _player: AudioStreamPlayer2D
var _is_playing: bool = false

var _stream_cache: Dictionary = {}

const AUDIO_DIR := "res://assets/audio/"

func _ready():
	_player = AudioStreamPlayer2D.new()
	add_child(_player)
	_player.finished.connect(_on_player_finished)
	ThemeManager.sound_toggled.connect(_on_sound_toggled)
	if OS.has_feature('web'):
		_resume_web_audio()


func _resume_web_audio():
	# Resume Godot's internal audio context via the captured AudioContext
	# (window.__godotAudioCtx is set by the head_include hook in index.html)
	JavaScriptBridge.eval("""
		if (window.__godotAudioCtx && window.__godotAudioCtx.state === 'suspended') {
			window.__godotAudioCtx.resume();
		}
	""")

func _on_player_finished():
	_is_playing = false

func is_playing() -> bool:
	return _is_playing

func _load_stream(path: String) -> AudioStream:
	if _stream_cache.has(path):
		return _stream_cache[path]
	var stream := load(path) as AudioStream
	if stream:
		_stream_cache[path] = stream
	return stream

func play_letter(letter_id: String):
	if not ThemeManager.sound_enabled:
		return
	stop_all()
	var path: String = AUDIO_DIR + letter_id.to_lower() + "_letter_tts.wav"
	var stream: AudioStream = _load_stream(path)
	if stream:
		_player.stream = stream
		_player.play()
		_is_playing = true

func play_word(letter_id: String):
	if not ThemeManager.sound_enabled:
		return
	stop_all()
	var data: Dictionary = AlphabetData.get_letter_data(letter_id)
	var word_lower: String = data.get("word_lower", "")
	if word_lower.is_empty():
		return
	var path: String = AUDIO_DIR + word_lower + "_tts.wav"
	var stream: AudioStream = _load_stream(path)
	if stream:
		_player.stream = stream
		_player.play()
		_is_playing = true

func play_prompt(path: String):
	if not ThemeManager.sound_enabled:
		return
	stop_all()
	var stream: AudioStream = _load_stream(path)
	if stream:
		_player.stream = stream
		_player.play()
		_is_playing = true

func _on_sound_toggled(enabled: bool):
	if not enabled:
		stop_all()

func stop_all():
	if _player and _player.playing:
		_player.stop()
	if _player:
		_player.stream = null
	_is_playing = false
