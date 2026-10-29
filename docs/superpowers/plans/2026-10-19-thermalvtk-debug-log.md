# ThermalVTK — диагностический лог контурного ESP

**Goal:** Дать ThermalVTK переиспользуемый канал диагностических логов и оснастить контурный путь пробами, чтобы сессию можно было разобрать по файлу, а не гадать.

**Architecture:** Новый статический синк `VTKDebug.gd` — единственное место с гейтом и файлом. Все модули зовут `Dbg.log(tag, msg)`. Включение — MCM-ключ `Bool debug_log` в категории `05. Diagnostics`. Пробы: события (регистрация/состояние/сбор мешей) + сводка раз в секунду.

**Tech Stack:** GDScript (Godot 4.6.3), modloader; проверка — `.check/check.ps1` (парсинг + headless-тесты).

## Global Constraints

- Отступы в `.gd` — только табы; файлы в CRLF (сохранять).
- Версия мода — только `standalone mods/ThermalVTK/mod.txt`, поле `version`. Цель — `1.3.0`.
- Лог-файл — `user://MCM/thermal-vtk/debug.log` (каталог `user://MCM/thermal-vtk` мод уже создаёт).
- Лог по умолчанию выключен; включается только ключом MCM. Гейт и файл живут только в `VTKDebug`; места вызова не проверяют флаг и не открывают файл.
- Логи служебные, английские; UI-тексты (тосты `_notify`) не трогаем.
- `check.ps1` копирует `standalone mods/ThermalVTK/mods/ThermalVTK/*.gd` в `.check/project/mods/ThermalVTK`, гоняет `--check-only` по каждому файлу и список тестов `$tests` (явный, пополняется руками). Зелёный статус = нет `SCRIPT ERROR`/`Parse Error`/`Invalid call`/`Failed to load script`, есть `tests passed`, код выхода 0.
- Коммиты — только по явной команде владельца. Шаги «Commit» помечены `[skip]` и выполняются лишь тогда, когда владелец попросит.
- Все команды — из `D:\RTVMOD`. Godot: `D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe` (в `check.ps1` передаётся через `-Godot "<путь>"`, если не в PATH).

---

### Task 1: Канал логов `VTKDebug.gd` + headless-тест

**Files:**
- Create: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKDebug.gd`
- Create: `.check/project/tests/test_debug.gd`
- Modify: `.check/check.ps1:105` (массив `$tests`)

**Interfaces:**
- Produces (static):
  - `VTKDebug.LOG_PATH: String` = `"user://MCM/thermal-vtk/debug.log"`
  - `VTKDebug.enabled: bool`
  - `VTKDebug.set_enabled(v: bool) -> void`
  - `VTKDebug.log(tag: String, msg: String) -> void`
  - `VTKDebug.fmt(tag: String, msg: String) -> String` → `"[TAG] msg"`
  - `VTKDebug.reset_for_tests() -> void`

- [ ] **Step 1: Write the failing test**

Create `.check/project/tests/test_debug.gd`:

```gdscript
extends SceneTree

