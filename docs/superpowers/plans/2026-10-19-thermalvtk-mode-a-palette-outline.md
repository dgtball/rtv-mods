# ThermalVTK Mode A (Palette + Keyed Outline) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Re-enable the world thermal palette in contour mode (Mode A) while keeping per-state outline colours, by moving the outline's colour substitution into the NVG overlay shader via fixed detector keys.

**Architecture:** The outline ring stops painting a display colour and instead emits a fixed "state key" colour (like bot heat / mines already do). The NVG overlay shader (`VTKNVG.gdshader`) detects that key on the NVG-processed screen and substitutes the state display colour *after* the palette. Mode A becomes `thermalMode = set_thermal and _nvg_active()`; bots are simply not keyed in A (`bot_paint=false`). Body fill is disabled in A. The palette dropdown shrinks from 6 to 4 entries.

**Tech Stack:** Godot 4.6.3 (GDScript + Godot shading language), RTV ModLoader, headless test stand in `.check/`.

## Global Constraints

- **Spec:** `docs/superpowers/specs/2026-10-19-thermalvtk-mode-a-palette-outline-design.md`.
- **Line endings — preserve per file, byte-for-byte.** `ThermalVTK.gd` is CRLF. `VTKNVG.gd`, `VTKNVG.gdshader`, `VTKOutline.gd`, `VTKOutlineRing.gdshader`, `VTKOutlineBody.gdshader`, `VTKESP.gd`, `VTKStates.gd`, `VTKTracker.gd`, `VTKShaders.gd` are LF-only. After every edit, verify: `$b=[IO.File]::ReadAllBytes($f); ($b -contains 13)` — `True` only for CRLF files.
- **Tabs only** for indentation in `.gd` and `.gdshader`. No spaces for indent.
- **Test source lives in two places.** The mod compiles from `standalone mods/ThermalVTK/mods/ThermalVTK/`; `.check/check.ps1` copies `*.gd`/`*.gdshader` into `.check/project/mods/ThermalVTK/` before running. Running a single test requires the copy step first (the copy only happens inside `check.ps1`).
- **Full check:** from `D:\RTVMOD` run `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`. Green = no `SCRIPT ERROR`/`Parse Error`/`Invalid call`/`Failed to load script`, plus `Tests passed: 22 file(s)`. cp1251 console mojibake is a display artefact, not a failure.
- **Single test:** copy the changed sources, then run, e.g.
  `powershell -NoProfile -Command "Copy-Item 'D:\RTVMOD\standalone mods\ThermalVTK\mods\ThermalVTK\*.gd' 'D:\RTVMOD\.check\project\mods\ThermalVTK\' -Force; & 'D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'D:\RTVMOD\.check\project' --script res://tests/test_states.gd"`
- **Commits are gated.** Per `AGENTS.md`, do NOT commit unless the user explicitly authorises it. Treat every `Commit` step as a checkpoint: if the user has not authorised commits in this session, skip it and continue. When authorised, commit the listed files only.
- **No version bump / no packaging until Task 6 (calibration) passes.** Final version is `1.5.0` (minor).
- **Do not touch** the `else` branch of `VTKNVG.gdshader` (thermal-vision-off path); it must keep its mine substitution unchanged.
- **Never delete live UI text or logging lines** beyond what a task states.

---

### Task 1: State-key constants and mapping in `VTKStates.gd`

Pure data + mapping; headless-testable. The ring will emit these exact colours.

**Files:**
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKStates.gd`
- Test: `.check/project/tests/test_states.gd`

**Interfaces:**
- Produces: `VTKStates.KEY_NORMAL/KEY_ALERTED/KEY_HUNTING/KEY_COMBAT/KEY_NOMAD` (`Color`), `VTKStates.state_key(cat: int) -> Color`. Consumed by `VTKOutline`/`VTKESP` (raw emitted keys) and mirrored (washed values) in `VTKNVG`.

- [ ] **Step 1: Write the failing test**

Append to `.check/project/tests/test_states.gd` (and add `t_keys()` to `_run()` before the final `print("")`):

```gdscript
func t_keys() -> void:
	ck(S.state_key(S.NORMAL) == S.KEY_NORMAL, "state_key(NORMAL)")
	ck(S.state_key(S.ALERTED) == S.KEY_ALERTED, "state_key(ALERTED)")
	ck(S.state_key(S.HUNTING) == S.KEY_HUNTING, "state_key(HUNTING)")
	ck(S.state_key(S.COMBAT) == S.KEY_COMBAT, "state_key(COMBAT)")
	ck(S.state_key(99) == S.KEY_NORMAL, "state_key(unknown) -> NORMAL")
	ck(S.KEY_NOMAD != S.KEY_NORMAL, "nomad key distinct from normal")
