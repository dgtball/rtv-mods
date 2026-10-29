# Двухколоночный picker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Перевести выбор предмета на две колонки: слева слоты на шаге «Экипировка» и категории-фасеты на шаге «Снаряжение», справа — каталог с плоской сеткой и панелью обвесов.

**Architecture:** Чистая логика группировки (`category_of`, `facets_of`) живёт в `VTKPicker.gd` и тестируется headless. Всё, что знает про ресурсы и узлы Godot, остаётся в `VTKUI.gd`. Обе страницы строятся один раз, обновление заменяет содержимое контейнеров, поэтому фокус в поиске и позиция скролла переживают перерисовку.

**Tech Stack:** Godot 4.6.3, GDScript, стенд `.check` на `godot --headless --check-only` плюс Python-проверки; макет и его стенд — `docs/mockups/picker-a2-interactive.html` и `.check/a2/run.py`.

Спека: `docs/superpowers/specs/2026-10-05-picker-facets-layout-design.md`

## Global Constraints

- Отступы в `.gd` — **только табы**. `encoding_check.py` ловит пробельный отступ и `MIXED-EOL`.
- Кодировка — UTF-8 **без BOM**. Новый русский текст проверять `python .check\mojibake_scan.py <файл>`.
- EOL: `VTKUI.gd`, `VTKPicker.gd`, `VTKData.gd` — **CRLF**. Остальные `.gd`, `.py`, `.md` — **LF**. После правки CRLF-файла убедиться, что Edit не оставил хвост из одиночных LF.
- Локализуется только обвязка мода. Имена предметов, типы и слоты приходят из `Database` как есть. Функция — `Loc.txt()`, не `tr()`.
- Новая строка в UI = новая запись в `RU` того же прохода. `keycheck.py` падает на рассинхроне.
- Ключ словаря `RU` — сама английская строка. Строка с кавычкой пишется в одинарных кавычках.
- Функция с путём `return null` обязана иметь аннотацию возврата (`-> Control`, `-> Variant`): иначе анализатор Godot 4 типизирует её как `null`, и следующий `x["key"]` даёт Parse Error на весь скрипт.
- Событие мыши ловим через `gui_input` на `Control`-клетке, а не через `LineEdit.gui_input`: Godot обрывает последний при потере фокуса.
- Git в репозитории **нет**. Откат — snapshot:

```powershell
$snap = "C:\Users\home\AppData\Local\Temp\opencode\vtk-snap-" + (Get-Date -Format "yyyyMMdd-HHmm")
New-Item -ItemType Directory -Force -Path $snap | Out-Null
Copy-Item -Recurse -Force "loadouts\mods\VTK" "$snap\VTK"
Copy-Item -Force "loadouts\mod.txt" "$snap\mod.txt"
$snap
```

- Перед сборкой версия поднимается в `loadouts\mod.txt`: здесь **4.4.0 → 4.5.0** (новая функциональность, формат сохранённых данных не меняется).
- Игра обновлялась уже после написания старого плана. Эта правка читает `item.slots`, `compatible` и `maxAmount`, поэтому перед Task 1 сверить их на живой базе: `slots` у гранат не должны исчезнуть из `Grenade_1`/`Grenade_2`, иначе группа «Гранаты» станет пустой и не покажется — это тихий дефект, стенд его не поймает.

Полный набор проверок после каждой задачи, где меняется код:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
python .check\keycheck.py
python .check\a2\run.py
python .check\encoding_check.py
```

---

### Task 1: Категория предмета по слотам

Граната лежит в слотах `Grenade_1`/`Grenade_2`, а её `type` в данных игры не grenade. Читать категорию по одному `type` — значит не набрать группу «Гранаты» ни на одной полке.

**Files:**
- Modify: `loadouts/mods/VTK/VTKPicker.gd:13-18` (`CATEGORY_ORDER`)
- Modify: `loadouts/mods/VTK/VTKPicker.gd` — константы и `category_of` сразу после `matches_slot` (конец строки 56)
- Test: `.check/project/tests/test_picker.gd`

**Interfaces:**
- Consumes: `matches_slot(slots, slot) -> bool` (строка 48)
- Produces: `const CATEGORY_GRENADE := "@grenade"`, `const GRENADE_SLOTS := ["Grenade_1", "Grenade_2"]`, `static func category_of(slots, type) -> String` — `"@grenade"`, либо `str(type).to_lower()`, либо `""`

- [x] **Step 1: Write the failing test**

В `.check/project/tests/test_picker.gd` добавить вызов в `_init()` после `t_shelves_of()`:

```gdscript
	t_category_of()
```

и новую функцию в конец файла (отступы — табы):

```gdscript
func t_category_of() -> void:
	ck(P.category_of(["Grenade_1"], "Consumable") == "@grenade", "слот-граната бьёт type")
	ck(P.category_of(["Grenade_2"], null) == "@grenade", "второй слот-граната тоже")
	ck(P.category_of(["Primary", "Grenade_1"], "Weapon") == "@grenade", "среди прочих слотов")
	ck(P.category_of(["Primary"], "Weapon") == "weapon", "без слота-гранаты это type в нижнем регистре")
	ck(P.category_of(null, "Medical") == "medical", "null slots не мешают type")
	ck(P.category_of(["Head"], null) == "", "без type предмет вне групп")
	ck(P.category_of(null, null) == "", "ни слотов ни типа - вне групп")
	ck(P.category_of("Grenade_1", "Weapon") == "weapon", "строка слотами не считается слотами")
	ck(P.CATEGORY_ORDER.has("@grenade"), "в порядке категорий есть гранаты")
```

- [x] **Step 2: Run test to verify it fails**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `Invalid call. Nonexistent function 'category_of'`, `VERDICT: fail test_picker.gd`.

- [x] **Step 3: Write minimal implementation**

В `VTKPicker.gd` в `CATEGORY_ORDER` вставить `"@grenade"` после `"armor"`:

```gdscript
const CATEGORY_ORDER := ["weapon", "armor", "@grenade", "ammo", "ammunition", "attachment",
	"medical", "consumable", "food", "equipment", "backpack", "clothing",
	"tool", "part", "valuable", "junk"]
```

Сразу после конца `matches_slot` вставить:

```gdscript
# Группа предмета для полок и фасетов. Слоты важнее type: граната лежит в
# Grenade_1/2, а её type в данных игры не grenade, и группа "Гранаты" по одному
# type не набралась бы. Виртуальный ключ начинается с @, чтобы не совпасть с
# типом из данных. Ни слотов ни type - предмет вне групп, не показываем.
const CATEGORY_GRENADE := "@grenade"
const GRENADE_SLOTS := ["Grenade_1", "Grenade_2"]

static func category_of(slots, type) -> String:
	for gs in GRENADE_SLOTS:
		if matches_slot(slots, str(gs)):
			return CATEGORY_GRENADE
	if type == null:
		return ""
	return str(type).to_lower()
