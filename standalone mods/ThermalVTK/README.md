# ThermalVTK

**Version:** 1.7.5

Standalone NVG / thermal-vision mod for Road to Vostok. It is the thermal
feature of Vostok Toolkit, packaged on its own.

> **Do not run this together with Vostok Toolkit.** Both mods patch the same
> in-game NVG material and will fight over it. Install one or the other.

## What it does

- Replaces the vanilla NVG overlay shader with an adjustable one (noise,
  brightness, world palette).
- While NVG is worn, a single thermal view: NPCs get a coloured body outline
  by their awareness state (idle, in combat, defending), with friendly Nomads
  always green. The outline is a clean silhouette with an adjustable rim. The
  body cools after death, dimming and fading out.
- Mines light up while thermal vision is on.
- World palettes (Classic, Amber, Forest, Ice) and winter auto-dimming.
- A hotkey to turn the thermal layer on and off, and a hotkey to cycle the
  world palette, each with an on-screen notification.

## Install

1. Copy `ThermalVTK.vmz` into the game's `mods` folder.
2. Make sure Mod Configuration Menu is installed.
3. Open the MCM menu, set `ThermalVTK` up (bind the toggle hotkey there).

## Build (from the repo)

```powershell
powershell -ExecutionPolicy Bypass -File pack.ps1
```
