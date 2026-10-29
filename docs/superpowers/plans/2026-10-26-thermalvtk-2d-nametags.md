# ThermalVTK 2D nametags — Implementation Plan

> **For agentic workers:** Use superpowers executing-plans or subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Replace the Label3D NPC labels with a 2D `Control` overlay, expand the label text (name, distance, health, state, vs, reloading), move the nomad diamond into 2D, and add an independent MCM toggle for it. No new MCM keys for individual label fields (gated by `debug_log`).

**Architecture:** Two new modules — pure `VTKLabels.gd` (strings, geometry-free) and thin `VTKLabelLayer.gd` (`Control._draw`). `VTKESP` creates a `CanvasLayer(layer=1)` and pushes facts per frame. The nomad diamond and LOS raycast remain; the key/detector mechanism (KEY_NOMAD/DET_NOMAD) is removed.

**Tech Stack:** GDScript (Godot 4.6.3), MCM `ConfigFile` descriptors, headless `.check/check.ps1` for compile + tests.

**Spec:** `docs/superpowers/specs/2026-10-26-thermalvtk-2d-nametags-design.md`

## Global Constraints

- Tabs only (no mixed spaces) — required by the bench.
- Pure modules (`VTKLabels`, …) must not call `load()` or reach into the game; they must be headless-safe.
- `mod.txt` version 2.2.0; `version.txt` synced by `pack.ps1` (do not hardcode).
- MCM merges by key: new `nomad_marker` key auto-added to profiles by `_sync_config`.
- Removal: `VTKNomadMarker.gdshader` deleted; `KEY_NOMAD`/`DET_NOMAD`/`nomadKey` detector removed.
- Do not rework working code beyond scope (no 2D outlines).
- Verification command: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1` → green, including `test_labels.gd` listed in `$tests`.

## Review Focus

- **Inspector:** Leave stale item structs in the overlay buffer after `clear()` → labels from a previous frame ghosting. Expected: `clear()` empties both buffers and sets visible false.
- **Inspector:** Overlay reads `gameData` through a path that is null in tests → silent abort of `_overlay_sync`. Expected: null GameData degrades gracefully (gates skipped, overlay still drives off overlay-layer state), never a `Null`/Parse crash.
- **Inspector:** Camera behind the NPC (screen projection bogus). Expected: items are drawn only when `camera.is_position_behind(anchor)` is false, no out-of-range triangles.
- **Inspector:** Expired trigger suffix formats seconds with stale `now`. Expected: negative countdown never printed; suffix vanishes when the window is gone.
- **Inspector:** `_want` membership refers to stale id after bot deactivates. Expected: only ids still present in `_entries` draw labels.
- **Inspector:** `_nomad_los` must never invoke `_camera()` when `los_probe` is set (test seam). Expected: probe return wins, zero ray casts / camera lookups.

---

## Task 1: Pure label-text module (`VTKLabels.gd`) + tests

**Files:**
- Create: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKLabels.gd`
- Create test: `.check/project/tests/test_labels.gd` (add uid similarly to neighbours)

**Interfaces:**
- Produces: `VTKLabels.name_of`, `VTKLabels.header`, `VTKLabels.status`, `VTKLabels.trigger_suffix`, `VTKLabels.health_frac`.

- [ ] **Step 1:** Write failing test at `.check/project/tests/test_labels.gd` (extends `SceneTree`, `_init` connects `_run`) with assertions:
  - `name_of("Bandit", "") == "Bandit"`; `name_of("Bandit", "Vanya") == "Vanya"`.
  - `header("Bandit", 42.0) == "Bandit  42 m"`; `header("Bandit", 42.7) == "Bandit  43 m"`.
  - `status(8, false, "") == "Hunt"`; `status(8, true, "") == "Hunt, reloading"`; `status(8, false, "vs you") == "Hunt vs you"`; `status(8, true, "vs Bandit_2") == "Hunt, reloading vs Bandit_2"`.
  - `trigger_suffix({}, 10.0) == ""`.
  - live/expired handled.
  - `health_frac(0.0, 100.0) == 0.0`, etc.
- [ ] **Step 2:** Run check → FAIL (file missing).
- [ ] **Step 3:** Create `VTKLabels.gd` (extends RefCounted, preloads VTKStates, static funcs per spec).
- [ ] **Step 4:** Add to `$tests` in `check.ps1` + uid file.
- [ ] **Step 5:** Run check → green.

**Commit:** `feat(thermal-nametags): add pure VTKLabels text module + tests`

---

## Task 2: Add `nomad_marker` to Settings (MCM)

**Files:**
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKSettings.gd` (DESCRIPTORS + Rec + read)
- Tests: `.check/project/tests/test_settings.gd` add case.

- [ ] **Step 1:** Write failing test `t_nomad_marker_default_and_read`.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Add field to Rec, descriptor pos 10 cat 01. ThermalVision, line in read().
- [ ] **Step 4:** Run → green.

**Commit:** `feat(thermal-nametags): nomad_marker MCM setting`

---

## Task 3: Remove dead nomad key/detector

**Files:**
- Modify: `VTKNVG.gd` (DET_NOMAD const, set_nomad_color var, two pushes)
- Modify: `VTKNVG.gdshader` (uniforms, dNom, branch, comments)
- Modify: `VTKStates.gd` (KEY_NOMAD, comments)
- Modify: `VTKCalibration.gd` (comment only)
- Delete: `VTKNomadMarker.gdshader`
- Modify tests: `test_states.gd`, `test_shaders.gd` (remove nomad refs; keep state/mine asserts)

- [ ] **Steps 1-5:** edit + remove refs + run check green.

**Commit:** `chore(thermal-nametags): drop dead nomad key/detector`

---

## Task 4: Thin `VTKLabelLayer.gd` (Control) overlay

**Files:**
- Create: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKLabelLayer.gd`

Implement `extends Control`, `set_frame`, `clear`, `_draw` (camera guard, project/draw lines/bars/diamonds), `_ready`.

- [ ] Implement + run bench green.

**Commit:** `feat(thermal-nametags): thin 2D label layer Control`

---

## Task 5: Rewrite `VTKESP.gd` to feed the overlay layer

**Files:**
- Modify: `VTKESP.gd`
- Modify: `test_esp.gd`

Internal new: `_overlay_layer: CanvasLayer`, `_overlay: Control`, `_overlay_sync(now)`, `_head_world(node) -> Vector3`, `_nomad_los(e, to) -> bool`; `p_nomad_marker`, `p_color_*`; apply_config extended.

Removed specs' Label3D/marker-mesh constructs per design.

- [ ] Rewrite tests (Replace `esp._label_text` → `VTKLabels.trigger_suffix`; remove t_calibration_marker; retarget marker tests to diamond feed and LOS; in-place contour toggle tests).
- [ ] Implement changes.
- [ ] Run check green.

**Commit:** `feat(thermal-nametags): feed NPC facts into 2D overlay`

---

## Task 6: Version, changelog, cleanup

**Files:** `mod.txt` (version 2.2.0), `CHANGELOG.md` (per spec). Run check green. Commit.

---

## Self-review

- All six spec deliverables (VTKLabels, VTKLabelLayer, VTKESP feed, Settings nomad_marker, removal, tests) appear in tasks.
- Each review-focus failure mode has a corresponding test target in Task 5.
- Proportion: bodies left to implementer; plan ~2-4 transfers more than the spec and only states exact string literals and interfaces.