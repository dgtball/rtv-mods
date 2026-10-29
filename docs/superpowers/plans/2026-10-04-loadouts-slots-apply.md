# Вкладка сетов: слоты и Apply — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Редактор сетов начинает явно раскладывать предметы по слотам, показывает в ячейке, куда предмет попадёт, и применение сета запускается кнопкой «Применить» на карточке.

**Architecture:** Чистая логика раскладки выносится в новый `VTKDraft.gd` без `load()` и без путей внутрь игры — слоты передаются снаружи уже вычитанными из ресурса. Так черновик полностью тестируется headless. `VTKData.gd` получает одну функцию массовой записи `replace_set()`. `VTKUI.gd` перестаёт держать плоский `_items` и строит UI поверх черновика.

**Tech Stack:** Godot 4.6.3, GDScript, `.check/check.ps1` как стенд парсинга, `godot --headless --script` как тест-раннер.

## Global Constraints

- Отступы в `.gd` — **только табы**. Пробелы в отступах недопустимы.
- Файлы в UTF-8. PowerShell-консоль кириллицу искажает — проверять байтами или UTF-8 отчётом, не глазами.
- Функция локализации — `Loc.txt()`, **не** `tr()`: `Object.tr()` перекрывать нельзя.
- Ключ словаря `Loc` — английская строка. Новая строка UI = новая запись в `RU` **того же прохода**.
- Строка с кавычками пишется в одинарных кавычках: `'Loadout "'`.
- **`OptionButton` не использовать** — в 4.1.2 его попап показывал один пункт вместо двух при корректных данных. Для выбора — кнопки.
- `loadouts/mod.txt` — одна строка, без BOM и переводов строк.
- Не вызывать `Grid.ClearGrid()` и `interface.Reset()`.
- Готовый продукт — `Loadouts.vmz`; исходники только в `loadouts/`.
- Ассеты именуются префиксом `VTK`; `.check/` и `docs/` в пакет не попадают.
- Версия: minor-подъём, формат сохранённых данных не меняется. Финальная — `4.2.0`.

## File Structure

| Файл | Ответственность |
|---|---|
| `loadouts/mods/VTK/VTKDraft.gd` | **Создать.** Черновик сета: `name`, `equip`, `gear`. Чистая логика, без `load()`. Полностью тестируется headless. |
| `loadouts/mods/VTK/VTKData.gd` | **Изменить.** Добавить `replace_set()`. Остальное не трогать. |
| `loadouts/mods/VTK/VTKUI.gd` | **Изменить.** Вкладка сетов: ячейка показывает назначение, редактор — две секции, список — карточки с «Применить». |
| `loadouts/mods/VTK/VTKLoc.gd` | **Изменить.** RU-переводы новых строк. |
| `.check/project/tests/test_draft.gd` | **Создать.** Headless-тесты черновика и `replace_set`. |
| `.check/check.ps1` | **Изменить.** После парсинга гонять тесты. |

Существующие в `VTKData` функции `set_equip_item`, `add_gear_item`, `remove_gear_item`, `set_gear_amount`, `create_empty` в этом слайсе **не используются** — черновик собирает всё сам и пишет одним вызовом. Удалять их нельзя (вне области), отметить как кандидатов на чистку позже.

---

### Task 1: Черновик сета и headless-тесты

**Files:**
- Create: `loadouts/mods/VTK/VTKDraft.gd`
- Create: `.check/project/tests/test_draft.gd`
- Modify: `.check/check.ps1:70-76`

**Interfaces:**
- Consumes: ничего.
- Produces:
  - `VTKDraft.new(p_name := "", p_equip := {}, p_gear := []) -> VTKDraft`
  - `static VTKDraft.slot_of(slots) -> String` — первый слот или `""`
  - `static VTKDraft.slot_label(slots) -> String` — все слоты через `", "`, или `""`
  - `add(path: String, item_name: String, slots, amount: float, type_name: String) -> String` — возвращает занятый слот или `""`
  - `equip_slot_of(path: String) -> String`
  - `gear_index_of(path: String) -> int`
  - `has_path(path: String) -> bool`
  - `amount_of(path: String) -> float`
  - `remove_slot(slot: String) -> void`
  - `remove_gear(path: String) -> void`
  - `set_gear_amount(path: String, amount: float) -> void`
  - `descriptor_of(path: String) -> Dictionary`
  - `set_attachments(path: String, atts: Array) -> void`
  - `clear() -> void`, `is_empty() -> bool`, `equip_count() -> int`, `item_count() -> int`
  - `to_saved() -> Dictionary` → `{"equip": …, "gear": …}`
  - `load_from(ld) -> void`
  - поля: `set_name: String`, `equip: Dictionary`, `gear: Array`

- [ ] **Step 1: Создать `.check/project/tests/test_draft.gd` с падающим тестом**

