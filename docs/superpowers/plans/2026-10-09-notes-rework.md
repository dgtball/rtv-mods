# Notes: иконки предметов + автоочистка сданных — план реализации

Дата: 2026-10-09. Спека: `docs/superpowers/specs/2026-10-09-notes-rework-design.md`.

## Цель

Заменить текстовые списки `Deliver:`/`Receive:` в карточках игровой вкладки Notes на ряды иконок предметов (бейдж `×N`, имя в тултипе) и убирать сданные квесты из Notes — немедленно при сдаче и как страховку при каждом открытии вкладки.

## Архитектура

Новый `VTKNotes.gd` (статический `RefCounted`, как `VTKPicker`/`VTKDraft`) несёт чистые решения (`group_items`, `completed_lists`, `is_completed`, `find_note`, `badge_text`) и построение узлов (`build_icon_row`, `augment_note`) без `load()` и путей внутрь игры. `VTKHooks.gd` оркестрирует: два новых post-хука (`interface-initializenotes-post`, `trader-completetask-post`), доступ к `/root/Loader` и удаление заметок. Ванильные `Task.tscn`/`Task.gd` не трогаем.

## Технологии

GDScript (Godot 4.6.3), RTVModLib (Metro Mod Loader 3.4.2) hooks, headless-стенд `.check` (Godot `--headless`).

## Global Constraints

- Версия: `loadouts/mod.txt` и `loadouts/mods/VTK/version.txt` → **`4.11.0`** (было `4.10.3`).
- Отступы в `.gd` — только табы; файлы в UTF-8; кавычки в строках с `"` — одинарные.
- Коммиты — **только если пользователь об этом явно попросил**; по умолчанию каждый таск заканчивается прогоном стенда, а не `git commit`.
- Стенды после каждого таска: `python .check\layout_check.py` и `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`.
- Godot для проб: бинарь ищется в `tools` (`*_console.exe`), иначе `-Godot "<path>"`.
- Имена предметов не локализуются (берутся как есть).
- Имя хука — строковый литерал (`interface-initializenotes-post`, `trader-completetask-post`): wrap-surface фиксируется сканером литеральных `.hook("...")`.

## Карта файлов

| Файл | Действие | Ответственность |
|---|---|---|
| `loadouts/mods/VTK/VTKNotes.gd` | создать | чистая логика + построение узлов Notes |
| `.check/project/tests/test_notes.gd` | создать | headless-тесты `VTKNotes` |
| `.check/check.ps1` | изменить | добавить `test_notes.gd` в `$tests` |
| `loadouts/mods/VTK/VTKHooks.gd` | изменить | preload `VTKNotes`, 2 хука, 2 колбэка |
| `.check/project/tests/test_hooks.gd` | изменить | тест немедленной очистки заметки |
| `loadouts/mod.txt` | изменить | версия `4.11.0` |
| `loadouts/mods/VTK/version.txt` | изменить | версия `4.11.0` |
| `README.md` | изменить | версия `4.11.0` |
| `AGENTS.md` | изменить | упомянуть `VTKNotes.gd` |

---

## Task 1: Чистая логика `VTKNotes.gd` (TDD)

**Файлы:**
- Создать: `loadouts/mods/VTK/VTKNotes.gd`
- Создать: `.check/project/tests/test_notes.gd`
- Изменить: `.check/check.ps1:80`

**Interfaces:**
- Produces:
  - `static func group_items(items) -> Array` — элементы `[{"item","count"}]`, порядок первого появления
  - `static func completed_lists(traders) -> Dictionary` — `{trader_lower: {task_name: true}}`
  - `static func is_completed(task_data, completed) -> bool`
  - `static func find_note(notes, task_data) -> Variant`
  - `static func badge_text(count: int) -> String`

- [ ] **Step 1: Написать падающий тест**

Создать `.check/project/tests/test_notes.gd`:

```gdscript
extends SceneTree

const N = preload("res://mods/VTK/VTKNotes.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _init() -> void:
	t_group_items()
	t_group_items_fallback()
	t_completed_lists()
	t_is_completed()
	t_find_note()
	t_badge_text()
	print("")
	if fails == 0:
		print("Notes tests passed")
		quit(0)
	else:
		print("Notes tests failed: ", fails)
		quit(1)

func t_group_items() -> void:
	var a := {"resource_path": "res://A", "name": "Bandage"}
	var b := {"resource_path": "res://B", "name": "Saline"}
	var got := N.group_items([a, b, a, a, b])
	ck(got.size() == 2, "group_items: две группы из пяти предметов")
	if got.size() == 2:
		ck(got[0]["item"]["name"] == "Bandage" and got[0]["count"] == 3, "первый по появлению, count=3")
		ck(got[1]["item"]["name"] == "Saline" and got[1]["count"] == 2, "второй, count=2")
	ck(N.group_items([]).is_empty(), "group_items: пустой вход")
	ck(N.group_items(null).is_empty(), "group_items: null")

func t_group_items_fallback() -> void:
	# Без resource_path группируем по name.
	var x := {"resource_path": "", "name": "Rags"}
	var y := {"resource_path": "", "name": "Rags"}
	var got := N.group_items([x, y])
	ck(got.size() == 1 and got[0]["count"] == 2, "group_items: fallback на name")

func t_completed_lists() -> void:
	var traders := {"doctor": ["A", "B"], "generalist": ["C"]}
	var got := N.completed_lists(traders)
	ck(got.has("doctor") and got["doctor"].has("A"), "completed_lists: doctor")
	ck(got.has("generalist") and got["generalist"].has("C"), "completed_lists: generalist")
	ck(N.completed_lists(null).is_empty(), "completed_lists: null -> пусто")

func t_is_completed() -> void:
	var completed := N.completed_lists({"doctor": ["A"]})
	ck(N.is_completed({"trader": "Doctor", "name": "A"}, completed), "is_completed: Doctor/A сдан")
	ck(not N.is_completed({"trader": "Doctor", "name": "Z"}, completed), "is_completed: Doctor/Z не сдан")
	ck(not N.is_completed({"trader": "Hunter", "name": "A"}, completed), "is_completed: чужой торговец")
	ck(not N.is_completed(null, completed), "is_completed: null task")

func t_find_note() -> void:
	var note := {"trader": "Doctor", "name": "A"}
	var other := {"trader": "Doctor", "name": "B"}
	var notes := [other, note]
	var found = N.find_note(notes, {"trader": "Doctor", "name": "A"})
	ck(found != null and found.get("name") == "A", "find_note: находит по name+trader")
	ck(N.find_note(notes, {"trader": "Doctor", "name": "Q"}) == null, "find_note: чужого нет -> null")
	ck(N.find_note([], {"trader": "Doctor", "name": "A"}) == null, "find_note: пустой список")
	ck(N.find_note(null, {"trader": "Doctor", "name": "A"}) == null, "find_note: null")

func t_badge_text() -> void:
	ck(N.badge_text(1) == "", "badge_text: 1 -> пусто")
	ck(N.badge_text(0) == "", "badge_text: 0 -> пусто")
	ck(N.badge_text(2) == "×2", "badge_text: 2 -> ×2")
	ck(N.badge_text(5) == "×5", "badge_text: 5 -> ×5")
```

- [ ] **Step 2: Прописать тест в стенде**

В `.check/check.ps1` строка 80 — добавить `"res://tests/test_notes.gd"` в `$tests`:

```powershell
$tests = @("res://tests/test_draft.gd", "res://tests/test_picker.gd", "res://tests/test_hooks.gd", "res://tests/test_feed.gd", "res://tests/test_spawn.gd", "res://tests/test_notes.gd")
```

- [ ] **Step 3: Запустить тест — должен упасть**

Run:
```
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```
Expected: FAIL — `test_notes.gd` валится (нет `res://mods/VTK/VTKNotes.gd`), в выводе `Notes tests failed` или ошибка загрузки.

- [ ] **Step 4: Создать `VTKNotes.gd` с чистой логикой**

Создать `loadouts/mods/VTK/VTKNotes.gd`:

```gdscript
extends RefCounted
## Логика вкладки Notes: группировка предметов задачи, признак сдачи и
## построение строк иконок. Чистая часть (без узлов) тестируется headless,
## как VTKPicker/VTKDraft: ни load(), ни путей внутрь игры.

static func group_items(items) -> Array:
	var order: Array = []
	if typeof(items) != TYPE_ARRAY:
		return order
	var index := {}
	for it in items:
		if it == null:
			continue
		var key := str(it.get("resource_path"))
		if key == "":
			key = str(it.get("name"))
		if key == "":
			key = str(it)
		if index.has(key):
			var entry: Dictionary = order[index[key]]
			entry["count"] = int(entry["count"]) + 1
		else:
			index[key] = order.size()
			order.append({"item": it, "count": 1})
	return order

static func completed_lists(traders) -> Dictionary:
	var out := {}
	if traders == null:
		return out
	for k in ["generalist", "doctor", "gunsmith", "driver", "hunter", "grandma"]:
		var names = traders.get(k)
		if typeof(names) != TYPE_ARRAY:
			continue
		var set := {}
		for n in names:
			set[str(n)] = true
		out[k] = set
	return out

static func is_completed(task_data, completed) -> bool:
	if task_data == null or typeof(completed) != TYPE_DICTIONARY:
		return false
	var trader := str(task_data.get("trader")).to_lower()
	var sets = completed.get(trader)
	if typeof(sets) != TYPE_DICTIONARY:
		return false
	return sets.has(str(task_data.get("name")))

static func find_note(notes, task_data) -> Variant:
	if typeof(notes) != TYPE_ARRAY or task_data == null:
		return null
	var want_name := str(task_data.get("name"))
	var want_trader := str(task_data.get("trader"))
	for n in notes:
		if n == null:
			continue
		if str(n.get("name")) == want_name and str(n.get("trader")) == want_trader:
			return n
	return null

static func badge_text(count: int) -> String:
	if count > 1:
		return "×" + str(count)
	return ""
```

- [ ] **Step 5: Запустить тест — должен пройти**

Run:
```
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```
Expected: `Notes tests passed`, `Tests passed: 6 file(s)`, `Parse check passed`.

- [ ] **Step 6: Чекпойнт**

Run: `python .check\layout_check.py`
Expected: без ошибок. Коммит не делаем (см. Global Constraints).

---

## Task 2: Построение узлов `VTKNotes.gd` (`build_icon_row`, `augment_note`)

**Файлы:**
- Изменить: `loadouts/mods/VTK/VTKNotes.gd`
- Изменить: `.check/project/tests/test_notes.gd`

**Interfaces:**
- Consumes: `group_items`, `badge_text` (Task 1)
- Produces:
  - `static func build_icon_row(entries: Array) -> Control`
  - `static func augment_note(card) -> void`

- [ ] **Step 1: Дописать падающие тесты**

В `test_notes.gd` добавить вызовы в `_init()` после `t_badge_text()`:

```gdscript
	t_build_icon_row()
```

И добавить функции в конец файла:

```gdscript
func _has_texture(node) -> bool:
	for c in node.get_children():
		if c is TextureRect and c.texture != null:
			return true
	return false

func _badge_of(node) -> String:
	for c in node.get_children():
		if c is Label and c.text.begins_with("×"):
			return c.text
	return ""

func _has_label_text(node, text: String) -> bool:
	for c in node.get_children():
		if c is Label and c.text == text:
			return true
	return false

func t_build_icon_row() -> void:
	var tex := ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	var row := N.build_icon_row([
		{"item": {"name": "Bandage", "icon": tex}, "count": 1},
		{"item": {"name": "Saline", "icon": tex}, "count": 3},
		{"item": {"name": "Rags", "icon": null}, "count": 1},
	])
	ck(row != null and row.get_child_count() == 3, "build_icon_row: клетка на предмет")
	if row.get_child_count() == 3:
		var c0 = row.get_child(0)
		ck(c0.tooltip_text == "Bandage", "тултип = имя предмета")
		ck(_has_texture(c0), "иконка есть -> TextureRect")
		ck(_badge_of(c0) == "", "count 1 -> без бейджа")
		var c1 = row.get_child(1)
		ck(_badge_of(c1) == "×3", "count 3 -> бейдж ×3")
		var c2 = row.get_child(2)
		ck(_has_label_text(c2, "Rags"), "нет иконки -> текстовый фоллбэк")
	row.free()
```

Тест `augment_note` добавим в Step 3 вместе с его реализацией (он требует фиктивной карточки с деревом узлов).

Запустить:
```
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```
Expected: FAIL — `build_icon_row` не определён.

- [ ] **Step 2: Реализовать `build_icon_row`**

Добавить в `VTKNotes.gd`:

```gdscript
const ICON_CELL := 52.0

static func build_icon_row(entries: Array) -> Control:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 4)
	for e in entries:
		row.add_child(_make_cell(e.get("item"), int(e.get("count", 1))))
	return row

static func _make_cell(item, count: int) -> Control:
	var cell := Control.new()
	cell.custom_minimum_size = Vector2(ICON_CELL, ICON_CELL)
	cell.tooltip_text = str(item.get("name"))
	var icon = item.get("icon")
	if icon is Texture2D:
		var tr := TextureRect.new()
		tr.texture = icon
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cell.add_child(tr)
	else:
		var fallback := Label.new()
		fallback.text = str(item.get("name"))
		fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fallback.add_theme_font_size_override("font_size", 9)
		cell.add_child(fallback)
	var badge := badge_text(count)
	if badge != "":
		var lbl := Label.new()
		lbl.text = badge
		lbl.anchor_left = 0.55
		lbl.anchor_top = 0.55
		lbl.anchor_right = 1.0
		lbl.anchor_bottom = 1.0
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		lbl.add_theme_font_size_override("font_size", 11)
		cell.add_child(lbl)
	return cell
```

Запустить:
```
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```
Expected: `Notes tests passed` (включая `build_icon_row`).

- [ ] **Step 3: Реализовать `augment_note` и его тест**

Добавить в `VTKNotes.gd`:

```gdscript
static func augment_note(card) -> void:
	if card == null:
		return
	var task_data = card.get("taskData")
	if task_data == null:
		return
	_apply_section(card.get("inputItems"), card.get("inputGrid"), task_data.get("deliver"))
	_apply_section(card.get("outputItems"), card.get("outputGrid"), task_data.get("receive"))

static func _apply_section(items_label, grid, items) -> void:
	if items_label != null and items_label is Node:
		items_label.visible = false
	if grid != null and grid is Node:
		grid.visible = false
	var entries := group_items(items)
	if entries.is_empty():
		return
	var section = items_label.get_parent() if (items_label != null and items_label is Node) else null
	if section == null:
		return
	var container = section.get_parent()
	if container == null:
		return
	var row := build_icon_row(entries)
	container.add_child(row)
	container.move_child(row, section.get_index() + 1)
```

В `test_notes.gd` добавить вызов `t_augment_note()` в `_init()` после `t_build_icon_row()` и дописать в конец файла:

```gdscript
class FakeCard extends PanelContainer:
	var taskData = null
	var inputItems: Label
	var outputItems: Label
	var inputGrid: Control
	var outputGrid: Control

func _make_card(card: FakeCard, deliver: Array, receive: Array) -> void:
	var elements := VBoxContainer.new()
	card.add_child(elements)

	var description := Label.new()
	elements.add_child(description)

	var input_label := Label.new()
	input_label.text = "Deliver:"
	elements.add_child(input_label)
	card.inputItems = Label.new()
	card.inputItems.text = "Item, Item"
	input_label.add_child(card.inputItems)
	card.inputGrid = GridContainer.new()
	elements.add_child(card.inputGrid)

	var output_label := Label.new()
	output_label.text = "Receive:"
	elements.add_child(output_label)
	card.outputItems = Label.new()
	card.outputItems.text = "Item, Item"
	output_label.add_child(card.outputItems)
	card.outputGrid = GridContainer.new()
	elements.add_child(card.outputGrid)

	card.taskData = {"deliver": deliver, "receive": receive}

func t_augment_note() -> void:
	var card := FakeCard.new()
	var a := {"resource_path": "res://A", "name": "Bandage"}
	var b := {"resource_path": "res://B", "name": "Saline"}
	_make_card(card, [a, a, b], [b])
	N.augment_note(card)

	ck(card.inputItems.visible == false, "augment_note: текст Deliver скрыт")
	ck(card.outputItems.visible == false, "augment_note: текст Receive скрыт")
	ck(card.inputGrid.visible == false, "augment_note: грид Deliver скрыт")
	ck(card.outputGrid.visible == false, "augment_note: грид Receive скрыт")

	# Ряд иконок вставлен после секции 'Deliver:' (VBox: Description, Input, row, Input_Grid, Output, ...).
	var input_label := card.inputItems.get_parent()
	ck(input_label.get_index() == 1, "секция Deliver на месте")
	var row_in = card.get_child(0).get_child(input_label.get_index() + 1)
	ck(row_in is Control and row_in.get_child_count() == 2,
		"ряд Deliver: 2 разных предмета")
	var output_label := card.outputItems.get_parent()
	var row_out = card.get_child(0).get_child(output_label.get_index() + 1)
	ck(row_out is Control and row_out.get_child_count() == 1,
		"ряд Receive: 1 предмет")

	# Пустые списки — ряд не строится, текст всё равно скрыт.
	var empty := FakeCard.new()
	_make_card(empty, [], [])
	N.augment_note(empty)
	ck(empty.get_child(0).get_child_count() == 5, "пустые списки: ряд не добавлен")

	card.free()
	empty.free()
```

