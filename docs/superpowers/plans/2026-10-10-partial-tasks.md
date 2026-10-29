# PartialTasks (частичная сдача заданий торговцу) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Дать игроку вносить требуемые задачи торговцу предметы частями (кнопка Deposit + инлайн-прогресс), завершать задачу при покрытии вкладов и сохранять вклады между сессиями.

**Architecture:** Чистая арифметика леджера вынесена в новый `VTKDeposits.gd` (headless-тестируемо). Леджер хранится в метаданных ресурса `TraderSave` (`user://Traders.tres`, мета-ключ `vtk_deposits`). Связка с деревом — в `VTKHooks.gd` через хуки Metro Mod Loader: render при открытии вкладки и при входе в режим Input, один replace-хук (`task-_on_complete_pressed`). Спека: `docs/superpowers/specs/2026-10-10-partial-tasks-design.md`.

**Tech Stack:** GDScript (Godot 4.6.3), Metro Mod Loader 3.4.2 (хуки `_lib.hook`, replace + `skip_super()`), Python-стенды `.check/`.

## Global Constraints

- Отступы в `.gd` — только табы. Файлы в UTF-8 без BOM. Строка с кавычкой пишется в одинарных кавычках.
- Локализуется только обвязка мода; имена предметов берутся из `Database` и не переводятся. Ключ словаря `RU` — сама английская строка.
- Версия живёт в одном месте — `loadouts/mod.txt`. В GDScript версию не дублировать.
- Версия сейчас `4.11.2`; этот фичер → `4.12.0` (minor).
- Прогон стендов:
  - `& "C:\Users\home\AppData\Local\Programs\Python\Python312\python.exe" .check\layout_check.py`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1 -Godot "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe"`
  - `& "C:\Users\home\AppData\Local\Programs\Python\Python312\python.exe" .check\keycheck.py`
- Имена хуков задавать **строковыми литералами** — wrap-surface фиксируется сканом литеральных `.hook("...")`.
- **Коммит только по явной команде пользователя.** Шаги «Commit» в плане выполнять лишь после подтверждения; иначе — оставить изменения в рабочем дереве.
- Новые ключи локализации добавлять в один проход с кодом, который их использует (иначе `keycheck.py` пометит как stale).

---

### Task 1: Чистый модуль `VTKDeposits.gd` + headless-тест

**Files:**
- Create: `loadouts/mods/VTK/VTKDeposits.gd`
- Create: `.check/project/tests/test_deposits.gd`
- Modify: `.check/check.ps1:80` (список `$tests`)

**Interfaces:**
- Produces:
  - `VTKDeposits.task_key(path: String, name: String, trader: String) -> String`
  - `VTKDeposits.normalize_slots(entries: Array) -> Array` — элементы `{ "index": int, "file": String, "name": String, "required": int }`, `index` = позиция во входе.
  - `VTKDeposits.coverage(ledger: Dictionary, key: String, slots: Array) -> Dictionary` — `{ "slots": [ { "index", "file", "name", "required", "deposited", "remaining", "satisfied" } ], "all_satisfied": bool }` (`slots` — нормализованные).
  - `VTKDeposits.apply(ledger, key, slots, offered) -> Dictionary` — `{ "ledger": Dictionary, "take": [ { "ref", "amount" } ] }`; `offered` — `[ { "file", "amount", "ref" } ]`.
  - `VTKDeposits.clear_task(ledger: Dictionary, key: String) -> Dictionary`
  - `VTKDeposits.badge_text(deposited: int, required: int) -> String`
  - `VTKDeposits.is_covered(coverage: Dictionary) -> bool`

- [ ] **Step 1: Написать падающий тест**

Создать `.check/project/tests/test_deposits.gd`:

```gdscript
extends SceneTree

