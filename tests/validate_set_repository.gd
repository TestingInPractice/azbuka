extends Node
## Валидатор SetRepository: единый путь чтения для встроенных и пользовательских
## наборов. Создаёт настоящие файлы картинки и звука в user://, чтобы проверить
## реальную загрузку, а не только разбор путей.
## Запуск: godot --headless --path . res://tests/validate_set_repository.tscn

const TEST_SET_PATH := "user://custom_sets_test.json"
const TEST_LETTER := "А"
const TEST_WORD := "Аист"

## Алфавит для обхода всех 33 букв. Держим рядом с проверкой, а не берём из
## production-кода: если сам SetRepository начнёт отдавать неполный алфавит,
## валидатор, считающий по нему же, этого не заметит.
const ALL_LETTERS := [
	"А", "Б", "В", "Г", "Д", "Е", "Ё", "Ж", "З", "И", "Й", "К", "Л", "М",
	"Н", "О", "П", "Р", "С", "Т", "У", "Ф", "Х", "Ц", "Ч", "Ш", "Щ", "Ъ",
	"Ы", "Ь", "Э", "Ю", "Я",
]

var failures := 0
## Счётчик выполненных проверок: страховка от ложного «всё прошло» (урок Task 5
## — валидатор печатал PASSED при нуле выполненных assert'ов).
var checks := 0
var _saved_store_path := ""
var _saved_progress_path := ""
var _set_id := ""


func _ready() -> void:
	await get_tree().process_frame

	# Страховка от ложного «всё прошло»: без неё счётчик остался бы нулевым и
	# валидатор завершился бы с exit 0, не проверив ничего.
	if not _class_loaded():
		_finish()
		return

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

	# Буквы, которой нет в пользовательском наборе. Раньше здесь стояло
	# «пустые данные» и «нет текстуры» — то есть проверка ЗАКРЕПЛЯЛА баг:
	# игра листает все 33 буквы (LetterCard.LETTERS), и пустой словарь рисовал
	# пустую карточку. Теперь контракт обратный: незаполненная буква ведёт себя
	# как при выборе встроенного набора.
	#
	# Отличие от кода из плана: утверждение переписано, а не смягчено. Проверки
	# на is_custom=false и на встроенный путь картинки — по всем 33 буквам —
	# добавлены ниже в _check_fallback_for_all_letters(); здесь остаётся то же
	# самое на конкретной букве «Ъ», чтобы починка не уехала в 33 отдельные
	# теста и не исчезла из них вовсе.
	var hard_sign := SetRepository.get_word_data("Ъ")
	_check(bool(hard_sign.get("is_custom", true)) == false,
			"незаполненная буква Ъ помечена is_custom=false")
	_check(not str(hard_sign.get("word", "")).is_empty(),
			"незаполненная буква Ъ отдаёт встроенное слово")
	_check(SetRepository.get_word_texture("Ъ") != null,
			"незаполненная буква Ъ грузит встроенную текстуру")
	_check(SetRepository.get_active_letters().has("Ъ") == false,
			"незаполненной буквы нет в списке букв набора")

	# DEFECT 1. Частичный набор: родитель заполнил 5 из 33 букв, а игра
	# обязана показать все 33. Незаполненная буква возвращает пустой словарь
	# и рисует пустую карточку.
	#
	# Правило выбрано целиком на букву, а не на поле: неполная запись целиком
	# уходит на встроенные данные. Иначе собственное слово родителя встало бы
	# рядом с чужой картинкой — карточка «Бегемот» с картинкой банана хуже,
	# чем честная встроенная «Б». Проверка на Б (слово есть, медиа нет)
	# ловит именно это смешение.
	#
	# Отличие от кода из плана: ниже добавлен _check_fallback_for_all_letters(),
	# который обходит все 33 буквы. Поштучные проверки провалились бы на
	# паре Е/Э — они схлопываются на одном имени файла (урок Task 1).
	var partial_id := str(CustomSetsStore.create_set("Частичный набор").get("id", ""))
	_write_real_files(partial_id)
	CustomSetsStore.set_entry(partial_id, "А", "Аист",
			CustomSetsStore.set_dir(partial_id) + CustomSetsStore.image_file_name("А"),
			CustomSetsStore.set_dir(partial_id) + CustomSetsStore.audio_file_name("А"))
	CustomSetsStore.set_entry(partial_id, "Б", "Бегемот", "", "")
	_check(CustomSetsStore.is_entry_complete(partial_id, "А"),
			"частичный набор: А заполнена целиком")
	_check(CustomSetsStore.is_entry_complete(partial_id, "Б") == false,
			"частичный набор: Б записана без медиа, то есть неполна")
	ProgressManager.set_word_set_id(partial_id)
	SetRepository.clear_cache()

	# Полная запись отдаётся как есть.
	var custom_a := SetRepository.get_word_data("А")
	_check(bool(custom_a.get("is_custom", false)) == true,
			"полная пользовательская запись помечена is_custom=true")
	_check(str(custom_a.get("word", "")) == "Аист",
			"полная пользовательская запись отдаёт слово родителя")
	_check(str(custom_a.get("image_path", "")).begins_with("user://custom_sets/"),
			"полная пользовательская запись отдаёт путь из user://")

	# Неполная запись уходит на встроенные данные ЦЕЛИКОМ.
	var builtin_b := SetRepository.get_word_data("Б")
	_check(bool(builtin_b.get("is_custom", true)) == false,
			"неполная запись помечена is_custom=false, а не true")
	_check(str(builtin_b.get("word", "")) != "Бегемот",
			"неполная запись не подставляет слово родителя (получено: %s)"
			% str(builtin_b.get("word", "")))
	_check(str(builtin_b.get("image_path", "")).begins_with("res://assets/images/"),
			"неполная запись получает встроенную картинку, а не картинку родителя")
	_check(SetRepository.get_word_texture("Б") != null,
			"неполная запись: текстура грузится, карточка не пустая")
	_check(SetRepository.get_word_audio("Б") != null,
			"неполная запись: звук слова грузится")
	_check(SetRepository.get_letter_audio("Б") != null,
			"неполная запись: название буквы доступно")
	_check(SetRepository.get_letter_sound("Б") != null,
			"неполная запись: фонема буквы доступна")

	_check_fallback_for_all_letters(partial_id)

	# Встроенный набор после всего этого обязан вести себя как раньше.
	ProgressManager.set_word_set(1)
	SetRepository.clear_cache()
	var builtin_a := SetRepository.get_word_data("А")
	_check(str(builtin_a.get("word", "")) == "Авто́бус",
			"встроенный набор не затронут откатом")
	_check(bool(builtin_a.get("is_custom", true)) == false,
			"встроенный набор по-прежнему is_custom=false")
	CustomSetsStore.delete_set(partial_id)
	# Возвращаем выбор на исходный пользовательский набор: дальше идут
	# проверки удалённого файла, и они смотрят именно его картинку.
	ProgressManager.set_word_set_id(_set_id)
	SetRepository.clear_cache()

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


