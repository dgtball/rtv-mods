# Управление количеством в клетке снаряжения (патроны, обоймы) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** В клетке снаряжения патроны шагают целой коробкой (`defaultAmount`) и получают разовую кнопку Full; число можно ввести с клавиатуры; у обойм тумблер Full/Empty переезжает вниз и ясно помечается.

**Architecture:** Пол/потолок инкремента выносится в чистый `VTKDraft.bump_amount` (тестируется headless). Шаг «на добавление» при повторе клика — необязательные `step`/`cap` в `_gear_add`/`add`/`add_gear`. `VTKUI` считает `step`/`cap` из ресурса (`_gear_step`/`_gear_cap`), протягивает их в `_place_into` и перерисовывает клетку в две строки: A — степпер со вводом числа, B — контекстная кнопка.

**Tech Stack:** GDScript (Godot 4.6.3), headless-стенды `.check/check.ps1` и `.check/layout_check.py`, `keycheck.py`.

## Global Constraints

- Отступы в `.gd` — **только табы**. Никаких пробелов для выравнивания.
- Версия **4.17.1** поднимается планом `2026-10-14-gear-placement-header.md` (Task 4). Этот план версию **не бампает** — только добавляет пункты `### Added` в уже существующую секцию `## [4.17.1]`.
- **Порядок обязателен:** сначала довести до конца план gear/header (задачи 2–4), потом этот. Причина — `_make_item_cell` (`VTKUI.gd:2631`), `_place_into` (`:2769`) и `_bump_gear` правит он же.
- Коммитим только трекаемые пути (`loadouts/**`, `CHANGELOG.md`). `.check/`, `docs/` под gitignore.
- Сообщения коммитов — префикс `feat:` / `docs:` (как в истории).
- Godot-бинарник: `D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe`.
- Гейт (запускать после каждой задачи):
  `powershell -NoProfile -ExecutionPolicy Bypass -File D:\RTVMOD\.check\check.ps1 -Godot "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe"`
  Зелёный = код выхода 0, `Parse check passed: 16 scripts`, `Tests passed: 9 file(s)`, нет строк `SCRIPT ERROR` / `Parse Error` / `Invalid call` / `Failed to load script`.
- Плюс после задач, трогающих `VTKLoc.gd`/UI: `py -3 .check\keycheck.py` (рассинхрон ключей) и `py -3 .check\layout_check.py` (раскладка picker, правок не требует — крестик `PRESET_TOP_RIGHT` в клетке сохраняется).
- `Draft` — чистая логика: ни `load()`, ни путей внутрь игры. `VTKUI` ресурсы грузит, поэтому headless-тестов на UI нет — только парсинг + ручная проверка.

---

### Task 1: `Draft.bump_amount` — инкремент с полом и потолком

**Files:**
- Modify: `loadouts/mods/VTK/VTKDraft.gd` (новая функция рядом с `set_gear_amount`, `VTKDraft.gd:222-232`)
- Test: `.check/project/tests/test_draft.gd` (новый `t_bump_amount`, регистрация в `_init`)

**Interfaces:**
- Consumes: `amount_of` (`VTKDraft.gd:128`), `set_gear_amount` (`:222`), `gear_index_of` (`:117`).
- Produces: `func bump_amount(path: String, dir: float, step: float, cap: float) -> void` — зовётся из `VTKUI._bump_gear` (Task 3).

- [ ] **Step 1: Write the failing test**

В `.check/project/tests/test_draft.gd` после `t_add_gear()` в `_init()` (`test_draft.gd:30`) добавить строку регистрации:

```gdscript
	t_bump_amount()
```

И саму функцию в конец файла (после `t_add_gear`, `test_draft.gd:599`):