const D = preload("res://mods/VTK/VTKDeposits.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _init() -> void:
	t_task_key()
	t_normalize_slots()
	t_coverage()
	t_apply()
	t_clear_task()
	t_badge_text()
	print("")
	if fails == 0:
		print("Deposits tests passed")
		quit(0)
	else:
		print("Deposits tests failed: ", fails)
		quit(1)

func _slots() -> Array:
	return D.normalize_slots([
		{"file": "Beer", "name": "Beer", "amount": 3},
		{"file": "Can", "name": "Can", "amount": 1},
	])

func t_task_key() -> void:
	ck(D.task_key("res://X.tres", "A", "Doctor") == "res://X.tres", "task_key: непустой path")
	ck(D.task_key("", "A", "Doctor") == "A::Doctor", "task_key: фоллбэк name::trader")

func t_normalize_slots() -> void:
	var got := D.normalize_slots([
		{"file": "Beer", "name": "Beer", "amount": 3},
		{"name": "OnlyName", "amount": 0},
	])
	ck(got.size() == 2, "normalize_slots: два слота")
	ck(got[0]["index"] == 0 and got[0]["file"] == "Beer" and got[0]["required"] == 3, "нормализация первого")
	ck(got[1]["index"] == 1 and got[1]["file"] == "OnlyName", "file: фоллбэк на name")
	ck(got[1]["required"] == 1, "amount<1 -> 1")
	ck(D.normalize_slots(null).is_empty(), "normalize_slots: null -> пусто")

func t_coverage() -> void:
	var slots := _slots()
	var empty := D.coverage({}, "K", slots)
	ck(empty["all_satisfied"] == false, "coverage: пусто -> не покрыто")
	ck(empty["slots"][0]["deposited"] == 0 and empty["slots"][0]["remaining"] == 3, "coverage: остаток = нужно")
	var part := D.coverage({"K": {0: 1}}, "K", slots)
	ck(part["all_satisfied"] == false and part["slots"][0]["remaining"] == 2, "coverage: частично")
	var full := D.coverage({"K": {0: 5, 1: 1}}, "K", slots)
	ck(full["all_satisfied"] == true, "coverage: покрыто")
	ck(full["slots"][0]["deposited"] == 3, "coverage: вклад обрезан до нужно")

func t_apply() -> void:
	var slots := _slots()
	var r := D.apply({}, "K", slots, [
		{"file": "Beer", "amount": 5, "ref": "n1"},
		{"file": "Can", "amount": 1, "ref": "n2"},
	])
	ck(r["ledger"]["K"][0] == 3 and r["ledger"]["K"][1] == 1, "apply: леджер заполнен")
	var take: Array = r["take"]
	ck(take.size() == 2, "apply: две стопки списаны")
	ck(take[0]["ref"] == "n1" and take[0]["amount"] == 3, "apply: из Beer взято не больше остатка")
	ck(take[1]["ref"] == "n2" and take[1]["amount"] == 1, "apply: Can целиком")

	# Повторный депозит по уже покрытому слоту не берёт ничего.
	var again := D.apply(r["ledger"], "K", slots, [{"file": "Beer", "amount": 2, "ref": "n3"}])
	ck(again["take"].is_empty(), "apply: покрытый слот не берёт")

	# Чужой file игнорируется.
	var wrong := D.apply({}, "K", slots, [{"file": "Rags", "amount": 4, "ref": "n4"}])
	ck(wrong["take"].is_empty() and wrong["ledger"].get("K", {}).is_empty(), "apply: чужой file -> ничего")

	# Исходный леджер не мутируется.
	var base := {"K": {0: 1}}
	var copy := D.apply(base, "K", slots, [{"file": "Beer", "amount": 1, "ref": "n5"}])
	ck(base["K"][0] == 1, "apply: исходный леджер не изменён")
	ck(copy["ledger"]["K"][0] == 2, "apply: копия изменена")

func t_clear_task() -> void:
	var base := {"K": {0: 1}, "Z": {0: 2}}
	var out := D.clear_task(base, "K")
	ck(not out.has("K") and out.has("Z"), "clear_task: удаляет только K")
	ck(base.has("K"), "clear_task: исходный не тронут")

func t_badge_text() -> void:
	ck(D.badge_text(2, 5) == "2 / 5", "badge_text: 2 / 5")
	ck(D.badge_text(0, 3) == "0 / 3", "badge_text: 0 / 3")
	ck(D.is_covered({"all_satisfied": true}), "is_covered: true")
	ck(not D.is_covered({"all_satisfied": false}), "is_covered: false")
```

- [ ] **Step 2: Запустить тест, убедиться что падает**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1 -Godot "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe"`
Expected: FAIL — `mods/VTK/VTKDeposits.gd` отсутствует, `test_deposits.gd` не в списке; скрипт не грузится.

- [ ] **Step 3: Добавить тест в список стенда**

В `.check/check.ps1:80` добавить в конец массива `$tests` элемент `"res://tests/test_deposits.gd"`:

```powershell
$tests = @("res://tests/test_draft.gd", "res://tests/test_picker.gd", "res://tests/test_hooks.gd", "res://tests/test_feed.gd", "res://tests/test_spawn.gd", "res://tests/test_notes.gd", "res://tests/test_deposits.gd")
```

- [ ] **Step 4: Написать реализацию**

Создать `loadouts/mods/VTK/VTKDeposits.gd`:

```gdscript
extends RefCounted
## Чистая логика частичной сдачи заданий торговцу (PartialTasks).
## Ни load(), ни путей внутрь игры: на вход обычные словари/массивы,
## поэтому модуль покрыт headless-тестом test_deposits.gd.

static func task_key(path: String, name: String, trader: String) -> String:
	var p := str(path).strip_edges()
	if p != "":
		return p
	return str(name) + "::" + str(trader)

static func normalize_slots(entries) -> Array:
	var out: Array = []
	if typeof(entries) != TYPE_ARRAY:
		return out
	for i in range(entries.size()):
		var e = entries[i]
		var file := ""
		var nm := ""
		var amount := 1
		if e != null and typeof(e) == TYPE_DICTIONARY:
			file = str(e.get("file", ""))
			if file == "":
				file = str(e.get("name", ""))
			nm = str(e.get("name", ""))
			amount = int(e.get("amount", 1))
		if amount < 1:
			amount = 1
		out.append({"index": i, "file": file, "name": nm, "required": amount})
	return out

static func coverage(ledger: Dictionary, key: String, slots: Array) -> Dictionary:
	var task: Dictionary = {}
	if typeof(ledger) == TYPE_DICTIONARY and typeof(ledger.get(key)) == TYPE_DICTIONARY:
		task = ledger[key]
	var per: Array = []
	var all := true
	for s in slots:
		var idx := int(s["index"])
		var req := int(s["required"])
		var dep := int(task.get(idx, 0))
		if dep > req:
			dep = req
		var satisfied := dep >= req
		if not satisfied:
			all = false
		per.append({
			"index": idx,
			"file": str(s["file"]),
			"name": str(s["name"]),
			"required": req,
			"deposited": dep,
			"remaining": req - dep,
			"satisfied": satisfied,
		})
	return {"slots": per, "all_satisfied": all}

static func apply(ledger: Dictionary, key: String, slots: Array, offered: Array) -> Dictionary:
	var out := _copy_ledger(ledger)
	var task: Dictionary = _dup_task(out.get(key, {}))
	var remaining := {}
	for s in slots:
		var idx := int(s["index"])
		remaining[idx] = max(0, int(s["required"]) - int(task.get(idx, 0)))
	var take: Array = []
	if typeof(offered) == TYPE_ARRAY:
		for o in offered:
			if o == null or typeof(o) != TYPE_DICTIONARY:
				continue
			var file := str(o.get("file"))
			var amt := int(o.get("amount", 0))
			if file == "" or amt <= 0:
				continue
			var used := 0
			for s in slots:
				if used >= amt:
					break
				if str(s["file"]) != file:
					continue
				var idx := int(s["index"])
				var rem := int(remaining.get(idx, 0))
				if rem <= 0:
					continue
				var give: int = min(rem, amt - used)
				remaining[idx] = rem - give
				task[idx] = int(task.get(idx, 0)) + give
				used += give
			if used > 0:
				take.append({"ref": o.get("ref"), "amount": used})
	if task.is_empty():
		out.erase(key)
	else:
		out[key] = task
	return {"ledger": out, "take": take}

static func clear_task(ledger: Dictionary, key: String) -> Dictionary:
	var out := _copy_ledger(ledger)
	out.erase(key)
	return out

static func badge_text(deposited: int, required: int) -> String:
	return str(deposited) + " / " + str(required)

static func is_covered(coverage: Dictionary) -> bool:
	return bool(coverage.get("all_satisfied", false))

static func _copy_ledger(ledger) -> Dictionary:
	var out := {}
	if typeof(ledger) != TYPE_DICTIONARY:
		return out
	for k in ledger:
		out[k] = _dup_task(ledger[k])
	return out

static func _dup_task(task) -> Dictionary:
	var out := {}
	if typeof(task) != TYPE_DICTIONARY:
		return out
	for k in task:
		out[k] = int(task[k])
	return out
```

- [ ] **Step 5: Запустить тест, убедиться что проходит**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1 -Godot "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe"`
Expected: `Parse check passed: 13 scripts`, `Deposits tests passed`, `Tests passed: 7 file(s)`, exit 0.

Также: `& "C:\Users\home\AppData\Local\Programs\Python\Python312\python.exe" .check\layout_check.py` → OK (новых GONE/PRESENT не вводим).

- [ ] **Step 6: Commit**

```bash
git add loadouts/mods/VTK/VTKDeposits.gd .check/project/tests/test_deposits.gd .check/check.ps1
git commit -m "feat(deposits): pure ledger logic module + headless tests"
```

---

### Task 2: VTKHooks — регистрация хуков, леджер, отрисовка прогресса и кнопки Deposit

**Files:**
- Modify: `loadouts/mods/VTK/VTKHooks.gd` (consts, поля, `_do_register`, новые функции)
- Modify: `loadouts/mods/VTK/VTKLoc.gd` (ключи `Deposit`, тултип)

**Interfaces:**
- Consumes: `VTKDeposits`, `Loc` (Task 1; `Loc` существует).
- Produces (внутренние, используются Task 3/4):
  - `_render_task_card(iface, card) -> void`
  - `_slots_from_grid(grid) -> Array`
  - `_card_covered(card) -> bool`
  - `_traders()`, `_ledger() -> Dictionary`, `_ledger_set(data: Dictionary) -> void`
  - `_key_of(task_data) -> String`, `_find_deposit_button(card) -> Button`, `_make_deposit_button(card) -> Button`
  - константа мета-ключа `vtk_deposits`.

- [ ] **Step 1: Смонтировать модули и поля**

В `loadouts/mods/VTK/VTKHooks.gd` рядом с существующими `const` (после строки 11 `const Notes = ...`) добавить:

```gdscript
const VTKDeposits = preload("res://mods/VTK/VTKDeposits.gd")
const Loc = preload("res://mods/VTK/VTKLoc.gd")
```

Рядом с `var _hooks_notes: Array = []` (строка 8) добавить:

```gdscript
var _hooks_deposits: Array = []
```

- [ ] **Step 2: Зарегистрировать хуки**

В `_do_register()` после строки `_hooks_notes.append(_lib.hook("interface-initializenotes-post", _on_notes_rendered))` (строка 153) добавить:

```gdscript
	_hooks_deposits.append(_lib.hook("interface-initializetasks-post", _on_tasks_rendered))
	_hooks_deposits.append(_lib.hook("interface-startinput-post", _on_tasks_startinput))
	_hooks_deposits.append(_lib.hook("task-_on_complete_pressed", _on_task_complete_pressed))
```

> **КОРРЕКЦИЯ (Task 4, Step 0):** хук `task-cancomplete` **исключён** — см. спеку и Task 4 Step 0.
> Дамп загрузчика показал, что у void-метода `Task.CanComplete()` возврат замены отбрасывается, а
> `skip_super()` отменил бы выставление `completeButton.disabled`. Коммит Task 2 завёл четвёртый хук —
> Task 4 его удалит.

Итоговую строку счётчика (строка 156) заменить на:

```gdscript
	print("[VTK] Per-frame hooks registered (" + str(_hooks_kc.size() + _hooks_notes.size() + _hooks_deposits.size() + 1) + " hooks)")
```

- [ ] **Step 3: Добавить леджер-IO, слоты и отрисовку**

Добавить в `VTKHooks.gd` (например, после `_on_notes_rendered`, ~строка 475) новые функции. **Replace-колбэки `_on_task_cancomplete` / `_on_task_complete_pressed` заводим здесь как рабочие, но `task-_on_complete_pressed` пока не действует — тело завершения появится в Task 4; на этом шаге оставить его «хождением в ваниль» (см. ниже).**

```gdscript
const TRADERS_RES := "user://Traders.tres"
const DEPOSITS_META := "vtk_deposits"

func _traders() -> Variant:
	if not FileAccess.file_exists("user://Traders.tres"):
		return null
	return load("user://Traders.tres")

func _ledger() -> Dictionary:
	var traders = _traders()
	if traders == null:
		return {}
	var m = traders.get_meta("vtk_deposits", {})
	return m if typeof(m) == TYPE_DICTIONARY else {}

func _ledger_set(data: Dictionary) -> void:
	var traders = _traders()
	if traders == null:
		return
	traders.set_meta("vtk_deposits", data)
	ResourceSaver.save(traders, "user://Traders.tres")

func _clear_ledger_key(task_data) -> void:
	if task_data == null:
		return
	var key := _key_of(task_data)
	var ledger := _ledger()
	if not ledger.has(key):
		return
	_ledger_set(VTKDeposits.clear_task(ledger, key))

func _slots_from_grid(grid) -> Array:
	var entries: Array = []
	for cell in grid.get_children():
		var file := ""
		var nm := ""
		var amount := 1
		if cell != null and is_instance_valid(cell):
			var sd = cell.get("slotData")
			if sd != null:
				var item = sd.get("itemData")
				if item != null:
					file = str(item.get("file"))
					nm = str(item.get("name"))
				amount = int(sd.get("amount", 1))
		entries.append({"file": file, "name": nm, "amount": amount})
	return VTKDeposits.normalize_slots(entries)

func _key_of(task_data) -> String:
	return VTKDeposits.task_key(str(task_data.get("resource_path")), str(task_data.get("name")), str(task_data.get("trader")))

func _card_covered(card) -> bool:
	if card == null or not is_instance_valid(card):
		return false
	var task_data = card.get("taskData")
	var grid = card.get("inputGrid")
	if task_data == null or grid == null or not (grid is Node):
		return false
	var slots := _slots_from_grid(grid)
	if slots.is_empty():
		return false
	var key := _key_of(task_data)
	return VTKDeposits.is_covered(VTKDeposits.coverage(_ledger(), key, slots))

func _on_tasks_rendered() -> void:
	var iface = _lib._caller if _lib else null
	if iface == null or not is_instance_valid(iface):
		return
	_render_all_tasks(iface)

func _on_tasks_startinput() -> void:
	var iface = _lib._caller if _lib else null
	if iface == null or not is_instance_valid(iface):
		return
	_render_all_tasks(iface)

func _render_all_tasks(iface) -> void:
	var list = iface.get("taskList")
	if list == null or not (list is Node):
		return
	for card in list.get_children():
		_render_task_card(iface, card)

func _card_completed(card) -> bool:
	if card == null or not is_instance_valid(card):
		return false
	var task_data = card.get("taskData")
	if task_data == null:
		return false
	return Notes.is_completed(task_data, Notes.completed_lists(_traders()))

func _render_task_card(iface, card) -> void:
	if card == null or not is_instance_valid(card):
		return
	var grid = card.get("inputGrid")
	var task_data = card.get("taskData")
	if grid == null or not (grid is Node) or task_data == null:
		return
	var btn := _find_deposit_button(card)
	if _card_completed(card):
		_clear_badges(grid)
		if btn != null:
			btn.queue_free()
		return
	var slots := _slots_from_grid(grid)
	if slots.is_empty():
		return
	var key := _key_of(task_data)
	var cov := VTKDeposits.coverage(_ledger(), key, slots)
	for s in cov["slots"]:
		_paint_slot(grid, s)
	if btn == null:
		btn = _make_deposit_button(card)
	if btn != null:
		# Deposit доступен только для карточки, выбранной в режиме Input,
		# и пока задача не покрыта (иначе сдавать через Complete).
		btn.disabled = iface.get("inputTarget") != card or VTKDeposits.is_covered(cov)

func _find_deposit_button(card) -> Button:
	var buttons = card.get_node_or_null("Margin/Elements/Buttons")
	if buttons == null or not (buttons is Node):
		return null
	var b = buttons.get_node_or_null("VTKDepositButton")
	return b if (b != null and b is Button) else null

func _make_deposit_button(card) -> Button:
	var buttons = card.get_node_or_null("Margin/Elements/Buttons")
	if buttons == null or not (buttons is Node):
		return null
	var btn := Button.new()
	btn.name = "VTKDepositButton"
	btn.text = Loc.txt("Deposit")
	btn.tooltip_text = Loc.txt("Deposit selected items toward this task")
	buttons.add_child(btn)
	return btn

func _paint_slot(grid, s) -> void:
	var idx := int(s["index"])
	if idx < 0 or idx >= grid.get_child_count():
		return
	var cell = grid.get_child(idx)
	if cell == null or not is_instance_valid(cell):
		return
	var amount_lbl = cell.get_node_or_null("Details/Amount")
	if amount_lbl != null and amount_lbl is Node:
		amount_lbl.visible = false
	var badge = cell.get_node_or_null("VTKDepositBadge")
	if badge == null or not (badge is Label):
		badge = Label.new()
		badge.name = "VTKDepositBadge"
		badge.anchor_left = 0.0
		badge.anchor_top = 0.5
		badge.anchor_right = 1.0
		badge.anchor_bottom = 1.0
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		badge.add_theme_font_size_override("font_size", 11)
		cell.add_child(badge)
	if bool(s["satisfied"]):
		badge.text = "✓"
		if cell.has_method("State"):
			cell.call("State", "Selected")
	else:
		badge.text = VTKDeposits.badge_text(int(s["deposited"]), int(s["required"]))

func _clear_badges(grid) -> void:
	for cell in grid.get_children():
		if cell == null or not is_instance_valid(cell):
			continue
		var badge = cell.get_node_or_null("VTKDepositBadge")
		if badge != null:
			badge.queue_free()
```

- [ ] **Step 4: Добавить ключи локализации**

В `loadouts/mods/VTK/VTKLoc.gd`, в словарь `RU` (перед закрывающей `}` на строке 184), добавить два ключа в алфавитном порядке по английскому ключу (D — после `'Create new loadout'`):

```gdscript
	'Deposit': 'Внести',
	'Deposit selected items toward this task': 'Внести выбранные предметы в счёт задачи',
