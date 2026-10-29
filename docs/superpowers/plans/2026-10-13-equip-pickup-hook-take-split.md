# Авто-экип через подбор + Take/Split в слоте экипировки — план реализации

Дата: 2026-10-13
Спека: `docs/superpowers/specs/2026-10-13-equip-pickup-hook-take-split-design.md`

## Как читать этот план

Для инженера, который не знает ни игры, ни мода. Каждая задача — законченный
шаг с тестом и прогоном стенда. Термины:

- **Слот (equip slot)** — узел `FakeSlot`/реальный слот экипировки с
  параметром `hint` (по нему `VTKData._is_equip_slot` отличает слот от Label).
- **Узел предмета** — Node с полем `slotData` (ресурс `SlotData`: `itemData`,
  `amount`). Лежит ребёнком `inventoryGrid` или слота.
- **Подбор** — ванильный `Pickup.Interact()`; удачный подбор вызывает
  `queue_free()` на узле `Pickup`.
- Выражение `_lib._caller` — узел, чей метод сейчас обёрнут modloader’ом.

### Коммиты

Владелец разрешил **коммиты по задачам** в этом запуске (SDD-ревью опирается на
diff `BASE..HEAD`). Каждая задача завершается коммитом её файлов с осмысленным
сообщением. Пуш — только по отдельной просьбе владельца.

**Важно: `.check/` не отслеживается git** (корневой `.gitignore` — `/*` с белым
списком `assets/`, `loadouts/`, `docs/vostokmods/`; `docs/superpowers/` тоже вне
git). Поэтому в коммит попадают только отслеживаемые файлы задачи:
`loadouts/**`, `loadouts/mod.txt`. Тесты (`.check/project/tests/*`) и правки
документации остаются в рабочем дереве — их нельзя `git add` без `-f`, и это
ожидаемо. Для ревью контроллер отдельно прикладывает изменённые тест-файлы к
пакету ревью, чтобы ревьюер их видел.

### Стенды (гейт после каждой задачи)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1 -Godot "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe"
py .check\layout_check.py
```

Зелёный `check.ps1`: парсинг 16 скриптов + строка `tests passed` в каждом из 8
тест-файлов, код выхода 0, и НИ ОДНОЙ строки `SCRIPT ERROR` / `Invalid call` /
`Parse Error`. Зелёный `layout_check.py`: `layout exit: 0`.

### Отступы и кодировка

Отступы — только табы. `VTKHooks.gd` хранится с LF, `VTKData.gd`/`VTKUI.gd`/
`VTKSurface.gd` — CRLF. Инструмент `edit` сохраняет EOL сам; Python-правки —
только через `C:\Users\home\AppData\Local\Temp\opencode\vtk_eol.py`.

---

## Структура файлов

| Файл | Ответственность | Что меняется |
|---|---|---|
| `loadouts/mods/VTK/VTKEquip.gd` | чистая математика экипировки | +`split_share`/`take_share`/`equip_space`/`equip_move`; −`merge_amounts` |
| `loadouts/mods/VTK/VTKHooks.gd` | рантайм-склейка: хуки подбора/контекста, перенос в слот | новые хендлеры; переработка `_equip_move`/`_merge_picked`; удаление polling |
| `loadouts/mod.txt` | декларация хуков и версия | +`Pickup.gd`, `+Interface.gd`; версия `4.16.0` |
| `loadouts/mods/VTK/version.txt`, `README.md` | отображаемая версия | `4.16.0` |
| `.check/project/tests/test_equip.gd` | тесты чистой математики | новые функции, удаление `t_merge` |
| `.check/project/tests/test_hooks.gd` | тесты рантайма | новые фейки и тесты подбора/контекста; удаление poll-тестов |
| `AGENTS.md` | заметки для будущих сессий | строка о хуках подбора (void, без `_result`) |

Декомпозиция по ответственности: чистая логика живёт в `VTKEquip`, склейка — в
`VTKHooks`. Тесты соответствуют слою: `test_equip.gd` (математика, без сцены),
`test_hooks.gd` (узлы/хуки).

---

## Task 1 — Чистая математика `VTKEquip`

**Files:**
- Modify: `loadouts/mods/VTK/VTKEquip.gd`
- Test: `.check/project/tests/test_equip.gd`

Интерфейс (используется в Task 2 и Task 4):

```gdscript
static func split_share(amount: int) -> int          # доля Split
static func take_share(default_amount: int) -> int   # доля Take
static func equip_space(max_amount: int, occupied: int) -> int   # свободное место (-1 = без лимита)
static func equip_move(picked: int, occupied: int, max_amount: int) -> int   # сколько уедет
```

- [ ] **1.1 Красный тест.** В `test_equip.gd` замени тело `t_merge()` на
      `t_move()` и вызов `t_merge()` на `t_move()`, плюс добавь вызов `t_split()`
      после `t_decide()` в `_init()`:

```gdscript
func _init() -> void:
	t_slots()
	t_decide()
	t_split()
	t_move()
	print("")
	if fails == 0:
		print("Equip tests passed")
		quit(0)
	else:
		print("Equip tests failed: ", fails)
		quit(1)

