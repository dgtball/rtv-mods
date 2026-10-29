# ThermalVTK 1.7.1 — contour colour contract fix, marker, presets, see-through-walls removal

Date: 2026-10-21
Status: approved (design), pending implementation plan
Base: `5749e89` (release 1.7.0)

## Summary

In-game verification of 1.7.0 found four defects rooted in one design flaw: the contour pipeline is a **key → substitute** contract (the mod paints a world-space pixel, the NVG overlay detects a pixel near a "key" colour and swaps in the NPC's state display colour; every non-key pixel is re-coloured by the luminance-driven false-colour ramp, whose hot end is white). The body fill and the nomad marker were never brought onto that contract, so the overlay mis-colours them. 1.7.1 puts both onto the contract, removes the "See through walls" setting (which also removes a solid-shell artefact), fixes the F6 toast, and turns "Outline style" into a fill preset.

Target release: **1.7.1** (patch).

## Root causes (from code investigation)

1. **Fill goes white above ~0.05 opacity.** `VTKESP._opts_for` gives the body the *display* colour (`"fill_color": _state_color(cat)`, `VTKESP.gd:440`), which the overlay does not detect as a key (measured distances 0.06–0.52 to the nearest detector key; tolerance is 0.22). The fill pixels therefore fall through to `ThermalPalette(luminance)`; raising opacity lifts pixel luminance up the ramp to the white band (`VTKNVG.gdshader:82-88,131-133,147`). The combat display colour `(0.95,0.18,0.15)` is within 0.059 of `stNormalKey (1.00,0.21,0.16)`, so a combat NPC can additionally be mis-labelled as normal.
2. **"Front-faces" renders back faces.** `VTKShaders.gd:29-32` rewrites `cull_back`→`cull_front` for style 0, so back-face normals point away, `rim01` saturates, the rim `smoothstep`/`discard` never fires, and `Outline rim` is dead in the default style. The through-walls variant (depth-test disabled) additionally paints a solid shell over the whole body, hiding the fill.
3. **Nomad marker renders red.** The marker is a plain world-space `Label3D` (`VTKESP.gd:341-351`) with `modulate = Color(0.30,1.0,0.35)`. It is only visible with thermal on, so it always passes through the thermal branch; green is not near any key (distances 0.83–1.23) and is re-coloured by the ramp (classic palette red band), so the green never reaches the screen. (`outline_modulate` default is black, not red — the "red outline" hypothesis is disproved; the built-in font also lacks U+25C6.)
4. **F6 toast fires with thermal off.** `_cycle_palette()` (`ThermalVTK.gd:70-76`) has no state guard; the only check is "NVG node exists".

## Design

### 1. Colour contract (foundation)

Everything the mod draws in world space must paint a **pure key colour** so the overlay detects it; the overlay decides the final colour and density.

Key set:
- `KEY_NORMAL`, `KEY_COMBAT`, `KEY_DEFEND` — outline (existing).
- **`KEY_FILL_NORMAL`, `KEY_FILL_COMBAT`, `KEY_FILL_DEFEND`** — body fill (new; symmetric to the outline so the overlay can give fill a different density and the fill carries state colour through its own channel).
- **`KEY_NOMAD`** — nomad marker (new).
- `mineKey` — unchanged.

All keys live in `VTKStates.gd`. Values chosen so no two keys (and no display colour) fall within the detector tolerance of each other — verify numerically at implementation time.

### 2. Body fill (mechanism A — density owned by the overlay)

- `VTKOutlineBody.gdshader`: paint a single `fill_key: vec3` uniform at full alpha in world space. `VTKOutline` sets `fill_key` per frame to the category's `KEY_FILL_<state>` (same pattern as the ring's `state_key`). `fill_opacity` no longer scales world-space alpha; the fill must be opaque enough to be detected.
- `VTKNVG.gdshader`: add detectors `dFillN/dFillC/dFillD` and `dNomad` to the "closest key wins" min (`VTKNVG.gdshader:124-128`). On a fill key, output `mix(backgroundColor, stateColor, fillOpacity)` where `fillOpacity` is a new uniform fed from the MCM "Fill opacity" slider. On a nomad key, output the green display colour.
- `VTKNVG.gd`: feed `fillOpacity`, the three fill keys, the three fill detection results and `nomadColor` as uniforms; add setters.
- `VTKOutline.gd`: push fill-key instead of display colour; stop multiplying world-space `fill_alpha` by opacity.

### 3. Outline / Front-faces rim fix