```

- [x] **Step 4: Run test to verify it passes**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `VERDICT: ok test_picker.gd`, `Picker tests passed`, девять новых строк `ok`.

- [x] **Step 5: Откатная точка**

Snapshot по команде из Global Constraints.

---

### Task 2: Единая запись каталога

Полки шага 1 и каталог шага 2 читают один и тот же список предметов. Если категорию считать в двух местах по-разному, шаги разойдутся.

**Files:**
- Modify: `loadouts/mods/VTK/VTKPicker.gd:13-15` — комментарий над `CATEGORY_ORDER`
- Modify: `loadouts/mods/VTK/VTKUI.gd:1040-1052` (`_items_for_target`)
- Modify: `loadouts/mods/VTK/VTKUI.gd:780-788` (`_items_for_gear`)
- Modify: `loadouts/mods/VTK/VTKUI.gd:10-26` (`CATEGORY_LABELS`)
- Modify: `loadouts/mods/VTK/VTKLoc.gd` — запись `'Grenades'`

**Interfaces:**
- Consumes: `Picker.category_of(slots, type) -> String` (Task 1)
- Produces: `VTKUI._entry(it) -> Dictionary` — `{"item": Resource, "cat": String, "name": String}`

- [x] **Step 1: Добавить `_entry` и переключить оба источника**

В `VTKUI.gd` перед `func _items_for_target()` вставить:

```gdscript
# Запись каталога для Picker. Поле name дублируется из item, чтобы facets_of
# считал счётчики и фильтровал, не доставая Resource: чистой функции не
# полагается на то, что у предмета вообще есть имя.
func _entry(it) -> Dictionary:
	return {"item": it, "cat": Picker.category_of(it.get("slots"), it.get("type")),
		"name": str(it.get("name", ""))}
```

В `_items_for_target` и в `_items_for_gear` заменить одинаковую строку

```gdscript
		out.append({"item": it, "cat": str(it.get("type", "")).to_lower()})
```

на

```gdscript
		out.append(_entry(it))
```

- [x] **Step 2: Заголовок полки для гранат**

В `CATEGORY_LABELS` вставить перед закрывающей скобкой блока:

```gdscript
	"@grenade": "Grenades",
```

Ключ с `@` живёт в `CATEGORY_LABELS`, а не в `RU`: там лежат английские имена категорий, которые потом идут в `Loc.txt()`.

- [x] **Step 3: Запись в RU**

В `VTKLoc.gd` в `const RU` вставить по алфавиту между `'Grips'` и `'Interface language'`:

```gdscript
	'Grenades': 'Гранаты',
```

- [x] **Step 4: Убрать ссылку на то, что скоро удалят**

Над `CATEGORY_ORDER` в `VTKPicker.gd` сейчас написано «те же имена, что в _type_colors в VTKUI.gd»; `_type_colors` удаляется в Task 7. Заменить этот абзац:

```gdscript
# Порядок полок категорий. Значения - это то, что вернул category_of: обычно
# str(item.type).to_lower(), но у гранат виртуальный ключ "@grenade". Категория
# из данных, которой здесь нет, не теряется: уходит в конец по алфавиту.
```

- [x] **Step 5: Run test to verify it passes**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
python .check\keycheck.py
python .check\mojibake_scan.py loadouts\mods\VTK\VTKLoc.gd loadouts\mods\VTK\VTKPicker.gd
python .check\encoding_check.py
```

Expected: `Parse check passed: 9 scripts`, `RESULT: every Loc.txt() key has a RU entry`, `OK: no replacement chars`, `PROBLEMS: 0`.

- [x] **Step 6: Откатная точка**

Snapshot.

---

### Task 3: Фасеты категорий

Левая колонка шага 2 — список категорий со счётчиками. Счётчик обязан совпадать с тем, что окажется в сетке, поэтому считает `facets_of`, а не UI.

**Files:**
- Modify: `loadouts/mods/VTK/VTKPicker.gd` — `facets_of` сразу после `shelves_of` (конец строки 89)
- Test: `.check/project/tests/test_picker.gd`

**Interfaces:**
- Consumes: `matches_search(item_name, query) -> bool`, `CATEGORY_ORDER`
- Produces: `static func facets_of(items, query) -> Array` — строки `{"key": String, "items": Array, "count": int}`; первая строка с пустым `key` — «Все»

- [x] **Step 1: Write the failing test**

В `test_picker.gd` добавить в `_init()` после `t_category_of()`:

```gdscript
	t_facets_of()
```

и в конец файла:

```gdscript
func t_facets_of() -> void:
	var list: Array = [
		{"name": "АК-74", "cat": "weapon"},
		{"name": "Граната М50", "cat": "@grenade"},
		{"name": "Аптечка", "cat": "medical"},
		{"name": "АК-74У", "cat": "weapon"},
	]
	var f := P.facets_of(list, "")
	ck(f.size() == 4, "Все + weapon + гранаты + медицина")
	ck(str(f[0].get("key", "x")) == "" and int(f[0].get("count", -1)) == 4,
		"строка Все впереди и считает всё")
	ck(str(f[1].get("key", "")) == "weapon" and int(f[1].get("count", 0)) == 2,
		"вторым идёт weapon с двумя")
	ck(str(f[2].get("key", "")) == "@grenade" and int(f[2].get("count", 0)) == 1,
		"гранаты по слотам, а не по type")
	ck(str(f[3].get("key", "")) == "medical", "медицина последней по CATEGORY_ORDER")
	var q := P.facets_of(list, "ак")
	ck(int(q[0].get("count", -1)) == 2, "запрос сужает строку Все")
	ck(q.size() == 2, "пустые группы под запросом выпадают")
	ck(str(q[1].get("key", "")) == "weapon" and int(q[1].get("count", 0)) == 2,
		"счётчик фасета тоже пересчитан")
	var sum := 0
	for r in q:
		if str(r.get("key", "")) != "":
			sum += int(r.get("count", 0))
	ck(sum == int(q[0].get("count", -1)), "сумма фасетов равна Все: группы не пересекаются")
	var empty := P.facets_of([], "")
	ck(empty.size() == 1 and int(empty[0].get("count", -1)) == 0,
		"пустой каталог даёт только строку Все с нулём")
	ck(P.facets_of([null, "мусор"], "").size() == 1, "мусорные элементы пропускаются")
```

- [x] **Step 2: Run test to verify it fails**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `Invalid call. Nonexistent function 'facets_of'`, `VERDICT: fail test_picker.gd`.

- [x] **Step 3: Write minimal implementation**

В `VTKPicker.gd` после конца `shelves_of` вставить:

```gdscript
# Фасеты левой колонки шага 2: строка "Все" первой, затем по строке на
# категорию. Пустые под текущим запросом выпадают - иначе фасет вёл бы в
# пустую сетку. На вход - записи _entry: нужен name для поиска и cat для
# группировки. Счётчик строки равен числу её элементов, поэтому клик по фасету
# всегда открывает ровно то, что показано цифрой.
static func facets_of(items, query) -> Array:
	var all: Array = []
	var buckets: Dictionary = {}
	for e in items:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		if not matches_search(str(e.get("name", "")), query):
			continue
		all.append(e)
		var c := str(e.get("cat", ""))
		if c == "":
			continue
		if not buckets.has(c):
			buckets[c] = []
		buckets[c].append(e)
	var out: Array = [{"key": "", "items": all, "count": all.size()}]
	for c in CATEGORY_ORDER:
		if buckets.has(c):
			out.append({"key": c, "items": buckets[c], "count": buckets[c].size()})
			buckets.erase(c)
	var rest := buckets.keys()
	rest.sort()
	for c in rest:
		out.append({"key": str(c), "items": buckets[c], "count": buckets[c].size()})
	return out
```

- [x] **Step 4: Run test to verify it passes**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `Picker tests passed`, одиннадцать новых строк `ok`.

- [x] **Step 5: Откатная точка**

Snapshot.

---

### Task 4: Стенд раскладки и левая колонка шага 1

Ни один стенд не знает, что `+ Добавить` не должен вернуться, а боковая колонка — должна. Сначала появляется проверка символов, потом вёрстка, которую она охраняет.

