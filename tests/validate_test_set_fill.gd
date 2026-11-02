extends Node
## Валидатор инструмента наполнения тестового набора.
##
## Проверяет главное обещание инструмента: набор получает НОВЫЕ слова, свои
## карточки и свою озвучку, а не копию встроенного набора 1. Дополнительно
## проверяются флаги (--letters, --reset, неизвестный аргумент), чтение через
## SetRepository и реальная загрузка файлов из user://.
##
## Пути хранилища и прогресса уводятся на тестовые, чтобы не тронуть данные
## ребёнка.
## Запуск: godot --headless --path . res://tests/validate_test_set_fill.tscn

const Filler := preload("res://tools/test_set_filler.gd")
const FillScript := preload("res://tools/fill_test_set.gd")
const Data := preload("res://tools/test_set_data.gd")
const Files := preload("res://tools/test_set_files.gd")

const TEST_STORE_PATH := "user://custom_sets_fill_test.json"
const TEST_PROGRESS_PATH := "user://progress_fill_test.json"
const TEST_SET_NAME := "Набор валидатора наполнения"
const SCOPED_SET_NAME := "Набор валидатора: две буквы"

const ALL_LETTERS := [
	"А", "Б", "В", "Г", "Д", "Е", "Ё", "Ж", "З", "И", "Й", "К", "Л", "М",
	"Н", "О", "П", "Р", "С", "Т", "У", "Ф", "Х", "Ц", "Ч", "Ш", "Щ", "Ъ",
	"Ы", "Ь", "Э", "Ю", "Я",
]

## Ожидаемые слова записаны здесь, а не берутся из TestSetData: валидатор,
## сверяющий модуль с самим собой, не поймал бы подмену слова в данных.
const EXPECTED := {
	"А": "Альбо́м", "Б": "Бу́блик", "В": "Ви́шня", "Г": "Гнездо́",
	"Д": "Ды́ня", "Е": "Единоро́г", "Ё": "Ё́мкость", "Ж": "Жасми́н",
	"З": "Зе́ркало", "И": "Имби́рь", "Й": "Йо́га", "К": "Коза́",
	"Л": "Ло́дка", "М": "Моро́женое", "Н": "Но́ра", "О": "О́блако",
	"П": "Помидо́р", "Р": "Ре́па", "С": "Су́мка", "Т": "Ту́ча",
	"У": "Укро́п", "Ф": "Фона́рь", "Х": "Хо́бот", "Ц": "Ци́фра",
	"Ч": "Чесно́к", "Ш": "Шмель", "Щ": "Щаве́ль", "Ъ": "Разъе́зд",
	"Ы": "Бык", "Ь": "Лось", "Э": "Эта́ж", "Ю": "Ю́нга", "Я": "Я́ма",
}

var checks := 0
var failures := 0
var _saved_store_path := ""
var _saved_progress_path := ""
var _saved_word_set_id := ""


