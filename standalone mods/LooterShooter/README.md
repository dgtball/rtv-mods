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