**Files:**
- Create: `.check/layout_check.py`
- Modify: `loadouts/mods/VTK/VTKUI.gd:60` (`_gear_grid_open`), `:66-70` (переменные), `:427-445` (`_build_editor`), `:523-528` (`_reset_picker_state`), `:530-569` (`_page_wrap`, `_build_page_equipment`), `:905-1052` (`_refresh_page_equipment`, `_refresh_slots`, `_make_equip_block`, `_make_target_chip`)
- Modify: `loadouts/mods/VTK/VTKLoc.gd` — запись `'Slots'`

**Interfaces:**
- Consumes: `Picker.all_slots(slot_lists) -> Array`, `Picker.has_panel(info) -> bool`, `Draft.shown_count(desc) -> int`, `_make_step_btn(label) -> Button`, `_make_chip_style(active, hover) -> StyleBoxFlat`
- Produces: `const SIDE_WIDTH := 232`, `_page_columns(title, side, main) -> HBoxContainer`, `_make_slot_row(slot, desc) -> Control`, `_on_slot_row_input(ev, slot, desc) -> void`, `_rebuild_target_bar() -> void`, `_make_dot(color) -> Panel`, `_make_slot_style(active) -> StyleBoxFlat`, переменные `_side_slots_box: VBoxContainer` и `_target_bar: HBoxContainer`
- Удаляются: `_gear_grid_open`, `_slots_box` (переименован в `_side_slots_box`), `_make_target_chip`, `_make_equip_block`

Удаление `_make_equip_block` не убирает тумблер заполнения обоймы у экипировки: он жил в этой строке, а теперь открывается панелью обвесов — `_build_att_panel` для обоймы уже возвращает `_build_mag_panel` с `CheckButton`.

- [x] **Step 1: Создать стенд раскладки**

Создать `.check/layout_check.py` — LF, UTF-8 без BOM:

```python
# -*- coding: utf-8 -*-
"""Проверка раскладки picker по исходникам VTKUI.gd.

Стенд .check ловит парсинг, макет - дизайн. Ни один из них не знает, что кнопка
"+ Добавить" не должна вернуться, а боковая колонка - должна. Здесь ровно эта
проверка: символы, которых быть не должно, и символы, которые должны быть.

Списки пополняются вместе с задачами плана: каждая задача добавляет свои.

Использование: python .check\layout_check.py
"""
import io
import re
import sys

UI = r"D:\RTVMOD\loadouts\mods\VTK\VTKUI.gd"

GONE = [
    "_make_target_chip",
    "_make_equip_block",
]

GONE_RE = [
    (r"(?<!side_)\b_slots_box\b", "_slots_box без префикса side_"),
]

PRESENT = [
    "_page_columns",
    "SIDE_WIDTH := 232",
    "_make_slot_row",
    "_on_slot_row_input",
    "_make_dot",
    "_target_bar",
    "_side_slots_box",
]


def esc(s):
    return s.encode("ascii", "backslashreplace").decode("ascii")


def main():
    src = io.open(UI, encoding="utf-8").read()
    bad = 0
    for s in GONE:
        n = src.count(s)
        if n:
            bad += 1
            print("  GONE    %-34s встречается %d раз" % (esc(s), n))
    for pattern, what in GONE_RE:
        n = len(re.findall(pattern, src))
        if n:
            bad += 1
            print("  GONE-RE %-34s встречается %d раз" % (esc(what), n))
    for s in PRESENT:
        if src.count(s) == 0:
            bad += 1
            print("  MISS    %-34s не найдено" % esc(s))
    print("GONE: %d, GONE_RE: %d, PRESENT: %d" % (len(GONE), len(GONE_RE), len(PRESENT)))
    if bad:
        print("RESULT: раскладка разошлась с планом: %d" % bad)
        sys.exit(1)
    print("RESULT: символы раскладки на месте")


main()
```

- [x] **Step 2: Run the check to see it fail**

Run: `python .check\layout_check.py`
Expected: `RESULT: раскладка разошлась с планом: 9` — два `GONE` (`_make_target_chip`, `_make_equip_block`), один `GONE-RE` (`_slots_box` без префикса `side_`) и шесть `MISS` (`_page_columns`, `SIDE_WIDTH := 232`, `_make_slot_row`, `_on_slot_row_input`, `_target_bar`, `_side_slots_box`; `_make_dot` в коде уже был).

- [x] **Step 3: Переменные и сброс состояния**

Переименовать `var _slots_box: VBoxContainer = null` в `var _side_slots_box: VBoxContainer = null`, и сразу под ним добавить `var _target_bar: HBoxContainer = null`.

`var _equip_box` меняет тип на `HBoxContainer`: `_page_columns` возвращает `HBoxContainer`, и старая аннотация `VBoxContainer` даёт Parse Error.

В `_build_editor` заменить блок обнуления (строки 434-445) на:

```gdscript
	_gear_picker = null
	_gear_search_field = null
	_gear_chips = null
	_gear_shelves = null
	_gear_grid_scroll = null
	_shelves_box = null
	_side_slots_box = null
	_target_bar = null
	_equip_box = null
	_gear_box = null
	_page_label = null
```

Дубль `_gear_picker = null` во второй группе (строка 443) при этом исчезает — он был мусором.

`var _gear_grid_open` и его сбросы в `_reset_picker_state` и `_set_target_slot` остаются на этом шаге нетронутыми: сам механизм сворачиваемой сетки удаляется в Task 5, и удалять его здесь означало бы оставить файл непарсящимся. В `GONE` стенда он тоже не появляется до Task 5.

- [x] **Step 4: Каркас двух колонок**

В `VTKUI.gd` сразу после конца `_page_wrap()` вставить:

```gdscript
# Ширина левой колонки. В макете 216, но в игре в строке слота ещё живут
# снятие предмета и тумблер заполнения обоймы, и 216 впритык.
const SIDE_WIDTH := 232

# Каркас страницы: слева колонка выбора, справа предметы. Ширина колонки
# задаётся здесь единожды, иначе шаги разъедутся на пиксель и перестанут
# выглядеть одной сеткой.
func _page_columns(title: String, side: Control, main: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_theme_constant_override("separation", 6)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(SIDE_WIDTH, 0)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color("#171208")
	ps.border_color = _dark_border
	ps.border_width_right = 1
	ps.content_margin_left = 6
	ps.content_margin_right = 6
	ps.content_margin_top = 4
	ps.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", ps)

	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 4)
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color("#5f5347"))
	sv.add_child(lbl)
	sv.add_child(side)
	panel.add_child(sv)
	h.add_child(panel)

	var mv := VBoxContainer.new()
	mv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mv.add_theme_constant_override("separation", 4)
	mv.add_child(main)
	h.add_child(mv)
	return h
```

- [x] **Step 5: Пересобрать страницу шага 1**

Заменить тело `_build_page_equipment()`:

```gdscript
func _build_page_equipment() -> Control:
	var main := _page_wrap()

	# Шапка цели: чем заполнен слот-цель и сброс на "все предметы". Список
	# занятых слотов чипами больше не нужен - левая колонка и есть этот список.
	_target_bar = HBoxContainer.new()
	_target_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_target_bar.add_theme_constant_override("separation", 4)
	main.add_child(_target_bar)

	# Поиск живёт над сеткой и обновляет её на лету. text_changed, а не
	# gui_input: у LineEdit gui_input при потере фокуса Godot обрывает, и
	# вторая вкладка с первого раза роняла бы редактор.
	var search := LineEdit.new()
	search.placeholder_text = Loc.txt("Search items...")
	search.add_theme_color_override("font_color", Color("#ffffff"))
	search.add_theme_color_override("placeholder_color", Color("#666666"))
	search.add_theme_stylebox_override("normal", _make_dark_style())
	search.add_theme_stylebox_override("focus", _make_dark_style())
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_changed.connect(func(t): _set_search(t))
	main.add_child(search)

	var shelves_scroll := ScrollContainer.new()
	shelves_scroll.custom_minimum_size = Vector2(0, 240)
	shelves_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shelves_box = VBoxContainer.new()
	_shelves_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shelves_box.add_theme_constant_override("separation", 6)
	shelves_scroll.add_child(_shelves_box)
	main.add_child(shelves_scroll)

	_side_slots_box = VBoxContainer.new()
	_side_slots_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side_slots_box.add_theme_constant_override("separation", 3)

	_equip_box = _page_columns(Loc.txt("Slots"), _side_slots_box, main)
	return _equip_box
```

- [x] **Step 6: Строки слотов**

Заменить тело `_refresh_slots()`:

```gdscript
func _refresh_slots() -> void:
	if _side_slots_box == null:
		return
	for child in _side_slots_box.get_children():
		_side_slots_box.remove_child(child)
		child.queue_free()
	if _draft == null:
		return
	# Порядок берём из Picker.all_slots, чтобы ряд был одинаковым от сета к
	# сету, а не в порядке ключей словаря.
	var lists: Array = []
	for k in _draft.equip.keys():
		lists.append([str(k)])
	for slot in Picker.all_slots(lists):
		var s := str(slot)
		var desc = _draft.equip.get(s, {})
		if typeof(desc) != TYPE_DICTIONARY:
			desc = {}
		_side_slots_box.add_child(_make_slot_row(s, desc))
```

На место удалённых `_make_equip_block` и `_make_target_chip` вставить:

```gdscript
# Строка слота в левой колонке: тег, точка занятости, имя, метка обвесов и
# снятие предмета. Панель обвесов открывается кликом по строке цели и живёт в
# правой колонке, поэтому в строке нужен только маркер "у этого есть обвесы".
func _make_slot_row(slot: String, desc: Dictionary) -> Control:
	var occupied := not desc.is_empty()
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 22)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_theme_stylebox_override("panel", _make_slot_style(_target_slot == slot))
	row.gui_input.connect(func(ev): _on_slot_row_input(ev, slot, desc))

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(hb)

	var tag := Label.new()
	tag.text = slot
	tag.add_theme_font_size_override("font_size", 9)
	tag.add_theme_color_override("font_color", Color("#8a7a6a"))
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(tag)

	# Точка отвечает на "есть предмет", а не на категорию, поэтому её цвет не
	# связан с палитрой категорий и переживает отказ от них.
	hb.add_child(_make_dot(_gold if occupied else Color("#2a1f14")))

	var nm := Label.new()
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if occupied:
		var cnt := Draft.shown_count(desc)
		nm.text = str(desc.get("name", "?"))
		if cnt > 1:
			nm.text += " x" + str(cnt)
		nm.tooltip_text = str(desc.get("path", ""))
		nm.add_theme_color_override("font_color", Color("#d8cdbe"))
		if Picker.has_panel(_item_info(str(desc.get("path", "")))):
			var mark := Label.new()
			mark.text = "◆"
			mark.add_theme_font_size_override("font_size", 8)
			mark.add_theme_color_override("font_color", _gold)
			mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hb.add_child(mark)
	else:
		nm.text = Loc.txt("Empty")
		nm.add_theme_color_override("font_color", Color("#4d443a"))
	hb.add_child(nm)

	if occupied:
		var drop := _make_step_btn("x")
		drop.tooltip_text = Loc.txt("Remove")
		drop.pressed.connect(func(): _remove_slot(slot))
		hb.add_child(drop)
	return row

# Клик по строке слота: строка становится целью, а клик по текущей цели с
# предметом открывает панель обвесов. Иначе обвесы пришлось бы искать
# отдельной кнопкой, а в строке шириной 232 для неё нет места.
func _on_slot_row_input(ev: InputEvent, slot: String, desc: Dictionary) -> void:
	var mb := ev as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var path_now := str(desc.get("path", ""))
	if path_now != "" and _target_slot == slot:
		_toggle_attachment_panel(path_now)
		return
	_set_target_slot(slot)

func _make_slot_style(active: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#2a1a0a") if active else Color("#1a1510")
	s.border_color = _gold if active else Color("#241b12")
	s.border_width_all = 1
	s.corner_radius_all = 3
	s.content_margin_left = 4
	s.content_margin_right = 4
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	return s

# Точка-индикатор 7x7. Отдельный узел, а не символ в тексте: цвет задаётся
# стилем и не зависит от шрифта игры.
func _make_dot(color: Color) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(7, 7)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_all = 2
	p.add_theme_stylebox_override("panel", s)
	return p

# Шапка цели: имя слота-цели и кнопка сброса. Показывать все занятые слоты
# чипами больше не нужно - левая колонка и есть этот список.
func _rebuild_target_bar() -> void:
	if _target_bar == null:
		return
	for child in _target_bar.get_children():
		_target_bar.remove_child(child)
		child.queue_free()
	if _target_slot != "":
		var tgt := Label.new()
		tgt.text = Loc.txt("Target: ") + _target_slot
		tgt.add_theme_font_size_override("font_size", 10)
		tgt.add_theme_color_override("font_color", _gold)
		_target_bar.add_child(tgt)
	var b := Button.new()
	b.text = Loc.txt("All items")
	b.add_theme_font_size_override("font_size", 10)
	b.tooltip_text = Loc.txt("All items")
	var on := _target_slot == ""
	b.add_theme_stylebox_override("normal", _make_chip_style(on))
	b.add_theme_color_override("font_color", _gold if on else Color("#cccccc"))
	b.pressed.connect(func(): _set_target_slot(""))
	_target_bar.add_child(b)
```

- [x] **Step 7: Подключить шапку к обновлению**

Заменить тело `_refresh_page_equipment()`:

```gdscript
func _refresh_page_equipment() -> void:
	_rebuild_target_bar()
	_refresh_slots()
	_rebuild_shelves()
```

- [x] **Step 8: Запись в RU**

В `VTKLoc.gd` вставить по алфавиту между `'Sets'` и `'Set is empty'`:

```gdscript
	'Slots': 'Слоты',
```

- [x] **Step 9: Run all checks to verify it passes**

Run:

```powershell
python .check\layout_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
python .check\keycheck.py
python .check\a2\run.py
python .check\encoding_check.py
python .check\mojibake_scan.py loadouts\mods\VTK\VTKUI.gd loadouts\mods\VTK\VTKLoc.gd
```

Expected: `RESULT: символы раскладки на месте`, `Parse check passed: 9 scripts`, `RESULT: every Loc.txt() key has a RU entry`, `PASS=77 FAIL=0`, `PROBLEMS: 0`, `OK: no replacement chars`.

- [x] **Step 10: Откатная точка**

Snapshot.

---

