# Changelog

## [1.2.1] - 2026-11-18

### Changed
- `Unbreakable` now follows the equipment slot the item actually sits in, so a
  weapon, helmet or rig moved to another slot keeps its bonus.

## [1.2.0] - 2026-11-18

### Added
- `Never Jam` affix for firearms from Rare upward: a weapon above 0% condition
  no longer jams. A broken weapon still jams and still needs repair.
- `Unbreakable` affix for Legendary weapons, helmets and rigs: condition never
  drops below the value the item was found with, and repairs still work.
  On helmets and rigs it means the armour never wears out at all.
- `Battery Save` affix for the flashlight, NVG and cassette player: the battery
  drains 5-10% / 20-50% / 70-90% slower by tier.
- `Extra Loot` and `Sanity Drain` now also roll on the watch and the map.

### Changed
- `Wear` now slows weapon wear instead of speeding it up: it is a chance not to
  lose condition on a shot, shown as `Wear Resistance` (10-20% / 20-35% /
  35-60% by tier).
- Balance caps are gone from every affix, so strong Legendary sets can now
  stack far past the old limits.

### Fixed
- Carry capacity and insulation values in the tooltip no longer stay white
  after a coloured affix is shown.
- Debug mode can be enabled by adding `debug_enabled=true` to `config.ini`,
  and the line is no longer dropped when the game rewrites the file.

## [1.1.0] - 2026-11-12

### Added
- `ammo_save` affix for firearms: a chance that a shot does not spend a round
  (5-10% / 10-15% / 15-50% by tier).

### Changed
- Rarity frequency now defaults to 0.5, so roughly half as many items are
  enchanted.
- Tier affix counts are ranges: Common 1-2, Rare 2-3, Legendary 3-5. Items with
  fewer distinct stats get as many as they have.
- Legendary firearms can now carry five affixes.

### Fixed
- The `wear` affix now works on weapons that have no damage or recoil affix.

## [1.0.0] - 2026-11-08

### Added
- Registry author + host source for vostokmods metadata.

## [0.7.1] - 2026-11-08

### Changed
- Trimmed affix ranges (roughly ×2.5) to keep builds balanced without hard caps.

## [0.7.0] - 2026-11-08

### Added
- `noise` affix for clothing: reduces AI hearing distance when the affix is
  present.
- `vitality` affix for clothing: increases maximum health (scaled).

### Changed
- RTL now loads before Evolve (priority -1) so noise and vitality replace
  hooks land first.

## [0.6.1] - 2026-11-08

### Added
- `wear` affix for weapons: increases the chance that the weapon loses
  condition when fired (no knives).

## [0.6.0] - 2026-11-08

### Added
- Protection affixes on helmets now do something: an extra level of armor
  protection applies for the duration of the hit check and resets afterward.
- Perception affixes give a chance to roll an extra item when you open a
  container.

### Fixed
- Health regeneration no longer caps at 100 when your maximum health is
  raised by another mod.

## [0.5.0] - 2026-11-08

### Added
- Passive affixes on worn clothing now work: carry capacity, insulation, sprint
  speed, slower stamina/hunger/thirst/sanity drain, and health regeneration
  that gets stronger below 30% health.
- Passive affixes on weapons now work: damage, recoil and fire rate, with a
  damage bonus while your health is below 30%.

### Changed
- Noise and protection affixes are still informational only for now.

## [0.4.1] - 2026-10-29

### Fixed
- Dropped weapons and clothing keep their rarity and affixes: on the ground,
  after picking them up again, and after leaving and re-entering a shelter.

## [0.4.0] - 2026-10-29

### Added
- Weapons and clothing lying on the ground now roll a rarity and passive
  affixes, the same way items found in containers do.
- The roll is kept when you pick the item up, and it stays on the item after
  saving and loading.

## [0.3.4] - 2026-10-29

### Fixed
- Rarity and affixes no longer reset when travelling to another map or leaving a shelter.
- The mod menu now shows the current version instead of an old one.
- The loader no longer logs an error about a hook that could never fire.

## [0.3.2] - 2026-10-29

### Fixed
- Rarity and affixes no longer disappear from a container's contents after closing and reopening it.

## [0.3.1] - 2026-10-29

### Fixed
- Removed two leftover debug listeners that could never fire; this clears the loader warnings about them in the log. No gameplay change.

## [0.3.0] - 2026-10-28

### Added
- Knives and belt pouches can now drop with a rarity and passive affixes.

### Changed
- Armour plates and weapon attachments no longer drop with a rarity.

### Fixed
- Affixes now actually roll on found items (previously the roll failed and items came out without them).
- Knives no longer roll recoil or fire rate bonuses, which they cannot use.
