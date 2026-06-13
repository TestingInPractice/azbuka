extends Node

const RECORD_BUS := "VoiceRecord"

var _record_effect: AudioEffectRecord = null
var _mic_player: AudioStreamPlayer = null
var _playback_player: AudioStreamPlayer = null
var _is_recording: bool = false
var _recording: AudioStreamWAV = null


func _ready():
	_setup_recording_bus()
	_mic_player = AudioStreamPlayer.new()
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.bus = RECORD_BUS
	add_child(_mic_player)
	_playback_player = AudioStreamPlayer.new()
	add_child(_playback_player)


func _setup_recording_bus():
	for i in AudioServer.get_bus_count():
		if AudioServer.get_bus_name(i) == RECORD_BUS:
			_record_effect = AudioServer.get_bus_effect(i, 0)
			return
	var idx = AudioServer.get_bus_count()
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, RECORD_BUS)
	AudioServer.add_bus_effect(idx, AudioEffectRecord.new())
	_record_effect = AudioServer.get_bus_effect(idx, 0)


func start_recording() -> bool:
	if _is_recording:
		return false
	_recording = null
	_record_effect.set_recording_active(true)
	_mic_player.play()
	_is_recording = true
	return true


func stop_recording():
	if not _is_recording:
		return
	_record_effect.set_recording_active(false)
	_mic_player.stop()
	_recording = _record_effect.get_recording()
	_is_recording = false


func play_recording():
	if _recording:
		_playback_player.stream = _recording
		_playback_player.play()


func stop_playback():
	if _playback_player and _playback_player.playing:
		_playback_player.stop()


func is_recording() -> bool:
	return _is_recording


func is_playing() -> bool:
	return _playback_player != null and _playback_player.playing


func has_recording() -> bool:
	return _recording != null


func clear_recording():
	_recording = null


func _exit_tree():
	if _is_recording:
		_record_effect.set_recording_active(false)
		_mic_player.stop()
