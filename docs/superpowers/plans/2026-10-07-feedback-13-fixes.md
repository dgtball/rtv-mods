# Vostok Toolkit 4.7.3 — 13 пунктов фидбека + бэклог Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Внести 13 пунктов пользовательского фидбека по вкладкам и 4 бэклог-пункта, поднять версию до 4.7.3, пересобрать и доставить `Loadouts.vmz`.

**Architecture:** Все правки — в двух существующих скриптах (`VTKUI.gd`, `VTKLoc.gd`) плюс усиление стендов (`layout_check.py`, `keycheck.py`). Новых файлов и `preload` не появляется. Логика выбора остаётся в `VTKPicker.gd`/`VTKDraft.gd` — не трогаем.

**Tech Stack:** GDScript / Godot 4.6.3, стенды: `layout_check.py` (символы раскладки), `check.ps1` (headless-парсинг + 3 теста), `keycheck.py` (переводы), `encoding_check.py` (mojibake + версия в паке).

## Global Constraints

- Формат: только табы, UTF-8 без BOM, сохранять СУЩЕСТВУЮЩИЕ переводы строк каждого файла (VTKUI.gd — CRLF, VTKLoc.gd — LF; не нормализовать — whole-file diff). Кириллицу править только tools-редактором; после правок `py -3 .check\encoding_check.py`. (Редакция после Task 6: исходная формулировка «CRLF для VTK*.gd» была ошибочной — AGENTS.md требует только табы+UTF-8; ruling: оставить LF.)
- **Репозиторий без git-истории для разработки**: в git входят только `loadouts/**`, README, LICENSE, assets (`/*`-whitelist в `.gitignore`); `.check/`, `docs/`, `.superpowers/` — игнорируются. Поэтому вместо commit-шагов — прогон стендов после каждой задачи, ревью-пакеты по снапшотам `snap/task-N-before|after`. Перед Task 7 (крупный сплайс) сделать снапшот: скопировать `VTKUI.gd` в `%TEMP%\opencode\vtk-snap-<дата>.gd`.
- Стенды (workdir `D:\RTVMOD`), запускать после **каждой** задачи:
  - `py -3 .check\layout_check.py` → ожидаем строку `RESULT: символы раскладки на месте`, exit 0;
  - `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1` → нет `SCRIPT ERROR` / `Parse Error`, строка `Tests passed: 3 file(s)`;
  - `py -3 .check\keycheck.py` → `RESULT: every Loc.txt() key has a RU entry` (после Task 6 — обязательно).
- Номера строк — ориентиры текущего файла; править **по содержимому** (поиском), номера уплывают после каждой задачи.
- Версия: `loadouts/mod.txt` сейчас `4.7.2`; поднимается до `4.7.3` **только в Task 12**, перед сборкой.
- Размеры (22→28, 46×24→64×30 и т.п.) — утверждённый дизайн; доводка по скриншоту в игре только с согласия пользователя.
- Игровые факты (цепочка EXPAND, поведение FlowContainer) уже сверены с исходниками Godot 4.6: `flow_container.cpp` растягивает `SIZE_EXPAND_FILL`-дети на всю ширину полосы (`stretch_avail`), тултип-попап добавляется ребёнком к владельцу-контролу (`viewport.cpp`) и наследует `_panel.theme` через `NOTIFICATION_PARENTED` (`window.cpp`).

---

### Task 1: Телепорт — вертикальная цепочка (#13)

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd` — `_build_ui` (`_main_vbox`, создание табов), `_page_columns` (`mv`), `_build_teleport_tab` (`main`)
- Modify: `.check/layout_check.py` — FUNCS

**Interfaces:**
- Consumes: `_scroll` (792×800), `_page_columns` (уже возвращает `HBoxContainer` с EXPAND).
- Produces: растянутый на всё окно `scroll` списка точек телепорта; FUNCS-гарантии `_build_ui` и `_build_teleport_tab`.

- [ ] **Step 1: `_main_vbox` и табы получают вертикальный EXPAND** (в `_build_ui`)

```gdscript
	_main_vbox = VBoxContainer.new()
	_main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_vbox.add_theme_constant_override("separation", 6)
