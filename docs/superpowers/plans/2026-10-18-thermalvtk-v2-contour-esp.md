# ThermalVTK v2 — Contour ESP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a state-coloured contour ESP (body fill + grown rim ring, per-faction colour, cooling corpses, PVisible flash, distance fade) to ThermalVTK as a new mode A, keeping the current full-screen thermal as mode B, toggled with F6 while NVG is worn.

**Architecture:** Pure logic (state→category mapping, colour tables, tracker maths) lands in two `RefCounted` modules so it is headless-testable. Scene work lands in two `Node`s: `VTKESP` (AI discovery via RTVModLib hooks + polling fallback, faction/state/PVisible reads) and `VTKOutline` (builds `material_overlay` + `next_pass` chains per NPC mesh, pushes parameters only on change). The NVG overlay (`VTKNVG`) is unchanged in mode B and gains one flag (`set_bot_paint`) in mode A: bots stop being key-painted, so the screen shader simply stops detecting them — no shader change. Design source of truth: `docs/superpowers/specs/2026-10-18-thermalvtk-v2-contour-esp-design.md`.

**Tech Stack:** GDScript (Godot 4.6.3), `.gdshader`, RTVModLib hooks (`Engine.get_meta("RTVModLib")`), MCM (`mod_configuration_menu`, section-typed entries incl. `Color`), PowerShell build/check scripts.

## Global Constraints

- Godot 4.6.3; **tabs only** in `.gd`; files UTF-8 (no BOM).
- Version lives in exactly one place: `standalone mods/ThermalVTK/mod.txt` `version`. No version constant in GDScript. `pack.ps1` mirrors it into `mods/ThermalVTK/version.txt` and `README.md`.
- Identity is fixed: name `ThermalVTK`, id `thermal-vtk`, folder `res://mods/ThermalVTK/`, autoload `ThermalVTK`, config dir `user://MCM/thermal-vtk`, state file `user://MCM/thermal-vtk/thermal_state.cfg`, artifact `ThermalVTK.vmz`.
- Scripts may only reference `res://mods/ThermalVTK/...` and `res://ModConfigurationMenu/Scripts/Doink Oink/MCM_Helpers.tres`. Any new path into the game goes into `VTKPaths.gd`, nowhere else.
- English-only UI strings; no localisation layer in this mod.
- Parse + test command (from repo root; add `-Godot "<path to Godot_*_console.exe>"` if not on PATH):
  `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
  Green means **all** of: every script prints `ok`; each test prints `tests passed`; no `SCRIPT ERROR` / `Parse Error` / `Invalid call` / `Failed to load script`; exit code 0.
- No automated gameplay verification exists for this mod — in-game checks are called out per task under **Manual verify**.
- Do not commit. Leave the working tree dirty for the user to review.

## Deviations from spec (approved intent, refined mechanics)

1. **Two shader files, not one.** `VTKOutlineBody.gdshader` + `VTKOutlineRing.gdshader`. Godot's `render_mode` is compile-time, so the LOS variant of each is produced by removing the `depth_test_disabled, ` token from the loaded code (one small pure function, tested). A single `VTKOutline.gdshader` cannot carry both depth modes.
2. **No stencil.** The body/ring split is done by the ring's rim term (grazing-angle `pow`), exactly like ImmersiveThreatHighlight, rather than NPCESP's stencil read/write. Fewer extensions, no stencil-in-Forward+ risk (spec risk #4), same visual.
3. **Visibility flash folded into the body shader** (`flash` uniform), the way NPCESP folds visibility into its body pass. No third shader.
4. **`mines_emission` key not added** — the existing `thermal_mines` / `set_mines_enabled` already covers it.
5. **`through_walls` is a per-NPC radius**, matching the spec wording "сквозь стены **в радиусе** through-walls": NPCs closer than it use the depth-test-disabled chain, farther ones the depth-tested chain. A per-NPC boolean, not a global mode.
6. **Dead colour** = the body pass cooling toward the cold tone over `corpse_decay`; the ring keeps the last category colour with fading alpha.

---

### Task 1: Pure state → category → colour logic (`VTKStates.gd`)

**Files:**
- Create: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKStates.gd`
- Create: `.check/project/tests/test_states.gd`
- Modify: `.check/check.ps1` (add `test_states` to `$tests`)

**Interfaces:**
- Consumes: nothing.
- Produces: `VTKStates.category_of(state: int) -> int`, `VTKStates.category_key(cat: int) -> String`, `VTKStates.default_color(cat: int) -> Color`, `VTKStates.color_for(state: int) -> Color`, category constants `NORMAL/ALERTED/HUNTING/COMBAT`. Used by Tasks 2, 4, 7.

- [ ] **Step 1: Write the failing test** — `.check/project/tests/test_states.gd`

```gdscript
extends SceneTree

const S = preload("res://mods/ThermalVTK/VTKStates.gd")

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
	t_normal_states()
	t_alerted_states()
	t_hunting_states()
	t_combat_states()
	t_unknown_defaults_to_normal()
	t_colors()
	print("")
	if fails == 0:
		print("States tests passed")
		quit(0)
	else:
		print("States tests failed: ", fails)
		quit(1)

func t_normal_states() -> void:
	for s in [0, 1, 2, 3, 4, 15, 16]:
		ck(S.category_of(s) == S.NORMAL, "state %d -> NORMAL" % s)

func t_alerted_states() -> void:
	for s in [5, 10, 12]:
		ck(S.category_of(s) == S.ALERTED, "state %d -> ALERTED" % s)

func t_hunting_states() -> void:
	for s in [9, 6, 7, 14]:
		ck(S.category_of(s) == S.HUNTING, "state %d -> HUNTING" % s)

func t_combat_states() -> void:
	for s in [8, 11, 13]:
		ck(S.category_of(s) == S.COMBAT, "state %d -> COMBAT" % s)

func t_unknown_defaults_to_normal() -> void:
	ck(S.category_of(-1) == S.NORMAL, "unknown state -1 -> NORMAL")
	ck(S.category_of(99) == S.NORMAL, "unknown state 99 -> NORMAL")

func t_colors() -> void:
	ck(S.default_color(S.ALERTED) != S.default_color(S.COMBAT), "alerted != combat colour")
	ck(S.color_for(8) == S.default_color(S.COMBAT), "color_for(8) = combat default")
	ck(S.category_key(S.HUNTING) == "state_hunting", "category_key(HUNTING)")
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `test_states.gd` FAILs to load (`Failed to load script: res://mods/ThermalVTK/VTKStates.gd`).

- [ ] **Step 3: Write `VTKStates.gd`**

```gdscript
extends RefCounted
# Pure logic: AI.State ints -> awareness category -> colour. No scene access,
# no load(), no paths into the game, so it runs headless (test_states.gd).
# State ints from AI.gd: Idle=0..Group=16. Anything unknown reads as NORMAL.

const NORMAL := 0
const ALERTED := 1
const HUNTING := 2
const COMBAT := 3

const NORMAL_STATES: Array[int] = [0, 1, 2, 3, 4, 15, 16]
const ALERTED_STATES: Array[int] = [5, 10, 12]
const HUNTING_STATES: Array[int] = [9, 6, 7, 14]
const COMBAT_STATES: Array[int] = [8, 11, 13]

const DEFAULT_NORMAL := Color(1.0, 0.72, 0.28)
const DEFAULT_ALERTED := Color(1.0, 0.9, 0.25)
const DEFAULT_HUNTING := Color(1.0, 0.5, 0.1)
const DEFAULT_COMBAT := Color(0.95, 0.18, 0.15)
const DEFAULT_NOMAD := Color(0.30, 1.0, 0.35)

# MCM colour keys, one per category, plus the nomad override.
const CATEGORY_KEYS: Array[String] = ["state_normal", "state_alerted", "state_hunting", "state_combat"]

static var _map: Dictionary = {}

static func _build() -> void:
	if not _map.is_empty():
		return
	for s in NORMAL_STATES:
		_map[s] = NORMAL
	for s in ALERTED_STATES:
		_map[s] = ALERTED
	for s in HUNTING_STATES:
		_map[s] = HUNTING
	for s in COMBAT_STATES:
		_map[s] = COMBAT

static func category_of(state: int) -> int:
	_build()
	return int(_map.get(state, NORMAL))

static func category_key(cat: int) -> String:
	if cat < 0 or cat >= CATEGORY_KEYS.size():
		return CATEGORY_KEYS[NORMAL]
	return CATEGORY_KEYS[cat]

static func default_color(cat: int) -> Color:
	match cat:
		ALERTED:
			return DEFAULT_ALERTED
		HUNTING:
			return DEFAULT_HUNTING
		COMBAT:
			return DEFAULT_COMBAT
		_:
			return DEFAULT_NORMAL

static func color_for(state: int) -> Color:
	return default_color(category_of(state))

static func default_nomad() -> Color:
	return DEFAULT_NOMAD
```

