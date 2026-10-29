# ThermalVTK 2.1.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cut the per-frame cost of the ESP with many NPCs, let X-ray reveals run without the contour layer, and stop the friendly-nomad diamond from showing through walls.

**Architecture:** One collection pass per frame fills flags on the existing per-NPC record (distance, trigger window, x-ray, optional line of sight); one apply pass drives the rings from a reused candidate pool and a reused options dictionary. Layers (`contour_layer`, `xray_layer`) are separate gates over that shared pass. The marker's visibility is decided by a camera raycast, with a live x-ray window overriding it.

**Tech Stack:** GDScript 4.6 (Godot 4.6.3), Road to Vostok modloader, headless test stand in `.check/`.

**Spec:** `docs/superpowers/specs/2026-10-25-thermalvtk-2.1.0-perf-xray-layers-design.md`

## Global Constraints

- Source root: `standalone mods/ThermalVTK/mods/ThermalVTK/`. Tabs only, UTF-8.
- Test stand: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`. Green means **all three**: no `SCRIPT ERROR` / `Parse Error` / `Invalid call` / `Failed to load script`, the string `tests passed` present, exit code 0.
- `.check/` and `RTVcopy/` are git-ignored by repo policy. Test edits live on disk only: never `git add -f` them, never edit `.gitignore`; commit mod sources, and treat the stand as the runtime harness it is.
- A `const` Dictionary in Godot 4.6 is pooled **per access site**: two reads of `Tracker.EMPTY_WINDOW` are not `is_same`, though two returns from the same function are. Do not write identity assertions across access sites; assert content plus `is_read_only()`.
- `VTKESP._draw(ppos: Vector3)` keeps its signature; tests call it directly.
- `VTKESP._opts_for(e, node, now)` keeps its signature and keeps returning a Dictionary.
- `Tracker.pick_nearest(candidates, cap)` keeps working with two arguments; its return type is `Array` of int ids.
- `VTKOutline.set_entry_xray(id, on)` keeps its signature.
- No new config keys, no save-format change. Version `2.1.0` in `mod.txt` and `version.txt`; README version line synced by hand (ThermalVTK has no pack script that does it).
- `VTKNomadMarker.gdshader` render mode does not change: `depth_test_disabled` stays (1.11.5 scope fix).
- Comments and CHANGELOG in English; CHANGELOG describes player-visible effects only.

## Review Focus

- Player or bot collider intersecting the marker ray must not hide the marker: the ray excludes both subtrees (Task 5 test `t_los_excludes_self`).
- No camera or no physics space (menu, headless, map load) must fail open: marker visible, never invisible (Task 5 `t_los_fails_open`).
- X-ray layer with the contour off must still patch the weapon: otherwise the ring paints over the gun and the scope housing (Task 4 `t_weapon_runs_without_contour`).
- The shared empty-window constant must never be mutated: one accidental write would blank every entry (Task 1 `t_empty_window_shared`).
- Reused candidate dictionaries and the reused options dictionary must not be retained and mutated after the frame (Task 3 `t_opts_reuse_updates` and `t_candidate_pool_reused`).

---

### Task 0: Baseline commit of the in-flight 2.0.0 work

**Files:**
- Commit only: `standalone mods/ThermalVTK/` (12 files already modified)

**Interfaces:**
- Consumes: nothing.
- Produces: a clean base so every later task diff is reviewable on its own.

- [ ] **Step 1: Confirm only ThermalVTK files are dirty**

Run: `git -C D:\RTVMOD status --short`
Expected: the 12 `standalone mods/ThermalVTK/...` entries, nothing else.

- [ ] **Step 2: Commit the baseline**

```bash
git add "standalone mods/ThermalVTK"
git commit -m "ThermalVTK 2.0.0: new default state colours"
```

- [ ] **Step 3: Confirm the tree is clean**

Run: `git -C D:\RTVMOD status --short`
Expected: no output.

---

### Task 1: Tracker shared empty window and reusable cap output

**Files:**
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKTracker.gd`
- Test: `.check/project/tests/test_tracker.gd`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `Tracker.EMPTY_WINDOW` — `const Dictionary`, read-only, the value returned when no window is live.
  - `Tracker.pick_nearest(candidates: Array, cap: int, out: Variant = null) -> Array` — fills `out` and returns it; the two-argument call allocates a fresh result. `out` is a `Variant`, not `Array = []`, because a mutable literal default would be one shared array across calls.
  - `Tracker._dist_less(a: Dictionary, b: Dictionary) -> bool` — the comparator that replaces the per-call lambda.

- [ ] **Step 1: Write the failing tests**

Add to `test_tracker.gd` `_run()`:

```gdscript
	t_empty_window_shared()
	t_pick_nearest_reuses_out()
```

and the two functions:

```gdscript
func t_empty_window_shared() -> void:
	var a: Dictionary = T.pick_trig({"trig": {}}, 0.0)
	var b: Dictionary = T.pick_trig({"trig": {}}, 0.0)
	# Godot 4.6 pools a const Dictionary per access site, so `a` is never the
	# same instance as `T.EMPTY_WINDOW` read here. What the constant guarantees
	# is an empty, read-only, shared container: `is_read_only()` is false for a
	# fresh `{}`, so this still fails if someone downgrades it to `static var`.
	ck(a.is_empty() and a == T.EMPTY_WINDOW and a.is_read_only(), "no window returns the shared constant")
	ck(is_same(a, b), "two calls do not allocate separate windows")

func t_pick_nearest_reuses_out() -> void:
	var cands := [{"id": 3, "dist": 30.0}, {"id": 1, "dist": 10.0}, {"id": 2, "dist": 20.0}]
	var out: Array = [99]
	var same: Array = T.pick_nearest(cands, 2, out)
	ck(is_same(same, out), "the caller's array is returned")
	ck(out == [1, 2], "nearest two ids filled into it")
	ck(cands[0]["id"] == 3, "the input array is not reordered")
	ck(T.pick_nearest(cands, 2) == [1, 2], "the two-argument call still works")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `test_tracker.gd` fails to parse or reports FAIL; no `Tracker tests passed`.

- [ ] **Step 3: Implement in `VTKTracker.gd`**

Add above `TRIG_PRIORITY`:

```gdscript
# Returned instead of a fresh {} on the per-entry per-frame read: the ESP calls
# pick_trig once per NPC per frame, and the empty dictionary was pure garbage.
const EMPTY_WINDOW := {}
```

In `pick_trig`, replace the empty-trigger `return {}` with `return EMPTY_WINDOW`.

Replace `pick_nearest` with the optional output array and a named comparator:

```gdscript
static func pick_nearest(candidates: Array, cap: int, out: Variant = null) -> Array:
	var dst: Array = []
	if out is Array:
		dst = out
	var sorted: Array = candidates.duplicate()
	sorted.sort_custom(_dist_less)
	dst.clear()
	var n: int = mini(cap, sorted.size())
	for i in n:
		dst.append(sorted[i]["id"])
	return dst

static func _dist_less(a: Dictionary, b: Dictionary) -> bool:
	return float(a["dist"]) < float(b["dist"])
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `Tracker tests passed`, overall exit 0.

- [ ] **Step 5: Commit**

```bash
git add "standalone mods/ThermalVTK/mods/ThermalVTK/VTKTracker.gd"
git commit -m "ThermalVTK 2.1.0: tracker reuses the empty window and cap output"
```

