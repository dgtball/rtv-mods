# ThermalVTK 1.7.0 — ITH outline, three categories, corpse cooling — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the NPC contour a clean ITH-style outline (no "inflate/inside-out" look) with a Front/Back-face toggle, collapse AI states to three categories (Normal/Combat/Defend), make corpse cooling actually work, and add two experimental style toggles (Outline style, Fill style).

**Architecture:** ThermalVTK is a Godot 4.6.3 mod. `VTKStates.gd` (pure) maps AI states → category → colour/key; `VTKTracker.gd` (pure) holds per-NPC entry lifecycle; `VTKESP.gd` discovers NPCs, builds per-NPC draw options, owns debug labels; `VTKOutline.gd` owns the per-NPC `material_overlay` body+ring chain; `VTKShaders.gd` caches shader variants; `VTKNVG.gd`/`VTKNVG.gdshader` is the full-screen overlay that substitutes the ring's detector key with the state colour. `ThermalVTK.gd` is the autoload: MCM registration + config plumbing.

**Tech Stack:** GDScript (Godot 4.6.3), GDShader. Headless test harness in `.check/` (gitignored on disk, not committed).

## Global Constraints

- **Version:** bump to `1.7.0` in `standalone mods/ThermalVTK/mod.txt` (field `version`). `version.txt` and `README.md` version are written by `pack.ps1` — do not hand-edit.
- **Line endings:** `ThermalVTK.gd` and `mod.txt` are **CRLF**; every other `.gd`/`.gdshader`/`.md` and every test file is **LF**. Preserve exactly.
- **Indentation:** tabs only.
- **GDScript strict typing:** `:=` on a Variant expression is a Parse Error — annotate explicitly (`var x: int = ...`, `var d: Dictionary = ...`).
- **`Object.get()` takes exactly one argument.** For a property with a fallback use `VTKData.prop(obj, name, default)`; `obj.get(name, default)` aborts the function in headless.
- **No `return` inside shader `fragment()`** (`discard` is allowed).
- **English** for code comments, MCM strings, and CHANGELOG. Player-facing CHANGELOG lines describe visible effects only.
- **Tests:** registered by hand in `$tests` in `.check/check.ps1`. Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`. Green = no `SCRIPT ERROR` / `Parse Error` / `Invalid call` / `Failed to load script` lines, a `tests passed` line, exit 0. `Unicode parsing error ... NUL` and `ObjectDB instances leaked` are NOT errors. Also `py -3 .check\layout_check.py` must exit 0.
- **Mod source root:** `D:\RTVMOD\standalone mods\ThermalVTK\mods\ThermalVTK\`. Repo root: `D:\RTVMOD`.
- **Commits:** one per task. Messages in the repo's `type(thermalvtk): ...` style.

**Category table (the source of truth for every task):**

| Category | const | states (AI.State int) |
|---|---|---|
| Normal | `NORMAL` (0) | Idle 0, Wander 1, Loot 2, Guard 3, Patrol 4, Group 16 |
| Combat | `COMBAT` (1) | Combat 8, Hunt 9, Attack 11, Grenade 13 |
| Defend | `DEFEND` (2) | Cover 5, Hide 6, Ambush 7, Defend 10, Vantage 12, Lurk 14, Switch 15 |

Old enum was NORMAL=0, ALERTED=1, HUNTING=2, COMBAT=3. New: NORMAL=0, COMBAT=1, DEFEND=2.

---

### Task 1: Three-category state model (`VTKStates.gd` + `test_states.gd`)

**Files:**
- Modify: `mods/ThermalVTK/VTKStates.gd`
- Test: `.check/project/tests/test_states.gd`

**Interfaces:**
- Produces: `NORMAL=0`, `COMBAT=1`, `DEFEND=2` consts; `category_of(state:int)->int`; `category_key(cat:int)->String` (`state_normal`/`state_combat`/`state_defend`); `default_color(cat:int)->Color`; `state_key(cat:int)->Color` (detector key); `category_name(cat:int)->String` (`NORMAL`/`COMBAT`/`DEFEND`); `label_text(state:int, nomad:bool)->String`.
- Removes: `ALERTED`, `HUNTING`, `KEY_ALERTED`, `KEY_HUNTING`, `DEFAULT_ALERTED`, `DEFAULT_HUNTING`, `DEFAULT_NOMAD`, `CATEGORY_KEY_COLORS` entries beyond 3, `state_alerted`/`state_hunting`/`nomad_color` keys.

- [ ] **Step 1: Rewrite the failing test** — replace the body of `test_states.gd` with three-category assertions:

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
	t_combat_states()
	t_defend_states()
	t_unknown_defaults_to_normal()
	t_colors()
	t_keys()
	print("")
	if fails == 0:
		print("States tests passed")
		quit(0)
	else:
		print("States tests failed: ", fails)
		quit(1)

func t_normal_states() -> void:
	for s in [0, 1, 2, 3, 4, 16]:
		ck(S.category_of(s) == S.NORMAL, "state %d -> NORMAL" % s)

func t_combat_states() -> void:
	for s in [8, 9, 11, 13]:
		ck(S.category_of(s) == S.COMBAT, "state %d -> COMBAT" % s)

func t_defend_states() -> void:
	for s in [5, 6, 7, 10, 12, 14, 15]:
		ck(S.category_of(s) == S.DEFEND, "state %d -> DEFEND" % s)

func t_unknown_defaults_to_normal() -> void:
	ck(S.category_of(-1) == S.NORMAL, "unknown state -1 -> NORMAL")
	ck(S.category_of(99) == S.NORMAL, "unknown state 99 -> NORMAL")

func t_colors() -> void:
	ck(S.default_color(S.NORMAL) != S.default_color(S.COMBAT), "normal != combat colour")
	ck(S.default_color(S.COMBAT) != S.default_color(S.DEFEND), "combat != defend colour")
	ck(S.color_for(8) == S.default_color(S.COMBAT), "color_for(8) = combat default")
	ck(S.category_key(S.DEFEND) == "state_defend", "category_key(DEFEND)")

func t_keys() -> void:
	ck(S.state_key(S.NORMAL) == S.KEY_NORMAL, "state_key(NORMAL)")
	ck(S.state_key(S.COMBAT) == S.KEY_COMBAT, "state_key(COMBAT)")
	ck(S.state_key(S.DEFEND) == S.KEY_DEFEND, "state_key(DEFEND)")
```

