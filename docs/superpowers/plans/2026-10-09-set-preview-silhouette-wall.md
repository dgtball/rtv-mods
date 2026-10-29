# Превью сета: силуэт + стена инвентаря — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Заменить текстовую сводку сета (`_fill_summary`) визуальной двухпанельной картинкой: слева экипировка как S1 (оружие + силуэт + мелкие слоты, read-only), справа «стена инвентаря» с предметами `gear` и реальными размерами ячеек; в двух местах — правая колонка «Сеты» и шаг 3 «Готово».

**Architecture:** Один общий билдер превью кормится либо `pack` (превью), либо `_draft` (шаг 3). Клетки экипировки — уже существующие `_make_equip_cell`/`_make_weapon_cell` с новым read-only режимом (desc передаётся аргументом, интерактив отключается). Стена — ручная раскладка по строкам с первым подходящим местом, размер ячеек из реального поля `size`.

**Tech Stack:** GDScript (Godot 4.6.3), стенды `.check/` (parse + headless-тесты + layout_check + keycheck + encoding).

## Global Constraints

- Версия в `loadouts/mod.txt` (поле `version`) — единственное место; bump до `4.9.1` (задача 7).
- VTKUI.gd и VTKPicker.gd — только табы и CRLF; остальные VTK*.gd — LF.
- Коммитить только `loadouts/**`; one-liner по-английски; `README.md`, `docs/`, `.check/`, `AGENTS.md`, `.docs/` не коммитятся.
- Ключи словаря: EN-ключ = английская строка; новая UI-строка = новая запись в `RU` тем же проходом. `Loc.txt()`, не `tr()`.
- Одинарные кавычки для строк с кавычкой: `'Loadout "'`.
- Клетки сетки не должны матчить GONE-строки `layout_check.py` (переменная зовётся `box`, не `cell`/`eqcell`).
- Мёртвый код удаляется: stale-ключи из VTKLoc.gd и мёртвые функции (keycheck/layout словит).
- Имена предметов/слотов НЕ локализуются (из Database).
- `.gd` UTF-8; новый русский текст проверять `encoding_check.py`.

---
## Task 1: Read-only режим клеток экипировки

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd` — `_make_equip_cell` (~1692), `_make_weapon_cell` (~1757), `_make_body_zone` (~1823)

**Interfaces:**
- Consumes: `_equip_cell_style(active, hover, occupied)` (есть), `Picker.item_art`, `_cell_resource(desc)`, `_item_icon(res)`, `_make_dot(color)`, `_make_mini_btn`, Loc.
- Produces: `_make_equip_cell(slot: String, min_h: int, desc: Dictionary = {}, interactive := true) -> Control`, `_make_weapon_cell(slot: String, desc: Dictionary = {}, interactive := true) -> Control`, `_make_body_zone(slots: Array, eq: Dictionary = {}, interactive := true) -> Control`.

- [ ] **Step 1: Поменять сигнатуры и логику источника описания**

`_make_equip_cell`: получить `desc` аргументом; если пустой И interactive — фолбэк на `_draft.equip.get(slot)` (прежнее поведение для шага экипировки). При `interactive == false`: не вешать `_attach_row_hover`, `_attach_motion`, `gui_input`→`_on_slot_row_input`, не ставить кнопку ✕; активная подсветка `_target_slot` не используется (active=false). Тултип и точка занятости как сейчас.

```gdscript
func _make_equip_cell(slot: String, min_h: int, desc: Dictionary = {}, interactive := true) -> Control:
	var src: Dictionary = desc
	if src.is_empty() and interactive:
		if _draft != null:
			var raw = _draft.equip.get(slot)
			if typeof(raw) == TYPE_DICTIONARY:
				src = raw
	var occupied := not src.is_empty()
	var box := Panel.new()
	box.custom_minimum_size = Vector2(0, min_h)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.clip_contents = true
	box.tooltip_text = str(src.get("name", Loc.txt(slot))) if occupied else Loc.txt(slot)
	box.add_theme_stylebox_override("panel", _equip_cell_style(false, false, occupied))
	if interactive:
		_attach_row_hover(box, func(hv: bool): return _equip_cell_style(false, hv, occupied))
		_attach_motion(box)
		box.gui_input.connect(func(ev): _on_slot_row_input(ev, slot, src))
	# центр, иконка/подпись, точка — без изменений от текущего кода, источник src вместо desc
	...
	if interactive and occupied:
		var drop := _make_mini_btn("✕", Vector2(16, 16), 8)
		drop.tooltip_text = Loc.txt("Remove")
		drop.add_theme_color_override("font_color", Color("#e05a4a"))
		drop.pressed.connect(func(): _remove_slot(slot))
		box.add_child(drop)
		drop.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		drop.offset_left = 2
		drop.offset_top = 2
		drop.offset_right = 18
		drop.offset_bottom = 18
	...
