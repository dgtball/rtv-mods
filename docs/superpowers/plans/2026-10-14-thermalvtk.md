# ThermalVTK Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a standalone Godot mod, `ThermalVTK`, that ships only the NVG/thermal-vision feature of Vostok Toolkit, plus a hotkey that toggles thermal with an on-screen notification.

**Architecture:** A direct port of `loadouts/mods/VTK/VTKNVG.gd` + its two shaders into a fresh `res://mods/ThermalVTK/` namespace, with all debug tooling removed and a small `ThermalVTK.gd` autoload replacing `VTKUI.gd`'s MCM/config role. The autoload reads its own MCM config, drives the NVG node, and handles the toggle hotkey.

**Tech Stack:** GDScript (Godot 4.6.3), `.gdshader`, MCM (`mod_configuration_menu`), PowerShell build/check scripts.

## Global Constraints

- Godot 4.6.3; indie tabs only in `.gd`; files UTF-8.
- Version lives in exactly one place: `standalone mods/ThermalVTK/mod.txt` `version="1.0.0"`. No `MOD_VERSION`/version constants in GDScript. `pack.ps1` writes `mods/ThermalVTK/version.txt` from `mod.txt`.
- Identity is exactly: name `ThermalVTK`, id `thermal-vtk`, folder `res://mods/ThermalVTK/`, autoload `ThermalVTK`, config dir `user://MCM/thermal-vtk`, artifact `ThermalVTK.vmz`.
- English-only UI strings. No localisation, no debug probe / F4 overlay / `debug.log`.
- Scripts may only reference `res://mods/ThermalVTK/...` paths and `res://ModConfigurationMenu/Scripts/Doink Oink/MCM_Helpers.tres`.
- Do not run alongside Vostok Toolkit; documented in README.
- Parse verification command (run from repo root; add `-Godot "<path>"` if the binary is not on PATH):
  `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
  Green means: each standalone script prints `ok`, and the run ends without `SCRIPT ERROR` / `Parse Error` / `Invalid call` / `Failed to load script`.

---

### Task 1: Scaffold, paths, shaders, parse-check wiring

**Files:**
- Rename dir: `standalone mods/ThermalV` → `standalone mods/ThermalVTK`
- Create: `standalone mods/ThermalVTK/mod.txt`
- Create: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKPaths.gd`
- Create: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKBot.gdshader` (copy, unchanged)
- Create: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKNVG.gdshader` (copy + debugDetect removed)
- Modify: `.gitignore`
- Modify: `.check/check.ps1`

**Interfaces:**
- Consumes: nothing.
- Produces: `VTKPaths.gd` constants `LOADER`, `NVG`, `GAME_DATA` (used by Tasks 2–4); parse-check coverage of `res://mods/ThermalVTK/*.gd`.

- [ ] **Step 1: Rename the folder**

```powershell
Rename-Item -LiteralPath "D:\RTVMOD\standalone mods\ThermalV" -NewName "ThermalVTK"
```

- [ ] **Step 2: Whitelist the folder in `.gitignore`**

Replace the file contents with:

```
/*
!/.gitignore
!/LICENSE
!/README.md
!/CHANGELOG.md
!/assets/
!/loadouts/
!/standalone mods/
!/docs/vostokmods/
/standalone mods/**/*.vmz
```

- [ ] **Step 3: Write `mod.txt`**

```ini
[mod]
name="ThermalVTK"
id="thermal-vtk"
version="1.0.0"

[autoload]
ThermalVTK="res://mods/ThermalVTK/ThermalVTK.gd"

[dependencies]
optional=["mod_configuration_menu"]
```

- [ ] **Step 4: Write `VTKPaths.gd`**

```gdscript
extends RefCounted
# Hard paths into the game used by ThermalVTK. Absolute NodePaths from the tree
# root, so they resolve through get_node_or_null(...) from any node. Fix here on
# a game update, not in each file.

const LOADER := "/root/Loader"
const NVG := "/root/Map/Core/UI/NVG"
const GAME_DATA := "res://Resources/GameData.tres"
```

- [ ] **Step 5: Copy both shaders into place**

```powershell
$dst = "D:\RTVMOD\standalone mods\ThermalVTK\mods\ThermalVTK"
Copy-Item "D:\RTVMOD\loadouts\mods\VTK\VTKBot.gdshader" $dst -Force
Copy-Item "D:\RTVMOD\loadouts\mods\VTK\VTKNVG.gdshader" $dst -Force
```

`VTKBot.gdshader` needs no edits.

- [ ] **Step 6: Remove the debug uniform + branch from `VTKNVG.gdshader`**

Delete this line entirely:

```glsl
uniform bool debugDetect = false;
```

Then replace this block:

```glsl
		// The framebuffer can be read back only after shading, so a CPU probe
		// can never see the pre-shader frame. Let the shader report itself:
		// green where the detector fires, black where it misses.
		if (debugDetect) {
			color = vec4(minD < 0.22 ? vec3(0.0, 1.0, 0.0) : vec3(0.0), pixelColor.a);
		} else {
			float rawLuminance = dot(pixelColor.rgb, vec3(0.299, 0.587, 0.114));
```

