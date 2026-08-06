# Progress Ledger — «Азбука» (azbuka)

Обновляется по завершении рабочих сессий. Формат: дата → что сделано → доказательства → статус.

---

## 2026-08-05 — iPhone-фиксы: звук, стрелки, картинка «Й» (деплой + live-верификация)

**Проблемы (отчёт пользователя с iPhone):**
1. Звук не работает — unlock-скрипт в `export_presets.cfg` (head_include) содержал синтаксическую ошибку `Unexpected end of input`.
2. Стрелки навигации ◀/▶ не отображаются — глифы отсутствуют в шрифте на iOS.
3. Картинка йогурта на букве «Й» не отображается — несоответствие регистра: маппинг `"Й": "Yogurt"` vs файл `yogurt.png` (регистрозависимый .pck).

**Фиксы:**
- `export_presets.cfg:23` — переписан `head_include` unlock-скрипт (IIFE, обёртка `window.__godotAudioCtx` вокруг `window.AudioContext`). Проверено: `node --check` OK, лог экспорта подтверждает встраивание (1246 B, parse OK).
- `ui/games/azbuka/letter_card.tscn:153,167` — `◀`→`‹`, `▶`→`›` (глифы есть в NotoSans).
- `ui/games/azbuka/letter_card.gd:51` — `"Й": "Yogurt"` → `"Й": "yogurt"`.
- `project.godot` проверен: нет форсированного `mix_rate` (только `audio/driver/enable_input=true`) — избегаем статтера на iOS.

**Экспорт и деплой:**
- `godot --headless --path . --export-release "Web" /tmp/azbuka-web/index.html` → EXIT 0.
- Экспортированный `index.html` верифицирован: unlock-скрипт парсится, меты (`viewport-fit=cover`, `mobile-web-app-capable`) на месте, `.pck` содержит lowercase `yogurt.png`, без `Yogurt.png`.
- Деплой: rsync → `/tmp/azbuka-ghpages`, восстановлен `.nojekyll`, коммит `14d42c1`, push `862e77b..14d42c1 gh-pages -> gh-pages`.
- Live: https://TestingInPractice.github.io/azbuka/

**Live-верификация (Playwright, fresh-загрузка после сброса SW):**

| Баг | Статус | Доказательство |
|---|---|---|
| Звук | ✅ FIXED | `window.__godotAudioCtx` = объект, `state:"running"`, `sampleRate:48000`. Лог свежей загрузки чист (только boot + 1 косметический warning про deprecated meta). `Unexpected end of input` в консоли — остаток от первой (SW-кэшированной сломанной) загрузки сессии, не от текущего билда. Live `index.html` из сети содержит исправленный скрипт (проверено curl). |
| Стрелки | ✅ FIXED | 4 клика по «‹» прошли навигацию Н→М→Л→К→Й (каждый подтверждён логом `letter_card: prev`). Ранее — чернила в обеих областях кнопок (10.1% / 14.6% тёмных пикселей, min 53/26) — глифы рендерятся, не tofu. |
| Картинка «Й» | ✅ FIXED | Карточка Й открыта, промпт «Найди букву «Й» в слове». Область картинки: 45 657 уникальных цветов (фото-контент; серый/маджента missing-texture = 0). Шаблонное сопоставление с `assets/images/yogurt.png`: корреляция 0.668 при 160px в точке (564,320). Палитра отрендеренной области совпадает с ассетом: (149,194,224) голубой, (252,244,225) кремовый, (253,253,253) белый. |

**Незакоммичено на `azbuka-v2`:** `M export_presets.cfg`, `M ui/games/azbuka/letter_card.gd`, `M ui/games/azbuka/letter_card.tscn` (фиксы уже в деплое, но в ветке висят как изменения — ждут коммита по команде пользователя).

**Скриншоты:** `azbuka-07…11-*.png` в корне репо (untracked, не коммитить).

**Артефакты сессии:** `/tmp/azbuka-web/` (экспорт), `/tmp/azbuka-ghpages/` (деплой-worktree, HEAD `14d42c1`), `/tmp/ocr_screenshot.swift` (OCR-хелпер).
