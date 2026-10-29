# Ванила-интеграция батча 5: чистка внутренностей без смены UX

Дата: 2026-10-15
Целевые версии: 4.17.4 (Kill) → 4.17.5 (Deposits) → 4.17.6 (Travel) → 4.17.7 (Death+Restart) — четыре патча

Источник: `docs/audit/vostok-toolkit-4.15.1.md` (§2 Vanilla parity, §5 roadmap батч 5),
верификация в `docs/audit/vostok-toolkit-4.15.1-gap.md`.

## Контекст

Аудит 4.15.1 нашёл десять мест, где мод стыкуется с ванилой через хрупкие
эвристики вместо ванильных событий и полей (пункты V1, V2, V3, V6, V8, V9, V10,
V11, V12, V13). Это не видимые игроку баги: функционал работает, но ломается при
обновлении игры и держится на отпечатках памяти вместо API. Батч 5 переводит
стыковку на ванильные точки входа.

Срезов четыре, они соответствуют четырём фичам, которые трогает каждая правка:
Kill, Deposits, Travel, Death+Restart. Между срезами нет общих незакоммиченных
изменений, поэтому каждый выпускается отдельным патчем и проверяется в игре
изолированно.

## Проблема (сводка по пунктам аудита)

**Kill (V6).** `_agent_root` (VTKHooks.gd:767) поднимается вверх до 12 предков,
проверяя `has_method("Activate") and not is_dead`; `_weapon_name_of` (:778)
перебирает шесть имён свойств оружия; `agent_kind` (VTKKillCounter.gd)
разбирает имя скрипта/узла/owner по подстрокам (`_identities`). Всё это —
археология по именам, а не обращение к ванильным полям.

**Deposits (V3).** `_on_deposit_pressed` (VTKHooks.gd:1209) и `_consume` (:1187)
сами мутируют инвентарь (`slotData.set("amount", left)`, `node.queue_free()`) и
вручную поднимают `iface.set("inputTarget"/"isInputting")` + `GetOutputItems()`,
вместо ванильного `Task.AddInputItem` / `Interface.Complete`.

**Travel (V1, V9, V12, V13).** `_teleport_internal` (VTKTravel.gd) зовёт
`Loader.LoadScene`, затем ждёт кадрами: `_wait_scene_change` (`SCENE_WAIT_FRAMES
= 600`), `_await_map_ready` (guard `180`/`1800` по `isCaching` плюс таймер
`0.35 c`), вручную пишет `gameData.set("interface"/"isOccupied")`. Ванильный
`Compiler.Spawn()` — это и есть точное событие прибытия (см. дизайн).

**Death+Restart (V2, V10, V8, V9, V12, V13).** `_poll_death`
(VTKHooks.gd:123) читает флаги `isDead`/`permadeath` каждый кадр;
`_resolve_gamedata` (:108) при промахе сканирует `get_tree().root`; `_on_restart_pressed`
вручную пишет `shelter`/`permadeath`/`difficulty` и имеет мёртвый фолбек
`_wipe_saves_for_restart`.

**Общий (V11).** Точечные `get_node_or_null` без единой точки реакции на промах:
когда версия игры убирает путь, мод молча перестаёт работать (как счётчик
убийств при потере `/root/VTKUI`).

## Цели

1. Атрибуция киллов — из ванильных полей агента (`identifier`/`variant`), а не
   из имён скриптов/узлов.
2. Закрытие интерфейсов и вклад предметов — через ванильные `Interface`/`Task`.
3. Телепорт и переход между картами — по событиям ванилы (`Compiler.Spawn`,
   `SceneTree.scene_changed`), без пофреймовых guard'ов и таймеров.
4. Экран смерти и рестарт — по событию загрузки сцены смерти, без пофреймового
   скана флагов; убрать мёртвый фолбек и избыточные записи.
5. Единый хелпер реакции на промах пути (V11): один раз логировать, дальше молча.
6. Ни одного видимого игроку изменения поведения.

