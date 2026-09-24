# VOICES — «Азбука»: полный скрипт озвучки

Единый реестр **всех** текстов проекта: названия букв, слова по наборам, звуки-промпты и сообщения интерфейса.
Тексты с ударениями (U+0301) — источник истины `content/alphabet_data.json` (поле `letter_name` + `sets[].word`).
Файл описывает, **что и где произносится**, и какие файлы для этого используются.

Счётчики: **33 буквы**, **165 слов** (5 наборов × 33), **198** ссылок на аудио букв/слов (`_tts.wav`), **197** файлов новой озвучки (`_new.ogg`) — все ссылки разрешаются, отсутствующих файлов нет.

---

## 0. Как пользоваться

- Озвучка генерируется локально: скилл `silero-voiceover`.
  - Правки и полная регенерация новой озвучки — `scripts/silero_regenerate_new_ogg.py`
    (локальный сервис `localhost:8000`, голос `kseniya`, TTS-запрос на **48000 Hz** — иначе Silero
    звучит на ~4 dB тише, — ogg на выходе 24000 Hz, `atempo 0.7` — логопедический темп для детей 2 лет).
  - Прежний `scripts/silero_voice_generate.py` (resume, tempo 0.8, URL выключенного второго ПК) оставлен как история.
- Формат входа для генератора: JSON `[{"id": "автобус", "kind": "word", "text": "Авто́бус"}, ...]`; флаг `--rename-by-kind` даёт имена `{id}_word.ogg`.
- Два варианта озвучки в игре (переключатель «Старая»/«Новая» в настройках):
  - старая — `*_tts.wav` (пути прописаны в `alphabet_data.json`);
  - новая — `*_new.ogg` (подставляется в `systems/alphabet_data.gd:123` заменой `_tts.wav` → `_new.ogg`).
- Ударение в тексте — комбинируемый акут U+0301 после ударной гласной: `Авто́бус`. Буква «ё» ударение не требует.
- Односложные слова (Дом, Сок, Мяч, Конь, Юг…) ударения не имеют.

---

## 1. Названия букв (33)

Как произносится буква вслух. Поле `letter_name` в `alphabet_data.json`.

> **Особый случай — «Ё»:** локальный Silero падает на одиночном символе «ё» (`{"detail":"tts failed: "}`),
> поэтому `ё_letter_new.ogg` сгенерирован с текстом **«Йо»** (= /jo/ — ровно так произносится «Ё»).
> Декомпозированная форма «е + U+0308» движком читается как «е» — не использовать.

| Буква | Произношение (с ударением) | Старая озвучка | Новая озвучка |
|:---:|---|---|---|
| А | А | `а_letter_tts.wav` | `а_letter_new.ogg` |
| Б | Бэ | `б_letter_tts.wav` | `б_letter_new.ogg` |
| В | Вэ | `в_letter_tts.wav` | `в_letter_new.ogg` |
| Г | Гэ | `г_letter_tts.wav` | `г_letter_new.ogg` |
| Д | Дэ | `д_letter_tts.wav` | `д_letter_new.ogg` |
| Е | Е | `е_letter_tts.wav` | `е_letter_new.ogg` |
| Ё | Ё | `ё_letter_tts.wav` | `ё_letter_new.ogg` |
| Ж | Жэ | `ж_letter_tts.wav` | `ж_letter_new.ogg` |
| З | Зэ | `з_letter_tts.wav` | `з_letter_new.ogg` |
| И | И | `и_letter_tts.wav` | `и_letter_new.ogg` |
| Й | И́ кра́ткое | `й_letter_tts.wav` | `й_letter_new.ogg` |
| К | Ка | `к_letter_tts.wav` | `к_letter_new.ogg` |
| Л | Эль | `л_letter_tts.wav` | `л_letter_new.ogg` |
| М | Эм | `м_letter_tts.wav` | `м_letter_new.ogg` |
| Н | Эн | `н_letter_tts.wav` | `н_letter_new.ogg` |
| О | О | `о_letter_tts.wav` | `о_letter_new.ogg` |
| П | Пэ | `п_letter_tts.wav` | `п_letter_new.ogg` |
| Р | Эр | `р_letter_tts.wav` | `р_letter_new.ogg` |
| С | Эс | `с_letter_tts.wav` | `с_letter_new.ogg` |
| Т | Тэ | `т_letter_tts.wav` | `т_letter_new.ogg` |
| У | У | `у_letter_tts.wav` | `у_letter_new.ogg` |
| Ф | Эф | `ф_letter_tts.wav` | `ф_letter_new.ogg` |
| Х | Ха | `х_letter_tts.wav` | `х_letter_new.ogg` |
| Ц | Цэ | `ц_letter_tts.wav` | `ц_letter_new.ogg` |
| Ч | Чэ | `ч_letter_tts.wav` | `ч_letter_new.ogg` |
| Ш | Ша | `ш_letter_tts.wav` | `ш_letter_new.ogg` |
| Щ | Ща | `щ_letter_tts.wav` | `щ_letter_new.ogg` |
| Ъ | Твёрдый знак | `ъ_letter_tts.wav` | `ъ_letter_new.ogg` |
| Ы | Ы | `ы_letter_tts.wav` | `ы_letter_new.ogg` |
| Ь | Мя́гкий знак | `ь_letter_tts.wav` | `ь_letter_new.ogg` |
| Э | Э | `э_letter_tts.wav` | `э_letter_new.ogg` |
| Ю | Ю | `ю_letter_tts.wav` | `ю_letter_new.ogg` |
| Я | Я | `я_letter_tts.wav` | `я_letter_new.ogg` |

---

## 2. Слова по буквам (165)