```

- [ ] **Step 2: Run test to verify it fails**

Run the single-test command above with `test_states.gd`.
Expected: FAIL / compile error — `S.state_key` and `S.KEY_NORMAL` do not exist.

- [ ] **Step 3: Write minimal implementation**

In `VTKStates.gd`, after the `DEFAULT_*` colours (keep LF endings, tabs):

```gdscript
# Detector keys the ring emits. Fixed (never preset-driven) so the overlay
# detector can match them; only the substitution colours vary. Chosen far apart
# and away from MINE_KEY (blue) / MARKER_KEY (green, reserved).
const KEY_NORMAL := Color(1.0, 0.0, 0.0)
const KEY_ALERTED := Color(1.0, 1.0, 0.0)
const KEY_HUNTING := Color(1.0, 0.0, 1.0)
const KEY_COMBAT := Color(0.0, 1.0, 1.0)
const KEY_NOMAD := Color(0.0, 1.0, 0.0)

const CATEGORY_KEY_COLORS: Array[Color] = [KEY_NORMAL, KEY_ALERTED, KEY_HUNTING, KEY_COMBAT]

static func state_key(cat: int) -> Color:
	if cat < 0 or cat >= CATEGORY_KEY_COLORS.size():
		return KEY_NORMAL
	return CATEGORY_KEY_COLORS[cat]
```

- [ ] **Step 2b: Run test to verify it passes**

Run: single `test_states.gd` (after copying sources). Expected: `States tests passed`, exit 0.

- [ ] **Step 3b: Commit (gated)**

```bash
git add "standalone mods/ThermalVTK/mods/ThermalVTK/VTKStates.gd" ".check/project/tests/test_states.gd"
git commit -m "feat(thermalvtk): state-key constants for contour passthrough"
```

---

### Task 2: Ring emits `state_key`; `VTKOutline` writes it

**Files:**
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKOutlineRing.gdshader`
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKOutline.gd:97-138`
- Test: `.check/project/tests/test_shaders.gd`, `.check/project/tests/test_outline.gd`

**Interfaces:**
- Consumes: `VTKStates.KEY_NORMAL` (fallback key), `opts["state_key"]: Color`, `opts["grow"]: float`.
- Produces: ring `ShaderMaterial` param `state_key` (`Color`) and `grow` (`float`); handshake `opts["state_key"]` expected by `VTKOutline.refresh`.

- [ ] **Step 1: Write the failing tests**

In `.check/project/tests/test_shaders.gd`, add `t_ring_emits_state_key()` to `_run()`:

```gdscript
func t_state_key_uniform() -> void:
	var src := FileAccess.get_file_as_string("res://mods/ThermalVTK/VTKOutlineRing.gdshader")
	ck(src.contains("uniform vec3 state_key"), "ring declares state_key")
	ck(not src.contains("outline_color"), "ring no longer declares outline_color")
```

Append to `.check/project/tests/test_outline.gd` (add `t_refresh_sets_state_key()` to `_run()`):

```gdscript
func t_refresh_sets_state_key() -> void:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	var o = Outline.new()
	o.apply(7, root, {"state_key": Color(0, 1, 0), "grow": 0.01, "fill_alpha": 0.0})
	var ring: ShaderMaterial = o.material_of(7)["ring"]
	var body: ShaderMaterial = o.material_of(7)["body"]
	ck(ring.get_shader_parameter("state_key") == Color(0, 1, 0), "ring state_key set")
	ck(is_equal_approx(float(ring.get_shader_parameter("grow")), 0.01), "ring grow set")
	ck(is_equal_approx(float(body.get_shader_parameter("fill_alpha")), 0.0), "body fill_alpha forced from opts")
	root.free()