## Не-цели

- Не меняем UX/раскладку вкладок, экрана смерти, счётчика и ленты киллов, вклада.
- Не трогаем вычисления `VTKDeposits.gd` (чистая математика леджера).
- Не трогаем батч 4 (UI) и уже выпущенный 4.17.2/4.17.3.
- Не вводим новых настроек MCM и новых ключей локализации сверх необходимых.
- Не занимаемся пунктами аудита, отмеченными WON'T-FIX (D13, D15, V18).
- Не рефакторим монолит `VTKUI.gd` (это батч 6).
- Не добавляем новых тестовых файлов, кроме правок `test_hooks.gd`.

## Принципы

- **Никакого видимого игроку изменения**: после каждого среза игру можно прогнать
  и убедиться, что поведение прежнее. Срез коммитится и патчится отдельно, откат —
  по одному срезу.
- **Ванила — источник правды**: событие берём хуком на ванильный метод, поле —
  напрямую с агента/`gameData`, а не угадыванием по именам.
- **Математика мода остаётся в моде**: чистые функции (`VTKDeposits`, `VTKPicker`,
  `VTKNotes`) не трогаем — меняется только оркестровка.
- **Fail-closed (V11)**: отсутствие ванильного пути логируется один раз на путь и
  деградирует безопасно, а не молчит.

## Дизайн

### Срез 1 — Kill (V6 + V11) → 4.17.4

**Ванильные ориентиры.** Атакующий приходит как `identifier` — так игра зовёт
`hitCollider.ApplyDamage(..., identifier)` (`AI.gd:1178`). У агента есть
`@export var identifier: Node3D` (`AI.gd:20`) и `var variant: AIData` (`AI.gd:60`).
Фракция — `variant.faction` (enum `AIData.Faction`: `Nomad`/`Boss`/…), сравнение
как в ваниле (`variant.Faction.Nomad`). Оружие ИИ — поле на агенте
(`weaponData`/`weaponType`, `AI.gd:65-67`; `weapon`, `AI.gd:61`).

**Изменения.**
- Подъём к агенту от `identifier` — по маркеру `"variant" in n` (1–2 уровня),
  вместо `_agent_root` с 12 предками и предикатом `Activate`+`dead`.
- `agent_kind`: `nomad` при `variant.faction == Nomad`, `""` при `Boss`
  (исключён — как сейчас Punisher/Bogeyman), иначе `enemy`. `_identities`/
  разбор подстрок удаляются.
  **Поведение боссов сохраняется как есть** (Boss → не считается). Смена этого
  правила — отдельное решение вне батча 5; см. открытый вопрос 8.
- Имя оружия — из поля агента, вместо `_weapon_name_of` (перебор шести имён).
- Остаются: латч `_player_hits` (окно 15 c), `_last_damager`, `_seen_deaths`,
  фолбек `_direction_is_player` (когда direction — вектор игрока).
- V11: вводится хелпер (см. раздел V11); `_rig_weapon_name`/`_find_inventory_node`
  переводятся на него.

**Затрагивает.** `VTKHooks.gd` (`_on_ai_weapon_damage`, `_on_ai_explosion`,
`_emit_kill_event`, `_agent_root`, `_weapon_name_of`, `_weapon_str`),
`VTKKillCounter.gd` (`agent_kind`, `_identities`, `agent_display_name`,
`_is_agent`), возможно `VTKFeed.gd`.

**Probe (в плане).** Значения enum `AIData.Faction` (headless по `RTVcopy/extracted`);
какое поле агента даёт имя оружия; `variant.name`/`nicknames` для display-name.
Если `variant.faction` не воспроизводит различение Guard/Military/Bandit —
оставить имя скрипта как вторичный признак.

### Срез 2 — Deposits (V3) → 4.17.5

**Ванильные ориентиры.**
- `Task.AddInputItem(slotData)` (`Task.gd:194`): помечает совпавшую ячейку
  `inputGrid` через `child.State("Selected")` и зовёт `CanComplete()`.
