# Превью набора и Done: три колонки с управлением — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Перевести превью сета и страницу Done черновика на согласованную трёхколоночную раскладку (Экипировка | Инвентарь | Управление), перенести кнопки действий в колонку Управление, собрать шапку карточки набора, оформить рейл «VOSTOK TOOLKIT» плашкой и версией справа.

**Architecture:** Весь код — UI-логика в `VTKUI.gd` (один общий билдер каркаса колонок `_build_set_preview` + новый хелпер колонки управления `_make_control_column`, пересборка шапок и кнопок в `_refresh_preview`/`_refresh_page_done`), рейл в `_build_ui`, локализация в `VTKLoc.gd`. Имена предметов и пути внутрь игры не задействованы — headless-тестов на UI нет, верификация через стенды: `layout_check.py` (маркеры раскладки), `check.ps1` (парсинг + тесты), `keycheck.py` (ключи словаря), `mojibake_scan.py`/`encoding_check.py`.

**Tech Stack:** GDScript (Godot 4.6.3), `VTKSurface.gd` (панели/кнопки), `VTKLoc.gd` (строки).

## Global Constraints

- Отступы в `.gd` — только табы. Скобки сбалансированы.
- Файлы `.gd` — UTF-8. Русский текст не допускает двойного кодирования; сканер `mojibake_scan.py` перед сборкой.
- Версия живёт только в `loadouts/mod.txt`, в GDScript не дублируется (рейл берёт `_mod_version()`).
- **Версию не поднимать в этой ветке задач**: финальное значение уточняем с пользователем на этапе сборки.
- Коммитить только `loadouts/**` (`.check/`, `docs/`, `RTVcopy/` — вне контроля версии) и только по явному согласию пользователя.
- Чужая незакоммиченная работа не трогается: `README.md`, `VTKNVG.gd`, `VTKNVG.gdshader` и правки тепловизора в `VTKUI.gd`, удалённые ключи в `VTKLoc.gd` (`Mine highlighting`, `Thermal vision`, и их полные формы).
- Строчные `Loc.txt("...")` — только в словаре `RU` (английский источник); `keycheck.py` не должен показывать `MISSING` или лишние `unused` для ключей этой задачи.
- Каждый новый ключ словаря добавляется **в той же ревизии, в которой получает потребителя** (иначе `keycheck.py` даст `unused`).
- `layout_check.py` (в `.check/`, не коммитится) пополняется маркерами в каждой задаче, иначе финальный прогон не отличит новую раскладку от регрессии.
- Шаги редактора 1–2 (Экипировка/Снаряжение) и `_make_item_cell` не меняются.

---

### Task 1: Рейл «VOSTOK TOOLKIT» — плашка «V» и версия справа

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd:432-460` (`_build_ui`)
- Modify: `.check/layout_check.py` (PRESENT — маркер плашки) — не коммитится
- Test: `py .check\layout_check.py`, `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`

**Interfaces:**
- Consumes: `_mod_version()` (VTKUI.gd:3439), `_panel`, `rail` (HBox, верхний рейл панели).
- Produces: новый локальный узел плашки в `_build_ui`; версия остаётся строкой `"v" + _mod_version()`.

- [ ] **Step 1: Заменить содержимое рейла**

Заменить блок `name_box`/`rname`/`rver` (VTKUI.gd:448-460) так, чтобы вместо столбика «имя → версия» рейл стал одним рядом: плашка + имя + заполнитель + версия справа. `rail` и его настройки (438-446) не меняются.

```gdscript
	var brand := Panel.new()
	brand.custom_minimum_size = Vector2(26, 26)
	brand.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color("#d48a3a")
	bs.corner_radius_all = 4
	brand.add_theme_stylebox_override("panel", bs)
	rail.add_child(brand)
	var bv := Label.new()
	bv.text = "V"
	bv.add_theme_font_size_override("font_size", 13)
	bv.add_theme_color_override("font_color", Color("#0e0b08"))
	bv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brand.add_child(bv)

	var rname := Label.new()
	rname.text = "VOSTOK TOOLKIT"
	rname.add_theme_font_size_override("font_size", 11)
	rname.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rail.add_child(rname)

	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.add_child(fill)

	var rver := Label.new()
	rver.text = "v" + _mod_version()
	rver.add_theme_font_size_override("font_size", 9)
	rver.add_theme_color_override("font_color", Color("#5f5347"))
	rver.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rail.add_child(rver)
