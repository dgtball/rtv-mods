# Composite оружия с обвесами — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Клетки оружия в экипировке/превью/«Готово» рисуют сцену `tetris` с навешанными обвесами, а слоты с неинцептированным вложением (риг+плита, NVG, Player) получают голый глиф ⚙; убраны золотая точка, ✕ уведён вправо вверх, кнопка хоткея выровнена.

**Architecture:** Чистая математика выбора пакета масштаб/смещение живёт в `VTKPicker.gd` (headless-тестируема). Иконка-шестерёнка строится в `VTKSurface.gd` из SVG. Рендер composite и вёрстка клетки — в `VTKUI.gd::_make_equip_cell` (путь один для экипировки, превью и «Готово»).

**Tech Stack:** GDScript / Godot 4.6.3, modloader-мод `VTK`, headless-стенд `.check` (`check.ps1` + `layout_check.py`).

## Global Constraints

- Отступы в `.gd` — **только табы**.
- Версия мода живёт только в `loadouts/mod.txt` (поле `version`) + `loadouts/mods/VTK/version.txt`; цель — `4.17.0` (minor: новая функциональность).
- Коммитим **только** трекаемые пути: `loadouts/**`, `README.md`, `CHANGELOG.md`. Стенд `.check/` и `docs/` под `.gitignore` — их правки не коммитятся.
- Гейт после каждой правки кода:
  - `py -3 .check\layout_check.py` → `$LASTEXITCODE` = 0.
  - `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1 -Godot "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe"` → exit 0, есть `Parse check passed: 16 scripts` и `Tests passed: <N> file(s)`, нет `SCRIPT ERROR`/`Parse Error`/`Invalid call`/`Failed to load script`.
- Headless-тесты — `extends SceneTree`, `_init()`, хелпер `ck()`, печать `<X> tests passed`, `quit(0/1)`. Файл теста кладётся в `.check/project/tests/`, регистрируется в `$tests` в `.check/check.ps1`.
- Ключ/значения полей ресурса оружия (проверено): `tetris` (PackedScene), `size` (Vector2 в сетке), `magazineScale/Offset` (float), `opticScale/Offset` (float), `suppressorScale/Offset` (float), `magazineOpticScale/Offset` (float), `magazineSuppressorScale/Offset` (Vector2), `opticSuppressorScale/Offset` (Vector2), `fullyModdedScale/Offset` (Vector2). Базовый scale = `0.5`.
- Класс обвеса по `subtype`: `Optic`→`optic`, `Muzzle`→`muzzle`, `Magazine`→`magazine`.
- Композитные дети бывают **только** у `type == "Weapon"`.

---

## File Structure

| Файл | Ответственность | Изменение |
|---|---|---|
| `loadouts/mods/VTK/VTKPicker.gd` | чистая логика: классификация обвеса, выбор пакета | +2 static |
| `loadouts/mods/VTK/VTKSurface.gd` | генерация SVG-иконок | +1 static |
| `loadouts/mods/VTK/VTKUI.gd` | рендер клетки экипировки, страница «Готово» | правка `_make_equip_cell`, `_build_page_done`; +хелперы |
| `.check/project/tests/test_composite.gd` | headless-тесты чистой логики | новый |
| `.check/check.ps1` | список тестов | +1 файл |
| `loadouts/mod.txt`, `loadouts/mods/VTK/version.txt`, `README.md`, `CHANGELOG.md` | версия | 4.17.0 |

---

### Task 1: Чистая логика — классификация обвеса и выбор пакета

**Files:**
- Modify: `loadouts/mods/VTK/VTKPicker.gd`
- Test: `.check/project/tests/test_composite.gd` (новый), `.check/check.ps1` (регистрация)

**Interfaces:**
- Produces:
  - `VTKPicker.attachment_class(subtype) -> String` → `"optic" | "muzzle" | "magazine" | ""`
  - `VTKPicker.composite_pack(res, classes: Array) -> Dictionary` → `{"scale": float, "offset": Vector2}`, offset — в **неповёрнутом** 64-пространстве, знаки как в ванильном `Item.UpdateSprite`.

- [ ] **Step 1: Написать падающий тест**

Создать `.check/project/tests/test_composite.gd`:

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

