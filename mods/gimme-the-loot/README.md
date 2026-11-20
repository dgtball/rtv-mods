# **Gimme the Loot**

**Version:** 1.2.3  
**Mod ID:** `gimme-the-loot`  
**Author:** CaptiveAI

Per-instance rarity tiers & real passive affixes for weapons and clothing
you find in Road to Vostok (containers, corpses, ground-spawned loot).

> **Do not remove this mod from an existing save.** It stores extra fields
> on every item (`loot_tier`, `loot_affixes`). Removing the mod drops them.

## What it does

- **Common** — blue border, 1-2 affixes
- **Rare** — purple border, 2-3 affixes
- **Legendary** — gold border, 3-5 affixes

Affixes are **real** (not cosmetic), e.g. carry capacity, insulation, sprint
speed, stamina/hunger/thirst/sanity drains, regen, damage, recoil, fire rate,
never jam, unbreakable gear, frost resistance and slower battery drain.

## Installation

1. Copy `GimmeTheLoot.vmz` into the game's `mods` folder.
2. Mod Configuration Menu is optional but recommended.

## Contents summary

- Per-instance tier + affixes survive pick-up, save/load and map travel.
- Nested implants and plates can receive `protection` and `Wear` affixes.
- Optional integration with Evolve/ItemClarity **is NOT recommended** for
  stability: use only one of the three mods.

## Table: maximum affix values (T3)

Stat | Max |
|---|---|
| Capacity | +6 kg |
| Insulation | +12–16% |
| Regen | 0.04 HP/s |
| Low-HP regen | 0.04 HP/s |
| Sanity drain | −12% |
| Thirst/Hunger/Stamina drain | −9%–−12% |
| Sprint | +6% |
| Noise (AI range) | 16% |
| max_hp | +30% (1-5% / 5-15% / 15-30% by tier) |
| Extra Loot | ~100% chance |
| Protection | +1 level |
| Damage | +12% |
| Recoil | −12% |
| Fire rate | +8% |
| Low-HP damage | +20% |
| Wear Resistance | up to +60% |
| Ammo save | +50% |
| Battery save | up to 90% |
| Never Jam | Rare and above |
| Unbreakable | Legendary weapons, helmets and rigs |
| Frost Resistant | Legendary clothing: no frostbite while worn |

Notes:
- There are no balance caps any more: stacking several Legendary pieces can
  push a value all the way to its natural limit (a drain to 0, a chance to 100%).
- Noise is floored at ~4 m.
- `Extra Loot` and `Sanity Drain` also roll on the watch and the map.
- `Never Jam` needs a working weapon: at 0% condition it still jams.
- `Unbreakable` holds condition at the value the item was found with; a repair
  raises that value.
- `Frost Resistant` prevents frostbite only while the item is worn.

## MCM settings

### 01. Display
- Paint item cells
- Show affix block in tooltip

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