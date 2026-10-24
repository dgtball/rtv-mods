# Classic Palette Monotonic Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Classic thermal palette's luminance ladder monotonic (heat = brighter) so fog-compressed frames stop reading "warmer = darker".

**Architecture:** Two stop-value edits in the Classic (`else`) branch of `ThermalPalette` in `VTKNVG.gdshader`, plus a factual comment. No detector, display color, MCM, or other-palette change. Release mechanics: version bump + CHANGELOG + pack + deploy, then partner's in-game verification.

**Tech Stack:** Godot 4.6.3 shader (`VTKNVG.gdshader`), PowerShell (`pack.ps1`), git.

**Spec:** `docs/superpowers/specs/2026-10-24-classic-palette-monotonic-design.md`

## Global Constraints

- Tabs for indentation; shader comments factual, English, no game-path promises.
- No change to Amber/Forest/Ice stops (`worldPaletteMode` 1/2/3), no change to any `*Key`/`*Color` uniform, `thermalDarken`, `dayMix`, `highlightKnee`.
- Execute discipline: raw shells measure nothing here; no HID/probe changes.
- Version lives only in `standalone mods/ThermalVTK/mod.txt` field `version`; current 1.17.1 → 1.17.2.
- CHANGELOG = player-visible effect, Keep a Changelog, English, tops the file under `# Changelog`.
- Deploy target: `D:\SteamLibrary\steamapps\common\Road to Vostok\mods\ThermalVTK.vmz`.
- `docs/` is gitignored: stage spec/plan files with `git add -f`.

## Review Focus

The mod has no automated test stand; verification = grep/pack + partner's in-game session. Classes the plan's checks cannot pin, most likely first:

1. **Shader vector typo / stray character** in the Classic branch — whole shader fails to compile on load and the thermal picture may not appear at all. Expected: exact `vec3(0.24, 0.10, 0.38)` / `vec3(0.65, 0.0, 0.10)` literals, balanced parens. → Task 1 grep step + Task 3 first in-game look.
2. **Edit lands in the wrong palette branch** (modes 1–3 get the values instead of the `else` Classic branch) — all palettes shift at once. Expected: only the `else` (Classic) branch holds the new literals; Amber/Forest/Ice lines byte-identical to before. → Task 1 verification (`git diff` shows exactly 2 changed stop lines within the `else` block) + Task 3 palette A/B.
3. **Night readability regression** from the darker c1 — cold night ground should stay distinguishable from black, not crush together. Expected: night lawn slightly dark purple, still visually
distinct from c0 black. → Task 3 night check (partner decides acceptable, tuning is ±0.02 on the same two stops).
4. **Fog still flat** if the margin is judged too small — same two stops, one more notch darker c1 / brighter c2 by ±0.02, re-pack, re-check. → Task 3 contingency step.
5. **stale claims in other files' comments** about Classic values (none known today) — grep `(0.30, 0.12` and `(0.55, 0.0, 0.08` across the mod after the edit; only the shader may still mention them inside a "was" wording. → Task 1 verification.

---

### Task 1: Classic palette stops — monotonic luminance

**Files:**
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKNVG.gdshader` (Classic `else` branch of `ThermalPalette`, lines ~99–105: c1 and c2 assignments)

**Interfaces:**
- Consumes: spec values (below).
- Produces: Classic palette stops c0 (unchanged), c1 = `vec3(0.24, 0.10, 0.38)`, c2 = `vec3(0.65, 0.0, 0.10)`, c3/c4 (unchanged). No other file consumes literal stops.

- [ ] **Step 1: Edit the two stops in the Classic `else` branch only**

- `c1 = vec3(0.30, 0.12, 0.45);` → `c1 = vec3(0.24, 0.10, 0.38);`
- `c2 = vec3(0.55, 0.0, 0.08);` → `c2 = vec3(0.65, 0.0, 0.10);`
- Add one comment line above `c1` (English, factual): the Classic ladder must ascend in luminance (dot(rgb, 0.299/0.587/0.114)); the old c1 (0.211) outshone the old c2 (0.174), so fog-compressed midtones read "warmer = darker".

- [ ] **Step 2: Verify the edit is exactly the Classic branch**

Run: `git diff "standalone mods/ThermalVTK/mods/ThermalVTK/VTKNVG.gdshader"`
Expected: exactly 2 stop lines changed, both inside the `else {` block; the `worldPaletteMode == 1/2/3` branches untouched; parens balanced; tabs intact.

- [ ] **Step 3: Grep for stale Classic literals elsewhere**

Run: `Select-String -SimpleMatch "0.12, 0.45", "0.55, 0.0, 0.08" -Path "standalone mods\ThermalVTK\mods\ThermalVTK\*"`
Expected: hits only in the shader's "was" comment context; no stale value in any `.gd` file.

- [ ] **Step 4: Commit**

```bash
git add "standalone mods/ThermalVTK/mods/ThermalVTK/VTKNVG.gdshader"
git commit -m "ThermalVTK 1.17.2: Classic palette stops ascend in luminance (fog readability)"
```

### Task 2: Version, CHANGELOG, pack, deploy

**Files:**
- Modify: `standalone mods/ThermalVTK/mod.txt` (field `version`)
- Modify: `standalone mods/ThermalVTK/CHANGELOG.md` (top entry)
- Build: `standalone mods/ThermalVTK/pack.ps1` → `D:\SteamLibrary\steamapps\common\Road to Vostok\mods\ThermalVTK.vmz`

**Interfaces:**
- Consumes: Task 1 commit.
- Produces: release 1.17.2 deployed in game.

- [ ] **Step 1: `mod.txt`**

`version="1.17.2"`.

- [ ] **Step 2: CHANGELOG entry after `# Changelog`**

```markdown
## [1.17.2] - 2026-10-24

### Fixed
- The Classic thermal palette now gets brighter with every step up in heat: foggy days and other low-contrast scenes no longer show colder ground as a brighter shade than the warm spots on it.
```

- [ ] **Step 3: Pack and deploy**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File "standalone mods\ThermalVTK\pack.ps1" -OutFile "D:\SteamLibrary\steamapps\common\Road to Vostok\mods\ThermalVTK.vmz"`
Expected: `Version in mod.txt: 1.17.2`, 21 entries, no error output.

- [ ] **Step 4: Ledger note**

Append to the SDD progress file: Task 1 done (commit sha), Task 2 done (pack size), deployed.

### Task 3: Partner in-game verification (gate)

**Files:** none (playtest only).

**Interfaces:**
- Consumes: deploy from Task 2.
- Produces: verdict classic-vs-ice readability; possible tuning request back to Task 1 (±0.02 on c1/c2).

- [ ] **Step 1: Fog midday, Classic vs Ice**

Re-shoot the seconds-apart pair at "Outpost (Area 05)" foggy midday: warm lawn spots must read *brighter* than the cold ground in Classic; violet→red must ascend with heat. Ice stays as the reference (unchanged).

- [ ] **Step 2: Night Classic**

Cold night frame: ground reads dark purple, distinct from the black of `c0`; no crush merge.

- [ ] **Step 3: Keys regression sweep**

Rings (normal/combat/defend), mines, nomad marker read as in 1.17.1 in both Classic and one other palette — colors unchanged by design (substitution happens before the palette).

- [ ] **Step 4: Verdict**

PASS → close ledger, offer `finishing-a-development-branch` style wrap (here on main: just record). FAIL → tune c1 darker / c2 lighter by ±0.02, repeat Task 2 steps 3–4 and re-verify.
