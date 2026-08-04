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


func debug(source: String, event: String, data: Dictionary = {}) -> void:
	_log(Level.DEBUG, source, event, data)


func info(source: String, event: String, data: Dictionary = {}) -> void:
	_log(Level.INFO, source, event, data)


func warning(source: String, event: String, data: Dictionary = {}) -> void:
	_log(Level.WARNING, source, event, data)


func error(source: String, event: String, data: Dictionary = {}) -> void:
	_log(Level.ERROR, source, event, data)


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
