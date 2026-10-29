# CheatMenu Visual Port — 4.7.1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Довести мод Vostok Toolkit до вида «идеального макета» (v4.7.1): убрать лишний хром рейла и статус-строку, вернуть точки вместо иконок в слотах и чипах, заменить пунктир пустых слотов на приглушённые строки, перевести все поверхности UI на слоёные SVG-текстуры золотой палитры (приём CheatMenu `FieldTheme`), заменить иконки 36×36 на обрезанные по `used_rect` «спрайты» 84×48 в ячейках 96×132, увеличить панель до 800×880.

**Architecture:** Декор, собранный из `StyleBoxFlat`, переезжает на `VTKSurface` — статический RefCounted-фабрикат, кэширующий `StyleBoxTexture` по ключу состояния/цвета/полей. Кроп иконок — чистая функция `Picker.item_art()` в `VTKPicker.gd`, тестируется headless. Мелочи (хром, точки, пунктир, размеры) правятся маленькими задачами; стенды `.check` держат раскладку и парсинг зелёными после каждой задачи.

**Tech Stack:** Godot 4.6.3, GDScript, `Image.load_svg_from_string`, `AtlasTexture`+`filter_clip`, стенды `layout_check.py`/`check.ps1`, `pack.ps1`.

## Global Constraints