with:

```glsl
		{
			float rawLuminance = dot(pixelColor.rgb, vec3(0.299, 0.587, 0.114));
```

(The `{` keeps the inner scope intact so the closing `}` before `} else {` at the `if (thermalMode)` level stays balanced.)

- [ ] **Step 7: Extend `.check/check.ps1` for the standalone sources**

After the existing copy block (the three `Copy-Item` lines that fill `$modDst`), insert:

```powershell
$altSrc = Join-Path (Split-Path $checkRoot -Parent) "standalone mods\ThermalVTK\mods\ThermalVTK"
$altDst = Join-Path $proj "mods\ThermalVTK"
if (Test-Path -LiteralPath $altSrc -PathType Container) {
    if (Test-Path -LiteralPath $altDst) { Remove-Item -LiteralPath $altDst -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $altDst | Out-Null
    Copy-Item -Path (Join-Path $altSrc "*.gd") -Destination $altDst -Force -ErrorAction SilentlyContinue
    Copy-Item -Path (Join-Path $altSrc "*.gdshader") -Destination $altDst -Force -ErrorAction SilentlyContinue
}
```

Then, immediately before the `Write-Host "Parse check passed: $($scripts.Count) scripts"` line, insert:

```powershell
if (Test-Path -LiteralPath $altDst -PathType Container) {
    $altScripts = Get-ChildItem -LiteralPath $altDst -Filter "*.gd" | Sort-Object Name
    foreach ($s in $altScripts) {
        $res = "res://mods/ThermalVTK/" + $s.Name
        $out = & $Godot --headless --path $proj --check-only --script $res 2>&1 | Out-String
        $bad = ($LASTEXITCODE -ne 0) -or ($out -match "SCRIPT ERROR|Parse Error|Failed to load script")
        if ($bad) {
            $fail++
            Write-Host "FAIL  ThermalVTK/$($s.Name)"
            Write-Host $out.Trim()
        } else {
            Write-Host "ok    ThermalVTK/$($s.Name)"
        }
    }
}
```

- [ ] **Step 8: Run the check stand**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: the existing VTK scripts check `ok`, plus one line `ok    ThermalVTK/VTKPaths.gd`; no `SCRIPT ERROR`/`Parse Error`; exit 0.

- [ ] **Step 9: Commit**

```powershell
git -C "D:\RTVMOD" add ".gitignore" ".check/check.ps1" "standalone mods/ThermalVTK"
git -C "D:\RTVMOD" commit -m "feat(thermalvtk): scaffold standalone mod, paths, shaders, check wiring"
```

---

### Task 2: Port `VTKNVG.gd` (probe-free)

**Files:**
- Create: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKNVG.gd`

**Interfaces:**
- Consumes: `VTKPaths.gd` (`NVG`, `GAME_DATA`).
- Produces: class `VTKNVG extends Node` with public fields `set_nvg_noise`, `set_nvg_white`, `set_palette`, `set_world`, `set_mark_nomads`, `set_winter_auto`, `set_winter_dim`, `set_bot_preset`, `set_far_distance` and methods `set_thermal_enabled(on: bool)`, `set_mines_enabled(on: bool)` (used by Tasks 3–4).

- [ ] **Step 1: Copy the source**

```powershell
Copy-Item "D:\RTVMOD\loadouts\mods\VTK\VTKNVG.gd" "D:\RTVMOD\standalone mods\ThermalVTK\mods\ThermalVTK\VTKNVG.gd" -Force
```

- [ ] **Step 2: Repoint the preload and shader paths**

Replace:

```gdscript
const Paths = preload("res://mods/VTK/VTKPaths.gd")
```

with:

```gdscript
const Paths = preload("res://mods/ThermalVTK/VTKPaths.gd")
```

Replace:

```gdscript
const SHADER_RES := "res://mods/VTK/VTKNVG.gdshader"
const BOT_SHADER_RES := "res://mods/VTK/VTKBot.gdshader"

const DEBUG_MINES := false
const DEBUG_LOG := "user://loadouts_debug.log"
```

with:

```gdscript
const SHADER_RES := "res://mods/ThermalVTK/VTKNVG.gdshader"
const BOT_SHADER_RES := "res://mods/ThermalVTK/VTKBot.gdshader"
```

- [ ] **Step 3: Delete the debug vars and logging functions**

Delete the entire block from `var _dbg_f: FileAccess = null` through the end of `_dbg_map()` (immediately before `const TICK := 0.1`), i.e.:

```gdscript
var _dbg_f: FileAccess = null
var _dbg_summary_cd: float = 0.0

func _dbg_open() -> void:
	... (whole functions _dbg_open, _dbg, _dbg_map) ...
func _dbg_map() -> String:
	if _game_data == null:
		return "?"
	return String(_game_data.get("currentMap"))