| № | Буква | Набор | Слово (с ударением) | Картинка | Старая озвучка | Новая озвучка |
|:---:|:---:|:---:|---|---|---|---|
| 1 | А | 1 | Авто́бус | `Bus` | `автобус_tts.wav` | `автобус_new.ogg` |
| 2 | А | 2 | Арбу́з | `generated/Watermelon` | `арбуз_tts.wav` | `арбуз_new.ogg` |
| 3 | А | 3 | А́ист | `generated/Stork` | `аист_tts.wav` | `аист_new.ogg` |
| 4 | А | 4 | Анана́с | `generated/Pineapple` | `ананас_tts.wav` | `ананас_new.ogg` |
| 5 | А | 5 | Абрико́с | `generated/Apricot` | `абрикос_tts.wav` | `абрикос_new.ogg` |
| 6 | Б | 1 | Бана́н | `Banana` | `банан_tts.wav` | `банан_new.ogg` |
| 7 | Б | 2 | Бе́лка | `generated/Squirrel` | `белка_tts.wav` | `белка_new.ogg` |
| 8 | Б | 3 | Бо́чка | `generated/Barrel` | `бочка_tts.wav` | `бочка_new.ogg` |
| 9 | Б | 4 | Боти́нок | `generated/Boot` | `ботинок_tts.wav` | `ботинок_new.ogg` |
| 10 | Б | 5 | Бараба́н | `generated/Drum` | `барабан_tts.wav` | `барабан_new.ogg` |
| 11 | В | 1 | Вода́ | `Water` | `вода_tts.wav` | `вода_new.ogg` |
| 12 | В | 2 | Ведро́ | `generated/Bucket` | `ведро_tts.wav` | `ведро_new.ogg` |
| 13 | В | 3 | Во́лк | `generated/Wolf` | `волк_tts.wav` | `волк_new.ogg` |
| 14 | В | 4 | Воро́на | `generated/Crow` | `ворона_tts.wav` | `ворона_new.ogg` |
| 15 | В | 5 | Ва́режки | `generated/Mittens` | `варежки_tts.wav` | `варежки_new.ogg` |
| 16 | Г | 1 | Гусь | `Goose` | `гусь_tts.wav` | `гусь_new.ogg` |
| 17 | Г | 2 | Гриб | `generated/Mushroom` | `гриб_tts.wav` | `гриб_new.ogg` |
| 18 | Г | 3 | Гора́ | `generated/Mountain` | `гора_tts.wav` | `гора_new.ogg` |
| 19 | Г | 4 | Га́лстук | `generated/Tie` | `галстук_tts.wav` | `галстук_new.ogg` |
| 20 | Г | 5 | Гло́бус | `generated/Globe` | `глобус_tts.wav` | `глобус_new.ogg` |
| 21 | Д | 1 | Дом | `House` | `дом_tts.wav` | `дом_new.ogg` |
| 22 | Д | 2 | Де́рево | `generated/Tree` | `дерево_tts.wav` | `дерево_new.ogg` |
| 23 | Д | 3 | Дива́н | `generated/Sofa` | `диван_tts.wav` | `диван_new.ogg` |
| 24 | Д | 4 | Дельфи́н | `generated/Dolphin` | `дельфин_tts.wav` | `дельфин_new.ogg` |
| 25 | Д | 5 | Дя́тел | `generated/Woodpecker` | `дятел_tts.wav` | `дятел_new.ogg` |
| 26 | Е | 1 | Ель | `Christmas_Tree` | `ель_tts.wav` | `ель_new.ogg` |
| 27 | Е | 2 | Ено́т | `generated/Raccoon` | `енот_tts.wav` | `енот_new.ogg` |
| 28 | Е | 3 | Ежеви́ка | `generated/Blackberry` | `ежевика_tts.wav` | `ежевика_new.ogg` |
| 29 | Е | 4 | Ежи́ха | `generated/Hedgehog` | `ежиха_tts.wav` | `ежиха_new.ogg` |
| 30 | Е | 5 | Еда́ | `generated/Food` | `еда_tts.wav` | `еда_new.ogg` |
| 31 | Ё | 1 | Ёж | `Hedgehog` | `ёж_tts.wav` | `ёж_new.ogg` |
| 32 | Ё | 2 | Ёлка | `generated/Fir_Tree` | `ёлка_tts.wav` | `ёлка_new.ogg` |
| 33 | Ё | 3 | Ёрш | `generated/Ruff` | `ёрш_tts.wav` | `ёрш_new.ogg` |
| 34 | Ё | 4 | Ёршик | `generated/Bottle_Brush` | `ёршик_tts.wav` | `ёршик_new.ogg` |
| 35 | Ё | 5 | Ёлочная игрушка | `generated/Christmas_Toy` | `ёлочная игрушка_tts.wav` | `ёлочная игрушка_new.ogg` |
| 36 | Ж | 1 | Жу́к | `Beetle` | `жук_tts.wav` | `жук_new.ogg` |
| 37 | Ж | 2 | Жира́ф | `generated/Giraffe` | `жираф_tts.wav` | `жираф_new.ogg` |
| 38 | Ж | 3 | Жёлудь | `generated/Acorn` | `жёлудь_tts.wav` | `жёлудь_new.ogg` |
| 39 | Ж | 4 | Журна́л | `generated/Magazine` | `журнал_tts.wav` | `журнал_new.ogg` |
| 40 | Ж | 5 | Жемчу́г | `generated/Pearl` | `жемчуг_tts.wav` | `жемчуг_new.ogg` |
| 41 | З | 1 | За́яц | `Hare` | `заяц_tts.wav` | `заяц_new.ogg` |
| 42 | З | 2 | Зонт | `generated/Umbrella` | `зонт_tts.wav` | `зонт_new.ogg` |
| 43 | З | 3 | Звезда́ | `generated/Star` | `звезда_tts.wav` | `звезда_new.ogg` |
| 44 | З | 4 | Зе́бра | `generated/Zebra` | `зебра_tts.wav` | `зебра_new.ogg` |
| 45 | З | 5 | Земляни́ка | `generated/Strawberry` | `земляника_tts.wav` | `земляника_new.ogg` |
| 46 | И | 1 | Игру́шка | `Toy` | `игрушка_tts.wav` | `игрушка_new.ogg` |
| 47 | И | 2 | Индю́к | `generated/Turkey` | `индюк_tts.wav` | `индюк_new.ogg` |
| 48 | И | 3 | Игла́ | `generated/Needle` | `игла_tts.wav` | `игла_new.ogg` |
| 49 | И | 4 | И́рис | `generated/Iris` | `ирис_tts.wav` | `ирис_new.ogg` |
| 50 | И | 5 | Избу́шка | `generated/Hut` | `избушка_tts.wav` | `избушка_new.ogg` |
| 51 | Й | 1 | Йо́гурт | `yogurt` | `йогурт_tts.wav` | `йогурт_new.ogg` |
| 52 | Й | 2 | Йе́ти | `generated/Yeti` | `йети_tts.wav` | `йети_new.ogg` |
| 53 | Й | 3 | Йод | `generated/Iodine` | `йод_tts.wav` | `йод_new.ogg` |
| 54 | Й | 4 | Ча́йник | `generated/Teapot` | `чайник_tts.wav` | `чайник_new.ogg` |
| 55 | Й | 5 | Ча́йка | `generated/Seagull` | `чайка_tts.wav` | `чайка_new.ogg` |
| 56 | К | 1 | Кот | `Cat` | `кот_tts.wav` | `кот_new.ogg` |
| 57 | К | 2 | Каранда́ш | `generated/Pencil` | `карандаш_tts.wav` | `карандаш_new.ogg` |
| 58 | К | 3 | Ку́рица | `generated/Hen` | `курица_tts.wav` | `курица_new.ogg` |
| 59 | К | 4 | Капу́ста | `generated/Cabbage` | `капуста_tts.wav` | `капуста_new.ogg` |
| 60 | К | 5 | Кенгуру́ | `generated/Kangaroo` | `кенгуру_tts.wav` | `кенгуру_new.ogg` |
| 61 | Л | 1 | Луна́ | `Moon` | `луна_tts.wav` | `луна_new.ogg` |
| 62 | Л | 2 | Лиса́ | `generated/Fox` | `лиса_tts.wav` | `лиса_new.ogg` |
| 63 | Л | 3 | Лягу́шка | `generated/Frog` | `лягушка_tts.wav` | `лягушка_new.ogg` |
| 64 | Л | 4 | Лимо́н | `generated/Lemon` | `лимон_tts.wav` | `лимон_new.ogg` |
| 65 | Л | 5 | Ла́сточка | `generated/Swallow` | `ласточка_tts.wav` | `ласточка_new.ogg` |
| 66 | М | 1 | Мяч | `Ball` | `мяч_tts.wav` | `мяч_new.ogg` |
| 67 | М | 2 | Маши́на | `generated/Car` | `машина_tts.wav` | `машина_new.ogg` |
| 68 | М | 3 | Морко́вь | `generated/Carrot` | `морковь_tts.wav` | `морковь_new.ogg` |
| 69 | М | 4 | Му́ха | `generated/Fly` | `муха_tts.wav` | `муха_new.ogg` |
| 70 | М | 5 | Макаро́ны | `generated/Pasta` | `макароны_tts.wav` | `макароны_new.ogg` |
| 71 | Н | 1 | Нос | `Nose` | `нос_tts.wav` | `нос_new.ogg` |
| 72 | Н | 2 | Носо́к | `generated/Sock` | `носок_tts.wav` | `носок_new.ogg` |
| 73 | Н | 3 | Ни́тка | `generated/Thread` | `нитка_tts.wav` | `нитка_new.ogg` |
| 74 | Н | 4 | Но́жницы | `generated/Scissors` | `ножницы_tts.wav` | `ножницы_new.ogg` |
| 75 | Н | 5 | Не́бо | `generated/Sky` | `небо_tts.wav` | `небо_new.ogg` |
| 76 | О | 1 | Окно́ | `Window` | `окно_tts.wav` | `окно_new.ogg` |
| 77 | О | 2 | Обезья́на | `generated/Monkey` | `обезьяна_tts.wav` | `обезьяна_new.ogg` |
| 78 | О | 3 | Очки́ | `generated/Glasses` | `очки_tts.wav` | `очки_new.ogg` |
| 79 | О | 4 | Огуре́ц | `generated/Cucumber` | `огурец_tts.wav` | `огурец_new.ogg` |
| 80 | О | 5 | Осьмино́г | `generated/Octopus` | `осьминог_tts.wav` | `осьминог_new.ogg` |
| 81 | П | 1 | Пода́рок | `Gift` | `подарок_tts.wav` | `подарок_new.ogg` |
| 82 | П | 2 | Парово́з | `generated/Locomotive` | `паровоз_tts.wav` | `паровоз_new.ogg` |
| 83 | П | 3 | Пчела́ | `generated/Bee` | `пчела_tts.wav` | `пчела_new.ogg` |
| 84 | П | 4 | Пету́х | `generated/Rooster` | `петух_tts.wav` | `петух_new.ogg` |
| 85 | П | 5 | Пингви́н | `generated/Penguin` | `пингвин_tts.wav` | `пингвин_new.ogg` |
| 86 | Р | 1 | Рот | `Mouth` | `рот_tts.wav` | `рот_new.ogg` |
| 87 | Р | 2 | Ра́дуга | `raduga` | `радуга_tts.wav` | `радуга_new.ogg` |
| 88 | Р | 3 | Раке́та | `generated/Rocket` | `ракета_tts.wav` | `ракета_new.ogg` |
| 89 | Р | 4 | Ро́бот | `generated/Robot` | `робот_tts.wav` | `робот_new.ogg` |
| 90 | Р | 5 | Руче́й | `generated/Stream` | `ручей_tts.wav` | `ручей_new.ogg` |
| 91 | С | 1 | Сок | `Juice` | `сок_tts.wav` | `сок_new.ogg` |
| 92 | С | 2 | Самолёт | `generated/Airplane` | `самолёт_tts.wav` | `самолёт_new.ogg` |
| 93 | С | 3 | Слон | `generated/Elephant` | `слон_tts.wav` | `слон_new.ogg` |
| 94 | С | 4 | Светофо́р | `generated/Traffic_Light` | `светофор_tts.wav` | `светофор_new.ogg` |
| 95 | С | 5 | Скворе́ц | `generated/Starling` | `скворец_tts.wav` | `скворец_new.ogg` |
| 96 | Т | 1 | Торт | `Cake` | `торт_tts.wav` | `торт_new.ogg` |
| 97 | Т | 2 | Ты́ква | `generated/Pumpkin` | `тыква_tts.wav` | `тыква_new.ogg` |
| 98 | Т | 3 | Телефо́н | `generated/Phone` | `телефон_tts.wav` | `телефон_new.ogg` |
| 99 | Т | 4 | Таре́лка | `generated/Plate` | `тарелка_tts.wav` | `тарелка_new.ogg` |
| 100 | Т | 5 | Тра́ктор | `generated/Tractor` | `трактор_tts.wav` | `трактор_new.ogg` |
| 101 | У | 1 | У́тка | `Duck` | `утка_tts.wav` | `утка_new.ogg` |
| 102 | У | 2 | Ули́тка | `generated/Snail` | `улитка_tts.wav` | `улитка_new.ogg` |
| 103 | У | 3 | У́лей | `generated/Beehive` | `улей_tts.wav` | `улей_new.ogg` |
| 104 | У | 4 | Утю́г | `generated/Iron` | `утюг_tts.wav` | `утюг_new.ogg` |
| 105 | У | 5 | Усы́ | `generated/Whiskers` | `усы_tts.wav` | `усы_new.ogg` |
| 106 | Ф | 1 | Фонта́н | `Fountain` | `фонтан_tts.wav` | `фонтан_new.ogg` |
| 107 | Ф | 2 | Флаг | `generated/Flag` | `флаг_tts.wav` | `флаг_new.ogg` |
| 108 | Ф | 3 | Фи́лин | `generated/Owl` | `филин_tts.wav` | `филин_new.ogg` |
| 109 | Ф | 4 | Фа́ртук | `generated/Apron` | `фартук_tts.wav` | `фартук_new.ogg` |
| 110 | Ф | 5 | Флами́нго | `generated/Flamingo` | `фламинго_tts.wav` | `фламинго_new.ogg` |
| 111 | Х | 1 | Хлеб | `Bread` | `хлеб_tts.wav` | `хлеб_new.ogg` |
| 112 | Х | 2 | Хомя́к | `generated/Hamster` | `хомяк_tts.wav` | `хомяк_new.ogg` |
| 113 | Х | 3 | Хвост | `generated/Tail` | `хвост_tts.wav` | `хвост_new.ogg` |
| 114 | Х | 4 | Хала́т | `generated/Robe` | `халат_tts.wav` | `халат_new.ogg` |
| 115 | Х | 5 | Халва́ | `generated/Halva` | `халва_tts.wav` | `халва_new.ogg` |
| 116 | Ц | 1 | Цыплёнок | `Chicken` | `цыплёнок_tts.wav` | `цыплёнок_new.ogg` |
| 117 | Ц | 2 | Цвето́к | `generated/Flower` | `цветок_tts.wav` | `цветок_new.ogg` |
| 118 | Ц | 3 | Ца́пля | `generated/Heron` | `цапля_tts.wav` | `цапля_new.ogg` |
| 119 | Ц | 4 | Цирк | `generated/Circus` | `цирк_tts.wav` | `цирк_new.ogg` |
| 120 | Ц | 5 | Цепо́чка | `generated/Chain` | `цепочка_tts.wav` | `цепочка_new.ogg` |
| 121 | Ч | 1 | Чай | `Tea` | `чай_tts.wav` | `чай_new.ogg` |
| 122 | Ч | 2 | Часы́ | `generated/Clock` | `часы_tts.wav` | `часы_new.ogg` |
| 123 | Ч | 3 | Черепа́ха | `generated/Turtle` | `черепаха_tts.wav` | `черепаха_new.ogg` |
| 124 | Ч | 4 | Чемода́н | `generated/Suitcase` | `чемодан_tts.wav` | `чемодан_new.ogg` |
| 125 | Ч | 5 | Червя́к | `generated/Worm` | `червяк_tts.wav` | `червяк_new.ogg` |
| 126 | Ш | 1 | Ша́пка | `Hat` | `шапка_tts.wav` | `шапка_new.ogg` |
| 127 | Ш | 2 | Шар | `generated/Balloon` | `шар_tts.wav` | `шар_new.ogg` |
| 128 | Ш | 3 | Ши́шка | `generated/Pinecone` | `шишка_tts.wav` | `шишка_new.ogg` |
| 129 | Ш | 4 | Шарф | `generated/Scarf` | `шарф_tts.wav` | `шарф_new.ogg` |
| 130 | Ш | 5 | Шокола́д | `generated/Chocolate` | `шоколад_tts.wav` | `шоколад_new.ogg` |
| 131 | Щ | 1 | Щено́к | `Puppy` | `щенок_tts.wav` | `щенок_new.ogg` |
| 132 | Щ | 2 | Щётка | `generated/Brush` | `щётка_tts.wav` | `щётка_new.ogg` |
| 133 | Щ | 3 | Щу́ка | `generated/Pike` | `щука_tts.wav` | `щука_new.ogg` |
| 134 | Щ | 4 | Щи | `generated/Shchi` | `щи_tts.wav` | `щи_new.ogg` |
| 135 | Щ | 5 | Щит | `generated/Shield` | `щит_tts.wav` | `щит_new.ogg` |
| 136 | Ъ | 1 | Объявле́ние | `announcement` | `объявление_tts.wav` | `объявление_new.ogg` |
| 137 | Ъ | 2 | Подъе́зд | `generated/Entrance` | `подъезд_tts.wav` | `подъезд_new.ogg` |
| 138 | Ъ | 3 | Объя́тие | `generated/Hug` | `объятие_tts.wav` | `объятие_new.ogg` |
| 139 | Ъ | 4 | Съёмка | `generated/Filming` | `съёмка_tts.wav` | `съёмка_new.ogg` |
| 140 | Ъ | 5 | Подъёмник | `generated/Lift` | `подъёмник_tts.wav` | `подъёмник_new.ogg` |
| 141 | Ы | 1 | Мы́ло | `Soap` | `мыло_tts.wav` | `мыло_new.ogg` |
| 142 | Ы | 2 | Сыр | `generated/Cheese` | `сыр_tts.wav` | `сыр_new.ogg` |
| 143 | Ы | 3 | Дым | `generated/Smoke` | `дым_tts.wav` | `дым_new.ogg` |
| 144 | Ы | 4 | Рысь | `generated/Lynx` | `рысь_tts.wav` | `рысь_new.ogg` |
| 145 | Ы | 5 | Мышь | `generated/Mouse` | `мышь_tts.wav` | `мышь_new.ogg` |
| 146 | Ь | 1 | Конь | `Horse` | `конь_tts.wav` | `конь_new.ogg` |
| 147 | Ь | 2 | Медве́дь | `generated/Bear` | `медведь_tts.wav` | `медведь_new.ogg` |
| 148 | Ь | 3 | Оле́нь | `generated/Deer` | `олень_tts.wav` | `олень_new.ogg` |
| 149 | Ь | 4 | Дверь | `generated/Door` | `дверь_tts.wav` | `дверь_new.ogg` |
| 150 | Ь | 5 | Тюле́нь | `generated/Seal` | `тюлень_tts.wav` | `тюлень_new.ogg` |
| 151 | Э | 1 | Экра́н | `Screen` | `экран_tts.wav` | `экран_new.ogg` |
| 152 | Э | 2 | Эскала́тор | `generated/Escalator` | `эскалатор_tts.wav` | `эскалатор_new.ogg` |
| 153 | Э | 3 | Э́му | `generated/Emu` | `эму_tts.wav` | `эму_new.ogg` |
| 154 | Э | 4 | Электри́чка | `generated/Electric_Train` | `электричка_tts.wav` | `электричка_new.ogg` |
| 155 | Э | 5 | Эскимо́ | `generated/Popsicle` | `эскимо_tts.wav` | `эскимо_new.ogg` |
| 156 | Ю | 1 | Юла́ | `Spinning_Top` | `юла_tts.wav` | `юла_new.ogg` |
| 157 | Ю | 2 | Ю́бка | `generated/Skirt` | `юбка_tts.wav` | `юбка_new.ogg` |
| 158 | Ю | 3 | Юг | `generated/South` | **НЕТ** | **НЕТ** |
| 159 | Ю | 4 | Юпи́тер | `generated/Jupiter` | `юпитер_tts.wav` | `юпитер_new.ogg` |
| 160 | Ю | 5 | Ю́рта | `generated/Yurt` | `юрта_tts.wav` | `юрта_new.ogg` |
| 161 | Я | 1 | Я́блоко | `Apple` | `яблоко_tts.wav` | `яблоко_new.ogg` |
| 162 | Я | 2 | Я́года | `generated/Berry` | `ягода_tts.wav` | `ягода_new.ogg` |
| 163 | Я | 3 | Я́корь | `generated/Anchor` | `якорь_tts.wav` | `якорь_new.ogg` |
| 164 | Я | 4 | Я́щерица | `generated/Lizard` | `ящерица_tts.wav` | `ящерица_new.ogg` |
| 165 | Я | 5 | Я́хта | `generated/Yacht` | `яхта_tts.wav` | `яхта_new.ogg` |

