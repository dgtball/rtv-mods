# Winter Snow Trim Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Winter snow frames stop eating the hot third of the thermal palette: a season-2-only multiplier on the effective `thermalDarken` re-spreads the background down the ladder (night dirt → purple, snow → amber), keyed off the measured probes.

**Architecture:** One pure static (`VTKDaylight.snow_trim`) computes the trim from data `_daylight_tick` already gathers; `VTKNVG.gd` stores `_snow_trim`, `_apply_uniforms` multiplies the user's `thermalDarken` by it, `_reset_daylight` restores 1.0. No shader change, no MCM key, no exposure change.

**Tech Stack:** GDScript (Godot 4.6.3, tabs), PowerShell pack, git.

**Spec:** `docs/superpowers/specs/2026-10-24-winter-snow-trim-design.md`

## Global Constraints

- Tabs; factual English comments; comments may mention measured numbers (probe table is in the spec).
- No DET_*/KEY_*/MINE_KEY changes; no shader file changes; no new MCM keys; no exposure-model change.
- Constants exactly: `SNOW_TRIM_NIGHT = 0.60`, `SNOW_TRIM_DAY = 0.80`; condition `season == 2 and not indoor and not shelter`; blend `lerp(NIGHT, DAY, light)`.
- Version 1.17.2 → 1.17.3 (patch, new player-visible fix), single source `mod.txt`; CHANGELOG top entry under `# Changelog`; deploy `D:\SteamLibrary\steamapps\common\Road to Vostok\mods\ThermalVTK.vmz`.
- `docs/` gitignored → stage with `git add -f`.

## Review Focus

No automated stand; gates = reading the diff + pack + partner's in-game session. Failure classes, most likely first:

1. **Trim never updates** — `_daylight_tick` computes it but the uniform write stays `set_world` only, or the change-detection threshold kills sub-0.001 updates. Expected: `_apply_uniforms` writes `set_world * _snow_trim` and the tick commits the new trim through an `_apply_uniforms()` call when it moves. → Task 1 grep + Task 3 in-game delta.
2. **Trim leaks into non-winter scenes** — condition inverted or `light` misread so summer gets trimmed. Expected: `snow_trim` returns exactly 1.0 unless season == 2, outdoor. → Task 1 headless value probe + Task 3 summer check.
3. **Toggle/map-change leak** — comp switched off mid-winter leaves the last trimmed value painted. Expected: `_reset_daylight` resets `_snow_trim = 1.0`; `_restore_exposure` path re-pushes via `apply_config`'s `_apply_uniforms()`. → Task 1 code read + partner toggle-off check.
4. **Keys tuned instead of background** — any edit touching `_key_set`/key constants would invalidate the day/night anchors. Expected: diff touches only trim plumbing. → Task 1 diff audit.
5. **stale CHANGELOG/version mismatch** — README/version.txt/mod.txt/CHANGELOG all 1.17.3 after pack. → Task 2 verification.

---

### Task 1: Snow trim plumbing

**Files:**
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKDaylight.gd` (constants + `snow_trim`)
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKNVG.gd` (member, tick, uniform write, reset)

**Interfaces:**
- Consumes: `Daylight.day_mix`-style helpers pattern; `_sim_value("season", 1)` / `_game_flag("indoor")` / `_game_flag("shelter")` (already used by the `light_level` call).
- Produces: `_snow_trim: float` member; thermalDarken uniform = `set_world * _snow_trim`; `Daylight.snow_trim(season: int, indoor: bool, shelter: bool, light: float) -> float`.

- [ ] **Step 1: `VTKDaylight.gd`** — constants `SNOW_TRIM_DAY := 0.80`, `SNOW_TRIM_NIGHT := 0.60` next to the existing ones, plus:

```gdscript
static func snow_trim(season: int, indoor: bool, shelter: bool, light: float) -> float:
```

Body: 1.0 unless `season == 2 and not indoor and not shelter`; else `lerpf(SNOW_TRIM_NIGHT, SNOW_TRIM_DAY, clampf(light, 0.0, 1.0))`. Comment cites the probe numbers (dirt t 0.62 → 0.37 at 0.60).

- [ ] **Step 2: `VTKNVG.gd`** — member `var _snow_trim: float = 1.0` near the daylight members; in `_daylight_tick` after `light` is computed:

```gdscript
var trim: float = Daylight.snow_trim(int(_sim_value("season", 1)), _game_flag("indoor"), _game_flag("shelter"), light)
```

commit it like the day-mix path: if `absf(trim - _snow_trim) > 0.001:` → `_snow_trim = trim` and `_apply_uniforms()`.

- [ ] **Step 3: `VTKNVG.gd`** — `_apply_uniforms` line for thermalDarken becomes `set_world * _snow_trim`; `_reset_daylight` sets `_snow_trim = 1.0` (the cadence push repaints; `apply_config`'s `_apply_uniforms()` covers the toggle-off path).

- [ ] **Step 4: Verify**

grep `snow_trim` (2 files) and `set_world \* _snow_trim` (1 hit at the uniform write); diff audit: zero changes touching keys/materials/shaders. Headless value probe if convenient (Godot not required — recompute by hand and note in the ledger): dirt 0.365→0.37 t at night, snow 0.559→0.57.

- [ ] **Step 5: Commit**

```bash
git add "standalone mods/ThermalVTK/mods/ThermalVTK/VTKDaylight.gd" "standalone mods/ThermalVTK/mods/ThermalVTK/VTKNVG.gd"
git commit -m "ThermalVTK 1.17.3: winter snow trim re-spreads the thermal background"
```

### Task 2: Version, CHANGELOG, pack, deploy

**Files:**
- Modify: `standalone mods/ThermalVTK/mod.txt`, `standalone mods/ThermalVTK/CHANGELOG.md`
- Build: `pack.ps1` → deploy

**Interfaces:**
- Consumes: Task 1 commit. Produces: release 1.17.3 deployed.

- [ ] **Step 1: `mod.txt`** `version="1.17.3"`.

- [ ] **Step 2: CHANGELOG top entry**

```markdown
## [1.17.3] - 2026-10-24

### Fixed
- Winter backgrounds no longer flood the thermal picture in red and cream: snowy scenes spread across the full palette again, so shadows read cold and only the brightest snow reads hot, both day and night.
```

- [ ] **Step 3: Pack and deploy**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File "standalone mods\ThermalVTK\pack.ps1" -OutFile "D:\SteamLibrary\steamapps\common\Road to Vostok\mods\ThermalVTK.vmz"`
Expected: `Version in mod.txt: 1.17.3`, 21 entries, no errors. Sync commit for README/version.txt if the packer dirties them.

### Task 3: Partner in-game verification (gate)

**Files:** none — playtest.

- [ ] **Step 1:** Minefield winter night — dirt/shadow purple, bright patch mid, snow amber; no red lava field.
- [ ] **Step 2:** Minefield winter day — snow keeps texture, no longer pinned cream (headroom visible).
- [ ] **Step 3:** Summer day + night unchanged; fog day unchanged (1.17.2 behavior).
- [ ] **Step 4:** Keys sweep from 1.17.2 (still pending): rings/mine/nomad as in 1.17.1; toggle Daylight compensation off mid-winter → trim releases immediately.
- [ ] **Step 5:** FAIL → constants ±0.05 (night first), repeat pack/deploy, re-verify. PASS → merge to main, delete branch.