# Поля AKM (значения сняты headless с res://Items/Weapons/AKM/AKM.tres).
func _akm() -> Dictionary:
	return {
		"magazineScale": 0.5, "magazineOffset": 5.0,
		"opticScale": 0.5, "opticOffset": -5.0,
		"suppressorScale": 0.45, "suppressorOffset": -20.0,
		"magazineOpticScale": 0.5, "magazineOpticOffset": 0.0,
		"magazineSuppressorScale": 0.45, "magazineSuppressorOffset": Vector2(-20.0, 5.0),
		"opticSuppressorScale": 0.45, "opticSuppressorOffset": Vector2(-20.0, -5.0),
		"fullyModdedScale": 0.45, "fullyModdedOffset": Vector2(-20.0, 0.0),
	}

func _init() -> void:
	t_class()
	t_pack()
	print("")
	if fails == 0:
		print("Composite tests passed")
		quit(0)
	else:
		print("Composite tests failed: ", fails)
		quit(1)

func t_class() -> void:
	ck(P.attachment_class("Optic") == "optic", "Optic -> optic")
	ck(P.attachment_class("Muzzle") == "muzzle", "Muzzle -> muzzle")
	ck(P.attachment_class("Magazine") == "magazine", "Magazine -> magazine")
	ck(P.attachment_class("Stock") == "", "Stock -> пусто")
	ck(P.attachment_class(null) == "", "null -> пусто")

func t_pack() -> void:
	var a := _akm()
	ck(P.composite_pack(a, ["magazine"]) == {"scale": 0.5, "offset": Vector2(0, -5)},
		"только магазин -> magazineScale/Offset")
	ck(P.composite_pack(a, ["optic"]) == {"scale": 0.5, "offset": Vector2(0, 5)},
		"только прицел -> opticScale/Offset")
	ck(P.composite_pack(a, ["muzzle"]) == {"scale": 0.45, "offset": Vector2(-20, 0)},
		"только дуло -> suppressorScale/Offset")
	ck(P.composite_pack(a, ["magazine", "optic"]) == {"scale": 0.5, "offset": Vector2(0, 0)},
		"маг+прицел -> magazineOptic*")
	ck(P.composite_pack(a, ["magazine", "muzzle"]) == {"scale": 0.45, "offset": Vector2(-20, -5)},
		"маг+дуло -> magazineSuppressor*")
	ck(P.composite_pack(a, ["optic", "muzzle"]) == {"scale": 0.45, "offset": Vector2(-20, 5)},
		"прицел+дуло -> opticSuppressor*")
	ck(P.composite_pack(a, ["magazine", "optic", "muzzle"]) == {"scale": 0.45, "offset": Vector2(-20, 0)},
		"все три -> fullyModded*")
	ck(P.composite_pack(a, []) == {"scale": 0.5, "offset": Vector2.ZERO},
		"без обвесов -> база 0.5/ZERO")
	ck(P.composite_pack({}, ["optic"]) == {"scale": 0.5, "offset": Vector2.ZERO},
		"пустой ресурс не падает, отдаёт базу")
```

- [ ] **Step 2: Зарегистрировать тест и прогнать — убедиться, что падает**

В `.check/check.ps1` (строка 80) добавить `"res://tests/test_composite.gd"` в `$tests`.

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1 -Godot "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe"`
Expected: FAIL — `Parse Error`/`Nonexistent function 'attachment_class'`.

- [ ] **Step 3: Реализовать минимально**

В конец `loadouts/mods/VTK/VTKPicker.gd`:

```gdscript
# Класс обвеса по данным игры. Vanilla Item.UpdateAttachments делит обвесы на
# Optic/Muzzle/Magazine, и только эти классы участвуют в выборе позы оружия.
static func attachment_class(subtype) -> String:
	match str(subtype):
		"Optic":
			return "optic"
		"Muzzle":
			return "muzzle"
		"Magazine":
			return "magazine"
		_:
			return ""

# Пакеты масштаб+смещение оружия под навешанные классы (Item.UpdateSprite).
# offset отдаётся в неповёрнутом 64-пространстве: одиночные смещения в данных
# скаляр и в ванили едут по одной оси, парные - Vector2; знак уже приведён к
# "position += offset", поворот применяет вызывающий. Ключ - классы через "+".
const COMPOSITE_PACKS := {
	"magazine": {"s": "magazineScale", "o": "magazineOffset", "k": "y", "sd": 0.5},
	"optic": {"s": "opticScale", "o": "opticOffset", "k": "y", "sd": 0.5},
	"muzzle": {"s": "suppressorScale", "o": "suppressorOffset", "k": "x", "sd": 0.45},
	"magazine+optic": {"s": "magazineOpticScale", "o": "magazineOpticOffset", "k": "y", "sd": 0.5},
	"magazine+muzzle": {"s": "magazineSuppressorScale", "o": "magazineSuppressorOffset", "k": "vec", "sd": 0.45},
	"optic+muzzle": {"s": "opticSuppressorScale", "o": "opticSuppressorOffset", "k": "vec", "sd": 0.45},
	"magazine+optic+muzzle": {"s": "fullyModdedScale", "o": "fullyModdedOffset", "k": "vec", "sd": 0.45},
}

static func composite_pack(res, classes: Array) -> Dictionary:
	var present: Array = []
	for c in ["magazine", "optic", "muzzle"]:
		if classes.has(c):
			present.append(c)
	if present.is_empty():
		return {"scale": 0.5, "offset": Vector2.ZERO}
	var key := str(present[0])
	for i in range(1, present.size()):
		key += "+" + str(present[i])
	if not COMPOSITE_PACKS.has(key):
		return {"scale": 0.5, "offset": Vector2.ZERO}
	var p: Dictionary = COMPOSITE_PACKS[key]
	var sc = res.get(p["s"])
	if sc == null:
		sc = float(p["sd"])
	var o = res.get(p["o"])
	var off := Vector2.ZERO
	if p["k"] == "vec":
		if o is Vector2:
			off = Vector2(o.x, -o.y)
	elif p["k"] == "y":
		off = Vector2(0.0, -(float(o) if o != null else 0.0))
	else:
		off = Vector2(float(o) if o != null else 0.0, 0.0)
	return {"scale": float(sc), "offset": off}
```

Note: `res` может быть `Dictionary` (тест) или `Resource` (боевой); `.get(key)` без default работает у обоих.

- [ ] **Step 4: Прогнать — убедиться, что проходит**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1 -Godot "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe"`
Expected: PASS — `Composite tests passed`, `Tests passed: 9 file(s)`, код 0.

- [ ] **Step 5: Коммит**

```bash
git add loadouts/mods/VTK/VTKPicker.gd
git commit -m "feat: composite attachment pack selection (pure logic)"
```

---

### Task 2: SVG-иконка шестерёнки

**Files:**
- Modify: `loadouts/mods/VTK/VTKSurface.gd`

**Interfaces:**
- Produces: `VTKSurface.gear_icon(size: int, color: Color) -> Texture2D` — Texture2D размера `size×size` (может быть `null`, если SVG не собрался).

- [ ] **Step 1: Реализовать**

В `loadouts/mods/VTK/VTKSurface.gd` добавить (рядом с `svg_texture`):

```gdscript
# Голая шестерёнка золотым: признак, что в слоте есть вложение. Своя SVG, а не
# символ шрифта игры: U+2699 в шрифте может отсутствовать, а мод и так рисует
# иконки из строк. Цвет подставляется в fill-rule evenodd-путь (отверстие).
static func gear_icon(size: int, color: Color) -> Texture2D:
	var hex := color.to_html(false)
	# Скобки обязательны: в GDScript % связывает сильнее +, и без них формат
	# применился бы только ко второму слагаемому (String formatting error,
	# интерполяция не срабатывает).
	var svg := ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 24 24">' \
		+ '<path fill="#%s" fill-rule="evenodd" d="M19.14 12.94a7.5 7.5 0 0 0 0-1.88l2.03-1.58a.49.49 0 0 0 .12-.61l-1.92-3.32a.49.49 0 0 0-.59-.22l-2.39.96a7.4 7.4 0 0 0-1.62-.94l-.36-2.54a.48.48 0 0 0-.48-.41h-3.84a.48.48 0 0 0-.48.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96a.48.48 0 0 0-.59.22L2.74 8.87a.49.49 0 0 0 .12.61l2.03 1.58a7.5 7.5 0 0 0 0 1.88l-2.03 1.58a.49.49 0 0 0-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.48-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32a.49.49 0 0 0-.12-.61l-2.01-1.58zM12 15.6a3.6 3.6 0 1 1 0-7.2 3.6 3.6 0 0 1 0 7.2z"/></svg>') \
		% [size, size, hex]
	return svg_texture(svg)
