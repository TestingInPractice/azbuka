## Logger — центральная точка входа для логирования.
## Автолоад (project.godot → [autoload] Logger="*res://logging/logger.gd").
##
## Декомпозиция:
##   logging/log_level.gd                — уровни (DEBUG/INFO/WARN/ERROR)
##   logging/log_entry.gd                — запись лога
##   logging/handlers/log_handler.gd     — базовый обработчик
##   logging/handlers/console_handler.gd — вывод в консоль (веб: DevTools)
##   logging/handlers/file_handler.gd    — вывод в файл user://logs/azbuka.log
##   logging/logger.gd                   — фасад: маршрутизация по обработчикам
##
## Использование из любой сцены:
##   GameLogger.info("letter_detail", "ready", {"letter": letter})
##   GameLogger.error("global", "instantiate FAILED")
extends Node

const LogLevel := preload("res://logging/log_level.gd")
const LogEntry := preload("res://logging/log_entry.gd")
const ConsoleHandler := preload("res://logging/handlers/console_handler.gd")
const FileHandler := preload("res://logging/handlers/file_handler.gd")

var handlers: Array = []
var min_level: int = LogLevel.Level.DEBUG

func _ready() -> void:
	# Консоль — всегда (в вебе это DevTools браузера, на десктопе — вывод редактора).
	add_handler(ConsoleHandler.new())
	# Файл — только вне веба (в вебе user:// это IndexedDB, вручную не прочитать).
	if not OS.has_feature("web"):
		add_handler(FileHandler.new())

func set_min_level(level: int) -> void:
	min_level = level

func add_handler(handler) -> void:
	handlers.append(handler)

func clear_handlers() -> void:
	handlers.clear()

func debug(channel: String, message: String, data: Dictionary = {}) -> void:
	_emit(LogLevel.Level.DEBUG, channel, message, data)

func info(channel: String, message: String, data: Dictionary = {}) -> void:
	_emit(LogLevel.Level.INFO, channel, message, data)

func warn(channel: String, message: String, data: Dictionary = {}) -> void:
	_emit(LogLevel.Level.WARN, channel, message, data)

func error(channel: String, message: String, data: Dictionary = {}) -> void:
	_emit(LogLevel.Level.ERROR, channel, message, data)

func _emit(level: int, channel: String, message: String, data: Dictionary) -> void:
	if level < min_level:
		return
	var entry := LogEntry.new(level, channel, message, data)
	for handler in handlers:
		if handler.accepts(level):
			handler.handle(entry)

## Диагностика текстуры: существует ли ресурс, грузится ли, класс, размер.
func texture_diag(channel: String, label: String, path: String) -> void:
	var data := {"path": path}
	var exists := ResourceLoader.exists(path)
	data["exists"] = exists
	if not exists:
		error(channel, "TEXTURE_MISSING: %s" % label, data)
		return
	var res := ResourceLoader.load(path)
	data["load_ok"] = res != null
	data["res_class"] = res.get_class() if res else "null"
	if res is Texture2D:
		data["size"] = "%dx%d" % [res.get_width(), res.get_height()]
		info(channel, "TEXTURE_OK: %s" % label, data)
	else:
		warn(channel, "TEXTURE_NOT_TEXTURE2D: %s (class=%s)" % [label, data["res_class"]], data)
