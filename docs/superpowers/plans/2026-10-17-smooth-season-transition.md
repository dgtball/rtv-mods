# Smooth Seasonal Transition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fade the seasonal tint (tree/grass `tint` + air tint) over 8 real seconds instead of snapping when a Dynamic season changes.

**Architecture:** `VTKSeasonDriver` (RefCounted) keeps a crossfade state and exposes `tick(delta)`, called from the existing per-frame `VTKHooks._process`. A pure `VTKSeasons.blend()` does the interpolation and is headless-tested. Materials are global; air is per-scene and re-bound on `on_world_ready()`.

**Tech Stack:** GDScript (Godot 4.6.3), static/pure `RefCounted` helpers, headless test harness in `.check/`.

## Global Constraints

- Godot version: 4.6.3 (matches `RTVcopy/RTV.pck`, pack format 3).
- GDScript indentation: **tabs only**. Files are UTF-8.
- The mod version lives in exactly one place: `loadouts/mod.txt`, field `version` (quoted). Never duplicate it in code.
- Stands must be green after every `.gd` change:
  - `py -3 .check\layout_check.py` → exit 0.
  - `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1 -Godot "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe"` → prints `Tests passed: 15 file(s)` (15 becomes 15; `test_seasons.gd` already listed), with NO lines matching `SCRIPT ERROR`, `Parse Error`, `Invalid call`, `Failed to load script`.
- Packaging: `powershell -ExecutionPolicy Bypass -File pack.ps1` must print `Version in mod.txt: 5.1.1`; then copy `D:\RTVMOD\Loadouts.vmz` to `D:\SteamLibrary\steamapps\common\Road to Vostok\mods\Loadouts.vmz`.
- Commit steps: **commit only when the user explicitly approves committing** (AGENTS.md rule). If not approved, stop after verification.
- No new user-facing strings, so no localization changes.
- Duration is a hardcoded constant (user decision); no MCM setting.

---

### Task 1: Pure `blend` helper in VTKSeasons

**Files:**
- Modify: `loadouts/mods/VTK/VTKSeasons.gd` (append a static function)
- Test: `.check/project/tests/test_seasons.gd` (add `t_blend`)

**Interfaces:**
- Produces: `static func blend(a: Color, b: Color, t: float) -> Color` — clamped linear interpolation; `t` below 0 returns `a`, above 1 returns `b`.

- [ ] **Step 1: Write the failing test**

Add to `.check/project/tests/test_seasons.gd`. Register it in `_init` by inserting `t_blend()` after the `t_palettes()` line, and append the function at the end of the file:

```gdscript
func t_blend() -> void:
	var a := Color(0, 0, 0)
	var b := Color(1, 1, 1)
	ck(S.blend(a, b, 0.0) == a, "blend t=0 -> a")
	ck(S.blend(a, b, 1.0) == b, "blend t=1 -> b")
	ck(S.blend(a, b, -1.0) == a, "blend ниже 0 клампится к a")
	ck(S.blend(a, b, 2.0) == b, "blend выше 1 клампится к b")
	ck(S.blend(a, b, 0.5).is_equal_approx(Color(0.5, 0.5, 0.5)), "blend середина")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1 -Godot "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe"`
Expected: FAIL for the `test_seasons.gd` file — an error that `blend` is not found on the script (non-zero exit / `Seasons tests failed`).

- [ ] **Step 3: Write minimal implementation**

Append to `loadouts/mods/VTK/VTKSeasons.gd`:

```gdscript
static func blend(a: Color, b: Color, t: float) -> Color:
	return a.lerp(b, clampf(t, 0.0, 1.0))
```