```

- [ ] **Step 2: Run to verify failure**

Run single `test_outline.gd` and `test_shaders.gd`. Expected: FAIL (`state_key` param null / ring source still has `outline_color`).

- [ ] **Step 3: Edit `VTKOutlineRing.gdshader`**

Replace the `outline_color` uniform and the fragment body:

```glsl
uniform vec3 state_key : source_color = vec3(1.0, 0.0, 0.0);
uniform float grow : hint_range(0.0, 0.15, 0.001) = 0.006;
uniform float rim_power : hint_range(0.0, 6.0, 0.1) = 1.0;

void vertex() {
	VERTEX += NORMAL * grow;
}

void fragment() {
	float rim01 = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	ALBEDO = state_key;
	ALPHA = pow(rim01, rim_power);
}
```

(Delete `outline_color` and `brightness`. Update the header comment: the colour is no longer drawn by this shader — it emits a detector key the overlay substitutes.)

- [ ] **Step 4: Edit `VTKOutline.gd::refresh`**

Replace the ring block (current lines ~105-124):

```gdscript
	var key: Color = opts.get("state_key", States.KEY_NORMAL)
	var grow := float(opts.get("grow", 0.006))
	if ring_mat.get_shader_parameter("state_key") != key \
			or not is_equal_approx(float(ring_mat.get_shader_parameter("grow")), grow):
		ring_mat.set_shader_parameter("state_key", key)
		ring_mat.set_shader_parameter("grow", grow)
```

Delete the now-unused locals `color`, `alpha`, `bright` from `refresh` (keep `flash`, `grow` usage for the body). Leave the body block unchanged.

- [ ] **Step 5: Run to verify pass**

Run single `test_outline.gd` and `test_shaders.gd` (after copying sources). Expected: `Outline tests passed`, `Shaders tests passed`.

- [ ] **Step 6: Commit (gated)**

```bash
git add "standalone mods/ThermalVTK/mods/ThermalVTK/VTKOutlineRing.gdshader" "standalone mods/ThermalVTK/mods/ThermalVTK/VTKOutline.gd" ".check/project/tests/test_outline.gd" ".check/project/tests/test_shaders.gd"
git commit -m "feat(thermalvtk): outline ring emits detector state_key"
```

---

### Task 3: `VTKESP` passes `state_key` and disables body fill

**Files:**
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKESP.gd` (`_opts_for`, ~258-283)
- Test: `.check/project/tests/test_esp.gd`

**Interfaces:**
- Consumes: `VTKStates.state_key`, `VTKStates.KEY_NOMAD`, `VTKOutline` opts contract from Task 2 (`state_key`, `fill_alpha`).
- Produces: `_opts_for` returns `state_key` (Color) and `fill_alpha = 0.0`.

- [ ] **Step 1: Write the failing test**

Add to `.check/project/tests/test_esp.gd` (add `const S = preload(...)` and `t_opts_state_key()` to `_run()`):

```gdscript
const S = preload("res://mods/ThermalVTK/VTKStates.gd")

func t_opts_state_key() -> void:
	var esp = ESP.new()
	esp.name = "VTKESP_opts"
	root.add_child(esp)
	var node := Node3D.new()
	root.add_child(node)
	var hostile := esp._opts_for({"cat": S.COMBAT, "nomad": false}, node, 10.0, 0.0)
	ck(hostile["state_key"] == S.KEY_COMBAT, "hostile combat keys combat")
	ck(is_equal_approx(float(hostile["fill_alpha"]), 0.0), "body fill disabled in contour mode")
	var nomad := esp._opts_for({"cat": S.NORMAL, "nomad": true}, node, 10.0, 0.0)
	ck(nomad["state_key"] == S.KEY_NOMAD, "nomad keys nomad")
	esp.free()
	node.free()
```

- [ ] **Step 2: Run to verify failure**

Run single `test_esp.gd` (after copying). Expected: FAIL (`state_key` missing / wrong).

- [ ] **Step 3: Edit `VTKESP.gd::_opts_for`**