```

- [ ] **Step 2: Маркер стенда — плашка**

В `.check/layout_check.py` в список `PRESENT` добавить:

```python
    "_rail_brand",
```

- [ ] **Step 3: Присвоить маркер в коде**

Чтобы маркер `_rail_brand` был не пустым идеалом, добавить в комментарий над блоком рейла (VTKUI.gd:432-437) имя переменной плашки. Например, в строке комментария «верхний рейл устройства» заменить на «верхний рейл устройства: плашка `_rail_brand` + имя, версия справа».

- [ ] **Step 4: Проверить стенды**

Run: `py .check\layout_check.py`
Expected: `GONE: ..., PRESENT: ..., FUNCS: ...` зелёные, `_rail_brand` в PRESENT; JSON-вывод счётом без ошибок.

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: нет `SCRIPT ERROR` / `Parse Error` / `Invalid call` / `Failed to load script`, есть `tests passed`.

- [ ] **Step 5: Коммит**

```bash
git add loadouts/mods/VTK/VTKUI.gd
git commit -m "feat: rail brand plaque and right-aligned version (VTKUI)"
```

---

### Task 2: Каркас трёх колонок (`_build_set_preview`) и колонка управления

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd:546-555` (`_build_set_preview`), рядом с ним новый `_make_control_column`
- Modify: `loadouts/mods/VTK/VTKUI.gd:1714-1745` (`_make_equip_preview`), `1830-1861` (`_make_inventory_panel`)
- Modify: `loadouts/mods/VTK/VTKLoc.gd` — удалить `'grid 8 columns'`
- Modify: `.check/layout_check.py` (GONE/PRESENT/FUNCS) — не коммитится
- Test: `py .check\layout_check.py`, `check.ps1`, `python .check\keycheck.py`

**Interfaces:**
- Consumes: `_make_equip_preview(eq)`, `_make_inventory_wall(gear)` (VTKUI.gd:1781), `VTKSurface.style_button(...)`, `Loc.txt("Controls")`, `Loc.txt("Equipment")`, `Loc.txt("Inventory")`.
- Produces:
  - `_build_set_preview(eq: Dictionary, gear: Array, fill := true, controls: Control) -> Control` — три колонки; без `title`.
  - `_make_control_column(title: String, buttons: Array) -> Control` — панель-колонка с шапкой и вертикальным стеком кнопок.

- [ ] **Step 1: Новый хелпер `_make_control_column`**

Вставить перед `_build_set_preview` (VTKUI.gd:546):

```gdscript
# Колонка управления превью/Done: шапка + вертикальный стек кнопок.
# Принимает готовые кнопки (стиль и текст задаёт вызывающий), раскладывает
# их столбиком по центру высоты колонки. Панель тянется по вертикали.
func _make_control_column(title: String, buttons: Array) -> Control:
	var panel := VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 6)
	var head := Label.new()
	head.text = title
	head.add_theme_font_size_override("font_size", 9)
	head.add_theme_color_override("font_color", _gold)
	head.add_theme_constant_override("letter_spacing", 1)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(head)
	var stack := VBoxContainer.new()
	stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stack.add_theme_constant_override("separation", 4)
	for btn in buttons:
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stack.add_child(btn)
	panel.add_child(stack)
	return panel
```

- [ ] **Step 2: Каркас `_build_set_preview` — три колонки**

