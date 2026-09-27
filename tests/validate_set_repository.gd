extends Node
## Валидатор SetRepository: единый путь чтения для встроенных и пользовательских
## наборов. Создаёт настоящие файлы картинки и звука в user://, чтобы проверить
## реальную загрузку, а не только разбор путей.
## Запуск: godot --headless --path . res://tests/validate_set_repository.tscn

const TEST_SET_PATH := "user://custom_sets_test.json"
const TEST_LETTER := "А"
const TEST_WORD := "Аист"

var failures := 0
var _saved_store_path := ""
var _saved_progress_path := ""
var _set_id := ""


func _ready() -> void:
	await get_tree().process_frame

	_saved_store_path = CustomSetsStore.save_path
	_saved_progress_path = ProgressManager.save_path
	CustomSetsStore.save_path = TEST_SET_PATH
	ProgressManager.save_path = "user://set_repository_test_progress.json"
	_remove_test_file("user://set_repository_test_progress.json")
	if FileAccess.file_exists(TEST_SET_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SET_PATH))
	CustomSetsStore.clear_memory()
	CustomSetsStore.load_sets()

	# Встроенный набор 1 работает как раньше.
	ProgressManager.set_word_set(1)
	var built_in := SetRepository.get_word_data("А")
	_check(str(built_in.get("word", "")) == "Авто́бус", "встроенный набор отдаёт слово из set 1")
	_check(bool(built_in.get("is_custom", true)) == false, "встроенный набор помечен как не пользовательский")
	_check(str(built_in.get("image_path", "")).begins_with("res://assets/images/"),
			"встроенный набор отдаёт res://-путь картинки")
	_check(SetRepository.get_word_texture("А") != null, "встроенная картинка загрузилась в Texture2D")
	_check(SetRepository.get_word_audio("А") != null, "встроенное слово озвучено")
	_check(SetRepository.get_letter_audio("А") != null, "встроенное название буквы озвучено")
	# У Ъ/Ь нет отдельного звука буквы — так же, как в LetterCard, который
	# тоже берёт путь из get_letter_sound_path() и проигрывает только название.
	# AlphabetData.get_letter_sound_path() сам отдаёт путь названия буквы,
	# когда своего фонемного звука нет (Ъ/Ь), поэтому get_letter_sound()
	# не может вернуть null: это осознанный фолбэк, а не тишина.
	_check(SetRepository.get_letter_sound("Ъ") != null, "у Ъ фолбэк на название буквы")
	_check(SetRepository.get_letter_audio("Ъ") != null, "у Ъ есть название буквы")
	_check(SetRepository.get_letter_sound("А") != null, "у А есть и звук буквы")
	_check(SetRepository.get_active_letters().size() == 33, "во встроенном наборе 33 буквы")

	# Пустая буква и буква вне набора не роняют репозиторий.
	_check(SetRepository.get_word_data("").is_empty(), "пустая буква -> пустые данные")
	_check(SetRepository.get_word_texture("") == null, "пустая буква -> нет текстуры")
	_check(SetRepository.get_word_audio("") == null, "пустая буква -> нет звука")

	# Пользовательский набор.
	var created := CustomSetsStore.create_set("Набор для теста")
	_set_id = str(created.get("id", ""))
	_check(not _set_id.is_empty(), "тестовый набор создан")
	_write_real_files(_set_id)
	_check(CustomSetsStore.set_entry(_set_id, TEST_LETTER, TEST_WORD,
			CustomSetsStore.set_dir(_set_id) + CustomSetsStore.image_file_name(TEST_LETTER),
			CustomSetsStore.set_dir(_set_id) + CustomSetsStore.audio_file_name(TEST_LETTER)),
			"запись буквы сохранена")

	ProgressManager.set_word_set_id(_set_id)
	_check(SetRepository.get_active_set_id() == _set_id, "активный набор — пользовательский")
	_check(SetRepository.is_custom_set(_set_id), "набор распознан как пользовательский")
	_check(SetRepository.is_custom_set("1") == false, "встроенный набор не пользовательский")

	var custom := SetRepository.get_word_data(TEST_LETTER)
	_check(str(custom.get("word", "")) == TEST_WORD, "пользовательское слово прочитано")
	_check(bool(custom.get("is_custom", false)) == true, "данные помечены как пользовательские")
	_check(str(custom.get("image_path", "")).begins_with("user://custom_sets/"),
			"путь картинки ведёт в user://")
	_check(str(custom.get("audio_path", "")).begins_with("user://custom_sets/"),
			"путь звука ведёт в user://")

	var tex := SetRepository.get_word_texture(TEST_LETTER)
	_check(tex != null, "картинка из user:// загрузилась")
	if tex != null:
		_check(tex.get_width() == 8 and tex.get_height() == 8, "размер загруженной картинки 8x8")
	_check(SetRepository.get_word_texture(TEST_LETTER) == tex, "текстура берётся из кэша")

	var stream := SetRepository.get_word_audio(TEST_LETTER)
	_check(stream != null, "звук из user:// загрузился")
	if stream != null:
		_check(stream is AudioStreamWAV, "загружен AudioStreamWAV")
		_check(stream.get_length() > 0.0, "у звука ненулевая длительность")

	_check(SetRepository.get_active_letters().size() == 1, "в наборе только одна буква")
	_check(SetRepository.has_letter(TEST_LETTER), "has_letter находит заполненную букву")
	_check(SetRepository.get_active_set_id() == _set_id, "выбор набора не сбился")

	# Название буквы и её звук наследуются от встроенных данных.
	_check(SetRepository.get_letter_audio(TEST_LETTER) != null,
			"название буквы наследуется из встроенных данных")
	_check(SetRepository.get_letter_sound(TEST_LETTER) != null,
			"звук буквы наследуется из встроенных данных")

	# Буквы, которой нет в пользовательском наборе, нет и в наборе.
	# Проверяем на "Ъ" — TEST_LETTER в наборе есть (см. has_letter выше).
	_check(SetRepository.get_word_data("Ъ").is_empty(), "незаполненная буква -> пустые данные")
	_check(SetRepository.get_word_texture("Ъ") == null, "незаполненная буква -> нет текстуры")
	_check(SetRepository.get_active_letters().has("Ъ") == false,
			"незаполненной буквы нет в списке букв набора")

	# Отсутствующий файл не роняет загрузку.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(
			CustomSetsStore.set_dir(_set_id) + CustomSetsStore.image_file_name(TEST_LETTER)))
	SetRepository.clear_cache()
	_check(SetRepository.get_word_texture(TEST_LETTER) == null,
			"удалённый файл картинки -> null, а не падение")

	# Удаление набора возвращает к встроенным данным.
	CustomSetsStore.delete_set(_set_id)
	ProgressManager.set_word_set(1)
	SetRepository.clear_cache()
	_check(SetRepository.is_custom_set(_set_id) == false, "удалённый набор больше не пользовательский")
	_check(str(SetRepository.get_word_data(TEST_LETTER).get("word", "")) == "Авто́бус",
			"после удаления набора вернулись встроенные данные")

	# Персистентность: набор переживает перечитывание JSON.
	var saved_id := str(CustomSetsStore.create_set("Второй").get("id", ""))
	CustomSetsStore.set_entry(saved_id, TEST_LETTER, TEST_WORD, "user://x.webp", "user://x.wav")
	CustomSetsStore.clear_memory()
	CustomSetsStore.load_sets()
	_check(str(CustomSetsStore.get_entry(saved_id, TEST_LETTER).get("word", "")) == TEST_WORD,
			"запись буквы пережила перечитывание JSON")
	CustomSetsStore.delete_set(saved_id)

	CustomSetsStore.save_path = _saved_store_path
	ProgressManager.save_path = _saved_progress_path
	_remove_test_file("user://set_repository_test_progress.json")
	if FileAccess.file_exists(TEST_SET_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SET_PATH))
	_finish()