```
и в цикле создания табов:
```gdscript
		vb.name = tname
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vb.hide()
```

- [ ] **Step 2: правая колонка `_page_columns` тянется** — в `var mv := VBoxContainer.new()` добавить `mv.size_flags_vertical = Control.SIZE_EXPAND_FILL` (сразу после строки с горизонтальным флагом).

- [ ] **Step 3: `main` телепорта тянется** — в `_build_teleport_tab`:
```gdscript
	var main := VBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 6)
```

- [ ] **Step 4: гарды в layout_check** — в `FUNCS` добавить:
```python
    ("_build_ui", [
        "_main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL",
        "vb.size_flags_vertical = Control.SIZE_EXPAND_FILL",
    ], "цепочка табов обязана тянуться от скролла до таба"),
    ("_build_teleport_tab", [
        "main.size_flags_vertical = Control.SIZE_EXPAND_FILL",
    ], "список точек телепорта растёт на всё окно"),
```
и дополнить существующую запись `_page_columns` третьей строкой `"mv.size_flags_vertical = Control.SIZE_EXPAND_FILL"`.

- [ ] **Step 5: стенды** → оба зелёные. В игре (отложено в Task 12 checklist): вкладка «Телепорт» — список карт занимает высоту окна, скролл лишний раз не нужен; вкладки «Сеты»/«Настройки» выглядят как раньше (контент прижат сверху).

---

### Task 2: Настройки — строка языка (#12)

**Files:**
- Modify: `VTKUI.gd` — `_make_lang_row`
- Modify: `.check/layout_check.py` — FUNCS

**Interfaces:**
- Consumes: `VTKSurface.panel`, `_make_seg_btn_style`, `_lang_btns`.
- Produces: плоская строка без внешней рамки, кнопки EN/RU `64×30`; `_make_lang_row(parent) -> HBoxContainer` — контракт не меняется.

- [ ] **Step 1: убрать обводку-панель и дубль `add_child`.** В `_make_lang_row` (текущие строки 2401–2456) удалить создание `set_row` (`PanelContainer` + stylebox `surface(..., 10, 10, 7, 7)` + `parent.add_child(set_row)`) и `set_row.add_child(row)`; вместо них — один раз сразу после создания `row`:
```gdscript
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
```
Удалить последнюю строку `parent.add_child(row)` (бывш. 2455) — она добавляла `row` повторно и каждый билд UI печатал `already has a parent 'set_row'`.

- [ ] **Step 2: кнопки крупнее** — в цикле `for c in codes:` заменить `b.custom_minimum_size = Vector2(46, 24)` на `Vector2(64, 30)`.

- [ ] **Step 3: гард** — в FUNCS добавить:
```python
    ("_make_lang_row", ["Vector2(64, 30)", "parent.add_child(row)"],
     "строка языка: крупные кнопки и ровно один привязанный parent"),
```

- [ ] **Step 4: стенды** → зелёные; в игре строка «Язык интерфейса» — без рамки блока, EN/RU шире и выше.

---

### Task 3: Размеры — степпер и чипы фильтра (#1, #4)

**Files:**
- Modify: `VTKUI.gd` — `_make_step_row_style`, `_make_chip_style`

- [ ] **Step 1: карточки шагов вровень с «Применить/Изменить».** Функция:
```gdscript
# Стиль карточки шага: активный - золотая рамка, как у слотов. Ховер не
# перебивает активное состояние. Вертикальные поля 9/11 совпадают со
# style_button, поэтому карточка (~38 px) растёт до высоты «Применить».
func _make_step_row_style(active: bool, hover: bool = false) -> StyleBox:
	return VTKSurface.surface("hover" if hover else "normal", active, false, active, 8, 8, 9, 11)