---

### Task 2: Outline clears only rings outside the live set

**Files:**
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKOutline.gd`
- Test: `.check/project/tests/test_outline.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: `VTKOutline.clear_not_in(keep: Dictionary) -> void` — `keep` maps id → `true`; every applied id absent from it is cleared.

- [ ] **Step 1: Write the failing test**

Add to `test_outline.gd` `_run()`:

```gdscript
	t_clear_not_in()
```

and:

```gdscript
func t_clear_not_in() -> void:
	var a := Node3D.new()
	a.add_child(MeshInstance3D.new())
	(a.get_child(0) as MeshInstance3D).mesh = BoxMesh.new()
	var b := Node3D.new()
	b.add_child(MeshInstance3D.new())
	(b.get_child(0) as MeshInstance3D).mesh = BoxMesh.new()
	var o = Outline.new()
	o.apply(1, a, {})
	o.apply(2, b, {})
	o.clear_not_in({1: true})
	ck(o.has(1), "kept id survives")
	ck(not o.has(2), "absent id is cleared")
	o.clear_not_in({})
	ck(not o.has(1), "an empty keep clears everything")
	var c := Node3D.new()
	c.add_child(MeshInstance3D.new())
	(c.get_child(0) as MeshInstance3D).mesh = BoxMesh.new()
	o.apply(3, c, {})
	o.clear_not_in({3: true})
	ck(o.has(3), "the later clear leaves nothing stale behind")
	a.free()
	b.free()
	c.free()
```

- [ ] **Step 2: Run to verify it fails**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `test_outline.gd` FAIL / parse error on `clear_not_in`.

- [ ] **Step 3: Implement in `VTKOutline.gd`**

Add a reused list next to `_scoped`:

```gdscript
var _clear_pool: Array = []
```

and after `clear(id)`:

```gdscript
# Clears every applied ring that is not in the live set. The ESP builds the set
# once per frame; iterating our own items avoids a keys() snapshot per frame.
func clear_not_in(keep: Dictionary) -> void:
	_clear_pool.clear()
	for id in _items:
		if not keep.has(id):
			_clear_pool.append(id)
	for id in _clear_pool:
		clear(id)
```

- [ ] **Step 4: Run to verify it passes**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `Outline tests passed`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add "standalone mods/ThermalVTK/mods/ThermalVTK/VTKOutline.gd"
git commit -m "ThermalVTK 2.1.0: outline clears rings outside the live set"
```

---

### Task 3: One ESP collection pass and one apply pass

**Files:**
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKESP.gd`
- Test: `.check/project/tests/test_esp.gd`

**Interfaces:**
- Consumes: `Tracker.EMPTY_WINDOW`, `Tracker.pick_nearest(cands, cap, out)`, `Outline.clear_not_in(keep)`.
- Produces (internal, relied on by Tasks 4–6):
  - `_ids_for_frame() -> Array` — `_entries.keys()` once per frame value.
  - `_want_add(id: int) -> void` — adds to `_want`/`_want_ids` without duplicates.
  - `_fill_opts(opts: Dictionary, e: Dictionary, now: float) -> void` — rewrites a reused options dictionary.
  - Record keys written by `_draw`: `dist: float`, `win: Dictionary`, `xray_live: bool`, `opts: Dictionary`.
  - `_dbg_tick(delta: float, ppos: Variant) -> void` — builds its line after the 1-second gate.

- [ ] **Step 1: Write the failing tests**

Add to `test_esp.gd` `_run()`:

```gdscript
	t_distance_crops_corpses()
	t_xray_window_skips_cap()
	t_opts_reuse_updates()
	t_candidate_pool_reused()
	t_label_reads_stored_window()
```

and the functions:

```gdscript
# Distance now applies to corpses too: the tooltip promises the range without
# an exception for bodies.
func t_distance_crops_corpses() -> void:
	var scene := Node3D.new()
	scene.name = "Map_corpse_dist"
	var bot := FakeBot.new()
	bot.name = "AI_Bandit_corpse_dist"
	scene.add_child(bot)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	bot.add_child(mesh)
	root.add_child(scene)
	current_scene = scene
	var esp = ESP.new()
	esp.name = "VTKESP_corpse_dist"
	root.add_child(esp)
	esp.p_trig = false
	esp.p_dist = 5.0
	bot.dead = true
	bot.global_position = Vector3(0.0, 0.0, -50.0)
	esp._draw(Vector3.ZERO)
	ck(not esp._outline.has(bot.get_instance_id()), "far corpse gets no ring")
	bot.global_position = Vector3(0.0, 0.0, -2.0)
	esp._draw(Vector3.ZERO)
	ck(esp._outline.has(bot.get_instance_id()), "near corpse still gets its cooling ring")
	esp.free()
	scene.queue_free()

# A live reveal is a temporary event, not a contour candidate: it must not push
# a nearer idle bot out of the 24-slot cap.
func t_xray_window_skips_cap() -> void:
	var scene := Node3D.new()
	scene.name = "Map_xray_cap"
	root.add_child(scene)
	current_scene = scene
	var ids: Array = []
	for i in 26:
		var b := FakeBot.new()
		b.name = "AI_Bandit_cap_%d" % i
		var m := MeshInstance3D.new()
		m.mesh = BoxMesh.new()
		b.add_child(m)
		b.global_position = Vector3(0.0, 0.0, -float(i + 1))
		scene.add_child(b)
		ids.append(b.get_instance_id())
	var esp = ESP.new()
	esp.name = "VTKESP_xray_cap"
	root.add_child(esp)
	esp.p_dist = 100.0
	var far: FakeBot = scene.get_child(25)
	Tracker.tag_trig(esp._entries[far.get_instance_id()], "fire", 100.0, esp._now() + 60.0, 60.0)
	esp._draw(Vector3.ZERO)
	ck(esp._outline.has(far.get_instance_id()), "a reveal beyond the cap still draws")
	ck(esp._outline._items.size() == 25, "24 idle rings plus the reveal")
	esp.free()
	scene.queue_free()
```

Wait: the far bot is the 26th nearest, so it is outside CAP anyway; the point is that it draws in addition to the 24 nearest. `_items.size() == 25` proves CAP stayed 24 for the contour and the reveal came on top. Place the reveal bot at `-float(i + 1)` means it is the farthest; fine.

