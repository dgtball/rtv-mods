# Drop Fallback Death UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the 20-second fallback death panel from VTKHooks.gd and ship it as v4.8.3.

**Architecture:** Single-file behavioral change in `loadouts/mods/VTK/VTKHooks.gd`: after `DEATH_FIND_TIMEOUT_MS` with no vanilla "Load Game" button found, log one warning, set `_death_gave_up = true` and stop scanning; the vanilla Death screen handles itself. The flag resets when the death screen clears. All fallback-only code (`_build_fallback_panel`, `_on_menu_pressed`, `_on_quit_pressed`, `_death_restart_btn`) is deleted. `layout_check.py` gains a VTKHooks.gd scan so the deleted symbols cannot silently return.

**Tech Stack:** GDScript (Godot 4.6.3), PowerShell stand (`check.ps1`), Python (`.check/layout_check.py`), Metro Mod Loader packaging (`pack.ps1`).

## Global Constraints

- Working tree already contains the user's in-flight v4.8.2 work in the same files (`VTKHooks.gd`, `VTKFeed.gd`, version files). Do NOT touch `VTKFeed.gd`. Preserve all existing lines in `VTKHooks.gd` except the deletions listed in Task 2.
- Version source of truth: `loadouts/mod.txt`. `pack.ps1` derives `loadouts/mods/VTK/version.txt` and the README header from it automatically — never edit those by hand.
- Repo publishes **only** `loadouts/`, `assets/`, `README.md`, `LICENSE`, `.gitignore`. `docs/superpowers/plans/` is NOT committed.
- Indentation: tabs only. Keep encoding UTF-8.
- Fallback symbols must appear exactly once elsewhere: `layout_check.py` HOOKS_GONE.
- Test stand: `.check/project/tests/` is a copy area; edit sources `D:\RTVMOD\.check\project\tests\test_hooks.gd` — check.ps1 copies nothing into tests, tests are edited in place.
- Gate before packing: `python .check\layout_check.py` exit 0 AND `.check\check.ps1` green (exit 0, "Parse check passed", "Tests passed").

---

### Task 1: RED test for give-up behavior

**Files:**
- Modify: `D:\RTVMOD\.check\project\tests\test_hooks.gd`

**Interfaces:**
- Consumes: `TestHooks.new()` (extends VTKHooks), `_handle_death_screen(gd, is_dead, is_ironman)`, `_death_find_since`, `_death_gave_up`, `_death_load_btn`
- Produces: nothing (test-only)

- [ ] **Step 1: Add the test function and call it from `_run()`**

In `_run()` (line 57) add `t_death_timeout_gives_up()` before `t_ironman_restart_restores_difficulty()`.

Append at end of file (after `FakeRig`):

```gdscript
# После удаления фолбек-панели: если ванильная "Load Game" не нашлась за
# DEATH_FIND_TIMEOUT_MS, мод пишет одно предупреждение и дальше не вмешивается,
# а когда экран смерти уходит — готов сканировать заново.
func t_death_timeout_gives_up() -> void:
	var h = TestHooks.new()
	root.add_child(h)
	var ds := Node.new()
	ds.name = "Death"
	root.add_child(ds)
	var gd := FakeGD.new()

	h._handle_death_screen(gd, true, true)
	ck(not h._death_gave_up, "до таймаута фолбек-флаг не поднят")
	h._death_find_since = Time.get_ticks_msec() - 30000
	h._handle_death_screen(gd, true, true)
	ck(h._death_gave_up, "после таймаута дальнейший поиск отключён")
	ck(h._death_load_btn == null, "ванильная кнопка не тронута")

	h._handle_death_screen(gd, false, false)
	ck(not h._death_gave_up, "уход экрана смерти сбрасывает флаг для следующего забега")

	ds.free()
	h.queue_free()
```

- [ ] **Step 2: Run the test, verify it FAILS**

Run:
```powershell
& "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe" --headless --path "D:\RTVMOD\.check\project" --script res://tests/test_hooks.gd
```
Expected: RED — `h._death_gave_up` has no member yet → `SCRIPT ERROR: Invalid get index` (or similar), no "Hooks tests passed", exit != 0. Exit/marks may be: `Hooks tests failed` or a SCRIPT ERROR, either is a valid FAIL.

### Task 2: Implement give-up + remove fallback in VTKHooks.gd

**Files:**
- Modify: `D:\RTVMOD\loadouts\mods\VTK\VTKHooks.gd`

**Interfaces:**
- Consumes: existing `_handle_death_screen`, `_death_scene_root`, `_find_load_button`, `_repurpose_load_button`, `_restore_load_button`, `_dump_death_tree`, `DEATH_FIND_TIMEOUT_MS`, `_death_find_since`
- Produces: new state `_death_gave_up: bool`; removed symbols `_death_restart_btn`, `_build_fallback_panel`, `_on_menu_pressed`, `_on_quit_pressed`

