# Vostok Toolkit

Everything a Vostok run needs in one mod: loadout presets, dynamic seasons, fast travel, kill stats and an ironman restart.

**Version:** 5.5.0 · **Loader:** Metro Mod Loader 3.4.2 · **Game:** 0.2.3.0 · **Language:** RU / EN

## Features

| Feature | What it does |
|---|---|
| **Ironman Restart** | Death-screen Restart button for permadeath runs (+ Apartments map). |
| **Loadout Presets** | Save equipment/inventory as a preset and bind it to a hotkey. |
| **Dynamic seasons** | Play and watch as one season gives way to another. |
| **Auto-equip** | Items with slots are equipped on pickup (MCM toggle). |
| **Matches stack in equip** | Matches stack right into the equipment slot. |
| **Item delete** | Delete an item straight from the inventory. |
| **Better Tasks** | Completed-quest auto-cleanup, partial hand-in, Notes icon rows. |
| **Kill Stats & Killfeed** | HUD kill/enemy counter and a dynamic killfeed that shows your own name (set in MCM). |
| **Fast Travel** | Move between maps, shelters and traders. |

## Installation

1. Install Metro Mod Loader for Road to Vostok.
2. Download `VostokToolkit.vmz` from [Releases](https://github.com/dgtball/rtv-mods/releases).
3. Delete the old `Loadouts.vmz` from `Road to Vostok\mods\` if you have one: 5.4.0 renamed the archive, and two copies load the mod twice.
4. Launch the game.

## Usage

- Toggle panel: `F3` (configurable in MCM).
- Presets live in `user://MCM/vostok-toolkit/VTKsets.json`; interface language in MCM (General → Language).

## Building from source

`VostokToolkit.vmz` is a zip of the contents of `mods/vostok-toolkit/`: `mod.txt` and `mods/` at the archive root (no top-level folder). Run `pack.ps1 -Mod vostok-toolkit` from the repository root; the archive lands in `dist/`.

## Repository layout

- `mods/vostok-toolkit/mod.txt` — name, id, version, autoload
- `mods/vostok-toolkit/mods/VTK/*.gd` — mod source (prefix `VTK`)
- `mods/vostok-toolkit/CHANGELOG.md` — release history

## Compatibility

Compatible with LateStart. Tested alongside ElegantHUD, JCM and other common mods. Conflicts are unlikely but not impossible.

## Credits

- [Juuzoz' Cheat Menu - JCM](https://vostokmods.net/mod/juuzoz-cheat-menu-jcm) by juuzoz_ — the starting point for the loadout idea
- [Partial Task Hand-In](https://modworkshop.net/mod/56789) by Ryujiro — inspired partial task hand-in
- [Season Expansion System](https://modworkshop.net/mod/56781) by Peter Master — I believe he will return and update his mods.

## Development note

This project is developed with the assistance of generative AI.

## License

[MIT](LICENSE). Community mod, not affiliated with Road to Vostok or its author.
