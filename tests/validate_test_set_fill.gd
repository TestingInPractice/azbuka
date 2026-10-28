extends Node
## Валидатор инструмента наполнения тестового набора.
##
## Проверяет: три буквы получают встроенные медиа, файлы существуют и
## декодируются, SetRepository видит записи как пользовательские, повторный
## прогон обновляет тот же набор без дубликата, а после проверки не остаётся
## ни набора, ни файлов. Пути хранилища и прогресса уводятся на тестовые, чтобы
## не тронуть данные ребёнка.
## Запуск: godot --headless --path . res://tests/validate_test_set_fill.tscn

const Filler := preload("res://tools/test_set_filler.gd")
const TEST_STORE_PATH := "user://custom_sets_fill_test.json"
const TEST_PROGRESS_PATH := "user://progress_fill_test.json"
const TEST_SET_NAME := "Набор валидатора наполнения"
const LETTERS: Array[String] = ["А", "Б", "В"]

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

	var options := {
		"name": TEST_SET_NAME, "set_id": "", "letters": LETTERS,
		"reset": false, "export_dir": "",
	}
	var filler := Filler.new()
	var first: Dictionary = filler.fill(options)
	_check(bool(first.get("ok", false)),
			"первый прогон успешен (ошибки: %s)" % _failed_text(first))
	var set_id := str(first.get("set_id", ""))
	_check(set_id.begins_with("c_"), "набор получил id вида c_ (получено: %s)" % set_id)
	_check(CustomSetsStore.get_sets().size() == 1,
			"в тестовом хранилище ровно один набор (получено: %d)"
			% CustomSetsStore.get_sets().size())
	_check(str(CustomSetsStore.get_set_by_id(set_id).get("name", "")) == TEST_SET_NAME,
			"имя набора сохранено")
	_check(PackedStringArray(first.get("requested", [])).size() == LETTERS.size(),
			"запрошены ровно три буквы (получено: %s)" % str(first.get("requested", [])))
	_check((first.get("complete", []) as Array).size() == LETTERS.size(),
			"все три буквы признаны заполненными")
	_check((first.get("failed", []) as Array).is_empty(),
			"ошибок по буквам нет (получено: %s)" % _failed_text(first))
	_check(CustomSetsStore.get_set_complete_count(set_id) == LETTERS.size(),
			"хранилище считает три полные буквы (получено: %d)"
			% CustomSetsStore.get_set_complete_count(set_id))

	var first_entries := {}
	for letter: String in LETTERS:
		var entry := CustomSetsStore.get_entry(set_id, letter)
		first_entries[letter] = entry
		_check_letter_files(set_id, letter, entry)

	# SetRepository читает активный набор, поэтому на время проверки он
	# переключается. После проверки выбор возвращается к прежнему, иначе
	# валидатор поменял бы состояние прогресса соседним тестам.
	ProgressManager.set_word_set_id(set_id)
	SetRepository.clear_cache()
	for letter: String in LETTERS:
		var data := SetRepository.get_word_data(letter)
		var entry: Dictionary = first_entries[letter]
		_check(bool(data.get("is_custom", false)),
				"SetRepository помечает букву %s пользовательской" % letter)
		_check(str(data.get("word", "")) == str(entry.get("word", "")),
				"SetRepository отдаёт слово буквы %s" % letter)
		_check(str(data.get("image_path", "")) == "user://" + str(entry.get("image", "")),
				"SetRepository отдаёт путь картинки буквы %s" % letter)
		_check(str(data.get("audio_path", "")) == "user://" + str(entry.get("audio", "")),
				"SetRepository отдаёт путь звука буквы %s" % letter)
		_check(SetRepository.get_word_texture(letter) != null,
				"SetRepository загружает картинку буквы %s" % letter)
		_check(SetRepository.get_word_audio(letter) != null,
				"SetRepository загружает звук буквы %s" % letter)

	# Повторный прогон: тот же набор, те же пути, ни одного дубликата.
	var second: Dictionary = filler.fill(options)
	_check(bool(second.get("ok", false)),
			"второй прогон успешен (ошибки: %s)" % _failed_text(second))
	_check(str(second.get("set_id", "")) == set_id,
			"второй прогон обновил тот же набор (получено: %s, ждали %s)"
			% [str(second.get("set_id", "")), set_id])
	_check(CustomSetsStore.get_sets().size() == 1,
			"после второго прогона набор по-прежнему один (получено: %d)"
			% CustomSetsStore.get_sets().size())
	for letter: String in LETTERS:
		_check(CustomSetsStore.get_entry(set_id, letter) == first_entries[letter],
				"пути буквы %s после второго прогона не изменились" % letter)

	# Уборка: набор, его каталог и тестовые файлы не должны пережить валидатор.
	_check(CustomSetsStore.delete_set(set_id), "набор удалён")
	_check(CustomSetsStore.get_set_by_id(set_id).is_empty(), "набора больше нет в хранилище")
	_check(not DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(CustomSetsStore.set_dir(set_id))),
			"каталог набора удалён вместе с файлами")
	ProgressManager.set_word_set_id(_saved_word_set_id)
	SetRepository.clear_cache()
	CustomSetsStore.clear_memory()
	CustomSetsStore.save_path = _saved_store_path
	ProgressManager.save_path = _saved_progress_path
	_remove_file(TEST_STORE_PATH)
	_remove_file(TEST_PROGRESS_PATH)
	_check(not FileAccess.file_exists(TEST_STORE_PATH), "тестовый JSON хранилища удалён")
	_check(not FileAccess.file_exists(TEST_PROGRESS_PATH), "тестовый JSON прогресса удалён")
	_remove_empty_sets_dir()

	_finish()


