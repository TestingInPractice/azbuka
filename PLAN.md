# PLAN: Монетизация V2 — Донаты + Реклама

> Версия: 2.0 (облегчённая)
> Статус: черновик

---

## Суть

Весь контент приложения бесплатный. Монетизация:
1. **Донаты** — кнопка на главном экране (ЮMoney + СБП)
2. **Видеореклама** — interstital video (до 30 сек) при каждом запуске
3. **Баннер** — адаптивный, < 10% экрана, в нижней части

Если сумма донатов за месяц достигает цели (`GOAL`) — реклама автоматически отключается у всех пользователей до конца месяца.

---

## 1. Docker-сервис (отдельный контейнер)

### Стек
- Fastify (Node.js) или FastAPI (Python)
- SQLite (одна таблица, без внешних БД)
- Один контейнер, `docker compose up`

### Переменные окружения

```
GOAL=10000                    # Цель сбора на месяц (руб)
PORT=3000                     # Порт сервиса
YOOMONEY_SECRET=...           # Секрет для проверки webhook ЮMoney
ADMIN_PASS=...                # Пароль для админки
```

### Модель БД

```sql
CREATE TABLE donations (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  amount       REAL NOT NULL,
  source       TEXT DEFAULT 'yoomoney',   -- yoomoney | sbp | manual
  label        TEXT,                       -- метка платежа (order_id)
  created_at   TEXT DEFAULT (datetime('now'))
);

CREATE TABLE config (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
-- config: goal, ads_disabled, month, year, total_month
```

### API endpoints

| Метод | Путь | Описание |
|-------|------|----------|
| `GET` | `/api/status` | `{ total, goal, ads_disabled }` — публичный, вызывается клиентом при запуске |
| `POST` | `/webhook/yoomoney` | Webhook от ЮMoney: проверка подписи, запись доната, пересчёт `ads_disabled` |
| `GET` | `/admin` | HTML-дашборд: сумма, цель, список донатов, кнопки управления |
| `POST` | `/admin/add-donation` | Ручное добавление доната (для СБП) |
| `POST` | `/admin/set-goal` | Изменить цель (если нужно без перезапуска) |

### Логика `/api/status`

```
month_total = sum(donations WHERE month == current_month AND year == current_year)

if total >= goal AND !ads_disabled:
    ads_disabled = true

return { total: month_total, goal: goal, ads_disabled: ads_disabled }
```

### Логика `/webhook/yoomoney`

```
1. Проверить HMAC-SHA1 подпись (секрет)
2. Если notification_type == "payment" И status == "success":
   - INSERT INTO donations (amount, label)
   - Пересчитать total_month
   - Если total_month >= goal: config.ads_disabled = true
3. Вернуть HTTP 200
```

### Сброс месяца

При запуске сервис проверяет:
- Если текущий месяц/год != сохранённому в config:
  - `total_month = 0`
  - `ads_disabled = false`
  - Обновить месяц/год

### Dockerfile

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["node", "server.js"]
```

### docker-compose.yml

```yaml
version: '3'
services:
  donation-service:
    build: .
    ports:
      - "3000:3000"
    environment:
      - GOAL=10000
      - ADMIN_PASS=admin123
    volumes:
      - ./data:/app/data     # persist SQLite
    restart: unless-stopped
```

---

## 2. Изменения в Godot

### 2.1 Главный экран — счетчик донатов

**Файлы:** `scenes/main_menu.tscn`, `scripts/main_menu.gd`

Добавить под кнопками меню, над баннером:

```
HBoxContainer "DonationContainer" — alignment=center
├── ProgressBar "DonationProgress" — max=GOAL, show_percentage=false
└── Label "DonationLabel" — "Собрано X ₽ из Y ₽"

Button "DonateButton" — "❤ Поддержать проект"
```

**Логика `_ready()` + `_check_donation_status()`:**

```gdscript
func _check_donation_status():
    var http = HTTPRequest.new()
    add_child(http)
    http.request_completed.connect(_on_status_received)
    http.request("https://donation-service.example.com/api/status")

func _on_status_received(_result, _code, _headers, body):
    var data = JSON.parse_string(body.get_string_from_utf8())
    donation_progress.max = data.goal
    donation_progress.value = min(data.total, data.goal)
    donation_label.text = "Собрано %d ₽ из %d ₽ за месяц" % [data.total, data.goal]
    ads_disabled = data.ads_disabled

    if ads_disabled:
        donate_button.text = "🎉 Спасибо! Реклама отключена"
        donate_button.disabled = true
    else:
        donate_button.text = "❤ Поддержать проект"
