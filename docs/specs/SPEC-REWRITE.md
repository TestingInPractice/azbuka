# СПЕЦИФИКАЦИЯ: Переписывание игры «Азбука» (SPEC-REWRITE)

- **Версия:** 1.0
- **Статус:** черновик (на утверждение)
- **Движок:** Godot 4.6 (gl_compatibility)
- **Основание:** `docs/specs/tz-complete.md` (ТЗ v2.0, финальное), `docs/specs/goals.md` (цели V2), отчёт ревизии фактического кода (2026-08-03)
- **Процесс:** Build Loop (см. `AGENTS.md`) — спека является источником истины для декомпозиции на фазы

---

## 1. Цель и контекст

### 1.1 Почему переписываем

Текущая кодовая база разрабатывалась итеративно (V1 → V2) и содержит:

1. **Неструктурированный код** — экраны, скрипты и синглтоны лежат плоским списком (`scenes/`, `scripts/`), функционал не сгруппирован по папкам.
2. **Слабую наблюдаемость** — логгер появился поздно, покрывает не все переходы; ряд ошибок (серый фон в веб-экспорте, `Error opening file 'res://assets/images/Banana.png'`) было трудно диагностировать.
3. **Мёртвый код** — `main_menu.tscn` (недостижим, `go_to_main_menu()` нигде не вызывается), `letter_card.tscn` (не подключена), `responsive.gd` (не используется), `alphabet_screen.gd` (удалён, остался `.uid`).
4. **Расхождения ТЗ ↔ код** — слова в AlphabetData отличаются от ТЗ (см. § 9.2).

### 1.2 Что сохраняем (не трогаем)

| Ресурс | Объём | Решение |
|--------|-------|---------|
| Изображения | 97 файлов (PNG/JPG) | Переносим как есть, путей не меняем |
| Аудио | 220 файлов (121 WAV + 66 OGG + 33 RAW) | Переносим как есть |
| Шрифт | `NotoSans-Regular.ttf` | Переносим |
| Функционал | Все экраны и мини-игры | Воспроизводим 1:1 по ТЗ |
| Форматы данных | `progress.json`, `settings.json` | Сохраняем (совместимость прогресса) |

### 1.3 Что меняем

1. **Структура кода** — функционал группируется по папкам (§ 3).
2. **Логирование** — единый логгер с каналами и структурированными событиями (§ 4).
3. **Отладка** — MCP-сервер, диагностика ресурсов, телеметрия переходов (§ 5).
4. **Мёртвый код удаляем** — `main_menu`, `letter_card`, `responsive`, `alphabet_screen` не переносим.

---

## 2. Нефункциональные требования (NFR)

| # | Требование | Значение |
|---|-----------|----------|
| NFR-1 | Видеопоток | 60 FPS, без просадок на средних устройствах |
| NFR-2 | Viewport | 1080×1920 portrait, stretch=canvas_items, aspect=expand, initial 540×960 |
| NFR-3 | Рендер | `gl_compatibility` |
| NFR-4 | Хранилище | < 60 МБ (без учёта .godot) |
| NFR-5 | Платформы | Web (PWA), Android, iOS, macOS |
| NFR-6 | Микрофон | Android: `RECORD_AUDIO`, iOS: `Microphone` |
| NFR-7 | Аудиозапись | WAV PCM16, моно, частота = AudioServer mix rate |
| NFR-8 | **Логируемость** | Каждый переход экрана и каждое действие игрока фиксируются логгером (§ 4) |
| NFR-9 | **Отлаживаемость** | MCP-сервер доступен в dev-сборках; экспорт с debug-символами для веба (§ 5) |
| NFR-10 | **Модульность** | Каждый экран — самодостаточная папка (сцена + скрипт + свои компоненты) |

---

## 3. Архитектура

### 3.1 Структура папок (ГЛАВНОЕ ТРЕБОВАНИЕ — «функционал по папкам»)