```

- [ ] **Step 2: Проверить сборку файла**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1 -Godot "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe"`
Expected: PASS — `Parse check passed: 16 scripts`, код 0.

- [ ] **Step 3: Зафиксировать визуальную проверку**

Иконку нельзя оценить headless. Быстрый предпросмотр: временно, локально (не коммитить), в любом уже рисуемом месте вызвать `VTKSurface.gear_icon(13, VTKSurface.GOLD)` — либо пропустить и проверить на общем прогоне в Task 3.

- [ ] **Step 4: Коммит**

```bash
git add loadouts/mods/VTK/VTKSurface.gd
git commit -m "feat: gear glyph from SVG for attachment presence"
```

---

### Task 3: Composite в клетке экипировки + глиф + правки ✕/точки

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd` (`_make_equip_cell` ~1657-1749, `_make_dot` use, +хелперы)

**Interfaces:**
- Consumes: `Picker.composite_pack`, `Picker.attachment_class` (Task 1); `VTKSurface.gear_icon` (Task 2); `_item_info` (существует, возвращает `{"resource":...}`); `_rotates_icon` (существует).
- Produces (внутренние): `_has_attachments(src) -> bool`, `_composite_meta(src) -> Dictionary` (`{"files": Array, "classes": Array}`), `_render_composite(box, res, src, w, h, rotated) -> bool`, `_glyph_size(w, h) -> int`, `_x_size(w, h) -> Dictionary` (`{"box": int, "font": int}`).

- [ ] **Step 1: Добавить хелперы**

Рядом с `_make_equip_cell` в `loadouts/mods/VTK/VTKUI.gd`:

```gdscript
# Есть ли в слоте вложения (плита рига, обвесы оружия). Пустой ключ и не-массив
# считаются отсутствием.
func _has_attachments(src: Dictionary) -> bool:
	var a = src.get("attachments")
	return typeof(a) == TYPE_ARRAY and (a as Array).size() > 0

# Имена `file` навешанных обвесов и их классы: по file прячем/показываем детей
# сцены tetris, по классам Picker.composite_pack выбирает позу.
func _composite_meta(src: Dictionary) -> Dictionary:
	var files: Array = []
	var classes: Array = []
	var ats = src.get("attachments")
	if typeof(ats) == TYPE_ARRAY:
		for p in ats:
			var r = _item_info(str(p)).get("resource")
			if r == null:
				continue
			files.append(str(r.get("file")))
			var cls := Picker.attachment_class(r.get("subtype"))
			if cls != "" and not classes.has(cls):
				classes.append(cls)
	return {"files": files, "classes": classes}

# Оружие рисуется своей сценой tetris: база + спрайты обвесов, как в экране
# персонажа игры. Прячем всех детей, показываем навешанные, поза - из пакета.
# Возвращает false, если композита нет (не оружие/нет tetris) - тогда рисуется
# прежняя иконка. Смещение пакета в 64-пространстве, при повороте разворачиваем
# его тем же -90°, что и узел, чтобы оси совпали с ванильными.
func _render_composite(box: Panel, res, src: Dictionary, w: int, h: int, rotated: bool) -> bool:
	var scene = res.get("tetris")
	if scene == null:
		return false
	var node: Node2D = scene.instantiate()
	var meta := _composite_meta(src)
	for ch in node.get_children():
		ch.visible = meta["files"].has(str(ch.name))
	var pack := Picker.composite_pack(res, meta["classes"])
	var base = res.get("size")
	if not (base is Vector2) or base.x <= 0.0 or base.y <= 0.0:
		base = Vector2(1, 1)
	var cell := Vector2(w * EQ_CELL + (w - 1) * EQ_GAP, h * EQ_CELL + (h - 1) * EQ_GAP)
	var pad := 8.0
	var bx := float(base.x) * 64.0
	var by := float(base.y) * 64.0
	if rotated:
		var t := bx
		bx = by
		by = t
	var fit := minf((cell.x - pad) / bx, (cell.y - pad) / by)
	# natural = size*128 (панель size*64 вдвое плотнее), поэтому scale = fit*pack.scale.
	# Тут раньше стоял лишний /0.5: композит рендерился вдвое крупнее клетки.
	var sc := fit * float(pack["scale"])
	node.scale = Vector2(sc, sc)
	node.rotation_degrees = -90.0 if rotated else 0.0
	var off: Vector2 = pack["offset"]
	if rotated:
		off = Vector2(off.y, -off.x)
	node.position = cell * 0.5 + off * fit
	box.add_child(node)
	return true