## Обход ВСЕХ 33 букв на частичном наборе. Не выборка: урок Task 1 — Е и Э
## схлопывались на одном имени файла, и поштучная проверка была зелёной.
## Проверяем весь набор целиком и собираем нарушения списком, а не падаем на
## первом: один прогон должен показать масштаб, а не одну букву.
func _check_fallback_for_all_letters(partial_id: String) -> void:
	var no_word: Array[String] = []
	var bad_flag: Array[String] = []
	var bad_image: Array[String] = []
	var no_texture: Array[String] = []
	var no_word_audio: Array[String] = []
	var no_letter_audio: Array[String] = []
	var no_letter_sound: Array[String] = []
	var same_as_parent: Array[String] = []
	var builtin_mismatch: Array[String] = []
	for letter: String in ALL_LETTERS:
		if CustomSetsStore.is_entry_complete(partial_id, letter):
			continue
		var data := SetRepository.get_word_data(letter)
		if str(data.get("word", "")).strip_edges().is_empty():
			no_word.append(letter)
		if bool(data.get("is_custom", true)):
			bad_flag.append(letter)
		if not str(data.get("image_path", "")).begins_with(SetRepository.BUILTIN_IMAGE_DIR):
			bad_image.append(letter)
		if SetRepository.get_word_texture(letter) == null:
			no_texture.append(letter)
		if SetRepository.get_word_audio(letter) == null:
			no_word_audio.append(letter)
		if SetRepository.get_letter_audio(letter) == null:
			no_letter_audio.append(letter)
		if SetRepository.get_letter_sound(letter) == null:
			no_letter_sound.append(letter)
		# Слово не должно совпадать с тем, что родитель написал в Б: подмена
		# чужого слова собственным означала бы смешение полей.
		if str(data.get("word", "")) == "Бегемот":
			same_as_parent.append(letter)
		# Откат обязан быть ПОБАЙТОВО тем же, что встроенный набор 1.
		var expected := _builtin_reference(letter)
		if str(data.get("word", "")) != str(expected.get("word", "")) \
				or str(data.get("image_path", "")) != str(expected.get("image_path", "")) \
				or str(data.get("audio_path", "")) != str(expected.get("audio_path", "")) \
				or bool(data.get("is_custom", true)) != bool(expected.get("is_custom", true)):
			builtin_mismatch.append(letter)

	_check(ALL_LETTERS.size() == 33, "в тестовом алфавите 33 буквы (получено: %d)"
			% ALL_LETTERS.size())
	_check(no_word.is_empty(), "у всех незаполненных букв есть слово (нет: %s)" % str(no_word))
	_check(bad_flag.is_empty(),
			"у всех незаполненных букв is_custom=false (нарушено: %s)" % str(bad_flag))
	_check(bad_image.is_empty(),
			"у всех незаполненных букв встроенный путь картинки (нарушено: %s)" % str(bad_image))
	_check(no_texture.is_empty(),
			"текстура грузится для всех незаполненных букв (нет: %s)" % str(no_texture))
	_check(no_word_audio.is_empty(),
			"звук слова есть для всех незаполненных букв (нет: %s)" % str(no_word_audio))
	_check(no_letter_audio.is_empty(),
			"название буквы есть для всех незаполненных букв (нет: %s)" % str(no_letter_audio))
	_check(no_letter_sound.is_empty(),
			"фонема буквы есть для всех незаполненных букв (нет: %s)" % str(no_letter_sound))
	_check(same_as_parent.is_empty(),
			"слово родителя не подставляется в другие буквы (подставлено: %s)" % str(same_as_parent))
	_check(builtin_mismatch.is_empty(),
			"откат совпадает со встроенным набором 1 побайтово (расхождений: %s)"
			% str(builtin_mismatch))
	# Инвариант уровня множества: откат обязан дать 33 РАЗНЫХ картинок.
	# Проверка на отсутствие букв, а не на равенство счётчиков, ловит и
	# схлопывание (Е/Э), и молчаливую подмену всех букв одной.
	var images := {}
	for letter: String in ALL_LETTERS:
		images[str(SetRepository.get_word_data(letter).get("image_path", ""))] = letter
	_check(images.size() == 33,
			"у 33 букв 33 разных картинок (получено: %d)" % images.size())
	_print("fallback для всех 33 букв: OK")


