# Set Preview: 30/70, squares, grey slots, fixed 8×8 wall — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Поправить превью сета: колонка экипировки 30%, неиспользуемые слоты — серые «заблокированные» клетки, слоты — квадраты, стена инвентаря — фиксированная сетка 8×8.

**Architecture:** Один связный визуальный проход в `loadouts/mods/VTK/VTKUI.gd`. Все изменения затрагивают только превью (правая колонка вкладки «Сеты» и шаг 3 «Готово», общий билдер `_build_set_preview`) — редактор экипировки не меняется. Правило «разделяй по чистой логике» не задевается: правки в UI-билдерах, поведение picker-логики не меняется.

**Tech Stack:** GDScript 4.6 (Godot), файл `VTKUI.gd` (CRLF, табы), стенды `.check/` на Python 3 + PowerShell.

Документы: спека `docs/superpowers/specs/2026-10-09-set-preview-30-70-squares-grey-8x8-design.md`.

## Global Constraints

- Только превью (оба места: «Сеты» и «Готово»). Редактор экипировки (`interactive=true` путь) не меняется.
- Версия поднимается до **4.9.3** в двух файлах: `loadouts/mod.txt` (`version="4.9.2"` → `"4.9.3"`) и `loadouts/mods/VTK/version.txt` (`4.9.2` → `4.9.3`).
- `VTKUI.gd` — только табы, только CRLF (после правок LF-only = 0).
- Никаких новых `load()`-путей внутрь игры; только контролы Godot + StyleBoxFlat.
- Коммиты только по `loadouts/**`. `VTKHooks.gd` в рабочем дереве — чужая задача, НЕ трогать и НЕ коммитить.
- Стенды после каждого изменения: `py -3 .check\layout_check.py`, `py -3 .check\keycheck.py`, `py -3 .check\encoding_check.py`, `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`.
- Визуальный результат проверяет пользователь в игре (стенды не проверяют раскладку в рантайме).

---

### Task 1: Визуальный рефакторинг превью

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd:1602-1733` (`_make_equip_cell`), `:1737-1756` (`_make_body_zone`), `:1758-1806` (`_make_equip_preview`), `:1856-1878` (`_make_inventory_wall`), `:1880-1911` (`_make_inventory_panel`)

**Interfaces:**
- Produces:
  - `_make_equip_cell(slot: String, min_h: int, desc: Dictionary = {}, interactive := true, fixed := false) -> Control`
  - `_make_body_zone(slots: Array, eq: Dictionary = {}, interactive := true, square := false) -> Control`
  - `_make_inventory_wall(gear: Array) -> Control` (канва 405×405, фон — пустые клетки)
  - `_make_inventory_panel(gear: Array, meta: String = "") -> Control` (stretch_ratio 0.7)
  - `_make_equip_preview(title: String, eq: Dictionary) -> Control` (stretch_ratio 0.3, min width 132)
- Consumes: `Picker.equip_layout(body list)`, `loc.txt`, существующие константы `EQ_CELL_H=58`, `EQ_SMALL_H=48`, `EQ_GAP=4`, `INVEN_CELL=48`, `INVEN_COLS=8`, `INVEN_GAP=3`.

- [ ] **Step 1: `_make_equip_cell` — флаг `fixed` и компактная вёрстка**

Строка 1602, сигнатура:
```gdscript
func _make_equip_cell(slot: String, min_h: int, desc: Dictionary = {}, interactive := true, fixed := false) -> Control:
```

Строки 1612-1613, размер и растяжение:
```gdscript
	box.custom_minimum_size = Vector2(min_h, min_h) if fixed else Vector2(0, min_h)
	if fixed:
		box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