- [ ] **Step 2: Run to verify it fails**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: FAIL — `S.COMBAT` / `S.DEFEND` / `S.KEY_DEFEND` undefined (Parse Error in test).

- [ ] **Step 3: Rewrite `VTKStates.gd` to the three-category model.** Replace consts and mapping:

```gdscript
const NORMAL := 0
const COMBAT := 1
const DEFEND := 2

const NORMAL_STATES: Array[int] = [0, 1, 2, 3, 4, 16]
const COMBAT_STATES: Array[int] = [8, 9, 11, 13]
const DEFEND_STATES: Array[int] = [5, 6, 7, 10, 12, 14, 15]

const DEFAULT_NORMAL := Color(1.0, 0.72, 0.28)
const DEFAULT_COMBAT := Color(0.95, 0.18, 0.15)
const DEFAULT_DEFEND := Color(0.62, 0.30, 0.95)

# Detector keys the ring emits; the overlay detector matches them and swaps in
# the category colour. Keep them far apart.
const KEY_NORMAL := Color(1.0, 0.0, 0.0)
const KEY_COMBAT := Color(0.0, 1.0, 1.0)
const KEY_DEFEND := Color(1.0, 0.0, 1.0)

const CATEGORY_KEY_COLORS: Array[Color] = [KEY_NORMAL, KEY_COMBAT, KEY_DEFEND]

static func state_key(cat: int) -> Color:
	if cat < 0 or cat >= CATEGORY_KEY_COLORS.size():
		return KEY_NORMAL
	return CATEGORY_KEY_COLORS[cat]

const CATEGORY_KEYS: Array[String] = ["state_normal", "state_combat", "state_defend"]

static var _map: Dictionary = {}

static func _build() -> void:
	if not _map.is_empty():
		return
	for s in NORMAL_STATES:
		_map[s] = NORMAL
	for s in COMBAT_STATES:
		_map[s] = COMBAT
	for s in DEFEND_STATES:
		_map[s] = DEFEND

static func category_of(state: int) -> int:
	_build()
	return int(_map.get(state, NORMAL))

static func category_key(cat: int) -> String:
	if cat < 0 or cat >= CATEGORY_KEYS.size():
		return CATEGORY_KEYS[NORMAL]
	return CATEGORY_KEYS[cat]

static func default_color(cat: int) -> Color:
	match cat:
		COMBAT:
			return DEFAULT_COMBAT
		DEFEND:
			return DEFAULT_DEFEND
		_:
			return DEFAULT_NORMAL

static func color_for(state: int) -> Color:
	return default_color(category_of(state))

const STATE_NAMES: Array[String] = [
	"Idle", "Wander", "Loot", "Guard", "Patrol", "Cover", "Hide", "Ambush",
	"Combat", "Hunt", "Defend", "Attack", "Vantage", "Grenade", "Lurk",
	"Switch", "Group",
]

const CATEGORY_NAMES: Array[String] = ["NORMAL", "COMBAT", "DEFEND"]

static func state_name(state: int) -> String:
	if state < 0 or state >= STATE_NAMES.size():
		return "State" + str(state)
	return STATE_NAMES[state]

static func category_name(cat: int) -> String:
	if cat < 0 or cat >= CATEGORY_NAMES.size():
		return CATEGORY_NAMES[NORMAL]
	return CATEGORY_NAMES[cat]

# Two-line debug label: raw state on top, the category below.
static func label_text(state: int, _nomad: bool) -> String:
	return "%s\n%s" % [state_name(state), category_name(category_of(state))]
```

`DEFAULT_NOMAD`, `default_nomad()`, `KEY_NOMAD`, `category_of` nomad handling are removed.