```

- [ ] **Step 5: Заглушка колбэка завершения (для компиляции)**

Пока Task 4 не добавлен, добавить в `VTKHooks.gd` временные колбэки-обёртки, чтобы регистрация ссылалась на существующие функции (тело заменяется в Task 4):

```gdscript
func _on_task_cancomplete() -> bool:
	return false

func _on_task_complete_pressed() -> void:
	pass
```

- [ ] **Step 6: Прогнать стенды**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1 -Godot "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe"`
Expected: `Parse check passed: 13 scripts`, `Tests passed: 7 file(s)`, exit 0.

Run: `& "C:\Users\home\AppData\Local\Programs\Python\Python312\python.exe" .check\keycheck.py`
Expected: нет ошибок (ключи `Deposit`/тултип используются и есть в RU).

- [ ] **Step 7: Ручная проверка (игра)**

Открыть вкладку Tasks у торговца. Ожидается: у задач с предметами на ячейках требований — бейдж `нужно / нужно` (вклады 0), кнопка **Deposit** в ряду кнопок. Вне режима Input кнопка неактивна; нажатия ничего не делают.

- [ ] **Step 8: Commit**

```bash
git add loadouts/mods/VTK/VTKHooks.gd loadouts/mods/VTK/VTKLoc.gd
git commit -m "feat(deposits): task card progress badges and Deposit button"
```