```
res://
├── project.godot
├── export_presets.cfg
├── autoload/                    # глобальные синглтоны
│   ├── global.gd                # навигация + утилиты (sparkle)
│   ├── audio_manager.gd         # звуки букв/слов
│   ├── theme_manager.gd         # темы светлая/тёмная
│   ├── progress_manager.gd      # прогресс + режимы
│   ├── alphabet_data.gd         # данные 33 букв
│   └── logger.gd                # GameLogger (уровни, каналы, хендлеры)
├── logging/                     # система логирования
│   ├── log_level.gd
│   ├── log_entry.gd
│   └── handlers/
│       ├── log_handler.gd
│       ├── console_handler.gd
│       └── file_handler.gd
├── core/                        # переиспользуемая доменная логика (без UI)
│   ├── fx/
│   │   └── sparkle.gd           # эффект правильного ответа
│   └── audio/
│       └── error_beep.gd        # программный beep ошибки (300Hz)
├── screens/                     # ЭКРАНЫ — по одному на папку
│   ├── start_screen/
│   │   ├── start_screen.tscn
│   │   ├── start_screen.gd
│   │   ├── donate_overlay.tscn  # донат-диалог (СБП + ЮMoney)
│   │   └── donate_overlay.gd
│   ├── roadmap/                 # карта-змейка
│   │   ├── roadmap_screen.tscn
│   │   ├── roadmap_screen.gd
│   │   ├── roadmap_path.gd      # отрисовка линии-змейки
│   │   └── cat_character.gd     # персонаж-кот
│   ├── letter_detail/           # страница буквы
│   │   ├── letter_detail.tscn
│   │   ├── letter_detail.gd
│   │   └── voice_recorder.gd    # запись/воспроизведение голоса
│   ├── settings/
│   │   ├── settings_screen.tscn
│   │   └── settings_screen.gd
│   └── games/                   # мини-игры
│       ├── find_letter/
│       │   ├── game_find_letter.tscn
│       │   └── game_find_letter.gd
│       ├── collect_word/
│       │   ├── game_collect_word.tscn
│       │   └── game_collect_word.gd
│       └── guess_picture/
│           ├── game_guess_picture.tscn
│           └── game_guess_picture.gd
├── components/                  # переиспользуемые компоненты UI
│   ├── forest_background/
│   │   ├── forest_background.tscn      # дальний план (roadmap)
│   │   ├── forest_background_close.tscn # крупный план (letter_detail)
│   │   └── forest_background.gd
│   └── styled_button.gd         # фабрика кнопок ThemeManager.style_button
├── debug/                       # ОТЛАДОЧНЫЕ ИНСТРУМЕНТЫ
│   ├── mcp_server.gd            # TCP-сервер 127.0.0.1:9090 (JSON-команды)
│   └── asset_diag.gd            # проверка путей ресурсов (texture_diag)
└── assets/
    ├── images/                  # 97 файлов — ПЕРЕНОСИМ КАК ЕСТЬ
    ├── audio/                   # 220 файлов — ПЕРЕНОСИМ КАК ЕСТЬ
    └── fonts/NotoSans-Regular.ttf
```

**Правила структуры:**
- Экран = папка в `screens/` со сценой, скриптом и локальными компонентами.
- Общее между экранами → `components/` (фоны) или `core/` (логика без UI).
- Синглтоны — только в `autoload/`.
- Отладка изолирована в `debug/` и не влияет на геймплей.

### 3.2 Синглтоны (autoload) — контракты

Порядок регистрации в `project.godot` [autoload] (важен для зависимостей):

> Порядок = порядок инициализации в Godot: синглтон доступен только ПОСЛЕ своей регистрации, поэтому сначала идут без зависимостей.

| # | Имя | Скрипт | Зависит от |
|---|-----|--------|-----------|
| 1 | `GameLogger` | autoload/logger.gd | — |
| 2 | `AlphabetData` | autoload/alphabet_data.gd | — |
| 3 | `ThemeManager` | autoload/theme_manager.gd | GameLogger |
| 4 | `ProgressManager` | autoload/progress_manager.gd | GameLogger |
| 5 | `AudioManager` | autoload/audio_manager.gd | ThemeManager, AlphabetData |
| 6 | `Global` | autoload/global.gd | AlphabetData, GameLogger |