```gdscript
extends SceneTree

const Draft = preload("res://mods/VTK/VTKDraft.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _init() -> void:
	t_slot_of()
	t_slot_label()
	t_gear_increments()
	t_equip_replaces()
	t_remove_scoped()
	t_attachments()
	t_to_saved_and_back()
	print("")
	if fails == 0:
		print("Draft tests passed")
		quit(0)
	else:
		print("Draft tests failed: ", fails)
		quit(1)

func t_slot_of() -> void:
	ck(Draft.slot_of(["Primary", "Secondary"]) == "Primary", "slot_of берёт первый")
	ck(Draft.slot_of([]) == "", "slot_of пустого массива пустой")
	ck(Draft.slot_of(null) == "", "slot_of null пустой")

func t_slot_label() -> void:
	ck(Draft.slot_label(["Primary", "Secondary"]) == "Primary, Secondary", "slot_label через запятую")
	ck(Draft.slot_label([]) == "", "slot_label пустого массива пустой")

func t_gear_increments() -> void:
	var d = Draft.new()
	var s := d.add("res://a.tres", "Аптечка", [], 1.0, "Medical")
	ck(s == "", "без слотов слот пустой")
	ck(d.gear.size() == 1, "без слотов предмет уходит в gear")
	ck(d.equip.is_empty(), "без слотов equip пуст")
	d.add("res://a.tres", "Аптечка", [], 1.0, "Medical")
	ck(d.gear.size() == 1, "повторный клик не плодит записи")
	ck(d.amount_of("res://a.tres") == 2.0, "повторный клик даёт +1")

func t_equip_replaces() -> void:
	var d = Draft.new()
	d.add("res://v1.tres", "АК-74М", ["Primary"], 1.0, "Weapon")
	d.add("res://v2.tres", "АК-74ММ", ["Primary", "Secondary"], 1.0, "Weapon")
	ck(d.equip.size() == 1, "второе оружие заменяет первое в том же слоте")
	ck(d.equip.has("Primary"), "слот Primary занят")
	ck(d.equip["Primary"]["path"] == "res://v2.tres", "в слоте лежит второй предмет")
	ck(d.gear.is_empty(), "оружие не попадает в gear")

func t_remove_scoped() -> void:
	var d = Draft.new()
	d.add("res://v.tres", "АК", ["Primary"], 1.0, "Weapon")
	d.add("res://a.tres", "Аптечка", [], 1.0, "Medical")
	d.remove_slot("Primary")
	ck(d.equip.is_empty(), "remove_slot чистит только слот")
	ck(d.gear.size() == 1, "remove_slot не трогает gear")
	d.remove_gear("res://a.tres")
	ck(d.gear.is_empty(), "remove_gear чистит только gear")

func t_attachments() -> void:
	var d = Draft.new()
	d.add("res://v.tres", "АК", ["Primary"], 1.0, "Weapon")
	d.set_attachments("res://v.tres", ["res://att.tres"])
	ck(d.descriptor_of("res://v.tres").get("attachments", []).size() == 1, "вложение записано в дескриптор")

func t_to_saved_and_back() -> void:
	var d = Draft.new("Стрелок")
	d.add("res://v.tres", "АК", ["Primary"], 1.0, "Weapon")
	d.add("res://a.tres", "Аптечка", [], 2.0, "Medical")
	var saved: Dictionary = d.to_saved()
	ck(saved["equip"].size() == 1, "to_saved: один слот")
	ck(saved["gear"].size() == 1, "to_saved: одна запись gear")
	var d2 = Draft.new()
	d2.load_from({"name": "Стрелок", "equip": saved["equip"], "gear": saved["gear"]})
	ck(d2.set_name == "Стрелок", "load_from читает имя")
	ck(d2.item_count() == 2, "load_from восстанавливает состав")
```

- [ ] **Step 2: Прогнать тест и убедиться, что он падает**

Run:
```powershell
& "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe" --headless --path "D:\RTVMOD\.check\project" --import
& "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe" --headless --path "D:\RTVMOD\.check\project" --script res://tests/test_draft.gd
```
Expected: ошибка загрузки `res://mods/VTK/VTKDraft.gd` — файла ещё нет.

- [ ] **Step 3: Создать `loadouts/mods/VTK/VTKDraft.gd`**

```gdscript
extends RefCounted

# Черновик сета. Чистая логика: ни load(), ни путей внутрь игры.
# Слоты приходят снаружи уже вычитанными из ресурса предмета — поэтому черновик
# тестируется headless, без копии игры.

var set_name: String = ""
var equip: Dictionary = {}
var gear: Array = []

func _init(p_name: String = "", p_equip: Dictionary = {}, p_gear: Array = []) -> void:
	set_name = p_name
	equip = p_equip.duplicate(true)
	gear = p_gear.duplicate(true)

static func slot_of(slots) -> String:
	if typeof(slots) != TYPE_ARRAY or slots.size() == 0:
		return ""
	return str(slots[0])

static func slot_label(slots) -> String:
	if typeof(slots) != TYPE_ARRAY:
		return ""
	var names := []
	for s in slots:
		names.append(str(s))
	return ", ".join(names)

static func _desc(path: String, item_name: String, amount: float, type_name: String) -> Dictionary:
	return {"name": item_name, "path": path, "amount": amount, "type": type_name}

func add(path: String, item_name: String, slots, amount: float, type_name: String) -> String:
	var slot := slot_of(slots)
	if slot != "":
		equip[slot] = _desc(path, item_name, amount, type_name)
		return slot
	var idx := gear_index_of(path)
	if idx >= 0:
		gear[idx]["amount"] = float(gear[idx].get("amount", 1.0)) + 1.0
		return ""
	gear.append(_desc(path, item_name, amount, type_name))
	return ""

func equip_slot_of(path: String) -> String:
	for k in equip.keys():
		if typeof(equip[k]) == TYPE_DICTIONARY and str(equip[k].get("path")) == path:
			return str(k)
	return ""

func gear_index_of(path: String) -> int:
	for i in range(gear.size()):
		if typeof(gear[i]) == TYPE_DICTIONARY and str(gear[i].get("path")) == path:
			return i
	return -1

func has_path(path: String) -> bool:
	if equip_slot_of(path) != "":
		return true
	return gear_index_of(path) >= 0

func amount_of(path: String) -> float:
	var slot := equip_slot_of(path)
	if slot != "":
		return float(equip[slot].get("amount", 1.0))
	var idx := gear_index_of(path)
	if idx >= 0:
		return float(gear[idx].get("amount", 1.0))
	return 0.0

func descriptor_of(path: String) -> Dictionary:
	var slot := equip_slot_of(path)
	if slot != "":
		return equip[slot]
	var idx := gear_index_of(path)
	if idx >= 0:
		return gear[idx]
	return {}

func set_attachments(path: String, atts: Array) -> void:
	var d := descriptor_of(path)
	if not d.is_empty():
		d["attachments"] = atts.duplicate(true)

func remove_slot(slot: String) -> void:
	equip.erase(slot)

func remove_gear(path: String) -> void:
	var idx := gear_index_of(path)
	if idx >= 0:
		gear.remove_at(idx)

func set_gear_amount(path: String, amount: float) -> void:
	var idx := gear_index_of(path)
	if idx >= 0:
		gear[idx]["amount"] = maxf(0.0, amount)

func clear() -> void:
	equip.clear()
	gear.clear()

func is_empty() -> bool:
	return equip.is_empty() and gear.is_empty()

func equip_count() -> int:
	return equip.size()

func item_count() -> int:
	return equip.size() + gear.size()

func to_saved() -> Dictionary:
	return {"equip": equip.duplicate(true), "gear": gear.duplicate(true)}

func load_from(ld) -> void:
	if typeof(ld) != TYPE_DICTIONARY:
		return
	set_name = str(ld.get("name", ""))
	var eq = ld.get("equip")
	equip = eq.duplicate(true) if typeof(eq) == TYPE_DICTIONARY else {}
	var gr = ld.get("gear")
	gear = gr.duplicate(true) if typeof(gr) == TYPE_ARRAY else []
```