const Dbg = preload("res://mods/ThermalVTK/VTKDebug.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _init() -> void:
	process_frame.connect(_run)

func _wipe() -> void:
	if FileAccess.file_exists(Dbg.LOG_PATH):
		DirAccess.remove_absolute(Dbg.LOG_PATH)

func _run() -> void:
	Dbg.reset_for_tests()
	_wipe()
	t_fmt()
	t_disabled_writes_nothing()
	_wipe()
	t_enabled_creates_and_appends()
	Dbg.reset_for_tests()
	_wipe()
	print("")
	if fails == 0:
		print("Debug tests passed")
		quit(0)
	else:
		print("Debug tests failed: ", fails)
		quit(1)

func t_fmt() -> void:
	ck(Dbg.fmt("ESP", "x") == "[ESP] x", "fmt composes [TAG] msg")

# The gate must stop the file from ever being created, not just stop writes.
func t_disabled_writes_nothing() -> void:
	Dbg.set_enabled(false)
	Dbg.log("ESP", "should not create")
	ck(not FileAccess.file_exists(Dbg.LOG_PATH), "disabled log creates no file")

func t_enabled_creates_and_appends() -> void:
	Dbg.set_enabled(true)
	Dbg.log("ESP", "hello")
	ck(FileAccess.file_exists(Dbg.LOG_PATH), "enabled log creates file")
	var txt := ""
	if FileAccess.file_exists(Dbg.LOG_PATH):
		var f := FileAccess.open(Dbg.LOG_PATH, FileAccess.READ)
		if f != null:
			txt = f.get_as_text()
			f.close()
	ck(txt.contains("[ESP] hello"), "file holds the logged line")
	ck(txt.contains("session start"), "file holds a session header")
```

- [ ] **Step 2: Register the test**

In `.check/check.ps1:105`, append to the `$tests` array (keep existing entries), so the line reads:

```powershell
$tests = @("res://tests/test_picker.gd", "res://tests/test_draft.gd", "res://tests/test_hooks.gd", "res://tests/test_notes.gd", "res://tests/test_deposits.gd", "res://tests/test_feed.gd", "res://tests/test_spawn.gd", "res://tests/test_items.gd", "res://tests/test_data.gd", "res://tests/test_equip.gd", "res://tests/test_composite.gd", "res://tests/test_travel.gd", "res://tests/test_config.gd", "res://tests/test_session.gd", "res://tests/test_seasons.gd", "res://tests/test_states.gd", "res://tests/test_tracker.gd", "res://tests/test_shaders.gd", "res://tests/test_outline.gd", "res://tests/test_debug.gd")
```

(Only the trailing `, "res://tests/test_debug.gd"` is the change; copy the existing list verbatim and add the new entry. If the on-disk list differs from the line above, add just the new element to whatever is there.)

- [ ] **Step 3: Run the test to verify it fails**

Run from `D:\RTVMOD`:

```
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```

Expected: under `--- test_debug.gd ---` a load/parse error (`Failed to load script` / `Parse Error`) → `VERDICT: FAIL test_debug.gd`, because `VTKDebug.gd` does not exist yet.

- [ ] **Step 4: Write the implementation**

Create `standalone mods/ThermalVTK/mods/ThermalVTK/VTKDebug.gd` (tabs, CRLF):

```gdscript
extends RefCounted
# Single diagnostic-log sink for ThermalVTK. Every probe funnels through log(),
# so the enable gate and the file handle live in exactly one place. Off by
# default; turned on from the MCM "Debug log" option.

const LOG_PATH := "user://MCM/thermal-vtk/debug.log"

static var enabled := false
static var _file: FileAccess = null

static func set_enabled(v: bool) -> void:
	enabled = v
	if enabled:
		_open()

static func _open() -> void:
	if _file != null:
		return
	DirAccess.make_dir_recursive_absolute("user://MCM/thermal-vtk")
	# WRITE_READ, not READ_WRITE: READ_WRITE refuses to create a missing file,
	# WRITE_READ creates it and still does not truncate, so sessions append.
	_file = FileAccess.open(LOG_PATH, FileAccess.WRITE_READ)
	if _file == null:
		push_warning("[ThermalVTK] cannot open debug log %s err=%s" % [LOG_PATH, FileAccess.get_open_error()])
		return
	_file.seek_end()
	_file.store_line("=== session start %s v%s ===" % [_now_str(), _version()])
	_file.flush()

static func log(tag: String, msg: String) -> void:
	if not enabled:
		return
	_open()
	var line := "[%s]%s" % [_now_str(), fmt(tag, msg)]
	if _file != null:
		_file.store_line(line)
		_file.flush()
	print(line)

static func fmt(tag: String, msg: String) -> String:
	return "[%s] %s" % [tag, msg]

static func reset_for_tests() -> void:
	enabled = false
	if _file != null:
		_file.close()
		_file = null

static func _now_str() -> String:
	var dt := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d %02d:%02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]

static func _version() -> String:
	var vf := FileAccess.open("res://mods/ThermalVTK/version.txt", FileAccess.READ)
	if vf == null:
		return "?"
	var v := vf.get_as_text().strip_edges()
	return v if v != "" else "?"