> `McpInteractionServer` — **НЕ** autoload в проде. Инстанцируется только в dev-режиме (см. § 5.2).

#### 3.2.1 GameLogger — API (расширяется)
```gdscript
# Уровни: DEBUG=0, INFO=1, WARN=2, ERROR=3 (см. log_level.gd)
GameLogger.debug(channel: String, message: String, data: Dictionary = {})
GameLogger.info(channel: String, message: String, data: Dictionary = {})
GameLogger.warn(channel: String, message: String, data: Dictionary = {})
GameLogger.error(channel: String, message: String, data: Dictionary = {})
GameLogger.set_min_level(level: int)
GameLogger.texture_diag(channel: String, label: String, path: String)  # диагностика ресурса
```
Полный контракт каналов и событий — § 4.

#### 3.2.2 Global
- Свойства: `current_letter_data: Dictionary`, `last_visited_letter: String`, `letter_names: Dictionary` (33 пары «буква → название», см. ТЗ § 2.1).
- Навигация (каждый переход ЛОГИРУЕТСЯ, § 4.2):
  - `go_to_letter_detail(letter)` — ставит `current_letter_data`, инстанцирует `screens/letter_detail/letter_detail.tscn`, передаёт `letter` и `letter_name`.
  - `go_to_game_find_letter()`, `go_to_collect_word()`, `go_to_game_guess_picture()`
  - `go_to_roadmap()`, `go_to_settings()`, `go_to_start_screen()`
  - `switch_scene(new_scene: Node)` — add_child → current_scene → queue_free старой (анти-фликкер: скрыть перед добавлением).
- `sparkle_at(pos: Vector2, parent: Node)` — 6 символов ✦★●♥♦, 5 цветов, tween (позиция 0.6s TRANS_BACK, scale→2.0, fade 0.6s), queue_free 0.7s. Переносится в `core/fx/sparkle.gd` (статический метод).

#### 3.2.3 AlphabetData
- `DATA: Array[Dictionary]` — 33 записи: `letter`, `word`, `word_lower`, `image_path`.
- **Фактический список (из кода, расходится с ТЗ):**

| Буква | Слово | Буква | Слово |
|-------|-------|-------|-------|
| А | Автобус | П | Подарок ⚠️ |
| Б | Банан | Р | Рот |
| В | Вода | С | Сок |
| Г | Гусь | Т | Торт |
| Д | Дом | У | Утка |
| Е | Ель ⚠️ | Ф | Фонтан |
| Ё | Ёж ⚠️ | Х | Хлеб |
| Ж | Жук | Ц | Цыплёнок |
| З | Заяц | Ч | Чай |
| И | Игрушка | Ш | Шапка |
| Й | Йогурт | Щ | Щенок |
| К | Кот | Ъ | Объявление ⚠️ |
| Л | Луна | Ы | Мыло |
| М | Мяч | Ь | Конь |
| Н | Нос | Э | Экран |
| О | Окно | Ю | Юла |
| | | Я | Яблоко |

⚠️ — расхождения с таблицей ТЗ § 2.5 (ТЗ: Е/Еж, Ё/Ёлка, П/Пирог, Ъ/Объём). **Решение:** берём ФАКТИЧЕСКИЙ список (соответствует аудио- и картинкам на диске).
- `get_letter_data(letter: String) → Dictionary` — поиск по `entry.letter`, возврат `duplicate()`.
- **Требование верификации:** в фазе ассетов проверить, что каждый `image_path` существует (источник бага `Banana.png`).