```gdscript
# Шаг «+/−» в клетке снаряжения. Пол = 1: «−» не удаляет запись, удаление
# только через ✕. Потолок задаёт вызывающий: патроны - maxAmount, обоймы - 99.
func t_bump_amount() -> void:
	var ammo := "res://ammo_bump.tres"
	var d = Draft.new()
	d.add_gear(ammo, "5.45x39", 30.0, "Ammo")
	ck(d.amount_of(ammo) == 30.0, "bump_amount: первая коробка ложится как amount 30")
	d.bump_amount(ammo, 1.0, 30.0, 300.0)
	ck(d.amount_of(ammo) == 60.0, "bump_amount прибавляет шаг, а не 1")
	d.bump_amount(ammo, 1.0, 30.0, 300.0)
	ck(d.amount_of(ammo) == 90.0, "bump_amount шагает коробками дальше")
	d.bump_amount(ammo, 1.0, 300.0, 300.0)
	ck(d.amount_of(ammo) == 300.0, "bump_amount не превышает потолок")
	d.bump_amount(ammo, 1.0, 300.0, 300.0)
	ck(d.amount_of(ammo) == 300.0, "bump_amount на потолке остаётся на потолке")
	d.bump_amount(ammo, -1.0, 300.0, 300.0)
	ck(d.amount_of(ammo) == 1.0, "bump_amount вниз клампится к 1, не удаляет")
	d.bump_amount(ammo, -1.0, 30.0, 300.0)
	ck(d.amount_of(ammo) == 1.0, "bump_amount ниже единицы не идёт")
	ck(d.gear_index_of(ammo) >= 0, "bump_amount не выбрасывает запись на полу")
	# обоймы: потолок 99, шаг 1
	var mag := "res://mag_bump.tres"
	var m = Draft.new()
	m.add_gear(mag, "Обойма", 8.0, "Attachment", true)
	m.bump_amount(mag, 1.0, 1.0, 99.0)
	ck(m.amount_of(mag) == 2.0, "bump_amount обоймы прибавляет одну обойму")
	m.bump_amount(mag, -1.0, 1.0, 99.0)
	ck(m.amount_of(mag) == 1.0, "bump_amount обоймы убавляет до 1")
	# cap = 0 значит "без потолка"
	var med := "res://med_bump.tres"
	var c = Draft.new()
	c.add_gear(med, "Аптечка", 1.0, "Medical")
	c.bump_amount(med, 1.0, 1.0, 0.0)
	ck(c.amount_of(med) == 2.0, "bump_amount без потолка растёт свободно")
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```
powershell -NoProfile -ExecutionPolicy Bypass -File D:\RTVMOD\.check\check.ps1 -Godot "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe"
```
Expected: FAIL для `test_draft.gd` (`Invalid call. Nonexistent function 'bump_amount'`), нет `Draft tests passed`, ненулевой код выхода.

- [ ] **Step 3: Write minimal implementation**

В `loadouts/mods/VTK/VTKDraft.gd` после `set_gear_amount` (`VTKDraft.gd:232`) добавить:

```gdscript
# Инкремент количества с полом и потолком. Пол = 1: «−» не удаляет запись,
# удаление - только ✕. step/cap приходят от UI: черновик не грузит ресурсы и
# не знает ни стака калибра, ни вместимости.
func bump_amount(path: String, dir: float, step: float, cap: float) -> void:
	var t := amount_of(path) + dir * step
	if t < 1.0:
		t = 1.0
	if cap > 0.0 and t > cap:
		t = cap
	set_gear_amount(path, t)
```

- [ ] **Step 4: Run test to verify it passes**

Run: тот же `check.ps1`.
Expected: `Draft tests passed`, `Tests passed: 9 file(s)`, код 0.

- [ ] **Step 5: Commit**

```bash
git add loadouts/mods/VTK/VTKDraft.gd
git commit -m "feat: Draft.bump_amount steps gear amount with floor and cap"
```
(`.check/project/tests/test_draft.gd` под gitignore — проверить `git status`, лишнее не добавлять.)

---

### Task 2: `Draft` — шаг при повторном клике (`step`/`cap`)

**Files:**
- Modify: `loadouts/mods/VTK/VTKDraft.gd:47-78` (`add`, `_gear_add`, `add_gear`)
- Test: `.check/project/tests/test_draft.gd` (новый `t_add_gear_step`, регистрация в `_init`)

**Interfaces:**
- Consumes: —
- Produces:
  - `func _gear_add(path: String, item_name: String, amt: float, type_name: String, counted: bool, step := 0.0, cap := 0.0) -> void`
  - `func add(path: String, item_name: String, slots, amount: float, type_name: String, counted: bool = false, step := 0.0, cap := 0.0) -> String`
  - `func add_gear(path: String, item_name: String, amount: float, type_name: String, counted: bool = false, step := 0.0, cap := 0.0) -> void`

- [ ] **Step 1: Write the failing test**

Регистрация в `_init()` (после `t_bump_amount()` из Task 1):

```gdscript
	t_add_gear_step()
