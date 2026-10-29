# Batch 5 cleanup — design/spec

- Date: 2026-10-14
- Base: audit branch 4.17.1, audit doc `docs/audit/vostok-toolkit-4.15.1.md`
- Files: `loadouts/mods/VTK/VTKTravel.gd`, `loadouts/mods/VTK/VTKHooks.gd`, `loadouts/mods/VTK/VTKFeed.gd`
- Version after batch: `4.17.1 → 4.17.2` (patch: refactor, no behavior change)

## Goal

Remove dead debug logging, dead helper functions, dead branches and magic numbers from the approved ✅ items of the 4.17.1 audit, in three files, with **strictly no behavior change**. Net effect: fewer lines, less per-frame work, no player-visible difference.

## Non-goals

- No behavior change of any kind on the paths that survive (public API, signals, saved data, UI, MCM keys).
- No changes to ⏸️ / ⚠️ / Bug items of the audit.
- No `VTKUI.gd` `_process` restructuring (not in ✅).
- No test expectation changes (`.check/project/tests/*` untouched).
- No renames of surviving symbols; no reformatting beyond the deleted lines.
- No `CHANGELOG.md` entry beyond the roll-up line (internal cleanup → «Minor performance improvements» or omit).

## Scope

| ID | Item | File | Status |
|----|------|------|--------|
| V1a | Delete debug log (`_log`, `_log_reset`, `TRAVEL_LOG`, `_teleport_started_ms`, `_log_file`, 32 call sites) | VTKTravel.gd | in scope |
| V1b | Delete `_monitor_placement` + its call | VTKTravel.gd | in scope |
| V1c | Delete `_dump_subtree` (call site `_trader_point`) | VTKTravel.gd | in scope |
| V1d | Delete `_ray_floor` (logging-only helper) | VTKTravel.gd | in scope |
| V1e | `is_shelter_unlocked`: drop `FileAccess` fallback, keep `CheckShelterState` only | VTKTravel.gd | in scope |
| V12 | Delete `game_data.set("playerVector", Vector3.ZERO)` in `_place_player` | VTKTravel.gd | in scope |
| V2 | Delete `_dump_death_tree` + call site + `_death_dump_at` | VTKHooks.gd | in scope |
| V6a | Delete 10 dead property probes in `_player_weapon_name` | VTKHooks.gd | in scope |
| V6b | Feed `_process`: early-out when `_rows.is_empty()` (`_enabled` guard already present) | VTKFeed.gd | in scope |
| V6c | `_on_controller_process`: early-out when all three dicts empty | VTKHooks.gd | in scope |
| V13a | `DEATH_PROBE_MS := 1000` (value unchanged) | VTKHooks.gd | in scope |
| V13b | `PLAYER_HITS_TTL_MSEC := 30000` (value unchanged) | VTKHooks.gd | in scope |
| V10a | Delete `_wipe_saves_for_restart` + else-call in `_on_restart_pressed` | VTKHooks.gd | **BLOCKED** — see below |
| V10b | Delete restart writes `shelter`/`permadeath` (1460/1461/1464/1465) | VTKHooks.gd | **BLOCKED** — see below |

## Blocked items (approved ✅, but would break live tests)

Hard constraints of this batch: «don't change test expectations» and «check.ps1 green after». Two approved items assert against `test_hooks.gd` and cannot land without a test edit, which Batch 5 forbids. They stay in the audit as-is and wait for a batch that is allowed to touch tests.

### BLOCKED — V10a `_wipe_saves_for_restart` is not dead

Audit called it a dead branch. It is a **tested fallback**: `_on_restart_pressed` (VTKHooks.gd:1476-1479) calls it when `Loader` has no `NewGame`, and `t_ironman_restart_restores_difficulty` asserts exactly that:

- `.check/project/tests/test_hooks.gd:253-258` — fixture `FakeLoaderNoNew` (has `LoadScene`, no `NewGame`);
- `test_hooks.gd:303-304` — `old_h._on_restart_pressed(old_gd, null)` then `ck(old_h.wiped, "без Loader.NewGame рестарт откатывается на wipe")`;
- `test_hooks.gd:16-21` — `TestHooks` overrides `_wipe_saves_for_restart` to set `wiped = true` (base method must exist for the override to intercept).

Deleting VTKHooks.gd:1418-1441 and the else-call at 1478-1479 makes `wiped` stay `false` → `FAIL` at test_hooks.gd:304. **Out of scope for Batch 5.**

### BLOCKED — V10b restart `shelter`/`permadeath` writes are asserted

`t_ironman_restart_restores_difficulty` checks the writes on a `FakeGD` fixture (fields default `permadeath = false`, `shelter = false`):

