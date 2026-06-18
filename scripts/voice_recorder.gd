extends Node

const RECORD_BUS := "VoiceRecord"

var _capture_effect: AudioEffectCapture = null
var _mic_player: AudioStreamPlayer = null
var _playback_player: AudioStreamPlayer = null
var _is_recording: bool = false
var _recorded_data: PackedByteArray = []
var _accumulated_frames: PackedVector2Array = []


func _ready():
	_setup_capture_bus()
	_mic_player = AudioStreamPlayer.new()
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.bus = RECORD_BUS
	add_child(_mic_player)
	_playback_player = AudioStreamPlayer.new()
	add_child(_playback_player)
	set_process(false)


func _process(_delta):
	if _is_recording and _capture_effect and _capture_effect.get_frames_available() > 0:
		_accumulated_frames.append_array(_capture_effect.get_buffer(_capture_effect.get_frames_available()))


func _setup_capture_bus():
	for i in AudioServer.get_bus_count():
		if AudioServer.get_bus_name(i) == RECORD_BUS:
			_capture_effect = AudioServer.get_bus_effect(i, 0)
			return
	var idx = AudioServer.get_bus_count()
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, RECORD_BUS)
	AudioServer.add_bus_effect(idx, AudioEffectCapture.new())
	_capture_effect = AudioServer.get_bus_effect(idx, 0)


func start_recording() -> bool:
	if _is_recording:
		return false
	_accumulated_frames.clear()
	_recorded_data.clear()
	_capture_effect.clear_buffer()
	_capture_effect.set_buffer_length(5.0)
	_mic_player.play()
	_is_recording = true
	set_process(true)
	return true


func stop_recording():
	if not _is_recording:
		return
	_is_recording = false
	_mic_player.stop()
	set_process(false)

	# read any remaining frames
	if _capture_effect and _capture_effect.get_frames_available() > 0:
		_accumulated_frames.append_array(_capture_effect.get_buffer(_capture_effect.get_frames_available()))
	_capture_effect.clear_buffer()

	if _accumulated_frames.is_empty():
		_recorded_data = PackedByteArray()
		return

	var mix_rate := AudioServer.get_mix_rate()
	_recorded_data.resize(_accumulated_frames.size() * 2)
	for i in _accumulated_frames.size():
		var sample := (_accumulated_frames[i].x + _accumulated_frames[i].y) * 0.5
		sample = clampf(sample, -1.0, 1.0)
		var val := int(sample * 32767)
		_recorded_data[i * 2] = val & 0xFF
		_recorded_data[i * 2 + 1] = (val >> 8) & 0xFF
	_accumulated_frames.clear()


func play_recording():
	if _recorded_data.is_empty():
		return
	var wav := AudioStreamWAV.new()
	wav.data = _recorded_data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = AudioServer.get_mix_rate()
	wav.stereo = false
	_playback_player.stream = wav
	_playback_player.play()


func stop_playback():
	if _playback_player and _playback_player.playing:
		_playback_player.stop()


func is_recording() -> bool:
	return _is_recording


func is_playing() -> bool:
	return _playback_player != null and _playback_player.playing


func has_recording() -> bool:
	return not _recorded_data.is_empty()


func clear_recording():
	_recorded_data.clear()


func _exit_tree():
	set_process(false)
	if _is_recording:
		_mic_player.stop()