```gdscript
# The options dictionary lives on the record and is rewritten in place; a fresh
# dictionary per NPC per frame was the single biggest allocation in _draw.
func t_opts_reuse_updates() -> void:
	var scene := Node3D.new()
	scene.name = "Map_opts_reuse"
	var bot := FakeBot.new()
	bot.name = "AI_Bandit_opts"
	scene.add_child(bot)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	bot.add_child(mesh)
	root.add_child(scene)
	current_scene = scene
	var esp = ESP.new()
	esp.name = "VTKESP_opts_reuse"
	root.add_child(esp)
	esp.p_dist = 100.0
	esp._frame = 1
	var id := bot.get_instance_id()
	esp._draw(Vector3.ZERO)
	var first: Dictionary = esp._entries[id].get("opts")
	ck(first != null, "draw stores the options on the record")
	Tracker.apply_state(esp._entries[id], 8)
	esp._draw(Vector3.ZERO)
	var second: Dictionary = esp._entries[id].get("opts")
	ck(is_same(second, first), "the dictionary object is reused")
	ck(second["state_key"] == S.KEY_COMBAT, "the reused dictionary carries the new state")
	esp.free()
	scene.queue_free()

# The candidate pool is reused; pick_nearest must not sort it in place, or the
# next frame would start from a pre-sorted pool (and the cap test would go green
# by accident).
func t_candidate_pool_reused() -> void:
	var scene := Node3D.new()
	scene.name = "Map_pool"
	var near := FakeBot.new()
	near.name = "AI_Bandit_near"
	var far := FakeBot.new()
	far.name = "AI_Bandit_far"
	for b in [near, far]:
		var m := MeshInstance3D.new()
		m.mesh = BoxMesh.new()
		b.add_child(m)
		scene.add_child(b)
	near.global_position = Vector3(0.0, 0.0, -1.0)
	far.global_position = Vector3(0.0, 0.0, -9.0)
	root.add_child(scene)
	current_scene = scene
	var esp = ESP.new()
	esp.name = "VTKESP_pool"
	root.add_child(esp)
	esp.p_dist = 100.0
	esp._draw(Vector3.ZERO)
	ck(int(esp._cand_pool[0]["dist"]) == 1, "the pool keeps the collection order")
	ck(esp._cand_refs.size() == 2, "the reference array is sized to the collection")
	esp._draw(Vector3.ZERO)
	ck(int(esp._cand_pool[0]["dist"]) == 1, "a second frame did not reorder the pool")
	ck(esp._outline.has(near.get_instance_id()) and esp._outline.has(far.get_instance_id()), "both rings applied")
	esp.free()
	scene.queue_free()

# The debug label reads the window collected by _draw instead of scanning the
# trigger table again.
func t_label_reads_stored_window() -> void:
	var esp = ESP.new()
	root.add_child(esp)
	var node := Node3D.new()
	root.add_child(node)
	var e := {"nomad": false, "dead": false}
	var now := esp._now()
	e["win"] = {"source": "fire", "dist": 50.0, "expires": now + 9.0, "span": 9.0}
	var txt: String = esp._label_text(e, node, 0)
	ck(txt.contains("[fire"), "the stored window reaches the label")
	ck(txt.contains("9."), "the stored countdown is used")
	esp.free()
	node.free()
```

- [ ] **Step 2: Run to verify they fail**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `test_esp.gd` FAIL or parse error (`_cand_pool` / `_cand_refs` do not exist).

- [ ] **Step 3: Rewrite the ESP frame**

In `VTKESP.gd`:

1. Add fields next to `_entries`:

```gdscript
var _ids_frame: Array = []
var _ids_stamp: int = -1
var _cand_pool: Array = []
var _cand_refs: Array = []
var _keep_pool: Array = []
var _want: Dictionary = {}
var _want_ids: Array = []
var _stale: Array = []
var _dbg_draw_ms: float = 0.0
```

2. Add:

```gdscript
func _ids_for_frame() -> Array:
	if _ids_stamp != _frame:
		_ids_frame = _entries.keys()
		_ids_stamp = _frame
	return _ids_frame

func _want_add(id: int) -> void:
	if not _want.has(id):
		_want[id] = true
		_want_ids.append(id)
```

3. Rewrite `_draw(ppos)` as the collection + apply described below. Keep the signature. The collection loop:

```gdscript
func _draw(ppos: Vector3) -> void:
	var t0: int = 0
	if Dbg.enabled:
		t0 = Time.get_ticks_usec()
	var now := _now()
	_ids_frame = _entries.keys()
	_ids_stamp = _frame
	_stale.clear()
	_want.clear()
	_want_ids.clear()
	var used := 0
	for id in _ids_frame:
		if not _entries.has(id):
			continue
		var e: Dictionary = _entries[id]
		var node = e.get("node")
		if node == null or not is_instance_valid(node) or not node.is_inside_tree():
			_outline.clear(id)
			_stale.append(id)
			continue
		if not bool(e.get("dead", false)) and bool(node.get("dead")):
			Tracker.mark_dead(e, now)
		var dist: float = ppos.distance_to((node as Node3D).global_position)
		e["dist"] = dist
		var win: Dictionary = Tracker.EMPTY_WINDOW
		if not bool(e.get("dead", false)):
			win = Tracker.pick_trig(e, now)
		e["win"] = win
		var xray: bool = p_trig and not win.is_empty() and dist <= float(win.get("dist", 0.0))
		e["xray_live"] = xray
		if _frame % POLL_EVERY == 0:
			Tracker.apply_state(e, _read_state(node))
		if dist <= p_dist:
			var c: Dictionary
			if used < _cand_pool.size():
				c = _cand_pool[used]
			else:
				c = {}
				_cand_pool.append(c)
			c["id"] = id
			c["dist"] = dist
			used += 1
		if xray:
			_want_add(id)
	for id in _stale:
		_entries.erase(id)
	_cand_refs.resize(used)
	for i in used:
		_cand_refs[i] = _cand_pool[i]
	var keep: Array = Tracker.pick_nearest(_cand_refs, CAP, _keep_pool)
	for id in keep:
		_want_add(id)
	var applied := 0
	for id in _want_ids:
		if not _entries.has(id):
			continue
		var e: Dictionary = _entries[id]
		var node = e.get("node")
		if node == null or not is_instance_valid(node):
			continue
		var opts = e.get("opts")
		if opts == null:
			opts = {}
			e["opts"] = opts
		_fill_opts(opts, e, now)
		if _outline.has(id):
			_outline.refresh(id, opts)
		else:
			_outline.apply(id, node, opts)
		applied += 1
	_outline.clear_not_in(_want)
	_dbg_cand = used
	_dbg_keep = keep.size()
	_dbg_applied = applied
	if Dbg.enabled:
		_dbg_draw_ms = float(Time.get_ticks_usec() - t0) / 1000.0
```

4. Replace `_opts_for` with the shape + filler:

```gdscript
func _opts_for(e: Dictionary, node: Node, now: float) -> Dictionary:
	var opts: Dictionary = {}
	_fill_opts(opts, e, now)
	return opts

func _fill_opts(opts: Dictionary, e: Dictionary, now: float) -> void:
	var cool := Tracker.cool_factor(e, now, p_decay)
	var win: Dictionary = e.get("win", Tracker.EMPTY_WINDOW)
	var xray := bool(e.get("xray_live", false))
	if xray and not win.is_empty():
		cool = clampf(1.0 - Tracker.fade_factor(win, now), 0.0, 1.0)
	var cat: int = int(e.get("cat", States.NORMAL))
	var key: Color = States.state_key(cat)
	if p_cal_active:
		key = Calibration.candidate(p_cal_index)
	opts["cat"] = cat
	opts["nomad"] = bool(e.get("nomad", false))
	opts["state_key"] = key
	opts["cool"] = cool
	opts["rim"] = p_rim
	opts["brightness"] = p_brightness
	opts["grow"] = p_thickness
	opts["xray"] = xray
```

5. `_labels_sync` iterates `_ids_for_frame()` and skips `not _entries.has(id)`; `_label_text` uses the stored window with a fallback:

```gdscript
	var ev: Dictionary = Tracker.EMPTY_WINDOW
	if e.has("win"):
		ev = e["win"]
	else:
		ev = Tracker.pick_trig(e, _now())
```

