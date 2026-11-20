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

## Table: affix values by tier

| Stat                               | Common         | Rare           | Legendary      |
| ---------------------------------- | --------------- | --------------- | --------------- |
| damage                             | 2–6%           | 4–8%           | 6–12%          |
| recoil                             | −1–−2%         | −2–−4%         | −4–−6%         |
| wear                               | 10–20%         | 20–35%         | 35–60%         |
| low_hp_damage                      | 5–10%          | 8–14%          | 12–20%         |
| ammo_save                          | 5–10%          | 10–15%         | 15–50%         |
| never_jam                          | —              | Yes            | Yes            |
| unbreakable                        | —              | —              | Yes            |
| regen                              | 0.005–0.01 HP/s | 0.01–0.025 HP/s | 0.02–0.04 HP/s |
| low_hp_regen                       | 0.015 HP/s     | 0.025 HP/s     | 0.04 HP/s      |
| capacity                           | 1–2 kg         | 2–4 kg         | 4–6 kg         |
| stamina_drain                      | −3–−6%         | −5–−9%         | −8–−12%        |
| insulation                         | 4–8%           | 8–12%          | 12–16%         |
| thirst_drain                       | −3–−6%         | −5–−9%         | −8–−12%        |
| hunger_drain                       | −3–−6%         | −5–−9%         | −8–−12%        |
| sanity_drain                       | −3–−6%         | −5–−9%         | −8–−12%        |
| noise                              | −5–−8%         | −7–−12%        | −10–−16%       |
| sprint                             | 1–2%           | 2–4%           | 4–6%           |
| extra_loot                         | 1%             | 2–3%           | 3–4%           |
| protection                         | —              | +1 level       | +1 level       |
| max_hp                             | 1–5%           | 5–15%          | 15–30%         |
| frost_resistant                    | —              | —              | Yes            |
| battery_save                       | 5–10%          | 20–50%         | 70–90%         |

`—` means the affix does not roll at that tier. Negative values are bonuses:
drain, recoil and AI detection range go down.

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