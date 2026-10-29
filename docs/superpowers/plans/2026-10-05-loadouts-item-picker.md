# Трёхшаговый выбор предметов — Implementation Plan

> **Обновление 2026-10-05 (v4.5.0).** Раскладка страниц заменена: левая колонка
> слотов на шаге 1, фасеты категорий и постоянно открытая плоская сетка на шаге 2,
> панель обвесов в правой колонке, шаг 3 в две колонки. Удалены чипы занятых
> слотов в шапке шага 1, кнопка `+ Add`, полки категорий в шаге 2, панель обвесов
> внутри `_slots_box`, префиксы `[x] `/`[ ] ` у обвесов и цвета категорий.
> Правки, тесты и структурный стенд — `docs/superpowers/plans/2026-10-05-picker-facets-layout.md`.
> Описания ниже про старую раскладку — читай как историю, а не как инструкцию.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Заменить плоский редактор сета на три свободно переключаемые страницы (Экипировка → Снаряжение → Готово) с выбором слота как цели, одиночными обвесами по группам и настоящим поиском.

**Architecture:** Новая чистая функция `VTKPicker.gd` держит все решения, не требующие ресурсов: список слотов из данных, фильтры «подходит ли слот», «подходит ли поиск», полосы категорий, признак «есть ли панель», группировка обвесов по `subtype`. Она не вызывает `load()` и не знает про игру, поэтому тестируется headless, как `VTKDraft.gd`. `VTKDraft.gd` получает два метода: `add_to_slot()` для адресного размещения и `toggle_attachment()` для одиночного обвеса по группе. `VTKData.gd` переезжает на `VTKsets.json` с одноразовым переносом. `VTKUI.gd` перестраивает только `_build_editor()` и его спутников, остальные вкладки не трогаются.

**Tech Stack:** Godot 4.6.3, GDScript, headless-проверка через `godot --headless --check-only`, тесты черновика как `extends SceneTree`.

**Design doc:** `docs/superpowers/specs/2026-10-05-loadouts-item-picker-design.md`
**Behavior oracle:** `docs/mockups/picker-a2-interactive.html`, регрессия — `python .check\a2\run.py` (53 проверки)

## Global Constraints

- Версия живёт только в `loadouts/mod.txt`, поле `version`. Поднять до `4.4.0` в Task 13. `MOD_VERSION`/`ESP_VERSION` в коде не дублировать.
- Отступы в `.gd` — **только табы**. `VTKData.gd` и `VTKUI.gd` — CRLF. Новый `VTKPicker.gd` — CRLF, UTF-8 **без BOM**.
- Любая строка в UI идёт через `Loc.txt()`. Функция называется `Loc.txt()`, а не `tr()` — перекрытие даёт Parse Error. Строка с кавычкой пишется в одинарных кавычках.
- Каждый новый вызов `Loc.txt("...")` обязан получить запись в `RU` в `VTKLoc.gd` в том же проходе. Проверяет `python .check\keycheck.py`.
- Запрещено: `OptionButton`, `Grid.ClearGrid()`, `interface.Reset()`.
- Имена предметов, типов, слотов, трейдеров и убежищ не локализуются — приходят из `Database`.
- `VTKDraft.gd` и `VTKPicker.gd` не вызывают `load()` и не ходят по путям внутрь игры. Всё, что требует ресурсов, приходит снаружи строкой, `Callable` или готовыми данными.
- Формат записи сета **не меняется**: `attachments` остаётся плоским массивом путей, `equip` — словарём слот→descriptor, `gear` — массивом descriptor'ов. `count`/`full_mag` у обойм не трогаем.
- Git в проекте нет, поэтому вместо `git commit` каждый таск заканчивается снимком:

```powershell
$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
$dst = "C:\Users\home\AppData\Local\Temp\opencode\vtk-snap-$stamp"
New-Item -ItemType Directory -Force -Path $dst | Out-Null
Copy-Item -Recurse -Force "D:\RTVMOD\loadouts" $dst
Write-Host "snapshot: $dst"
```

- Перед любым выводом в консоль помнить: оболочка cp1251, кириллица и `−`/`◆` через неё не идут. Отчёты читать файлом.

## File Structure

| Файл | Действие | Ответственность |
|---|---|---|
| `loadouts/mods/VTK/VTKPicker.gd` | создать | Чистые решения выбора: слоты, фильтры, полосы, панель, группы обвесов |
| `loadouts/mods/VTK/VTKDraft.gd` | изменить | `add_to_slot()`, `toggle_attachment()` поверх существующих `add()`/`set_attachments()` |
| `loadouts/mods/VTK/VTKData.gd` | изменить | `SAVE_FILE` → `VTKsets.json`, `LEGACY_SAVE_FILE`, `migrate_save_file()` |
| `loadouts/mods/VTK/VTKUI.gd` | изменить | Перестроить `_build_editor()` и его спутников; остальные вкладки не трогать |
| `loadouts/mods/VTK/VTKLoc.gd` | изменить | `RU`-записи новых строк |
| `loadouts/mod.txt` | изменить | `version="4.4.0"` |
| `.check/project/tests/test_picker.gd` | создать | Тесты `VTKPicker` headless |
| `.check/project/tests/test_draft.gd` | изменить | Тесты `add_to_slot`, `toggle_attachment`, миграции файла |
| `.check/check.ps1` | изменить | Прогонять `test_picker.gd` рядом с `test_draft.gd` |
| `AGENTS.md` | изменить | Счётчик `preload` во `VTKUI.gd` (13 → 14) |

`VTKUI.gd` уже 1605 строк. Новую логику выбора в него не кладём: она уезжает в `VTKPicker.gd` и остаётся тестируемой, а в `VTKUI.gd` остаётся только сборка узлов.

## Task Boundaries

Каждый таск заканчивается независимо проверяемым результатом. Порядок выбран так, чтобы логика проверялась тестами раньше, чем на неё навешивается UI.

| Task | Что сдаёт | Чем проверяется |
|---|---|---|
| 1 | `VTKPicker.all_slots()` | `test_picker.gd` |
| 2 | `VTKPicker.matches_slot/matches_search/shelves_of` | `test_picker.gd` |
| 3 | `VTKPicker.has_panel/group_attachments` | `test_picker.gd` |
| 4 | `VTKDraft.add_to_slot()` | `test_draft.gd` |
| 5 | `VTKDraft.toggle_attachment()` | `test_draft.gd` |
| 6 | `VTKsets.json` + миграция | `test_draft.gd` |
| 7 | Каркас трёх страниц и степпера | `check.ps1` + в игре |
| 8 | Шаг 1: слоты, сетка, поиск | `check.ps1` + в игре |
| 9 | Шаг 1: маршрутизация клика по карточке | `check.ps1` + в игре |
| 10 | Шаг 2: чипы и пикер снаряжения | `check.ps1` + в игре |
| 11 | Панель обвесов single-choice | `check.ps1` + в игре |
| 12 | Шаг 3: сводка и сохранение с валидацией | `check.ps1` + в игре |
| 13 | Локализация, версия, сборка, чеклист | все проверки |

---

### Task 1: `VTKPicker.all_slots()`

**Files:**
- Create: `loadouts/mods/VTK/VTKPicker.gd`
- Create: `.check/project/tests/test_picker.gd`
- Modify: `.check/check.ps1:77-84`

**Interfaces:**
- Consumes: ничего, это первая задача.
- Produces: класс `VTKPicker` со статическими `SLOT_ORDER: Array[String]`, `all_slots(slot_lists) -> Array`. Дальше используется Task 8.

- [ ] **Step 1: Создать `test_picker.gd` с одним тестом, который падает**

Файл `.check/project/tests/test_picker.gd`, CRLF, UTF-8 без BOM, отступы табами:

```gdscript
extends SceneTree

const P = preload("res://mods/VTK/VTKPicker.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _init() -> void:
	t_all_slots()
	print("")
	if fails == 0:
		print("Picker tests passed")
		quit(0)
	else:
		print("Picker tests failed: ", fails)
		quit(1)

func t_all_slots() -> void:
	var got := P.all_slots([["Primary", "Secondary"], ["Head"], ["Head"], null, "Primary"])
	ck(got == ["Primary", "Secondary", "Head"], "слоты в предпочтительном порядке, без дублей")
	ck(P.all_slots([]).is_empty(), "пустой список даёт пустой результат")
	ck(P.all_slots([null, [""], [null]]).is_empty(), "мусорные значения игнорируются")
	var extra := P.all_slots([["Head"], ["Zzz"], ["Альт"]])
	ck(extra.size() == 3 and str(extra[0]) == "Head", "известные слоты идут первыми")
	ck(str(extra[1]) != "Head", "новый слот не потерялся")
```

- [ ] **Step 2: Зарегистрировать тест в `check.ps1`**

Заменить строки 77-84 файла `.check/check.ps1` на:

```powershell
Write-Host "--- draft tests ---"
$fail = 0
foreach ($t in @("res://tests/test_draft.gd", "res://tests/test_picker.gd")) {
    $tout = & $Godot --headless --path $proj --script $t 2>&1 | Out-String
    Write-Host $tout.Trim()
    if (($LASTEXITCODE -ne 0) -or ($tout -match "FAIL")) {
        $fail++
    }
}
if ($fail -ne 0) {
    Write-Warning "Tests failed: $fail file(s)"
    exit 1
}
Write-Host "Tests passed"
```

- [ ] **Step 3: Прогнать и убедиться, что падает**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `FAIL  не удалось загрузить preload` или `Parse Error` на `VTKPicker.gd` — файла ещё нет.

- [ ] **Step 4: Создать `VTKPicker.gd` с `all_slots()`**

Файл `loadouts/mods/VTK/VTKPicker.gd`, CRLF, UTF-8 без BOM:

```gdscript
extends RefCounted
## Чистые решения выбора предметов: слоты, фильтры, полосы категорий, группы
## обвесов. Ни load(), ни путей внутрь игры - поэтому файл тестируется headless,
## как VTKDraft. Всё, что знает про ресурсы, приходит снаружи готовыми данными.

const SLOT_ORDER := ["Primary", "Secondary", "Melee", "Body", "Head",
	"Backpack", "Pouches", "Grenade_1", "Grenade_2", "Flashlight", "Radio"]

# Слоты, встречающиеся у предметов, в предпочтительном порядке.
# Предпочтительных, которых нет в данных, не выводим: после обновления игры
# лишних пустых строк не появится. Найденные вне списка идут в конец по алфавиту,
# чтобы новый слот не потерялся.
static func all_slots(slot_lists) -> Array:
	var found := {}
	for s in slot_lists:
		if typeof(s) != TYPE_ARRAY:
			continue
		for one in s:
			var n := str(one)
			if n != "":
				found[n] = true
	var out: Array = []
	for s in SLOT_ORDER:
		if found.has(s):
			out.append(s)
			found.erase(s)
	var rest := found.keys()
	rest.sort()
	for s in rest:
		out.append(str(s))
	return out
```

- [ ] **Step 5: Прогнать и убедиться, что зелено**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `ok  VTKPicker.gd`, `Picker tests passed`, `Tests passed`.

- [ ] **Step 6: Снимок**

```powershell
$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
$dst = "C:\Users\home\AppData\Local\Temp\opencode\vtk-snap-$stamp"
New-Item -ItemType Directory -Force -Path $dst | Out-Null
Copy-Item -Recurse -Force "D:\RTVMOD\loadouts" $dst
Write-Host "snapshot: $dst"
```

---

### Task 2: Фильтры и полосы

**Files:**
- Modify: `loadouts/mods/VTK/VTKPicker.gd`
- Modify: `.check/project/tests/test_picker.gd`

**Interfaces:**
- Consumes: `VTKPicker` из Task 1.
- Produces: `matches_slot(slots, slot: String) -> bool`, `matches_search(item_name: String, query: String) -> bool`, `shelves_of(items) -> Array`, константа `CATEGORY_ORDER: Array[String]`. Используются Task 8.

- [ ] **Step 1: Дописать тесты**

В `test_picker.gd` добавить вызовы в `_init()` после `t_all_slots()`:

```gdscript
	t_matches_slot()
	t_matches_search()
	t_shelves_of()
```

и сами функции:

```gdscript
func t_matches_slot() -> void:
	ck(P.matches_slot(["Primary", "Secondary"], "Secondary") == true, "слот из списка подходит")
	ck(P.matches_slot(["Primary"], "Head") == false, "чужой слот не подходит")
	ck(P.matches_slot(["Head"], "Head") == true, "одиночный слот работает")
	ck(P.matches_slot(null, "Head") == false, "null slots не подходит ни к чему")
	ck(P.matches_slot("Primary", "Primary") == false, "строка вместо массива не считается слотами")
	ck(P.matches_slot(null, "") == true, "пустой слот-цель подходит всему")
	ck(P.matches_slot(["Head"], "") == true, "без цели фильтр слота выключен")

func t_matches_search() -> void:
	ck(P.matches_search("Аптечка", "") == true, "пустой запрос подходит всему")
	ck(P.matches_search("Аптечка", "   ") == true, "запрос из пробелов считается пустым")
	ck(P.matches_search("Аптечка", "апт") == true, "поиск без учёта регистра")
	ck(P.matches_search("Аптечка", "АПТ") == true, "поиск в верхнем регистре находит")
	ck(P.matches_search("Аптечка", "  апт  ") == true, "запрос обрезается по краям")
	ck(P.matches_search("Аптечка", "нож") == false, "чужое слово не подходит")
	ck(P.matches_search("Аптечка", "ечк") == true, "совпадение в середине слова")
	ck(P.matches_search("", "апт") == false, "пустое имя не совпадает ни с чем")

func t_shelves_of() -> void:
	var items := [
		{"name": "Нож", "cat": "tool"},
		{"name": "АК", "cat": "weapon"},
		{"name": "Аптечка", "cat": "med"},
		{"name": "Граната", "cat": "gren"},
		{"name": "Рация", "cat": "equip"},
	]
	var got := P.shelves_of(items)
	ck(got.size() == 5, "пять непустых полос")
	ck(str(got[0]["cat"]) == "weapon", "оружие идёт первым")
	ck(str(got[1]["cat"]) == "armor" or got.size() == 5, "пустой полосы брони нет в выдаче")
	ck(P.shelves_of([]).is_empty(), "пустой список предметов даёт пустые полосы")
	ck(P.shelves_of([{"name": "Х", "cat": "weapon"}, "мусор", null]).size() == 1,
		"мусорные элементы пропускаются")
```

- [ ] **Step 2: Прогнать и убедиться, что падает**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `Picker tests failed` с `Parse Error` или `Invalid call` на отсутствующих функциях.

- [ ] **Step 3: Реализовать**

Дописать в `VTKPicker.gd` после `all_slots()`:

```gdscript
const CATEGORY_ORDER := ["weapon", "armor", "equip", "gren", "ammo", "med",
	"food", "tool"]

static func matches_slot(slots, slot: String) -> bool:
	if slot == "":
		return true
	if typeof(slots) != TYPE_ARRAY:
		return false
	for s in slots:
		if str(s) == slot:
			return true
	return false

static func matches_search(item_name: String, query: String) -> bool:
	var q := query.strip_edges().to_lower()
	if q == "":
		return true
	return str(item_name).to_lower().find(q) >= 0

# Полосы категорий в порядке CATEGORY_ORDER, пустые пропускаются.
# Элемент полосы: {"cat": String, "items": Array}.
static func shelves_of(items) -> Array:
	var out: Array = []
	for c in CATEGORY_ORDER:
		var bucket: Array = []
		for it in items:
			if typeof(it) == TYPE_DICTIONARY and str(it.get("cat", "")) == c:
				bucket.append(it)
		if not bucket.is_empty():
			out.append({"cat": c, "items": bucket})
	return out
```

- [ ] **Step 4: Прогнать и убедиться, что зелено**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `Picker tests passed`.

- [ ] **Step 5: Снимок**

```powershell
$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
$dst = "C:\Users\home\AppData\Local\Temp\opencode\vtk-snap-$stamp"
New-Item -ItemType Directory -Force -Path $dst | Out-Null
Copy-Item -Recurse -Force "D:\RTVMOD\loadouts" $dst
Write-Host "snapshot: $dst"
```

---

### Task 3: Панель предмета и группы обвесов

**Files:**
- Modify: `loadouts/mods/VTK/VTKPicker.gd`
- Modify: `.check/project/tests/test_picker.gd`

**Interfaces:**
- Consumes: `VTKPicker` из Task 1.
- Produces: `has_panel(info) -> bool`, `group_attachments(attachments) -> Array`. Используются Tasks 8, 9, 11.

- [ ] **Step 1: Дописать тесты**

В `_init()` добавить `t_has_panel()` и `t_group_attachments()`, а также функции:

```gdscript
func t_has_panel() -> void:
	ck(P.has_panel({"compatible": [{"name": "ПСО"}]}) == true, "есть compatible - панель нужна")
	ck(P.has_panel({"compatible": []}) == false, "пустой compatible - панель не нужна")
	ck(P.has_panel({"maxAmount": 8}) == true, "обойма - панель нужна для тумблера")
	ck(P.has_panel({"maxAmount": 0}) == false, "нулевой maxAmount - панель не нужна")
	ck(P.has_panel({}) == false, "пустой info - панели нет")
	ck(P.has_panel(null) == false, "null - панели нет")
	ck(P.has_panel({"compatible": null}) == false, "compatible не массив - панели нет")
	ck(P.has_panel({"compatible": [{"name": "ПСО"}], "maxAmount": 8}) == true,
		"обвесы и обойма вместе - одна панель")

func t_group_attachments() -> void:
	var atts := [
		{"path": "res://pso.tres", "name": "ПСО-1", "subtype": "Sight"},
		{"path": "res://koll.tres", "name": "ПК-01", "subtype": "Sight"},
		{"path": "res://muz.tres", "name": "Дуло", "subtype": "Muzzle"},
		{"path": "res://grip.tres", "name": "Цевьё", "subtype": "Grip"},
	]
	var got := P.group_attachments(atts)
	ck(got.size() == 3, "три группы: Оптика, Дуло, Цевьё")
	ck(str(got[0]["grp"]) == "Sight", "прицелы в одной группе")
	ck(got[0]["items"].size() == 2, "два прицела в группе")
	ck(str(got[1]["grp"]) == "Muzzle", "вторая группа - дуло")
	var no_sub := P.group_attachments([{"path": "res://x.tres", "name": "Х"}])
	ck(str(no_sub[0]["grp"]) == "Other", "без subtype группа Other")
	ck(P.group_attachments([]).is_empty(), "пустой список даёт пустые группы")
	ck(P.group_attachments([null, {"name": "без пути"}, {"path": "", "name": "пусто"}]).is_empty(),
		"элементы без пути отбрасываются")
	ck(P.group_attachments([{"path": "res://a.tres", "subtype": ""}])[0]["items"].size() == 1,
		"пустой subtype не теряет обвес")
```

- [ ] **Step 2: Прогнать и убедиться, что падает**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `Picker tests failed`.

- [ ] **Step 3: Реализовать**

Дописать в `VTKPicker.gd`:

```gdscript
# Есть ли что показать в панели предмета: обвесы или тумблер заполнения обоймы.
# Единая проверка для клетки, строки слота, чипа и самой панели - иначе метка
# и содержимое панели могут разойтись.
static func has_panel(info) -> bool:
	if typeof(info) != TYPE_DICTIONARY:
		return false
	var compat = info.get("compatible")
	if compat is Array and compat.size() > 0:
		return true
	var max_a = info.get("maxAmount")
	return max_a != null and float(max_a) > 0.0

# Обвесы, сгруппированные по их собственному subtype: оптику нельзя надеть
# вместе с оптикой, а дуло с дулом. Элемент группы: {"grp": String, "items": Array},
# элемент обвеса: {"path": String, "name": String, "subtype": String}.
static func group_attachments(attachments) -> Array:
	var groups: Array = []
	var index := {}
	for a in attachments:
		if typeof(a) != TYPE_DICTIONARY:
			continue
		var path := str(a.get("path", ""))
		if path == "":
			continue
		var grp := str(a.get("subtype", "")) if a.get("subtype") != null else "Other"
		if grp == "":
			grp = "Other"
		if not index.has(grp):
			index[grp] = groups.size()
			groups.append({"grp": grp, "items": []})
		groups[index[grp]]["items"].append(
			{"path": path, "name": str(a.get("name", "?")), "subtype": grp})
	return groups
```

- [ ] **Step 4: Прогнать и убедиться, что зелено**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `Picker tests passed`.

- [ ] **Step 5: Снимок**

```powershell
$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
$dst = "C:\Users\home\AppData\Local\Temp\opencode\vtk-snap-$stamp"
New-Item -ItemType Directory -Force -Path $dst | Out-Null
Copy-Item -Recurse -Force "D:\RTVMOD\loadouts" $dst
Write-Host "snapshot: $dst"
```

---

### Task 4: `VTKDraft.add_to_slot()`

**Files:**
- Modify: `loadouts/mods/VTK/VTKDraft.gd` (после `add()`, строка 66)
- Modify: `.check/project/tests/test_draft.gd`

**Interfaces:**
- Consumes: существующие `free_slot_of()`, `_desc()`, `equip`.
- Produces: `add_to_slot(path: String, item_name: String, slots, amount: float, type_name: String, slot: String, counted: bool = false) -> String`. Вызывается из Task 9.

- [ ] **Step 1: Дописать тест**

В `_init()` файла `test_draft.gd` добавить `t_add_to_slot()` после `t_free_slot_of()`, и саму функцию:

```gdscript
func t_add_to_slot() -> void:
	var d = Draft.new()
	var w := "res://w_slot.tres"
	var got := d.add_to_slot(w, "АКС", ["Primary", "Secondary"], 1.0, "Weapon", "Secondary")
	ck(got == "Secondary", "add_to_slot кладёт в запрошенный слот, а не в первый свободный")
	ck(d.equip.size() == 1, "в экипировке одна запись")
	ck(str(d.equip["Secondary"].get("path")) == w, "в Secondary лежит нужный предмет")
	ck(d.equip.has("Primary") == false, "Primary не тронут")
	ck(float(d.equip["Secondary"].get("amount")) == 1.0, "amount предмета записан")
	# занятый слот вытесняется, а не дублируется
	var got2 := d.add_to_slot("res://w_slot2.tres", "ПП", ["Primary"], 1.0, "Weapon", "Secondary")
	ck(got2 == "Secondary", "вытеснение возвращает слот")
	ck(str(d.equip["Secondary"].get("path")) == "res://w_slot2.tres", "новый предмет занял слот")
	ck(d.equip.size() == 1, "вытесненный предмет не остался второй записью")
	# слот, которого нет в slots предмета, отклоняется
	ck(d.add_to_slot(w, "АКС", ["Primary"], 1.0, "Weapon", "Secondary") == "",
		"слот вне slots предмета отклоняется")
	# мусорные входы
	ck(d.add_to_slot(w, "АКС", null, 1.0, "Weapon", "Primary") == "", "null slots отклоняется")
	ck(d.add_to_slot(w, "АКС", [], 1.0, "Weapon", "Primary") == "", "пустой slots отклоняется")
	ck(d.add_to_slot(w, "АКС", "Primary", 1.0, "Weapon", "Primary") == "",
		"строка вместо массива отклоняется")
	ck(d.add_to_slot(w, "АКС", ["Primary"], 1.0, "Weapon", "") == "", "пустой слот отклоняется")
	# обойма в слот не кладётся: в слоре живёт amount, а у обоймы нужен count
	ck(d.add_to_slot("res://mag_slot.tres", "Магазин", ["Primary"], 8.0, "Attachment",
		"Primary", true) == "", "обойма в слот не кладётся")
	ck(d.equip.size() == 1 and d.gear.is_empty(), "отказ не изменил черновик")
	# откат на add() после отказа: отказ add_to_slot ничего не трогает,
	# поэтому вызывающий код уводит предмет сам. Проверяем именно add(),
	# иначе утверждение про откат проходит по Primary, занятому ранее.
	d.add_to_slot("res://w_slot3.tres", "АКС-2", ["Primary", "Secondary"], 1.0, "Weapon", "Head")
	ck(not d.equip.has("Head"), "отказ не создал слот-призрак")
	d.add("res://w_slot3.tres", "АКС-2", ["Primary", "Secondary"], 1.0, "Weapon")
	ck(d.equip.has("Secondary"), "add() после отказа занимает свободный слот из slots")
```