- [ ] **Step 4: Прогнать тест — должен пройти**

Run:
```powershell
& "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe" --headless --path "D:\RTVMOD\.check\project" --import
& "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe" --headless --path "D:\RTVMOD\.check\project" --script res://tests/test_draft.gd
```
Expected: все строки `ok`, последняя — `Draft tests passed`, код выхода 0.

- [ ] **Step 5: Встроить тесты в `check.ps1`**

Заменить блок с 70-й строки:
```powershell
Write-Host ""
if ($fail -eq 0) {
    Write-Host "Parse check passed: $($scripts.Count) scripts"
} else {
    Write-Warning "Parse check failed: $fail of $($scripts.Count) scripts"
    exit 1
}
```
на:
```powershell
Write-Host ""
if ($fail -ne 0) {
    Write-Warning "Parse check failed: $fail of $($scripts.Count) scripts"
    exit 1
}

Write-Host "Parse check passed: $($scripts.Count) scripts"
Write-Host "--- draft tests ---"
$tout = & $Godot --headless --path $proj --script "res://tests/test_draft.gd" 2>&1 | Out-String
Write-Host $tout.Trim()
if (($LASTEXITCODE -ne 0) -or ($tout -match "FAIL")) {
    Write-Warning "Draft tests failed"
    exit 1
}
Write-Host "Draft tests passed"
```

- [ ] **Step 6: Прогнать полный стенд**

Run:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\RTVMOD\.check\check.ps1" -Godot "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe"
```
Expected: `ok` на 8 скриптах (7 прежних + `VTKDraft.gd`), `Parse check passed: 8 scripts`, затем `Draft tests passed`.

Коммита нет — репозиторий не под git.

---

### Task 2: Массовая запись сета в VTKData

**Files:**
- Modify: `loadouts/mods/VTK/VTKData.gd:239` (рядом с `set_gear_amount`)
- Modify: `.check/project/tests/test_draft.gd`

**Interfaces:**
- Consumes: `VTKDraft.to_saved()` из Task 1.
- Produces: `VTKData.replace_set(set_name: String, equip_dict: Dictionary, gear_list: Array) -> void`

- [ ] **Step 1: Добавить падающий тест в `test_draft.gd`**

В начало `const`-блока добавить:
```gdscript
const Data = preload("res://mods/VTK/VTKData.gd")
```
В `_init()` добавить вызов `t_replace_set()` перед `print("")`:
```gdscript
	t_replace_set()
```
И добавить функцию:
```gdscript
func t_replace_set() -> void:
	var n := "ZZ_test_replace_set"
	Data.replace_set(n, {"Primary": {"name": "АК", "path": "res://v.tres", "amount": 1.0, "type": "Weapon"}}, [])
	var back := Data.get_set(n)
	ck(back.size() > 0, "replace_set создал сет")
	ck(typeof(back.get("equip")) == TYPE_DICTIONARY and back["equip"].has("Primary"), "replace_set записал equip")
	Data.replace_set(n, {}, [{"name": "Аптечка", "path": "res://a.tres", "amount": 3.0, "type": "Medical"}])
	back = Data.get_set(n)
	ck(back["equip"].is_empty(), "повторный replace_set переписал equip")
	ck(back["gear"].size() == 1, "повторный replace_set записал gear")
	ck(int(back["gear"][0]["amount"]) == 3, "количество gear сохранилось")
	Data.remove(n)
	ck(Data.get_set(n).is_empty(), "remove убрал тестовый сет")
