# Batch 5 cleanup — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove dead debug logging, dead helpers, dead branches and magic numbers from the approved ✅ items of the 4.17.1 audit, in `VTKTravel.gd`, `VTKHooks.gd`, `VTKFeed.gd`, with strictly no behavior change; version `4.17.1 → 4.17.2`.

**Architecture:** Pure deletion/refactor in three files. VTKTravel is split into four sequential tasks so each diff is small and reviewable: (1) strip every `_log`/`_log_reset` call site and the locals they orphan, (2) delete the log subsystem itself (`TRAVEL_LOG`, state vars, `_log_reset`, `_log`), (3) delete the three now-uncalled helpers (`_monitor_placement`, `_dump_subtree`, `_ray_floor`) plus the one surviving call, (4) drop the `FileAccess` shelter fallback (V1e) and the `playerVector` write (V12). VTKHooks is three independent tasks (V2 death dump, V6a weapon probe, V13/V6c constants + early-out). Feed is one task (V6b). A final docs task bumps the version.

**Tech Stack:** Godot 4.6.3 (GDScript, tabs, LF), PowerShell stand `.check/check.ps1` (parse + 9 headless tests), Python stand `.check/layout_check.py` (source-layout symbols).

## Global Constraints

- Indent in `.gd` is **tabs only**; `VTKTravel.gd`, `VTKHooks.gd`, `VTKFeed.gd` are **LF** (`\n`, no CR). Use `edit` (preserves EOL); never rewrite a file with an external LF/CRLF converter.
- Encoding **UTF-8**. The only Russian text touched is the H4 comment; copy it byte-for-byte from this plan.
- **No test changes.** `.check/project/tests/*` is untouched. Header comment of the batch: «don't change test expectations».
- **No behavior change** on any surviving path (public API, signals, saved data, UI, MCM keys). Deletions only; no renames; no reformatting beyond the deleted/edited lines; no new comments except the H4 comment rewrite.
- **Version** (`loadouts/mod.txt`) is bumped **only in Task 9**. No other task edits `mod.txt` or `CHANGELOG.md`.
- **Gate after every task** (Godot must be in PATH; otherwise pass `-Godot "<path to Godot_*_console.exe>"` to `check.ps1`):
  - `python .check\layout_check.py` → exit code 0, all-zero GONE/PRESENT/FUNCS/HOOKS_GONE failures.
  - `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1` → exit code 0, a line containing `tests passed`, and **none** of the strings `SCRIPT ERROR`, `Parse Error`, `Invalid call`, `Failed to load script`. Expect `9 file(s)` of tests.
  - In this environment `python` may be a stub; fall back to `py .check\layout_check.py`.
- No new headless tests: this batch adds no pure logic (deletions and constant extraction). The two stand gates are the whole safety net; TDD's "failing test first" does not apply to a no-behavior-change refactor.
- Files changing together per task are committed together; one commit per task after the green gate. Commit messages in repo style (`type: lowercase description`).
- `.check/` and `docs/superpowers/` are **outside git** (`.gitignore`). Never commit them. Commit only `loadouts/**` (and, in Task 9, `CHANGELOG.md`).
- Anchors below are line numbers **at 4.17.1** and shift as edits apply. After each applied edit, re-locate by the unique snippet, never by line number.
- Blocked items V10a (`_wipe_saves_for_restart` + else-call) and V10b (restart `shelter`/`permadeath` writes) are **out of scope**: their deletion would fail `test_hooks.gd:284` / `:304`. Do not touch `VTKHooks.gd:1418-1480` beyond what each task states.

---

## File Structure

- `loadouts/mods/VTK/VTKTravel.gd` — Tasks 1–4 (logging subsystem, dead helpers, shelter fallback, playerVector write).
- `loadouts/mods/VTK/VTKHooks.gd` — Tasks 5–7 (death dump, weapon-name probe, timing consts + controller early-out).
- `loadouts/mods/VTK/VTKFeed.gd` — Task 8 (`_process` early-out).
- `loadouts/mod.txt`, `CHANGELOG.md` — Task 9 (version + roll-up line).

Task order is a prerequisite chain within each file; tasks across files are independent. Execute in listed order for a clean build at every checkpoint.

---

## Task 1: VTKTravel — strip `_log`/`_log_reset` call sites (V1a, part 1)

**Files:**
- Modify: `loadouts/mods/VTK/VTKTravel.gd`

**Interfaces:**
- Consumes: existing `_log(String)` / `_log_reset()` (definitions stay until Task 2).
- Produces: nothing. Calls into `_controller`, `_face_trader`, `_ray_floor_hit`, `_collect_rids`, `_node_forward` unchanged.

- [ ] **Step 1: `_teleport_internal` — delete the logging lines only.**

Delete exactly these lines (control flow and every `_message(...)` stay byte-identical):

```gdscript
	_log_reset()
	_teleport_started_ms = Time.get_ticks_msec()
```