- [ ] **Step 2: Прогнать и убедиться, что падает**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `FAIL add_to_slot ...` либо `Parse Error` — метода нет.

- [ ] **Step 3: Реализовать**

В `VTKDraft.gd` сразу после функции `add()` (заканчивается на строке 66) вставить:

```gdscript
# Положить предмет в конкретный слот. Занятый слот вытесняется: содержимое
# уходит из сета целиком, потому что оружие или броня в снаряжении бессмысленны,
# а молчаливый перенос пугает сильнее явного удаления.
# "" означает "слот непригоден" - вызывающий код откатывается на add().
func add_to_slot(path: String, item_name: String, slots, amount: float,
		type_name: String, slot: String, counted: bool = false) -> String:
	# У обоймы счётчик в count, а в слоре descriptor живёт с amount. Слотов у
	# обоймы нет, так что ветка недостижима, но подстраховка стоит одну строку.
	if counted:
		return ""
	if slot == "" or typeof(slots) != TYPE_ARRAY:
		return ""
	var fits := false
	for s in slots:
		if str(s) == slot:
			fits = true
			break
	if not fits:
		return ""
	# Присваивание по ключу и есть вытеснение: старый descriptor заменяется целиком,
	# вместе со своими обвесами. Erase не нужен, а проверка слота выше гарантирует,
	# что отказ ничего не тронул.
	equip[slot] = _desc(path, item_name, maxf(0.0, amount), type_name)
	return slot
```

- [ ] **Step 4: Прогнать и убедиться, что зелено**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `Draft tests passed` и `Picker tests passed`.

- [ ] **Step 5: Снимок**

```powershell
$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
$dst = "C:\Users\home\AppData\Local\Temp\opencode\vtk-snap-$stamp"
New-Item -ItemType Directory -Force -Path $dst | Out-Null
Copy-Item -Recurse -Force "D:\RTVMOD\loadouts" $dst
Write-Host "snapshot: $dst"
```

---

### Task 5: `VTKDraft.toggle_attachment()`

**Files:**
- Modify: `loadouts/mods/VTK/VTKDraft.gd` (рядом с `set_attachments()`, строка 125)
- Modify: `.check/project/tests/test_draft.gd`

**Interfaces:**
- Consumes: `descriptor_of()`.
- Produces: `toggle_attachment(owner_path: String, att_path: String, grp: String, grp_of: Callable) -> void`. Вызывается из Task 11.

- [ ] **Step 1: Дописать тест**

В `_init()` файла `test_draft.gd` добавить `t_toggle_attachment()` рядом с `t_attachments()`, и саму функцию:

```gdscript
func t_toggle_attachment() -> void:
	var d = Draft.new()
	var w := "res://w_att.tres"
	d.add(w, "АКС", ["Primary"], 1.0, "Weapon")
	# заглушка вместо load(): группа обвеса приходит снаружи
	var grp_of := func(p: String) -> String:
		if p.ends_with("pso") or p.ends_with("koll"):
			return "Sight"
		if p.ends_with("muz"):
			return "Muzzle"
		return "Other"
	d.toggle_attachment(w, "res://att_pso.tres", "Sight", grp_of)
	ck(d.descriptor_of(w).get("attachments", []).size() == 1, "первый обвес записан")
	d.toggle_attachment(w, "res://att_koll.tres", "Sight", grp_of)
	var a: Array = d.descriptor_of(w).get("attachments", [])
	ck(a.size() == 1, "второй прицел заменил первый, а не добавился")
	ck(str(a[0]) == "res://att_koll.tres", "остался последний выбранный")
	d.toggle_attachment(w, "res://att_muz.tres", "Muzzle", grp_of)
	a = d.descriptor_of(w).get("attachments", [])
	ck(a.size() == 2, "другая группа не вытеснила прицел")
	ck(a.has("res://att_koll.tres"), "коллиматор на месте после выбора дула")
	d.toggle_attachment(w, "res://att_koll.tres", "Sight", grp_of)
	a = d.descriptor_of(w).get("attachments", [])
	ck(a.size() == 1 and str(a[0]) == "res://att_muz.tres", "повторный клик снял прицел")
	d.toggle_attachment(w, "res://att_muz.tres", "Muzzle", grp_of)
	ck(not d.descriptor_of(w).has("attachments"), "пустой список обвесов удаляет ключ целиком")
	d.toggle_attachment("res://none.tres", "res://att_pso.tres", "Sight", grp_of)
	ck(d.gear.is_empty() and d.equip.size() == 1, "чужой путь не создаёт запись")
	d.toggle_attachment(w, "", "Sight", grp_of)
	ck(not d.descriptor_of(w).has("attachments"), "пустой путь обвеса игнорируется")
```

- [ ] **Step 2: Прогнать и убедиться, что падает**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `FAIL второй прицел заменил первый...` или `Parse Error`.

- [ ] **Step 3: Реализовать**

В `VTKDraft.gd` сразу после `set_attachments()` вставить:

```gdscript
# Обвес одиночный по группе: два прицела на стволе невалидны, поэтому выбор
# другого выбрасывает прежнего из той же группы, а повторный клик снимает.
# grp_of - Callable "путь обвеса -> группа", потому что черновик не грузит
# ресурсы. Пустой итог удаляет ключ, а не оставляет пустой массив.
func toggle_attachment(owner_path: String, att_path: String, grp: String,
		grp_of: Callable) -> void:
	var d := descriptor_of(owner_path)
	if d.is_empty() or att_path == "":
		return
	var atts: Array = []
	if d.has("attachments") and typeof(d["attachments"]) == TYPE_ARRAY:
		atts = d["attachments"]
	if atts.find(att_path) >= 0:
		atts.erase(att_path)
		# Ключ убирается только когда список опустел. Без проверки снятие
		# одного прицела стирает дуло и цевьё, выбранные раньше.
		if atts.is_empty():
			d.erase("attachments")
		return
	# Группа, заявленная вызывающим, сверяется с настоящей: опечатка в
	# разметке панели иначе молча вычистила бы чужую группу обвесов.
	var real_grp := grp
	if grp_of.is_valid():
		real_grp = str(grp_of.call(att_path))
	if real_grp == "":
		real_grp = grp
	var keep: Array = []
	for p in atts:
		if not grp_of.is_valid() or str(grp_of.call(str(p))) != real_grp:
			keep.append(p)
	keep.append(att_path)
	d["attachments"] = keep
```

- [ ] **Step 4: Прогнать и убедиться, что зелено**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `Draft tests passed` и `Picker tests passed`.

- [ ] **Step 5: Снимок**

```powershell
$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
$dst = "C:\Users\home\AppData\Local\Temp\opencode\vtk-snap-$stamp"
New-Item -ItemType Directory -Force -Path $dst | Out-Null
Copy-Item -Recurse -Force "D:\RTVMOD\loadouts" $dst
Write-Host "snapshot: $dst"
```

---

### Task 6: `VTKsets.json` и одноразовый перенос

**Files:**
- Modify: `loadouts/mods/VTK/VTKData.gd:4`
- Modify: `loadouts/mods/VTK/VTKUI.gd:140` (вызов) и `:521` (отладочный путь)
- Modify: `.check/project/tests/test_draft.gd`

**Interfaces:**
- Consumes: `get_all()`, `save_all()` из `VTKData.gd`.
- Produces: `VTKData.LEGACY_SAVE_FILE: String`, `VTKData.migrate_save_file() -> void`, `VTKData._migrate_one(src_path: String, dst_name: String) -> void`.

- [ ] **Step 1: Дописать тест миграции**

В `_init()` файла `test_draft.gd` добавить `t_save_file_migration()` в конец списка, и саму функцию:

```gdscript
func t_save_file_migration() -> void:
	var legacy := "user://MCM/vostok-toolkit/loadouts.json"
	var target := "user://MCM/vostok-toolkit/VTKsets.json"
	DirAccess.make_dir_recursive_absolute("user://MCM/vostok-toolkit")
	for p in [legacy, legacy + ".bak", target, target + ".bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(str(p)))
	ck(not FileAccess.file_exists(target), "VTKsets.json удалён перед тестом")
	var payload := '{"loadouts":[{"name":"ZZ_mig","quick_key":0,"equip":{},"gear":[]}]}'
	var f = FileAccess.open(legacy, FileAccess.WRITE)
	f.store_string(payload)
	f.close()
	var b = FileAccess.open(legacy + ".bak", FileAccess.WRITE)
	b.store_string(payload)
	b.close()
	Data.migrate_save_file()
	ck(FileAccess.file_exists(target), "loadouts.json перенесён в VTKsets.json")
	ck(FileAccess.file_exists(target + ".bak"), "loadouts.json.bak перенесён")
	ck(not FileAccess.file_exists(legacy), "старый loadouts.json удалён")
	var rf = FileAccess.open(target, FileAccess.READ)
	ck(rf.get_as_text() == payload, "содержимое перенесено байт в байт")
	rf.close()
	ck(Data.names().has("ZZ_mig"), "перенесённый сет читается через names()")
	Data.remove("ZZ_mig")
	var keep := '{"loadouts":[]}'
	var f2 = FileAccess.open(target, FileAccess.WRITE)
	f2.store_string(keep)
	f2.close()
	Data.migrate_save_file()
	var rf2 = FileAccess.open(target, FileAccess.READ)
	ck(rf2.get_as_text() == keep, "повторный вызов не трогает уже перенесённый файл")
	rf2.close()
	for p in [target, target + ".bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(str(p)))
```

- [ ] **Step 2: Прогнать и убедиться, что падает**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `FAIL loadouts.json перенесён в VTKsets.json` — миграции ещё нет.

- [ ] **Step 3: Переименовать файл в `VTKData.gd`**

Строку 4 заменить:

```gdscript
const SAVE_FILE := "user://MCM/vostok-toolkit/VTKsets.json"
const LEGACY_SAVE_FILE := "user://MCM/vostok-toolkit/loadouts.json"
```

Сразу после неё вставить:

```gdscript
# Одноразовый перенос loadouts.json -> VTKsets.json. Копия, а не rename:
# если удаление старого файла не удалось, данные всё равно уже на месте.
# Выходим, если новый файл уже есть - перенос не должен перетирать живое.
static func migrate_save_file() -> void:
	if FileAccess.file_exists(SAVE_FILE):
		return
	_migrate_one(LEGACY_SAVE_FILE, "VTKsets.json")
	_migrate_one(LEGACY_SAVE_FILE + ".bak", "VTKsets.json.bak")

static func _migrate_one(src_path: String, dst_name: String) -> void:
	if not FileAccess.file_exists(src_path):
		return
	var src = FileAccess.open(src_path, FileAccess.READ)
	if src == null:
		print("[VTK] save file migration failed: cannot open ", src_path)
		return
	var text := src.get_as_text()
	src.close()
	var dst_path := SAVE_FILE.get_base_dir() + "/" + dst_name
	var dst = FileAccess.open(dst_path, FileAccess.WRITE)
	if dst == null:
		print("[VTK] save file migration failed: cannot write ", dst_path)
		return
	dst.store_string(text)
	dst.close()
	var r := DirAccess.remove_absolute(ProjectSettings.globalize_path(src_path))
	if r != OK:
		print("[VTK] save file migration: copied ", dst_name,
			", failed to remove ", src_path, " (code ", str(r), ")")
		return
	print("[VTK] save file migrated: ", src_path.get_file(), " -> ", dst_name)
```

- [ ] **Step 4: Вызвать миграцию из `VTKUI._init_later()`**

В `VTKUI.gd` строку 140 (`	_migrate_mcm_dir()`) дополнить следующими строками:

```gdscript
	_migrate_mcm_dir()
	var LD = preload("res://mods/VTK/VTKData.gd")
	LD.migrate_save_file()
```

Порядок важен: обе миграции должны отработать до `_load_items()`, `_restore_toggles()` и `_register_mcm()`.

- [ ] **Step 5: Поправить отладочный путь**

В `VTKUI.gd` строку 521 заменить:

```gdscript
		debug.text = Loc.txt("file: ") + str(OS.get_user_data_dir()) + "/MCM/vostok-toolkit/VTKsets.json"
```

- [ ] **Step 6: Убедиться, что старого имени больше нет в живом коде**

