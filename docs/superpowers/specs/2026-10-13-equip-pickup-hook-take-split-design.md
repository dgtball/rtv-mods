# Авто-экип через хук подбора + Take/Split в слоте экипировки

Дата: 2026-10-13
Статус: дизайн утверждён владельцем (вариант A), спецификация готова к ревью.
Связанные ветки: `audit` (текущая).

## Цель

Две правки вокруг экипировки:

1. **Авто-экип перевести с отслеживания количества на реальное событие подбора** —
   `Pickup.Interact()`. Убирает корень ложных срабатываний: игра при любом перекладывании
   в инвентаре временно перетасовывает узлы, и дельта количества это ловит. Событие подбора
   детерминировано.
2. **Починить ванильные `Take`/`Split` для предметов в слоте экипировки** — сейчас кнопки
   показываются, но молча ничего не делают (`contextGrid == null`). Должны перекладывать
   долю стака в инвентарь.

Бонус-правило: при подборе в слот уносится **только подобранное количество, но не больше
свободного места в слоте**; отложенное в инвентаре не трогается.

## Что выяснено в ваниле (по детокенизированным исходникам)

Источник — кэш modloader’а: `%APPDATA%\Road to Vostok\modloader_hooks\vanilla\Scripts\*.gd`
(пишет сам modloader в `_detokenize_script`). Это **настоящий** исходник игры, не дамп строк.

- **Подбор = `Pickup.Interact()`** (`Pickup.gd:23`):
  ```
  if interface.AutoStack(slotData, interface.inventoryGrid): ...queue_free()
  elif interface.Create(slotData, interface.inventoryGrid, false): ...queue_free()
  else: interface.PlayError()
  ```
  Успех ⇒ узел `Pickup` уходит в `queue_free()`. Провал ⇒ остаётся (PlayError).
- **`Interface.Create(slotData, targetGrid, useDrop)`** (`Interface.gd:1553`) инстанцирует
  `preload("res://UI/Elements/Item.tscn")`, `newItem.Initialize(self, slotData)`, кладёт в грид
  через `AutoPlace`. Возвращает `bool`.
- **`Interface.AutoStack(slotData, targetGrid)`** (`Interface.gd:1580`) сливает стек в
  существующую стопку того же `itemData.file` до `maxAmount`; при переполнении создаёт
  остаток через `Create`. Возвращает `bool`.
- **`Interface.Equip(targetItem, targetSlot)`** (`Interface.gd:1865`) переносит узел в слот
  (`reparent`, `State("Static")`, `equipped = true`, `rigManager.UpdateRig`).
- **`Interface.Unequip(targetSlot)`** (`Interface.gd:1886`) снимает узел из слота в
  `Interface`, возвращает узел.
- **`ContextTake`/`ContextSplit`** (`Interface.gd:2271,2248`) начинаются с
  `if contextItem == null || contextGrid == null: print("Null: Context ..."); return`.
  Далее уменьшают `contextItem.slotData.amount` и создают остаток `Create(newSlotData, contextGrid, true)`.
- **Ванильный `Context.Update`** (`Context.gd:50`) показывает `Split`, если
  `stackable && amount > 1`, и `Take` (`"Take (N)"`), если `stackable && amount > defaultAmount`.
  Для экипированного стака эти условия выполняются ⇒ кнопки видны, но
  `ContextSplit/ContextTake` выходят по `contextGrid == null`. Это и есть баг.
- **`Interface.Reset()`** (`Interface.gd:3351`) чистит `itemDragged`/`contextItem`/`contextGrid`/`contextSlot`.
- **modloader: replace-хуки.** Имя без суффикса (`interface-contexttake`) — слот единственного
  владельца. Колбэк зовётся с аргументами метода; если внутри вызвать `_lib.skip_super()`,
  ванильное тело пропускается. В моде уже используется (`VTKHooks.gd:1197`).
- **Wrap-surface фиксируется** сканом литеральных `.hook("...")` и секцией `[hooks]` в `mod.txt`.
  Имена хуков обязаны быть строковыми литералами.

## Раздел 1 — Авто-экип через хук `pickup-interact`

- `pickup-interact-pre` (`_lib._caller` = узел `Pickup`): запоминаем `itemData` и подобранное
  количество `P = slotData.amount` **до** того, как `AutoStack` изменит `slotData.amount`
  (в ветке переполнения `AutoStack` переписывает `slotData.amount` в остаток).