---

## 3. Звуки-промпты и музыка

| Файл | Роль | Текст / примечание | Где играется |
|---|---|---|---|
| `assets/audio/hint_find_letter.wav` | подсказка при открытии карточки буквы | «Найди и нажми на букву» (переозвучена 2026-09-21) | `letter_card.gd:28`, вызов `:472` |
| `assets/audio/prompt_correct.wav` | похвала за верный ответ | «Молодец!» (переозвучена 2026-09-22) | `letter_card.gd:26/:543`, `find_letter.gd:36/:322`, `guess_picture.gd:15/:196` |
| `assets/audio/prompt_forward.wav` | промпт «дальше» после записи | «Молодец! Нажми ›» (создан 2026-09-21) | `letter_card.gd:27`, вызов `:564` |
| `assets/audio/music/menu_theme.ogg` | фоновая музыка главного меню | инструментал | `main_menu.gd:30` |
| (нет файла) | звук ошибки | синтезируется кодом (тон) | `find_letter.gd:335`, `guess_picture.gd:219`, `collect_word.gd:421` |

---

## 4. Сообщения интерфейса

Все видимые пользователю русские строки. «Озвучка» — играет ли рядом звук; сами строки озвучиваются только если указано обратное.

### Главное меню

_`ui/main_menu/`_