func t_split() -> void:
	ck(E.split_share(40) == 20, "split(40) -> 20")
	ck(E.split_share(21) == 10, "split(21) -> 10 (как ванильное целочисленное деление)")
	ck(E.split_share(1) == 0, "split(1) -> 0")
	ck(E.take_share(10) == 10, "take_share отдаёт defaultAmount")

func t_move() -> void:
	ck(E.equip_space(300, 0) == 300, "пустой слот -> весь лимит")
	ck(E.equip_space(300, 295) == 5, "место = лимит - занято")
	ck(E.equip_space(300, 300) == 0, "полный стек -> 0")
	ck(E.equip_space(0, 0) == -1, "нет лимита (нестакающийся) -> -1")
	ck(E.equip_move(20, 0, 300) == 20, "влезает целиком")
	ck(E.equip_move(20, 295, 300) == 5, "режется по свободному месту")
	ck(E.equip_move(20, 300, 300) == 0, "некуда -> 0")
	ck(E.equip_move(1, 0, 0) == 1, "нестакающийся едет целиком")
	ck(E.equip_move(-3, 0, 300) == 0, "отрицательное -> 0")
```

- [ ] **1.2 Прогон (красный).** `check.ps1` печатает `SCRIPT ERROR` / тест падает:
      `Invalid call. Nonexistent function 'split_share'`.

- [ ] **1.3 Реализация.** В `VTKEquip.gd` добавь в конец. **`merge_amounts`
      НЕ удаляй в этой задаче:** её единственный потребитель —
      `VTKHooks._merge_into` (строка 517) — живёт до переписывания в Task 2.3е,
      поэтому удаление здесь роняет парсинг `VTKHooks.gd`. `merge_amounts`
      удаляется в Task 3.2, когда потребителя уже нет.

```gdscript
# Доля стака, уходящая при Split: ванильная формула (целочисленное деление
# amount / 2, см. Interface.ContextSplit).
static func split_share(amount: int) -> int:
	return int(amount / 2.0)

# Доля стака, уходящая при Take: ванильный defaultAmount предмета.
static func take_share(default_amount: int) -> int:
	return default_amount

# Свободное место в слоте: maxAmount минус занятое. -1 = лимита нет
# (нестакающийся предмет, maxAmount <= 0), место не ограничено.
static func equip_space(max_amount: int, occupied: int) -> int:
	if max_amount <= 0:
		return -1
	var s := max_amount - occupied
	return s if s > 0 else 0

# Сколько уедет из подобранного: не больше свободного места слота.
static func equip_move(picked: int, occupied: int, max_amount: int) -> int:
	var p := picked if picked > 0 else 0
	var room := equip_space(max_amount, occupied)
	if room < 0:
		return p
	return p if p < room else room
```

- [ ] **1.4 Прогон (зелёный).** `check.ps1` → `tests passed`, `layout_check.py` →
      `layout exit: 0`.

---

## Task 2 — Авто-экип по событию подбора

**Files:**
- Modify: `loadouts/mods/VTK/VTKHooks.gd`
- Modify: `loadouts/mod.txt`
- Test: `.check/project/tests/test_hooks.gd`

Интерфейс (используется в Task 3 при удалении старого кода):

```gdscript
var _pickup_pending: int = 0
func _on_pickup_interact_pre() -> void
func _on_pickup_interact_post() -> void
func _find_inventory_node(ig, res) -> Node
func _equip_picked(iface, ig, res, picked: int) -> void
func _equip_move(iface, ig, node, sl, picked: int) -> void
func _do_equip_move(iface, ig, node, sl) -> void
func _merge_picked(iface, ig, node, occ, occ_sd, res, picked: int) -> void
```

- [ ] **2.1 Красный тест.** В `test_hooks.gd`:

  (а) Расширь фейки (после `class FakeItem`, строки 525–530). Добавь
  `class FakePickup`, методы `AutoStack`/`Create`/`Reset`/`HideContext`/`PlayStack`
  и реальный reparent в `FakeIface.Equip`, плюс `slotData`-адресацию. Замени
  `class FakeIface` (строки 541–554) на:

```gdscript
class FakePickup extends Node:
	var slotData = null
	var interface = null

class FakeIface extends Node:
	var inventoryGrid = null
	var equipment = null
	var equipped: Array = []
	var stats_calls := 0
	var created: Array = []

	func Equip(node, sl) -> void:
		equipped.append([node, str(sl.name)])
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		sl.add_child(node)

	func UpdateStats(_force) -> void:
		stats_calls += 1

	func PlayEquip() -> void:
		pass

	func PlayStack() -> void:
		pass

	func Reset() -> void:
		pass

	func HideContext() -> void:
		pass

	func AutoStack(sd, grid) -> bool:
		if grid == null or sd == null:
			return false
		var res = sd.get("itemData")
		if res == null:
			return false
		var maxa := int(res.get("maxAmount"))
		var amt := int(sd.get("amount"))
		for el in grid.get_children():
			if not is_instance_valid(el):
				continue
			var esd = el.get("slotData")
			if esd == null or str(esd.get("itemData").get("file", "")) != str(res.get("file", "")):
				continue
			var room := maxa - int(esd.get("amount"))
			if room <= 0:
				continue
			if amt <= room:
				esd.set("amount", int(esd.get("amount")) + amt)
				return true
			esd.set("amount", int(esd.get("amount")) + room)
			sd.set("amount", amt - room)
			return Create(sd, grid, false)
		return false

	func Create(sd, grid, _use_drop) -> bool:
		created.append(sd)
		if grid == null:
			return false
		var it := FakeItem.new()
		it.slotData = sd
		grid.add_child(it)
		return true