```

- [ ] **Step 2: Прогнать — должен упасть**

Run:
```powershell
& "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe" --headless --path "D:\RTVMOD\.check\project" --import
& "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe" --headless --path "D:\RTVMOD\.check\project" --script res://tests/test_draft.gd
```
Expected: ошибка `Invalid call. Nonexistent function 'replace_set'`.

- [ ] **Step 3: Добавить `replace_set` в `VTKData.gd`**

После `set_gear_amount` (конец функции на строке 255):
```gdscript

static func replace_set(set_name: String, equip_dict: Dictionary, gear_list: Array) -> void:
	var all = get_all()
	var found := false
	for i in range(all.size()):
		if typeof(all[i]) != TYPE_DICTIONARY or str(all[i].get("name")) != set_name:
			continue
		var n := _norm(all[i])
		n["equip"] = equip_dict.duplicate(true)
		n["gear"] = gear_list.duplicate(true)
		all[i] = n
		found = true
		break
	if not found:
		all.append({
			"name": set_name,
			"quick_key": 0,
			"equip": equip_dict.duplicate(true),
			"gear": gear_list.duplicate(true),
		})
	save_all(all)
```

- [ ] **Step 4: Прогнать полный стенд**

Run:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\RTVMOD\.check\check.ps1" -Godot "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe"
```
Expected: `Parse check passed: 8 scripts`, `Draft tests passed`, все строки `ok`.

Коммита нет.

---

### Task 3: Ячейка сетки показывает назначение

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd:1-2` (константы и переменные)
- Modify: `loadouts/mods/VTK/VTKUI.gd:639-703` (`_make_item_cell`)
- Modify: `loadouts/mods/VTK/VTKUI.gd:705-721` (`_add_item_from_grid`)
- Modify: `loadouts/mods/VTK/VTKLoc.gd`

**Interfaces:**
- Consumes: `VTKDraft` из Task 1.
- Produces: поле `_draft: VTKDraft`, функция `_item_slots(item) -> Array`, ячейка показывает подпись назначения и золотую рамку.

- [ ] **Step 1: Добавить константу и поле**

Рядом с другими `const` в начале файла добавить:
```gdscript
const Draft = preload("res://mods/VTK/VTKDraft.gd")
```

Рядом с `var _items: Array = []` добавить:
```gdscript
var _draft: Draft = null
```

- [ ] **Step 2: Добавить хелпер чтения слотов**

После `_make_item_cell` (перед `_add_item_from_grid`) добавить:
```gdscript
func _item_slots(item) -> Array:
	if item == null:
		return []
	var slots = item.get("slots")
	if typeof(slots) != TYPE_ARRAY:
		return []
	return slots
```

- [ ] **Step 3: В `_make_item_cell` добавить подпись и рамку**

Сразу после блока `cell.add_theme_stylebox_override("panel", normal_style)` добавить вторую рамку:
```gdscript
	var in_set_style := StyleBoxFlat.new()
	in_set_style.bg_color = Color("#1a1510")
	in_set_style.border_color = _gold
	in_set_style.border_width_all = 1
	in_set_style.corner_radius_all = 4
```

Сразу после добавления `name_lbl` в `vbox` добавить подпись назначения и счётчик:
```gdscript
	var slots := _item_slots(item)
	var slot_txt := Draft.slot_label(slots)
	var dest = Label.new()
	dest.text = slot_txt if slot_txt != "" else Loc.txt("gear")
	dest.add_theme_font_size_override("font_size", 7)
	dest.add_theme_color_override("font_color", Color("#8a7a60"))
	dest.autowrap_mode = TextServer.AUTOWRAP_WORD
	dest.max_lines_visible = 2
	dest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(dest)

	var path_now: String = item.resource_path
	var already := _draft != null and _draft.has_path(path_now)
	if already:
		var cur_slot := _draft.equip_slot_of(path_now)
		if cur_slot == "":
			var n := int(_draft.amount_of(path_now))
			if n > 1:
				var cnt = Label.new()
				cnt.text = "×" + str(n)
				cnt.add_theme_font_size_override("font_size", 8)
				cnt.add_theme_color_override("font_color", _gold)
				cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
				vbox.add_child(cnt)
		cell.add_theme_stylebox_override("panel", in_set_style)
```

Строку `cell.add_theme_stylebox_override("panel", normal_style)` внутри обработчика `mouse_exited` оставить — при уходе мыши рамка должна возвращаться в обычную. Обработчик `mouse_entered` заменить на:
```gdscript
	cell.mouse_entered.connect(func():
		var base_style := in_set_style if already else hover_style
		cell.add_theme_stylebox_override("panel", base_style)
	)
```

- [ ] **Step 4: Переписать `_add_item_from_grid`**

Заменить тело функции на:
```gdscript
func _add_item_from_grid(item, type_name: String) -> void:
	if _draft == null:
		return
	var path: String = item.resource_path
	var amt := 1.0
	var res = load(path)
	var slots: Array = []
	if res != null:
		var t = res.get("type")
		if t != "Weapon" and t != "Ammo":
			var maxAm = res.get("maxAmount")
			if maxAm != null and maxAm > 1:
				amt = float(maxAm)
		slots = _item_slots(res)
	_draft.add(path, item.name, slots, amt, type_name)
	_refresh_draft_ui()
	_populate_item_grid()
```

- [ ] **Step 5: Добавить перевод `gear` в `VTKLoc.gd`**

В словарь `RU` добавить запись:
```gdscript
	'gear': 'снаряжение',
```

- [ ] **Step 6: Прогнать стенд парсинга**

Run:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\RTVMOD\.check\check.ps1" -Godot "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe"
```
Expected: `Parse check passed: 8 scripts`, `Draft tests passed`.