```

Функция в конец файла:

```gdscript
# Патроны в снаряжение попадают коробкой и коробкой же шагают при повторном
# клике. Прочие предметы остаются на правиле «ровно +1» (шаг по умолчанию 0).
func t_add_gear_step() -> void:
	var ammo := "res://ammo_step.tres"
	var d = Draft.new()
	d.add_gear(ammo, "5.45x39", 30.0, "Ammo", false, 30.0, 300.0)
	ck(d.amount_of(ammo) == 30.0, "клик по патронам кладёт коробку")
	d.add_gear(ammo, "5.45x39", 30.0, "Ammo", false, 30.0, 300.0)
	ck(d.amount_of(ammo) == 60.0, "повторный клик прибавляет коробку, а не 1")
	for i in range(20):
		d.add_gear(ammo, "5.45x39", 30.0, "Ammo", false, 30.0, 300.0)
	ck(d.amount_of(ammo) == 300.0, "клик по патронам упирается в потолок 300")
	# без step повтор по-прежнему +1 (правило не сломано)
	var med := "res://med_step.tres"
	var p = Draft.new()
	p.add_gear(med, "Аптечка", 1.0, "Medical")
	p.add_gear(med, "Аптечка", 50.0, "Medical")
	ck(p.amount_of(med) == 2.0, "add_gear без step на повтор даёт +1")
	# add() с step всё ещё занимает свободный слот
	var w := "res://w_step.tres"
	var s: String = p.add(w, "АК", ["Primary"], 1.0, "Weapon", false, 1.0, 0.0)
	ck(s == "Primary", "add с step заполняет слот как прежде")
	# обойма: шаг не влияет, считаются штуки
	var mag := "res://mag_step.tres"
	var m = Draft.new()
	m.add_gear(mag, "Обойма", 8.0, "Attachment", true, 30.0, 300.0)
	m.add_gear(mag, "Обойма", 8.0, "Attachment", true, 30.0, 300.0)
	ck(m.amount_of(mag) == 2.0, "step не влияет на счёт обойм")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `check.ps1`.
Expected: FAIL — `add_gear` не принимает 7 аргументов (`Invalid call`), нет `Draft tests passed`.

- [ ] **Step 3: Write minimal implementation**

Заменить `add` (`VTKDraft.gd:47-54`) на:

```gdscript
func add(path: String, item_name: String, slots, amount: float, type_name: String, counted: bool = false, step := 0.0, cap := 0.0) -> String:
	var amt := maxf(0.0, amount)
	var slot := free_slot_of(slots)
	if slot != "":
		equip[slot] = _desc(path, item_name, amt, type_name)
		return slot
	_gear_add(path, item_name, amt, type_name, counted, step, cap)
	return ""
```

Заменить `_gear_add` (`VTKDraft.gd:59-72`): правило повтора становится шаговым.

```gdscript
func _gear_add(path: String, item_name: String, amt: float, type_name: String, counted: bool, step := 0.0, cap := 0.0) -> void:
	var idx := gear_index_of(path)
	if idx >= 0:
		if gear[idx].has("count"):
			gear[idx]["count"] = int(gear[idx].get("count", 1)) + 1
		else:
			var inc := 1.0 if step <= 0.0 else step
			var t := float(gear[idx].get("amount", 1.0)) + inc
			if cap > 0.0 and t > cap:
				t = cap
			gear[idx]["amount"] = t
		return
	var d := _desc(path, item_name, amt, type_name)
	if counted:
		d["count"] = 1
		d["amount"] = 0.0
		d["full_mag"] = true
	gear.append(d)
```

Заменить `add_gear` (`VTKDraft.gd:77-78`) на:

```gdscript
func add_gear(path: String, item_name: String, amount: float, type_name: String, counted: bool = false, step := 0.0, cap := 0.0) -> void:
	_gear_add(path, item_name, maxf(0.0, amount), type_name, counted, step, cap)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `check.ps1`.
Expected: `Draft tests passed`, `Tests passed: 9 file(s)`, код 0. Существующий `t_add_clamp` («ровно +1 независимо от переданного amount», `test_draft.gd:408`) остаётся зелёным.

- [ ] **Step 5: Commit**

```bash
git add loadouts/mods/VTK/VTKDraft.gd
git commit -m "feat: repeated gear click steps by a whole box for ammo"
```

---

### Task 3: `VTKUI` — `step`/`cap` из ресурса и проброс в добавление/шаг

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd:2378-2391` (`_info_of`), `:2535-2539` (`_bump_gear`), `:2769-2805` (`_place_into`); новые хелперы рядом с `_bump_gear`.