6. Add the two free helpers next to `_label_free`/`_marker_free` (Task 4 reuses them):

```gdscript
func _labels_free_all() -> void:
	for id in _labels.keys():
		_label_free(id)
	_labels.clear()

func _markers_free_all() -> void:
	for id in _markers.keys():
		_marker_free(id)
	_markers.clear()
```

Reorder `_process` so `_draw(ppos)` runs **before** `_labels_sync()` and `_markers_sync()`: both consume `e["win"]`/`e["xray_live"]`, and running them first would paint one frame behind. `_frame` increments before `_draw`, so the `_ids_for_frame` stamp is current. Replace the whole `_process` body below `_scope_probe(delta)` with:

```gdscript
	_scope_probe(delta)
	_frame += 1
	if not _pending.is_empty():
		for node_id in _pending:
			var n := instance_from_id(node_id)
			if n != null and is_instance_valid(n) and n.is_inside_tree() and _is_bot(n):
				_register(n)
		_pending.clear()
	# Collection before the consumers: labels and markers read the flags and
	# the window this pass stores on the record.
	var ppos_v = _player_pos()
	if ppos_v != null:
		var ppos: Vector3 = ppos_v
		if enabled:
			_draw(ppos)
	_labels_sync()
	_markers_sync()
	_dbg_tick(delta, ppos_v)
```

The parked branch stays as it is for now; Task 4 swaps its gate and the inline marker loop for the helpers.

7. Replace `_dbg_tick`:

```gdscript
func _dbg_tick(delta: float, ppos: Variant) -> void:
	_dbg_cd -= delta
	if _dbg_cd > 0.0:
		return
	_dbg_cd = 1.0
	if not Dbg.enabled:
		return
	var where := "no player in group Player"
	if ppos != null:
		var p: Vector3 = ppos
		where = "ppos=%.1f,%.1f,%.1f" % [p.x, p.y, p.z]
	Dbg.log("ESP", "entries=%d cand=%d keep=%d applied=%d draw=%.2fms %s" % [_entries.size(), _dbg_cand, _dbg_keep, _dbg_applied, _dbg_draw_ms, where])
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `ESP tests passed`, `Tracker tests passed`, overall exit 0.

- [ ] **Step 5: Commit**

```bash
git add "standalone mods/ThermalVTK/mods/ThermalVTK/VTKESP.gd"
git commit -m "ThermalVTK 2.1.0: one collection pass and one apply pass per ESP frame"
```

---

### Task 4: Independent contour and X-ray layers

**Files:**
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKESP.gd`
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/ThermalVTK.gd`
- Test: `.check/project/tests/test_esp.gd`, `.check/project/tests/test_debug.gd`, `.check/project/tests/test_profile.gd`

**Interfaces:**
- Consumes: the Task 3 frame.
- Produces:
  - `VTKESP.contour_layer: bool`, `VTKESP.xray_layer: bool`
  - `VTKESP.set_layers(contour: bool, xray: bool) -> void` (replaces `set_enabled`)
  - `ThermalVTK._xray_enabled: bool` (from `rec.outline_xray`)
  - `ThermalVTK._apply_mode()` calls `_esp.set_layers(on and _outline_enabled, on and _xray_enabled)` with `on = _thermal_enabled and _nvg_active()`.

- [ ] **Step 1: Write the failing tests**

In `test_esp.gd`, replace every `esp.set_enabled(...)` with `esp.set_layers(...)`:
- `set_enabled(false)` → `set_layers(false, false)`
- `set_enabled(true)` → `set_layers(true, false)`
- line 449 `esp.enabled = true` → `esp.set_layers(true, false)` and keep the following `esp.marker_visible = true`.

`_draw` is only reached through the layer gate in `_process`, so every test that calls it directly has to arm the layers the way the coordinator does. Add `set_layers` right after `ESP.new()` in:

| Test | Call |
|---|---|
| `t_toggle_keeps_death_time` | `esp.set_layers(true, false)` |
| `t_distance_crops` | `esp.set_layers(true, false)` |
| `t_label_suffix_independent` (the residue half, `resp`) | `resp.set_layers(true, true)` |
| `t_dead_node_marks_entry` | `esp.set_layers(true, false)` |
| `t_distance_crops_corpses` (Task 3) | `esp.set_layers(true, false)` |
| `t_xray_window_skips_cap` (Task 3) | `esp.set_layers(true, true)` |
| `t_opts_reuse_updates` (Task 3) | `esp.set_layers(true, false)` |
| `t_candidate_pool_reused` (Task 3) | `esp.set_layers(true, false)` |

The two Task 3 tests that expect a reveal (`t_xray_window_skips_cap`, and the residue half of `t_label_suffix_independent`) need `true, true`; with only the contour armed the x-ray layer is parked and the reveal never draws.

Add to `_run()`:

```gdscript
	t_xray_layer_without_contour()
	t_layers_drive_marker()
	t_weapon_runs_without_contour()
```

```gdscript
class FakeWeapon extends RefCounted:
	var ticks := 0
	var modes: Array = []
	func tick() -> void:
		ticks += 1
	func set_scope_mode(scoped: bool, pip: bool) -> void:
		modes.append([scoped, pip])

# X-ray is its own layer: with the contour off, a reveal still draws, and it
# disappears when the window expires.
func t_xray_layer_without_contour() -> void:
	var scene := Node3D.new()
	scene.name = "Map_xray_layer"
	var bot := FakeBot.new()
	bot.name = "AI_Bandit_xray_layer"
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	bot.add_child(mesh)
	bot.global_position = Vector3(0.0, 0.0, -40.0)
	scene.add_child(bot)
	root.add_child(scene)
	current_scene = scene
	var esp = ESP.new()
	esp.name = "VTKESP_xray_layer"
	root.add_child(esp)
	esp.p_dist = 5.0
	esp.set_layers(false, true)
	var id := bot.get_instance_id()
	var now := esp._now()
	Tracker.tag_trig(esp._entries[id], "fire", 100.0, now + 60.0, 60.0)
	esp._draw(Vector3.ZERO)
	ck(esp._outline.has(id), "reveal draws with the contour off")
	var ring: ShaderMaterial = esp._outline._items[id]["ring"]
	ck(ring.shader == Sh.ring_xray(), "the reveal uses the x-ray shader")
	Tracker.tag_trig(esp._entries[id], "fire", 100.0, now - 1.0, 60.0)
	esp._draw(Vector3.ZERO)
	ck(not esp._outline.has(id), "an expired window clears the ring")
	esp.free()
	scene.queue_free()

func t_layers_drive_marker() -> void:
	var esp = ESP.new()
	root.add_child(esp)
	esp.set_layers(true, false)
	ck(esp.contour_layer and esp.marker_visible, "contour on shows the marker")
	esp.set_layers(false, true)
	ck(not esp.contour_layer and esp.xray_layer, "x-ray alone is a live layer")
	ck(not esp.marker_visible, "the marker belongs to the contour")
	esp.set_layers(false, false)
	ck(not esp.contour_layer and not esp.xray_layer, "both layers can be off")
	esp.free()