func _ready() -> void:
	await get_tree().process_frame

	_saved_store_path = CustomSetsStore.save_path
	_saved_progress_path = ProgressManager.save_path
	_saved_word_set_id = ProgressManager.get_word_set_id()
	CustomSetsStore.save_path = TEST_STORE_PATH
	ProgressManager.save_path = TEST_PROGRESS_PATH
	_remove_file(TEST_STORE_PATH)
	_remove_file(TEST_PROGRESS_PATH)
	CustomSetsStore.clear_memory()
	CustomSetsStore.load_sets()

	# given: пустое хранилище и полный список из 33 новых слов
	_check(ALL_LETTERS.size() == 33, "алфавит валидатора содержит 33 буквы")
	_check(EXPECTED.size() == 33, "таблица ожидаемых слов содержит 33 записи")
	_check_data_matches_expected()
	_check_new_words_are_new()

	# when: заполняем весь алфавит
	var filler := Filler.new()
	var first: Dictionary = filler.fill({
		"name": TEST_SET_NAME, "set_id": "", "letters": [],
		"reset": false, "export_dir": "",
	})
	var set_id := str(first.get("set_id", ""))

	# then: все 33 буквы записаны и проверены
	_check(bool(first.get("ok", false)), "первый прогон успешен (ошибки: %s)" % _failed_text(first))
	_check(set_id.begins_with("c_"), "набор получил id вида c_ (получено: %s)" % set_id)
	_check(PackedStringArray(first.get("requested", [])).size() == 33,
			"запрошены все 33 буквы (получено: %d)"
			% PackedStringArray(first.get("requested", [])).size())
	_check((first.get("complete", []) as Array).size() == 33, "все 33 буквы заполнены")
	_check((first.get("failed", []) as Array).is_empty(), "ошибок по буквам нет")
	_check(CustomSetsStore.get_set_complete_count(set_id) == 33,
			"хранилище считает 33 полные буквы (получено: %d)"
			% CustomSetsStore.get_set_complete_count(set_id))

	# then: каждая буква получила своё слово, свою карточку и свою озвучку
	for letter: String in ALL_LETTERS:
		_check_letter(set_id, letter)

	# then: игра читает набор через SetRepository, а не напрямую из хранилища
	ProgressManager.set_word_set_id(set_id)
	SetRepository.clear_cache()
	for letter: String in ALL_LETTERS:
		var data := SetRepository.get_word_data(letter)
		var entry := CustomSetsStore.get_entry(set_id, letter)
		_check(str(data.get("word", "")) == EXPECTED[letter],
				"SetRepository отдаёт новое слово буквы %s (получено: %s)"
				% [letter, str(data.get("word", ""))])
		_check(bool(data.get("is_custom", false)),
				"SetRepository помечает букву %s пользовательской" % letter)
		_check(str(data.get("image_path", "")) == "user://" + str(entry.get("image", "")),
				"SetRepository отдаёт путь картинки буквы %s" % letter)
		_check(str(data.get("audio_path", "")) == "user://" + str(entry.get("audio", "")),
				"SetRepository отдаёт путь звука буквы %s" % letter)
		_check(SetRepository.get_word_texture(letter) != null,
				"SetRepository загружает карточку буквы %s" % letter)
		_check(SetRepository.get_word_audio(letter) != null,
				"SetRepository загружает озвучку буквы %s" % letter)

	# when: --letters=А,Б на отдельном наборе
	var scoped: Dictionary = filler.fill({
		"name": SCOPED_SET_NAME, "set_id": "", "letters": ["А", "Б"],
		"reset": false, "export_dir": "",
	})
	var scoped_id := str(scoped.get("set_id", ""))

	# then: ограничение работает, остальные буквы не тронуты
	_check(bool(scoped.get("ok", false)), "прогон --letters=А,Б успешен")
	_check(PackedStringArray(scoped.get("requested", [])) == PackedStringArray(["А", "Б"]),
			"запрошены ровно А и Б (получено: %s)" % str(scoped.get("requested", [])))
	_check(CustomSetsStore.get_set_letters(scoped_id) == _letters(["А", "Б"]),
			"в наборе только А и Б (получено: %s)"
			% str(CustomSetsStore.get_set_letters(scoped_id)))
	_check(CustomSetsStore.get_sets().size() == 2, "полный и урезанный наборы сосуществуют")

	# when: --reset на урезанном наборе
	var reset: Dictionary = filler.fill({
		"name": SCOPED_SET_NAME, "set_id": "", "letters": ["В"],
		"reset": true, "export_dir": "",
	})
	var reset_id := str(reset.get("set_id", ""))

	# then: буквы заменены, а id и имя набора сохранены — на id ссылается прогресс
	_check(bool(reset.get("ok", false)), "прогон --reset успешен")
	_check(reset_id == scoped_id, "reset сохранил id набора (было %s, стало %s)"
			% [scoped_id, reset_id])
	_check(not CustomSetsStore.get_set_by_id(scoped_id).is_empty(), "набор после reset на месте")
	_check(str(CustomSetsStore.get_set_by_id(scoped_id).get("name", "")) == SCOPED_SET_NAME,
			"reset сохранил имя набора")
	_check(CustomSetsStore.get_set_letters(reset_id) == _letters(["В"]),
			"после reset в наборе только В (получено: %s)"
			% str(CustomSetsStore.get_set_letters(reset_id)))
	_check(CustomSetsStore.get_sets().size() == 2, "после reset наборов по-прежнему два")
	_check(_letter_files_gone(scoped_id, ["А", "Б"]), "reset удалил файлы прежних букв")

	# then: разбор аргументов не ослаблен
	var valid := FillScript.parse_args(PackedStringArray([
		"--name=Проверка", "--set-id=c_abcdef", "--letters=А,Б", "--reset",
		"--export-dir=/tmp/azbuka-export",
	]))
	_check(bool(valid.get("ok", false)), "известные флаги разбираются")
	_check(str(valid.get("name", "")) == "Проверка", "флаг --name доходит до options")
	_check(PackedStringArray(valid.get("letters", [])) == PackedStringArray(["А", "Б"]),
			"флаг --letters доходит до options")
	_check(bool(valid.get("reset", false)), "флаг --reset доходит до options")
	_check(_is_argument_error("--bogus"), "неизвестный флаг это ошибка аргументов")
	_check(_is_argument_error("--word-set=2"), "флага --word-set нет и он отвергается")

	_cleanup()


