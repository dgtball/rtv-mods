# План: сетка экипировки с силуэтом (S1)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Заменить плоский список слотов шага 1 «Экипировка» сеткой с силуэтом тела (вариант S1 мокапа).

**Architecture:** Раскладка слотов (какие слоты в какой зоне и в каком порядке) живёт в чистом `VTKPicker.equip_layout()`, UI в `VTKUI.gd` строит из неё три зоны: оружие, тело с силуэтом, мелкие слоты. Прозрачные клетки одежды пропускают силуэт, который рисует внутренний класс `BodySilhouette`.

**Tech Stack:** GDScript (Godot 4.6.3), `StyleBoxFlat`, `GridContainer`/`CenterContainer`/`MarginContainer`.

**Источник:** `docs/superpowers/specs/2026-10-09-equipment-silhouette-grid-design.md`.

## Global Constraints

1. **Коммиты — только `loadouts/**`.** `.check/`, `docs/`, `.docs/`, `AGENTS.md` не в индексе (`git ls-files` их не видит). Никаких `git add -A`: `git add <файл>` + `git commit -m "..."` (one-liner, английский).
2. **Базовая линия зелёная** (проверено при планировании): `layout_check.py` — GONE 63 / GONE_RE 1 / PRESENT 73 / FUNCS 13 / HOOKS_GONE 4; `keycheck.py` — 153 ключа; `check.ps1` — 5 тестов passed. Прогон перед задачей.
3. **Красный шаг** — сначала списки стенда (`layout_check.py`: GONE/PRESENT/FUNCS; `test_picker.gd`), прогон → красный, затем код → зелёный.
4. **`.gd` — табы, UTF-8.** VTKUI.gd/`VTKPicker.gd` — CRLF (VTKPicker.gd проверен как CRLF; остальное LF). Перед сплайсом VTKUI.gd — снапшот: `Copy-Item loadouts\mods\VTK\VTKUI.gd "$env:TEMP\opencode\vtk-snap-$(Get-Date -Format HHmmss).gd"`.
5. **Аннотации типов обязательны** там, где `return null`/присваивание узлов, иначе Parse Error по всему файлу.
6. **Проверка после каждой задачи:**
   ```
   py -3 .check\layout_check.py
   py -3 .check\keycheck.py
   powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
   ```
   Вердикт check.ps1 = exit 0 + нет `SCRIPT ERROR|Parse Error|Invalid call|Failed to load script` + `tests passed`.
7. **Новых RU-строк нет** — переиспользуются имена слотов и ключ `Equipment`.
8. **Игровой прогон** после T2 обязателен (визуальная часть) до T3.

---

## T1. VTKPicker.equip_layout — чистая раскладка сетки

**Files:**
- Modify: `loadouts/mods/VTK/VTKPicker.gd`
- Test: `.check/project/tests/test_picker.gd`

**Interfaces:**
- Produces: `EQUIP_WEAPONS`, `EQUIP_BODY`, `EQUIP_SMALL`, `equip_layout(present: Array) -> Dictionary`, `_keep_slots(order, present) -> Array`.
- Consumes: нет.

- [ ] **Step 1: Красный шаг — тест**

В `.check/project/tests/test_picker.gd` в `_init()` добавить `t_equip_layout()` (после `t_all_slots()`), и новую функцию в конец файла:

```gdscript
func t_equip_layout() -> void:
	var all := P.SLOT_ORDER.duplicate()
	var got := P.equip_layout(all)
	ck(got.get("weapons", []) == ["Primary", "Secondary"], "оружие наверху двумя слотами")
	ck(got.get("body", []) == ["Head", "Helmet", "Torso", "Rig", "Legs", "Backpack", "Feet", "Belt"],
		"тело 2×4: слева вниз, справа вниз")
	ck(got.get("small", []).size() == 10, "десять мелких слотов")
	ck(str(got.get("small", [])[0]) == "Hands" and str(got["small"][9]) == "Matches",
		"мелкие слоты в порядке сетки 2×5")
	# Раскладка покрывает ровно SLOT_ORDER, без дублей и пропусков.
	var flat: Array = []
	flat.append_array(got["weapons"])
	flat.append_array(got["body"])
	flat.append_array(got["small"])
	ck(flat.size() == P.SLOT_ORDER.size(), "раскладка не теряет и не дублирует слоты")
	for s in P.SLOT_ORDER:
		ck(flat.has(s), "слот " + str(s) + " есть в раскладке")
	# Слот, которого нет в каталоге, не показывается: после апдейта игры
	# пустых клеток не прибавится.
	var one := P.equip_layout(["Head"])
	ck(one["body"] == ["Head"], "недостающие слоты тела выпадают")
	ck(one["weapons"].is_empty(), "недостающее оружие выпадает")
	ck(one["small"].is_empty(), "недостающие мелкие слоты выпадают")
	ck(P.equip_layout([])["body"].is_empty(), "пустой каталог даёт пустую раскладку")
```