Заменить тело `_build_set_preview` (VTKUI.gd:546-555):

```gdscript
func _build_set_preview(eq: Dictionary, gear: Array, fill := true, controls: Control = null) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL if fill else Control.SIZE_SHRINK_BEGIN
	row.add_child(_make_equip_preview(eq))
	row.add_child(_make_inventory_panel(gear))
	if controls != null:
		row.add_child(controls)
	return row
```

- [ ] **Step 3: `_make_equip_preview` перестаёт принимать `title`**

Заменить сигнатуру (VTKUI.gd:1714) `func _make_equip_preview(title: String, eq: Dictionary) -> Control:` на `func _make_equip_preview(eq: Dictionary) -> Control:` и заголовок (1721-1726):

```gdscript
	var head := Label.new()
	head.text = Loc.txt("Equipment").to_upper()
	head.add_theme_font_size_override("font_size", 9)
	head.add_theme_color_override("font_color", _gold)
	head.add_theme_constant_override("letter_spacing", 1)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(head)
```

Панель колонки (1716-1718) перевести на растяжение по вертикали:

```gdscript
	panel.custom_minimum_size = Vector2(EQ_COL_W, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
```

- [ ] **Step 4: `_make_inventory_panel` без счётчика**

Заменить сигнатуру (VTKUI.gd:1830) `func _make_inventory_panel(gear: Array, meta: String = "") -> Control:` на `func _make_inventory_panel(gear: Array) -> Control:` и шапку (1836-1851): убрать `meta_lbl`, оставить только `ttl`, добавить `letter_spacing` и капс:

```gdscript
	var head := HBoxContainer.new()
	var ttl := Label.new()
	ttl.text = Loc.txt("Inventory").to_upper()
	ttl.add_theme_font_size_override("font_size", 9)
	ttl.add_theme_color_override("font_color", _gold)
	ttl.add_theme_constant_override("letter_spacing", 1)
	ttl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(ttl)
	panel.add_child(head)
```

Панель (1832-1835) перевести на растяжение по вертикали:

```gdscript
	panel.custom_minimum_size = Vector2(INVEN_COLS * INVEN_CELL + (INVEN_COLS - 1) * INVEN_GAP + 12, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
```

- [ ] **Step 5: Удалить ключ `grid 8 columns` из словаря**

В `loadouts/mods/VTK/VTKLoc.gd:172` удалить строку `'grid 8 columns': 'сетка 8 колонок',`. Потребитель (`meta` в `_build_set_preview`) удалён в этом же изменении, `keycheck.py` не даст ни `MISSING`, ни `unused`.

- [ ] **Step 6: Маркеры стенда раскладки**

В `.check/layout_check.py`:

- `GONE`: добавить `"grid 8 columns"` (возврат счётчика в шапку панели инвентаря) и `"_make_slot_badge"` не нужно — нет. Достаточно `"grid 8 columns"`.
- `PRESENT`: добавить `"_make_control_column"`.
- `FUNCS` — заменить запись `("_build_set_preview", [...])`:

```python
    ("_build_set_preview", [
        "_make_equip_preview(eq)",
        "_make_inventory_panel(gear)",
        "if fill else Control.SIZE_SHRINK_BEGIN",
    ], "превью: три колонки экипировка|инвентарь|управление, Done по содержимому"),
```

- [ ] **Step 7: Проверить стенды и keycheck**

Run: `py .check\layout_check.py`
Expected: зелёные; `_make_control_column` в PRESENT; `grid 8 columns` в GONE; FUNCS `_build_set_preview` проходит по телу (используются `_make_equip_preview(eq)` и `_make_inventory_panel(gear)`).

Run: `python .check\keycheck.py`
Expected: `grid 8 columns` отсутствует и в коде, и в неиспользуемых; новых `MISSING`/`unused` для ключей этой задачи нет.

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: нет `SCRIPT ERROR` / `Parse Error` / `Invalid call` / `Failed to load script`, есть `tests passed`.