- Репозиторий **без git**: точки контроля — стенды `.check` и снапшоты в `%TEMP%\opencode\vtk-snap-*`. Шагов `git commit` в плане нет.
- Стенды зелёные после **каждой** задачи:
  - `python .check\layout_check.py`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1` (Godot в PATH; иначе `-Godot "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe"`)
- Исходники мода — `loadouts/mods/VTK/*.gd`; отступы только табы; файлы UTF-8 без BOM, `VTK*.gd` — CRLF.
- Версия живёт только в `loadouts/mod.txt` (`version="4.7.1"`). Версии в коде не добавлять.
- Локализация через `Loc.txt()`; удаление русского перевода — вместе с удалением строки из кода (иначе keycheck не сойдётся).
- **Не трогаем:** точки `_make_dot`, кружки шагов `_make_step_circle_style`, золотой свитч `ToggleSwitch` — остаются `StyleBoxFlat`.
- Иконки: кроп только на отображении (`AtlasTexture` поверх оригинала), ассеты игры не меняются.
- Списки `GONE`/`PRESENT`/`FUNCS` в `layout_check.py` пополняются в той же задаче, где меняется код, иначе следующей прогон стенда упадёт.
- Не удалять используемые функции: `_item_slots`, `Draft.slot_label`, `_add_depth`, `_item_icon`.

---

### Task 1: Убрать рейловый хром и статус-строку

Удаляем бренд-квадрат «VTK», подпись вкладки в рейле (`_rail_tab`), живые часы (`_clock_label`/`_clock_text`), нижнюю статус-строку (`_chrome_stat`, `_set_stat`, `_stat_msg`). Рейл остаётся: `VOSTOK TOOLKIT` + `v4.7.1`.

**Files:**
- Modify: `D:\RTVMOD\loadouts\mods\VTK\VTKUI.gd`
- Modify: `D:\RTVMOD\loadouts\mods\VTK\VTKLoc.gd`
- Modify: `D:\RTVMOD\.check\layout_check.py`

**Interfaces:**
- Produces: `_switch_tab` без `_rail_tab`; `_set_problem`/`_clear_problem` без `_set_stat`; функции `_chrome_stat`, `_set_stat`, `_make_dot_texture` удалены.

- [ ] **Step 1: обновить `layout_check.py` — список `GONE`**

Добавить в конец списка `GONE`:

```python
    "_chrome_stat",
    "_set_stat",
    "_rail_tab",
    "_clock_label",
    "_clock_text",
    "_stat_msg",
    "_make_dot_texture",
```

- [ ] **Step 2: удалить переменные хрома** (VTKUI.gd, строки 107–113)

Удалить целиком:

```gdscript
# КПК-хром: верхний рейл устройства и нижняя статус-строка. Часы обновляются
# в _process раз в секунду, пока панель открыта; текст рейла про текущую
# вкладку переписывает _switch_tab.
var _rail_tab: Label = null
var _clock_label: Label = null
var _clock_text: String = ""
var _stat_msg: Label = null
```

- [ ] **Step 3: зачистить `_process`** (строки 122–128)

Заменить:

```gdscript
func _process(_delta: float) -> void:
	if _clock_label != null and visible:
		var now := Time.get_time_dict_from_system()
		var short := "%02d:%02d" % [now["hour"], now["minute"]]
		if short != _clock_text:
			_clock_text = short
			_clock_label.text = short
	var scene = get_tree().current_scene
```

на:

```gdscript
func _process(_delta: float) -> void:
	var scene = get_tree().current_scene
```

- [ ] **Step 4: удалить `_chrome_stat`, `_set_stat`, `_make_dot_texture`**

Удалить целиком функции на строках 319–348 (`_chrome_stat`, `_set_stat`) и 371–374 (`_make_dot_texture`). Поиск вхождения: `func _chrome_stat`, `func _set_stat`, `func _make_dot_texture`. `_make_dot_texture` — мёртвый код (единственное вхождение — объявление, вызовов нет).

- [ ] **Step 5: зачистить `_build_ui`**

5a. Рейл: заменить блок 413–482 (от комментария `# КПК-хром: верхний рейл устройства...` до `seg.add_child(_clock_label)` включительно) на:

```gdscript
	# КПК-хром: верхний рейл устройства. Только имя и версия: бренд-квадрат,
	# текущая вкладка и часы из макета убраны.
	var rail := HBoxContainer.new()
	rail.position = Vector2(4, 4)
	rail.size = Vector2(732, 30)
	rail.add_theme_constant_override("separation", 8)
	_panel.add_child(rail)
	_ui_nodes.append(rail)

	var name_box := VBoxContainer.new()
	name_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_box.add_theme_constant_override("separation", 0)
	rail.add_child(name_box)
	var rname := Label.new()
	rname.text = "VOSTOK TOOLKIT"
	rname.add_theme_font_size_override("font_size", 11)
	name_box.add_child(rname)
	var rver := Label.new()
	rver.text = "v" + _mod_version()
	rver.add_theme_font_size_override("font_size", 8)
	rver.add_theme_color_override("font_color", Color("#5f5347"))
	name_box.add_child(rver)
```

5b. Статус-строка: удалить блок 522–544 целиком (от `# КПК-хром: нижняя статус-строка...` до `statbar.add_child(sver)`).

- [ ] **Step 6: зачистить `_switch_tab`** (строки 556–557)

Удалить:

```gdscript
	if _rail_tab != null:
		_rail_tab.text = name
```

- [ ] **Step 7: зачистить `_set_problem`/`_clear_problem`** (строки 804–812)

Удалить `_set_stat(msg, "err")` из `_set_problem` и `_set_stat(Loc.txt("Ready"), "exp")` из `_clear_problem`. Остаётся обновление `_page_label`.

- [ ] **Step 8: удалить переводы** (VTKLoc.gd, строки 144–145)

```gdscript
	'Ready': 'Готово',
	' files': ' файлов',
```

- [ ] **Step 9: контрольная точка**

Run:
```
python .check\layout_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```
Expected: оба зелёные (`RESULT: символы раскладки на месте`, `tests passed`, код 0). Снапшот: `%TEMP%\opencode\vtk-snap-4.7.1-task1.gd`.

---

### Task 2: Убрать MCM-плашку и подсказки из настроек

Удаляем блок «тонкие настройки живут в MCM» и строку-подсказку про `ui_toggles.json`. Вкладка «Настройки» остаётся: язык + три тумблера.

**Files:**
- Modify: `D:\RTVMOD\loadouts\mods\VTK\VTKUI.gd`
- Modify: `D:\RTVMOD\loadouts\mods\VTK\VTKLoc.gd`
- Modify: `D:\RTVMOD\.check\layout_check.py`

**Interfaces:**
- Produces: `_build_settings_tab` заканчивается на `_make_toggle_row(..., _thermal_toggle)`.

- [ ] **Step 1: обновить `layout_check.py` — `GONE`**

```python
    "mcm_ref",
    "mcm_box",
    "box_icon",
    "hintline",
    "Fine settings (noise, thermal palette, UI hotkey) live in MCM.",
    "All mod keys are registered there automatically.",
    "Toggle state is stored in ui_toggles.json and survives restarts.",
```

- [ ] **Step 2: удалить блок MCM из `_build_settings_tab`** (строки 2696–2763)

Удалить целиком от `var mcm_ref := PanelContainer.new()` до `hintline.add_child(hint)` включительно. Не трогать заголовок «Modules» и три `_make_toggle_row`.

- [ ] **Step 3: удалить переводы** (VTKLoc.gd, строки 154–156)

```gdscript
	'Fine settings (noise, thermal palette, UI hotkey) live in MCM.': 'Тонкие настройки (шум, палитра тепловизора, горячая клавиша UI) живут в MCM.',
	'All mod keys are registered there automatically.': 'Все ключи мода регистрируются там автоматически.',
	'Toggle state is stored in ui_toggles.json and survives restarts.': 'Состояние переключателей хранится в ui_toggles.json и переживает перезапуски.',
```

- [ ] **Step 4: контрольная точка**

Run:
```
python .check\layout_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```
Expected: зелёные. Снапшот: `%TEMP%\opencode\vtk-snap-4.7.1-task2.gd`.

---

### Task 3: Точки вместо иконок в слотах и чипах снаряжения

Возвращаем точку `_make_dot` на место иконок `item.icon` в строке слота и в чипе снаряжения.

**Files:**
- Modify: `D:\RTVMOD\loadouts\mods\VTK\VTKUI.gd`

**Interfaces:**
- Consumes: `_make_dot(color)` (без изменений).
- Produces: после задачи `_item_icon` используется только в `_make_item_cell`/`_make_att_cell`.

- [ ] **Step 1: строка слота — убрать иконку** (VTKUI.gd, строки 1521–1538)

Заменить блок:

```gdscript
	# Точка отвечает на "есть предмет", а не на категорию, поэтому её цвет не
	# связан с палитрой категорий и переживает отказ от них. Когда у предмета
	# есть реальная иконка, она занимает место точки, как в макете.
	var placed_icon: Texture2D = null
	if occupied:
		var res = _item_info(str(desc.get("path", ""))).get("resource")
		placed_icon = _item_icon(res) if res != null else null
	if placed_icon != null:
		var ic := TextureRect.new()
		ic.texture = placed_icon
		ic.custom_minimum_size = Vector2(14, 14)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(ic)
	else:
		hb.add_child(_make_dot(_gold if occupied else Color("#2a1f14")))
```

на:

```gdscript
	# Точка отвечает на "есть предмет", а не на категорию. Иконок в слотах и
	# чипах нет: спрайты живут только в ячейках каталога и обвесов.
	hb.add_child(_make_dot(_gold if occupied else Color("#2a1f14")))
```

- [ ] **Step 2: чип снаряжения — убрать иконку** (строки 1041–1053)

Заменить:

```gdscript
	var chip_icon: Texture2D = null
	var chip_res = _item_info(path_now).get("resource")
	if chip_res != null:
		chip_icon = _item_icon(chip_res)
	if chip_icon != null:
		var ic := TextureRect.new()
		ic.texture = chip_icon
		ic.custom_minimum_size = Vector2(14, 14)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ic)
```

на:

```gdscript
	row.add_child(_make_dot(_gold))
```

- [ ] **Step 3: контрольная точка**

Run:
```
python .check\layout_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```
Expected: зелёные. Снапшот: `%TEMP%\opencode\vtk-snap-4.7.1-task3.gd`.

---

### Task 4: Пустой слот — приглушённая строка вместо пунктира

Убираем `DashedBorder` и заменяем его на `PanelContainer` со стилем пустой строки. Ховер и золотая рамка активной цели сохраняются.

**Files:**
- Modify: `D:\RTVMOD\loadouts\mods\VTK\VTKUI.gd`
- Modify: `D:\RTVMOD\.check\layout_check.py`

**Interfaces:**
- Consumes: `_make_slot_style(active, hover)` расширяется третьим флагом `empty`.
- Produces: класс `DashedBorder` удаляется полностью.

- [ ] **Step 1: обновить `layout_check.py` — `GONE`**

```python
    "DashedBorder",
```

- [ ] **Step 2: расширить `_make_slot_style`** (строки 1582–1593)

Заменить сигнатуру и тело:

```gdscript
func _make_slot_style(active: bool, hover: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#2a1a0a") if active else Color("#201a12" if hover else "#1a1510")
	s.border_color = _gold if active else Color("#d48a3a66" if hover else "#241b12")
	s.border_width_all = 1
	s.corner_radius_all = 3
	s.content_margin_left = 4
	s.content_margin_right = 4
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	_add_depth(s, active)
	return s
```

на:

```gdscript
func _make_slot_style(active: bool, hover: bool = false, empty: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	if empty:
		s.bg_color = Color("#15110d")
		s.border_color = _gold if active else Color("#d48a3a55" if hover else "#241b12")
	else:
		s.bg_color = Color("#2a1a0a") if active else Color("#201a12" if hover else "#1a1510")
		s.border_color = _gold if active else Color("#d48a3a66" if hover else "#241b12")
	s.border_width_all = 1
	s.corner_radius_all = 3
	s.content_margin_left = 4
	s.content_margin_right = 4
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	_add_depth(s, active)
	return s
```

- [ ] **Step 3: заменить ветку пустого слота** (строки 1490–1507)

Заменить:

```gdscript
	else:
		# Пустой слот - пунктирная рамка: StyleBoxFlat не умеет пунктир, поэтому
		# рамка рисуется кастомным контролом и перекрашивается при ховере и
		# выборе цели.
		var dashed := DashedBorder.new()
		dashed.custom_minimum_size = Vector2(0, 22)
		dashed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dashed.mouse_filter = Control.MOUSE_FILTER_STOP
		var base_col := _gold if active else Color("#3a2e20")
		dashed.border_color = base_col
		dashed.mouse_entered.connect(func():
			dashed.border_color = _gold if active else Color("#d48a3a66")
			dashed.queue_redraw())
		dashed.mouse_exited.connect(func():
			dashed.border_color = base_col
			dashed.queue_redraw())
		dashed.gui_input.connect(func(ev): _on_slot_row_input(ev, slot, desc))
		row = dashed
```

на:

```gdscript
	else:
		# Пустой слот - обычная приглушённая строка (пунктир в Godot удел
		# кастомного _draw, а он не переживает пересборку строки).
		var box := PanelContainer.new()
		box.custom_minimum_size = Vector2(0, 22)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.mouse_filter = Control.MOUSE_FILTER_STOP
		box.add_theme_stylebox_override("panel", _make_slot_style(active, false, true))
		_attach_row_hover(box, func(hv: bool): return _make_slot_style(active, hv, true))
		_attach_motion(box)
		box.gui_input.connect(func(ev): _on_slot_row_input(ev, slot, desc))
		row = box
```

- [ ] **Step 4: удалить класс `DashedBorder`** (строки 1608–1635)

Удалить целиком комментарий `# Пустой слот: пунктирная рамка...` и `class DashedBorder:` с `_draw`/`_dash`.

- [ ] **Step 5: контрольная точка**

Run:
```
python .check\layout_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```
Expected: зелёные. Снапшот: `%TEMP%\opencode\vtk-snap-4.7.1-task4.gd`.

---

### Task 5: Создать `VTKSurface.gd` — слоёные SVG-поверхности

Новый файл по образцу CheatMenu `FieldTheme.gd`, но в золотой палитре мода. Статический `RefCounted`, кэширует SVG-текстуры и `StyleBoxTexture` по ключу состояния/цвета/полей.

**Files:**
- Create: `D:\RTVMOD\loadouts\mods\VTK\VTKSurface.gd`
- Modify: `D:\RTVMOD\.check\layout_check.py` (PRESENT)

**Interfaces:**
- Produces (использует Task 6):
  - `VTKSurface.surface(state := "normal", accent := false, danger := false, strong := false, ml := 14, mr := 14, mt := 9, mb := 11) -> StyleBoxTexture` — кэш по всем параметрам.
  - `VTKSurface.panel(inset := false, margin := 16) -> StyleBoxFlat`
  - `VTKSurface.focus_style() -> StyleBoxFlat` — золотая рамка фокуса.
  - `VTKSurface.style_button(button: Button, accent := false, danger := false, ml := 14, mr := 14, mt := 9, mb := 11) -> void`
  - `VTKSurface.svg_texture(svg: String) -> Texture2D` (внутреннее).
  - `VTKSurface.clear_cache() -> void`

- [ ] **Step 1: создать файл `VTKSurface.gd`**

Полное содержимое:

```gdscript
extends RefCounted
## Слоёные SVG-поверхности в золотой палитре (приём CheatMenu/FieldTheme).
## Всё кэшируется по ключу состояния; поверхности статичны и переживают
## перестройку UI (mod.tres не перегружается, кэш чистить не нужно).

const GOLD := Color("#d48a3a")
const INK := Color("#d8cdbe")
const MUTED := Color("#8a7a6a")

static var _surfaces: Dictionary = {}
static var _textures: Dictionary = {}

static func clear_cache() -> void:
	_surfaces.clear()
	_textures.clear()

static func svg_texture(svg: String) -> Texture2D:
	if _textures.has(svg):
		return _textures[svg]
	var image := Image.new()
	if image.load_svg_from_string(svg) != OK:
		return null
	var tex := ImageTexture.create_from_image(image)
	_textures[svg] = tex
	return tex

static func surface(state: String = "normal", accent: bool = false,
		danger: bool = false, strong: bool = false,
		ml: int = 14, mr: int = 14, mt: int = 9, mb: int = 11) -> StyleBoxTexture:
	var key := "%s/%s/%s/%s/%d/%d/%d/%d" % [state, accent, danger, strong, ml, mr, mt, mb]
	if _surfaces.has(key):
		return _surfaces[key]

	var edge := "#5a3a1a" if accent else "#3a2e20"
	var top := "#33220e" if accent else "#261f18"
	var bottom := "#241708" if accent else "#191410"
	if danger:
		top = "#40261c"
		bottom = "#2c1a14"
		edge = "#6e3d2a"
	if state == "hover":
		top = "#3f2e12" if accent else "#2c2417"
		bottom = "#241708" if accent else "#1c1711"
		edge = "#d48a3a" if accent else "#c9823a"
	elif state == "pressed":
		top = "#18130c"
		bottom = "#291c09"
		edge = "#b87a30"
	elif state == "disabled":
		top = "#1c1713"
		bottom = "#151210"
		edge = "#2e251c"

	var svg := ('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64">' \
		+ '<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1">' \
		+ '<stop stop-color="%s"/><stop offset="1" stop-color="%s"/>' \
		+ '</linearGradient></defs>' \
		+ '<rect x="1" y="3" width="62" height="61" rx="5" fill="#0d0a07" fill-opacity=".7"/>' \
		+ '<rect x="1.5" y="1.5" width="61" height="58" rx="4" fill="url(#g)" stroke="%s"/>' \
		+ '<path d="M6 3H58" stroke="#d8cdbe" stroke-opacity=".10"/>' \
		+ '<path d="M5 57H59" stroke="#000" stroke-opacity=".5"/>' \
		+ '<rect x="4" y="5" width="56" height="50" rx="2" fill="none" stroke="#d8cdbe" stroke-opacity=".03"></rect>' \
		+ '</svg>') % [top, bottom, edge]

	var style := StyleBoxTexture.new()
	style.texture = svg_texture(svg)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 8)
	style.content_margin_left = ml
	style.content_margin_right = mr
	style.content_margin_top = mt
	style.content_margin_bottom = mb
	_surfaces[key] = style
	return style

static func panel(inset: bool = false, margin: int = 16) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#171208") if inset else Color("#1a1510")
	s.border_color = Color("#2a1f14")
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(margin)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 5
	s.shadow_offset = Vector2(0, 3)
	return s

static func focus_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color.TRANSPARENT
	s.border_color = GOLD
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	return s

static func style_button(button: Button, accent: bool = false, danger: bool = false,
		ml: int = 14, mr: int = 14, mt: int = 9, mb: int = 11) -> void:
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", Color("#efe5d4"))
	button.add_theme_color_override("font_pressed_color", GOLD)
	button.add_theme_color_override("font_disabled_color", Color("#5f5347"))
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, surface(state, accent, danger, false, ml, mr, mt, mb))
	button.add_theme_stylebox_override("focus", focus_style())
```

- [ ] **Step 2: добавить в `layout_check.py` — `PRESENT`**

```python
    "VTKSurface.surface",
    "VTKSurface.panel",
    "VTKSurface.style_button",
```

- [ ] **Step 3: контрольная точка**

Run:
```
python .check\layout_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```
Expected: зелёные (новый файл подхватывается `check.ps1` — он копирует `loadouts/mods/VTK/*.gd`).

---

### Task 6: Перевести поверхности UI на `VTKSurface`

Заменяем фабрики `StyleBoxFlat` и места прямого создания стилей на `VTKSurface.surface` у интерактивных контролов и `VTKSurface.panel` у полей. **Не трогаем** (остаются `StyleBoxFlat`): `_make_dot` (1602), `_make_step_circle_style` (738), `ToggleSwitch` (1683/1693), индикаторы `ind_s` (3318/3352). Флас-строки в табличке ниже — по мысли «все панели и поля».

**Files:**
- Modify: `D:\RTVMOD\loadouts\mods\VTK\VTKUI.gd`
- Modify: `D:\RTVMOD\.check\layout_check.py`

**Interfaces:**
- Consumes: `VTKSurface` из Task 5.
- Produces: функция `_make_dark_style` удаляется; `_make_chip_style`/`_make_slot_style`/`_make_step_row_style`/`_make_seg_btn_style`/`_make_tp_section_style` остаются как обёртки над `VTKSurface` (подписей вызовов не меняют).

- [ ] **Step 0 (обязательное): подключить модуль в `VTKUI.gd`**

Рядом с остальными прелоадами (блок `const Loc`/`const Picker`/`const Draft` в начале файла):

```gdscript
const VTKSurface := preload("res://mods/VTK/VTKSurface.gd")
```

- [ ] **Step 1: обновить `layout_check.py` — `GONE`**

```python
    "_make_dark_style",
```

- [ ] **Step 2: вкладки** (VTKUI.gd, строки 350–369)

Заменить обе функции:

```gdscript
func _make_tab_style() -> StyleBox:
	return VTKSurface.surface("normal", false, false, false, 14, 14, 6, 6)

func _make_tab_active_style() -> StyleBox:
	return VTKSurface.surface("normal", true, false, true, 14, 14, 6, 6)
```

- [ ] **Step 3: чипы фильтров** (строки 376–389)

```gdscript
func _make_chip_style(active: bool, hover: bool = false) -> StyleBox:
	return VTKSurface.surface("hover" if hover else "normal", active, false, false, 8, 12, 4, 4)
```

- [ ] **Step 4: поля ввода и маленькие кнопки вместо `_make_dark_style`**

4a. Поиск шага 1 (908–909), поиск снаряжения (954–955), имя сета (1312–1313):

заменить `("normal", _make_dark_style())` → `("normal", VTKSurface.panel(true, 10))`; `("focus", _make_dark_style(_gold))` → `("focus", VTKSurface.focus_style())`.

4b. Кнопка шага `_make_step_btn` (1103):

```gdscript
	VTKSurface.style_button(b, false, false, 2, 2, 4, 4)
```

4c. Кнопка «Полная обойма» `_make_full_mag_btn` (1120):

```gdscript
	VTKSurface.style_button(b, on, false, 8, 8, 4, 4)
```

4d. Панели обвесов `_build_att_panel` (2431) и `_build_mag_panel` (2571):

заменить `("panel", _make_dark_style())` → `("panel", VTKSurface.panel(true, 10))`.

4e. Удалить функцию `_make_dark_style` (271–281) целиком.

- [ ] **Step 5: стиль строки слота** (после Task 4 — строки ~1582 с флагом `empty`)

Заменить тело (сигнатуру сохранить: `(active: bool, hover: bool = false, empty: bool = false) -> StyleBox`):

```gdscript
func _make_slot_style(active: bool, hover: bool = false, empty: bool = false) -> StyleBox:
	if empty:
		return VTKSurface.surface("hover" if hover else "disabled", active, false, active, 4, 4, 2, 2)
	return VTKSurface.surface("hover" if hover else "normal", active, false, active, 4, 4, 2, 2)
```

- [ ] **Step 6: стиль строки шага** (717–735)

Заменить тело (сигнатуру сохранить: `(active: bool, hover: bool = false) -> StyleBox`):

```gdscript
func _make_step_row_style(active: bool, hover: bool = false) -> StyleBox:
	return VTKSurface.surface("hover" if hover else "normal", active, false, active, 8, 4, 2, 2)
```

- [ ] **Step 7: сегмент языка** (2814–2859)

7a. Панель сегментов (2815–2820): заменить `seg_style` блок на

```gdscript
	seg_panel.add_theme_stylebox_override("panel", VTKSurface.panel(true, 4))
```

(переменную `seg_style` удалить).

7b. `_make_seg_btn_style` (2847–2859):

```gdscript
func _make_seg_btn_style(active: bool) -> StyleBox:
	return VTKSurface.surface("normal", active, false, false, 8, 8, 4, 4)
```

- [ ] **Step 8: телепорт** (3325–3336 и 3211–3221)

```gdscript
func _make_tp_section_style(active: bool) -> StyleBox:
	return VTKSurface.surface("normal", active, false, false, 10, 10, 7, 7)
```

и в `_tp_row` (3211–3221) заменить блок `var normal := StyleBoxFlat.new() ... _add_depth(normal)` на:

```gdscript
	row.add_theme_stylebox_override("panel", VTKSurface.surface("normal", false, false, false, 10, 10, 7, 7))
```

- [ ] **Step 9: карточки и ряды-панели**

9a. Чип снаряжения `_make_gear_chip` (1024–1033): заменить блок `var cs := ... _add_depth(cs)` на одну строку рядом с созданием card:

```gdscript
	card.add_theme_stylebox_override("panel", VTKSurface.surface("normal", false, false, false, 8, 8, 4, 4))
```

9b. Карточка сета (2003–2012):

```gdscript
	card.add_theme_stylebox_override("panel", VTKSurface.surface("normal", false, false, false, 12, 12, 11, 11))
```

9c. Ряд языка (2776–2788) и ряд тумблера `_make_toggle_row` (2874–2886):

заменить блок `var rs := StyleBoxFlat.new() ... _add_depth(rs)` на

```gdscript
	set_row.add_theme_stylebox_override("panel", VTKSurface.surface("normal", false, false, false, 10, 10, 7, 7))
```

и в `_make_toggle_row` (2888–2891) заменить ховер-дубликат:

```gdscript
	_attach_row_hover(set_row, func(hv: bool) -> StyleBox:
		return VTKSurface.surface("hover" if hv else "normal", false, false, false, 10, 10, 7, 7))
```

9d. Слева от сеток `_page_columns` (863–868):

```gdscript
	var ps := VTKSurface.panel(true, 6)
	ps.border_width_left = 0
	ps.border_width_top = 0
	ps.border_width_bottom = 0
	ps.shadow_color = Color(0, 0, 0, 0)
	panel.add_theme_stylebox_override("panel", ps)
```

9e. Главная панель `_build_ui` (401–409):

```gdscript
	var panel_style := VTKSurface.panel(false, 0)
	panel_style.shadow_color = Color(0, 0, 0, 0.5)
	panel_style.shadow_size = 12
	panel_style.shadow_offset = Vector2(0, 6)
	_panel.add_theme_stylebox_override("panel", panel_style)
```

- [ ] **Step 10: скроллбары и тултипы — тема на `_panel`**

В `_build_ui` сразу после `_ui_nodes.append(_panel)` добавить:

```gdscript
	var ui_theme := Theme.new()
	ui_theme.set_stylebox("scroll", "VScrollBar", VTKSurface.panel(true, 4))
	ui_theme.set_stylebox("grabber", "VScrollBar", VTKSurface.surface("normal", true, false, false, 2, 2, 2, 2))
	ui_theme.set_stylebox("grabber_highlight", "VScrollBar", VTKSurface.surface("hover", true, false, false, 2, 2, 2, 2))
	ui_theme.set_stylebox("grabber_pressed", "VScrollBar", VTKSurface.surface("pressed", true, false, false, 2, 2, 2, 2))
	ui_theme.set_stylebox("panel", "TooltipPanel", VTKSurface.panel(false, 12))
	ui_theme.set_font_size("font_size", "TooltipLabel", 10)
	_panel.theme = ui_theme
```

- [ ] **Step 11: кнопки без собственных стилей — `VTKSurface.style_button`**

Добавить вызов после настройки текста у кнопок (акцент/опасность по смыслу):
- кнопки действий шага 1 (1336–1348): `save_btn` → `style_button(save_btn, true)`, `clear_btn` → `style_button(clear_btn)`, `cancel_btn` → `style_button(cancel_btn)`;
- `qk_btn` (2039): `style_button(qk_btn, qk > 0)`;
- на карточке сета (2074–2086): `apply_btn` → `style_button(apply_btn, true)`, `edit_btn` → `style_button(edit_btn)`, `del_btn` → `style_button(del_btn, false, true)`;
- `_make_create_btn` (2093): `style_button(ghost, true)`;
- `_make_att_btn` (2105): `style_button(b, true)`.

Конкретно: `VTKSurface.style_button(X)` — это полная замена четырёх состояний кнопки + фокус; цвет текста кнопки после этого вручную не трогаем (стиль задаёт `INK`/`GOLD`).

- [ ] **Step 12: контрольная точка**

Run:
```
python .check\layout_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```

Проверить `Select-String 'StyleBoxFlat.new('` в VTKUI.gd: остаться должны только `_make_dot` (1602), `_make_step_circle_style` (738), `ToggleSwitch` (1683/1693), `ind_s` (3318/3352). Снапшот: `%TEMP%\opencode\vtk-snap-4.7.1-task6.gd`.

---

### Task 7: Спрайты предметов, ячейки 96×132, шрифты крупнее

Реальные иконки каталога с кропом по непрозрачной области (`Picker.item_art`), ячейки 96×132 с иконо-зоной 84×48 без dest-подписи, сетка и панель под новый размер, шрифты имен +1.

**Files:**
- Modify: `D:\RTVMOD\loadouts\mods\VTK\VTKPicker.gd` (item_art + тест)
- Modify: `D:\RTVMOD\.check\project\tests\test_picker.gd`
- Modify: `D:\RTVMOD\loadouts\mods\VTK\VTKUI.gd`
- Modify: `D:\RTVMOD\.check\layout_check.py`

**Interfaces:**
- Produces: `Picker.item_art(texture) -> Texture2D` — статический кроп-функционал (`AtlasTexture` на оригинале + кэш по `instance_id`).
- Consumes: `VTKSurface.surface` для стилей ячеек.

- [ ] **Step 1: обновить `layout_check.py`**

`PRESENT`:

```python
    "Picker.item_art",
```

`GONE`:

```python
    "Draft.slot_label",
```

- [ ] **Step 2: `VTKPicker.gd` — `Picker.item_art`**

Добавить статический кэш и функцию (рядом с `const CATEGORIES`, до первого `static func`):

```gdscript
static var _art_cache: Dictionary = {}

# Кроп непрозрачной области иконки: AtlasTexture на оригинальном ресурсе, файлы
# игры не трогает. used_rect расширен на 3 пикселя и обрезан по границе текстуры,
# filter_clip убирает размытие по краю. Кэш по instance_id: иконки приходят из
# одного набора ресурсов и переживают перестроение UI.
static func item_art(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	var key := texture.get_instance_id()
	if _art_cache.has(key):
		return _art_cache[key]
	var image := texture.get_image()
	if image == null:
		return texture
	if image.is_compressed():
		image.decompress()
	var used := image.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return texture
	var rect := Rect2(used).grow(3.0).intersection(Rect2(Vector2.ZERO, texture.get_size()))
	if rect.size.x <= 0 or rect.size.y <= 0:
		return texture
	var art := AtlasTexture.new()
	art.atlas = texture
	art.region = rect
	art.filter_clip = true
	_art_cache[key] = art
	return art
```

- [ ] **Step 3: `test_picker.gd` — `t_item_art`**

Добавить функцию и вызвать её в `_init` (рядом с остальными `t_*`):

```gdscript
func t_item_art() -> void:
	var img := Image.create(64, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(10, 12, 40, 20), Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	var art := P.item_art(tex)
	ck(art is AtlasTexture, "item_art режет прозрачные поля")
	var region: Rect2 = (art as AtlasTexture).region
	ck(region.position == Vector2(7, 9), "item_art кроп: позиция +3")
	ck(region.size == Vector2(46, 26), "item_art кроп: размер +3")
	ck(P.item_art(tex) == art, "item_art кэшируется по экземпляру")
	ck(P.item_art(null) == null, "item_art: null-безопасность")
```

- [ ] **Step 4: `VTKUI.gd` — геометрия окна** (`_build_ui`)

- 399: `_panel.size = Vector2(740, 826)` → `Vector2(800, 880)`
- 417: `rail.size = Vector2(732, 30)` → `Vector2(792, 30)`
- 502: `_scroll.size = Vector2(732, 712)` → `Vector2(792, 800)`
- 847: `var cell := 80.0` → `var cell := 96.0` (`_make_grid_columns`)

- [ ] **Step 5: `_make_item_cell` — полноразмерная плитка**

Заменить блок строчек 2150–2220 (от `func` до конца dest-блока, перед `var path_now`) на:

```gdscript
func _make_item_cell(item, forced_slot = null) -> Control:
	var cell = Panel.new()
	cell.custom_minimum_size = Vector2(96, 132)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.mouse_filter = Control.MOUSE_FILTER_STOP

	var normal_style := VTKSurface.surface("normal")
	var hover_style := VTKSurface.surface("hover")
	var in_set_style := VTKSurface.surface("normal", true, false, true)

	cell.add_theme_stylebox_override("panel", normal_style)
	_attach_motion(cell)

	var center = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(center)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(vbox)

	var tex = TextureRect.new()
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.custom_minimum_size = Vector2(84, 48)
	var icon := _item_icon(item)
	if icon:
		tex.texture = Picker.item_art(icon)
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(tex)

	var name_lbl = Label.new()
	name_lbl.text = item.name
	name_lbl.add_theme_font_size_override("font_size", 9)
	name_lbl.add_theme_color_override("font_color", Color("#aaa"))
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_lbl.max_lines_visible = 2
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)
```

Остальное без изменений: блок `var path_now` / `already` / `cnt` / `in_set_style` (2236), `tooltip_text`, `gui_input`, hover-обработчики (2248–2254). Имена `normal_style`, `hover_style`, `in_set_style` сохранить — на них ссылаются обработчики.

- [ ] **Step 6: `_make_att_cell` — полноразмерная плитка**

Заменить строчки 2474–2538 (от `var cell` до конца label) на:

```gdscript
	var cell := Panel.new()
	cell.custom_minimum_size = Vector2(96, 132)
	cell.mouse_filter = Control.MOUSE_FILTER_STOP

	# Принадлежность, а не "первый в списке": дуло, коллиматор и лазер стоят
	# одновременно, и золотым должен быть каждый из них.
	var on := _draft != null and _draft.has_attachment(owner_path, str(att_res.resource_path))

	var normal := VTKSurface.surface("normal")
	var hover := VTKSurface.surface("hover")
	var picked := VTKSurface.surface("normal", true, false, true)

	cell.add_theme_stylebox_override("panel", picked if on else normal)
	_attach_motion(cell)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(center)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(vbox)

	var tex = TextureRect.new()
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.custom_minimum_size = Vector2(84, 48)
	var icon := _item_icon(att_res)
	if icon:
		tex.texture = Picker.item_art(icon)
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(tex)

	var nm = Label.new()
	nm.text = str(att_res.name)
	nm.add_theme_font_size_override("font_size", 9)
	nm.add_theme_color_override("font_color", _gold if on else Color("#aaa"))
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD
	nm.max_lines_visible = 2
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(nm)
```

Остальное без изменений: `tooltip_text`, `gui_input`, hover-обработчики (2550–2554), выход из функции.

- [ ] **Step 7: шрифты крупнее**

- 1057: `nm.add_theme_font_size_override("font_size", 11)` в `_make_gear_chip` → `12` (имя чипа в снаряжении).
- 1197: `9 if level else 10` в `_make_facet_row` → `10 if level else 11` (подпись фасета).
- 1205: там же, счётчик: `9 if level else 10` → `10 if level else 11`.

- [ ] **Step 8: контрольная точка**

Run:
```
python .check\layout_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```

Проверить головы: `Picker.item_art`, `Draft.slot_label` в GONE, `VTKSurface.surface` в PRESENT. Снапшот: `%TEMP%\opencode\vtk-snap-4.7.1-task7.gd`.

---

### Task 8: Версия, стенды, AGENTS.md, сборка

Финальный проход: поднять версию до 4.7.1, прогнать все стенды, обновить `AGENTS.md`, собрать `Loadouts.vmz` и скопировать в папку модов игры.

**Files:**
- Modify: `D:\RTVMOD\loadouts\mod.txt` — `version="4.7.0"` → `version="4.7.1"`
- Modify: `D:\RTVMOD\AGENTS.md`
- Produce: `D:\RTVMOD\Loadouts.vmz` (артефакт) и копия в папку модов игры

- [ ] **Step 1: ключи локализации**

Прогнать `python .check\keycheck.py` — проверка, что удалённые RU-строки (Tasks 1–2) не остались в словаре, а новых строк в коде без перевода нет.

- [ ] **Step 2: полный прогон стендов**

```
python .check\layout_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```

Проверить отступы (только табы) во всех `.gd`, включая новый `VTKSurface.gd`: нет смешанных пробелов, скобки сбалансированы. Сверить счётчик прелоадов (добавился `VTKSurface`) с `Select-String -SimpleMatch 'preload('` по `loadouts\mods\VTK\*.gd`.

- [ ] **Step 3: обновить `AGENTS.md`**

1. Структура: в строке про `loadouts/mods/VTK/` «семь скриптов» → «восемь»; добавить в перечисление `VTKSurface.gd` (слоёные SVG-поверхности, статический `RefCounted`, прелоадится `const` из `VTKUI.gd`).
2. Таблица привязок: добавить строку `const VTKSurface := preload("res://mods/VTK/VTKSurface.gd")` → `VTKUI.gd`; счётчик прелоадов ×15 → ×16.
3. Раздел «Проверка»: добавить пункт про `VTKSurface` (не `load()`, только SVG→`ImageTexture`—`svg_texture` грузит из строки, не из файла) и `Picker.item_art` (кроп `AtlasTexture` на оригинале, кэш по `instance_id`, headless-тест — не нарушает правило «VTKPicker — чистая логика»).

- [ ] **Step 4: версия регламенту**

Версия `4.7.1` — фикс-релиз над `4.7.0` (внешний вид: удалён хром статус-строки и MCM-плашки, слоты и чипы — без иконок, поверхности из SVG, кроп спрайтов). Формат записей сетов и ключи конфига не менялись — мажор/минор не нужны.

- [ ] **Step 5: сборка и доставка**

```
powershell -ExecutionPolicy Bypass -File pack.ps1
```

Свериться с печатью версии в выводе (`mod.txt`), затем скопировать:

```
Copy-Item -LiteralPath "D:\RTVMOD\Loadouts.vmz" -Destination "D:\SteamLibrary\steamapps\common\Road to Vostok\mods\Loadouts.vmz" -Force
```

- [ ] **Step 6: ручная проверка в игре** (не автоматизируется)

Запустить RTV с модом. Проверить: три вкладки, вкладки/сегменты языка в золотой обводке при активе, слои строк слотов и фасетов, пустой слот — матово-тёмная строка без пунктира, чипы фильтров, карточки сетов, телепорт, скроллбар в золоте, тултипы на тёмной подложке, кроп иконок в каталоге (карточка 96×132, без обрезки и размытия), печать `v4.7.1` в рейле.

---

## Apex: определение готовности

Версия 4.7.1 готова, когда:

1. `check.ps1` зелёный: нет `SCRIPT ERROR` / `Parse Error` / `Invalid call` / `Failed to load script`, есть `tests passed`, код выхода 0 (включая `t_item_art`).
2. `layout_check.py` зелёный: GONE не содержит `_chrome_stat`, `_set_stat`, `_rail_tab`, `_clock_label`, `_clock_text`, `_stat_msg`, `_make_dot_texture`, `mcm_ref`, `mcm_box`, `box_icon`, `hintline`, `DashedBorder`, `_make_dark_style`, `Draft.slot_label`; PRESENT содержит `_page_columns`, `_make_slot_row`, `_make_facet_row`, `_done_equip_col`, `VTKSurface.surface`, `VTKSurface.panel`, `VTKSurface.style_button`, `Picker.item_art`.
3. `keycheck.py` молчит.
4. `mod.txt` `version="4.7.1"`, `Loadouts.vmz` собран и лежит в папке модов игры.
5. Макет `picker-ideal-layout.html` соответствует: рейл без бренда/часов/статуса, заголовок «VOSTOK TOOLKIT v4.7.1» слева, точки вместо иконок в слотах/чипах, каталог — имена, круглые кнопки шагов золотые при активе.

## Открытые вопросы (резолвятся в момент реализации)

- Точный оттенок `VTKSurface.surface` для «hover» — сверять на живой игре с макетом; правка — только палитра в `VTKSurface.gd`, интерфейс не меняется.
- Кнопки карточки сета (`Apply/Edit/✕`) и «+ Create loadout» получают SVG-стиль `style_button`: если в игре это визуально тяжело, уменьшить margins, не переделывая сами кнопки.