```gdscript
	_log("teleport start -> " + target_map + " (from " + actual_current + ", offset kind=" + str(typeof(final_offset)) + ")")
```

```gdscript
		_log("FAIL scene never changed for " + target_map)
```

```gdscript
	_log("scene changed detected")
```

```gdscript
		_log("FAIL: map never became ready for " + target_map)
```

```gdscript
		_log("resolved offset Vector3 " + str(point))
```

```gdscript
		_log("FAIL trader " + dest_label + ": landing point NOT resolved (" + str(typeof(point)) + "), player left at map spawn")
```

```gdscript
		_log("resolved offset is NOT Vector3 (" + str(typeof(point)) + "), player NOT moved")
```

```gdscript
	_log("teleport done -> " + dest)
```

- [ ] **Step 2: `_save_before_transition` — remove logs and the orphaned `shelter` local.**

Replace the whole function (was lines 175-186):

```gdscript
func _save_before_transition(target_map: String, loader: Node) -> void:
	if loader == null or not loader.has_method("SaveCharacter"):
		_log("pre-transition save: Loader.SaveCharacter unavailable")
		return
	var iface := get_node_or_null(Paths.INTERFACE)
	if iface == null:
		_log("pre-transition save: Interface missing, skipping")
		return
	var shelter := game_data != null and bool(game_data.get("shelter"))
	_log("pre-transition save: shelter=" + str(shelter) + " -> " + target_map + " (grids still live, saving BEFORE scene change)")
	loader.call("SaveCharacter")
	_log("pre-transition save: done")
```

with:

```gdscript
func _save_before_transition(target_map: String, loader: Node) -> void:
	if loader == null or not loader.has_method("SaveCharacter"):
		return
	var iface := get_node_or_null(Paths.INTERFACE)
	if iface == null:
		return
	loader.call("SaveCharacter")
```

(`target_map` stays as an unused parameter — legal GDScript, keeps the signature.)

- [ ] **Step 3: `_close_interfaces` — remove debug locals and logs.**

Replace (was lines 230-246, from `var ui` through the `else` log):

```gdscript
	var ui := get_node_or_null(Paths.UI)
	var iface := get_node_or_null(Paths.INTERFACE)
	var gd_iface := "n/a"
	if game_data != null:
		gd_iface = str(game_data.get("interface"))
	var iface_vis := "n/a"
	if iface != null:
		iface_vis = str(iface.visible)
	_log("close_interfaces: ui_found=" + str(ui != null) + " has_ToggleInterface=" + str(ui != null and ui.has_method("ToggleInterface")) + " Interface.visible=" + iface_vis + " gameData.interface=" + gd_iface)
	if iface != null and iface.has_method("Close"):
		iface.call("Close")
		_log("close_interfaces: called Interface.Close() (deterministic)")
	elif ui != null and ui.has_method("ToggleInterface"):
		ui.call("ToggleInterface")
		_log("close_interfaces: FALLBACK blind ToggleInterface (Interface.Close unavailable)")
	else:
		_log("close_interfaces: nothing to close")
```

with:

```gdscript
	var ui := get_node_or_null(Paths.UI)
	var iface := get_node_or_null(Paths.INTERFACE)
	if iface != null and iface.has_method("Close"):
		iface.call("Close")
	elif ui != null and ui.has_method("ToggleInterface"):
		ui.call("ToggleInterface")
```

- [ ] **Step 4: `_trader_point` — remove logs, collapse the empty `else`, drop orphaned `ctrl`/`ref_floor`/`map_name`.**

Replace the whole function (was lines 285-336):