## Эталонные встроенные данные буквы: тот же путь, но без пользовательского
## набора. Считается переключением на встроенный набор 1 и обратно.
func _builtin_reference(letter: String) -> Dictionary:
	var saved_custom := ProgressManager.get_word_set_id()
	var saved_number := ProgressManager.get_word_set()
	ProgressManager.set_word_set(1)
	var reference := SetRepository.get_word_data(letter)
	ProgressManager.set_word_set(saved_number)
	ProgressManager.set_word_set_id(saved_custom)
	return reference


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
	checks += 1
	if ok:
		_print("OK: " + msg)
	else:
		_fail(msg)


## Публичный контракт SetRepository, на который опираются все четыре игры.
## Проверяется по списку методов, а не по факту вызова: вызов упал бы на
## первой строке и тихо оставил бы счётчик на нуле.
##
## SetRepository — автолоад, а не class_name, поэтому контракт смотрим у узла
## /root/SetRepository через get_script(): приведение самого автолоада к Script
## не проходит (Invalid cast), а get_script() даёт тот же список методов.
func _class_loaded() -> bool:
	var required := [
		"get_active_set_id", "is_custom_set", "get_word_data", "get_word_texture",
		"get_word_audio", "get_letter_audio", "get_letter_sound",
		"get_active_letters", "has_letter", "clear_cache",
	]
	var node := get_tree().root.get_node_or_null("SetRepository")
	if node == null:
		_fail("автолоад SetRepository не зарегистрирован")
		return false
	var script: Script = node.get_script()
	if script == null:
		_fail("у SetRepository нет скрипта")
		return false
	var methods := {}
	for method: Dictionary in script.get_script_method_list():
		methods[method.get("name", "")] = true
	var ok := true
	for method_name: String in required:
		if not methods.has(method_name):
			_fail("у SetRepository нет метода %s" % method_name)
			ok = false
	return ok


func _fail(msg: String) -> void:
	failures += 1
	printerr("FAIL: " + msg)


func _print(msg: String) -> void:
	print("[set_repository_validate] " + msg)


func _finish() -> void:
	if checks == 0:
		printerr("FAILED: не выполнено ни одной проверки — валидатор не отработал")
		get_tree().quit(1)
		return
	if failures > 0:
		printerr("FAILED: %d проверок" % failures)
		get_tree().quit(1)
	else:
		print("[set_repository_validate] PASSED: %d проверок успешны" % checks)
		get_tree().quit(0)