```

  (б) Замени старые `t_equip_flow` / `t_equip_poll_pickup` / `t_equip_poll_absorb`
  / `t_equip_unequip_kept` (строки 556–783) на новые тесты подбора и убери
  `_mk_iface`/`_poll`/`_poll_seed` (больше не нужны):

```gdscript
func _mk_iface2() -> Dictionary:
	var iface := FakeIface.new()
	iface.name = "Interface"
	var ig := FakeGrid.new()
	ig.name = "inventoryGrid"
	iface.inventoryGrid = ig
	iface.add_child(ig)
	var equip := Node.new()
	equip.name = "Equipment"
	iface.equipment = equip
	iface.add_child(equip)
	root.add_child(iface)
	return {"iface": iface, "ig": ig, "equip": equip}

func _mk_pickup(iface, sd) -> FakePickup:
	var p := FakePickup.new()
	p.name = "Pickup"
	p.slotData = sd
	p.interface = iface
	root.add_child(p)
	return p

# Свободный слот: подбор уносит подобранное количество из инвентаря в слот.
func t_equip_pickup_free() -> void:
	var h = TestHooks.new()
	root.add_child(h)
	var c := _mk_iface2()
	var lib := FakeLib2.new()
	h._lib = lib
	var rifle := {"file": "AKM", "name": "AKM", "slots": ["Primary"]}
	var primary := FakeSlot.new(); primary.name = "Primary"; primary.hint = "Primary"
	c["equip"].add_child(primary)

	var psd := FakeSD.new(); psd.itemData = rifle; psd.amount = 1
	var p := _mk_pickup(c["iface"], psd)
	lib._caller = p
	h._on_pickup_interact_pre()
	# симуляция ванильного Create: предмет лёг в свободную клетку инвентаря
	var gun := FakeItem.new()
	var gsd := FakeSD.new(); gsd.itemData = rifle; gsd.amount = 1; gun.slotData = gsd
	c["ig"].add_child(gun)
	p.queue_free()
	h._on_pickup_interact_post()
	ck(c["iface"].equipped.size() == 1 and c["iface"].equipped[0][1] == "Primary", "подбор в свободный слот -> Equip")
	h.queue_free()
	c["iface"].free()

# Занятый слот того же типа: подобранное докладывается, отложенное не трогаем.
func t_equip_pickup_merge() -> void:
	var h = TestHooks.new()
	root.add_child(h)
	var c := _mk_iface2()
	var lib := FakeLib2.new()
	h._lib = lib
	var matches := {"file": "Matches", "name": "Matches", "slots": ["Matches"], "stackable": true, "maxAmount": 300, "defaultAmount": 10}
	var mslot := FakeSlot.new(); mslot.name = "Matches"; mslot.hint = "Matches"
	c["equip"].add_child(mslot)
	var occ := FakeItem.new()
	var osd := FakeSD.new(); osd.itemData = matches; osd.amount = 20; occ.slotData = osd
	mslot.add_child(occ)

	var psd := FakeSD.new(); psd.itemData = matches; psd.amount = 20
	var p := _mk_pickup(c["iface"], psd)
	lib._caller = p
	h._on_pickup_interact_pre()
	# симуляция ванильного AutoStack: подобрано 20, в инвентаре уже лежало 10
	var inc := FakeItem.new()
	var isd := FakeSD.new(); isd.itemData = matches; isd.amount = 30; inc.slotData = isd
	c["ig"].add_child(inc)
	p.queue_free()
	h._on_pickup_interact_post()
	ck(int(isd.amount) == 10, "уносим только подобранное: 10 отложенных остаются")
	ck(int(c["equip"].get_child(0).get_child(0).slotData.amount) == 40, "экипированный стек вырос на 20")
	h.queue_free()
	c["iface"].free()

