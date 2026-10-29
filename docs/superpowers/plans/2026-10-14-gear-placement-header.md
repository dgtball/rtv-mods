# Вкладка «Снаряжение» кладёт в снаряжение + сдвиг шапки — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Клик по предмету на вкладке «Снаряжение» кладёт его в рюкзак (не в слот), а шапка «VOSTOK TOOLKIT» опускается ниже HUD-счётчика.

**Architecture:** Чистая логика в `VTKDraft.gd` получает `add_gear` (общая gear-ветка вынесена в `_gear_add`). `VTKUI.gd` протягивает флаг `force_gear` от сетки шага 2 до `_place_into`. Правка шапки — сдвиг четырёх `offset_top`ов.

**Tech Stack:** GDScript (Godot 4.6.3), headless-стенды `.check/check.ps1` и `.check/layout_check.py`.

## Global Constraints

- Отступы в `.gd` — **только табы**. Никаких пробелов для выравнивания.
- Версия поднимается до **4.17.1** (4.17.0 уже выпущен): `loadouts/mod.txt`, `loadouts/mods/VTK/version.txt`, `README.md` — в Task 4.
- Коммитим только трекаемые пути (`loadouts/**`, `CHANGELOG.md`). `.check/`, `docs/` под gitignore.
- Сообщения коммитов — префикс `feat:` / `fix:` (как в истории).
- Godot-бинарник: `D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe`.
- Гейт (запускать после каждой задачи):
  `powershell -NoProfile -ExecutionPolicy Bypass -File D:\RTVMOD\.check\check.ps1 -Godot "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe"`
  Зелёный = код выхода 0, `Parse check passed: 16 scripts`, `Tests passed: 9 file(s)`, нет строк `SCRIPT ERROR` / `Parse Error` / `Invalid call` / `Failed to load script`.
- `Draft` — чистая логика: ни `load()`, ни путей внутрь игры.

---

### Task 1: `Draft.add_gear` — предмет уходит в снаряжение мимо слотов

**Files:**
- Modify: `loadouts/mods/VTK/VTKDraft.gd:47-66` (функция `add`)
- Test: `.check/project/tests/test_draft.gd` (новый `t_add_gear`, регистрация в `_init`)

**Interfaces:**
- Consumes: существующие `free_slot_of` (`VTKDraft.gd:23`), `gear_index_of` (`:105`), `_desc` (`:40`).
- Produces:
  - `func add_gear(path: String, item_name: String, amount: float, type_name: String, counted: bool = false) -> void`
  - `func _gear_add(path: String, item_name: String, amt: float, type_name: String, counted: bool) -> void`

- [ ] **Step 1: Write the failing test**

Добавить в `.check/project/tests/test_draft.gd` строку регистрации в `_init()` (после `t_free_slot_of()`):

```gdscript
	t_add_gear()
```

И саму функцию (в конец файла, после `t_mag_shown_count`):