- [ ] **Step 4: Run test to verify it passes**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1 -Godot "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe"`
Expected: `Seasons tests passed` and `Tests passed: 15 file(s)`.

- [ ] **Step 5: Commit**

```bash
git add loadouts/mods/VTK/VTKSeasons.gd .check/project/tests/test_seasons.gd
git commit -m "feat(seasons): add pure blend() helper for tint interpolation"
```
(Only if the user approved committing.)

---

### Task 2: Crossfade state in VTKSeasonDriver

**Files:**
- Modify: `loadouts/mods/VTK/VTKSeasonDriver.gd` (add state + `tick`; refactor `set_season`, air handling, `restore`, `on_world_ready`)

**Interfaces:**
- Consumes: `SEASONS.blend(a, b, t) -> Color` (Task 1); existing `SEASONS.uses_tint/tree_tint/grass_tint/air_tint`.
- Produces for Task 3: `func tick(delta: float) -> void` on the driver.
- Produces: `set_season(index: int, is_dynamic_run: bool = true, visuals: bool = true)`, `on_world_ready() -> void`, `restore() -> void` (signatures unchanged from 5.1.0).

- [ ] **Step 1: Add the constant and transition state**

In `loadouts/mods/VTK/VTKSeasonDriver.gd`, after `const AIR_PROPS := ["ambient_light_color"]` add:

```gdscript
# Кроссфейд тона: ваниль плавно сходит снег (глобальный Snow), а тон должен
# приходить так же - за фиксированное реальное время, а не скачком.
const TRANSITION_SECS := 8.0
```

Then, in the field block (after `var _world: Node = null`), add:

```gdscript
var _fade_active := false
var _fade_t := 0.0
var _fade_from_index := -1
var _fade_mats: Array = []
var _fade_airs: Array = []
```

- [ ] **Step 2: Refactor `set_season`**

Replace the whole `set_season` function (current lines 41-53) with:

```gdscript
func set_season(index: int, is_dynamic_run: bool = true, visuals: bool = true) -> void:
	if not is_dynamic_run:
		return
	_visuals = visuals
	var sim := _get_sim()
	if sim == null:
		return
	_set_prop(sim, "season", 2 if index == 3 else 1)
	var first := _last_index < 0
	if not _visuals:
		_cancel_fade()
		_restore_foliage()
		_restore_air_all()
	elif first or TRANSITION_SECS <= 0.0:
		_cancel_fade()
		_apply_tint(index)
	else:
		_begin_fade(index)
	_last_index = index
```

- [ ] **Step 3: Add `tick` and the fade helpers**

Insert these functions (e.g. right after `set_season`):

```gdscript
func tick(delta: float) -> void:
	if not _fade_active:
		return
	_fade_t = minf(1.0, _fade_t + delta / TRANSITION_SECS)
	for e in _fade_mats:
		_set_mat(e, SEASONS.blend(e["from"], e["to"], _fade_t))
	for a in _fade_airs:
		_set_air_value(a, SEASONS.blend(a["from"], a["to"], _fade_t))
	if _fade_t >= 1.0:
		_cancel_fade()

func _begin_fade(index: int) -> void:
	if not _bound:
		_bind()
	_fade_from_index = _last_index
	_fade_mats.clear()
	for e in _tree_entries:
		_add_fade_mat(_fade_mats, e, SEASONS.tree_tint(index) if SEASONS.uses_tint(index) else e["orig"])
	for e in _grass_entries:
		_add_fade_mat(_fade_mats, e, SEASONS.grass_tint(index) if SEASONS.uses_tint(index) else e["orig"])
	_fade_airs = _air_pairs(index, _fade_from_index)
	_air_entries_clear_and_fill(_fade_airs)
	_fade_t = 0.0
	_fade_active = true

func _add_fade_mat(list: Array, e: Dictionary, to: Color) -> void:
	var mat = e["mat"]
	if mat == null or not is_instance_valid(mat):
		return
	var from = mat.get_shader_parameter("tint")
	if not (from is Color):
		from = Color(1, 1, 1, 1)
	list.append({"mat": mat, "from": from, "to": to})

func _cancel_fade() -> void:
	_fade_active = false
	_fade_t = 0.0
	_fade_mats.clear()
	_fade_airs.clear()