# The weapon patch keeps outline overlays from painting over the gun and the
# scope housing. It must run for the x-ray layer too.
func t_weapon_runs_without_contour() -> void:
	var scene := Node3D.new()
	scene.name = "Map_weapon_layer"
	root.add_child(scene)
	current_scene = scene
	var esp = ESP.new()
	esp.name = "VTKESP_weapon_layer"
	root.add_child(esp)
	var w := FakeWeapon.new()
	esp._weapon = w
	esp.set_layers(false, true)
	esp._process(0.016)
	ck(w.ticks == 1, "weapon tick runs for the x-ray layer")
	ck(w.modes.size() == 1, "scope mode is pushed once")
	esp.free()
	scene.queue_free()
```

In `test_debug.gd`, change `FakeESP` to:

```gdscript
class FakeESP extends Node:
	var contour_layer: bool = false
	var xray_layer: bool = false
	var marker_visible: bool = false
	func set_layers(contour: bool, xray: bool) -> void:
		contour_layer = contour
		xray_layer = xray
		marker_visible = contour
```

and update `t_marker_follows_contour_gate`:
- `ck(esp.contour_layer == false, ...)`, `ck(esp.xray_layer == true, "x-ray stays live while the contour is off")`, then `ck(esp.marker_visible == false, ...)`.
- after contour on: both true.
- thermal off: both false.

In `test_profile.gd`, change `FakeESP` the same way (replace `enabled`/`set_enabled` with `contour_layer`/`xray_layer`/`set_layers`).

Add to `test_profile.gd` `_run()`:

```gdscript
	t_apply_mode_splits_layers()
```

```gdscript
func t_apply_mode_splits_layers() -> void:
	var mod = ThermalMod.new()
	var esp := FakeESP.new()
	var nvg := FakeNVG.new()
	mod._esp = esp
	mod._nvg = nvg
	mod._thermal_enabled = true
	mod._outline_enabled = true
	mod._xray_enabled = true
	mod._apply_mode()
	ck(esp.contour_layer and esp.xray_layer, "both layers follow their toggles")
	mod._outline_enabled = false
	mod._apply_mode()
	ck(not esp.contour_layer and esp.xray_layer, "x-ray survives the contour toggle")
	mod._xray_enabled = false
	mod._apply_mode()
	ck(not esp.contour_layer and not esp.xray_layer, "both toggles off")
	mod.free()
	esp.free()
	nvg.free()
```

- [ ] **Step 2: Run to verify they fail**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `set_layers` / `contour_layer` / `_xray_enabled` missing; tests FAIL.

- [ ] **Step 3: Implement the layers**

`VTKESP.gd`:

1. Replace `var enabled: bool = false` with:

```gdscript
# Two independent layers share one collection pass. `enabled` is gone: the
# contour layer gates rings and the marker, the x-ray layer gates reveals.
var contour_layer: bool = false
var xray_layer: bool = false
```

2. Replace `set_enabled` with:

```gdscript
func set_layers(contour: bool, xray: bool) -> void:
	if contour_layer == contour and xray_layer == xray:
		return
	var any_before := _any_layer()
	contour_layer = contour
	xray_layer = xray
	marker_visible = contour
	Dbg.log("ESP", "layers contour=%s xray=%s" % [str(contour), str(xray)])
	if not _any_layer():
		_outline.clear_all()
		_labels_free_all()
		_markers_free_all()
	elif not any_before and is_inside_tree():
		_reseed(get_tree().current_scene)

func _any_layer() -> bool:
	return contour_layer or xray_layer
```

3. In `_draw`, gate the two writes:
- candidate condition: `if contour_layer and dist <= p_dist:`
- x-ray flag: `var xray: bool = xray_layer and p_trig and ...`

4. In `_process`, change the parking condition to `if not _any_layer():`, remove `marker_visible` from it, and keep the cleanup there. Change `_weapon.set_scope_mode(scoped and enabled, pip)` to `_weapon.set_scope_mode(scoped and _any_layer(), pip)`. In the Task 3 tail, change `if enabled: _draw(ppos)` to `if _any_layer(): _draw(ppos)`.

5. In `_labels_sync`, change **both** visibility writes to `true`: `lbl.visible = true` in the update branch and in `_label_make` (lines ~484 and ~514 today). Labels are a debug layer: they follow the diagnostic log, not the contour, and `_labels_free_all` owns the teardown.

6. Reuse the `_labels_free_all`/`_markers_free_all` helpers added in Task 3. In the `_process` parked branch, replace the inline `for id in _markers.keys(): _marker_free(id)` block with `_markers_free_all()`; leave the `_pending.clear()` and `_weapon.set_scope_mode(false, false)` lines as they are. In `_exit_tree`, replace both inline loops with the two helpers so the teardown has one implementation.

7. Make the weapon field untyped so tests can inject a fake: `var _weapon = WeaponOcclusion.new()` (drop the `:=`, which infers the script type and rejects `FakeWeapon` at assignment). This is what lets `t_weapon_runs_without_contour` observe the tick.

8. Remove the now-unused `_labels_state` field and every `_labels_state.clear()` / `_labels_state[id] = 0`.

`ThermalVTK.gd`:

1. Add `var _xray_enabled: bool = true` next to `_outline_enabled`.
2. In `_mcm_apply`, after `_outline_enabled = rec.outline_enabled` add `_xray_enabled = rec.outline_xray`.
3. Rewrite `_apply_mode`:

```gdscript
func _apply_mode() -> void:
	if _esp != null and is_instance_valid(_esp):
		# Two independent layers on the thermal stack: the contour (rings and
		# the nomad marker) and the x-ray reveals. Either one can run alone.
		var on := _thermal_enabled and _nvg_active()
		_esp.set_layers(on and _outline_enabled, on and _xray_enabled)
```

4. `_cal_step` reads `_esp.contour_layer` instead of `_esp.enabled`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `ESP tests passed`, `Debug tests passed`, `Profile tests passed`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add "standalone mods/ThermalVTK/mods/ThermalVTK/VTKESP.gd" "standalone mods/ThermalVTK/mods/ThermalVTK/ThermalVTK.gd"
git commit -m "ThermalVTK 2.1.0: contour and x-ray are independent layers"
```

---

### Task 5: Nomad marker line of sight

**Files:**
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKESP.gd`
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKNomadMarker.gdshader` (comment only)
- Test: `.check/project/tests/test_esp.gd`

**Interfaces:**
- Consumes: `e["xray_live"]` and `e["win"]` from Task 3; the layers from Task 4.
- Produces:
  - `los_probe: Callable` — test seam; when valid it fully replaces the camera raycast and returns `bool`.
  - `_marker_los(e: Dictionary, mi: MeshInstance3D) -> bool`
  - `_los_raycast(from: Vector3, to: Vector3, e: Dictionary) -> bool`
  - `_subtree_rids(root: Node, out: Array[RID]) -> void` — appends `CollisionObject3D` RIDs of the subtree.
  - `_marker_make(id, node) -> MeshInstance3D` (now returns the marker).
  - Record key `los: bool`.

- [ ] **Step 1: Write the failing tests**

Add to `test_esp.gd` `_run()`:

```gdscript
	t_los_hides_marker()
	t_los_xray_reveals()
	t_los_excludes_self()
```