```
(было `8, 4, 2, 2` — карточка ~22 px против ~38 px у кнопок действия.)

- [ ] **Step 2: чипы фильтра выше.** `_make_chip_style`: `8, 12, 4, 4` → `8, 12, 7, 7` (высота ~20 → ~26, как у строк слотов после Task 4).

- [ ] **Step 3: стенды** → зелёные; в игре: стелпер визуально вровень с «Применить», чипы фильтра чуть выше.

---

### Task 4: Размеры — строки слотов, крестик, фасеты (#2, #9)

**Files:**
- Modify: `VTKUI.gd` — `_make_slot_row` (2 места), `_make_step_btn`, `_make_facet_row`

- [ ] **Step 1: строки слотов выше** — оба `panel.custom_minimum_size = Vector2(0, 22)` / `box.custom_minimum_size = Vector2(0, 22)` в `_make_slot_row` → `Vector2(0, 28)`.

- [ ] **Step 2: крестик/плюс/минус крупнее** — `_make_step_btn`: `b.custom_minimum_size = Vector2(20, 20)` → `Vector2(24, 24)` (24 ≤ 28−2−2 — влезает в стиль строки; затрагивает и «x»/«+»/«−» чипов снаряжения — однородный рост).

- [ ] **Step 3: фасеты +6 px** — `_make_facet_row`: `row.custom_minimum_size = Vector2(0, 17 if level else 20)` → `Vector2(0, 23 if level else 26)` («на тот же размер, что и в п2» = +6).

- [ ] **Step 4: стенды** → зелёные; в игре: Х не вылезает за рамку слота, категории снаряжения крупнее.

---

### Task 5: Клетки — фикс ширины и центрирования (#6, #7)

**Files:**
- Modify: `VTKUI.gd` — `_make_item_cell`, `_make_att_cell`
- Modify: `.check/layout_check.py` — GONE

**Interfaces:**
- Consumes: `Picker.item_art`, `_attach_motion`.
- Produces: клетки всегда 96×132, слева по краю; содержимое по центру клетки.

- [ ] **Step 1: убрать растяжение в потоке** — удалить строку `cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL` в `_make_item_cell` и оставить комментарий:
```gdscript
	# Без SIZE_EXPAND_FILL: HFlowContainer растягивает такие клетки на всю
	# ширину полосы, пока предметов мало (stretch в flow_container.cpp).
```
Обоснование проверено по исходникам Godot 4.6: именно `stretch_avail` раздувает 1–4 клетки на всю полосу; в `GridContainer` (шаг 2) флаг всё равно не получал излишка — поведение шага 2 не меняется.

- [ ] **Step 2: центр по всей клетке** — в `_make_item_cell` и `_make_att_cell` сразу после `cell.add_child(center)`:
```gdscript
	# Panel - не контейнер: без пресета center остаётся нулевым прямоугольником
	# в левом верхнем углу, и иконка центрируется относительно угла клетки.
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
```

- [ ] **Step 3: гард** — в GONE layout_check добавить строку (без кавычек в значении — ровно то, что удалили):
```python
    "cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL",
```

- [ ] **Step 4: стенды** → зелёные; в игре: при 1–4 предметах клетки фиксированные слева, иконка по центру клетки, ховер ловит весь тайл.

---

### Task 6: Локализация слотов и отказ от «Цель:» (#3, #8)

**Files:**
- Modify: `VTKLoc.gd` — удалить `'Target: '`, добавить 10 ключей слотов
- Modify: `VTKUI.gd` — 5 точек отображения
- Modify: `.check/keycheck.py` — парсинг `SLOT_ORDER`
- Modify: `.check/layout_check.py` — GONE

**Interfaces:**
- Consumes: `VTKPicker.SLOT_ORDER` (список 11 слотов), `Loc.txt()` (ключ = английская строка).
- Produces: локализованные слоты во всех местах отображения; ключ `'Target: '` удалён.

- [ ] **Step 1: VTKLoc.gd** — удалить строку `'Target: ': 'Цель: ',` (бывш. 79). Добавить блоком после `'Pouches': 'Подсумки',` (эта запись уже есть и покрывает слот Pouches):
```gdscript
	# Слоты набора: ключи идут из VTKPicker.SLOT_ORDER, отображаются только,
	# данные игры (item.slots) остаются английскими.
	'Primary': 'Основное',
	'Secondary': 'Второстепенное',
	'Melee': 'Холодное',
	'Body': 'Тело',
	'Head': 'Голова',
	'Backpack': 'Рюкзак',
	'Grenade_1': 'Гранаты 1',
	'Grenade_2': 'Гранаты 2',
	'Flashlight': 'Фонарик',
	'Radio': 'Радио',
```

- [ ] **Step 2: VTKUI.gd — пять точек отображения** (поиском):
```gdscript
	# 1) метка цели (бывш. Loc.txt("Target: ") + slot):
	tgt.text = Loc.txt(_target_slot) if _target_slot != "" else "-"
	# 2) строка слота:
	tag.text = Loc.txt(slot)
	# 3) сводка на «Готово»:
	var line := Loc.txt(slot) + " · " + str(desc.get("name", "?"))
	# 4) чипы сетов:
	ch.text = Loc.txt(str(slot))
	# 5) сообщение об отказе:
	_set_problem(Loc.txt("Does not fit: ") + Loc.txt(slot))