#### 3.2.4 AudioManager
- Один `AudioStreamPlayer2D`, кеш `_stream_cache`.
- `play_letter(letter_id)` → `res://assets/audio/{lower(letter)}_letter_tts.wav` (существующие файлы `а_letter_tts.wav` …).
- `play_word(letter_id)` → `res://assets/audio/{word_lower}_tts.wav` (например `автобус_tts.wav`).
- `play_prompt(path)` — `hint_find_letter.wav`, `prompt_correct.wav`, `prompt_forward.wav`.
- `stop_all()`, `is_playing()`.
- Уважает `ThemeManager.sound_enabled`; в вебе — `_resume_web_audio()` (AudioContext).
- Все воспроизведения логируются (§ 4.2, канал `audio`).

#### 3.2.5 ThemeManager
- Сигналы: `theme_changed(theme_name)`, `sound_toggled(enabled)`.
- Константы: light `bg=#FFF5E6 card=#FFFFFF text=#333333`; dark `bg=#1A1A2E card=#16213E text=#E0E0E0`.
- `toggle_theme()`, `get_bg()`, `get_card_bg()`, `get_text()`, `apply_theme()`, `load_settings()/save_settings()` (`user://settings.json`).
- `style_button(btn, bg_color, font_color=WHITE, corner_radius=20)` — единая стилизация (normal/hover/pressed StyleBoxFlat + тень).
- `_ready()`: `ThemeDB.fallback_font = NotoSans-Regular.ttf`.

#### 3.2.6 ProgressManager
- Сигнал: `enabled_modes_changed`.
- Данные: `completed_letters: Array[String]`, `games_played: int`, `last_played: String`, `errored_letters: Array[String]`, `enabled_modes: Dictionary` (keys: `alphabet`, `find_letter`, `collect_word`, `guess_picture`), `TOTAL_LETTERS = 33`.
- `load_progress()/save_progress()` (`user://progress.json`), `mark_letter_completed(letter)`, `mark_game_played()`, `mark_letter_errored(letter)`, `is_letter_completed(letter)`, `is_letter_errored(letter)`, `get_completed_count()`, `is_mode_enabled(mode)`, `set_mode_enabled(mode, value)`, `get_enabled_modes_count()`, `reset_progress()`.
- **Новое:** каждое изменение прогресса логируется (канал `progress`) — цель: можно восстановить, что произошло, из лога.

### 3.3 Карта навигации (целевая)

```
start_screen ──«Азбука»──→ roadmap ──клик точки──→ letter_detail ──Назад/стрелки──→ roadmap
     │                          │                       │ (авто: кот идёт, потом detail)
     ├──«Найди букву»──→ game_find_letter ──итог/Назад──→ start_screen
     ├──«Собери слово»──→ game_collect_word ──итог/Назад──→ start_screen
     ├──«Угадай картинку»──→ game_guess_picture ──итог/Назад──→ start_screen
     └──«*»──→ settings ──Назад──→ start_screen
                  └──Сброс прогресса──→ roadmap
```

- `main_menu`, `alphabet_screen` — **не переносим** (мёртвый код).
- Начальная сцена проекта: `res://screens/start_screen/start_screen.tscn`.

---

## 4. Логирование (КЛЮЧЕВОЕ ТРЕБОВАНИЕ)

### 4.1 Принципы

1. **Единый логгер** — только `GameLogger` (никаких `print()` в геймплейном коде).
2. **Каналы** — каждое сообщение имеет канал; фильтрация и поиск по каналу.
3. **Уровни** — DEBUG < INFO < WARN < ERROR; минимальный уровень настраивается.
4. **Структурированность** — данные в `data: Dictionary` → сериализация в JSON.
5. **Два хендлера** — console (всегда) + file (`user://logs/azbuka.log`, только не-web).

### 4.2 Каналы и события (обязательный минимум)