# Размер глифа присутствия по клетке: max(w,h) >= 6 -> L, 4..5 -> M, 2 -> S, 1 -> XS.
# Реально встречаются S (риг 2×2) и XS (NVG/Player 1×1); L/M - фолбэк, если
# композит оружия почему-то не сработал.
func _glyph_size(w: int, h: int) -> int:
	var m := maxi(w, h)
	if m >= 6:
		return 16
	if m >= 4:
		return 14
	if m == 2:
		return 13
	return 11

# Размер крестика и шрифт по клетке: L 26/14, M/S 22/12, XS 18/10.
func _x_size(w: int, h: int) -> Dictionary:
	var m := maxi(w, h)
	if m >= 6:
		return {"box": 26, "font": 14}
	if m == 1:
		return {"box": 18, "font": 10}
	return {"box": 22, "font": 12}
```

- [ ] **Step 2: Переписать блок отрисовки `_make_equip_cell`**

Заменить фрагмент от `var tex := _item_icon(...)` до конца функции (строки ~1679-1749) на:

```gdscript
	var res := _cell_resource(src) if occupied else null
	var rotated := occupied and _rotates_icon(slot, src)
	var composited := false
	if occupied and res != null and res.get("tetris") != null and str(res.get("type")) == "Weapon":
		composited = _render_composite(box, res, src, w, h, rotated)

	if not composited:
		var tex := _item_icon(res) if occupied else null
		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(center)
		if tex != null:
			var icon := TextureRect.new()
			icon.texture = Picker.item_art(tex, rotated)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			var sq := maxi(16, mini(w * EQ_CELL, h * EQ_CELL) - 16)
			icon.custom_minimum_size = Vector2(sq, sq)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			center.add_child(icon)
		else:
			var lb := Label.new()
			lb.text = Loc.txt(slot)
			lb.add_theme_font_size_override("font_size", 9)
			lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lb.add_theme_color_override("font_color", VTKSurface.INK if occupied else VTKSurface.BROWN)
			lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			center.add_child(lb)

	# Признак вложения там, где композита нет (риг с плитой, NVG/Player). Оружию
	# не нужен: обвесы видны на модели.
	if not composited and _has_attachments(src):
		var gsz := _glyph_size(w, h)
		var gear := TextureRect.new()
		gear.texture = VTKSurface.gear_icon(gsz, _gold)
		gear.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		gear.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		gear.custom_minimum_size = Vector2(gsz, gsz)
		gear.size = Vector2(gsz, gsz)
		gear.position = Vector2(5, 4)
		gear.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(gear)

	if interactive and occupied:
		var xs := _x_size(w, h)
		var drop := _make_mini_btn("✕", Vector2(xs["box"], xs["box"]), xs["font"])
		drop.tooltip_text = Loc.txt("Remove")
		drop.add_theme_color_override("font_color", Color("#e05a4a"))
		drop.pressed.connect(func(): _remove_slot(slot))
		box.add_child(drop)
		drop.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		drop.offset_left = -(int(xs["box"]) + 4)
		drop.offset_top = 4
		drop.offset_right = -4
		drop.offset_bottom = int(xs["box"]) + 4
	return box
```

Проверить: прежний блок `_make_dot` (строки ~1702-1708) удалён целиком (саму функцию `_make_dot` не трогать — она нужна на полке, `VTKUI.gd:1397`).

- [ ] **Step 3: Прогнать стенды**

Run: `py -3 .check\layout_check.py` → exit 0.
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1 -Godot "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe"`
Expected: PASS — `Parse check passed: 16 scripts`, `Tests passed: 9 file(s)`, код 0.

- [ ] **Step 4: Ручная проверка в игре**