```

- [ ] **Step 5: Run to verify it passes**

```
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```

Expected: `ok ThermalVTK/VTKDebug.gd` in the parse section; `VERDICT: ok test_debug.gd`; final `tests passed`; exit code 0.

- [ ] **Step 6: Commit** `[skip]`

```
git add "standalone mods/ThermalVTK/mods/ThermalVTK/VTKDebug.gd" ".check/project/tests/test_debug.gd" ".check/check.ps1"
git commit -m "feat(thermalvtk): add shared debug-log sink"
```

---

### Task 2: MCM-тумблер `05. Diagnostics`

**Files:**
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/ThermalVTK.gd` (preload; новая категория после `CAT4`; вызов в `_mcm_apply`)

**Interfaces:**
- Consumes: `VTKDebug.set_enabled(v: bool) -> void`

- [ ] **Step 1: Preload the sink**

After the two existing preloads at the top (`const Paths = ...`, `const States = ...`) add:

```gdscript
const Dbg = preload("res://mods/ThermalVTK/VTKDebug.gd")
```

- [ ] **Step 2: Add the MCM category and key**

In `_register_mcm`, immediately after the `var CAT4 := "04. Contour Range"` block (after the `outline_through_walls` `set_value`) and before `cfg.set_value("Info", "version", _mod_version())`, insert:

```gdscript
	var CAT5 := "05. Diagnostics"
	cfg.set_value("Bool", "debug_log", {"name": "Debug log", "default": false, "value": false, "category": CAT5, "menu_pos": 0, "tooltip": "Write a diagnostic log of the contour ESP to user://MCM/thermal-vtk/debug.log. For troubleshooting; leave off for normal play."})
```

- [ ] **Step 3: Wire the toggle in `_mcm_apply`**

In `_mcm_apply`, right after the block that loads the config when it is empty:

```gdscript
	if cfg.get_sections().is_empty() and FileAccess.file_exists(CONFIG_FILE):
		cfg.load(CONFIG_FILE)
```

and before `_ensure_nvg()`, insert:

```gdscript
	VTKDebug.set_enabled(bool(_mcm_key_val(cfg, "Bool", "debug_log", false)))
```

- [ ] **Step 4: Run the parse stand**

```
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```

Expected: `ok ThermalVTK/ThermalVTK.gd`; whole run green; exit 0.

- [ ] **Step 5: Commit** `[skip]`

```
git add "standalone mods/ThermalVTK/mods/ThermalVTK/ThermalVTK.gd"
git commit -m "feat(thermalvtk): add Debug log MCM option"
```

---

### Task 3: Пробы в `VTKESP.gd`

**Files:**
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKESP.gd`

**Interfaces:**
- Consumes: `VTKDebug.log(tag: String, msg: String) -> void`

- [ ] **Step 1: Preload + summary fields**

After `const WeaponOcclusion = preload(...)` add:

```gdscript
const Dbg = preload("res://mods/ThermalVTK/VTKDebug.gd")
```

After `var _player: Node3D = null` add:

```gdscript
var _dbg_cd: float = 0.0
var _dbg_cand: int = 0
var _dbg_keep: int = 0
var _dbg_applied: int = 0
```

- [ ] **Step 2: Enable toggle event**

Replace `set_enabled` with:

```gdscript
func set_enabled(on: bool) -> void:
	if enabled == on:
		return
	enabled = on
	Dbg.log("ESP", "esp enabled=%s" % str(on))
	if not enabled:
		_outline.clear_all()
		_entries.clear()
```

- [ ] **Step 3: Hook-presence event**

At the top of `_register_hooks` (before the existing `if not Engine.has_meta("RTVModLib"): return`), insert:

```gdscript
	if not Engine.has_meta("RTVModLib"):
		Dbg.log("ESP", "hooks: RTVModLib absent, polling fallback")
		return
	Dbg.log("ESP", "hooks: RTVModLib present")
```

and delete the now-duplicated original `if not Engine.has_meta("RTVModLib"): return` that followed.

- [ ] **Step 4: Registration / state / death events**

At the end of `_register` (after `_entries[id]["node"] = node`) add:

```gdscript
	Dbg.log("ESP", "register id=%d nomad=%s name=%s" % [id, str(nomad), node.name])