| Текст (с ударением) | Где | Элемент | Озвучка |
|---|---|---|---|
| А́збука | `main_menu.tscn:46` | TitleLabel — заголовок | только текст |
| А́збука | `main_menu.tscn:55` | кнопка игры «Азбука» | только текст |
| Найди́ бу́кву | `main_menu.tscn:64` | кнопка игры | только текст |
| Собери́ сло́во | `main_menu.tscn:73` | кнопка игры | только текст |
| Угада́й бу́кву | `main_menu.tscn:82` | кнопка игры | только текст |
| ⚙ (без текста) | `main_menu.tscn:96` | кнопка настроек | — |

### Экран «Азбука» (змейка)

_`ui/games/azbuka/azbuka.tscn`, `azbuka.gd`_

| Текст (с ударением) | Где | Элемент | Озвучка |
|---|---|---|---|
| А́збука | `azbuka.tscn:63` | TitleLabel | только текст |
| 🏠 | `azbuka.tscn:99` | кнопка «Домой» | — |
| ‹ Наза́д | `back_button.tscn:9` | кнопка «Назад» | только текст |
| А … Я (33 буквы) | `azbuka.gd:126` | кружки-кнопки змейки | только текст |

### Карточка буквы

_`ui/games/azbuka/letter_card.tscn`, `letter_card.gd`_