- [ ] **Step 8: Коммит**

```bash
git add loadouts/mods/VTK/VTKUI.gd loadouts/mods/VTK/VTKLoc.gd
git commit -m "feat: preview and Done share a three-column frame with a control column (VTKUI)"
```

---

### Task 3: Превью — шапка карточки и кнопки в колонку Управление

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd:558-639` (`_refresh_preview`)
- Modify: `loadouts/mods/VTK/VTKLoc.gd` — добавить `Controls`, `Delete`, `Loadout`, `' items'`
- Modify: `.check/layout_check.py` (GONE/PRESENT/FUNCS) — не коммитится
- Test: `py .check\layout_check.py`, `check.ps1`, `python .check\keycheck.py`

**Interfaces:**
- Consumes: `_build_set_preview(eq, gear, fill, controls)` из Task 2, `_make_control_column(title, buttons)`, `LD.get_set(_selected_set)` (VTKData), `_keycode_to_string(qk)`, `_begin_bind(_selected_set, qk_btn)`, `_delete_loadout`, `_edit_loadout`, `LD.load_loadout`, `VTKSurface.style_button(btn, accent, danger)`.
- Produces: шапка карточки (имя кремовое + подпись «Раскладка · N предметов»); колонка Управление с кнопками Применить/Изменить/клавиша/Удалить.

- [ ] **Step 1: Loc-ключи для превью**

В `loadouts/mods/VTK/VTKLoc.gd` в `const RU := {` добавить (в алфавитном месте — рядом с `'Categories'`/`'Cancel'`):

```gdscript
	'Controls': 'Управление',
```

Рядом с `'Delete'` — добавить:

```gdscript
	'Delete': 'Удалить',
```

Рядом с `'Loadout name required'` — добавить:

```gdscript
	'Loadout': 'Раскладка',
```

Рядом с `' items · '` (VTKLoc.gd:171) — добавить:

```gdscript
	' items': ' предметов',
```

Все четыре ключа получают потребителя именно в этой ревизии (Step 2–3), поэтому `keycheck.py` будет зелёным.

- [ ] **Step 2: Шапка карточки**

Заменить блок `head`/`nm`/`kb` (VTKUI.gd:580-597). Убрать хоткей-бейдж `kb` целиком, имя сделать кремовым `#d8cdbe`, под ним подпись «Раскладка · N предметов»:

```gdscript
	var card_head := VBoxContainer.new()
	card_head.add_theme_constant_override("separation", 2)
	var nm := Label.new()
	nm.text = str(pack.get("name", _selected_set))
	nm.add_theme_font_size_override("font_size", 14)
	nm.add_theme_color_override("font_color", Color("#d8cdbe"))
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_head.add_child(nm)
	var cap := Label.new()
	cap.text = (Loc.txt("Loadout") + " · " + str(gr_a.size()) + Loc.txt(" items")).to_upper()
	cap.add_theme_font_size_override("font_size", 9)
	cap.add_theme_color_override("font_color", Color("#5f5347"))
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_head.add_child(cap)
	_preview_box.add_child(card_head)
```

Переменные `eq_d`/`gr_a` (599-600) объявлены ниже `head`; перенести их объявления **выше** `card_head` (перед Step 2 блоком), иначе `gr_a` недоступна. Итоговый порядок в `_refresh_preview`: пустой набор → назначение `pack` → `eq_d`/`gr_a` → шапка карточки → колонки.

- [ ] **Step 3: Кнопки из `actions` в колонку Управление**

Удалить блок `var actions := HBoxContainer.new()` … `_preview_box.add_child(actions)` (VTKUI.gd:602-635, 639). Вместо него собрать четыре кнопки и передать в колонку:

```gdscript
	var apply_btn := Button.new()
	apply_btn.text = Loc.txt("Apply")
	VTKSurface.style_button(apply_btn, true)
	apply_btn.pressed.connect(func(): LD.load_loadout(_selected_set))
	var edit_btn := Button.new()
	edit_btn.text = Loc.txt("Edit")
	VTKSurface.style_button(edit_btn)
	edit_btn.pressed.connect(func(): _edit_loadout(_selected_set))
	var qk_btn := Button.new()
	qk_btn.add_theme_font_size_override("font_size", 9)
	if qk > 0:
		qk_btn.text = _keycode_to_string(qk)
		qk_btn.add_theme_color_override("font_color", _gold)
	else:
		qk_btn.text = "?"
		qk_btn.add_theme_color_override("font_color", Color("#444"))
	VTKSurface.style_button(qk_btn, qk > 0)
	qk_btn.pressed.connect(func(): _begin_bind(_selected_set, qk_btn))
	var del_btn := Button.new()
	del_btn.text = Loc.txt("Delete")
	VTKSurface.style_button(del_btn, false, true)
	del_btn.pressed.connect(func(): _delete_loadout(_selected_set))

	_preview_box.add_child(_build_set_preview(
		eq_d, gr_a, true,
		_make_control_column(Loc.txt("Controls").to_upper(), [apply_btn, edit_btn, qk_btn, del_btn])))
```

Переменная `qk` объявлена выше (VTKUI.gd:589) — оставить как есть.

- [ ] **Step 4: Маркеры стенда**

В `.check/layout_check.py`:

- `GONE`: добавить `'del_btn.text = "✕"'` (текстовая «Удалить» вместо крестика в превью). Строку `var actions := HBoxContainer.new()` НЕ добавлять в GONE на этом шаге: вторая такая строка живёт в `_build_page_done` (`VTKUI.gd:1522`) и удаляется в Task 4 — добавь её в GONE там.
- `PRESENT`: добавить `Loc.txt("Loadout")`, `"Loc.txt(\" items\")"`, `"Loc.txt(\"Delete\")"`. Не `' items'`: подстрока ` items` матчится и с сохраняющимся `' items · '` (карточка сетов, VTKUI.gd:2387), что не доказывает использование нового ключа подписи.
- `FUNCS` — добавить запись по телу `_refresh_preview`:

```python
    ("_refresh_preview", [
        "_make_control_column(Loc.txt(\"Controls\")",
        "Loc.txt(\"Delete\")",
    ], "превью: кнопки в колонке Управление, удаление текстом"),
```

- [ ] **Step 5: Проверить стенды и keycheck**

Run: `py .check\layout_check.py`
Expected: зелёные; GONE ловит `del_btn.text = "✕"`, PRESENT — новые ключи, FUNCS `_refresh_preview` проходит.

Run: `python .check\keycheck.py`
Expected: `Controls`, `Delete`, `Loadout`, ` items` использованы и в словаре; лишних `unused` нет (кроме известных, неотносимых к задаче).

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: нет `SCRIPT ERROR` / `Parse Error` / `Invalid call` / `Failed to load script`, есть `tests passed`.

- [ ] **Step 6: Коммит**

```bash
git add loadouts/mods/VTK/VTKUI.gd loadouts/mods/VTK/VTKLoc.gd
git commit -m "feat: preview card header with loadout caption, actions moved into control column (VTKUI)"
```

---

### Task 4: Done — кнопки Сохранить/Отмена в колонку, подпись счётчика

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd:1473-1537` (`_build_page_done`), `1541-1551` (`_refresh_page_done`)
- Modify: `.check/layout_check.py` (GONE — `var actions`, FUNCS — `_build_page_done`) — не коммитится
- Test: `py .check\layout_check.py`, `check.ps1`, `python .check\keycheck.py`

**Interfaces:**
- Consumes: `_build_set_preview(eq, gear, fill, controls)` из Task 2, `_make_control_column(title, buttons)` из Task 2, `_save_loadout`, `_cancel_draft`, `_draft.equip`/`_draft.gear`/`_draft.set_name`, `Loc.txt("Loadout")`/`Loc.txt(" items")` (Task 3).
- Produces: `_done_preview` собирается через каркас с колонкой Сохранить/Отмена; `_done_meta: Label` — подпись счётчика под строкой имени.

- [ ] **Step 1: Поле подписи счётчика**

Рядом с `var _done_preview: Control = null` (VTKUI.gd:100) добавить:

```gdscript
var _done_meta: Label = null
```

- [ ] **Step 2: `_build_page_done` — превью с колонкой и подпись**

Заменить блок построения `_done_preview` и `name_row` (VTKUI.gd:1476-1518): превью собрать через каркас с готовой колонкой Сохранить/Отмена, под строкой имени добавить подпись счётчика.

Превью (1480):

```gdscript
	_done_preview = _build_set_preview({}, [], false,
		_make_control_column(Loc.txt("Controls").to_upper(), []))
	v.add_child(_done_preview)
```

После `v.add_child(name_row)` (1518) вставить подпись:

```gdscript
	_done_meta = Label.new()
	_done_meta.add_theme_font_size_override("font_size", 9)
	_done_meta.add_theme_color_override("font_color", Color("#5f5347"))
	_done_meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_done_meta)