**Interfaces:**
- Consumes: `Draft.bump_amount` (Task 1), `Draft.add`/`add_gear` с `step`/`cap` (Task 2), `_is_magazine` (`VTKUI.gd:1245`), `_item_info` (`:2371`).
- Produces: `_gear_step(path) -> float`, `_gear_cap(path) -> float` (используются в Task 4 кнопками Full и вводом числа).

> **Зависимость:** `_place_into` уже принимает `force_gear` из плана gear/header (Task 2). Если её ещё нет — сначала выполнить тот план.

- [ ] **Step 1: Добавить `defaultAmount` в `_info_of`**

В словаре `_info_of` (`VTKUI.gd:2390`) после строки `"maxAmount": res.get("maxAmount"),` добавить:

```gdscript
		"defaultAmount": res.get("defaultAmount"),
```

- [ ] **Step 2: Добавить `_gear_step`/`_gear_cap` и переписать `_bump_gear`**

Заменить `_bump_gear` (`VTKUI.gd:2535-2539`) на:

```gdscript
# Шаг «−/+» и потолок клетки снаряжения. Патроны шагают стаком калибра и
# упираются во вместимость; обоймы - по штуке до 99; прочее - по одному до
# maxAmount, если он задан. Знание о ресурсе живёт здесь, в Draft не идёт.
func _gear_step(path: String) -> float:
	var info := _item_info(path)
	if str(info.get("type")) == "Ammo":
		var da = info.get("defaultAmount")
		if da != null and float(da) >= 1.0:
			return float(da)
	return 1.0

func _gear_cap(path: String) -> float:
	if _is_magazine(path):
		return 99.0
	var ma = _item_info(path).get("maxAmount")
	if ma != null and float(ma) > 1.0:
		return float(ma)
	return 0.0

# dir - направление шага (+1 / -1), не сырая дельта: шаг и потолок зависят от
# ресурса, поэтому считаются здесь, а не в вызывающем коде.
func _bump_gear(path: String, dir: float) -> void:
	if _draft == null:
		return
	_draft.bump_amount(path, dir, _gear_step(path), _gear_cap(path))
	refresh(RefreshScope.GEAR | RefreshScope.DONE)
```

(Вызовы `_bump_gear(path_now, -1.0)` / `(path_now, 1.0)` в `_make_item_cell` остаются валидными: ±1 — это направление. Перерисуются они в Task 4.)

- [ ] **Step 3: Протянуть `step`/`cap` в `_place_into`**

Заменить блок расчёта количества в `_place_into` (`VTKUI.gd:2784-2789`):

```gdscript
	var t := str(res.get("type"))
	# Патроны в снаряжение попадают коробкой (defaultAmount) и той же коробкой
	# шагают: клик и «+/−» в одном масштабе, потолок - maxAmount. Прочие
	# стакаемые по-прежнему берут maxAmount; оружие - 1.
	var amt := 1.0
	var step := 0.0
	var cap := 0.0
	if t == "Ammo":
		var da = res.get("defaultAmount")
		if da != null and float(da) >= 1.0:
			amt = float(da)
			step = float(da)
		var ma = res.get("maxAmount")
		if ma != null and float(ma) > 1.0:
			cap = float(ma)
	elif t != "Weapon":
		var max_am = res.get("maxAmount")
		if max_am != null and float(max_am) > 1.0:
			amt = float(max_am)
```

В force_gear-ветке (`_place_into`, добавлена планом gear/header) передать шаг и потолок:

```gdscript
	if force_gear:
		_draft.add_gear(path, item_name, amt, t, counted, step, cap)
		_after_place()
		return
```

В обычный путь (`VTKUI.gd:2804`) передать шаг и потолок:

```gdscript
	_draft.add(path, item_name, slots, amt, t, counted, step, cap)
```

- [ ] **Step 4: Гейт**

Run: `check.ps1`, затем `py -3 .check\layout_check.py`.
Expected: `Parse check passed: 16 scripts`, `Tests passed: 9 file(s)`, код 0; `layout_check.py` код 0. (UI-юнитов нет — парсинг + ручная проверка.)

