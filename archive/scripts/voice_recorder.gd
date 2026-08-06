extends Node

const RECORD_BUS := "VoiceRecord"

var _capture_effect: AudioEffectCapture = null
var _mic_player: AudioStreamPlayer = null
var _playback_player: AudioStreamPlayer = null
var _mic_prepared: bool = false
var _is_recording: bool = false
var _recorded_data: PackedByteArray = []
var _accumulated_frames: PackedVector2Array = []
var _current_level: float = 0.0


func _ready():
	_setup_capture_bus()
	_playback_player = AudioStreamPlayer.new()
	add_child(_playback_player)
	set_process(false)


func _process(_delta):
	if _is_recording and _capture_effect and _capture_effect.get_frames_available() > 0:
		var frames := _capture_effect.get_buffer(_capture_effect.get_frames_available())
		_accumulated_frames.append_array(frames)

		var sum_sq := 0.0
		for f in frames:
			var m := (f.x + f.y) * 0.5
			sum_sq += m * m
		var rms := sqrt(sum_sq / frames.size()) if frames.size() > 0 else 0.0
		_current_level = lerp(_current_level, rms, 0.25)


func _setup_capture_bus():
	for i in AudioServer.get_bus_count():
		if AudioServer.get_bus_name(i) == RECORD_BUS:
			_capture_effect = AudioServer.get_bus_effect(i, 0)
			_capture_effect.set_buffer_length(6.0)
			AudioServer.set_bus_volume_db(i, -80)
			return
	var idx = AudioServer.get_bus_count()
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, RECORD_BUS)
	var cap := AudioEffectCapture.new()
	cap.set_buffer_length(6.0)
	AudioServer.add_bus_effect(idx, cap)
	_capture_effect = AudioServer.get_bus_effect(idx, 0)
	AudioServer.set_bus_volume_db(idx, -80)


func prepare_microphone():
	if _mic_prepared:
		return
	_mic_player = AudioStreamPlayer.new()
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.bus = RECORD_BUS
	add_child(_mic_player)
	_mic_player.play()
	_mic_prepared = true
	print("VoiceRecorder: microphone prepared and playing")


func start_recording() -> bool:
	if _is_recording:
		return false
	if not _capture_effect:
		push_error("VoiceRecorder: AudioEffectCapture is null - cannot record")
		return false
	if not _mic_prepared:
		push_warning("VoiceRecorder: mic not prepared, calling prepare_microphone()")
		prepare_microphone()

	_accumulated_frames.clear()
	_recorded_data.clear()
	_capture_effect.clear_buffer()
	_capture_effect.set_buffer_length(5.0)
	_is_recording = true
	set_process(true)
	print("VoiceRecorder: recording started")
	return true


func stop_recording():
	if not _is_recording:
		return
	_is_recording = false
	set_process(false)
	_current_level = 0.0

	if _capture_effect and _capture_effect.get_frames_available() > 0:
		_accumulated_frames.append_array(_capture_effect.get_buffer(_capture_effect.get_frames_available()))
	_capture_effect.clear_buffer()

	if _accumulated_frames.is_empty():
		_recorded_data = PackedByteArray()
		push_warning("VoiceRecorder: no frames captured — microphone may be silent or permissions denied")
		return

	print("VoiceRecorder: captured ", _accumulated_frames.size(), " frames")

	var mix_rate := AudioServer.get_mix_rate()
	_recorded_data.resize(_accumulated_frames.size() * 2)
	for i in _accumulated_frames.size():
		var sample := (_accumulated_frames[i].x + _accumulated_frames[i].y) * 0.5
		sample = clampf(sample, -1.0, 1.0)
		var val := int(sample * 32767)
		_recorded_data[i * 2] = val & 0xFF
		_recorded_data[i * 2 + 1] = (val >> 8) & 0xFF
	_accumulated_frames.clear()

	print("VoiceRecorder: recording done — data size = ", _recorded_data.size(), " bytes")


func play_recording():
	if _recorded_data.is_empty():
		return

	var playback_data: PackedByteArray = _recorded_data
	var max_abs: int = 0
	for i in range(0, _recorded_data.size(), 2):
		var sample: int = _recorded_data[i] | (_recorded_data[i+1] << 8)
		if sample > 32767:
			sample -= 65536
		var abs_sample: int = -sample if sample < 0 else sample
		if abs_sample > max_abs:
			max_abs = abs_sample

	if max_abs > 0 and max_abs < 26214:
		var scale: float = 26214.0 / max_abs
		playback_data = PackedByteArray()
		playback_data.resize(_recorded_data.size())
		for i in range(0, _recorded_data.size(), 2):
			var sample: int = _recorded_data[i] | (_recorded_data[i+1] << 8)
			if sample > 32767:
				sample -= 65536
			var scaled: int = clampi(int(sample * scale), -32768, 32767)
			var uscaled: int = scaled + 65536 if scaled < 0 else scaled
			playback_data[i] = uscaled & 0xFF
			playback_data[i+1] = (uscaled >> 8) & 0xFF

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = AudioServer.get_mix_rate()
	wav.stereo = false
	wav.data = playback_data
	_playback_player.stream = wav
	_playback_player.play()


func stop_playback():
	if _playback_player and _playback_player.playing:
		_playback_player.stop()


func is_recording() -> bool:
	return _is_recording


func is_playing() -> bool:
	return _playback_player != null and _playback_player.playing


func get_current_level() -> float:
	return _current_level

func get_recorded_data() -> PackedByteArray:
	return _recorded_data

func has_recording() -> bool:
	return not _recorded_data.is_empty()


func clear_recording():
	_recorded_data.clear()

func save_recording(path: String) -> bool:
	if _recorded_data.is_empty():
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return false
	var data_size := _recorded_data.size()
	var file_size := 36 + data_size
	var sample_rate := AudioServer.get_mix_rate()

	var header := PackedByteArray()
	header.resize(44)
	header.encode_u32(0, 0x46464952)
	header.encode_u32(4, file_size)
	header.encode_u32(8, 0x45564157)
	header.encode_u32(12, 0x20746D66)
	header.encode_u32(16, 16)
	header.encode_u16(20, 1)
	header.encode_u16(22, 1)
	header.encode_u32(24, sample_rate)
	header.encode_u32(28, sample_rate * 2)
	header.encode_u16(32, 2)
	header.encode_u16(34, 16)
	header.encode_u32(36, 0x61746164)
	header.encode_u32(40, data_size)

	file.store_buffer(header)
	file.store_buffer(_recorded_data)
	file.close()
	return true


func _exit_tree():
	set_process(false)
	if _is_recording and _mic_player:
		_mic_player.stop()