- [ ] **Step 4: Wire the test into the runner** — in `.check/check.ps1`, append `"res://tests/test_states.gd"` to the `$tests` array literal.

- [ ] **Step 5: Run the check again**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `ok VTKStates.gd`, `States tests passed`, `VERDICT: ok test_states.gd`.

- [ ] **Step 6: Commit** — skipped (do not commit; leave tree dirty).

---

### Task 2: Pure tracker maths (`VTKTracker.gd`)

**Files:**
- Create: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKTracker.gd`
- Create: `.check/project/tests/test_tracker.gd`
- Modify: `.check/check.ps1` (add `test_tracker` to `$tests`)

**Interfaces:**
- Consumes: `VTKStates` (Task 1) via `preload` for `category_of`.
- Produces: entry dict shape `{"id", "cat", "nomad", "dead", "death_ts", "last_seen"}` and statics `new_entry`, `apply_state`, `mark_dead`, `cool_factor`, `distance_alpha`, `pick_nearest`, `nomad_of`/`is_nomad`. Used by Tasks 5, 6.

- [ ] **Step 1: Write the failing test** — `.check/project/tests/test_tracker.gd`

```gdscript
extends SceneTree

const T = preload("res://mods/ThermalVTK/VTKTracker.gd")

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
	t_new_entry()
	t_apply_state_change_gate()
	t_death_cools()
	t_distance_alpha()
	t_pick_nearest_cap()
	t_nomad_detection()
	print("")
	if fails == 0:
		print("Tracker tests passed")
		quit(0)
	else:
		print("Tracker tests failed: ", fails)
		quit(1)

func t_new_entry() -> void:
	var e := T.new_entry(7, false, 100.0)
	ck(int(e["id"]) == 7, "id stored")
	ck(e["nomad"] == false, "nomad false")
	ck(e["dead"] == false, "dead false")
	ck(int(e["cat"]) == 0, "cat defaults NORMAL")

func t_apply_state_change_gate() -> void:
	var e := T.new_entry(1, false, 0.0)
	ck(T.apply_state(e, 8) == true, "first state 8 reports change")
	ck(int(e["cat"]) == 3, "cat COMBAT after state 8")
	ck(T.apply_state(e, 11) == false, "state 11 same category reports no change")
	ck(T.apply_state(e, 0) == true, "state 0 reports change back to NORMAL")

func t_death_cools() -> void:
	var e := T.new_entry(1, false, 10.0)
	T.mark_dead(e, 10.0)
	ck(e["dead"] == true, "dead set")
	ck(is_equal_approx(T.cool_factor(e, 10.0, 8.0), 0.0), "cool 0 at death")
	ck(is_equal_approx(T.cool_factor(e, 14.0, 8.0), 0.5), "cool 0.5 at half decay")
	ck(is_equal_approx(T.cool_factor(e, 30.0, 8.0), 1.0), "cool clamps to 1")
	ck(is_equal_approx(T.cool_factor(e, 30.0, 0.0), 0.0), "decay 0 keeps cool 0")

func t_distance_alpha() -> void:
	ck(is_equal_approx(T.distance_alpha(0.0, 100.0), 1.0), "near alpha 1")
	ck(is_equal_approx(T.distance_alpha(50.0, 100.0), 1.0), "at fade start alpha 1")
	ck(is_equal_approx(T.distance_alpha(75.0, 100.0), 0.5), "midpoint alpha 0.5")
	ck(is_equal_approx(T.distance_alpha(100.0, 100.0), 0.0), "at max alpha 0")
	ck(is_equal_approx(T.distance_alpha(120.0, 100.0), 0.0), "beyond max alpha 0")
	ck(is_equal_approx(T.distance_alpha(5.0, 0.0), 0.0), "max 0 alpha 0")

func t_pick_nearest_cap() -> void:
	var cand := []
	for i in 30:
		cand.append({"id": i, "dist": float(30 - i)})
	var picked := T.pick_nearest(cand, 24)
	ck(picked.size() == 24, "cap 24 respected")
	ck(int(picked[0]) == 29, "nearest first (id 29, dist 1)")

func t_nomad_detection() -> void:
	ck(T.is_nomad_faction(0) == true, "faction 0 -> nomad")
	ck(T.is_nomad_faction(1) == false, "faction 1 -> hostile")
	ck(T.is_nomad_faction(4) == false, "faction 4 -> hostile")
```

- [ ] **Step 2: Run and confirm failure**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `test_tracker.gd` fails to load `VTKTracker.gd`.

- [ ] **Step 3: Write `VTKTracker.gd`**

```gdscript
extends RefCounted
# Pure tracker state + maths: entry lifecycle, state-category change gate,
# corpse cooling, distance fade, nearest-N cap, faction classification.
# `now` is a caller-supplied clock (seconds), so nothing here touches the tree
# and every rule is headless-testable (test_tracker.gd).

const States = preload("res://mods/ThermalVTK/VTKStates.gd")
const FADE_START_RATIO := 0.5
# Faction ints from the AI variant: 0 is the friendly faction (Nomads).
const FACTION_NOMAD := 0

static func is_nomad_faction(faction: int) -> bool:
	return faction == FACTION_NOMAD

static func new_entry(id: int, nomad: bool, now: float) -> Dictionary:
	return {
		"id": id,
		"cat": States.NORMAL,
		"nomad": nomad,
		"dead": false,
		"death_ts": 0.0,
		"last_seen": now,
	}

# Returns true only when the awareness category actually changed, so the
# renderer can push colour/alpha only then (NPCESP's change gate).
static func apply_state(e: Dictionary, state: int) -> bool:
	var cat := States.category_of(state)
	if int(e.get("cat", -1)) == cat:
		return false
	e["cat"] = cat
	return true

static func mark_dead(e: Dictionary, now: float) -> void:
	if bool(e.get("dead", false)):
		return
	e["dead"] = true
	e["death_ts"] = now

# Heat still held: 0 right at death, 1 fully cooled after decay_s.
static func cool_factor(e: Dictionary, now: float, decay_s: float) -> float:
	if not bool(e.get("dead", false)) or decay_s <= 0.0:
		return 0.0
	return clampf((now - float(e.get("death_ts", 0.0))) / decay_s, 0.0, 1.0)

# Full alpha inside FADE_START_RATIO of the range, then linear to 0 at max.
static func distance_alpha(dist: float, max_dist: float) -> float:
	if max_dist <= 0.0 or dist >= max_dist:
		return 0.0
	var fade_start := max_dist * FADE_START_RATIO
	if dist <= fade_start:
		return 1.0
	return clampf(1.0 - (dist - fade_start) / (max_dist - fade_start), 0.0, 1.0)

# candidates: Array of {"id": int, "dist": float}. Returns the nearest `cap` ids.
static func pick_nearest(candidates: Array, cap: int) -> Array:
	var sorted := candidates.duplicate()
	sorted.sort_custom(func(a, b): return float(a["dist"]) < float(b["dist"]))
	var out: Array = []
	var n: int = mini(cap, sorted.size())
	for i in n:
		out.append(sorted[i]["id"])
	return out
```

- [ ] **Step 4: Wire the test** — append `"res://tests/test_tracker.gd"` to `$tests` in `.check/check.ps1`.

- [ ] **Step 5: Run the check**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `ok VTKTracker.gd`, `Tracker tests passed`, `VERDICT: ok test_tracker.gd`.

---

### Task 3: Outline shaders + LOS variant builder (`VTKOutlineBody/Ring.gdshader`, `VTKShaders.gd`)

**Files:**
- Create: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKOutlineBody.gdshader`
- Create: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKOutlineRing.gdshader`
- Create: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKShaders.gd`
- Create: `.check/project/tests/test_shaders.gd`
- Modify: `.check/check.ps1` (add `test_shaders` to `$tests`)