```gdscript
# Шаг 2: клик по предмету на вкладке «Снаряжение» кладёт его в рюкзак, минуя
# free_slot_of. Регрессия: граната/оружие/броня уезжали в снаряжение, потому
# что add() первым делом занимал свободный слот.
func t_add_gear() -> void:
	var d = Draft.new()
	var g := "res://gear_grenade.tres"
	d.add_gear(g, "Граната", 1.0, "Consumable")
	ck(d.equip.is_empty(), "add_gear не занимает слот экипировки")
	ck(d.gear.size() == 1, "add_gear кладёт предмет в снаряжение")
	ck(d.gear_index_of(g) == 0, "add_gear пишет по указанному пути")
	# slots у предмета игнорируются: слот-цель шага 2 пуст
	var w := "res://gear_weapon.tres"
	d.add_gear(w, "АК", 1.0, "Weapon")
	ck(d.equip.is_empty(), "оружие со слотами тоже идёт в снаряжение")
	ck(d.gear.size() == 2, "оружие добавилось второй записью")
	# повторный клик копит, а не плодит записи
	d.add_gear(w, "АК", 1.0, "Weapon")
	ck(d.gear.size() == 2, "повторный add_gear не плодит записи")
	ck(d.amount_of(w) == 2.0, "повторный add_gear даёт +1")
	# обойма: count, а не amount
	var mag := "res://gear_mag.tres"
	d.add_gear(mag, "Обойма", 8.0, "Attachment", true)
	var desc: Dictionary = d.descriptor_of(mag)
	ck(int(desc.get("count", 0)) == 1, "add_gear обоймы пишет count 1")
	ck(float(desc.get("amount", -1.0)) == 0.0, "add_gear обоймы не хранит патроны в amount")
	ck(Draft.is_full(desc) == true, "новая обойма из add_gear полная")
	# минус клампится, как в add()
	var a = Draft.new()
	a.add_gear("res://gear_med.tres", "Аптечка", -3.0, "Medical")
	ck(a.gear.size() == 1, "add_gear с минусом создаёт запись")
	ck(a.amount_of("res://gear_med.tres") == 0.0, "add_gear с минусом клампит к нулю")
	# регрессия: старый add по-прежнему занимает слот первым (шаг 1 не сломан)
	var r = Draft.new()
	r.add("res://slot_w.tres", "АК", ["Primary"], 1.0, "Weapon")
	ck(r.equip.has("Primary"), "add всё ещё занимает слот")
	ck(r.gear.is_empty(), "add не увёл предмет в снаряжение при свободном слоте")
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```
powershell -NoProfile -ExecutionPolicy Bypass -File D:\RTVMOD\.check\check.ps1 -Godot "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe"
```
Expected: FAIL for `test_draft.gd` (в выводе `Invalid call. Nonexistent function 'add_gear'` / нет `Draft tests passed`); итог с ненулевым кодом.

- [ ] **Step 3: Write minimal implementation**

Заменить тело `add` (`VTKDraft.gd:47-66`) на:

```gdscript
func add(path: String, item_name: String, slots, amount: float, type_name: String, counted: bool = false) -> String:
	var amt := maxf(0.0, amount)
	var slot := free_slot_of(slots)
	if slot != "":
		equip[slot] = _desc(path, item_name, amt, type_name)
		return slot
	_gear_add(path, item_name, amt, type_name, counted)
	return ""

# Общая gear-ветка add() и add_gear(): путь уже есть -> +1, иначе новая запись.
# Вынесена, чтобы правило стекирования жило в одном месте, а шаг 2 мог класть
# в снаряжение мимо free_slot_of.
func _gear_add(path: String, item_name: String, amt: float, type_name: String, counted: bool) -> void:
	var idx := gear_index_of(path)
	if idx >= 0:
		if gear[idx].has("count"):
			gear[idx]["count"] = int(gear[idx].get("count", 1)) + 1
		else:
			gear[idx]["amount"] = float(gear[idx].get("amount", 1.0)) + 1.0
		return
	var d := _desc(path, item_name, amt, type_name)
	if counted:
		d["count"] = 1
		d["amount"] = 0.0
		d["full_mag"] = true
	gear.append(d)

# Клик на вкладке «Снаряжение» (шаг 2): слот не выбирается, авто-экип там
# превращал гранату или ствол в снаряжение вопреки замыслу. Поэтому кладём
# в снаряжение напрямую, без free_slot_of.
func add_gear(path: String, item_name: String, amount: float, type_name: String, counted: bool = false) -> void:
	_gear_add(path, item_name, maxf(0.0, amount), type_name, counted)
```

- [ ] **Step 4: Run test to verify it passes**

Run: тот же `check.ps1`.
Expected: `VERDICT: ok res://tests/test_draft.gd`, `Draft tests passed`, `Tests passed: 9 file(s)`, код выхода 0.

- [ ] **Step 5: Commit**