```

- [ ] **Step 3: keycheck видит слоты** — в `keycheck.py` после блока `SUBCATEGORY_ORDER` добавить:
```python
for s in re.findall(r'"([^"]+)"', block(picker, "const SLOT_ORDER := [", "[", "]")):
    dynamic.setdefault(s, set()).add("VTKPicker.gd/SLOT_ORDER")
```
(иначе новые ключи попадут в «unused», а пропущенный слот — не пойман.)

- [ ] **Step 4: гард** — в GONE layout_check: `'"Target: "'`.

- [ ] **Step 5: стенды** → все три зелёные; keycheck: `RESULT: every Loc.txt() key has a RU entry`, в «unused» не должно быть новых слотов. В игре: слоты по-русски в строке, сводке, чипах; цель — «Primary» без «Цель:».

---

### Task 7: Фильтр шага 1 — пересборка бара (#5)

**Files:**
- Modify: `VTKUI.gd` — `_rebuild_target_bar`, заменить `_target_subcategories` на `_target_cats`/`_target_subs`, добавить `_validate_target_filters`, вызов в `_set_search`
- Modify: `.check/layout_check.py` — PRESENT/GONE/FUNCS

**Interfaces:**
- Consumes: `_target_filter_items() -> Array` (записи `{item, name, cat, sub}` **без** фильтра по категории), `Picker.category_keys()`, `Picker.order_subcategories()`.
- Produces: `_target_cats(found) -> Array`, `_target_subs(found, cat) -> Array`, `_validate_target_filters() -> void`; поведение бара по спецификации пользователя.

**Утверждённая спецификация (дословно):** «Нажимая на слот, если в фильтре несколько категорий — показываем категории, по тапу на категорию разворачиваются подкатегории. Если категория одна и есть несколько подкатегорий — показываем только подкатегории. Если и категория, и подкатегория в одном экземпляре — фильтр не показываем».

- [ ] **Step 0: снапшот** — скопировать `VTKUI.gd` в `%TEMP%\opencode\vtk-snap-473-targetbar.gd`.

- [ ] **Step 1: заменить `_rebuild_target_bar`** (от `func _rebuild_target_bar()` до строки-комментария `# Чип фильтра.`; искать конец **вперёд** от начала):
```gdscript
func _rebuild_target_bar() -> void:
	if _target_bar == null:
		return
	for child in _target_bar.get_children():
		_target_bar.remove_child(child)
		child.queue_free()

	var tgt := Label.new()
	tgt.text = Loc.txt(_target_slot) if _target_slot != "" else "-"
	tgt.add_theme_font_size_override("font_size", 10)
	tgt.add_theme_color_override("font_color", _gold)
	_target_bar.add_child(tgt)

	# Показываем только когда есть что фильтровать: несколько категорий -
	# чипы категорий (плюс подкатегории выбранной), одна категория с
	# несколькими подкатегориями - только подкатегории, единственный
	# экземпляр и того и другого - не показываем вовсе.
	var found := _target_filter_items()
	var cats := _target_cats(found)
	var show_subs: Array = []
	var show_line := false
	if cats.size() > 1:
		show_line = true
		if _target_cat != "":
			show_subs = _target_subs(found, _target_cat)
	elif cats.size() == 1:
		show_subs = _target_subs(found, cats[0])
		show_line = show_subs.size() > 1
	if not show_line:
		return

	var line := HFlowContainer.new()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_theme_constant_override("h_separation", 4)
	line.add_theme_constant_override("v_separation", 2)

	var lbl := Label.new()
	lbl.text = Loc.txt("Filter") + ":"
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color("#5f5347"))
	line.add_child(lbl)

	if cats.size() > 1:
		for c in cats:
			line.add_child(_make_filter_chip(c, _target_cat == c))
	for sub in show_subs:
		line.add_child(_make_filter_chip(sub, _target_sub == sub, true))

	var reset := Button.new()
	reset.text = Loc.txt("Reset")
	reset.add_theme_font_size_override("font_size", 9)
	reset.tooltip_text = Loc.txt("Reset")
	var any_on := _target_cat != "" or _target_sub != ""
	reset.add_theme_stylebox_override("normal", _make_chip_style(any_on))
	reset.add_theme_color_override("font_color", _gold if any_on else Color("#5f5347"))
	reset.pressed.connect(_reset_target_filters)
	line.add_child(reset)

	_target_bar.add_child(line)
```