- `Interface.InputSelection()` (`Interface.gd:1438`): образец ванильного
  add/remove — selected → `RemoveInputItem`, иначе при `CanInput` → `State("Selected")`
  + `AddInputItem`.
- `Interface.Complete(data)` (`Interface.gd:1460`): `trader.CompleteTask(taskData)` +
  `UpdateTraderInfo()` + `DestroyInputItems(data)` (удаляет выбранные предметы
  инвентаря) + `GetOutputItems()` (выдаёт награды) + `ResetInput()`.
- `Interface.StartInput(target)` (`:1416`) выставляет `inputTarget`.

**Изменения (уточнено при планировании).**
- Завершение — `Interface.StartInput(card)` затем `Interface.Complete(task_data)`
  вместо ручной установки `inputTarget`/`isInputting` + `GetOutputItems()` +
  `ResetInput()` + повторных `CompleteTask`/`UpdateTraderInfo`.
- `VTKDeposits.gd` (чистая математика) **не трогаем**; `_refresh_notes_for`
  (обновление Notes на месте) сохраняется.
- **Пометка ячеек остаётся собственной** (`_paint_cell`: ✓-бейдж + `State("Selected")`).
  `Task.AddInputItem` не используется: частичный вклад (amount) не ложится на
  целые ячейки `inputGrid`, а ✓-бейджа у ванильного метода нет — переход на него
  изменил бы вид. `CanComplete()` уже вызывается.
- V9/V12: убрать прямые записи состояния интерфейса, где ванильный вызов их
  покрывает. `slotData.set("amount", left)` **остаётся**: у `SlotData.amount` нет
  сеттера (методы `Update/Reset/GridSave` — про ячейку, не про количество).

**Затрагивает.** `VTKHooks.gd` (`_on_deposit_pressed:1209`, `_consume:1187`,
`_on_task_complete_pressed`, `_selected_stacks:1156`).

**Probe.** Наличие ванильного частичного-удаления стека; достаточно ли
`Interface.Complete` без предварительного `StartInput` (в ваниле Complete зовётся
из `Task._on_complete_pressed`, где `inputTarget` уже стоит).

### Срез 3 — Travel (V1, V9, V12, V13) → 4.17.6

**Ключевая находка.** Ванильный переход между картами:

1. `Loader.LoadScene(target)` выставляет `gameData.shelter`/`permadeath`/`tutorial`/
   `menu` по имени сцены (`Loader.gd:216-375`), затем через ~2 c меняет сцену.
2. `Compiler._ready()` ставит `isCaching = true` (`Compiler.gd:25`), камера
   крутится для прогрева шейдеров.
3. `Compiler._physics_process` после прогрева снимает `isCaching`, затем зовёт
   `Spawn()` (`Compiler.gd:47`).
4. `Compiler.Spawn()` расставляет контроллер по `gameData.previousMap` и группе
   `Transition` (`Compiler.gd:205-214`) и снимает `isTransitioning`/`freeze`/
   `isOccupied` (`:217-220`).

Значит **`Compiler.Spawn()` — точное событие «карта готова, игрок поставлен»**, а
`SceneTree.scene_changed` — точное событие смены сцены. Оба заменяют пофреймовые
ожидания.

**Изменения.**
- Добавить хук `compiler-spawn-post` → прибытие. Он заменяет `_await_map_ready`
  (guard `180`/`1800` + `0.35 c`).
- Ожидание смены сцены — `await get_tree().scene_changed` вместо
  `_wait_scene_change`/`SCENE_WAIT_FRAMES = 600`.
- Оставить `loader.LoadScene(target)`: у телепорта нет ванильного Transition-узла,
  а `previousMap`/`currentMap` — **входные данные** ванильного `Compiler`, не обход
  API (ванила их читает в `Compiler.gd:133+`, а проставляет переход по границе
  карты). Записи сохранить.
