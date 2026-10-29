# Телепорт — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Добавить в мод вкладку «Телепорт» с тремя блоками (карты, убежища, трейдеры) и переименовать мод в `Vostok Toolkit` без потери сохранённых сетов.

**Architecture:** Новая логика живёт в отдельном файле `LoadoutsTravel.gd` (данные + действия), `LoadoutsUI.gd` только рисует кнопки и вызывает методы. Все три команды сходятся к одной приватной `_teleport_internal(target_map, final_offset)`. Переименование меняет `name`/`id` в `mod.txt` и семь мест с путём `MCM/loadouts`, плюс одноразовая миграция папки.

**Tech Stack:** Godot 4.6.3, GDScript, MCM (ModConfigurationMenu), autoload `LoadoutsUI`.

## Global Constraints

- Отступы в `.gd` — **только табы**. Пробелы не допускаются.
- Версия живёт только в `loadouts/mod.txt`, поле `version`. Итоговое значение — `3.0.0`.
- Итоговый `mod.txt`: `name="Vostok Toolkit"`, `id="vostok-toolkit"`.
- Проверка парсинга: `powershell -NoProfile -ExecutionPolicy Bypass -File "D:\RTVMOD\.check\check.ps1"` — должна пройти для всех файлов `.gd`.
- Сборка: `powershell -NoProfile -ExecutionPolicy Bypass -File "D:\RTVMOD\pack.ps1"`.
- Развёртывание: копировать `D:\RTVMOD\Loadouts.vmz` в `D:\SteamLibrary\steamapps\common\Road to Vostok\mods\Loadouts.vmz`.
- Рабочая папка **не является git-репозиторием** — шагов `git commit` в плане нет. Вместо коммита каждый таск заканчивается прогоном `check.ps1`.
- `DEBUG_PROBE` в `LoadoutsNVG.gd` **остаётся `true`**: диагностика тепловизора продолжается завтра. Не выключать и не удалять логирование.
- Никаких изменений в `LoadoutsNVG.gd`, кроме перечисленного явно. Тепловизор и белый экран — отдельная задача.
- Свойства `gameData` читать и писать только через `.get()` / `.set()` с запасным значением.
- Ужесточения ради этого релиза не делать: смена поведения ironman, `tonemap_exposure`, ванильного `tint` не трогаем.

---

### Task 1: Переименование мода и миграция папки MCM

**Files:**
- Modify: `D:\RTVMOD\loadouts\mod.txt`
- Modify: `D:\RTVMOD\loadouts\mods\Loadouts\LoadoutsData.gd:3,28`
- Modify: `D:\RTVMOD\loadouts\mods\Loadouts\LoadoutsUI.gd:433,794,798,1012,1049,1078`
- Modify: `D:\RTVMOD\loadouts\mods\Loadouts\LoadoutsUI.gd:80-92` (`_init_later`)

**Interfaces:**
- Consumes: ничего.
- Produces: функция `_migrate_mcm_dir() -> void` в `LoadoutsUI.gd`; новая папка `user://MCM/vostok-toolkit`. Все остальные таски могут считать, что `user://MCM/vostok-toolkit` существует.

- [ ] **Step 1: Изменить `mod.txt`**

`mod.txt` — **одна строка без единого перевода строки** (107 байт, 0 CR, 0 LF). Формат плоский, `[mod]` и `[autoload]` склеены. Перенос строк вставлять нельзя: загрузчик разбирает файл как плоский список `key="value"`. Меняются ровно три значения, порядок и остальной текст сохраняются.

Итоговая строка целиком:

```
[mod]name="Vostok Toolkit"id="vostok-toolkit"version="3.0.0"[autoload]LoadoutsUI="res://mods/Loadouts/LoadoutsUI.gd"
```

Проверить после записи, что переводов строк по-прежнему ноль:

```powershell
$b = [System.IO.File]::ReadAllBytes("D:\RTVMOD\loadouts\mod.txt"); "cr=$(@($b | Where-Object { $_ -eq 13 }).Count) lf=$(@($b | Where-Object { $_ -eq 10 }).Count)"
```
Expected: `cr=0 lf=0`.