```

so that `const TICK := 0.1` follows the `MINE_KEY` comment/const directly.

- [ ] **Step 4: Delete the `set_debug_probe` field**

Replace:

```gdscript
# Off by default. Gates every probe and the F4 detection overlay; when false
# _dbg() returns immediately, so nothing is written to the log and no file is
# even opened. Turn on from MCM only when there is something to diagnose.
var set_debug_probe: bool = false

var _game_data: Resource = null
```

with:

```gdscript
var _game_data: Resource = null
```

- [ ] **Step 5: Delete `_debug_detect`**

Replace:

```gdscript
var _scene_ref: Node = null
var _debug_detect: bool = false
```

with:

```gdscript
var _scene_ref: Node = null
```

- [ ] **Step 6: Delete the F4 input handler and `apply_debug_probe`**

Delete from `func _unhandled_input(event: InputEvent) -> void:` up to and including the end of `func apply_debug_probe()`, so that `func _ready() -> void:` follows the `_was_on` var block directly.

- [ ] **Step 7: Strip the debug block from `_ready`**

Replace:

```gdscript
	if set_debug_probe:
		_dbg_open()
		_dbg("[probe] ready, gameData=" + str(_game_data != null) + " shader=" + str(ResourceLoader.exists(SHADER_RES)))

	# Shader lives in its own .gdshader file (packed by pack.ps1). load() is
```

with:

```gdscript
	# Shader lives in its own .gdshader file (packed by pack.ps1). load() is
```

- [ ] **Step 8: Drop the Trader logging branch**

In `_scan_node`, replace:

```gdscript
	elif path.ends_with("Mine.gd"):
		_register_mine(n)
	elif path.ends_with("Trader.gd"):
		_log_trader(n)
	elif _is_bot(n):
		_register_bot(n)
```

with:

```gdscript
	elif path.ends_with("Mine.gd"):
		_register_mine(n)
	elif _is_bot(n):
		_register_bot(n)
```

In `_deferred_check`, replace:

```gdscript
	if path.ends_with("Mine.gd"):
		_register_mine(n)
		return
	if path.ends_with("Trader.gd"):
		_log_trader(n)
		return
	if _is_bot(n):
		_register_bot(n)
```

with:

```gdscript
	if path.ends_with("Mine.gd"):
		_register_mine(n)
		return
	if _is_bot(n):
		_register_bot(n)
```

- [ ] **Step 9: Strip debug from `_try_install_shader`**

Replace:

```gdscript
	if mat == null or not (mat is ShaderMaterial):
		if set_debug_probe and _installed:
			_dbg("[probe] install lost: material is " + str(mat))
		_installed = false
		return
	mat.shader = _shader
	_nvg_mat_node = target
	_installed = true
	if set_debug_probe:
		_dbg("[probe] shader INSTALLED on " + str(target.get_path()))
	_apply_uniforms()
```

with:

```gdscript
	if mat == null or not (mat is ShaderMaterial):
		_installed = false
		return
	mat.shader = _shader
	_nvg_mat_node = target
	_installed = true
	_apply_uniforms()
```

- [ ] **Step 10: Drop `debugDetect` from `_apply_uniforms`**

Replace:

```gdscript
	nvg_mat.set_shader_parameter("worldPaletteMode", set_palette)
	nvg_mat.set_shader_parameter("debugDetect", _debug_detect)
	nvg_mat.set_shader_parameter("markNomads", set_mark_nomads)
```

with:

```gdscript
	nvg_mat.set_shader_parameter("worldPaletteMode", set_palette)
	nvg_mat.set_shader_parameter("markNomads", set_mark_nomads)
```

- [ ] **Step 11: Delete the debug summary block from `_process`**

Replace:

```gdscript
	_retry_mines()

	if set_debug_probe:
		_dbg_summary_cd -= delta
		if _dbg_summary_cd <= 0.0:
			... (whole block through _probe_pixels()) ...
```

with:

```gdscript
	_retry_mines()
```

- [ ] **Step 12: Delete `_probe_pixels`, `_count_friendly`, `_log_trader`**

Delete the entire run from the comment `# Reads the real framebuffer back ...` (immediately after `_cdist`) through the end of `_log_trader()`, so that `func _register_bot(node: Node) -> void:` follows `_cdist` directly.

- [ ] **Step 13: Strip debug from `_register_bot`**

Replace:

```gdscript
		"paint": null,
		"probed": false,
		"friendly": _is_friendly(node),
```

with:

```gdscript
		"paint": null,
		"friendly": _is_friendly(node),
```

Replace:

```gdscript
		"child_count": -1,
	}
	if set_debug_probe:
		_dbg("[bot] %s tracked pos=%s" % [node.get_path(), str(node.global_position)])
```

with:

```gdscript
		"child_count": -1,
	}
```

- [ ] **Step 14: Strip the clobber report from `_frame_pre_draw`**

Replace:

```gdscript
			if g.material_override == paint:
				continue
			if set_debug_probe and not e.get("probed", false):
				_dbg("[bot:clobber] %s mesh=%s was=%s now=%s" % [
					node.name, String(g.name), str(paint),
					(g.material_override.get_class() if g.material_override != null else "null")])
				e["probed"] = true
			g.material_override = paint
```