| Канал | Событие | Пример вызова |
|-------|---------|---------------|
| `nav` | Переход экрана | `GameLogger.info("nav", "switch_scene", {"from": from_scene, "to": to_scene})` |
| `nav` | Навигация по буквам (Prev/Next) | `GameLogger.info("nav", "letter_navigate", {"direction": "next", "from": "А", "to": "Б"})` |
| `screen` | Жизненный цикл экрана | `GameLogger.info("screen", "ready", {"scene": "letter_detail", "letter": "А"})` |
| `screen` | Выход из экрана | `GameLogger.info("screen", "exit", {"scene": "roadmap"})` |
| `input` | Ключевое действие игрока | `GameLogger.info("input", "dot_clicked", {"letter": "Г", "index": 3})` |
| `game` | Раунд мини-игры | `GameLogger.info("game", "round_start", {"game": "find_letter", "round": 1, "answer": "А"})` |
| `game` | Правильный/неправильный ответ | `GameLogger.info("game", "answer", {"correct": true, "letter": "А"})` |
| `game` | Итог игры | `GameLogger.info("game", "game_over", {"game": "collect_word", "score": 5})` |
| `audio` | Воспроизведение звука | `GameLogger.debug("audio", "play_letter", {"letter": "А", "path": "..."})` |
| `audio` | Запись голоса | `GameLogger.info("audio", "record_start"/"record_stop", {"duration": 3.2})` |
| `theme` | Смена темы | `GameLogger.info("theme", "changed", {"theme": "dark"})` |
| `progress` | Изменение прогресса | `GameLogger.info("progress", "letter_completed", {"letter": "В", "total": 3})` |
| `progress` | Сброс прогресса | `GameLogger.warn("progress", "reset", {})` |
| `assets` | Ошибка загрузки ресурса | `GameLogger.error("assets", "load_failed", {"path": "res://assets/images/X.png", "error": "..."})` |
| `error` | Любая ошибка | `GameLogger.error("error", "<what>", {"detail": ...})` |
| `debug` | Служебная диагностика | `GameLogger.debug("debug", "texture_diag", {"label": ..., "path": ...})` |

### 4.3 Требования к реализации

1. `texture_diag()` — при сбое загрузки текстуры/аудио ВСЕГДА логировать `assets` + ERROR (это ловит баг серого фона и `Banana.png`).
2. `Global.switch_scene()` — обязательный лог `nav` с `from`/`to`.
3. `file_handler` пишет `user://logs/azbuka.log`; на web — только console (файловая система недоступна).
4. Минимальный уровень по умолчанию: DEBUG в dev, INFO в релизе (задаётся в settings.json, ключ `logging.min_level`).

---

## 5. Отладка

### 5.1 Диагностика ресурсов (asset_diag)

- При старте dev-сборки проходит по `AlphabetData.DATA` и проверяет `FileAccess.file_exists(image_path)` для всех 33 картинок; несуществующие → `GameLogger.error("assets", ...)`.
- Кнопка/команда «Проверить ресурсы» в dev-режиме.

### 5.2 MCP-сервер (debug/mcp_server.gd)

- TCP-сервер на `127.0.0.1:9090`, JSON-команды построчно (эмуляция ввода/навигации извне).
- **Инстанцируется только в dev-режиме:** флаг `OS.is_debug_build()` или `ProjectSettings.get_setting("application/config/dev_mode")`.
- НЕ является autoload в релизных сборках.

### 5.3 Dev-режим

- `project.godot` → `application/config/dev_mode=true` (dev) / `false` (prod).
- В dev: логгер DEBUG, MCP-сервер активен, asset_diag включён.
- В prod: логгер INFO, MCP отключён.

### 5.4 Веб-экспорт

- Экспорт PWA (web). Отладка в браузере через консоль (file_handler недоступен).
- Известная проблема прошлой версии: серый фон на web — диагностируется через `assets`-логи и texture_diag на этапе фазы ассетов.

---

## 6. Функциональные требования (по экранам)

> Ссылки на AC из ТЗ в скобках. Все UI-детали (иерархия узлов, размеры, цвета, анимации) — по ТЗ § 3; здесь — суть + изменения.

### 6.1 StartScreen (AC-001, AC-012, AC-201)