---

### Task 3: Депозит и гейт `task-cancomplete`

**Files:**
- Modify: `loadouts/mods/VTK/VTKHooks.gd` (заполнить `_on_task_cancomplete`, добавить `_selected_stacks`, `_consume`, `_on_deposit_pressed`; подключить кнопку)

**Interfaces:**
- Consumes: `_render_task_card`, `_slots_from_grid`, `_ledger`, `_ledger_set`, `_find_deposit_button`, `VTKDeposits.*` (Task 1/2).
- Produces: рабочий Deposit (списание + запись леджера) и `task-cancomplete` replace.

- [ ] **Step 1: Реализовать сбор выделенного и списание стопок**

Добавить в `VTKHooks.gd`:

```gdscript
func _selected_stacks(iface) -> Array:
	var out: Array = []
	var grid = iface.get("inventoryGrid")
	if grid == null or not (grid is Node):
		return out
	for cell in grid.get_children():
		if cell == null or not is_instance_valid(cell):
			continue
		if not bool(cell.get("selected")):
			continue
		var sd = cell.get("slotData")
		if sd == null:
			continue
		var item = sd.get("itemData")
		if item == null:
			continue
		out.append({
			"file": str(item.get("file")),
			"name": str(item.get("name")),
			"amount": int(sd.get("amount", 0)),
			"ref": cell,
		})
	return out

func _consume(take: Array) -> void:
	for t in take:
		if t == null or typeof(t) != TYPE_DICTIONARY:
			continue
		var node = t.get("ref")
		var amt := int(t.get("amount", 0))
		if node == null or not is_instance_valid(node) or amt <= 0:
			continue
		var sd = node.get("slotData")
		if sd == null:
			continue
		var left := int(sd.get("amount", 0)) - amt
		if left <= 0:
			var grid = node.get_parent()
			if grid != null and grid.has_method("Pick"):
				grid.Pick(node)
			node.queue_free()
		else:
			sd.set("amount", left)
			node.call("UpdateDetails")
			node.call("State", "Static")
```