```

Комментарий «Порядок из макета» (1476-1479) поправить: превью — трёхколоночный каркас, строка имени с подписью счётчика за ним.

**Удалить блок `actions` целиком** (VTKUI.gd:1520-1536): строку с комментарием «Две кнопки одного размера…» и три переменные `actions`/`save_btn`/`cancel_btn` — эти кнопки теперь пересоздаются в `_refresh_page_done` (Step 3) внутри колонки Управление. Без этого удаления Сохранить и Отмена будут висеть и в строке под карточкой (дубль), а GONE `var actions := HBoxContainer.new()` не сойдётся (вторая строка останется в файле).

- [ ] **Step 3: `_refresh_page_done` — кнопки и счётчик**

Заменить тело `_refresh_page_done` (1541-1551):

```gdscript
func _refresh_page_done() -> void:
	if _done_preview == null:
		return
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
		_make_control_column(Loc.txt("Controls").to_upper(), [save_btn, cancel_btn])))
	if _done_meta != null:
		_done_meta.text = (Loc.txt("Loadout") + " · " +
			str((_draft.gear if _draft else []).size()) + Loc.txt(" items")).to_upper()
```

- [ ] **Step 4: Маркеры стенда**

В `.check/layout_check.py` `FUNCS` добавить запись по телу `_build_page_done`:

```python
    ("_build_page_done", [
        "_build_set_preview({}, [], false,",
        "_done_meta",
    ], "Done: каркас трёх колонок с колонкой управления, подпись счётчика под именем"),
