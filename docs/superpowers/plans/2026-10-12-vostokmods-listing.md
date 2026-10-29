# Vostok Toolkit — Vostok Mods Listing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prepare all repository artifacts needed to publish Vostok Toolkit (`4.15.1`) on vostokmods.net: renamed gallery assets, a repo `CHANGELOG.md`, a paste-ready listing document (metadata + EN + RU + site changelog), and an updated `README.md`.

**Architecture:** Documentation-and-assets only. The mod runtime fixes are already in the working tree (`VTKEquip.gd` + hooks) and `loadouts/mod.txt` is already `4.15.1`; this plan does not touch `loadouts/`. One new markdown deliverable (`docs/vostokmods/listing.md`) is the single paste source for the website form; `README.md` mirrors it. The existing `.check/encoding_check.py` mojibake scanner is extended to cover docs so the Russian text is checked automatically.

**Tech Stack:** Markdown, git, PowerShell (Windows), Python (existing `.check` tooling).

## Global Constraints

- Version `4.15.0`. **Do NOT edit `loadouts/mod.txt`** — documentation/assets work is outside the packed `loadouts/` folder.
- All new/edited files are **UTF-8 without BOM**, LF line endings (repo convention: README/AGENTS/LICENSE are LF-only).
- Russian text must pass the mojibake scan (`[\u0400-\u04FF]` followed by one of `\u0402\u0403\u00B0\u201E\u00A1\uFFFD`).
- Asset filenames: kebab-case, `.jpg`, no spaces, no `&`.
- Game version string exactly `0.2.1.0`. License string exactly `MIT`.
- Site vocabulary (exact strings): Categories `UI`, `Gameplay`, `Visuals`, `Fixes & Tweaks`; Tags `Quality of Life`, `Equipment`, `Tools`.
- No emojis anywhere.
- Author/uploader is the site account; no separate `Authors` field is written by us.
- **Prerequisite (mod side, out of this plan's scope):** `test_equip.gd` must exist and be listed in `.check/check.ps1` before the release build; `pack.ps1` must produce a `4.15.1` `Loadouts.vmz`.

---

### Task 1: Rename gallery assets to kebab-case

**Files:**
- Rename in `assets/`: 7 tracked-soon `.jpg` files (currently untracked).
- Remove: `assets/logo.jpg` (already deleted in the working tree).

**Interfaces:**
- Produces (final asset basenames, used by listing.md and README.md):
  `ironman-restart.jpg`, `loadout-presets.jpg`, `better-tasks.jpg`, `better-notes.jpg`, `thermal-vision.jpg`, `kill-stats-killfeed.jpg`, `fast-travel.jpg`.

> Note: the files are **untracked**, so `git mv` will not work. Rename on disk, then stage with `git add -A`, which also records the `logo.jpg` deletion.

- [ ] **Step 1: Rename on disk**

```powershell
Rename-Item -LiteralPath "assets\Ironman Restart.jpg"      -NewName "ironman-restart.jpg"
Rename-Item -LiteralPath "assets\Loadout Presets.jpg"      -NewName "loadout-presets.jpg"
Rename-Item -LiteralPath "assets\Better Tasks.jpg"         -NewName "better-tasks.jpg"
Rename-Item -LiteralPath "assets\Better Notes.jpg"         -NewName "better-notes.jpg"
Rename-Item -LiteralPath "assets\Thermal Vision.jpg"       -NewName "thermal-vision.jpg"
Rename-Item -LiteralPath "assets\Kill Stats & Killfeed.jpg" -NewName "kill-stats-killfeed.jpg"
Rename-Item -LiteralPath "assets\Fast Travel.jpg"          -NewName "fast-travel.jpg"
```

- [ ] **Step 2: Verify the asset set**

Run: `Get-ChildItem assets -File | Select-Object -ExpandProperty Name`
Expected (7 files, `logo.jpg` gone):
```
better-notes.jpg
better-tasks.jpg
fast-travel.jpg
ironman-restart.jpg
kill-stats-killfeed.jpg
loadout-presets.jpg
thermal-vision.jpg
```

- [ ] **Step 3: Verify no stale references remain**

Run: `Select-String -Path README.md,docs/vostokmods/listing.md -Pattern 'logo\.jpg|Loadout Presets\.jpg|Ironman Restart\.jpg' -ErrorAction SilentlyContinue`
Expected: no output (Task 4 rewrites README's image refs; listing.md is created in Task 3 with kebab names).

- [ ] **Step 4: Commit (additions + logo deletion)**

```powershell
git add -A assets
git commit -m "chore(assets): rename gallery images to kebab-case; drop logo.jpg"
```

---

### Task 2: Add repository `CHANGELOG.md`

**Files:**
- Create: `CHANGELOG.md`

**Interfaces:**
- Produces: the repo changelog; its `4.15.1` entry content is reused verbatim in `docs/vostokmods/listing.md` (Task 3).

- [ ] **Step 1: Write the file**

```markdown
# Changelog

All notable changes to Vostok Toolkit are documented here.
Format based on Keep a Changelog; versioning: MAJOR.MINOR.PATCH.

## [4.15.1] - 2026-10-12

### Added
- Initial public release on Vostok Mods
- Loadout presets with hotkey binding
- Auto-equip: items with slots are equipped on pickup (MCM toggle)
- Matches and other stackables top up the equipped slot without extra clicks
- Better Tasks: completed-quest auto-cleanup, partial hand-in, Notes icon rows
- Thermal vision (NVG): world heat glow, mine highlighting, friendly markers
- Kill stats HUD and dynamic killfeed
- Fast travel between maps, shelters and traders
- Ironman Restart button and the Apartments map
- RU / EN interface language switch in MCM
```

- [ ] **Step 2: Verify the file writes clean UTF-8/LF (no BOM)**

Run: `([IO.File]::ReadAllBytes("$PWD\CHANGELOG.md")[0..2] -join ',')`
Expected: NOT `239,187,191` (no BOM).

- [ ] **Step 3: Commit**

```powershell
git add CHANGELOG.md
git commit -m "docs: add CHANGELOG.md starting at 4.15.1"
```

---

### Task 3: Add paste-ready listing document

**Files:**
- Create: `docs/vostokmods/listing.md`
- Modify: `.gitignore` (add `!/docs/vostokmods/` so the deliverable is tracked; `docs/` is otherwise ignored by the `/*` rule)

**Interfaces:**
- Consumes: asset basenames from Task 1; changelog entry from Task 2.
- Produces: the single copy-paste source for the website form (metadata table, EN body, RU body, site changelog block).

- [ ] **Step 1: Whitelist the deliverable path**

Add this line to `.gitignore` after the `!/loadouts/` line:

```
!/docs/vostokmods/
```

- [ ] **Step 2: Write `docs/vostokmods/listing.md`**

````markdown
# Vostok Toolkit — Vostok Mods listing

Paste-ready content for https://vostokmods.net/explore/mods (form fields + description).

## Fields

| Field | Value |
|---|---|
| Title | `Vostok Toolkit` |
| Summary | `A quality-of-life toolkit for Road to Vostok — loadout presets, smarter tasks, thermal vision, kill stats, a dynamic killfeed and fast travel, all in one mod.` |
| Categories | `UI`, `Gameplay`, `Visuals`, `Fixes & Tweaks` |
| Tags | `Quality of Life`, `Equipment`, `Tools` |
| Game versions | `0.2.1.0` |
| Source code | `https://github.com/dgtball/VostokToolKit` |
| License | `MIT` |
| Dependency | Metro Mod Loader 3.4.2; MCM (language, settings) |
| Cover image | `ironman-restart.jpg` |

Gallery upload order: cover `ironman-restart.jpg`, then `loadout-presets.jpg`, `better-tasks.jpg`, `better-notes.jpg`, `thermal-vision.jpg`, `kill-stats-killfeed.jpg`, `fast-travel.jpg`.

## Description (English)

![](ironman-restart.jpg)

**Vostok Toolkit** bundles a full set of quality-of-life features for Road to Vostok into a single mod — from saved loadout presets to a reworked task flow, thermal vision, combat stats and fast travel. The panel and every hotkey are configured in MCM.

### Loadout Presets
Save your equipment and inventory as a preset, bind it to a hotkey, and restore a full kit in one press.

![](loadout-presets.jpg)

### Auto-equip
Items with slots are equipped immediately on pickup (MCM toggle).

### Matches stack in equip
Matches stack right into the equipment slot — no extra click.

### Better Tasks
Completed quests clean themselves up, tasks can be handed in partially, and the Notes tab shows per-item progress with icon rows.

![](better-tasks.jpg)
![](better-notes.jpg)

### Thermal Vision (NVG)
Replaces the night-vision goggles with a thermal view: the world glows by heat, mines are highlighted and friendly Nomads are marked, so threats stand out in poor visibility.

![](thermal-vision.jpg)

### Kill Stats & Killfeed
A HUD counter tracks your kills and how many hostiles are currently alive, and a dynamic killfeed reports combat events as they happen.

![](kill-stats-killfeed.jpg)

### Fast Travel
Move between maps, shelters and traders without the walk.

![](fast-travel.jpg)

### Ironman Restart
On death in Ironman mode, the inactive Load Game button is replaced with a Restart button that restarts the permadeath run. A bonus Apartments map is included.

![](ironman-restart.jpg)

---

**Requirements**
- Road to Vostok 0.2.1.0
- Metro Mod Loader 3.4.2
- MCM — for language and per-feature settings

**Default hotkey**
- Toggle panel: `F3` (configurable in MCM)

**Interface language**
- RU / EN, switched in MCM (General → Language)

**Compatibility**
- Compatible with LateStart. Tested alongside ElegantHUD, JCM and other common mods. Conflicts are unlikely but not impossible.

**Credits**
- Juuzoz' Cheat Menu [JCM] by juuzoz_ — the starting point for the loadout idea
- Thermal Vision by Vito921 — inspiration for the thermal rework
- Partial Task Hand-In by Ryujiro — inspired partial task hand-in
- and the other modders who keep the game interesting

**Development note**
- This project is developed with the assistance of generative AI.

**License**
- MIT. Community mod, not affiliated with Road to Vostok or its author.

## Description (Russian block, appended after the English)

---

## Vostok Toolkit (RU)

**Vostok Toolkit** объединяет набор quality-of-life функций для Road to Vostok в одном моде: сохранённые сеты снаряжения, переработан функционал заданий, тепловизор, боевую статистику и быстрое перемещение. Панель и функции настраиваются в MCM.

### Сеты (Loadout Presets)
Сохрани экипировку и инвентарь как сет, назначь горячую клавишу и используй одним нажатием.

### Автоэкипировка (Auto-equip)
Предметы со слотами надеваются сразу при подборе (тогл в MCM).

### Спички в экипировке (Matches stack in equip)
Спички стакаются сразу в слоте экипировки.

### Better Tasks
Выполненные задания самоочищаются, задания можно сдавать по частям, вкладка Notes показывает прогресс по предметам рядами иконок.

### Тепловизор (NVG)
Заменяет ПНВ на Тепловизор: Мины подсвечиваются, противники заметны при плохой видимости, кочевникам добавлен маркер ▼.

### Счётчик убитых и Killfeed
HUD-счётчик отслеживает убийства и число живых противников, а динамичная лента убийств сообщает о боевых событиях по ходу.

### Телепорт (Fast Travel)
Перемещение между картами, убежищами и торговцами без ходьбы.

### Ironman Restart
После смерти в Ironman неактивная кнопка Load Game заменяется кнопкой Restart, перезапускающей permadeath-забег. Бонусом добавлена карта Apartments.

**Требования**
- Road to Vostok 0.2.1.0
- Metro Mod Loader 3.4.2
- MCM — язык, настройки функций

**Язык интерфейса**
- RU / EN, переключается в MCM (General → Language)

## Changelog (site tab)

4.15.1 — Initial public release

Added:
- Loadout presets with hotkey binding
- Auto-equip: items with slots are equipped on pickup (MCM toggle)
- Matches and other stackables top up the equipped slot without extra clicks
- Better Tasks: completed-quest auto-cleanup, partial hand-in, Notes icon rows
- Thermal vision (NVG): world heat glow, mine highlighting, friendly markers
- Kill stats HUD and dynamic killfeed
- Fast travel between maps, shelters and traders
- Ironman Restart button and the Apartments map
- RU / EN interface language switch in MCM
````

- [ ] **Step 3: Verify every gallery image reference matches a file in `assets/`**

```powershell
$names = Select-String -Path docs\vostokmods\listing.md -Pattern '!\[\]\(([^)]+)\)' -AllMatches |
  ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
$missing = $names | Where-Object { -not (Test-Path (Join-Path 'assets' $_)) }
if ($missing) { "MISSING: $missing" } else { "all image refs resolve" }
```
Expected: `all image refs resolve`.

- [ ] **Step 4: Commit**

```powershell
git add .gitignore docs/vostokmods/listing.md
git commit -m "docs: add Vostok Mods listing (metadata, EN+RU, changelog)"
```

---

### Task 4: Update `README.md`

**Files:**
- Modify (overwrite): `README.md`

**Interfaces:**
- Consumes: asset basenames from Task 1; copy consistent with `docs/vostokmods/listing.md` (Task 3).

- [ ] **Step 1: Overwrite `README.md`**

```markdown
# Vostok Toolkit

A quality-of-life toolkit for **Road to Vostok** — loadout presets, smarter tasks, thermal vision, kill stats, a dynamic killfeed and fast travel, all in one mod.

![Ironman Restart](assets/ironman-restart.jpg)

**Version:** 4.15.1 · **Loader:** Metro Mod Loader 3.4.2 · **Game:** 0.2.1.0 · **Language:** RU / EN

## Features

| Feature | What it does |
|---|---|
| **Loadout Presets** | Save equipment/inventory as a preset and bind it to a hotkey. |
| **Auto-equip** | Items with slots are equipped on pickup (MCM toggle). |
| **Matches stack in equip** | Matches stack right into the equipment slot. |
| **Better Tasks** | Completed-quest auto-cleanup, partial hand-in, Notes icon rows. |
| **Thermal Vision (NVG)** | World heat glow, mine highlighting, friendly Nomad markers. |
| **Kill Stats & Killfeed** | HUD kill/enemy counter and a dynamic killfeed. |
| **Fast Travel** | Move between maps, shelters and traders. |
| **Ironman Restart** | Death-screen Restart button for permadeath runs (+ Apartments map). |

## Installation

1. Install Metro Mod Loader for Road to Vostok.
2. Download `Loadouts.vmz` from [Releases](https://github.com/dgtball/VostokToolKit/releases).
3. Drop it into `Road to Vostok\mods\`.
4. Launch the game.

## Usage

- Toggle panel: `F3` (configurable in MCM).
- Presets live in `user://MCM/vostok-toolkit/VTKsets.json`; interface language in MCM (General → Language).

## Building from source

`Loadouts.vmz` is a zip of the contents of `loadouts/`: `mod.txt` and `mods/` at the archive root (no top-level `loadouts` folder). Zip the folder and rename to `.vmz`, or run `pack.ps1`.

## Repository layout

- `loadouts/mod.txt` — name, id, version, autoload
- `loadouts/mods/VTK/*.gd` — mod source (prefix `VTK`)
- `assets/` — images for the README and the Vostok Mods listing

## Compatibility

Compatible with LateStart. Tested alongside ElegantHUD, JCM and other common mods. Conflicts are unlikely but not impossible.

## Credits

- Juuzoz' Cheat Menu [JCM](https://vostokmods.net/mod/juuzoz-cheat-menu-jcm) by juuzoz_ — the starting point for the loadout idea
- [Thermal Vision](https://www.nexusmods.com/roadtovostok/mods/141) by Vito921 — inspiration for the thermal rework
- [Partial Task Hand-In](https://modworkshop.net/mod/56789) by Ryujiro — inspired partial task hand-in

## Development note

This project is developed with the assistance of generative AI.

## License

[MIT](LICENSE). Community mod, not affiliated with Road to Vostok or its author.
```

- [ ] **Step 2: Verify the headline image resolves**

Run: `Test-Path assets\ironman-restart.jpg`
Expected: `True`.

- [ ] **Step 3: Commit**

```powershell
git add README.md
git commit -m "docs(readme): rework for Vostok Mods listing (EN, screenshots, dev note)"
```

---

### Task 5: Extend the encoding scanner to docs and run full verification

**Files:**
- Modify: `.check/encoding_check.py` (the `files = ...` line; add a `DOCS` list)

**Interfaces:**
- Consumes: `README.md`, `CHANGELOG.md`, `docs/**/*.md` from Tasks 2–4.

- [ ] **Step 1: Extend the scanned file list**

Replace the line:

```python
files = sorted(glob.glob(r"D:\RTVMOD\loadouts\mods\VTK\*.gd")) + [r"D:\RTVMOD\loadouts\mod.txt"]
```

with:

```python
DOCS = [r"D:\RTVMOD\README.md", r"D:\RTVMOD\CHANGELOG.md"] + sorted(glob.glob(r"D:\RTVMOD\docs\**\*.md", recursive=True))
files = sorted(glob.glob(r"D:\RTVMOD\loadouts\mods\VTK\*.gd")) + [r"D:\RTVMOD\loadouts\mod.txt"] + [p for p in DOCS if os.path.exists(p)]
```

- [ ] **Step 2: Run the scanner**

Run: `python .check\encoding_check.py`
Expected: new lines for `README.md`, `CHANGELOG.md`, `listing.md` (and the spec/plan) all show `ok` (or blank notes), `PROBLEMS: 0`, exit code 0. Any `MOJIBAKE`, `REPLACEMENT-CHAR`, `BOM`, `NOT UTF-8`, or `MIXED-EOL` note is a failure — fix the offending file and re-run.

- [ ] **Step 3: Cross-check the copy is identical between listing.md and CHANGELOG.md**

Confirm by eye that the changelog block in `docs/vostokmods/listing.md` lists the same bullets as `CHANGELOG.md`.
Expected: the changelog block in `listing.md` matches `CHANGELOG.md` apart from the `Initial public release` line (10 bullets).

- [ ] **Step 4: Review the full change set**

Run: `git status --short` and `git log --oneline -5`
Expected: only `assets/*` renames + `logo.jpg` deletion, `CHANGELOG.md`, `docs/vostokmods/listing.md`, `.gitignore`, `README.md`, `.check/encoding_check.py` changed. **Nothing under `loadouts/`.**

- [ ] **Step 5: Commit**

```powershell
git add .check/encoding_check.py
git commit -m "chore(check): scan markdown docs for mojibake"
```

---

## Manual publication (not an agent task)

These steps run on the website and require the site account:

1. Sign in (Discord).
2. Create mod: Title / Summary from `docs/vostokmods/listing.md` → Fields.
3. Set Categories and Tags from the same table.
4. Game version `0.2.1.0`.
5. Build `Loadouts.vmz` (`pack.ps1`) and upload it as version `4.15.1`.
6. Upload the gallery images in the listed order; cover = `ironman-restart.jpg`.
7. Paste the EN description, then the RU block; inline images point at the uploaded gallery URLs.
8. Links → Source code; License `MIT`; Changelog block; Development note.

## Self-Review

- **Spec coverage:** metadata fields → Task 3; EN + RU copy → Task 3 (README mirror → Task 4); assets/cover → Task 1; changelog `4.15.1` → Task 2 + Task 3; repo changes → Tasks 2–4; disclosure note → Tasks 3–4; new features (Auto-equip, Matches stack in equip) → Tasks 2, 3, 4; version/game strings → Global Constraints + Tasks 3–4.
- **Placeholder scan:** none; every file's full content is inline. Auto-equip / Matches have no screenshots (mechanics); item deletion is out of this release.
- **Name consistency:** asset basenames are identical across Task 1 (produces), Task 3 (fields + gallery order + inline refs), and Task 4 (README refs). Changelog bullets match between Task 2 and Task 3 (same bullets minus the `Initial public release` line). `ironman-restart.jpg` is the cover in Task 3 and the manual steps.
