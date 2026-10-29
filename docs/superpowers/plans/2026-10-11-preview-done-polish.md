# Полировка превью/Done и фикс поиска Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Привести карточку превью сета и страницу Done к макету `full-page-v2.html`/`done-page.html` (ровная геометрия экипировка↔инвентарь, единые кнопки, рейл, разделители) и починить пустой поиск на шаге 2, релиз 4.13.4.

**Architecture:** Все правки — в существующем монолитном `VTKUI.gd` (один экран, ручное построение Control-дерева) плюс вычистка мёртвых ключей локали в `VTKLoc.gd`. Чистая логика не меняется, кроме одной строки в `_entry` (запись каталога шага 2 обязана нести `name`, иначе `Picker.facets_of` фильтрует по пустой строке). Защита от регрессий — стенды `.check/layout_check.py` (GONE/PRESENT/FUNCS) и headless-тест `test_picker.gd`.

**Tech Stack:** GDScript (Godot 4.6.3), PowerShell-стенды, Python-стенды, PowerShell 5.1.

## Global Constraints

- **Версия релиза — `4.13.4`.** Живёт только в `loadouts/mod.txt`, поле `version`. Дубликата в GDScript нет.
- **Отступы в `.gd` — только табы**, кодировка UTF-8. Новый/изменённый код — без смешанных пробелов.
- **Локаль:** английский — исходный язык, ключ словаря сам является английской строкой. Локализуется только обвязка мода; имена предметов/типов/карт не переводятся.
- **`Loc.txt()`, не `tr()`.** Строку с кавычкой писать в одинарных кавычках.
- **Не трогать чужие незакоммиченные правки** в дереве: `README.md`, `VTKNVG.gd`, `VTKNVG.gdshader`, хунк `thermal_bot_opacity` в `VTKUI.gd` (~строка 3418). Их нельзя ни коммитить, ни откатывать, ни перезаписывать.
- **Коммиты — только по явному согласию пользователя.** Стейджить только `loadouts/**` (`.check/`, `.docs/`, `RTVcopy/` вне git). Никогда не `git add -A`.
- **Стейджинг `VTKUI.gd` (из-за чужого хунка тепловизора):** обычный `git add loadouts/mods/VTK/VTKUI.gd` затянет и чужой хунк. Стейджить скриптом-фильтром (см. «Скрипт стейджинга» ниже): он оставляет из `git diff` только хунки, чья новая строка начинается до 3000. Если скрипт печатает «пусто» — файл без изменений, стейджить нечего.
- **`docs/` и `.check/` в gitignore** — план, спека и скрипт стейджинга не коммитятся, это норма репозитория.
- **Тесты живут в `.check/project/tests/test_*.gd`** (standalone, gitignored). `check.ps1` копирует `loadouts/mods/VTK/*.gd` в `.check/project/mods/VTK`. Новый тест добавляется в список `$tests` в `check.ps1` вручную.
- **Зелёный статус `check.ps1`** = нет строк `SCRIPT ERROR` / `Parse Error` / `Invalid call` / `Failed to load script` + есть `tests passed` + код выхода 0.
- **Godot headless:** `D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe` (не в PATH, передаётся через `-Godot`).
- **`py` launcher** (не `python`). Стенды: `py .check\layout_check.py`, `py .check\keycheck.py`, `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`.
- **Инвариант выравнивания (Task 2):** экипировка и инвентарь должны совпадать по высоте 8 рядов: `8·EQ_CELL + 7·EQ_GAP == 8·INVEN_CELL + 7·INVEN_GAP` (при `EQ_CELL=70, EQ_GAP=3, INVEN_CELL=70, INVEN_GAP=3` обе стороны = 581). Отступ содержимого внутри панели — 6px с обеих сторон (MarginContainer).
- **`MOUSE_FILTER_IGNORE`** на декоративных узлах (ColorRect-разделители, отступы), чтобы они не съедали клики.

