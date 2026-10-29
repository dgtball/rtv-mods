# Стена инвентаря: чипы 1×1 без рамки — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Перевести правую панель «Инвентарь» в превью сета на чипы 1×1 без рамки в квадратной сетке 8×8 (клетка 70px).

**Architecture:** Чисто UI-подстройка `VTKUI.gd`: константы (`INVEN_CELL=70`, новый `INVEN_ROWS=8`), укладка стены по индексу вместо реальных размеров, чип без Panel-стиля, панель больше не тянется по ширине. Данные (`gear`) и прочая вёрстка не меняются. `Picker.item_art`/`Draft.shown_count` используются как раньше. Headless-тесты не задействованы (объяснение ниже в «Проверка»); защита — стенд `layout_check.py`.

**Tech Stack:** GDScript (Godot 4.6.3), `python` (стенды `.check/`), `powershell pack.ps1`.

## Global Constraints

- Отступы в `.gd` — только табы; файлы `.gd` — UTF-8.
- Версия живёт в одном месте — `loadouts/mod.txt` (`version="4.12.1"`), в коде не дублируется, `mods/VTK/version.txt` регенерирует `pack.ps1`.
- Новая строка/ключ локализации не вводится. Ключи `Inventory`, ` items · `, `grid 8 columns` остаются.
- Коммитить только `loadouts/**`; `.check/`, `docs/`, `Loadouts.vmz` не коммитятся. Коммит — только по явному согласию пользователя.
- Код до/после должен проходить: `python .check\layout_check.py`, `python .check\keycheck.py`, `python .check\encoding_check.py`, `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`.
- Стенд `layout_check.py` читает `D:\RTVMOD\loadouts\mods\VTK\VTKUI.gd` по абсолютному пути (`.check/layout_check.py:16`).

---

### Task 1: Константы и комментарий геометрии

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd` (блок 1024–1035)

**Interfaces:**
- Consumes: — (первая задача)
- Produces: константы `INVEN_CELL := 70`, `INVEN_COLS := 8`, `INVEN_ROWS := 8`, `INVEN_GAP := 3` — их используют Task 2/3 (`_make_inventory_wall`, `_wall_item`, `_make_inventory_panel`).

- [ ] **Step 1: Заменить блок констант**

Сейчас (`VTKUI.gd:1030–1035`):

```gdscript
const EQ_COL_W := 375
const EQ_CELL := 55
const EQ_GAP := 4
const INVEN_CELL := 55
const INVEN_COLS := 8
const INVEN_GAP := 3
```

После:

```gdscript
const EQ_COL_W := 375
const EQ_CELL := 55
const EQ_GAP := 4
# Стена инвентаря: чипы 1×1, клетка 70px для читаемости иконок, всегда 8×8.
# С размерами экипировки больше не согласована: реальный размер слота ей
# не нужен (превью), и поле не растягивается по ширине.
const INVEN_CELL := 70
const INVEN_COLS := 8
const INVEN_ROWS := 8
const INVEN_GAP := 3
```

- [ ] **Step 2: Обновить комментарий выше блока** (строки 1026–1027)

Сейчас: «Клетка стены инвентаря (INVEN_CELL) крупнее на ту же долю, чтобы обе сетки читались в одном масштабе» — устарела (сетки больше не согласованы). Заменить строки 1026–1027 на:

```gdscript
# поля панели. Размер клетки стены инвентаря задаётся отдельно (INVEN_CELL).
# Раскладка слотов живёт в Picker.EQUIP_GRID;
```

«Колонка экипировки - 375» на строке 1025 остаётся; «Раскладка слотов живёт в Picker.EQUIP_GRID;» сохраняется (на неё опирается строка 1028 «здесь только геометрия»).

- [ ] **Step 3: Проверка парсинга**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: «parse OK: 12»/все файлы `OK`, без `Parse Error`.

---

### Task 2: Чип без рамки — `_wall_item`

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd` (1755–1789)