```

In `_on_ai_deactivate`, add a log after the erase:

```gdscript
func _on_ai_deactivate() -> void:
	var n := _caller()
	if is_instance_valid(n):
		_entries.erase(n.get_instance_id())
		Dbg.log("ESP", "deactivate id=%d" % n.get_instance_id())
```

In `_on_ai_changestate`, after `Tracker.apply_state(_entries[id], _read_state(n))` add:

```gdscript
		Dbg.log("ESP", "changestate id=%d state=%d" % [id, _read_state(n)])
```

In `_on_ai_death`, after `Tracker.mark_dead(_entries[id], _now())` add:

```gdscript
		Dbg.log("ESP", "death id=%d" % id)
```

- [ ] **Step 5: Per-frame summary**

Replace `_process` with:

```gdscript
func _process(delta: float) -> void:
	if not enabled:
		return
	_weapon.tick()
	_frame += 1
	if not _pending.is_empty():
		for node_id in _pending:
			var n := instance_from_id(node_id)
			if n != null and is_instance_valid(n):
				_scan(n)
		_pending.clear()

	var ppos_v = _player_pos()
	if ppos_v == null:
		_dbg_tick(delta, "no player in group Player")
		return
	var ppos: Vector3 = ppos_v
	_draw(ppos)
	_dbg_tick(delta, "entries=%d cand=%d keep=%d applied=%d ppos=%.1f,%.1f,%.1f" % [_entries.size(), _dbg_cand, _dbg_keep, _dbg_applied, ppos.x, ppos.y, ppos.z])

func _dbg_tick(delta: float, msg: String) -> void:
	_dbg_cd -= delta
	if _dbg_cd > 0.0:
		return
	_dbg_cd = 1.0
	Dbg.log("ESP", msg)
```

- [ ] **Step 6: Draw counters**

Replace the final loop of `_draw` with:

```gdscript
	var applied := 0
	for id in keep:
		if not valid.has(id) or not _entries.has(id):
			continue
		var e: Dictionary = _entries[id]
		var node = e.get("node")
		var opts: Dictionary = opts_by_id[id]
		if not _outline.has(id):
			_outline.apply(id, node, opts)
		else:
			_outline.refresh(id, opts)
		applied += 1
	_dbg_cand = cands.size()
	_dbg_keep = keep.size()
	_dbg_applied = applied
```

- [ ] **Step 7: Run the stand**

```
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```

Expected: `ok ThermalVTK/VTKESP.gd`; all tests green; exit 0.

- [ ] **Step 8: Commit** `[skip]`

```
git add "standalone mods/ThermalVTK/mods/ThermalVTK/VTKESP.gd"
git commit -m "feat(thermalvtk): probe ESP discovery and draw in debug log"
```

---

### Task 4: Пробы в `VTKOutline.gd`

**Files:**
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKOutline.gd`

**Interfaces:**
- Consumes: `VTKDebug.log(tag: String, msg: String) -> void`
- Changes internal signatures: `_recollect(id: int, entry: Dictionary)`, `_set_wall(id: int, entry: Dictionary, wall: bool)` (both called only from `refresh`).

- [ ] **Step 1: Preload**

After `const States = preload(...)` add:

```gdscript
const Dbg = preload("res://mods/ThermalVTK/VTKDebug.gd")
```

- [ ] **Step 2: Probe `apply`**

Replace the head of `apply` (the `_collect` + empty guard) with:

```gdscript
func apply(id: int, node: Node, opts: Dictionary) -> void:
	var meshes: Array = []
	_collect(node, meshes)
	if meshes.is_empty():
		Dbg.log("OUTLINE", "apply id=%d meshes=0 child_count=%d" % [id, node.get_child_count()])
		return
	Dbg.log("OUTLINE", "apply id=%d meshes=%d child_count=%d" % [id, meshes.size(), node.get_child_count()])
```

- [ ] **Step 3: Probe `_recollect` (add `id` param + delta log)**

Replace `_recollect` with:

```gdscript
func _recollect(id: int, entry: Dictionary) -> void:
	var node = entry.get("node")
	if node == null or not is_instance_valid(node):
		return
	var before := int(entry.get("child_count", -1))
	for m in entry.get("meshes", []):
		if is_instance_valid(m):
			(m as GeometryInstance3D).material_overlay = null
	var fresh: Array = []
	_collect(node, fresh)
	Dbg.log("OUTLINE", "recollect id=%d child_count=%d->%d meshes=%d" % [id, before, node.get_child_count(), fresh.size()])
	if fresh.is_empty():
		return
	var body_mat: ShaderMaterial = entry["body"]
	for m in fresh:
		(m as GeometryInstance3D).material_overlay = body_mat
	entry["meshes"] = fresh
	entry["child_count"] = node.get_child_count()
```

- [ ] **Step 4: Probe `_set_wall` (add `id` param + log)**

Replace `_set_wall` with:

```gdscript
func _set_wall(id: int, entry: Dictionary, wall: bool) -> void:
	if bool(entry.get("wall", wall)) == wall:
		return
	(entry["body"] as ShaderMaterial).shader = Shaders.body(wall)
	(entry["ring"] as ShaderMaterial).shader = Shaders.ring(wall)
	entry["wall"] = wall
	Dbg.log("OUTLINE", "wall id=%d through=%s" % [id, str(wall)])
```

- [ ] **Step 5: Update the two calls in `refresh`**

In `refresh`, change:

```gdscript
		_recollect(entry)
```
to
```gdscript
		_recollect(id, entry)
```
and
```gdscript
	_set_wall(entry, bool(opts.get("through_walls", true)))
```
to
```gdscript
	_set_wall(id, entry, bool(opts.get("through_walls", true)))
```

- [ ] **Step 6: Run the stand**

```
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```

Expected: `ok ThermalVTK/VTKOutline.gd`; `test_outline.gd` still green; exit 0.

- [ ] **Step 7: Commit** `[skip]`

```
git add "standalone mods/ThermalVTK/mods/ThermalVTK/VTKOutline.gd"
git commit -m "feat(thermalvtk): probe outline mesh collection in debug log"
```

---

### Task 5: Проба в `VTKWeaponOcclusion.gd`

**Files:**
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKWeaponOcclusion.gd`

**Interfaces:**
- Consumes: `VTKDebug.log(tag: String, msg: String) -> void`

- [ ] **Step 1: Preload + counters**

After the leading comment block (before `var _last_scene_id`) add:

```gdscript
const Dbg = preload("res://mods/ThermalVTK/VTKDebug.gd")
```

After `var _patched_base: Dictionary = {}` add:

```gdscript
var _dbg_patched: int = 0
var _dbg_layer_skip: int = 0
```

- [ ] **Step 2: Reset counters on scene change**

In `tick`, inside the `if sid != _last_scene_id:` block, after `_patched_base.clear()` add:

```gdscript
		_dbg_patched = 0
		_dbg_layer_skip = 0
```

- [ ] **Step 3: Count layer skips and patches**

In `_patch_mesh`, replace the layer guard with:

```gdscript
	if (mesh.layers & 2) == 0:
		_dbg_layer_skip += 1
		return
```

and at the end of `_patch_mesh` (after the `for i in count:` loop) add:

```gdscript
	_dbg_patched += count
```

- [ ] **Step 4: One summary on attach, one on miss**

In `_setup`, inside the player loop right before its `return` (after `for child in mgr.get_children(): _patch_rig(child)`) add:

```gdscript
		Dbg.log("WEAPON", "occlusion attached rigs=%d patched=%d layer_skipped=%d" % [mgr.get_child_count(), _dbg_patched, _dbg_layer_skip])
```

At function end of `_setup` (reached when no player camera manager is found) add:

```gdscript
	Dbg.log("WEAPON", "occlusion: no player camera manager found")