## Проверяет одну букву: слово, относительные пути, реальные файлы и их разбор.
func _check_letter_files(set_id: String, letter: String, entry: Dictionary) -> void:
	var expected_word := str(AlphabetData.get_word_data(letter, 1).get("word", ""))
	_check(str(entry.get("word", "")) == expected_word,
			"слово буквы %s взято из встроенного набора" % letter)
	var image_rel := str(entry.get("image", ""))
	var audio_rel := str(entry.get("audio", ""))
	_check(image_rel == "custom_sets/%s/%s" % [set_id, CustomSetsStore.image_file_name(letter)],
			"путь картинки буквы %s относительный и в каталоге набора (получено: %s)"
			% [letter, image_rel])
	_check(audio_rel == "custom_sets/%s/%s" % [set_id,
			CustomSetsStore.audio_file_name(letter, "wav")],
			"путь звука буквы %s относительный и в каталоге набора (получено: %s)"
			% [letter, audio_rel])
	_check(not image_rel.begins_with("user://") and not image_rel.begins_with("/"),
			"в метаданных буквы %s нет абсолютного пути картинки" % letter)
	_check(not audio_rel.begins_with("user://") and not audio_rel.begins_with("/"),
			"в метаданных буквы %s нет абсолютного пути звука" % letter)

	var image_abs := ProjectSettings.globalize_path("user://" + image_rel)
	var audio_abs := ProjectSettings.globalize_path("user://" + audio_rel)
	_check(FileAccess.file_exists(image_abs), "файл картинки буквы %s существует" % letter)
	_check(FileAccess.file_exists(audio_abs), "файл звука буквы %s существует" % letter)
	_check(FileAccess.get_file_as_bytes(image_abs).size() > 0,
			"файл картинки буквы %s не пустой" % letter)
	_check(FileAccess.get_file_as_bytes(audio_abs).size() > 0,
			"файл звука буквы %s не пустой" % letter)
	var image := Image.load_from_file(image_abs)
	_check(image != null and image.get_width() > 0 and image.get_height() > 0,
			"картинка буквы %s декодируется" % letter)
	_check(AudioStreamWAV.load_from_file(audio_abs) != null,
			"звук буквы %s декодируется как WAV" % letter)
	_check(bool(CustomSetsStore.is_entry_complete(set_id, letter)),
			"запись буквы %s полная по контракту хранилища" % letter)


func _failed_text(result: Dictionary) -> String:
	var parts: Array[String] = []
	for item: Dictionary in result.get("failed", []):
		parts.append("%s: %s" % [str(item.get("letter", "")), str(item.get("reason", ""))])
	return "; ".join(parts) if not parts.is_empty() else "нет"


## Удаляет пустой общий каталог наборов. Чужие наборы не трогаются: если внутри
## что-то есть, каталог остаётся на месте.
func _remove_empty_sets_dir() -> void:
	var abs_path := ProjectSettings.globalize_path(CustomSetsStore.SETS_DIR)
	var dir := DirAccess.open(abs_path)
	if dir == null:
		return
	if dir.get_files().is_empty() and dir.get_directories().is_empty():
		DirAccess.remove_absolute(abs_path)


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
