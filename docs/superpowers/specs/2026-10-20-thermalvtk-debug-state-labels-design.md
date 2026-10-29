# ThermalVTK — подписи состояния над NPC в режиме отладки

**Дата:** 2026-10-20
**Статус:** на утверждении
**Связанные спеки:** `2026-10-20-thermalvtk-pipoff-orbit-detect-design.md` (та же версия 1.5.0),
`2026-10-19-thermalvtk-mode-a-palette-outline-design.md`
**Версия:** 1.5.0 (вторая фича в том же релизе)

## Что и зачем

Визуальная проверка словарика переноса `AI.State` → категория (`VTKStates.gd`:
`NORMAL_STATES`/`ALERTED_STATES`/`HUNTING_STATES`/`COMBAT_STATES`). Сырой стейт
меняется на NPC в реальном времени, а виден в игре только цвет обводки — аномалию
словарика сейчас заметить нельзя. В режиме отладки над каждой NPC печатаем две строки:
**имя сырого стейта** и **категорию**, получившуюся в моде.

## Решение

| Аспект | Решение |
|---|---|
| Гейт | Существующий MCM `debug_log` (CAT5, `ThermalVTK.gd:309`), уже зовёт `VTKDebug.set_enabled()`. Новый ключ не добавляем, `ThermalVTK.gd` не трогаем. |
| Содержание | Две строки: `Patrol` / `NORMAL`. Для номадов вторая строка — `NOMAD`. |
| Рисование | `Label3D` как ребёнок NPC: `billboard = BILLBOARD_ENABLED`, `no_depth_test = true`, высокий `render_priority`, контур текста (outline) для читаемости. |
| Расположение | Родитель — `node.mesh` (`AI.gd:25` — `@export var mesh: MeshInstance3D`, то есть всегда Node3D), позиция `Y = mesh.get_aabb().end.y + 0.1` в локальных координатах меша. Фолбэк (если `mesh` вдруг не Node3D) — родитель сам NPC, `Y = 1.9`. |
| Жизненный цикл | Создание/удаление/обновление — только в `VTKESP.gd`. |

## Изменения по файлам

### `mods/ThermalVTK/VTKStates.gd` (LF) — только чистая логика

- `const STATE_NAMES: Array[String]` — 17 имён в порядке `AI.gd:95`:
  `Idle, Wander, Loot, Guard, Patrol, Cover, Hide, Ambush, Combat, Hunt, Defend,
  Attack, Vantage, Grenade, Lurk, Switch, Group` (индексы 0..16).
- `static func state_name(state: int) -> String` — фолбэк `"State" + str(state)`
  для выхода за диапазон (словари полны, но защищаемся).
- `static func category_name(cat: int) -> String` — `NORMAL/ALERTED/HUNTING/COMBAT`,
  иначе `NORMAL`.
- `static func label_text(state: int, nomad: bool) -> String` —
  `"%s\n%s" % [state_name(state), "NOMAD" if nomad else category_name(category_of(state))]`.

Всё остаётся `static`/`RefCounted` без сцены и `load()` → покрывается headless.

### `mods/ThermalVTK/VTKESP.gd` (LF)

Состояние:

- `var _labels: Dictionary` — `id -> Label3D`.
- `var _labels_state: Dictionary` — `id -> int` (последний напечатанный сырой стейт).

Новые функции:

- `_label_make(entry, node)` — создаёт `Label3D`, ставит позицию (см. таблицу),
  текст `States.label_text(state, nomad)`; `nomad` берётся из записи
  (`Tracker.new_entry` кладёт `"nomad"`), сырой стейт — из `_read_state(node)`.
- `_labels_sync()` — один проход по `_entries`:
  - `VTKDebug.enabled == false` → снести все `Label3D`, очистить оба словаря, выйти;
  - запись есть, а метки нет → создать;
  - метка есть, записи нет или узел недействителен → снести;
  - `state` из `_read_state(node)` не совпал с `_labels_state[id]` → переписать `text`.