# Свободный слот, в инвентаре излишек: в слот уходит подобранное, остаток
# возвращается в инвентарь.
func t_equip_pickup_partial_leftover() -> void:
	var h = TestHooks.new()
	root.add_child(h)
	var c := _mk_iface2()
	var lib := FakeLib2.new()
	h._lib = lib
	var matches := {"file": "Matches", "name": "Matches", "slots": ["Matches"], "stackable": true, "maxAmount": 300}
	var mslot := FakeSlot.new(); mslot.name = "Matches"; mslot.hint = "Matches"
	c["equip"].add_child(mslot)

	var psd := FakeSD.new(); psd.itemData = matches; psd.amount = 20
	var p := _mk_pickup(c["iface"], psd)
	lib._caller = p
	h._on_pickup_interact_pre()
	var inc := FakeItem.new()
	var isd := FakeSD.new(); isd.itemData = matches; isd.amount = 30; inc.slotData = isd
	c["ig"].add_child(inc)
	p.queue_free()
	h._on_pickup_interact_post()
	ck(c["iface"].equipped.size() == 1, "подобранное ушло в слот")
	ck(int(c["equip"].get_child(0).get_child(0).slotData.amount) == 20, "в слот ушло ровно подобранное")
	var left := 0
	for ch in c["ig"].get_children():
		left += int(ch.get("slotData").get("amount"))
	ck(left == 10, "отложенные 10 вернулись в инвентарь")
	h.queue_free()
	c["iface"].free()

# Неудачный подбор (узел не удалён) и не-экипировка не двигают ничего.
func t_equip_pickup_guards() -> void:
	var h = TestHooks.new()
	root.add_child(h)
	var c := _mk_iface2()
	var lib := FakeLib2.new()
	h._lib = lib
	var rifle := {"file": "AKM", "name": "AKM", "slots": ["Primary"]}
	var primary := FakeSlot.new(); primary.name = "Primary"; primary.hint = "Primary"
	c["equip"].add_child(primary)

	var psd := FakeSD.new(); psd.itemData = rifle; psd.amount = 1
	var p := _mk_pickup(c["iface"], psd)
	lib._caller = p
	h._on_pickup_interact_pre()
	var gun := FakeItem.new()
	var gsd := FakeSD.new(); gsd.itemData = rifle; gsd.amount = 1; gun.slotData = gsd
	c["ig"].add_child(gun)
	# подбор не удался: узел не в queue_free
	h._on_pickup_interact_post()
	ck(c["iface"].equipped.is_empty(), "неудачный подбор (PlayError) ничего не экипирует")
	h.queue_free()
	c["iface"].free()

func t_equip_pickup_wrong_type_no_move() -> void:
	var h = TestHooks.new()
	root.add_child(h)
	var c := _mk_iface2()
	var lib := FakeLib2.new()
	h._lib = lib
	var beer := {"file": "Beer", "name": "Beer", "slots": []}
	var psd := FakeSD.new(); psd.itemData = beer; psd.amount = 1
	var p := _mk_pickup(c["iface"], psd)
	lib._caller = p
	h._on_pickup_interact_pre()
	p.queue_free()
	h._on_pickup_interact_post()
	ck(c["iface"].equipped.is_empty(), "не экипировка -> слот не трогаем")
	h.queue_free()
	c["iface"].free()
```

  (в) В `_run()` (строки 190–194) замени вызовы старых equip-тестов на:
```gdscript
	t_post_callback_arity()
	t_equip_pickup_free()
	t_equip_pickup_merge()
	t_equip_pickup_partial_leftover()
	t_equip_pickup_failed_no_move()
	t_equip_pickup_wrong_type_no_move()
```
  и добавь `"_on_pickup_interact_post": 0` в словарь `expected` теста
  `t_post_callback_arity` (строка 65).

  (г) В `FakeLib2` (строка 267) добавь флаг и метод (пригодятся в Task 4):
```gdscript
class FakeLib2:
	var _caller = null
	var skipped := false

	func skip_super() -> void:
		skipped = true
```

- [ ] **2.2 Прогон (красный).** `check.ps1` → `Invalid call. Nonexistent function
      '_on_pickup_interact_pre'`.

- [ ] **2.3 Реализация.** В `VTKHooks.gd`:

  (а) Рядом с `_equip_on` (строка 44) добавь:
```gdscript
var _pickup_pending: int = 0
```

  (б) В `_process` (строка 115) убери `_poll_equip()` — остаётся:
```gdscript
func _process(_delta: float) -> void:
	if not _registered:
		_try_register()
	_poll_death()
```

  (в) Упрости `set_equip_enabled` (строки 121–128) — поля дельты уходят в Task 3:
```gdscript
func set_equip_enabled(on: bool) -> void:
	_equip_on = on
```

  (г) В `_do_register` (после строки 220) добавь регистрацию:
```gdscript
	_hooks_equip.append(_lib.hook("pickup-interact-pre", _on_pickup_interact_pre))
	_hooks_equip.append(_lib.hook("pickup-interact-post", _on_pickup_interact_post))
```

  (д) Убери `_arm_equip(EQUIP_ARM_MS)` из `_on_newgame_post` (строка 239) и
      `_on_loadcharacter_post` (строка 253); из тела `_on_loadcharacter_post`
      оставь только лог:
```gdscript
func _on_loadcharacter_post() -> void:
	Log.log("[VTK] loadcharacter-post")
