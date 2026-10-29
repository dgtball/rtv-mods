# Changelog

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