Замечание: `_refresh_draft_ui` появится в Task 4. До этого вызова в игре не будет — это ожидаемо, Task 3 проверяется только парсингом; вручную в игре на этом шаге ничего проверять нельзя.

Коммита нет.

---

### Task 4: Редактор из двух секций поверх черновика

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd:403-478` (`_build_editor`)
- Modify: `loadouts/mods/VTK/VTKUI.gd:731-856` (панель вложений, перевод на `_open_att_path`)
- Modify: `loadouts/mods/VTK/VTKUI.gd:1054-1070` (`_save_loadout`)
- Modify: `loadouts/mods/VTK/VTKUI.gd` (переменные `_equip_box`, `_gear_box`, `_open_att_path`, удаление `_items`)
- Modify: `loadouts/mods/VTK/VTKLoc.gd`

**Interfaces:**
- Consumes: `VTKDraft` (Task 1), `VTKData.replace_set` (Task 2).
- Produces: `_refresh_draft_ui() -> void`, `_start_new_draft() -> void`, поля `_equip_box`, `_gear_box`, `_open_att_path`.

- [ ] **Step 1: Заменить переменные**

Удалить `var _items: Array = []`, `var _items_container: VBoxContainer = null`, `var _open_att_panel: int = -1`.
Добавить:
```gdscript
var _equip_box: VBoxContainer = null
var _gear_box: VBoxContainer = null
var _open_att_path: String = ""
```

- [ ] **Step 2: Переписать `_build_editor`**

Вместо одного `_items_container` и плоского заголовка — две секции. Ключевая часть, начиная с `var items_title = Label.new()` (строка 458) и до конца функции:
```gdscript
	var eq_title = Label.new()
	eq_title.text = Loc.txt("Equipment")
	eq_title.add_theme_font_size_override("font_size", 12)
	eq_title.add_theme_color_override("font_color", _gold)
	_editor_panel.add_child(eq_title)

	_equip_box = VBoxContainer.new()
	_equip_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor_panel.add_child(_equip_box)

	var gear_title = Label.new()
	gear_title.text = Loc.txt("Gear")
	gear_title.add_theme_font_size_override("font_size", 12)
	gear_title.add_theme_color_override("font_color", _gold)
	_editor_panel.add_child(gear_title)

	_gear_box = VBoxContainer.new()
	_gear_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor_panel.add_child(_gear_box)

	var action_row = HBoxContainer.new()
	action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var save_btn = Button.new()
	save_btn.text = Loc.txt("Save loadout")
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_btn.pressed.connect(_save_loadout)
	action_row.add_child(save_btn)
	var clear_btn = Button.new()
	clear_btn.text = Loc.txt("Clear")
	clear_btn.pressed.connect(_clear_draft)
	action_row.add_child(clear_btn)
	var cancel_btn = Button.new()
	cancel_btn.text = Loc.txt("Cancel")
	cancel_btn.pressed.connect(_cancel_draft)
	action_row.add_child(cancel_btn)
	_editor_panel.add_child(action_row)
```

Заголовок редактора (строки 408-415) оставить, но текст брать из черновика:
```gdscript
	var ed_title = Label.new()
	if _draft != null and _draft.set_name != "":
		ed_title.text = Loc.txt("Editing: ") + _draft.set_name
	else:
		ed_title.text = Loc.txt("Create new loadout")
```

Поле `_name_input` больше не нужно — имя задаётся в `_start_new_draft()`. Удалить блок `name_row` (строки 417-434).

- [ ] **Step 3: Добавить `_refresh_draft_ui`**

```gdscript
func _refresh_draft_ui() -> void:
	if _equip_box == null or _gear_box == null:
		return
	for c in _equip_box.get_children():
		_equip_box.remove_child(c)
		c.queue_free()
	for c in _gear_box.get_children():
		_gear_box.remove_child(c)
		c.queue_free()
	if _draft == null:
		return

	if _draft.equip.is_empty():
		var e = Label.new()
		e.text = Loc.txt("No equipment")
		e.add_theme_color_override("font_color", Color("#555"))
		_equip_box.add_child(e)
	else:
		for slot in _draft.equip.keys():
			var d: Dictionary = _draft.equip[slot]
			var row = HBoxContainer.new()
			row.custom_minimum_size = Vector2(0, 22)
			var tag = Label.new()
			tag.text = str(slot)
			tag.custom_minimum_size = Vector2(90, 0)
			tag.add_theme_font_size_override("font_size", 10)
			tag.add_theme_color_override("font_color", _gold)
			row.add_child(tag)
			var nm = Label.new()
			nm.text = str(d.get("name", "?"))
			nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nm.add_theme_font_size_override("font_size", 10)
			row.add_child(nm)
			var amt := int(float(d.get("amount", 1.0)))
			if amt > 1:
				var q = Label.new()
				q.text = "x" + str(amt)
				q.add_theme_font_size_override("font_size", 9)
				q.add_theme_color_override("font_color", Color("#666"))
				row.add_child(q)
			if _has_compat(d):
				row.add_child(_make_att_btn(d))
			var slot_name := str(slot)
			var rm = Button.new()
			rm.text = "✕"
			rm.custom_minimum_size = Vector2(18, 18)
			rm.pressed.connect(func(): _draft.remove_slot(slot_name); _refresh_draft_ui(); _populate_item_grid())
			row.add_child(rm)
			_equip_box.add_child(row)
			if _open_att_path == str(d.get("path", "")):
				var ap := _build_attachment_panel(d)
				if ap != null:
					_equip_box.add_child(ap)

	if _draft.gear.is_empty():
		var g = Label.new()
		g.text = Loc.txt("No gear")
		g.add_theme_color_override("font_color", Color("#555"))
		_gear_box.add_child(g)
	else:
		for d in _draft.gear:
			var row2 = HBoxContainer.new()
			row2.custom_minimum_size = Vector2(0, 22)
			var nm2 = Label.new()
			nm2.text = str(d.get("name", "?"))
			nm2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nm2.add_theme_font_size_override("font_size", 10)
			row2.add_child(nm2)
			var minus = Button.new()
			minus.text = "−"
			minus.custom_minimum_size = Vector2(18, 18)
			var plus = Button.new()
			plus.text = "+"
			plus.custom_minimum_size = Vector2(18, 18)
			var cur_path := str(d.get("path", ""))
			minus.pressed.connect(func(): _bump_gear(cur_path, -1.0))
			plus.pressed.connect(func(): _bump_gear(cur_path, 1.0))
			row2.add_child(minus)
			var q2 = Label.new()
			q2.text = str(int(float(d.get("amount", 1.0))))
			q2.custom_minimum_size = Vector2(38, 0)
			q2.add_theme_font_size_override("font_size", 10)
			row2.add_child(q2)
			row2.add_child(plus)
			if _has_compat(d):
				row2.add_child(_make_att_btn(d))
			var rm2 = Button.new()
			rm2.text = "✕"
			rm2.custom_minimum_size = Vector2(18, 18)
			rm2.pressed.connect(func(): _draft.remove_gear(cur_path); _refresh_draft_ui(); _populate_item_grid())
			row2.add_child(rm2)
			_gear_box.add_child(row2)
			if _open_att_path == str(d.get("path", "")):
				var ap2 := _build_attachment_panel(d)
				if ap2 != null:
					_gear_box.add_child(ap2)

