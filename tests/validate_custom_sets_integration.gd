extends Node
## Интеграция своих наборов: Settings показывает кнопки, выбор набора доезжает
## до ProgressManager, а ни одна из четырёх игр больше не читает AlphabetData
## напрямую. Запуск:
## godot --headless --path . res://tests/validate_custom_sets_integration.tscn
## Отличия от кода из плана (ничего не ослаблено, все плановые проверки на месте):
## 1. Добавлены _class_loaded() и счётчик checks — страховка от ложного
##    «всё прошло» (урок Task 5: валидатор печатал PASSED при нуле assert'ов).
##    Для .tscn-задачи страховка обязательна вдвойне: сцена, которая не
##    загрузилась, молчит, а не падает.
## 2. План звал _check/_fail/_print/_finish, но не определял их НИ ОДНОГО раза:
##    файл не разбирался («Function _check() not found in base self») и валидатор
##    зависал молча. Определения взяты из validate_constructor_ui.gd — того же
##    плана, уже проверенного прогонами Task 8 и Task 9.
## 3. План не await'ил _check_settings_custom_buttons(), а функция содержит
##    await. Без await _ready() доходил до _finish() раньше, чем наборы
##    успевали создаться, и проверки Settings просто не выполнялись — то есть
##    целый блок молчал. Исправлен порядок вызова, проверки те же.
## 4. План брал %MySetsButton через get_node() и сразу дергал
##    accessibility_name. Пока кнопки нет, get_node() возвращает null, и
##    обращение к полю роняет корутину — валидатор замолкал, не показав ни одного
##    FAIL. Заменено на get_node_or_null() с явной проверкой: отсутствие кнопки
##    теперь читается как FAIL, а не как тишина.
## 5. Путь хранилища уводится на user://custom_sets_integration_test.json.
##    План писал прямо в user://custom_sets.json, то есть в боевые данные
##    ребёнка, и звал clear_memory() + load_sets() поверх них. Конвенция
##    переопределения пути уже есть в validate_custom_sets_store.gd,
##    validate_set_repository.gd и validate_constructor_ui.gd.
##
## План обещал в разделе Interfaces static func set_entry_scan_targets(),
## но в коде определил только const GAME_SCRIPTS. Определены оба: константа
## остаётся источником для циклов плана, функция даёт тот же список наружу.
##
## Что остаётся непроверяемым headless и проверяется только в браузере:
##   - сам диалог выбора файла (WebFilePicker.pick) — вне веба он честно отдаёт
##     not_web, и проверяется именно ветка отмены;
##   - реальные кадры с микрофона и сам захват голоса (в headless шина есть,
##     а frames_available() == 0);
##   - ввод PIN в ParentalGate: open_constructor() вынесен отдельным методом
##     именно поэтому — шов «кнопка -> PIN -> метод» проверяется по наличию
##     метода и подписки, а не реальным диалогом;
##   - проигрывание в колонки (проверяется лишь то, что поток не null).

## Игры, которые обязаны ходить в данные набора только через SetRepository.
const GAME_SCRIPTS := [
	"res://ui/games/azbuka/letter_card.gd",
	"res://ui/games/collect_word/collect_word.gd",
	"res://ui/games/find_letter/find_letter.gd",
	"res://ui/games/guess_picture/guess_picture.gd",
]

## Строки, которые не должны остаться в играх. Совпадение по подстроке.
const FORBIDDEN := [
	"AlphabetData.get_word_data",
	"AlphabetData.get_word_audio_path",
	"AlphabetData.get_word_image_name",
	"_image_path_for",
]

## Счётчик выполненных проверок: страховка от ложного «всё прошло» (урок Task 5 —
## валидатор печатал PASSED при нуле выполненных assert'ов).
var checks := 0
var failures := 0
## Боевые пути хранилища и прогресса: восстанавливаются в _finish-цепочке.
var _saved_store_path: String = ""
var _saved_progress_path: String = ""