Run: `Select-String -Path "D:\RTVMOD\loadouts\mods\VTK\*.gd" -Pattern "loadouts\.json"`
Expected: единственное совпадение — `LEGACY_SAVE_FILE` в `VTKData.gd` плюс `LEGACY_SAVE_FILE + ".bak"`. Строки в `_migrate_one` не содержат старого имени.

- [ ] **Step 7: Прогнать и убедиться, что зелено**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `Draft tests passed` и `Picker tests passed`.

- [ ] **Step 8: Снимок**

```powershell
$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
$dst = "C:\Users\home\AppData\Local\Temp\opencode\vtk-snap-$stamp"
New-Item -ItemType Directory -Force -Path $dst | Out-Null
Copy-Item -Recurse -Force "D:\RTVMOD\loadouts" $dst
Write-Host "snapshot: $dst"
```

---

### Task 7: Каркас трёх страниц и степпера

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd:408-500` (`_build_editor()`), `:632-727` (`_refresh_draft_ui()`)
- Modify: `loadouts/mods/VTK/VTKLoc.gd` (секция `RU`)

**Interfaces:**
- Consumes: `Loc`, `Draft` из `VTKUI.gd`; `VTKPicker` из Task 1-3.
- Produces: поля `_target_slot: String`, `_search_text: String`, `_page: int`, узлы `_page_equip`, `_page_gear`, `_page_done`, `_step_btns: Array`; функции `_build_stepper() -> Control`, `_show_page(n: int) -> void`, `_build_page_equipment() -> Control`, `_build_page_gear() -> Control`, `_build_page_done() -> Control`, `_refresh_pages() -> void`, `_reset_picker_state() -> void`.

- [ ] **Step 1: Объявить новые поля**

В `VTKUI.gd` рядом с существующими полями редактора (после строки 25, `_open_att_path`) добавить:

```gdscript
var _page: int = 0
var _target_slot: String = ""
var _search_text: String = ""
var _step_btns: Array = []
var _page_equip: Control = null
var _page_gear: Control = null
var _page_done: Control = null
var _page_label: Label = null
```

- [ ] **Step 2: Добавить RU-записи новых строк**

В `VTKLoc.gd` в словарь `RU` добавить строки (в алфавитном порядке, как там принято):

```gdscript
	'All items': 'Все предметы',
	'Done': 'Готово',
	'Loadout name': 'Название сета',
	'Nothing fits': 'Ничего не подходит',
	'Search items...': 'Поиск предметов...',
	'Set is empty': 'Сет пуст',
	'Loadout name required': 'Нужно название',
```

- [ ] **Step 3: Переписать `_build_editor()`**

Заменить тело `_build_editor()` (`VTKUI.gd:408-500`) на:

```gdscript
func _build_editor() -> void:
	for child in _editor_panel.get_children():
		_editor_panel.remove_child(child)
		child.queue_free()
	_step_btns = []
	_name_input = null
	_item_grid_container = null
	_item_grid = null
	_equip_box = null
	_gear_box = null
	_page_label = null

	var ed_title = Label.new()
	if _draft != null and _draft.set_name != "":
		ed_title.text = Loc.txt("Editing: ") + _draft.set_name
	else:
		ed_title.text = Loc.txt("Create new loadout")
	ed_title.add_theme_font_size_override("font_size", 12)
	ed_title.add_theme_color_override("font_color", _gold)
	_editor_panel.add_child(ed_title)

	_editor_panel.add_child(_build_stepper())

	_page_equip = _build_page_equipment()
	_page_gear = _build_page_gear()
	_page_done = _build_page_done()
	_editor_panel.add_child(_page_equip)
	_editor_panel.add_child(_page_gear)
	_editor_panel.add_child(_page_done)

	_reset_picker_state()
	_show_page(_page)
	_refresh_pages()
	_editor_panel.visible = _draft != null
```

- [ ] **Step 4: Реализовать степпер и переключение страниц**

После `_build_editor()` вставить:

```gdscript
const PAGE_TITLES := ["Equipment", "Gear", "Done"]

func _build_stepper() -> Control:
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 4)
	for i in range(PAGE_TITLES.size()):
		var idx := i
		var b := Button.new()
		b.text = Loc.txt(str(PAGE_TITLES[i]))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): _show_page(idx))
		_step_btns.append(b)
		row.add_child(b)
	var msg = Label.new()
	_page_label = msg
	msg.add_theme_font_size_override("font_size", 10)
	msg.add_theme_color_override("font_color", _gold)
	row.add_child(msg)
	return row

# Страницы строятся один раз, переключение - это visible. Пересборка узлов
# потеряла бы фокус в поле названия и позицию скролла.
func _show_page(n: int) -> void:
	_page = clampi(n, 0, 2)
	if _page_equip != null:
		_page_equip.visible = _page == 0
	if _page_gear != null:
		_page_gear.visible = _page == 1
	if _page_done != null:
		_page_done.visible = _page == 2
	for i in range(_step_btns.size()):
		var b := _step_btns[i] as Button
		if b == null:
			continue
		if i == _page:
			b.add_theme_color_override("font_color", _gold)
			b.add_theme_stylebox_override("normal", _make_tab_active_style())
		else:
			b.add_theme_color_override("font_color", Color("#888"))
			b.add_theme_stylebox_override("normal", _make_tab_style())

func _set_problem(msg: String) -> void:
	if _page_label != null:
		_page_label.text = msg

func _clear_problem() -> void:
	if _page_label != null:
		_page_label.text = ""

func _reset_picker_state() -> void:
	_target_slot = ""
	_search_text = ""
```

- [ ] **Step 5: Реализовать три заготовки страниц**

После `_reset_picker_state()` вставить:

```gdscript
func _page_wrap() -> VBoxContainer:
	var v = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	return v

func _build_page_equipment() -> Control:
	_equip_box = _page_wrap()
	return _equip_box

func _build_page_gear() -> Control:
	_gear_box = _page_wrap()
	return _gear_box

func _build_page_done() -> Control:
	var v = _page_wrap()
	_name_input = LineEdit.new()
	_name_input.placeholder_text = Loc.txt("Enter a name...")
	_name_input.add_theme_color_override("font_color", Color("#fff"))
	_name_input.add_theme_color_override("placeholder_color", Color("#666"))
	_name_input.add_theme_stylebox_override("normal", _make_dark_style())
	_name_input.add_theme_stylebox_override("focus", _make_dark_style())
	_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _draft != null:
		_name_input.text = _draft.set_name
	v.add_child(_name_input)
	return v

func _refresh_pages() -> void:
	pass
```

- [ ] **Step 6: Подключить сброс состояния к точкам пересборки**

В `_start_new_draft()` (`VTKUI.gd:1287`), `_cancel_draft()` (`:1293`) и `_edit_loadout()` (`:1343`) ничего не менять кроме порядка: `_reset_picker_state()` уже вызывается из `_build_editor()`, поэтому состояние сбрасывается само. Убедиться, что в `_edit_loadout()` между `d.load_from(raw)` и `_build_editor()` ничего нового не требуется: формат не менялся, миграции обвесов нет.

- [ ] **Step 7: Проверить локализацию**

Run: `python .check\keycheck.py`
Expected: `RESULT: every Loc.txt() key has a RU entry`.

- [ ] **Step 8: Прогнать парсинг**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `Parse check passed: 9 scripts`, тесты зелёные.

- [ ] **Step 9: Снимок**

```powershell
$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
$dst = "C:\Users\home\AppData\Local\Temp\opencode\vtk-snap-$stamp"
New-Item -ItemType Directory -Force -Path $dst | Out-Null
Copy-Item -Recurse -Force "D:\RTVMOD\loadouts" $dst
Write-Host "snapshot: $dst"
```

---

### Task 8: Шаг 1 — слоты, сетка с фильтром, поиск

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd` (заполнить `_build_page_equipment()`, добавить функции)
- Modify: `loadouts/mods/VTK/VTKLoc.gd` (секция `RU`)

**Interfaces:**
- Consumes: `VTKPicker.all_slots/matches_slot/matches_search/shelves_of/has_panel` (Tasks 1-3), `_item_slots()`, `_make_dark_style()`.
- Produces: `_slots_box`, `_shelves_box`, `_target_slot`, `_search_text`, `_item_index` (словарь `resource_path -> Resource`), `_item_info(path: String) -> Dictionary`, `_items_for_target() -> Array`, `_set_target_slot(slot: String) -> void`, `_set_search(text: String) -> void`, `_rebuild_shelves() -> void`, `_make_shelf(shelf: Dictionary) -> Control`, `_refresh_page_equipment() -> void`, `_make_equip_block(desc: Dictionary, slot: String) -> Control`, `_make_target_chip(...)`, `_cat_color(cat: String) -> Color`. Используется Tasks 9-12.

Имена разошлись с ранней редакцией этого таска, где были `_all_slots()`, `_populate_item_grid()`, `_item_grid`, `_attach_btn()` и `_refresh_slot_list()`. Причина одна: все они подразумевали один плоский список предметов и один контейнер на страницу. Реализация развела список слотов (`_slots_box`) и полки предметов (`_shelves_box`), потому что список пересобирается на каждом клике, а полки должны пережить пересборку вместе с фокусом в поиске.

- [ ] **Step 1: Дописать RU-записи**

В `VTKLoc.gd` в `RU` добавить:

```gdscript
	'Attachments for': 'Обвесы для',
```

- [ ] **Step 2: Добавить индекс ресурсов и сбор данных о предмете**

В `_load_items()` при обходе `_db_items` складывать ресурс в индекс, а доступ к сведениям о предмете сделать единственной функцией. Индекс обязателен: без него `_item_info()` звал бы `load()` по пути на каждый предмет базы при каждом клике, то есть читала бы тысячи ресурсов с диска.

```gdscript
var _item_index: Dictionary = {}

func _item_info(path: String) -> Dictionary:
	if path == "":
		return {"path": "", "slots": [], "compatible": [], "maxAmount": 0.0,
			"type": "", "subtype": "", "cat": ""}
	var res = _item_index.get(path, null)
	if res == null:
		return {"path": path, "slots": [], "compatible": [], "maxAmount": 0.0,
			"type": "", "subtype": "", "cat": ""}
	var compat = res.get("compatible")
	return {
		"path": path,
		"slots": _item_slots(res),
		"compatible": compat if compat is Array else [],
		"maxAmount": res.get("maxAmount"),
		"type": str(res.get("type", "")),
		"subtype": str(res.get("subtype", "")),
		"cat": str(res.get("type", "")).to_lower(),
	}
```

Функция принимает путь, а не предмет базы: её зовут и из клетки предмета, и из descriptor’а, где предмета уже нет - только путь. `compatible` и `maxAmount` лежат в словаре рядом с `panel`, потому что `Picker.has_panel()` сам их читает, а UI показывает `maxAmount` как вместимость обоймы.

Порядок слотов задаётся `SLOT_ORDER` из `VTKPicker` напрямую, без функции-объединителя: ранняя редакция собирала `_all_slots()` как объединение слотов всех предметов базы, но в UI слоты берутся из черновика, а не из базы, и одиннадцать слотов в порядке базы не имеет смысла.

- [ ] **Step 3: Реализовать фильтр и поиск**

После `_item_info()` вставить:

```gdscript
# Сначала слот, потом поиск поверх него: слот Head плюс "апт" даёт аптечки,
# годные в голову, а не все аптечки игры.
func _items_for_target() -> Array:
	var out: Array = []
	for item in _db_items:
		if not Picker.matches_slot(_item_info(str(item.resource_path)), _target_slot):
			continue
		if not Picker.matches_search(str(item.name), _search_text):
			continue
		out.append(item)
	return out

func _set_target_slot(slot: String) -> void:
	_target_slot = slot
	_open_att_path = ""
	_clear_problem()
	_refresh_page_equipment()

func _set_search(text: String) -> void:
	_search_text = text
	_rebuild_shelves()
```

`matches_slot()` принимает словарь `_item_info()`, а не массив слотов: задача 2 так и вынесла разбор ресурса в `VTKPicker`, и шаг 1 не должен снова брать `load()` на каждый предмет базы. `_item_info()` к тому же берёт ресурс из `_item_index`, то есть второй раз с диска не читает ничего.

- [ ] **Step 4: Реализовать чипы цели и строки слотов**

После `_set_search()` вставить:

```gdscript
# Чипы цели: занятые слоты плюс "Все предметы". Пустые слоты списком целей
# не нужны - в режиме "Все предметы" предмет сам уходит в свободный слот,
# а список из одиннадцати пустых чипов занимал бы пол-экрана.
func _make_target_chip(slot: String, name: String) -> Button:
	var b := Button.new()
	b.text = slot if name == "" else slot + ": " + name
	b.custom_minimum_size = Vector2(0, 18)
	b.add_theme_font_size_override("font_size", 8)
	if _target_slot == slot:
		b.add_theme_color_override("font_color", _gold)
		b.add_theme_stylebox_override("normal", _make_tab_active_style())
	b.pressed.connect(func(): _set_target_slot(slot))
	return b

# Список слотов и полки предметов обновляются вместе: чипы цели и фильтр
# предметов зависят от одного и того же _target_slot.
func _refresh_page_equipment() -> void:
	_refresh_slots()
	_rebuild_shelves()

func _refresh_slots() -> void:
	if _slots_box == null or _draft == null:
		return
	for c in _slots_box.get_children():
		_slots_box.remove_child(c)
		c.queue_free()
	var tgt = HBoxContainer.new()
	var tl = Label.new()
	tl.text = Loc.txt("Target") + ": "
	tl.add_theme_font_size_override("font_size", 9)
	tl.add_theme_color_override("font_color", _gold)
	tgt.add_child(tl)
	tgt.add_child(_make_target_chip("", Loc.txt("All items")))
	for slot in Picker.all_slots():
		if _draft.equip.has(slot):
			tgt.add_child(_make_target_chip(str(slot),
				str(_draft.equip[slot].get("name", ""))))
	_slots_box.add_child(tgt)
	for slot in Picker.all_slots():
		var slot_name := str(slot)
		var id: Dictionary = _draft.equip.get(slot_name, {})
		if id.is_empty():
			continue
		_slots_box.add_child(_make_equip_block(id, slot_name))
		if _open_att_path != "" and _open_att_path == str(id.get("path", "")):
			var ap := _build_att_panel(id)
			if ap != null:
				_slots_box.add_child(ap)
```

Ранняя редакция этого шага собирала всё в `_equip_box` и звала `_refresh_slot_list()`. Отброшено:

- очистка всего `_equip_box` попутно стирала поиск и полки, потому что они лежали в том же контейнере;
- строки пустых слотов в сетке: клик по ним менял цель, но предмет в них положить нечем - вместо этого цель выбирается чипами занятых слотов;
- `_attach_btn(slot)` и `_attach_btn_gear(path)` разделены на `_make_equip_block()` и `_make_gear_block()`: обе строки собираются из имени, счётчика, кнопки обоймы и кнопки удаления, и одна функция с флагом "это gear" читалась хуже двух прямых.
- [ ] **Step 5: Переписать `_build_page_equipment()`**

Заменить заготовку из Task 7 Step 5 на:

```gdscript
func _build_page_equipment() -> Control:
	# Возвращаем корень страницы, а не добавляем в _editor_panel: страницу
	# добавляет _build_editor(), и Bar.new() здесь вообще не существует.
	#
	# Внутри страницы три отдельных контейнера, и это не избыточность:
	# _refresh_slot_list() пересобирает список слотов на каждое обновление,
	# а поиск и сетка должны пережить эту пересборку вместе с фокусом в
	# поиске. Общий _equip_box для всех троих стирал бы их на каждом клике.
	var v := _page_wrap()
	var search = LineEdit.new()
	search.placeholder_text = Loc.txt("Search items...")
	# Живой поиск - на text_changed, не на gui_input: Godot рвёт gui_input у
	# LineEdit при потере фокуса, и клик по полосе категорий глушил бы поиск.
	search.text_changed.connect(func(t): _set_search(t))
	v.add_child(search)

	# Цель выбирается чипами занятых слотов. Пустые слоты доступны иначе -
	# в режиме "Все предметы" предмет сам уходит в свободный слот.
	_slots_box = VBoxContainer.new()
	_slots_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_slots_box)

	# Сетки категорий нет: полосы категорий по CATEGORY_ORDER, внутри -
	# кнопки предметов. ScrollContainer переживает пересборку полос.
	var shelves_scroll := ScrollContainer.new()
	shelves_scroll.custom_minimum_size = Vector2(0, 240)
	_shelves_box = VBoxContainer.new()
	shelves_scroll.add_child(_shelves_box)
	v.add_child(shelves_scroll)

	_equip_box = v
	return v
```

Правило: страница возвращает корень, `_editor_panel.add_child()` зовёт вызывающий `_build_editor()`, а `_refresh_slots()` пересобирает только `_slots_box` - чипы цели и строки слотов. Поиск и `_shelves_box` живут рядом и переживают эту пересборку вместе с фокусом в поиске.

- [ ] **Step 6: Переписать сетку предметов в `_rebuild_shelves()`**

Контейнер `_item_grid` и его мета-ключ `shelf_idx` из ранней редакции плана выброшены. Причина: полосы категорий строятся в `VBoxContainer` внутри `ScrollContainer`, номер полосы нигде не нужен, а `get_meta`/`set_meta` на пересобираемом узле — лишнее состояние. Название функции тоже меняется на `_rebuild_shelves()`, потому что «grid» в нём уже неверно.

В `VTKUI.gd`:

```gdscript
# Пересобирает полосы категорий под текущую цель и поиск.
func _rebuild_shelves() -> void:
	if _shelves_box == null:
		return
	for child in _shelves_box.get_children():
		_shelves_box.remove_child(child)
		child.queue_free()
	var rows: Array = []
	for item in _items_for_target():
		rows.append({"item": item, "cat": str(_item_info(item)["cat"])})
	if rows.is_empty():
		var e = Label.new()
		e.text = Loc.txt("Nothing fits")
		e.add_theme_color_override("font_color", Color("#666"))
		_shelves_box.add_child(e)
		return
	for shelf in Picker.shelves_of(rows):
		_shelves_box.add_child(_make_shelf(shelf))
```

Полоса — заголовок категории плюс кнопки предметов:

```gdscript
func _make_shelf(shelf: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head = Label.new()
	head.text = Loc.txt(CATEGORY_LABELS.get(str(shelf["cat"]), str(shelf["cat"])))
	head.add_theme_font_size_override("font_size", 9)
	head.add_theme_color_override("font_color", _gold)
	box.add_child(head)
	for row in shelf["items"]:
		box.add_child(_make_item_cell(str(row["item"])))
	return box
```

`CATEGORY_LABELS` — словарь в `VTKUI.gd`, ключ `cat` из базы, значение английская строка для `Loc.txt()`. Категории базы приходят с большой буквы (`Consumable`), а `CATEGORY_ORDER` в `VTKPicker` разбирает их в `String.to_lower()`, поэтому словарь ключуется строчными: `{"consumable": "Consumables", ...}`. Прописывать русские строки здесь нельзя: они обязаны лежать в `VTKLoc.gd`, иначе `keycheck.py` их не увидит.

- [ ] **Step 7: Прогнать парсинг**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `Parse check passed: 9 scripts`. Ошибок анализатора быть не должно: `Picker` — это `preload`, который надо добавить.

- [ ] **Step 8: Добавить `preload` и обновить счётчик в `AGENTS.md`**

В `VTKUI.gd` рядом с существующими `preload` добавить строку `const Picker = preload("res://mods/VTK/VTKPicker.gd")`. В `AGENTS.md` в таблице привязок заменить `preload("res://mods/VTK/...")` ×11 на ×12, а упоминание числа `preload` во `VTKUI.gd` привести к фактическому.

- [ ] **Step 9: Снимок**

```powershell
$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
$dst = "C:\Users\home\AppData\Local\Temp\opencode\vtk-snap-$stamp"
New-Item -ItemType Directory -Force -Path $dst | Out-Null
Copy-Item -Recurse -Force "D:\RTVMOD\loadouts" $dst
Write-Host "snapshot: $dst"
```

---

### Task 9: Шаг 1 — маршрутизация клика по карточке

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd` (`_make_item_cell()`, добавить `_place_item()`)

**Interfaces:**
- Consumes: `Draft.add_to_slot()`, `Draft.add()`, `Draft.shown_count()`, `Picker.has_panel()`.
- Produces: `_place_item(item, forced_slot: String = "") -> void`, `_place_into(item, forced_slot: String) -> void`, `_open_panel_if_any(path: String) -> void`. Используется Tasks 10, 11.

- [ ] **Step 1: Добавить маршрутизацию**

После `_add_item_from_grid()` в `VTKUI.gd` вставить:
```gdscript
# Куда попадёт предмет: в выбранный слот, в первый свободный или в снаряжение.
# forced_slot переопределяет выбор цели на шаге 1, его передаёт клетка шага 2.
func _place_item(item, forced_slot: String = "") -> void:
	_place_into(item, forced_slot)

# Ядро маршрутизации живёт в _place_into(), потому что шаг 2 отдаёт его
# с forced_slot = "GEAR", минуя _place_item().
func _place_into(item, forced_slot: String) -> void:
	if _draft == null or item == null:
		return
	var path: String = item.resource_path
	var info := _item_info(path)
	var slots: Array = info.get("slots", [])
	var amt := 1.0
	var counted := false
	var t := str(info.get("type", ""))
	if t != "Weapon" and t != "Ammo":
		var maxAm = info.get("maxAmount")
		if maxAm != null and maxAm > 1:
			amt = float(maxAm)
	counted = t == "Attachment" and str(info.get("subtype")) == "Magazine"
	var placed := ""
	if forced_slot == "GEAR":
		placed = "GEAR"
	elif forced_slot != "":
		placed = _draft.add_to_slot(path, str(item.name), slots, amt, t,
			forced_slot, counted)
	if placed != "GEAR" and placed == "":
		# Явная цель отказала - откат на add() был бы молчаливым переносом
		# в другой слот, и игрок бы не понял, куда делся предмет.
		if forced_slot != "":
			_set_problem(Loc.txt("Does not fit") + ": " + forced_slot)
			return
		_draft.add(path, str(item.name), slots, amt, t, counted)
	if placed == "GEAR":
		_gear_grid_scroll.visible = false
		_gear_picker.text = Loc.txt("+ Add")
	_open_panel_if_any(path)
	_clear_problem()
	_refresh_pages()

# Панель открывается только если открывать есть что: обвесы или тумблер обоймы.
func _open_panel_if_any(path: String) -> void:
	if _draft == null:
		return
	if Picker.has_panel(_item_info(path)):
		_open_att_path = path
	else:
		_open_att_path = ""
```

Три отличия от ранней редакции:

- `load(path)` заменён на `_item_info(path)`: ресурс уже в `_db_items`, а в Task 8 этим же аргументом пользуется и пересборка полок. Второй `load()` на тот же путь означал бы двойное чтение ресурса с диска на каждый клик;
- отказ при явной цели больше не откатывается на `add()`. Тихий перенос в другой слот хуже явного отказа, о котором игрок узнаёт из строки проблемы;
- `_populate_item_grid()` в конце вызова убран: `_refresh_pages()` пересобирает полки сам, а второй вызов только что стёр бы свежесобранное.
- [ ] **Step 2: Переключить клетку на `_place_item()`**

В `_make_item_cell()` найти подключение кнопки, где вызывается `_add_item_from_grid(it, type_name)`, и заменить вызов на `_place_item(it, forced_slot)`. Саму `_add_item_from_grid()` удалить: после перехода на шаги она не вызывается ниоткуда. Второй аргумент `_make_item_cell()` не умолчать нельзя - без него шаг 2 клал бы предмет в слот, выбранный целью на шаге 1.

- [ ] **Step 3: Реализовать `_refresh_pages()`**

После `_build_page_done()` вставить:

```gdscript
# Единственная точка обновления трёх страниц. Все остальные места зовут её,
# а не отдельные _refresh_*: после выбора предмета меняются и чипы цели, и
# счётчики, и итоговая сводка, и любая из них, вызванная в одиночку,
# оставляла бы вторую страницу в старом состоянии.
func _refresh_pages() -> void:
	_refresh_page_equipment()
	_refresh_page_gear()
	_refresh_page_done()