Запустить:
```
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```
Expected: `Notes tests passed`.

- [ ] **Step 4: Чекпойнт**

Run: `python .check\layout_check.py`
Expected: без ошибок.

---

## Task 3: Подключение хуков в `VTKHooks.gd` (TDD)

**Файлы:**
- Изменить: `loadouts/mods/VTK/VTKHooks.gd` (`const`, `var`, `_do_register`, 2 колбэка)
- Изменить: `.check/project/tests/test_hooks.gd`

**Interfaces:**
- Consumes: `VTKNotes.find_note/completed_lists/is_completed/augment_note` (Task 1–2)
- Produces: `_on_task_completed(task_data)`, `_on_notes_rendered()`

- [ ] **Step 1: Написать падающий тест немедленной очистки**

В `.check/project/tests/test_hooks.gd`:
- в `_run()` добавить вызов `t_task_note_removed_on_complete()` перед `print("")`;
- добавить класс и тест:

```gdscript
class FakeLoaderNotes extends Node:
	var notes: Array = []
	var saved: Array = []

	func LoadTaskNotes() -> Array:
		return notes

	func SaveTaskNotes(task, add: bool) -> void:
		saved.append([task, add])
		if not add and notes.has(task):
			notes.erase(task)

func t_task_note_removed_on_complete() -> void:
	var ldr := FakeLoaderNotes.new()
	ldr.name = "Loader"
	root.add_child(ldr)
	var h = TestHooks.new()
	root.add_child(h)

	var note := {"name": "Duty Calls", "trader": "Doctor"}
	ldr.notes = [note]

	h._on_task_completed({"name": "Other", "trader": "Doctor"})
	ck(ldr.saved.is_empty(), "чужая задача заметку не трогает")

	h._on_task_completed(note)
	ck(ldr.saved.size() == 1 and ldr.saved[0][1] == false, "сдача задачи удаляет заметку")
	ck(not ldr.notes.has(note), "заметка убрана из списка")

	ldr.free()
	h.queue_free()
```

Запустить:
```
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```
Expected: FAIL — `_on_task_completed` не определён (или `Invalid call`).

- [ ] **Step 2: Подключить `VTKNotes` и зарегистрировать хуки**

В `loadouts/mods/VTK/VTKHooks.gd`:

Добавить рядом с `const KC` (строка 9):

```gdscript
const Notes = preload("res://mods/VTK/VTKNotes.gd")
```

Добавить рядом с `var _hooks_kc` (строка 7):

```gdscript
var _hooks_notes: Array = []
```

В `_do_register()` после строки 149 (`_hooks_kc.append(_lib.hook("ai-death-pre", _on_ai_death))`) добавить:

```gdscript
	_hooks_notes.append(_lib.hook("trader-completetask-post", _on_task_completed))
	_hooks_notes.append(_lib.hook("interface-initializenotes-post", _on_notes_rendered))
```

Изменить строку 151, добавив в счётчик заметочные хуки:

```gdscript
	print("[VTK] Per-frame hooks registered (" + str(_hooks_kc.size() + _hooks_notes.size() + 1) + " hooks)")
```

- [ ] **Step 3: Реализовать колбэки**

Добавить в `VTKHooks.gd` (например, после `_on_controller_process`):

```gdscript
# Сдача задачи во вкладке торговца: убираем её заметку из Notes сразу.
# Notes в этот момент закрыт, поэтому чистим только данные (Loader).
func _on_task_completed(task_data) -> void:
	if task_data == null:
		return
	var ldr = get_node_or_null("/root/Loader")
	if ldr == null or not ldr.has_method("LoadTaskNotes") or not ldr.has_method("SaveTaskNotes"):
		return
	var inst = Notes.find_note(ldr.call("LoadTaskNotes"), task_data)
	if inst != null:
		ldr.call("SaveTaskNotes", inst, false)

# Отрисовка вкладки Notes: сданные заметки убираем, у остальных меняем текст
# списка предметов на ряд иконок. Страховка для задач, сданных в обход
# Trader.CompleteTask, и заметок из сессий до установки мода.
func _on_notes_rendered() -> void:
	var iface = _lib._caller if _lib else null
	if iface == null or not is_instance_valid(iface):
		return
	var list = iface.get("notesList")
	if list == null or not (list is Node):
		return
	var ldr = get_node_or_null("/root/Loader")
	var traders = null
	if FileAccess.file_exists("user://Traders.tres"):
		traders = load("user://Traders.tres")
	var completed = Notes.completed_lists(traders)
	var notes = []
	if ldr != null and ldr.has_method("LoadTaskNotes"):
		notes = ldr.call("LoadTaskNotes")
	for card in list.get_children():
		if card == null or not is_instance_valid(card):
			continue
		var task_data = card.get("taskData")
		if task_data == null:
			continue
		if Notes.is_completed(task_data, completed):
			var inst = Notes.find_note(notes, task_data)
			if inst != null and ldr != null and ldr.has_method("SaveTaskNotes"):
				ldr.call("SaveTaskNotes", inst, false)
			card.queue_free()
		else:
			Notes.augment_note(card)
```