**Interfaces:**
- Consumes: `INVEN_CELL` (Task 1), `_cell_resource(desc)` (существует), `_item_icon(...)`, `Picker.item_art(...)`, `Draft.shown_count(desc)`, `_gold`.
- Produces: `_wall_item(desc: Dictionary) -> Control` — чип 1×1 без рамки; его зовёт `_make_inventory_wall` (Task 3).

- [ ] **Step 1: Заменить тело `_wall_item`**

Сейчас тело (1755–1789) создаёт `Panel` и вешает `VTKSurface.surface("normal")`. Заменить целиком на:

```gdscript
func _wall_item(desc: Dictionary) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(INVEN_CELL, INVEN_CELL)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.tooltip_text = str(desc.get("name", "?"))
	var tex := _item_icon(_cell_resource(desc))
	if tex != null:
		var img := TextureRect.new()
		img.texture = Picker.item_art(tex)
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(img)
		var qty := Draft.shown_count(desc)
		if qty > 1:
			var q := Label.new()
			q.text = "×" + str(qty)
			q.add_theme_font_size_override("font_size", 9)
			q.add_theme_color_override("font_color", _gold)
			q.mouse_filter = Control.MOUSE_FILTER_IGNORE
			q.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
			q.offset_left = -24
			q.offset_top = -18
			q.offset_right = -2
			q.offset_bottom = -2
			box.add_child(q)
	return box
```

Примечания: `clip_contents`/строки стиля панели пропадают — чип теперь прозрачный, рамку не рисует. Иконка `STRETCH_KEEP_ASPECT_CENTERED` внутри 70px не вылезает за клетку.

- [ ] **Step 2: Проверка стенда раскладки** (маркер «нет рамки»)

Run: `py -c "import io;print(r'VTKSurface.surface(\"normal\"))' in io.open(r'loadouts/mods/VTK/VTKUI.gd',encoding='utf-8').read())"`
Expected: `False` (строка рамки удалена). Затем `py .check\layout_check.py` — после Task 5 станет зелёным; до него допускается красный по GONE-маркеру, если добавили строку в `GONE` раньше.

---

### Task 3: Укладка стены по индексу — `_make_inventory_wall` + удаление `_gear_cell_size`

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd` (1743–1753 удалить, 1791–1847 заменить)

**Interfaces:**
- Consumes: `INVEN_CELL`, `INVEN_COLS`, `INVEN_ROWS`, `INVEN_GAP` (Task 1); `_wall_item` (Task 2).
- Produces: `_make_inventory_wall(gear: Array) -> Control` — квадратная стена 8×8 (мин), не тянется; `SIZE_SHRINK_BEGIN` по горизонтали.

- [ ] **Step 1: Удалить `_gear_cell_size`**

Вырезать функцию `func _gear_cell_size(desc: Dictionary) -> Vector2i:` целиком (1743–1753). Больше никто её не зовёт (единственные вызовы были в `_wall_item:1756` и `_make_inventory_wall:1803` — оба переписываются в этой задаче).

- [ ] **Step 2: Заменить `_make_inventory_wall`**

Сейчас (1795–1847) — жадная укладка по реальным размерам. Заменить целиком на:

```gdscript
# Стена инвентаря: чипы 1×1, 8 колонок, минимум 8 рядов - поле всегда квадрат
# 581×581 (при ≤64 стеках). Не растягивается по ширине: блок превью прижат
# влево, остаток строки - справа. Пиксельные координаты, посчитанные один
# раз, не пережили бы ресайз окна, поэтому предметы держатся якорями -
# долями от ширины/высоты стены.
func _make_inventory_wall(gear: Array) -> Control:
	var n := 0
	for desc in gear:
		if typeof(desc) == TYPE_DICTIONARY:
			n += 1
	var rows := maxi(INVEN_ROWS, int(ceil(n / float(INVEN_COLS))))
	var wall := Control.new()
	wall.custom_minimum_size = Vector2(INVEN_COLS * INVEN_CELL + (INVEN_COLS - 1) * INVEN_GAP,
		rows * INVEN_CELL + (rows - 1) * INVEN_GAP)
	wall.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	wall.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wall.clip_contents = true
	var bg := GridContainer.new()
	bg.columns = INVEN_COLS
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_theme_constant_override("h_separation", INVEN_GAP)
	bg.add_theme_constant_override("v_separation", INVEN_GAP)
	for i in range(rows * INVEN_COLS):
		var gc := Panel.new()
		gc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		gc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var gs := StyleBoxFlat.new()
		gs.bg_color = Color("#14110c")
		gs.corner_radius_all = 3
		gc.add_theme_stylebox_override("panel", gs)
		bg.add_child(gc)
	wall.add_child(bg)
	var idx := 0
	for desc in gear:
		if typeof(desc) != TYPE_DICTIONARY:
			continue
		var item := _wall_item(desc)
		var col := idx % INVEN_COLS
		var row := int(idx / INVEN_COLS)
		item.anchor_left = float(col) / float(INVEN_COLS)
		item.anchor_right = float(col + 1) / float(INVEN_COLS)
		item.anchor_top = float(row) / float(rows)
		item.anchor_bottom = float(row + 1) / float(rows)
		item.offset_left = 0.0
		item.offset_top = 0.0
		item.offset_right = 0.0
		item.offset_bottom = 0.0
		wall.add_child(item)
		idx += 1
	return wall