- [ ] **Step 2: Прогон — красный**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `SCRIPT ERROR ... equip_layout` (или `Invalid call`), exit != 0.

- [ ] **Step 3: Реализация**

В `loadouts/mods/VTK/VTKPicker.gd` после `SLOT_ORDER` добавить:

```gdscript
# Раскладка сетки экипировки (вариант S1). Порядок в списках = порядок
# заполнения GridContainer'а по строкам (тело 2 колонки, мелкие 2 колонки).
# Презентация, а не данные, но живёт рядом с SLOT_ORDER: UI читает раскладку
# отсюда, а не держит свою копию списка слотов, и это тестируется headless.
const EQUIP_WEAPONS := ["Primary", "Secondary"]
const EQUIP_BODY := ["Head", "Helmet", "Torso", "Rig", "Legs", "Backpack", "Feet", "Belt"]
const EQUIP_SMALL := ["Hands", "Knife", "Light", "Time", "Map", "NVG",
	"Grenade_1", "Grenade_2", "Player", "Matches"]

# Раскладка сетки экипировки, отфильтрованная по каталогу: present - результат
# all_slots. Слот, которого нет в предметах игры, из раскладки выпадает, иначе
# после апдейта игры появилась бы пустая неинтерактивная клетка.
static func equip_layout(present: Array) -> Dictionary:
	return {
		"weapons": _keep_slots(EQUIP_WEAPONS, present),
		"body": _keep_slots(EQUIP_BODY, present),
		"small": _keep_slots(EQUIP_SMALL, present),
	}

static func _keep_slots(order: Array, present: Array) -> Array:
	var out: Array = []
	for s in order:
		if present.has(str(s)):
			out.append(str(s))
	return out
```

- [ ] **Step 4: Прогон — зелёный**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `Picker tests passed`, `tests passed`, exit 0.

- [ ] **Step 5: Коммит**

```
git add loadouts/mods/VTK/VTKPicker.gd
git commit -m "Add Picker.equip_layout for the silhouette equipment grid"
```

---

## T2. VTKUI: сетка экипировки вместо списка слотов

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd`
- Modify: `.check/layout_check.py`

**Interfaces:**
- Consumes: `Picker.equip_layout`, `Picker.all_slots`, `Picker.item_art`, `_on_slot_row_input`, `_remove_slot`, `_item_icon`, `_item_info`, `_make_dot`, `_make_mini_btn`, `_attach_row_hover`, `_attach_motion`, `VTKSurface.style_button`.
- Produces: `_equip_grid_box`, `_equip_cell_style`, `_make_equip_cell`, `_make_weapon_cell`, `_make_body_zone`, класс `BodySilhouette`, константы `EQ_CELL_H/EQ_WEAP_H/EQ_SMALL_H/EQ_GAP`.
- Changes: `_make_slot_row` удаляется; `_side_slots_box` переименован в `_equip_grid_box`.

- [ ] **Step 1: Красный шаг — списки стенда**

В `.check/layout_check.py`:
- в `GONE` добавить `"_side_slots_box"`, `"_make_slot_row"`;
- из `PRESENT` удалить `"_side_slots_box"`, `"_make_slot_row"`, добавить:
```python
    "_equip_grid_box",
    "_equip_cell_style",
    "_make_equip_cell",
    "_make_weapon_cell",
    "_make_body_zone",
    "BodySilhouette",
    "Picker.equip_layout",
    "EQ_CELL_H",