- Keep the two ring variants: front (`cull_front`) and back (`cull_back`). Make `rim_start`/`rim_end` produce a working visible edge band in the **front** variant (the desired clean silhouette), instead of the current dead branch. The back variant keeps the inflated look with `rim_power`.
- The exact rim math is an implementation detail, but the **acceptance criterion is fixed**: moving `Outline rim` from 0.0 to 1.0 must visibly change the front-face edge band width in-game.

### 4. Nomad marker

- Replace the `Label3D` with a small billboard **mesh** (diamond/quad) carrying a shader that emits `KEY_NOMAD`.
- Shown when thermal + NVG on **and** Contour ESP is on (user accepted dropping the "independent of Contour ESP" behaviour).
- **Not** drawn through walls (depth-tested like the outline; the user accepted this).
- Green is guaranteed by the overlay's nomad-key substitution.

### 5. Remove "See through walls"

Delete the setting and all its wiring; outlines always line-of-sight:
- `ThermalVTK.gd`: remove MCM key `outline_through_walls`; remove `_esp.p_through` assignment.
- `VTKESP.gd`: remove `var p_through`; remove the `"through_walls"` opt.
- `VTKOutline.gd`: `_build_chain(front_faces)`, drop `wall` from `_items`/`_set_variants`, drop `wall` opt read.
- `VTKShaders.gd`: body variants 2→1 (`body()`), ring 4→2 (`ring(front_faces)`), delete `strip_depth_test` and the LOS/wall variant construction.
- Remove `depth_test_disabled` from both outline shaders.
- `_sync_config` auto-drops the stale key from user configs; no migration.

### 6. F6 toast

- `ThermalVTK._cycle_palette()`: early `return` when `not _thermal_enabled` (full no-op — no cycle, no persist, no toast). The thermal toggle toast is untouched.

### 7. Outline-style presets

Selecting "Outline style" auto-sets the fill settings; the individual sliders remain as overrides:
- **Front-faces** → `Fill body = ON`, `Fill opacity = 0.05` (Flat, the only fill style now).
- **Back-faces** → `Fill body = OFF`.
- Applied in `ThermalVTK._mcm_apply` with a change-guard against the last applied style (persisted in the mod state file beside `world_palette`), so it fires only on a real dropdown change, not on every MCM tweak.

### 8. Remove Gradient fill style

Drop `fill_style` (Gradient) — Flat only. Removes the `fill_style` uniform/MCM key and the gradient branch in `VTKOutlineBody.gdshader`. `warmColor`/`coldColor` uniforms go too.

## MCM surface after 1.7.1

- Removed: `outline_through_walls`, `fill_style`.
- `outline_style` now also drives the fill preset.
- Kept: `outline_rim`, `fill_opacity`, `outline_body_fill`, colours (3), outline distance/thickness/brightness, corpse cooling, debug log, thermal/NVG keys.

## Tests to update

- `test_shaders.gd`: drop `t_strip_depth_test`; rewrite `t_shaders_compile` for `body()`/`ring(front_faces)` (no wall variant); add a compile check for the name/fill keys.
- `test_outline.gd`: fill is now key-based (not display colour, not `fill_alpha * opacity`); remove `fill_style`/`warmColor`/`coldColor` assertions.
- `test_esp.gd`: marker is a mesh emitting `KEY_NOMAD` (not `Label3D.modulate`); opts no longer carry `through_walls`; fill opts carry a fill key.
- `test_states.gd`: assert the new keys (`KEY_FILL_*`, `KEY_NOMAD`) and their separation from one another and from the display colours.

## Changelog (player-visible, English)

Draft at implementation: fixes ("body fill now shows the NPC's state colour at any opacity"; "friendly nomad marker is green again"), changes ("removed See through walls"; "the contour outline style now sets a matching body-fill preset"; "F6 only works with thermal vision on"), removed ("gradient fill option").

## Out of scope

- Anything LooterShooter.
- Whole-branch refactors; per-task deferred minors from 1.7.0 (label/marker duplication, dropdown string-compare, etc.) unless a fix touches them.
- Exact game-space appearance outside headless verification — the in-game pass is the user's.

## Open items resolved into decisions

- Fill mechanism: **A** (overlay owns density).
- Fill-key channel: **three fill keys per state**.
- Nomad marker: **mesh + KEY_NOMAD**, not through walls, not independent of Contour ESP.
- Rim: **fixed for Front**.
- Gradient: **removed**.
- F6: **full no-op when thermal off**.
- Version: **1.7.1**.