```

- [ ] **Step 3: Удалить второй комментарий над старой стеной** (1791–1794) — он описывал растяжение по ширине; его заменил комментарий внутри нового тела.

- [ ] **Step 4: Проверка**

Run: `py -c "import io;s=io.open(r'loadouts/mods/VTK/VTKUI.gd',encoding='utf-8').read();print('_gear_cell_size' in s, 'row_h := 1' in s)"`
Expected: `False False`. И `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1` по парсингу — `OK`, без `Parse Error`.

---

### Task 4: Панель не тянется — `_make_inventory_panel`

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd` (1852)

**Interfaces:**
- Consumes: `_make_inventory_wall` (Task 3), `INVEN_CELL` (Task 1).
- Produces: панель шириной по содержимому; блок «экипировка → инвентарь» прижат влево.

- [ ] **Step 1: Сменить размерный флаг панели**

Сейчас (`VTKUI.gd:1852`):

```gdscript
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
```

После:

```gdscript
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
```

Вертикальный флаг (`SIZE_SHRINK_BEGIN`, 1853) не трогать. Шапка и паддинг панели не меняются.

- [ ] **Step 2: Проверка**

Граница снизу — `func _cell_resource`, а не `_build_set_preview` (последняя стоит раньше панели, в шапке). В теле панели легитимно остаётся `EXPAND_FILL` у подписи меты (`meta_lbl`) — проверяем именно флаг панели, а не отсутствие `EXPAND_FILL` вообще.

Run: `py .superpowers\sdd\inventory-wall-chips\markers.py`
Expected: `panel SHRINK: True`, `panel EXPAND: False` (флаг панели сменён; EXPAND у меты не в счёт).

---

### Task 5: Стенд раскладки — `layout_check.py`

**Files:**
- Modify: `.check/layout_check.py` (GONE 19–106, PRESENT 123–210, FUNCS 221–275)

**Interfaces:**
- Consumes: символы из Task 1–4 (`INVEN_CELL := 70`, `INVEN_ROWS`, отсутствие `VTKSurface.surface("normal"))`, `row_h := 1`, `_gear_cell_size`).
- Produces: зелёный стенд, защищающий новую раскладку от откатов.

- [ ] **Step 1: PRESENT** (строка 193): заменить `"INVEN_CELL := 55"` на `"INVEN_CELL := 70"`.

- [ ] **Step 2: PRESENT**: добавить `"INVEN_ROWS",` в список (рядом со строкой `"INVEN_COLS",` на 208).

- [ ] **Step 3: GONE**: добавить в конец списка `GONE` (после 105):