```

- [ ] **Step 5: Run the parse stand**

```
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```

Expected: `ok ThermalVTK/VTKWeaponOcclusion.gd`; whole run green; exit 0.

- [ ] **Step 6: Commit** `[skip]`

```
git add "standalone mods/ThermalVTK/mods/ThermalVTK/VTKWeaponOcclusion.gd"
git commit -m "feat(thermalvtk): probe weapon-occlusion patching in debug log"
```

---

### Task 6: Версия, CHANGELOG, сборка, установка

**Files:**
- Modify: `standalone mods/ThermalVTK/mod.txt`
- Modify: `standalone mods/ThermalVTK/CHANGELOG.md`
- Build: `standalone mods/ThermalVTK/pack.ps1`

- [ ] **Step 1: Bump version**

In `mod.txt` change `version="1.2.1"` → `version="1.3.0"`.

- [ ] **Step 2: CHANGELOG**

Add at the top of `CHANGELOG.md`, above the current first release section:

```markdown
## [1.3.0] - 2026-10-19

### Added
- "Debug log" option under Diagnostics: writes a diagnostic log of the contour ESP to a file, for troubleshooting.
```

- [ ] **Step 3: Pack**

```
powershell -ExecutionPolicy Bypass -File "standalone mods\ThermalVTK\pack.ps1"
```

Expected: `Version in mod.txt: 1.3.0`, `README version synced to 1.3.0`, `Pack done: ... (N entries, .. KB)`.

- [ ] **Step 4: Install**

```
Copy-Item -LiteralPath "D:\RTVMOD\standalone mods\ThermalVTK\ThermalVTK.vmz" -Destination "D:\SteamLibrary\steamapps\common\Road to Vostok\mods" -Force
```

- [ ] **Step 5: In-game verification**

1. Enable «Debug log» in MCM → `05. Diagnostics`.
2. Enter a raid, stay in mode A, approach a hostile NPC.
3. Read `%APPDATA%\Road to Vostok\MCM\thermal-vtk\debug.log`.
4. Confirm: `session start ... v1.3.0`, `hooks: RTVModLib ...`, `esp enabled=true`, `register id=... nomad=...`, per-second `entries=... cand=... keep=... applied=...`, and `apply id=... meshes=<n>` with `n > 0`. A `meshes=0` line names the failure directly.

- [ ] **Step 6: Commit** `[skip]`

```
git add "standalone mods/ThermalVTK/mod.txt" "standalone mods/ThermalVTK/CHANGELOG.md" "standalone mods/ThermalVTK/mods/ThermalVTK/version.txt" "standalone mods/ThermalVTK/README.md"
git commit -m "release(thermalvtk): 1.3.0 debug log"
```

---

## Self-Review

**Spec coverage:**
- Каркас `VTKDebug.gd` (static `enabled`/`_file`/`set_enabled`/`log`/`fmt`/`reset`) → Task 1.
- Файл+консоль, append (`WRITE_READ`/`seek_end`), `push_warning` на промах открытия → Task 1 Step 4.
- MCM `05. Diagnostics` + `set_enabled` в `_mcm_apply`; по умолчанию молчит → Task 2.
- Пробы ESP (enable/register/deactivate/changestate/death/hooks/сводка/no-player) → Task 3.
- Пробы Outline (apply + `meshes=0`, recollect delta, wall flip) → Task 4.
- Проба WeaponOcclusion (attached / no parent, счётчики слоя) → Task 5.
- Тест `test_debug.gd` (fmt, gate создаёт файл/нет, шапка) + регистрация в `$tests` + очистка файла → Task 1.
- Версия 1.3.0 + CHANGELOG + pack + install → Task 6.

**Placeholder scan:** нет TBD/TODO; каждый шаг содержит точный код и команду.

**Type consistency:** `fmt(tag, msg) -> String`; `log(tag, msg) -> void`; `set_enabled(bool)`; `reset_for_tests()`; MCM-ключ `debug_log` (Bool). `_set_wall`/`_recollect` получили `id: int` первым параметром — обновлены и объявления, и оба вызова в `refresh`.

**Открытый нюанс (вне спеки):** `_setup` в Task 5 вызывает `Dbg.log(... "no player camera manager found")` из `tick()`, который до первого успешного attach исполняется каждый кадр, — строка может спамить, пока менеджер не найден. Если это окажется шумно, добавить одноразовый флаг как в основном моде; сейчас не требуется.