```

Примечание: в текущем коде точка/✕/иконка добавляются на `box` с `set_anchors_and_offsets_preset`; менять их порядок нельзя. иконка — `_item_icon(_cell_resource(src))`. Всё тело после «box.add_child(center)» менять не нужно, только переменные `desc`/`raw`.

`_make_weapon_cell` — то же самое: `desc` параметром, фолбэк на `_draft`, при `interactive == false` без hover/motion/gui_input/✕. Раскладка иконка+имя слева остаётся.

`_make_body_zone(slots, eq = {}, interactive := true)` — при непустом `eq` передавать `_make_equip_cell(str(slot), EQ_CELL_H, eq.get(str(slot), {}), interactive)`, иначе прежний вызов `_make_equip_cell(str(slot), EQ_CELL_H)`.

- [ ] **Step 2: Проверить существующие вызовы не сломаны**

Существующие вызовы (`_refresh_slots`: `_make_body_zone(body)`, `_make_equip_cell(str(slot), EQ_SMALL_H)`, `_make_weapon_cell(str(slot))`) — с умолчаниями interactive=true — дают прежнее поведение.

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1` → parse 11 скриптов, exit 0, `tests passed`.

- [ ] **Step 3: layout_check**

`python .check\layout_check.py` → списки не меняются (символы прежние).

- [ ] **Step 4: Commit**

```bash
git add loadouts/mods/VTK/VTKUI.gd
git commit -m "feat: read-only mode for equipment grid cells"
```

---
## Task 2: Левая панель превью `_make_equip_preview`

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd` (после `_make_body_zone`)

**Interfaces:**
- Consumes: `Picker.equip_layout`, `Picker.all_slots`, `_make_weapon_cell(slot, desc, false)`, `_make_body_zone(slots, eq, false)`, `_make_equip_cell(slot, h, desc, false)`, `VTKSurface.panel`.
- Produces: `_make_equip_preview(title: String, eq: Dictionary) -> Control` — готовый контейнер левой панели (заголовок + оружие + силуэт + мелкие, read-only).

- [ ] **Step 1: Написать билдер**

```gdscript
func _make_equip_preview(title: String, eq: Dictionary) -> Control:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(318, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 6)
	panel.add_theme_stylebox_override("panel", VTKSurface.panel(true, 6))
	var head := Label.new()
	head.text = title
	head.add_theme_font_size_override("font_size", 9)
	head.add_theme_color_override("font_color", Color("#5f5347"))
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(head)
	var lists: Array = []
	for it in _db_items:
		if it != null:
			lists.append(it.get("slots"))
	var layout := Picker.equip_layout(Picker.all_slots(lists))
	var weap: Array = layout.get("weapons", [])
	if not weap.is_empty():
		var wbox := VBoxContainer.new()
		wbox.add_theme_constant_override("separation", EQ_GAP)
		for slot in weap:
			wbox.add_child(_make_weapon_cell(str(slot), eq.get(str(slot), {}), false))
		panel.add_child(wbox)
	var body: Array = layout.get("body", [])
	if not body.is_empty():
		panel.add_child(_make_body_zone(body, eq, false))
	var small: Array = layout.get("small", [])
	if not small.is_empty():
		var sgrid := GridContainer.new()
		sgrid.columns = 2
		sgrid.add_theme_constant_override("h_separation", EQ_GAP)
		sgrid.add_theme_constant_override("v_separation", EQ_GAP)
		for slot in small:
			sgrid.add_child(_make_equip_cell(str(slot), EQ_SMALL_H, eq.get(str(slot), {}), false))
		panel.add_child(sgrid)
	if weap.is_empty() and body.is_empty() and small.is_empty():
		var ph := Label.new()
		ph.text = Loc.txt("Set is empty")
		ph.add_theme_font_size_override("font_size", 11)
		ph.add_theme_color_override("font_color", Color("#666666"))
		ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(ph)
	return panel