```gdscript
# The LOS gate is spread over frames by `(_frame + id) % LOS_EVERY`. A test that
# wants a fresh raycast must set `_frame` to the phase where that expression is
# zero for this id, otherwise the marker keeps the verdict it already has.
func los_force(esp, id: int) -> void:
	esp._frame = (esp.LOS_EVERY - (id % esp.LOS_EVERY)) % esp.LOS_EVERY
	esp._markers_sync()

# A wall between the camera and the diamond hides it. The probe replaces the
# real raycast so the test stays headless.
func t_los_hides_marker() -> void:
	var scene := Node3D.new()
	scene.name = "Map_los"
	var bot := FakeBot.new()
	bot.name = "AI_Nomad_los"
	scene.add_child(bot)
	root.add_child(scene)
	current_scene = scene
	var esp = ESP.new()
	esp.name = "VTKESP_los"
	root.add_child(esp)
	esp.set_layers(true, true)
	esp.los_probe = func() -> bool:
		return false
	var id := bot.get_instance_id()
	esp._markers_sync()
	ck(esp._markers.has(id), "marker exists")
	ck(not (esp._markers[id] as MeshInstance3D).visible, "a blocked line of sight hides it")
	esp.los_probe = func() -> bool:
		return true
	los_force(esp, id)
	ck((esp._markers[id] as MeshInstance3D).visible, "clear line of sight shows it")
	esp.free()
	scene.queue_free()

# A live reveal is the one thing allowed to show the diamond through a wall.
func t_los_xray_reveals() -> void:
	var scene := Node3D.new()
	scene.name = "Map_los_xray"
	var bot := FakeBot.new()
	bot.name = "AI_Nomad_los_xray"
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	bot.add_child(mesh)
	bot.global_position = Vector3(0.0, 0.0, -40.0)
	scene.add_child(bot)
	root.add_child(scene)
	current_scene = scene
	var esp = ESP.new()
	esp.name = "VTKESP_los_xray"
	root.add_child(esp)
	esp.p_dist = 5.0
	esp.set_layers(true, true)
	esp.los_probe = func() -> bool:
		return false
	var id := bot.get_instance_id()
	var now := esp._now()
	Tracker.tag_trig(esp._entries[id], "fire", 100.0, now + 60.0, 60.0)
	esp._draw(Vector3.ZERO)
	esp._markers_sync()
	ck(bool(esp._entries[id].get("xray_live", false)), "the reveal window is live")
	ck((esp._markers[id] as MeshInstance3D).visible, "a live reveal shows the diamond through the wall")
	Tracker.tag_trig(esp._entries[id], "fire", 100.0, now - 1.0, 60.0)
	esp._draw(Vector3.ZERO)
	los_force(esp, id)
	ck(not (esp._markers[id] as MeshInstance3D).visible, "after the window the wall hides it again")
	esp.free()
	scene.queue_free()

# The ray starts inside the player capsule and ends at a point above the bot;
# both subtrees must be excluded or the marker is never visible.
func t_los_excludes_self() -> void:
	var body := CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	body.add_child(shape)
	var nested := StaticBody3D.new()
	nested.add_child(CollisionShape3D.new())
	(nested.get_child(0) as CollisionShape3D).shape = BoxShape3D.new()
	body.add_child(nested)
	var esp = ESP.new()
	var rids: Array[RID] = []
	esp._subtree_rids(body, rids)
	ck(rids.size() == 2, "both collision objects collected")
	ck(rids.has(body.get_rid()), "the root body rid is included")
	ck(rids.has(nested.get_rid()), "a nested body rid is included")
	esp.free()
	body.free()
```

- [ ] **Step 2: Run to verify it fails**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `test_esp.gd` FAIL / parse error on `los_probe` and `_subtree_rids`.

- [ ] **Step 3: Implement the marker LOS**

In `VTKESP.gd`:

1. Constants and fields:

```gdscript
# Frames between line-of-sight raycasts per nomad. The id spreads the checks
# across frames, so a squad of nomads costs one raycast every few frames.
const LOS_EVERY := 6
# Test seam: when valid, it answers "is the diamond visible" and the camera
# raycast is skipped entirely.
var los_probe: Callable
var _los_query: PhysicsRayQueryParameters3D = null
var _los_exclude: Array[RID] = []
var _los_player: Node = null
```

2. `_markers_sync` iterates `_ids_for_frame()` with the `_entries.has(id)` guard, and for a live, non-dead nomad it ensures the marker exists and then:

```gdscript
		var mi: MeshInstance3D = _markers.get(id)
		if mi == null or not is_instance_valid(mi):
			mi = _marker_make(id, node)
			if mi == null:
				continue
		var win: Dictionary = e.get("win", Tracker.EMPTY_WINDOW)
		var xray: bool = bool(e.get("xray_live", false)) and not win.is_empty()
		if xray:
			e["los"] = true
		elif not e.has("los") or (_frame + id) % LOS_EVERY == 0:
			e["los"] = _marker_los(e, mi)
		mi.visible = bool(e.get("los", true))
```


3. Change `_marker_make` to `-> MeshInstance3D` and `return mi` at the end (return `null` when the anchor parent is missing).

4. Implement:

```gdscript
func _marker_los(e: Dictionary, mi: MeshInstance3D) -> bool:
	if los_probe.is_valid():
		return bool(los_probe.call())
	var cam := _camera() as Camera3D
	if cam == null or not is_inside_tree():
		return true
	return _los_raycast(cam.global_position, mi.global_position, e)

func _camera() -> Camera3D:
	var vp := get_viewport()
	if vp == null:
		return null
	return vp.get_camera_3d()

func _los_raycast(from: Vector3, to: Vector3, e: Dictionary) -> bool:
	var vp := get_viewport()
	if vp == null:
		return true
	var world := vp.find_world_3d()
	if world == null:
		return true
	var space := world.direct_space_state
	if space == null:
		return true
	if _los_query == null:
		_los_query = PhysicsRayQueryParameters3D.new()
	_los_exclude.clear()
	var p := _player_node()
	if p != null:
		_subtree_rids(p, _los_exclude)
	var node = e.get("node")
	if node is Node:
		_subtree_rids(node, _los_exclude)
	_los_query.from = from
	_los_query.to = to
	_los_query.exclude = _los_exclude
	_los_query.collide_with_areas = false
	_los_query.collide_with_bodies = true
	_los_query.hit_from_inside = false
	return space.intersect_ray(_los_query).is_empty()

func _player_node() -> Node:
	if _los_player != null and is_instance_valid(_los_player):
		return _los_player
	_los_player = null
	for p in get_tree().get_nodes_in_group("Player"):
		if p is Node3D:
			_los_player = p
			break
	return _los_player

func _subtree_rids(root: Node, out: Array[RID]) -> void:
	if root == null or not is_instance_valid(root):
		return
	if root is CollisionObject3D:
		out.append((root as CollisionObject3D).get_rid())
	for c in root.get_children():
		_subtree_rids(c, out)
```

5. Update the outdated comment in `_marker_make` (lines about "The default depth test is kept") to say the shader has no depth test on purpose (1.11.5) and visibility is decided by `_marker_los`.

6. Update the shader header comment: `depth_test_disabled` is kept for the scope picture; walls are handled by the ESP raycast, not by the depth test.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `ESP tests passed`, exit 0. `test_shaders.gd` still passes: the shader keeps `depth_test_disabled`.

- [ ] **Step 5: Commit**

```bash
git add "standalone mods/ThermalVTK/mods/ThermalVTK/VTKESP.gd" "standalone mods/ThermalVTK/mods/ThermalVTK/VTKNomadMarker.gdshader"
git commit -m "ThermalVTK 2.1.0: the nomad diamond honours walls"
```

