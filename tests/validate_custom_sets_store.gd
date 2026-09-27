extends Node
## Валидатор CustomSetsStore: CRUD, персистентность, валидация записей.
## Переопределяет save_path на тестовый, чтобы не трогать данные ребёнка.
## Запуск: godot --headless --path . res://tests/validate_custom_sets_store.tscn

const TEST_PATH := "user://custom_sets_test.json"

var failures := 0


func _ready() -> void:
	await get_tree().process_frame

	CustomSetsStore.save_path = TEST_PATH
	# Чистый старт: файл теста мог остаться от прошлого прогона.
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	CustomSetsStore.clear_memory()
	_check(CustomSetsStore.load_sets(), "load_sets() на пустом хранилище успешен")
	_check(CustomSetsStore.get_sets().is_empty(), "хранилище изначально пусто")

	# 1. Создание набора.
	var created: Dictionary = CustomSetsStore.create_set("Мой набор")
	_check(not created.is_empty(), "create_set вернул запись")
	var set_id := str(created.get("id", ""))
	_check(set_id.begins_with("c_"), "id начинается с c_ (получено: %s)" % set_id)
	_check(str(created.get("name", "")) == "Мой набор", "имя набора сохранено")
	_check((created.get("letters", {}) as Dictionary).is_empty(), "новый набор без букв")
	_check(CustomSetsStore.get_set_letter_count(set_id) == 0, "счётчик букв = 0")

	# 2. Пустое имя отклоняется.
	_check(CustomSetsStore.create_set("").is_empty(), "create_set с пустым именем отклонён")
	_check(CustomSetsStore.create_set("   ").is_empty(), "create_set с пробелами отклонён")

	# 3. Запись буквы.
	_check(CustomSetsStore.set_entry(set_id, "А", "Автобус", "custom_sets/x/img_a.webp",
			"custom_sets/x/aud_a.wav"), "set_entry сохранил запись")
	var entry: Dictionary = CustomSetsStore.get_entry(set_id, "А")
	_check(str(entry.get("word", "")) == "Автобус", "word прочитан")
	_check(str(entry.get("image", "")) == "custom_sets/x/img_a.webp", "image прочитан")
	_check(str(entry.get("audio", "")) == "custom_sets/x/aud_a.wav", "audio прочитан")
	_check(not CustomSetsStore.is_entry_complete(set_id, "Б"), "Б без записи неполная")

	# Регистр буквы нормализуется.
	CustomSetsStore.set_entry(set_id, "а", "Арбуз", "i", "a")
	_check(CustomSetsStore.get_entry(set_id, "А").get("word", "") == "Арбуз",
			"строчная буква пишет в ту же запись, что заглавная")

	# Неполная запись сохраняется: родитель печатает слово раньше, чем
	# выберет картинку, и работа не должна теряться при перезапуске.
	_check(CustomSetsStore.set_entry(set_id, "Б", "  ", "i", "a"),
			"запись без слова, но с медиа, сохранена")
	_check(str(CustomSetsStore.get_entry(set_id, "Б").get("word", "")) == "",
			"пустое слово остаётся пустым, а не записывается пробелами")
	_check(not CustomSetsStore.is_entry_complete(set_id, "Б"),
			"запись без слова неполная")
	_check(CustomSetsStore.set_entry(set_id, "В", "Волк", "", ""),
			"запись только со словом сохранена")
	_check(not CustomSetsStore.is_entry_complete(set_id, "В"),
			"слово без картинки и звука неполная")
	_check(not CustomSetsStore.set_entry(set_id, "Г", "  ", "", ""),
			"запись, где пусто всё, отклонена")
	_check(CustomSetsStore.get_entry(set_id, "Г").is_empty(),
			"отклонённая пустая запись не создана")

	# Пути нормализуются: "user://" срезается, в метаданных путь
	# относительный. Иначе вызывающий, сложивший путь через set_dir(),
	# получил бы "user://user://custom_sets/...".
	CustomSetsStore.set_entry(set_id, "Д", "Дом", "user://custom_sets/%s/img_d.webp" % set_id,
			"/custom_sets/%s/aud_d.wav" % set_id)
	var normalized := CustomSetsStore.get_entry(set_id, "Д")
	_check(str(normalized.get("image", "")) == "custom_sets/%s/img_d.webp" % set_id,
			"префикс user:// срезан (получено: %s)" % str(normalized.get("image", "")))
	_check(str(normalized.get("audio", "")) == "custom_sets/%s/aud_d.wav" % set_id,
			"ведущий слэш срезан (получено: %s)" % str(normalized.get("audio", "")))

	# 4. Неизвестные id и буквы дают пустые структуры, а не ошибки.
	_check(CustomSetsStore.get_set_by_id("nope").is_empty(), "неизвестный set_id -> {}")
	_check(CustomSetsStore.get_entry("nope", "А").is_empty(), "неизвестный набор -> {}")
	_check(CustomSetsStore.get_entry(set_id, "Ъ").is_empty(), "неизвестная буква -> {}")
	_check(CustomSetsStore.delete_set("nope") == false, "удаление несуществующего набора -> false")
	_check(CustomSetsStore.rename_set("nope", "x") == false, "переименование несуществующего -> false")

	# 5. Персистентность: перечитываем с диска. Записей А, Б, В, Д.
	_check(CustomSetsStore.get_set_letter_count(set_id) == 4, "после записи 4 буквы")
	CustomSetsStore.clear_memory()
	_check(CustomSetsStore.load_sets(), "повторный load_sets() успешен")
	_check(CustomSetsStore.get_set_by_id(set_id).get("name", "") == "Мой набор",
			"после перезагрузки имя набора сохранено")
	_check(CustomSetsStore.get_entry(set_id, "А").get("word", "") == "Арбуз",
			"после перезагрузки запись буквы сохранена")
	_check(CustomSetsStore.get_entry(set_id, "Д").get("image", "") == "custom_sets/%s/img_d.webp"
			% set_id, "после перезагрузки нормализованный путь сохранён")

	# 6. Имена файлов — ASCII.
	_check(CustomSetsStore.image_file_name("Я") == "img_ya.webp", "image_file_name(Я)")
	_check(CustomSetsStore.audio_file_name("Ъ") == "aud_q.wav", "audio_file_name(Ъ)")
	_check(CustomSetsStore.set_dir(set_id) == "user://custom_sets/%s/" % set_id,
			"set_dir для набора")

	# 6a. Расширение аудио. Загруженный mp3 обязан остаться mp3: Godot выбирает
	# загрузчик по расширению, и mp3 под именем .wav просто не откроется.
	_check(CustomSetsStore.audio_file_name("Ъ", "mp3") == "aud_q.mp3",
			"audio_file_name с mp3")
	_check(CustomSetsStore.audio_file_name("Ъ", ".M4A") == "aud_q.m4a",
			"точка и регистр в расширении нормализуются")
	_check(CustomSetsStore.audio_file_name("Ъ", "") == "aud_q.wav",
			"пустое расширение -> wav")
	_check(CustomSetsStore.extension_for_mime("audio/wav") == "wav",
			"audio/wav -> wav")
	_check(CustomSetsStore.extension_for_mime("audio/mpeg") == "mp3",
			"audio/mpeg -> mp3")
	_check(CustomSetsStore.extension_for_mime("audio/mp4") == "m4a",
			"audio/mp4 -> m4a (iPhone)")
	_check(CustomSetsStore.extension_for_mime("audio/ogg") == "ogg",
			"audio/ogg -> ogg")
	_check(CustomSetsStore.extension_for_mime("audio/wav;codec=1") == "wav",
			"mime с параметрами разбирается")
	_check(CustomSetsStore.extension_for_mime("application/pdf") == "",
			"неизвестный mime отвергнут пустой строкой")

	# 7. Набор неполный, пока не все 33 буквы заполнены.
	_check(not CustomSetsStore.is_set_complete(set_id), "набор с 4 буквами неполный")

	# 8. Сортировка букв по алфавиту. Добавляем Я, Б уже есть.
	CustomSetsStore.set_entry(set_id, "Я", "Яблоко", "i", "a")
	CustomSetsStore.set_entry(set_id, "Б", "Банан", "i", "a")
	var letters: Array[String] = CustomSetsStore.get_set_letters(set_id)
	_check(letters.size() == 5, "в наборе 5 букв (получено: %d)" % letters.size())
	_check(letters[0] == "А" and letters[1] == "Б" and letters[2] == "В"
			and letters[3] == "Д" and letters[4] == "Я",
			"буквы отсортированы по алфавиту (получено: %s)" % str(letters))

	# 9. Переименование.
	_check(CustomSetsStore.rename_set(set_id, "Другое имя"), "rename_set успешен")
	_check(CustomSetsStore.get_set_by_id(set_id).get("name", "") == "Другое имя", "новое имя")
	_check(not CustomSetsStore.rename_set(set_id, "   "), "переименование в пустое имя отклонено")

	# 10. Удаление.
	_check(CustomSetsStore.delete_set(set_id), "delete_set успешен")
	_check(CustomSetsStore.get_set_by_id(set_id).is_empty(), "набор удалён")
	_check(CustomSetsStore.get_sets().is_empty(), "хранилище снова пустое")

	# 11. Вне web хранилище считается доступным.
	_check(CustomSetsStore.is_storage_available(), "is_storage_available() вне web = true")

	# Уборка.
	CustomSetsStore.save_path = CustomSetsStore.DEFAULT_SAVE_PATH
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))

	_finish()


func _check(ok: bool, msg: String) -> void:
	if ok:
		_print("OK: " + msg)
	else:
		_fail(msg)


func _fail(msg: String) -> void:
	failures += 1
	printerr("FAIL: " + msg)


func _print(msg: String) -> void:
	print("[custom_sets_store_validate] " + msg)


func _finish() -> void:
	if failures > 0:
		printerr("FAILED: %d проверок" % failures)
		get_tree().quit(1)
	else:
		print("[custom_sets_store_validate] PASSED: все проверки успешны")
		get_tree().quit(0)
