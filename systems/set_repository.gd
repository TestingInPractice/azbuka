extends Node
## SetRepository: единственный путь чтения данных буквы для всех игр.
##
## Игры больше не знают, откуда взялись данные: встроенный набор читается из
## AlphabetData, пользовательский — из CustomSetsStore и файлов в user://.
## Единая точка выбора — ProgressManager.get_word_set_id().
##
## Кэширует Texture2D и AudioStream по пути: картинки и слова проигрываются
## много раз за игру, а load() на каждом кадре — лишняя работа. Кэш
## сбрасывается по сигналу sets_changed, чтобы правка набора была видна сразу.
##
## Тонкость: load() не умеет открывать файлы из user:// в веб-сборке (у них нет
## .import). Поэтому картинки читаются через Image.load_from_file(), а звук —
## через форматозависимый load_from_file().

## Базовые пути встроенных ресурсов: для них load() работает как раньше.
const BUILTIN_IMAGE_DIR := "res://assets/images/"

var _texture_cache: Dictionary = {}
var _audio_cache: Dictionary = {}


func _ready() -> void:
	CustomSetsStore.sets_changed.connect(clear_cache)


## Идентификатор активного набора: id пользовательского либо номер встроенного.
func get_active_set_id() -> String:
	return ProgressManager.get_word_set_id()


## Пользовательский ли набор. Основано на реальном наличии набора в хранилище,
## а не на префиксе id: удалённый набор перестаёт быть пользовательским, и
## игра молча возвращается к встроенным данным.
func is_custom_set(set_id: String) -> bool:
	return not CustomSetsStore.get_set_by_id(set_id).is_empty()


## Данные слова для активного набора: {word, image_path, audio_path, is_custom}.
## Встроенный набор: image/audio — пути res://. Пользовательский: пути user://.
##
## Откат на встроенные данные — ПО БУКВЕ, а не по полю. Если родитель заполнил
## 5 букв из 33, а игра листает весь алфавит (см. LetterCard.LETTERS), то
## остальные 28 обязаны вести себя ровно так же, как при выборе встроенного
## набора. Без отката они давали пустой словарь и рисовали пустую карточку.
##
## Гранулярность — целиком на запись, а не на поле. Запись считается
## пользовательской только когда у неё есть И слово, И картинка, И звук
## (CustomSetsStore.is_entry_complete). Неполная запись уходит на встроенные
## данные ЦЕЛИКОМ. Полевое слияние отвергнуто осознанно: собственное слово
## родителя встало бы рядом со встроенной картинкой ДРУГОГО слова, и карточка
## «Бегемот» с картинкой банана хуже для ребёнка, чем честная встроенная «Б».
func get_word_data(letter: String) -> Dictionary:
	var key := letter.to_upper()
	if key.is_empty():
		return {}
	var set_id := get_active_set_id()
	if is_custom_set(set_id):
		return _custom_word_data(set_id, key)
	return _builtin_word_data(key)


## Текстура картинки слова или null. Результат кэшируется по пути.
func get_word_texture(letter: String) -> Texture2D:
	var path := str(get_word_data(letter).get("image_path", ""))
	if path.is_empty():
		return null
	if _texture_cache.has(path):
		return _texture_cache[path] as Texture2D
	var texture: Texture2D = null
	if path.begins_with("res://"):
		texture = load(path) as Texture2D
	else:
		var image := Image.new()
		var err := image.load(path)
		if err == OK:
			texture = ImageTexture.create_from_image(image)
		else:
			GameLogger.warning("SetRepository", "image_load_failed", {"path": path, "err": err})
	if texture == null:
		GameLogger.warning("SetRepository", "image_missing", {"path": path, "letter": letter})
		return null
	_texture_cache[path] = texture
	return texture


## Звук слова или null. Для встроенных наборов это res://-файл, для
## пользовательских — WAV/OGG/MP3 из user://.
func get_word_audio(letter: String) -> AudioStream:
	return _cached_audio(str(get_word_data(letter).get("audio_path", "")))


## Название буквы. Свойство буквы, а не набора: всегда из встроенных данных.
func get_letter_audio(letter: String) -> AudioStream:
	return _cached_audio(AlphabetData.get_letter_audio_path(letter, ProgressManager.get_voice_variant()))