with:

```gdscript
			if g.material_override == paint:
				continue
			g.material_override = paint
```

- [ ] **Step 15: Delete `_describe` and `_mesh_paths`**

Delete the run from `func _describe(n: Variant) -> String:` through the end of `func _mesh_paths(meshes: Array) -> Array:`, so that `func _retry_mines() -> void:` follows `_register_mine` directly.

- [ ] **Step 16: Strip debug from `_register_mine`**

Replace:

```gdscript
	var _inner = node.get("mine")
	var visual: Node = node
	if set_debug_probe:
		_dbg("[mine] %s | mine_prop=%s (%s) | sweep=whole_node | children=%d" % [
			node.get_path(), str(_inner), ("null" if _inner == null else _inner.get_class()),
			node.get_child_count()])
	var meshes: Array = []
	_collect_meshes(visual, meshes)
	if set_debug_probe:
		_dbg("[mine] %s | collected %d geometry nodes: %s" % [node.get_path(), meshes.size(), str(_mesh_paths(meshes))])
		var _sizes: Array = []
		for m in meshes:
			if is_instance_valid(m):
				_sizes.append("%s(aabb=%s)" % [m.name, str((m as GeometryInstance3D).get_aabb().size)])
		_dbg("[mine] %s | shell+interior sizes: %s" % [node.get_path(), str(_sizes)])
	if meshes.is_empty():
```

with:

```gdscript
	var visual: Node = node
	var meshes: Array = []
	_collect_meshes(visual, meshes)
	if meshes.is_empty():
```

Replace:

```gdscript
		_mine_watch[id] = node
		if DEBUG_MINES:
			print("[VTKNVG] mine without mesh yet: %s" % node.get_path())
		return
	_mine_watch.erase(id)
	_mines[id] = {"node": node, "meshes": meshes}
	if DEBUG_MINES:
		print("[VTKNVG] mine registered: %s meshes=%d" % [node.get_path(), meshes.size()])
```

with:

```gdscript
		_mine_watch[id] = node
		return
	_mine_watch.erase(id)
	_mines[id] = {"node": node, "meshes": meshes}
```

- [ ] **Step 17: Delete `_mine_report`**

Delete the run from `func _mine_report() -> void:` through its closing line, so that `func set_thermal_enabled(on: bool) -> void:` follows `_update_mine` directly.

- [ ] **Step 18: Verify no debug symbols remain**

Run: `Select-String -Path "D:\RTVMOD\standalone mods\ThermalVTK\mods\ThermalVTK\VTKNVG.gd" -SimpleMatch -Pattern "_dbg","set_debug_probe","DEBUG_","_probe_pixels","_log_trader","_describe","_mesh_paths","_mine_report","_count_friendly","_debug_detect"`
Expected: no output.

- [ ] **Step 19: Run the check stand**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `ok    ThermalVTK/VTKPaths.gd`, `ok    ThermalVTK/VTKNVG.gd`; no `SCRIPT ERROR`/`Parse Error`; exit 0.

- [ ] **Step 20: Commit**

```powershell
git -C "D:\RTVMOD" add "standalone mods/ThermalVTK/mods/ThermalVTK/VTKNVG.gd"
git -C "D:\RTVMOD" commit -m "feat(thermalvtk): port VTKNVG without debug probe"
```

---

### Task 3: Autoload `ThermalVTK.gd` — MCM + settings

**Files:**
- Create: `standalone mods/ThermalVTK/mods/ThermalVTK/ThermalVTK.gd`

**Interfaces:**
- Consumes: `VTKPaths.gd` (`LOADER`); `VTKNVG.gd` public setters/fields from Task 2.
- Produces: autoload `ThermalVTK` with `_key_thermal_toggle: int`, `_thermal_enabled: bool`, `_mines_enabled: bool`, `_ensure_nvg()`, `_mcm_apply(cfg)`, `_mod_version()`. (Hotkey/notification come in Task 4.)

- [ ] **Step 1: Write `ThermalVTK.gd`**