```gdscript
func _trader_point(entry: Dictionary) -> Vector3:
	var fallback := Vector3.ZERO
	if entry.has("pos"):
		var raw = entry["pos"]
		if raw is Vector3:
			fallback = raw
	var trader_name := String(entry.get("name", ""))
	var node := find_trader(trader_name)
	var anchor: Vector3 = fallback
	if node != null:
		anchor = node.global_position
		_log("trader " + trader_name + ": node at " + str(anchor))
		_log("trader " + trader_name + ": tree " + _dump_subtree(node, 0))
	else:
		_log("trader " + trader_name + ": node NOT found by name+Trader.gd, using hardcoded fallback " + str(fallback))
	var ctrl := _controller()
	_log("trader " + trader_name + ": controller " + ("present at " + str(ctrl.global_position) if ctrl != null else "NULL"))
	var facing := _node_forward(node)
	_log("trader " + trader_name + ": facing " + str(facing) + " rot=" + (str((node as Node3D).global_rotation) if node is Node3D else "n/a"))
	_look_at = anchor
	_has_look_at = true
	var ctrl2 := _controller()
	if ctrl2 == null:
		var raw2 := anchor + facing * TRADER_STAND_DISTANCE
		_log("trader " + trader_name + ": controller NULL, cannot place near trader, using raw probe " + str(raw2))
		return raw2
	var space := ctrl2.get_world_3d().direct_space_state
	var exclude: Array = [ctrl2.get_rid()]
	if node != null:
		_collect_rids(node, exclude)
	var ref_floor := _ray_floor(space, exclude, anchor)
	_log("trader " + trader_name + ": floor under trader y=" + str(ref_floor) + " (anchor y=" + str(anchor.y) + ")")
	var stand_dir := -facing
	_log("trader " + trader_name + ": stand dir " + str(stand_dir))
	for dist in [TRADER_STAND_DISTANCE, 2.5, 3.0, 1.5]:
		var cand: Vector3 = anchor + stand_dir * float(dist)
		var hit := _ray_floor_hit(space, exclude, cand)
		if not hit.is_empty():
			var hp: Vector3 = hit["position"]
			_log("trader " + trader_name + ": STAND " + str(hp) + " at dist " + str(dist) + " dir " + str(stand_dir))
			return hp
	for step in range(12):
		var ang := TAU * float(step) / 12.0
		var cand2: Vector3 = anchor + Vector3(cos(ang), 0.0, sin(ang)) * TRADER_STAND_DISTANCE
		var hit2 := _ray_floor_hit(space, exclude, cand2)
		if not hit2.is_empty():
			var hp2: Vector3 = hit2["position"]
			_log("trader " + trader_name + ": STAND ring " + str(hp2) + " step " + str(step))
			return hp2
	var map_name := String(entry.get("map", ""))
	_log("no floor near " + trader_name + " on " + map_name + "; using trader altitude " + str(anchor))
	return anchor + stand_dir * TRADER_STAND_DISTANCE
```

with:

```gdscript
func _trader_point(entry: Dictionary) -> Vector3:
	var fallback := Vector3.ZERO
	if entry.has("pos"):
		var raw = entry["pos"]
		if raw is Vector3:
			fallback = raw
	var trader_name := String(entry.get("name", ""))
	var node := find_trader(trader_name)
	var anchor: Vector3 = fallback
	if node != null:
		anchor = node.global_position
	var facing := _node_forward(node)
	_look_at = anchor
	_has_look_at = true
	var ctrl2 := _controller()
	if ctrl2 == null:
		var raw2 := anchor + facing * TRADER_STAND_DISTANCE
		return raw2
	var space := ctrl2.get_world_3d().direct_space_state
	var exclude: Array = [ctrl2.get_rid()]
	if node != null:
		_collect_rids(node, exclude)
	var stand_dir := -facing
	for dist in [TRADER_STAND_DISTANCE, 2.5, 3.0, 1.5]:
		var cand: Vector3 = anchor + stand_dir * float(dist)
		var hit := _ray_floor_hit(space, exclude, cand)
		if not hit.is_empty():
			var hp: Vector3 = hit["position"]
			return hp
	for step in range(12):
		var ang := TAU * float(step) / 12.0
		var cand2: Vector3 = anchor + Vector3(cos(ang), 0.0, sin(ang)) * TRADER_STAND_DISTANCE
		var hit2 := _ray_floor_hit(space, exclude, cand2)
		if not hit2.is_empty():
			var hp2: Vector3 = hit2["position"]
			return hp2
	return anchor + stand_dir * TRADER_STAND_DISTANCE
```

(Forced orphans: `ctrl` was only read by a log; `ref_floor`→`_ray_floor(...)` fed only a log; `map_name` fed only the final log. All three are deleted. The `_dump_subtree` call disappears with its enclosing log line; the function itself stays until Task 3.)

- [ ] **Step 5: `_await_map_ready` — delete one log line.**

Delete:

```gdscript
	_log("map ready: isCaching=" + str(caching) + " after " + str(guard) + " cached frames")
```

Keep the `var caching := ...` line, the `if caching: return false`, the awaits and the final `return is_inside_tree()`.

- [ ] **Step 6: `_place_player` — delete the two log lines only.**

Replace (was lines 405-417):

```gdscript
func _place_player(target: Vector3) -> void:
	var ctrl := _controller()
	if ctrl == null:
		_log("place_player: controller NULL, player NOT moved (target was " + str(target) + ")")
		return
	ctrl.global_position = target
	ctrl.set("velocity", Vector3.ZERO)
	if game_data != null:
		game_data.set("playerVector", Vector3.ZERO)
	_log("place_player: moved controller to " + str(target) + ", readback=" + str(ctrl.global_position))
	if _has_look_at:
		_face_trader(ctrl, _look_at)
	_monitor_placement(target, ctrl)
```

with:

```gdscript
func _place_player(target: Vector3) -> void:
	var ctrl := _controller()
	if ctrl == null:
		return
	ctrl.global_position = target
	ctrl.set("velocity", Vector3.ZERO)
	if game_data != null:
		game_data.set("playerVector", Vector3.ZERO)
	if _has_look_at:
		_face_trader(ctrl, _look_at)
	_monitor_placement(target, ctrl)
```