## Кладёт настоящий WebP 8x8 и настоящий WAV в папку набора.
func _write_real_files(set_id: String) -> void:
	var dir_path := ProjectSettings.globalize_path(CustomSetsStore.set_dir(set_id))
	DirAccess.make_dir_recursive_absolute(dir_path)

	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.2, 0.7, 0.9, 1.0))
	image.save_webp(dir_path.path_join(CustomSetsStore.image_file_name(TEST_LETTER)))

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.stereo = false
	var samples := PackedByteArray()
	samples.resize(2205 * 2)
	for i in 2205:
		var val := 0
		if i < 1102:
			val = 8000
		samples[i * 2] = val & 0xFF
		samples[i * 2 + 1] = (val >> 8) & 0xFF
	wav.data = samples
	wav.save_to_wav(dir_path.path_join(CustomSetsStore.audio_file_name(TEST_LETTER)))


func _remove_test_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _check(ok: bool, msg: String) -> void:
	if ok:
		_print("OK: " + msg)
	else:
		_fail(msg)


func _fail(msg: String) -> void:
	failures += 1
	printerr("FAIL: " + msg)


func _print(msg: String) -> void:
	print("[set_repository_validate] " + msg)


func _finish() -> void:
	if failures > 0:
		printerr("FAILED: %d проверок" % failures)
		get_tree().quit(1)
	else:
		print("[set_repository_validate] PASSED: все проверки успешны")
		get_tree().quit(0)