```gdscript
extends Node
const Paths = preload("res://mods/ThermalVTK/VTKPaths.gd")

const MOD_ID := "thermal-vtk"
const MOD_NAME := "ThermalVTK"
const CONFIG_DIR := "user://MCM/thermal-vtk"
const CONFIG_FILE := "user://MCM/thermal-vtk/config.ini"
const MCM_HELPERS := "res://ModConfigurationMenu/Scripts/Doink Oink/MCM_Helpers.tres"

var _nvg: Node = null
var _key_thermal_toggle: int = 0
var _thermal_enabled: bool = false
var _mines_enabled: bool = true

func _ready() -> void:
	_register_mcm()

func _ensure_nvg() -> void:
	if _nvg != null and is_instance_valid(_nvg):
		return
	var NVG = preload("res://mods/ThermalVTK/VTKNVG.gd")
	_nvg = NVG.new()
	add_child(_nvg)

# ---------- MCM ----------

func _register_mcm() -> void:
	_ensure_nvg()
	if not ResourceLoader.exists(MCM_HELPERS):
		_apply_defaults()
		return
	var MCM = load(MCM_HELPERS)
	if MCM == null or not MCM.has_method("RegisterConfiguration"):
		_apply_defaults()
		return
	var cfg = ConfigFile.new()
	var CAT := "01. ThermalVision"
	cfg.set_value("Keycode", "key_thermal_toggle", {"name": "Hotkey: Toggle thermal vision", "default": 0, "default_type": "Keycode", "value": 0, "category": CAT, "menu_pos": 0, "tooltip": "Press in game to turn the thermal layer on and off."})
	cfg.set_value("Float", "nvg_noise", {"name": "NVG noise", "default": 4.0, "value": 4.0, "minRange": 0.0, "maxRange": 60.0, "step": 0.5, "category": CAT, "menu_pos": 1, "tooltip": "Grain amount over the NVG image. Lower is cleaner. Vanilla is fixed at 10."})
	cfg.set_value("Float", "nvg_white", {"name": "NVG brightness", "default": 1.0, "value": 1.0, "minRange": 0.05, "maxRange": 1.0, "step": 0.05, "category": CAT, "menu_pos": 2, "tooltip": "Brightness of the NVG image. 1 = full brightness; lower darkens the whole overlay."})
	cfg.set_value("Bool", "thermal_enabled", {"name": "Thermal vision", "default": false, "value": false, "category": CAT, "menu_pos": 3, "tooltip": "Master switch for the thermal vision layer: bot heat glow, mines and the Nomad marker. Plain green NVG is unaffected while this is off."})
	cfg.set_value("Bool", "thermal_mines", {"name": "Mine highlighting", "default": true, "value": true, "category": CAT, "menu_pos": 4, "tooltip": "Highlight mines while thermal vision is on."})
	cfg.set_value("Bool", "thermal_mark_nomads", {"name": "Mark friendly Nomads", "default": true, "value": true, "category": CAT, "menu_pos": 5, "tooltip": "Draw a floating green marker over friendly Nomads so they are not shot by accident."})
	cfg.set_value("Bool", "thermal_winter_auto", {"name": "Winter auto-dimming", "default": true, "value": true, "category": CAT, "menu_pos": 6, "tooltip": "In winter (season 2) snow blows the thermal image out; dim the world so bots stay readable."})
	cfg.set_value("Float", "thermal_winter_dim", {"name": "Winter dimming", "default": 0.55, "value": 0.55, "minRange": 0.2, "maxRange": 1.0, "step": 0.05, "category": CAT, "menu_pos": 7, "tooltip": "Multiplier applied to world brightness while winter auto-dimming is active. Lower means darker snow."})
	cfg.set_value("Int", "thermal_palette", {"default": 0, "value": 0, "minRange": 0, "maxRange": 5, "step": 1, "category": CAT, "menu_pos": 8, "tooltip": "0 = Classic, 1 = White Hot (grey), 2 = Black Hot (inverted grey), 3 = Amber, 4 = Forest, 5 = Ice.", "name": "World palette"})
	cfg.set_value("Float", "thermal_world", {"default": 1.70, "value": 1.70, "minRange": 1.0, "maxRange": 4.0, "step": 0.05, "category": CAT, "menu_pos": 9, "tooltip": "How bright the surrounding world reads in thermal.", "name": "World brightness"})
	cfg.set_value("Int", "thermal_bot_preset", {"default": 0, "value": 0, "minRange": 0, "maxRange": 3, "step": 1, "category": CAT, "menu_pos": 10, "tooltip": "0 = Amber, 1 = White, 2 = Orange, 3 = Red. Living bots glow in this colour; a corpse cools from the head down before disappearing.", "name": "Bot colour"})
	cfg.set_value("Float", "thermal_far_distance", {"default": 45.0, "value": 45.0, "minRange": 5.0, "maxRange": 300.0, "step": 5.0, "category": CAT, "menu_pos": 11, "tooltip": "Bots and mines only glow within this distance; past it they read as ordinary scenery. 5 = only right beside you, 300 = the whole map.", "name": "Distance"})
	cfg.set_value("Info", "version", _mod_version())
	cfg.set_value("Info", "author", "opencode")
	DirAccess.make_dir_recursive_absolute(CONFIG_DIR)
	_sync_config(cfg)
	MCM.RegisterConfiguration(MOD_ID, MOD_NAME, CONFIG_DIR, "NVG thermal overlay: bot, mine and Nomad highlighting", _mcm_apply, self)
	_mcm_apply(ConfigFile.new())

# Merge the freshly declared keys into the on-disk config by KEY: drop sections
# and keys that no longer exist in code, add new ones, but never overwrite a
# user's saved "value". Info is always rewritten.
func _sync_config(cfg: ConfigFile) -> void:
	var existing := ConfigFile.new()
	if FileAccess.file_exists(CONFIG_FILE):
		existing.load(CONFIG_FILE)
		var stale_sections := []
		for s in existing.get_sections():
			if s != "Info" and not cfg.has_section(s):
				stale_sections.append(s)
		for s in stale_sections:
			existing.erase_section(s)
		for s in cfg.get_sections():
			var stale_keys: Array = []
			if existing.has_section(s):
				for k in existing.get_section_keys(s):
					if not cfg.has_section_key(s, k):
						stale_keys.append(k)
			for k in stale_keys:
				existing.erase_section_key(s, k)
		for s in cfg.get_sections():
			for k in cfg.get_section_keys(s):
				if s == "Info":
					existing.set_value(s, k, cfg.get_value(s, k, {}))
					continue
				if not existing.has_section_key(s, k):
					existing.set_value(s, k, cfg.get_value(s, k, {}))
					continue
				var old_v = existing.get_value(s, k, {})
				var new_v = cfg.get_value(s, k, {})
				if typeof(old_v) == TYPE_DICTIONARY and typeof(new_v) == TYPE_DICTIONARY:
					var merged = new_v.duplicate()
					merged["value"] = old_v.get("value", new_v.get("value"))
					existing.set_value(s, k, merged)
		existing.save(CONFIG_FILE)
	if not FileAccess.file_exists(CONFIG_FILE):
		cfg.save(CONFIG_FILE)

func _mcm_key_val(cfg: ConfigFile, section: String, key: String, fallback):
	if not cfg.has_section_key(section, key):
		return fallback
	var d = cfg.get_value(section, key, {})
	if typeof(d) == TYPE_DICTIONARY and d.has("value"):
		return d["value"]
	return d if typeof(d) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT] else fallback

func _mcm_apply(cfg: ConfigFile) -> void:
	if cfg.get_sections().is_empty() and FileAccess.file_exists(CONFIG_FILE):
		cfg.load(CONFIG_FILE)
	_ensure_nvg()
	if _nvg == null or not is_instance_valid(_nvg):
		return
	_key_thermal_toggle = int(_mcm_key_val(cfg, "Keycode", "key_thermal_toggle", 0))
	_thermal_enabled = bool(_mcm_key_val(cfg, "Bool", "thermal_enabled", false))
	_mines_enabled = bool(_mcm_key_val(cfg, "Bool", "thermal_mines", true))
	_nvg.set_nvg_noise = float(_mcm_key_val(cfg, "Float", "nvg_noise", 4.0))
	_nvg.set_nvg_white = float(_mcm_key_val(cfg, "Float", "nvg_white", 1.0))
	_nvg.set_palette = int(_mcm_key_val(cfg, "Int", "thermal_palette", 0))
	_nvg.set_world = float(_mcm_key_val(cfg, "Float", "thermal_world", 1.70))
	_nvg.set_mark_nomads = bool(_mcm_key_val(cfg, "Bool", "thermal_mark_nomads", true))
	_nvg.set_winter_auto = bool(_mcm_key_val(cfg, "Bool", "thermal_winter_auto", true))
	_nvg.set_winter_dim = float(_mcm_key_val(cfg, "Float", "thermal_winter_dim", 0.55))
	_nvg.set_bot_preset = int(_mcm_key_val(cfg, "Int", "thermal_bot_preset", 0))
	_nvg.set_far_distance = float(_mcm_key_val(cfg, "Float", "thermal_far_distance", 45.0))
	_nvg.set_thermal_enabled(_thermal_enabled)
	_nvg.set_mines_enabled(_mines_enabled)

func _apply_defaults() -> void:
	if _nvg != null and is_instance_valid(_nvg):
		_nvg.set_thermal_enabled(_thermal_enabled)
		_nvg.set_mines_enabled(_mines_enabled)

func _mod_version() -> String:
	var vf = FileAccess.open("res://mods/ThermalVTK/version.txt", FileAccess.READ)
	if vf == null:
		return "unknown"
	var v := vf.get_as_text().strip_edges()
	vf.close()
	return v if v != "" else "unknown"
```