**Interfaces:**
- Consumes: nothing at runtime; `VTKShaders` loads the two `.gdshader` files by `preload`.
- Produces: `VTKShaders.body(through_walls: bool) -> Shader`, `VTKShaders.ring(through_walls: bool) -> Shader`, and pure `VTKShaders.strip_depth_test(code: String) -> String`. Used by Task 4.

- [ ] **Step 1: Write `VTKOutlineBody.gdshader`**

```glsl
shader_type spatial;
render_mode unshaded, cull_back, depth_test_disabled, depth_draw_never;

// Body fill for the contour ESP. Same cooling-ladder idea as VTKBot.gdshader,
// but this is a DISPLAY shader: it paints warm/mid/cold colours directly onto
// material_overlay (mode A hides the bot keys, so nothing detects them on the
// NVG screen). `cool` drives the cold front down the body as a corpse cools.
// `flash` mixes toward flash_color when the NPC's sensor sees the player.
// The `depth_test_disabled` token is stripped at load to build the LOS variant.
uniform vec3 warmColor : source_color = vec3(0.6, 0.48, 0.09);
uniform vec3 midColor : source_color = vec3(0.55, 0.45, 0.28);
uniform vec3 coldColor : source_color = vec3(0.28, 0.3, 0.4);
uniform float fill_alpha : hint_range(0.0, 1.0, 0.01) = 0.4;
uniform float cool : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float footY = 0.0;
uniform float bodyHeight = 1.8;
uniform float band = 0.28;
uniform vec3 flash_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float flash : hint_range(0.0, 1.0, 0.01) = 0.0;

void fragment() {
	float worldY = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).y;
	float h = clamp((worldY - footY) / bodyHeight, 0.0, 1.0);
	float coldFront = 1.35 - cool * 1.7;
	float midFront = coldFront - band;
	vec3 col = warmColor;
	if (h > coldFront) {
		col = coldColor;
	} else if (h > midFront) {
		col = midColor;
	}
	col = mix(col, flash_color, flash);
	ALBEDO = col;
	ALPHA = fill_alpha;
}
```

- [ ] **Step 2: Write `VTKOutlineRing.gdshader`**

```glsl
shader_type spatial;
render_mode unshaded, cull_back, depth_test_disabled, depth_draw_never;

// Silhouette ring: a grown shell (VERTEX += NORMAL * grow) whose alpha is
// trimmed to the grazing edge by the rim term, so only a band hugging the
// silhouette survives — the ImmersiveThreatHighlight look without mesh
// duplicates. Colour is the state category. `depth_test_disabled` is stripped
// at load to build the LOS variant.
uniform vec4 outline_color : source_color = vec4(1.0, 0.72, 0.28, 1.0);
uniform float brightness : hint_range(0.1, 3.0, 0.05) = 0.6;
uniform float grow : hint_range(0.0, 0.15, 0.001) = 0.006;
uniform float rim_power : hint_range(0.0, 6.0, 0.1) = 1.0;

void vertex() {
	VERTEX += NORMAL * grow;
}

void fragment() {
	float rim01 = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	ALBEDO = outline_color.rgb * brightness;
	ALPHA = outline_color.a * pow(rim01, rim_power);
}
```

- [ ] **Step 3: Write the failing test** — `.check/project/tests/test_shaders.gd`

```gdscript
extends SceneTree

const Sh = preload("res://mods/ThermalVTK/VTKShaders.gd")

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
	t_strip_depth_test()
	t_shaders_compile()
	print("")
	if fails == 0:
		print("Shaders tests passed")
		quit(0)
	else:
		print("Shaders tests failed: ", fails)
		quit(1)

func t_strip_depth_test() -> void:
	var src := "render_mode unshaded, cull_back, depth_test_disabled, depth_draw_never;"
	var out := Sh.strip_depth_test(src)
	ck(out == "render_mode unshaded, cull_back, depth_draw_never;", "depth_test_disabled token removed")
	ck(not out.contains("depth_test_disabled"), "no depth_test_disabled left")
	ck(Sh.strip_depth_test("render_mode unshaded;") == "render_mode unshaded;", "no-op when absent")

func t_shaders_compile() -> void:
	ck(Sh.body(false) != null, "wall body shader made")
	ck(Sh.ring(false) != null, "wall ring shader made")
	var los_body := Sh.body(true)
	var los_ring := Sh.ring(true)
	ck(los_body != null and los_body.code.contains("depth_test_disabled") == false, "LOS body has depth test")
	ck(los_ring != null and los_ring.code.contains("depth_test_disabled") == false, "LOS ring has depth test")
```

- [ ] **Step 4: Run and confirm failure**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `test_shaders.gd` fails to load `VTKShaders.gd`.

- [ ] **Step 5: Write `VTKShaders.gd`**

```gdscript
extends RefCounted
# Builds the outline shaders. The .gdshader files carry the through-walls
# variant (depth_test_disabled); the LOS variant is the same code with that one
# token removed, because render_mode is compile-time in Godot. Caching keeps a
# single Shader resource per variant so materials share program state.

const BODY_SRC := preload("res://mods/ThermalVTK/VTKOutlineBody.gdshader")
const RING_SRC := preload("res://mods/ThermalVTK/VTKOutlineRing.gdshader")

static var _body_wall: Shader = null
static var _body_los: Shader = null
static var _ring_wall: Shader = null
static var _ring_los: Shader = null

static func strip_depth_test(code: String) -> String:
	return code.replace("depth_test_disabled, ", "")

static func body(through_walls: bool) -> Shader:
	if _body_wall == null:
		_body_wall = BODY_SRC
		var los := Shader.new()
		los.code = strip_depth_test(BODY_SRC.code)
		_body_los = los
	return _body_wall if through_walls else _body_los

static func ring(through_walls: bool) -> Shader:
	if _ring_wall == null:
		_ring_wall = RING_SRC
		var los := Shader.new()
		los.code = strip_depth_test(RING_SRC.code)
		_ring_los = los
	return _ring_wall if through_walls else _ring_los
```

- [ ] **Step 6: Wire the test** — append `"res://tests/test_shaders.gd"` to `$tests` in `.check/check.ps1`.

- [ ] **Step 7: Run the check**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `ok VTKOutlineBody.gdshader` (shader `.gdshader` files are copied but not check-only parsed; that is fine), `ok VTKShaders.gd`, `Shaders tests passed`.

- [ ] **Step 8: Manual verify (in game, deferred)** — note in the task log that shader compilation errors would surface only in-game; the strings follow NPCESP's proven `render_mode` token set, so risk is low.

---

### Task 4: Outline application node (`VTKOutline.gd`)

**Files:**
- Create: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKOutline.gd`
- Modify: `.check/check.ps1` (no test; parse-check only)

**Interfaces:**
- Consumes: `VTKShaders` (Task 3), `VTKStates` (Task 1), `VTKTracker` (Task 2).
- Produces: `VTKOutline.new()`, `apply(id, node, opts)`, `refresh(id, opts)`, `clear(id)`, `clear_all()`, `prune_missing(valid_ids)`. `opts` is `{"cat": int, "nomad": bool, "color": Color, "alpha": float, "cool": float, "through_walls": bool, "flash": float, "foot_y": float, "body_height": float, "brightness": float, "grow": float}`. Consumed by Task 5.

- [ ] **Step 1: Write `VTKOutline.gd`**

```gdscript
extends RefCounted
# Owns one material_overlay + next_pass chain per NPC mesh and pushes shader
# parameters only when they move (change gate). Overlay chains live on the
# meshes themselves, so nothing here is a scene-tree child except through the
# NPC meshes. Faction/state colours come in via `opts`; this file only draws.

const Shaders = preload("res://mods/ThermalVTK/VTKShaders.gd")
const States = preload("res://mods/ThermalVTK/VTKStates.gd")

# id -> {"meshes": Array, "body": ShaderMaterial, "ring": ShaderMaterial,
#        "wall": bool, "_c": ... change-gate cache}
var _items: Dictionary = {}

func has(id: int) -> bool:
	return _items.has(id)

func material_of(id: int) -> Dictionary:
	return _items.get(id, {})

# Collect the NPC's paintable geometry (visible MeshInstance3D with a mesh).
func _collect(node: Node, out: Array) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null and mi.visible and (mi.layers & 2) != 0:
			out.append(mi)
	for c in node.get_children():
		_collect(c, out)