```

Требование к GONE-строкам: переменные клеток называются `box` (внутри клеток), здесь — `wbox`/`sgrid`/`panel`; строка `cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL` появляться не должна.

- [ ] **Step 2: Проверка**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1` → parse OK. `python .check\layout_check.py` → `_make_equip_preview` добавить в `PRESENT` (обновить `layout_check.py`, файл не коммитится) — ожидаем GONE не изменён, PRESENT +1.

- [ ] **Step 3: Commit**

```bash
git add loadouts/mods/VTK/VTKUI.gd
git commit -m "feat: equipment preview panel with silhouette"
```

---
## Task 3: Стена инвентаря `_make_inventory_wall`

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd` (после `_make_equip_preview`)
- Modify: `.check/layout_check.py` (не коммитится)

**Interfaces:**
- Consumes: `_cell_resource(desc)`, `_item_icon(res)`, `Picker.item_art`, `Draft.shown_count(desc)`, `VTKSurface.surface/panel`, `_gold`.
- Produces: `_gear_cell_size(desc: Dictionary) -> Vector2i`, `_wall_item(desc: Dictionary) -> Control`, `_make_inventory_panel(gear: Array, meta: String) -> Control`.

- [ ] **Step 1: Размер ячейки из реального поля `size`**

Пустой/без ресурса → `Vector2i(1,1)`. `size` из ресурса — Vector2 ячеек; округлить, минимум 1, ширина не больше 8.

```gdscript
func _gear_cell_size(desc: Dictionary) -> Vector2i:
	if desc.is_empty():
		return Vector2i(1, 1)
	var res: Variant = _cell_resource(desc)
	if res == null:
		return Vector2i(1, 1)
	var sz: Variant = res.get("size")
	if typeof(sz) == TYPE_VECTOR2:
		var s: Vector2 = sz
		return Vector2i(clampi(roundi(s.x), 1, 8), maxi(1, roundi(s.y)))
	return Vector2i(1, 1)
```

- [ ] **Step 2: Ячейка предмета**

```gdscript
func _wall_item(desc: Dictionary) -> Control:
	var sz := _gear_cell_size(desc)
	var w := sz.x
	var h := sz.y
	var box := Panel.new()
	box.custom_minimum_size = Vector2(w * INVEN_CELL + (w - 1) * INVEN_GAP, h * INVEN_CELL + (h - 1) * INVEN_GAP)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.clip_contents = true
	box.tooltip_text = str(desc.get("name", "?"))
	box.add_theme_stylebox_override("panel", VTKSurface.surface("normal"))
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
			q.offset_left = -20
			q.offset_top = -14
			q.offset_right = -2
			q.offset_bottom = -2
			box.add_child(q)
	return box