### Task 5: Фасеты и постоянно открытый каталог шага 2

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd:66-71` (переменные), `:427-445` (`_build_editor`), `:523-528` (`_reset_picker_state`), `:571-608` (`_build_page_gear`), `:610-612` (`_refresh_page_gear`), `:745-812` (`_toggle_gear_picker`, `_set_gear_search`, `_rebuild_gear_picker`, `_make_gear_shelf`)
- Modify: `loadouts/mods/VTK/VTKUI.gd` — `_set_gear_facet`, `_on_facet_input`, `_refresh_gear_catalog`
- Modify: `.check/layout_check.py` — списки `GONE` и `PRESENT`
- Modify: `loadouts/mods/VTK/VTKLoc.gd` — запись `'Categories'`, удаление `'+ Add'` и `'- Add'`

**Interfaces:**
- Consumes: `Picker.facets_of(items, query) -> Array` (Task 3), `_items_for_gear() -> Array`, `_make_item_cell(item, forced_slot) -> Control`, `_make_slot_style(active) -> StyleBoxFlat`, `_make_dot(color) -> Panel` (Task 4)
- Produces: `static` — нет; UI — `_refresh_gear_catalog() -> void`, `_rebuild_gear_facets(facets: Array) -> void`, `_rebuild_gear_grid(facets: Array) -> void`, `_facet_items(facets: Array, key: String) -> Array`, `_make_facet_row(facet: Dictionary) -> Control`, `_on_facet_input(ev, key) -> void`, `_set_gear_facet(key: String) -> void`, переменные `_gear_facet_key: String`, `_gear_facets_box: VBoxContainer`, `_gear_grid: GridContainer`
- Удаляются: `_gear_picker`, `_gear_shelves`, `_toggle_gear_picker`, `_rebuild_gear_picker`, `_make_gear_shelf`

- [x] **Step 1: Расширить стенд раскладки**

В `.check/layout_check.py` в `GONE` дописать:

```python
    "_gear_grid_open",
    "+ Add",
    "- Add",
    "_toggle_gear_picker",
    "_gear_picker",
    "_make_gear_shelf",
    "_gear_shelves",
```

в `PRESENT` дописать:

```python
    "_make_facet_row",
    "_on_facet_input",
    "_set_gear_facet",
    "_refresh_gear_catalog",
    "_gear_facets_box",
    "_gear_grid",
    "_gear_facet_key",
    "Picker.facets_of",
```

- [x] **Step 2: Run the check to see it fail**

Run: `python .check\layout_check.py`
Expected: `RESULT: раскладка разошлась с планом: 9` — один `GONE` (`_gear_grid_open`, механизм сворачиваемой сетки ещё жив) и восемь `MISS`. `_make_target_chip`, `_make_equip_block` и одиночный `_slots_box` убраны уже в Task 4, поэтому в `GONE` они больше не срабатывают.

- [x] **Step 3: Переменные**

В блоке переменных заменить `var _gear_picker: Button = null` и `var _gear_shelves: VBoxContainer = null` на:

```gdscript
var _gear_facet_key: String = ""
var _gear_facets_box: VBoxContainer = null
var _gear_grid: GridContainer = null
```

В `_build_editor` заменить строки `_gear_picker = null` и `_gear_shelves = null` на:

```gdscript
	_gear_facets_box = null
	_gear_grid = null
	_gear_facet_key = ""
```

В `_reset_picker_state` добавить строку:

```gdscript
	_gear_facet_key = ""
```

- [x] **Step 4: Пересобрать страницу шага 2**

Заменить тело `_build_page_gear()`:

```gdscript
func _build_page_gear() -> Control:
	var main := _page_wrap()

	# Чипы снаряжения идут первыми: это выбранное, его и правят. Поиск ниже
	# относится к каталогу, а не к этим чипам.
	_gear_chips = VBoxContainer.new()
	_gear_chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gear_chips.add_theme_constant_override("separation", 2)
	main.add_child(_gear_chips)

	# Отдельное поле поиска: запрос шага 1 относится к выбору предмета в слот
	# и не должен молча фильтровать снаряжение, и наоборот.
	var search := LineEdit.new()
	search.placeholder_text = Loc.txt("Search items...")
	search.add_theme_color_override("font_color", Color("#ffffff"))
	search.add_theme_color_override("placeholder_color", Color("#666666"))
	search.add_theme_stylebox_override("normal", _make_dark_style())
	search.add_theme_stylebox_override("focus", _make_dark_style())
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_changed.connect(func(t): _set_gear_search(t))
	_gear_search_field = search
	main.add_child(search)

	# Каталог всегда открыт: он и раньше был длиннее окна, поэтому кнопка
	# раскрытия только добавляла лишний клик к выбору предмета.
	_gear_grid_scroll = ScrollContainer.new()
	_gear_grid_scroll.custom_minimum_size = Vector2(0, 238)
	_gear_grid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gear_grid = GridContainer.new()
	_gear_grid.columns = 4
	_gear_grid.add_theme_constant_override("h_separation", 5)
	_gear_grid.add_theme_constant_override("v_separation", 5)
	_gear_grid_scroll.add_child(_gear_grid)
	main.add_child(_gear_grid_scroll)

	_gear_facets_box = VBoxContainer.new()
	_gear_facets_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gear_facets_box.add_theme_constant_override("separation", 3)

	_gear_box = _page_columns(Loc.txt("Categories"), _gear_facets_box, main)
	return _gear_box
```

- [x] **Step 5: Фасеты и сетка одним проходом**

Строка «Все предметы» в фасетах переиспользует существующий ключ `All items`, а не добавляет почти такой же «Все»: в колонке 232 px надпись с цифрой помещается, а лишний ключ в `RU` жил бы ради одной строки.

Заменить тело `_refresh_page_gear()`:

```gdscript
func _refresh_page_gear() -> void:
	_rebuild_gear_chips()
	_refresh_gear_catalog()
```

Удалить `_toggle_gear_picker` и `_make_gear_shelf`. Заменить тело `_rebuild_gear_picker()` и добавить рядом четыре новых функции:

```gdscript
# Фасеты и сетка считаются одним проходом по списку предметов: facets_of
# фильтрует и группирует его целиком, а считать дважды - значит фильтровать
# дважды.
func _refresh_gear_catalog() -> void:
	var facets: Array = []
	if _draft != null:
		facets = Picker.facets_of(_items_for_gear(), _gear_search)
	_rebuild_gear_facets(facets)
	_rebuild_gear_grid(facets)

# Фасеты левой колонки: строки категорий со счётчиками. Цифра считается по
# текущему запросу, поэтому всегда равна тому, что окажется в сетке после клика.
func _rebuild_gear_facets(facets: Array) -> void:
	if _gear_facets_box == null:
		return
	for child in _gear_facets_box.get_children():
		_gear_facets_box.remove_child(child)
		child.queue_free()
	if _draft == null:
		return
	for f in facets:
		_gear_facets_box.add_child(_make_facet_row(f))

# Строка фасета: точка, название, счётчик. Точка у всех строк одного цвета -
# она помечает строку как переключатель, а категорию называет текст. Клик по
# активной строке ничего не меняет: вернуться к «всем предметам» можно только
# кликом по строке «Все предметы» - случайный повторный клик по своей же
# строке не должен сбрасывать выбор.
func _make_facet_row(facet: Dictionary) -> Control:
	var key := str(facet.get("key", ""))
	var active := _gear_facet_key == key
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 20)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_theme_stylebox_override("panel", _make_slot_style(active))
	row.gui_input.connect(func(ev): _on_facet_input(ev, key))

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(hb)
	hb.add_child(_make_dot(Color("#5f5347")))

	var nm := Label.new()
	nm.text = Loc.txt("All items") if key == "" else Loc.txt(str(CATEGORY_LABELS.get(key, key)))
	nm.add_theme_font_size_override("font_size", 10)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nm.add_theme_color_override("font_color", _gold if active else Color("#d8cdbe"))
	hb.add_child(nm)

	var cnt := Label.new()
	cnt.text = str(int(facet.get("count", 0)))
	cnt.add_theme_font_size_override("font_size", 10)
	cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cnt.add_theme_color_override("font_color", Color("#8a7a6a"))
	hb.add_child(cnt)
	return row