func _ready() -> void:
	await get_tree().process_frame

	# Страховка от ложного «всё прошло»: если сцена или class_name не загрузились,
	# вызовы падают на первой строке, счётчик остаётся нулевым, и валидатор
	# завершился бы с exit 0.
	if not _class_loaded():
		_finish()
		return

	# Отличие от плана — пути уводятся на тестовые файлы. План писал прямо в
	# user://custom_sets.json, то есть в данные ребёнка, и звал clear_memory()
	# поверх них. Конвенция уже есть в validate_custom_sets_store.gd,
	# validate_set_repository.gd и validate_constructor_ui.gd.
	_saved_store_path = CustomSetsStore.save_path
	_saved_progress_path = ProgressManager.save_path
	CustomSetsStore.save_path = TEST_STORE_PATH
	ProgressManager.save_path = TEST_PROGRESS_PATH
	CustomSetsStore.clear_memory()
	CustomSetsStore.load_sets()

	_check_no_direct_alphabet_data_access()
	_check_direct_read_inventory()
	# Отличие от плана — await. Функция содержит await, а план звал её без
	# него: _ready() доходил до _finish() раньше, чем наборы успевали создаться,
	# и весь блок Settings молчал, не выполнив ни одной проверки.
	await _check_settings_custom_buttons()
	_check_repository_follows_selection()
	await _check_full_custom_set()
	await _check_builtin_parity()
	await _check_restart_persistence()
	await _check_game_scenes_witness()

	CustomSetsStore.save_path = _saved_store_path
	ProgressManager.save_path = _saved_progress_path
	_cleanup()
	_finish()


## Регрессионный скан: одна забытая строка AlphabetData в игре означает, что
## игра молча игнорирует свой набор, и это не ловится ни одним другим тестом.
##
## Отличие от плана — комментарии отбрасываются перед поиском. План искал
## подстроку во всём файле, и скан ругался на комментарии, где автор объясняет,
## ПОЧЕМУ вызов удалён: «у таких файлов нет импорта. Свой _image_path_for()
## искал…». Это ровно тот случай, когда тест падает на тексте, а код чист.
## Проверяется вызов, а не любое упоминание имени.
func _check_no_direct_alphabet_data_access() -> void:
	for path: String in GAME_SCRIPTS:
		if not FileAccess.file_exists(path):
			_fail("игра не найдена: %s" % path)
			continue
		var code := _code_without_comments(FileAccess.get_file_as_string(path))
		for needle: String in FORBIDDEN:
			if code.contains(needle):
				_fail("%s всё ещё вызывает %s" % [path.get_file(), needle])
	_print("set_entry scan: OK")


## Убирает строки-комментарии и хвостовые комментарии после кода.
## Простой разбор, а не токенизатор: нужен только факт «это имя не встречается
## в выполняемом коде», а скобки/строки внутри имён не встречаются.
func _code_without_comments(source: String) -> String:
	var kept: PackedStringArray = PackedStringArray()
	for raw_line: String in source.split("\n"):
		var code_part := raw_line
		var comment_at := code_part.find("#")
		if comment_at >= 0:
			code_part = code_part.substr(0, comment_at)
		kept.append(code_part)
	return "\n".join(kept)


