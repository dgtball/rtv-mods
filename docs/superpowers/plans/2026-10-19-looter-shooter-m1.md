# LooterShooter M1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the Milestone-1 skeleton of the `LooterShooter` mod: a standalone Road to Vostok mod that tags weapon/clothing loot with a per-instance rarity tier and affixes, shows them as a colored cell border + tooltip block, and exposes a debug mode — with headless tests for all pure logic.

**Architecture:** A standalone mod under `standalone mods/LooterShooter/` with a `LSHBoot` autoload that registers runtime hooks via the modloader's `RTVModLib`. Loot is tagged at `LootContainer.CreateLoot` (post) and `LootContainer.AILoot` (post) through a single accessor module (`LSHStore`). Affix data lives in `LSHPool`; selection/values in the pure module `LSHRoll`; item category in the pure module `LSHCategory`. Display uses the ItemClarity pattern (`node_added` + full-tree scan) for borders and a `Tooltip.Update` post hook for the affix block. An extended `SlotData` (`[script_extend]`) carries the two fields and re-implements `Update()`/`Reset()` so they survive every clone path.

**Tech Stack:** GDScript (Godot 4.6.3), Road to Vostok modloader v3.4.2 (`RTVModLib` runtime hooks, `[script_extend]`), Mod Configuration Menu 2.9.3 (optional dependency), PowerShell (`pack.ps1`, `.check/check.ps1`), Python (`layout_check.py`).

## Global Constraints