```

Константы рядом с базой: `const INVEN_CELL := 48`, `const INVEN_COLS := 8`, `const INVEN_GAP := 3`.

- [ ] **Step 3: Стена с укладкой «первая подходящая строка»**

Укладка: идём по `gear`, держим текущую свободную колонку `col` и максимальную высоту строки `row_h`; если `col + w > INVEN_COLS` — переход на новую строку (`row += row_h`, `col = 0`, `row_h = 0`). Клетка позиционируется внутрь `wall` через `set_position(Vector2(col * (INVEN_CELL + INVEN_GAP), row))`, `set_size(Vector2(w * INVEN_CELL + (w - 1) * INVEN_GAP, h * INVEN_CELL + (h - 1) * INVEN_GAP))`. После цикла `wall.custom_minimum_size = Vector2(INVEN_COLS * INVEN_CELL + (INVEN_COLS - 1) * INVEN_GAP, row + row_h)`.

```gdscript
func _make_inventory_wall(gear: Array) -> Control:
	var wall := Control.new()
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wall.clip_contents = true
	var col := 0
	var row := 0.0
	var row_h := 0
	for desc in gear:
		if typeof(desc) != TYPE_DICTIONARY:
			continue
		var s := _gear_cell_size(desc)
		if col + s.x > INVEN_COLS:
			row += float(row_h * (INVEN_CELL + INVEN_GAP))
			col = 0
			row_h = 0
		var item := _wall_item(desc)
		item.position = Vector2(col * (INVEN_CELL + INVEN_GAP), row)
		item.size = Vector2(s.x * INVEN_CELL + (s.x - 1) * INVEN_GAP, s.y * INVEN_CELL + (s.y - 1) * INVEN_GAP)
		wall.add_child(item)
		col += s.x
		row_h = maxi(row_h, s.y)
	wall.custom_minimum_size = Vector2(INVEN_COLS * INVEN_CELL + (INVEN_COLS - 1) * INVEN_GAP, row + float(row_h * INVEN_CELL + (row_h - 1) * INVEN_GAP))
	return wall
```

- [ ] **Step 4: Панель «Инвентарь»**

```gdscript
func _make_inventory_panel(gear: Array, meta: String = "") -> Control:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(INVEN_COLS * INVEN_CELL + (INVEN_COLS - 1) * INVEN_GAP + 12, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 6)
	var head := HBoxContainer.new()
	var ttl := Label.new()
	ttl.text = Loc.txt("Inventory")
	ttl.add_theme_font_size_override("font_size", 9)
	ttl.add_theme_color_override("font_color", _gold)
	ttl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(ttl)
	var meta_lbl := Label.new()
	meta_lbl.text = meta
	meta_lbl.add_theme_font_size_override("font_size", 9)
	meta_lbl.add_theme_color_override("font_color", Color("#5f5347"))
	meta_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	meta_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(meta_lbl)
	panel.add_child(head)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 6)
	pad.add_theme_constant_override("margin_top", 6)
	pad.add_theme_constant_override("margin_right", 6)
	pad.add_theme_constant_override("margin_bottom", 6)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wall := _make_inventory_wall(gear)
	pad.add_child(wall)
	panel.add_child(pad)
	return panel
```

Внимание на AGENTS: вертикальный `SIZE_EXPAND_FILL` обязан дойти до области под предметы — здесь панель превью сама внутри скролла, поэтому размер задан `custom_minimum_size`, а не флагом.

- [ ] **Step 5: layout_check + проверка**

`python .check\layout_check.py`: добавить `_make_inventory_wall`/`_make_inventory_panel`/`INVEN_COLS` в `PRESENT`. GONE не трогать (строки с `box.` на клетках не матчат). `check.ps1` — parse OK.

- [ ] **Step 6: Commit**

```bash
git add loadouts/mods/VTK/VTKUI.gd
git commit -m "feat: inventory wall with real item sizes"
```

---
## Task 4: Общий билдер и врезка в два места

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd` — `_refresh_preview` (~526-626), `_build_page_done` (~1454-1471, 1520-1528), `_refresh_page_done` (~1534-1541); новые переменные `_done_preview` вместо `_done_summary/_done_equip_col/_done_gear_col`

**Interfaces:**
- Consumes: `_make_equip_preview(title, eq)`, `_make_inventory_panel(gear, meta)`, `_gold`, Loc, `VTKSurface.style_button`, `_keycode_to_string`.
- Produces: `_build_set_preview(title: String, eq: Dictionary, gear: Array) -> Control` (+ строка мета «N items · grid 8 columns»).

- [ ] **Step 1: Общий билдер**

```gdscript
func _build_set_preview(title: String, eq: Dictionary, gear: Array) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(_make_equip_preview(title, eq))
	var meta := str(gear.size()) + Loc.txt(" items \u00b7 ") + Loc.txt("grid 8 columns")
	row.add_child(_make_inventory_panel(gear, meta))
	return row
```

