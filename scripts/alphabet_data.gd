extends Node

var DATA := [
	{ "letter": "А", "word": "Автобус", "word_lower": "автобус", "image_path": "res://assets/images/avtobus.png" },
	{ "letter": "Б", "word": "Банан", "word_lower": "банан", "image_path": "res://assets/images/banan.png" },
	{ "letter": "В", "word": "Вода", "word_lower": "вода", "image_path": "res://assets/images/voda.png" },
	{ "letter": "Г", "word": "Гусь", "word_lower": "гусь", "image_path": "res://assets/images/gus.png" },
	{ "letter": "Д", "word": "Дом", "word_lower": "дом", "image_path": "res://assets/images/dom.jpg" },
	{ "letter": "Е", "word": "Еж", "word_lower": "еж", "image_path": "res://assets/images/ezh.jpg" },
	{ "letter": "Ё", "word": "Ёлка", "word_lower": "ёлка", "image_path": "res://assets/images/yolka.jpg" },
	{ "letter": "Ж", "word": "Жук", "word_lower": "жук", "image_path": "res://assets/images/zhuk.jpg" },
	{ "letter": "З", "word": "Заяц", "word_lower": "заяц", "image_path": "res://assets/images/zayac.jpg" },
	{ "letter": "И", "word": "Игрушка", "word_lower": "игрушка", "image_path": "res://assets/images/igrushka.png" },
	{ "letter": "Й", "word": "Йогурт", "word_lower": "йогурт", "image_path": "res://assets/images/yogurt.png" },
	{ "letter": "К", "word": "Кот", "word_lower": "кот", "image_path": "res://assets/images/kot.png" },
	{ "letter": "Л", "word": "Луна", "word_lower": "луна", "image_path": "res://assets/images/luna.png" },
	{ "letter": "М", "word": "Мяч", "word_lower": "мяч", "image_path": "res://assets/images/myach.png" },
	{ "letter": "Н", "word": "Нос", "word_lower": "нос", "image_path": "res://assets/images/Nose.png" },
	{ "letter": "О", "word": "Окно", "word_lower": "окно", "image_path": "res://assets/images/Window.png" },
	{ "letter": "П", "word": "Пирог", "word_lower": "пирог", "image_path": "res://assets/images/pie.png" },
	{ "letter": "Р", "word": "Рот", "word_lower": "рот", "image_path": "res://assets/images/Mouth.png" },
	{ "letter": "С", "word": "Сок", "word_lower": "сок", "image_path": "res://assets/images/Juice.png" },
	{ "letter": "Т", "word": "Торт", "word_lower": "торт", "image_path": "res://assets/images/Cake.jpg" },
	{ "letter": "У", "word": "Утка", "word_lower": "утка", "image_path": "res://assets/images/Duck.jpg" },
	{ "letter": "Ф", "word": "Фонтан", "word_lower": "фонтан", "image_path": "res://assets/images/Fountain.jpg" },
	{ "letter": "Х", "word": "Хлеб", "word_lower": "хлеб", "image_path": "res://assets/images/Bread.jpg" },
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