Имя автозагрузки `LoadoutsUI` и путь `res://mods/Loadouts/LoadoutsUI.gd` не трогать — внутренние имена сохраняются.

- [ ] **Step 2: Заменить путь в `LoadoutsData.gd`**

Строка 3, заменить `const SAVE_FILE`:
```gdscript
const SAVE_FILE := "user://MCM/vostok-toolkit/loadouts.json"
```
Было `const SAVE_FILE = ...` — обратить внимание на `:=`, в файле используется вывод типа через `:=`.

Строка 28, заменить `var real_dir`:
```gdscript
var real_dir = OS.get_user_data_dir() + "/MCM/vostok-toolkit"
```

- [ ] **Step 3: Заменить пути в `LoadoutsUI.gd`**

Строка 433, заменить `"user://MCM/loadouts/loadouts.json"` на `"user://MCM/vostok-toolkit/loadouts.json"`.

Строка 794:
```gdscript
const TOGGLE_CFG := "user://MCM/vostok-toolkit/ui_toggles.json"
```

Строка 798:
```gdscript
var d = DirAccess.open(OS.get_user_data_dir() + "/MCM/vostok-toolkit")
```

Строка 1012:
```gdscript
var path = "user://MCM/vostok-toolkit"
```

Строка 1049, целиком:
```gdscript
MCM.RegisterConfiguration("vostok-toolkit", "Vostok Toolkit", path, "Loadouts, ESP and teleport", _mcm_apply, self)
```

Строка 1078:
```gdscript
var cpath = "user://MCM/vostok-toolkit/config.ini"
```

- [ ] **Step 4: Добавить функцию миграции в `LoadoutsUI.gd`**

Вставить перед `func _init_later()` (то есть между строкой 78 и 80):

```gdscript
func _migrate_mcm_dir() -> void:
	var old_dir := OS.get_user_data_dir() + "/MCM/loadouts"
	var new_dir := OS.get_user_data_dir() + "/MCM/vostok-toolkit"
	if not DirAccess.dir_exists_absolute(old_dir):
		return
	if DirAccess.dir_exists_absolute(new_dir):
		return
	DirAccess.make_dir_recursive_absolute(new_dir)
	var src := DirAccess.open(old_dir)
	if src == null:
		return
	src.list_dir_begin()
	var fname := src.get_next()
	while fname != "":
		if not src.current_is_dir() and not fname.begins_with("."):
			src.copy_absolute(new_dir + "/" + fname)
		fname = src.get_next()
	src.list_dir_end()
	DirAccess.remove_absolute(old_dir)
	print("[Loadouts] MCM dir migrated: loadouts -> vostok-toolkit")
```

- [ ] **Step 5: Вызвать миграцию первой в `_init_later()`**

В `func _init_later()` первой строкой после `_late_initialized = true` добавить `_migrate_mcm_dir()`. Итоговый порядок — критичен, миграция обязана выполниться до `_load_items()`, `_restore_toggles()` и `_register_mcm()`, иначе они создадут пустую новую папку:

```gdscript
func _init_later() -> void:
	if _late_initialized:
		return
	_late_initialized = true
	_migrate_mcm_dir()
	print("[Loadouts] Starting UI init")
	_load_items()
	_build_ui()
	_restore_toggles()
	var Hooks = preload("res://mods/Loadouts/LoadoutsHooks.gd")
	_hooks = Hooks.new()
	add_child(_hooks)
	_register_mcm()
	print("[Loadouts] UI init done")
```