- [ ] **Step 4: Запустить тест — должен пройти**

Run:
```
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```
Expected: `Hooks tests passed`, `Notes tests passed`, `Tests passed: 6 file(s)`, `Parse check passed`.

- [ ] **Step 5: Чекпойнт**

Run: `python .check\layout_check.py`
Expected: без ошибок.

---

## Task 4: Версия, документация, сборка

**Файлы:**
- Изменить: `loadouts/mod.txt`, `loadouts/mods/VTK/version.txt`, `README.md`, `AGENTS.md`

- [ ] **Step 1: Поднять версию**

`loadouts/mods/VTK/version.txt`: заменить содержимое на `4.11.0` (одна строка).

`loadouts/mod.txt` — единственная строка без переводов строки; заменить `version="4.10.3"` на `version="4.11.0"`. Итог:

```
[mod]name="Vostok Toolkit"id="vostok-toolkit"version="4.11.0"[autoload]VTKUI="res://mods/VTK/VTKUI.gd"
```

`README.md`: заменить `4.10.3` на `4.11.0` (единственное вхождение, строка 7).

- [ ] **Step 2: Обновить `AGENTS.md`**

- Таблица «Структура»: строку ``| `loadouts/mods/VTK/` | восемь скриптов мода, префикс `VTK` |`` заменить на ``| `loadouts/mods/VTK/` | девять скриптов мода, префикс `VTK` |``.
- Добавить строку в таблицу: `| loadouts/mods/VTK/VTKNotes.gd | логика Notes: группировка предметов, признак сдачи, построение строк иконок; чистые функции тестируются headless |`.
- В раздел «Проверка» добавить абзац: `VTKNotes.gd` — чистая логика Notes (группировка по `resource_path`, признак сдачи по `TraderSave`, построение плиток иконок из переданных `Texture2D`): ни `load()`, ни путей внутрь игры, потому покрыт headless-тестом `test_notes.gd`. Карточки Notes — ванильный `Task.tscn`; мод добавляет ряд иконок через `augment_note`, не трогая сцену. Версию не дублирует.

- [ ] **Step 3: Прогнать оба стенда**

Run:
```
python .check\layout_check.py
```
Run:
```
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```
Expected: `layout_check` без ошибок; `check.ps1` — `Parse check passed`, `Tests passed: 6 file(s)`.

- [ ] **Step 4: Собрать пак**

Run:
```
powershell -ExecutionPolicy Bypass -File pack.ps1
```
Expected: вывод печатает `version 4.11.0`; создаётся `Loadouts.vmz`. Установка в папку модов и ручная проверка в игре — по решению пользователя.

---

## Ручная проверка в игре (вне автотестов)

- Notes: у задач с предметами вместо строки текста — ряд иконок, `×N` для повторов, имя в тултипе; заголовки `Deliver:`/`Receive:` на месте.
- Задача без `deliver`/`receive` — карточка как раньше.
- Сдать задачу через торговца → её заметка исчезает из Notes при следующем открытии, при повторном открытии не возвращается.
- Задача, сданная до установки мода, исчезает из Notes при первом открытии.

## Self-review (проверено)

- **Покрытие спеки:** иконки (Task 2), автоочистка в двух точках (Task 3 `_on_task_completed` + `_on_notes_rendered`), края (фоллбэк без иконки — Task 2 `_make_cell`; пустые списки — Task 2 тест; отсутствие `Traders.tres` — `completed_lists(null)` и `FileAccess.file_exists`), версия/файлы (Task 4). Полное.
- **Плейсхолдеры:** код приведён целиком; промежуточная заглушка `_make_card` в Task 2 Step 1 явно помечена и заменяется в Step 3.
- **Консистентность типов:** `group_items/completed_lists/is_completed/find_note/badge_text/build_icon_row/augment_note` совпадают между тасками и тестами; `_on_task_completed`/`_on_notes_rendered` — как в Task 3.