```

  (е) Замени `_equip_handle`/`_equip_move`/`_merge_into` (строки 473–537) на
      новые. **Дополнительно удали `_poll_equip` (строки 329–406):** он зовёт
      удаляемую `_equip_handle` и после правки `_process` (2.3б) становится
      мёртвым; если оставить — парсинг падает (`_equip_handle not found`).
      Остальные poll-хелперы (`_update_equip_qty`/`_item_type_key`/`_node_qty`/
      `_add_node_qty`/`_type_name`/`_collect_equip_qty`) пока остаются — их
      удалит Task 3:

```gdscript
# Авто-экип по событию подбора: Pickup.Interact удалил узел, значит предмет
# лёг в инвентарь. Переносим в слот ровно подобранное количество (не больше
# свободного места), отложенное в инвентаре не трогаем.
func _on_pickup_interact_pre() -> void:
	_pickup_pending = 0
	if not _equip_on or _lib == null:
		return
	var p = _lib._caller
	if p == null or not is_instance_valid(p):
		return
	var sd = p.get("slotData")
	if sd == null:
		return
	var res = sd.get("itemData")
	if res == null or not EquipFlow.is_equipment(res):
		return
	var amt := int(sd.get("amount"))
	_pickup_pending = amt if amt > 0 else 1

func _on_pickup_interact_post() -> void:
	var picked := _pickup_pending
	_pickup_pending = 0
	if not _equip_on or picked <= 0 or _lib == null:
		return
	var p = _lib._caller
	# Подбор удался только если ванильный Interact вызвал queue_free.
	if p == null or not is_instance_valid(p) or not p.is_queued_for_deletion():
		return
	var sd = p.get("slotData")
	if sd == null:
		return
	var res = sd.get("itemData")
	if res == null or not EquipFlow.is_equipment(res):
		return
	var iface = p.get("interface")
	if iface == null or not is_instance_valid(iface):
		iface = _resolve_interface()
	if iface == null or not is_instance_valid(iface):
		return
	var ig = iface.get("inventoryGrid")
	if ig == null or not is_instance_valid(ig):
		return
	_equip_picked(iface, ig, res, picked)

func _equip_picked(iface, ig, res, picked: int) -> void:
	if picked <= 0:
		return
	var equip_root = iface.get("equipment")
	if equip_root == null or not is_instance_valid(equip_root):
		return
	var node = _find_inventory_node(ig, res)
	if node == null:
		return
	var free_sl = VTKData._find_free_slot(equip_root, EquipFlow.wanted_slots(res), 0)
	if free_sl != null:
		_equip_move(iface, ig, node, free_sl, picked)
		return
	var occ_sl = VTKData._find_occupied_slot(equip_root, res, 0)
	if occ_sl == null:
		Log.log("[VTK] equip: skip '" + str(res.get("name")) + "' (no free/occupied slot)")
		return
	var occ = VTKData._slot_item(occ_sl)
	if occ == null:
		return
	var occ_sd = occ.get("slotData")
	if occ_sd == null:
		return
	if EquipFlow.decide(res, occ_sd.get("itemData")) != "merge":
		Log.log("[VTK] equip: skip '" + str(res.get("name")) + "' (no merge)")
		return
	_merge_picked(iface, ig, node, occ, occ_sd, res, picked)

# Узел инвентаря того же предмета с наибольшим количеством (после подбора игра
# могла доложить подобранное в уже лежащий стек).
func _find_inventory_node(ig, res) -> Node:
	if ig == null or not is_instance_valid(ig):
		return null
	var best: Node = null
	var best_amt := -1
	for c in ig.get_children():
		if not is_instance_valid(c):
			continue
		var sd = c.get("slotData")
		if sd == null:
			continue
		if not EquipFlow.same_item(res, sd.get("itemData")):
			continue
		var amt := int(sd.get("amount"))
		if amt > best_amt:
			best_amt = amt
			best = c
	return best

func _equip_move(iface, ig, node, sl, picked: int) -> void:
	var sd = node.get("slotData")
	if sd == null:
		return
	var res = sd.get("itemData")
	var moved := EquipFlow.equip_move(picked, 0, int(res.get("maxAmount", 0)))
	if moved <= 0:
		return
	var amt := int(sd.get("amount"))
	var have := amt if amt > 0 else 1
	if moved >= have:
		_do_equip_move(iface, ig, node, sl)
		return
	# Часть узла: в слот уезжает moved, остаток возвращаем в инвентарь на
	# освободившуюся (после переноса) клетку.
	var leftover := have - moved
	sd.set("amount", moved)
	if node.has_method("UpdateDetails"):
		node.UpdateDetails()
	_do_equip_move(iface, ig, node, sl)
	var new_sd = SlotData.new()
	new_sd.itemData = res
	new_sd.amount = leftover
	if not iface.AutoStack(new_sd, ig):
		iface.Create(new_sd, ig, true)

func _do_equip_move(iface, ig, node, sl) -> void:
	if ig != null and ig.has_method("Pick"):
		ig.Pick(node)
	if iface.has_method("Equip"):
		iface.Equip(node, sl)
	if iface.has_method("PlayEquip"):
		iface.PlayEquip()
	if iface.has_method("UpdateStats"):
		iface.UpdateStats(true)
	Log.log("[VTK] equip: moved item -> " + str(sl.name))