- [ ] **Step 6: Прогнать проверку парсинга**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File "D:\RTVMOD\.check\check.ps1"`
Expected: все файлы `.gd` прошли, ошибок компиляции нет.

- [ ] **Step 7: Проверить, что старых путей не осталось**

Run:
```powershell
Get-ChildItem -LiteralPath "D:\RTVMOD\loadouts" -Recurse -Filter "*.gd" | Select-String -Pattern 'MCM/loadouts'
```
Expected: пустой вывод. Любое совпадение означает невыполненную замену из Step 3.

---

### Task 2: Ядро телепорта — `LoadoutsTravel.gd`

**Files:**
- Create: `D:\RTVMOD\loadouts\mods\Loadouts\LoadoutsTravel.gd`

**Interfaces:**
- Consumes: ничего.
- Produces:
  - class_name не задавать — файл подключается через `preload`.
  - `func travel_to_map(map_name: String) -> void`
  - `func travel_to_shelter(shelter_name: String) -> void`
  - `func is_shelter_unlocked(shelter_name: String) -> bool`
  - `func set_unlocked_only(on: bool) -> void`
  - `const MAPS: Array`, `const SHELTERS: Array`, `const TRADERS: Array`
  - `final_offset` в `_teleport_internal` принимает три формы: `null` — не двигать игрока; `Vector3` — поставить в эту точку; `Callable` — вызвать **после** смены сцены и взять returned `Vector3`.

- [ ] **Step 1: Создать файл с данными и скелетом**

```gdscript
extends Node

const GAME_DATA_RES := "res://Resources/GameData.tres"
const CONTROLLER_PATH := "/root/Map/Core/Controller"
const LOADER_PATH := "/root/Loader"
const SCENE_WAIT_FRAMES := 600

const MAPS := [
	"Village", "Highway", "School", "Outpost",
	"Minefield", "Bridge", "Apartments", "Terminal", "Airfield"
]

const SHELTERS := [
	"Cabin", "Attic", "Classroom", "Tent", "Bunker", "Garage"
]

const TRADERS := [
	{"name": "Doctor", "map": "School", "pos": Vector3(46.0, 9.0, 49.0)},
	{"name": "Gunsmith", "map": "Outpost", "pos": Vector3(106.1, 0.21, -140.0)},
	{"name": "Generalist", "map": "Village", "pos": Vector3(44.9, 0.4, 65.4)}
]

var game_data: Resource = null
var unlocked_only: bool = false
var _busy: bool = false


func _ready() -> void:
	game_data = load(GAME_DATA_RES)
	process_mode = Node.PROCESS_MODE_ALWAYS
```

- [ ] **Step 2: Добавить публичные команды карты и убежища**

Вставить после `_ready()`:

```gdscript
func travel_to_map(map_name: String) -> void:
	if not MAPS.has(map_name):
		_message("Неизвестная карта: " + map_name, Color.RED)
		return
	_teleport_internal(map_name, null)


func travel_to_shelter(shelter_name: String) -> void:
	if not SHELTERS.has(shelter_name):
		_message("Неизвестное убежище: " + shelter_name, Color.RED)
		return
	if unlocked_only and not is_shelter_unlocked(shelter_name):
		_message("Убежище ещё не открыто: " + shelter_name, Color.RED)
		return
	_teleport_internal(shelter_name, null)


func is_shelter_unlocked(shelter_name: String) -> bool:
	var loader := _loader()
	if loader != null and loader.has_method("CheckShelterState"):
		return bool(loader.CheckShelterState(shelter_name))
	return FileAccess.file_exists("user://" + shelter_name + ".tres")


func set_unlocked_only(on: bool) -> void:
	unlocked_only = on
```

- [ ] **Step 3: Добавить общую внутреннюю функцию**

Вставить после `set_unlocked_only`:

```gdscript
func _teleport_internal(target_map: String, final_offset: Variant) -> void:
	if _busy:
		_message("Телепорт уже выполняется", Color.YELLOW)
		return
	if game_data != null and bool(game_data.get("tutorial")):
		_message("Телепорт недоступен в туториале", Color.RED)
		return
	var loader := _loader()
	if loader == null or not loader.has_method("LoadScene"):
		_message("Не найден загрузчик сцен", Color.RED)
		return
	_busy = true
	_close_interfaces()
	var actual_current := _current_map_name()
	if game_data != null:
		if bool(game_data.get("shelter")) and loader.has_method("SaveShelter"):
			loader.SaveShelter(actual_current)
		game_data.set("previousMap", actual_current)
		game_data.set("currentMap", target_map)
	var prev_id := 0
	var scene := get_tree().current_scene
	if scene != null:
		prev_id = scene.get_instance_id()
	loader.LoadScene(target_map)
	if not await _wait_scene_change(prev_id):
		_busy = false
		_message("Сцена не загрузилась: " + target_map, Color.RED)
		return
	if loader.has_method("SaveCharacter"):
		loader.SaveCharacter()
	if loader.has_method("SaveWorld"):
		loader.SaveWorld()
	var point: Variant = _resolve_final_offset(final_offset)
	if point is Vector3:
		_place_player(point)
	_busy = false
	_message("Телепорт: " + target_map, Color.GREEN)