func _has_compat(desc) -> bool:
	if typeof(desc) != TYPE_DICTIONARY:
		return false
	var res = load(str(desc.get("path", "")))
	if res == null:
		return false
	var c = res.get("compatible")
	return c is Array and c.size() > 0

func _make_att_btn(desc) -> Button:
	var path_now := str(desc.get("path", ""))
	var atts = desc.get("attachments") if desc.has("attachments") else []
	var b := Button.new()
	b.text = Loc.txt(" rnd.") + str(atts.size()) + " "
	b.custom_minimum_size = Vector2(0, 18)
	b.add_theme_font_size_override("font_size", 8)
	if atts.size() > 0:
		b.add_theme_color_override("font_color", _gold)
	b.pressed.connect(func(): _toggle_attachment_panel(path_now))
	return b

func _bump_gear(path: String, delta: float) -> void:
	if _draft == null:
		return
	_draft.set_gear_amount(path, _draft.amount_of(path) + delta)
	_refresh_draft_ui()
	_populate_item_grid()

func _toggle_attachment_panel(path: String) -> void:
	if _open_att_path == path:
		_open_att_path = ""
	else:
		_open_att_path = path
	_refresh_draft_ui()
```

- [ ] **Step 4: Перевести `_build_attachment_panel` и `_connect_att_cb` на дескриптор черновика**

В `_build_attachment_panel(item)` все записи вложений заменить на запись в дескриптор. Внутри функции найти место, где чекбоксы пишут выбранные вложения (бывший `_items[idx]["attachments"] = ...`), и заменить вызов на:
```gdscript
	if _draft != null:
		_draft.set_attachments(str(item.get("path", "")), chosen)
```

- [ ] **Step 5: Переписать `_save_loadout` и добавить функции черновика**

```gdscript
func _start_new_draft() -> void:
	_draft = Draft.new()
	_open_att_path = ""
	_build_editor()

func _cancel_draft() -> void:
	_draft = null
	_open_att_path = ""
	_build_editor()
	_refresh_loadout_list()

func _clear_draft() -> void:
	if _draft == null:
		return
	_draft.clear()
	_refresh_draft_ui()
	_populate_item_grid()

func _save_loadout() -> void:
	if _draft == null:
		return
	var name_new := _draft.set_name.strip_edges()
	if name_new == "":
		return
	if _draft.item_count() == 0:
		return
	var LD = preload("res://mods/VTK/VTKData.gd")
	var all = LD.get_all()
	for ld in all:
		if str(ld.get("name")) == name_new and name_new != _editing_name:
			return
	if _editing_name != "" and _editing_name != name_new:
		LD.remove(_editing_name)
	LD.replace_set(name_new, _draft.equip, _draft.gear)
	_draft.set_name = name_new
	_editing_name = name_new
	_refresh_loadout_list()
```

- [ ] **Step 6: Добавить переводы**

В `RU` добавить:
```gdscript
	'Equipment': 'Экипировка',
	'Gear': 'Снаряжение',
	'No equipment': 'Экипировка пуста',
	'No gear': 'Снаряжение пусто',
	'Cancel': 'Отмена',
```

- [ ] **Step 7: Удалить мёртвый код**

Удалить `_refresh_items_ui`, `_remove_item`, `_reset_editor`, `_clear_items`, а также все обращения к `_items` и `_items_container` по всему файлу. Проверить, что `_reset_editor` и `_clear_items` больше нигде не вызываются:
Run:
```powershell
Select-String -Path "D:\RTVMOD\loadouts\mods\VTK\VTKUI.gd" -Pattern "_items|_items_container|_reset_editor|_clear_items|_open_att_panel"
```
Expected: пустой вывод.

- [ ] **Step 8: Прогнать стенд парсинга**

Run:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\RTVMOD\.check\check.ps1" -Godot "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe"
```
Expected: `Parse check passed: 8 scripts`, `Draft tests passed`.