Скрипт стейджинга (создаётся в Task 1 как `.check/stage_vtk.py`, переиспользуется во всех задачах):
```python
import re, subprocess, sys, os
path = "loadouts/mods/VTK/VTKUI.gd"
diff = subprocess.run(["git", "diff", "-U6", "--", path], capture_output=True).stdout
if not diff.strip():
    print("пусто: VTKUI.gd без изменений")
    sys.exit(0)
out, keep = [], True
for ln in diff.split(b"\n"):
    m = re.match(rb"@@ -\d+(?:,\d+)? \+(\d+)", ln)
    if m:
        keep = int(m.group(1)) < 3000
    if keep:
        out.append(ln)
tmp = os.path.join(os.environ.get("TEMP", "."), "vtkui.patch")
open(tmp, "wb").write(b"\n".join(out))
subprocess.run(["git", "apply", "--cached", tmp], check=True)
print("staged", tmp)
```
Проверка после стейджинга: `git diff --cached --stat` и `git diff --cached -- loadouts/mods/VTK/VTKUI.gd` не должны содержать `thermal_bot_opacity`.

---

## File Structure

- `loadouts/mods/VTK/VTKUI.gd` — вся вёрстка (Tasks 1–7).
- `loadouts/mods/VTK/VTKLoc.gd` — удаление мёртвых ключей (Task 7).
- `.check/project/tests/test_picker.gd` — регресс-тест `facets_of` (Task 1).
- `.check/check.ps1` — регистрация нового теста (Task 1).
- `.check/layout_check.py` — GONE/PRESENT/FUNCS (Tasks 1–7).
- `loadouts/mod.txt` — версия (Task 8).

---

### Task 1: Фикс пустого поиска на шаге «Снаряжение» (`_entry` без `name`)

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd:2197-2202`
- Modify: `.check/layout_check.py:240-311` (FUNCS)
- Modify: `.check/project/tests/test_picker.gd`
- Modify: `.check/check.ps1`

**Interfaces:**
- Produces: `_entry(it) -> Dictionary` теперь `{item, name, cat, sub}`, где `name = str(it.get("name",""))`. Ключ `name` читает `Picker.facets_of` (`VTKPicker.gd:548`).

**Контекст:** `_items_for_gear()` (1500) отдаёт `_entry(it)` в `Picker.facets_of`, который фильтрует `str(e.get("name",""))`. Без `name` при непустом запросе всё выпадает — поиск шага 2 всегда пуст. Шаг 1 (`_items_for_target` :2211) читает `it.get("name")` напрямую и работает.

- [ ] **Step 1: Написать падающий тест**

В `.check/project/tests/test_picker.gd` добавить функцию (перед функцией `_init`, стиль файла — табы):

```gdscript
func t_facets_of_requires_name() -> void:
	# Регрессия: facets_of фильтрует по ключу name записи. Запись без name
	# (как её отдавал _entry до 4.13.4) под непустым запросом выпадает целиком.
	var with_name: Array = [{"name": "AKM", "cat": "weapon"}]
	var without: Array = [{"cat": "weapon"}]
	ck(int(P.facets_of(with_name, "akm")[0].get("count", -1)) == 1,
		"запись с name находится по запросу")
	ck(int(P.facets_of(without, "akm")[0].get("count", -1)) == 0,
		"запись без name под запросом выпадает (нужен ключ name)")
	ck(int(P.facets_of(without, "")[0].get("count", -1)) == 1,
		"без запроса запись без name остаётся")
```

И зарегистрировать вызов в `_init` рядом с существующим `t_facets_of()`:
```gdscript
	t_facets_of()
	t_facets_of_requires_name()
```

- [ ] **Step 2: Прогнать тест — убедиться, что падает**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: FAIL — в выводе есть `запись без name под запросом выпадает` (или `tests failed`). Тест ловит контракт `facets_of`; сам `_entry` тестом не покрыт (нужен `_db_items`).

- [ ] **Step 3: Внести `name` в `_entry`**

Заменить тело `VTKUI.gd:2197-2202`:
```gdscript
func _entry(it) -> Dictionary:
	return {
		"item": it,
		"name": str(it.get("name", "")),
		"cat": Picker.category_of(it.get("slots"), it.get("type")),
		"sub": Picker.subcategory_of(str(it.resource_path), it.get("type")),
	}