func _resolve_final_offset(final_offset: Variant) -> Variant:
	if final_offset is Callable:
		var c: Callable = final_offset
		if c.is_valid():
			return c.call()
		return null
	return final_offset


func _wait_scene_change(prev_id: int) -> bool:
	for _i in range(SCENE_WAIT_FRAMES):
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if scene != null and scene.get_instance_id() != prev_id:
			await get_tree().create_timer(0.1, false).timeout
			return true
	return false
```

- [ ] **Step 4: Добавить вспомогательные функции**

Вставить после `_wait_scene_change`:

```gdscript
func _loader() -> Node:
	return get_node_or_null(LOADER_PATH)


func _controller() -> Node3D:
	var c := get_node_or_null(CONTROLLER_PATH)
	if c is Node3D:
		return c
	return null


func _current_map_name() -> String:
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path == "":
		return ""
	return scene.scene_file_path.get_file().get_basename()


func _close_interfaces() -> void:
	var parent := get_parent()
	if parent != null and is_instance_valid(parent) and parent.has_method("_set_panel_open"):
		parent.call("_set_panel_open", false)
	var ui := get_node_or_null("/root/Map/Core/UI")
	if ui != null and ui.has_method("ToggleInterface"):
		ui.call("ToggleInterface")
	else:
		var iface := get_node_or_null("/root/Map/Core/UI/Interface")
		if iface != null and iface.has_method("Close"):
			iface.call("Close")
		if game_data != null:
			game_data.set("interface", false)
			game_data.set("isOccupied", false)


func _message(text: String, color: Color) -> void:
	var loader := _loader()
	if loader != null and loader.has_method("Message"):
		loader.call("Message", text, color)
		return
	print("[Loadouts] " + text)


func _place_player(target: Vector3) -> void:
	var ctrl := _controller()
	if ctrl == null:
		print("[Loadouts] controller not found, player not placed")
		return
	ctrl.global_position = target
	ctrl.set("velocity", Vector3.ZERO)
	if game_data != null:
		game_data.set("playerVector", Vector3.ZERO)
```

- [ ] **Step 5: Прогнать проверку парсинга**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File "D:\RTVMOD\.check\check.ps1"`
Expected: все файлы прошли. `_place_player` использует `ctrl.set("velocity", ...)` вместо прямого обращения — это сделано намеренно, чтобы анализатор не спотыкался на свойстве, которого нет в заглушке `Controller`.

---

### Task 3: Вкладка «Телепорт» с блоками Карты и Убежища

**Files:**
- Modify: `D:\RTVMOD\loadouts\mods\Loadouts\LoadoutsUI.gd:260,289-292`

> **СУПЕРСЕДИРОВАНО 2026-10-03.** Блок кода ниже — ранний вариант Task 3 и расходится
> с релизом 3.0.0. Каноничны spec
> `docs/superpowers/specs/2026-10-03-teleport-ui-design.md` и живой код
> `loadouts/mods/Loadouts/LoadoutsUI.gd`. Расхождения:
>
> - Закрытые убежища **не** получают ни серого цвета, ни подписи «— закрыто». Ветка с
>   `note2 = "закрыто"` и `enabled = false` удалена. При `tp_unlocked_shelters_only=true`
>   кнопка остаётся активной, а отказ приходит красным сообщением из
>   `travel_to_shelter` — как в референс-моде JCM. `disabled = true` и подпись
>   «в туториале» остались только для tutorial.
> - `_tp_switch` очищает все три контейнера, включая `_tp_traders_box`, и отсоединяет
>   узлы (`remove_child()`) перед `queue_free()`.
> - Секция «Трейдеры» здесь только объявлена; её наполняет Task 6.
- Modify: `D:\RTVMOD\loadouts\mods\Loadouts\LoadoutsUI.gd` — добавить переменные и функции