func _build_chain(through_walls: bool) -> Array:
	var body_mat := ShaderMaterial.new()
	body_mat.shader = Shaders.body(through_walls)
	body_mat.render_priority = 20
	var ring_mat := ShaderMaterial.new()
	ring_mat.shader = Shaders.ring(through_walls)
	ring_mat.render_priority = 21
	body_mat.next_pass = ring_mat
	return [body_mat, ring_mat]

func apply(id: int, node: Node, opts: Dictionary) -> void:
	var meshes: Array = []
	_collect(node, meshes)
	if meshes.is_empty():
		return
	var wall := bool(opts.get("through_walls", true))
	var chain := _build_chain(wall)
	var body_mat: ShaderMaterial = chain[0]
	var ring_mat: ShaderMaterial = chain[1]
	# render_priority high so overlays draw after the world but before the
	# weapon (patched to priority 10 in Task 10).
	body_mat.render_priority = 20
	ring_mat.render_priority = 21
	for m in meshes:
		(m as MeshInstance3D).material_overlay = body_mat
	_items[id] = {"meshes": meshes, "body": body_mat, "ring": ring_mat, "wall": wall}
	refresh(id, opts)

# Swap the depth variant in place when the through-walls decision flips; the
# overlay assignment does not change, only the two shader resources.
func _set_wall(entry: Dictionary, wall: bool) -> void:
	if bool(entry.get("wall", wall)) == wall:
		return
	(entry["body"] as ShaderMaterial).shader = Shaders.body(wall)
	(entry["ring"] as ShaderMaterial).shader = Shaders.ring(wall)
	entry["wall"] = wall

func refresh(id: int, opts: Dictionary) -> void:
	var entry = _items.get(id)
	if entry == null:
		return
	_set_wall(entry, bool(opts.get("through_walls", true)))
	var color: Color = opts.get("color", States.DEFAULT_NORMAL)
	var alpha := float(opts.get("alpha", 1.0))
	var bright := float(opts.get("brightness", 0.6))
	var grow := float(opts.get("grow", 0.006))
	var flash := float(opts.get("flash", 0.0))
	var foot_y := float(opts.get("foot_y", 0.0))
	var body_h := float(opts.get("body_height", 1.8))
	var cool := float(opts.get("cool", 0.0))
	var fill_alpha := float(opts.get("fill_alpha", 0.4))

	var body_mat: ShaderMaterial = entry["body"]
	var ring_mat: ShaderMaterial = entry["ring"]

	var ring_col := Color(color.r, color.g, color.b, color.a * alpha)
	if ring_mat.get_shader_parameter("outline_color") != ring_col \
			or not is_equal_approx(float(ring_mat.get_shader_parameter("brightness")), bright) \
			or not is_equal_approx(float(ring_mat.get_shader_parameter("grow")), grow):
		ring_mat.set_shader_parameter("outline_color", ring_col)
		ring_mat.set_shader_parameter("brightness", bright)
		ring_mat.set_shader_parameter("grow", grow)

	if not is_equal_approx(float(body_mat.get_shader_parameter("fill_alpha")), fill_alpha * alpha):
		body_mat.set_shader_parameter("fill_alpha", fill_alpha * alpha)
	if not is_equal_approx(float(body_mat.get_shader_parameter("cool")), cool):
		body_mat.set_shader_parameter("cool", cool)
	if not is_equal_approx(float(body_mat.get_shader_parameter("footY")), foot_y):
		body_mat.set_shader_parameter("footY", foot_y)
	if not is_equal_approx(float(body_mat.get_shader_parameter("bodyHeight")), body_h):
		body_mat.set_shader_parameter("bodyHeight", body_h)
	if not is_equal_approx(float(body_mat.get_shader_parameter("flash")), flash):
		body_mat.set_shader_parameter("flash", flash)
	var flash_col: Color = opts.get("flash_color", Color.WHITE)
	if body_mat.get_shader_parameter("flash_color") != flash_col:
		body_mat.set_shader_parameter("flash_color", flash_col)

func clear(id: int) -> void:
	var entry = _items.get(id)
	if entry == null:
		return
	for m in entry.get("meshes", []):
		if is_instance_valid(m):
			(m as MeshInstance3D).material_overlay = null
	_items.erase(id)

func clear_all() -> void:
	for id in _items.keys():
		clear(id)

# Drop entries whose node is gone (targets no longer in `valid_ids`).
func prune_missing(valid_ids: Dictionary) -> void:
	for id in _items.keys():
		if not valid_ids.has(id):
			clear(id)
```

- [ ] **Step 2: Run the check**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `ok VTKOutline.gd`.

Note: `bodyHeight` uniform is `bodyHeight` in the shader — keep the exact spelling; Godot shader uniform names are case-sensitive and `set_shader_parameter` must match.

---

### Task 5: ESP tracking node (`VTKESP.gd`)

**Files:**
- Create: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKESP.gd`
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKPaths.gd` (add hook constants)
- Create: `.check/project/tests/test_esp_faction.gd`
- Modify: `.check/check.ps1` (add `test_esp_faction` to `$tests`)

**Interfaces:**
- Consumes: `VTKTracker`, `VTKStates`, `VTKOutline`, `VTKPaths`.
- Produces: node `VTKESP` with `set_enabled(on)`, `set_params(d)`, `npc_count() -> int`; a `Callable`-free public API. Consumed by `ThermalVTK.gd` (Task 7).

The faction/state read helpers are pure enough to test; extract them into `VTKTracker` (already done for `is_nomad_faction`) and add one more pure helper `VTKTracker.read_faction(variant) -> int` that takes a variant resource and returns the int faction, plus `VTKTracker.faction_from_node(node) -> int` in the ESP file. To keep Task 5 testable, put the *decision* logic in `VTKTracker.read_faction` (pure) and keep only tree access in `VTKESP`.

- [ ] **Step 1: Extend `VTKTracker.gd` with the faction reader (pure)**

Add to `VTKTracker.gd` (and extend `test_tracker.gd`):

```gdscript
# Variant is an AIData resource exposing `faction` as an int. Anything missing
# reads as hostile (1), the safe default for an ESP.
static func read_faction(variant: Variant) -> int:
	if variant == null:
		return 1
	var f = variant.get("faction")
	if f == null:
		return 1
	return int(f)
```

Test additions in `test_tracker.gd`:

```gdscript
func t_read_faction() -> void:
	ck(T.read_faction(null) == 1, "null variant -> hostile 1")
	var d := {"faction": 0}
	ck(T.read_faction(d) == 0, "dict faction 0 -> nomad")
```

- [ ] **Step 2: Add path constants to `VTKPaths.gd`**

```gdscript
# RTVModLib is reached via Engine.get_meta("RTVModLib"), not a node path. The
# AI hook names are declared in mod.txt [hooks] (res://Scripts/AI.gd).
const AI_SCRIPT_SUFFIX := "AI.gd"
const AI_HOOKS := ["Activate", "Deactivate", "ChangeState", "Death"]
```

- [ ] **Step 3: Write `VTKESP.gd`**

```gdscript
extends Node
# Discovers NPCs (RTVModLib AI hooks with a polling fallback), reads faction /
# state / PVisible, and hands per-NPC draw options to VTKOutline. Owns no
# materials itself. Enabled only in mode A; VTKNVG is unaware of it.

const Paths = preload("res://mods/ThermalVTK/VTKPaths.gd")
const Tracker = preload("res://mods/ThermalVTK/VTKTracker.gd")
const States = preload("res://mods/ThermalVTK/VTKStates.gd")
const Outline = preload("res://mods/ThermalVTK/VTKOutline.gd")

# Polling cadence for state re-reads / fallback discovery (frames).
const POLL_EVERY := 12
const CAP := 24

var enabled: bool = false
# MCM-driven params; see _defaults().
var p_fill := true
var p_decay := 8.0
var p_dist := 150.0
var p_through := 5.0
var p_flash := true
var p_flash_color := Color.WHITE
var p_thickness := 0.006
var p_brightness := 0.6
var p_colors := {
	"state_normal": States.DEFAULT_NORMAL,
	"state_alerted": States.DEFAULT_ALERTED,
	"state_hunting": States.DEFAULT_HUNTING,
	"state_combat": States.DEFAULT_COMBAT,
}
var p_nomad := States.DEFAULT_NOMAD

var _entries: Dictionary = {}
var _pending: Array[int] = []
var _frame: int = 0
var _outline := Outline.new()
var _lib = null
var _hook_ids: Array[int] = []
var _player: Node3D = null