func _on_facet_input(ev: InputEvent, key: String) -> void:
	var mb := ev as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	_set_gear_facet(key)

# Фасет меняет только набор клеток: предметы из набора не уходят, поэтому
# открытая панель обвесов остаётся уместной.
func _set_gear_facet(key: String) -> void:
	_gear_facet_key = key
	_refresh_gear_catalog()

func _facet_items(facets: Array, key: String) -> Array:
	for f in facets:
		if str(f.get("key", "")) == key:
			return f.get("items", [])
	return []

# Плоская сетка вместо полок: категорию уже называет подсвеченная строка слева,
# а второй заголовок над теми же предметами только путает. Клетка уходит с
# пустым слотом - слот-цель принадлежит шагу 1.
func _rebuild_gear_grid(facets: Array) -> void:
	if _gear_grid == null:
		return
	for child in _gear_grid.get_children():
		_gear_grid.remove_child(child)
		child.queue_free()
	var found := _facet_items(facets, _gear_facet_key)
	if found.is_empty():
		var note := Label.new()
		note.text = Loc.txt("Nothing fits")
		note.add_theme_font_size_override("font_size", 11)
		note.add_theme_color_override("font_color", Color("#666666"))
		_gear_grid.add_child(note)
		return
	for entry in found:
		var res = entry.get("item")
		if res == null:
			continue
		_gear_grid.add_child(_make_item_cell(res, ""))
```

Заменить тело `_set_gear_search()`:

```gdscript
func _set_gear_search(t: String) -> void:
	_gear_search = t
	# Только каталог: пересборка страницы пересоздала бы поле поиска и выкинула
	# бы из него курсор на каждом символе.
	_refresh_gear_catalog()
```

- [x] **Step 6: Локализация**

В `VTKLoc.gd` вставить по алфавиту между `'Chest rig'` и `'Clothing'`:

```gdscript
	'Categories': 'Категории',
```

Удалить из `const RU` строки `'+ Add': '+ Добавить',` и `'- Add': '− Добавить',` — кнопки раскрытия больше нет, и `keycheck.py` покажет их как устаревшие. В `VTKUI.gd` строк `Loc.txt("+ Add")` и `Loc.txt("- Add")` после Task 5 не остаётся.

В Task 5 меняются типы ещё двух переменных: `var _gear_box: VBoxContainer` на `HBoxContainer` (его тоже возвращает `_page_columns`), а `_items_for_gear()` перестаёт фильтровать поиском — `facets_of` применяет запрос сам, и двойной фильтр ломал бы счётчики фасетов.

- [x] **Step 7: Run all checks to verify it passes**

Run:

```powershell
python .check\layout_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
python .check\keycheck.py
python .check\a2\run.py
python .check\encoding_check.py
```

Expected: `RESULT: символы раскладки на месте`, `Parse check passed: 9 scripts`, `RESULT: every Loc.txt() key has a RU entry`, `PASS=77 FAIL=0`, `PROBLEMS: 0`. Строк `'+ Add'` и `'- Add'` в отчёте `keycheck.py` больше нет; оставшиеся 26 записей `unused RU entries` — это названия категорий, они передаются в `Loc.txt()` динамически через `CATEGORY_LABELS.get()` и не могут быть найдены статически.

- [x] **Step 8: Откатная точка**

Snapshot.

---

### Task 6: Панель обвесов в правой колонке

После переноса слотов в боковую колонку панель обвесов оказалась бы среди строк слота. В макете она под каталогом, в правой колонке — там же.

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd:66-71` (переменные), `:427-445` (`_build_editor`), `:536-569` (`_build_page_equipment`), `:571-608` (`_build_page_gear`), `:610-612` (`_refresh_page_gear`), `:629-645` (`_rebuild_gear_chips`, `_make_gear_block`), `:905-913` (`_refresh_pages`, `_refresh_page_equipment`), `:1565-1586` (`_make_att_toggle`)
- Modify: `.check/layout_check.py` — списки `GONE` и `PRESENT`

**Interfaces:**
- Consumes: `_build_att_panel(path) -> Control`, `_make_chip_style(active, hover) -> StyleBoxFlat`, `_open_att_path: String`
- Produces: `_rebuild_att_box(host: VBoxContainer, path: String) -> void`, переменные `_equip_att_box: VBoxContainer`, `_gear_att_box: VBoxContainer`
- Удаляется: `_make_gear_block`

- [x] **Step 1: Расширить стенд раскладки**

В `GONE` дописать:

```python
    "_make_gear_block",
    '"[x] "',
    '"[ ] "',
```

в `PRESENT` дописать:

```python
    "_rebuild_att_box",
    "_equip_att_box",
    "_gear_att_box",
```

- [x] **Step 2: Run the check to see it fail**

Run: `python .check\layout_check.py`
Expected: `RESULT: раскладка разошлась с планом: 6` — три `GONE` и три `MISS`.

- [x] **Step 3: Переменные и контейнеры**

После `var _done_summary: VBoxContainer = null` добавить:

```gdscript
var _equip_att_box: VBoxContainer = null
var _gear_att_box: VBoxContainer = null
```

В `_build_editor` рядом с обнулением прочих контейнеров добавить:

```gdscript
	_equip_att_box = null
	_gear_att_box = null
```

В `_build_page_equipment` после `main.add_child(shelves_scroll)` добавить:

```gdscript
	_equip_att_box = VBoxContainer.new()
	_equip_att_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(_equip_att_box)
```

В `_build_page_gear` после `main.add_child(_gear_grid_scroll)` добавить:

```gdscript
	_gear_att_box = VBoxContainer.new()
	_gear_att_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(_gear_att_box)
```

- [x] **Step 4: Перерисовка панели**

Заменить тело `_refresh_page_equipment()`:

```gdscript
func _refresh_page_equipment() -> void:
	_rebuild_target_bar()
	_refresh_slots()
	_rebuild_shelves()
	_rebuild_att_box(_equip_att_box, _open_att_path)
```

Заменить тело `_refresh_page_gear()`:

```gdscript
func _refresh_page_gear() -> void:
	_rebuild_gear_chips()
	_refresh_gear_catalog()
	_rebuild_att_box(_gear_att_box, _open_att_path)
```

Добавить рядом с `_build_att_panel` новую функцию:

```gdscript
# Панель обвесов живёт в правой колонке под каталогом, а не рядом со строкой
# слота: после переноса слотов в боковую колонку она оказалась бы среди строк.
# Один _open_att_path на обе страницы - страницы показываются по одной, поэтому
# открытая панель не дублируется.
func _rebuild_att_box(host: VBoxContainer, path: String) -> void:
	if host == null:
		return
	for child in host.get_children():
		host.remove_child(child)
		child.queue_free()
	if path == "":
		return
	var panel := _build_att_panel(path)
	if panel != null:
		host.add_child(panel)
```

- [x] **Step 5: Чип снаряжения без своей панели**

Удалить `_make_gear_block` целиком и заменить в `_rebuild_gear_chips` строку

```gdscript
		_gear_chips.add_child(_make_gear_block(desc))
```

на

```gdscript
		_gear_chips.add_child(_make_gear_chip(desc))
```

- [x] **Step 6: Кнопка обвеса без префикса**

В `_make_att_toggle` заменить блок с `b.text` и цветами на:

```gdscript
	var on := bool(a.get("on", false))
	# Выбранный обвес выделяется цветом и рамкой, как строка фасета. Префикс
	# "[x] " съедал ширину кнопки и ломал вёрстку на длинных названиях.
	b.text = str(a.get("name", "?"))
	b.tooltip_text = att_path
	b.add_theme_font_size_override("font_size", 10)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 20)
	b.add_theme_stylebox_override("normal", _make_chip_style(on))
	b.add_theme_color_override("font_color", _gold if on else Color("#bbb"))
```

Строку `var on := bool(a.get("on", false))` из старого блока удалить — она теперь объявлена в новом.

- [x] **Step 7: Run all checks to verify it passes**

Run:

```powershell
python .check\layout_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
python .check\keycheck.py
python .check\a2\run.py
python .check\encoding_check.py
```

Expected: `RESULT: символы раскладки на месте`, `Parse check passed: 9 scripts`, `RESULT: every Loc.txt() key has a RU entry`, `PASS=77 FAIL=0`, `PROBLEMS: 0`.

- [x] **Step 8: Откатная точка**

Snapshot.

---

### Task 7: Отказ от цветов категорий

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd:93-109` (`_type_colors`), `:258-261` (`_cat_color`), `:1073-1095` (`_make_shelf`)
- Modify: `.check/layout_check.py` — список `GONE`

**Interfaces:**
- Consumes: ничего нового
- Produces: ничего нового; удаляются `_type_colors: Dictionary` и `_cat_color(cat: String) -> Color`

- [x] **Step 1: Расширить стенд раскладки**

В `GONE` дописать:

```python
    "_type_colors",
    "_cat_color",
```

- [x] **Step 2: Run the check to see it fail**

Run: `python .check\layout_check.py`
Expected: две строки `GONE`, `RESULT: раскладка разошлась с планом: 2`.

- [x] **Step 3: Удалить словарь и функцию**

Удалить целиком `var _type_colors: Dictionary = { ... }` (строки 93-109, 17 строк) и `_cat_color` (строки 258-261):

```gdscript
func _cat_color(cat: String) -> Color:
	# _type_colors живёт в игровом регистре ("Armor"), категории - в нижнем
	return _type_colors.get(cat.capitalize(), Color("#8a7a5a"))
```

- [x] **Step 4: Заголовок полки нейтральным цветом**

В `_make_shelf` заменить

```gdscript
	head.add_theme_color_override("font_color", _cat_color(cat))
```

на

```gdscript
	head.add_theme_color_override("font_color", Color("#d8cdbe"))
```

- [x] **Step 5: Проверить, что других вызовов не осталось**

Run: `rg -n "_cat_color|_type_colors" loadouts\mods\VTK`
Expected: вывод пустой. Если найдено — править те места тем же способом.

- [x] **Step 6: Run all checks to verify it passes**

Run:

```powershell
python .check\layout_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
python .check\keycheck.py
python .check\a2\run.py
python .check\encoding_check.py
```

Expected: `RESULT: символы раскладки на месте`, `Parse check passed: 9 scripts`, `PASS=77 FAIL=0`, `PROBLEMS: 0`.

- [x] **Step 7: Откатная точка**

Snapshot.

---

### Task 8: Шаг 3 в две колонки

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd:71` (переменные), `:427-445` (`_build_editor`), `:835-838` (`_done_summary`), `:859-901` (`_refresh_page_done`, `_summary_line`)
- Modify: `.check/layout_check.py` — список `PRESENT`

**Interfaces:**
- Consumes: `Picker.all_slots(slot_lists) -> Array`, `Draft.shown_count(desc) -> int`, `Draft.is_full(desc) -> bool`, `_is_magazine(path) -> bool`, `_item_info(path) -> Dictionary`, `_summary_line(text, color) -> Label`
- Produces: `_equip_row_text(slot, desc) -> String`, `_summary_head(text) -> Label`, `_gear_mag_tail(desc) -> String`, переменные `_done_equip_col: VBoxContainer`, `_done_gear_col: VBoxContainer`; `_done_summary` меняет тип с `VBoxContainer` на `HBoxContainer`

Счётчик `xN` в строке экипировки ставится только при `cnt > 1`: у одиночного предмета единица ничего не сообщает, а колонка узкая. Обвесы идут через ` + ` поимённо — по старому хвосту `rnd. N` нельзя было понять, что надето, и набор приходилось проверять, открывая панель. Путь без найденного имени откатывается к имени файла, чтобы строка не осталась с пустым хвостом.

- [x] **Step 1: Расширить стенд раскладки**

В `PRESENT` дописать:

```python
    "_done_equip_col",
    "_done_gear_col",
    "_summary_head",
    "_gear_mag_tail",
```

- [x] **Step 2: Run the check to see it fail**

Run: `python .check\layout_check.py`
Expected: четыре строки `MISS`, `RESULT: раскладка разошлась с планом: 4`.

- [x] **Step 3: Переменные**

Строку `var _done_summary: VBoxContainer = null` заменить на:

```gdscript
var _done_summary: HBoxContainer = null
var _done_equip_col: VBoxContainer = null
var _done_gear_col: VBoxContainer = null
```

В `_build_editor` рядом с `_done_summary = null` добавить:

```gdscript
	_done_equip_col = null
	_done_gear_col = null
```

- [x] **Step 4: Каркас сводки**

В `_build_page_done` заменить блок создания `_done_summary` (строки 835-838) на:

```gdscript
	# Две колонки, как в макете: в плоском списке не видно, где кончается один
	# раздел и начинается другой.
	_done_summary = HBoxContainer.new()
	_done_summary.add_theme_constant_override("separation", 8)
	_done_equip_col = VBoxContainer.new()
	_done_equip_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_done_equip_col.add_theme_constant_override("separation", 1)
	_done_gear_col = VBoxContainer.new()
	_done_gear_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_done_gear_col.add_theme_constant_override("separation", 1)
	_done_summary.add_child(_done_equip_col)
	_done_summary.add_child(_done_gear_col)
	v.add_child(_done_summary)
```

- [x] **Step 5: Наполнение сводки**

Заменить тело `_refresh_page_done()`:

```gdscript
func _refresh_page_done() -> void:
	if _done_summary == null or _done_equip_col == null or _done_gear_col == null:
		return
	for col in [_done_equip_col, _done_gear_col]:
		for child in col.get_children():
			col.remove_child(child)
			child.queue_free()
	if _draft == null:
		return
	_done_equip_col.add_child(_summary_head(Loc.txt("Equipment")))
	_done_gear_col.add_child(_summary_head(Loc.txt("Gear")))
	if _draft.item_count() == 0:
		_done_equip_col.add_child(_summary_line(Loc.txt("Set is empty"), Color("#666666")))
		return
	var lists: Array = []
	for k in _draft.equip.keys():
		lists.append([str(k)])
	var any_eq := false
	for slot in Picker.all_slots(lists):
		var desc = _draft.equip.get(str(slot), {})
		if typeof(desc) != TYPE_DICTIONARY or desc.is_empty():
			continue
		any_eq = true
		_done_equip_col.add_child(_summary_line(_equip_row_text(str(slot), desc)))
	for desc in _draft.gear:
		_done_gear_col.add_child(_summary_line("· " + str(desc.get("name", "?"))
			+ " x" + str(Draft.shown_count(desc)) + _gear_mag_tail(desc),
			Color("#a89a80")))
	if not any_eq:
		_done_equip_col.add_child(_summary_line(Loc.txt("Empty"), Color("#666666")))
	# Заголовок уже добавлен, поэтому пусто - это когда строк не больше одной.
	if _done_gear_col.get_child_count() <= 1:
		_done_gear_col.add_child(_summary_line(Loc.txt("Empty"), Color("#666666")))

# Строка экипировки в сводке: тег, имя, счётчик и названия надетых обвесов через
# плюс. Раньше здесь было только "rnd. N", и по такому хвосту нельзя было
# понять, какой обвес стоит - проверять набор приходилось, открывая панель.
func _equip_row_text(slot: String, desc: Dictionary) -> String:
	var line := slot + " · " + str(desc.get("name", "?"))
	var cnt := Draft.shown_count(desc)
	if cnt > 1:
		line += " x" + str(cnt)
	var names: Array = []
	var ats = desc.get("attachments")
	if typeof(ats) == TYPE_ARRAY:
		for ap in ats:
			var info := _item_info(str(ap))
			var n := str(info.get("name", ""))
			if n == "":
				n = str(ap).get_file()
			names.append(n)
	for n in names:
		line += "  + " + str(n)
	return line

# Хвост строки снаряжения: у обоймы - сколько патронов, у остальных пусто.
func _gear_mag_tail(desc: Dictionary) -> String:
	var path_now := str(desc.get("path", ""))
	if not _is_magazine(path_now):
		return ""
	if not Draft.is_full(desc):
		return "  " + Loc.txt("Empty")
	var raw = _item_info(path_now).get("maxAmount")
	var cap := int(round(float(raw if raw != null else 0.0)))
	return "  " + Loc.txt("[rounds]") + " " + str(cap)

func _summary_head(text: String) -> Label:
	var l := _summary_line(text, _gold)
	l.add_theme_font_size_override("font_size", 10)
	return l
```

- [x] **Step 6: Run all checks to verify it passes**

Run:

```powershell
python .check\layout_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
python .check\keycheck.py
python .check\a2\run.py
python .check\encoding_check.py
```

Expected: `RESULT: символы раскладки на месте`, `Parse check passed: 9 scripts`, `RESULT: every Loc.txt() key has a RU entry`, `PASS=77 FAIL=0`, `PROBLEMS: 0`.

- [x] **Step 7: Откатная точка**

Snapshot.

---

### Task 9: Документация, версия, пакет

**Files:**
- Modify: `docs/superpowers/plans/2026-10-05-loadouts-item-picker.md` — разделы про шаги 1 и 2 описывают старую раскладку
- Modify: `docs/superpowers/plans/2026-10-05-picker-facets-layout.md` — отметить выполненные шаги
- Modify: `AGENTS.md` — раздел «Проверка»: добавить `layout_check.py`; отметить, что цветов категорий в UI нет
- Modify: `loadouts/mod.txt` — `version="4.4.0"` → `version="4.5.0"`
- Build: `Loadouts.vmz`

**Interfaces:**
- Consumes: всё, что сделано в Task 1-8
- Produces: `Loadouts.vmz` версии 4.5.0

- [x] **Step 1: Привести старый план в порядок**

В `docs/superpowers/plans/2026-10-05-loadouts-item-picker.md` найти описания, которые больше не верны, и заменить их отсылкой к новому плану: чипы занятых слотов в шапке шага 1, кнопка `+ Add` и полки категорий в шаге 2, панель обвесов внутри `_slots_box`. Минимальная правка — добавить в начало плана абзац:

```markdown
> **Обновление 2026-10-05.** Раскладка страниц заменена: левая колонка слотов
> на шаге 1, фасеты категорий и постоянно открытая плоская сетка на шаге 2,
> панель обвесов в правой колонке, шаг 3 в две колонки. Правки и их тесты —
> `docs/superpowers/plans/2026-10-05-picker-facets-layout.md`.
```

Остальные разделы старого плана не трогать: `slashes_of`, `Draft`, применение сета и телепорт не менялись.

- [x] **Step 2: Обновить AGENTS.md**

В разделе «Проверка» дописать строку про новый стенд:

```markdown
- `.check\layout_check.py` сверяет раскладку picker по исходникам `VTKUI.gd`: список символов, которых быть не должно (кнопка `+ Add`, `_cat_color`), и список символов, которые должны быть (`_page_columns`, `_make_slot_row`, `_make_facet_row`). Список пополняется вместе с задачами плана.
```

В той же таблице про локализацию ничего менять не нужно. В раздел про цвета, если он есть, дописать: категориальных цветов в UI мода нет — точки занятости и активной строки достаточно.

- [x] **Step 3: Поднять версию**

В `loadouts/mod.txt` заменить `version="4.4.0"` на `version="4.5.0"`. Формат сохранённых данных не меняется, значит MINOR, а не MAJOR.

- [x] **Step 4: Финальный прогон всех проверок**

Run:

```powershell
python .check\layout_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
python .check\keycheck.py
python .check\a2\run.py
python .check\mojibake_scan.py loadouts\mods\VTK\VTKUI.gd loadouts\mods\VTK\VTKPicker.gd loadouts\mods\VTK\VTKLoc.gd
Select-String -SimpleMatch 'preload(' -Path loadouts\mods\VTK\*.gd | Measure-Object | Select-Object -ExpandProperty Count
```

Expected: `RESULT: символы раскладки на месте`, `Parse check passed: 9 scripts`, `RESULT: every Loc.txt() key has a RU entry`, `PASS=77 FAIL=0`, `OK: no replacement chars`, `17`. Расхождение счётчика `preload` с таблицей в `AGENTS.md` означает, что где-то появился или пропал `preload` — исправить до сборки.

Г glob считает по всем `loadouts\mods\VTK\*.gd`, а таблица в `AGENTS.md` разбита по файлам: `VTKUI.gd` — 15, ещё по одному `Loc` в `VTKTravel.gd` и `VTKData.gd`. Поэтому здесь ожидается 17, а не 15; сверять надо пофайлово.

- [x] **Step 5: Собрать пакет**

Run: `powershell -ExecutionPolicy Bypass -File pack.ps1`
Expected: печатает версию `4.5.0` перед упаковкой, затем `Loadouts.vmz` собран.

- [x] **Step 6: Проверить собранный пакет**

Run: `python .check\encoding_check.py`
Expected: `pack version: 4.5.0`, `PROBLEMS: 0`.

- [x] **Step 7: Откатная точка**

Snapshot после сборки.

- [x] **Step 8: Передать пользователю**

Сообщить путь к пакету и список того, что нужно проверить в игре глазами:

1. Шаг 1: слева все слоты, включая пустые, ширина колонки читается; клик по слоту фильтрует каталог; клик по текущей занятой строке открывает обвесы; кнопка снятия работает; «Все предметы» сбрасывает цель.
2. Шаг 1: ввод в поиск не теряет фокус и не сбрасывает курсор; список пересобирается на лету.
3. Полка «Гранаты» есть, гранаты не лежат в «Расходниках».
4. Шаг 2: фасеты со счётчиками, клик фильтрует, повторный клик по активному фасету ничего не делает, «Все предметы» сбрасывает, кнопки `+ Add` нет, сетка плоская.
5. Шаг 2: счётчики и список пересчитываются при вводе в поиск — ищем по имени и получаем непустой список (регрессия `_entry` без поля `name`).
6. Панель обвесов под каталогом в правой колонке, выбранный обвес выделен без префикса `[x]`, тумблер полной обоймы на месте.
7. Шаг 3: две колонки «Экипировка» и «Снаряжение», у каждой своё пустое состояние; у экипировки видны тег, имя и названия обвесов через ` + `.
8. Сохранить сет с обвесами, применить его — обвесы на месте.