- [ ] **Step 2: Реализовать обработчик Deposit**

Заменить временные колбэки из Task 2 и добавить обработчик. Найти строку `btn.tooltip_text = ...` в `_make_deposit_button` и добавить после неё подключение:

```gdscript
	btn.pressed.connect(_on_deposit_pressed.bind(card))
```

Добавить функцию:

```gdscript
func _on_deposit_pressed(card) -> void:
	if card == null or not is_instance_valid(card):
		return
	var iface = card.get("interface")
	if iface == null or not is_instance_valid(iface):
		return
	if iface.get("inputTarget") != card:
		return
	var task_data = card.get("taskData")
	var grid = card.get("inputGrid")
	if task_data == null or grid == null or not (grid is Node):
		return
	var slots := _slots_from_grid(grid)
	if slots.is_empty():
		return
	var offered := _selected_stacks(iface)
	if offered.is_empty():
		return
	var key := _key_of(task_data)
	var res := VTKDeposits.apply(_ledger(), key, slots, offered)
	var take: Array = res.get("take", [])
	if take.is_empty():
		return
	_consume(take)
	_ledger_set(res.get("ledger", {}))
	_render_task_card(iface, card)
	if card.has_method("CanComplete"):
		card.CanComplete()
```

Заглушку `_on_task_cancomplete` **не трогаем** здесь: хук исключён (CORRECTION выше), боевой гейт
не нужен. Коммит Task 3 завёл рабочий `_on_task_cancomplete` с `skip_super()` — Task 4 Step 0 его удалит.