- `_close_interfaces` — убрать прямые `gameData.set("interface"/"isOccupied")`,
  оставить ванильный закрыватель интерфейса (probe: `Interface.Close()`/`UIManager`).
- Удалить `SCENE_WAIT_FRAMES`, `0.1`, `0.35`, `180`, `1800`.
- Регистрация хука в `mod.txt` секции `[hooks]` и в `VTKHooks._ready`.

**Затрагивает.** `VTKTravel.gd` (`_teleport_internal`, `_wait_scene_change`,
`_await_map_ready`, `_close_interfaces`, константы), `VTKHooks.gd` (регистрация
хука), `loadouts/mod.txt` (`[hooks]`).

**Probe.** Достаточно ли `Interface.Close()` для закрытия интерфейса перед
переходом; поведение `compiler-spawn-post` на первой загрузке игры (не телепорт)
— хук не должен ничего сломать, если карта стартует сама.

### Срез 4 — Death+Restart (V2, V10, V8, V9, V12, V13) → 4.17.7

**Ванильные ориентиры.** Смерть ведёт в сцену `Death` (`Character.gd:370
Loader.LoadScene("Death")`). `Loader.LoadScene` выставляет `shelter`/`permadeath`
по имени сцены, поэтому ручные записи в `_on_restart_pressed` избыточны.

**Изменения.**
- **V8**: `_resolve_gamedata` — только типизированный `load(GAME_DATA_RES)` с
  аннотацией; убрать флаг-скан `get_tree().root`.
- **V2**: детект смерти — событийно через `loader-loadscene-post` при
  `scene == "Death"`, вместо пофреймового чтения `isDead`/`permadeath`. Repurpose
  ванильной кнопки на экране смерти **остаётся** (это фича мода); латч
  `_death_latched` ведётся от хука.
- **V10a**: удалить `_wipe_saves_for_restart` и её вызов (ванильный
  `Loader.NewGame` есть всегда); править `test_hooks.gd:294-304` (убрать
  фолбек-кейс).
- **V10b**: убрать в `_on_restart_pressed` избыточные `gd.set("shelter")`/
  `gd.set("permadeath")` — их уже выставляет `Loader.LoadScene(start_map)`
  (`Loader.gd:252-361`); править `test_hooks.gd:284/288`.
- Оставить: `isDead = false`, `previousMap = ""`, `Loader.NewGame(difficulty, season)`
  — синк difficulty/permadeath делает существующий `loader-newgame-post`
  (`_on_newgame_post`).
- V9/V12/V13: убрать прямые записи ванильного состояния и тайминги там, где их
  покрывает событие.

**Затрагивает.** `VTKHooks.gd` (`_poll_death:123`, `_resolve_gamedata:108`,
`_handle_death_screen:1269`, `_on_restart_pressed`, `_wipe_saves_for_restart:1380`,
регистрация `loader-loadscene-post`), `.check/project/tests/test_hooks.gd`
(строки 284/288/294-304), `loadouts/mod.txt` (`[hooks]`) при добавлении хука.

**Probe.** Нужны ли ещё записи `difficulty` в restart (дублирует
`_on_newgame_post`); не срабатывает ли `loader-loadscene-post` на другие сцены.

### Общий элемент — V11 (вводится в срезе 1)

Хелпер в `VTKPaths.gd` (или рядом), статический, без состояния:

```gdscript
# Резолв пути ванилы; при промахе — один WARN на путь, дальше молча (fail-closed).
static func resolve(owner: Node, path: String) -> Node:
    var n := owner.get_node_or_null(path)
    if n == null:
        _warn_once(path)
    return n
```

`_warn_once` держит статическую таблицу `{path: true}` и пишет в `VTKLog`
(`WARN`) только первый раз. Это заменяет молчаливые точечные `get_node_or_null`
там, где промах означает отказ фичи (счётчик убийств и т.п.). Счётчик
`preload`/`layout_check` не затрагивается.