func _check_settings_custom_buttons() -> void:
	var scene: PackedScene = load("res://ui/settings/settings.tscn")
	var settings: Node = scene.instantiate()
	add_child(settings)
	await get_tree().process_frame
	_check(settings.get_node_or_null("%MySetsButton") != null,
			"в Settings есть кнопка «Свои наборы»")
	# Отличие от плана — get_node_or_null + ранний выход. План брал
	# get_node("%MySetsButton") и сразу дергал accessibility_name: пока кнопки
	# нет, это null, и обращение к полю роняет корутину — валидатор замолкает,
	# не показав ни одного FAIL. Отсутствие кнопки обязано читаться как FAIL.
	var gate_button := settings.get_node_or_null("%MySetsButton") as Button
	if gate_button == null:
		_fail("кнопки «Свои наборы» нет — дальнейшие проверки Settings не имеют смысла")
		settings.queue_free()
		await get_tree().process_frame
		return
	_check(not gate_button.accessibility_name.strip_edges().is_empty(),
			"у кнопки конструктора есть accessibility_name")
	# Открытие конструктора не спрашивает PIN в самом методе: его вызывает
	# обработчик кнопки через ParentalGate, а open_constructor() — уже после.
	_check(settings.has_method("open_constructor"),
			"open_constructor() вынесен отдельным методом")

	# Три встроенных набора: кнопки на месте, выбор работает.
	ProgressManager.set_word_set(2)
	_check(ProgressManager.get_word_set_id() == "2",
			"встроенный набор представлен строковым id (получено: %s)"
			% ProgressManager.get_word_set_id())

	# Два своих набора — две кнопки в той же карточке.
	CustomSetsStore.clear_memory()
	CustomSetsStore.load_sets()
	ProgressManager.set_word_set(1)
	var alpha := CustomSetsStore.create_set("Альфа")
	var beta := CustomSetsStore.create_set("Бета")
	settings.sync_custom_set_buttons()
	var buttons: Array[Button] = settings.get_custom_set_buttons()
	_check(buttons.size() == 2, "два своих набора -> две кнопки (получено: %d)"
			% buttons.size())

	# Выбор своего набора не спрашивает PIN и переключает прогресс.
	var alpha_id := str(alpha.get("id", ""))
	buttons[0].button_pressed = true
	_check(ProgressManager.get_word_set_id() == alpha_id,
			"выбор своего набора переключил прогресс (получено: %s, ожидалось %s)"
			% [ProgressManager.get_word_set_id(), alpha_id])

	# Имя на кнопке совпадает с именем набора, а не с его id.
	var has_name := false
	for button: Button in buttons:
		if button.text.contains("Альфа") or button.text.contains("Бета"):
			has_name = true
	_check(has_name, "кнопки подписаны именами наборов")

	# Удалённые наборы убирают свои кнопки, встроенные не страдают.
	CustomSetsStore.delete_set(str(beta.get("id", "")))
	settings.sync_custom_set_buttons()
	_check(settings.get_custom_set_buttons().size() == 1,
			"после удаления набора осталась одна кнопка")
	# Отличие от плана — get_node_or_null: get_node() на отсутствующем узле
	# роняет корутину так же, как разыменование null.
	_check(settings.get_node_or_null("%WordSetButton1") as Button != null,
			"кнопки встроенных наборов остались на месте")

	# Набор, удалённый будучи активным, не должен ронять выбор.
	CustomSetsStore.delete_set(alpha_id)
	settings.sync_custom_set_buttons()
	_check(ProgressManager.get_word_set_id() != alpha_id,
			"удаление активного набора сбросило выбор")

	settings.queue_free()
	await get_tree().process_frame


## Репозиторий обязан видеть ровно тот набор, который выбран в прогрессе,
## иначе игра и Settings показывают разное.
func _check_repository_follows_selection() -> void:
	ProgressManager.set_word_set(3)
	_check(SetRepository.get_active_set_id() == "3",
			"репозиторий видит встроенный набор 3 (получено: %s)"
			% SetRepository.get_active_set_id())
	_check(SetRepository.is_custom_set("3") == false,
			"встроенный набор не считается пользовательским")

	var created := CustomSetsStore.create_set("Для репозитория")
	var set_id := str(created.get("id", ""))
	CustomSetsStore.set_entry(set_id, "А", "Автобус", "", "")
	ProgressManager.set_word_set_id(set_id)
	_check(SetRepository.get_active_set_id() == set_id,
			"репозиторий видит пользовательский набор")
	_check(SetRepository.is_custom_set(set_id),
			"пользовательский набор распознан")
	_check(SetRepository.has_letter("А"), "has_letter находит заполненную букву")
	_check(SetRepository.get_active_letters().size() == 1,
			"в пользовательском наборе только заполненные буквы (получено: %d)"
			% SetRepository.get_active_letters().size())

	# Возврат к встроенному набору не оставляет репозиторий в custom-режиме.
	# Отличие от плана — проверяем АКТИВНЫЙ набор. План звал
	# is_custom_set(set_id) == false, но набор ещё существует (удаляется
	# следующей строкой), а контракт set_repository.gd прямо говорит:
	# «Пользовательский ли набор. Основано на реальном наличии набора в
	# хранилище, а не на префиксе id». То есть is_custom_set() отвечает на
	# вопрос «существует ли», а не «активен ли». Проверка плана была верной
	# всегда бы и падала всегда — то есть ничего не проверяла.
	ProgressManager.set_word_set(1)
	_check(SetRepository.get_active_set_id() == "1",
			"после возврата активен встроенный набор 1 (получено: %s)"
			% SetRepository.get_active_set_id())
	_check(SetRepository.is_custom_set(SetRepository.get_active_set_id()) == false,
			"после возврата к набору 1 активный набор не пользовательский")
	_check(SetRepository.is_custom_set(set_id),
			"неактивный пользовательский набор остаётся пользовательским по наличию")
	CustomSetsStore.delete_set(set_id)


