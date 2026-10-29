# ThermalVTK — приём ITH для обводки, три категории, рабочее остывание трупов

**Дата:** 2026-10-20
**Статус:** на утверждении
**Связанные:** `2026-10-20-thermalvtk-fill-mode-unified-design.md`,
`2026-10-20-thermalvtk-debug-state-labels-design.md`
**Версия:** 1.7.0 (minor: новое поведение + новые настройки; формат сейвов не меняется)

## Что и зачем

Продолжение 1.6.x после in-game проверки. Три темы:

1. **Обводка «выворачивает» модельку.** Наш ring/body шейдер использует `cull_back` при
   `depth_test_disabled` — рисует передние грани прямо по телу, силуэт раздувается.
   Референс `ImmersiveThreatHighlight` (`referens/`) решает это иначе: `cull_front`
   (задние грани) + rim через `smoothstep` + `discard`. Переносим приём, даём тумблер
   Front-faces / Back-faces, чтобы выбрать лучший в игре.
2. **Состояния сводятся к трём категориям** (Normal / Combat / Defend) вместо четырёх;
   номады больше не отдельный цвет, а помечаются зелёным `◆` над головой.
3. **Остывание трупов не работает.** `cool` читает `e["dead"]`/`e["death_ts"]`, которые
   ставит хук `ai-death-post`; хук не срабатывает (доказано фиксом лейбла в 1.6.1, где
   фолбэк на `node.get("dead")` сработал). Кул-путь фолбэка не получил.

## Целевая модель

Один режим (как в 1.6.x). NVG + `Thermal vision` on → термомир + тела NPC заливкой и
обводкой. Обводка — аккуратный контур (по умолчанию приём ITH). Три категории состояния,
категорийный цвет. Номад — цвет своей категории + зелёный `◆` (игровая метка, живёт
независимо от debug-лога).

## Изменения

### Обводка: приём ITH (`VTKOutlineRing.gdshader`, `VTKOutline.gd`, `VTKShaders.gd`)

- Ring-шейдер получает uniform `outline_style` (int: 0 = Front-faces ITH, 1 = Back-faces).
  - **Front-faces (0):** `ALPHA = smoothstep(rim_start, rim_end, rim01)`;
    `if (line < 0.03) discard;`. cull-режим — `cull_front`.
  - **Back-faces (1):** `ALPHA = pow(rim01, rim_power)`. cull-режим — `cull_back`.
  - `rim01 = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0)` — общая.
- Cull-режим в Godot — compile-time (`render_mode`), uniform его не меняет. Значит
  `VTKShaders.gd` строит **две** пары вариантов: (cull_front + depth-варианты) и
  (cull_back + depth-варианты). Стиль выбирает пару; `through_walls` по-прежнему выбирает
  внутри пары LOS/wall (см. ниже). Кеш `Shader` расширяется до 4 body + 4 ring.
- Итог по cull: **style** переключает связку целиком (cull + rim-формула), как просил
  пользователь.
- `rim` — **один** MCM-слайдер `outline_rim` (0.0..1.0, дефолт 0.42), трактовка разная:
  - Front-faces: `rim_start = outline_rim`, `rim_end = outline_rim + 0.4` (ITH 0.42→0.82).
  - Back-faces: `rim_power` берётся из `outline_rim` (степень; дефолт 0.42 даёт мягкий
    край, при 1.0 — как сейчас). `rim_power` перестаёт быть запечённой константой.

### Body fill: два подхода (`VTKOutlineBody.gdshader`, `VTKOutline.gd`)

- `fill_style` (MCM Dropdown, дефолт `flat`):
  - **flat (0, текущий):** `ALBEDO = fillColor * mix(1.0, 0.15, cool)`,
    `ALPHA = fill_alpha * (1.0 - cool)`. Плоский цвет категории. Материал — display.
  - **gradient (1, эксперимент):** вертикальный градиент по телу: низ = warm-тон, верх =
    cold-тон (точные тона подберём в игре), поверх — примесь цвета категории по
    `fill_alpha`. Материал — display (палитра NVG прогоняет его, цвет плавает от пресета
    — это ожидаемая цена эксперимента, зафиксировано).
- `outline_style`/`fill_style` — uniform-ветки в одном шейдере на каждый (меньше кешей,
  один preload на файл), а cull разводится в ресурсы (см. выше), потому что `render_mode`
  компилируется.

### Трупы (`VTKESP.gd`)

- В `_draw` (или `_opts_for`), увидев `node.get("dead")` при `not e["dead"]` — вызвать
  `Tracker.mark_dead(e, _now())`. Тогда `cool` растёт линейно от 0 до 1 за `corpse_decay`
  секунд, независимо от хука. Затухание плавное, синхронно для заливки и обводки (1.6.1
  уже пушит `cool` в body и ring).
- Если игра выгрузила труп из сцены раньше `corpse_decay` — обводка исчезает вместе с ним
  (решение пользователя: оставить как есть).

### Категории (`VTKStates.gd`, `ThermalVTK.gd`, MCM CAT3)

- Было: NORMAL / ALERTED / HUNTING / COMBAT + NOMAD.
- Стало: **NORMAL / COMBAT / DEFEND** (номад — флаг, не категория).

| Категория | Состояния (enum `AI.State`) |
|---|---|
| NORMAL | Idle, Wander, Loot, Guard, Patrol, Group |
| COMBAT | Combat, Hunt, Attack, Grenade |
| DEFEND | Cover, Hide, Ambush, Defend, Vantage, Lurk, Switch |