- [ ] **Step 2: заменить `_target_subcategories`** (от её комментария до `func _remove_slot`) на три функции:
```gdscript
# Уникальные категории найденного списка в порядке чипов: сначала известный
# порядок Picker.category_keys(), затем остальные по алфавиту - строка
# фильтров и валидация должны считать набор одинаково.
func _target_cats(found: Array) -> Array:
	var known := Picker.category_keys()
	var out: Array = []
	for c in known:
		for e in found:
			if str(e.get("cat", "")) == c and not out.has(c):
				out.append(c)
	var extra: Array = []
	for e in found:
		var c := str(e.get("cat", ""))
		if c != "" and not known.has(c) and not extra.has(c):
			extra.append(c)
	extra.sort()
	out.append_array(extra)
	return out

# Подкатегории одной категории из найденного списка, в общем порядке
# Picker.order_subcategories, чтобы чипы не прыгали между перестройками.
func _target_subs(found: Array, cat: String) -> Array:
	var seen: Array = []
	for e in found:
		if str(e.get("cat", "")) == cat:
			var s := str(e.get("sub", ""))
			if s != "" and not seen.has(s):
				seen.append(s)
	return Picker.order_subcategories(seen)

# Смена запроса меняет набор найденного: под категорию или подкатегорию
# могло остаться одно или ноль предметов, и фильтр без чипов молча пускал бы
# пустую сетку. Сбрасываем только то, чего больше нет в данных.
func _validate_target_filters() -> void:
	if _target_cat == "" and _target_sub == "":
		return
	var found := _target_filter_items()
	var cats := _target_cats(found)
	if _target_cat != "":
		if not cats.has(_target_cat):
			_target_cat = ""
			_target_sub = ""
		elif _target_sub != "" and not _target_subs(found, _target_cat).has(_target_sub):
			_target_sub = ""
		return
	if cats.size() == 1:
		if _target_sub != "" and not _target_subs(found, cats[0]).has(_target_sub):
			_target_sub = ""
	else:
		_target_sub = ""
```

- [ ] **Step 3: вызов валидации** — в `_set_search` первой строкой после `_search_text = t`:
```gdscript
	_validate_target_filters()
```

- [ ] **Step 4: гарды layout_check** — PRESENT += `"_validate_target_filters"`, `"_target_cats"`, `"_target_subs"`; GONE += `"_target_subcategories"`; FUNCS +=:
```python
    ("_set_search", ["_validate_target_filters()"],
     "смена запроса валидирует фильтры до пересборки сетки"),
```

- [ ] **Step 5: стенды** → зелёные. В игре проверить ветки: слот с 2+ категориями (чипы → тап → подкатегории), слот с 1 категорией и 2+ подкатегориями (только подкатегории), слот с одним предметом (фильтра нет), ввод/стирание поиска (протухшие чипы исчезают, сетка не пустеет молча), «Сброс».

---

### Task 8: Снаряжение — сворачивание подкатегорий (#10)

**Files:**
- Modify: `VTKUI.gd` — объявление, `_rebuild_gear_facets`, `_set_gear_facet`, комментарий `_make_facet_row`, `_reset_picker_state`
- Modify: `.check/layout_check.py` — PRESENT

- [ ] **Step 1: флаг** — после `var _gear_sub_key: String = ""`:
```gdscript
# Повторный клик по активной категории сворачивает её подкатегории;
# категория при этом остаётся выбранным фильтром.
var _gear_subs_collapsed: bool = false
```

- [ ] **Step 2: условие показа** — в `_rebuild_gear_facets`:
```gdscript
		if _gear_facet_key != "" and key == _gear_facet_key and not _gear_subs_collapsed:
```
и обновить комментарий над `_make_facet_row` (бывш. «Клик по активной строке ничего не меняет…») на: «Клик по активной строке сворачивает/разворачивает её подкатегории; категория продолжает фильтровать. К возврату ко «Всем предметам» ведёт строка «Все предметы»».