**Interfaces:**
- Consumes: `LoadoutsTravel` из Task 2, его `MAPS`, `SHELTERS`, `travel_to_map`, `travel_to_shelter`, `is_shelter_unlocked`.
- Produces: `var _travel: Node`, `func _ensure_travel() -> void`, `func _build_teleport_tab(parent: VBoxContainer) -> void`, `func _refresh_teleport_tab() -> void`, `func _tp_switch(section: String) -> void`.

- [ ] **Step 1: Добавить переменные состояния**

Рядом с другими переменными вкладок (после строки 25 `var _current_tab: String = ""`) вставить:

```gdscript
# teleport tab
var _travel: Node = null
var _tp_section: String = "maps"
var _tp_section_btns: Array = []
var _tp_maps_box: VBoxContainer = null
var _tp_shelters_box: VBoxContainer = null
var _tp_traders_box: VBoxContainer = null
```

- [ ] **Step 2: Зарегистрировать вкладку**

Строку 260 заменить:
```gdscript
	var tabs = ["Сеты", "Настройки", "Телепорт"]
```

После строки 290 (`_build_settings_tab(...)`) добавить строку:
```gdscript
	_build_teleport_tab(_tab_containers["Телепорт"])
```

- [ ] **Step 3: Добавить функцию подгрузки узла travel**

Вставить рядом с `_ensure_nvg()`:

```gdscript
func _ensure_travel() -> void:
	if _travel != null and is_instance_valid(_travel):
		return
	var T := preload("res://mods/Loadouts/LoadoutsTravel.gd")
	_travel = T.new()
	add_child(_travel)
```

- [ ] **Step 4: Добавить построение вкладки**

Вставить перед `func _register_mcm()`:

```gdscript
func _build_teleport_tab(parent: VBoxContainer) -> void:
	_ensure_travel()

	var head := Label.new()
	head.text = "Телепорт"
	head.add_theme_font_size_override("font_size", 14)
	head.add_theme_color_override("font_color", _gold)
	parent.add_child(head)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	parent.add_child(bar)

	_tp_maps_box = VBoxContainer.new()
	_tp_maps_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tp_shelters_box = VBoxContainer.new()
	_tp_shelters_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tp_traders_box = VBoxContainer.new()
	_tp_traders_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for box in [_tp_maps_box, _tp_shelters_box, _tp_traders_box]:
		box.add_theme_constant_override("separation", 4)
		parent.add_child(box)

	var defs := [["maps", "Карты"], ["shelters", "Убежища"], ["traders", "Трейдеры"]]
	for d in defs:
		var key: String = d[0]
		var b := Button.new()
		b.text = d[1]
		b.custom_minimum_size = Vector2(110, 26)
		b.add_theme_font_size_override("font_size", 12)
		var k := key
		b.pressed.connect(func(): _tp_switch(k))
		bar.add_child(b)
		_tp_section_btns.append({"key": key, "btn": b})

	_tp_switch("maps")


func _tp_switch(section: String) -> void:
	_tp_section = section
	_tp_maps_box.visible = section == "maps"
	_tp_shelters_box.visible = section == "shelters"
	_tp_traders_box.visible = section == "traders"
	for entry in _tp_section_btns:
		var is_active: bool = entry["key"] == section
		var btn: Button = entry["btn"]
		if is_active:
			btn.add_theme_color_override("font_color", _gold)
			btn.add_theme_stylebox_override("normal", _make_tab_active_style())
		else:
			btn.add_theme_color_override("font_color", Color("#888"))
			btn.add_theme_stylebox_override("normal", _make_tab_style())
	_refresh_teleport_tab()


func _refresh_teleport_tab() -> void:
	_ensure_travel()
	if _travel == null or not is_instance_valid(_travel):
		return
	for c in _tp_maps_box.get_children():
		c.queue_free()
	for c in _tp_shelters_box.get_children():
		c.queue_free()
	var in_tutorial: bool = game_data != null and bool(game_data.get("tutorial"))

	for m in _travel.MAPS:
		var note := "в туториале" if in_tutorial else ""
		_tp_maps_box.add_child(_tp_row(String(m), note, not in_tutorial, func(): _travel.travel_to_map(String(m))))

	for s in _travel.SHELTERS:
		var unlocked: bool = bool(_travel.is_shelter_unlocked(String(s)))
		var enabled: bool = not in_tutorial
		var note2 := "" if unlocked else "закрыто"
		if in_tutorial:
			note2 = "в туториале"
		elif bool(_travel.unlocked_only) and not unlocked:
			note2 = "закрыто"
			enabled = false
		_tp_shelters_box.add_child(_tp_row(String(s), note2, enabled, func(): _travel.travel_to_shelter(String(s))))


func _tp_row(title: String, note: String, enabled: bool, callback: Callable) -> Control:
	var b := Button.new()
	b.text = title if note == "" else title + "  —  " + note
	b.custom_minimum_size = Vector2(0, 28)
	b.add_theme_font_size_override("font_size", 12)
	b.disabled = not enabled
	if not enabled:
		b.add_theme_color_override("font_color", Color("#666"))
	var cb := callback
	b.pressed.connect(func():
		if cb.is_valid():
			cb.call())
	return b
```