(The `playerVector` write stays here; it is removed in Task 4. The `_monitor_placement` call stays here; it is removed in Task 3.)

- [ ] **Step 7: `_face_trader` — delete logs and the orphaned `zeroed` local.**

Replace (was lines 424-438):

```gdscript
func _face_trader(ctrl: Node3D, trader_pos: Vector3) -> void:
	var d := trader_pos - ctrl.global_position
	d.y = 0.0
	if d.length() < 0.01:
		_log("face: trader too close, yaw untouched")
		return
	var yaw := atan2(-d.x, -d.z)
	var r := ctrl.global_rotation
	ctrl.global_rotation = Vector3(r.x, yaw, r.z)
	var head = ctrl.get("head")
	var zeroed := false
	if head is Node3D:
		(head as Node3D).rotation.y = 0.0
		zeroed = true
	_log("face: yaw=" + str(yaw) + " to " + str(trader_pos) + ", head_yaw_zeroed=" + str(zeroed))
```

with:

```gdscript
func _face_trader(ctrl: Node3D, trader_pos: Vector3) -> void:
	var d := trader_pos - ctrl.global_position
	d.y = 0.0
	if d.length() < 0.01:
		return
	var yaw := atan2(-d.x, -d.z)
	var r := ctrl.global_rotation
	ctrl.global_rotation = Vector3(r.x, yaw, r.z)
	var head = ctrl.get("head")
	if head is Node3D:
		(head as Node3D).rotation.y = 0.0
```

- [ ] **Step 8: `_monitor_placement` — delete its three log lines and the orphaned `vel` local.**

Replace (was lines 441-453):

```gdscript
func _monitor_placement(target: Vector3, ctrl: Node) -> void:
	for step in [0.1, 0.35, 1.0, 3.0]:
		await get_tree().create_timer(step, true, false, true).timeout
		if not is_instance_valid(ctrl):
			_log("monitor: controller became invalid")
			return
		var now: Vector3 = ctrl.global_position
		var drift := now - target
		var vel = ctrl.get("velocity")
		_log("monitor +" + str(step) + "s: pos=" + str(now) + " drift=" + str(drift) + " vel=" + str(vel))
		if drift.length() > 0.5:
			_log("monitor +" + str(step) + "s: DRIFTED from target, something else owns position")
			return
```

with:

```gdscript
func _monitor_placement(target: Vector3, ctrl: Node) -> void:
	for step in [0.1, 0.35, 1.0, 3.0]:
		await get_tree().create_timer(step, true, false, true).timeout
		if not is_instance_valid(ctrl):
			return
		var drift := ctrl.global_position - target
		if drift.length() > 0.5:
			return
```

(The function is deleted whole in Task 3; this step only keeps the tree parsing until then.)

- [ ] **Step 9: Verify (do not skip).**

Run: `python .check\layout_check.py`
Expected: exit 0, all-zero failures.

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: exit 0, `tests passed`, 9 files, no `SCRIPT ERROR` / `Parse Error` / `Invalid call` / `Failed to load script`.

- [ ] **Step 10: Commit.**

```bash
git add loadouts/mods/VTK/VTKTravel.gd
git commit -m "refactor: drop travel debug log call sites"
```

---

## Task 2: VTKTravel — delete the log subsystem definitions (V1a, part 2)

**Files:**
- Modify: `loadouts/mods/VTK/VTKTravel.gd`

**Interfaces:**
- Consumes: nothing (all callers removed in Task 1).
- Produces: nothing. `Log` preload stays (still used by `_message`); `FLOOR_PROBE_UP`/`FLOOR_PROBE_DOWN` stay (used by `_ray_floor_hit`).

- [ ] **Step 1: Delete the const and the two state vars.**

Delete:

```gdscript
const TRAVEL_LOG := "user://loadouts_travel.log"
```

Delete:

```gdscript
var _teleport_started_ms: int = 0
var _log_file: FileAccess = null
```

- [ ] **Step 2: Delete `_log_reset` and `_log`.**

Delete both whole functions (was lines 260-282):

```gdscript
func _log_reset() -> void:
	if _log_file != null:
		_log_file.close()
		_log_file = null
	if FileAccess.file_exists(TRAVEL_LOG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TRAVEL_LOG))


func _log(msg: String) -> void:
	if _log_file == null:
		_log_file = FileAccess.open(TRAVEL_LOG, FileAccess.READ_WRITE)
		if _log_file == null:
			_log_file = FileAccess.open(TRAVEL_LOG, FileAccess.WRITE)
		if _log_file == null:
			Log.log("[VTK] " + msg)
			return
	_log_file.seek_end()
	var elapsed := 0
	if _teleport_started_ms > 0:
		elapsed = Time.get_ticks_msec() - _teleport_started_ms
	_log_file.store_line("[" + Time.get_datetime_string_from_system() + " | +" + str(elapsed) + "ms] " + msg)
	_log_file.flush()
	Log.log("[VTK] " + msg)
```