## Фонема буквы с фолбэком на название (у Ъ/Ь своего звука нет).
func get_letter_sound(letter: String) -> AudioStream:
	return _cached_audio(AlphabetData.get_letter_sound_path(letter))


## Буквы активного набора. Для встроенного — все 33, для пользовательского —
## только заполненные родителем.
func get_active_letters() -> Array[String]:
	var set_id := get_active_set_id()
	if is_custom_set(set_id):
		return CustomSetsStore.get_set_letters(set_id)
	var out: Array[String] = []
	for entry: Dictionary in AlphabetData.get_letters():
		out.append(str(entry.get("letter", "")))
	return out


## Есть ли буква в активном наборе.
func has_letter(letter: String) -> bool:
	return get_active_letters().has(letter.to_upper())


## Сбрасывает кэш текстур и звуков. Вызывается по сигналу sets_changed.
func clear_cache() -> void:
	_texture_cache.clear()
	_audio_cache.clear()


## Данные слова из пользовательского набора: пути уже с префиксом user://.
## Запись неполная (нет слова, картинки или звука) — отдаём встроенные данные
## буквы с is_custom=false. Раньше здесь был `return {}`, и любая незаполненная
## буква давала пустую карточку.
##
## is_custom обязан соответствовать реально возвращённым данным: по нему UI
## отличает родительское содержимое от встроенного, и ошибка здесь молча
## подписала бы встроенную букву как пользовательскую.
func _custom_word_data(set_id: String, key: String) -> Dictionary:
	if not CustomSetsStore.is_entry_complete(set_id, key):
		return _builtin_word_data(key)
	var entry := CustomSetsStore.get_entry(set_id, key)
	var image_rel := str(entry.get("image", ""))
	var audio_rel := str(entry.get("audio", ""))
	return {
		"word": str(entry.get("word", "")),
		"image_path": ("user://" + image_rel) if not image_rel.is_empty() else "",
		"audio_path": ("user://" + audio_rel) if not audio_rel.is_empty() else "",
		"is_custom": true,
	}


## Данные слова из встроенного набора. Слово и картинка берутся из выбранного
## набора с фолбэком на набор 1 (так же, как раньше в каждой игре).
func _builtin_word_data(key: String) -> Dictionary:
	var set_number := ProgressManager.get_word_set()
	var data := AlphabetData.get_word_data(key, set_number)
	var word := str(data.get("word", ""))
	if word.is_empty():
		word = str(AlphabetData.get_letter_data(key).get("word", ""))
	var image_name := str(data.get("image", ""))
	if image_name.is_empty():
		image_name = AlphabetData.get_fallback_image(key)
	return {
		"word": word,
		"image_path": (BUILTIN_IMAGE_DIR + image_name + ".png") if not image_name.is_empty() else "",
		"audio_path": AlphabetData.get_word_audio_path(key, set_number, ProgressManager.get_voice_variant()),
		"is_custom": false,
	}


## Звук по пути с кэшем. Пустой путь или ошибка загрузки -> null.
func _cached_audio(path: String) -> AudioStream:
	if path.is_empty():
		return null
	if _audio_cache.has(path):
		return _audio_cache[path] as AudioStream
	var stream := _load_audio(path)
	if stream == null:
		return null
	_audio_cache[path] = stream
	return stream


## Загрузка звука. res:// открывается через load(), user:// — только через
## форматозависимый load_from_file(): в веб-сборке у файлов в user:// нет
## импорта, и общий загрузчик их не видит.
func _load_audio(path: String) -> AudioStream:
	var stream: AudioStream = null
	if path.begins_with("res://"):
		stream = load(path) as AudioStream
	else:
		match path.get_extension().to_lower():
			"wav":
				stream = AudioStreamWAV.load_from_file(path)
			"ogg":
				stream = AudioStreamOggVorbis.load_from_file(path)
			"mp3":
				stream = AudioStreamMP3.load_from_file(path)
			_:
				GameLogger.warning("SetRepository", "audio_format_unsupported", {"path": path})
				return null
	if stream == null:
		GameLogger.warning("SetRepository", "audio_missing", {"path": path})
	return stream
