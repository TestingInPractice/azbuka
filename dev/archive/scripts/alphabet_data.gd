extends Node

var DATA := [
	{ "letter": "А", "word": "Автобус", "word_lower": "автобус", "image_path": "res://assets/images/Bus.png" },
	{ "letter": "Б", "word": "Банан", "word_lower": "банан", "image_path": "res://assets/images/Banana.png" },
	{ "letter": "В", "word": "Вода", "word_lower": "вода", "image_path": "res://assets/images/Water.png" },
	{ "letter": "Г", "word": "Гусь", "word_lower": "гусь", "image_path": "res://assets/images/Goose.png" },
	{ "letter": "Д", "word": "Дом", "word_lower": "дом", "image_path": "res://assets/images/House.png" },
	{ "letter": "Е", "word": "Ель", "word_lower": "ель", "image_path": "res://assets/images/Christmas_Tree.png" },
	{ "letter": "Ё", "word": "Ёж", "word_lower": "ёж", "image_path": "res://assets/images/Hedgehog.png" },
	{ "letter": "Ж", "word": "Жук", "word_lower": "жук", "image_path": "res://assets/images/Beetle.png" },
	{ "letter": "З", "word": "Заяц", "word_lower": "заяц", "image_path": "res://assets/images/Hare.png" },
	{ "letter": "И", "word": "Игрушка", "word_lower": "игрушка", "image_path": "res://assets/images/Toy.png" },
	{ "letter": "Й", "word": "Йогурт", "word_lower": "йогурт", "image_path": "res://assets/images/Yogurt.png" },
	{ "letter": "К", "word": "Кот", "word_lower": "кот", "image_path": "res://assets/images/Cat.png" },
	{ "letter": "Л", "word": "Луна", "word_lower": "луна", "image_path": "res://assets/images/Moon.png" },
	{ "letter": "М", "word": "Мяч", "word_lower": "мяч", "image_path": "res://assets/images/Ball.png" },
	{ "letter": "Н", "word": "Нос", "word_lower": "нос", "image_path": "res://assets/images/Nose.png" },
	{ "letter": "О", "word": "Окно", "word_lower": "окно", "image_path": "res://assets/images/Window.png" },
	{ "letter": "П", "word": "Подарок", "word_lower": "подарок", "image_path": "res://assets/images/Gift.png" },
	{ "letter": "Р", "word": "Рот", "word_lower": "рот", "image_path": "res://assets/images/Mouth.png" },
	{ "letter": "С", "word": "Сок", "word_lower": "сок", "image_path": "res://assets/images/Juice.png" },
	{ "letter": "Т", "word": "Торт", "word_lower": "торт", "image_path": "res://assets/images/Cake.png" },
	{ "letter": "У", "word": "Утка", "word_lower": "утка", "image_path": "res://assets/images/Duck.png" },
	{ "letter": "Ф", "word": "Фонтан", "word_lower": "фонтан", "image_path": "res://assets/images/Fountain.png" },
	{ "letter": "Х", "word": "Хлеб", "word_lower": "хлеб", "image_path": "res://assets/images/Bread.png" },
	{ "letter": "Ц", "word": "Цыплёнок", "word_lower": "цыплёнок", "image_path": "res://assets/images/Chicken.png" },
	{ "letter": "Ч", "word": "Чай", "word_lower": "чай", "image_path": "res://assets/images/Tea.png" },
	{ "letter": "Ш", "word": "Шапка", "word_lower": "шапка", "image_path": "res://assets/images/Hat.png" },
	{ "letter": "Щ", "word": "Щенок", "word_lower": "щенок", "image_path": "res://assets/images/Puppy.png" },
	{ "letter": "Ъ", "word": "Объявление", "word_lower": "объявление", "image_path": "res://assets/images/announcement.png" },
	{ "letter": "Ы", "word": "Мыло", "word_lower": "мыло", "image_path": "res://assets/images/Soap.png" },
	{ "letter": "Ь", "word": "Конь", "word_lower": "конь", "image_path": "res://assets/images/Horse.png" },
	{ "letter": "Э", "word": "Экран", "word_lower": "экран", "image_path": "res://assets/images/Screen.png" },
	{ "letter": "Ю", "word": "Юла", "word_lower": "юла", "image_path": "res://assets/images/Spinning_Top.png" },
	{ "letter": "Я", "word": "Яблоко", "word_lower": "яблоко", "image_path": "res://assets/images/Apple.png" },
]

func get_letter_data(letter: String) -> Dictionary:
	for entry in DATA:
		if entry.letter == letter:
			return entry.duplicate()
	return {}