- [ ] **Step 3: Confirm zero callers remain.**

Run: `Select-String -Path loadouts\mods\VTK\VTKTravel.gd -Pattern '_log\(|_log_reset|TRAVEL_LOG|_log_file|_teleport_started_ms'`
Expected: no output (except none).

- [ ] **Step 4: Verify (do not skip).**

Run: `python .check\layout_check.py` → exit 0.
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1` → exit 0, `tests passed`, 9 files, none of the four error strings.

- [ ] **Step 5: Commit.**

```bash
git add loadouts/mods/VTK/VTKTravel.gd
git commit -m "refactor: delete travel log helpers and state"
```

---

## Task 3: VTKTravel — delete dead helpers (V1b, V1c, V1d)

**Files:**
- Modify: `loadouts/mods/VTK/VTKTravel.gd`

**Interfaces:**
- Consumes: Task 1 (callers removed) — `_dump_subtree` and `_ray_floor` are already uncalled; `_monitor_placement` still has one call.
- Produces: nothing. Survivors `_ray_floor_hit`, `_collect_rids`, `_node_forward` stay.

- [ ] **Step 1: Delete `_ray_floor` (V1d).**

Delete the whole function (was lines 345-349):

```gdscript
func _ray_floor(space: PhysicsDirectSpaceState3D, exclude: Array, point: Vector3) -> float:
	var h := _ray_floor_hit(space, exclude, point)
	if h.is_empty():
		return point.y
	return float((h["position"] as Vector3).y)
```

- [ ] **Step 2: Delete `_dump_subtree` (V1c).**

Delete the whole function (was lines 360-372):

```gdscript
func _dump_subtree(node: Node, depth: int) -> String:
	if depth > 3:
		return ""
	var out := ""
	for ch in node.get_children():
		var pos := ""
		if ch is Node3D:
			pos = "@" + str((ch as Node3D).global_position)
		out += ch.name + "(" + ch.get_class() + pos + ")"
		if ch is Node3D:
			out += "[" + _dump_subtree(ch, depth + 1) + "]"
		out += " "
	return out.strip_edges()
```

- [ ] **Step 3: Delete `_monitor_placement` and its call (V1b).**

Delete the whole function (Task 1 body):

```gdscript
func _monitor_placement(target: Vector3, ctrl: Node) -> void:
	for step in [0.1, 0.35, 1.0, 3.0]:
		await get_tree().create_timer(step, true, false, true).timeout
		if not is_instance_valid(ctrl):
			return
		var drift := ctrl.global_position - target
		if drift.length() > 0.5:
			return
```

Delete the call inside `_place_player`:

```gdscript
	_monitor_placement(target, ctrl)
```

`_place_player` then ends with:

```gdscript
	if _has_look_at:
		_face_trader(ctrl, _look_at)
```

- [ ] **Step 4: Grep sweep.**

Run: `Select-String -Path loadouts\mods\VTK\VTKTravel.gd -Pattern '_monitor_placement|_dump_subtree|_ray_floor'`
Expected: no output (`_ray_floor_hit` is a different name and must **not** be matched).

- [ ] **Step 5: Verify (do not skip).**

Run: `python .check\layout_check.py` → exit 0.
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1` → exit 0, `tests passed`, 9 files, none of the four error strings.

- [ ] **Step 6: Commit.**

```bash
git add loadouts/mods/VTK/VTKTravel.gd
git commit -m "refactor: delete dead travel helpers"
```

---

## Task 4: VTKTravel — drop shelter file fallback and playerVector write (V1e, V12)

**Files:**
- Modify: `loadouts/mods/VTK/VTKTravel.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: `is_shelter_unlocked(shelter_name: String) -> bool` keeps its exact signature; return value now derives only from `Loader.CheckShelterState`.

- [ ] **Step 1: `is_shelter_unlocked` — drop the `FileAccess` fallback (V1e).**

Replace (was lines 61-65):

```gdscript
func is_shelter_unlocked(shelter_name: String) -> bool:
	var loader := _loader()
	if loader != null and loader.has_method("CheckShelterState"):
		return bool(loader.CheckShelterState(shelter_name))
	return FileAccess.file_exists(Paths.SHELTER_SAVE_FMT % shelter_name)
```

with:

```gdscript
func is_shelter_unlocked(shelter_name: String) -> bool:
	var loader := _loader()
	if loader != null and loader.has_method("CheckShelterState"):
		return bool(loader.CheckShelterState(shelter_name))
	return false
```

`Paths.SHELTER_SAVE_FMT` stays in `VTKPaths.gd` (shared const, `VTKPaths.gd` is out of scope).

- [ ] **Step 2: `_place_player` — drop the `playerVector` write (V12).**

Replace:

```gdscript
	ctrl.global_position = target
	ctrl.set("velocity", Vector3.ZERO)
	if game_data != null:
		game_data.set("playerVector", Vector3.ZERO)
	if _has_look_at:
```

with:

```gdscript
	ctrl.global_position = target
	ctrl.set("velocity", Vector3.ZERO)
	if _has_look_at:
```

- [ ] **Step 3: Verify (do not skip).**

Run: `python .check\layout_check.py` → exit 0.
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1` → exit 0, `tests passed`, 9 files, none of the four error strings.

- [ ] **Step 4: Commit.**

```bash
git add loadouts/mods/VTK/VTKTravel.gd
git commit -m "refactor: drop travel shelter file fallback and player vector write"
```

---

## Task 5: VTKHooks — delete the death tree dump (V2)

**Files:**
- Modify: `loadouts/mods/VTK/VTKHooks.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing. `_handle_death_screen` keeps its `waited >= DEATH_FIND_TIMEOUT_MS` early return.

- [ ] **Step 1: Delete the state var.**

Delete:

```gdscript
var _death_dump_at: int = 0
```

(`var _death_probe_at: int = 0` on the next line stays.)

- [ ] **Step 2: Delete the call site.**

In `_handle_death_screen`, delete the tail call. The surrounding block becomes:

```gdscript
	var waited := now - _death_find_since
	if waited >= DEATH_FIND_TIMEOUT_MS:
		_death_gave_up = true
		Log.log("[VTK] No 'Load Game' button after " + str(waited) + "ms; leaving vanilla death screen")
		return
```

- [ ] **Step 3: Delete the whole `_dump_death_tree` function (was lines 1352-1375).**

Delete:

```gdscript
func _dump_death_tree(root: Node, waited: int, now: int) -> void:
	if now - _death_dump_at < 1000:
		return
	_death_dump_at = now
	var lines: Array = []
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is BaseButton:
			var b := n as BaseButton
			var bt := String(b.text).strip_edges()
			lines.append("[VTK]   " + b.get_class() + " path='" + str(b.get_path()) + "' name='" + str(b.name) + "' text='" + bt + "' tip='" + str(b.tooltip_text) + "' vis=" + str(b.visible) + " dis=" + str(b.disabled) + " focus=" + str(b.focus_mode) + " conns=" + str(b.pressed.get_connections().size()))
		elif n is Control:
			var c := n as Control
			var txt := ""
			if "text" in c:
				txt = String(c.get("text"))
			elif c is RichTextLabel:
				txt = String((c as RichTextLabel).get_parsed_text())
			if txt.strip_edges() != "":
				lines.append("[VTK]   " + c.get_class() + " path='" + str(c.get_path()) + "' text='" + txt + "' vis=" + str(c.visible))
		for ch in n.get_children():
			stack.push_back(ch)
	Log.log("[VTK] death tree @" + str(waited) + "ms:\n" + "\n".join(lines))
```

- [ ] **Step 4: Grep sweep.**

Run: `Select-String -Path loadouts\mods\VTK\VTKHooks.gd -Pattern '_dump_death_tree|_death_dump_at'`
Expected: no output.

- [ ] **Step 5: Verify (do not skip).**

Run: `python .check\layout_check.py` → exit 0.
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1` → exit 0, `tests passed`, 9 files, none of the four error strings. `t_death_timeout_gives_up` must stay green.

- [ ] **Step 6: Commit.**

```bash
git add loadouts/mods/VTK/VTKHooks.gd
git commit -m "refactor: drop death tree dump"
```

---

## Task 6: VTKHooks — simplify `_player_weapon_name` (V6a)

**Files:**
- Modify: `loadouts/mods/VTK/VTKHooks.gd`

**Interfaces:**
- Consumes: existing `_rig_weapon_name() -> String`.
- Produces: `_player_weapon_name() -> String` with the same signature (callers at lines 632 and 716 unchanged). `_weapon_str` and `_weapon_name_of` stay (still used).

- [ ] **Step 1: Replace the function and its comment.**

Replace (was lines 733-751):

```gdscript
# Имя оружия игрока: свойства GameData, затем оружие в руках у игрока.
# Список и порядок — из probe-вывода (Task 1, п.3); лишние свойства просто
# не найдутся и вернут "".
func _player_weapon_name() -> String:
	var gd = _resolve_gamedata()
	if gd != null:
		for p in ["currentWeaponName", "weaponName", "currentWeapon", "weapon", "equippedWeapon"]:
			if p in gd:
				var s := _weapon_str(gd.get(p))
				if s != "":
					return s
	var pl = get_tree().get_first_node_in_group("Player")
	if pl != null:
		for p in ["currentWeapon", "activeWeapon", "weapon", "weaponName", "equippedWeapon"]:
			if p in pl:
				var s := _weapon_str(pl.get(p))
				if s != "":
					return s
	return _rig_weapon_name()
```

with:

```gdscript
# Имя оружия игрока: GameData и узел игрока имени не несут (probe, Task 1),
# настоящее оружие — WeaponRig под Camera/Manager, см. _rig_weapon_name().
func _player_weapon_name() -> String:
	return _rig_weapon_name()
```