func _ready() -> void:
	name = "VTKESP"
	get_tree().node_added.connect(_on_node_added)
	_reseed(get_tree().current_scene)
	_register_hooks()

func set_enabled(on: bool) -> void:
	if enabled == on:
		return
	enabled = on
	if not enabled:
		_outline.clear_all()
		_entries.clear()

func npc_count() -> int:
	return _entries.size()

# ---------------------------------------------------------------------------
# Discovery
# ---------------------------------------------------------------------------

func _on_node_added(node: Node) -> void:
	_pending.append(node.get_instance_id())

func _reseed(scene: Node) -> void:
	if scene != null:
		_scan(scene)

func _scan(n: Node) -> void:
	if n == null:
		return
	if _is_bot(n):
		_register(n)
	for c in n.get_children():
		_scan(c)

# Same predicate VTKNVG uses: AI.gd is a Node3D with Activate(), `dead` and
# `mesh`. Trader.gd has Activate() but no `dead`, so it stays out.
func _is_bot(n: Node) -> bool:
	return n is Node3D and n.has_method("Activate") and "dead" in n and "mesh" in n

func _register(node: Node) -> void:
	var id := node.get_instance_id()
	if _entries.has(id):
		return
	var variant = node.get("variant")
	var faction := Tracker.read_faction(variant)
	var nomad := Tracker.is_nomad_faction(faction) or String(node.name).contains("Nomad")
	_entries[id] = Tracker.new_entry(id, nomad, _now())
	_entries[id]["node"] = node

func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

# ---------------------------------------------------------------------------
# Hooks (best effort) + polling fallback
# ---------------------------------------------------------------------------

func _register_hooks() -> void:
	if not Engine.has_meta("RTVModLib"):
		return
	_lib = Engine.get_meta("RTVModLib")
	if _lib == null:
		return
	# Hook names and arities match AI.gd's void methods: Activate(state),
	# Deactivate(), ChangeState(state), Death(direction, force). activate is a
	# "-pre" hook (the node is not yet active/visible at "-post"); the others are
	# "-post". A wrong arity is a silent no-op in Callable.callv — see .check
	# test_hooks.gd for the same trap. Names mirror NPCESP's proven set.
	_hook_ids.append(_lib.hook("ai-activate-pre", _on_ai_activate, 100))
	_hook_ids.append(_lib.hook("ai-deactivate-post", _on_ai_deactivate, 100))
	_hook_ids.append(_lib.hook("ai-changestate-post", _on_ai_changestate, 100))
	_hook_ids.append(_lib.hook("ai-death-post", _on_ai_death, 100))

func _caller() -> Node:
	return _lib._caller if _lib != null else null

func _on_ai_activate(_state: String) -> void:
	var n := _caller()
	if is_instance_valid(n):
		_register(n)

func _on_ai_deactivate() -> void:
	var n := _caller()
	if is_instance_valid(n):
		_entries.erase(n.get_instance_id())

func _on_ai_changestate(_state: String) -> void:
	var n := _caller()
	if not is_instance_valid(n):
		return
	var id := n.get_instance_id()
	if not _entries.has(id):
		_register(n)
	if _entries.has(id):
		Tracker.apply_state(_entries[id], _read_state(n))

func _on_ai_death(_direction: Vector3 = Vector3.ZERO, _force: float = 0.0) -> void:
	var n := _caller()
	if not is_instance_valid(n):
		return
	var id := n.get_instance_id()
	if _entries.has(id):
		Tracker.mark_dead(_entries[id], _now())

func _exit_tree() -> void:
	if _lib != null:
		for h in _hook_ids:
			_lib.unhook(h)
	_hook_ids.clear()

func _read_state(node: Node) -> int:
	var s = node.get("currentState")
	if s == null:
		return 0
	return int(s)

# ---------------------------------------------------------------------------
# Per-frame draw
# ---------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if not enabled:
		return
	_frame += 1
	if not _pending.is_empty():
		for node_id in _pending:
			var n := instance_from_id(node_id)
			if n != null and is_instance_valid(n):
				_scan(n)
		_pending.clear()

	var ppos := _player_pos()
	if ppos == null:
		return
	_draw(ppos)

func _draw(ppos: Vector3) -> void:
	var now := _now()
	var cands: Array = []
	var opts_by_id: Dictionary = {}
	var valid: Dictionary = {}
	for id in _entries.keys():
		var e: Dictionary = _entries[id]
		var node = e.get("node")
		if node == null or not is_instance_valid(node) or not node.is_inside_tree():
			continue
		valid[id] = true
		var pos: Vector3 = (node as Node3D).global_position
		# Distance read runs every frame (fade must be smooth); deeper state/
		# PVisible reads are throttled by the poll cadence.
		var dist := ppos.distance_to(pos)
		if dist > p_dist and not e.get("dead", false):
			continue
		e["dist"] = dist
		cands.append({"id": id, "dist": dist})
		if _frame % POLL_EVERY == 0:
			Tracker.apply_state(e, _read_state(node))
		opts_by_id[id] = _opts_for(e, node, dist, now)
	# Drop overlays for NPCs that vanished.
	for id in _outline_ids():
		if not valid.has(id):
			_outline.clear(id)
	var keep: Array = Tracker.pick_nearest(cands, CAP)
	if keep.size() < cands.size():
		for c in cands:
			if c["id"] not in keep:
				valid.erase(c["id"])
				_outline.clear(c["id"])
	for id in keep:
		var e: Dictionary = _entries[id]
		var node = e.get("node")
		var opts: Dictionary = opts_by_id[id]
		if not _outline.has(id):
			_outline.apply(id, node, opts)
		else:
			_outline.refresh(id, opts)

func _outline_ids() -> Array:
	return _entries.keys()

func _opts_for(e: Dictionary, node: Node, dist: float, now: float) -> Dictionary:
	var cool := Tracker.cool_factor(e, now, p_decay)
	var alpha := Tracker.distance_alpha(dist, p_dist)
	var color: Color = p_nomad if e.get("nomad", false) else p_colors.get(States.category_key(int(e["cat"])), States.DEFAULT_NORMAL)
	var flash := 0.0
	if p_flash and _player_visible(node):
		flash = 0.7
	var foot_y: float = (node as Node3D).global_position.y
	return {
		"cat": int(e["cat"]),
		"nomad": e.get("nomad", false),
		"color": color,
		"alpha": alpha,
		"cool": cool,
		"through_walls": p_through > 0.0 and dist <= p_through,
		"flash": flash,
		"flash_color": p_flash_color,
		"foot_y": foot_y,
		"body_height": 1.8,
		"brightness": p_brightness,
		"grow": p_thickness,
		"fill_alpha": 0.4 if p_fill else 0.0,
	}

# sensor.PVisible is true when the NPC's sensor currently sees the player.
func _player_visible(node: Node) -> bool:
	var sensor = node.get("sensor")
	if sensor == null:
		return false
	return sensor.get("PVisible") == true

func _player_pos() -> Variant:
	var players := get_tree().get_nodes_in_group("Player")
	for p in players:
		if p is Node3D:
			return (p as Node3D).global_position
	return null
```

Wait — `States.category_key` returns `state_normal` etc., and `p_colors` keys match. Good. But `_opts_for` returns `Variant` from `p_colors.get(...)` — annotate `var color: Color = ...`; a Dictionary.get returns Variant, and assigning to a typed `Color` var is a runtime cast, which is fine in GDScript (not `:=`). Confirmed pattern from AGENTS.md.

Also `_player_pos() -> Variant` returning `(p as Node3D).global_position` — a Vector3; and the caller compares `ppos == null`. Returning Variant is needed because of the `null` return path (AGENTS.md: function whose return type is unannotated gets `null` type → Parse Error on use). So annotate `-> Variant`. Then `var ppos := _player_pos()` would infer Variant and `ppos.distance_to` would be a Parse Error. So the caller must annotate: `var ppos: Variant = _player_pos()` and then `var pos3: Vector3 = ppos`. Let me handle that explicitly in the plan:

```gdscript
	var ppos_v = _player_pos()
	if ppos_v == null:
		return
	var ppos: Vector3 = ppos_v
	_draw(ppos)