```python
    # Стена инвентаря 4.12.1: чипы 1×1 без рамки. Рамка чипа - маркер возврата,
    # как и прежняя укладка по реальным размерам (_gear_cell_size, row_h).
    'VTKSurface.surface("normal"))',
    "row_h := 1",
    "_gear_cell_size",
```

- [ ] **Step 4: FUNCS**: добавить в конец списка (после `_refresh_slots`, 275):

```python
    ("_make_inventory_wall", [
        "INVEN_ROWS",
        "Control.SIZE_SHRINK_BEGIN",
    ], "стена: всегда 8+ рядов, квадратная, не тянется"),
    ("_wall_item", [
        "Picker.item_art",
    ], "чип инвентаря рисует иконку"),
```

- [ ] **Step 5: Прогнать стенд**

Run: `py .check\layout_check.py`
Expected: exit 0, `RESULT: символы раскладки на месте`; `GONE` 85 (было 82), `GONE_RE` 1, `PRESENT` 87 (было 86), `FUNCS` 18 (было 16).

---

### Task 6: Версия — `loadouts/mod.txt`

**Files:**
- Modify: `loadouts/mod.txt`

**Interfaces:**
- Consumes: —
- Produces: версия пакета `4.12.1` (её печатает `pack.ps1` и пишет в `mods/VTK/version.txt`).

- [ ] **Step 1: Поднять версию**

Сейчас: `id="vostok-toolkit"version="4.12.0"` (пользователь уже поднял после телепорта; это и есть база для фичи). Заменить `4.12.0` → `4.12.1`.

- [ ] **Step 2: Проверить**

Run: `Select-String -LiteralPath loadouts\mod.txt -Pattern 'version\s*=\s*"([^"]+)"'`
Expected: `version="4.12.1"`.

---

### Task 7: Полный прогон стендов

**Files:**
- (нет — проверка)

- [ ] **Step 1: layout_check**

Run: `py .check\layout_check.py`
Expected: exit 0.

- [ ] **Step 2: keycheck**

Run: `py .check\keycheck.py`
Expected: exit 0, нет stale-ключей (новые ключи не вводились).

- [ ] **Step 3: encoding_check** (временный артефакт — до пересборки пака печатает старую версию; это нормально)

Run: `py .check\encoding_check.py`
Expected: `PROBLEMS: 0`.

- [ ] **Step 4: check.ps1** (парсинг + headless-тесты)

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: exit 0; `parse` всех 12 `.gd` — `OK`; `tests 6 passed`.

---

### Task 8: Сборка и ручная проверка

**Files:**
- Modify (генерирует `pack.ps1`): `loadouts/mods/VTK/version.txt`, `Loadouts.vmz`, README (строку версии)

- [ ] **Step 1: Собрать пак**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File pack.ps1`
Expected: `Version in mod.txt: 4.12.1`; `Pack done: D:\RTVMOD\Loadouts.vmz (14 entries, …)`.

- [ ] **Step 2: Прогнать encoding_check уже по свежему паку**

Run: `py .check\encoding_check.py`
Expected: `version.txt matches mod.txt: 4.12.1`, `PROBLEMS: 0`.

- [ ] **Step 3: Ручная проверка в игре** (это ещё не автоматизируется — см. «Проверка» спека):

В превью сета и на странице Done:
- поле инвентаря — квадрат 581×581, ровные клетки 70px, без рамок у предметов, иконка + «×N», тултип на чипе;
- блок экипировка → инвентарь прижат влево, пустота справа;
- при ≤64 стеках поле 8×8; при большем — растёт по высоте;
- при 64 стеках (граница) rows = ceil(64/8) = 8.

- [ ] **Step 4: Коммит (только по явному согласию пользователя)**

```bash
git add loadouts/mod.txt loadouts/mods/VTK/VTKUI.gd loadouts/mods/VTK/version.txt
git commit -m "4.12.1: инвентарь - чипы 1х1 без рамки, сетка 8x8"
```

`git status` перед коммитом: не забирать `README.md` (чужие правки) и `.check/`/`docs/` (вне коммита).