- [ ] **Step 3: Стенды**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1 -Godot "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe"`
Expected: parse зелёный, тесты зелёные, exit 0.

- [ ] **Step 4: Ручная проверка**

В игре: нажать Input на задаче, выделить часть требуемых предметов, нажать Deposit. Ожидаемо: списывается не больше остатка, бейдж растёт, лишнее остаётся в инвентаре. При полном покрытии бейдж `✓`, ячейки зелёные, кнопка Deposit гаснет. В `user://Traders.tres` появляется мета `vtk_deposits`.

- [ ] **Step 5: Commit**

```bash
git add loadouts/mods/VTK/VTKHooks.gd
git commit -m "feat(deposits): deposit action, stack consumption"
```

---

### Task 4: Завершение по леджеру и очистка при сдаче

**Files:**
- Modify: `loadouts/mods/VTK/VTKHooks.gd` (коррекция рендера/гейта; `_on_task_complete_pressed`; `_on_task_completed`)

**Interfaces:**
- Consumes: `_card_covered`, `_clear_ledger_key`, `_render_task_card`, `VTKDeposits.is_covered`.
- Produces: рабочая кнопка Complete по покрытию; replace `task-_on_complete_pressed`; очистка леджера в `trader-completetask-post`.

**Предусловие:** Task 2 завёл 4 хука `_hooks_deposits` (включая `task-cancomplete`) и заглушку `_on_task_cancomplete`; Task 3 сделал её боевой со `skip_super()`. И то, и другое неверно (см. спеку): у void-метода `Task.CanComplete()` возврат замены **отбрасывается**, а `skip_super()` на покрытом пути отменяет единственный эффект — выставление `completeButton.disabled`. Хук убираем; доступность Complete выставляем в рендере.

- [ ] **Step 0: Убрать хук `task-cancomplete`, починить обходы детей**

1. В `_do_register()` удалить строку
   `_hooks_deposits.append(_lib.hook("task-cancomplete", _on_task_cancomplete))`
   (счётчик `_hooks_deposits.size()` уменьшится сам).