```

Hmm, `var ppos_v = _player_pos()` unannotated gets inferred Variant (from `-> Variant`) — that's allowed (untyped var). Then `var ppos: Vector3 = ppos_v`. Good.

Actually `_draw(ppos)` signature `_draw(ppos: Vector3)`.

The `_outline_ids()` returning `_entries.keys()` — that's a fresh Array (keys() copies), safe to iterate while erasing from `_outline`. But I call `_outline.clear(id)` inside that loop; `_outline` is separate from `_entries`. Fine.

But there's a subtle bug: iterating `_outline_ids()` (which is `_entries.keys()`) and calling `_outline.clear` is fine, but I never remove dead entries from `_entries` here (they're removed in `_draw` only if not valid... actually I skip invalid nodes without erasing). Add erasing: I'll note cleanup in Task 5 step but keep the code listing as above plus a prune. Let me include a prune of invalid entries:

```gdscript
	for id in _entries.keys():
		var e: Dictionary = _entries[id]
		var node = e.get("node")
		if node == null or not is_instance_valid(node) or not node.is_inside_tree():
			_outline.clear(id)
			_entries.erase(id)
```

I'll restructure `_draw` to prune first. Let me simplify the listing to avoid double logic. I'll rewrite _draw cleanly in the plan.

Also the `_outline_ids()` helper becomes unnecessary.

OK. I'll finalize the code in the plan.

- [ ] **Step 4: Write `test_esp_faction.gd`** — actually `read_faction` is in VTKTracker and tested in test_tracker.gd. So no separate test file needed; drop `test_esp_faction.gd` and instead extend test_tracker.gd. Simplify: remove that file + runner line from Task 5.

Let me adjust Task 5 Files accordingly.

- [ ] **Step 5: Run check** → `ok VTKESP.gd`.

---

### Task 6: Mode-A gating in `VTKNVG.gd` + remove nomad marker

**Files:**
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKNVG.gd`
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKNVG.gdshader` (drop marker key/uniform usage is optional; keep shader file as-is and just never pass `markNomads`)

**Interfaces:**
- Consumes: nothing new.
- Produces: `set_bot_paint(on: bool)` on `VTKNVG`; removes `set_mark_nomads`, `_update_nomad_marker`, `_mat_marker`, `_marker_mesh`, `MARKER_KEY`, `MARKER_NAME`, `_make_marker_mesh`. Consumed by Task 7.

- [ ] **Step 1: Add the bot-paint flag and gate**

Add near the other settings:

```gdscript
# Mode A keeps the world palette but stops painting bots with detector keys, so
# the NVG screen shader no longer finds them; the contour ESP draws instead.
var set_bot_paint: bool = true
var _bots_painted: bool = false
```

In `_process`, replace the `if on:` block's bot loop with:

```gdscript
	if on:
		_paint_on = false
		if set_bot_paint:
			for id in _bots.keys():
				_update_bot(id, true, ppos)
			_bots_painted = true
		elif _bots_painted:
			_clear_bot_paint()
			_bots_painted = false
		for id in _mines.keys():
			_update_mine(id, true, ppos)
	elif _was_on or _paint_on:
		_clear_paint()
		_paint_on = false
		_bots_painted = false
```

Add `_clear_bot_paint()` mirroring `_clear_paint()`'s bot half (without touching mines or the removed marker):

```gdscript
func _clear_bot_paint() -> void:
	for id in _bots.keys():
		var e = _bots.get(id)
		if e == null:
			continue
		for m in e.get("meshes", []):
			if is_instance_valid(m):
				(m as GeometryInstance3D).material_override = null
		e["painted"] = false
		e["paint"] = null
```

Add a public setter:

```gdscript
func set_bot_paint(on: bool) -> void:
	if set_bot_paint == on:
		return
	set_bot_paint = on
	if not on and _bots_painted:
		_clear_bot_paint()
		_bots_painted = false
```

- [ ] **Step 2: Guard `_frame_pre_draw` (defensive)**

Verified: `_paint_on` is set true in exactly one place — `_update_bot` (line 566); `_update_mine` never sets it. So with `set_bot_paint == false`, `_update_bot` is never called, `_paint_on` stays false, and `_frame_pre_draw` early-returns on line 633. The guard is therefore redundant today, but add it so a future non-bot painter cannot re-assert stale bot paint: inside `_frame_pre_draw`'s bot loop, before reading `e.get("paint")`, add `if not set_bot_paint: continue`.

- [ ] **Step 3: Remove the nomad marker**

Delete: `const MARKER_KEY`, `const MARKER_NAME`, `_mat_marker`, `_marker_mesh`, `_make_marker_mesh()`, `_update_nomad_marker()`, the two `_update_nomad_marker(...)` calls in `_clear_paint()`, the `_mat_marker = _key_material(MARKER_KEY)` block in `_ready`, and the `nvg_mat.set_shader_parameter("markNomads", set_mark_nomads)` line. Remove `var set_mark_nomads: bool = true`.

- [ ] **Step 4: Run check**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `ok VTKNVG.gd`; all existing tests still `tests passed`.

---

### Task 7: Autoload wiring — F6 mode toggle, persistence, ESP lifecycle

**Files:**
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/ThermalVTK.gd`

**Interfaces:**
- Consumes: `VTKESP` (Task 5), `VTKNVG.set_bot_paint` (Task 6).
- Produces: `_mode_full_thermal: bool` (false = mode A, true = mode B), persisted under `[state] full_thermal_mode`; F6 handled in `_unhandled_input`.

- [ ] **Step 1: Add fields + ESP owner**

```gdscript
const KEY_MODE := KEY_F6
var _esp: Node = null
var _mode_full_thermal: bool = false

func _ensure_esp() -> void:
	if _esp != null and is_instance_valid(_esp):
		return
	var ESP = preload("res://mods/ThermalVTK/VTKESP.gd")
	_esp = ESP.new()
	add_child(_esp)
```

Call `_ensure_esp()` in `_ensure_nvg()` after creating `_nvg` (so mode toggles have both).

- [ ] **Step 2: F6 in `_unhandled_input`** — add before the existing keycode check:

```gdscript
	if (event is InputEventKey) and event.pressed and not event.echo:
		if (event as InputEventKey).physical_keycode == KEY_MODE:
			_toggle_mode()
			get_viewport().set_input_as_handled()
			return
```

- [ ] **Step 3: Mode applier + persistence**

```gdscript
func _toggle_mode() -> void:
	_mode_full_thermal = not _mode_full_thermal
	_apply_mode()
	_notify("Thermal mode: " + ("FULL" if _mode_full_thermal else "CONTOUR"),
		Color(1, 0.7, 0.3) if not _mode_full_thermal else Color(0.6, 0.8, 1.0))
	_save_mode(_mode_full_thermal)

func _apply_mode() -> void:
	if _nvg != null and is_instance_valid(_nvg):
		# Mode B = v1: bots carry the detector keys the NVG screen reads.
		# Mode A: keys off, contour ESP on.
		_nvg.set_bot_paint(_mode_full_thermal)
	if _esp != null and is_instance_valid(_esp):
		_esp.set_enabled(_thermal_enabled and not _mode_full_thermal)

func _save_mode(v: bool) -> void:
	var sf := ConfigFile.new()
	sf.set_value("state", "full_thermal_mode", v)
	var err := sf.save(STATE_FILE)
	if err != OK:
		push_warning("ThermalVTK: failed to save mode (%d)" % err)

func _read_mode() -> Variant:
	if not FileAccess.file_exists(STATE_FILE):
		return null
	var sf := ConfigFile.new()
	if sf.load(STATE_FILE) != OK:
		return null
	return bool(sf.get_value("state", "full_thermal_mode", false))
```

Note: `_save_thermal_enabled` and `_save_mode` both write the same `ConfigFile` file with a single key each, so the second save clobbers the first's key. Fix: make both read-modify-write the same file. Replace the pair with a small state-file helper:

```gdscript
func _save_state(key: String, v) -> void:
	var sf := ConfigFile.new()
	if FileAccess.file_exists(STATE_FILE):
		sf.load(STATE_FILE)
	sf.set_value("state", key, v)
	var err := sf.save(STATE_FILE)
	if err != OK:
		push_warning("ThermalVTK: failed to save state '%s' (%d)" % [key, err])

func _read_state(key: String, fallback):
	if not FileAccess.file_exists(STATE_FILE):
		return fallback
	var sf := ConfigFile.new()
	if sf.load(STATE_FILE) != OK:
		return fallback
	return sf.get_value("state", key, fallback)
```