- `_label_free(id)` — снести метку + обе записи.

Точки вызова:

- `_process()` — сразу после `_weapon.tick()` (`:198`), **до** ранних `return`
  (иначе при отсутствии игрока метки не обновятся и при выключенном дебаге не снесутся).
- `set_enabled(false)` — рядом с `_outline.clear_all()` (`:72`), потому что там
  чистятся `_entries`.
- `_on_ai_deactivate()` — после `_entries.erase(...)` (`:154`).
- `_exit_tree()` — снести оставшиеся.

Ограничение текста — не чаще, чем меняется сырой стейт: каждый кадр только
`_read_state` + сравнение `int`, конкатенация строки лишь при расхождении.
`get("currentState")` на ≤40 нодах в кадр — пренебрежимо дёшево.

**Сознательно не делаем:** новый MCM-ключ, расстояние/экранный бюджет меток
(лимит: очень толстая карта может дать много меток — если в игре заметим, гейтнем
по дистанции отдельным заходом), фильтрация мёртвых NPC (запись живёт до
деактивации).

### `mods/ThermalVTK/VTKDebug.gd` — без изменений

Гейт — читаемый публичный `static var enabled` (`:8`); экспортирующую функцию не
добавляем, `set_enabled` уже прокинут из `_mcm_apply` (`ThermalVTK.gd:389`).

### `.check/project/tests/test_states.gd`

Добавить проверки: `state_name(0) == "Idle"`, `state_name(4) == "Patrol"`,
`state_name(16) == "Group"`, `state_name(99)` не падает и не пустой,
`category_name(2) == "HUNTING"`, `category_name(99) == "NORMAL"`,
`label_text(9, false) == "Hunt\nHUNTING"` (9 = `Hunt` из `HUNTING_STATES`),
`label_text(5, false) == "Cover\nALERTED"` (5 = `Cover` из `ALERTED_STATES`),
`label_text(5, true) == "Cover\nNOMAD"` (номад бьёт категорию). Вызвать из `_run()`
отдельной `t_labels()` рядом с существующими `t_*`; сами проверки `category_of`
сохранить.

Сверка индексов с ванилью обязательна: `AI.gd:95` —
`{Idle, Wander, Loot, Guard, Patrol, Cover, Hide, Ambush, Combat, Hunt, Defend,
Attack, Vantage, Grenade, Lurk, Switch, Group}` = 0..16, ровно как в четырёх
массивах `VTKStates.gd`.

## Риски (только в игре)

1. **Читаемость сквозь NVG/прицел.** Палитра оверлея перекрасит и метку, как и мир.
   `no_depth_test` + outline должны оставить её различимой; если нет — поднимем
   `render_priority` или покрасим в контрастный цвет.
2. **Высота метки.** AABB у скиннинг-меша считается в bind-позе, возможен снос
   вверх/вниз; лечится константой в `_label_make`, проверяется на первом NPC.
3. **Ложные метки на мёртвых** — запись живёт до деактивации; если мешает, сносить
   при `dead` в `_labels_sync`.

## Проверка

1. `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1` → зелёный,
   в списке должен остаться `test_states.gd` (количество тестов вырос на 0 — файл
   уже в `$tests`, `check.ps1:105`).
2. В игре: MCM → CAT5 → Debug log **on**, режим Contour, NVG надет.
   - над NPC две строки: сырой стейт меняется при переходах, вторая строка
     переключается `NORMAL → ALERTED → HUNTING → COMBAT`;
   - номады показывают `NOMAD`;
   - выключили Debug log → метки исчезли мгновенно (не требует перезахода карты);
   - переключили режим/сняли NVG → метки остались (зависят только от дебага и ESP);
   - выключили ESP (не CONTOUR) → меток нет.
3. Прогон обеих фич PIP-off (из первой спеки) — без ухудшений.