- `test_hooks.gd:284` — `ck(gd.permadeath, "ironman-рестарт поднимает permadeath")` — fails if `gd.set("permadeath", true)` (VTKHooks.gd:1461) is deleted;
- `test_hooks.gd:288` — `ck(gd.shelter == false, ...)` passes only by fixture default, not by production code.

In the real game the writes are overwritten by `Loader.LoadScene`, but the test asserts the intermediate state. Deleting 1460/1461/1464/1465 → `FAIL` at test_hooks.gd:284. **Out of scope for Batch 5.**

## Per-file diffs

Line numbers are orientation anchors at 4.17.1 and shift as edits apply. Every hunk is anchored by its unique code snippet; re-locate by symbol, not by line, after each applied edit. Tabs only, UTF-8.

### `loadouts/mods/VTK/VTKTravel.gd`

**T1 — consts/vars (V1a).** Delete:

```gdscript
const TRAVEL_LOG := "user://loadouts_travel.log"     # line 10
var _teleport_started_ms: int = 0                     # line 33
var _log_file: FileAccess = null                      # line 34
```

Keep `Log` preload (still used by `_message`), `FLOOR_PROBE_UP`/`FLOOR_PROBE_DOWN` (still used by `_ray_floor_hit`).

**T2 — `is_shelter_unlocked` (V1e).** Replace body of (lines 61-65):

```gdscript
func is_shelter_unlocked(shelter_name: String) -> bool:
	var loader := _loader()
	if loader != null and loader.has_method("CheckShelterState"):
		return bool(loader.CheckShelterState(shelter_name))
	return false
```

The former `FileAccess.file_exists(Paths.SHELTER_SAVE_FMT % shelter_name)` fallback is gone; explicit `return false` keeps the analyzer happy. `Paths.SHELTER_SAVE_FMT` stays in `VTKPaths.gd` (shared const; only consumer was this line — harmless, VTKPaths is out of scope).

**T3 — `_teleport_internal` (V1a).** Delete:

- `_log_reset()` and `_teleport_started_ms = Time.get_ticks_msec()` (lines 126-127);
- `_log("teleport start -> " ...)` (131);
- `_log("FAIL scene never changed for " ...)` (146) — keep the surrounding `_busy = false` + `_message`;
- `_log("scene changed detected")` (149);
- `_log("FAIL: map never became ready for " ...)` (156);
- `_log("resolved offset Vector3 " ...)` (160);
- `_log("FAIL trader " ...)` (164);
- `_log("resolved offset is NOT Vector3 " ...)` (168);
- `_log("teleport done -> " ...)` (172).

All `_message(...)` calls and control flow stay byte-identical.

**T4 — `_save_before_transition` (V1a).** Delete the four `_log(...)` lines (177, 181, 184, 186) and the now-unused `var shelter := game_data != null and bool(game_data.get("shelter"))` (183 — its only consumer was the log string at 184). Result:

```gdscript
func _save_before_transition(target_map: String, loader: Node) -> void:
	if loader == null or not loader.has_method("SaveCharacter"):
		return
	var iface := get_node_or_null(Paths.INTERFACE)
	if iface == null:
		return
	loader.call("SaveCharacter")
```

Unused param `target_map` is legal GDScript, keeps the signature.

**T5 — `_close_interfaces` (V1a).** Delete the debug-only vars `gd_iface` (232-234), `iface_vis` (235-237) and the four `_log(...)` lines (238, 241, 244, 246). `ui`/`iface` lookups and the Close/ToggleInterface logic stay. Result:

```gdscript
func _close_interfaces() -> void:
	var parent := get_parent()
	if parent != null and is_instance_valid(parent) and parent.has_method("_set_panel_open"):
		parent.call("_set_panel_open", false)
	var ui := get_node_or_null(Paths.UI)
	var iface := get_node_or_null(Paths.INTERFACE)
	if iface != null and iface.has_method("Close"):
		iface.call("Close")
	elif ui != null and ui.has_method("ToggleInterface"):
		ui.call("ToggleInterface")
	if game_data != null:
		game_data.set("interface", false)
		game_data.set("isOccupied", false)
```

**T6 — `_log_reset` / `_log` functions (V1a).** Delete both whole functions (lines 260-266 and 268-282), including all `FileAccess`/`DirAccess` I/O. After T1-T5 there are no callers left.

**T7 — `_trader_point` (V1a/V1c/V1d).** Delete the `_log(...)` lines at 296, 297 (this call also removed the only `_dump_subtree` use), 299, 301, 303, 309, 316, 318, 324, 332, 335. Collapse the dead remnants:

- `var ctrl := _controller()` (300) — its only consumer was the log at 301; delete both;
- `var ref_floor := _ray_floor(space, exclude, anchor)` (315) — logging-only (V1d); delete;
- the `else` branch of `if node != null:` (298-299) becomes empty once its log is gone — delete the `else`, keep `anchor = node.global_position`;
- the `controller NULL` branch keeps `var raw2 := anchor + facing * TRADER_STAND_DISTANCE` and `return raw2` (log line 309 deleted only).

