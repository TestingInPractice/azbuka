extends Node
## VoiceRecord: захват микрофона и запись в WAV-байты.
##
## Выделен из LetterCard, где рекордер жил встроенным: конструктору наборов
## тоже нужна запись озвучки слова, и дублировать шину и эффект захвата в двух
## местах нельзя — AudioEffectCapture на шине может быть только один.
##
## Запись идёт на шине VoiceRecord, которая заглушена на -80 dB: иначе голос
## ребёнка слышно в колонках. Микрофон освобождается сразу после записи —
## на iOS активная захват-сессия переводит аудиомикшер в "голосовой" режим
## и следующие звуки играют тише.
##
## Чистое ядро (stereo_frames_to_pcm, pcm_to_wav_bytes, normalize_pcm) не
## зависит от устройства и покрыто тестами; работа с шиной проверяется в браузере.

const RECORD_BUS := "VoiceRecord"
## Глушина шины захвата: голос не должен попадать в колонки.
const MIC_SILENCE_DB := -80.0
## Длина буфера захвата в секундах. Запись 10 с дольше буфера, поэтому кадры
## накапливаются в _process по мере поступления.
const BUFFER_LENGTH := 6.0
## Доля, до которой выравнивается пик при воспроизведении тихой записи.
## 26214 из 32767 оставляет запас от клиппинга.
const NORMALIZE_PEAK := 26214.0

signal recording_started
## Запись остановлена. has_data — есть ли пригодные для сохранения данные.
signal recording_finished(has_data: bool)

var _capture_effect: AudioEffectCapture = null
var _mic_player: AudioStreamPlayer = null
var _accumulated_frames := PackedVector2Array()
var _recorded_data := PackedByteArray()
var _is_recording := false
var _current_level := 0.0


func _ready() -> void:
	_setup_capture_bus()
	set_process(false)


func _process(_delta: float) -> void:
	if not _is_recording or _capture_effect == null:
		return
	var available: int = _capture_effect.get_frames_available()
	if available <= 0:
		return
	var frames: PackedVector2Array = _capture_effect.get_buffer(available)
	_accumulated_frames.append_array(frames)
	var sum_sq := 0.0
	for frame: Vector2 in frames:
		var sample: float = (frame.x + frame.y) * 0.5
		sum_sq += sample * sample
	var rms: float = sqrt(sum_sq / float(frames.size()))
	# Сглаживание, чтобы индикатор не дрожал.
	_current_level = lerpf(_current_level, rms, 0.25)


## Стереокадры захвата -> моно PCM 16-bit little-endian.
## Каналы усредняются, выход за [-1, 1] обрезается, а не переполняется.
static func stereo_frames_to_pcm(frames: PackedVector2Array) -> PackedByteArray:
	var pcm := PackedByteArray()
	pcm.resize(frames.size() * 2)
	for i in frames.size():
		var sample := (frames[i].x + frames[i].y) * 0.5
		sample = clampf(sample, -1.0, 1.0)
		var value := int(sample * 32767)
		pcm[i * 2] = value & 0xFF
		pcm[i * 2 + 1] = (value >> 8) & 0xFF
	return pcm


## PCM 16-bit mono -> полный WAV-файл (44-байтный заголовок + данные).
## Пустой PCM даёт пустой результат: файл без звука бесполезен.
static func pcm_to_wav_bytes(pcm: PackedByteArray, sample_rate: int) -> PackedByteArray:
	if pcm.is_empty():
		return PackedByteArray()
	var header := PackedByteArray()
	header.resize(44)
	var data_size: int = pcm.size()
	header.encode_u32(0, 0x46464952)
	header.encode_u32(4, 36 + data_size)
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
	header.append_array(pcm)
	return header


## Выравнивает тихую запись до пика NORMALIZE_PEAK. Громкий сигнал и тишина
## не меняются; входные байты не изменяются на месте.
static func normalize_pcm(pcm: PackedByteArray) -> PackedByteArray:
	if pcm.is_empty():
		return PackedByteArray()
	var max_abs := 0
	for i in range(0, pcm.size(), 2):
		var sample: int = pcm[i] | (pcm[i + 1] << 8)
		if sample > 32767:
			sample -= 65536
		max_abs = maxi(max_abs, -sample if sample < 0 else sample)
	if max_abs <= 0 or max_abs >= int(NORMALIZE_PEAK):
		return pcm.duplicate()
	var scale := NORMALIZE_PEAK / float(max_abs)
	var out := PackedByteArray()
	out.resize(pcm.size())
	for i in range(0, pcm.size(), 2):
		var sample: int = pcm[i] | (pcm[i + 1] << 8)
		if sample > 32767:
			sample -= 65536
		var scaled := clampi(int(sample * scale), -32768, 32767)
		var unsigned := scaled + 65536 if scaled < 0 else scaled
		out[i] = unsigned & 0xFF
		out[i + 1] = (unsigned >> 8) & 0xFF
	return out