## Проверяет одну букву: слово, пути, файлы, байты и реальное чтение.
func _check_letter(set_id: String, letter: String) -> void:
	var expected := str(EXPECTED[letter])
	var entry := CustomSetsStore.get_entry(set_id, letter)
	_check(str(entry.get("word", "")) == expected,
			"слово буквы %s новое (получено: %s)" % [letter, str(entry.get("word", ""))])
	_check(bool(CustomSetsStore.is_entry_complete(set_id, letter)),
			"запись буквы %s полная" % letter)

	var image_rel := str(entry.get("image", ""))
	var audio_rel := str(entry.get("audio", ""))
	_check(image_rel == "custom_sets/%s/%s" % [set_id, CustomSetsStore.image_file_name(letter)],
			"путь картинки буквы %s относительный и в каталоге набора" % letter)
	_check(audio_rel == "custom_sets/%s/%s" % [set_id,
			CustomSetsStore.audio_file_name(letter, "wav")],
			"путь звука буквы %s относительный и в каталоге набора" % letter)
	_check(not image_rel.begins_with("user://") and not image_rel.begins_with("/"),
			"в метаданных буквы %s нет абсолютного пути картинки" % letter)
	_check(not audio_rel.begins_with("user://") and not audio_rel.begins_with("/"),
			"в метаданных буквы %s нет абсолютного пути звука" % letter)

	var image_abs := ProjectSettings.globalize_path("user://" + image_rel)
	var audio_abs := ProjectSettings.globalize_path("user://" + audio_rel)
	var image_bytes := FileAccess.get_file_as_bytes(image_abs)
	var audio_bytes := FileAccess.get_file_as_bytes(audio_abs)
	_check(image_bytes.size() > 0, "картинка буквы %s не пустая" % letter)
	_check(audio_bytes == FileAccess.get_file_as_bytes(Data.audio_path(letter)),
			"звук буквы %s совпадает с фикстурой байт в байт" % letter)

	# then: картинка не совпадает ни с одной из пяти встроенных
	var fixture_bytes := FileAccess.get_file_as_bytes(Data.image_path(letter))
	for set_number in range(1, 6):
		var bundled := _bundled_image_bytes(letter, set_number)
		_check(not bundled.is_empty(), "встроенная картинка буквы %s набора %d читается"
				% [letter, set_number])
		_check(image_bytes != bundled,
				"картинка буквы %s набора отличается от встроенного набора %d"
				% [letter, set_number])
		_check(fixture_bytes != bundled,
				"фикстура буквы %s отличается от встроенного набора %d" % [letter, set_number])

	var image := Image.load_from_file(image_abs)
	_check(image != null and image.get_width() > 0 and image.get_height() > 0,
			"картинка буквы %s декодируется" % letter)
	var audio := AudioStreamWAV.load_from_file(audio_abs)
	_check(audio != null, "звук буквы %s декодируется как WAV" % letter)
	_check(audio != null and audio.get_length() > 0.2,
			"звук буквы %s длиннее 0.2 с (получено: %.2f)"
			% [letter, audio.get_length() if audio != null else 0.0])


## Слова из TestSetData совпадают с таблицей валидатора.
func _check_data_matches_expected() -> void:
	for letter: String in ALL_LETTERS:
		_check(Data.get_word(letter) == EXPECTED[letter],
				"TestSetData отдаёт слово буквы %s (получено: %s)"
				% [letter, Data.get_word(letter)])
		_check(FileAccess.file_exists(Data.image_path(letter)),
				"фикстура картинки буквы %s существует" % letter)
		_check(FileAccess.file_exists(Data.audio_path(letter)),
				"фикстура звука буквы %s существует" % letter)


