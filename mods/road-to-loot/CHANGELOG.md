# Changelog

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