Replace colour selection + return dict:

```gdscript
	var nomad := bool(e.get("nomad", false))
	var cat: int = int(e.get("cat", States.NORMAL))
	var key: Color = States.KEY_NOMAD if nomad else States.state_key(cat)
	var flash := 0.0
	if p_flash and _player_visible(node):
		flash = 0.7
	var foot_y: float = (node as Node3D).global_position.y
	return {
		"cat": cat,
		"nomad": nomad,
		"state_key": key,
		"alpha": alpha,
		"cool": cool,
		"through_walls": p_through > 0.0 and dist <= p_through,
		"flash": flash,
		"flash_color": p_flash_color,
		"foot_y": foot_y,
		"body_height": 1.8,
		"brightness": p_brightness,
		"grow": p_thickness,
		"fill_alpha": 0.0,
	}
```

Keep `p_fill`/`p_colors`/`p_nomad` fields for now (removed in Task 7 cleanup) — they are simply no longer emitted.

- [ ] **Step 4: Run to verify pass**

Run single `test_esp.gd`. Expected: `ESP tests passed`.

- [ ] **Step 5: Commit (gated)**

```bash
git add "standalone mods/ThermalVTK/mods/ThermalVTK/VTKESP.gd" ".check/project/tests/test_esp.gd"
git commit -m "feat(thermalvtk): contour passes state_key, body fill off in mode A"
```

---

### Task 4: Overlay detects state keys and substitutes colours (`VTKNVG`)

**Files:**
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKNVG.gd`
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKNVG.gdshader`
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/ThermalVTK.gd` (`_mcm_apply`)
- Test: `.check/project/tests/test_shaders.gd`

**Interfaces:**
- Consumes: emitted keys from `VTKStates` (Task 1) — new `DET_ST_*` constants are their measured/initial washed values.
- Produces: `VTKNVG.set_state_colors(colors: Dictionary)` (keys `state_normal`/`state_alerted`/`state_hunting`/`state_combat`/`nomad_color`); `VTKNVG.set_outline_brightness: float`; uniforms `stNormalKey/stAlertedKey/stHuntingKey/stCombatKey/stNomadKey`, `stNormalColor/stAlertedColor/stHuntingColor/stCombatColor/stNomadColor`, `stateBright`.

- [ ] **Step 1: Write the failing test**

Add to `.check/project/tests/test_shaders.gd`:

```gdscript
func t_state_keys_in_overlay() -> void:
	var f := FileAccess.open(NVG_SHADER_RES, FileAccess.READ)
	var code := f.get_as_text()
	f.close()
	for u in ["stNormalKey", "stAlertedKey", "stHuntingKey", "stCombatKey", "stNomadKey",
			"stNormalColor", "stAlertedColor", "stHuntingColor", "stCombatColor", "stNomadColor"]:
		ck(code.contains(u), "overlay declares %s" % u)
	ck(code.contains("dStN") and code.contains("dStNomad"), "overlay distance vars present")
```

- [ ] **Step 2: Run to verify failure**

Run single `test_shaders.gd`. Expected: FAIL.

- [ ] **Step 3: Edit `VTKNVG.gdshader`**

Add after the bot colour uniforms (~line 48):

```glsl
// Contour ESP state keys. The ring emits these fixed colours; the frame is
// NVG-processed before this shader sees it, so the *Key uniforms hold the
// measured post-NVG (washed) values (see VTKNVG.gd DET_ST_*). The *Color
// uniforms are the per-state display colours, substituted AFTER the palette.
uniform vec3 stNormalKey : source_color = vec3(1.0, 0.0, 0.0);
uniform vec3 stAlertedKey : source_color = vec3(1.0, 1.0, 0.0);
uniform vec3 stHuntingKey : source_color = vec3(1.0, 0.0, 1.0);
uniform vec3 stCombatKey : source_color = vec3(0.0, 1.0, 1.0);
uniform vec3 stNomadKey : source_color = vec3(0.0, 1.0, 0.0);
uniform vec3 stNormalColor : source_color = vec3(1.0, 0.72, 0.28);
uniform vec3 stAlertedColor : source_color = vec3(1.0, 0.9, 0.25);
uniform vec3 stHuntingColor : source_color = vec3(1.0, 0.5, 0.1);
uniform vec3 stCombatColor : source_color = vec3(0.95, 0.18, 0.15);
uniform vec3 stNomadColor : source_color = vec3(0.30, 1.0, 0.35);
uniform float stateBright : hint_range(0.1, 3.0, 0.05) = 0.6;
```

In the `if (thermalMode)` branch, extend the distance block (after `dMark`):

```glsl
		float dStN = distance(pixelColor.rgb, stNormalKey);
		float dStA = distance(pixelColor.rgb, stAlertedKey);
		float dStH = distance(pixelColor.rgb, stHuntingKey);
		float dStC = distance(pixelColor.rgb, stCombatKey);
		float dStNomad = distance(pixelColor.rgb, stNomadKey);