func _merge_picked(iface, ig, node, occ, occ_sd, res, picked: int) -> void:
	var occ_amt := int(occ_sd.get("amount"))
	var moved := EquipFlow.equip_move(picked, occ_amt, int(res.get("maxAmount", 0)))
	if moved <= 0:
		return
	occ_sd.set("amount", VTKData._whole(float(occ_amt) + float(moved)))
	var sd = node.get("slotData")
	var amt := int(sd.get("amount"))
	var have := amt if amt > 0 else 1
	var leftover := have - moved
	if leftover <= 0:
		if ig != null and ig.has_method("Pick"):
			ig.Pick(node)
		node.queue_free()
	else:
		sd.set("amount", leftover)
		if node.has_method("UpdateDetails"):
			node.UpdateDetails()
	if occ.has_method("UpdateDetails"):
		occ.UpdateDetails()
	if iface.has_method("UpdateStats"):
		iface.UpdateStats(true)
	Log.log("[VTK] equip: merged " + str(moved) + " into stack (left " + str(leftover) + ")")
```

  (ж) В `mod.txt` добавь строку в `[hooks]` (нужна для генерации обёртки
      `Pickup.Interact`):
```
res://Scripts/Pickup.gd = Interact
```

- [ ] **2.4 Прогон (зелёный).** `check.ps1` → `tests passed`; `layout_check.py` →
      `layout exit: 0`.

---

## Task 3 — Удаление polling-машинерии

**Files:**
- Modify: `loadouts/mods/VTK/VTKHooks.gd`
- Modify: `loadouts/mods/VTK/VTKData.gd`
- Modify: `loadouts/mods/VTK/VTKEquip.gd` (удаление `merge_amounts`)
- Test: `.check/project/tests/test_hooks.gd`

- [ ] **3.1 Красный тест.** Убедись, что в `test_hooks.gd` нет остатков poll:
      поиск `rg -n "_poll_equip|_arm_equip|_equip_qty|_equip_low|_equip_names|_equip_poll_at|_equip_iface_id|_own_op_msec|EQUIP_POLL|EQUIP_DIP|EQUIP_ARM|EQUIP_BULK|EQUIP_OWN|_mk_iface|_poll_seed" .check/project/tests/test_hooks.gd`
      должен быть пуст (Task 2 уже убрал потребителей). Если что-то осталось —
      удали. Затем `check.ps1` остаётся зелёным (доказывает: удалять безопасно).

- [ ] **3.2 Удаление из `VTKHooks.gd`** (`_poll_equip` уже удалён в Task 2.3е):
  - `_update_equip_qty` (411–428);
  - `_item_type_key` (433–440);
  - `_node_qty` (444–449);
  - `_add_node_qty` (451–460);
  - `_type_name` (462–463);
  - `_collect_equip_qty` (465–471);
  - `_arm_equip` (256–257);
  - поля `_equip_armed_at`, `_equip_poll_at`, `_equip_iface_id`, `_equip_qty`,
    `_equip_low`, `_equip_names` (строки 46–54);
  - константы `EQUIP_ARM_MS`, `EQUIP_POLL_MS`, `EQUIP_DIP_MS`, `EQUIP_BULK_LIMIT`,
    `EQUIP_OWN_WINDOW_MS` (строки 29–43; проверь, что `EQUIP_*` больше нигде не
    встречается: `rg -n "EQUIP_" loadouts/mods/VTK/VTKHooks.gd`).

- [ ] **3.2a `merge_amounts` в `VTKEquip.gd`.** Удали `merge_amounts`. К этому
      моменту Task 2.3е переписал `VTKHooks._merge_into`, так что потребителя
      больше нет (`rg -n "merge_amounts" loadouts/mods/VTK/` — пусто).

- [ ] **3.3 Мёртвый код в `VTKData.gd`.** Удали `_own_op_recent` (строки 17–18) —
      единственный потребитель был `_poll_equip`. `_touch_own_op`/`_own_op_msec`
      ОСТАВЬ (их зовёт `_insert`).

- [ ] **3.4 Прогон (зелёный).** `check.ps1` → `tests passed`; `layout_check.py` →
      `layout exit: 0`. Финальная проверка отсутствия символов:
      `rg -n "poll_equip|_arm_equip|_equip_qty|_equip_low|_equip_names|EQUIP_POLL|EQUIP_DIP|EQUIP_ARM|EQUIP_BULK|EQUIP_OWN" loadouts/mods/VTK/` — пусто.

---

## Task 4 — Take/Split из слота экипировки

**Files:**
- Modify: `loadouts/mods/VTK/VTKHooks.gd`
- Modify: `loadouts/mod.txt`
- Test: `.check/project/tests/test_hooks.gd`

Интерфейс (использует Task 1):

```gdscript
func _on_context_take_replace() -> void
func _on_context_split_replace() -> void
func _context_slot_share(is_take: bool) -> void
```

- [ ] **4.1 Красный тест.** В `test_hooks.gd` добавь тесты (после новых
      тестов подбора):

```gdscript
# Take/Split из слота экипировки: ванильные ContextTake/ContextSplit в слоте
# молча выходят (contextGrid == null). Возвращаем долю стака в инвентарь.
func t_context_split_slot() -> void:
	var h = TestHooks.new()
	root.add_child(h)
	var c := _mk_iface2()
	var lib := FakeLib2.new()
	h._lib = lib
	lib._caller = c["iface"]
	var matches := {"file": "Matches", "name": "Matches", "slots": ["Matches"], "stackable": true, "maxAmount": 300, "defaultAmount": 10}
	var slot := FakeSlot.new(); slot.name = "Matches"; slot.hint = "Matches"
	c["equip"].add_child(slot)
	var item := FakeItem.new()
	var isd := FakeSD.new(); isd.itemData = matches; isd.amount = 40; item.slotData = isd
	slot.add_child(item)
	c["iface"].set("contextItem", item)
	c["iface"].set("contextSlot", slot)
	c["iface"].set("contextGrid", null)
	h._on_context_split_replace()
	ck(int(isd.amount) == 20, "Split делит стек в слоте пополам")
	ck(c["iface"].created.size() == 1 and int(c["iface"].created[0].get("amount")) == 20, "доля ушла в инвентарь")
	ck(lib.skipped, "Split пропускает ванильное тело (skip_super)")
	h.queue_free()
	c["iface"].free()