- [ ] **Step 1: Replace the state-variable block (lines 24-40)**

Old:
```gdscript
# The death screen ships its own "Load Game" button: live in a normal run,
# greyed out under permadeath. We borrow that button instead of stacking our own
# panel on top of it, and hand the original text/state/connections back when the
# screen goes away. A null button here means the fallback panel is in use.
var _death_load_btn = null
var _death_load_bound = null
var _death_load_orig_text: String = ""
var _death_load_orig_disabled: bool = false
var _death_load_orig_conns: Array = []

# Death.tscn is mounted asynchronously behind Loader's FadeInLoading, so on the
# first frames after death there is no button to borrow yet. Give the scene time
# to appear before committing to the fallback panel.
const DEATH_FIND_TIMEOUT_MS := 20000
var _death_find_since: int = 0
var _death_dump_at: int = 0
var _death_probe_at: int = 0
```

New (also delete `var _death_restart_btn = null` from line 18):
```gdscript
# The death screen ships its own "Load Game" button: live in a normal run,
# greyed out under permadeath. We borrow that button instead of stacking our own
# panel on top of it, and hand the original text/state/connections back when the
# screen goes away.
var _death_load_btn = null
var _death_load_bound = null
var _death_load_orig_text: String = ""
var _death_load_orig_disabled: bool = false
var _death_load_orig_conns: Array = []

# Death.tscn mounts asynchronously behind Loader's FadeInLoading, so the button
# may take a few frames to appear. Give it up to DEATH_FIND_TIMEOUT_MS, then
# leave the vanilla screen alone (single warning) instead of stacking our own UI.
const DEATH_FIND_TIMEOUT_MS := 20000
var _death_find_since: int = 0
var _death_gave_up: bool = false
var _death_dump_at: int = 0
var _death_probe_at: int = 0
```

- [ ] **Step 2: Cleanup branch — drop `_death_restart_btn`, reset `_death_gave_up`**

In `_handle_death_screen`, replace the cleanup branch (lines 434-444):
```gdscript
	if not is_dead or not is_ironman:
		if _death_restart_btn != null and is_instance_valid(_death_restart_btn):
			_death_restart_btn.queue_free()
			_death_restart_btn = null
		_restore_load_button()
		_death_find_since = 0
		_death_is_ironman = false
```
with:
```gdscript
	if not is_dead or not is_ironman:
		_restore_load_button()
		_death_find_since = 0
		_death_gave_up = false
		_death_is_ironman = false
```

- [ ] **Step 3: Ironman branch — drop overlay guard, restructure timeout**

Replace lines 446-475 (from `if _death_restart_btn ...` through `_build_fallback_panel(gd, root)`):
```gdscript
	if _death_load_btn != null and is_instance_valid(_death_load_btn):
		return

	_death_is_ironman = is_ironman
	var now := Time.get_ticks_msec()
	if _death_find_since == 0:
		_death_find_since = now
		print("[VTK] death screen tracking started @" + str(now))

	# Only ever touch the Death scene. Walking the root re-found a dozen
	# unrelated buttons ("Continue to Main Menu", JCM, the Settings tree) and
	# buried the real one under hundreds of MCM lines.
	var root := _death_scene_root()
	if root == null:
		return

	var load_btn := _find_load_button(root)
	if load_btn != null:
		_repurpose_load_button(load_btn, gd, root)
		return

	if _death_gave_up:
		return

	var waited := now - _death_find_since
	if waited >= DEATH_FIND_TIMEOUT_MS:
		_death_gave_up = true
		print("[VTK] No 'Load Game' button after " + str(waited) + "ms; leaving vanilla death screen")
		return
	_dump_death_tree(root, waited, now)
```

- [ ] **Step 4: Delete `_build_fallback_panel` and add reset in `_on_restart_pressed`**

Delete the whole `func _build_fallback_panel(gd, root) -> void:` block (old lines 560-600).

In `_on_restart_pressed`, replace lines 634-639:
```gdscript
	if _death_restart_btn != null and is_instance_valid(_death_restart_btn):
		_death_restart_btn.queue_free()
		_death_restart_btn = null
	_death_load_btn = null
	_death_load_bound = null
	_death_load_orig_conns = []
```
with:
```gdscript
	_death_load_btn = null
	_death_load_bound = null
	_death_load_orig_conns = []
	_death_gave_up = false
```

- [ ] **Step 5: Delete `_on_menu_pressed` and `_on_quit_pressed`**

Delete both functions at the end of the file (old lines 692-706):
```gdscript
func _on_menu_pressed() -> void: ...
func _on_quit_pressed() -> void: ...
```

- [ ] **Step 6: Run the full stand — verify GREEN**