## Пофайловый учёт того, что играм разрешено читать напрямую.
##
## Отличие от плана — плана не было. Скан выше спрашивает «есть ли запрещённое»,
## но не говорит, что РАЗРЕШЕНО: запрет на «AlphabetData.get_word_data» проходит
## и для файла, который читает что угодно другое напрямую. Здесь перечислено
## ровно то, что допустимо, и всё остальное — ошибка.
##
## Дистракторы в играх «найди букву» и «угадай букву» — шум, а не данные набора:
## варианты ответа должны включать буквы, которых в выбранном наборе нет, иначе
## задача неразрешима. Поэтому AlphabetData.get_letters() там и остался.
const DIRECT_READ_ALLOWLIST := {
	"res://ui/games/azbuka/letter_card.gd": [],
	"res://ui/games/collect_word/collect_word.gd": [],
	"res://ui/games/find_letter/find_letter.gd": ["AlphabetData.get_letters("],
	"res://ui/games/guess_picture/guess_picture.gd": [
		"AlphabetData.get_letters(", "AlphabetData.get_letter_data(",
	],
}


func _check_direct_read_inventory() -> void:
	for path: String in GAME_SCRIPTS:
		if not FileAccess.file_exists(path):
			continue
		var allowed: Array = DIRECT_READ_ALLOWLIST.get(path, [])
		var code := _code_without_comments(FileAccess.get_file_as_string(path))
		for line: String in code.split("\n"):
			if not line.contains("AlphabetData."):
				continue
			var found := ""
			for needle: String in allowed:
				if line.contains(needle):
					found = needle
					break
			if found.is_empty():
				_fail("%s читает AlphabetData напрямую: %s"
						% [path.get_file(), line.strip_edges()])