```

Then after `minD = min(minD, dMark);`:

```glsl
		minD = min(minD, min(min(dStN, dStA), min(min(dStH, dStC), dStNomad)));
```

And extend the substitution chain (before the bot-heat `else`):

```glsl
				} else if (minD == dStN) {
					subColor = stNormalColor * stateBright;
				} else if (minD == dStA) {
					subColor = stAlertedColor * stateBright;
				} else if (minD == dStH) {
					subColor = stHuntingColor * stateBright;
				} else if (minD == dStC) {
					subColor = stCombatColor * stateBright;
				} else if (minD == dStNomad) {
					subColor = stNomadColor * stateBright;
				} else {
```

(That final `else {` is the existing bot-heat block; keep its body verbatim.)

- [ ] **Step 4: Edit `VTKNVG.gd`**

Add constants near `DET_WARM` (~line 63):

```gdscript
# Contour state keys (emitted by VTKStates.KEY_*; mirrored here as the measured
# post-NVG values). INITIAL values = the emitted colours; Task 6 replaces them
# with the calibrated washed values.
const DET_ST_NORMAL := Color(1.0, 0.0, 0.0)
const DET_ST_ALERTED := Color(1.0, 1.0, 0.0)
const DET_ST_HUNTING := Color(1.0, 0.0, 1.0)
const DET_ST_COMBAT := Color(0.0, 1.0, 1.0)
const DET_ST_NOMAD := Color(0.0, 1.0, 0.0)
```

Add state field + setter near the other `set_*` vars / setters:

```gdscript
var set_outline_brightness: float = 0.6
var _state_colors: Dictionary = {}

func set_state_colors(colors: Dictionary) -> void:
	_state_colors = colors
	_apply_uniforms()
```

In `_apply_uniforms`, change the mode line:

```gdscript
	nvg_mat.set_shader_parameter("thermalMode", set_thermal and _nvg_active())
```

and add the pushes after the existing `mineColor`/`markerColor` lines:

```gdscript
	nvg_mat.set_shader_parameter("stNormalKey", DET_ST_NORMAL)
	nvg_mat.set_shader_parameter("stAlertedKey", DET_ST_ALERTED)
	nvg_mat.set_shader_parameter("stHuntingKey", DET_ST_HUNTING)
	nvg_mat.set_shader_parameter("stCombatKey", DET_ST_COMBAT)
	nvg_mat.set_shader_parameter("stNomadKey", DET_ST_NOMAD)
	nvg_mat.set_shader_parameter("stNormalColor", _state_colors.get("state_normal", Color(1.0, 0.72, 0.28)))
	nvg_mat.set_shader_parameter("stAlertedColor", _state_colors.get("state_alerted", Color(1.0, 0.9, 0.25)))
	nvg_mat.set_shader_parameter("stHuntingColor", _state_colors.get("state_hunting", Color(1.0, 0.5, 0.1)))
	nvg_mat.set_shader_parameter("stCombatColor", _state_colors.get("state_combat", Color(0.95, 0.18, 0.15)))
	nvg_mat.set_shader_parameter("stNomadColor", _state_colors.get("nomad_color", Color(0.30, 1.0, 0.35)))
	nvg_mat.set_shader_parameter("stateBright", set_outline_brightness)
```

Update the `bot_paint` doc comment (lines ~92-96): remove the claim that it "gates thermalMode / the palette is skipped".

- [ ] **Step 5: Edit `ThermalVTK.gd::_mcm_apply`**

Replace the `_esp.p_colors = {...}` / `_esp.p_nomad = ...` block with routing to `_nvg`, and add brightness:

```gdscript
		_esp.p_brightness = float(_mcm_key_val(cfg, "Float", "outline_brightness", 0.6))
		_nvg.set_outline_brightness = _esp.p_brightness
		_nvg.set_state_colors({
			"state_normal": _mcm_color_val(cfg, "state_normal", States.DEFAULT_NORMAL),
			"state_alerted": _mcm_color_val(cfg, "state_alerted", States.DEFAULT_ALERTED),
			"state_hunting": _mcm_color_val(cfg, "state_hunting", States.DEFAULT_HUNTING),
			"state_combat": _mcm_color_val(cfg, "state_combat", States.DEFAULT_COMBAT),
			"nomad_color": _mcm_color_val(cfg, "nomad_color", States.DEFAULT_NOMAD),
		})
```

Keep the existing `_esp.p_fill`/`p_flash`/`p_flash_color` lines (harmless; `p_fill` no longer affects fill_alpha, handled in Task 7).

- [ ] **Step 6: Run to verify pass**

Run single `test_shaders.gd`, then the full `check.ps1`. Expected: shaders pass; full run still green (22 tests).

- [ ] **Step 7: Commit (gated)**

```bash
git add "standalone mods/ThermalVTK/mods/ThermalVTK/VTKNVG.gd" "standalone mods/ThermalVTK/mods/ThermalVTK/VTKNVG.gdshader" "standalone mods/ThermalVTK/mods/ThermalVTK/ThermalVTK.gd" ".check/project/tests/test_shaders.gd"
git commit -m "feat(thermalvtk): overlay substitutes contour state keys after palette"
```

---

### Task 5: Palette dropdown (4 entries)

**Files:**
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKNVG.gdshader` (palette function)
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/ThermalVTK.gd` (registration + apply)
- Test: `.check/project/tests/test_shaders.gd`

**Interfaces:**
- Produces: `_palette_mode_from_cfg(cfg) -> int` (0=Classic, 1=Amber, 2=Forest, 3=Ice); shader `worldPaletteMode` accepts 0..3.

- [ ] **Step 1: Write the failing test**

Add to `.check/project/tests/test_shaders.gd`:

```gdscript
func t_palette_four_modes() -> void:
	var f := FileAccess.open(NVG_SHADER_RES, FileAccess.READ)
	var code := f.get_as_text()
	f.close()
	var n := 0
	for i in [1, 2, 3, 4, 5]:
		if code.contains("worldPaletteMode == %d" % i):
			n += 1
	ck(n == 3, "only modes 1..3 remain (got %d)" % n)
	ck(not code.contains("Black Hot"), "no Black Hot branch")
```

- [ ] **Step 2: Run to verify failure**

Run single `test_shaders.gd`. Expected: FAIL (`n == 5`).

- [ ] **Step 3: Edit the shader palette function**

Delete the `worldPaletteMode == 1` (white hot) and `== 2` (black hot) branches. Renumber: old `== 3` → `== 1`, old `== 4` → `== 2`, old `== 5` -> `== 3`. Keep the final `else` (= Classic) unchanged. Update the comment above `ThermalPalette` to `// 0 = Classic (else), 1 = Amber, 2 = Forest, 3 = Ice.`

- [ ] **Step 4: Edit `ThermalVTK.gd`**

Change the registration (line ~144):

```gdscript
	cfg.set_value("Dropdown", "thermal_palette", {"default": "classic", "value": "classic", "options": {"classic": "Classic", "amber": "Amber", "forest": "Forest", "ice": "Ice"}, "category": CAT, "menu_pos": 9, "tooltip": "World thermal palette.", "name": "World palette"})
```

Add a mapping helper (near the other `_mcm_*` helpers):

```gdscript
const PALETTE_MODES := {"classic": 0, "amber": 1, "forest": 2, "ice": 3}
# Old Int configs (0..5) map onto the 4 remaining palettes; 1/2 (white/black
# hot) were dropped and fall back to Classic.
const LEGACY_PALETTE := {0: 0, 3: 1, 4: 2, 5: 3}

func _palette_mode_from_cfg(cfg: ConfigFile) -> int:
	var raw = _mcm_key_val(cfg, "Dropdown", "thermal_palette", "classic")
	if raw is String:
		return int(PALETTE_MODES.get(raw, 0))
	if raw is int or raw is float:
		return int(LEGACY_PALETTE.get(int(raw), 0))
	return 0
```

Change the apply line (`_nvg.set_palette = ...`):

```gdscript
	_nvg.set_palette = _palette_mode_from_cfg(cfg)
```

- [ ] **Step 4b: Run to verify pass**

Run single `test_shaders.gd`. Expected: `Shaders tests passed`.

- [ ] **Step 5: Commit (gated)**

```bash
git add "standalone mods/ThermalVTK/mods/ThermalVTK/VTKNVG.gdshader" "standalone mods/ThermalVTK/mods/ThermalVTK/ThermalVTK.gd" ".check/project/tests/test_shaders.gd"
git commit -m "feat(thermalvtk): world palette dropdown (classic/amber/forest/ice)"
```

---

### Task 6: In-game calibration of `DET_ST_*` + visual verification

Cannot be done headless. The emitted state keys pass through the vanilla NVG world processing (glow + tonemap) and are alpha-blended with the world, so the washed values must be measured. This task is the gate before version bump/packaging.

**Files:**
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKNVG.gd` (`DET_ST_*`)
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKNVG.gdshader` (temporary debug uniform)

**Interfaces:**
- Consumes: everything from Tasks 1-5.
- Produces: final `DET_ST_NORMAL/ALERTED/HUNTING/COMBAT/NOMAD` values.

- [ ] **Step 1: Build and install a calibration build**

Bump `version.txt`/`mod.txt` is NOT needed yet; just package and install:
Run from `D:\RTVMOD`: `powershell -ExecutionPolicy Bypass -File pack.ps1`
Copy `ThermalVTK.vmz` to `D:\SteamLibrary\steamapps\common\Road to Vostok\mods\ThermalVTK.vmz`.

- [ ] **Step 2: Enter Mode A with a known NPC**

In game: put on NVG, press the mode hotkey so the on-screen toast reads `Thermal mode: CONTOUR`. Set MCM `NVG noise` to `0` and `World palette` to `Classic`. Approach/observe a hostile NPC so a ring is visible.

- [ ] **Step 3: Screenshot and sample ring pixels**

Capture a screenshot of the ring (windowed, no HUD overlap). Sample a pixel on the ring core (the densest band), reading its RGB. Do this for at least the `normal` (amber-category) state; if other states are hard to force, note the sampled `normal` value and reuse the same per-key offset later.

- [ ] **Step 4: Set `DET_ST_*` to the sampled values**

For each state, replace the corresponding constant in `VTKNVG.gd` with the measured post-NVG colour (the *display* substitution still comes from MCM, unaffected). Verify each `DET_ST_*` is >= 0.22 away from the others and from `DET_WARM/MID/COLD/MINE`.

- [ ] **Step 5: Verify detection**

Re-pack, reinstall, and confirm in Mode A that: the world is palette-coloured; the ring reads in its state colour and is NOT remapped by the palette; mines still highlight; Mode B (FULL) still shows bot heat + palette. If the ring is not detected, raise the shader's `stateBright` default and/or widen the ring band (`rim_power`), then re-measure.

- [ ] **Step 6: Commit (gated)**

```bash
git add "standalone mods/ThermalVTK/mods/ThermalVTK/VTKNVG.gd" "standalone mods/ThermalVTK/mods/ThermalVTK/VTKNVG.gdshader"
git commit -m "fix(thermalvtk): calibrate contour state-key detection bands"
```

---

### Task 7: Cleanup, version bump, package, install

**Files:**
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKESP.gd` (drop dead `p_colors`/`p_nomad`/`p_fill` emitters)
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/ThermalVTK.gd` (drop dead `_esp.p_colors`/`p_nomad`/`p_fill` writes)
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/version.txt`, `standalone mods/ThermalVTK/mod.txt`
- Modify: `standalone mods/ThermalVTK/CHANGELOG.md`, `README.md`
- Modify: `.check/project/tests/test_shaders.gd` (stale mine-test comment)

**Interfaces:**
- Consumes: all prior tasks.

- [ ] **Step 1: Remove dead contour-colour plumbing**

In `VTKESP.gd`: delete `p_colors`/`p_nomad` (and `p_fill` if now unused after Task 3 forcing `fill_alpha = 0.0`). In `ThermalVTK.gd::_mcm_apply`: delete the corresponding `_esp.p_colors = ...`, `_esp.p_nomad = ...`, `_esp.p_fill = ...` writes. (Keep `p_flash`/`p_flash_color` fields for the deferred PVisible return.) Re-run `check.ps1`; if a test references a removed field, fix the test.

- [ ] **Step 2: Fix stale test comment**

In `test_shaders.gd::t_nvg_contour_reads_mines`, update the comment to note the `else` branch now only serves the thermal-vision-off path (contour uses the `thermalMode` branch). Keep the assertion.

- [ ] **Step 3: Bump version**

Set `standalone mods/ThermalVTK/mods/ThermalVTK/version.txt` to `1.5.0` and `standalone mods/ThermalVTK/mod.txt` `version` to `1.5.0`.

- [ ] **Step 4: Update CHANGELOG**

Add a `## [1.5.0] - 2026-10-19` section (player-visible effects only):
- Added: contour outlines keep their state colours while the thermal palette is active.
- Changed: restored the thermal world palette in contour mode; world palette is now a 4-option choice (Classic / Amber / Forest / Ice).
- Fixed: (if applicable) outline detection tuning.

- [ ] **Step 5: Synchronize README** if it documents the palette options or modes.

- [ ] **Step 6: Full check**

Run from `D:\RTVMOD`: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`; also `py -3 .check\layout_check.py`. Expected: `Parse check passed`, `Tests passed: 22 file(s)`, exit 0.

- [ ] **Step 7: Pack and install**

Run from `D:\RTVMOD`: `powershell -ExecutionPolicy Bypass -File pack.ps1` (confirm the printed version reads `1.5.0`). Copy `ThermalVTK.vmz` to the game mods folder and record its SHA256.

- [ ] **Step 8: Commit (gated)**

```bash
git add "standalone mods/ThermalVTK"
git commit -m "chore(thermalvtk): 1.5.0 -- mode A palette + keyed contour, palette dropdown"
```

---

## Self-Review

**Spec coverage:**
- Approach 1 state keys → Tasks 1-4.
- 5 states, no flash in A → Tasks 1, 3 (flash not emitted; fields kept).
- Body fill off in A → Task 3 (`fill_alpha = 0.0`).
- Palette Dropdown 4 + migration → Task 5.
- Calibration → Task 6.
- Related edits (stale comments, `outline_brightness` → overlay) → Tasks 4, 7.
- Version/pack → Task 7.
- Tests (test_states/test_shaders/test_outline/test_esp) → Tasks 1-5.

**Known gaps / accepted simplifications (verify in Task 6):**
- **Distance fade.** The ring now emits an exact key with rim-shaped alpha and no distance alpha, so the outline no longer fades smoothly with distance (hard cutoff at `outline_distance`). If the fade is wanted back, add a `discard`-dither in the ring driven by `opts["alpha"]` (keeps keys pure) — deferred until requested.
- `outline_brightness` now multiplies the overlay substitution colour (`stateBright`), not the ring.
- Dead nomad-marker code (`markNomads`/`MARKER_KEY`/`markerKey`) intentionally untouched.

**Type consistency:** emitted keys `VTKStates.KEY_*` (Color) ↔ opelay `DET_ST_*` (Color) via `set_state_colors` dict keys `state_normal/state_alerted/state_hunting/state_combat/nomad_color` (matches MCM colour keys in `ThermalVTK.gd`). Ring param name `state_key` consistent across `VTKOutlineRing.gdshader`, `VTKOutline.gd`, `VTKESP.gd`.
