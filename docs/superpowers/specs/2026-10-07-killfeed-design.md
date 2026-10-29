# Kill feed: лента убийств «killer > victim» поверх VTKKillCounter

Дата: 2026-10-07
Статус: утверждён к реализации

## Контекст

У счётчика убийств (`VTKKillCounter.gd`) есть только агрегатная строка
«Killed: N Enemies: N Nomads: N». Хотим ленту убийств в стиле Counter-Strike:
`Player [weapon] [HS] > Bandit`, `Bandit [grenade] > Nomad` — с указанием убийцы,
жертвы, оружия и маркеров (хедшот / граната).

Данных для атрибуции в моде уже много: `VTKHooks.gd` висит на `ai-weapondamage-pre`
(сигнатура `hitbox, damage, vector, id`) и `ai-death-pre` (`direction, force`),
счётчик уже классифицирует агентов по скриптам (`AI_Nomad`, `AI_Bandit`,
`AI_Guard`, `AI_Military`; Punisher/Bogeyman сейчас не классифицируются).
Референсы (VRCETS Milestones, VostokRelay) показали рабочие приёмы: headshot по
`hitbox == "Head"`, direction-эвристика игрока (`direction · playerVector > 0.985`),
дедуп смертей по instance_id, чтение оружия по `currentWeapon…`-свойствам.

## Принятые решения

| Вопрос | Решение |
|---|---|
| Атрибуция убийцы | Последний нанёсший урон, окно 15 с. Нет данных → строка не показывается (без «died») |
| Позиция ленты | Столбик под счётчиком и под игровыми строками карты/FPS (фиксированный offset-константа, не наши ноды — привязаться не к чему) |
| Цвета | Константы в коде: зелёный `Color(0.55, 0.85, 0.55)` — player/nomad, красный `Color(1, 0.45, 0.45)` — враг |
| Состав строки | Оружие: `killer → иконка оружия → [иконка HS] → victim`. Граната: `killer → иконка гранаты → victim`. Стрелки `>` нет |
| Маркеры | HS — точно (hitbox); граната — best-effort (`force`/имя оружия), не подтвердится — просто без маркера |
| Иконки | HS — файл `Icon_headshot.webp` из референса; граната — SVG через `VTKSurface`; оружие — иконка предмета из `Database` по имени оружия, иначе без иконки |
| Настройки | Два MCM-тумблера: `kill_counter_enabled`, `kill_feed_enabled` (оба default true). Цвета/окно/лимит — константы |
| Архитектура | Подход B: новый `VTKFeed.gd`, события из `VTKHooks`, `VTKKillCounter` не меняется |
| Версия | `4.7.2` → `4.8.0` (новая функциональность, обратная совместимость сохранена) |

## 1. Атрибуция событий — `VTKHooks.gd`

Новое состояние рядом с `_player_hits`:

```
_last_damager: Dictionary
# victim_iid -> { attacker_id: int, t: msec, hitbox: String, weapon: String, player: bool }
```

### `ai-weapondamage-pre`

- Вызывающий (`_lib._caller`) — жертва, 4-й аргумент `id` — предполагаемый
  атакующий. Перед основной логикой — probe-этап (см. §5): если `id` не нода,
  атрибуция игрока падает на direction-эвристику в `ai-death`.
- Пишем/обновляем `_last_damager[victim_iid]`: атакующий, время, `hitbox`
  (`== "Head"` → флаг хедшота), оружие (у игрока — из GameData `currentWeapon…`;
  у AI — из атакующего AI, если свойство найдено, иначе пусто).
- Если атакующий — игрок (группа `Player`) → флаг `player: true`.

### `ai-death-pre`

1. Дедуп по instance_id (приём VRCETS `_seen_ai_deaths`): одна смерть = одно событие.
2. Убийца: запись из `_last_damager` моложе **15 с**; иначе direction-эвристика
   (`direction` vs `playerVector` GameData) → убийца-игрок; иначе **событие не
   выпускаем**.
3. Собираем событие `{killer_kind, killer_name, victim_kind, victim_name,
   weapon, headshot, grenade, t}` и выпускаем сигналом
   `kill_event(dict)` с autoload-ноды (подписчик один — `VTKFeed`).
4. Запись из `_last_damager` стирается.

### Граната (best-effort)

В probe-этапе смотрим, что даёт `ai-death` аргумент `force` и как выглядит имя
гранаты в Database. Если детект подтверждается — флаг `grenade` и подавление
иконки оружия; нет — флаг всегда false, строка не ломается.

### Очистка

- Окно 15 с и протухшие записи чистятся тем же тиком, что и `_player_hits`
  в `_on_controller_process`.