| Текст (с ударением) | Где | Элемент | Озвучка |
|---|---|---|---|
| Бу́ква | `letter_card.tscn:100` | кнопка «озвучить букву» | аудио буквы по нажатию |
| Сло́во | `letter_card.tscn:112` | кнопка «озвучить слово» | аудио слова по нажатию |
| Микрофо́н | `letter_card.tscn:126; letter_card.gd:354/374/554` | кнопка записи | только текст |
| За́пись… | `letter_card.gd:360/548` | кнопка записи во время записи | только текст |
| Слу́шать | `letter_card.tscn:141` | воспроизведение записи ребёнка | играет запись |
| ‹ / › | `letter_card.tscn:153/167` | предыдущая / следующая буква | только текст |
| 🏠 | `letter_card.tscn:186` | кнопка «Домой» | — |
| ‹ Наза́д | `back_button.tscn:9` | кнопка «Назад» | только текст |
| Найди́ бу́кву «X» в сло́ве | `letter_card.gd:459/538` | HintLabel — подсказка карточки | hint_find_letter.wav при открытии |
| Скажи́ всё сло́во! | `letter_card.gd:517` | HintLabel — буква выбрана верно | prompt_correct.wav |
| Попро́буй ещё! | `letter_card.gd:532` | HintLabel — неверная буква | только текст (бип) |
| За́пись не получи́лась. Прове́рь микрофо́н. | `letter_card.gd:557` | HintLabel — пустая запись | только текст |
| Молоде́ц! Нажми́ › | `letter_card.gd:562` | HintLabel — запись сохранена | prompt_forward.wav (создан 2026-09-21) |
| Аа, Бб, … | `letter_card.gd:423` | большая буква + строчная | только текст |
| MIC | `letter_card.gd:762` | индикатор уровня микрофона | только текст |
| буквы слова | `letter_card.gd:496` | квадраты мини-игры «собери слово» | prompt_correct.wav при верном выборе |