```

- [ ] **Step 4: Прогнать тест и стенд парсинга**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: PASS — есть `tests passed`, код выхода 0.

- [ ] **Step 5: Добавить FUNCS-гард на `_entry` в `layout_check.py`**

В список `FUNCS` (перед закрывающей `]` на строке 311) добавить:
```python
    ("_entry", ['"name":', 'it.get("name")'],
     "запись каталога несёт name — шаг 2 фильтрует поиск по нему"),
```
Run: `py .check\layout_check.py`
Expected: `RESULT: символы раскладки на месте` (проверка FUNCS по телу `_entry`).

- [ ] **Step 6: Ручная проверка в игре**

Собрать пак (см. Task 8, но для промежуточной проверки достаточно `powershell -ExecutionPolicy Bypass -File pack.ps1` после шага с версией) и скопировать в игру, затем: открыть редактор сета → шаг «Снаряжение» → ввести в поиск `AK` → список и счётчики фасетов не пусты. Ожидается: предметы находятся.

- [ ] **Step 7: Commit (по согласию пользователя)**

Запустить `py .check\stage_vtk.py`, затем:
```powershell
git diff --cached --stat
git commit -m "fix: шаг 2 находит предметы по непустому запросу (_entry.name)"
```
(`.check/**` и `docs/**` в gitignore — коммитится только `VTKUI.gd`.)

---

### Task 2: Выровнять геометрию экипировки по инвентарю

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd:1059-1070` (константы), `:1748-1782` (`_make_equip_preview`)
- Modify: `.check/layout_check.py:204-205` (PRESENT), `:240-311` (FUNCS)

**Interfaces:**
- Consumes: `EQ_COL_W`, `EQ_CELL`, `EQ_GAP`; `MarginContainer`-отступ 6px как в `_make_inventory_panel` (:1882-1887).
- Produces: `_make_equip_preview(eq) -> Control` с сеткой в `MarginContainer`. Константы: `EQ_COL_W=447`, `EQ_CELL=70`, `EQ_GAP=3`.

**Контекст:** инвентарь — `INVEN_CELL=70`, `INVEN_GAP=3`, панель `8·70+7·3+12=593`, содержимое в `MarginContainer` 6px (581 по высоте). Экипировка — `EQ_CELL=55`, `EQ_GAP=4`, без отступа → 6·55+5·4=350 ширина, 8·55+7·4=468 высота. Приводим к тем же 70/3 и отступу 6px: ширина `6·70+5·3=435`, +12 = `EQ_COL_W=447`, высота 8·70+7·3=581. Побочный эффект (осознан): сетка шага 1 «Экипировка» тоже станет 435×581.

- [ ] **Step 1: Обновить константы**

Заменить `VTKUI.gd:1055-1074`:
```gdscript
# Ширина левой колонки по умолчанию (шаг 2 «Снаряжение» и «Точки»). Шаг 1
# «Экипировка» идёт под колонку 447 (EQ_COL_W): укладка 6×8 шире 232.
const SIDE_WIDTH := 232

# Размеры сетки экипировки (вариант E): фиксированная сетка 6 колонок × 8 рядов,
# клетка EQ_CELL, зазор EQ_GAP. Колонка экипировки - 447: 6·70 + 5·3 = 435 плюс
# поля панели 12. Метрики (клетка 70, зазор 3) совпадают с инвентарём, поэтому
# превью ровное по низу. Раскладка слотов живёт в Picker.EQUIP_GRID;
# здесь только геометрия. Прежних высот оружия/тела/мелочи больше нет - все клетки
# одного размера, разный только размах (2×6, 2×2, 1×1).
const EQ_COL_W := 447
const EQ_CELL := 70
const EQ_GAP := 3
# Стена инвентаря: чипы 1×1, клетка 70px для читаемости иконок, всегда 8×8.
# Метрики совпадают с экипировкой (70/3) и отступом 6px: ряды колонок ровные.
const INVEN_CELL := 70
const INVEN_COLS := 8
const INVEN_ROWS := 8
const INVEN_GAP := 3
```

- [ ] **Step 2: Обернуть сетку экипировки в MarginContainer 6px**

Заменить блок `else` в `_make_equip_preview` (`VTKUI.gd:1780-1781`):
```gdscript
	else:
		var pad := MarginContainer.new()
		pad.add_theme_constant_override("margin_left", 6)
		pad.add_theme_constant_override("margin_top", 6)
		pad.add_theme_constant_override("margin_right", 6)
		pad.add_theme_constant_override("margin_bottom", 6)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pad.add_child(_make_equip_grid(cells, int(layout.get("cols", 6)),
			int(layout.get("rows", 8)), eq, false))
		panel.add_child(pad)
```

- [ ] **Step 3: Обновить PRESENT и FUNCS в `layout_check.py`**

Строки 204-205 станут:
```python
    "EQ_COL_W := 447",
    "EQ_CELL := 70",
```
В `FUNCS` добавить:
```python
    ("_make_equip_preview", ["MarginContainer", "EQ_COL_W"],
     "превью экипировки: сетка в отступе 6px, колонка EQ_COL_W"),
```

- [ ] **Step 4: Проверить**

Run: `py .check\layout_check.py`
Expected: `RESULT: символы раскладки на месте`
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `tests passed`, код выхода 0.

- [ ] **Step 5: Ручная проверка в игре**

В игре: открыть любой сет → превью: правые края экипировки и инвентаря на одной линии, низ обеих колонок на одной линии; проверить вкладку «Экипировка» редактора — сетка не вылезает за колонку.

- [ ] **Step 6: Commit (по согласию пользователя)**

`py .check\stage_vtk.py` → `git commit -m "style: экипировка превью ровно под инвентарь (70/3, отступ 6px)"`.

---

### Task 3: Кнопки управления превью одного размера

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd:658`
- Modify: `.check/layout_check.py` (GONE)

**Interfaces:** удаление единственной строки. `_make_control_column` (:569) задаёт `size_flags_horizontal = EXPAND_FILL` и общий `style_button`; хоткей-кнопка переставала совпадать по высоте из-за меньшего шрифта.

- [ ] **Step 1: Удалить override шрифта у хоткей-кнопки**

Удалить строку `VTKUI.gd:658`:
```gdscript
	qk_btn.add_theme_font_size_override("font_size", 9)
```
Остальные кнопки колонки (`Apply`/`Edit`/`Del`) override не имеют — теперь все на теме.

- [ ] **Step 2: Добавить GONE-маркер**

В список `GONE` (`layout_check.py`, перед `]` на строке 119):
```python
    'qk_btn.add_theme_font_size_override("font_size", 9)',
```
(с комментарием: `# 4.13.4: кнопка хоткея в колонке управления не мельче соседних`)

- [ ] **Step 3: Проверить**

Run: `py .check\layout_check.py`
Expected: `RESULT: символы раскладки на месте`
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `tests passed`, код выхода 0.

- [ ] **Step 4: Ручная проверка в игре**

Превью сета: три кнопки в колонке «Управление» (`Применить`, `Изменить`, `R·F6` / `Удалить`) одинаковой высоты и ширины.

- [ ] **Step 5: Commit (по согласию пользователя)**

`py .check\stage_vtk.py` → `git commit -m "style: кнопки колонки управления превью одного размера"`.

---

### Task 4: Строки фасетов «Снаряжения» выше на 5px

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd:1373`
- Modify: `.check/layout_check.py` (PRESENT)

**Interfaces:** `_make_facet_row(facet, level)` — высота `custom_minimum_size.y` 26→31 (категория, `level=false`) и 23→28 (подкатегория, `level=true`).

- [ ] **Step 1: Поднять высоту строки**

Заменить `VTKUI.gd:1373` (категория, `level=false`, 26→31; подкатегория, `level=true`, 23→28 — обе строки +5px, категория остаётся выше):
```gdscript
	row.custom_minimum_size = Vector2(0, 28 if level else 31)
```

- [ ] **Step 2: Добавить PRESENT-маркер**

В список `PRESENT` (перед `]` на строке 229):
```python
    "28 if level else 31",
```

- [ ] **Step 3: Проверить**

Run: `py .check\layout_check.py`
Expected: `RESULT: символы раскладки на месте`
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `tests passed`, код выхода 0.

- [ ] **Step 4: Ручная проверка в игре**

Шаг «Снаряжение»: строки категорий и подкатегорий заметно выше прежних, текст не подрезан.

- [ ] **Step 5: Commit (по согласию пользователя)**

`py .check\stage_vtk.py` → `git commit -m "style: строки фасетов снаряжения выше на 5px"`.

---

### Task 5: Рейл — имя, плашка «V», версия и полоса-разделитель

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd:450-484` (brand/rname/rver), вставить разделитель перед `:486`
- Modify: `.check/layout_check.py` (PRESENT)

**Interfaces:**
- Consumes: `_panel` (`PRESET_FULL_RECT`, строка 415), `Color("#2a2419")` — цвет разделителей макета.
- Produces: локальная переменная `rail_sep` (ColorRect).

- [ ] **Step 1: Увеличить плашку «V» и её букву**

Заменить `VTKUI.gd:451` и `:455` и `:460`:
```gdscript
	brand.custom_minimum_size = Vector2(30, 30)
```
(`:451`; строки 452-454 без изменений)
```gdscript
	bs.corner_radius_all = 8
```
(`:455`)
```gdscript
	bv.add_theme_font_size_override("font_size", 15)
```
(`:460`)

- [ ] **Step 2: Увеличить имя и версию**

`VTKUI.gd:470`:
```gdscript
	rname.add_theme_font_size_override("font_size", 14)
```
`VTKUI.gd:481`:
```gdscript
	rver.add_theme_font_size_override("font_size", 10)
```

- [ ] **Step 3: Вставить полосу-разделитель между рейлом и вкладками**

Перед `var tab_bar = HBoxContainer.new()` (`VTKUI.gd:486`) вставить:
```gdscript
	# Полоса под рейлом (макет .rail border-bottom): 1px на всю ширину
	# рабочей области (как рейл и вкладки, врезка 4px).
	var rail_sep := ColorRect.new()
	rail_sep.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	rail_sep.offset_left = 4
	rail_sep.offset_top = 56
	rail_sep.offset_right = -4
	rail_sep.offset_bottom = 57
	rail_sep.color = Color("#2a2419")
	rail_sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(rail_sep)
```

- [ ] **Step 4: PRESENT-маркер**

В `PRESENT` добавить:
```python
    "rail_sep",
```

- [ ] **Step 5: Проверить**

Run: `py .check\layout_check.py`
Expected: `RESULT: символы раскладки на месте`
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `tests passed`, код выхода 0.

- [ ] **Step 6: Ручная проверка в игре**

Верх экрана: «V» крупнее и скруглённее, «VOSTOK TOOLKIT» и `v4.13.4` читаемее, под рейлом — тонкая линия на всю ширину, не перекрывающая вкладки.

- [ ] **Step 7: Commit (по согласию пользователя)**

`py .check\stage_vtk.py` → `git commit -m "style: рейл крупнее с полосой-разделителем под ним"`.

---

### Task 6: Разделитель под шапкой превью и удаление подписи «Раскладка · N предметов»

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd:641-647`
- Modify: `.check/layout_check.py` (FUNCS `_refresh_preview`)

**Interfaces:**
- Consumes: `_preview_box` (VBoxContainer), `gr_a` остаётся использованным ниже (`_build_set_preview(..., gr_a, ...)`).
- Produces: локальная переменная `head_sep` (ColorRect) в `_refresh_preview`.

- [ ] **Step 1: Удалить `cap` и добавить разделитель**

Заменить `VTKUI.gd:641-647` (блок `var cap ... _preview_box.add_child(card_head)`) на:
```gdscript
	_preview_box.add_child(card_head)

	# Разделитель под именем сета (макет .card head border-bottom).
	var head_sep := ColorRect.new()
	head_sep.custom_minimum_size = Vector2(0, 1)
	head_sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_sep.color = Color("#2a2419")
	head_sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_box.add_child(head_sep)
```
(`gr_a` остаётся объявленным в :630 и используется ниже — не удалять.)

- [ ] **Step 2: Дополнить FUNCS `_refresh_preview`**

К существующей записи `("_refresh_preview", [...])` (строки 303-306) добавить `"head_sep"` в список `needed`:
```python
    ("_refresh_preview", [
        "_make_control_column(Loc.txt(\"Controls\")",
        "Loc.txt(\"Delete\")",
        "head_sep",
    ], "превью: кнопки в колонке Управление, удаление текстом, разделитель шапки"),
```

- [ ] **Step 3: Проверить**

Run: `py .check\layout_check.py`
Expected: `RESULT: символы раскладки на месте`
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `tests passed`, код выхода 0.

- [ ] **Step 4: Ручная проверка в игре**

Превью сета: под именем сета — тонкая линия; подписи «РАСКЛАДКА · N ПРЕДМЕТОВ» больше нет.

- [ ] **Step 5: Commit (по согласию пользователя)**

`py .check\stage_vtk.py` → `git commit -m "style: разделитель под шапкой превью, убрана подпись счётчика"`.

---

### Task 7: Done — имя и хоткей в колонку управления, удаление `_done_meta`, чистка локали

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd:100-101`, `:1508-1587`, (FUNCS `_build_page_done`)
- Modify: `loadouts/mods/VTK/VTKLoc.gd` (удалить `'Name:'`, `'Hotkey:'`, `'Loadout'`, `' items'`)
- Modify: `.check/layout_check.py` (GONE / PRESENT / FUNCS)

**Interfaces:**
- Consumes: `_name_input` (`LineEdit`), `_bind_btn` (`Button`, он же `_done_bind_btn`), `_make_control_column(title, buttons)`, `_build_set_preview(eq, gear, fill, controls)`.
- Produces: `_build_page_done() -> Control` создаёт `_name_input`/`_bind_btn` один раз (без `name_row`); `_refresh_page_done()` перевешивает их в столбец `[имя, хоткей, Сохранить, Отмена]` и не трогает текст/фокус. `_done_meta` удалён полностью.

**Критично:** `_done_preview` пересобирается через `queue_free`. `_name_input`/`_bind_btn` надо **отцепить** от старого столбца до очистки, иначе они освободятся вместе с ним (потеря текста и фокуса).

- [ ] **Step 1: Удалить объявление `_done_meta`**

Удалить `VTKUI.gd:101` (`var _done_meta: Label = null`).

- [ ] **Step 2: Переписать `_build_page_done` (1508-1562)**

Заменить тело целиком:
```gdscript
func _build_page_done() -> Control:
	var v := _page_wrap()

	# Карточка трёх колонок состава; имя сета и кнопка хоткея живут в столбце
	# «Управление», как в превью. Узлы создаются один раз и перевешиваются в
	# столбец при каждой пересборке (_refresh_page_done), чтобы не терять текст.
	_name_input = LineEdit.new()
	_name_input.placeholder_text = Loc.txt("Enter a name...")
	_name_input.add_theme_color_override("font_color", Color("#ffffff"))
	_name_input.add_theme_color_override("placeholder_color", Color("#666666"))
	_name_input.add_theme_stylebox_override("normal", VTKSurface.panel(true, 10))
	_name_input.add_theme_stylebox_override("focus", VTKSurface.focus_style())
	if _draft != null:
		_name_input.text = _draft.set_name

	# Хоткей назначается до сохранения: для нового сета бинд копится в
	# _pending_qk и применяется в _save_loadout.
	_bind_btn = Button.new()
	_done_bind_btn = _bind_btn
	_bind_btn.custom_minimum_size = Vector2(120, 20)
	_bind_btn.add_theme_font_size_override("font_size", 10)
	_apply_qk_btn(_bind_btn, _display_qk())
	_bind_btn.pressed.connect(func(): _begin_bind_pending(_bind_btn))

	_done_preview = _build_set_preview({}, [], false,
		_make_control_column(Loc.txt("Controls").to_upper(), []))
	v.add_child(_done_preview)
	return v
```

- [ ] **Step 3: Переписать `_refresh_page_done` (1566-1587)**

```gdscript
# Сводка перед сохранением: что уйдёт в сет. Пересобирается целиком тем же
# билдером, что и превью сета, - вторая раскладка не нужна.
func _refresh_page_done() -> void:
	if _done_preview == null:
		return
	# Поле имени и кнопка хоткея переживают пересборку: отцепить от старого
	# столбца, иначе queue_free унёс бы их вместе с ним (текст и фокус).
	if _name_input != null and _name_input.get_parent() != null:
		_name_input.get_parent().remove_child(_name_input)
	if _bind_btn != null and _bind_btn.get_parent() != null:
		_bind_btn.get_parent().remove_child(_bind_btn)
	for child in _done_preview.get_children():
		_done_preview.remove_child(child)
		child.queue_free()
	var save_btn := Button.new()
	save_btn.text = Loc.txt("Save loadout")
	VTKSurface.style_button(save_btn, true)
	save_btn.pressed.connect(_save_loadout)
	var cancel_btn := Button.new()
	cancel_btn.text = Loc.txt("Cancel")
	VTKSurface.style_button(cancel_btn)
	cancel_btn.pressed.connect(_cancel_draft)
	_done_preview.add_child(_build_set_preview(
		_draft.equip if _draft else {},
		_draft.gear if _draft else [],
		false,
		_make_control_column(Loc.txt("Controls").to_upper(),
			[_name_input, _bind_btn, save_btn, cancel_btn])))
```

- [ ] **Step 4: Удалить мёртвые ключи локали**

Свериться, что ключи больше нигде не вызываются:
```powershell
rg -n --fixed-strings 'Name:' loadouts\mods\VTK
rg -n --fixed-strings 'Hotkey:' loadouts\mods\VTK
rg -n --fixed-strings 'Loc.txt("Loadout")' loadouts\mods\VTK
rg -n --fixed-strings 'Loc.txt(" items")' loadouts\mods\VTK
```
Ожидается: совпадения только внутри `VTKLoc.gd` (сам словарь). Удалить из `VTKLoc.gd` записи `'Name:'`, `'Hotkey:'`, `'Loadout'`, `' items'`.
Run: `py .check\keycheck.py`
Expected: нет `stale` по этим ключам, код выхода 0.

- [ ] **Step 5: Обновить `layout_check.py`**

- В `FUNCS` записи `("_build_page_done", [...])` (307-310) заменить `"_done_meta"` на `"_name_input"`:
```python
    ("_build_page_done", [
        "_build_set_preview({}, [], false,",
        "_name_input",
    ], "Done: каркас трёх колонок, имя и хоткей — в колонке управления"),
```
- В `GONE` добавить:
```python
    "_done_meta",
    'Loc.txt("Loadout")',
    'Loc.txt(" items")',
    'Loc.txt("Name:")',
    'Loc.txt("Hotkey:")',
```
- Из `PRESENT` удалить строки 226-227 (`'Loc.txt("Loadout")'`, `'Loc.txt(" items")'`).

- [ ] **Step 6: Проверить**

Run: `py .check\layout_check.py`
Expected: `RESULT: символы раскладки на месте`
Run: `py .check\keycheck.py`
Expected: код выхода 0
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `tests passed`, код выхода 0.

- [ ] **Step 7: Ручная проверка в игре**

Открыть редактор сета → вкладка «Done»: в правой колонке сверху вниз поле имени, кнопка хоткея, «Сохранить», «Отмена»; заголовок «УПРАВЛЕНИЕ» на месте; подписи счётчика под карточкой нет. Ввести имя → переключиться на другую вкладку редактора и обратно (пересборка) → текст имени сохранился. Нажать хоткей-кнопку → бинд назначается.

- [ ] **Step 8: Commit (по согласию пользователя)**

Стейджинг: `py .check\stage_vtk.py` (VTKUI.gd) + `git add loadouts/mods/VTK/VTKLoc.gd`, затем:
```powershell
git commit -m "refactor: Done — имя и хоткей в колонку управления, убрана подпись счётчика"
```

---

### Task 8: Версия 4.13.4, сборка, копия в игру

**Files:**
- Modify: `loadouts/mod.txt` (`version`)
- Generated: `loadouts/mods/VTK/version.txt`, `Loadouts.vmz` (оба — pack.ps1)

**Interfaces:** `pack.ps1` печатает версию из `mod.txt` перед упаковкой; согласует `version.txt` и README.

- [ ] **Step 1: Поднять версию**

В `loadouts/mod.txt` заменить `version=` на `version=4.13.4`.

- [ ] **Step 2: Прогнать все стенды**

```powershell
py .check\layout_check.py
py .check\keycheck.py
py .check\encoding_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```
Expected: у каждого код выхода 0; `check.ps1` печатает `tests passed`.

- [ ] **Step 3: Собрать пак**

Run: `powershell -ExecutionPolicy Bypass -File pack.ps1`
Expected: вывод содержит `4.13.4`, создан `Loadouts.vmz`.

- [ ] **Step 4: Скопировать пак в игру**

```powershell
Copy-Item -LiteralPath "D:\RTVMOD\Loadouts.vmz" -Destination "D:\SteamLibrary\steamapps\common\Road to Vostok\mods\Loadouts.vmz" -Force
```
Проверить рейл: в игре версия показывает `v4.13.4`.

- [ ] **Step 5: Финальная ручная проверка в игре**

Пройти все правки разом: поиск шага 2, ровное превью, кнопки управления, строки фасетов, рейл, разделитель шапки превью, Done.

- [ ] **Step 6: Commit (по согласию пользователя)**

```powershell
git add loadouts/mod.txt loadouts/mods/VTK/version.txt
git commit -m "release: 4.13.4"
```
`README.md` не стейджить (чужая правка). Если `pack.ps1` изменил README — оставить как есть.

---

## Self-Review

**Spec coverage** (по `2026-10-11-preview-done-polish-design.md`):
1. Фикс поиска (`_entry.name`) → Task 1. ✅
2. Кнопки превью равного размера → Task 3. ✅
3. Экипировка вровень (A1: 70/3, отступ 6px, EQ_COL_W=447) → Task 2. ✅
4. Фасет-строки +5px (31/28, только высота) → Task 4. ✅
5. Рейл (имя 14, плашка 30/radius 8/«V» 15, версия 10, полоса `#2a2419`) → Task 5. ✅
6. Разделитель под шапкой превью → Task 6. ✅
7. Удаление cmeta (cap в превью и `_done_meta` в Done) → Tasks 6, 7. ✅
8. Done: имя+хоткей в столбец управления, `queue_free`-безопасное перевешивание, заголовок «УПРАВЛЕНИЕ» остаётся → Task 7. ✅
9. Локаль: удалить `'Name:'`, `'Hotkey:'`, `'Loadout'`, `' items'`; новых ключей нет → Task 7. ✅
10. Версия 4.13.4 + pack + копия → Task 8. ✅

**Placeholder scan:** нет TODO/TBD; все шаги содержат точный код/команды.

**Type consistency:** `_entry` возвращает словарь с ключом `name` (Task 1) — используется в `_make_item_cell` через `entry.get("item")`, `cat`/`sub` через существующий код; новое поле аддитивно. `_make_control_column(title: String, buttons: Array)` (Task 7 передаёт `[_name_input, _bind_btn, save_btn, cancel_btn]`, все `Control`). `_build_set_preview(eq, gear, fill, controls)` — сигнатура не меняется. `rail_sep`/`head_sep` — локальные, не пересекаются по областям видимости.

**Риск незакрытый специей:** `EQ_COL_W=447` расширяет и сетку шага 1 (осознанно, зафиксировано в спеке). Если в игре строка превью не влезет в окно — снижать `EQ_CELL`, а не отступ.