```

### 2.2 DonateButton — открыть форму оплаты

По нажатию:
- **PWA:** `JavaScriptBridge.eval("window.open('https://yoomoney.ru/quickpay/confirm?...')")` или `OS.shell_open(url)`
- **Android/iOS:** `OS.shell_open(url)`

URL формы ЮMoney:
```
https://yoomoney.ru/quickpay/confirm
  ?receiver=41001xxxxxxxxxxxx
  &quickpay-form=button
  &paymentType=AC
  &sum=100
  &label=donation_{timestamp}
  &successURL=https://azbuka.app/spasibo
```

### 2.3 Реклама — отключение через флаг

В сцене `main_menu.tscn`:
- **Interstitial video:** показывается при заходе на главный экран, только если `!ads_disabled`
- **Banner:** показан внизу, только если `!ads_disabled`

Если `ads_disabled == true`:
- Видео не показывается
- Баннер скрыт
- Вместо баннера — текст "🎉 Реклама отключена благодаря нашим спонсорам!"

### 2.4 Ad SDK интеграция

Для показа рекламы используются готовые Godot-плагины:

| Платформа | Плагин | Форматы |
|-----------|--------|---------|
| PWA (Web) | `BasilYes/godot-yandex-games-sdk` (через `JavaScriptBridge`) | Interstitial video |
| Android | `noctisalamandra/godot-yandex-ads-android` | Interstitial video + Banner |

---

## 3. Структура Docker-сервиса

```
donation-service/
├── Dockerfile
├── docker-compose.yml
├── package.json
├── server.js            # Fastify API
├── db.js                # SQLite helper
├── routes/
│   ├── status.js        # GET /api/status
│   ├── webhook.js       # POST /webhook/yoomoney
│   └── admin.js         # GET/POST /admin/*
├── views/
│   └── dashboard.html   # HTML админка
└── data/                # SQLite файл (persist volume)
```

---

## 4. Этапы реализации

### Wave 1: Docker-сервис
1. Инициализировать проект `donation-service/`
2. SQLite + модели
3. `GET /api/status` — публичный статус
4. `POST /webhook/yoomoney` — приём донатов
5. Логика `ads_disabled` + goal + сброс месяца
6. `POST /admin/add-donation` — ручной ввод
7. `GET /admin` — HTML дашборд
8. Dockerfile + docker-compose.yml

### Wave 2: Клиент (Godot)
9. Счетчик донатов на главном экране
10. DonateButton + открытие формы оплаты
11. Проверка `GET /api/status` при запуске
12. Отключение рекламы по флагу `ads_disabled`
13. Интеграция Yandex Ads (interstitial + banner)

### Wave 3: QA
14. E2E: донат → webhook → total обновлён → реклама отключена
15. Сброс месяца: проверить что реклама включилась снова
16. Offline-поведение (без интернета — последний кешированный статус)

---

## 5. Файлы для создания

### Docker-сервис (вне репозитория Godot)
| Файл | Описание |
|------|----------|
| `donation-service/Dockerfile` | Образ контейнера |
| `donation-service/docker-compose.yml` | Оркестрация |
| `donation-service/package.json` | Зависимости |
| `donation-service/server.js` | Точка входа |
| `donation-service/db.js` | SQLite helper |
| `donation-service/routes/status.js` | GET /api/status |
| `donation-service/routes/webhook.js` | POST /webhook/yoomoney |
| `donation-service/routes/admin.js` | Admin endpoints |
| `donation-service/views/dashboard.html` | HTML админка |

### Godot-клиент
| Файл | Изменение |
|------|-----------|
| `scripts/main_menu.gd` | Счетчик, статус, управление рекламой |
| `scenes/main_menu.tscn` | DonationContainer, ProgressBar, DonateButton, Banner |

---

## 6. CPM и ожидаемый доход (Россия, 2026)

| Формат | CPM | Доход с 1000 показов | При 1000 DAU/мес |
|--------|-----|---------------------|-------------------|
| Interstitial video (30s) | 50–150 ₽ | 50–150 ₽ | 1500–4500 ₽ |
| Banner adaptive | 10–50 ₽ | 10–50 ₽ | 300–1500 ₽ |
| **Итого** | | | **~2000–6000 ₽/мес** |

При достижении цели донатов реклама отключается — доход временно прекращается до следующего месяца.
