extends Node
## CLI-обёртка наполнения набора: разбирает флаги, запускает Filler, печатает итог.
##
## Сцена, а не --script: инструмент обязан ходить через автолоады
## (AlphabetData, CustomSetsStore, SetRepository), а --script их не поднимает.
##
## Запуск:
## godot --headless --path . tools/fill_test_set.tscn -- --name="Тестовый набор"
## Флаги: --name, --set-id, --letters=А,Б,В, --reset, --export-dir.

const Filler := preload("res://tools/test_set_filler.gd")


func _ready() -> void:
	var options := parse_args(OS.get_cmdline_user_args())
	if not bool(options.get("ok", false)):
		printerr("[fill_test_set] ошибка аргументов: " + str(options.get("error", "")))
		get_tree().quit(1)
		return
	var result: Dictionary = Filler.new().fill(options)
	_print_summary(result, options)
	get_tree().quit(0 if bool(result.get("ok", false)) else 1)


## Разбирает аргументы после "--". Неизвестный флаг это ошибка, а не тишина:
## опечатка в --letters иначе молча заполнила бы весь алфавит.
static func parse_args(args: PackedStringArray) -> Dictionary:
	var options := {
		"ok": true, "error": "", "name": "", "set_id": "",
		"letters": [], "reset": false, "export_dir": "",
	}
	for arg: String in args:
		if arg.begins_with("--name="):
			options["name"] = arg.trim_prefix("--name=")
		elif arg.begins_with("--set-id="):
			options["set_id"] = arg.trim_prefix("--set-id=")
		elif arg.begins_with("--letters="):
			options["letters"] = _split_letters(arg.trim_prefix("--letters="))
		elif arg.begins_with("--export-dir="):
			options["export_dir"] = arg.trim_prefix("--export-dir=")
		elif arg == "--reset":
			options["reset"] = true
		else:
			options["ok"] = false
			options["error"] = "неизвестный аргумент: " + arg
			return options
	return options


static func _split_letters(raw: String) -> Array[String]:
	var letters: Array[String] = []
	for part: String in raw.split(","):
		var letter := part.strip_edges().to_upper()
		if letter.is_empty() or letters.has(letter):
			continue
		letters.append(letter)
	return letters


func _print_summary(result: Dictionary, options: Dictionary) -> void:
	var requested := PackedStringArray(result.get("requested", []))
	var failed: Array = result.get("failed", [])
	print("[fill_test_set] набор: %s" % str(result.get("set_name", "")))
	print("[fill_test_set] id: %s (%s)" % [str(result.get("set_id", "")),
			"создан" if bool(result.get("created", false)) else "обновлён"])
	print("[fill_test_set] запрошено букв: %d (%s)" % [requested.size(),
			", ".join(requested)])
	print("[fill_test_set] полностью заполнено: %d" % (result.get("complete", []) as Array).size())
	for item: Dictionary in failed:
		printerr("[fill_test_set] ОШИБКА буква %s: %s" % [str(item.get("letter", "")),
				str(item.get("reason", ""))])
	if not str(options.get("export_dir", "")).is_empty():
		print("[fill_test_set] выгружено файлов: %d в %s" % [int(result.get("export_files", 0)),
				str(result.get("export_dir", ""))])
	if not str(result.get("error", "")).is_empty():
		printerr("[fill_test_set] ошибка: " + str(result["error"]))
	print("[fill_test_set] ИТОГ: %s" % ("успех" if bool(result.get("ok", false)) else "есть ошибки"))