### Игра «Найди букву»

_`ui/games/find_letter/find_letter.tscn`, `find_letter.gd`_

| Текст (с ударением) | Где | Элемент | Озвучка |
|---|---|---|---|
| Найди́ бу́кву | `find_letter.tscn:46` | TitleLabel | только текст |
| Нажми́ на карти́нку и вы́бери бу́кву | `find_letter.tscn:54; find_letter.gd:165` | HintLabel | только текст |
| Гото́вы игра́ть? | `find_letter.tscn:67` | ReadyTitleLabel | только текст |
| Нача́ть | `find_letter.tscn:76` | кнопка старта | только текст |
| Ка́рточка N из M | `find_letter.tscn:91 (заглушка); find_letter.gd:160` | CardNumberLabel | аудио буквы по клику на картинку |
| буквы на квадратах | `find_letter.gd:199` | 4 кнопки-буквы | аудио буквы по клику на картинку |
| Молоде́ц! | `find_letter.gd:323` | HintLabel — верный ответ | prompt_correct.wav |
| Попро́буй ещё! | `find_letter.gd:336` | HintLabel — неверный ответ | только текст (бип) |
| Вы прошли́ все ка́рточки | `find_letter.tscn:153` | CompletionTitleLabel | только текст |
| Нача́ть за́ново? | `find_letter.tscn:159` | CompletionQuestionLabel | только текст |
| Да | `find_letter.tscn:173` | кнопка «Да» | только текст |
| Нет | `find_letter.tscn:181` | кнопка «Нет» | только текст |
| ‹ / › | `find_letter.tscn:192/206` | предыдущая / следующая карточка | только текст |
| 🏠 | `find_letter.tscn:224` | кнопка «Домой» | — |

### Игра «Угадай букву»

