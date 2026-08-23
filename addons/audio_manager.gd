extends Node
## AudioManager: воспроизведение звуков.
##
## Проигрывает аудио по пути ресурса (res://assets/audio/...). Путь передаёт
## вызывающий код (например, AlphabetData.get_letter_audio_path), поэтому
## AudioManager не знает про данные и темы проекта: зависимости вводятся на
## месте вызова. Состояние звука (включён/выключен) хранится здесь же.
## Синглтон-автолоад, не зависит от других сервисов.

## Состояние звука изменилось (false - звук выключен).
signal sound_toggled(enabled: bool)

## Включён ли звук в приложении.
var sound_enabled: bool = true

var _player: AudioStreamPlayer
var _music_player: AudioStreamPlayer
var _music_path: String = ""


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = &"Master"
	add_child(_player)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = &"Master"
	add_child(_music_player)


func set_sound_enabled(enabled: bool) -> void:
	if sound_enabled == enabled:
		return
	sound_enabled = enabled
	if not sound_enabled:
		stop_all()
	sound_toggled.emit(sound_enabled)


func play_audio(path: String) -> void:
	if not sound_enabled:
		return
	if path.is_empty():
		return
	var stream := load(path) as AudioStream
	if stream == null:
		push_error("AudioManager: не найден аудиофайл " + path)
		return
	play_stream(stream)


func play_stream(stream: AudioStream) -> void:
	if not sound_enabled:
		return
	_player.stream = stream
	_player.play()


func stop_all() -> void:
	if _player != null:
		_player.stop()
	stop_music()


## Запускает зацикленную музыку по пути ресурса. Если этот трек уже играет,
## ничего не делает (не перезапускает с начала).
func play_music(path: String) -> void:
	if not sound_enabled:
		return
	if path.is_empty():
		return
	if _music_path == path and _music_player.playing:
		return
	var stream := load(path) as AudioStream
	if stream == null:
		push_error("AudioManager: не найден музыкальный файл " + path)
		return
	stream.loop = true
	_music_path = path
	_music_player.stream = stream
	_music_player.play()


## Останавливает музыку и сбрасывает запомненный трек.
func stop_music() -> void:
	_music_path = ""
	if _music_player != null:
		_music_player.stop()
