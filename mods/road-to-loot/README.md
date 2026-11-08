# Road To Loot

**Version:** 0.7.1

Standalone loot-rarity mod for Road to Vostok. Weapons and clothing found in
containers, on bodies and lying on the ground roll a per-instance rarity tier
with passive affixes.

> **Do not remove this mod from an existing save.** It stores two extra fields
> on every item. Removing the mod makes the game drop those values.

## What it does

- Every weapon and piece of clothing you find rolls a rarity: Common (blue),
  Rare (purple) or Legendary (gold).
- Rarer items carry more passive affixes (Common 1, Rare 2, Legendary 3).
- Affixes show in the item tooltip; the cell border is tinted by rarity.
- Affixes on worn clothing change gameplay: carry capacity, insulation, sprint
  speed, stamina/hunger/thirst/sanity drain and health regeneration.
- Affixes on weapons change gameplay: damage, recoil and fire rate; damage and
  regeneration gain a bonus while your health is below 30%.
- Military and elite containers shift the odds upward.

## Affixes & maximum bonuses

Stats can come from multiple affixes and items; totals add up, so these are
theoretical single-item maxima unless an effect states otherwise.

| Stat | Category | Max per affix (T3) | Typical full-set (best case) |
|---|---|---|---|
| Capacity | Clothing | +6 kg | +36 kg (9 slots × 4 kg est.) |
| Insulation | Clothing | +12-16% | up to 90% of total protection |
| Regen | Clothing | 0.04 HP/s | 0.36 HP/s |
| Low-HP regen | Clothing | 0.04 HP/s | 0.36 HP/s |
| Sanity drain | Clothing | -12% | up to zero drain |
| Thirst/Hunger/Stamina drain | Clothing | -9% | up to zero drain, floored at 20% cost |
| Sprint | Clothing | +6% | +54% (~x1.54 multiplier) |
| Noise | Clothing | 16% | earshot floor ~4 m |
| max_hp | Clothing | +4% | +36% (~x1.36) |
| Perception | Clothing | 30% | ~100% chance |
| Protection | Clothing (Helmet/Armor plate) | +1 level | +2-3 levels || Damage | Weapon | +12% | up to ~2.4x (per affix stack) |
| Recoil | Weapon | -12% | up to ~0.7x (multiplier) |
| Fire rate | Weapon | +8% | up to ~1.4x (cooldown) |
| Low-HP damage | Weapon | +20% | up to ~5-6x bonus |
| Wear | Weapon | +12% extra | up to ~50% extra |

Notes:
- Base stats on each item are unaffected by RTL.
- Drain effects are floored (
  factor >= 0.2) to avoid the game stalling them completely.
- Noise has a floor of 4 m (never fully silent).

## Install

1. Copy `RoadToLoot.vmz` into the game's `mods` folder.
2. Mod Configuration Menu is optional, but recommended for the debug tools.

## Debug (for testing)

Enable "Debug mode" in the MCM menu: force a rarity tier for all finds, or
re-roll the item under the cursor with the debug hotkey.

## Build (from the repo)

```powershell
powershell -ExecutionPolicy Bypass -File pack.ps1
```

## Manual test checklist (before a release)

- Container weapon rolls a tier (check the log with "Log rolls").
- Tooltip shows the rarity line and affixes; the cell border matches.
- Moving/dropping/stashing/reloading keeps the tier and affixes.
- Travelling to another map or leaving a shelter keeps the tier and affixes on
  everything in the backpack, on the body and in the catalog.
- Corpse loot rolls.
- World loot (weapons and clothing on the ground) rolls a tier, and the tier
  survives picking it up.
- "Force tier" debug applies to all finds.
- The re-roll hotkey updates the hovered item.
- Capacity, insulation and sprint on the character screen change with worn
  affixes and return to normal when the item is removed.
- Stamina, hunger, thirst and sanity drain slower with the matching affix.
- Health regenerates with a regen affix, faster below 30% health.
- A weapon with a damage, recoil or fire-rate affix behaves differently from a
  plain copy of the same weapon; removing it restores the plain behaviour.
- Runs without MCM installed.
- No save errors with the mod present.
- Coexists with Evolve and ItemClarity.