Коммита нет.

---

### Task 5: Карточки сетов и кнопка «Применить»

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd:480-552` (`_refresh_loadout_list`)
- Modify: `loadouts/mods/VTK/VTKUI.gd:378-401` (`_build_loadouts_tab`)
- Modify: `loadouts/mods/VTK/VTKUI.gd:1076-1086` (`_edit_loadout`)
- Modify: `loadouts/mods/VTK/VTKLoc.gd`

**Interfaces:**
- Consumes: черновик из Task 4, `VTKData.get_all`, `VTKData.item_count`.
- Produces: карточки вместо плоских строк, кнопка «Применить» → `VTKData.load_loadout(name)`.

- [ ] **Step 1: Переписать `_refresh_loadout_list`**

```gdscript
func _refresh_loadout_list() -> void:
	for child in _list_container.get_children():
		_list_container.remove_child(child)
		child.queue_free()

	var LD = preload("res://mods/VTK/VTKData.gd")
	var loadouts = LD.get_all()
	if loadouts.is_empty():
		var empty = Label.new()
		empty.text = Loc.txt("No saved loadouts")
		empty.add_theme_color_override("font_color", Color("#666"))
		_list_container.add_child(empty)
		return

	for ld in loadouts:
		if typeof(ld) != TYPE_DICTIONARY:
			continue
		var nm := str(ld.get("name", ""))
		var pack: Dictionary = LD.get_set(nm)

		var card = Panel.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cs := StyleBoxFlat.new()
		cs.bg_color = Color("#1a1510")
		cs.border_color = Color("#2a1f14")
		cs.border_width_all = 1
		cs.corner_radius_all = 4
		card.add_theme_stylebox_override("panel", cs)

		var box = VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_child(box)

		var top = HBoxContainer.new()
		top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var qk = int(ld.get("quick_key", 0))
		var qk_btn = Button.new()
		qk_btn.custom_minimum_size = Vector2(22, 18)
		qk_btn.add_theme_font_size_override("font_size", 8)
		if qk > 0:
			qk_btn.text = _keycode_to_string(qk)
			qk_btn.add_theme_color_override("font_color", _gold)
		else:
			qk_btn.text = "?"
			qk_btn.add_theme_color_override("font_color", Color("#444"))
		qk_btn.pressed.connect(func(): _cycle_quick_key_789(nm))
		top.add_child(qk_btn)

		var titles = VBoxContainer.new()
		titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_lbl = Label.new()
		name_lbl.text = nm
		name_lbl.add_theme_font_size_override("font_size", 11)
		titles.add_child(name_lbl)
		var eq_d: Dictionary = pack.get("equip", {})
		var gr_a: Array = pack.get("gear", [])
		var meta = Label.new()
		meta.text = Loc.txt(" items · ") + str(eq_d.size() + gr_a.size()) + Loc.txt(" in equipment")
		meta.add_theme_font_size_override("font_size", 8)
		meta.add_theme_color_override("font_color", Color("#666"))
		titles.add_child(meta)
		top.add_child(titles)
		box.add_child(top)

		var chips = HBoxContainer.new()
		chips.add_theme_constant_override("separation", 3)
		var shown := 0
		for slot in eq_d.keys():
			if shown >= 4:
				var more = Label.new()
				more.text = "+" + str(eq_d.size() - 4)
				more.add_theme_font_size_override("font_size", 8)
				more.add_theme_color_override("font_color", _gold)
				chips.add_child(more)
				break
			var ch = Label.new()
			ch.text = str(slot)
			ch.add_theme_font_size_override("font_size", 8)
			ch.add_theme_color_override("font_color", Color("#8a7a60"))
			chips.add_child(ch)
			shown += 1
		box.add_child(chips)

		var foot = HBoxContainer.new()
		foot.add_theme_constant_override("separation", 4)
		var apply_btn = Button.new()
		apply_btn.text = Loc.txt("Apply")
		apply_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		apply_btn.pressed.connect(func(): LD.load_loadout(nm))
		foot.add_child(apply_btn)
		var edit_btn = Button.new()
		edit_btn.text = Loc.txt("Edit")
		edit_btn.pressed.connect(func(): _edit_loadout(nm))
		foot.add_child(edit_btn)
		var del_btn = Button.new()
		del_btn.text = "✕"
		del_btn.pressed.connect(func(): _delete_loadout(nm))
		foot.add_child(del_btn)
		box.add_child(foot)

		_list_container.add_child(card)

	var ghost = Button.new()
	ghost.text = Loc.txt("+ Create loadout")
	ghost.pressed.connect(_start_new_draft)
	_list_container.add_child(ghost)
```

- [ ] **Step 2: Обновить `_edit_loadout`**

Заменить тело на:
```gdscript
func _edit_loadout(name: String) -> void:
	var LD = preload("res://mods/VTK/VTKData.gd")
	var raw = LD.get_set(name)
	if raw.is_empty():
		return
	var d = Draft.new()
	d.load_from(raw)
	_draft = d
	_editing_name = name
	_open_att_path = ""
	_build_editor()