- [ ] **Step 5: Добавить `game_data` в `LoadoutsUI.gd`**

В файле нет переменной `gameData`, а `_refresh_teleport_tab` её использует. Вставить рядом с прочими переменными:

```gdscript
var game_data: Resource = null
```

И первой строкой в `_init_later()`, сразу после `_migrate_mcm_dir()`:

```gdscript
	game_data = load("res://Resources/GameData.tres")
```

- [ ] **Step 6: Обновлять вкладку при открытии панели**

В `func _switch_tab(name: String)` добавить вызов в начало функции:

```gdscript
	if name == "Телепорт":
		_refresh_teleport_tab()
```

- [ ] **Step 7: Прогнать проверку парсинга**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File "D:\RTVMOD\.check\check.ps1"`
Expected: все файлы прошли.

---

### Task 4: MCM-флаг «только открытые убежища»

**Files:**
- Modify: `D:\RTVMOD\loadouts\mods\Loadouts\LoadoutsUI.gd:1002,1086-1092`

**Interfaces:**
- Consumes: `set_unlocked_only(on: bool)` из Task 2.
- Produces: ключ MCM `tp_unlocked_shelters_only` (Bool, default `false`) в секции `"03. Travel"`.

- [ ] **Step 1: Добавить ключ в `_register_mcm`**

После строки с `cfg.set_value("Info", "author", "opencode")` вставить:

```gdscript
	var TR := "03. Travel"
	cfg.set_value("Bool", "tp_unlocked_shelters_only", {"name": "Unlocked shelters only", "default": false, "value": false, "category": TR, "menu_pos": 0, "tooltip": "When enabled, teleporting to a locked shelter is refused."})
```

Текст `name` и `tooltip` задан не буквально из первоначальной редакции плана, а исправлен под решение пользователя. Прежний tooltip обещал «undiscovered shelters are greyed out», но серого оформления больше нет — флаг влияет только на выполнение перехода. Правку внес implementer; здесь она зафиксирована, чтобы план не вводил в заблуждение.

- [ ] **Step 2: Применить ключ в `_mcm_apply`**

Вставлять **до** блока `_ensure_nvg()`, а не в конец функции. В `_mcm_apply()` есть ранний
`return` на случай, если `_nvg_node` ещё не валиден:

```gdscript
	_ensure_nvg()
	if _nvg_node == null or not is_instance_valid(_nvg_node):
		return
```

Поэтому код, поставленный после этого `return` (включая прежний вариант «в конце, после
`_apply_nvg_settings()`»), не выполнился бы ни при одном запуске, где NVG ещё не готов, —
то есть был бы мёртвым. Правильное место — сразу после чтения `_key_ui_toggle` и до
`_ensure_nvg()`:

```gdscript
	_key_ui_toggle = int(_mcm_key_val(cfg, "Keycode", "key_ui_toggle", 0))
	_ensure_travel()
	if _travel != null and is_instance_valid(_travel):
		var tp_unlocked = bool(_mcm_key_val(cfg, "Bool", "tp_unlocked_shelters_only", false))
		_travel.set_unlocked_only(tp_unlocked)
	_ensure_nvg()