- Смена карты / вход в шелтер / выключение — сигнал `feed_reset` (или прямой
  вызов `VTKFeed.clear()`), лента пустится вместе со счётчиком.

Существующий подсчёт киллов (`_kill_count`, `_kill_counter._tick`) **не меняется** —
лента только читает события.

## 2. Рендер — новый `VTKFeed.gd`

- `Control`, child `VTKUI`, рядом с `VTKKillCounter`; включается/выключается
  тумблером MCM.
- Позиция: `Vector2(10, 10 + FEED_TOP_OFFSET)` — константа под игровые строки
  карты/FPS под строкой счётчика (значение подстроим по факту на экране).
- Утверждено макетом Task 2: шрифт **15px**, высота строки **20px**, отступ
  `FEED_TOP_OFFSET = 72`, подложка под каждой строкой `rgba(0,0,0,0.45)`
  (горизонтальный padding 6px, зазор между строками ~2px), иконки 14×14.
- Строка = `HBoxContainer` с `Label`-ами и `TextureRect`-иконками на
  `PanelContainer` с `StyleBoxFlat`-подложкой; новых строк
  сверху, максимум **5** (константа), старые вытесняются.
- Fade: полная видимость `FEED_DURATION` секунд, затем плавное затухание
  `modulate.a` в `_process`, потом `queue_free`.
- Цвет по правилу: killer/nomad → зелёный, враг → красный; имя берётся из
  событий (имена сущностей из игры — не локализуются, правило 1 AGENTS.md);
  собственные строки UI — через `Loc.txt()`.
- Чистая логика (список строк, вытеснение по лимиту, таймер fade, цветовые
  правила) выносится так, чтобы тестировалась headless, как `VTKPicker`
  (ни `load()`, ни путей внутрь игры в тестимой части).

## 3. Иконки и упаковка

| Иконка | Источник |
|---|---|
| Хедшот | `referens/Icon_headshot.webp` → `loadouts/mods/VTK/Icon_headshot.webp` |
| Граната | SVG-строка через `VTKSurface.svg_texture()` (после probe можно заменить файлом) |
| Оружие | Имя оружия → предмет в `Database` → его иконка; нет — без иконки |

- Godot 4 работает с WebP, отдельный PNG не нужен.
- **`pack.ps1` пакует только `.gd/.tres/.tscn/.gdshader`** — расширить список на
  `.webp/.png`, иначе иконка не попадёт в `.vmz`.
- `.check/check.ps1` копирует только `*.gd` — иконку грузить рантаймовым
  `load()` под `ResourceLoader.exists`: в стенде файла нет и ресурс просто
  не найден (`preloaded` ресурс уронил бы компиляцию стенда).

## 4. MCM и версия

- Секция `04. KillFeed` в `_register_mcm` (`VTKUI.gd`):
  - `kill_counter_enabled` (Bool, default true) — подключает существующее
    `VTKKillCounter.set_enabled` к `_mcm_apply` (сейчас тумблер живёт только в UI —
    при реализации свериться, откуда он зовётся);
  - `kill_feed_enabled` (Bool, default true) — `VTKFeed.set_enabled`.
- Существующий код синхронизации config.ini ключи чистит сам — отдельных мер не нужно.
- Цвета, окно 15 с, лимит 5 строк, FEED_TOP_OFFSET, FEED_DURATION, шрифт 15px,
  высота строки 20px, подложка `rgba(0,0,0,0.45)` — константы.
- `loadouts/mod.txt`: `4.7.2` → `4.8.0` перед сборкой.

## 5. Probe-этап и проверка

Порядок работ:

1. **Probe в игре**: временные `print` в `ai-weapondamage-pre` / `ai-death-pre`
   (плюс пробный вывод аргументов и свойств оружия атакующего) — подтвердить:
   что 4-й аргумент — атакующий-нода; что direction-эвристика сходится с
   `_player_hits`; что `force`/имя оружия дают детект гранаты; что иконка
   оружия достаётся из Database. Лог сверяем **до** написания атрибуции.
   Probe временный, перед релизом удаляется.
2. **Стенд**: `python .check\layout_check.py` + `powershell -File .check\check.ps1`
   (парсинг, headless-тесты `VTKFeed`-логики, зелёный статус = SCRIPT ERROR нет,
   `tests passed` есть, exit 0).
3. **layout_check.py**: добавить проверки новых функций в `PRESENT`,
   отсутствие удалённых — в `GONE`.
4. **Ручная проверка в игре**: строки появляются на убийствах player и AI-vs-AI,
   HS/граната, fade, очистка на смене карты, тумблеры MCM.
5. **HTML-макет** (`docs/mockups/`): после probe-данных — реальный вид строк
   (цвета, иконки, offset под игровыми строками) для утверждения до сборки.