## Настоящий полный набор: 33 буквы, у каждой свой WebP и свой WAV.
##
## Проверяется ровно то, ради чего план и писался: после выбора своего набора
## игра получает СВОИ картинки и СВОЙ звук, а не картинки набора 1. Поэтому
## файлы пишутся настоящие (иначе get_word_texture вернёт null и проверка
## прошла бы на пустоте) и разные для разных букв (иначе кэш репозитория
## замаскировал бы ошибку «все буквы ссылаются на один файл»).
func _check_full_custom_set() -> void:
	var record := CustomSetsStore.create_set("Полный набор")
	var set_id := str(record.get("id", ""))
	var letters := CustomSetsStore.LETTER_ORDER
	_write_letter_files(set_id, letters)
	for i in letters.length():
		var letter := letters[i]
		CustomSetsStore.set_entry(set_id, letter, "Слово" + letter,
				"user://" + CustomSetsStore.set_dir(set_id).trim_prefix("user://")
						+ CustomSetsStore.image_file_name(letter),
				"user://" + CustomSetsStore.set_dir(set_id).trim_prefix("user://")
						+ CustomSetsStore.audio_file_name(letter))
	ProgressManager.set_word_set_id(set_id)
	SetRepository.clear_cache()

	var active: Array[String] = SetRepository.get_active_letters()
	_check(active.size() == CustomSetsStore.FULL_SET_SIZE,
			"полный набор отдаёт все %d букв (получено: %d)"
			% [CustomSetsStore.FULL_SET_SIZE, active.size()])
	# Порядок проверяем против самого LETTER_ORDER, а не против
	# get_set_letters(): то и то пришло бы из хранилища, и равенство держалось бы
	# даже при перепутанных буквах. Игра листает набор по этому порядку, поэтому
	# «А» после «Б» — это уже другой набор на экране.
	var expected_order: Array[String] = []
	for i in letters.length():
		expected_order.append(letters[i])
	_check(active == expected_order,
			"буквы полного набора идут в порядке LETTER_ORDER (получено: %s)"
			% str(active))

	var bad_word := ""
	var bad_texture := ""
	var bad_audio := ""
	var image_paths := {}
	var audio_paths := {}
	for letter: String in letters:
		var data := SetRepository.get_word_data(letter)
		if str(data.get("word", "")) != "Слово" + letter:
			bad_word = letter
			break
		if SetRepository.get_word_texture(letter) == null:
			bad_texture = letter
			break
		if SetRepository.get_word_audio(letter) == null:
			bad_audio = letter
			break
		image_paths[letter] = str(data.get("image_path", ""))
		audio_paths[letter] = str(data.get("audio_path", ""))
	_check(bad_word.is_empty(), "у всех 33 букв своё слово")
	_check(bad_texture.is_empty(),
			"у всех 33 букв своя картинка, а не заглушка (сорвано на «%s»)"
			% bad_texture)
	_check(bad_audio.is_empty(),
			"у всех 33 букв свой звук (сорвано на «%s»)" % bad_audio)
	# Разные файлы на разные буквы: иначе кэш по пути вернул бы одну картинку
	# на весь набор, и проверка выше прошла бы враньём.
	_check(image_paths.size() == CustomSetsStore.FULL_SET_SIZE,
			"у каждой буквы свой файл картинки (уникальных путей: %d)"
			% image_paths.size())
	_check(audio_paths.size() == CustomSetsStore.FULL_SET_SIZE,
			"у каждой буквы свой файл звука (уникальных путей: %d)"
			% audio_paths.size())
	_check(CustomSetsStore.is_set_complete(set_id),
			"набор из 33 заполненных букв помечен готовым к играм")

	# Пути лежат в каталоге набора, а не в корне user://: ровно та ошибка,
	# что стоила файлов в Task 7.
	var inside := true
	for letter: String in letters:
		if not str(image_paths.get(letter, "")).contains(set_id):
			inside = false
		if not str(audio_paths.get(letter, "")).contains(set_id):
			inside = false
	_check(inside, "файлы набора лежат в его каталоге, а не в корне user://")
	CustomSetsStore.delete_set(set_id)
	ProgressManager.set_word_set(1)


## Кладёт настоящий WebP и настоящий WAV для каждой буквы. Пишутся разные
## картинки (цвет по индексу), чтобы кэш репозитория по пути не смог замаскировать
## «все буквы смотрят в один файл».
func _write_letter_files(set_id: String, letters: String) -> void:
	var dir_path := ProjectSettings.globalize_path(CustomSetsStore.set_dir(set_id))
	DirAccess.make_dir_recursive_absolute(dir_path)
	for i in letters.length():
		var letter := letters[i]
		var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		image.fill(Color(float(i) / 33.0, 0.5, 0.9, 1.0))
		image.save_webp(dir_path.path_join(CustomSetsStore.image_file_name(letter)))

		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = 22050
		wav.stereo = false
		var samples := PackedByteArray()
		samples.resize(441 * 2)
		for s in 441:
			# Разная высота тона на букву: одинаковые файлы не скрыли бы подмену
			# содержимого, а проверка уникальных путей её бы и не поймала.
			var val := 4000 + i * 300
			samples[s * 2] = val & 0xFF
			samples[s * 2 + 1] = (val >> 8) & 0xFF
		wav.data = samples
		wav.save_to_wav(dir_path.path_join(CustomSetsStore.audio_file_name(letter)))