```

- [ ] **Step 3: Прогнать проверку парсинга**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File "D:\RTVMOD\.check\check.ps1"`
Expected: все файлы прошли.

---

### Task 5: Телепорт к трейдерам с поиском земли

**Files:**
- Modify: `D:\RTVMOD\loadouts\mods\Loadouts\LoadoutsTravel.gd`

**Interfaces:**
- Consumes: `_teleport_internal` (с поддержкой `Callable` в `final_offset`), `_controller`, `game_data`, `_current_map_name` из Task 2.
- Produces: `func travel_to_trader(entry: Dictionary) -> void`, `func find_trader(trader_name: String) -> Node3D`.

- [ ] **Step 1: Добавить команду трейдера**

Вставить рядом с `travel_to_shelter`:

```gdscript
func travel_to_trader(entry: Dictionary) -> void:
	if entry == null or not entry.has("map"):
		return
	# Передаётся Callable, а не Vector3: живой трейдер появляется в дереве
	# только после смены сцены, поэтому точку обязательно считать после
	# загрузки. Callable вызывается на шаге 9 внутри _teleport_internal.
	_teleport_internal(String(entry["map"]), func(): return _trader_point(entry))


func find_trader(trader_name: String) -> Node3D:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return _find_trader_in(scene, trader_name)


func _find_trader_in(root: Node, trader_name: String) -> Node3D:
	for child in root.get_children():
		if child is Node3D:
			if child.name == trader_name and _is_trader(child):
				return child
			var found := _find_trader_in(child, trader_name)
			if found != null:
				return found
	return null


func _is_trader(n: Node) -> bool:
	var s = n.get("script")
	if s is Script:
		return String((s as Script).resource_path).ends_with("Trader.gd")
	return false
```

- [ ] **Step 2: Добавить расчёт точки и установку на землю**

Вставить рядом с `_place_player`:

```gdscript
func _trader_point(entry: Dictionary) -> Vector3:
	var fallback := Vector3.ZERO
	if entry.has("pos"):
		var raw = entry["pos"]
		if raw is Vector3:
			fallback = raw
	var node := find_trader(String(entry.get("name", "")))
	var anchor: Vector3 = fallback
	if node != null:
		anchor = node.global_position
	var ctrl := _controller()
	var origin := ctrl.global_position if ctrl != null else anchor
	var flat := Vector3(anchor.x - origin.x, 0.0, anchor.z - origin.z)
	if flat.length() < 0.01:
		flat = Vector3(0.0, 0.0, -3.0)
	var side := flat.normalized() * 3.0
	var probe := anchor + side
	var ctrl2 := _controller()
	if ctrl2 == null:
		return probe
	var space := ctrl2.get_world_3d().direct_space_state
	var from := probe + Vector3(0.0, 30.0, 0.0)
	var params := PhysicsRayQueryParameters3D.create(from, probe + Vector3(0.0, -60.0, 0.0))
	params.exclude = [ctrl2.get_rid()]
	var hit := space.intersect_ray(params)
	if hit.is_empty():
		for radius in [2.0, 4.0, 6.0]:
			for step in range(6):
				var angle := TAU * float(step) / 6.0
				var offset := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
				var p2 := anchor + offset
				var p3 := p2 + Vector3(0.0, 30.0, 0.0)
				var params2 := PhysicsRayQueryParameters3D.create(p3, p2 + Vector3(0.0, -60.0, 0.0))
				params2.exclude = [ctrl2.get_rid()]
				var hit2 := space.intersect_ray(params2)
				if not hit2.is_empty():
					return hit2["position"]
		print("[Loadouts] no ground near trader, using raw point")
		return probe
	return hit["position"]
```