- [ ] **Step 2: Врезка в `_refresh_preview`**

Заменить блок «Состав — теми же строками...» (создание `cols`/`ec`/`gc`, `Draft.new()`, `d.load_from(pack)`, `_fill_summary(d, ec, gc)`) на:

```gdscript
	var eq_d: Dictionary = pack.get("equip", {})
	var gr_a: Array = pack.get("gear", [])
	_preview_box.add_child(_build_set_preview(
		Loc.txt("Equipment") + " \u00b7 " + str(pack.get("name", _selected_set)), eq_d, gr_a))
```

Порядок действий в макете: шапка (имя+хоткей), мета «N items · M in equipment» (уже есть), затем панели превью, затем футер кнопок. Сейчас кнопки вставляются до колонок — перенести вставку `actions` в `_preview_box` в конец (после `_build_set_preview`). Мета-строку выше (567-573) подставить под панели или оставить на месте — по макету «Экипировка · имя» уходит в заголовок левой панели, мета в шапку правой панели; строка `meta` (570) из превью удаляется.

- [ ] **Step 3: Врезка в «Готово»**

В `_build_page_done` заменить создание `_done_summary`/`_done_equip_col`/`_done_gear_col` (строки про триколоночную сводку) на одну переменную `_done_preview: Control = _build_set_preview(...)` (пустой, наполняется в `_refresh_page_done`). В `_ready`-вызове `_refresh_page_done()` прогнать. В `_refresh_page_done` очищать `_done_preview` и пересобирать:

```gdscript
func _refresh_page_done() -> void:
	if _done_preview == null:
		return
	for child in _done_preview.get_children():
		_done_preview.remove_child(child)
		child.queue_free()
	_done_preview.add_child(_build_set_preview(
		Loc.txt("Equipment") + " \u00b7 " + str(_draft.set_name if _draft else ""),
		_draft.equip if _draft else {},
		_draft.gear if _draft else []))
```

Объявления полей: `var _done_preview: Control = null` (заменить `_done_summary`/`_done_equip_col`/`_done_gear_col`).

- [ ] **Step 4: Проверка**

`check.ps1` parse OK. `layout_check.py`: PR FUNCS «превью — не интерактив» не требуется; убедиться, что `_refresh_page_done` не матчит GONE. `keycheck.py`: ключи `Inventory`, `grid 8 columns` могут ещё не быть — см. Task 5 (порядок: сначала Task 5, потом суставной прогон). Если keycheck падает на этом шаге — это ожидаемо, зелёным становится после Task 5.

- [ ] **Step 5: Commit**

```bash
git add loadouts/mods/VTK/VTKUI.gd
git commit -m "feat: preview and Done page use visual set preview"
```