---

### Task 6: Parked hooks and hot debug strings

**Files:**
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKESP.gd`
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKWeaponOcclusion.gd`
- Test: `.check/project/tests/test_esp.gd`

**Interfaces:**
- Consumes: `_any_layer()` from Task 4.
- Produces: no new public interface.

- [ ] **Step 1: Write the failing tests**

Add to `test_esp.gd` `_run()`:

```gdscript
	t_parked_trigger_does_not_register()
```

```gdscript
# With every layer parked, a trigger event from an unknown bot must not build a
# record or a log line: the next enable reseeds the scene anyway.
func t_parked_trigger_does_not_register() -> void:
	var scene := Node3D.new()
	scene.name = "Map_parked_hook"
	var bot := FakeBot.new()
	bot.name = "AI_Bandit_parked_hook"
	scene.add_child(bot)
	root.add_child(scene)
	current_scene = scene
	var esp = ESP.new()
	esp.name = "VTKESP_parked_hook"
	root.add_child(esp)
	var lib := FakeLib.new()
	lib._caller = bot
	esp._lib = lib
	esp.set_layers(false, false)
	esp._entries.erase(bot.get_instance_id())
	esp._on_ai_playfire()
	ck(not esp._entries.has(bot.get_instance_id()), "a parked layer ignores the trigger")
	esp.set_layers(true, false)
	# set_layers(true, ...) reseeds the live scene, so the bot is back in the
	# registry before the hook runs; erase it again, or the second assertion
	# would pass without the hook doing anything.
	esp._entries.erase(bot.get_instance_id())
	esp._on_ai_playfire()
	ck(esp._entries.has(bot.get_instance_id()), "a live layer registers the caller again")
	esp.free()
	scene.queue_free()
```

- [ ] **Step 2: Run to verify it fails**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: FAIL — the parked trigger still registers the bot.

- [ ] **Step 3: Implement**

In `_trig_event`, after the `span`/`dist` guards and before `var n := _caller()`:

```gdscript
	# Parked (thermal or both layers off): do not grow the registry from a
	# sound event. Known entries keep their tags, so debug labels still read a
	# window that was opened before the layer went off.
	if not _any_layer():
		var known := _caller()
		if known == null or not is_instance_valid(known):
			return
		var kid: int = known.get_instance_id()
		if not _entries.has(kid):
			return
		Tracker.tag_trig(_entries[kid], source, dist, _now() + span, span)
		return
```

Wrap the two `Dbg.log` calls in `_trig_event` with `if Dbg.enabled:`.

In `_on_ai_changestate`, read the state once:

```gdscript
	var state := _read_state(node)
	Tracker.apply_state(_entries[id], state)
	Dbg.log("ESP", "changestate id=%d state=%d" % [id, state])
```

In `VTKWeaponOcclusion._patch_mesh`, wrap the `trail` string construction in `if Dbg.enabled:` and pass an empty string to the log otherwise. Do not change the patch itself.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `ESP tests passed`, `Weapon tests passed`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add "standalone mods/ThermalVTK/mods/ThermalVTK/VTKESP.gd" "standalone mods/ThermalVTK/mods/ThermalVTK/VTKWeaponOcclusion.gd"
git commit -m "ThermalVTK 2.1.0: parked ESP stops registering and logging"
```

---

### Task 7: NVG uniform batching, bounded mine retries, script-kind cache

**Files:**
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKNVG.gd`
- Create: `.check/project/tests/test_nvg.gd`
- Modify: `.check/check.ps1` (add the test to `$tests`)

**Interfaces:**
- Consumes: nothing.
- Produces (internal, pinned by the new test):
  - `VTKNVG._dirty: bool`
  - `VTKNVG._script_kind_for(n: Node) -> int` (`0` not ours, `1` NVG, `2` Mine)
  - `VTKNVG.MINE_RETRY_LIMIT := 50`
  - `_mine_watch` values become `{"node": Node, "tries": int}`.

- [ ] **Step 1: Write the failing test**

Create `.check/project/tests/test_nvg.gd`:

```gdscript
extends SceneTree

const NVG = preload("res://mods/ThermalVTK/VTKNVG.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _init() -> void:
	process_frame.connect(_run)

func _run() -> void:
	t_dirty_batches_setters()
	t_mine_retry_is_bounded()
	t_off_upkeep_clears_dead_mines()
	t_script_kind_cache()
	print("")
	if fails == 0:
		print("NVG tests passed")
		quit(0)
	else:
		print("NVG tests failed: ", fails)
		quit(1)

# The uniforms used to be pushed every 0.1 s whether anything changed or not.
# A setter only marks the material dirty; the next tick pushes once.
func t_dirty_batches_setters() -> void:
	var nvg = NVG.new()
	root.add_child(nvg)
	nvg.set_state_colors({"state_normal": Color.RED})
	ck(nvg._dirty, "a setter marks the uniforms dirty")
	nvg._apply_uniforms()
	ck(not nvg._dirty, "a push clears the flag")
	nvg.set_thermal_enabled(true)
	ck(nvg._dirty, "thermal toggle marks dirty")
	nvg.free()

# A mine whose visual never appears used to be swept on every tick forever.
func t_mine_retry_is_bounded() -> void:
	var nvg = NVG.new()
	root.add_child(nvg)
	var mine := Node3D.new()
	root.add_child(mine)
	nvg._register_mine(mine)
	var id := mine.get_instance_id()
	ck(nvg._mine_watch.has(id), "a visual-less mine is parked")
	for i in NVG.MINE_RETRY_LIMIT:
		nvg._retry_mines()
	ck(not nvg._mine_watch.has(id), "the park is dropped after the retry limit")
	ck(not nvg._mines.has(id), "it never becomes a painted mine")
	nvg.free()
	mine.free()

func t_off_upkeep_clears_dead_mines() -> void:
	var nvg = NVG.new()
	root.add_child(nvg)
	var mine := Node3D.new()
	root.add_child(mine)
	nvg._mines[mine.get_instance_id()] = {"node": mine, "meshes": []}
	mine.free()
	nvg._off_frame_upkeep()
	ck(nvg._mines.is_empty(), "a freed mine is dropped while thermal is off")
	nvg._off_frame_upkeep()
	ck(nvg._mines.is_empty(), "the early return keeps the next pass cheap")
	nvg.free()

# The script verdict is cached per script, not per node: the map load queues
# thousands of nodes from the same few scripts.
func t_script_kind_cache() -> void:
	var nvg = NVG.new()
	root.add_child(nvg)
	var script := GDScript.new()
	script.resource_path = "res://Scripts/NVG.gd"
	var a := Node.new()
	var b := Node.new()
	a.set_script(script)
	b.set_script(script)
	ck(nvg._script_kind_for(a) == 1, "an NVG script reads as NVG")
	ck(nvg._script_kind_for(b) == 1, "the second node reuses the verdict")
	ck(nvg._script_kind_for(Node.new()) == 0, "a scriptless node reads as foreign")
	ck(nvg._script_kind.size() == 1, "only the resolved script is cached; a null script short-circuits")
	nvg.free()
	a.free()
	b.free()
```

- [ ] **Step 2: Add the test to the stand and run it to fail**