- [ ] **Step 3: Прогнать проверку парсинга**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File "D:\RTVMOD\.check\check.ps1"`
Expected: все файлы прошли.

---

### Task 6: Блок «Трейдеры» в интерфейсе

**Files:**
- Modify: `D:\RTVMOD\loadouts\mods\Loadouts\LoadoutsUI.gd` — функция `_refresh_teleport_tab`

**Interfaces:**
- Consumes: `TRADERS`, `travel_to_trader` из Task 5.
- Produces: заполненный блок «Трейдеры».

- [ ] **Step 1: Добавить отрисовку трейдеров**

В `func _refresh_teleport_tab()`, после цикла по убежищам, добавить:

```gdscript
	for t in _travel.TRADERS:
		var entry: Dictionary = t
		var label := String(entry["name"]) + "  —  " + String(entry["map"])
		var note3 := "в туториале" if in_tutorial else ""
		_tp_traders_box.add_child(_tp_row(label, note3, not in_tutorial, func(): _travel.travel_to_trader(entry)))
```

- [ ] **Step 2: Прогнать проверку парсинга**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File "D:\RTVMOD\.check\check.ps1"`
Expected: все файлы прошли.

---

### Task 7: Сборка, развёртывание, проверка в игре

**Files:**
- Verify: `D:\RTVMOD\loadouts\mod.txt` содержит `version="3.0.0"`

**Interfaces:**
- Consumes: всё из Task 1–6.
- Produces: `D:\RTVMOD\Loadouts.vmz` и развёрнутый пакет.

- [ ] **Step 1: Убедиться, что версия поднята**

Run:
```powershell
Get-Content -LiteralPath "D:\RTVMOD\loadouts\mod.txt" -Raw
```
Expected: одна строка, содержащая `name="Vostok Toolkit"`, `id="vostok-toolkit"`, `version="3.0.0"`, и без переводов строк.

- [ ] **Step 2: Собрать пакет**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File "D:\RTVMOD\pack.ps1"`
Expected: пакет собран, напечатана версия из `mod.txt`.

- [ ] **Step 3: Развернуть**

Run:
```powershell
Copy-Item -LiteralPath "D:\RTVMOD\Loadouts.vmz" -Destination "D:\SteamLibrary\steamapps\common\Road to Vostok\mods\Loadouts.vmz" -Force
```
Expected: копирование без ошибки.

- [ ] **Step 4: Проверить миграцию в игре**

Запустить игру, открыть панель мода. Проверить, что:
- в MCM есть раздел `03. Travel` с ключом `Only teleport to discovered shelters`;
- сохранённые сеты на месте, то есть список сетов не пуст, если до переименования они были;
- папка `user://MCM/loadouts` исчезла, а `user://MCM/vostok-toolkit` присутствует и содержит `config.ini`, `loadouts.json`, `ui_toggles.json`.

- [ ] **Step 5: Проверить телепорт в игре**

По очереди:
- все 9 карт из блока «Карты»;
- все 6 убежищ из блока «Убежища», включая закрытое;
- все 3 трейдера из блока «Трейдеры», включая переход с чужой карты.

Для каждого пункта убедиться, что игрок стоит на земле, а не в воздухе или стене, и что игра не падает.

- [ ] **Step 6: Проверить MCM-флаг**

Выключить «Only teleport to discovered shelters» — телепорт в закрытое убежище работает. Включить — кнопка закрытого убежища неактивна.

---

## Открытые вопросы, не входящие в план

- **Белый экран при включении тепловизора.** В `2.5.0` `gameData.NVG` оставался `false` во всех записях лога, то есть наш `thermalMode` не включался ни разу; белый экран в thermal-ветке шейдера получиться не мог. Не-thermal ветка нашего шейдера совпадает с рабочим модом `ThermalVision`. Отдельно найдено: `_apply_env()` в `LoadoutsNVG.gd` выставляет `env.tonemap_white` и не восстанавливает его при выключении NVG — при значении 1.0 безвредно, но при понижении «NVG white point» среда останется выбитой в белое. Разбор — после того как заработает телепорт.
- **Мины не подсвечиваются.** `_update_mine` использует `show = thermal_on and set_mines`, где `thermal_on = set_thermal and _nvg_active()`. Пока `gameData.NVG` не становится `true`, мины не получают материал (в логе `ours=false`). Рабочий мод `ThermalVision` не зависит от `gameData.NVG`: он ставит `thermalMode` из своего тумблера и сам показывает overlay через `_set_nvg_chain_visible(true)`.
- **Hunter, Driver, Grandma** не найдены офлайн и в список не входят.