func t_context_take_slot() -> void:
	var h = TestHooks.new()
	root.add_child(h)
	var c := _mk_iface2()
	var lib := FakeLib2.new()
	h._lib = lib
	lib._caller = c["iface"]
	var matches := {"file": "Matches", "name": "Matches", "slots": ["Matches"], "stackable": true, "maxAmount": 300, "defaultAmount": 10}
	var slot := FakeSlot.new(); slot.name = "Matches"; slot.hint = "Matches"
	c["equip"].add_child(slot)
	var item := FakeItem.new()
	var isd := FakeSD.new(); isd.itemData = matches; isd.amount = 40; item.slotData = isd
	slot.add_child(item)
	c["iface"].set("contextItem", item)
	c["iface"].set("contextSlot", slot)
	c["iface"].set("contextGrid", null)
	h._on_context_take_replace()
	ck(int(isd.amount) == 30, "Take снимает defaultAmount из слота")
	ck(c["iface"].created.size() == 1 and int(c["iface"].created[0].get("amount")) == 10, "доля ушла в инвентарь")
	ck(lib.skipped, "Take пропускает ванильное тело")
	h.queue_free()
	c["iface"].free()

# Предмет в гриде (contextGrid != null): мод не вмешивается, тело ванили идёт.
func t_context_grid_defers_to_vanilla() -> void:
	var h = TestHooks.new()
	root.add_child(h)
	var c := _mk_iface2()
	var lib := FakeLib2.new()
	h._lib = lib
	lib._caller = c["iface"]
	var matches := {"file": "Matches", "name": "Matches", "slots": ["Matches"], "stackable": true, "maxAmount": 300, "defaultAmount": 10}
	var item := FakeItem.new()
	var isd := FakeSD.new(); isd.itemData = matches; isd.amount = 40; item.slotData = isd
	c["ig"].add_child(item)
	c["iface"].set("contextItem", item)
	c["iface"].set("contextGrid", c["ig"])
	c["iface"].set("contextSlot", null)
	h._on_context_split_replace()
	ck(int(isd.amount) == 40, "предмет в гриде -> ванильное поведение (не трогаем)")
	ck(not lib.skipped, "супер не пропускается для грида")
	ck(c["iface"].created.is_empty(), "в гриде доля создаётся ванильным кодом, не нами")
	h.queue_free()
	c["iface"].free()
```

  В `_run()` добавь вызовы:
```gdscript
	t_context_split_slot()
	t_context_take_slot()
```

- [ ] **4.2 Прогон (красный).** `Invalid call. Nonexistent function
      '_on_context_split_replace'`.

- [ ] **4.3 Реализация.** В `VTKHooks.gd` добавь (рядом с обработчиками
      контекстного меню, недалеко от `_on_context_update_post`):

```gdscript
# --- Take/Split из слота экипировки ----------------------------------------
# Ванильные ContextTake/ContextSplit требуют contextGrid != null и в слоте
# молча выходят: кнопки в меню есть, эффекта нет. Если предмет лежит в слоте,
# сами возвращаем долю стака в инвентарь (AutoStack/Create) и пропускаем
# ванильное тело; для предметов в гриде не вмешиваемся (contextGrid != null).
func _on_context_take_replace() -> void:
	_context_slot_share(true)

func _on_context_split_replace() -> void:
	_context_slot_share(false)

