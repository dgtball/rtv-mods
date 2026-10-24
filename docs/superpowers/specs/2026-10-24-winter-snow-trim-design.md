# Winter snow trim for the thermal background

Date: 2026-10-24 · Mod: ThermalVTK · Size: small change

## Intent and why

Winter night evidence (Meд field probes, 2026-10-24, build 1.17.2): the whole
winter frame lands in the hot third of the Classic palette — dark dirt
probe (0.306,0.380,0.439) → lum 0.365 → t 0.62 (red), bright snow
(0.471,0.580,0.682) → lum 0.559 → t 0.95 (cream); a mid bright patch
(0.365,0.443,0.514) → t 0.73 (amber). Even shadows read red: the field has
no cold colors left — the winter-sort of oversaturation the partner calls
"лава". Winter day pins snow at t = 1.0 (post-comp probe 0.82) with no
headroom. Root cause: snow bounces far more amplified NVG light than any
summer surface, and the fixed `thermalDarken 1.7` maps that whole band into
the red-to-cream third. Pre-exists the 1.17.2 palette fix (that fix is the
correct-monotonic ladder; it is not the cause).

## Goals

- Winter (season 2), outdoor: the background re-spreads down the ladder —
  night dirt ≈ t 0.37 (purple), bright patches ≈ t 0.44, snow ≈ t 0.57
  (amber); day snow gets headroom off the t = 1.0 ceiling.
- Keys, mines, nomad: untouched (substitution happens before the palette;
  the trim is background-only).
- Summer, fog, caves, interiors: byte-identical behavior (trim = 1.0).
- Rides the existing `Daylight compensation` MCM switch: comp off →
  trim off (1.0), restored on the same path that restores exposure.

## Non-goals / anti-goals

- No «physically cold snow» (dark-blue ice): the pipeline reads the
  amplified frame's luminance; per-pixel temperature does not exist. Snow
  stays the brightest object; it just stops eating the whole palette.
- No AGC, no new MCM keys, no shader structure change.

## Approach

One static in `VTKDaylight` + one multiplier at the uniform write:

- `VTKDaylight.snow_trim(season, indoor, shelter, light) -> float`:
  1.0 unless (season == 2 and not indoor and not shelter);
  otherwise `lerp(SNOW_TRIM_NIGHT, SNOW_TRIM_DAY, light)`.
- Constants fit the probes: `SNOW_TRIM_NIGHT = 0.60` (dirt 0.365×1.7×0.6
  = t 0.37), `SNOW_TRIM_DAY = 0.80` (snow off the ceiling).
- `VTKNVG.gd`: member `_snow_trim` (default 1.0), computed in
  `_daylight_tick` from the same sim values the light level already reads;
  `_apply_uniforms` writes `thermalDarken = set_world * _snow_trim`;
  `_reset_daylight` sets `_snow_trim` back to 1.0 (toggle off / map change
  restore through the existing cadence push).
- In-game confirmation once, ±0.05 tuning if the seam reads too flat.

## Verification

1. grep: the only new hot-path references are `snow_trim` in VTKDaylight
   and the `_snow_trim` member in VTKNVG.gd; no DET_*/key changes.
2. `pack.ps1` clean; deploy to the game mods dir.
3. Partner in game, Minefield winter night: dirt/shadow no longer red
   (purple), bright snow amber, ladder ordered; winter day: snow keeps
   texture with headroom; summer day/night unchanged; keys unchanged.

## What's left to the builder

Exact constant placement/comment wording, member update cadence (change of
>0.001 like the day-mix path), CHANGELOG wording, version bump 1.17.2 →
1.17.3.