- Хаб игры. Кнопки: «📖 Азбука» (→ roadmap), «🔍 Найди букву», «🧩 Собери слово», «🖼️ Угадай картинку», «⚙️» (→ settings), «+» (донат).
- **Донат-блок:** DonateOverlay → SbpDialog (QR `QR_sbp.jpg`, номер `+7 904 409-14-70`, «Открыть Сбербанк» → URL/`OS.shell_open`, «Копировать номер» → clipboard) и Yoomoney URL.
- Скрывает кнопки отключённых режимов (`ProgressManager.enabled_modes_changed`).
- Фон: `start_screen.png` (весь экран, KEEP_ASPECT_COVERED).

### 6.2 Roadmap — карта-змейка (AC-202…AC-207, AC-210)

- 33 буквы, 4 точки на линию, серпантин (LTR/RTL чередование), `DOTS_PER_LINE=4, LINE_HEIGHT=130, DOT_RADIUS=26, LINE_WIDTH=6, PATH_COLOR=#5B8C5A`.
- Состояния точек: normal `#6B9B6A` / completed `#A0C4A0` + «✓» / current `#F4D03F` + золотое свечение / errored `#E8A87C` (из `ProgressManager.is_letter_errored`).
- Персонаж-кот (программный 2D: круг, хвост-линия, ноги; IDLE — покачивание хвоста, WALK — бег) стоит на последней изученной букве.
- Клик по точке: если текущая — сразу `go_to_letter_detail`; иначе анимация «кот идёт» (350px/s по сегментам, bounce) → `go_to_letter_detail`.
- Кнопки «⬇ Экран 2» / «⬆ Экран 1» (tween scroll 0.4s).
- Фон: `forest_background.tscn` (дальний).
- **Изменение:** «Назад» → `go_to_start_screen()` (было в ТЗ main_menu).

### 6.3 LetterDetail (AC-204, AC-209…AC-232)

- Буква крупно (`viewport_h/4`), картинка слова ≤55% ширины экрана, фон `forest_background_close.tscn` (`fone4.jpg`).
- 🔊 Буква / 🔊 Слово (`play_letter` / `play_word`).
- **Мини-игра «Найди букву в слове»** (AC-217…AC-221): слоты букв слова; клик по нужной букве → sparkle+bounce+«Молодец! ✨»+`mark_letter_completed`; ошибка → beep 300Hz+шейк+«Попробуй ещё!»+`mark_letter_errored`.
- ← Предыдущая / Следующая → (AC-222…AC-226): slide-анимация 0.3s, disabled на границах, остановка записи при переходе.
- 🎤 Запись (AC-227…AC-232): пульсация, «🔴», ▶️ disabled без записи; новая запись затирает старую. Воспроизведение с авто-нормализацией.
- **Автозапись при правильном ответе:** ждёт звуки → `prompt_correct.wav` → запись 10с → `user://recordings/{буква}_{слово}_{ts}.wav` → «Молодец! Нажми →» → `prompt_forward.wav`.
- LevelBar микрофона (зелёный→жёлтый→красный) — встроен кодом.
- VoiceRecorder — отдельная нода (`voice_recorder.gd`), шина `VoiceRecord` с `AudioEffectCapture`.

### 6.4 Settings (AC-012)

- Тема (toggle + текст «Текущая: …»), звук ON/OFF.
- 4 чекбокса режимов; нельзя выключить последний активный (AcceptDialog).
- Сброс прогресса (ConfirmationDialog) → `reset_progress()` → roadmap.
- Назад → start_screen.

### 6.5 GameFindLetter (AC-006)

- 10 раундов, 4 варианта (1 правильная буква + 3 дистрактора), картинка слова загружается кодом, цвет placeholder по HSV-хэшу буквы.
- Верно: счёт++, зелёная кнопка, sparkle, `play_letter`, 0.6s. Ошибка: disabled, красная, beep, шейк.
- Итог: «Идеально!» (10/10) / «Отлично!» (≥7) / «Попробуй ещё!» (<7); «Играть снова»; «← На главную» → start_screen. `mark_game_played()`.

