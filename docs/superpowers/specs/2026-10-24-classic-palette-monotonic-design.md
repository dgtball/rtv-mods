# Classic thermal palette: restore heat = brightness order

Date: 2026-10-24 · Mod: ThermalVTK · Size: small change

## Intent and why

In a foggy midday frame the whole world is compressed into a narrow
luminance band that maps onto palette stops 0.25–0.5. The Classic palette
has a luminance **inversion** exactly there: its cold stop c1
(purple 0.30,0.12,0.45) measures brighter on screen (lum 0.211) than its
hot stop c2 (red 0.55,0,0.08, lum 0.174). The player therefore sees
"warmer = darker" across that seam: violet lawn with darker red veins
(fog.jpg / classic.jpg, 2026-10-24), flat unreadable mass, contradictory
depth cues. All three other palettes (Amber, Forest, Ice) are monotonic
in luminance; the same seconds-apart Ice frame (ice.jpg) stays readable.

## Goals

- Classic fog/midday and any narrow-band scene reads with a strict
  heat→brightness order across the c1→c2 seam.
- Keep the hue identity: cold = muted blue-purple, medium = red,
  hot = amber, hottest = white-cream. No change to key colors, detectors,
  display colors, MCM settings.
- No change to Amber/Forest/Ice stops.

## Non-goals / anti-goals

- No AGC, no daylight-model change, no shader structural work. (AGC
  remains a separate future idea for too-dark scenes.)
- No palette "language" redesign: hues stay recognizable.

## Constraints

- Edits confined to the Classic branch (`else`) of `ThermalPalette` in
  `standalone mods/ThermalVTK/mods/ThermalVTK/VTKNVG.gdshader`.
- Detector keys are substituted before the palette; this change cannot
  touch any DET_* orbit (verified in shader layout: substitution happens
  at `dCore < DET_TOL_CORE` before `ThermalPalette(luminance)`).
- Discipline of this mod: comments factual, tabs for indent, pack with
  `pack.ps1`, version lives in `mod.txt`.

## Approach (the one sensible way)

Reorder stop *values* so luminance is monotonic, keeping hues:

- c1 `vec3(0.30, 0.12, 0.45)` → `vec3(0.24, 0.10, 0.38)`
  (lum 0.211 → 0.174): the cold stop keeps its purple cast but stops
  outshining the hot step.
- c2 `vec3(0.55, 0.0, 0.08)` → `vec3(0.65, 0.0, 0.10)`
  (lum 0.174 → 0.206): the red stop gains the missing bit of heat.

Resulting ladder: 0.003 → 0.174 → 0.206 → 0.651 → 0.977, all ascending;
the seam margin is ~0.032 (c1→c2). Wide steps c0→c1 and c2→c3 stay as
they were. Values need one in-game confirmation pass; if the fog image
still looks flat or night midtones suffer, adjust c1 darker / c2 lighter
by ±0.02 within the same shapes.

## Verification

1. `pack.ps1` clean, no new files.
2. In game (partner): foggy midday Scene "Outpost (Area 05)" — Classic
   vs Ice comparison pair, same as the screenshots: faint warm spots on
   the lawn must now read *brighter* than the cold ground; violet→red
   must ascend. Night check: cold night frame should read as dark
   purple, still distinct from black. Bots/rings/mines/nomad reading as
   before (colors unchanged — does not touch detector paths).
3. Version bump 1.17.1 → 1.17.2 (patch), CHANGELOG entry (player-visible
   wording), pack + deploy to the game mods dir.

## What's left to the builder

Exact final values within the shapes above, comment lines in the shader,
CHANGELOG wording, version/deploy mechanics.