func _context_slot_share(is_take: bool) -> void:
	var iface = _lib._caller if _lib else null
	if iface == null or not is_instance_valid(iface):
		return
	if iface.get("contextGrid") != null:
		return
	var item = iface.get("contextItem")
	var slot = iface.get("contextSlot")
	if item == null or slot == null or not is_instance_valid(item):
		return
	var sd = item.get("slotData")
	if sd == null:
		return
	var res = sd.get("itemData")
	if res == null:
		return
	var amount := int(sd.get("amount"))
	var share := EquipFlow.take_share(int(res.get("defaultAmount"))) if is_take else EquipFlow.split_share(amount)
	if share <= 0 or share > amount:
		return
	sd.set("amount", amount - share)
	if item.has_method("UpdateDetails"):
		item.UpdateDetails()
	var new_sd = SlotData.new()
	new_sd.itemData = res
	new_sd.amount = share
	var ig = iface.get("inventoryGrid")
	if ig != null and is_instance_valid(ig):
		if not iface.AutoStack(new_sd, ig):
			iface.Create(new_sd, ig, true)
	if iface.has_method("HideContext"):
		iface.HideContext()
	if iface.has_method("Reset"):
		iface.Reset()
	if iface.has_method("PlayStack"):
		iface.PlayStack()
	if _lib != null:
		_lib.skip_super()
```

  В `_do_register` добавь (после регистрации контекст-поста, строка 220):
```gdscript
	_hooks_context.append(_lib.hook("interface-contexttake", _on_context_take_replace))
	_hooks_context.append(_lib.hook("interface-contextsplit", _on_context_split_replace))
```

  В `mod.txt` допиши в `[hooks]`:
```
res://Scripts/Interface.gd = ContextTake, ContextSplit
```

- [ ] **4.2 Прогон (зелёный).** `check.ps1` → `tests passed`; `layout_check.py` →
      `layout exit: 0`.

---

## Task 5 — Версия и заметка в `AGENTS.md`

**Files:**
- Modify: `loadouts/mod.txt`, `loadouts/mods/VTK/version.txt`, `README.md`
- Modify: `AGENTS.md`

- [ ] **5.1** `loadouts/mod.txt`: `version="4.15.10"` → `version="4.16.0"`.
- [ ] **5.2** `loadouts/mods/VTK/version.txt`: `4.15.10` → `4.16.0`.
- [ ] **5.3** `README.md` строка 7: `**Version:** 4.15.10` → `**Version:** 4.16.0`.
- [ ] **5.4** В `AGENTS.md`, в раздел «Проверка» (или рядом), добавь пункт:

```
- Авто-экип висит на ванильном событии подбора `Pickup.Interact()` (хуки
  `pickup-interact-pre/-post`), а не на отличии количества в инвентаре: игра
  при перекладывании временно пересобирает узлы, дельта это ловила. Оба hook
  void -> колбэки без `_result` (см. `t_post_callback_arity`). Take/Split в
  слоте экипировки — replace-хуки `interface-contexttake`/`interface-contextsplit`
  (`skip_super` только когда `contextGrid == null`); декларация обёрток в
  `mod.txt` `[hooks]`.
```

- [ ] **5.5 Прогон.** `check.ps1` → `tests passed`; `layout_check.py` →
      `layout exit: 0`.

---

## Task 6 — Сборка и игровая проверка

- [ ] **6.1** Убедись, что оба стенда зелёные (Task 1–5).
- [ ] **6.2** `powershell -ExecutionPolicy Bypass -File pack.ps1` — печатает
      `4.16.0`; скопируй `D:\RTVMOD\Loadouts.vmz` в
      `D:\SteamLibrary\steamapps\common\Road to Vostok\mods\Loadouts.vmz`.
- [ ] **6.3** Игровой чек-лист (владелец):
  1. Пустой слот экипировки → подобрать экипировку → предмет в слоте.
  2. Слот занят тем же стаком → подобрать тот же предмет → подобранное
     докладывается, отложенное в инвентаре остаётся.
  3. Инвентарь, слот пуст, в инвентаре уже лежит такой же стек с излишком →
     подобрать → в слот уходит подобранное, остаток остаётся в инвентаре.
  4. Контекстное меню на предмете в слоте → `Split` и `Take` переносят долю
     стака в инвентарь.
  5. Перекладывание предметов внутри инвентаря больше НЕ утаскивает их в слот.
- [ ] **6.4** При провале — фиксировать симптомы в этой сессии, не коммитить
      до исправления.

---

## Самопроверка плана (выполнена автором)

- **Покрытие спеки:** раздел 1 (подбор) → Task 2; раздел 2 (правило
  «только подобранное») → Task 2; раздел 3 (Take/Split) → Task 4; декларации
  хуков → Task 2.3ж и 4.2; удаление дельты → Task 3; чистые помощники и тесты →
  Task 1; версии → Task 5; игровая проверка → Task 6.
- **Плейсхолдеры:** нет TBD/«добавить обработку». Везде конкретный код.
- **Согласованность типов:** `EquipFlow.equip_move/split_share/take_share`
  определены в Task 1 и используются в Task 2/4 с той же сигнатурой;
  `_find_inventory_node -> Node`, `_equip_picked(iface, ig, res, picked)`,
  `_equip_move(iface, ig, node, sl, picked)` совпадают во всех упоминаниях.
- `merge_amounts` удалён в Task 3 и до того нигде не вызывается (единственный
  потребитель — старый `_merge_into`, переписанный в Task 2.3е).