```

- [ ] **Step 4: Replace the air functions**

Replace the current `_apply_air` (lines 124-139) and `_set_air` (lines 141-150) and `_restore_air` (lines 152-156) with:

```gdscript
# Воздух: пары from/to считаются от ванильного цвета, снятого метой с объекта,
# поэтому переживают пересборку драйвера и перезагрузку карты.
func _air_pairs(to_index: int, from_index: int) -> Array:
	var out: Array = []
	var world := _find_world()
	if world == null:
		return out
	var env_node = world.get("environment")
	if env_node != null and is_instance_valid(env_node):
		var env_res = env_node.get("environment")
		if env_res != null:
			for prop in AIR_PROPS:
				_air_pair(out, env_res, prop, to_index, from_index, AIR_STRENGTH)
	var sun = world.get("sunLight")
	if sun == null:
		sun = world.get_node_or_null("Planet/Sun/Light")
	if sun != null and is_instance_valid(sun):
		_air_pair(out, sun, "light_color", to_index, from_index, AIR_STRENGTH * 0.6)
	return out

func _air_pair(out: Array, obj: Object, prop: String, to_index: int, from_index: int, strength: float) -> void:
	if not obj.has_meta(_vanilla_key(prop)):
		var cur = obj.get(prop)
		if not (cur is Color):
			return
		obj.set_meta(_vanilla_key(prop), cur)
	var vanilla: Color = obj.get_meta(_vanilla_key(prop))
	out.append({
		"obj": obj,
		"prop": prop,
		"from": _tint_color(vanilla, SEASONS.air_tint(from_index), strength),
		"to": _tint_color(vanilla, SEASONS.air_tint(to_index), strength),
	})

func _apply_air(index: int) -> void:
	_air_entries.clear()
	for a in _air_pairs(index, -1):
		_set_air_value(a, a["to"])
		_air_entries.append({"obj": a["obj"], "prop": a["prop"]})

func _set_air_value(a: Dictionary, color: Color) -> void:
	var obj = a["obj"]
	if obj != null and is_instance_valid(obj):
		obj.set(a["prop"], color)

func _air_entries_clear_and_fill(pairs: Array) -> void:
	_air_entries.clear()
	for a in pairs:
		_air_entries.append({"obj": a["obj"], "prop": a["prop"]})

func _restore_air_all() -> void:
	for e in _air_entries:
		var obj = e["obj"]
		var prop: String = e["prop"]
		if obj != null and is_instance_valid(obj) and obj.has_meta(_vanilla_key(prop)):
			obj.set(prop, obj.get_meta(_vanilla_key(prop)))
	_air_entries.clear()
```

- [ ] **Step 5: Refactor `restore` and `on_world_ready`**

Replace the current `restore` (lines 70-76) with:

```gdscript
func restore() -> void:
	_cancel_fade()
	_restore_foliage()
	_restore_air_all()
	_last_index = -1
	_world = null
```

Replace the current `on_world_ready` (lines 65-68) with:

```gdscript
func on_world_ready() -> void:
	_world = null
	if not _visuals or _last_index < 0:
		return
	if _fade_active:
		_fade_airs = _air_pairs(_last_index, _fade_from_index)
		_air_entries_clear_and_fill(_fade_airs)
		for a in _fade_airs:
			_set_air_value(a, SEASONS.blend(a["from"], a["to"], _fade_t))
	else:
		_apply_air(_last_index)
```

- [ ] **Step 6: Verify parse + stands**

Run: `py -3 .check\layout_check.py`
Expected: exit 0.

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1 -Godot "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe"`
Expected: `Tests passed: 15 file(s)`, no `SCRIPT ERROR` / `Parse Error` / `Invalid call` / `Failed to load script`.

- [ ] **Step 7: Commit**

```bash
git add loadouts/mods/VTK/VTKSeasonDriver.gd
git commit -m "feat(seasons): crossfade tints over TRANSITION_SECS in the driver"
```
(Only if the user approved committing.)

---

### Task 3: Drive the crossfade from VTKHooks

**Files:**
- Modify: `loadouts/mods/VTK/VTKHooks.gd` (`_process`, currently lines 74-78)

**Interfaces:**
- Consumes: `VTKSeasonDriver.tick(delta: float) -> void` (Task 2).

- [ ] **Step 1: Tick the driver each frame**

Replace the current `_process`:

```gdscript
func _process(_delta: float) -> void:
	if not _registered:
		_try_register()
	if _dyn_enabled:
		_season_apply()
```

with:

```gdscript
func _process(delta: float) -> void:
	if not _registered:
		_try_register()
	if _dyn_enabled:
		_season_apply()
		if _season_driver != null:
			_season_driver.tick(delta)
```

- [ ] **Step 2: Verify parse + stands**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1 -Godot "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe"`
Expected: `Tests passed: 15 file(s)`, no error lines.

- [ ] **Step 3: Commit**

```bash
git add loadouts/mods/VTK/VTKHooks.gd
git commit -m "feat(seasons): tick the season driver for smooth tint transitions"
```
(Only if the user approved committing.)

---

### Task 4: Preserve Dynamic mode on death-restart

**Files:**
- Modify: `loadouts/mods/VTK/VTKHooks.gd` (`_resolve_start_season`, currently ~:1371-1377)
- Test: `.check/project/tests/test_hooks.gd` (add `t_dynamic_restart_stays_dynamic`)

**Interfaces:**
- Consumes: existing `const DYNAMIC_SEASON := 3` and `var _dyn_enabled` in `VTKHooks.gd`.
- Produces: no new API.

**Bug:** `_resolve_start_season()` returns the vanilla `Simulation.season` (`1`/`2`). On death-restart `_on_restart_pressed` passes it to `Loader.NewGame(difficulty, season)`, so `_on_newgame_post` → `_season_new_run(season)` sees `season != 3` and leaves `_dyn_enabled = false` — the Dynamic run comes back as a plain Summer/Winter run. Fix: return `DYNAMIC_SEASON` when the current session is dynamic.

- [ ] **Step 1: Write the failing test**

In `.check/project/tests/test_hooks.gd`, register the new test in `_run()` by inserting `t_dynamic_restart_stays_dynamic()` after the `t_death_load_pressed_runs_restart()` line, and append this function (it reuses the existing `FakeGD`, `FakeSim`, `FakeLoader`, `TestHooks` fixtures):

```gdscript
# Dynamic-забег после смерти обязан остаться Dynamic: _resolve_start_season
# отдавал только ванильный сезон Simulation (1/2), и NewGame стартовал обычный
# забег - сезоны переставали циклиться.
func t_dynamic_restart_stays_dynamic() -> void:
	var gd := FakeGD.new()
	gd.difficulty = 3
	gd.isDead = true

	var sim := FakeSim.new()
	sim.name = "Simulation"
	sim.season = 2
	root.add_child(sim)
	var loader := FakeLoader.new()
	loader.name = "Loader"
	root.add_child(loader)

	var h = TestHooks.new()
	root.add_child(h)
	h._dyn_enabled = true
	h._on_restart_pressed(gd, null, true)

	ck(loader.new_game_called, "dynamic-рестарт зовёт NewGame")
	ck(loader.new_game_season == 3, "dynamic-рестарт сохраняет Dynamic (сезон 3), а не ванильный")

	sim.free()
	loader.free()
	h.queue_free()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1 -Godot "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe"`
Expected: `Hooks tests failed` — the assertion `dynamic-рестарт сохраняет Dynamic (сезон 3), а не ванильный` fails because `new_game_season == 2`.

- [ ] **Step 3: Fix `_resolve_start_season`**

Replace the current `_resolve_start_season` body:

```gdscript
func _resolve_start_season() -> int:
	var sim = get_node_or_null(Paths.SIMULATION)
	if sim != null:
		var s = sim.get("season")
		if s != null:
			return int(s)
	return 1
```

with:

```gdscript
func _resolve_start_season() -> int:
	if _dyn_enabled:
		return DYNAMIC_SEASON
	var sim = get_node_or_null(Paths.SIMULATION)
	if sim != null:
		var s = sim.get("season")
		if s != null:
			return int(s)
	return 1
```

- [ ] **Step 4: Run test to verify it passes**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1 -Godot "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe"`
Expected: `Hooks tests passed` and `Tests passed: 15 file(s)`. The existing `t_ironman_restart_restores_difficulty` / `t_death_load_pressed_runs_restart` still expect vanilla `season == 2` (they leave `_dyn_enabled` at its default false), so they must still pass.

- [ ] **Step 5: Commit**