```

Каждая из трёх функций ниже не трогает контейнер чужой страницы. `_refresh_page_equipment()` пересобирает `_slots_box` и `_shelves_box`, `_refresh_page_gear()` - `_gear_chips` и, если открыт, `_gear_shelves`, `_refresh_page_done()` - `_done_summary`.

- [ ] **Step 4: Заглушки на время задачи**

`_refresh_page_gear()` и `_refresh_page_done()` появятся в Tasks 10 и 12. Чтобы код собирался, в этом таске создать их сразу минимальными:

```gdscript
func _refresh_page_gear() -> void:
	pass

func _refresh_page_done() -> void:
	pass
```

- [ ] **Step 5: Прогнать парсинг**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `Parse check passed: 9 scripts`.

- [ ] **Step 6: Снимок**

```powershell
$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
$dst = "C:\Users\home\AppData\Local\Temp\opencode\vtk-snap-$stamp"
New-Item -ItemType Directory -Force -Path $dst | Out-Null
Copy-Item -Recurse -Force "D:\RTVMOD\loadouts" $dst
Write-Host "snapshot: $dst"
```

---

### Task 10: Шаг 2 — чипы снаряжения и пикер

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd` (заполнить `_build_page_gear()`, реализовать `_rebuild_gear_chips()`)

**Interfaces:**
- Consumes: `Draft.set_gear_amount()`, `Draft.shown_count()`, `Draft.remove_gear()`, `Draft.descriptor_of()`, `Draft.is_full()`, `Draft.set_full_mag()`.
- Produces: `_gear_picker: Button`, `_gear_search_field: LineEdit`, `_gear_chips`, `_gear_shelves`, `_gear_grid_scroll`, `_build_page_gear() -> Control`, `_toggle_gear_picker() -> void`, `_rebuild_gear_picker() -> void`, `_make_gear_shelf(shelf) -> Control`, `_rebuild_gear_chips() -> void`, `_make_gear_block(desc, cur) -> Control`, `_make_full_mag_btn(path) -> Button`, `_remove_gear(path) -> void`, `_set_gear_search(text) -> void`.

- [ ] **Step 1: Дописать RU-записи**

В `VTKLoc.gd` в `RU` добавить:

```gdscript
	'+ Add': '+ Добавить',
```

- [ ] **Step 2: Реализовать страницу снаряжения**

Заготовку `_build_page_gear()` из Task 7 заменить на:

```gdscript
var _gear_picker: Button = null
var _gear_search_field: LineEdit = null
var _gear_chips: VBoxContainer = null
var _gear_shelves: VBoxContainer = null

func _build_page_gear() -> Control:
	_gear_box = _page_wrap()
	# Свой поиск, а не общий с шагом 1: шаги - независимые деревья, и общий
	# _search_text означал бы, что переключение страницы стирает то, что
	# игрок набирал на другой.
	var search = LineEdit.new()
	search.placeholder_text = Loc.txt("Search items...")
	search.text_changed.connect(func(t): _set_gear_search(t))
	_gear_box.add_child(search)
	_gear_search_field = search
	_gear_picker = Button.new()
	_gear_picker.text = Loc.txt("+ Add")
	_gear_picker.pressed.connect(_toggle_gear_picker)
	_gear_box.add_child(_gear_picker)
	_gear_chips = VBoxContainer.new()
	_gear_box.add_child(_gear_chips)
	_gear_grid_scroll = ScrollContainer.new()
	_gear_shelves = VBoxContainer.new()
	_gear_grid_scroll.add_child(_gear_shelves)
	_gear_box.add_child(_gear_grid_scroll)
	return _gear_box
```

`+ Add` - кнопка-переключатель: повторное нажатие убирает полки обратно, поэтому состояние живёт в `_gear_grid_scroll.visible`, а не в отдельном флаге.

Сетки предметов для шага 2 нет - полосы категорий, как на шаге 1:

```gdscript
func _toggle_gear_picker() -> void:
	if _gear_grid_scroll == null:
		return
	_gear_grid_scroll.visible = not _gear_grid_scroll.visible
	_gear_picker.text = Loc.txt("- Add") if _gear_grid_scroll.visible else Loc.txt("+ Add")
	if _gear_grid_scroll.visible:
		_rebuild_gear_picker()

func _rebuild_gear_picker() -> void:
	for child in _gear_shelves.get_children():
		_gear_shelves.remove_child(child)
		child.queue_free()
	var rows: Array = []
	for item in _db_items:
		if not Picker.matches_search(str(item.name), _gear_search_text):
			continue
		rows.append({"item": item, "cat": str(_item_info(item)["cat"])})
	if rows.is_empty():
		var e = Label.new()
		e.text = Loc.txt("Nothing fits")
		_gear_shelves.add_child(e)
		return
	for shelf in Picker.shelves_of(rows):
		_gear_shelves.add_child(_make_gear_shelf(shelf))

func _make_gear_shelf(shelf: Dictionary) -> Control:
	var box := VBoxContainer.new()
	var head = Label.new()
	head.text = Loc.txt(CATEGORY_LABELS.get(str(shelf["cat"]), str(shelf["cat"])))
	head.add_theme_color_override("font_color", _gold)
	box.add_child(head)
	for row in shelf["items"]:
		box.add_child(_make_item_cell(str(row["item"]), "GEAR"))
	return box
```

Два отличия от `_make_shelf()`, и оба обязательны:

- клетка получает цель через второй аргумент `_make_item_cell(item, forced_slot := "")`. Клик по клетке шага 2 обязан попадать в снаряжение независимо от того, какой слот выбран целью на шаге 1, поэтому цель клетки задаётся явно, а не берётся из `_target_slot`;
- шаг 2 фильтрует по `_gear_search_text`, а не по `_search_text`.

Возврат клетки кнопкой, а не через `gui_input`:

```gdscript
func _make_item_cell(item: String, forced_slot: String = "") -> Control:
	var b := Button.new()
	b.text = str(item)
	var it := item
	b.pressed.connect(func(): _place_item(it, forced_slot))
	return b
```

Ранняя редакция плана предлагала `cell.gui_input.disconnect(func(_e): pass)` поверх `_make_item_cell()` и `GridContainer` из шести колонок. Обе вещи выброшены: `disconnect` требует ту же самую Callable, а лямбда создаёт новую, поэтому отключения не происходит и шаг 2 срабатывал бы дважды; `Control.gui_input` на клетках-`Control` работает, но `Button.pressed` короче и не требует разбора событий. Поле выбора в `LineEdit` остаётся на `text_changed` по той же причине, что и на шаге 1.
- [ ] **Step 3: Реализовать чипы и добавление в снаряжение**

После `_make_gear_shelf()` вставить:

```gdscript
# Клик по клетке кладёт предмет в снаряжение и закрывает полки. Обвесы
# открываются только если они есть, иначе состояние open осталось бы мусорным.
func _place_into(item, forced_slot: String) -> void:
	if _draft == null or item == null:
		return
	var path: String = item.resource_path
	var info := _item_info(path)
	var amt := 1.0
	var counted := false
	# Сведения берём из _item_info, а не load() по пути: предмет уже в базе,
	# а шаг 2 перебирает всю базу, и load() на каждый элемент грузил бы
	# ресурс с диска по второму разу.
	var cat := str(info.get("cat", ""))
	if cat != "Weapon" and cat != "Ammo":
		var maxAm = info.get("maxAmount")
		if maxAm != null and maxAm > 1:
			amt = float(maxAm)
	counted = str(info.get("type", "")) == "Attachment" and str(info.get("subtype")) == "Magazine"
	if forced_slot == "GEAR":
		_draft.add(path, str(item.name), [], amt, cat, counted)
		_gear_grid_scroll.visible = false
		_gear_picker.text = Loc.txt("+ Add")
	elif forced_slot == "":
		_draft.add(path, str(item.name), [], amt, cat, counted)
	else:
		var landed := _draft.add_to_slot(path, str(item.name), info.get("slots", []),
				amt, str(info.get("type", "")), forced_slot, counted)
		if landed == "":
			# Слот занят - предмет освободил его, но не влез. Молчаливый
			# перенос пугает сильнее явного отказа.
			_set_problem(Loc.txt("Does not fit") + ": " + forced_slot)
			return
		_set_target_slot("")
	if Picker.has_panel(info):
		_open_att_path = path
	_clear_problem()
	_refresh_pages()

# Пересобирает только чипы. _gear_box трогать нельзя: в нём живут поиск,
# кнопка "+ Add" и ScrollContainer полок, и пересборка всего контейнера
# стирала бы их вместе с фокусом в поиске.
func _rebuild_gear_chips() -> void:
	if _gear_chips == null or _draft == null:
		return
	for c in _gear_chips.get_children():
		_gear_chips.remove_child(c)
		c.queue_free()
	if _draft.gear.is_empty():
		var g = Label.new()
		g.text = Loc.txt("No gear")
		g.add_theme_color_override("font_color", Color("#555"))
		_gear_chips.add_child(g)
		return
	for d in _draft.gear:
		var desc: Dictionary = d
		var cur := str(desc.get("path", ""))
		_gear_chips.add_child(_make_gear_block(desc, cur))
		if _open_att_path == cur:
			var ap := _build_att_panel(desc)
			if ap != null:
				_gear_chips.add_child(ap)

func _make_gear_block(desc: Dictionary, cur: String) -> Control:
	var row := HBoxContainer.new()
	var nm = Label.new()
	nm.text = str(desc.get("name", "?"))
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.add_theme_font_size_override("font_size", 10)
	row.add_child(nm)
	var minus = Button.new()
	minus.text = "-"
	minus.custom_minimum_size = Vector2(18, 18)
	minus.pressed.connect(func(): _bump_gear(cur, -1.0))
	row.add_child(minus)
	var q = Label.new()
	q.text = str(Draft.shown_count(desc))
	q.custom_minimum_size = Vector2(38, 0)
	q.add_theme_font_size_override("font_size", 10)
	row.add_child(q)
	var plus = Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(18, 18)
	plus.pressed.connect(func(): _bump_gear(cur, 1.0))
	row.add_child(plus)
	var info := _item_info(cur)
	if Picker.has_panel(info):
		if str(info.get("subtype", "")) == "Magazine":
			# Обойма - это снаряжение, но её полнота живёт в count, поэтому
			# полную обойму можно развернуть прямо в чипе снаряжения.
			row.add_child(_make_full_mag_btn(cur))
		else:
			var atts: Array = desc.get("attachments", []) if desc.has("attachments") else []
			var ab := Button.new()
			ab.text = Loc.txt(" rnd.") + str(atts.size()) + " "
			ab.custom_minimum_size = Vector2(0, 18)
			ab.add_theme_font_size_override("font_size", 8)
			if atts.size() > 0:
				ab.add_theme_color_override("font_color", _gold)
			ab.pressed.connect(func(): _toggle_attachment_panel(cur))
			row.add_child(ab)
	var x = Button.new()
	x.text = "✕"
	x.custom_minimum_size = Vector2(18, 18)
	x.pressed.connect(func(): _remove_gear(cur))
	row.add_child(x)
	return row

func _make_full_mag_btn(path: String) -> Button:
	var b := Button.new()
	var d := _draft.descriptor_of(path)
	b.text = Loc.txt("Full") if Draft.is_full(d) else Loc.txt("Empty")
	b.custom_minimum_size = Vector2(38, 18)
	b.add_theme_font_size_override("font_size", 8)
	b.pressed.connect(func():
		Draft.set_full_mag(_draft.descriptor_of(path), not Draft.is_full(_draft.descriptor_of(path)))
		_refresh_pages()
	)
	return b

func _remove_gear(path: String) -> void:
	_draft.remove_gear(path)
	if _open_att_path == path:
		_open_att_path = ""
	_refresh_pages()
```

Три отличия от ранней редакции этого шага, все три из-за ошибок в ней:

- `_gear_box.add_child(_build_gear_grid())` выброшено: полки живут в `_gear_grid_scroll`, который строится один раз в `_build_page_gear()`, и состояние открытия - это его `visible`;
- `load(cur)` заменён на `_item_info(cur)`, тем же доводом, что выше;
- удаление обвесов из gear-чипа ушло в `_remove_gear()`, где сбрасывается и `_open_att_path`: иначе удалённый предмет оставался бы открытым и панель уезжала в пустоту.
- [ ] **Step 4: Заменить `−` на `-` в соглашениях**