2. Удалить функцию `_on_task_cancomplete` целиком.
3. Добавить обход только «живых» детей. В `inputGrid` шаблона `Task.tscn` 7 статичных ячеек;
   `Task.Initialize` освобождает их `queue_free()` (отложенно) и добавляет реальные слоты — post-хук
   срабатывает в том же кадре, поэтому без фильтра считались бы фантомы:

```gdscript
func _live_children(grid) -> Array:
	var out: Array = []
	if grid == null or not (grid is Node):
		return out
	for c in grid.get_children():
		if c != null and is_instance_valid(c) and not c.is_queued_for_deletion():
			out.append(c)
	return out
```

4. `_slots_from_grid`: обходить `_live_children(grid)` вместо `grid.get_children()`.
5. `_render_all_tasks`: `for card in _live_children(list):`.
6. `_clear_badges`: `for cell in _live_children(grid):` (тело без изменений).
7. Переименовать `_paint_slot(grid, s)` → `_paint_cell(cells: Array, s)` и брать ячейку из массива
   (а не `grid.get_child(idx)`), чтобы индекс совпадал со «живым» списком:

```gdscript
func _paint_cell(cells: Array, s) -> void:
	var idx := int(s["index"])
	if idx < 0 or idx >= cells.size():
		return
	var cell = cells[idx]
	if cell == null or not is_instance_valid(cell):
		return
	var amount_lbl = cell.get_node_or_null("Details/Amount")
	if amount_lbl != null and amount_lbl is Node:
		amount_lbl.visible = false
	var badge = cell.get_node_or_null("VTKDepositBadge")
	if badge == null or not (badge is Label):
		badge = Label.new()
		badge.name = "VTKDepositBadge"
		badge.anchor_left = 0.0
		badge.anchor_top = 0.5
		badge.anchor_right = 1.0
		badge.anchor_bottom = 1.0
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		badge.add_theme_font_size_override("font_size", 11)
		cell.add_child(badge)
	if bool(s["satisfied"]):
		badge.text = "✓"
		if cell.has_method("State"):
			cell.call("State", "Selected")
	else:
		badge.text = VTKDeposits.badge_text(int(s["deposited"]), int(s["required"]))
```

8. В `_render_task_card` заменить блок покраски и выставить доступность Complete:

```gdscript
	var cells := _live_children(grid)
	var slots := _slots_from_grid(grid)
	if slots.is_empty():
		return
	var key := _key_of(task_data)
	var cov := VTKDeposits.coverage(_ledger(), key, slots)
	for s in cov["slots"]:
		_paint_cell(cells, s)
	if btn == null:
		btn = _make_deposit_button(card)
	if btn != null:
		btn.disabled = iface.get("inputTarget") != card or VTKDeposits.is_covered(cov)
	var cbtn = card.get_node_or_null("Margin/Elements/Buttons/Complete")
	if cbtn != null and cbtn is Button and VTKDeposits.is_covered(cov):
		cbtn.disabled = false
```

- [ ] **Step 1: Заменить заглушку `_on_task_complete_pressed`**

```gdscript
func _on_task_complete_pressed() -> void:
	var card = _lib._caller if _lib else null
	if card == null or not is_instance_valid(card) or not _card_covered(card):
		return
	var iface = card.get("interface")
	var trader = iface.get("trader") if iface != null else null
	var task_data = card.get("taskData") if card != null else null
	if iface == null or trader == null or task_data == null:
		return
	if card.has_method("Completed"):
		card.Completed()
	if trader.has_method("CompleteTask"):
		trader.call("CompleteTask", task_data)
	if iface.has_method("UpdateTraderInfo"):
		iface.call("UpdateTraderInfo")
	# Награды — ванильным GetOutputItems, который читает inputTarget.outputGrid.
	var prev_target = iface.get("inputTarget")
	var prev_inputting = iface.get("isInputting")
	iface.set("inputTarget", card)
	iface.set("isInputting", true)
	if iface.has_method("GetOutputItems"):
		iface.call("GetOutputItems")
	iface.set("inputTarget", prev_target)
	iface.set("isInputting", prev_inputting)
	if iface.has_method("ResetInput"):
		iface.call("ResetInput")
	if _lib != null:
		_lib.skip_super()
	_render_task_card(iface, card)
```

- [ ] **Step 2: Чистить леджер при сдаче**

В существующем `_on_task_completed(task_data)` (строка 434) добавить первой строкой после проверки `null`:

```gdscript
	_clear_ledger_key(task_data)
```

Итог функции:

```gdscript
func _on_task_completed(task_data) -> void:
	if task_data == null:
		return
	_clear_ledger_key(task_data)
	var ldr = get_node_or_null("/root/Loader")
	if ldr == null or not ldr.has_method("SaveTaskNotes"):
		return
	...существующий блок заметки без изменений...
```