- [ ] **Step 2: Verify the config path exists in MCM land (no-op sanity)**

Run: `Select-String -Path "D:\RTVMOD\standalone mods\ThermalVTK\mods\ThermalVTK\ThermalVTK.gd" -SimpleMatch -Pattern "user://MCM/thermal-vtk"`
Expected: two matches (`CONFIG_DIR`, `CONFIG_FILE`).

- [ ] **Step 3: Run the check stand**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `ok    ThermalVTK/VTKPaths.gd`, `ok    ThermalVTK/VTKNVG.gd`, `ok    ThermalVTK/ThermalVTK.gd`; no parse errors; exit 0.

- [ ] **Step 4: Commit**

```powershell
git -C "D:\RTVMOD" add "standalone mods/ThermalVTK/mods/ThermalVTK/ThermalVTK.gd"
git -C "D:\RTVMOD" commit -m "feat(thermalvtk): add MCM-backed autoload and settings"
```

---

### Task 4: Hotkey toggle + notification + persistence

**Files:**
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/ThermalVTK.gd`

**Interfaces:**
- Consumes: `_key_thermal_toggle`, `_thermal_enabled`, `_nvg`, `Paths.LOADER` from Task 3.
- Produces: `_unhandled_input(event)`, `_toggle_thermal()`, `_notify(text: String, color: Color)`, `_save_thermal_enabled(v: bool)`.

- [ ] **Step 1: Add input handling and the toggle helpers**

Insert immediately after the `_ensure_nvg()` function:

```gdscript
# ---------- hotkey ----------

