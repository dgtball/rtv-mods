# Road to Vostok mods

Four independent mods for **Road to Vostok**, each in its own folder under `mods/`. They ship as
separate `.vmz` archives and can be installed on their own — there is no shared runtime code.

| Mod | What it does | Version | README |
|---|---|---|---|
| **Vostok Toolkit** (`vostok-toolkit`) | Loadout presets, partial task hand-in, Notes icon rows, kill stats and killfeed, fast travel | 5.2.0 | [mods/vostok-toolkit/README.md](mods/vostok-toolkit/README.md) |
| **ThermalVTK** (`thermal-vtk`) | Standalone thermal vision / NVG overlay with heat glow and ESP | 2.2.0 | [mods/thermal-vtk/README.md](mods/thermal-vtk/README.md) |
| **Road To Loot** (`road-to-loot`) | Per-instance rarity tiers and affixes for looted weapons and clothing | 0.3.4 | [mods/road-to-loot/README.md](mods/road-to-loot/README.md) |
| **Freeze for JCM** (`jcm-freeze`) | Freezes NPCs, the BTR and the helicopter on demand (JCM addon) | 1.2.0 | [mods/jcm-freeze/README.md](mods/jcm-freeze/README.md) |

> **Do not run Vostok Toolkit together with ThermalVTK** — both patch the game's NVG overlay.
> See the Toolkit README for the exact list of conflicts.

## Layout

```
mods/<slug>/       one folder per mod
  mod.txt          id, version, autoload, hooks  (slug = id)
  mods/<Folder>/   the scripts that end up inside the .vmz
  README.md        player-facing description
  CHANGELOG.md     release history
.check/            headless Godot stand: parse check + tests
dist/              built archives (not in git)
pack.ps1           builds all (or one) mod into dist/
```

## Building

Requires PowerShell 5.1 (Windows) and Python 3 for the checks.

```powershell
powershell -ExecutionPolicy Bypass -File pack.ps1 -All          # all four archives
powershell -ExecutionPolicy Bypass -File pack.ps1 -Mod thermal-vtk
```

Archives land in `dist/` and keep their historical names, so they drop straight into the game's
`mods` folder:

| Mod | Archive |
|---|---|
| Vostok Toolkit | `dist/Loadouts.vmz` |
| ThermalVTK | `dist/ThermalVTK.vmz` |
| Road To Loot | `dist/RoadToLoot.vmz` |
| Freeze for JCM | `dist/Freeze.vmz` |

The build writes `version.txt` next to each mod's scripts (taken from `mod.txt`) and keeps the
`**Version:**` line of that mod's README in sync. Shipped GDScript is stripped of comments and blank
lines; the sources in this repository are untouched.

## Checking

```powershell
py -3 .check\layout_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```

`check.ps1` copies every mod's sources into the headless Godot project under `.check/project/`,
parse-checks each script and runs all 41 test scripts. Godot **4.6.3** must be on `PATH`, otherwise
pass `-Godot <path to Godot_*_console.exe>`.

`layout_check.py` guards the Toolkit loadout UI against layout regressions: symbols that must not
come back, symbols that must stay, and the bodies of the functions that carry them.

## License

MIT — see [LICENSE](LICENSE).