- [ ] **Step 5: Commit**

```bash
git add loadouts/mods/VTK/VTKUI.gd
git commit -m "feat: ammo added and stepped by a whole box in gear cells"
```

---

### Task 4: Клетка снаряжения — строки A/B, кнопки Full, ввод числа, ключ `Full`

**Files:**
- Modify: `loadouts/mods/VTK/VTKLoc.gd` (RU-ключ `Full`)
- Modify: `loadouts/mods/VTK/VTKUI.gd`: `_make_full_mag_btn` (`:1277-1295`), `_make_item_cell` (`:2631-2730`); новые `_style_full_btn`, `_make_full_ammo_btn`, `_make_gear_action_row`, `_make_gear_count`, `_gear_edit_cap`, `_open_gear_amount_edit` (рядом с `_make_full_mag_btn`).

**Interfaces:**
- Consumes: `_gear_step`/`_gear_cap` (Task 3), `Draft.is_full`/`set_full_mag`/`set_gear_amount`, `VTKSurface.style_button`/`panel`/`focus_style`, `Loc.txt`.
- Produces: `_make_full_ammo_btn(path, desc) -> Button` (вызывается только из `_make_gear_action_row`).

- [ ] **Step 1: Ключ локализации `Full`**

В `VTKLoc.gd` в словаре `RU` добавить (по алфавиту/рядом с прочими `Full*`):

```gdscript
	"Full": "Полный",
```

- [ ] **Step 2: Общий вид кнопки Full + кнопка патронов**

Перед `_make_full_mag_btn` (`VTKUI.gd:1277`) добавить:

```gdscript
# Единый вид кнопок Full: включено - заливка и золотая точка, выключено -
# серый контур без точки. Точка - символ в тексте, а не отдельный узел:
# Button не контейнер, позиционировать детей вручную здесь хрупко.
func _style_full_btn(b: Button, on: bool, label: String) -> void:
	b.text = ("● " if on else "") + label
	b.custom_minimum_size = Vector2(0, 22)
	VTKSurface.style_button(b, on, false, 8, 8, 4, 4)
	b.add_theme_color_override("font_color", _gold if on else VTKSurface.GREY_DIM)

# Разовое действие патронов: выставить полный стак. Горит, когда уже полный.
func _make_full_ammo_btn(path: String, _desc: Dictionary) -> Button:
	var cap := _gear_cap(path)
	var on := cap > 0.0 and _draft != null and _draft.amount_of(path) >= cap
	var b := Button.new()
	_style_full_btn(b, on, Loc.txt("Full") + " · " + str(int(cap)))
	b.pressed.connect(func():
		if _draft == null or cap <= 0.0:
			return
		_draft.set_gear_amount(path, cap)
		refresh(RefreshScope.PAGES)
	)
	return b
```

- [ ] **Step 3: Переписать `_make_full_mag_btn` под общий вид (без `compact`)**

Заменить `_make_full_mag_btn` (`VTKUI.gd:1277-1295`) на:

```gdscript
# У обоймы тумблер переехал в строку B и стал крупным: прежний зажатый
# компакт-вид (шрифт 8, поля 2/2) почти не отличал включено от выключено.
func _make_full_mag_btn(path: String, desc: Dictionary) -> Button:
	var on := Draft.is_full(desc)
	var b := Button.new()
	_style_full_btn(b, on, Loc.txt("Full magazine") if on else Loc.txt("Empty"))
	b.pressed.connect(func():
		if _draft == null:
			return
		# Состояние берём с актуального descriptor'а, а не с захваченного
		# desc: после пересборки клеток он уже может быть не тем объектом.
		_draft.set_full_mag(path, not Draft.is_full(_draft.descriptor_of(path)))
		refresh(RefreshScope.PAGES)
	)
	return b
```

- [ ] **Step 4: Строка B и счётчик с вводом**

Рядом добавить:

```gdscript
# Строка B клетки снаряжения: одно действие по типу предмета, либо null.
func _make_gear_action_row(path: String, desc: Dictionary) -> Control:
	if _is_magazine(path):
		return _make_full_mag_btn(path, desc)
	if str(_item_info(path).get("type")) == "Ammo":
		return _make_full_ammo_btn(path, desc)
	if _att_panel_needed(_item_info(path)):
		return _make_att_btn(desc)
	return null

# Потолок для ручного ввода. cap = 0 значит "без потолка": в вводе берём
# большое число, иначе клампилось бы к нулю.
func _gear_edit_cap(path: String) -> int:
	var cap := _gear_cap(path)
	return int(cap) if cap >= 1.0 else 999999

# Число в строке A: клик открывает ввод точного значения. Внутри - Label,
# который подменяется LineEdit'ом на месте.
func _make_gear_count(path: String, cnt: int) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(30, 28)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := Label.new()
	lbl.text = str(cnt)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", _gold)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	lbl.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_open_gear_amount_edit(holder, lbl, path, cnt)
	)
	holder.add_child(lbl)
	return holder

# Клик по числу: Label -> LineEdit. Enter/потеря фокуса применяют значение,
# Esc отменяет. settled гасит двойной вызов (Enter + focus_exited).
func _open_gear_amount_edit(holder: Control, lbl: Label, path: String, cnt: int) -> void:
	var edit := LineEdit.new()
	edit.text = str(cnt)
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.add_theme_font_size_override("font_size", 12)
	edit.custom_minimum_size = Vector2(30, 28)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	edit.add_theme_stylebox_override("normal", VTKSurface.panel(true, 6))
	edit.add_theme_stylebox_override("focus", VTKSurface.focus_style())
	lbl.visible = false
	holder.add_child(edit)
	edit.grab_focus()
	var settled := false
	var apply := func(ok: bool) -> void:
		if settled:
			return
		settled = true
		if ok and _draft != null:
			var v := clampi(edit.text.to_int(), 1, _gear_edit_cap(path))
			_draft.set_gear_amount(path, float(v))
		# Пересборка сетки убирает поле - откладываем на кадр, чтобы не
		# освобождать узел внутри его же сигнала.
		refresh.call_deferred(RefreshScope.PAGES)
	edit.text_submitted.connect(func(_t: String) -> void: apply.call(true))
	edit.focus_exited.connect(func() -> void: apply.call(true))
	edit.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
			apply.call(false)
	)
```

- [ ] **Step 5: Перестроить клетку снаряжения**

`VTKUI.gd:2640` — высота клетки снаряжения 176 → 200 (добавился ряд):

```gdscript
	cell.custom_minimum_size = Vector2(GEAR_CELL_W, 200 if gi >= 0 else (168 if gear else 152))
```

Заменить gear-блок `VTKUI.gd:2669-2729` (от `if gear and _draft != null and gi >= 0:` до закрывающей скобки перед `cell.tooltip_text`) на:

```gdscript
	if gear and _draft != null and gi >= 0:
		cell.add_theme_stylebox_override("panel", in_set_style)
		var desc_g: Dictionary = _draft.gear[gi]
		var cnt_g := Draft.shown_count(desc_g)

		# Строка A: шаг. Число между «−» и «+» кликабельно (ввод точного
		# значения). Дубль ×N убран - число живёт здесь само.
		var row_a := HBoxContainer.new()
		row_a.add_theme_constant_override("separation", 4)
		row_a.alignment = BoxContainer.ALIGNMENT_CENTER
		row_a.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var minus := _make_mini_btn("−", Vector2(28, 28), 15)
		minus.pressed.connect(func(): _bump_gear(path_now, -1.0))
		row_a.add_child(minus)
		row_a.add_child(_make_gear_count(path_now, cnt_g))
		var plus := _make_mini_btn("+", Vector2(28, 28), 15)
		plus.pressed.connect(func(): _bump_gear(path_now, 1.0))
		row_a.add_child(plus)
		vbox.add_child(row_a)

		# Строка B: одно контекстное действие предмета, если оно есть.
		# Патроны - разовый Full, обоймы - тумблер Full magazine/Empty,
		# остальное с обвесами - rnd. (переехала из строки A).
		var row_b := _make_gear_action_row(path_now, desc_g)
		if row_b != null:
			vbox.add_child(row_b)

		# Удаление - крестик в правом верхнем углу клетки, красный: это
		# уничтожение набора, его не должно быть рядом с «В инвентарь».
		# Panel - не контейнер, якоря работают; кнопка добавляется после
		# center и рисуется поверх, клики на себя забирает она.
		var drop := _make_mini_btn("✕", Vector2(20, 20), 11)
		VTKSurface.style_button(drop, false, true, 2, 2, 2, 2)
		drop.add_theme_color_override("font_color", Color("#e05a4a"))
		drop.tooltip_text = Loc.txt("Remove")
		drop.pressed.connect(func(): _remove_gear(path_now))
		cell.add_child(drop)
		drop.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		drop.offset_left = -22
		drop.offset_top = 2
		drop.offset_right = -2
		drop.offset_bottom = 22
```