func _unhandled_input(event: InputEvent) -> void:
	if _key_thermal_toggle == 0:
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k := event as InputEventKey
	if k.keycode == _key_thermal_toggle or k.physical_keycode == _key_thermal_toggle:
		_toggle_thermal()
		get_viewport().set_input_as_handled()

func _toggle_thermal() -> void:
	_thermal_enabled = not _thermal_enabled
	if _nvg != null and is_instance_valid(_nvg):
		_nvg.set_thermal_enabled(_thermal_enabled)
	_notify("Thermal vision: " + ("ON" if _thermal_enabled else "OFF"),
		Color.GREEN if _thermal_enabled else Color(0.7, 0.7, 0.7))
	_save_thermal_enabled(_thermal_enabled)

# Same toast channel the toolkit uses for "Loadout ... applied".
func _notify(text: String, color: Color) -> void:
	var loader = get_node_or_null(Paths.LOADER)
	if loader != null and loader.has_method("Message"):
		loader.Message(text, color)

# Persist the hotkey choice as the MCM value so it survives a restart. The
# config file is MCM's own; here we only flip the "value" of an existing entry.
func _save_thermal_enabled(v: bool) -> void:
	if not FileAccess.file_exists(CONFIG_FILE):
		return
	var cf := ConfigFile.new()
	if cf.load(CONFIG_FILE) != OK:
		return
	if not cf.has_section_key("Bool", "thermal_enabled"):
		return
	var d = cf.get_value("Bool", "thermal_enabled", {})
	if typeof(d) != TYPE_DICTIONARY:
		return
	d["value"] = v
	cf.set_value("Bool", "thermal_enabled", d)
	cf.save(CONFIG_FILE)
```

- [ ] **Step 2: Run the check stand**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: all three standalone scripts `ok`; no parse errors; exit 0.

- [ ] **Step 3: Commit**

```powershell
git -C "D:\RTVMOD" add "standalone mods/ThermalVTK/mods/ThermalVTK/ThermalVTK.gd"
git -C "D:\RTVMOD" commit -m "feat(thermalvtk): toggle hotkey with on-screen notification"
```

---

### Task 5: Build script, docs, packaging

**Files:**
- Create: `standalone mods/ThermalVTK/pack.ps1`
- Create: `standalone mods/ThermalVTK/README.md`
- Create: `standalone mods/ThermalVTK/CHANGELOG.md`

**Interfaces:**
- Consumes: every file from Tasks 1–4.
- Produces: `standalone mods/ThermalVTK/ThermalVTK.vmz` and `mods/ThermalVTK/version.txt`.

- [ ] **Step 1: Write `pack.ps1`**

```powershell
param(
    [string]$OutFile = ""
)

$ErrorActionPreference = "Stop"

$src = $PSScriptRoot
if (-not $OutFile) {
    $OutFile = Join-Path $PSScriptRoot "ThermalVTK.vmz"
}