## Новые слова не встречаются ни в одном из пяти встроенных наборов и не
## повторяются между собой.
func _check_new_words_are_new() -> void:
	var bundled: Dictionary = {}
	for letter: String in ALL_LETTERS:
		for set_number in range(1, 6):
			bundled[_normalize(str(AlphabetData.get_word_data(letter, set_number).get("word", "")))] = true
	var seen: Dictionary = {}
	for letter: String in ALL_LETTERS:
		var word := _normalize(str(EXPECTED[letter]))
		_check(not bundled.has(word),
				"слово %s буквы %s не встречается во встроенных наборах" % [word, letter])
		_check(not seen.has(word), "слово %s буквы %s уникально внутри набора" % [word, letter])
		seen[word] = true


## Картинка буквы из встроенного набора: имя файла берётся из alphabet_data.json.
func _bundled_image_bytes(letter: String, set_number: int) -> PackedByteArray:
	var name := str(AlphabetData.get_word_data(letter, set_number).get("image", ""))
	if name.is_empty():
		name = AlphabetData.get_fallback_image(letter)
	var path := SetRepository.BUILTIN_IMAGE_DIR + name + ".png"
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	return FileAccess.get_file_as_bytes(path)


## Убирает ударение и регистр: сравнивать слова нужно по смыслу, а не по
## разметке TTS.
func _normalize(word: String) -> String:
	return word.replace("\u0301", "").to_lower()


func _letters(values: Array) -> Array[String]:
	var out: Array[String] = []
	for value: Variant in values:
		out.append(str(value))
	return out


func _is_argument_error(flag: String) -> bool:
	var parsed := FillScript.parse_args(PackedStringArray([flag]))
	return not bool(parsed.get("ok", false)) \
			and str(parsed.get("error", "")).contains("неизвестный аргумент")


func _failed_text(result: Dictionary) -> String:
	var parts: Array[String] = []
	for item: Dictionary in result.get("failed", []):
		parts.append("%s: %s" % [str(item.get("letter", "")), str(item.get("reason", ""))])
	return "; ".join(parts) if not parts.is_empty() else "нет"


## Удаляет созданные валидатором наборы, возвращает пути и чистит тестовые
## файлы. Чужие наборы в общем каталоге не трогаются.
func _cleanup() -> void:
	for record: Dictionary in CustomSetsStore.get_sets():
		CustomSetsStore.delete_set(str(record.get("id", "")))
	ProgressManager.set_word_set_id(_saved_word_set_id)
	SetRepository.clear_cache()
	CustomSetsStore.clear_memory()
	CustomSetsStore.save_path = _saved_store_path
	ProgressManager.save_path = _saved_progress_path
	_remove_file(TEST_STORE_PATH)
	_remove_file(TEST_PROGRESS_PATH)
	_check(CustomSetsStore.get_sets().is_empty(), "тестовое хранилище пусто после уборки")
	_check(not FileAccess.file_exists(TEST_STORE_PATH), "тестовый JSON хранилища удалён")
	_check(not FileAccess.file_exists(TEST_PROGRESS_PATH), "тестовый JSON прогресса удалён")
	_remove_empty_sets_dir()
	_finish()


## Удаляет пустой общий каталог наборов. Если внутри что-то осталось, каталог
## не трогается.
func _remove_empty_sets_dir() -> void:
	var abs_path := ProjectSettings.globalize_path(CustomSetsStore.SETS_DIR)
	var dir := DirAccess.open(abs_path)
	if dir == null:
		return
	if dir.get_files().is_empty() and dir.get_directories().is_empty():
		DirAccess.remove_absolute(abs_path)


## После очистки файлы прежних букв не остаются: иначе папка набора копит мусор.
func _letter_files_gone(set_id: String, letters: Array) -> bool:
	for letter: String in letters:
		var dir := CustomSetsStore.set_dir(set_id)
		var image_path := ProjectSettings.globalize_path(
				dir + CustomSetsStore.image_file_name(letter))
		var audio_path := ProjectSettings.globalize_path(
				dir + CustomSetsStore.audio_file_name(letter))
		if FileAccess.file_exists(image_path) or FileAccess.file_exists(audio_path):
			return false
	return true


func _remove_file(path: String) -> void:
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(abs_path):
		DirAccess.remove_absolute(abs_path)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("[test_set_fill_validate] OK: " + message)
	else:
		failures += 1
		printerr("[test_set_fill_validate] FAIL: " + message)


func _finish() -> void:
	if failures > 0:
		printerr("[test_set_fill_validate] FAILED: %d из %d проверок" % [failures, checks])
		get_tree().quit(1)
	else:
		print("[test_set_fill_validate] PASSED: %d проверок" % checks)
		get_tree().quit(0)