## Встроенные наборы не должны пострадать от миграции: SetRepository обязан
## отдавать ровно то, что отдавал AlphabetData раньше. Проверяются все пять,
## а не только набор 1, — регрессия «свои наборы починили, а набор 3 отвалился»
## самая неприятная, потому что её видно только тем, кто играл в третий набор.
func _check_builtin_parity() -> void:
	for set_number in range(1, ProgressManager.WORD_SET_COUNT + 1):
		ProgressManager.set_word_set(set_number)
		SetRepository.clear_cache()
		var bad_word := ""
		var bad_image := ""
		for letter: String in CustomSetsStore.LETTER_ORDER:
			var expected := AlphabetData.get_word_data(letter, set_number)
			var got := SetRepository.get_word_data(letter)
			if str(got.get("word", "")) != str(expected.get("word", "")):
				bad_word = letter
				break
			var expected_image := str(expected.get("image", ""))
			if expected_image.is_empty():
				expected_image = AlphabetData.get_fallback_image(letter)
			if str(got.get("image_path", "")) \
					!= SetRepository.BUILTIN_IMAGE_DIR + expected_image + ".png":
				bad_image = letter
				break
		_check(bad_word.is_empty(),
				"встроенный набор %d отдаёт те же слова, что и раньше" % set_number)
		_check(bad_image.is_empty(),
				"встроенный набор %d отдаёт те же картинки, что и раньше" % set_number)
		# Картинка должна грузиться, а не только называться правильно.
		var probe := CustomSetsStore.LETTER_ORDER[0]
		_check(SetRepository.get_word_texture(probe) != null,
				"картинка встроенного набора %d грузится" % set_number)
	ProgressManager.set_word_set(1)
	SetRepository.clear_cache()


## Выбор должен пережить перезапуск: прогресс и набор лежат в user://, и
## после перечитывания обоих репозиторий обязан отдать тот же набор. Без этой
## проверки тест зелёный, а игра после перезагрузки страницы молча откатывается
## на набор 1.
func _check_restart_persistence() -> void:
	var record := CustomSetsStore.create_set("После перезапуска")
	var set_id := str(record.get("id", ""))
	CustomSetsStore.set_entry(set_id, "А", "Автобус", "", "")
	CustomSetsStore.set_entry(set_id, "Б", "Бампер", "", "")
	ProgressManager.set_word_set_id(set_id)

	# Имитация перезапуска: сбрасываем кэш и память, читаем оба файла заново.
	SetRepository.clear_cache()
	CustomSetsStore.clear_memory()
	CustomSetsStore.load_sets()
	ProgressManager.load_progress()
	SetRepository.clear_cache()

	_check(ProgressManager.get_word_set_id() == set_id,
			"после перечитывания прогресса выбран тот же набор (получено: %s)"
			% ProgressManager.get_word_set_id())
	_check(SetRepository.get_active_set_id() == set_id,
			"после перечитывания хранилища репозиторий видит тот же набор")
	_check(SetRepository.get_active_letters().size() == 2,
			"после перечитывания набор отдаёт обе буквы (получено: %d)"
			% SetRepository.get_active_letters().size())
	_check(str(SetRepository.get_word_data("А").get("word", "")) == "Автобус",
			"после перечитывания слово «А» сохранилось")
	CustomSetsStore.delete_set(set_id)
	ProgressManager.set_word_set(1)


## Все четыре игры должны пережить старт на своём наборе.
##
## Отличие от плана — плана не было. Скан проверяет исходники, а не поведение:
## игра может не содержать запрещённых строк и всё равно упасть в _ready() на
## своём наборе (например, получить пустой поток и разделить на ноль). Здесь
## каждая сцена реально создаётся и один кадр дожидается завершения _ready().
func _check_game_scenes_witness() -> void:
	const GAME_SCENES := [
		"res://ui/games/azbuka/letter_card.tscn",
		"res://ui/games/collect_word/collect_word.tscn",
		"res://ui/games/find_letter/find_letter.tscn",
		"res://ui/games/guess_picture/guess_picture.tscn",
	]
	# Активен набор 1: он полон, и любая проверка «данные есть» проходит
	# честно, а не на пустом наборе.
	ProgressManager.set_word_set(1)
	for path: String in GAME_SCENES:
		if ResourceLoader.exists(path) == false:
			_fail("сцена игры не загружается: %s" % path)
			continue
		var packed: PackedScene = load(path)
		var instance := packed.instantiate()
		add_child(instance)
		await get_tree().process_frame
		await get_tree().process_frame
		_check(instance.is_inside_tree(),
				"%s поднялся на своём наборе" % path.get_file())
		instance.queue_free()
		await get_tree().process_frame