- `pickup-interact-post`: если `pickup.is_queued_for_deletion()` (подбор удался) и
  `EquipFlow.is_equipment(itemData)` — находим узел(ы) этого типа в `inventoryGrid` и вызываем
  `_equip_handle` с ограничением (см. раздел 2).
- `EQUIP_ARM_MS` (arm после `loadcharacter`/`newgame`) для авто-экипа **больше не нужен** как
  защита от фантомов: подбор — явное событие. Убираем вызовы `_arm_equip` из
  `_on_loadcharacter_post` (стр. ~253) и `_on_newgame_post` (стр. ~239); если потребителей не
  остаётся — удаляем сам `_arm_equip`, `EQUIP_ARM_MS` и поле `_equip_armed_at`.

## Раздел 2 — Правило переноса «только подобранное, до полного»

- Целевой слот: сначала **свободный** совместимый (`_find_free_slot`), иначе **занятый** тем же
  типом (`_find_occupied_slot`).
- `space = maxAmount − (занятое количество в слоте, 0 для свободного)`.
- `moved = clamp(min(P, space), 0, …)`; `P = 0` (нет подбора) или `space ≤ 0` ⇒ ничего не делаем.
- **Занятый слот:** `occ_sd.amount += moved`; `node.slotData.amount -= moved`; обновить
  `UpdateDetails` у обоих. Отложенное в инвентаре остаётся. (По сути текущий `_merge_into`,
  но с кэпом `min(P, space)` вместо «до полного»; текущий `merge_amounts` берёт `incoming` =
  весь стак — меняем на `P`.)
- **Свободный слот:**
  - если `moved == node.slotData.amount` — переносим узел целиком (`ig.Pick(node)` →
    `iface.Equip(node, slot)`), без остатка;
  - иначе — уменьшаем `node.slotData.amount` до `moved`, переносим узел в слот, а остаток
    (`бывшее − moved`) возвращаем в инвентарь через `AutoStack(newSlotData, inventoryGrid)`
    или `Create(newSlotData, inventoryGrid, true)`.
  - Если вернуть остаток не удалось (инвентарь полон по клеткам) — фоллбэк: переносим узел
    целиком (оборванных предметов быть не должно).
- Сопоставление предметов — по `slotData.itemData.file` (как ванильный `AutoStack`).
- Никакого отслеживания «новый/не новый узел» и дельт количества: убирается.

## Раздел 3 — Take/Split в слоте экипировки (replace-хуки)

- `interface-contextsplit` (replace, `_lib._caller` = `Interface`):
  - если `contextGrid != null` — не вмешиваемся (ваниль как есть);
  - если `contextGrid == null && contextSlot != null` — берём `contextItem`; `share =
    round(amount / 2)`; уменьшаем стак в слоте (`amount -= share`, `UpdateDetails`); отправляем
    `newSlotData(itemData, share)` в инвентарь через `AutoStack(...) || Create(..., inventoryGrid, true)`;
    `Reset()`, `HideContext()`, `PlayStack()`; `_lib.skip_super()`.
- `interface-contexttake` (`Interface.gd:2271`): то же, но `share = itemData.defaultAmount`.
- Если `contextItem == null` — не вмешиваемся (ваниль печатает «Null: Context …»).
- Дельту шлём через `AutoStack` + `Create`, чтобы сливалось с существующей стопкой
  (подтверждено заказчиком), а не плодило карманы.

## Хуки (регистрация)

В `VTKHooks._do_register()` рядом с существующими, имена — строковые литералы:

- `_hooks_equip.append(_lib.hook("pickup-interact-pre", _on_pickup_interact_pre))`
- `_hooks_equip.append(_lib.hook("pickup-interact-post", _on_pickup_interact_post))`
- `_hooks_context.append(_lib.hook("interface-contexttake", _on_context_take_replace))`
- `_hooks_context.append(_lib.hook("interface-contextsplit", _on_context_split_replace))`

`mod.txt`: в `[hooks]` добавить `res://Scripts/Pickup.gd = Interact` и
`res://Scripts/Interface.gd = ContextTake, ContextSplit` (совместно с литеральными `.hook(...)`).

Замечание по replace-слотам: они единственного владельца — если другой мод тоже заменит
`interface-contexttake`, победит первый; наш фоллбэк — не вмешиваться при `contextGrid != null`.

## Удаляемый код (следствие раздела 1)

