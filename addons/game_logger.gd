extends Node
## GameLogger: центральный логгер приложения «Азбука».
##
## Структурированное логирование для агент-дружелюбности: каждая запись имеет
## источник (source), событие (event) и словарь данных (data). Записи выводятся
## в консоль и рассылаются через сигнал message_logged для будущего окна
## отладки. Синглтон-автолоад, не зависит от других сервисов проекта.

enum Level { DEBUG, INFO, WARNING, ERROR }

## Новая запись лога. Слушатели (например, UI-отладчик) подписываются сюда.
signal message_logged(source: String, event: String, data: Dictionary, level: Level)

## Минимальный уровень, который попадает в лог.
var min_level: Level = Level.DEBUG

## Локальный журнал событий. Путь можно переопределить в тестах.
const ANALYTICS_FILE := "user://analytics/events.jsonl"
var analytics_path := ANALYTICS_FILE
## В headless-прогонах журнал по умолчанию выключен, чтобы валидаторы не
## дописывали события в данные ребёнка. Валидатор аналитики включает его явно.
var analytics_enabled := DisplayServer.get_name() != "headless"


func debug(source: String, event: String, data: Dictionary = {}) -> void:
	_log(Level.DEBUG, source, event, data)


func info(source: String, event: String, data: Dictionary = {}) -> void:
	_log(Level.INFO, source, event, data)


func warning(source: String, event: String, data: Dictionary = {}) -> void:
	_log(Level.WARNING, source, event, data)


func error(source: String, event: String, data: Dictionary = {}) -> void:
	_log(Level.ERROR, source, event, data)


## Записывает продуктовое событие в локальный JSONL-журнал. Это не отладочный
## лог: сюда попадают только осмысленные шаги воронки (открытие приложения,
## старт игры, открытие буквы), чтобы потом можно было посчитать прохождение.
func analytics(event: String, data: Dictionary = {}) -> void:
	if not analytics_enabled or event.is_empty():
		return
	var dir := analytics_path.get_base_dir()
	if not dir.is_empty():
		DirAccess.make_dir_recursive_absolute(dir)
	var file: FileAccess
	if FileAccess.file_exists(analytics_path):
		file = FileAccess.open(analytics_path, FileAccess.READ_WRITE)
	else:
		file = FileAccess.open(analytics_path, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(JSON.stringify({
		"ts": Time.get_datetime_string_from_system(true),
		"event": event,
		"data": data,
	}))
	file.flush()


func _log(level: Level, source: String, event: String, data: Dictionary) -> void:
	if level < min_level:
		return
	message_logged.emit(source, event, data, level)
	var line := "[%s] %s: %s %s" % [_level_to_string(level), source, event, _data_to_string(data)]
	if level == Level.ERROR:
		push_error(line)
	else:
		print(line)


func _level_to_string(level: Level) -> String:
	match level:
		Level.DEBUG:
			return "DEBUG"
		Level.INFO:
			return "INFO"
		Level.WARNING:
			return "WARNING"
		Level.ERROR:
			return "ERROR"
	return "UNKNOWN"


func _data_to_string(data: Dictionary) -> String:
	if data.is_empty():
		return ""
	return " data=" + JSON.stringify(data)