Result (structure):

```gdscript
	var node := find_trader(trader_name)
	var anchor: Vector3 = fallback
	if node != null:
		anchor = node.global_position
	var facing := _node_forward(node)
	_look_at = anchor
	_has_look_at = true
	var ctrl2 := _controller()
	if ctrl2 == null:
		var raw2 := anchor + facing * TRADER_STAND_DISTANCE
		return raw2
	var space := ctrl2.get_world_3d().direct_space_state
	var exclude: Array = [ctrl2.get_rid()]
	if node != null:
		_collect_rids(node, exclude)
	var stand_dir := -facing
	for dist in [TRADER_STAND_DISTANCE, 2.5, 3.0, 1.5]:
		...  # unchanged: _ray_floor_hit loops, ring loop, fallback return
```

`_ray_floor_hit`, `_collect_rids`, `_node_forward` are untouched.

**T8 — delete `_ray_floor` (V1d).** Whole function, lines 345-349. Sole caller was T7.

**T9 — delete `_dump_subtree` (V1c).** Whole function, lines 360-372. Sole caller was `_trader_point` line 297 (removed in T7).

**T10 — `_await_map_ready` (V1a).** Delete `_log("map ready: ...")` (398). The `caching` var and the `if caching: return false` logic stay.

**T11 — `_place_player` (V1a/V12).** Delete both `_log(...)` lines (408, 414), the `playerVector` write (V12: `if game_data != null: game_data.set("playerVector", Vector3.ZERO)`, 412-413), and the `_monitor_placement(target, ctrl)` call (417). Result:

```gdscript
func _place_player(target: Vector3) -> void:
	var ctrl := _controller()
	if ctrl == null:
		return
	ctrl.global_position = target
	ctrl.set("velocity", Vector3.ZERO)
	if _has_look_at:
		_face_trader(ctrl, _look_at)
```

**T12 — `_face_trader` (V1a).** Delete `_log("face: trader too close, ...")` (428 — the early `return` stays) and `_log("face: yaw=...")` (438).

**T13 — delete `_monitor_placement` (V1b).** Whole function, lines 441-453 (including its await-timer loop). Sole caller removed in T11.

### `loadouts/mods/VTK/VTKHooks.gd`

**H1 — consts (V13).** Next to the existing TTL consts (lines 21-22) add:

```gdscript
const PLAYER_HITS_TTL_MSEC := 30000
```

Above `var _death_probe_at: int = 0` (line 61) add:

```gdscript
const DEATH_PROBE_MS := 1000
```

Then, in `_poll_death` (line 151): `if pnow - _death_probe_at > 1000:` → `if pnow - _death_probe_at > DEATH_PROBE_MS:`. Values identical; no timing change.

**H2 — delete `_death_dump_at` (V2).** Delete `var _death_dump_at: int = 0` (line 60). Sole consumer is `_dump_death_tree` (H3).

**H3 — delete `_dump_death_tree` + call site (V2).** In `_handle_death_screen`, delete the tail call `_dump_death_tree(root, waited, now)` (line 1318 — the `waited >= DEATH_FIND_TIMEOUT_MS` early-return above it stays). Delete the whole function (lines 1352-1375). Pure log emission; no test asserts on it (`t_death_timeout_gives_up` only checks button handling/timeout behavior).

**H4 — `_player_weapon_name` probes (V6a).** Replace the function (lines 733-751, including the now-stale probe comment) with:

```gdscript
# Имя оружия игрока: GameData и узел игрока имени не несут (probe, Task 1),
# настоящее оружие — WeaponRig под Camera/Manager, см. _rig_weapon_name().
func _player_weapon_name() -> String:
	return _rig_weapon_name()
```

The two property-scan loops (`currentWeaponName`/`weaponName`/... over `gd` and over the `Player`-group node) are removed. Keep `_weapon_str` (still used by `_weapon_name_of` at line 795) and `_weapon_name_of` (used at line 638). Test impact: `t_player_rig_weapon` (test_hooks.gd:500-538) fakes only the WeaponRig path — no gd/player weapon props in the fixture — so all three assertions (`M4A1`, visible rig, skip rig without `data.file`) pass unchanged.

**H5 — `_on_controller_process` early-out + TTL const (V6c/V13).** In the function (842-864), after the existing guard:

```gdscript
	if not is_instance_valid(controller):
		return
```

insert:

```gdscript
	if _player_hits.is_empty() and _seen_deaths.is_empty() and _last_damager.is_empty():
		return
```

