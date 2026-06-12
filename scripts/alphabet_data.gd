extends Node

const DATA := [
	{ "letter": "А", "word": "Арбуз", "word_lower": "арбуз", "image_path": "res://assets/images/arbuz.png", "sound_letter_path": "", "sound_word_path": "" },
	{ "letter": "Б", "word": "Банан", "word_lower": "банан", "image_path": "res://assets/images/banan.png", "sound_letter_path": "", "sound_word_path": "" },
	{ "letter": "В", "word": "Волк", "word_lower": "волк", "image_path": "res://assets/images/volk.png", "sound_letter_path": "", "sound_word_path": "" },
	{ "letter": "Г", "word": "Гриб", "word_lower": "гриб", "image_path": "res://assets/images/grib.png", "sound_letter_path": "", "sound_word_path": "" },
	{ "letter": "Д", "word": "Дом", "word_lower": "дом", "image_path": "res://assets/images/dom.png", "sound_letter_path": "", "sound_word_path": "" },
	{ "letter": "Е", "word": "Енот", "word_lower": "енот", "image_path": "res://assets/images/enot.png", "sound_letter_path": "", "sound_word_path": "" },
	{ "letter": "Ё", "word": "Ёж", "word_lower": "ёж", "image_path": "res://assets/images/yozh.png", "sound_letter_path": "", "sound_word_path": "" },
	{ "letter": "Ж", "word": "Жук", "word_lower": "жук", "image_path": "res://assets/images/zhuk.png", "sound_letter_path": "", "sound_word_path": "" },
	{ "letter": "З", "word": "Зебра", "word_lower": "зебра", "image_path": "res://assets/images/zebra.png", "sound_letter_path": "", "sound_word_path": "" },
	{ "letter": "И", "word": "Ириска", "word_lower": "ириска", "image_path": "res://assets/images/iriska.png", "sound_letter_path": "", "sound_word_path": "" },
	{ "letter": "Й", "word": "Йогурт", "word_lower": "йогурт", "image_path": "res://assets/images/yogurt.png", "sound_letter_path": "", "sound_word_path": "" },
	{ "letter": "К", "word": "Кот", "word_lower": "кот", "image_path": "res://assets/images/kot.png", "sound_letter_path": "", "sound_word_path": "" },
	{ "letter": "Л", "word": "Лиса", "word_lower": "лиса", "image_path": "res://assets/images/lisa.png", "sound_letter_path": "", "sound_word_path": "" },
	{ "letter": "М", "word": "Медведь", "word_lower": "медведь", "image_path": "res://assets/images/medved.png", "sound_letter_path": "", "sound_word_path": "" },
	{ "letter": "Н", "word": "Носорог", "word_lower": "носорог", "image_path": "res://assets/images/nosorog.png", "sound_letter_path": "", "sound_word_path": "" },
	{ "letter": "О", "word": "Окно", "word_lower": "окно", "image_path": "res://assets/images/okno.png", "sound_letter_path": "", "sound_word_path": "" },
	{ "letter": "П", "word": "Пингвин", "word_lower": "пингвин", "image_path": "res://assets/images/pingvin.png", "sound_letter_path": "", "sound_word_path": "" },
	{ "letter": "Р", "word": "Рыба", "word_lower": "рыба", "image_path": "res://assets/images/ryba.png", "sound_letter_path": "", "sound_word_path": "" },
	{ "letter": "С", "word": "Сова", "word_lower": "сова", "image_path": "res://assets/images/sova.png", "sound_letter_path": "", "sound_word_path": "" },
	{ "letter": "Т", "word": "Тигр", "word_lower": "тигр", "image_path": "res://assets/images/tigr.png", "sound_letter_path": "", "sound_word_path": "" },
	{ "letter": "У", "word": "Утка", "word_lower": "утка", "image_path": "res://assets/images/utka.png", "sound_letter_path": "", "sound_word_path": "" },
	{ "letter": "Ф", "word": "Филин", "word_lower": "филин", "image_path": "res://assets/images/filin.png", "sound_letter_path": "", "sound_word_path": "" },
	{ "letter": "Х", "word": "Хлеб", "word_lower": "хлеб", "image_path": "res://assets/images/hleb.png", "sound_letter_path": "", "sound_word_path": "" },
	{ "letter": "Ц", "word": "Цыпленок", "word_lower": "цыпленок", "image_path": "res://assets/images/cyplenok.png", "sound_letter_path": "", "sound_word_path": "" },
	{ "letter": "Ч", "word": "Черепаха", "word_lower": "черепаха", "image_path": "res://assets/images/cherepaha.png", "sound_letter_path": "", "sound_word_path": "" },
	{ "letter": "Ш", "word": "Шапка", "word_lower": "шапка", "image_path": "res://assets/images/shapka.png", "sound_letter_path": "", "sound_word_path": "" },
	{ "letter": "Щ", "word": "Щенок", "word_lower": "щенок", "image_path": "res://assets/images/shenok.png", "sound_letter_path": "", "sound_word_path": "" },
	{ "letter": "Ъ", "word": "Подъезд", "word_lower": "подъезд", "image_path": "res://assets/images/podjezd.png", "sound_letter_path": "", "sound_word_path": "" },
	{ "letter": "Ы", "word": "Сыр", "word_lower": "сыр", "image_path": "res://assets/images/syr.png", "sound_letter_path": "", "sound_word_path": "" },
	{ "letter": "Ь", "word": "Лось", "word_lower": "лось", "image_path": "res://assets/images/los.png", "sound_letter_path": "", "sound_word_path": "" },
	{ "letter": "Э", "word": "Эскимо", "word_lower": "эскимо", "image_path": "res://assets/images/eskimo.png", "sound_letter_path": "", "sound_word_path": "" },
	{ "letter": "Ю", "word": "Юла", "word_lower": "юла", "image_path": "res://assets/images/yula.png", "sound_letter_path": "", "sound_word_path": "" },
	{ "letter": "Я", "word": "Яблоко", "word_lower": "яблоко", "image_path": "res://assets/images/yabloko.png", "sound_letter_path": "", "sound_word_path": "" },
]

static func get(letter: String) -> Dictionary:
	for entry in DATA:
		if entry.letter == letter:
			return entry.duplicate()
	return {}