```bash
git add loadouts/mods/VTK/VTKDraft.gd .check/project/tests/test_draft.gd
git commit -m "feat: Draft.add_gear places items into gear bypassing slots"
```

(Если `.check/project/tests/test_draft.gd` под gitignore — она там и есть; тогда `git add` только `loadouts/mods/VTK/VTKDraft.gd`. Проверить `git status`.)

---

### Task 2: Проброс `force_gear` из сетки шага 2 в `_place_into`

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd:2631` (`_make_item_cell`), `:2737-2741` (обработчик клика), `:2769-2805` (`_place_into`), `:1504` (вызов шага 2)

**Interfaces:**
- Consumes: `Draft.add_gear` из Task 1.
- Produces: ничего для следующих задач (последняя правка поведения).

- [ ] **Step 1: Расширить сигнатуру `_make_item_cell` и вызов шага 2**

`VTKUI.gd:2631` — добавить 4-й параметр:

```gdscript
func _make_item_cell(item, forced_slot = null, gear := false, force_gear := false) -> Control:
```

`VTKUI.gd:1504` — передать флаг:

```gdscript
		_gear_grid.add_child(_make_item_cell(res, "", true, true))
```

`VTKUI.gd:2738-2741` — пробросить в обработчик клика:

```gdscript
	cell.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_place_into(it, slot, force_gear)
	)
```

- [ ] **Step 2: Добавить ветку `force_gear` в `_place_into`**

Сигнатура (`VTKUI.gd:2769`):

```gdscript
func _place_into(item, slot: String, force_gear := false) -> void:
```

Сразу после строк `var slots = _item_slots(res)` и `var item_name := str(res.get("name"))` (то есть перед `if slot != ""`, `VTKUI.gd:2793`) вставить:

```gdscript
	# Шаг 2 («Снаряжение»): слот не выбирается, предмет идёт в снаряжение и
	# не занимает свободный слот экипировки.
	if force_gear:
		_draft.add_gear(path, item_name, amt, t, counted)
		_after_place()
		return
```

Обновить устаревшие комментарии про «Draft.add» для gear-клетки: `VTKUI.gd:2734-2736` и дубль `:2766-2768` — заменить упоминание `_place_into (Draft.add)` на `Draft.add_gear`.

- [ ] **Step 3: Гейт**

Run: `check.ps1`.
Expected: `Parse check passed: 16 scripts`, `Tests passed: 9 file(s)`, код 0. (Юнит-теста на UI нет — это парсинг + ручная проверка.)

- [ ] **Step 4: Commit**

```bash
git add loadouts/mods/VTK/VTKUI.gd
git commit -m "fix: gear tab adds items to backpack instead of equipping"
```

---

### Task 3: Опустить шапку «VOSTOK TOOLKIT» под счётчик убийств

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd:445-457` (рейл), `:498-508` (полоса), `:510-516` (вкладки), `:530-536` (скролл), комментарий `:445-451`

**Interfaces:**
- Consumes: —
- Produces: —

- [ ] **Step 1: Сдвинуть верхний блок вниз на 10px**

`VTKUI.gd:452-457` (рейл) — `offset_top`/`offset_bottom` с 24/54 на 34/64:

```gdscript
	var rail := HBoxContainer.new()
	rail.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	rail.offset_left = 4
	rail.offset_top = 34
	rail.offset_right = -4
	rail.offset_bottom = 64
```

`VTKUI.gd:500-505` (полоса `rail_sep`) — 56/57 на 66/67:

```gdscript
	var rail_sep := ColorRect.new()
	rail_sep.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	rail_sep.offset_left = 4
	rail_sep.offset_top = 66
	rail_sep.offset_right = -4
	rail_sep.offset_bottom = 67
```

`VTKUI.gd:510-516` (tab_bar) — 58/88 на 68/98:

