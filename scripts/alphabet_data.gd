extends Node

var DATA := [
	{ "letter": "А", "word": "Автобус", "word_lower": "автобус", "image_path": "res://assets/images/arbuz.png" },
	{ "letter": "Б", "word": "Банан", "word_lower": "банан", "image_path": "res://assets/images/banan.png" },
	{ "letter": "В", "word": "Вода", "word_lower": "вода", "image_path": "res://assets/images/volk.png" },
	{ "letter": "Г", "word": "Гусь", "word_lower": "гусь", "image_path": "res://assets/images/grib.png" },
	{ "letter": "Д", "word": "Дом", "word_lower": "дом", "image_path": "res://assets/images/dom.png" },
	{ "letter": "Е", "word": "Еж", "word_lower": "еж", "image_path": "res://assets/images/enot.png" },
	{ "letter": "Ё", "word": "Ёлка", "word_lower": "ёлка", "image_path": "res://assets/images/yozh.png" },
	{ "letter": "Ж", "word": "Жук", "word_lower": "жук", "image_path": "res://assets/images/zhuk.png" },
	{ "letter": "З", "word": "Заяц", "word_lower": "заяц", "image_path": "res://assets/images/zebra.png" },
	{ "letter": "И", "word": "Игрушка", "word_lower": "игрушка", "image_path": "res://assets/images/iriska.png" },
	{ "letter": "Й", "word": "Йогурт", "word_lower": "йогурт", "image_path": "res://assets/images/yogurt.png" },
	{ "letter": "К", "word": "Кот", "word_lower": "кот", "image_path": "res://assets/images/kot.png" },
	{ "letter": "Л", "word": "Луна", "word_lower": "луна", "image_path": "res://assets/images/lisa.png" },
	{ "letter": "М", "word": "Мяч", "word_lower": "мяч", "image_path": "res://assets/images/medved.png" },
	{ "letter": "Н", "word": "Нос", "word_lower": "нос", "image_path": "res://assets/images/nosorog.png" },
	{ "letter": "О", "word": "Окно", "word_lower": "окно", "image_path": "res://assets/images/okno.png" },
	{ "letter": "П", "word": "Подъезд", "word_lower": "подъезд", "image_path": "res://assets/images/pingvin.png" },
	{ "letter": "Р", "word": "Рот", "word_lower": "рот", "image_path": "res://assets/images/ryba.png" },
	{ "letter": "С", "word": "Сок", "word_lower": "сок", "image_path": "res://assets/images/sova.png" },
	{ "letter": "Т", "word": "Торт", "word_lower": "торт", "image_path": "res://assets/images/tigr.png" },
	{ "letter": "У", "word": "Утка", "word_lower": "утка", "image_path": "res://assets/images/utka.png" },
	{ "letter": "Ф", "word": "Фонтан", "word_lower": "фонтан", "image_path": "res://assets/images/filin.png" },
	{ "letter": "Х", "word": "Хлеб", "word_lower": "хлеб", "image_path": "res://assets/images/hleb.png" },
	{ "letter": "Ц", "word": "Цыплёнок", "word_lower": "цыплёнок", "image_path": "res://assets/images/cyplenok.png" },
	{ "letter": "Ч", "word": "Чай", "word_lower": "чай", "image_path": "res://assets/images/cherepaha.png" },
	{ "letter": "Ш", "word": "Шапка", "word_lower": "шапка", "image_path": "res://assets/images/shapka.png" },
	{ "letter": "Щ", "word": "Щенок", "word_lower": "щенок", "image_path": "res://assets/images/shenok.png" },
	{ "letter": "Ъ", "word": "Объём", "word_lower": "объём", "image_path": "res://assets/images/podjezd.png" },
	{ "letter": "Ы", "word": "Мыло", "word_lower": "мыло", "image_path": "res://assets/images/syr.png" },
	{ "letter": "Ь", "word": "Конь", "word_lower": "конь", "image_path": "res://assets/images/los.png" },
	{ "letter": "Э", "word": "Экран", "word_lower": "экран", "image_path": "res://assets/images/eskimo.png" },
	{ "letter": "Ю", "word": "Юла", "word_lower": "юла", "image_path": "res://assets/images/yula.png" },
	{ "letter": "Я", "word": "Яблоко", "word_lower": "яблоко", "image_path": "res://assets/images/yabloko.png" },
]

func get_letter_data(letter: String) -> Dictionary:
	for entry in DATA:
		if entry.letter == letter:
			return entry.duplicate()
	return {}