$modTxt = Join-Path $src "mod.txt"
if (Test-Path -LiteralPath $modTxt) {
    $ver = (Select-String -LiteralPath $modTxt -Pattern 'version\s*=\s*"([^"]+)"').Matches.Groups[1].Value
    if ($ver) {
        Write-Host "Version in mod.txt: $ver"
        $verFile = Join-Path $src "mods\ThermalVTK\version.txt"
        [System.IO.File]::WriteAllText($verFile, $ver + "`n", (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "  + mods/ThermalVTK/version.txt ($ver)"
        $readme = Join-Path $PSScriptRoot "README.md"
        if (Test-Path -LiteralPath $readme) {
            $rd = [System.IO.File]::ReadAllText($readme, [System.Text.Encoding]::UTF8)
            $rd2 = [regex]::Replace($rd, '(?m)^(\*\*[^*]+:\*\*\s*)[0-9][0-9a-zA-Z.\-]*', ('${1}' + $ver))
            if ($rd2 -ne $rd) {
                [System.IO.File]::WriteAllText($readme, $rd2, (New-Object System.Text.UTF8Encoding($false)))
                Write-Host "README version synced to $ver"
            }
        }
    }
    else { Write-Warning "mod.txt has no version field" }
} else {
    Write-Warning "mod.txt not found in $src"
}

$entries = @(Get-ChildItem -LiteralPath $src -Recurse -File |
    Where-Object { $_.Name -in @("mod.txt", "version.txt") -or $_.Extension -in @(".gd", ".tres", ".tscn", ".gdshader", ".webp", ".png") } |
    ForEach-Object { $_.FullName.Substring($src.Length).TrimStart([char[]]"\/") -replace "\\", "/" } |
    Sort-Object)

if ($entries.Count -eq 0) {
    throw "Nothing to pack in $src"
}

Add-Type -AssemblyName "System.IO.Compression"
Add-Type -AssemblyName "System.IO.Compression.FileSystem"

$tmpZip = Join-Path ([System.IO.Path]::GetTempPath()) ("thermalvtk_" + [guid]::NewGuid().ToString("N") + ".vmz")
$stream = [System.IO.File]::Create($tmpZip)
$zip = New-Object System.IO.Compression.ZipArchive($stream, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($en in $entries) {
        $srcPath = Join-Path $src ($en -replace "/", "\")
        Write-Host "  + $en"
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $srcPath, $en, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
}
finally {
    $zip.Dispose()
    $stream.Dispose()
}

if (Test-Path -LiteralPath $OutFile) {
    Remove-Item -LiteralPath $OutFile -Force
}
Move-Item -LiteralPath $tmpZip -Destination $OutFile -Force

$sizeKb = [math]::Round((Get-Item -LiteralPath $OutFile).Length / 1KB, 1)
Write-Host ""
Write-Host "Pack done: $OutFile ($($entries.Count) entries, $sizeKb KB)"
```

- [ ] **Step 2: Write `README.md`**

````markdown
# ThermalVTK

**Version:** 1.0.0

Standalone NVG / thermal-vision mod for Road to Vostok. It is the thermal
feature of Vostok Toolkit, packaged on its own.

> **Do not run this together with Vostok Toolkit.** Both mods patch the same
> in-game NVG material and will fight over it. Install one or the other.

## What it does

- Replaces the vanilla NVG overlay shader with an adjustable one (noise,
  brightness).
- Adds a thermal layer on top of NVG: bounty bots glow with a heat signature
  that cools after death, mines light up, and friendly Nomads get a floating
  marker.
- World palettes, bot colour presets, glow distance, and winter auto-dimming.
- A hotkey to turn the thermal layer on and off, with an on-screen
  notification.

## Install

1. Copy `ThermalVTK.vmz` into the game's `mods` folder.
2. Make sure Mod Configuration Menu is installed.
3. Open the MCM menu, set `ThermalVTK` up (bind the toggle hotkey there).

## Build (from the repo)

```powershell
powershell -ExecutionPolicy Bypass -File pack.ps1
```
````

- [ ] **Step 3: Write `CHANGELOG.md`**

```markdown
# Changelog

## [1.0.0] - 2026-10-14

### Added
- Standalone thermal vision (NVG) release: bot heat glow, mine highlighting, friendly Nomad marker, world palettes and winter auto-dimming.
- Hotkey to toggle thermal vision, with an on-screen notification.
```

- [ ] **Step 4: Build the artifact**

Run: `powershell -ExecutionPolicy Bypass -File "standalone mods\ThermalVTK\pack.ps1"` (workdir `D:\RTVMOD`)
Expected: prints `Version in mod.txt: 1.0.0`, lists `+ mod.txt`, `+ mods/ThermalVTK/*.gd`, `+ mods/ThermalVTK/*.gdshader`, `+ mods/ThermalVTK/version.txt`, and `Pack done: ...ThermalVTK.vmz (...)`.

- [ ] **Step 5: Inspect the archive contents**

Run: `Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::OpenRead("D:\RTVMOD\standalone mods\ThermalVTK\ThermalVTK.vmz").Entries.FullName`
Expected entries: `mod.txt`, `mods/ThermalVTK/ThermalVTK.gd`, `mods/ThermalVTK/VTKNVG.gd`, `mods/ThermalVTK/VTKPaths.gd`, `mods/ThermalVTK/VTKNVG.gdshader`, `mods/ThermalVTK/VTKBot.gdshader`, `mods/ThermalVTK/version.txt`. No `pack.ps1`, no `README.md`, no `CHANGELOG.md`.

- [ ] **Step 6: Confirm `version.txt` content**

Run: `Get-Content "D:\RTVMOD\standalone mods\ThermalVTK\mods\ThermalVTK\version.txt"`
Expected: `1.0.0`

- [ ] **Step 7: Commit**

```powershell
git -C "D:\RTVMOD" add "standalone mods/ThermalVTK/pack.ps1" "standalone mods/ThermalVTK/README.md" "standalone mods/ThermalVTK/CHANGELOG.md" "standalone mods/ThermalVTK/mods/ThermalVTK/version.txt"
git -C "D:\RTVMOD" commit -m "chore(thermalvtk): add build script, README and changelog"
```

---

## Manual acceptance (after Task 5)

Performed by a human in-game, once, with Vostok Toolkit removed:

1. Copy `ThermalVTK.vmz` to `D:\SteamLibrary\steamapps\common\Road to Vostok\mods`.
2. Enable it; open MCM and confirm the `ThermalVTK` category shows all settings.
3. Put NVG on: the green view still works and noise matches the setting.
4. Enable Thermal vision: bots glow and cool after death, mines light up,
   friendly Nomads get the marker, winter dimming and palettes apply.
5. Bind the hotkey and press it in game: toast reads `Thermal vision: ON` /
   `Thermal vision: OFF`, the effect flips instantly, and the choice survives a
   restart.
6. Check the game log for absence of `ThermalVTK` / `VTKNVG` errors.