- [ ] **Step 3: Стенды**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1 -Godot "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe"`
Expected: parse зелёный, тесты зелёные, exit 0.

- [ ] **Step 4: Ручная проверка**

В игре: полностью внести задачу (Deposit до покрытия), нажать Complete **без** входа в Input и **после** входа в Input — задача сдаётся, награды приходят, ничего из инвентаря не списывается, заметка пропадает, мета `vtk_deposits` для задачи очищается. Проверить смешанный случай: часть внесена, остаток выделен живыми предметами — Complete работает.

- [ ] **Step 5: Commit**

```bash
git add loadouts/mods/VTK/VTKHooks.gd
git commit -m "feat(deposits): complete covered tasks without consuming inventory"
```

---

### Task 5: Версия, документация, финальная сборка

**Files:**
- Modify: `loadouts/mod.txt`
- Modify: `loadouts/mods/VTK/version.txt`
- Modify: `README.md`
- Modify: `AGENTS.md`

- [ ] **Step 1: Поднять версию**

- `loadouts/mod.txt` → заменить `version="4.11.2"` на `version="4.12.0"`.
- `loadouts/mods/VTK/version.txt` → `4.12.0`.
- `README.md:7` → `**Версия:** 4.12.0`.

- [ ] **Step 2: Обновить AGENTS.md**

- В таблице файлов добавить строку про `loadouts/mods/VTK/VTKDeposits.gd` (чистая логика леджера PartialTasks, headless `test_deposits.gd`).
- В заметке про локализацию/тесты упомянуть `test_deposits.gd` в списке `$tests`.
- Обновить счётчик `preload`: `VTKHooks.gd` теперь грузит `Loc` и `VTKDeposits` — сверять командой:
  `Select-String -SimpleMatch 'preload(' -Path loadouts\mods\VTK\*.gd`
- В описании хуков `VTKHooks.gd` дописать новые: `interface-initializetasks-post`, `interface-startinput-post`, replace `task-_on_complete_pressed`.

- [ ] **Step 3: Прогнать стенды (layout + parse + ключи)**

Run:
```
& "C:\Users\home\AppData\Local\Programs\Python\Python312\python.exe" .check\layout_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1 -Godot "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe"
& "C:\Users\home\AppData\Local\Programs\Python\Python312\python.exe" .check\keycheck.py
```
Expected: layout OK (новых UI-символов вне VTKUI нет); `Parse check passed: 13 scripts`; `Tests passed: 7 file(s)`; keycheck без рассинхрона; exit 0 везде.

- [ ] **Step 4: Сборка**

Run: `powershell -ExecutionPolicy Bypass -File pack.ps1`
Expected: вывод печатает версию `4.12.0`; создаётся `Loadouts.vmz`.

- [ ] **Step 5: Установка и смоук в игре**

Скопировать `Loadouts.vmz` в папку модов игры, запустить, пройти ручной чеклист.

- [ ] **Step 6: Commit**

```bash
git add loadouts/mod.txt loadouts/mods/VTK/version.txt README.md AGENTS.md
git commit -m "chore: bump version to 4.12.0, document VTKDeposits"
```

---

## Manual Test Checklist (после сборки)

- Задача без `deliver` — кнопки Deposit и бейджей нет.
- Частичный депозит: списывается не больше остатка, лишнее остаётся; бейдж `N / M` растёт.
- Полное покрытие: бейдж `✓`, ячейки зелёные, Deposit гаснет, Complete активна.
- Complete без входа в Input и после — задача сдаётся, награды приходят, предметы не списываются дважды.
- Смешанный случай (часть внесена, часть выделена) — Complete работает.
- Заметка после сдачи пропадает (существующая механика Notes).
- Перезапуск игры: вклады на месте. Новая игра: вклады сброшены.
- Две задачи с одинаковым `deliver` у одного торговца — вклады не смешиваются.

## Notes for the implementer

- `Task.gd` скомпилирован (`.gdc`): тела методов `CanComplete` / `_on_complete_pressed` не читаются. Имена взяты из декомпиляции референса. Если хук не срабатывает — в логе Metro Mod Loader будет предупреждение «no such method» для `task-cancomplete` / `task-_on_complete_pressed`; тогда уточнить имена в `.check/_gdc_*` дампах (`_gdc_all.txt`).
- Загрузчик фиксирует wrap-surface по литеральным `.hook(...)` в исходниках мода — не сокращать имена хуков до переменных.
- Replace-хук единственный владелец: чужой мод на тот же `task-cancomplete` может выиграть (first-wins). Известный риск, отражён в спеке.
- Порядок слотов `inputGrid` стабилен между открытиями (`TaskData.deliver` с повторами), индекс слота — позиция ячейки.
- Семантика replace-хуков Metro Mod Loader: по умолчанию обёртка **всё равно зовёт ваниль и берёт её результат**, а `lib.skip_super()` отменяет ваниль. Поэтому заглушки `_on_task_cancomplete`/`_on_task_complete_pressed` можно заводить до реализации (`return false`/`pass` без `skip_super` → ваниль работает как раньше, регрессии нет). Боевые версии вызывают `skip_super()` только на «своём» пути (покрыто леджером).
- Deposit доступен только для карточки в режиме Input и пока задача не покрыта: `btn.disabled = iface.get("inputTarget") != card or VTKDeposits.is_covered(cov)`. Без подходящих выделенных предметов нажатие всё равно ничего не спишет (пустой `take` → ранний выход).
