# Smooth Seasonal Transition Design

Status: draft
Date: 2026-10-17

## Goal
Make the seasonal tint change (tree/grass `tint` shader parameter + air tint) fade
over a fixed real-time duration instead of snapping when the Dynamic season changes.
This mirrors vanilla's smooth snow melt, which is the reference look the user asked
to replicate.

## Background
- Vanilla exposes a global shader uniform `Snow` (every snow shader declares
  `global uniform float Snow;`). The vanilla `World` script eases it, producing a
  smooth winter<->summer snow fade. Neither SES nor VTK writes `Snow`; VTK only sets
  `Simulation.season`. SES confirms this in a comment: "vanilla owns Snow via
  winterValue chain".
- VTK 5.1.0 recolours shared tree/grass materials via their `tint` shader parameter
  and tints air via `ambient_light_color` / sun `light_color`. These are set
  instantly on a season change, so they pop next to the eased snow.

## Decisions
- Mechanism: time-based crossfade in the driver, not tied to the `Snow` global.
- Duration: a single hardcoded constant `TRANSITION_SECS = 8.0` (no MCM setting).
  A value of 0 means instant.
- The first application of a run (`_last_index < 0`) is instant - no fade at load.
- Driven from `VTKHooks._process(delta)` while `_dyn_enabled`; it only advances while
  a transition is active, so cost is near zero otherwise.
- Restore on disable (non-dynamic run / mod off) stays instant.
- No change to snow handling; vanilla keeps owning `Snow`.

## Architecture
- `VTKSeasonDriver.gd` (RefCounted) gains:
  - state: `_active: bool`, `_t: float`, and the from/to values per target.
  - `tick(delta: float) -> void`: if active, advance `_t += delta / TRANSITION_SECS`,
    write the interpolated values, and at `_t >= 1` snap to the target and clear.
  - `set_season(index, is_dynamic_run, visuals)` refactored: compute the target tint
    set; if `_last_index < 0` (or `TRANSITION_SECS == 0`) apply instantly, otherwise
    begin a crossfade from the currently applied values.
  - `on_world_ready()`: re-bind air; if a transition is active, write the current
    interpolated value so the fresh scene matches.
- `VTKSeasons.gd` (pure) gains `blend(a: Color, b: Color, t: float) -> Color`
  (clamped linear interpolation) - headless-testable.
- `VTKHooks.gd`: `_process` calls `_season_driver.tick(_delta)` when `_dyn_enabled`
  and the driver exists (its `_delta` is currently unused).

## Targets
- tree materials: `uses_tint(index) ? tree_tint(index) : entry.orig` (per material,
  so winter fades back to the vanilla green).
- grass materials: analogous with `grass_tint`.
- air: `_tint_color(vanilla, air_tint(index), AIR_STRENGTH)` for all four seasons
  (the air tint exists for winter too).

## Data flow
1. Season boundary detected in `_season_apply` (index change).
2. `set_season` captures the currently applied colours (`from`) and computes the
   targets (`to`); first apply -> instant, otherwise `_active = true`, `_t = 0`.
3. Each frame `tick(delta)` writes `blend(from, to, _t)` to materials and air; at the
   end it snaps to the target and clears.
4. Map reload -> `on_world_ready()` rebinds air and writes the current value.

## Files
- loadouts/mods/VTK/VTKSeasonDriver.gd (transition state + tick; refactor
  set_season / _apply_tint / _restore_foliage)
- loadouts/mods/VTK/VTKSeasons.gd (blend helper)
- loadouts/mods/VTK/VTKHooks.gd (tick call in _process)
- .check/project/tests/test_seasons.gd (blend tests)
- loadouts/mod.txt (version 5.1.1)
- CHANGELOG.md (5.1.1 entry)

## Testing
- Headless: `blend` endpoints and clamping (t=0 -> a, t=1 -> b, outside [0,1] clamps).
- Stands: layout_check.py and check.ps1 (15/15) green.
- Manual in-game: lower cycle_days, watch a season change and confirm the tint eases
  over ~8 s and winter fades back to green without a pop; confirm the tint survives a
  map transition.

## Open
- The exact vanilla snow-ease duration is unknown (World.gdc is tokenized; no
  readable constant). 8.0 s is a starting point; adjust the constant if it visibly
  mismatches.
- Whether vanilla eases `Snow` from `Simulation.season` or from `World.winterValue`
  is unverified. VTK does not write `winterValue`, and snow was observed to change on
  a season flip, so nothing here is changed for snow.