```
- в `FUNCS` заменить кортеж `("_make_slot_row", ["item_lbl","clip_text"], ...)` на:
```python
    ("_make_equip_cell", [
        "_on_slot_row_input",
        "Picker.item_art",
    ], "клетка сетки кликабельна и показывает иконку предмета"),
    ("_refresh_slots", [
        "Picker.equip_layout",
        "_make_body_zone",
    ], "сетка строится из чистой раскладки, а не из плоского списка"),
```

Прогон `py -3 .check\layout_check.py` → `MISS` по новым строкам и `GONE` по старым.

- [ ] **Step 2: Реализация — константы и переменные**

В `loadouts/mods/VTK/VTKUI.gd`:
- заменить `var _side_slots_box: VBoxContainer = null` (48) на `var _equip_grid_box: VBoxContainer = null`;
- в `_build_editor` null-сброс `_side_slots_box = null` (~799) → `_equip_grid_box = null`;
- рядом с `const SIDE_WIDTH := 232` (1011) добавить:
```gdscript
# Размеры сетки экипировки (вариант S1): оружие и мелкие слоты ниже, клетки
# тела выше под силуэт. Зона силуэта = 4 ряда по EQ_CELL_H + 3 зазора.
const EQ_CELL_H := 58
const EQ_WEAP_H := 48
const EQ_SMALL_H := 48
const EQ_GAP := 4
```

- [ ] **Step 3: Реализация — `_build_page_equipment`**

Заменить хвост функции (1105-1108):
```gdscript
	# Слоты - та же левая колонка, что категории в Снаряжении: обе страницы
	# берут каркас у _page_columns, поэтому выглядят одинаково.
	_side_slots_box = VBoxContainer.new()
	_side_slots_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side_slots_box.add_theme_constant_override("separation", 3)
	return _page_columns(Loc.txt("Slots"), _side_slots_box, v)
```
на:
```gdscript
	# Левая колонка - сетка с силуэтом (задача T2): оружие, тело, мелкие слоты.
	# Каркас берёт у _page_columns, как и категории Снаряжения.
	_equip_grid_box = VBoxContainer.new()
	_equip_grid_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_equip_grid_box.add_theme_constant_override("separation", 6)
	return _page_columns(Loc.txt("Equipment"), _equip_grid_box, v)
```

- [ ] **Step 4: Реализация — `_refresh_slots` (1624)**

Заменить тело функции целиком:
```gdscript
func _refresh_slots() -> void:
	if _equip_grid_box == null:
		return
	for child in _equip_grid_box.get_children():
		_equip_grid_box.remove_child(child)
		child.queue_free()
	if _draft == null:
		return
	# Слоты копим из всех предметов каталога, а не из занятых в этом сете:
	# иначе пустая клетка была бы видна только у того сета, где занята.
	var lists: Array = []
	for it in _db_items:
		if it != null:
			lists.append(it.get("slots"))
	var layout := Picker.equip_layout(Picker.all_slots(lists))
	var weap: Array = layout.get("weapons", [])
	if not weap.is_empty():
		var wbox := VBoxContainer.new()
		wbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wbox.add_theme_constant_override("separation", EQ_GAP)
		for slot in weap:
			wbox.add_child(_make_weapon_cell(str(slot)))
		_equip_grid_box.add_child(wbox)
	var body: Array = layout.get("body", [])
	if not body.is_empty():
		_equip_grid_box.add_child(_make_body_zone(body))
	var small: Array = layout.get("small", [])
	if not small.is_empty():
		var sgrid := GridContainer.new()
		sgrid.columns = 2
		sgrid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sgrid.add_theme_constant_override("h_separation", EQ_GAP)
		sgrid.add_theme_constant_override("v_separation", EQ_GAP)
		for slot in small:
			sgrid.add_child(_make_equip_cell(str(slot), EQ_SMALL_H))
		_equip_grid_box.add_child(sgrid)
