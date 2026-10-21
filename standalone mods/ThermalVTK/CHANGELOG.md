# Changelog

## [1.7.2] - 2026-10-21

### Changed
- The NPC outline is now always the clean silhouette look.
- The corpse cooling time defaults to 30 s (adjustable up to 180 s).

### Removed
- The "Outline style", "Body fill" and "Fill opacity" settings: NPCs are outlined only, never filled.

## [1.7.1] - 2026-10-21

### Changed
- The body fill now reads as a translucent state colour (density is its own control); the warm-to-cold gradient and the separate "Fill style" setting are gone.
- Switching the "Outline style" picks a matching fill preset automatically (front-face → fill on, back-face → fill off), so you can still adjust the slider afterwards.
- The friendly-nomad marker shows only while the contour is on.

### Fixed
- The friendly-nomad marker shows a proper green again, and it no longer disappears on nearby nomads.
- The body fill keeps a distinct colour per state instead of washing out to white.
- Front-face outlines show a proper rim again (the rim was lost on the default style).
- Disabling the contour no longer leaves nomad markers floating.
- The palette-cycle hotkey does nothing while thermal vision is off (no palette change, no notification).

### Removed
- The "Fill style" setting (flat vs gradient); the body fill is now always a translucent state colour.
- The "See through walls" option; the contour no longer draws through geometry.

## [1.7.0] - 2026-10-20

### Added
- Friendly nomads now show a green diamond marker above them when thermal vision and the night-vision helmet are both on.
- A new "Outline style" setting: the cleaner front-face silhouette (default) or the older back-face look.
- A new "Fill style" setting: a flat state colour (default) or a warm-to-cold thermal gradient fill.

### Changed
- NPC colours are now three categories instead of four: Normal / idle, In combat, and Defending. The old "Alerted" and "Hunting" colours were merged into these, so any colours saved for them are dropped.
- The contour outline now draws a neater silhouette that hugs the body instead of the older inflated look.
- The default outline range is now 60 m so the view is less cluttered; it is still adjustable.
- Debug state labels now appear whenever the debug log is on, even with thermal vision off.

### Fixed
- The "Corpse cooling time" setting now takes effect: a dead NPC's outline cools from warm to cold over the configured time.

## [1.6.1] - 2026-10-20

### Fixed
- The body fill now uses the same state colour as the outline, so they always match after changing a state colour in the settings.
- The outline on a dead body now dims as the body cools, matching the fill.
- The debug state label no longer stays floating over a dead body.

## [1.6.0] - 2026-10-20

### Added
- A Fill opacity slider for the NPC body fill; the body now fills with the NPC's state colour.

### Changed
- F6 now cycles the world thermal palette instead of switching thermal modes.

### Removed
- The separate FULL thermal mode; contour is now the only mode.
- The Bot colour, Distance and Spotted flash settings.

## [1.5.0] - 2026-10-20

### Added
- In the debug log mode, every NPC now shows its AI state and the colour category the mod assigned, so the state dictionary can be checked while playing.

### Fixed
- The contour outline no longer disappears or changes colour when aiming a magnifying scope while the game's scope rendering is off.

## [1.4.0] - 2026-10-19

### Changed
- Contour ESP now only shows while the night-vision helmet is worn.
- In contour mode the world is shown as plain night vision, so the outlines no longer get washed out by the surrounding heat colours. Mines stay highlighted.
- The world no longer dims in winter.

### Fixed
- Toggling thermal vision off and on again no longer permanently removes the outlines of NPCs that are already in the scene.

## [1.3.1] - 2026-10-19

### Fixed
- Contour mode: your weapon now draws in front of the NPC outlines instead of being covered by them.
- The diagnostic log no longer writes the same message every frame, so it stays readable.

## [1.3.0] - 2026-10-19

### Added
- "Debug log" option under Diagnostics: writes a diagnostic log of the contour ESP to a file, for troubleshooting.

## [1.2.1] - 2026-10-19

### Fixed
- Contour ESP now actually draws: NPC outlines, body fill and the visibility flash were invisible because no NPC geometry matched the collector.

## [1.2.0] - 2026-10-18

### Added
- Contour ESP: NPCs get a coloured outline by their awareness state (idle, alerted, hunting, in combat), with friendly nomads always green.
- Body fill inside the outline: a warm-to-cold thermal gradient, cooling over a configurable time after death.
- Spotted flash: the body flashes when an NPC's own sensors see you.
- F6 switches between the contour view and the full-screen thermal view while NVG is worn.
- New settings for the contour: on/off, body fill, corpse cooling time, outline thickness, brightness, spotted flash and flash colour, per-state colours, outline range and see-through-walls range.

### Changed
- The floating marker over friendly Nomads is replaced by the green outline.

## [1.1.0] - 2026-10-15

### Added
- The mod loader now shows this mod's thumbnail and checks for updates.

## [1.0.0] - 2026-10-14

### Added
- Standalone thermal vision (NVG) release: bot heat glow, mine highlighting, friendly Nomad marker, world palettes and winter auto-dimming.
- Hotkey to toggle thermal vision, with an on-screen notification.