### 6.6 GameCollectWord (AC-007)

- 5 раундов, слова длиной ≥3 из AlphabetData. Картинка + перемешанные буквы; сборка по порядку.
- Верно: буква гаснет, добавляется в WordBuilder, `play_letter`. Ошибка: шейк всех + красная вспышка, очистка.
- Слово собрано: «Молодец!», sparkle, `play_word`, 1.5s. Итог: «Отлично! Все слова собраны!», 4 sparkle, → start_screen. `mark_game_played()`.

### 6.7 GameGuessPicture (AC-008)

- 10 раундов: крупная буква + 4 слова (1 правильное + 3 дистрактора), кнопки по HSV-цвету.
- Верно: «Молодец!», зелёная, sparkle, `play_letter`, 1.2s. Ошибка: красная + disabled, фидбек, `play_letter("Э")`.
- Итог: «Ваш счёт: X / 10», «Играть ещё». `mark_game_played()`.

---

## 7. Данные

### 7.1 progress.json (`user://progress.json`) — БЕЗ ИЗМЕНЕНИЙ
```json
{
  "completed_letters": ["А", "Б"],
  "games_played": 5,
  "last_played": "2026-08-03",
  "errored_letters": ["П"],
  "enabled_modes": {
    "alphabet": true, "find_letter": true,
    "collect_word": true, "guess_picture": true
  }
}
```

### 7.2 settings.json (`user://settings.json`) — + логгирование
```json
{
  "theme": { "current": "light" },
  "audio": { "sound_enabled": true },
  "logging": { "min_level": 0 }
}
```

### 7.3 Записи голоса
- `user://recordings/{буква}_{слово}_{yyyy-MM-dd_HH-mm-ss}.wav` (автозапись при правильном ответе).
- Прослушивание — только в рантайме (не список файлов в UI).

---

## 8. Ассеты

### 8.1 Инвентарь

| Группа | Кол-во | Формат | Пути |
|--------|--------|--------|------|
| Изображения | 97 | PNG/JPG | `assets/images/` |
| Аудио букв | 33×3 | WAV (_tts) + OGG + RAW | `assets/audio/` |
| Аудио слов | 50+×2 | WAV + OGG | `assets/audio/` |
| Промпты | 4 | WAV | `assets/audio/{hint_find_letter,prompt_correct,prompt_forward}.wav` |
| Шрифт | 1 | TTF | `assets/fonts/NotoSans-Regular.ttf` |
| Донат | 1 | JPG | `assets/images/QR_sbp.jpg` |
| Фоны | 5 | PNG/JPG | `fone.png, fone2.png, fone3.jpg, fone4.jpg, start_screen.png` |

### 8.2 Правила

1. Файлы переносим как есть (пути не меняем — совместимость с `.import` и сохранёнными данными).
2. **Фаза ассетов включает верификацию:** каждый `image_path` из AlphabetData существует на диске; аудио-файлы букв/слов существуют. Отчёт — в лог (`assets`).
3. `.import` файлы генерируются Godot при первом открытии — не копируем вручную.

---

## 9. Известные расхождения ТЗ ↔ код (решения зафиксированы)

| # | Расхождение | Решение |
|---|-------------|---------|
| 1 | Слова Е/Ё/П/Ъ (ТЗ vs код) | Используем фактические (Ель/Ёж/Подарок/Объявление) — соответствуют ассетам |
| 2 | AC-208 (объекты на фоне) | Не реализуем (единый fone.jpg) |
| 3 | AC-213 (картинка под буквой) | Картинка под буквой по центру (фактически) |
| 4 | main_menu / letter_card / responsive / alphabet_screen | Удаляем (мёртвый код) |
| 5 | `Global.go_to_main_menu()` | Удаляем (не вызывается) |
| 6 | Звуки букв: ТЗ `_letter.raw` | Фактически `_letter_tts.wav` — используем WAV |