Проверить, что прежний вызов `_make_full_mag_btn(path_now, desc_g, true)` (`VTKUI.gd:2688`) удалён вместе со старым блоком (сигнатура без `compact`).

- [ ] **Step 6: Гейт**

Run: `check.ps1`, затем `py -3 .check\keycheck.py`, затем `py -3 .check\layout_check.py`.
Expected: `Parse check passed: 16 scripts`, `Tests passed: 9 file(s)`, код 0 (нет `SCRIPT ERROR` / `Parse Error` / `Invalid call`); `keycheck.py` не находит неключёванных/лишних строк; `layout_check.py` код 0.

Ручная проверка (владелец, в игре): патроны шагают коробкой и Full заливается; клик по числу даёт поле ввода (Enter/Esc); обойма Full/Empty крупная и с точкой; `rnd.` у снаряжения с обвесами; ✕ на месте.

- [ ] **Step 7: Commit**

```bash
git add loadouts/mods/VTK/VTKUI.gd loadouts/mods/VTK/VTKLoc.gd
git commit -m "feat: gear cell with ammo/magazine amount controls and typed amounts"
```

---

### Task 5: CHANGELOG `### Added` и сборка

**Files:**
- Modify: `CHANGELOG.md` (секция `## [4.17.1] - 2026-10-14`, группа `### Added`)
- Build: `pack.ps1` → `Loadouts.vmz`

**Interfaces:**
- Consumes: — (версию уже поднял план gear/header)
- Produces: —

- [ ] **Step 1: Пункты `### Added`**

В `CHANGELOG.md`, в секции `## [4.17.1] - 2026-10-14` под `### Fixed` (если секции нет — создать её целиком с `### Added` и `### Fixed` из плана gear/header), добавить группу `### Added`:

```markdown
### Added

- Ammo is now added to and stepped by a whole box, with a Full button to top up a stack.
- Click a gear item's number to type an exact amount.
- The magazine Full/Empty control sits below the count and is clearly marked when on.
```

Между заголовком группы и пунктами — пустая строка.

- [ ] **Step 2: Финальный гейт + сборка**

Run: `check.ps1` (ожидание как выше), затем:
```
powershell -ExecutionPolicy Bypass -File D:\RTVMOD\pack.ps1
```
Expected: `pack.ps1` печатает `4.17.1` из `mod.txt`, собирает `Loadouts.vmz`.

- [ ] **Step 3: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: changelog 4.17.1 ammunition controls"
```

---

## Self-Review

- **Spec coverage:** п.1 (шаг = стак, пол 1, потолок maxAmount) — Task 1, 2, 3; п.2 (Full у патронов) — Task 4; п.3 (Full magazine вниз, крупная) — Task 4; п.4 (заливка + точка) — Task 4 (`_style_full_btn`); п.5 (ввод числа) — Task 4; п.6 (клик по патронам = коробка) — Task 2, 3. Локализация `Full` — Task 4. CHANGELOG — Task 5. Спека `2026-10-14-ammo-magazine-amount-controls-design.md` покрыта полностью.
- **Placeholder scan:** пустых «TBD/TODO» нет; все шаги с кодом.
- **Type consistency:** `bump_amount(path, dir, step, cap)` — реализация (Task 1) и вызов (Task 3) совпадают. `step`/`cap` — последние необязательные параметры `_gear_add`/`add`/`add_gear` (Task 2), пробрасываются в `_place_into` (Task 3). `_gear_cap` используется в `_make_full_ammo_btn`/`_gear_edit_cap` (Task 4). `_make_full_mag_btn(path, desc)` — новая сигнатура (Task 4) и её единственный вызов в `_make_gear_action_row` (Task 4) совпадают, старый вызов с `compact` удалён.
- **Порядок:** Task 4 правит те же `_make_item_cell`/`_place_into`, что и план gear/header (Task 2) — тот план обязан быть завершён первым.