- Цвета: NORMAL — текущий (жёлто-амбер), COMBAT — красный, DEFEND — фиолетовый.
  Дефолты в `VTKStates` (`DEFAULT_*`), MCM CAT3 — 3 Color-поля (`state_normal`,
  `state_combat`, `state_defend`); `nomad_color` удаляется из MCM. `_sync_config` вычистит
  мёртвые ключи.
- `category_of()` мапит enum → 3; `state_key()`/`default_color()`/`label_text()`
  переписаны под 3.

### Номад: `◆` (`VTKESP.gd`)

- Номад красится цветом **своей категории** (как все).
- Отдельный `Label3D` над номадом с текстом `◆` (зелёный), виден при **NVG + Thermal on**,
  **независимо от debug-лога**. Это игровая метка «братишка», чтобы узнавать ночью.
- Отдельная жизнь от debug-лейбла (свой узел, свой жизненный цикл).

### Debug-лейбл (`VTKESP.gd`)

- Показывается при включённом debug-логе **всегда** (сейчас гвард `if not Dbg.enabled`
  ставит показ в зависимость от debug; проверить и убедиться, что NVG на него не влияет).
- Текст = состояние. Поля кроме состояния пока не добавляем.

### MCM после правок (категория 02 остаётся одной)

Порядок/набор 02.Contour ESP:

- `outline_enabled` (Bool)
- `outline_style` (Dropdown: Front-faces / Back-faces, дефолт Front-faces) — новый
- `outline_rim` (Float 0.0..1.0, дефолт 0.42) — новый
- `outline_thickness` (Float, **minRange 0.001, maxRange 0.02**, дефолт 0.006) — расширен
- `outline_body_fill` (Bool)
- `fill_style` (Dropdown: Flat / Gradient, дефолт Flat) — новый
- `fill_opacity` (Float 0.0..1.0, дефолт 0.4)
- `corpse_decay` (Float, дефолт 8)
- `outline_brightness` (Float, дефолт 0.6)
- `outline_distance` (Float, **дефолт 60**, было 150)
- `outline_through_walls` (Float, дефолт 5) — сохранён как порог близкой зоны

Удаляется: `nomad_color` (CAT3). `_sync_config` вычистит его из `config.ini`.

### Семантика `outline_through_walls` (сохранён)

Порог близкой зоны: `dist <= outline_through_walls` → LOS-шейдер (не сквозь стены),
иначе wall-шейдер (сквозь стены). Работает в **обоих** style (style выбирает cull+rim,
through_walls — depth-вариант внутри стиля). Пользователь решил сохранить и «потом убрать,
если что».

## Вне объёма

- Обводка сквозь увеличенную оптику (PIP off) — как в 1.5.x, не трогаем.
- Поля debug-лейбла кроме состояния.
- Удаление `outline_through_walls`.
- Защита трупов от CAP/дистанции.

## Риски

1. **Cull-режим не uniform.** `render_mode` в Godot компилируется, поэтому style требует
   отдельных `Shader`-ресурсов, а не ветки. `VTKShaders.gd` строит 2 cull × 2 depth = 4
   варианта на шейдер. Следить, чтобы `strip_depth_test` (снятие токена) применялся и к
   новым вариантам.
2. **Uniform-ветка style/rim внутри одного шейдера** vs отдельный ресурс — выбрана ветка
   для rim/fill (не для cull). Убедиться, что ветка не ломает `discard` (в `fragment()`
   `discard` допустим, `return` — нет).
3. **Подход №2 (gradient) — display**, палитра NVG окрасит его в цвета пресета; цвет
   категории будет плавать. Это осознанная цена эксперимента.
4. **Смена категорий** затрагивает тесты (`test_states.gd`, `test_tracker.gd`) и MCM-ключи;
   `category_of` с 4 → 3 меняет семантику ключей цвета. Проверить `keycheck`/стенд.
5. **`◆`-узел** живёт независимо от debug-лейбла и от `_labels_sync` — нужен свой
   lifecycle (создать/снять по nomad + NVG/Thermal), чистить на deactivate/death/exit.
6. **Фолбэк `mark_dead` по `node.get("dead")`** — если хук смерти иногда всё же срабатывает,
   `mark_dead` идемпотентен (`if e.dead: return`), двойной записи нет.

## Проверка

1. `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1` → зелёный, тот
   же набор тестов (+ обновлённые states/tracker), нет `SCRIPT ERROR`/`Parse Error`/
   `Invalid call`.
2. `py -3 .check\layout_check.py` → exit 0.
3. `pack.ps1` → `ThermalVTK.vmz` → install.
4. В игре (NVG + Thermal on):
   - обводка не «выворачивает» модельку в стиле Front-faces; в Back-faces ведёт себя как
     раньше; тумблер переключает;
   - `Outline rim` меняет ширину/резкость ободка;
   - `Thickness` уходит тоньше 0.006;
   - три категории: бой — красный, оборона — фиолетовый, мирный — текущий;
   - номад цветом своей категории + зелёный `◆`; `◆` виден и без debug-лога (debug off);
   - debug-лейбл виден и без NVG (при debug on);
   - `Corpse cooling time` → труп плавно тускнеет и исчезает (заливка + обводка);
   - `Fill style` переключает Flat/Gradient (gradient проверяем визуально);
   - `outline_distance` дефолт 60;
   - в `config.ini` нет `nomad_color`.