```gdscript
	var tab_bar = HBoxContainer.new()
	tab_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	tab_bar.offset_left = 4
	tab_bar.offset_top = 68
	tab_bar.offset_right = -4
	tab_bar.offset_bottom = 98
```

`VTKUI.gd:530-536` (`_scroll`) — `offset_top` 92 на 102 (`offset_bottom = -4` не трогать):

```gdscript
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_left = 4
	_scroll.offset_top = 102
	_scroll.offset_right = -4
	_scroll.offset_bottom = -4
```

- [ ] **Step 2: Обновить комментарий**

`VTKUI.gd:448-451` — поправить число в пояснении:

```gdscript
	# Отступ сверху не 4, а 34: счётчик убийств - отдельный CanvasLayer слоем
	# 9999 поверх панели, его Label стоит в (10,10) шрифтом 13 и опускается до
	# y≈28, и при меньшем верхе имя «VOSTOK TOOLKIT» уходило под счётчик.
	# Рейл и вкладки сдвинуты на ту же величину, чтобы не наехать друг на друга.
```

- [ ] **Step 3: Гейт**

Run: `check.ps1`.
Expected: `Parse check passed: 16 scripts`, `Tests passed: 9 file(s)`, код 0.

- [ ] **Step 4: Commit**

```bash
git add loadouts/mods/VTK/VTKUI.gd
git commit -m "fix: lower panel header clear of the kill counter"
```

---

### Task 4: CHANGELOG и версия 4.17.1

**Files:**
- Modify: `CHANGELOG.md` (новая секция `## [4.17.1] - 2026-10-14`, группа `### Fixed`)
- Modify: `loadouts/mod.txt` (поле `version`), `loadouts/mods/VTK/version.txt`, `README.md` (строка `**Version:**`)

**Interfaces:**
- Consumes: — (в версии 4.17.1 поднимется ещё раз план ammo — там только `### Added`, без повторного бампа)
- Produces: —

- [ ] **Step 1: Секция CHANGELOG 4.17.1**

Над `## [4.17.0] - 2026-10-14` вставить новую секцию (пункт — видимый игроку эффект, без внутренних имён):

```markdown
## [4.17.1] - 2026-10-14

### Fixed

- Items added on the Gear tab now go to the backpack instead of the equipment slots.
```

Проверить, что между заголовком группы и пунктами стоит пустая строка.

- [ ] **Step 2: Поднять версию до 4.17.1**

`loadouts/mod.txt`: `version` → `4.17.1`.
`loadouts/mods/VTK/version.txt`: `4.17.1`.
`README.md`: в строке `**Version:**` заменить `4.17.0` → `4.17.1` (не трогая остальной текст строки).

- [ ] **Step 3: Финальный гейт + сборка**

Run: `check.ps1` (ожидание как выше), затем:
```
powershell -ExecutionPolicy Bypass -File D:\RTVMOD\pack.ps1
```
Expected: `pack.ps1` печатает версию `4.17.1` из `mod.txt`, собирает `Loadouts.vmz`.

- [ ] **Step 4: Commit**

```bash
git add CHANGELOG.md loadouts/mod.txt loadouts/mods/VTK/version.txt README.md
git commit -m "release: 4.17.1"
```

---

## Self-Review

- **Spec coverage:** A (`add_gear` + `force_gear`) — Task 1, 2; B (сдвиг шапки) — Task 3; CHANGELOG — Task 4. Спека `2026-10-14-gear-placement-header-design.md` покрыта полностью.
- **Placeholder scan:** пустых «TBD/TODO» нет; все шаги с кодом.
- **Type consistency:** `add_gear(path, item_name, amount, type_name, counted)` совпадает в Task 1 (реализация) и Task 2 (вызов в `_place_into`). `_make_item_cell(item, forced_slot, gear, force_gear)` — 4-й параметр добавлен в сигнатуре и в вызове `:1504`. `_gear_add` — приватный, вызывается только из `add` и `add_gear`.