```

Строка 1685, стиль панели — для пустой клетки превью disabled-стиль, иначе как раньше:
```gdscript
	if not interactive and src.is_empty():
		var ds := StyleBoxFlat.new()
		ds.bg_color = Color("#1e1a15")
		ds.set_border_width_all(1)
		ds.border_color = Color("#4a443a")
		ds.corner_radius_all = 6
		box.add_theme_stylebox_override("panel", ds)
	else:
		box.add_theme_stylebox_override("panel", _equip_cell_style(active, false, occupied))
```

Строки 1691-1733, внутренняя вёрстка: для `fixed` — компактный вертикальный стак вместо HBox-макета. Объявление `var tex` (сейчас строка 1705) переносится вверх, до ветки:
```gdscript
	var tex := _item_icon(_cell_resource(src)) if occupied else null
	if fixed:
		var vbx := VBoxContainer.new()
		vbx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vbx.alignment = BoxContainer.ALIGNMENT_CENTER
		vbx.add_theme_constant_override("separation", 0)
		vbx.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(vbx)
		if tex != null:
			var icon := TextureRect.new()
			icon.texture = Picker.item_art(tex)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.custom_minimum_size = Vector2(min_h - 12, min_h - 26)
			icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbx.add_child(icon)
		var nm := Label.new()
		nm.text = Loc.txt(slot)
		nm.add_theme_font_size_override("font_size", 8)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.add_theme_color_override("font_color", Color("#d8cdbe") if occupied else Color("#5f5347"))
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbx.add_child(nm)
		var dot := _make_dot(_gold if occupied else Color("#2a1f14"))
		dot.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		dot.offset_left = -9
		dot.offset_top = 3
		dot.offset_bottom = 10
		dot.offset_right = -3
		box.add_child(dot)
	else:
		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 8)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_top", 4)
		margin.add_theme_constant_override("margin_bottom", 4)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(margin)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 6)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(hb)
		if tex != null:
			var wide := TextureRect.new()
			wide.texture = Picker.item_art(tex)
			wide.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			wide.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			wide.custom_minimum_size = Vector2(96, 0)
			wide.size_flags_vertical = Control.SIZE_EXPAND_FILL
			wide.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hb.add_child(wide)
		var nm2 := Label.new()
		nm2.text = Loc.txt(slot)
		nm2.add_theme_font_size_override("font_size", 10)
		nm2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm2.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		nm2.add_theme_color_override("font_color", Color("#d8cdbe") if occupied else Color("#5f5347"))
		nm2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(nm2)
		hb.add_child(_make_dot(_gold if occupied else Color("#2a1f14")))
		if interactive and occupied:
			var drop := _make_mini_btn("✕", Vector2(16, 16), 8)
			drop.tooltip_text = Loc.txt("Remove")
			drop.add_theme_color_override("font_color", Color("#e05a4a"))
			drop.pressed.connect(func(): _remove_slot(slot))
			hb.add_child(drop)
```

- [ ] **Step 2: `_make_body_zone` — флаг `square`**

Строка 1737, сигнатура:
```gdscript
func _make_body_zone(slots: Array, eq: Dictionary = {}, interactive := true, square := false) -> Control:
```

Строки 1739-1740, размер и растяжение зоны:
```gdscript
	zone.custom_minimum_size = Vector2(2 * EQ_CELL_H + EQ_GAP, 4 * EQ_CELL_H + 3 * EQ_GAP) if square else Vector2(0, 4 * EQ_CELL_H + 3 * EQ_GAP)
	if square:
		zone.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	else:
		zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
```

Строки 1751-1754, клетки с квадратом (проброс флага в клетку):
```gdscript
		if eq.is_empty():
			grid.add_child(_make_equip_cell(str(slot), EQ_CELL_H, {}, interactive, square))
		else:
			grid.add_child(_make_equip_cell(str(slot), EQ_CELL_H, eq.get(str(slot), {}), interactive, square))
