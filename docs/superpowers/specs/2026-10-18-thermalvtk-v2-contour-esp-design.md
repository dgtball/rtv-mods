# ThermalVTK v2 — контурный ESP поверх термала

**Дата:** 2026-10-18
**Статус:** утверждён
**Заменяет:** дизайн full-screen термала v1 (single-shader замена NVG-оверлея)

## Контекст и мотивация

Текущий ThermalVTK (v1) заменяет шейдер ванильного NVG-оверлея целиком: палитра мира, термальная заливка ботов (warm/mid/cold), эмиссия мин. Это конфликтует с основным модом VTK (оба лезут в NVG-оверлей → мерцание, розовые модели ботов при хоткее NVG без тепловизора).

Два референса показали альтернативу без full-screen замены:

- **ImmersiveThreatHighlight** — красивая обводка силуэта (inverted-hull: дубликат меша, `VERTEX += NORMAL * grow`, `cull_front`, rim через `smoothstep`). Минус: дубликат каждого `MeshInstance3D` поддерева NPC = 5–15 лишних узлов на бота, все в прозрачном проходе без окклюзии.
- **NPCESP** — `material_overlay` + `next_pass`-цепочка (body stencil → state-ring → LOS-tint), без дубликатов мешей. Состояния из `AI.currentState` (4 категории с цветами), фракции из `variant.faction`, фикс оружия игрока (патч шейдеров в transparent-проход).

Цель: взять обводку у ITH и механику состояний/цветов у NPCESP, отказаться от дубликатов мешей, сохранить world palette как атмосферу. Full-screen термал остаётся отдельным режимом без изменений.

## Режимы и NVG-гейт

```
NVG не надет  → всё выключено (поведение v1 сохранено)
NVG надет    → режим A или B; F6 переключает (тестовый хоткей)
```

### Режим A — World palette + контуры + эмиссия (новое)

- NVG-оверлей (`VTKNVG.gdshader`): world palette + light-based darken — как в v1.
- Боты **не** заливаются термалом на экране оверлея.
- Вместо этого — контур (`VTKOutline`) и термальная заливка тела по зонам (warm/mid/cold, переиспользуем BOT_PRESETS) в материалах NPC.
- Мины — эмиссия через стены.

### Режим B — Полный термальный вид (текущая сборка v1, без изменений)

- NVG-оверлей: палитра + термальная заливка ботов + эмиссия мин.
- Контуров нет (`VTKOutline` пассивен).

Переключение A↔B мгновенное: гасим/включаем подсистемы, NVG-оверлей не пересоздаётся.

## Архитектура

Вариант 1 — эволюция ThermalVTK (утверждён):

```
standalone mods/ThermalVTK/mods/ThermalVTK/
  ThermalVTK.gd        — автолоад, MCM, хоткеи (F6 = режим A/B)
  VTKNVG.gd            — NVG-оверлей: palette + darken + (режим B) термальная заливка
  VTKESP.gd            — НОВЫЙ: трекинг NPC (хуки AI + poll), фракции, состояния, PVisible
  VTKOutline.gd        — НОВЫЙ: контуры NPC, остывание трупов, дистанции, fade, кап
  VTKPaths.gd          — пути (расширить: AISpawner и пр.)
  VTKNVG.gdshader      — шейдер оверлея v1 (без изменений)
  VTKBot.gdshader      — шейдер заливки ботов v1 (без изменений)
  VTKOutline.gdshader  — НОВЫЙ: кольцо-контур (grow + rim + stencil)
```

Связи: `ThermalVTK.gd` → `VTKESP` → `VTKOutline`; `VTKNVG` не знает про ESP. Режим A/B — тумблеры, не перестройка дерева.

## Контур (VTKOutline + VTKOutline.gdshader)

Техника — **`material_overlay` с `next_pass`-цепочкой** (без дубликатов мешей):

1. **Body-проход**: stencil write 1, заливка тела термальным градиентом warm/mid/cold (переиспользуем BOT_PRESETS из v1), альфа ~0.4.
2. **Outline-проход**: stencil read != 1, `grow` вдоль нормалей, rim через `smoothstep`, цвет = цвет категории состояния. Depth test включён (LOS); при необходимости сквозь стены в радиусе through-walls — вариант с `depth_test_disabled` (по аналогии с двумя вариантами шейдеров у NPCESP: los_only / through-walls).
3. **PVisible flash**: поверх, короткая вспышка при `sensor.PVisible == true`.