Собрать и залить (Task 5 либо разово `pack.ps1` + копия `.vmz`), затем:
- Primary/Secondary: 0 / 1 / 3 обвеса; пистолет (без поворота) vs винтовка (поворот −90°); вылет дула обрезается клеткой, арт не уезжает за центр.
- Превью сета и страница «Готово» показывают то же; ✕ там нет.
- Rig `K19` + плита → голая ⚙ слева сверху; Rig без совместимой плиты → без глифа; NVG 1×1 → ⚙ меньше; Helmet → без глифа.
- ✕ в правом верхнем углу, крупнее прежнего; золотой точки занятости нигде нет.

- [ ] **Step 5: Коммит**

```bash
git add loadouts/mods/VTK/VTKUI.gd
git commit -m "feat: render weapon attachments composite in equip cells"
```

---

### Task 4: Выровнять кнопку хоткея на странице «Готово»

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd` (`_build_page_done`, строка 1538)

- [ ] **Step 1: Убрать оверрайд**

Удалить строку:

```gdscript
	_bind_btn.add_theme_font_size_override("font_size", 10)
```

(остаётся `_apply_qk_btn(_bind_btn, _display_qk())`, который ставит шрифт через `VTKSurface.style_button`).

- [ ] **Step 2: Прогнать стенды**

Run: `py -3 .check\layout_check.py` → exit 0.
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1 -Godot "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe"` → exit 0.

- [ ] **Step 3: Ручная проверка**

На странице «Готово» кнопка «Assign key» (и после назначения клавиши) совпадает по высоте с «Save loadout»/«Cancel».

- [ ] **Step 4: Коммит**

```bash
git add loadouts/mods/VTK/VTKUI.gd
git commit -m "fix: match Assign key button height to siblings"
```

---

### Task 5: Релиз 4.17.0

**Files:**
- Modify: `loadouts/mod.txt`, `loadouts/mods/VTK/version.txt`, `README.md`, `CHANGELOG.md`

- [ ] **Step 1: Поднять версию**

`loadouts/mod.txt`: `version` → `4.17.0`.
`loadouts/mods/VTK/version.txt`: `4.17.0`.
`README.md`: строку `**Version:** 4.16.5` → `**Version:** 4.17.0`.

- [ ] **Step 2: Запись в CHANGELOG**

В начало `CHANGELOG.md` (под заголовком) добавить:

```markdown
## [4.17.0] - 2026-10-14

### Added
- Weapons in a loadout now show their installed attachments on the preview art.
- Equipment slots that hold a nested item (armor plate, NVG) show a small gear mark.

### Changed
- The remove button on equipment slots moved to the top-right corner and is easier to hit.
```

- [ ] **Step 3: Сборка и проверка версии**

Run: `powershell -ExecutionPolicy Bypass -File pack.ps1`
Expected: печатает `4.17.0`, создаёт `Loadouts.vmz` без ошибок.

- [ ] **Step 4: Деплой и сверка**

```powershell
Copy-Item -LiteralPath "D:\RTVMOD\Loadouts.vmz" -Destination "D:\SteamLibrary\steamapps\common\Road to Vostok\mods\Loadouts.vmz" -Force
(Get-FileHash "D:\RTVMOD\Loadouts.vmz").Hash -eq (Get-FileHash "D:\SteamLibrary\steamapps\common\Road to Vostok\mods\Loadouts.vmz").Hash
```
Expected: `True`.

- [ ] **Step 5: Коммит**

```bash
git add loadouts/mod.txt loadouts/mods/VTK/version.txt README.md CHANGELOG.md
git commit -m "release: 4.17.0"
```

---

## Self-Review

- **Покрытие спеки:** композит оружия — Task 1 (пакет) + Task 3 (рендер); глиф присутствия — Task 2 + Task 3; ✕ вправо/крупнее и удаление точки — Task 3; кнопка хоткея — Task 4; версия/CHANGELOG — Task 5. Все разделы спеки покрыты.
- **Плейсхолдеры:** нет.
- **Согласованность типов:** `composite_pack(res, classes) -> {scale,offset}` используется в `_render_composite` именно так; `attachment_class(subtype) -> String` — в `_composite_meta`; `gear_icon(size, color)` — в Task 3. Имена хелперов `_has_attachments`/`_composite_meta`/`_render_composite`/`_glyph_size`/`_x_size` единообразны между Task 3 шагами.
- **Известное ограничение:** `res` в `composite_pack` — `Dictionary` (тест) и `Resource` (боевой); `.get(one_arg)` поддерживают оба.