- [ ] **Step 3: переключение** — `_set_gear_facet`:
```gdscript
func _set_gear_facet(key: String) -> void:
	if key != "" and key == _gear_facet_key:
		# Повторный клик по активной категории сворачивает её подкатегории.
		_gear_subs_collapsed = not _gear_subs_collapsed
	else:
		_gear_facet_key = key
		# Смена категории сбрасывает подкатегорию: иначе после "Винтовки" ->
		# "Пистолеты" остался бы фильтр "Снайперки" из прошлой ветки.
		_gear_sub_key = ""
		_gear_subs_collapsed = false
	_refresh_gear_catalog()
```
(комментарий «Фасет меняет только набор клеток…» сохранить над функцией.)

- [ ] **Step 4: сброс** — в `_reset_picker_state` добавить `_gear_subs_collapsed = false`.

- [ ] **Step 5: гард** — PRESENT += `"_gear_subs_collapsed"`.

- [ ] **Step 6: стенды** → зелёные; в игре: тап по «Оружие» раскрывает подкатегории, повторный тап скрывает (фильтр остаётся), смена категории сбрасывает и подкатегорию, и свёрнутость.

---

### Task 9: Обвесы — состояние на страницу (#11)

**Files:**
- Modify: `VTKUI.gd` — объявление (бывш. 36), 17 вхождений `_open_att_path` (перечень ниже)
- Modify: `.check/layout_check.py` — GONE/PRESENT

**Interfaces:**
- Consumes: `_page: int` (0 = Экипировка, 1 = Снаряжение, 2 = Готово), `_rebuild_att_box(host, path)`.
- Produces: `_open_equip_att: String`, `_open_gear_att: String` — каждая страница хранит и рендерит свою панель.

- [ ] **Step 1: объявление** — заменить `var _open_att_path: String = ""` на:
```gdscript
# Открытая панель обвесов своя у каждой страницы: экран, открытый в
# Экипировке, не должен появляться в Снаряжении.
var _open_equip_att: String = ""
var _open_gear_att: String = ""
```

- [ ] **Step 2: рендер каждой страницы** (поиском):
```gdscript
	# _refresh_page_equipment:
	_rebuild_att_box(_equip_att_box, _open_equip_att)
	# _refresh_page_gear:
	_rebuild_att_box(_gear_att_box, _open_gear_att)
```

- [ ] **Step 3: тоггл с учётом страницы:**
```gdscript
func _toggle_attachment_panel(path: String) -> void:
	if _page == 1:
		_open_gear_att = "" if _open_gear_att == path else path
	else:
		_open_equip_att = "" if _open_equip_att == path else path
	_refresh_draft_ui()
```

- [ ] **Step 4: автооткрытие после размещения** — в `_after_place` заменить `_open_att_path = _last_placed` на ветку по `_page == 1` → `_open_gear_att = _last_placed`, иначе `_open_equip_att = _last_placed`.

- [ ] **Step 5: все сбросы чистят обе переменные** (каждое место — обе строки):
```gdscript
	_open_equip_att = ""
	_open_gear_att = ""
```
Сайты: `_reset_picker_state`, `_remove_slot` (под `if _open_... == path_now:` обе), `_remove_gear` (под `if ... == path:` обе), `_set_target_slot`, `_start_new_draft`, `_cancel_draft`, `_edit_loadout`.

- [ ] **Step 6: комментарий `_rebuild_att_box`** — заменить «Один _open_att_path на обе страницы…» на:
```gdscript
# Своя панель у каждой страницы: экран, открытый в Экипировке, не должен
# появляться и в Снаряжении. Каждая страница рендерит только своё состояние.
```

- [ ] **Step 7: гарды** — GONE += `"_open_att_path"`; PRESENT += `"_open_equip_att"`, `"_open_gear_att"`.

- [ ] **Step 8: стенды** → зелёные; grep по `_open_att_path` = 0. В игре: открыть обвесы в Экипировке → перейти в Снаряжение → панель не видна; у каждого свой тоггл; смена слота/сета чистит обе.

---

### Task 10: Гигиена — orphan `'gear'`, `_dark_border`, `_add_depth` (бэклог)

**Files:**
- Modify: `VTKLoc.gd` — удалить `'gear': 'снаряжение',`
- Modify: `VTKUI.gd` — удалить `var _dark_border` и функцию `_add_depth` с её комментарием
- Modify: `.check/layout_check.py` — GONE