```

- [ ] **Step 5: Реализация — `_make_slot_row` → клетки и силуэт**

Удалить `_make_slot_row` (1650-1701) целиком и на её месте добавить:

```gdscript
# Стиль клетки сетки экипировки: прозрачная заливка, только рамка - силуэт
# тела обязан просвечивать сквозь клетки одежды. Активная цель - золото.
func _equip_cell_style(active: bool, hover: bool = false, occupied: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	s.set_border_width_all(1)
	s.corner_radius_all = 6
	if active:
		s.border_color = _gold
	elif hover:
		s.border_color = Color("#c9823a")
	elif occupied:
		s.border_color = Color("#3a2e20")
	else:
		s.border_color = Color("#2a1f14")
	return s

# Клетка слота в сетке: занятая показывает иконку предмета, пустая (или без
# иконки) - имя слота. Клик - прежний _on_slot_row_input: выбор цели, второй
# клик по занятой цели открывает панель обвесов.
func _make_equip_cell(slot: String, min_h: int) -> Control:
	var desc = _draft.equip.get(slot, {})
	if typeof(desc) != TYPE_DICTIONARY:
		desc = {}
	var occupied := not desc.is_empty()
	var active := _target_slot == slot
	var cell := Panel.new()
	cell.custom_minimum_size = Vector2(0, min_h)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.clip_contents = true
	cell.tooltip_text = Loc.txt(slot)
	cell.add_theme_stylebox_override("panel", _equip_cell_style(active, false, occupied))
	_attach_row_hover(cell, func(hv: bool): return _equip_cell_style(active, hv, occupied))
	_attach_motion(cell)
	cell.gui_input.connect(func(ev): _on_slot_row_input(ev, slot, desc))

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(center)

	var tex = _item_icon(_cell_resource(desc)) if occupied else null
	if tex != null:
		var icon := TextureRect.new()
		icon.texture = Picker.item_art(tex)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.custom_minimum_size = Vector2(0, maxi(16, min_h - 16))
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(icon)
	else:
		var lb := Label.new()
		lb.text = Loc.txt(slot)
		lb.add_theme_font_size_override("font_size", 9)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.add_theme_color_override("font_color", Color("#d8cdbe") if occupied else Color("#5f5347"))
		lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(lb)

	var dot := _make_dot(_gold if occupied else Color("#2a1f14"))
	cell.add_child(dot)
	dot.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	dot.offset_left = -10
	dot.offset_top = 3
	dot.offset_right = -3
	dot.offset_bottom = 10

	if occupied:
		var drop := _make_mini_btn("✕", Vector2(16, 16), 8)
		drop.tooltip_text = Loc.txt("Remove")
		VTKSurface.style_button(drop, false, true, 1, 1, 1, 1)
		drop.add_theme_color_override("font_color", Color("#e05a4a"))
		drop.pressed.connect(func(): _remove_slot(slot))
		cell.add_child(drop)
		drop.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		drop.offset_left = 2
		drop.offset_top = 2
		drop.offset_right = 18
		drop.offset_bottom = 18
	return cell

# Широкая клетка слота оружия: иконка слева, имя слота, точка и крестик.
func _make_weapon_cell(slot: String) -> Control:
	var desc = _draft.equip.get(slot, {})
	if typeof(desc) != TYPE_DICTIONARY:
		desc = {}
	var occupied := not desc.is_empty()
	var active := _target_slot == slot
	var cell := Panel.new()
	cell.custom_minimum_size = Vector2(0, EQ_WEAP_H)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.clip_contents = true
	cell.tooltip_text = Loc.txt(slot)
	cell.add_theme_stylebox_override("panel", _equip_cell_style(active, false, occupied))
	_attach_row_hover(cell, func(hv: bool): return _equip_cell_style(active, hv, occupied))
	_attach_motion(cell)
	cell.gui_input.connect(func(ev): _on_slot_row_input(ev, slot, desc))

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(margin)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(hb)

	var tex = _item_icon(_cell_resource(desc)) if occupied else null
	if tex != null:
		var icon := TextureRect.new()
		icon.texture = Picker.item_art(tex)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.custom_minimum_size = Vector2(96, 0)
		icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(icon)

	var nm := Label.new()
	nm.text = Loc.txt(slot)
	nm.add_theme_font_size_override("font_size", 10)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.size_flags_vertical = Control.SIZE_VERTICAL_ALIGNMENT_CENTER
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nm.add_theme_color_override("font_color", Color("#d8cdbe") if occupied else Color("#5f5347"))
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(nm)

	hb.add_child(_make_dot(_gold if occupied else Color("#2a1f14")))

	if occupied:
		var drop := _make_mini_btn("✕", Vector2(16, 16), 8)
		drop.tooltip_text = Loc.txt("Remove")
		VTKSurface.style_button(drop, false, true, 1, 1, 1, 1)
		drop.add_theme_color_override("font_color", Color("#e05a4a"))
		drop.pressed.connect(func(): _remove_slot(slot))
		hb.add_child(drop)
	return cell

# Зона силуэта: прозрачные клетки тела лежат поверх силуэта. Высота фиксирована
# (4 ряда), иначе GridContainer схлопнул бы ряды и силуэт разъехался с клетками.
func _make_body_zone(slots: Array) -> Control:
	var zone := Control.new()
	zone.custom_minimum_size = Vector2(0, 4 * EQ_CELL_H + 3 * EQ_GAP)
	zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var silh := BodySilhouette.new()
	silh.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	zone.add_child(silh)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grid.add_theme_constant_override("h_separation", EQ_GAP)
	grid.add_theme_constant_override("v_separation", EQ_GAP)
	for slot in slots:
		grid.add_child(_make_equip_cell(str(slot), EQ_CELL_H))
	zone.add_child(grid)
	return zone

# Ресурс предмета слота для иконки. Пустой дескриптор - null.
func _cell_resource(desc: Dictionary) -> Resource:
	var res = _item_info(str(desc.get("path", ""))).get("resource")
	return res

# Силуэт тела под прозрачными клетками одежды: голова, торс, ноги. Части
# центрируются якорем 0.5 по X, поэтому силуэт остаётся по центру при любой
# ширине колонки. Рисуется Panel'ами со StyleBoxFlat - без внешних текстур.
class BodySilhouette extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		modulate = Color(1, 1, 1, 0.6)
		_part(6.0, 46.0, 46.0, 23)
		_part(62.0, 96.0, 118.0, 16)
		_part(186.0, 76.0, 56.0, 16)

	func _part(top: float, w: float, h: float, radius: int) -> void:
		var p := Panel.new()
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.anchor_left = 0.5
		p.anchor_right = 0.5
		p.offset_left = -w * 0.5
		p.offset_right = w * 0.5
		p.offset_top = top
		p.offset_bottom = top + h
		var s := StyleBoxFlat.new()
		s.bg_color = Color("#1a1510")
		s.border_color = Color("#2a1f14")
		s.set_border_width_all(1)
		s.corner_radius_all = radius
		p.add_theme_stylebox_override("panel", s)
		add_child(p)
```

- [ ] **Step 6: Проверка и коммит**

```
py -3 .check\layout_check.py
py -3 .check\keycheck.py
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
git add loadouts/mods/VTK/VTKUI.gd
git commit -m "Replace step 1 slot list with a silhouette equipment grid"
```

---

## T3. Релиз 4.9.0

- [ ] **Step 1:** поднять `version` в `loadouts/mod.txt` до `4.9.0`; обновить в `AGENTS.md` абзац про шаг 1 (сетка S1, `Picker.equip_layout`, `EQ_*`, `_make_slot_row` удалён, `_side_slots_box` → `_equip_grid_box`).
- [ ] **Step 2:** `py -3 .check\encoding_check.py` (version.txt == mod.txt), три стенда зелёные.
- [ ] **Step 3:** `powershell -NoProfile -ExecutionPolicy Bypass -File pack.ps1` → сверить версию в выводе.
- [ ] **Step 4:** скопировать `Loadouts.vmz` в `D:\SteamLibrary\steamapps\common\Road to Vostok\mods\Loadouts.vmz`.
- [ ] **Step 5:** `git add loadouts/mod.txt` + `git commit -m "Release 4.9.0 with the silhouette equipment grid"`.

## Self-Review

- Спека покрыта: раскладка (T1), клетки/силуэт/стиль/клик/снятие (T2), версия (T3).
- Плейсхолдеров нет.
- Имена согласованы: `_equip_grid_box`, `_equip_cell_style`, `_make_equip_cell`, `_make_weapon_cell`, `_make_body_zone`, `_cell_resource`, `BodySilhouette`, `EQ_*`, `Picker.equip_layout`, `Picker.all_slots`.