Run:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File D:\RTVMOD\.check\check.ps1
```
Expected: "Parse check passed: 10 scripts", including `test_hooks.gd` — "Hooks tests passed", "Tests passed: 4 file(s)". (test_draft, test_picker, test_feed must stay green.)

- [ ] **Step 7: Commit — DEFERRED to Task 4**

`VTKHooks.gd` mixes the user's in-flight explosion-hook edits with the death change in one file; a file-level `git add` cannot split them. The whole `VTKHooks.gd` + `test_hooks.gd` pair ships in the single v4.8.3 release commit (Task 4 Step 4). Do not commit here.

### Task 3: Extend layout_check.py with a VTKHooks scan

**Files:**
- Modify: `D:\RTVMOD\.check\layout_check.py`
- Modify: `D:\RTVMOD\AGENTS.md` (one sentence)

**Interfaces:**
- Consumes: existing GONE/PRESENT/FUNCS flow for `VTKUI.gd`
- Produces: new `HOOKS_GONE` list scanned against `loadouts/mods/VTK/VTKHooks.gd`; guard against fallback-UI resurrection

- [ ] **Step 1: Add second-file scan**

After the `UI` constant add:

```python
HOOKS = r"D:\RTVMOD\loadouts\mods\VTK\VTKHooks.gd"

# Death-screen fallback UI was removed in v4.8.3: Restart/Main Menu/Quit panel
# that appeared after 20 s of waiting for the vanilla "Load Game" button.
HOOKS_GONE = [
    "_build_fallback_panel",
    "_on_menu_pressed",
    "_on_quit_pressed",
    "_death_restart_btn",
]
```

In `main()`, right after the UI FUNCS loop, add:

```python
    hooks = io.open(HOOKS, encoding="utf-8").read()
    for s in HOOKS_GONE:
        n = hooks.count(s)
        if n:
            bad += 1
            print("  HOOKS-GONE %-34s встречается %d раз" % (esc(s), n))
```

And reflect counts in the summary line:
```python
    print("GONE: %d, GONE_RE: %d, PRESENT: %d, FUNCS: %d, HOOKS_GONE: %d"
          % (len(GONE), len(GONE_RE), len(PRESENT), len(FUNCS), len(HOOKS_GONE)))
```

- [ ] **Step 2: Run layout check**

Run: `& "C:\Users\home\AppData\Local\Programs\Python\Python312\python.exe" D:\RTVMOD\.check\layout_check.py`
Expected: exit 0, summary line starts `GONE:` and ends `HOOKS_GONE: 4`, and "RESULT: символы раскладки на месте".

- [ ] **Step 3: AGENTS.md — note the second scan**

In the `.check\layout_check.py` bullet, append: ` С 4.8.3 стенд дополнительно сканирует VTKHooks.gd (`HOOKS_GONE` — удалённая фолбек-панель смерти).`

- [ ] **Step 4: Commit — CANCELLED**

`.check/` and `AGENTS.md` are intentionally untracked: the repo's `.gitignore` is `/*` with only `loadouts/`, `assets/`, `README.md`, `LICENSE`, `.gitignore` as exceptions. They stay local dev tooling (consistent with the plan's Global Constraints).

### Task 4: Version 4.8.3, gate, pack, release

**Files:**
- Modify: `D:\RTVMOD\loadouts\mod.txt` (`version="4.8.2"` → `version="4.8.3"`)
- Regenerated by pack: `loadouts/mods/VTK/version.txt`, README header
- Release: `Loadouts.vmz` → game mods folder + GitHub release `v4.8.3`

- [ ] **Step 1: Bump version in mod.txt**

Edit `D:\RTVMOD\loadouts\mod.txt`: `version="4.8.2"` → `version="4.8.3"` (single line, keep no trailing newline as-is).

- [ ] **Step 2: Run the gate**

1. `& "C:\Users\home\AppData\Local\Programs\Python\Python312\python.exe" D:\RTVMOD\.check\layout_check.py` → exit 0.
2. `powershell -NoProfile -ExecutionPolicy Bypass -File D:\RTVMOD\.check\check.ps1` → "Tests passed: 4 file(s)", exit 0.

- [ ] **Step 3: Pack and deploy**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File D:\RTVMOD\pack.ps1
```
Expected: "Version in mod.txt: 4.8.3", version.txt + README synced, "Pack done: D:\RTVMOD\Loadouts.vmz".

Copy: `Copy-Item "D:\RTVMOD\Loadouts.vmz" "D:\SteamLibrary\steamapps\common\Road to Vostok\mods\Loadouts.vmz" -Force`

- [ ] **Step 4: Commit everything (user's feed work + release)**

```powershell
git add -A
git commit -m "Explosion kill feed, rig weapon names, drop fallback death UI (v4.8.3)"
git push
```

- [ ] **Step 5: GitHub release**

```powershell
gh release create v4.8.3 D:\RTVMOD\Loadouts.vmz --title "Vostok Toolkit 4.8.3" --notes "Fallback death panel removed; ironman restart now relies on the vanilla Load Game button."
```
Expected: release URL.