- [ ] **Step 2: Verify (do not skip).**

Run: `python .check\layout_check.py` → exit 0.
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1` → exit 0, `tests passed`, 9 files, none of the four error strings. `t_player_rig_weapon` must stay green (fixture fakes only the WeaponRig path).

- [ ] **Step 3: Commit.**

```bash
git add loadouts/mods/VTK/VTKHooks.gd
git commit -m "refactor: simplify player weapon name lookup"
```

---

## Task 7: VTKHooks — extract timing consts and skip empty controller purge (V13a, V13b, V6c)

**Files:**
- Modify: `loadouts/mods/VTK/VTKHooks.gd`

**Interfaces:**
- Consumes: `_player_hits`, `_seen_deaths`, `_last_damager` dictionaries.
- Produces: `const DEATH_PROBE_MS := 1000`, `const PLAYER_HITS_TTL_MSEC := 30000`. `_on_controller_process(_delta: float) -> void` signature unchanged (arity 1).

- [ ] **Step 1: Add `PLAYER_HITS_TTL_MSEC` next to the existing TTL consts.**

After:

```gdscript
const HIT_WINDOW_MSEC := 15000
const SEEN_DEATHS_TTL_MSEC := 600000
```

add:

```gdscript
const PLAYER_HITS_TTL_MSEC := 30000
```

- [ ] **Step 2: Add `DEATH_PROBE_MS` above `_death_probe_at`.**

Before:

```gdscript
var _death_probe_at: int = 0
```

add:

```gdscript
const DEATH_PROBE_MS := 1000
```

- [ ] **Step 3: Replace the raw `1000` in `_poll_death`.**

Replace:

```gdscript
			if pnow - _death_probe_at > 1000:
```

with:

```gdscript
			if pnow - _death_probe_at > DEATH_PROBE_MS:
```

- [ ] **Step 4: Add the early-out and replace the raw `30000` in `_on_controller_process`.**

Replace the guard:

```gdscript
func _on_controller_process(_delta: float) -> void:
	var controller = _lib._caller if _lib else null
	if not is_instance_valid(controller):
		return
	var now = Time.get_ticks_msec()
	var stale: Array = []
	for iid in _player_hits:
		if now - int(_player_hits[iid]) > 30000:
```

with:

```gdscript
func _on_controller_process(_delta: float) -> void:
	var controller = _lib._caller if _lib else null
	if not is_instance_valid(controller):
		return
	if _player_hits.is_empty() and _seen_deaths.is_empty() and _last_damager.is_empty():
		return
	var now = Time.get_ticks_msec()
	var stale: Array = []
	for iid in _player_hits:
		if now - int(_player_hits[iid]) > PLAYER_HITS_TTL_MSEC:
```

The three purge loops below are unchanged.

- [ ] **Step 5: Verify (do not skip).**

Run: `python .check\layout_check.py` → exit 0.
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1` → exit 0, `tests passed`, 9 files, none of the four error strings. `t_post_callback_arity` must stay green (signature unchanged).

- [ ] **Step 6: Commit.**

```bash
git add loadouts/mods/VTK/VTKHooks.gd
git commit -m "refactor: extract death and hit timings, skip empty controller purge"
```

---

## Task 8: VTKFeed — early-out on empty feed (V6b)

**Files:**
- Modify: `loadouts/mods/VTK/VTKFeed.gd`

**Interfaces:**
- Consumes: `_rows: Array`.
- Produces: nothing; `_process(delta: float) -> void` signature unchanged.

- [ ] **Step 1: Insert the early-out after the scene-change block.**

Replace:

```gdscript
	var cs = get_tree().current_scene
	if cs != _scene_ref:
		_scene_ref = cs
		clear()
	var in_shelter := false
```

with:

```gdscript
	var cs = get_tree().current_scene
	if cs != _scene_ref:
		_scene_ref = cs
		clear()
	if _rows.is_empty():
		return
	var in_shelter := false
```

The `_enabled` guard above and everything below (shelter read, aging loop) stay as is.

- [ ] **Step 2: Verify (do not skip).**

Run: `python .check\layout_check.py` → exit 0.
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1` → exit 0, `tests passed`, 9 files, none of the four error strings. All `test_feed.gd` cases stay green (it never calls `_process`).

- [ ] **Step 3: Commit.**

```bash
git add loadouts/mods/VTK/VTKFeed.gd
git commit -m "perf: skip feed work when no rows"
```

---

## Task 9: Version bump and changelog (release)

**Files:**
- Modify: `loadouts/mod.txt`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: nothing.
- Produces: `version="4.17.2"` in `loadouts/mod.txt` (MCM reads it at runtime; no code constant duplicates it).

- [ ] **Step 1: Bump the version in `loadouts/mod.txt`.**

Replace:

```
version="4.17.1"
```

with:

```
version="4.17.2"
```

- [ ] **Step 2: Add the 4.17.2 release section to `CHANGELOG.md`.**

Insert above `## [4.17.1] - 2026-10-14`:

```markdown
## [4.17.2] - 2026-10-14

### Changed

- Minor performance improvements and internal cleanup.
```

- [ ] **Step 3: Verify (do not skip).**

Run: `python .check\layout_check.py` → exit 0.
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1` → exit 0, `tests passed`, 9 files, none of the four error strings.

- [ ] **Step 4: Confirm `pack.ps1` prints 4.17.2.**

Run: `powershell -ExecutionPolicy Bypass -File pack.ps1`
Expected: version line reads `4.17.2`; `Loadouts.vmz` rebuilt with no error.

- [ ] **Step 5: Commit.**

```bash
git add loadouts/mod.txt CHANGELOG.md
git commit -m "docs: 4.17.2 changelog and version bump"
```

---

## Self-Review

Run this checklist after the plan is written, against the spec `docs/superpowers/specs/2026-10-14-batch5-cleanup-design.md`.

**1. Spec coverage.** Every in-scope ✅ item maps to a task:

| Spec item | Task |
|---|---|
| V1a (log subsystem + 32 call sites) | Task 1 (call sites) + Task 2 (defs) |
| V1b (`_monitor_placement` + call) | Task 3 |
| V1c (`_dump_subtree` + call) | Task 3 (call removed in Task 1) |
| V1d (`_ray_floor`) | Task 3 (call removed in Task 1) |
| V1e (`is_shelter_unlocked` fallback) | Task 4 |
| V12 (`playerVector` write) | Task 4 |
| V2 (`_dump_death_tree` + call + `_death_dump_at`) | Task 5 |
| V6a (weapon-name probes) | Task 6 |
| V6b (feed `_process` early-out) | Task 8 |
| V6c (`_on_controller_process` early-out) | Task 7 |
| V13a (`DEATH_PROBE_MS`) | Task 7 |
| V13b (`PLAYER_HITS_TTL_MSEC`) | Task 7 |
| version 4.17.2 | Task 9 |
| V10a, V10b | **excluded** (blocked; Global Constraints) |

No ⏸️/⚠️/Bug item is touched; no `VTKUI.gd` `_process` restructuring.

**2. Placeholder scan.** No "TBD"/"TODO"/"handle edge cases"; every step carries the literal snippet or the literal grep/gate command. No "similar to Task N".

**3. Type/name consistency.** Deleted symbols are uniform across tasks: `_log`, `_log_reset`, `TRAVEL_LOG`, `_teleport_started_ms`, `_log_file`, `_dump_subtree`, `_ray_floor`, `_monitor_placement`, `_dump_death_tree`, `_death_dump_at`. Survivors referenced but never deleted: `_ray_floor_hit`, `_collect_rids`, `_node_forward`, `_weapon_str`, `_weapon_name_of`, `_message`, `Log` preload, `FLOOR_PROBE_*`, `_rig_weapon_name`, `Paths.SHELTER_SAVE_FMT` (in `VTKPaths.gd`). New names match the spec: `DEATH_PROBE_MS`, `PLAYER_HITS_TTL_MSEC`.

## Gate Checklist (per task and final)

- [ ] `python .check\layout_check.py` → exit 0, all-zero failures. (Pre-checked: `layout_check.py` lists `GONE`/`PRESENT`/`FUNCS`/`HOOKS_GONE` contain **none** of the deleted symbols; no stand edit needed.)
- [ ] `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1` → exit 0, `tests passed`, 9 file(s), no `SCRIPT ERROR` / `Parse Error` / `Invalid call` / `Failed to load script`.
- [ ] Watch-list tests green **without edits**: `t_player_rig_weapon`, `t_ironman_restart_restores_difficulty`, `t_post_callback_arity`, `t_death_timeout_gives_up`, all `test_feed.gd` cases.
- [ ] Final grep sweep across all three files: `_log(`, `_log_reset`, `TRAVEL_LOG`, `_log_file`, `_teleport_started_ms`, `_dump_subtree`, `_ray_floor(`, `_monitor_placement`, `_dump_death_tree`, `_death_dump_at` → zero hits.
- [ ] `Select-String -SimpleMatch 'preload(' loadouts\mods\VTK\VTKUI.gd` → count unchanged (no preloads touched).
- [ ] `git diff` from the pre-batch base touches **only** `VTKTravel.gd`, `VTKHooks.gd`, `VTKFeed.gd`, `loadouts/mod.txt`, `CHANGELOG.md`. No test file, no `layout_check.py`, no `VTKUI.gd`.
- [ ] Tabs-only / LF / UTF-8 preserved; no CRLF introduced; no stray `РЎ`/`Р°`/`вЂ”` in the H4 comment.
- [ ] `pack.ps1` prints `4.17.2`; optional manual smoke (one trader teleport, one normal + one ironman death→Restart, one kill-feed appearance/fade).