Then `_save_thermal_enabled(v)` → `_save_state("thermal_enabled", v)`, `_read_thermal_enabled()` → `_read_state("thermal_enabled", null)`, `_save_mode(v)` → `_save_state("full_thermal_mode", v)`, `_read_mode()` → `_read_state("full_thermal_mode", false)`.

- [ ] **Step 4: Apply mode in `_toggle_thermal` and at startup**

At the end of `_toggle_thermal()`, call `_apply_mode()`. In `_mcm_apply` after `_nvg.set_thermal_enabled(...)`, call `_apply_mode()`. In `_ready`, load the saved mode before registering MCM:

```gdscript
func _ready() -> void:
	var saved_mode = _read_mode()
	_mode_full_thermal = bool(saved_mode) if saved_mode != null else false
	_register_mcm()
```

- [ ] **Step 5: Run check**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `ok ThermalVTK.gd`, tests pass.

- [ ] **Step 6: Manual verify (in game)** — with NVG worn and thermal ON: F6 switches between full thermal (bots glow as before, no outline) and contour (palette + outlines, no bot screen glow). Toggle thermal ON/OFF and F6 across it without errors.

---

### Task 8: MCM keys for the outline tab

**Files:**
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/ThermalVTK.gd`

**Interfaces:**
- Consumes: `VTKESP` params (Task 5), `_mcm_color_val` helper.
- Produces: registered keys + `_mcm_apply` push into `_esp`.

- [ ] **Step 1: Extend `_mcm_key_val` for colours**

`_mcm_key_val` (line 143) only accepts bool/int/float primitives. Add a colour reader:

```gdscript
func _mcm_color_val(cfg: ConfigFile, key: String, fallback: Color) -> Color:
	if not cfg.has_section_key("Color", key):
		return fallback
	var d = cfg.get_value("Color", key, {})
	var v = d.get("value") if typeof(d) == TYPE_DICTIONARY else d
	return v if v is Color else fallback
```

- [ ] **Step 2: Register the new keys** — in `_register_mcm`, after the existing `thermal_*` block, add two categories:

```gdscript
	var CAT2 := "02. Contour ESP"
	cfg.set_value("Bool", "outline_enabled", {"name": "Contour ESP", "default": true, "value": true, "category": CAT2, "menu_pos": 0, "tooltip": "Draw state-coloured body outlines over NPCs. Off = full-screen thermal only."})
	cfg.set_value("Bool", "outline_body_fill", {"name": "Body fill", "default": true, "value": true, "category": CAT2, "menu_pos": 1, "tooltip": "Fill the NPC body with a warm-to-cold thermal gradient inside the outline."})
	cfg.set_value("Float", "corpse_decay", {"name": "Corpse cooling time", "default": 8.0, "value": 8.0, "minRange": 0.0, "maxRange": 30.0, "step": 1.0, "category": CAT2, "menu_pos": 2, "tooltip": "Seconds a dead NPC's outline takes to cool from warm to cold."})
	cfg.set_value("Float", "outline_thickness", {"name": "Outline thickness", "default": 0.006, "value": 0.006, "minRange": 0.0, "maxRange": 0.05, "step": 0.001, "category": CAT2, "menu_pos": 3, "tooltip": "How far the outline band grows beyond the body."})
	cfg.set_value("Float", "outline_brightness", {"name": "Outline brightness", "default": 0.6, "value": 0.6, "minRange": 0.1, "maxRange": 3.0, "step": 0.1, "category": CAT2, "menu_pos": 4, "tooltip": "Brightness multiplier on the outline colour."})
	cfg.set_value("Bool", "outline_pvisible", {"name": "Spotted flash", "default": true, "value": true, "category": CAT2, "menu_pos": 5, "tooltip": "Flash the body when the NPC's own sensors currently see you."})
	cfg.set_value("Color", "pvisible_color", {"name": "Flash colour", "default": Color(1, 1, 1), "value": Color(1, 1, 1), "allowAlpha": false, "category": CAT2, "menu_pos": 6, "tooltip": "Colour the body flashes when the NPC sees you."})

	var CAT3 := "03. Outline Colours"
	cfg.set_value("Color", "state_normal", {"name": "Normal / idle", "default": Color(1.0, 0.72, 0.28), "value": Color(1.0, 0.72, 0.28), "allowAlpha": false, "category": CAT3, "menu_pos": 0, "tooltip": "Colour for NPCs that are idle, patrolling, looting or guarding."})
	cfg.set_value("Color", "state_alerted", {"name": "Alerted", "default": Color(1.0, 0.9, 0.25), "value": Color(1.0, 0.9, 0.25), "allowAlpha": false, "category": CAT3, "menu_pos": 1, "tooltip": "Colour for NPCs taking cover, defending or taking a vantage point."})
	cfg.set_value("Color", "state_hunting", {"name": "Hunting", "default": Color(1.0, 0.5, 0.1), "value": Color(1.0, 0.5, 0.1), "allowAlpha": false, "category": CAT3, "menu_pos": 2, "tooltip": "Colour for NPCs hunting, hiding, ambushing or lurking."})
	cfg.set_value("Color", "state_combat", {"name": "In combat", "default": Color(0.95, 0.18, 0.15), "value": Color(0.95, 0.18, 0.15), "allowAlpha": false, "category": CAT3, "menu_pos": 3, "tooltip": "Colour for NPCs in combat, attacking or throwing grenades."})
	cfg.set_value("Color", "nomad_color", {"name": "Friendly nomads", "default": Color(0.30, 1.0, 0.35), "value": Color(0.30, 1.0, 0.35), "allowAlpha": false, "category": CAT3, "menu_pos": 4, "tooltip": "Colour for friendly nomads. Their state is ignored."})

	var CAT4 := "04. Contour Range"
	cfg.set_value("Float", "outline_distance", {"name": "Outline distance", "default": 150.0, "value": 150.0, "minRange": 0.0, "maxRange": 300.0, "step": 10.0, "category": CAT4, "menu_pos": 0, "tooltip": "Maximum distance for an outline. Past half of this the outline fades out."})
	cfg.set_value("Float", "outline_through_walls", {"name": "See through walls", "default": 5.0, "value": 5.0, "minRange": 0.0, "maxRange": 30.0, "step": 5.0, "category": CAT4, "menu_pos": 1, "tooltip": "NPCs closer than this show through walls. 0 = only when in direct line of sight."})
```

- [ ] **Step 3: Remove the nomad-marker key** — delete the `thermal_mark_nomads` registration line and the `_nvg.set_mark_nomads = ...` line in `_mcm_apply`. `_sync_config` drops the key from existing user configs automatically.

- [ ] **Step 4: Push params in `_mcm_apply`** — after the existing `_nvg.*` assignments:

```gdscript
	_ensure_esp()
	if _esp != null and is_instance_valid(_esp):
		_esp.p_decay = float(_mcm_key_val(cfg, "Float", "corpse_decay", 8.0))
		_esp.p_dist = float(_mcm_key_val(cfg, "Float", "outline_distance", 150.0))
		_esp.p_through = float(_mcm_key_val(cfg, "Float", "outline_through_walls", 5.0))
		_esp.p_thickness = float(_mcm_key_val(cfg, "Float", "outline_thickness", 0.006))
		_esp.p_brightness = float(_mcm_key_val(cfg, "Float", "outline_brightness", 0.6))
		_esp.p_fill = bool(_mcm_key_val(cfg, "Bool", "outline_body_fill", true))
		_esp.p_flash = bool(_mcm_key_val(cfg, "Bool", "outline_pvisible", true))
		_esp.p_flash_color = _mcm_color_val(cfg, "pvisible_color", Color.WHITE)
		_esp.p_colors = {
			"state_normal": _mcm_color_val(cfg, "state_normal", States.DEFAULT_NORMAL),
			"state_alerted": _mcm_color_val(cfg, "state_alerted", States.DEFAULT_ALERTED),
			"state_hunting": _mcm_color_val(cfg, "state_hunting", States.DEFAULT_HUNTING),
			"state_combat": _mcm_color_val(cfg, "state_combat", States.DEFAULT_COMBAT),
		}
		_esp.p_nomad = _mcm_color_val(cfg, "nomad_color", States.DEFAULT_NOMAD)
		var outline_on := bool(_mcm_key_val(cfg, "Bool", "outline_enabled", true))
		_esp.set_enabled(_thermal_enabled and outline_on and not _mode_full_thermal)