### Локализация

Новых строк не добавляется сверх тех, что появятся при ошибках V11 (если
сообщение логируется, а не показывается игроку — ключей `VTKLoc.RU` не нужно).
`keycheck.py` — без новых stale.

## Точки изменения

| Файл | Срез | Что |
|---|---|---|
| `loadouts/mods/VTK/VTKHooks.gd` | 1 | `_agent_root`→резолв по `variant`; `_weapon_name_of`→поле агента; `_emit_kill_event` |
| `loadouts/mods/VTK/VTKKillCounter.gd` | 1 | `agent_kind` по `variant.faction`; `_identities` удалить; `agent_display_name`; `_is_agent` |
| `loadouts/mods/VTK/VTKPaths.gd` | 1 | V11-хелпер `resolve` + `_warn_once` |
| `loadouts/mods/VTK/VTKHooks.gd` | 2 | `_on_task_complete_pressed` → `Interface.StartInput`+`Interface.Complete` (пометка ячеек и `_consume` остаются) |
| `loadouts/mods/VTK/VTKTravel.gd` | 3 | `_teleport_internal`/`_wait_scene_change`/`_await_map_ready`/`_close_interfaces`; −константы |
| `loadouts/mods/VTK/VTKHooks.gd` + `loadouts/mod.txt` | 3 | хук `compiler-spawn-post` |
| `loadouts/mods/VTK/VTKHooks.gd` | 4 | `_poll_death`→хук; `_resolve_gamedata` (V8); `_on_restart_pressed` (V10b); −`_wipe_saves_for_restart` (V10a) |
| `.check/project/tests/test_hooks.gd` | 4 | строки 284/288/294-304 |
| `CHANGELOG.md`, `loadouts/mod.txt`, `loadouts/mods/VTK/version.txt`, `README.md` | 1-4 | версии 4.17.4-4.17.7 (в тасках релиза) |

Стенды `layout_check.py` (`GONE`/`PRESENT`/`HOOKS_GONE`) и `check.ps1` правок
списков не требуют, кроме явной регистрации новых хуков в тесте арностей
(`test_hooks.gd` `t_post_callback_arity`), если новый хук — post не-void.

## Тестирование

Гейты на каждый срез: `py -3 .check\layout_check.py` (exit 0) и
`powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1` (exit 0,
«Parse check passed: 16 scripts», «Tests passed: 9 file(s)»).

- Срез 1: расширить `test_hooks.gd` атрибуцией (если логика чистая); проверить,
  что `agent_kind`/резолв агента тестируемы headless.
- Срез 4: править `test_hooks.gd:284/288/294-304` (V10a/b); `t_post_callback_arity`
  обновить, если добавлен не-void post-хук.

Стенды ловят парсинг и тесты, но не работу в игре — поведенческая проверка только
ручная (см. чек-листы срезов в разделе «Проверка в игре»).

## Проверка в игре (ручная, по срезам)

- **Kill:** убить Nomad / Bandit / Guard / Military — счётчик растёт, лента
  показывает верные kind/name/weapon; хедшот; взрыв гранатой; килл ИИ-об-ИИ не
  считается; босс (Punisher/Bogeyman) не считается — **поведение как до правки**.
- **Deposits:** частичный и полный стек; у Доктора (нестакающиеся) и Generalist;
  Complete выдаёт награды; открытая вкладка Notes обновляется на месте; прогресс
  сходится с Tasks.
- **Travel:** на карту (спавн на входе); в убежище (`unlocked_only` off/on); к
  каждому из трёх трейдеров (игрок стоит у трейдера лицом к нему); из убежища и
  обратно; нет зависания «Teleport in progress».
- **Death+Restart:** обычная смерть → кнопка Restart → новая игра; ironman-смерть
  (Apartments/Terminal/Airfield) → Restart в случайной ironman-карте, permadeath
  сохраняется; продолжение после не-ironman смерти не ломается; `SaveWorld`/
  `SaveShelter` после рестарта корректны.