```

- [ ] **Step 3: Проверить, что кнопка `Inventory` убрана**

Кнопки `spawn_loadout` в карточках больше нет — она вызывалась только из `_refresh_loadout_list`, который переписан. Функция `VTKData.spawn_loadout` остаётся в `VTKData` как используемая хоткеем.
Run:
```powershell
Select-String -Path "D:\RTVMOD\loadouts\mods\VTK\VTKUI.gd" -Pattern "spawn_loadout"
```
Expected: пустой вывод.

- [ ] **Step 4: Обновить подсказку над списком**

В `_build_loadouts_tab` заменить строку подсказки на:
```gdscript
	hint.text = Loc.txt("□ or ? — assign a quick key 7/8/9")
```

- [ ] **Step 5: Добавить переводы**

В `RU` добавить:
```gdscript
	'Apply': 'Применить',
	'Edit': 'Изменить',
	'+ Create loadout': '+ Создать сет',
	' items · ': ' предметов · ',
	' in equipment': ' в экипировке',
	'□ or ? — assign a quick key 7/8/9': '□ или ? — назначьте клавишу 7/8/9',
```

- [ ] **Step 6: Прогнать стенд парсинга и ключи локализации**

Run:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\RTVMOD\.check\check.ps1" -Godot "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe"
& "C:\Users\home\AppData\Local\hermes\hermes-agent\venv\Scripts\python.exe" "C:\Users\home\AppData\Local\Temp\opencode\keycheck.py"
```
Expected: `Parse check passed: 8 scripts`, `Draft tests passed`, `missing 0`.

Коммита нет.

---

### Task 6: Версия, сборка, развёртывание

**Files:**
- Modify: `loadouts/mod.txt`

**Interfaces:**
- Consumes: всё из Task 1-5.
- Produces: `Loadouts.vmz` версии 4.2.0 в папке модов игры.

- [ ] **Step 1: Поднять версию**

Полностью перезаписать `loadouts/mod.txt` одной строкой (без переводов строк):
```
[mod]name="Vostok Toolkit"id="vostok-toolkit"version="4.2.0"[autoload]VTKUI="res://mods/VTK/VTKUI.gd"
```

- [ ] **Step 2: Проверить, что версия одна строка без BOM**

Run:
```powershell
$b = [System.IO.File]::ReadAllBytes("D:\RTVMOD\loadouts\mod.txt")
"bytes=$($b.Length) newline_count=$(($b | Where-Object { $_ -eq 13 -or $_ -eq 10 }).Count) bom=$($b[0] -eq 0xEF)"
```
Expected: `newline_count=0 bom=False`.

- [ ] **Step 3: Собрать пакет**

Run:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\RTVMOD\pack.ps1"
```
Expected: `Version in mod.txt: 4.2.0` и `Pack done`. В пакете должно быть 9 записей: `mod.txt` плюс 8 скриптов.

- [ ] **Step 4: Развернуть и сверить хэш**

Run:
```powershell
$dst = "D:\SteamLibrary\steamapps\common\Road to Vostok\mods\Loadouts.vmz"
Copy-Item -LiteralPath "D:\RTVMOD\Loadouts.vmz" -Destination $dst -Force
$a = (Get-FileHash -LiteralPath "D:\RTVMOD\Loadouts.vmz" -Algorithm SHA256).Hash
$b = (Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash
"match $($a -eq $b) size $((Get-Item -LiteralPath $dst).Length)"
```
Expected: `match True`.

- [ ] **Step 5: Ручная проверка в игре**

Перезапустить игру и пройти чек-лист из спеки `docs/superpowers/specs/2026-10-04-loadouts-slots-apply-design.md`, раздел «Проверка»:

1. предмет с одним слотом показывает имя слота и попадает в «Экипировку»;
2. предмет без слотов показывает «снаряжение» и попадает в «Снаряжение»;
3. предмет с несколькими слотами показывает их через запятую и кладётся в первый;
4. второй предмет в тот же слот заменяет первый;
5. `✕` в «Экипировке» не трогает «Снаряжение» и наоборот;
6. «Применить» надевает экипировку и раскладывает остальное в инвентарь;
7. после «Применить» чужие предметы в инвентаре остались на месте;
8. карточка показывает верное `N предметов · M в экипировке`;
9. после перезапуска игры предметы из применённого сета на месте;
10. панель вложений у оружия по-прежнему открывается и сохраняется;
11. в логе `godot.log` нет новых `SCRIPT ERROR`.

Коммита нет.

---

## Self-Review

**Покрытие спеки:**

| Требование спеки | Задача |
|---|---|
| Подпись назначения в ячейке | 3 |
| Золотая рамка и счётчик `×N` | 3 |
| Клик: слот или gear, замена, `+1` | 1 (тест), 3 (проводка) |
| Секция «Экипировка» | 4 |
| Секция «Снаряжение» со степперами | 4 |
| Карточки сетов | 5 |
| «Применить» вызывает `load_loadout` | 5 |
| Убрать кнопку `Inventory` | 5, шаг 3 |
| Версия 4.2.0 | 6 |
| Запрет `OptionButton` | Глобальное ограничение, соблюдается во всех задачах |
| Новая строка = новый перевод | 3, 4, 5 |
| Откат | 6 |

**Незакрытое и осознанно:** захват любой клавиши, Shift-семантика, поиск предметов, мультивыбор типов, метка «Синхронизировать», ручной выбор слота для multi-slot предметов — следующий слайс по спецификации.

**Согласованность имён:** `_draft`, `_equip_box`, `_gear_box`, `_open_att_path`, `_refresh_draft_ui`, `_start_new_draft`, `_cancel_draft`, `_clear_draft`, `_bump_gear`, `_has_compat`, `_make_att_btn`, `_item_slots` — определены в задачах 3-5 и нигде не используются до определения. `replace_set` определена в задаче 2 и используется в задаче 4.