Один `ShaderMaterial` на NPC — пуш цвета/альфы только при изменении (change-gate, как `_c_type`/`_c_state` у NPCESP).

## Трекинг и состояния (VTKESP.gd)

- **Discovery**: хуки `ai-activate-post`, `ai-deactivate-post`, `ai-changestate-post`, `ai-death-post` (RTVModLib, priority 100, `_caller` как NPCESP) + fallback-поллинг `currentState` каждые 12 кадров.
- **Тип**: `variant.faction` — враждебный (1..4) → один bot color; номад → зелёный всегда, состояния игнорируются.
- **Состояние**: `AI.currentState` → категории:

| Категория | Состояния (enum int) | Дефолт-цвет |
|---|---|---|
| Обычный | Idle(0), Wander(1), Loot(2), Guard(3), Patrol(4), Switch(15), Group(16) | bot color (янтарный) |
| Настороженный | Cover(5), Defend(10), Vantage(12) | жёлтый |
| Ищет/прячется | Hunt(9), Hide(6), Ambush(7), Lurk(14) | оранжевый |
| В бою | Combat(8), Attack(11), Grenade(13) | красный |
| **Номад** | всегда (не зависит от состояния) | зелёный |

- **PVisible**: отдельная ось, `sensor.PVisible` — вспышка поверх любого состояния.
- **Death**: записываем время смерти, тепло «остывает» — lerp альфы/цвета от тёплого к холодному за `corpse_decay` секунд.

## Дистанции и LOS

- **Distance (LOS)**: 0–300 м, контур при прямой видимости (depth test).
- **Through-walls**: 0–30 м, шаг 5, дефолт 5; при 0 — только LOS.
- **Fade**: от 50% дистанции альфа падает до 0 (как у NPCESP, `FADE_START_RATIO = 0.5`).
- **Кап** одновременных подсвеченных NPC: 24 (отбор по ближайшей дистанции).

## Мины и эмиссия

- Мины: эмиссия через стены, работает и в A, и в B (как в v1).
- Маркер номадов: **убираем** (заменён зелёным контуром номадов).

## MCM

Категории: General / Outline / States / Thermal / Distances.

| Ключ | Тип | Дефолт |
|---|---|---|
| outline_enabled | Bool | true |
| body_fill (термальная заливка тела в контуре) | Bool | true |
| corpse_decay (Float, 0–30 с) | Float | 8 |
| distance_los (Float, 0–300) | Float | 150 |
| through_walls (Float, 0–30, шаг 5) | Float | 5 |
| state_normal (bot color) | Color | янтарный |
| state_alerted | Color | жёлтый |
| state_hunting | Color | оранжевый |
| state_combat | Color | красный |
| nomad_color | Color | зелёный |
| pvisible_flash (Bool) | Bool | true |
| pvisible_color | Color | белый |
| outline_thickness | Float | 0.004 |
| outline_brightness | Float | 0.6 |
| mines_emission | Bool | true |

Хоткей F6 — тестовый, в МСМ не регистрируем (добавим позже при необходимости).

## Тесты и миграция

- Headless-тесты: `test_states.gd` (категории из currentState), `test_tracker.gd` (фракции, fade, death cooldown) — чистая логика без сцены.
- `pack.ps1` без изменений.
- Текущие 14 тестов остаются; `VTKNVG.gd` не ломаем (режим B = v1).
- Версия: минорный апдейт (новая функциональность, обратная совместимость сохранена).

## Известные риски

1. Взаимодействие world palette (прозрачный проход NVG-оверлея) с overlay-материалами NPC — проверить в игре: overlay рисуется поверх, но порядок прозрачного прохода может дать сюрприз.
2. Патч шейдеров оружия игрока (weapon-occlusion fix из NPCESP) обязателен, иначе ESP поверх ствола. Задача входит в реализацию.
3. RTS/пул ботов: переполнение капа 24 — проверить на картах с 30+ ботами.
4. `material_overlay` + stencil в Forward+ — проверить, что stencil-операции корректны в рендерере игры (Godot 4.6.3).