## CHANGELOG (видимый игроку эффект)

Изменения внутренние; по правилам `AGENTS.md` формулируем как надёжность, без
имён методов/файлов. Предлагаемые строки (по одному патчу):

- `## [4.17.4]` Fixed: «Kill attribution is more reliable for unusual weapon and
  explosion kills.»
- `## [4.17.5]` Fixed: «Depositing items into a task is more robust and no longer
  interferes with the vanilla task flow.»
- `## [4.17.6]` Fixed: «Map travel and shelter teleport are more reliable across
  scene changes.»
- `## [4.17.7]` Fixed: «The death screen and restart are more reliable, especially
  in ironman.»

## Риски

- **Kill — смена эвристики атрибуции.** Наибольший риск: ванильные поля могут не
  воспроизвести различение, которое сейчас даёт имя скрипта (Guard/Military/Bandit;
  исключение Punisher/Bogeyman). Митигация: probe enum до правок; имя скрипта —
  вторичный признак, если нужно; полный ручной чек-лист киллов.
- **Deposits — частичный стек.** Ванильный `Pick` удаляет узел целиком; частичное
  удаление надо подтвердить probe. Иначе оставить ванильный `SlotData`-сеттер.
- **Travel — хук `compiler-spawn-post` на первой загрузке.** Хук срабатывает и
  при обычном старте карты, не только при телепорте. Митигация: обработчик
  проверяет, что телепорт запрошен модом.
- **Death+Restart — тесты и ironman.** Правка `test_hooks.gd` неизбежна (V10a/b);
  надо не потерять проверку синка difficulty.
- **Общий.** Стенд `.check` не видит рантайм-путей; каждая правка проверяется
  руками. Снапшоты перед правками (`%TEMP%\opencode\vtk-snap-*`) для отката.

## Сборка и выпуск

Порядок батча (по срезам, каждый — полный цикл):

1. `py -3 .check\layout_check.py` → exit 0.
2. `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1` → exit 0.
3. Поднять версию в `loadouts/mod.txt` (`4.17.4`…`4.17.7`) + `version.txt`/`README.md`/`CHANGELOG.md`.
4. `powershell -ExecutionPolicy Bypass -File pack.ps1`.
5. Скопировать `Loadouts.vmz` в `D:\SteamLibrary\steamapps\common\Road to Vostok\mods`.
6. Ручной чек-лист среза в игре; при успехе — следующий срез, при провале — откат среза.

## Открытые probe-вопросы (решает план, не спек)

1. Значения enum `AIData.Faction`; воспроизводит ли `variant.faction` различение
   Guard/Military/Bandit и исключение Punisher/Bogeyman.
2. ~~Поле имени оружия на агенте~~ **решено:** `AI.gd:66 weaponData: WeaponData`,
   имя — `weaponData.name` (`weaponType` только `"Pistol"`/`"Rifle"`).
3. ~~`variant.name`/`nicknames` для display-name~~ **решено:** `variant.name`
   (`Bandit/Nomad/Guard/Military/Punisher/Bogeyman`); `nicknames` — только Nomad,
   в ленте не используется (поведение прежнее).
4. ~~Ванильный сеттер частичного стека~~ **решено:** сеттера нет (`SlotData.amount`
   — поле), оставляем `set("amount", left)`.
5. Достаточно ли `Interface.Close()` для закрытия интерфейса перед переходом.
6. Нужны ли записи `difficulty` в restart (дублирует `_on_newgame_post`).
7. Поведение `compiler-spawn-post` на первой загрузке карты.
8. **Боссы (вне батча 5).** Сейчас `agent_kind` исключает `Boss`-фракцию
   (Punisher/Bogeyman) — они не считаются и не попадают в ленту. Боссы — тоже NPC;
   надо ли их считать/показывать, владелец решит отдельно. Батч 5 поведение
   **не меняет**, только переносит признак на `variant.faction`.