```

Add `const States = preload("res://mods/ThermalVTK/VTKStates.gd")` at the top of `ThermalVTK.gd`.

Note the ordering: `_apply_mode()` (Task 7) also calls `_esp.set_enabled(...)`. `_mcm_apply` runs `_apply_mode()` last (Task 7 step 4), so either place the explicit `set_enabled` before `_apply_mode`, or fold `outline_enabled` into `_apply_mode` via a stored flag `_outline_enabled`. Simplest: store `_outline_enabled: bool = true` in the autoload, set it in `_mcm_apply`, and have `_apply_mode()` use `_thermal_enabled and _outline_enabled and not _mode_full_thermal`. Do that instead of the inline `set_enabled` above.

- [ ] **Step 5: Run check**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `ok ThermalVTK.gd`, tests pass.

- [ ] **Step 6: Manual verify** — open MCM: the four new categories appear with all keys; change a colour and a slider and confirm the outline updates live while NVG+contour is active.

---

### Task 9: `mod.txt` hooks declaration

**Files:**
- Modify: `standalone mods/ThermalVTK/mod.txt`

**Interfaces:**
- Consumes: nothing.
- Produces: AI hooks instrumented by the loader, so `VTKESP._register_hooks` (Task 5) actually fires.

- [ ] **Step 1: Add the `[hooks]` section**

```
[hooks]
res://Scripts/AI.gd = Activate, Deactivate, ChangeState, Death
```

Full file after edit:

```
[mod]
name="ThermalVTK"
id="thermal-vtk"
version="1.1.7"

[autoload]
ThermalVTK="res://mods/ThermalVTK/ThermalVTK.gd"

[hooks]
res://Scripts/AI.gd = Activate, Deactivate, ChangeState, Death

[dependencies]
optional=["mod_configuration_menu"]

[updates]
source="vostokmods:01a13ece-21bc-7143-b326-e66cccf9790e"
```

- [ ] **Step 2: Verify hook arities against the detokenized source**

Read `%APPDATA%\Road to Vostok\modloader_hooks\vanilla\Scripts\AI.gd` and confirm `Activate`, `Deactivate`, `ChangeState`, `Death` signatures are void with `(String)`, `()`, `(String)`, `(Vector3, float)` respectively. If any signature differs, adjust the `VTKESP` callbacks (arity mismatch = silent no-op).

- [ ] **Step 3: Run check** (parse only; hooks are runtime)

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: green.

---

### Task 10: Weapon overlay-occlusion fix

**Files:**
- Create: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKWeaponOcclusion.gd`
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKESP.gd` (drive it each frame)

**Interfaces:**
- Consumes: nothing.
- Produces: `VTKWeaponOcclusion.new()`, `tick()` called once per frame while ESP is enabled.

- [ ] **Step 1: Port the fix** — create `VTKWeaponOcclusion.gd` adapting NPCESP's `check_weapon_occlusion` / `_setup_weapon_occlusion` / `_patch_weapon_*` (renderer lines 838–1035), with: `_radar._los_only` references dropped, `_log` routed to `push_warning`/no-op, player lookup via group `"Player"` → parent `"Camera"` → child `"Manager"`, and `render_priority = 10` kept (below the outline's 20/21 so outlines can still sit over the gun within the same transparent pass? No — the intent is the opposite: the gun must draw **after** the outlines). Therefore set the weapon priority **above** the outline priorities: use `render_priority = 30` for weapon materials and keep outlines at 20/21. Update every `render_priority = 10` in the ported code to `30`.

- [ ] **Step 2: Drive it from `VTKESP`** — add `var _weapon := WeaponOcclusion.new()` and call `_weapon.tick()` inside `VTKESP._process`, right after the `enabled` early-out guard is passed (only while mode A is active).

- [ ] **Step 3: Run check**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `ok VTKWeaponOcclusion.gd`, `ok VTKESP.gd`.

- [ ] **Step 4: Manual verify** — in mode A, stand in front of an NPC: the outline must not paint over the player's weapon.

---

### Task 11: Version, changelog, pack, install

**Files:**
- Modify: `standalone mods/ThermalVTK/mod.txt` (`version`)
- Modify: `standalone mods/ThermalVTK/CHANGELOG.md`
- Modify: `standalone mods/ThermalVTK/README.md` (features list)
- Produce: `standalone mods/ThermalVTK/ThermalVTK.vmz`

- [ ] **Step 1: Bump the version** — set `version="1.2.0"` in `mod.txt` (new feature, backward compatible).

- [ ] **Step 2: Changelog** — `CHANGELOG.md` is player-facing: describe the visible effect only.

```markdown
## [1.2.0] - 2026-10-18

### Added
- Contour ESP: NPCs are outlined by their awareness state (idle, alerted, hunting, in combat), with friendly nomads always green.
- Thermal body fill inside the outline, cooling from warm to cold over a configurable time after death.
- Body flash when an NPC's own sensors currently see you.
- F6 switches between the contour view and the full-screen thermal view while NVG is worn.
- New MCM categories for the contour: toggle, body fill, corpse cooling, thickness, brightness, flash, colours, and outline distance / see-through-walls range.

### Changed
- The friendly-nomad marker is replaced by the green outline.
- Outline range and see-through-walls range are configurable.
```

- [ ] **Step 3: README** — add the contour ESP to the feature list; note it requires the AI hooks section and that mode B is unchanged.

- [ ] **Step 4: Full check**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: every script `ok`; every test `tests passed` (16 test files now); exit code 0.

- [ ] **Step 5: Pack**

Run: `powershell -ExecutionPolicy Bypass -File "standalone mods\ThermalVTK\pack.ps1"`
Expected: `Version in mod.txt: 1.2.0`, entries include `mods/ThermalVTK/VTKOutlineBody.gdshader`, `VTKOutlineRing.gdshader`, `VTKShaders.gd`, `VTKESP.gd`, `VTKOutline.gd`, `VTKTracker.gd`, `VTKStates.gd`, `VTKWeaponOcclusion.gd`.

- [ ] **Step 6: Install**

Run: `Copy-Item -LiteralPath "standalone mods\ThermalVTK\ThermalVTK.vmz" -Destination "D:\SteamLibrary\steamapps\common\Road to Vostok\mods" -Force`

- [ ] **Step 7: Manual in-game verification checklist**

- NVG worn, thermal ON: no pink models; F6 switches A↔B cleanly; NVG toggle (hotkey) across both modes produces no errors.
- Mode A: outlines appear on hostiles; colour changes with state; nomads green; corpse cools and fades over the configured seconds; infinite-distance NPCs fade before the range limit; more than 24 NPCs in range still draw only the nearest 24.
- See-through-walls: NPCs behind cover inside the range show through; at 0, only line-of-sight.
- Mines still glow in both modes; world palette and light-based dimming still work.
- Player's weapon is not painted over by outlines.
- MCM: all new categories render and apply live.

---

## Self-Review

- **Spec coverage:** modes + F6 (T7), NVG gate (T6/T7), contour technique (T3/T4), tracking + states + faction + PVisible (T1/T2/T5), death cooling (T2/T4), distances + fade + cap (T2/T4/T5), mines emission (T6, unchanged path), nomad marker removal (T6), MCM (T8), tests (T1/T2/T3/T5), weapon fix (T10), version/changelog/pack (T11). Spec risks: #1 verified in T7 manual, #2 fixed in T10, #3 cap in T5/T11, #4 stencil avoided by design deviation.
- **Open decision for the user:** deviations 1–6 above. If the stencil approach or a single `VTKOutline.gdshader` is preferred over the rim/no-stencil approach, say so before execution and Tasks 3–4 change.
- **Type-safety traps already handled in code:** explicit annotations where a `Dictionary.get`/Variant flows into a typed local (`var color: Color = ...`, `var ppos: Vector3 = ppos_v`), per the mod's known Godot-4 analyzer pitfalls.

---

## Execution notes

- **T2:** `read_faction` test moved into `test_tracker.gd` (moved forward from T5), and `VTKTracker.read_faction` implemented in T2. Test locals annotated explicitly (`var e: Dictionary = ...`, `var picked: Array = ...`) because `:=` on a `preload`ed script's static call is not inferred while the target file is absent.
- **T8:** MCM key renamed `outline_decay` → `corpse_decay` to match the spec table.
- Per-task verification uses a single-test headless run (copy the new `.gd` into `.check/project/mods/ThermalVTK`, then `--script res://tests/<name>.gd`); the full `check.ps1` runs at T11 as the final gate.