- Target engine: **Godot 4.6.3** (the `.check` stand runs `godot --headless`).
- `.gd` files: **UTF-8, tabs for indentation, no trailing whitespace**.
- New internal UI/notification strings are **English literals** (the game's language); no `Loc`/translation layer in M1.
- Do **not** localize vanilla item names, types, or rarity words.
- Every runtime-hook callback arity must match the modloader rule: **void target → `args.size()` params; non-void target → `args.size() + 1` params** (last is `_result`). A mismatch is a silent no-op in Godot 4.6.3.
- Mod id for MCM registration: `"lootershooter"`. Loader `[mod] id`: `"looter-shooter"`. Scripts prefix: `LSH`.
- MCM is an **optional** dependency; every MCM call is guarded (`ResourceLoader.exists` + `has_method`), the mod must work with MCM absent.
- `RTVModLib` is fetched from `Engine.get_meta("RTVModLib")`; if missing, hooks do not register and the mod must degrade silently (only a log line).
- Vanilla `SlotData.Update()` copies **11** fields and skips `gridPosition`/`gridRotated`/`slot` (verbatim in Task 2). The extension must copy `loot_tier`/`loot_affixes` in `Update()` and clear them in `Reset()`.
- Container `loot` is **not persisted** — only `storage` is (see `Loader.gd:763-777`). Un-taken loot re-rolls on reload; this is intended (documented in README, Task 12).
- Hook wrap surface comes from `mod.txt [hooks]` (plus literal `.hook("...")` scans). Registering a name at runtime without a declaration will never fire.
- Do not modify files outside `standalone mods/LooterShooter/` except for the three explicitly listed shared files (`.check/check.ps1`, `docs/superpowers/plans/…`, and the `README`/`CHANGELOG` inside the mod).
- Commit after every task; commit messages follow the repo style (`feat(lsh): …`, `test(lsh): …`, `chore(lsh): …`).

## File Structure

| File | Responsibility |
|---|---|
| `standalone mods/LooterShooter/mod.txt` | Loader manifest: mod id/version, autoload, `[hooks]` declarations, optional MCM dependency |
| `standalone mods/LooterShooter/pack.ps1` | Build `LooterShooter.vmz` (mirror of ThermalVTK's packer, `$src = $PSScriptRoot`) |
| `standalone mods/LooterShooter/README.md` | Install, save warning, compatibility, debug mode |
| `standalone mods/LooterShooter/CHANGELOG.md` | Player-facing changelog |
| `.../mods/LooterShooter/LSHBoot.gd` | Autoload: init, lib hookup, hook registration, dispatch to Roll/Store/Display/Debug |
| `.../mods/LooterShooter/LSHConfig.gd` | Typed slice of MCM config (12 fields) + `read(cfg)` |
| `.../mods/LooterShooter/LSHPool.gd` | Affix pool data + validation (stat, category, tier ranges, unit, weight) |
| `.../mods/LooterShooter/LSHRoll.gd` | Pure roll math: context→tier weights, tier→N affixes, tier→value |
| `.../mods/LooterShooter/LSHCategory.gd` | Pure `resource_path`/`itemData` → category (`weapon`/`clothing`/`other`) |
| `.../mods/LooterShooter/LSHStore.gd` | The only code that reads/writes `loot_tier`/`loot_affixes` |
| `.../mods/LooterShooter/LSHDisplay.gd` | Cell border overlay + tooltip affix block + `node_added` tracking |
| `.../mods/LooterShooter/LSHDebug.gd` | Force tier, reroll hovered item, debug log |
| `.../mods/LooterShooter/Scripts/SlotData.gd` | `[script_extend]` override of `res://Scripts/SlotData.gd` |
| `.check/check.ps1` | (modified) copy + parse-check + test-run the new mod |
| `.check/project/tests/test_lsh_*.gd` | Six headless tests |

Dependency order: `LSHPool` → `LSHRoll` → (`LSHCategory`, `LSHStore`) → (`LSHConfig`, `LSHDebug`) → `LSHDisplay` → `LSHBoot`. `SlotData.gd` stands alone.

---

### Task 1: Mod skeleton — manifest, packer, README, autoload stub

**Files:**
- Create: `standalone mods/LooterShooter/mod.txt`
- Create: `standalone mods/LooterShooter/pack.ps1`
- Create: `standalone mods/LooterShooter/README.md`
- Create: `standalone mods/LooterShooter/CHANGELOG.md`
- Create: `standalone mods/LooterShooter/mods/LooterShooter/LSHBoot.gd`
- Test: manual — the new `.check` parse step in Task 8 covers it from Task 2 onward

**Interfaces:**
- Consumes: nothing.
- Produces:
  - Autoload node name **`LSH`** (path `res://mods/LooterShooter/LSHBoot.gd`).
  - Hook names declared in `[hooks]`: `lootcontainer-createloot-post`, `lootcontainer-ailoot-post`, `tooltip-update-post`.
  - `LSHBoot.has_method("reroll_item") -> bool` (used by `LSHDisplay._input` in Task 10 — declared here as a stub).

- [ ] **Step 1: Write `mod.txt`**

`standalone mods/LooterShooter/mod.txt`:

```ini
[mod]
name="LooterShooter"
id="looter-shooter"
version="0.1.0"

[autoload]
LSH="res://mods/LooterShooter/LSHBoot.gd"

[hooks]
res://Scripts/LootContainer.gd = CreateLoot, AILoot
res://Scripts/Tooltip.gd = Update

[dependencies]
optional=["doinkoink-mcm"]

[updates]
source=""
```

- [ ] **Step 2: Write `pack.ps1`**

Copy `standalone mods/ThermalVTK/pack.ps1` verbatim, then replace the three occurrences of `ThermalVTK` and the temp prefix:

- `$OutFile = Join-Path $PSScriptRoot "ThermalVTK.vmz"` → `".../LooterShooter.vmz"`
- `Join-Path $src "mods\ThermalVTK\version.txt"` → `Join-Path $src "mods\LooterShooter\version.txt"`
- Write-Host label `mods/ThermalVTK/version.txt` → `mods/LooterShooter/version.txt`
- `("thermalvtk_" + [guid]::NewGuid()...` → `("lootershooter_" + [guid]::NewGuid()...`

Everything else (version regex, README sync, entry filter, zip mechanics) stays identical.

- [ ] **Step 3: Write `README.md`**

`standalone mods/LooterShooter/README.md`:

```markdown
# LooterShooter

**Version:** 0.1.0

Standalone loot-rarity mod for Road to Vostok. Weapons and clothing found in
containers and on bodies roll a per-instance rarity tier with passive affixes.

> **Do not remove this mod from an existing save.** It stores two extra fields
> on every item. Removing the mod makes the game drop those values.

## What it does

- Every weapon and piece of clothing you find rolls a rarity: Common (blue),
  Rare (purple) or Legendary (gold).
- Rarer items carry more passive affixes (Common 1, Rare 2, Legendary 3).
- Affixes show in the item tooltip; the cell border is tinted by rarity.
- Military and elite containers shift the odds upward.

## Install

1. Copy `LooterShooter.vmz` into the game's `mods` folder.
2. Mod Configuration Menu is optional, but recommended for the debug tools.

## Debug (for testing)

Enable "Debug mode" in the MCM menu: force a rarity tier for all finds, or
re-roll the item under the cursor with the debug hotkey.

## Build (from the repo)

```powershell
powershell -ExecutionPolicy Bypass -File pack.ps1
```
```

- [ ] **Step 4: Write `CHANGELOG.md`**

`standalone mods/LooterShooter/CHANGELOG.md`:

```markdown
# Changelog

## [0.1.0] - 2026-10-19

### Added
- Weapons and clothing found in containers and on bodies now roll a rarity tier.
- Rarity tiers (Common, Rare, Legendary) carry one to three passive affixes.
- Rarity is shown as a tinted border on the item cell and a line in the tooltip.
- Debug mode: force a rarity tier, or re-roll the hovered item.

## [Unreleased]
```

- [ ] **Step 5: Write `LSHBoot.gd` (stub)**

`standalone mods/LooterShooter/mods/LooterShooter/LSHBoot.gd`:

```gdscript
extends Node

const Log = preload("res://mods/LooterShooter/LSHLog.gd")

var _lib = null

func _ready() -> void:
	Log.line("booted")

func reroll_item(_item) -> bool:
	return false
```

- [ ] **Step 6: Write `LSHLog.gd`**

`standalone mods/LooterShooter/mods/LooterShooter/LSHLog.gd`:

```gdscript
extends RefCounted

const PREFIX := "[LSH] "

static func line(msg: String) -> void:
	print(PREFIX + msg)

static func warn(msg: String) -> void:
	push_warning(PREFIX + msg)
```

- [ ] **Step 7: Verify the packer builds an archive**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File "standalone mods\LooterShooter\pack.ps1"
```

Expected: prints `Version in mod.txt: 0.1.0`, writes `mods/LooterShooter/version.txt`, then `Pack done: …\LooterShooter.vmz (4 entries, … KB)`. The entries are `mod.txt`, `mods/LooterShooter/LSHBoot.gd`, `mods/LooterShooter/LSHLog.gd`, `mods/LooterShooter/version.txt`.

- [ ] **Step 8: Commit**

```bash
git add "standalone mods/LooterShooter"
git commit -m "feat(lsh): mod skeleton (manifest, packer, autoload stub)"
```

---

### Task 2: Extended `SlotData` with carried fields

**Files:**
- Create: `standalone mods/LooterShooter/mods/LooterShooter/Scripts/SlotData.gd`
- Modify: `standalone mods/LooterShooter/mod.txt` (add `[script_extend]`)
- Test: `.check/project/tests/test_lsh_slotdata.gd`, plus `.check/project/stubs/SlotData.gd` gains the two fields (global class must expose them because the stand compiles the override against the stub)

**Interfaces:**
- Consumes: nothing.
- Produces: on every `SlotData` instance — `loot_tier: int` (default `0`) and `loot_affixes: Array` (default `[]`). `Update()` copies both; `Reset()` clears both.

- [ ] **Step 1: Extend the stand stub**

Modify `.check/project/stubs/SlotData.gd` — append two fields to the existing stub:

```gdscript
class_name SlotData
extends RefCounted

# Заглушка игрового класса SlotData: нужен только чтобы godot --check-only
# не спотыкался об отсутствующий в стенде class_name.

var itemData = null
var amount: int = 1
var chamber: bool = false
var nested: Array = []
var loot_tier: int = 0
var loot_affixes: Array = []
```

Also add the real `Update`/`Reset` shape to the stub so the override's `super.Update()` resolves and can be tested headlessly:

```gdscript
var condition = 100
var position = 0
var mode = 1
var zoom = 1
var casing = false
var state: String = ""
var storage: Array = []

func Update(slotData) -> void:
	itemData = slotData.itemData
	nested = slotData.nested.duplicate()
	storage = slotData.storage.duplicate()
	condition = slotData.condition
	amount = slotData.amount
	position = slotData.position
	mode = slotData.mode
	zoom = slotData.zoom
	chamber = slotData.chamber
	casing = slotData.casing
	state = slotData.state

func Reset() -> void:
	itemData = null
	nested.clear()
	storage.clear()
	condition = 100
	amount = 0
	position = 0
	mode = 1
	zoom = 1
	chamber = false
	casing = false
	state = ""
```

- [ ] **Step 2: Write the failing test**

`.check/project/tests/test_lsh_slotdata.gd`:

```gdscript
extends SceneTree

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _init() -> void:
	var SD = load("res://mods/LooterShooter/Scripts/SlotData.gd")
	ck(SD != null, "override script loads")

	var a = SD.new()
	ck(a.loot_tier == 0, "loot_tier default 0")
	ck(a.loot_affixes.is_empty(), "loot_affixes default empty")

	a.loot_tier = 3
	a.loot_affixes = [{"stat": "damage", "value": 0.2}]
	a.condition = 55
	a.amount = 7

	var b = SD.new()
	b.Update(a)
	ck(b.loot_tier == 3, "Update copies loot_tier")
	ck(b.loot_affixes.size() == 1, "Update copies loot_affixes")
	ck(b.loot_affixes[0]["stat"] == "damage", "Update copies affix payload")
	ck(b.condition == 55 and b.amount == 7, "super.Update still copies vanilla fields")

	b.Reset()
	ck(b.loot_tier == 0, "Reset clears loot_tier")
	ck(b.loot_affixes.is_empty(), "Reset clears loot_affixes")
	ck(b.condition == 100 and b.amount == 0, "super.Reset still resets vanilla fields")

	print("")
	if fails == 0:
		print("LSH SlotData tests passed")
		quit(0)
	else:
		print("LSH SlotData tests failed: ", fails)
		quit(1)
```

- [ ] **Step 3: Run test to verify it fails**

Add the test to `.check/check.ps1` `$tests` now (see Task 8 for the full stand wiring), then run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```

Expected: FAIL — `res://mods/LooterShooter/Scripts/SlotData.gd` does not exist, and the stand aborts at the "Test script missing" guard or reports `Failed to load script`.

- [ ] **Step 4: Write minimal implementation**

`standalone mods/LooterShooter/mods/LooterShooter/Scripts/SlotData.gd`:

```gdscript
extends "res://Scripts/SlotData.gd"

@export var loot_tier: int = 0
@export var loot_affixes: Array = []

func Update(slotData) -> void:
	super.Update(slotData)
	loot_tier = slotData.loot_tier
	loot_affixes = slotData.loot_affixes.duplicate(true)

func Reset() -> void:
	super.Reset()
	loot_tier = 0
	loot_affixes.clear()
```

Add to `mod.txt`:

```ini
[script_extend]
res://Scripts/SlotData.gd = "res://mods/LooterShooter/Scripts/SlotData.gd"
```

- [ ] **Step 5: Run test to verify it passes**

Run the stand (Task 8 wiring is in place by now):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```

Expected: `ok    res://mods/LooterShooter/Scripts/SlotData.gd` in the parse phase, and `LSH SlotData tests passed`.

- [ ] **Step 6: Commit**

```bash
git add "standalone mods/LooterShooter" ".check/project/stubs/SlotData.gd" ".check/project/tests/test_lsh_slotdata.gd" ".check/check.ps1"
git commit -m "feat(lsh): extend SlotData with loot_tier/loot_affixes"
```

---

### Task 3: Affix pool data

**Files:**
- Create: `standalone mods/LooterShooter/mods/LooterShooter/LSHPool.gd`
- Test: `.check/project/tests/test_lsh_pool.gd`

**Interfaces:**
- Consumes: nothing.
- Produces (static API on `LSHPool`):
  - `const VANILLA := 0`, `COMMON := 1`, `RARE := 2`, `LEGENDARY := 3`
  - `const TIER_NAMES := {0: "Vanilla", 1: "Common", 2: "Rare", 3: "Legendary"}`
  - `static func entries(category: String) -> Array` — every pool entry whose `category` matches (`"weapon"` or `"clothing"`)
  - `static func affix_ids(category: String) -> Array` — sorted list of distinct `stat` strings
  - `static func entry(category: String, stat: String) -> Dictionary` — the record, or `{}`
  - `static func validate() -> Array` — list of human-readable problem strings (empty = valid)
  - Entry shape: `{"stat": String, "category": String, "unit": String, "weight": float, "ranges": Dictionary}` where `ranges` maps tier int → `[min, max]` (a tier absent from `ranges` means "not rolled at this tier").

- [ ] **Step 1: Write the failing test**

`.check/project/tests/test_lsh_pool.gd`:

```gdscript
extends SceneTree

const Pool = preload("res://mods/LooterShooter/LSHPool.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _init() -> void:
	ck(Pool.validate().is_empty(), "pool passes validation: " + str(Pool.validate()))

	var w: Array = Pool.affix_ids("weapon")
	ck(w.size() == 7, "7 weapon affixes")
	for need in ["damage", "recoil", "sway", "fire_rate", "penetration", "low_hp_damage", "durability"]:
		ck(w.has(need), "weapon pool has " + need)

	var c: Array = Pool.affix_ids("clothing")
	ck(c.size() == 12, "12 clothing affixes")
	for need in ["max_hp", "regen", "low_hp_regen", "carry", "stamina_drain", "insulation",
			"noise", "sprint", "protection", "thirst_drain", "hunger_drain", "sanity_drain"]:
		ck(c.has(need), "clothing pool has " + need)

	var d: Dictionary = Pool.entry("weapon", "damage")
	ck(d["category"] == "weapon", "damage entry category")
	ck(d["ranges"][1] == [5, 15], "damage common range 5..15 as fractions")
	ck(d["ranges"][3] == [15, 30], "damage legendary range 15..30")

	var pen: Dictionary = Pool.entry("weapon", "penetration")
	ck(not pen["ranges"].has(1), "penetration not rolled at Common")
	ck(pen["ranges"][2] == [1, 1], "penetration rare flat +1")
	ck(pen["ranges"][3] == [1, 2], "penetration legendary +1..2")

	var rare_ids: Array = []
	for id in Pool.affix_ids("weapon"):
		var e: Dictionary = Pool.entry("weapon", id)
		if e["ranges"].has(2):
			rare_ids.append(id)
	ck(rare_ids.size() >= 2, "at least two weapon affixes are rollable at Rare")

	var hp: Dictionary = Pool.entry("clothing", "max_hp")
	ck(hp["ranges"][3] == [15, 50], "max_hp legendary 15..50")

	ck(Pool.entry("weapon", "nope").is_empty(), "unknown stat returns empty")
	ck(Pool.entry("weapon", "regen").is_empty(), "clothing stat not in weapon pool")

	print("")
	if fails == 0:
		print("LSH Pool tests passed")
		quit(0)
	else:
		print("LSH Pool tests failed: ", fails)
		quit(1)
```

Note on units: all percentage ranges are stored as **fractions** (`5` means 5 percentage points → `0.05` at roll time only for `damage` etc.; `penetration`/`protection` are stored as their final flat integers; `regen` is stored as HP/sec directly). To keep the pool honest, `damage/recoil/sway/fire_rate/low_hp_damage/durability/stamina_drain/insulation/noise/sprint/thirst_drain/hunger_drain/sanity_drain` store **percentage points as whole numbers** (5..30) and are divided by 100 at roll time; `max_hp` is whole HP, `carry` whole kg, `penetration`/`protection` flat ints, `regen` HP/sec float, `low_hp_regen` a multiplier float. The `unit` field records which: `"pct"`, `"hp"`, `"kg"`, `"flat"`, `"rate"`, `"mult"`.

- [ ] **Step 2: Run test to verify it fails**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```

(Ensure `"res://tests/test_lsh_pool.gd"` is in `$tests` — Task 8.) Expected: FAIL, `Failed to load script` for `LSHPool.gd`.

- [ ] **Step 3: Write minimal implementation**

`standalone mods/LooterShooter/mods/LooterShooter/LSHPool.gd`:

```gdscript
extends RefCounted

const VANILLA := 0
const COMMON := 1
const RARE := 2
const LEGENDARY := 3

const TIER_NAMES := {0: "Vanilla", 1: "Common", 2: "Rare", 3: "Legendary"}

const POOL: Array = [
	{"stat": "damage", "category": "weapon", "unit": "pct", "weight": 1.0,
		"ranges": {1: [5, 15], 2: [10, 20], 3: [15, 30]}},
	{"stat": "recoil", "category": "weapon", "unit": "pct", "weight": 1.0,
		"ranges": {1: [8, 15], 2: [12, 22], 3: [18, 30]}},
	{"stat": "sway", "category": "weapon", "unit": "pct", "weight": 1.0,
		"ranges": {1: [10, 20], 2: [15, 30], 3: [20, 40]}},
	{"stat": "fire_rate", "category": "weapon", "unit": "pct", "weight": 0.8,
		"ranges": {1: [5, 10], 2: [8, 14], 3: [10, 20]}},
	{"stat": "penetration", "category": "weapon", "unit": "flat", "weight": 0.6,
		"ranges": {2: [1, 1], 3: [1, 2]}},
	{"stat": "low_hp_damage", "category": "weapon", "unit": "pct", "weight": 0.7,
		"ranges": {1: [15, 25], 2: [25, 35], 3: [35, 50]}},
	{"stat": "durability", "category": "weapon", "unit": "pct", "weight": 0.8,
		"ranges": {1: [25, 40], 2: [40, 55], 3: [55, 75]}},

	{"stat": "max_hp", "category": "clothing", "unit": "hp", "weight": 1.0,
		"ranges": {1: [5, 10], 2: [10, 20], 3: [15, 50]}},
	{"stat": "regen", "category": "clothing", "unit": "rate", "weight": 1.0,
		"ranges": {1: [0.01, 0.02], 2: [0.02, 0.05], 3: [0.04, 0.08]}},
	{"stat": "low_hp_regen", "category": "clothing", "unit": "mult", "weight": 0.5,
		"ranges": {1: [2.0, 2.0], 2: [2.5, 2.5], 3: [3.0, 3.0]}},
	{"stat": "carry", "category": "clothing", "unit": "kg", "weight": 0.9,
		"ranges": {1: [2, 5], 2: [5, 8], 3: [8, 10]}},
	{"stat": "stamina_drain", "category": "clothing", "unit": "pct", "weight": 0.9,
		"ranges": {1: [8, 15], 2: [12, 22], 3: [18, 30]}},
	{"stat": "insulation", "category": "clothing", "unit": "pct", "weight": 0.9,
		"ranges": {1: [10, 20], 2: [20, 30], 3: [30, 40]}},
	{"stat": "noise", "category": "clothing", "unit": "pct", "weight": 0.7,
		"ranges": {1: [10, 20], 2: [15, 30], 3: [20, 40]}},
	{"stat": "sprint", "category": "clothing", "unit": "pct", "weight": 0.8,
		"ranges": {1: [3, 6], 2: [5, 9], 3: [8, 12]}},
	{"stat": "protection", "category": "clothing", "unit": "flat", "weight": 0.5,
		"ranges": {2: [1, 1], 3: [1, 1]}},
	{"stat": "thirst_drain", "category": "clothing", "unit": "pct", "weight": 0.7,
		"ranges": {1: [8, 15], 2: [12, 22], 3: [18, 30]}},
	{"stat": "hunger_drain", "category": "clothing", "unit": "pct", "weight": 0.7,
		"ranges": {1: [8, 15], 2: [12, 22], 3: [18, 30]}},
	{"stat": "sanity_drain", "category": "clothing", "unit": "pct", "weight": 0.5,
		"ranges": {1: [8, 15], 2: [12, 22], 3: [18, 30]}},
]

const UNITS := ["pct", "hp", "kg", "flat", "rate", "mult"]
const CATEGORIES := ["weapon", "clothing"]

static func entries(category: String) -> Array:
	var out: Array = []
	for e in POOL:
		if e["category"] == category:
			out.append(e)
	return out

static func affix_ids(category: String) -> Array:
	var ids: Array = []
	for e in POOL:
		if e["category"] == category and not ids.has(e["stat"]):
			ids.append(e["stat"])
	ids.sort()
	return ids

static func entry(category: String, stat: String) -> Dictionary:
	for e in POOL:
		if e["category"] == category and e["stat"] == stat:
			return e
	return {}

static func validate() -> Array:
	var problems: Array = []
	var seen: Array = []
	for e in POOL:
		var tag: String = str(e.get("category", "?")) + "/" + str(e.get("stat", "?"))
		if not CATEGORIES.has(e.get("category", "")):
			problems.append("bad category: " + tag)
		if e.get("stat", "") == "":
			problems.append("empty stat: " + tag)
		if seen.has(tag):
			problems.append("duplicate: " + tag)
		seen.append(tag)
		if not UNITS.has(e.get("unit", "")):
			problems.append("bad unit: " + tag)
		if float(e.get("weight", 0.0)) <= 0.0:
			problems.append("bad weight: " + tag)
		var ranges: Dictionary = e.get("ranges", {})
		if ranges.is_empty():
			problems.append("no ranges: " + tag)
		for tier in ranges.keys():
			if not [COMMON, RARE, LEGENDARY].has(tier):
				problems.append("bad tier " + str(tier) + ": " + tag)
			var r: Array = ranges[tier]
			if r.size() != 2 or float(r[0]) > float(r[1]):
				problems.append("bad range at tier " + str(tier) + ": " + tag)
	return problems
```

- [ ] **Step 4: Run test to verify it passes**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```

Expected: `LSH Pool tests passed`.

- [ ] **Step 5: Commit**

```bash
git add "standalone mods/LooterShooter/mods/LooterShooter/LSHPool.gd" ".check/project/tests/test_lsh_pool.gd"
git commit -m "feat(lsh): affix pool data with validation"
```

---

### Task 4: Pure roll math

**Files:**
- Create: `standalone mods/LooterShooter/mods/LooterShooter/LSHRoll.gd`
- Test: `.check/project/tests/test_lsh_roll.gd`

**Interfaces:**
- Consumes: `LSHPool` (Task 3) via `preload`.
- Produces (static API on `LSHRoll`):
  - `static func normalize_context(ctx: Dictionary) -> String` → `"default" | "rare" | "corpse" | "joker"`
  - `static func tier_weights(ctx: Dictionary, freq_mult: float, forced: int) -> Array` — 4 floats `[van, common, rare, leg]`; if `forced` is `1..3`, that tier gets weight `1.0` and the rest `0.0`; weights of the rolled tiers are scaled by `freq_mult` before normalizing (Vanilla weight is left as `1.0 - scaled_nonvanilla`, floor 0)
  - `static func pick_tier(weights: Array, r: float) -> int` → `0..3` (`r` in `[0,1)`)
  - `static func affix_count(tier: int) -> int` → `0,1,2,3`
  - `static func build_affixes(category: String, tier: int, rng: RandomNumberGenerator) -> Array` — `[{ "stat": String, "value": float, "unit": String }]`, no repeated stat, uses `LSHPool.entry(...).ranges[tier]`, converts `"pct"` to fraction (`×0.01`), rounds `"flat"`/`"hp"`/`"kg"` to int-as-float
  - `static func format_affix(a: Dictionary) -> String` — English display, e.g. `"+12% Damage"`, `"-18% Recoil`, `"+5 kg Carry`, `"Regen +0.03 HP/s"`, `"+1 Penetration"` (Task 10 uses this)

- [ ] **Step 1: Write the failing test**

`.check/project/tests/test_lsh_roll.gd`:

```gdscript
extends SceneTree

const Roll = preload("res://mods/LooterShooter/LSHRoll.gd")
const Pool = preload("res://mods/LooterShooter/LSHPool.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _init() -> void:
	ck(Roll.normalize_context({}) == "default", "empty ctx -> default")
	ck(Roll.normalize_context({"corpse": true}) == "corpse", "corpse ctx")
	ck(Roll.normalize_context({"joker": true}) == "joker", "joker ctx")
	ck(Roll.normalize_context({"rarity_roll": 10}) == "rare", "low roll -> rare")
	ck(Roll.normalize_context({"rarity_roll": 80}) == "default", "high roll -> default")

	var w: Array = Roll.tier_weights({"rarity_roll": 80}, 1.0, 0)
	ck(is_equal_approx(w[0], 0.60) and is_equal_approx(w[1], 0.30), "default weights van/common")
	ck(is_equal_approx(w[2], 0.09) and is_equal_approx(w[3], 0.01), "default weights rare/leg")

	var forced: Array = Roll.tier_weights({"rarity_roll": 80}, 1.0, 3)
	ck(forced == [0.0, 0.0, 0.0, 1.0], "forced legendary")

	ck(Roll.pick_tier([0.0, 0.0, 0.0, 1.0], 0.99) == 3, "pick legendary")
	ck(Roll.pick_tier([1.0, 0.0, 0.0, 0.0], 0.5) == 0, "pick vanilla")
	ck(Roll.pick_tier([0.0, 1.0, 0.0, 0.0], 0.0) == 1, "zero weight skipped")
	ck(Roll.pick_tier([0.25, 0.25, 0.25, 0.25], 0.9) == 3, "even split picks last bucket past 0.75")

	ck(Roll.affix_count(0) == 0 and Roll.affix_count(1) == 1, "count tier 0/1")
	ck(Roll.affix_count(2) == 2 and Roll.affix_count(3) == 3, "count tier 2/3")

	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var affixes: Array = Roll.build_affixes("weapon", 3, rng)
	ck(affixes.size() == 3, "legendary weapon -> 3 affixes")
	var stats: Array = []
	for a in affixes:
		stats.append(a["stat"])
	check_distinct(stats, "affix stats distinct")
	for a in affixes:
		var e: Dictionary = Pool.entry("weapon", a["stat"])
		ck(not e.is_empty(), "affix in pool: " + a["stat"])
		ck(a["value"] >= 0.0, "value non-negative: " + a["stat"])
	var dmg: Dictionary = Roll.build_affixes_from("weapon", 1, "damage", rng)
	ck(dmg["value"] >= 0.05 and dmg["value"] <= 0.15, "common damage fraction in range")

	var c2: Array = Roll.build_affixes("clothing", 2, rng)
	ck(c2.size() == 2, "rare clothing -> 2 affixes")

	ck(Roll.format_affix({"stat": "damage", "value": 0.12, "unit": "pct"}) == "+12% Damage",
			"format damage +12% Damage")
	ck(Roll.format_affix({"stat": "recoil", "value": -0.18, "unit": "pct"}) == "-18% Recoil",
			"format recoil -18% Recoil")
	ck(Roll.format_affix({"stat": "regen", "value": 0.03, "unit": "rate"}) == "Regen +0.03 HP/s",
			"format regen line")
	ck(Roll.format_affix({"stat": "penetration", "value": 1.0, "unit": "flat"}) == "+1 Penetration",
			"format penetration flat")

	print("")
	if fails == 0:
		print("LSH Roll tests passed")
		quit(0)
	else:
		print("LSH Roll tests failed: ", fails)
		quit(1)

func check_distinct(arr: Array, msg: String) -> void:
	var seen: Array = []
	for x in arr:
		if seen.has(x):
			fails += 1
			print("FAIL  ", msg, " (dup ", x, ")")
			return
		seen.append(x)
	print("ok    ", msg)
```

Note: this test references `Roll.build_affixes_from`, so that helper must exist.

- [ ] **Step 2: Run test to verify it fails**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```

Expected: FAIL, `build_affixes_from` / `LSHRoll.gd` missing.

- [ ] **Step 3: Write minimal implementation**

`standalone mods/LooterShooter/mods/LooterShooter/LSHRoll.gd`:

```gdscript
extends RefCounted

const Pool = preload("res://mods/LooterShooter/LSHPool.gd")

const CONTEXT_WEIGHTS := {
	"default": [0.60, 0.30, 0.09, 0.01],
	"rare":    [0.35, 0.40, 0.20, 0.05],
	"corpse":  [0.45, 0.35, 0.15, 0.05],
	"joker":   [0.15, 0.35, 0.35, 0.15],
}

static func normalize_context(ctx: Dictionary) -> String:
	if bool(ctx.get("joker", false)):
		return "joker"
	if bool(ctx.get("corpse", false)):
		return "corpse"
	var roll: int = int(ctx.get("rarity_roll", 100))
	if roll <= 25:
		return "rare"
	return "default"

static func tier_weights(ctx: Dictionary, freq_mult: float, forced: int) -> Array:
	if forced >= Pool.COMMON and forced <= Pool.LEGENDARY:
		var out := [0.0, 0.0, 0.0, 0.0]
		out[forced] = 1.0
		return out
	var base: Array = CONTEXT_WEIGHTS[normalize_context(ctx)]
	var mul: float = maxf(0.0, freq_mult)
	var scaled := [1.0, base[1] * mul, base[2] * mul, base[3] * mul]
	var sum: float = scaled[0] + scaled[1] + scaled[2] + scaled[3]
	if sum <= 0.0:
		return [1.0, 0.0, 0.0, 0.0]
	return [scaled[0] / sum, scaled[1] / sum, scaled[2] / sum, scaled[3] / sum]

static func pick_tier(weights: Array, r: float) -> int:
	var acc: float = 0.0
	for tier in range(weights.size()):
		acc += float(weights[tier])
		if r < acc:
			return tier
	return weights.size() - 1

static func affix_count(tier: int) -> int:
	return clampi(tier, 0, 3)

static func build_affixes(category: String, tier: int, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var n: int = affix_count(tier)
	if n <= 0:
		return out
	var candidates: Array = []
	for id in Pool.affix_ids(category):
		var e: Dictionary = Pool.entry(category, id)
		if e["ranges"].has(tier):
			candidates.append(e)
	var pool: Array = candidates.duplicate()
	for i in range(n):
		if pool.is_empty():
			break
		var e: Dictionary = _weighted_pick(pool, rng)
		pool.erase(e)
		out.append(_roll_one(e, tier, rng))
	return out

static func build_affixes_from(category: String, tier: int, stat: String, rng: RandomNumberGenerator) -> Dictionary:
	var e: Dictionary = Pool.entry(category, stat)
	if e.is_empty() or not e["ranges"].has(tier):
		return {}
	return _roll_one(e, tier, rng)

static func _weighted_pick(pool: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total: float = 0.0
	for e in pool:
		total += float(e["weight"])
	var r: float = rng.randf() * total
	var acc: float = 0.0
	for e in pool:
		acc += float(e["weight"])
		if r <= acc:
			return e
	return pool[pool.size() - 1]

static func _roll_one(e: Dictionary, tier: int, rng: RandomNumberGenerator) -> Dictionary:
	var r: Array = e["ranges"][tier]
	var lo: float = float(r[0])
	var hi: float = float(r[1])
	var unit: String = e["unit"]
	var value: float
	if unit == "flat":
		value = float(rng.randi_range(int(lo), int(hi)))
	elif unit == "mult":
		value = lo
	else:
		value = rng.randf_range(lo, hi)
		if unit == "pct":
			value *= 0.01
		elif unit == "hp" or unit == "kg":
			value = float(int(round(value)))
		elif unit == "rate":
			value = snappedf(value, 0.01)
	return {"stat": e["stat"], "value": value, "unit": unit}

static func format_affix(a: Dictionary) -> String:
	var unit: String = a.get("unit", "pct")
	var value: float = float(a.get("value", 0.0))
	var stat: String = a.get("stat", "")
	var label := stat.capitalize().replace("_", " ")
	match unit:
		"pct":
			var pct := int(round(value * 100.0))
			var sign := "+" if pct >= 0 else ""
			return sign + str(pct) + "% " + label
		"rate":
			return "Regen +" + str(value) + " HP/s"
		"hp":
			return "+" + str(int(round(value))) + " Max HP"
		"kg":
			return "+" + str(int(round(value))) + " kg " + label
		"flat":
			return "+" + str(int(round(value))) + " " + label
		"mult":
			return label + " x" + str(value)
	return label + " " + str(value)
```

- [ ] **Step 4: Run test to verify it passes**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```

Expected: `LSH Roll tests passed`.

- [ ] **Step 5: Commit**

```bash
git add "standalone mods/LooterShooter/mods/LooterShooter/LSHRoll.gd" ".check/project/tests/test_lsh_roll.gd"
git commit -m "feat(lsh): pure roll math (tier weights, affix build, formatting)"
```

---

### Task 5: Category classifier

**Files:**
- Create: `standalone mods/LooterShooter/mods/LooterShooter/LSHCategory.gd`
- Test: `.check/project/tests/test_lsh_category.gd`

**Interfaces:**
- Consumes: nothing.
- Produces (static API on `LSHCategory`):
  - `const WEAPON := "weapon"`, `const CLOTHING := "clothing"`, `const OTHER := "other"`
  - `static func of_path(path: String) -> String`
  - `static func of_item(itemData) -> String` — prefers `itemData.type` (`"Weapon"` → weapon; `"Armor"`, `"Helmet"`, `"Rig"` → clothing), falls back to `of_path(itemData.resource_path)`
  - `static func rollable(itemData) -> bool` — `of_item(itemData) != OTHER`

- [ ] **Step 1: Write the failing test**

`.check/project/tests/test_lsh_category.gd`:

```gdscript
extends SceneTree

const Cat = preload("res://mods/LooterShooter/LSHCategory.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _init() -> void:
	ck(Cat.of_path("res://Items/Weapons/KA-M.tres") == Cat.WEAPON, "path Weapons -> weapon")
	ck(Cat.of_path("res://Items/Clothing/M62 Jacket.tres") == Cat.CLOTHING, "path Clothing -> clothing")
	ck(Cat.of_path("res://Items/Armor/Plate.tres") == Cat.CLOTHING, "path Armor -> clothing")
	ck(Cat.of_path("res://Items/Consumables/Water_Bottle.tres") == Cat.OTHER, "path Consumables -> other")
	ck(Cat.of_path("") == Cat.OTHER, "empty path -> other")

	var w = {"type": "Weapon", "resource_path": "res://Items/Fishing/Rod.tres"}
	ck(Cat.of_item(w) == Cat.WEAPON, "type Weapon wins over path")
	var a = {"type": "Armor", "resource_path": "res://Items/Armor/Plate.tres"}
	ck(Cat.of_item(a) == Cat.CLOTHING, "type Armor -> clothing")
	var food = {"type": "Consumable", "resource_path": "res://Items/Consumables/Water.tres"}
	ck(Cat.of_item(food) == Cat.OTHER, "consumable -> other")
	var no_type = {"resource_path": "res://Items/Weapons/VSD.tres"}
	ck(Cat.of_item(no_type) == Cat.WEAPON, "no type falls back to path")

	ck(Cat.rollable(w), "weapon rollable")
	ck(not Cat.rollable(food), "consumable not rollable")

	print("")
	if fails == 0:
		print("LSH Category tests passed")
		quit(0)
	else:
		print("LSH Category tests failed: ", fails)
		quit(1)
```

- [ ] **Step 2: Run test to verify it fails**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```

Expected: FAIL, `LSHCategory.gd` missing.

- [ ] **Step 3: Write minimal implementation**

`standalone mods/LooterShooter/mods/LooterShooter/LSHCategory.gd`:

```gdscript
extends RefCounted

const WEAPON := "weapon"
const CLOTHING := "clothing"
const OTHER := "other"

const WEAPON_TYPES := ["Weapon"]
const CLOTHING_TYPES := ["Armor", "Helmet", "Rig"]

static func of_path(path: String) -> String:
	var p := path.to_lower()
	if p == "":
		return OTHER
	if p.contains("/weapons/"):
		return WEAPON
	if p.contains("/clothing/") or p.contains("/armor/") or p.contains("/helmets/"):
		return CLOTHING
	return OTHER

static func of_item(itemData) -> String:
	if itemData == null:
		return OTHER
	var t: String = str(itemData.get("type")) if "type" in itemData else ""
	if WEAPON_TYPES.has(t):
		return WEAPON
	if CLOTHING_TYPES.has(t):
		return CLOTHING
	var path: String = str(itemData.get("resource_path")) if "resource_path" in itemData else ""
	return of_path(path)

static func rollable(itemData) -> bool:
	return of_item(itemData) != OTHER
```

- [ ] **Step 4: Run test to verify it passes**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```

Expected: `LSH Category tests passed`.

- [ ] **Step 5: Commit**

```bash
git add "standalone mods/LooterShooter/mods/LooterShooter/LSHCategory.gd" ".check/project/tests/test_lsh_category.gd"
git commit -m "feat(lsh): item category classifier"
```

---

### Task 6: Store accessor

**Files:**
- Create: `standalone mods/LooterShooter/mods/LooterShooter/LSHStore.gd`
- Test: covered indirectly by Task 2 and Task 9 tests; no standalone test file

**Interfaces:**
- Consumes: `LSHPool` (tier constants).
- Produces (static API on `LSHStore`):
  - `static func tier(slotData) -> int`
  - `static func affixes(slotData) -> Array`
  - `static func has_tier(slotData) -> bool` — `tier(slotData) > 0`
  - `static func stamp(slotData, tier: int, affixes: Array) -> void`
  - `static func clear(slotData) -> void`

- [ ] **Step 1: Write minimal implementation**

`standalone mods/LooterShooter/mods/LooterShooter/LSHStore.gd`:

```gdscript
extends RefCounted

static func tier(slotData) -> int:
	if slotData == null or not ("loot_tier" in slotData):
		return 0
	return int(slotData.loot_tier)

static func affixes(slotData) -> Array:
	if slotData == null or not ("loot_affixes" in slotData):
		return []
	return slotData.loot_affixes

static func has_tier(slotData) -> bool:
	return tier(slotData) > 0

static func stamp(slotData, tier: int, affixes: Array) -> void:
	if slotData == null or not ("loot_tier" in slotData):
		return
	slotData.loot_tier = tier
	slotData.loot_affixes = affixes

static func clear(slotData) -> void:
	stamp(slotData, 0, [])
```

- [ ] **Step 2: Verify it parses**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```

Expected: `ok    res://mods/LooterShooter/LSHStore.gd` in the parse phase.

- [ ] **Step 3: Commit**

```bash
git add "standalone mods/LooterShooter/mods/LooterShooter/LSHStore.gd"
git commit -m "feat(lsh): store accessor for slot fields"
```

---

### Task 7: Config slice + MCM bridge + debug module

**Files:**
- Create: `standalone mods/LooterShooter/mods/LooterShooter/LSHConfig.gd`
- Create: `standalone mods/LooterShooter/mods/LooterShooter/LSHDebug.gd`
- Modify: `standalone mods/LooterShooter/mods/LooterShooter/LSHBoot.gd`
- Test: `.check/project/tests/test_lsh_config.gd`

**Interfaces:**
- Consumes: `LSHLog`.
- Produces:
  - `LSHConfig` — 12 fields with defaults + `func read(cfg: ConfigFile) -> void`:
    `paint_cells: bool = true`, `show_affix_block: bool = true`, `freq_mult: float = 1.0`, `tier_palette: int = 0`, `debug_enabled: bool = false`, `debug_force_tier: int = 0`, `debug_reroll_key: int = 0`, `log_rolls: bool = false`, plus reserved defaults `env_hint: bool = true` (unused in M1, kept at default), and three future-proof no-ops `notify_legendary: bool = false`, `hide_vanilla_rarity: bool = false`, `border_width: float = 2.0`.
  - `LSHDebug` — `func configure(cfg: LSHConfig) -> void`, `func force_tier() -> int`, `func reroll_enabled() -> bool`, `func matches_reroll(event: InputEvent) -> bool`, `func should_log() -> bool`.
  - `LSHBoot` gains: `var _cfg`, `var _debug`, `func reroll_item(item) -> bool`, `func register_mcm() -> void`.

- [ ] **Step 1: Write the failing test**

`.check/project/tests/test_lsh_config.gd`:

```gdscript
extends SceneTree

const Config = preload("res://mods/LooterShooter/LSHConfig.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _init() -> void:
	var c = Config.new()
	ck(c.paint_cells == true, "paint_cells default true")
	ck(c.show_affix_block == true, "show_affix_block default true")
	ck(is_equal_approx(c.freq_mult, 1.0), "freq_mult default 1.0")
	ck(c.debug_enabled == false, "debug_enabled default false")
	ck(c.debug_force_tier == 0, "debug_force_tier default 0")

	var cfg := ConfigFile.new()
	cfg.set_value("Bool", "paint_cells", {"default": true, "value": false})
	cfg.set_value("Float", "freq_mult", {"default": 1.0, "value": 2.0})
	cfg.set_value("Dropdown", "tier_palette", {"value": 1})
	cfg.set_value("Int", "debug_force_tier", {"value": 3})
	cfg.set_value("Bool", "debug_enabled", {"default": false, "value": true})
	cfg.set_value("Keycode", "debug_reroll_key", {"value": 4194332})
	cfg.set_value("Bool", "log_rolls", {"default": false, "value": true})
	c.read(cfg)
	ck(c.paint_cells == false, "read bool value")
	ck(is_equal_approx(c.freq_mult, 2.0), "read float value")
	ck(c.tier_palette == 1, "read dropdown value")
	ck(c.debug_force_tier == 3, "read int value")
	ck(c.debug_enabled == true, "read debug toggle")
	ck(c.debug_reroll_key == 4194332, "read keycode")
	ck(c.log_rolls == true, "read log toggle")

	var partial := ConfigFile.new()
	c.read(partial)
	ck(c.freq_mult >= 0.5 and c.freq_mult <= 2.0, "missing keys keep valid freq_mult")

	print("")
	if fails == 0:
		print("LSH Config tests passed")
		quit(0)
	else:
		print("LSH Config tests failed: ", fails)
		quit(1)
```

- [ ] **Step 2: Run test to verify it fails**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```

Expected: FAIL, `LSHConfig.gd` missing.

- [ ] **Step 3: Write `LSHConfig.gd`**

`standalone mods/LooterShooter/mods/LooterShooter/LSHConfig.gd`:

```gdscript
extends RefCounted

var paint_cells: bool = true
var show_affix_block: bool = true
var freq_mult: float = 1.0
var tier_palette: int = 0
var border_width: float = 2.0
var hide_vanilla_rarity: bool = false
var debug_enabled: bool = false
var debug_force_tier: int = 0
var debug_reroll_key: int = 0
var log_rolls: bool = false
var notify_legendary: bool = false
var env_hint: bool = true

func read(cfg: ConfigFile) -> void:
	paint_cells = _b(cfg, "paint_cells", paint_cells)
	show_affix_block = _b(cfg, "show_affix_block", show_affix_block)
	freq_mult = _f(cfg, "freq_mult", freq_mult)
	tier_palette = _i(cfg, "tier_palette", tier_palette)
	border_width = _f(cfg, "border_width", border_width)
	hide_vanilla_rarity = _b(cfg, "hide_vanilla_rarity", hide_vanilla_rarity)
	debug_enabled = _b(cfg, "debug_enabled", debug_enabled)
	debug_force_tier = _i(cfg, "debug_force_tier", debug_force_tier)
	debug_reroll_key = _i(cfg, "debug_reroll_key", debug_reroll_key)
	log_rolls = _b(cfg, "log_rolls", log_rolls)
	notify_legendary = _b(cfg, "notify_legendary", notify_legendary)
	env_hint = _b(cfg, "env_hint", env_hint)

func _val(cfg: ConfigFile, key: String):
	for section in ["Bool", "Int", "Float", "Dropdown", "Keycode", "String"]:
		if cfg.has_section_key(section, key):
			var v = cfg.get_value(section, key)
			if v is Dictionary and v.has("value"):
				return v["value"]
			if v is Dictionary or v == null:
				return null
			return v
	return null

func _b(cfg: ConfigFile, key: String, def: bool) -> bool:
	var v = _val(cfg, key)
	if v is bool:
		return v
	return def

func _i(cfg: ConfigFile, key: String, def: int) -> int:
	var v = _val(cfg, key)
	if v is int:
		return v
	if v is float:
		return int(v)
	return def

func _f(cfg: ConfigFile, key: String, def: float) -> float:
	var v = _val(cfg, key)
	if v is float:
		return v
	if v is int:
		return float(v)
	return def
```

- [ ] **Step 4: Write `LSHDebug.gd`**

`standalone mods/LooterShooter/mods/LooterShooter/LSHDebug.gd`:

```gdscript
extends RefCounted

var _enabled: bool = false
var _force_tier: int = 0
var _reroll_key: int = 0
var _log: bool = false

func configure(cfg) -> void:
	_enabled = cfg.debug_enabled
	_force_tier = cfg.debug_force_tier
	_reroll_key = cfg.debug_reroll_key
	_log = cfg.log_rolls

func force_tier() -> int:
	if not _enabled:
		return 0
	return _force_tier

func reroll_enabled() -> bool:
	return _enabled and _reroll_key != 0

func matches_reroll(event: InputEvent) -> bool:
	if not reroll_enabled():
		return false
	if event is InputEventKey and event.pressed and not event.echo:
		return int(event.physical_keycode) == _reroll_key
	return false

func should_log() -> bool:
	return _log
```

- [ ] **Step 5: Wire `LSHBoot.gd` (config + MCM registration + debug)**

Replace `standalone mods/LooterShooter/mods/LooterShooter/LSHBoot.gd` with:

```gdscript
extends Node

const Log = preload("res://mods/LooterShooter/LSHLog.gd")
const ConfigRec = preload("res://mods/LooterShooter/LSHConfig.gd")
const DebugMod = preload("res://mods/LooterShooter/LSHDebug.gd")

const MCM_HELPERS := "res://ModConfigurationMenu/Scripts/Doink Oink/MCM_Helpers.tres"

var _lib = null
var _cfg = ConfigRec.new()
var _debug = DebugMod.new()

func _ready() -> void:
	register_mcm()
	_debug.configure(_cfg)
	Log.line("booted (debug=" + str(_cfg.debug_enabled) + ")")

func register_mcm() -> void:
	if not ResourceLoader.exists(MCM_HELPERS):
		_cfg.read(ConfigFile.new())
		return
	var mcm = load(MCM_HELPERS)
	if mcm == null or not mcm.has_method("RegisterConfiguration"):
		_cfg.read(ConfigFile.new())
		return
	var cfg := ConfigFile.new()
	var cat := "01. Display"
	cfg.set_value("Bool", "paint_cells", {"name": "Paint item cells", "default": true, "value": true, "category": cat, "menu_pos": 0, "tooltip": "Tint the inventory cell by loot rarity."})
	cfg.set_value("Bool", "show_affix_block", {"name": "Show affix block in tooltip", "default": true, "value": true, "category": cat, "menu_pos": 1, "tooltip": "List the rolled affixes below the item tooltip."})
	cfg.set_value("Float", "border_width", {"name": "Border width", "default": 2.0, "value": 2.0, "minRange": 1.0, "maxRange": 6.0, "step": 1.0, "category": cat, "menu_pos": 2, "tooltip": "Thickness of the rarity border."})
	cfg.set_value("Dropdown", "tier_palette", {"name": "Rarity palette", "default": 0, "value": 0, "options": {"0": "Default (blue/purple/gold)", "1": "High contrast"}, "category": cat, "menu_pos": 3, "tooltip": "Colour set for the rarity tiers."})
	cfg.set_value("Bool", "hide_vanilla_rarity", {"name": "Hide vanilla rarity line", "default": false, "value": false, "category": cat, "menu_pos": 4, "tooltip": "Hide the vanilla rarity word; the mod's own rarity line still shows."})

	var bal := "02. Balance"
	cfg.set_value("Float", "freq_mult", {"name": "Rarity frequency", "default": 1.0, "value": 1.0, "minRange": 0.5, "maxRange": 2.0, "step": 0.5, "category": bal, "menu_pos": 0, "tooltip": "Scales how often higher tiers appear."})
	cfg.set_value("Bool", "notify_legendary", {"name": "Notify on legendary find", "default": false, "value": false, "category": bal, "menu_pos": 1, "tooltip": "Show an on-screen message when a legendary drops."})
	cfg.set_value("Bool", "env_hint", {"name": "Container context hint", "default": true, "value": true, "category": bal, "menu_pos": 2, "tooltip": "Let military and elite containers shift the odds upward."})

	var dbg := "03. Debug"
	cfg.set_value("Bool", "debug_enabled", {"name": "Debug mode", "default": false, "value": false, "category": dbg, "menu_pos": 0, "tooltip": "Enable the debug tools below."})
	cfg.set_value("Int", "debug_force_tier", {"name": "Force tier (0=off)", "default": 0, "value": 0, "minRange": 0, "maxRange": 3, "step": 1, "category": dbg, "menu_pos": 1, "tooltip": "1=Common, 2=Rare, 3=Legendary."})
	cfg.set_value("Keycode", "debug_reroll_key", {"name": "Re-roll hovered item", "default": 0, "default_type": "Keycode", "value": 0, "category": dbg, "menu_pos": 2, "tooltip": "Press to re-roll the item under the cursor."})
	cfg.set_value("Bool", "log_rolls", {"name": "Log rolls", "default": false, "value": false, "category": dbg, "menu_pos": 3, "tooltip": "Print every loot roll to the log."})
	cfg.set_value("Info", "version", "0.1.0")

	var path := "user://MCM/lootershooter"
	DirAccess.make_dir_recursive_absolute(path)
	var cfile := path + "/config.ini"
	if FileAccess.file_exists(cfile):
		var existing := ConfigFile.new()
		if existing.load(cfile) == OK:
			for section in existing.get_sections():
				if not cfg.has_section(section):
					existing.erase_section(section)
					continue
				for key in existing.get_section_keys(section):
					if not cfg.has_section_key(section, key):
						existing.erase_section_key(section, key)
						continue
					var old_v = existing.get_value(section, key)
					var new_v = cfg.get_value(section, key)
					if old_v is Dictionary and new_v is Dictionary:
						new_v["value"] = old_v.get("value", new_v.get("value"))
						existing.set_value(section, key, new_v)
			existing.save(cfile)
	else:
		cfg.save(cfile)
	mcm.RegisterConfiguration("lootershooter", "LooterShooter", path, "Per-instance loot rarity and affixes", Callable(self, "apply_config"), self)
	apply_config(ConfigFile.new())

func apply_config(cfg: ConfigFile) -> void:
	if cfg == null or cfg.get_sections().is_empty():
		var path := "user://MCM/lootershooter/config.ini"
		if FileAccess.file_exists(path):
			var c := ConfigFile.new()
			c.load(path)
			_cfg.read(c)
	if cfg != null and not cfg.get_sections().is_empty():
		_cfg.read(cfg)
	_debug.configure(_cfg)

func reroll_item(_item) -> bool:
	return false
```

- [ ] **Step 6: Run test to verify it passes**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```

Expected: `LSH Config tests passed`, and `ok` for `LSHBoot.gd`/`LSHConfig.gd`/`LSHDebug.gd`.

- [ ] **Step 7: Commit**

```bash
git add "standalone mods/LooterShooter/mods/LooterShooter/LSHConfig.gd" "standalone mods/LooterShooter/mods/LooterShooter/LSHDebug.gd" "standalone mods/LooterShooter/mods/LooterShooter/LSHBoot.gd" ".check/project/tests/test_lsh_config.gd"
git commit -m "feat(lsh): config slice, MCM registration, debug module"
```

---

### Task 8: Stand & packer wiring

**Files:**
- Modify: `.check/check.ps1`

**Interfaces:**
- Consumes: the mod files from Tasks 1–7.
- Produces: the stand copies + parse-checks + test-runs `standalone mods/LooterShooter/mods/LooterShooter/*.gd`, including `Scripts/SlotData.gd` (copied to `mods/LooterShooter/Scripts/SlotData.gd`, checked last).

- [ ] **Step 1: Add the third mod copy block**

In `.check/check.ps1`, immediately after the existing ThermalVTK copy block (which ends with `Copy-Item … "*.gdshader" … }`), insert:

```powershell
$lshSrc = Join-Path (Split-Path $checkRoot -Parent) "standalone mods\LooterShooter\mods\LooterShooter"
$lshDst = Join-Path $proj "mods\LooterShooter"
if (Test-Path -LiteralPath $lshSrc -PathType Container) {
    if (Test-Path -LiteralPath $lshDst) { Remove-Item -LiteralPath $lshDst -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $lshDst | Out-Null
    Copy-Item -Path (Join-Path $lshSrc "*.gd") -Destination $lshDst -Force -ErrorAction SilentlyContinue
    $lshSub = Join-Path $lshSrc "Scripts"
    if (Test-Path -LiteralPath $lshSub -PathType Container) {
        New-Item -ItemType Directory -Force -Path (Join-Path $lshDst "Scripts") | Out-Null
        Copy-Item -Path (Join-Path $lshSub "*.gd") -Destination (Join-Path $lshDst "Scripts") -Force -ErrorAction SilentlyContinue
    }
}
```

- [ ] **Step 2: Add the parse-check loop**

Immediately after the existing ThermalVTK parse loop (before the `Write-Host ""` / fail-exit), insert:

```powershell
if (Test-Path -LiteralPath $lshDst -PathType Container) {
    $lshScripts = Get-ChildItem -LiteralPath $lshDst -Filter "*.gd" -File | Sort-Object Name
    $lshSubScripts = @()
    if (Test-Path -LiteralPath (Join-Path $lshDst "Scripts") -PathType Container) {
        $lshSubScripts = Get-ChildItem -LiteralPath (Join-Path $lshDst "Scripts") -Filter "*.gd" -File | Sort-Object Name
    }
    foreach ($s in $lshScripts) {
        $res = "res://mods/LooterShooter/" + $s.Name
        $out = & $Godot --headless --path $proj --check-only --script $res 2>&1 | Out-String
        $bad = ($LASTEXITCODE -ne 0) -or ($out -match "SCRIPT ERROR|Parse Error|Failed to load script")
        if ($bad) {
            $fail++
            Write-Host "FAIL  LooterShooter/$($s.Name)"
            Write-Host $out.Trim()
        } else {
            Write-Host "ok    LooterShooter/$($s.Name)"
        }
    }
    foreach ($s in $lshSubScripts) {
        $res = "res://mods/LooterShooter/Scripts/" + $s.Name
        $out = & $Godot --headless --path $proj --check-only --script $res 2>&1 | Out-String
        $bad = ($LASTEXITCODE -ne 0) -or ($out -match "SCRIPT ERROR|Parse Error|Failed to load script")
        if ($bad) {
            $fail++
            Write-Host "FAIL  LooterShooter/Scripts/$($s.Name)"
            Write-Host $out.Trim()
        } else {
            Write-Host "ok    LooterShooter/Scripts/$($s.Name)"
        }
    }
}
```

- [ ] **Step 3: Add the six tests to `$tests`**

Extend the `$tests` array with (order does not matter; keep them on the same array literal):

```powershell
        "res://tests/test_lsh_pool.gd",
        "res://tests/test_lsh_roll.gd",
        "res://tests/test_lsh_category.gd",
        "res://tests/test_lsh_config.gd",
        "res://tests/test_lsh_slotdata.gd"
```

- [ ] **Step 4: Run the full stand**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```

Expected: every `*.gd` parse-checks `ok` (VTK + ThermalVTK + LooterShooter, including `LooterShooter/Scripts/SlotData.gd`), then each `test_lsh_*.gd` ends with `VERDICT: ok` and the run finishes with `Tests passed: <n> file(s)`, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add ".check/check.ps1"
git commit -m "test(lsh): parse-check and run LooterShooter in the .check stand"
```

---

### Task 9: Tag loot — `CreateLoot` / `AILoot` post hooks

**Files:**
- Modify: `standalone mods/LooterShooter/mods/LooterShooter/LSHBoot.gd`

**Interfaces:**
- Consumes: `LSHRoll`, `LSHStore`, `LSHCategory`, `LSHLog`, `_cfg`, `_debug` from Tasks 3–7.
- Produces:
  - `func tag_created_loot(item) -> void` — **arity 1**, for the VOID `CreateLoot(item: ItemData)` post hook (void → `args.size()` params). The just-created `SlotData` is not passed: `CreateLoot` builds `newSlotData` locally and `loot.append`s it, so the slot is reached through `_lib._caller.loot.back()` (design spec §6).
  - `func tag_ai_loot(slotData) -> void` — arity 1, for the NON-void `AILoot() -> SlotData` post hook (non-void → `args.size() + 1`; the lone param is `_result`, the picked slot).
  - `func _created_slot()` → the `SlotData` appended by the current `CreateLoot` call.
  - `func _roll_into(slotData, ctx: Dictionary) -> void`
  - `func roll_for(itemData, ctx: Dictionary, rng: RandomNumberGenerator) -> Dictionary` → `{"tier": int, "affixes": Array}` (pure, used by the reroll path in Task 10)

- [ ] **Step 1: Implement the roll-into helper and both hooks**

In `LSHBoot.gd`, add the preloads and the hook registration, and replace the `reroll_item` stub.

Preloads (top of file, after `DebugMod`):

```gdscript
const Roll = preload("res://mods/LooterShooter/LSHRoll.gd")
const Store = preload("res://mods/LooterShooter/LSHStore.gd")
const Category = preload("res://mods/LooterShooter/LSHCategory.gd")
```

In `_ready()`, after `_debug.configure(_cfg)`, add the lib hookup:

```gdscript
	var lib = Engine.get_meta("RTVModLib") if Engine.has_meta("RTVModLib") else null
	if lib == null:
		Log.warn("RTVModLib not found; loot hooks are inactive")
	else:
		_lib = lib
		_lib.hook("lootcontainer-createloot-post", Callable(self, "tag_created_loot"), 100)
		_lib.hook("lootcontainer-ailoot-post", Callable(self, "tag_ai_loot"), 100)
```

Append the functions at the end of the file:

```gdscript
func tag_created_loot(item) -> void:
	var slotData = _created_slot()
	if slotData == null or slotData.itemData == null:
		return
	_roll_into(slotData, {"item": item, "rarity_roll": _caller_rarity_roll()})

func _created_slot():
	if _lib == null:
		return null
	var caller = _lib._caller if "_caller" in _lib else null
	if caller == null or not ("loot" in caller):
		return null
	var loot = caller.loot
	if loot is Array and loot.size() > 0:
		return loot[loot.size() - 1]
	return null

func tag_ai_loot(slotData) -> void:
	if slotData == null or slotData.itemData == null:
		return
	var ctx := {"rarity_roll": _caller_rarity_roll()}
	_roll_into(slotData, ctx)

func _caller_rarity_roll() -> int:
	if _lib == null:
		return 100
	var caller = _lib._caller if "_caller" in _lib else null
	if caller != null and "rarityRoll" in caller:
		return int(caller.rarityRoll)
	return 100

func _roll_into(slotData, ctx: Dictionary) -> void:
	if slotData == null or slotData.itemData == null:
		return
	if not Category.rollable(slotData.itemData):
		return
	var r: Dictionary = roll_for(slotData.itemData, ctx, RandomNumberGenerator.new())
	if r["tier"] <= 0 and Store.has_tier(slotData):
		return
	Store.stamp(slotData, r["tier"], r["affixes"])
	if _debug.should_log():
		Log.line("roll " + str(slotData.itemData.name) + " tier=" + str(r["tier"])
				+ " affixes=" + str(r["affixes"]))

func roll_for(itemData, ctx: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var cat: String = Category.of_item(itemData)
	if cat == Category.OTHER:
		return {"tier": 0, "affixes": []}
	var rarity_roll: int = int(ctx.get("rarity_roll", 100))
	var ctx_dict := {"rarity_roll": rarity_roll, "corpse": bool(ctx.get("corpse", false)), "joker": bool(ctx.get("joker", false))}
	var weights: Array = Roll.tier_weights(ctx_dict, _cfg.freq_mult, _debug.force_tier())
	var tier: int = Roll.pick_tier(weights, rng.randf())
	var affixes: Array = Roll.build_affixes(cat, tier, rng)
	return {"tier": tier, "affixes": affixes}
```

- [ ] **Step 2: Verify it parses and the stand is green**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```

Expected: `ok    LooterShooter/LSHBoot.gd`, all tests still `VERDICT: ok`.

- [ ] **Step 3: Manual runtime check (Godot console)**

Install the packed mod (Task 12) and, in game, open any container with a weapon inside; with `Debug → Log rolls` on, the log shows `[LSH] roll <name> tier=<n> affixes=[...]`. Record the result in the PR/commit notes.

- [ ] **Step 4: Commit**

```bash
git add "standalone mods/LooterShooter/mods/LooterShooter/LSHBoot.gd"
git commit -m "feat(lsh): tag container and corpse loot via post hooks"
```

---

### Task 10: Display — cell border, tooltip block, reroll

**Files:**
- Create: `standalone mods/LooterShooter/mods/LooterShooter/LSHDisplay.gd`
- Modify: `standalone mods/LooterShooter/mods/LooterShooter/LSHBoot.gd`

(`LSHDebug.gd` is NOT touched: the display owns the rarity colours as `COLORS_DEFAULT`/`COLORS_CONTRAST`; `LSHDebug` stays logic-only, per the "colours live only in `LSHDisplay`" rule.)

**Interfaces:**
- Consumes: `LSHStore`, `LSHRoll`, `LSHPool`, `LSHLog`, `_cfg`, `LSHBoot.reroll_item`.
- Produces:
  - `LSHDisplay` (`extends RefCounted`):
    - `func configure(cfg) -> void`
    - `func attach(tree: SceneTree) -> void` — connects `tree.node_added`, scans the existing tree
    - `func track(node: Node) -> void` — called for every added node
    - `func paint(node) -> void` — idempotent border overlay (`_lsh_border`)
    - `func apply_tooltip(tooltip) -> void` — idempotent affix block (`_lsh_affix_block`) from `tooltip.interface.hoverItem`
    - `func reroll_hovered(tree: SceneTree) -> bool` — re-rolls the hovered item's `slotData`
    - `func _border_color(tier: int) -> Color`
    - `const BORDER_NAME := "_lsh_border"`, `const BLOCK_NAME := "_lsh_affix_block"`
  - `LSHBoot` gains `var _display` and a `tooltip-update-post` callback `func on_tooltip_update(item) -> void` (arity 1 — `Tooltip.Update(item)` is void).

- [ ] **Step 1: Implement `LSHDisplay.gd`** (it owns the rarity colours; do not add them anywhere else)

`standalone mods/LooterShooter/mods/LooterShooter/LSHDisplay.gd`:

```gdscript
extends RefCounted

const Log = preload("res://mods/LooterShooter/LSHLog.gd")
const Store = preload("res://mods/LooterShooter/LSHStore.gd")
const Roll = preload("res://mods/LooterShooter/LSHRoll.gd")
const Pool = preload("res://mods/LooterShooter/LSHPool.gd")

const BORDER_NAME := "_lsh_border"
const BLOCK_NAME := "_lsh_affix_block"
const COLORS_DEFAULT := {1: Color(0.35, 0.6, 1.0), 2: Color(0.7, 0.4, 1.0), 3: Color(1.0, 0.8, 0.2)}
const COLORS_CONTRAST := {1: Color(0.1, 0.75, 1.0), 2: Color(1.0, 0.2, 0.9), 3: Color(1.0, 0.95, 0.1)}

var _cfg = null
var _host = null

func configure(cfg) -> void:
	_cfg = cfg

func attach(tree: SceneTree) -> void:
	if not tree.node_added.is_connected(track):
		tree.node_added.connect(track)
	_walk(tree.get_root())

func track(node: Node) -> void:
	if _is_item(node):
		if _cfg == null or _cfg.paint_cells:
			paint(node)

func _walk(node: Node) -> void:
	if _is_item(node):
		if _cfg == null or _cfg.paint_cells:
			paint(node)
	for child in node.get_children():
		_walk(child)

func _is_item(node: Node) -> bool:
	return node is Panel and "slotData" in node

func paint(item) -> void:
	var existing = item.get_node_or_null(BORDER_NAME)
	var tier: int = 0 if item.slotData == null else Store.tier(item.slotData)
	if tier <= 0:
		if existing != null:
			existing.queue_free()
		return
	var overlay = existing
	if overlay == null:
		overlay = Panel.new()
		overlay.name = BORDER_NAME
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		item.add_child(overlay)
		item.move_child(overlay, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.draw_center = false
	var w: float = 2.0 if _cfg == null else _cfg.border_width
	style.set_border_width_all(int(w))
	style.border_color = _border_color(tier)
	overlay.add_theme_stylebox_override("panel", style)

func _border_color(tier: int) -> Color:
	var palette: Dictionary = COLORS_DEFAULT
	if _cfg != null and _cfg.tier_palette == 1:
		palette = COLORS_CONTRAST
	return palette.get(tier, Color(1, 1, 1, 0))

func apply_tooltip(tooltip) -> void:
	if tooltip == null:
		return
	var item = tooltip.interface.hoverItem if "interface" in tooltip and tooltip.interface != null else null
	if item == null or item.slotData == null:
		_clear_block(tooltip)
		return
	if _cfg != null and not _cfg.show_affix_block:
		_clear_block(tooltip)
		return
	var tier: int = Store.tier(item.slotData)
	if tier <= 0:
		_clear_block(tooltip)
		return
	var info = tooltip.find_child("Info", true, false)
	var vbox = info.get_parent() if info != null else null
	if vbox == null:
		vbox = tooltip.find_child("Elements", true, false)
	if not (vbox is VBoxContainer) and not (vbox is BoxContainer):
		return
	var block = vbox.get_node_or_null(BLOCK_NAME)
	if block == null:
		block = RichTextLabel.new()
		block.name = BLOCK_NAME
		block.bbcode_enabled = true
		block.fit_content = true
		block.scroll_active = false
		block.autowrap_mode = TextServer.AUTOWRAP_WORD
		block.custom_minimum_size = Vector2(256.0, 0.0)
		block.mouse_filter = Control.MOUSE_FILTER_IGNORE
		block.add_theme_font_size_override("normal_font_size", 12)
		vbox.add_child(block)
		var idx := 0 if info == null else info.get_index() + 1
		vbox.move_child(block, idx)
	var hex := "#" + _border_color(tier).to_html(false)
	block.text = "[color=" + hex + "]" + Pool.TIER_NAMES.get(tier, "") + "[/color]\n"
	for a in Store.affixes(item.slotData):
		block.text += "[color=#cccccc]" + Roll.format_affix(a) + "[/color]\n"
	block.visible = true

func _clear_block(tooltip) -> void:
	var block = tooltip.find_child(BLOCK_NAME, true, false)
	if block != null:
		block.visible = false

func reroll_hovered(tree: SceneTree) -> bool:
	var iface = tree.get_root().get_node_or_null("Map/Core/UI/Interface")
	if iface == null:
		return false
	var item = iface.hoverItem if "hoverItem" in iface else null
	if item == null or item.slotData == null:
		return false
	if _host == null or not _host.has_method("reroll_item"):
		return false
	return _host.reroll_item(item)
```

Add `func set_host(h) -> void: _host = h` to `LSHDisplay`.

- [ ] **Step 2: Wire display into `LSHBoot.gd`**

Preload: `const Display = preload("res://mods/LooterShooter/LSHDisplay.gd")`.

Add `var _display = Display.new()` near `_cfg`/`_debug`.

In `_ready()`, before the lib hookup:

```gdscript
	_display.configure(_cfg)
	_display.set_host(self)
```

In the `else` branch where `_lib` is set, add:

```gdscript
		_lib.hook("tooltip-update-post", Callable(self, "on_tooltip_update"), 100)
		_display.attach(get_tree())
```

Add:

```gdscript
func on_tooltip_update(tooltip) -> void:
	_display.apply_tooltip(tooltip)

func _input(event: InputEvent) -> void:
	if _debug.matches_reroll(event):
		if _display.reroll_hovered(get_tree()):
			Log.line("rerolled hovered item")

func reroll_item(item) -> bool:
	if item == null or item.slotData == null:
		return false
	var ctx := {"rarity_roll": 100}
	if _debug.force_tier() == 0:
		ctx["rarity_roll"] = randi_range(1, 100)
	var r: Dictionary = roll_for(item.slotData.itemData, ctx, RandomNumberGenerator.new())
	if r["tier"] <= 0:
		r = {"tier": Roll.pick_tier(Roll.tier_weights(ctx, _cfg.freq_mult, 1), randf()),
			 "affixes": Roll.build_affixes(Category.of_item(item.slotData.itemData), 1, RandomNumberGenerator.new())}
	Store.stamp(item.slotData, r["tier"], r["affixes"])
	_display.paint(item)
	return true
```

Also, in `apply_config`, after `_debug.configure(_cfg)`, add:

```gdscript
	_display.configure(_cfg)
```

- [ ] **Step 3: Verify it parses and the stand is green**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```

Expected: `ok` for all LooterShooter scripts; tests unaffected.

- [ ] **Step 4: Manual runtime check**

In game: hover a tagged weapon → tooltip shows a coloured rarity line + affix lines; its cell shows a tinted border; the debug hotkey re-rolls the hovered item and both update. Record the result.

- [ ] **Step 5: Commit**

```bash
git add "standalone mods/LooterShooter/mods/LooterShooter/LSHDisplay.gd" "standalone mods/LooterShooter/mods/LooterShooter/LSHBoot.gd"
git commit -m "feat(lsh): cell border, tooltip affix block, debug reroll"
```

---

### Task 11: Extend `layout_check.py`

**Files:**
- Modify: `.check/layout_check.py`

**Interfaces:**
- Consumes: nothing new.
- Produces: a `LooterShooter` pass that asserts the load-bearing symbols exist and that the discarded approaches stay gone.

- [ ] **Step 1: Add a second module glob + check block**

In `.check/layout_check.py`, add after `MODULES_GLOB`:

```python
LSH_GLOB = r"D:\RTVMOD\standalone mods\LooterShooter\mods\LooterShooter\*.gd"
LSH_GLOB_SUB = r"D:\RTVMOD\standalone mods\LooterShooter\mods\LooterShooter\Scripts\*.gd"

LSH_PRESENT = [
    ("LSHBoot.gd", "lootcontainer-createloot-post"),
    ("LSHBoot.gd", "lootcontainer-ailoot-post"),
    ("LSHBoot.gd", "tooltip-update-post"),
    ("LSHBoot.gd", "RegisterConfiguration"),
    ("LSHStore.gd", "static func stamp"),
    ("LSHStore.gd", "static func tier"),
    ("LSHRoll.gd", "static func tier_weights"),
    ("LSHRoll.gd", "static func build_affixes"),
    ("LSHPool.gd", "static func validate"),
    ("LSHCategory.gd", "static func of_item"),
    ("LSHDisplay.gd", "const BORDER_NAME"),
    ("LSHDisplay.gd", "const BLOCK_NAME"),
    ("Scripts/SlotData.gd", "extends \"res://Scripts/SlotData.gd\""),
    ("Scripts/SlotData.gd", "loot_tier"),
    ("Scripts/SlotData.gd", "loot_affixes"),
]

LSH_GONE = ["_rings", "_boost", "modloader_hooks", "take_over_path"]
```

And in `main()`, before the final summary, add:

```python
    lsh_files = {}
    for pattern in (LSH_GLOB, LSH_GLOB_SUB):
        for path in glob.glob(pattern):
            lsh_files[os.path.basename(path)] = open(path, encoding="utf-8").read()
    if lsh_files:
        for fname, needle in LSH_PRESENT:
            base = os.path.basename(fname)
            body = lsh_files.get(base, "")
            status = "ok" if needle in body else "MISSING"
            print(f"LSH PRESENT {status:8} {fname}: {needle}")
            if status == "MISSING":
                ok = False
        for needle in LSH_GONE:
            for fname, body in lsh_files.items():
                if needle in body:
                    print(f"LSH GONE    FAIL     {fname}: {needle}")
                    ok = False
```

- [ ] **Step 2: Run the layout stand**

```powershell
py -3 .check\layout_check.py
```

Expected: all `LSH PRESENT ok …` lines, no `LSH GONE FAIL`, and the existing `RESULT: символы раскладки на месте` line still prints.

- [ ] **Step 3: Commit**

```bash
git add ".check/layout_check.py"
git commit -m "test(lsh): layout assertions for the LooterShooter module"
```

---

### Task 12: Pack, install, and record the manual checklist

**Files:**
- Modify: `standalone mods/LooterShooter/README.md` (add the manual test checklist section)
- Modify: `standalone mods/LooterShooter/mod.txt` (version → `0.1.0` stays; bump only if Tasks 1–11 landed as one release)

**Interfaces:**
- Consumes: the packed archive from Task 1's packer.
- Produces: `standalone mods/LooterShooter/LooterShooter.vmz` copied to the game's mods folder; a recorded manual test result.

- [ ] **Step 1: Re-run the two stands green**

```powershell
py -3 .check\layout_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```

Expected: layout `RESULT: символы раскладки на месте`; check `Tests passed: <n> file(s)`, exit 0.

- [ ] **Step 2: Pack**

```powershell
powershell -ExecutionPolicy Bypass -File "standalone mods\LooterShooter\pack.ps1"
```

Expected: `Pack done: …\LooterShooter.vmz (N entries, … KB)`.

- [ ] **Step 3: Install**

Copy `standalone mods/LooterShooter/LooterShooter.vmz` into `D:\SteamLibrary\steamapps\common\Road to Vostok\mods`.

- [ ] **Step 4: Run the manual checklist in game**

Record pass/fail for each:

- Open a container with a weapon → log shows a tier roll (with `Log rolls` on).
- Hover a tagged weapon → tooltip shows a coloured rarity line and its affixes.
- The item's cell shows a tinted border matching the rarity.
- Take the weapon, drop it, pick it up, place in a stash container, reload the map → tier and affixes are unchanged.
- A corpse's loot rolls (kill an AI, loot the body).
- Debug: set `Force tier = 3`, loot a container → legendary every time.
- Debug: bind the re-roll hotkey, press it over a hovered item → tier/affixes change and the tooltip updates.
- With MCM removed, the mod still loads and rolls loot (no MCM lines in the log).
- Existing save loads; no `property not found` on `loot_tier`/`loot_affixes`.
- Coexists with Evolve + ItemClarity installed (both enabled) without errors.

- [ ] **Step 5: Append the checklist to README**

Add to `standalone mods/LooterShooter/README.md`:

```markdown
## Manual test checklist (before a release)

- Container weapon rolls a tier (check the log with "Log rolls").
- Tooltip shows the rarity line and affixes; the cell border matches.
- Moving/dropping/stashing/reloading keeps the tier and affixes.
- Corpse loot rolls.
- "Force tier" debug applies to all finds.
- The re-roll hotkey updates the hovered item.
- Runs without MCM installed.
- No save errors with the mod present.
- Coexists with Evolve and ItemClarity.
```

- [ ] **Step 6: Commit**

```bash
git add "standalone mods/LooterShooter"
git commit -m "chore(lsh): pack, install and manual-test checklist for M1"
```

---

## Self-Review

**1. Spec coverage** (against `2026-10-19-looter-shooter-design.md`):

| Spec item | Task |
|---|---|
| D1 per-instance rarity | 2 (fields), 9 (stamp) |
| D2 standalone mod | 1 |
| D3 pool = existing stats + regen | 3 |
| D4 0/1/2/3 affixes | 4 (`affix_count`) |
| D5 loot-only sources | 9 (`CreateLoot`/`AILoot`) |
| D9 final rolled numbers | 2 (`affixes` store values), 4 |
| D10 border + tooltip, MCM toggles | 7, 10 |
| D11 vanilla rarity kept + own line | 10 (own line added; vanilla untouched) |
| D12 palette blue/purple/gold | 10 |
| D13 storage excluded | 3 (absent from pool) |
| §4 fields + `Update`/`Reset` | 2 |
| §5 pool tables | 3 |
| §6 roll distribution + debug | 4, 7, 9 |
| §7 application points | deferred to M2/M3 (spec §12) — **not** in this plan |
| §8 display + MCM | 7, 10 |
| §9 save/compat | 12 (checklist) |
| §10 tests | 3, 4, 5, 7, 2 + stand 8 |
| §11 risk: reroll | 10 |
| §12 M1 scope | whole plan |

Application of affix effects (spec §7) is **M2/M3** by design; M1 only rolls, stores, and displays. No other gap.

**2. Placeholder scan:** no `TODO`/`TBD`/"similar to Task N"; every code step carries the full file content or the exact edit. Colours, ranges, keys, hook ids, and node names are literal.

**3. Type consistency:**
- `LSHStore.stamp(slotData, tier: int, affixes: Array)` — used identically in Tasks 9, 10.
- `LSHRoll.tier_weights(ctx, freq_mult, forced) -> Array` — used in 4, 9, 10.
- `LSHRoll.build_affixes(category, tier, rng)` / `build_affixes_from(category, tier, stat, rng)` — defined in 4, called in 9, 10.
- `LSHRoll.pick_tier`, `affix_count`, `format_affix` — defined 4, used 9, 10.
- `LSHPool.entry(category, stat)` / `affix_ids(category)` / `validate()` / `TIER_NAMES` — defined 3, used 4, 10.
- `LSHCategory.rollable(itemData)` / `of_item` / `of_path` / constants — defined 5, used 9, 10.
- `LSHConfig` field names in Task 7 match those read by `LSHDebug` and used in `LSHBoot`/`LSHDisplay`.
- `_display.paint(item)` takes an item node; `reroll_item` returns `bool`; `set_host` defined and called.
- `on_tooltip_update(item)` arity 1 matches void `Tooltip.Update(item)`.
- ⚠️ Known weakness: `tag_created_loot` reads the container context only from `_lib._caller.rarityRoll`; on the very first frames the caller may be `null` and the roll falls back to the `default` context. This is acceptable for M1 (context weighting is coarse) and is the single item to re-verify during Task 9's manual check.

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-10-19-looter-shooter-m1.md`.

Two execution options:

1. **Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.
2. **Inline Execution** — execute tasks in this session using `executing-plans`, batch execution with checkpoints.

Which approach?