```

- [ ] **Step 5: Проверить стенды и keycheck**

Run: `py .check\layout_check.py`
Expected: зелёные; FUNCS `_build_page_done` проходит.

Run: `python .check\keycheck.py`
Expected: `Controls`/`Loadout`/` items` дважды использованы (превью + Done), лишних `unused` нет.

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: нет `SCRIPT ERROR` / `Parse Error` / `Invalid call` / `Failed to load script`, есть `tests passed`.

- [ ] **Step 6: Коммит**

```bash
git add loadouts/mods/VTK/VTKUI.gd
git commit -m "feat: Done page uses three-column frame with save/cancel in control column (VTKUI)"
```

---

### Task 5: Сборка и версия

**Files:**
- Modify: `loadouts/mod.txt` (версия)
- Test: `py .check\layout_check.py`, `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`, `python .check\keycheck.py`, `python .check\encoding_check.py`, `python .check\mojibake_scan.py`, `py .check\layout_check.py`

**Interfaces:**
- Consumes: готовые задачи 1–4.
- Produces: `Loadouts.vmz` (артефакт), версия в `mod.txt`.

- [ ] **Step 1: Все стенды**

Run: `py .check\layout_check.py` → зелёные.
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1` → `tests passed`.
Run: `python .check\keycheck.py` → нет `MISSING`/`unused` по ключам задач 1–4.
Run: `python .check\encoding_check.py` и `python .check\mojibake_scan.py` → кодировка чистая.