_`ui/games/guess_picture/guess_picture.tscn`, `guess_picture.gd`_

| Текст (с ударением) | Где | Элемент | Озвучка |
|---|---|---|---|
| Ра́унд N / M | `guess_picture.tscn:47 (заглушка); guess_picture.gd:116` | RoundLabel | аудио буквы в начале раунда |
| Счёт: N | `guess_picture.tscn:54; guess_picture.gd:117/185` | ScoreLabel | только текст |
| слова-ответы | `guess_picture.gd:111` | 4 кнопки-ответа | только текст |
| Молоде́ц! | `guess_picture.gd:21/189` | StatusLabel — верный ответ | prompt_correct.wav |
| Попро́буй ещё! | `guess_picture.gd:23/212` | StatusLabel — неверный ответ | только текст (бип) |
| Игра́ око́нчена! | `guess_picture.tscn:133; guess_picture.gd:226` | FinaleLabel | только текст |
| Ваш счёт: N / M | `guess_picture.gd:227` | FinaleScoreLabel | только текст |
| Игра́ть ещё | `guess_picture.tscn:148` | кнопка «Играть ещё» | только текст |
| 🏠 | `guess_picture.tscn:165` | кнопка «Домой» | — |

### Игра «Собери слово»

_`ui/games/collect_word/collect_word.tscn`, `collect_word.gd`_

| Текст (с ударением) | Где | Элемент | Озвучка |
|---|---|---|---|
| Собери́ сло́во | `collect_word.tscn:47` | HeaderLabel | только текст |
| Собери́ сло́во из букв | `collect_word.tscn:82; collect_word.gd:16/164` | StatusLabel | аудио слова через 0.8 с |
| Попро́буй ещё! | `collect_word.gd:18/241` | StatusLabel — неверная буква | только текст (гудок) |
| буквы в пуле | `collect_word.gd:156` | кнопки букв | аудио буквы при верном выборе |
| ‹ / › | `collect_word.tscn:93/107` | предыдущее / следующее слово | только текст |
| 🏠 | `collect_word.tscn:124` | кнопка «Домой» | — |

### Настройки

_`ui/settings/settings.tscn`, `settings.gd`_

| Текст (с ударением) | Где | Элемент | Озвучка |
|---|---|---|---|
| Настро́йки | `settings.tscn:46` | TitleLabel | только текст |
| До́лжен быть включён хотя́ бы 1 режи́м игры́ | `settings.tscn:54` | WarningLabel (показывается 3 с) | только текст |
| А́збука | `settings.tscn:72` | чекбокс режима | только текст |
| Найди́ бу́кву | `settings.tscn:94` | чекбокс режима | только текст |
| Собери́ сло́во | `settings.tscn:108` | чекбокс режима | только текст |
| Угада́й бу́кву | `settings.tscn:122` | чекбокс режима | только текст |
| Сбро́сить | `settings.tscn:80` | кнопка сброса | только текст |
| Ка́рточек в се́рии: | `settings.tscn:139` | подпись | только текст |
| Набо́р слов: | `settings.tscn:167` | подпись | только текст |
| 1 2 3 4 5 | `settings.tscn:175/185/194/203/212` | кнопки выбора набора | только текст |
| Озву́чка: | `settings.tscn:229` | подпись | только текст |
| Ста́рая | `settings.tscn:238` | кнопка «старая озвучка» | только текст |
| Но́вая | `settings.tscn:249` | кнопка «новая озвучка» | только текст |
| Те́ма: све́тлая / Те́ма: тёмная | `settings.tscn:259; settings.gd:237-240` | кнопка темы | только текст |
| Поддержа́ть прое́кт | `settings.tscn:268` | кнопка доната | только текст |
| О́тзыв | `settings.tscn:277` | кнопка обратной связи | только текст |
| Сброс прогре́сса | `settings.tscn:287` | диалог — заголовок | только текст |
| Сбро́сить весь прогре́сс по а́збуке? | `settings.tscn:292` | диалог — текст | только текст |
| Сбро́сить | `settings.tscn:290` | диалог — подтверждение | только текст |
| Отме́на | `settings.tscn:291` | диалог — отмена | только текст |
| ‹ Наза́д | `back_button.tscn:9` | кнопка «Назад» | только текст |

### Экран для взрослых (родительский гейт)

_`ui/parental_gate/`_

| Текст (с ударением) | Где | Элемент | Озвучка |
|---|---|---|---|
| Э́то экра́н для взро́слых | `parental_gate.tscn:37` | TitleLabel | только текст |
| Ско́лько бу́дет N + M? | `parental_gate.tscn:45; parental_gate.gd:73` | QuestionLabel | только текст |
| числа-ответы | `parental_gate.tscn:61/70/79; parental_gate.gd:77` | 3 кнопки-ответа | только текст |
| Ве́рно! | `parental_gate.gd:133` | ResultLabel | только текст |
| ✕ Закры́ть | `parental_gate.tscn:100` | кнопка «Закрыть» | только текст |

### Попап доната

_`ui/donate/donate_overlay.tscn`_

| Текст (с ударением) | Где | Элемент | Озвучка |
|---|---|---|---|
| Поддержа́ть прое́кт | `donate_overlay.tscn:51` | TitleLabel | только текст |
| CloudTips | `donate_overlay.tscn:60` | кнопка перехода | только текст |
| Закры́ть | `donate_overlay.tscn:69` | кнопка «Закрыть» | только текст |

### Обратная связь

_`ui/feedback/feedback.tscn`_