---
## Task 5: Мёртвый код и ключи

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd` — удалить `_fill_summary`, `_summary_head`, `_summary_line`, `_equip_row_text`
- Modify: `loadouts/mods/VTK/VTKLoc.gd` — удалить stale-ключи RU
- Modify (не коммитится): `.check/keycheck.py` — без правок, просто прогнать

- [ ] **Step 1: Удалить мёртвые функции**

После Task 4 у `_fill_summary`/`_summary_head`/`_summary_line`/`_equip_row_text` не осталось вызовов. Удалить целиком (проверить grep'ом: `rg "_fill_summary|_summary_head|_summary_line|_equip_row_text" loadouts/mods/VTK` — только определения).

- [ ] **Step 2: Прогнать keycheck и почистить ключи**

Run: `python .check\keycheck.py` — выведет stale-ключи (используются в RU, но не в коде) и отсутствующие. Удалить из VTKLoc.gd только те, что реально стали мёртвыми из-за удалённых функций (например `Gear`, `Empty` — сверять по выводу; `Equipment`, `Remove`, `Cancel` и др. живы в других местах). Внимание: `Set is empty` НЕ удалять — с Task 2 его потребляет `_make_equip_preview`. Каждый удаляемый ключ проверить grep'ом по коду.

- [ ] **Step 3: Прогон стендов**

`python .check\layout_check.py`; `python .check\keycheck.py`; `python .check\encoding_check.py`; `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1` — все зелёные.

- [ ] **Step 4: Commit**

```bash
git add loadouts/mods/VTK/VTKUI.gd loadouts/mods/VTK/VTKLoc.gd
git commit -m "chore: remove dead summary code and stale keys"
```

---
## Task 6: Локализация новых подписей

**Files:**
- Modify: `loadouts/mods/VTK/VTKLoc.gd` (RU-ветка, тем же проходом)

- [ ] **Step 1: Добавить EN+RU пары**

Ключ = английская строка (EN):
- `'Inventory'` → `'Инвентарь'`
- `'grid 8 columns'` → `'сетка 8 колонок'`
- заголовки `'Equipment'`/`'Set is empty'` уже есть.

`' items \u00b7 '` уже есть (используется превью-метой). Сверить с `keycheck.py`.

- [ ] **Step 2: Проверка и commit**

`python .check\keycheck.py` (152 RU-ключа — цифра может измениться, главное 0 проблем), `encoding_check.py` — 0 проблем. 

```bash
git add loadouts/mods/VTK/VTKLoc.gd
git commit -m "feat: localize preview panel headers"
```

---
## Task 7: Версия 4.9.1, стенды, сборка, деплой

**Files:**
- Modify: `loadouts/mod.txt` (`version="4.9.1"`)
- Действия: стенды, `pack.ps1`, копия vmz в игру, коммит
- Cleanup: удалить временные пробники (`RTVcopy/extracted/probe_icons.gd`, `RTVcopy/extracted/probe_sizes.gd`, `.check/project/probe_layout.gd`, `$env:TEMP\opencode\probe_*_out.txt`) — файлы не в паке, но мусор убираем.

- [ ] **Step 1: Поднять версию**

`loadouts/mod.txt`: `version="4.9.0"` → `version="4.9.1"`.

- [ ] **Step 2: Все стенды**

```bash
python .check\layout_check.py
python .check\keycheck.py
python .check\encoding_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```
Все зелёные; `pack.ps1` печатает «4.9.1» перед упаковкой.

- [ ] **Step 3: Собрать и задеплоить**

```bash
powershell -ExecutionPolicy Bypass -File pack.ps1
Copy-Item "D:\RTVMOD\Loadouts.vmz" "D:\SteamLibrary\steamapps\common\Road to Vostok\mods\Loadouts.vmz" -Force
```

- [ ] **Step 4: Удалить пробники**

Удалить `probe_icons.gd`, `probe_sizes.gd`, `probe_layout.gd`, временные `probe_*_out.txt`.

- [ ] **Step 5: Commit**

```bash
git add loadouts/mod.txt loadouts/mods/VTK/version.txt
git commit -m "release: 4.9.1"
```

`version.txt` сгенерирует `pack.ps1` из `mod.txt` (файлы: `loadouts/mods/VTK/version.txt`). `README.md` (обновлён `pack.ps1`) и `docs/` не коммитить.

---
## Self-review

- Spec-покрытие: левая панель S1 read-only → Task 1–2; стена со spans по `size` и бейджами → Task 3; оба места (превью-колонка + «Готово») → Task 4; не используем живое состояние и поиск → задача не нужна, явно исключено; мёртвый код/ключи → Task 5; локализация → Task 6; версия/деплой → Task 7.
- Плейсхолдеров нет: каждый шаг содержит код или конкретное действие.
- Типовая согласованность: `_make_equip_cell(slot, min_h, desc={}, interactive=true)`, `_make_weapon_cell(slot, desc={}, interactive=true)`, `_make_body_zone(slots, eq={}, interactive=true)` заданы в Task 1 и используются в Task 2; `_build_set_preview(title, eq, gear)` в Task 4; `_gear_cell_size`/`_wall_item`/`_make_inventory_panel` в Task 3. Крайний случай: `Picker.all_slots([[slot,...]])` — существующий API (принимает массив списков слотов). `Draft.shown_count` и `_cell_resource` — существующие.