- [ ] **Step 2: Версия — спросить пользователя**

Финальное значение запросить у пользователя перед записью в `loadouts/mod.txt` (например `4.13.1` или `4.14.0` — решение за пользователем). Текущее значение в дереве — `4.13.0` (незакоммичено). Записать:

```text
[mod]name="Vostok Toolkit"id="vostok-toolkit"version="<выбранная>"[autoload]VTKUI="res://mods/VTK/VTKUI.gd"
```

- [ ] **Step 3: Сборка и копирование**

Run: `powershell -ExecutionPolicy Bypass -File pack.ps1`
Expected: печатает версию из `mod.txt` перед упаковкой; `Loadouts.vmz` создан.

Скопировать `Loadouts.vmz` в папку модов игры. Ручная проверка в игре: превью и Done как макет; нижние края колонок вровень; >64 стеков растягивают колонки со стеной; Применить/Изменить/клавиша/Удалить работают; в Done Сохранить/Отмена; хоткей виден один раз; подпись «Раскладка · N предметов» в превью и в Done; рейл — плашка «V» и версия справа.

- [ ] **Step 4: Коммит (по согласию)**

```bash
git add loadouts/mod.txt
git commit -m "release: three-column preview and Done layout (<выбранная> версия)"
```

---

## Self-Review

**1. Spec coverage:**
- Рейл с плашкой и версией справа → Task 1. ✅
- Каркас трёх колонок, `_make_control_column` → Task 2. ✅
- Шапка карточки (кремовое имя + «Раскладка · N предметов»), убирание хоткей-бейджа → Task 3. ✅
- Кнопки превью в колонку Управление, Удалить текстом → Task 3. ✅
- Done D2 (имя-строка над карточкой, Сохранить/Отмена в колонку, подпись счётчика) → Task 4. ✅
- Убирание счётчика из шапки панели инвентаря, `grid 8 columns` из словаря → Task 2. ✅
- ` items · ` остаётся (карточка списка сетов VTKUI.gd:2387) — план его не трогает. ✅
- Стенды GONE/PRESENT/FUNCS → каждой задачей. ✅
- Версия — не фиксируется, запрос на этапе сборки. ✅
- Вне области (шаги 1–2, `_make_item_cell`, спавнер) — не трогаются. ✅

**2. Placeholder scan:** «Куски» заменено фактическим кодом: вставки для `_build_ui`, `_make_control_column`, `_build_set_preview`, `_make_equip_preview`, `_make_inventory_panel`, `_refresh_preview`, `_build_page_done`, `_refresh_page_done`. Один осознанный фрагмент Task 4 Step 1: `_done_preview` в `_build_page_done` создаётся с пустым массивом кнопок (до `_refresh_page_done`), — это осознанный трэйс, прокомментирован.

**3. Type consistency:**
- `_build_set_preview(eq, gear, fill, controls)` — одинаково в Task 2 (сигнатура), Task 3 (вызов с `eq_d, gr_a, true, ...`), Task 4 (вызов с `{}, [], false, ...`). ✅
- `_make_control_column(title, buttons: Array) -> Control` — единообразен. ✅
- `_done_meta: Label` — объявлен (Task 4 Step 1), используется в Step 2–3. ✅
- `_make_equip_preview(eq)`, `_make_inventory_panel(gear)` — согласованы с Task 2. ✅
- Loc-ключи `Controls`/`Delete`/`Loadout`/` items` вводятся до первого использования. ✅