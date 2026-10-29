# ThermalVTK — standalone NVG/thermal mod (design)

Date: 2026-10-14

## Goal

Ship the NVG/thermal-vision feature of Vostok Toolkit as a separate,
self-contained mod that can be handed to players who do not want the full
toolkit. Same player-facing behaviour for the thermal layer, plus one new
feature: a hotkey that toggles thermal vision with an on-screen notification.

## Identity / namespace

Everything uses the **ThermalVTK** brand:

| Item | Value |
|---|---|
| Standalone project folder | `standalone mods/ThermalVTK/` (renamed from `ThermalV`) |
| `mod.txt` name | `ThermalVTK` |
| `mod.txt` id | `thermal-vtk` |
| Script folder in the pack | `res://mods/ThermalVTK/` |
| Autoload name/script | `ThermalVTK` / `res://mods/ThermalVTK/ThermalVTK.gd` |
| MCM config | `user://MCM/thermal-vtk/config.ini` |
| Build artifact | `ThermalVTK.vmz` |

`res://mods/ThermalVTK/` does not collide with the toolkit's
`res://mods/VTK/`, but both mods patch the same NVG `ShaderMaterial`. The
standalone does **not** coordinate with the toolkit; `README.md` states plainly
that the two must not be installed together.

## Scope

Ported (unchanged behaviour):

- Replace the vanilla NVG `ShaderMaterial` with the mod's own shader on the
  `NVG` node's `Overlay`/child (custom noise, brightness).
- Thermal layer: bot heat glow with corpse cooling, mine highlighting, friendly
  Nomad marker, winter auto-dimming, world palette, bot colour preset, glow
  distance.
- MCM category exposing all of the above.

Explicitly **not** ported:

- Loadouts/sets, teleport, kill feed/counter, task deposits, Picker/Draft UI.
- Localisation (English only; missing translations are irrelevant because keys
  are English strings).
- Debug tooling: probe log, F4 detection overlay, `user://...debug.log`.
- Game hooks (`[hooks]`) — the NVG layer needs none.

## Files

```
standalone mods/ThermalVTK/
  mod.txt                      name/id/version, autoload, optional MCM dep
  README.md                    install + "do not run with Vostok Toolkit"
  CHANGELOG.md                 1.0.0 entry
  pack.ps1                     builds ThermalVTK.vmz
  mods/ThermalVTK/
    ThermalVTK.gd              autoload: MCM, config, hotkey, notification
    VTKNVG.gd                  ported, probe code removed
    VTKNVG.gdshader            `debugDetect` uniform + branch removed
    VTKBot.gdshader            unchanged
    VTKPaths.gd                trimmed to NVG, GAME_DATA, LOADER
    version.txt                written by pack.ps1
```

File names keep the `VTK` prefix because the code is a straight port and the
in-code comments reference `VTKNVG`/`VTKBot` by name; renaming would only add
churn. This is a naming detail that can be revisited later.

### `mod.txt`

```
[mod]
name="ThermalVTK"
id="thermal-vtk"
version="1.0.0"

[autoload]
ThermalVTK="res://mods/ThermalVTK/ThermalVTK.gd"

[dependencies]
optional=["mod_configuration_menu"]
```

## `ThermalVTK.gd` (autoload)

Replaces the toolkit's `VTKUI` role for this one feature.

- `_ready()` → `_register_mcm()` then `_ensure_nvg()`. The NVG node is created
  even without MCM, with defaults (thermal off, custom NVG noise) so the shader
  swap still works.
- `_ensure_nvg()` lazily instantiates `res://mods/ThermalVTK/VTKNVG.gd` as a
  child.
- `_register_mcm()` mirrors the toolkit: `RegisterConfiguration("thermal-vtk",
  "ThermalVTK", "user://MCM/thermal-vtk", "NVG thermal overlay: bot, mine and
  Nomad highlighting", _mcm_apply, self)`, config synced **by keys** (stale keys
  removed, existing user values preserved, `Info` overwritten), `Info/version`
  from `res://mods/ThermalVTK/version.txt`.
- `_mcm_apply(cfg)` reads settings and pushes them onto the NVG node via the
  existing setters (`set_thermal_enabled`, `set_mines_enabled`, and the public
  `set_*` fields).
- Hotkey: `_unhandled_input` compares the pressed key against
  `key_thermal_toggle` (`keycode`/`physical_keycode`), the same comparison the
  toolkit's "Toggle UI" hotkey uses. Pressed → `_toggle_thermal()`.

MCM keys, category `01. ThermalVision`, in order:

| menu_pos | section | key | name |
|---|---|---|---|
| 0 | Keycode | `key_thermal_toggle` | Hotkey: Toggle thermal vision (default 0 = unbound) |
| 1 | Float | `nvg_noise` | NVG noise |
| 2 | Float | `nvg_white` | NVG brightness |
| 3 | Bool | `thermal_enabled` | Thermal vision |
| 4 | Bool | `thermal_mines` | Mine highlighting |
| 5 | Bool | `thermal_mark_nomads` | Mark friendly Nomads |
| 6 | Bool | `thermal_winter_auto` | Winter auto-dimming |
| 7 | Float | `thermal_winter_dim` | Winter dimming |
| 8 | Int | `thermal_palette` | World palette |
| 9 | Float | `thermal_world` | World brightness |
| 10 | Int | `thermal_bot_preset` | Bot colour |
| 11 | Float | `thermal_far_distance` | Distance |

Plus `Info/version` and `Info/author`.

## Hotkey + notification

- Hotkey toggles the persisted setting `thermal_enabled`, not a session-only
  flag.
- `_toggle_thermal()`:
  1. flip `_thermal_enabled`;
  2. `_nvg.set_thermal_enabled(...)`;
  3. persist the new value into `user://MCM/thermal-vtk/config.ini` by updating
     the `Bool/thermal_enabled` dictionary's `"value"` (best effort; the file is
     MCM's own and is loaded again on next launch);
  4. notify via `loader.Message(text, color)` on `/root/Loader` — the same path
     the "Loadout … applied" toast uses.
- Wording: `Thermal vision: ON` (green) / `Thermal vision: OFF` (grey).
- Default hotkey is unbound (`0`); the player assigns it in MCM, matching the
  toolkit's "Toggle UI" default.

## `VTKNVG.gd` changes on port

Remove everything debug-only, keeping the thermal logic identical:

- drop `set_debug_probe`, `_debug_detect`, `apply_debug_probe`, `_unhandled_input`
  (F4), `_dbg*`, `_dbg_map`, `_dbg_open`, `DEBUG_LOG`, `DEBUG_MINES`,
  `_probe_pixels`, `_count_friendly`, `_log_trader`, `_describe`, `_mesh_paths`,
  `_mine_report`, `_dbg_summary_cd`, and the `Trader.gd` branch in
  `_scan_node`/`_deferred_check` (it only logged).
- `_apply_uniforms` no longer sets `debugDetect`.
- `_frame_pre_draw` keeps the re-assert logic; the clobber-report branch goes.
- All `_dbg(...)` call sites removed.

`VTKNVG.gdshader`: remove `uniform bool debugDetect` and the `if (debugDetect)`
branch.

`VTKPaths.gd`: keep only `NVG`, `GAME_DATA`, `LOADER`. No theme/font, no
interface/controller paths.

`VTKBot.gdshader`, `VTKNVG.gdshader` otherwise unchanged.

## Build

`pack.ps1` is a copy of the repo-root script, adjusted:

- `$src = $PSScriptRoot` (the standalone folder itself holds `mod.txt` + `mods/`);
- writes `mods/ThermalVTK/version.txt`;
- default output `ThermalVTK.vmz` in the standalone folder;
- packs `mod.txt`, `version.txt`, `*.gd`, `*.gdshader`.

`.gitignore`: add `!/standalone mods/` to the whitelist and ignore built
`*.vmz` inside it.

## Verification

- Extend `.check/check.ps1` to also copy
  `standalone mods/ThermalVTK/mods/ThermalVTK/*.gd` into the throwaway project
  under `mods/ThermalVTK/` and run `--check-only` per file (translated to
  `res://mods/ThermalVTK/...`). This catches parse/compile errors.
- No headless unit tests: the NVG layer is engine-coupled (scene signals,
  `RenderingServer`, shaders). In-game checks stay manual.
- Green means all three, as for the toolkit: no `SCRIPT ERROR` / `Parse Error` /
  `Invalid call` / `Failed to load script`, and exit code 0.

## Manual acceptance

1. Install `ThermalVTK.vmz` alone (toolkit removed).
2. Put NVG on: vanilla green view keeps working, noise matches the setting.
3. Enable Thermal vision in MCM: bots glow and cool after death, mines light
   up, friendly Nomads get the marker, winter dimming and palettes apply.
4. Bind the hotkey, press it in game: toast `Thermal vision: ON`/`OFF`, effect
   flips immediately, and the choice survives a restart.
5. Confirm no `ThermalVTK`/`VTKNVG` errors in the game log.