- [ ] **Step 4: Run to verify it passes**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: PASS (`States tests passed`), exit 0. Other suites that referenced removed symbols will fail here — that is expected and fixed in later tasks; if `test_tracker.gd`/`test_esp.gd`/`test_shaders.gd` now error, note them and continue (this task's deliverable is `test_states.gd` green).

- [ ] **Step 5: Commit**

```bash
git add "standalone mods/ThermalVTK/mods/ThermalVTK/VTKStates.gd" .check/project/tests/test_states.gd
git commit -m "feat(thermalvtk): collapse AI states to three categories (normal/combat/defend)"
```

---

### Task 2: Detector plumbing for three categories (`VTKNVG.gdshader` + `VTKNVG.gd`)

**Files:**
- Modify: `mods/ThermalVTK/VTKNVG.gdshader`
- Modify: `mods/ThermalVTK/VTKNVG.gd`
- Test: `.check/project/tests/test_shaders.gd`

**Interfaces:**
- Consumes: `VTKStates.KEY_NORMAL/KEY_COMBAT/KEY_DEFEND` (Task 1).
- Produces: overlay uniforms `stNormalKey`/`stCombatKey`/`stDefendKey` (+ `st*Color`); drops `stAlertedKey`/`stHuntingKey`/`stNomadKey`. `set_state_colors` now takes a dict keyed `state_normal`/`state_combat`/`state_defend`.

- [ ] **Step 1: Update the test** — in `test_shaders.gd` `t_state_keys_in_overlay`, replace the alert/hunt/nomad key+colour assertions with combat/defend:

```gdscript
	ck(have.has("stNormalKey"), "overlay has stNormalKey")
	ck(have.has("stCombatKey"), "overlay has stCombatKey")
	ck(have.has("stDefendKey"), "overlay has stDefendKey")
	ck(have.has("stNormalColor"), "overlay has stNormalColor")
	ck(have.has("stCombatColor"), "overlay has stCombatColor")
	ck(have.has("stDefendColor"), "overlay has stDefendColor")
	ck(not have.has("stAlertedKey"), "overlay dropped stAlertedKey")
	ck(not have.has("stHuntingKey"), "overlay dropped stHuntingKey")
	ck(not have.has("stNomadKey"), "overlay dropped stNomadKey")
```

(Adjust to the existing helper names in `test_shaders.gd`; keep the mine-key and palette assertions.)

- [ ] **Step 2: Run to verify it fails**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: FAIL — `stDefendKey` not in overlay.

- [ ] **Step 3: Edit `VTKNVG.gdshader`** — replace the five `st*Key`/`st*Color` uniforms (lines ~36-45) with three:

```glsl
uniform vec3 stNormalKey : source_color = vec3(1.0, 0.0, 0.0);
uniform vec3 stCombatKey : source_color = vec3(0.0, 1.0, 1.0);
uniform vec3 stDefendKey : source_color = vec3(1.0, 0.0, 1.0);
uniform vec3 stNormalColor : source_color = vec3(1.0, 0.72, 0.28);
uniform vec3 stCombatColor : source_color = vec3(0.95, 0.18, 0.15);
uniform vec3 stDefendColor : source_color = vec3(0.62, 0.30, 0.95);
```

And in `fragment()` (lines ~128-155) reduce the distance/substitution to three keys + mine:

```glsl
		float dMine = orbitDist(pixelColor.rgb, mineKey);
		float dStN = orbitDist(pixelColor.rgb, stNormalKey);
		float dStC = orbitDist(pixelColor.rgb, stCombatKey);
		float dStD = orbitDist(pixelColor.rgb, stDefendKey);
		float minD = min(dMine, min(dStN, min(dStC, dStD)));
		...
				if (minD == dMine) {
					subColor = mineColor;
				} else if (minD == dStN) {
					subColor = stNormalColor * stateBright;
				} else if (minD == dStC) {
					subColor = stCombatColor * stateBright;
				} else {
					subColor = stDefendColor * stateBright;
				}
```

- [ ] **Step 4: Edit `VTKNVG.gd`** — in the uniform-push block (lines ~246-255) set the three keys/colours:

```gdscript
	nvg_mat.set_shader_parameter("stNormalKey", DET_ST_NORMAL)
	nvg_mat.set_shader_parameter("stCombatKey", DET_ST_COMBAT)
	nvg_mat.set_shader_parameter("stDefendKey", DET_ST_DEFEND)
	nvg_mat.set_shader_parameter("stNormalColor", _state_colors.get("state_normal", Color(1.0, 0.72, 0.28)))
	nvg_mat.set_shader_parameter("stCombatColor", _state_colors.get("state_combat", Color(0.95, 0.18, 0.15)))
	nvg_mat.set_shader_parameter("stDefendColor", _state_colors.get("state_defend", Color(0.62, 0.30, 0.95)))
```

Replace the `DET_ST_*` consts near the top of `VTKNVG.gd` accordingly (keep `DET_ST_NORMAL`, rename alert/hunt/nomad → `DET_ST_COMBAT`, `DET_ST_DEFEND`; drop the third). Ensure the detector-key consts equal `VTKStates.KEY_*` values.

- [ ] **Step 5: Run to verify it passes**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `Shaders tests passed`.

- [ ] **Step 6: Commit**

```bash
git add "standalone mods/ThermalVTK/mods/ThermalVTK/VTKNVG.gdshader" "standalone mods/ThermalVTK/mods/ThermalVTK/VTKNVG.gd" .check/project/tests/test_shaders.gd
git commit -m "refactor(thermalvtk): overlay detector carries three category keys"
```

---

### Task 3: Tracker + ESP wiring for three categories (`VTKTracker.gd`, `test_tracker.gd`, `VTKESP.gd`)

**Files:**
- Modify: `mods/ThermalVTK/VTKTracker.gd`
- Modify: `mods/ThermalVTK/VTKESP.gd`
- Test: `.check/project/tests/test_tracker.gd`

**Interfaces:**
- Consumes: `VTKStates.COMBAT=1`, `DEFEND=2` (Task 1).
- Produces: `Tracker.new_entry` no longer stores a `nomad` colour role (keeps `nomad` bool); `VTKESP.p_colors` keys `state_normal`/`state_combat`/`state_defend`; `VTKESP` drops `p_nomad`.

- [ ] **Step 1: Update `test_tracker.gd`** — the existing assertions `cat == 3` (COMBAT) and `apply_state(e, 11)` must become `cat == S.COMBAT` (== 1). Add a DEFEND check:

```gdscript
	ck(int(e["cat"]) == 1, "cat COMBAT (==1) after state 8")
	ck(T.apply_state(e, 11) == false, "state 11 (Attack) same category reports no change")
	ck(T.apply_state(e, 5) == true, "state 5 (Cover) moves to DEFEND")
	ck(int(e["cat"]) == 2, "cat DEFEND (==2) after state 5")
```

- [ ] **Step 2: Run to verify it fails**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: FAIL — old `cat == 3` assertion.

- [ ] **Step 3: Edit `VTKESP.gd`** — replace `p_colors`/`p_nomad` (lines 25-31):

```gdscript
var p_colors := {
	"state_normal": States.DEFAULT_NORMAL,
	"state_combat": States.DEFAULT_COMBAT,
	"state_defend": States.DEFAULT_DEFEND,
}
```

Delete `var p_nomad` and its uses. Update `_state_color` to drop the nomad branch and read the three-key dict:

```gdscript
func _state_color(cat: int) -> Color:
	var key: String = States.category_key(cat)
	return p_colors.get(key, States.default_color(cat))
```

Update the `_opts_for` `fill_color` call to `_state_color(cat)` (drop the `nomad` arg). `Tracker.new_entry` keeps its `nomad` parameter (still used to mark the `◆`), but `cool_factor`/`apply_state` are untouched.

- [ ] **Step 4: Run to verify it passes**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `Tracker tests passed`, `ESP tests passed`.

- [ ] **Step 5: Commit**

```bash
git add "standalone mods/ThermalVTK/mods/ThermalVTK/VTKTracker.gd" "standalone mods/ThermalVTK/mods/ThermalVTK/VTKESP.gd" .check/project/tests/test_tracker.gd
git commit -m "refactor(thermalvtk): tracker/esp use three-category colours"
```

---

### Task 4: Corpse cooling fallback (`VTKESP.gd` + `test_tracker.gd`)

**Files:**
- Modify: `mods/ThermalVTK/VTKESP.gd`
- Test: `.check/project/tests/test_tracker.gd`

**Interfaces:**
- Consumes: `Tracker.mark_dead(e, now)`, `Tracker.cool_factor(e, now, decay)`.
- Produces: `_draw` marks an entry dead from the node's own `dead` flag so `cool` rises even when the `ai-death-post` hook misses.

- [ ] **Step 1: Add a pure-logic assertion** to `test_tracker.gd` that `mark_dead` is idempotent and cooling rises:

```gdscript
func t_cooling() -> void:
	var e: Dictionary = T.new_entry(1, false, 0.0)
	ck(T.cool_factor(e, 0.0, 8.0) == 0.0, "alive -> cool 0")
	T.mark_dead(e, 10.0)
	ck(T.cool_factor(e, 10.0, 8.0) == 0.0, "just dead -> cool 0")
	ck(abs(T.cool_factor(e, 14.0, 8.0) - 0.5) < 0.001, "half decay -> cool 0.5")
	ck(T.cool_factor(e, 18.0, 8.0) == 1.0, "full decay -> cool 1")
	T.mark_dead(e, 99.0)
	ck(abs(float(e["death_ts"]) - 10.0) < 0.001, "mark_dead is idempotent")
```

Wire `t_cooling()` into `_run()`.

- [ ] **Step 2: Run to verify it passes already** (this proves the pure helper; the bug is in the wiring, fixed next)

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: PASS (`Tracker tests passed`).

- [ ] **Step 3: Edit `VTKESP.gd` `_draw`** — inside the entry loop, before building `opts`, seed death from the node:

```gdscript
		if not bool(e.get("dead", false)) and bool(node.get("dead")):
			Tracker.mark_dead(e, now)
```

Place it right after `valid[id] = true` (line ~302), so the node's own flag drives `cool` independent of the hook.

- [ ] **Step 4: Run to verify it passes**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: exit 0, no `SCRIPT ERROR`.

- [ ] **Step 5: Commit**

```bash
git add "standalone mods/ThermalVTK/mods/ThermalVTK/VTKESP.gd" .check/project/tests/test_tracker.gd
git commit -m "fix(thermalvtk): corpse cooling follows the node dead flag, not just the death hook"
```

---

### Task 5: ITH outline style + rim (`VTKOutlineRing.gdshader`, `VTKShaders.gd`, `VTKOutline.gd`)

**Files:**
- Modify: `mods/ThermalVTK/VTKOutlineRing.gdshader`
- Modify: `mods/ThermalVTK/VTKShaders.gd`
- Modify: `mods/ThermalVTK/VTKOutline.gd`
- Test: `.check/project/tests/test_outline.gd`, `.check/project/tests/test_shaders.gd`

**Interfaces:**
- Consumes: `opts["outline_style"]` (int 0=front,1=back), `opts["rim"]` (float).
- Produces: `VTKShaders.ring(through_walls:bool, front_faces:bool)->Shader` (new second arg); ring uniforms `outline_style`, `rim_start`, `rim_end`, `rim_power`.

- [ ] **Step 1: Update `test_shaders.gd`** — assert `VTKShaders.ring(false, true)` and `ring(false, false)` compile and are distinct; assert the ring source declares `outline_style`, `rim_start`, `rim_end`, `rim_power`. Keep existing `strip_depth_test` checks.

- [ ] **Step 2: Run to verify it fails**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: FAIL — `ring()` accepts one arg.

- [ ] **Step 3: Rewrite `VTKOutlineRing.gdshader`** with style branch:

```glsl
shader_type spatial;
render_mode unshaded, cull_back, depth_test_disabled, depth_draw_never;

// Silhouette ring. Front-faces mode (outline_style 0) uses the ImmersiveThreat
// Highlight trick: cull the front faces (render_mode cull_front, swapped in
// VTKShaders) and keep a smoothstep band, so a grazing rim survives instead of
// an inflated shell. Back-faces mode (1) keeps the pow() rim as before.
uniform vec3 state_key : source_color = vec3(1.0, 0.0, 0.0);
uniform float grow : hint_range(0.0, 0.2, 0.001) = 0.006;
uniform float rim_power : hint_range(0.0, 6.0, 0.1) = 1.0;
uniform float rim_start = 0.42;
uniform float rim_end = 0.82;
uniform int outline_style = 0;
uniform float cool : hint_range(0.0, 1.0, 0.01) = 0.0;

void vertex() {
	VERTEX += NORMAL * grow;
}

void fragment() {
	float rim01 = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	ALBEDO = state_key;
	float line;
	if (outline_style == 0) {
		line = smoothstep(rim_start, rim_end, rim01);
		if (line < 0.03) discard;
	} else {
		line = pow(rim01, rim_power);
	}
	ALPHA = line * (1.0 - cool);
}
```

Note: `cull_back` here is the depth-variant base; the front-faces cull is applied by `VTKShaders` (below) because `render_mode` is compile-time.

- [ ] **Step 4: Edit `VTKShaders.gd`** — build 4 ring variants (front/back × wall/los). `render_mode` swap = replace the `cull_*` token; depth swap = `strip_depth_test` (existing).

```gdscript
static func _with_cull(code: String, front: bool) -> String:
	return code.replace("cull_back", "cull_front") if front else code

static func ring(through_walls: bool, front_faces: bool) -> Shader:
	_ensure()
	return _ring_variant(through_walls, front_faces)
```

Implement `_ring_variant` with a small cache dictionary keyed on the two bools, building `Shader.new()` with `.code = strip_depth_test(_with_cull(RING_SRC.code, front_faces))` (and the wall variant without stripping). Keep `body(through_walls)` as-is for now (body cull is Task 9).

- [ ] **Step 5: Edit `VTKOutline.gd`** — pass style/rim into the ring material and rebuild the ring shader when the style flips:

```gdscript
	var style_on := bool(opts.get("outline_style", 0)) == 0   # 0 = front-faces
```

In `refresh`, after computing `grow`:

```gdscript
	var rim := float(opts.get("rim", 0.42))
	var style_front := bool(opts.get("front_faces", true))
	if ring_mat.get_shader_parameter("outline_style") == null or int(ring_mat.get_shader_parameter("outline_style")) != (0 if style_front else 1):
		ring_mat.set_shader_parameter("outline_style", 0 if style_front else 1)
		ring_mat.set_shader_parameter("rim_start", rim)
		ring_mat.set_shader_parameter("rim_end", rim + 0.4)
		ring_mat.set_shader_parameter("rim_power", rim)
```

`_build_chain`/`_set_wall` gain the `front_faces` argument and call `Shaders.ring(through_walls, front_faces)`.

- [ ] **Step 6: Run to verify it passes**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `Shaders tests passed`, `Outline tests passed`.

- [ ] **Step 7: Commit**

```bash
git add "standalone mods/ThermalVTK/mods/ThermalVTK/VTKOutlineRing.gdshader" "standalone mods/ThermalVTK/mods/ThermalVTK/VTKShaders.gd" "standalone mods/ThermalVTK/mods/ThermalVTK/VTKOutline.gd" .check/project/tests/test_shaders.gd .check/project/tests/test_outline.gd
git commit -m "feat(thermalvtk): ITH front-face outline style with rim control"
```

---

### Task 6: Fill style gradient (`VTKOutlineBody.gdshader` + `VTKOutline.gd`)

**Files:**
- Modify: `mods/ThermalVTK/VTKOutlineBody.gdshader`
- Modify: `mods/ThermalVTK/VTKOutline.gd`
- Test: `.check/project/tests/test_outline.gd`

**Interfaces:**
- Consumes: `opts["fill_style"]` (int 0=flat,1=gradient), `opts["foot_y"]`, `opts["body_height"]`.
- Produces: body uniforms unchanged (`fillColor`, `fill_alpha`, `cool`) plus `fill_style`, `warmColor`, `coldColor`.

- [ ] **Step 1: Add a test assertion** in `test_outline.gd` that the body source declares `fill_style`, `warmColor`, `coldColor` and still compiles.

- [ ] **Step 2: Run to verify it fails**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: FAIL — `fill_style` not present.

- [ ] **Step 3: Edit `VTKOutlineBody.gdshader`**:

```glsl
uniform vec3 fillColor : source_color = vec3(1.0, 0.72, 0.28);
uniform float fill_alpha : hint_range(0.0, 1.0, 0.01) = 0.4;
uniform float cool : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform int fill_style = 0;
uniform vec3 warmColor : source_color = vec3(1.0, 0.95, 0.7);
uniform vec3 coldColor : source_color = vec3(0.05, 0.05, 0.12);
uniform float footY = 0.0;
uniform float bodyHeight = 1.8;

void fragment() {
	if (fill_style == 1) {
		// Vertical thermal gradient: warm at the feet, cold at the head. The
		// state colour is mixed over it by fill_alpha.
		float h = clamp((VERTEX.y - footY) / max(bodyHeight, 0.001), 0.0, 1.0);
		vec3 thermal = mix(warmColor, coldColor, h);
		ALBEDO = mix(thermal, fillColor, fill_alpha) * mix(1.0, 0.15, cool);
	} else {
		ALBEDO = fillColor * mix(1.0, 0.15, cool);
	}
	ALPHA = fill_alpha * (1.0 - cool);
}
```

`VERTEX.y` is object-local, so use `footY`/`bodyHeight` only if the mesh origin differs; if `VERTEX.y` already local, `h` uses local Y directly — the implementer verifies which reads correctly in-game and keeps the code that does (note it in the report).

- [ ] **Step 4: Edit `VTKOutline.gd`** — push `fill_style` (and only default warm/cold; no MCM yet):

```gdscript
	var fill_style := int(opts.get("fill_style", 0))
	if body_mat.get_shader_parameter("fill_style") == null or int(body_mat.get_shader_parameter("fill_style")) != fill_style:
		body_mat.set_shader_parameter("fill_style", fill_style)
	if body_mat.get_shader_parameter("warmColor") == null:
		body_mat.set_shader_parameter("warmColor", Color(1.0, 0.95, 0.7))
		body_mat.set_shader_parameter("coldColor", Color(0.05, 0.05, 0.12))
```

- [ ] **Step 5: Run to verify it passes**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `Outline tests passed`.

- [ ] **Step 6: Commit**

```bash
git add "standalone mods/ThermalVTK/mods/ThermalVTK/VTKOutlineBody.gdshader" "standalone mods/ThermalVTK/mods/ThermalVTK/VTKOutline.gd" .check/project/tests/test_outline.gd
git commit -m "feat(thermalvtk): experimental gradient body fill style"
```

---

### Task 7: MCM + config plumbing (`ThermalVTK.gd`)

**Files:**
- Modify: `mods/ThermalVTK/ThermalVTK.gd`
- Test: `.check/project/tests/test_config.gd` (only if it asserts key sets; else none)

**Interfaces:**
- Consumes: nothing new from earlier tasks beyond the field names.
- Produces: MCM keys `outline_style` (Dropdown front/back), `outline_rim` (Float), `fill_style` (Dropdown flat/gradient), `outline_thickness` range 0.001..0.02, `outline_distance` default 60; removes `nomad_color`; ESP params `p_style`, `p_rim`, `p_fill_style`.

- [ ] **Step 1: Edit `_register_mcm` in `ThermalVTK.gd`** — CAT2 block (lines 146-152). Add after `outline_enabled`:

```gdscript
	cfg.set_value("Dropdown", "outline_style", {"default": "front", "value": "front", "options": {"front": "Front-faces (ITH)", "back": "Back-faces"}, "category": CAT2, "menu_pos": 1, "tooltip": "Outline look. Front-faces is the clean silhouette; Back-faces is the older inflated look.", "name": "Outline style"})
	cfg.set_value("Float", "outline_rim", {"name": "Outline rim", "default": 0.42, "value": 0.42, "minRange": 0.0, "maxRange": 1.0, "step": 0.02, "category": CAT2, "menu_pos": 2, "tooltip": "Band width/sharpness of the outline edge."})
	cfg.set_value("Dropdown", "fill_style", {"default": "flat", "value": "flat", "options": {"flat": "Flat (state colour)", "gradient": "Gradient (thermal)"}, "category": CAT2, "menu_pos": 6, "tooltip": "Body fill look. Gradient mixes the state colour over a warm-to-cold thermal ramp.", "name": "Fill style"})
```

Bump the remaining CAT2 `menu_pos` values so ordering stays unique (body fill 3, fill opacity 4, corpse 5, thickness 7, brightness 8, distance 9, through 10) — keep them monotonic; exact numbers are cosmetic.

Change `outline_thickness` (line 151): `"minRange": 0.001, "maxRange": 0.02, "step": 0.001`.
Change `outline_distance` (line 162): `"default": 60.0, "value": 60.0`.

In CAT3 (lines 155-159): keep `state_normal`, rename `state_alerted`→`state_combat` (name "In combat", default `Color(0.95,0.18,0.15)`, tooltip "Colour for NPCs in combat, hunting, attacking or throwing grenades."), `state_hunting`→`state_defend` (name "Defending", default `Color(0.62,0.30,0.95)`, tooltip "Colour for NPCs taking cover, defending, ambushing or lurking."), delete `state_combat` (old) and `nomad_color`.

- [ ] **Step 2: Edit `_mcm_apply`** (lines 283-307) — wire the new params:

```gdscript
		_esp.p_dist = float(_mcm_key_val(cfg, "Float", "outline_distance", 60.0))
		_esp.p_style = 0 if String(_mcm_key_val(cfg, "Dropdown", "outline_style", "front")) == "front" else 1
		_esp.p_rim = float(_mcm_key_val(cfg, "Float", "outline_rim", 0.42))
		_esp.p_fill_style = 0 if String(_mcm_key_val(cfg, "Dropdown", "fill_style", "flat")) == "flat" else 1
		_esp.p_colors = {
			"state_normal": _mcm_color_val(cfg, "state_normal", States.DEFAULT_NORMAL),
			"state_combat": _mcm_color_val(cfg, "state_combat", States.DEFAULT_COMBAT),
			"state_defend": _mcm_color_val(cfg, "state_defend", States.DEFAULT_DEFEND),
		}
		_nvg.set_state_colors({
			"state_normal": _mcm_color_val(cfg, "state_normal", States.DEFAULT_NORMAL),
			"state_combat": _mcm_color_val(cfg, "state_combat", States.DEFAULT_COMBAT),
			"state_defend": _mcm_color_val(cfg, "state_defend", States.DEFAULT_DEFEND),
		})
```

Delete the `_esp.p_nomad` assignment. Add fields in `VTKESP.gd`:

```gdscript
var p_style := 0
var p_rim := 0.42
var p_fill_style := 0
```

and include them in `_opts_for` output: `"front_faces": p_style == 0`, `"rim": p_rim`, `"outline_style": p_style`, `"fill_style": p_fill_style`.

- [ ] **Step 3: Run to verify it passes**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: exit 0. `_sync_config` will strip `nomad_color`/`state_alerted`/`state_hunting` from a player config on next run.

- [ ] **Step 4: Commit**

```bash
git add "standalone mods/ThermalVTK/mods/ThermalVTK/ThermalVTK.gd" "standalone mods/ThermalVTK/mods/ThermalVTK/VTKESP.gd"
git commit -m "feat(thermalvtk): MCM keys for outline style, rim, fill style; three category colours"
```

---

### Task 8: Nomad `◆` marker + always-on debug label (`VTKESP.gd`)

**Files:**
- Modify: `mods/ThermalVTK/mods/ThermalVTK/VTKESP.gd`

**Interfaces:**
- Consumes: `VTKStates.label_text(state, nomad)` (now ignores nomad), `enabled`, `_nvg` thermal state via `ThermalVTK.gd` (`_nvg_active()`/`set_thermal`).
- Produces: separate `_markers` dict; `◆` Label3D over nomads shown when NVG+thermal on; nomad excluded from category colour (already done in Task 3).

- [ ] **Step 1: Add a `_markers` dict and lifecycle** in `VTKESP.gd`:

```gdscript
var _markers: Dictionary = {}
var marker_visible: bool = false   # set from the thermal/NVG state by ThermalVTK
```

Add `_markers_sync()` mirroring `_labels_sync` but gated on `marker_visible` (not `Dbg.enabled`), creating a Label3D with `text="◆"`, green `modulate = Color(0.30, 1.0, 0.35)`, only for entries with `nomad == true` and not dead. Free markers on deactivate/death/`set_enabled(false)`/`_exit_tree` (mirror `_label_free`).

- [ ] **Step 2: Call `_markers_sync()`** from `_process` (next to `_labels_sync()`).

- [ ] **Step 3: Set `marker_visible`** from `ThermalVTK.gd`: in `_apply_mode` (or wherever `_nvg` thermal/NVG is known), `_esp.marker_visible = _thermal_enabled and _nvg_active()`. Also on the debug log toggle if it changes NVG — keep it simple: update it in the same place `_esp.set_enabled(...)` is called (line ~80).

- [ ] **Step 4: Fix `_labels_sync`** so debug labels show whenever `Dbg.enabled`, regardless of NVG. Verify current gate is only `Dbg.enabled` (line 222) — it already is; add a comment confirming the label is NVG-independent. No behaviour change beyond a comment if already correct.

- [ ] **Step 5: Run to verify it parses and tests pass**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: exit 0 (`ESP tests passed`).

- [ ] **Step 6: Commit**

```bash
git add "standalone mods/ThermalVTK/mods/ThermalVTK/VTKESP.gd" "standalone mods/ThermalVTK/mods/ThermalVTK/ThermalVTK.gd"
git commit -m "feat(thermalvtk): nomad diamond marker, always-on debug label"
```

---

### Task 9: Release 1.7.0 (version, CHANGELOG, README, build)

**Files:**
- Modify: `standalone mods/ThermalVTK/mod.txt`
- Modify: `standalone mods/ThermalVTK/CHANGELOG.md`
- Modify: `standalone mods/ThermalVTK/README.md`
- Build: `pack.ps1` → `ThermalVTK.vmz`

- [ ] **Step 1: Bump version** in `mod.txt`: `version="1.6.1"` → `version="1.7.0"` (CRLF preserved).

- [ ] **Step 2: Add CHANGELOG block** above `## [1.6.1]`:

```markdown
## [1.7.0] - 2026-10-20

### Added
- An Outline style setting (Front-faces / Back-faces) and an Outline rim slider, so the NPC outline can be a clean silhouette instead of an inflated shell.
- A Fill style setting (Flat / Gradient) to try a warm-to-cold body gradient.
- Friendly nomads now show a green diamond marker while night vision is on, so they can be told apart in the dark.

### Changed
- NPC states are grouped into three colours: normal (amber), combat (red) and defend (purple).
- The default outline distance is now 60 m (was 150 m); outline thickness can go thinner.

### Fixed
- Dead NPCs now dim and fade over the corpse cooling time again.
```

- [ ] **Step 3: Update README** — reflect three categories, the new settings, nomad `◆`, and the outline-style note.

- [ ] **Step 4: Build**

Run: `powershell -ExecutionPolicy Bypass -File pack.ps1` (in `standalone mods\ThermalVTK`)
Expected: `Version in mod.txt: 1.7.0`; `Pack done: ...ThermalVTK.vmz (N entries...)`.

- [ ] **Step 5: Install**

```powershell
Copy-Item -LiteralPath "D:\RTVMOD\standalone mods\ThermalVTK\ThermalVTK.vmz" -Destination "D:\SteamLibrary\steamapps\common\Road to Vostok\mods\ThermalVTK.vmz" -Force
```

- [ ] **Step 6: Commit**

```bash
git add "standalone mods/ThermalVTK/mod.txt" "standalone mods/ThermalVTK/CHANGELOG.md" "standalone mods/ThermalVTK/README.md" "standalone mods/ThermalVTK/mods/ThermalVTK/version.txt"
git commit -m "chore(thermalvtk): release 1.7.0"
```

---

## Self-Review

**Spec coverage:**
- §Обводка ITH + style + rim → Task 5. ✓
- §Body fill two approaches + fill_style → Task 6 + Task 7 (plumbing). ✓
- §Трупы fallback → Task 4. ✓
- §Категории (3) + colours + MCM CAT3 → Tasks 1, 2, 3, 7. ✓
- §Номад `◆` + colour-by-category → Tasks 3 (colour), 8 (marker). ✓
- §Debug label always-on → Task 8. ✓
- §MCM keys incl. thickness range, distance 60, through_walls kept → Task 7. ✓
- §Version 1.7.0 / CHANGELOG / build → Task 9. ✓

**Placeholder scan:** none — every code step carries real code.

**Type consistency:** `category_of`→int category; `category_key` keys `state_normal/combat/defend` used identically in Tasks 2/3/7; `Shaders.ring(through_walls, front_faces)` signature consistent across Task 5 (shaders) and consumer; `p_style/p_rim/p_fill_style` names consistent Task 7 (`_opts_for` output) ↔ Task 5/6 consumers.

**Known ordering note:** Task 1 intentionally leaves other suites red until Tasks 2-3 land; each task's deliverable is its own test green, and the full suite is green by Task 3.
