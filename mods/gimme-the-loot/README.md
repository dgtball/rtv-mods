# **Gimme the Loot**

**Version:** 0.7.2  
**Mod ID:** `gimme-the-loot`  
**Author:** CaptiveAI

Per-instance rarity tiers & real passive affixes for weapons and clothing
you find in Road to Vostok (containers, corpses, ground-spawned loot).

> **Do not remove this mod from an existing save.** It stores extra fields
> on every item (`loot_tier`, `loot_affixes`). Removing the mod drops them.

## What it does

- **Common** — blue border, 1 affix
- **Rare** — purple border, 2 affixes
- **Legendary** — gold border, 3 affixes

Affixes are **real** (not cosmetic), e.g. carry capacity, insulation, sprint
speed, stamina/hunger/thirst/sanity drains, regen, damage, recoil, fire rate.

## Installation

1. Copy `GimmeTheLoot.vmz` into the game's `mods` folder.
2. Mod Configuration Menu is optional but recommended.

## Contents summary

- Per-instance tier + affixes survive pick-up, save/load and map travel.
- Nested implants and plates can receive `protection` and `Wear` affixes.
- Optional integration with Evolve/ItemClarity **is NOT recommended** for
  stability: use only one of the three mods.

## Table: maximum affix values (T3)

<|constrain|> Stat | Max |
|---|---|
| Capacity | +6 kg |
| Insulation | +12–16% |
| Regen | 0.04 HP/s |
| Low-HP regen | 0.04 HP/s |
| Sanity drain | −12% |
| Thirst/Hunger/Stamina drain | −9%–−12% |
| Sprint | +6% |
| Noise (AI range) | 16% |
| max_hp | +4% per affix |
| Extra Loot | ~100% chance |
| Protection | +1 level |
| Damage | +12% |
| Recoil | −12% |
| Fire rate | +8% |
| Low-HP damage | +20% |
| Wear | +12% extra |

Notes:
- Drains are floored at ~20% so they cannot fully stop.
- Noise is floored at ~4 m.

## MCM settings

### 01. Display
- Paint item cells
- Show affix block in tooltip
- Rarity palette

### 02. Balance
- Rarity frequency (0.5–2.0×)
- Container context hint

Debug section is **dev-only** (requires `user://rtl_dev` file).

## Changelog

See `CHANGELOG.md`.

## Links
- nexusmods.com / moddb: search **Gimme the Loot**
- GitHub repo: RTVMOD (branch main, folder `mods/gimme-the-loot`)
PY