```

- [ ] **Step 3: `_make_equip_preview` — 30/70, минимум ширины, квадратные мелкие**

Строки 1760-1761:
```gdscript
	panel.custom_minimum_size = Vector2(132, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 0.3
```

Строка 1788 (вызов зоны тела превью — квадраты):
```gdscript
		panel.add_child(_make_body_zone(body, eq, false, true))
```

Строки 1791-1798 (сетка мелких — фиксированная ширина 100, клетки 48×48):
```gdscript
		var sgrid := GridContainer.new()
		sgrid.columns = 2
		sgrid.custom_minimum_size = Vector2(2 * EQ_SMALL_H + EQ_GAP, 0)
		sgrid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		sgrid.add_theme_constant_override("h_separation", EQ_GAP)
		sgrid.add_theme_constant_override("v_separation", EQ_GAP)
		for slot in small:
			sgrid.add_child(_make_equip_cell(str(slot), EQ_SMALL_H, eq.get(str(slot), {}), false, true))
		panel.add_child(sgrid)
```

- [ ] **Step 4: `_make_inventory_wall` — фиксированная сетка 8×8**

Переписать функцию (сейчас 1856-1878). Канва 405×405, фон — 64 пустые клетки, предметы кладутся прежним циклом без пересчёта высоты:
```gdscript
func _make_inventory_wall(gear: Array) -> Control:
	var wall := Control.new()
	wall.custom_minimum_size = Vector2(8 * INVEN_CELL + 7 * INVEN_GAP, 8 * INVEN_CELL + 7 * INVEN_GAP)
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wall.clip_contents = true
	var bg := GridContainer.new()
	bg.columns = INVEN_COLS
	bg.custom_minimum_size = wall.custom_minimum_size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_theme_constant_override("h_separation", INVEN_GAP)
	bg.add_theme_constant_override("v_separation", INVEN_GAP)
	for i in range(8 * INVEN_COLS):
		var gc := Panel.new()
		gc.custom_minimum_size = Vector2(INVEN_CELL, INVEN_CELL)
		gc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var gs := StyleBoxFlat.new()
		gs.bg_color = Color("#14110c")
		gs.corner_radius_all = 3
		gc.add_theme_stylebox_override("panel", gs)
		bg.add_child(gc)
	wall.add_child(bg)
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
	return wall
```

- [ ] **Step 5: `_make_inventory_panel` — 70%**

Строка 1884 (добавить stretch-долю после EXPAND_FILL):
```gdscript
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 0.7
```

- [ ] **Step 6: Прогнать стенды**

Run: `py -3 .check\layout_check.py` → exit 0, `GONE: 68, GONE_RE: 1, PRESENT: 80, FUNCS: 14, HOOKS_GONE: 4`
Run: `py -3 .check\keycheck.py` → exit 0, `RU entries: 154`
Run: `py -3 .check\encoding_check.py` → `PROBLEMS: 0`
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1` → `Tests passed: 5 file(s)`, exit 0
EOL: VTKUI.gd — CRLF, LF-only = 0 (скан байтами, см. Global Constraints).

- [ ] **Step 7: Поднять версию до 4.9.3**

`loadouts/mod.txt`: `version="4.9.2"` → `version="4.9.3"`.
`loadouts/mods/VTK/version.txt`: `4.9.2` → `4.9.3`.

- [ ] **Step 8: Коммит**

```bash
git add loadouts/mods/VTK/VTKUI.gd loadouts/mod.txt loadouts/mods/VTK/version.txt
git commit -m "fix: set preview — 30/70 split, square slots, grey unused, fixed 8x8 wall"
```

- [ ] **Step 9: Сборка и деплой**

```bash
powershell -NoProfile -ExecutionPolicy Bypass -File pack.ps1
Copy-Item Loadouts.vmz -Destination "D:\SteamLibrary\steamapps\common\Road to Vostok\mods" -Force
```
Проверить вывод pack.ps1: версия 4.9.3, 13 entries.
Визуальную проверку (30/70, серые пустые клетки, квадраты, сетка 8×8) делает пользователь в игре.