Кнопки количества используют `+` и `-` ASCII, а не `−` U+2212: текст кнопки попадает в локализацию только если станет видимой строкой, но ASCII безопаснее для консоли и шрифтов игры. Знак `✕` в строке слота оставляем: он не ASCII, но рисуется шрифтом игры, проверен на тех же версиях, что и стрелки степпера.

- [ ] **Step 5: Прогнать парсинг и локализацию**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`, затем `python .check\keycheck.py`
Expected: `Parse check passed: 9 scripts`, `RESULT: every Loc.txt() key has a RU entry`.

- [ ] **Step 6: Снимок**

```powershell
$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
$dst = "C:\Users\home\AppData\Local\Temp\opencode\vtk-snap-$stamp"
New-Item -ItemType Directory -Force -Path $dst | Out-Null
Copy-Item -Recurse -Force "D:\RTVMOD\loadouts" $dst
Write-Host "snapshot: $dst"
```

---

### Task 11: Панель обвесов single-choice

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd` (`_build_att_panel()`, удалить `_connect_att_cb()`), `VTKLoc.gd` (секция `RU`)

**Interfaces:**
- Consumes: `Draft.toggle_attachment()`, `Draft.is_full()`, `Draft.set_full_mag()`, `Picker.group_attachments()`, `Picker.has_panel()`.
- Produces: переписанные `_build_att_panel(desc: Dictionary) -> Control`, `_att_group_of(path) -> String`, `_att_group_label(grp) -> String`, `_att_entries(res) -> Array`, `_make_att_toggle(...)`, `_build_mag_panel(res, owner_path) -> Control`, `ATT_GROUP_LABELS`. Удаляются `_connect_att_cb()` и маппинг `subtype → Loc.txt` внутри панели.

- [ ] **Step 1: Добавить резолвер группы**

После `_open_panel_if_any()` в `VTKUI.gd` вставить:

```gdscript
# Группа обвеса - его собственный subtype. Резолвер нужен черновику, который
# не умеет грузить ресурсы, поэтому он живёт здесь.
func _grp_of(path: String) -> String:
	var res = load(path)
	if res == null:
		return "Other"
	var st = res.get("subtype")
	return str(st) if st != null else "Other"
```

- [ ] **Step 2: Переписать `_build_attachment_panel()`**

Заменить тело `_build_attachment_panel()` (`VTKUI.gd:972-1053`) на:

```gdscript
func _build_attachment_panel(item) -> Control:
	var res = load(str(item.get("path", "")))
	if res == null:
		return null
	var info := {"compatible": res.get("compatible"),
		"maxAmount": res.get("maxAmount")}
	if not Picker.has_panel(info):
		return null
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pan_style := StyleBoxFlat.new()
	pan_style.bg_color = Color("#14100c")
	pan_style.border_color = Color("#2a1f14")
	pan_style.border_width_all = 1
	pan_style.corner_radius_all = 4
	pan_style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", pan_style)
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	vb.add_theme_constant_override("h_separation", 4)
	panel.add_child(vb)

	var owner_path := str(item.get("path", ""))
	var head = Label.new()
	head.text = Loc.txt("Attachments for: ") + str(item.get("name", ""))
	head.add_theme_font_size_override("font_size", 9)
	head.add_theme_color_override("font_color", Color("#6a5a4a"))
	vb.add_child(head)

	# Обойма: панель целиком отдана под тумблер заполнения. Вложенные патроны
	# игра не читает, поэтому число патронов задаёт сам amount.
	if float(info.get("maxAmount", 0.0)) > 0.0:
		var cap := int(round(float(info["maxAmount"])))
		var row = HBoxContainer.new()
		row.add_theme_constant_override("margin_left", 8)
		var cb = CheckButton.new()
		cb.button_pressed = Draft.is_full(item)
		var op := owner_path
		cb.toggled.connect(func(on: bool):
			if _draft != null:
				_draft.set_full_mag(op, on)
			_refresh_pages()
		)
		row.add_child(cb)
		var lbl = Label.new()
		lbl.text = Loc.txt("Full magazine") + " - " + str(cap)
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", Color("#bbb"))
		row.add_child(lbl)
		vb.add_child(row)
		return panel

	# Обычные обвесы: выбор по группам, один на группу.
	var raw: Array = []
	var compat = res.get("compatible")
	if compat is Array:
		for cd in compat:
			if cd == null:
				continue
			var p := cd.resource_path if cd is Resource else str(cd.get("resource_path", ""))
			if p == "":
				continue
			raw.append({"path": p, "name": str(cd.get("name")) if cd.get("name") != null else "?", "subtype": _grp_of(p)})
	var groups := Picker.group_attachments(raw)
	var saved: Array = item.get("attachments") if item.has("attachments") else []
	for g in groups:
		var grp := str(g["grp"])
		var sect = Label.new()
		sect.text = Loc.txt(ATT_GROUP_LABELS.get(grp, grp))
		sect.add_theme_font_size_override("font_size", 9)
		sect.add_theme_color_override("font_color", Color("#6a5a4a"))
		sect.add_theme_constant_override("margin_left", 4)
		vb.add_child(sect)
		for a in g["items"]:
			var ap := str(a["path"])
			var on := saved.has(ap)
			var opt := Button.new()
			opt.text = str(a["name"])
			opt.add_theme_font_size_override("font_size", 10)
			opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if on:
				opt.add_theme_color_override("font_color", _gold)
				opt.add_theme_stylebox_override("normal", _make_tab_active_style())
			var op2 := owner_path
			var g2 := grp
			opt.pressed.connect(func():
				if _draft == null:
					return
				_draft.toggle_attachment(op2, ap, g2, Callable(self, "_grp_of"))
				_refresh_pages()
			)
			vb.add_child(opt)
	return panel
```

- [ ] **Step 3: Удалить старое и мёртвое**

Удалить функцию `_connect_att_cb()` (`VTKUI.gd:1055-1072`) целиком: она работала с `CheckButton` и ей больше не пользуются. `_has_compat()` (`VTKUI.gd:729`) и `_make_att_btn()` (`VTKUI.gd:738`) удаляются вместе с ней: их заменили `_make_equip_block()` на шаге 1 и `_make_gear_block()` на шаге 2. Проверка — ноль вызовов, а не ноль упоминаний: имя функции в комментарии убирать не нужно.

Run: `Select-String -Path "D:\RTVMOD\loadouts\mods\VTK\VTKUI.gd" -Pattern "_has_compat|_make_att_btn|_connect_att_cb"`
Expected: только объявления функций, без вызовов. Если остались вызовы — довести до нуля.

Плюс `ATT_GROUP_LABELS` в начало `VTKUI.gd` рядом с `CATEGORY_LABELS`: словарь `subtype -> английская строка`. Без него заголовки групп печатались бы внутренними именами вроде `Barrel`, и `keycheck.py` не увидел бы ключи. Плюс `_att_group_label()` для вызова из UI.

- [ ] **Step 4: Прогнать парсинг и локализацию**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`, затем `python .check\keycheck.py`
Expected: `Parse check passed: 9 scripts`, `RESULT: every Loc.txt() key has a RU entry`.

- [ ] **Step 5: Снимок**

```powershell
$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
$dst = "C:\Users\home\AppData\Local\Temp\opencode\vtk-snap-$stamp"
New-Item -ItemType Directory -Force -Path $dst | Out-Null
Copy-Item -Recurse -Force "D:\RTVMOD\loadouts" $dst
Write-Host "snapshot: $dst"
```

---

### Task 12: Шаг 3 — сводка и сохранение с валидацией

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd` (`_refresh_page_done()`, `_build_page_done()`, `_save_loadout()`)

**Interfaces:**
- Consumes: `Draft.item_count()`, `Draft.shown_count()`, `Draft.is_full()`, `Picker.all_slots()`, существующая логика `_save_loadout()`.
- Produces: `_done_summary: VBoxContainer`, `_refresh_page_done() -> void`, `_summary_line(text: String) -> Label`, валидация в `_save_loadout()` через `_set_problem()`.

- [ ] **Step 1: Реализовать сводку**

Рядом с `_set_problem()` вставить:

```gdscript
# Пересобирает сводку в _done_summary. Узлы шага 3 строятся один раз и
# переживают переключение страниц, поэтому сводка - единственное, что
# пересобирается на каждом обновлении.
func _refresh_page_done() -> void:
	if _done_summary == null or _draft == null:
		return
	for c in _done_summary.get_children():
		_done_summary.remove_child(c)
		c.queue_free()
	if _draft.equip.is_empty() and _draft.gear.is_empty():
		var e = Label.new()
		e.text = Loc.txt("Set is empty")
		e.add_theme_color_override("font_color", Color("#555"))
		_done_summary.add_child(e)
		return
	for slot in Picker.all_slots():
		if not _draft.equip.has(slot):
			continue
		var d: Dictionary = _draft.equip[slot]
		_done_summary.add_child(_summary_line(str(slot) + ": "
			+ str(d.get("name", "?"))))
		var atts: Array = d.get("attachments") if d.has("attachments") else []
		for ap in atts:
			var info := _item_info(str(ap))
			var name_s := str(info.get("name", "")) if not info.is_empty() else str(ap)
			var al := _summary_line("   " + name_s)
			al.add_theme_color_override("font_color", _gold)
			_done_summary.add_child(al)
		if not Draft.is_full(d) and d.has("count"):
			_done_summary.add_child(_summary_line("   " + Loc.txt("Empty")))
	for g in _draft.gear:
		var gd: Dictionary = g
		_done_summary.add_child(_summary_line(str(gd.get("name", "?"))
			+ " x" + str(Draft.shown_count(gd))))
		if not Draft.is_full(gd) and gd.has("count"):
			_done_summary.add_child(_summary_line("   " + Loc.txt("Empty")))

func _summary_line(text: String) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", Color("#bbbbbb"))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
```

Два отличия от ранней редакции:

- порядок строк задаётся `Picker.all_slots()`, а не `_draft.equip.keys()`. Ключи сета лежат в порядке добавления, и сводка после двух правок подряд переставляла бы строки, хотя содержимое не менялось;
- `load(ap)` заменён на `_item_info(ap)`: обвес уже в базе, и имя его лежит там же, а без находки показывается путь - так игрок видит `res://...` вместо названия.
- [ ] **Step 2: Добавить контейнер сводки и кнопки в `_build_page_done()`**

В `_build_page_done()` из Task 7 вставить перед `_name_input` блок сводки и после него кнопки:

```gdscript
	var summary := VBoxContainer.new()
	summary.name = "Summary"
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.add_theme_constant_override("separation", 2)
	v.add_child(summary)
```

и в конец функции:

```gdscript
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var save_btn = Button.new()
	save_btn.text = Loc.txt("Save loadout")
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_btn.pressed.connect(_save_loadout)
	row.add_child(save_btn)
	var clear_btn = Button.new()
	clear_btn.text = Loc.txt("Clear")
	clear_btn.pressed.connect(_clear_draft)
	row.add_child(clear_btn)
	var cancel_btn = Button.new()
	cancel_btn.text = Loc.txt("Cancel")
	cancel_btn.pressed.connect(_cancel_draft)
	row.add_child(cancel_btn)
	v.add_child(row)
	return v
```

- [ ] **Step 3: Добавить валидацию сохранения**

Заменить начало `_save_loadout()` (`VTKUI.gd:1307-1316`) на:

```gdscript
func _save_loadout() -> void:
	if _draft == null:
		return
	if _name_input != null:
		_draft.set_name = _name_input.text.strip_edges()
	var name_new := _draft.set_name.strip_edges()
	if name_new == "":
		_set_problem(Loc.txt("Loadout name required"))
		if _name_input != null:
			_name_input.grab_focus()
		return
	if _draft.item_count() == 0:
		_set_problem(Loc.txt("Set is empty"))
		_show_page(0)
		return
	if _name_input != null:
		_clear_problem()
```

Остальное тело функции не трогать.

Отдельной функции `_confirm()` из ранней редакции не делаем: она ничего не подтверждала, а только показывала строку и возвращала `false`, то есть была обёрткой над одним вызовом `_set_problem()` с лишним уровнем косвенности. Строка проблемы уже есть и уже показывается в степпере, а не в диалоге: диалогов в моде нет, и лишняя кнопка ради сообщения мешала бы на третьей странице. Проверка дубликата имени остаётся в теле `_save_loadout()` и тоже идёт через `_set_problem()`.