| Текст (с ударением) | Где | Элемент | Озвучка |
|---|---|---|---|
| Обра́тная связь | `feedback.tscn:46` | TitleLabel | только текст |
| Помоги́ нам сде́лать игру́ лу́чше. Расскажи́, что понра́вилось, а что мо́жно улучши́ть. Спаси́бо за твой о́тзыв! | `feedback.tscn:54` | DescriptionLabel | только текст |
| Отпра́вить о́тзыв | `feedback.tscn:64` | кнопка отправки | только текст |
| ‹ Наза́д | `back_button.tscn:9` | кнопка «Назад» | только текст |

---

## 5. Подписи для скринридеров (`accessibility_name`)

Не видны визуально, но читаются экранным диктором. Не озвучиваются проектом.

`Настройки`, `Прослушать букву`, `Прослушать слово`, `Записать голос`, `Прослушать запись`,
`Предыдущая буква`, `Следующая буква`, `Назад к азбуке`, `Домой`, `Начать игру`, `Картинка слова`,
`Предыдущая карточка`, `Следующая карточка`, `Предыдущее слово`, `Следующее слово`,
`Ответ: …`, `Слот слова N`, `Буква X`, `Набор слов 1-5`, `Старая озвучка`, `Новая озвучка`,
`Переключить тему`, `Сбросить прогресс`, `Ответ 1/2/3`, `Закрыть`, `Назад`.

---

## 6. Требует внимания (проверено)

### Исправлено

1. **`prompt_forward.wav`** — отсутствовал (оставался только `prompt_forward.wav.bak`). Создан заново: Silero kseniya, PCM16 22050 Hz mono, 2.00 с, текст «Молоде́ц! Нажми́ да́льше» (как `prompt_correct.wav`). Старый `prompt_forward.wav.bak` не тронут.
2. **`ё_letter_new.ogg`** — отсутствовал, при «Новой озвучке» название буквы «Ё» не проигрывалось. Создан (см. примечание в разделе 1).
3. **«Юг» (буква Ю, набор 3)** — был единственным словом из 165 без `word_audio`. Добавлен `word_audio: res://assets/audio/юг_tts.wav`; созданы `юг_tts.wav` (старая схема) и `юг_new.ogg` (новая). Теперь **все 165 слов** озвучены в обоих режимах.

4. **Перегенерация всей новой озвучки** — 2026-09-21 все **198** файлов `*_new.ogg` перегенерированы локальным Silero голосом `kseniya` в логопедическом темпе **0.7** (было 0.8), «как логопед для детей 2 лет»: `scripts/silero_regenerate_new_ogg.py`. Проверено: 198/198 vorbis 24000 Hz mono, битых 0, длительность выросла на ~14 % (0.8/0.7). Бэкап прежнего звучания — `_audio_legacy_archive/prev_new_ogg_before_regen_2026-09-21/`.
5. **Легаси-аудио заархивировано (пока не удалено)** — **119** файлов, недостижимых из кода, перенесены в `_audio_legacy_archive/legacy_unreachable/` вместе со своими `.import`. Папка помечена `.gdignore` — Godot её полностью игнорирует. Состав:
   - 72 — те же слова, что в текущих 165, но под старым именем файла (`автобус.wav` при живом `автобус_tts.wav`);
   - 33 — старая озвучка букв `{буква}_letter.ogg`;
   - 13 — слова, которых в текущих 5 наборах нет вообще: ириска, лось, носорог, подъехала (только `.wav`), рыба, сова, тигр;
   - 1 — `prompt_forward.wav.bak`.
6. **Попытка регенерации с завершающей «точкой» (откатена)** — 2026-09-22 была сделана попытка перегенерировать все 198 файлов с `APPEND_PERIOD` («.» в конце текста). Попытка **полностью откачена**: точка делает Silero заметно тише («Бэ.» max=−20.3 dB против «Бэ» max=−6.9 dB) и длиннее. Дополнительно вскрылось, что Silero на запросе `sample_rate=24000` звучит на ~4 dB тише, чем на `48000` (Вэ: −6.7 против −2.7 dB), а все «хорошие» файлы регена 21.09 делались через 48000. Итоговый рецепт (зашит в скрипт): **bare text без знаков, TTS-запрос 48000 Hz, ogg 24000 Hz, atempo 0.7**.
7. **7 букв «последнего прохода» перегенерированы** — 2026-09-22: `а, б, д, и, о, ы, э` (`*_letter_new.ogg`) перегенерированы этим рецептом: 7/7 без ошибок, mean −16.2…−19.3 dB (эталон GOOD 21.09: −17.6…−20.2), длительности 0.29–0.61 c (= raw/0.7). Godot-импорт чистый. Остальные 191 файл не тронуты.
8. **`prompt_correct.wav` переозвучен** — 2026-09-22: Silero kseniya, PCM16 22050 Hz mono, 0.86 с, текст «Молоде́ц!» (голос тот же, что у остальной новой озвучки; раньше файл был старой записью).

### Остаётся

9. **Звука ошибки нет как файла** — синтезируется кодом (тон) в трёх играх. Так и задумано.
10. **Аномалия:** `а_letter_tts.wav` длится 16.06 с (у остальных букв — доли секунды). Похоже на битый файл старой озвучки буквы «А»; в новой озвучке ему соответствует корректный `а_letter_new.ogg`.

> **Уточнение прежнего отчёта:** `default_bus_layout.tres` ошибочно назывался легаси-файлом. Это **не аудио и не мусор** — он прописан в `project.godot:26` (`bus/default_bus_layout`) и остаётся рабочим конфигом проекта. Поэтому в архив он не попал: файлов 119, а не 120.



---

_Сгенерировано из `content/alphabet_data.json`; строки интерфейса сверены с кодом по file:line._