In `.check/check.ps1`, append `"res://tests/test_nvg.gd"` to the `$tests` array.

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `test_nvg.gd` FAIL / parse error on `_dirty` or `MINE_RETRY_LIMIT`.

- [ ] **Step 3: Implement in `VTKNVG.gd`**

1. Fields next to `_mines`:

```gdscript
var _dirty: bool = true
var _script_kind: Dictionary = {}
const MINE_RETRY_LIMIT := 50
```

2. `_apply_uniforms()` sets `_dirty = false` as its first statement.

2b. In `_try_install_shader`, mark the uniforms dirty on **both** successful installs: add `_dirty = true` to the "material already ours" early return, and keep the direct `_apply_uniforms()` after the shader swap (that call clears the flag itself). Without the first one, a push dropped while `_installed` was false would never be retried: `_apply_uniforms` returns before the shader params but still clears the flag.

3. Setters mark dirty instead of pushing:

```gdscript
func set_thermal_enabled(on: bool) -> void:
	set_thermal = on
	_dirty = true
	_tick_cd = 0.0
```

`apply_config`, `set_state_colors`, `set_palette_mode` likewise (`_dirty = true`, `_tick_cd = 0.0`, no direct `_apply_uniforms`). `set_mines_enabled` keeps only `_tick_cd = 0.0`.

`_reset_daylight` replaces its `_apply_uniforms()` with `_dirty = true`.
`_daylight_tick` replaces the `_apply_uniforms()` in the snow-trim branch with `_dirty = true`.
In `_process`, inside `if worn != _was_worn:` add `_dirty = true` next to `_was_worn = worn`.

4. In `_process`, replace the unconditional tick push:

```gdscript
	_tick_cd = TICK
	if _dirty:
		_apply_uniforms()
	_retry_mines()
```

5. `_scan_node` and `_deferred_check` both resolve the kind through:

```gdscript
func _script_kind_for(n: Node) -> int:
	var s = n.get_script()
	if s == null:
		return 0
	var sid: int = s.get_instance_id()
	var cached = _script_kind.get(sid)
	if cached != null:
		return int(cached)
	var path := String(s.resource_path)
	var kind := 0
	if path.ends_with(NVG_SCRIPT_SUFFIX):
		kind = 1
	elif path.ends_with("Mine.gd"):
		kind = 2
	_script_kind[sid] = kind
	return kind
```

Clear the cache on a scene change where `_mines` is cleared: `_script_kind.clear()`.

6. `_register_mine` parks `{"node": node, "tries": 0}` when the sweep is empty.

7. `_retry_mines`:

```gdscript
func _retry_mines() -> void:
	if _mine_watch.is_empty():
		return
	var drop: Array = []
	for id in _mine_watch:
		var w: Dictionary = _mine_watch[id]
		var n = w.get("node")
		if n == null or not is_instance_valid(n):
			drop.append(id)
			continue
		var meshes: Array = []
		_collect_meshes(n, meshes)
		if not meshes.is_empty():
			_mines[id] = {"node": n, "meshes": meshes}
			drop.append(id)
			continue
		var tries := int(w.get("tries", 0)) + 1
		w["tries"] = tries
		if tries >= MINE_RETRY_LIMIT:
			Dbg.log("NVG", "mine visual never appeared id=%d" % id)
			drop.append(id)
	for id in drop:
		_mine_watch.erase(id)
```

`_register_mine` must not overwrite an existing parked entry (so its `tries` survives a re-register).

8. `_off_frame_upkeep`:

```gdscript
func _off_frame_upkeep() -> void:
	if _mines.is_empty():
		return
	var drop: Array = []
	for id in _mines:
		var e = _mines[id]
		if e == null or not is_instance_valid(e.get("node")):
			drop.append(id)
	for id in drop:
		_mines.erase(id)
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `NVG tests passed`, `Settings tests passed`, `Shaders tests passed`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add "standalone mods/ThermalVTK/mods/ThermalVTK/VTKNVG.gd"
git commit -m "ThermalVTK 2.1.0: NVG stops pushing unchanged uniforms and retries mines forever"
```

---

### Task 8: Version, changelog, full stand

**Files:**
- Modify: `standalone mods/ThermalVTK/mod.txt`
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/version.txt`
- Modify: `standalone mods/ThermalVTK/README.md`
- Modify: `standalone mods/ThermalVTK/CHANGELOG.md`

**Interfaces:**
- Consumes: everything above.
- Produces: the shipped 2.1.0 metadata.

- [ ] **Step 1: Bump both version files**

`mod.txt`: `version="2.1.0"`.
`version.txt`: `2.1.0` (single line).
`README.md`: the version label line that currently reads `2.0.0` → `2.1.0`.

- [ ] **Step 2: Add the changelog section**

At the top of `CHANGELOG.md`, under `# Changelog`:

```markdown
## [2.1.0] - 2026-10-25

### Added
- X-ray Triggers now work on their own: shots, shouts and footsteps show through walls even with NPC highlighting switched off.

### Changed
- Less per-frame work when many NPCs are in view, so heavy fights cost fewer frames.
- Reveal flashes no longer push nearby outlines out of view when the scene is crowded.
- The debug log reports the ESP frame time.

### Fixed
- The friendly-nomad diamond no longer shows through walls and cover; a live X-ray reveal still shows it on purpose.
- Corpses beyond the Distance setting are no longer outlined.
```

- [ ] **Step 3: Run the whole stand**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: every script `ok`, every test `VERDICT: ok`, final `Tests passed: 35 file(s)`, exit 0.

- [ ] **Step 4: Commit**

```bash
git add "standalone mods/ThermalVTK/mod.txt" "standalone mods/ThermalVTK/mods/ThermalVTK/version.txt" "standalone mods/ThermalVTK/README.md" "standalone mods/ThermalVTK/CHANGELOG.md"
git commit -m "ThermalVTK 2.1.0: bump version and changelog"
```

- [ ] **Step 5: Hand over the manual checklist**

Report the list from the spec's "Ручная проверка в игре" to the user; do not claim the marker or the fps gain is verified until they run it.

---

## Self-Review

- Spec coverage: frame allocations (Task 3), independent X-ray (Task 4), marker raycast (Task 5), parked hooks and hot `%` (Task 6), NVG uniforms/mines/pending (Task 7), corpses under Distance (Task 3), version/changelog (Task 8), measurement (`_dbg_draw_ms`, Task 3).
- Type consistency: `set_layers(bool,bool)` used by `ThermalVTK`; `clear_not_in(Dictionary)` fed by `_want`; `pick_nearest(Array,int,Variant)` called with `_keep_pool`; `_marker_make` now returns `MeshInstance3D`; `_los_exclude`/`_subtree_rids` use `Array[RID]` so the exclude list can go straight into `PhysicsRayQueryParameters3D.exclude`; `_mine_watch` values are dictionaries in every writer and reader; `_weapon` is untyped so `FakeWeapon` can be injected.
- Test wiring: every direct `_draw` caller arms `set_layers` (Task 4 table), because `_draw` is otherwise only reached through the `_process` gate; `los_force` sets `_frame` to the id's LOS phase instead of assuming a fixed one.
- Review Focus tests: all five lines have a named test in the task that owns the code.
- Out of scope: `Environment` cache, `_reseed` rewrite, marker distance, CAP size, separate marker toggle.