---

## 10. Приёмочные критерии (Acceptance Criteria)

### 10.1 Критерии переписывания (новые, SPEC-REWRITE)

| AC | Описание |
|----|----------|
| SR-001 | Код организован по папкам согласно § 3.1 (каждый экран — своя папка) |
| SR-002 | Ни одного `print()` в геймплейном коде — только `GameLogger` |
| SR-003 | Каждый переход экрана фиксируется в логе `nav` (from/to) |
| SR-004 | Логгер пишет `user://logs/azbuka.log` на десктопе; на web — консоль |
| SR-005 | MCP-сервер работает только в dev-сборках |
| SR-006 | asset_diag проверяет все 33 `image_path` при старте dev-сборки |
| SR-007 | Мёртвый код (main_menu, letter_card, responsive, go_to_main_menu) отсутствует |
| SR-008 | Прогресс/настройки совместимы: старые `progress.json`/`settings.json` читаются |
| SR-009 | Старые баги диагностируются: ошибка загрузки ресурса → ERROR в канале `assets` |

### 10.2 Критерии из ТЗ (регрессия)

Все AC-001…AC-232 из ТЗ § 7 (кроме отменённых: AC-208 объекты фона, AC-213 — фиксируем фактическое расположение, AC-001/AC-002 — в новой навигации через start_screen/roadmap).

---

## 11. План разработки (декомпозиция на фазы для Build Loop)

> Каждая фаза = отдельный цикл Ralph Loop (delegate → judge → commit). Порядок учитывает зависимости.

| Фаза | Содержание | Критерий готовности (DoD) |
|------|-----------|---------------------------|
| **P0** | Каркас: структура папок, project.godot (autoload-порядок, dev_mode), перенос assets, пустой start_screen | Проект запускается, логгер пишет в консоль/файл |
| **P1** | Логгер (logging/*) + GameLogger autoload + settings.json (min_level) | SR-002, SR-003, SR-004 |
| **P2** | Синглтоны: AlphabetData (+верификация image_path), ThemeManager, AudioManager, ProgressManager | SR-006; прогресс/настройки читают старые файлы (SR-008) |
| **P3** | Global (навигация + sparkle + letter_names) + switch_scene c логом `nav` | SR-003; переходы работают между заглушками |
| **P4** | StartScreen (кнопки, режимы, донат-оверлей) | AC-001, AC-012; режимы скрываются |
| **P5** | Roadmap (змейка, точки, кот, скролл, навигация) | AC-202…AC-207, AC-210 |
| **P6** | LetterDetail (буква, картинка, аудио, Prev/Next, мини-игра) | AC-209…AC-226 |
| **P7** | VoiceRecorder + автозапись (микрофон, LevelBar, WAV) | AC-227…AC-232 |
| **P8** | GameFindLetter | AC-006 |
| **P9** | GameCollectWord | AC-007 |
| **P10** | GameGuessPicture | AC-008 |
| **P11** | Settings (тема/звук/режимы/сброс) | AC-012; защита «минимум 1 режим» |
| **P12** | Debug-инструменты: MCP-сервер (dev), asset_diag при старте | SR-005, SR-006 |
| **P13** | Экспорт: Web PWA, Android, iOS, macOS; прогон asset_diag; регрессия AC | SR-001…SR-009, все AC |
| **P14** | Регрессия на web (консоль), финальный отчёт по логам | Баг серого фона диагностирован/исключён |

---

## 12. Риски

| Риск | Митигация |
|------|-----------|
| Серый фон на web-экспорте повторится | Логи `assets` + texture_diag на старте (P12, P14); проверка на этапе P13 |
| Имена файлов с регистром (`Banana.png` vs `banan.png`) | asset_diag проверяет точные пути из AlphabetData |
| Потеря прогресса пользователей | Форматы progress/settings не меняются (SR-008) |
| Микрофон на web/мобильных | Проверка пермишенов; fallback — без записи, но игра работает |