- [ ] **Step 1:** удалить оба объявления (предварительно grep: 0 использований).
- [ ] **Step 2:** GONE += `"_dark_border"`, `"_add_depth"`.
- [ ] **Step 3: стенды** → зелёные; `py -3 .check\keycheck.py` — в «unused» не должно остаться `'gear'`.

---

### Task 11: Тултипы на блоках — проверка в игре (бэклог Task 6)

**Files:** без правок (пока).

**Контекст:** `_panel.theme` задаёт `TooltipPanel` (тёмная панель, margin 12) и `TooltipLabel` (font 10) в VTKUI.gd:320–327. По исходникам Godot 4.6 тултип-попап добавляется **ребёнком к владельцу-контролу** (`viewport.cpp`, `_gui_show_tooltip_at`), а `Window` наследует тему через `NOTIFICATION_PARENTED` (`window.cpp:1524`) — запись должна работать. Сомнение ревьюера («отдельный Window, no-op») проверяем empirически.

- [ ] **Step 1: в игре** навести на слот (тултип «Убрать»), на клетку каталога (имя предмета), на строку фасета.
- [ ] **Step 2: результат.** Ожидание: тёмная панель `#1a1510` с рамкой и мелким шрифтом 10. Если тултип приходит дефолтным (жёлтый/шрифт игры) — **остановиться и доложить пользователю**, варианты фикса обсуждать отдельно (глобальная тема `get_window().theme` затронет UI игры и без обсуждения не применяется).

---

### Task 12: Релиз 4.7.3 — версия, сборка, доставка, чек-лист

**Files:**
- Modify: `loadouts/mod.txt` (`version="4.7.2"` → `4.7.3`)
- Create: `Loadouts.vmz` (pack.ps1), копия в папку модов игры

- [ ] **Step 1:** `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1` и `py -3 .check\layout_check.py` и `py -3 .check\keycheck.py` — финальный прогон всех трёх.
- [ ] **Step 2:** в `loadouts/mod.txt` → `version="4.7.3"`; `py -3 .check\encoding_check.py` (mojibake-скан исходников).
- [ ] **Step 3:** `powershell -ExecutionPolicy Bypass -File pack.ps1` (workdir `D:\RTVMOD`) → в выводе `Version in mod.txt: 4.7.3`; затем `py -3 .check\encoding_check.py` (проверит версию уже внутри пака).
- [ ] **Step 4:** скопировать `D:\RTVMOD\Loadouts.vmz` → `D:\SteamLibrary\steamapps\common\Road to Vostok\mods\Loadouts.vmz`.
- [ ] **Step 5: полный игровой чек-лист** — 1. степпер вровень с «Применить»; 2. Х в слоте внутри рамки; 3. цель без «Цель:»; 4. чипы фильтра выше; 5. все три ветки фильтра (#5-спецификация) + валидация при поиске; 6. сетка при 1–4 предметах слева, без растяжения; 7. иконка по центру клетки, ховер по всему тайлу; 8. слоты по-русски (строка/сводка/чипы/ошибка/цель); 9. фасеты +6; 10. повторный тап сворачивает подкатегории; 11. панель обвесов не утекает между страницами; 12. EN/RU 64×30 без рамки, без ошибки `already has a parent` в логе; 13. список телепорта на всю высоту; тултипы (Task 11); orphan/hygiene — ключей нет.
- [ ] **Step 6:** в игре открыть лог и убедиться, что нет `SCRIPT ERROR` / `already has a parent` / `Invalid call`.

---

## Self-review (выполненный)

- **Spec coverage:** 13 пунктов → Tasks 1–9 (13=T1, 12=T2, 1+4=T3, 2+9=T4, 6+7=T5, 3+8=T6, 5=T7, 10=T8, 11=T9); бэклог → T6/T9/T10 (ключи/гигиена), T11 (тултипы), T12 (версия+доставка). Пропусков нет.
- **Placeholders:** все правки даны кодом до/после или точным содержимым; команды и ожидаемые выводы стендов указаны.
- **Type consistency:** `_target_cats/_target_subs/_validate_target_filters` — имена совпадают между Step 2/3/4 T7 и гардами; `_open_equip_att/_open_gear_att` — между всеми 6 шагами T9; `keycheck`-блок `SLOT_ORDER` совпадает с реальным `const SLOT_ORDER := ["Primary", ...]`.