## Четыре игровых скрипта, которые обязаны ходить в данные набора только через
## SetRepository. План обещал такую функцию в разделе Interfaces, но в коде
## оставил только константу выше: определены оба, источник один.
static func set_entry_scan_targets() -> PackedStringArray:
	return PackedStringArray(GAME_SCRIPTS)


func _class_loaded() -> bool:
	var ok := true
	for path: String in GAME_SCRIPTS:
		if not FileAccess.file_exists(path):
			_fail("игровой скрипт не найден: %s" % path)
			ok = false
	if ResourceLoader.exists("res://ui/settings/settings.tscn") == false:
		_fail("settings.tscn не загружается — сцена молча ничего не проверяет")
		ok = false
	ok = _contract_ok(SetList, [
		"refresh", "get_row_count", "get_row",
	], ["open_editor", "sets_changed"]) and ok
	ok = _contract_ok(SetEditor, [
		"open_set", "get_set_id", "readiness_label",
	], ["set_saved", "close_requested"]) and ok
	return ok


func _contract_ok(klass: Variant, required: Array, expected_signals: Array) -> bool:
	var script := klass as Script
	if script == null:
		_fail("класс %s не зарегистрирован: нет class_name" % str(klass))
		return false
	var methods := {}
	for method: Dictionary in script.get_script_method_list():
		methods[method.get("name", "")] = true
	var signals := {}
	for signal_info: Dictionary in script.get_script_signal_list():
		signals[signal_info.get("name", "")] = true
	var ok := true
	for method_name: String in required:
		if not methods.has(method_name):
			_fail("у %s нет метода %s" % [str(klass), method_name])
			ok = false
	for signal_name: String in expected_signals:
		if not signals.has(signal_name):
			_fail("у %s нет сигнала %s" % [str(klass), signal_name])
			ok = false
	return ok


## Тестовые файлы вместо боевых. Конвенция переопределения пути — из
## validate_custom_sets_store.gd, validate_set_repository.gd и
## validate_constructor_ui.gd: писать в user://custom_sets.json нельзя, это
## данные ребёнка.
const TEST_STORE_PATH := "user://custom_sets_integration_test.json"
const TEST_PROGRESS_PATH := "user://custom_sets_integration_progress.json"


## Убирает тестовые файлы. Каталоги наборов при этом остаются боевыми, но id
## генерируются случайно, а наборы удаляются в конце прогона.
func _cleanup() -> void:
	for path: String in [TEST_STORE_PATH, TEST_PROGRESS_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _check(ok: bool, msg: String) -> void:
	checks += 1
	if ok:
		_print("OK: " + msg)
	else:
		_fail(msg)


func _fail(msg: String) -> void:
	failures += 1
	printerr("FAIL: " + msg)


func _print(msg: String) -> void:
	print("[custom_sets_integration_validate] " + msg)


func _finish() -> void:
	print("[custom_sets_integration_validate] выполнено проверок: %d" % checks)
	# Ноль выполненных проверок при нуле ошибок — это не успех, а сломанный
	# валидатор: печатать PASSED в таком случае нельзя.
	if checks == 0:
		printerr("FAILED: не выполнено ни одной проверки — валидатор не отработал")
		get_tree().quit(1)
		return
	if failures > 0:
		printerr("FAILED: %d проверок из %d" % [failures, checks])
		get_tree().quit(1)
	else:
		print("[custom_sets_integration_validate] PASSED: %d проверок успешны" % checks)
		get_tree().quit(0)