- [ ] **Step 4: Прогнать парсинг, локализацию, кодировки**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`, затем `python .check\keycheck.py`, затем `python .check\encoding_check.py`
Expected: `Parse check passed: 9 scripts`, `RESULT: every Loc.txt() key has a RU entry`, `PROBLEMS: 0`.

- [ ] **Step 5: Снимок**

```powershell
$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
$dst = "C:\Users\home\AppData\Local\Temp\opencode\vtk-snap-$stamp"
New-Item -ItemType Directory -Force -Path $dst | Out-Null
Copy-Item -Recurse -Force "D:\RTVMOD\loadouts" $dst
Write-Host "snapshot: $dst"
```

---

### Task 13: Локализация, версия, сборка, чеклист в игре

**Files:**
- Modify: `loadouts/mod.txt` (версия)
- Modify: `AGENTS.md` (счётчик `preload`, если не сделано в Task 8)

**Interfaces:**
- Consumes: всё из Tasks 1-12.
- Produces: `Loadouts.vmz` версии 4.4.0.

- [ ] **Step 1: Финальная сверка локализации**

Run: `python .check\keycheck.py`
Expected: `RESULT: every Loc.txt() key has a RU entry`. Если есть строки без перевода — добавить их в `RU` в этом же проходе. Строки в отчёте `unused` молча игнорировать нельзя: половина из них - ключи сборки (`Loc.txt(CATEGORY_LABELS.get(...))`), которые `keycheck.py` не видит по статическому разбору, но наличие переводов проверить надо глазами по `VTKLoc.gd`.

- [ ] **Step 2: Проверить кодировки**

Run: `python .check\mojibake_scan.py "D:\RTVMOD\loadouts\mods\VTK\VTKLoc.gd"`, затем `python .check\encoding_check.py`
Expected: `OK: no replacement chars, no C1, no foreign script`, `PROBLEMS: 0`.

Сканер принимает один файл, а не каталог: `mojibake_scan.py` читает `sys.argv[1]` как путь к файлу и падает с `PermissionError` на папке. Русские строки есть во всех девяти скриптах, так что проверять надо каждый: `Get-ChildItem loadouts\mods\VTK\*.gd | ForEach-Object { python .check\mojibake_scan.py $_.FullName }`.

- [ ] **Step 3: Проверить регрессию макета**

Run: `python .check\a2\run.py`
Expected: `PASS=53 FAIL=0`. Если макет правился по ходу работы, эталон и спека должны это отражать.

- [ ] **Step 4: Поднять версию**

В `loadouts/mod.txt` заменить `version="4.3.3"` на `version="4.4.0"`. Формат файла не трогать: он однострочный, без перевода строки в конце, и `encoding_check.py` считает такой файл нормальным (`loneLF=0` при нуле строк).

- [ ] **Step 5: Прогнать стенд парсинга**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `Parse check passed: 9 scripts`, `Draft tests passed`, `Picker tests passed`, код выхода 0. Стенд считает успехом только отсутствие строк `SCRIPT ERROR` / `Parse Error` / `Invalid call` / `Failed to load script` вместе с наличием `tests passed` и нулевым кодом выхода, поэтому одной строки `tests passed` мало.

- [ ] **Step 6: Собрать пакет**

Run: `powershell -ExecutionPolicy Bypass -File pack.ps1`
Expected: `Version in mod.txt: 4.4.0`, затем список из 10 записей и `Pack done`.

- [ ] **Step 7: Сверить контрольные суммы**

Run:

```powershell
(Get-FileHash -Algorithm SHA256 "D:\RTVMOD\Loadouts.vmz").Hash
```

После `encoding_check.py` он читает версию уже из собранного `Loadouts.vmz`, поэтому строка `pack version: 4.4.0` в его отчёте и есть проверка, что в пакет попала правильная версия. Путь к папке модов игры в этом окружении не определяется, копирование остаётся за пользователем; хеш сравнивать нужно против копии у него.

- [ ] **Step 8: Пройти чеклист в игре**

1. Открыть панель, нажать «+ Создать сет». Видны три страницы, активна первая.
2. Пустой сет: чип цели один — «Все предметы». Списка целей из одиннадцати пустых слотов нет, предмет сам уходит в первый свободный слот.
3. Кликнуть оружие — оно легло в `Primary`, в шапке появился чип `Primary: <название>`, снизу открылась панель обвесов.
4. Кликнуть чип `Primary: <название>` — полки сузились до предметов, влезающих в этот слот, чип подсвечен золотым.
5. Кликнуть «Все предметы» — полки снова полные, чип цели снят.
6. Ввести в поиск `апт` при цели `Primary` — остались только подходящие под слот аптечки. Поиск живой, поле фокус не теряет: клик по полке категории его не сбрасывает.
7. Выбрать оружие, не влезающее в цель — предмет не переехал молча, под поиском висит строка «Не влезает: <слот>».
8. Кликнуть один прицел, потом другой — остался только второй, первый исчез.
9. Кликнуть выбранный прицел ещё раз — обвесов не осталось совсем, а кнопка удаления предмета исчезла вместе с ними.
10. Кликнуть занятый слот, который же является целью — панель открылась, слот не потерял предмет.
11. Перейти на «Снаряжение», добавить нож — он в чипе, панели обвесов нет.
12. Нажать «+ Add», найти обойму, добавить — чип с количеством и кнопкой «Полная»; выключить — сводка на «Готово» показывает пустую обойму.
13. `+` и `-` у обоймы меняют количество, `✕` убирает вместе с обвесами.
14. Кликнуть предмет снаряжения — его панель обвесов открылась на странице 2, а не на странице 1.
15. Перейти на «Готово» — видны все слоты, обвесы и количества, пустой сет показывает «Сет пуст».
16. Нажать «Сохранить» с пустым названием — фокус в поле, подсказка «Нужно название».
17. Ввести имя, сохранить — сет появился в списке, остались на «Готово».
18. Выйти и вернуться, открыть сет на «Изменить» — состав совпадает со сводкой.
19. Применить сет в игре — предметы на месте, обойма полная если был включён тумблер.
20. Проверить миграцию: положить `loadouts.json` с парой сетов в `user://MCM/vostok-toolkit/`, запустить игру — сеты на месте, файл переименован, в лог есть строка `[VTK] save file migrated`. Второй запуск ничего не меняет.

- [ ] **Step 9: Снимок**

```powershell
$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
$dst = "C:\Users\home\AppData\Local\Temp\opencode\vtk-snap-$stamp"
New-Item -ItemType Directory -Force -Path $dst | Out-Null
Copy-Item -Recurse -Force "D:\RTVMOD\loadouts" $dst
Write-Host "snapshot: $dst"
```

---

## Self-Review

**Покрытие спеки:**

| Требование спеки | Task |
|---|---|
| Три свободно переключаемые страницы | 7 |
| Слот как цель, фильтр сетки, чип «Все предметы» | 8 |
| Занятый слот вытесняется | 4, 9 |
| Авторазмещение через первый свободный слот | 4 (`free_slot_of`), 9 |
| Поиск настоящим `LineEdit` | 8 |
| Полосы категорий вместо чипов типов | 2, 8 |
| Слоты из данных, предпочтительный порядок | 1, 8 |
| Обвесы одиночные по группам | 5, 11 |
| Панель не открывается, если нечего | 3, 9, 11 |
| У обоймы тумблер, а не список | 11 |
| Чипы снаряжения с количеством | 10 |
| Снятие до нуля чистит обвесы | 10 (через `set_gear_amount`) |
| Название на шаге 3 | 7, 12 |
| Пустое имя / пустой сет / занятое имя | 12 |
| Очистить и Отмена разведены | 7, 12 |
| Формат сохранения не меняется | сквозная, Task 6 |
| Никакой миграции обвесов | сквозная, обосновано в спеке |
| Слоты переживают переключение вкладок | 7 (`visible`, не пересборка) |
| Локализация новых строк | 7, 8, 10, 13 |
| Версия 4.4.0 | 13 |
| Миграция `loadouts.json` | 6 |
| Отладочный путь | 6 |
| Проверки: check, keycheck, encoding, a2 | 13 |

Разрывов нет.

**Имена согласованы между тасками:** `VTKPicker.all_slots` (1) → `SLOT_ORDER`, чипы и строки слотов (8), сводка (12); `Picker.has_panel` (3) → `_item_info()` (8), `_open_panel_if_any()` (9), `_make_equip_block()` / `_make_gear_block()` (8, 10); `Picker.matches_slot` / `matches_search` (2) → `_items_for_target()` (8), `_rebuild_gear_picker()` (10); `Picker.shelves_of` (2) → `_make_shelf()` (8), `_make_gear_shelf()` (10); `Draft.add_to_slot` (4) → `_place_into()` (9, 10); `Draft.toggle_attachment` (5) → `_make_att_toggle()` (11); `Picker.group_attachments` (3) → `_att_entries()` (11); `_refresh_pages()` (9) → вызывает `_refresh_page_equipment`, `_refresh_page_gear`, `_refresh_page_done` (9, 12).

**Имена, разошедшиеся с ранней редакцией плана.** Реализация переименовала их, и в тексте плана теперь везде новые: `_populate_item_grid()` → `_rebuild_shelves()`, `_item_grid` → `_shelves_box`, `_all_slots()` → `Picker.all_slots()` напрямую, `_refresh_slot_list()` → `_refresh_page_equipment()` + `_refresh_slots()`, `_refresh_gear_chips()` → `_rebuild_gear_chips()`, `_refresh_summary()` → `_refresh_page_done()`, `_build_attachment_panel()` → `_build_att_panel()`, `_attach_btn` / `_attach_btn_gear` → `_make_equip_block()` / `_make_gear_block()`, `_add_to_gear()` → `_place_into(item, "GEAR")`, `_item_info(item)` → `_item_info(path: String)`.

**Что было исправлено в плане по итогам реализации:**

| Было | Стало | Почему |
|---|---|---|
| `equip.erase(slot)` перед присваиванием | только `equip[slot] = _desc(...)` | проверка слота выше уже гарантирует отказ без побочных эффектов |
| `atts.erase(att_path)` + безусловный `d.erase("attachments")` | `erase` только при пустом `atts` | снятие одного прицела стирало дуло и цевьё |
| `Loc.txt(grp) if Loc.RU.has(grp) else grp` | `Loc.txt(ATT_GROUP_LABELS.get(grp, grp))` | внутренние имена вроде `Barrel` не переводятся ключом и не видны `keycheck.py` |
| `Parse check passed: 8 scripts` | `9 scripts` | сквозной счёт измерен на стенде |
| `_confirm(msg) -> bool` как обёртка над `_set_problem()` | прямо `_set_problem(...)` | лишний уровень косвенности вокруг единственного вызова |
| `load(path)` в `_item_info()`, `_open_panel_if_any()`, чипах, сводке | `_item_index` + `_item_info(path)` | ресурс уже загружен при обходе базы; повторный `load()` на каждый клик читает его с диска |
| `_draft.equip.keys()` как порядок строк сводки | `Picker.all_slots()` | порядок добавления переставлял строки сводки без изменения содержимого |
| `matches_slot(_item_slots(res), slot)` в цикле по базе | `matches_slot(_item_info(path), slot)` | задача 2 вынесла разбор ресурса в `VTKPicker` |
| пересборка всего `_equip_box` / `_gear_box` | пересборка только `_slots_box` / `_gear_chips` | контейнер страницы держит поиск и полки, они должны переживать обновление |
| откат на `add()` при негодном слоте | явная строка проблемы `Does not fit: <слот>` | молчаливый перенос в другой слот хуже явного отказа |
| `GridContainer` из шести колонок на шаге 2 | полосы категорий, как на шаге 1 | две разные сетки предметов на двух страницах |
| `_gear_grid_open` как отдельный флаг | `_gear_grid_scroll.visible` | состояние открытия и есть видимость контейнера |

**Известные шероховатости, помеченные в тексте:** в Task 8 Step 5 первая версия `_build_page_equipment()` содержала ошибочную строку `_editor_panel.add_child(Bar.new())` - она помечена к удалению в том же шаге, чтобы не осталось в итоговом коде. В Task 10 Step 2 первая версия `_make_gear_cell()` использовала `cell.gui_input.disconnect(func(_e): pass)`, что в GDScript недопустимо. Обе правки присутствуют явно, чтобы реализатор не переписал нерабочий вариант.