and replace `> 30000` (line 849) with `> PLAYER_HITS_TTL_MSEC`. Purge loops themselves are unchanged — when any dict is non-empty, behavior is byte-identical. Test impact: `t_post_callback_arity` only checks the argument count of `_on_controller_process` (1) — signature untouched.

### `loadouts/mods/VTK/VTKFeed.gd`

**F1 — `_process` early-out (V6b).** The `_enabled` guard already exists at lines 230-231 (`if not _enabled: return`) — no change there. After the scene-change block (lines 233-236, `if cs != _scene_ref: ... clear()`), insert **before** the shelter/interface reads:

```gdscript
	if _rows.is_empty():
		return
```

Rationale: with an empty feed there is nothing to age, nothing to clear on shelter entry (clear of an empty list is a no-op) and no `_was_shelter` transition that can matter — `_was_shelter` is only consulted by `if in_shelter and not _was_shelter: clear()`, which is observable only when rows exist. The expensive part (per-frame `get_node_or_null(Paths.INTERFACE)` + `gameData.shelter` read) is skipped. `test_feed.gd` never calls `_process` — no test impact.

Do **not** restructure anything else in `_process`.

## Verification plan

1. `python .check\layout_check.py` — must print all-zero GONE/PRESENT/FUNCS failures. No list entry references a deleted symbol (checked: `HOOKS_GONE`, `GONE`, `PRESENT`, `FUNCS` target `VTKUI.gd`/`VTKHooks.gd` symbols that Batch 5 does not touch).
2. `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1` — must be green: no `SCRIPT ERROR` / `Parse Error` / `Invalid call` / `Failed to load script`, `tests passed` present, exit code 0. Specific tests to watch: `t_player_rig_weapon`, `t_ironman_restart_restores_difficulty` (must keep passing **unchanged** — this is why V10a/V10b are blocked), `t_post_callback_arity`, `t_death_timeout_gives_up`, all `test_feed.gd` cases.
3. Grep sweep after implementation, all three files: `_log(`, `_log_reset`, `TRAVEL_LOG`, `_log_file`, `_teleport_started_ms`, `_dump_subtree`, `_ray_floor(`, `_monitor_placement`, `_dump_death_tree`, `_death_dump_at` — zero hits. `Select-String -SimpleMatch 'preload(' loadouts\mods\VTK\VTKUI.gd` — count unchanged (no preloads removed).
4. Diff review: `git diff` touches exactly `VTKTravel.gd`, `VTKHooks.gd`, `VTKFeed.gd`, `loadouts/mod.txt` (version), optionally `CHANGELOG.md`. No test files, no `layout_check.py`, no `VTKUI.gd`.
5. Version: bump `loadouts/mod.txt` `version="4.17.1"` → `"4.17.2"`; `pack.ps1` prints the version before packing — cross-check. `CHANGELOG.md`: single roll-up line «Minor performance improvements» under `### Changed` for 4.17.2 (or omit entirely per rule 4).
6. Manual smoke (optional, not blocking): one teleport to a trader (travel path), one death→Restart in a normal run and one in ironman (restart path), kill feed appears/fades (feed path).

## Risk

Trivial. The batch is LOC removal plus two constant extractions with identical values and three early-outs on provably empty state. No public API, signal, save-format, MCM-key or UI change. The only judgment calls (unused locals `shelter`/`ctrl`/`gd_iface`/`iface_vis`, empty `else` collapse in `_trader_point`) are forced by the deletions and verified against call sites. Residual risk is a missed call site of a deleted function — caught by the grep sweep (step 3) and by `check.ps1` compile pass.

## Self-review checklist

- [x] Every hunk traced to a specific ✅ item; no ⏸️/⚠️/Bug item touched.
- [x] Every deleted function's call sites enumerated (`_log`×32 + `_log_reset`×1, `_dump_subtree`×1, `_ray_floor`×1, `_monitor_placement`×1, `_dump_death_tree`×1); all removed in the same batch.
- [x] Survivors verified: `_ray_floor_hit`, `_collect_rids`, `_node_forward`, `_weapon_str`, `_weapon_name_of`, `_message`, `Log` preload, `FLOOR_PROBE_*` still referenced.
- [x] Two approved items found conflicting with live test assertions and moved to a Blocked section with exact test lines (test_hooks.gd:284, :304, fixture :253-258, override :16-21) instead of landing a red build.
- [x] Constants keep identical values (`1000`, `30000`); no timing change.
- [x] Early-outs placed so every previously observable state transition still fires (feed: after scene-change clear; hooks: after validity guard).
- [x] `layout_check.py` lists contain no symbol this batch deletes; no test file edited.
- [x] Tabs-only, UTF-8, no comments added beyond the two rewritten doc-comments required by deleted context (H4).
- [x] Version bump 4.17.2 recorded; CHANGELOG roll-up noted as optional.
