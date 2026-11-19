# Battery Extractor

**Version:** 1.0.0

A small mod that lets you take the battery back out of your battery-powered gear, with whatever charge is left in it.

## What it does

- Right-click a `Polaris`, `Narva` or `Phoenix` flashlight, the `PV7` nightvision goggles or the cassette player to get a new **Extract battery** action in the context menu.
- The device is drained to zero and you receive a `Battery (partial)` item carrying the charge that was left in it — a device at 37 % gives you a 37 % battery.
- Dragging that partial battery back onto a device charges it by exactly that amount. Ordinary batteries found in the world still charge a device to 100 %, unchanged.
- Devices with no charge left, and other electronics, never show the action.

## Install

1. Copy `BatteryExtractor.vmz` into the game's `mods` folder.
2. Enable the mod in the mod loader and start the game.

## How it works

Battery charge in this game is just a number on the item in the slot. The mod watches the context menu and adds its own button when a supported item is under the cursor. The battery it creates is a copy of the game's own `Batteries` item with the remaining charge written on it, so the game's normal drag-and-drop charging keeps working. No game files are written to disk.

## Build (from the repo)

```powershell
powershell -ExecutionPolicy Bypass -File pack.ps1 -Mod battery-extractor
```