```bash
git add -f loadouts/mods/VTK/VTKHooks.gd .check/project/tests/test_hooks.gd
git commit -m "fix(vtk): keep Dynamic season mode across a death restart"
```

---

### Task 5: Version, changelog, package, copy

**Files:**
- Modify: `loadouts/mod.txt` (`version`)
- Modify: `CHANGELOG.md` (new top entry)
- Auto-modified by `pack.ps1`: `loadouts/mods/VTK/version.txt`, `README.md` (version line) — commit them together.
- Produce: `Loadouts.vmz`, copied into the game.

**Interfaces:** none.

- [ ] **Step 1: Bump the version**

In `loadouts/mod.txt` change `version = "5.1.0"` to `version = "5.1.1"`.

- [ ] **Step 2: Add the changelog entry**

Insert directly under the `# Changelog` header block, above `## [5.1.0] - 2026-10-17`:

```markdown
## [5.1.1] - 2026-10-17

### Changed

- Seasonal colours now fade in and out smoothly over a few seconds instead of switching instantly.

### Fixed

- A Dynamic run keeps cycling seasons after a death restart instead of turning into a normal run.
```

- [ ] **Step 3: Run the stands**

Run: `py -3 .check\layout_check.py`
Expected: exit 0.

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1 -Godot "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe"`
Expected: `Tests passed: 15 file(s)`, no error lines.

- [ ] **Step 4: Pack and copy**

Run: `powershell -ExecutionPolicy Bypass -File pack.ps1`
Expected: prints `Version in mod.txt: 5.1.1`, `+ mods/VTK/version.txt (5.1.1)`, `README version synced to 5.1.1`, and `Pack done: D:\RTVMOD\Loadouts.vmz ...`. `pack.ps1` rewrites `loadouts/mods/VTK/version.txt` and the README version line from `mod.txt` — those files are now changed in the working tree.

Then:

```powershell
Copy-Item -LiteralPath "D:\RTVMOD\Loadouts.vmz" -Destination "D:\SteamLibrary\steamapps\common\Road to Vostok\mods\Loadouts.vmz" -Force
```

- [ ] **Step 5: Commit**

```bash
git add loadouts/mod.txt CHANGELOG.md loadouts/mods/VTK/version.txt README.md
git commit -m "chore: release 5.1.1 (smooth season transitions)"
```
(Only if the user approved committing.)

- [ ] **Step 6: Manual in-game check (user)**

Start a Dynamic run with a low `Days per season` (e.g. 1) and watch a season change:
- The tint eases over ~8 s; there is no pop.
- Winter fades back to the vanilla green, then the next season fades in.
- After a map transition, the tint is still correct.
If the tempo feels off, adjust `TRANSITION_SECS` in `VTKSeasonDriver.gd` and rebuild (Task 4 Step 4).

---

## Self-Review

**Spec coverage:**
- Time-based crossfade in the driver → Task 2.
- Hardcoded `TRANSITION_SECS = 8.0`, first apply instant, restore instant → Task 2 (`set_season` branch).
- Driven from `VTKHooks._process` → Task 3.
- `on_world_ready` re-binds air during a fade → Task 2 Step 5.
- Pure `blend` + headless test → Task 1.
- Version 5.1.1 + CHANGELOG + stands + pack/copy → Task 5.
- Restore on disable stays instant → Task 2 `set_season` `not _visuals` branch + `restore()`.

**Bug fix coverage:**
- Dynamic mode survives a death restart → Task 4 (`_resolve_start_season` returns `DYNAMIC_SEASON` when `_dyn_enabled`), regression test `t_dynamic_restart_stays_dynamic`.

**Placeholder scan:** none — every step carries real code or an exact command.

**Type consistency:**
- `blend(a: Color, b: Color, t: float) -> Color` used identically in Tasks 1 and 2.
- `tick(delta: float) -> void` defined in Task 2, called in Task 3.
- `set_season`, `on_world_ready`, `restore` signatures unchanged.
- `_air_pairs`, `_air_pair`, `_set_air_value`, `_air_entries_clear_and_fill`, `_restore_air_all`, `_begin_fade`, `_add_fade_mat`, `_cancel_fade` are all defined in Task 2 Step 4 and used only in Task 2.