## Готовит микрофон. false, если шины или устройства нет — тогда запись
## невозможна и вызывающий должен сообщить об этом пользователю.
func prepare_microphone() -> bool:
	if _mic_player != null and _mic_player.playing:
		return true
	if _mic_player == null:
		_mic_player = AudioStreamPlayer.new()
		_mic_player.stream = AudioStreamMicrophone.new()
		_mic_player.bus = RECORD_BUS
		add_child(_mic_player)
	_mic_player.play()
	var prepared: bool = _mic_player.playing
	GameLogger.info("VoiceRecord", "mic_prepared", {"ok": prepared})
	return prepared


## Начинает запись. false, если уже идёт запись или микрофон недоступен.
func start_recording() -> bool:
	if _is_recording:
		return false
	if not prepare_microphone():
		GameLogger.warning("VoiceRecord", "mic_unavailable", {})
		return false
	_accumulated_frames.clear()
	_recorded_data.clear()
	_current_level = 0.0
	if _capture_effect != null:
		_capture_effect.clear_buffer()
		_capture_effect.set_buffer_length(BUFFER_LENGTH)
	_is_recording = true
	set_process(true)
	recording_started.emit()
	GameLogger.info("VoiceRecord", "record_start", {})
	return true


## Останавливает запись и собирает PCM. false, если записи не было или
## микрофон не дал ни одного кадра.
func stop_recording() -> bool:
	if not _is_recording:
		return false
	_is_recording = false
	set_process(false)
	_current_level = 0.0
	if _capture_effect != null and _capture_effect.get_frames_available() > 0:
		_accumulated_frames.append_array(
				_capture_effect.get_buffer(_capture_effect.get_frames_available()))
	# Микрофон освобождаем сразу: см. предупреждение в шапке класса.
	release_microphone()
	_recorded_data = stereo_frames_to_pcm(_accumulated_frames)
	_accumulated_frames.clear()
	var has_data := not _recorded_data.is_empty()
	if not has_data:
		push_warning("VoiceRecord: no frames captured - microphone may be silent or permissions denied")
	recording_finished.emit(has_data)
	GameLogger.info("VoiceRecord", "record_stop", {"bytes": _recorded_data.size()})
	return has_data


## Идёт ли запись сейчас.
func is_recording() -> bool:
	return _is_recording


## Есть ли пригодные данные записи.
func has_data() -> bool:
	return not _recorded_data.is_empty()


## Копия записанного PCM (без WAV-заголовка).
func get_data() -> PackedByteArray:
	return _recorded_data.duplicate()


## Записанный PCM в виде готового WAV-файла.
func get_wav_bytes() -> PackedByteArray:
	return pcm_to_wav_bytes(_recorded_data, AudioServer.get_mix_rate())


## Текущий уровень сигнала 0..1 для индикатора записи.
func get_level() -> float:
	return _current_level


## Забывает запись, не трогая состояние микрофона.
func clear() -> void:
	_recorded_data.clear()
	_accumulated_frames.clear()
	_current_level = 0.0


## Отпускает микрофон, если он был запущен.
func release_microphone() -> void:
	if _mic_player != null and _mic_player.playing:
		_mic_player.stop()


## Создаёт шину VoiceRecord и вешает на неё AudioEffectCapture.
##
## ВАЖНО, не упрощать. Web export: AudioServer.add_bus() (at_pos=-1) попадает в
## JS Bus.addAt(-1), который через move()+splice(-2,0) ПЕРЕВОРАЧИВАЕТ JS-массив
## шин ([master, record] -> [record, master]) при существующей одной шине.
## C++ при этом думает, что индексы [Master(0), VoiceRecord(1)] — расходятся.
## Результат: set_bus_volume_db(1,-80) глушит Master, а буквы по индексу 0
## уходят в VoiceRecord — тишина. set_bus_layout() создаёт шины через
## set_sample_bus_count -> Bus.setCount -> create() (append без move) — порядок
## [master, record] корректен. default_bus_layout.tres уже содержит VoiceRecord.
func _setup_capture_bus() -> void:
	var bus_index: int = AudioServer.get_bus_index(RECORD_BUS)
	if bus_index == -1:
		var layout := load("res://assets/audio/default_bus_layout.tres") as AudioBusLayout
		if layout != null:
			AudioServer.set_bus_layout(layout)
			bus_index = AudioServer.get_bus_index(RECORD_BUS)
	if bus_index == -1:
		push_warning("VoiceRecord: шина %s не создана — запись будет недоступна" % RECORD_BUS)
		return
	if AudioServer.get_bus_effect_count(bus_index) == 0:
		_capture_effect = AudioEffectCapture.new()
		_capture_effect.set_buffer_length(BUFFER_LENGTH)
		AudioServer.add_bus_effect(bus_index, _capture_effect)
	else:
		_capture_effect = AudioServer.get_bus_effect(bus_index, 0) as AudioEffectCapture
	AudioServer.set_bus_volume_db(bus_index, MIC_SILENCE_DB)