Из `VTKHooks.gd` убираются: `_poll_equip`, `_update_equip_qty`, `_collect_equip_qty`, `_node_qty`,
`_add_node_qty`, `_item_type_key`, `_type_name`, поля `_equip_qty`, `_equip_low`, `_equip_names`,
`_equip_poll_at`, `_equip_iface_id`, константы `EQUIP_POLL_MS`, `EQUIP_DIP_MS`, а также
`_equip_seen`-остатки (если остались). Диагностические логи 4.15.10 (`grow …`, `dip confirmed …`)
уходят вместе с механизмом; в `_equip_handle`/`_equip_move`/`_merge_into` логи `Log.log` можно
оставить под общим `Log.enabled`. `_equip_on` (вкл/выкл фичи) сохраняется.

## Чистая логика `VTKEquip.gd` (headless)

Добавить чистые функции, покрываемые тестами (ни `load()`, ни путей внутрь игры):

- `split_share(amount: int) -> int` — `int(round(amount / 2.0))`.
- `take_share(default_amount: int) -> int` — `default_amount`.
- `equip_space(max_amount: int, occupied: int) -> int` — `max(0, max_amount - occupied)`.
- `equip_move(picked: int, occupied: int, max_amount: int) -> int` —
  `max(0, min(picked, equip_space(max_amount, occupied)))`.

`_equip_handle`/`_equip_move`/`_merge_into` в `VTKHooks` используют их и остаются рантайм-склейкой.

## Края и устойчивость

- `Pickup.gd` в игре отсутствует/не обёрнут (апдейт) ⇒ авто-экип просто не срабатывает, без ошибок.
- Предмет не экипируемый (`EquipFlow.is_equipment` false) ⇒ ничего.
- Нет подходящего слота / `space ≤ 0` ⇒ ничего (предмет остаётся в инвентаре).
- `pickup-interact-pre` без парного `-post` (игра упала между) ⇒ `P` перезапишется на следующем
  подборе; состояние — одно поле, гонок нет (один поток).
- Take/Split: `contextItem == null` ⇒ не вмешиваемся (ванильное сообщение в лог).
- `Create`-остаток при полном инвентаре ⇒ фоллбэк «перенести узел целиком» (раздел 2).
- `defaultAmount` для нестакающихся = 0/1 ⇒ `take_share` не создаёт пустой стак (кнопка Take
  ванильно и так показывается только при `amount > defaultAmount`).
- Имена методов `Pickup.Interact`, `Interface.ContextTake/ContextSplit` сверять по свежему
  детокенизированному кэшу после апдейта игры.

## Тесты

- Парсинг/стенд `.check/check.ps1` (16 скриптов) и `python .check\layout_check.py` — зелёные.
- Headless `test_hooks.gd`:
  - убрать фантомные `t_equip_poll_pickup` / `t_equip_poll_absorb` / `t_equip_unequip_kept`
    (проверяли дельту/узел), заменить на тест решения `_equip_handle` по `itemData`
    (free / occupied-merge / partial-leftover) через фейковый `Interface`/грид;
  - добавить тест `_on_pickup_interact_*` (мок `Pickup`, проверка `P` и вызова move).
- Headless `test_equip.gd` (или в `test_hooks.gd`): `split_share`, `take_share`, `equip_space`,
  `equip_move` (границы: 0, отрицательные, переполнение).
- Ручной игровой чек: 1) пусто → подбор → слот; 2) подбор при занятом слоте → merge; 3) инвентарь
  только → свободный слот; 4) Split/Take из слота → доля уходит в инвентарь; 5) перекладывание
  спичек в инвентаре больше не утаскивает их в слот.

## Версия и файлы

- Версия `4.15.10 → 4.16.0` (новое поведение/фичи: `loadouts/mod.txt`, `loadouts/mods/VTK/version.txt`,
  `README.md`).
- `loadouts/mods/VTK/VTKHooks.gd` — новый раздел подбора, replace-хуки, переработка
  `_equip_handle`/`_equip_move`/`_merge_into`, удаление polling.
- `loadouts/mods/VTK/VTKEquip.gd` — чистые помощники.
- `loadouts/mod.txt` — `[hooks]` и версия.
- `.check/project/tests/test_hooks.gd` — замена тестов; при необходимости новый `test_equip.gd`
  + строка в `$tests` в `.check/check.ps1` (список явный).
- `AGENTS.md` — обновить описание авто-экипа (событие подбора, Take/Split для слота), если там
  остались упоминания «свежего узла».

## Вне области

- Возврат вкладов/отмена Take/Split.
- Локализация имён предметов.
- Изменение внешнего вида контекстного меню (используем ванильные кнопки Split/Take).
- Хранение/миграции данных (формат сейвов не меняется).
