# Changelog

## [2.5.1] - 2026-11-11

### Fixed
- The kill counter of RTV Mini HUD no longer turns into N/A while ThermalVTK
  is installed. Corpse cooling still starts as soon as the game marks an NPC
  dead.

## [2.5.0] - 2026-11-11

### Changed
- The daylight thermal picture is calibrated from in-game measurements:
  bright days now keep detail across the thermal range instead of washing
  out into a white field, and sunny snow fields no longer pin the whole
  frame to the top of the range.
- The night thermal picture is unchanged.

## [2.4.11] - 2026-11-11

### Fixed
- The Measure button of the live tuning panel works: on 2.4.10 every
  measurement failed.
- The daylight debug line now shows the mix value of the step it
  describes, not the previous one.

## [2.4.10] - 2026-11-11

### Added
- A live tuning panel for the daylight compensation (default F9). It is a
  diagnostics tool: it only works with the debug log enabled, pauses the
  game while open and saves nothing -- slider values live until the helmet
  comes off.

### Fixed
- The "Daylight strength" setting now actually applies to the picture; it
  used to be accepted in the menu and then ignored.

### Changed
- Minor performance improvements.

## [2.4.7] - 2026-11-10

### Fixed
- The palette hotkey (F6) no longer works while the thermal picture is off:
  with the helmet removed it used to change the palette in the background and
  show a toast for a colour nobody could see.

## [2.4.6] - 2026-11-02

### Changed
- Removed the experimental MCM knobs (mask resolution, cadence, fill opacity
  and fill grow) that were added for testing. Baseline mask settings restored
  to full quality by default; fill opacity fixed at 0.2.

## [2.4.5] - 2026-11-02

### Added
- 'Mask resolution' (50/75/100 %) and 'Mask cadence' (every frame or every
  other frame) now live in the MCM menu, so the 2nd-world-pass cost can be
  tuned without rebuilding.
- 'Fill grow' is exposed for the full-body silhouette.

### Fixed
- none.

## [2.4.4] - 2026-11-02

### Changed
- The mask viewport no longer renders positional shadow maps and uses a
  slightly coarser LOD; this lowers the cost of each NPC pass without
  touching the ring shape or the edge quality.
- 'Full body fill' opacity is now tunable from the menu (0.1..1.0), so the
  fill can be kept transparent while debugging the cost.

## [2.4.3] - 2026-11-02

### Changed
- ESP contours no longer draw while thermal vision is off: the goggles alone
  (vanilla night vision) keep the thermal picture, but the NPC outline now
  appears only with thermal vision switched on.

## [2.4.2] - 2026-11-02

### Fixed
- NPC outline lines are crisp again, with the same edge quality as before
  2.4.1: the outline is rendered at full screen resolution with the same
  antialiasing as the main picture.

## [2.4.1] - 2026-11-02

### Fixed
- Frame rate with NPC outlines enabled is back to the plain night-vision level
  when no NPC is in range; the outline no longer keeps rendering the whole
  world for nothing.
- Fights no longer halve the frame rate: the outline pass only covers the
  distance it can actually draw, so distant scenery is skipped.

## [2.4.0] - 2026-11-02

### Changed
- NPC contour colours no longer wash out in daylight, snow or after a palette
  change: the state colour is exact in every condition.
- Outlines are still cut by walls and by the weapon, and the x-ray reveal still
  reaches through walls.

### Note
- Looking through a magnifying scope with PIP on no longer shows contours
  inside the glass; the thermal picture there is unchanged.

## [2.3.0] - 2026-11-01

### Added
- "Daylight strength": 0 leaves the vanilla NVG exposure alone, 1 applies the
  daylight model in full. Exposure, key gain and the tone curve all follow that
  one factor, so ring colours stay put at any strength.

### Changed
- Daylight compensation now notices a roof, a canopy or deep shade: a sky probe
  every half second trims the light to 45% instead of assuming open sky.
- The light level is smoothed over about two seconds, so a passing storm no
  longer pops the frame.
- The clock, weather and indoor flags are read four times a second instead of
  every frame.
- "Daylight Brightness" is now "Highlight softness" (same key, same behaviour).

### Note
- The sim ships two seasons (1 summer, 2 winter). Vostok Toolkit maps its four
  seasons onto the same field, so ThermalVTK behaves identically with and
  without the toolkit installed.

## [2.2.4] - 2026-11-01

### Changed
- X-ray triggers use the same ring as the ESP instead of swapping it for a
  different, depth-free look. The ring always stays depth-tested; a live window
  adds an overlay that paints only the part of the silhouette the world hides,
  so the reveal no longer shows the model's inner contours and the two effects
  cannot double up.
- The overlay pulses for as long as the window stays open.
- The per-footstep HOOK line is gone from the diagnostic log; a reveal still
  logs one ESP line per tag.

- Rim 0 is now a deliberate full-body fill: a solid silhouette in the NPC state
  colour (calm yellow, combat red, defending blue), shown in the scope as well,
  instead of the blown-out white body the old pow(x, 0) produced.
- A reveal past the ESP Distance (a shot from 70 m with Distance at 60 m) draws
  the whole contour, so triggers still work where the ESP ring is silent.

## [2.2.3] - 2026-11-01

### Removed
- The dead layout module behind the old 1D label code (VTKLabelLayout.gd) and
  its headless test. Since 2.2.0 the 2D overlay lays out its own labels, so the
  module only kept a test alive. Nothing changes in game.

## [2.2.2] - 2026-11-01

### Added
- NPC nametags, the health readout and trigger timers have their own MCM switch
  ("NPC labels (debug)"), and they no longer need thermal vision or the NVG
  helmet: the debug log stays the master switch, the label toggle refines it.

### Changed
- MCM names: "NPC ESP", "Mine ESP" and "Daylight Brightness"; the nomad marker
  is now "Nomads marker" and sits third in the thermal section, right after the
  palette hotkey.
- The friendly-nomad marker is an inverted triangle instead of a diamond: it
  points at the head, and it obeys the Distance setting like the outlines, so
  there is no marker over bots out of range and no oversized glyph at range.
- The health bar is gone: the readout is one line under the feet together with
  the trigger timer, for example "[walk 1.0s 5m] [HP: 64]". The trigger text
  uses the NPC state colour instead of a fixed yellow.
- The diagnostic log no longer mirrors every line into godot.log; it writes to
  user://MCM/thermal-vtk/debug.log only, and rotates to debug.log.old once a
  session starts with a file over 4 MB.
- The heartbeat line fires every 5 seconds and only when the numbers change;
  the scope probe fires once a second instead of twice.

### Fixed
- Debug labels stayed hidden without NVG because they were built from the
  outline working set, which is empty while no layer is active.

## [2.2.0] - 2026-10-26

### Changed
- NPC nametags (shown together with the debug log) are now drawn as a 2D overlay, so they stay crisp and follow their own colour instead of being repainted by the thermal palette.
### Added
- An independent toggle for the friendly-nomad diamond (MCM, under the thermal vision section) — on by default.

## [2.1.0] - 2026-10-25

### Added
- X-ray Triggers now work on their own: shots, shouts and footsteps show through walls even with NPC highlighting switched off.

### Changed
- Less per-frame work when many NPCs are in view, so heavy fights cost fewer frames.
- Reveal flashes no longer push nearby outlines out of view when the scene is crowded.
- The debug log reports the ESP frame time.

### Fixed
- The friendly-nomad diamond no longer shows through walls and cover; a live X-ray reveal still shows it on purpose.
- Corpses beyond the Distance setting are no longer outlined.


## [2.0.0] - 2026-10-24

### Changed
- New default colours for the state contours: a yellow "normal" silhouette (default world's own tint now reads as yellow), a blue "defending" silhouette. The red combat contour stays unchanged. Existing profiles keep their custom values; only fresh or reset profiles get the new colours.

## [1.17.5] - 2026-10-24

### Fixed
- The mod no longer writes its own error to the game log at startup.

### Changed
- Housekeeping only: dead code and duplicated defaults were removed. Nothing changes in game.

## [1.17.4] - 2026-10-25

### Changed
- The debug key-calibration sweep offers eight candidates instead of eleven. Three experimental probes from the combat-key pass were retired: they broke the sweep's minimum-spacing rule, so the on-screen choices no longer include a candidate pair that cannot be told apart.

## [1.17.3] - 2026-10-24

### Fixed
- Winter backgrounds no longer flood the thermal picture in red and cream: snowy scenes spread across the full palette again, so shadows read cold and only the brightest snow reads hot, both day and night.

## [1.17.2] - 2026-10-24

### Fixed
- The Classic thermal palette now gets brighter with every step up in heat: foggy days and other low-contrast scenes no longer show colder ground as a brighter shade than the warm spots on it.

## [1.17.1] - 2026-10-24

### Fixed
- The open daytime sky no longer reads as combat-red: washed-out bright pixels (the sky, clouds, snow glints) can no longer be mistaken for the combat outline key. The red rim band at the eyepiece edge and the red speckles on bright snow came from the same mix-up and go away with it.
- Distance contrast under daylight compensation is up: the highlight rolloff now keeps more of the midtone gradient, so the far forest and the fog band read as distinct shades again.

## [1.17.0] - 2026-10-24

### Added
- A "Highlight rolloff" setting: in daylight the brightest background (snow, sky, clouds) bends into a softer highlight, so it keeps texture and contrast instead of washing out into one flat white field. Night is unaffected.

## [1.16.0] - 2026-10-23

### Added
- Daylight compensation: the night-vision picture keeps its detail in bright sun and on snow instead of washing out white. Night and interiors stay almost untouched, and the feature can be turned off in settings.

## [1.15.1] - 2026-10-23

### Changed
- Lighter on the frame with many NPCs in view: outlines no longer draw over body parts or distance variants the game itself hides, so rings stop piling up on models that are already invisible.
- Mines only update their heat tint when they enter or leave the reveal range, instead of repainting every frame.

### Fixed
- Turning the thermal layer back on after a long pause no longer causes a one-time stutter.

## [1.15.0] - 2026-10-23

### Fixed
- NPC outlines stay inside the magnified scope picture and no longer bleed onto the scope body or the lens rim.
- X-ray reveals still show through walls while aiming, without leaking onto the scope housing.
- Picture-in-picture scopes show the outline once instead of twice.

## [1.13.0] - 2026-10-23

### Fixed
- The scope picture is back: an internal hardware experiment that reached the sights since the last two builds darkened the lens; it is withdrawn. The green nomad marker keeps working inside the scope without it.

## [1.12.3] - 2026-10-23

### Fixed
- Every scope's picture hardware is now actually patch-reached: the spare rule for picture-in-picture displays no longer mistakes the sights' own script signal for a display.

## [1.12.0] - 2026-10-23

### Added
- The trigger label names the step kind: walking bots show Walk, sprinting ones show Sprint, so their two reveal ranges can be tuned apart with confidence.

## [1.11.6] - 2026-10-23

### Fixed
- Scope picture hardware is now patch-reached reliably, whatever the rig calls its attachment node; optics stopped slipping past the first setup pass in some weapons.

## [1.11.5] - 2026-10-23

### Fixed
- The green nomad marker is visible in every scope view; near hardware no longer erases it.
- The outline no longer peeks past the rim right next to the lens edge.

### Changed
- Trigger settings renamed: the combat shout is now "Combat voice", the calm chatter is now "Voice"; combat voice reveal range defaults to 5 m.

## [1.11.4] - 2026-10-23

### Fixed
- The outline no longer paints past the edge of the magnified scope view: the sight's own housing stays on top of it.
- The outline no longer flashes over the scope glass while an enemy is tracked through a wall with the picture-in-picture scope.
- The green nomad marker is visible inside the magnified scope view again.

## [1.11.3] - 2026-10-23

### Fixed
- While aiming with the picture-in-picture scope, the outline no longer shows up twice: once in the magnified picture and once over the glass.
- The outline no longer paints over the scope's metal rim and tube while aiming; it still shows inside the magnified picture.

## [1.11.2] - 2026-10-23

### Fixed
- The scope picture no longer gets a dark opaque disc painted over it while the contour is on. Sights and lasers now keep their normal see-through look; the outline still behaves the same in and out of the scope view.

## [1.11.1] - 2026-10-23

### Fixed
- NPC outlines no longer bleed through the scope glass when the weapon is lowered; while aiming, outlines still show inside the scope picture as before. The outline's draw order now follows the aiming state: over the glass in the scope view, under it otherwise.

## [1.11.0] - 2026-10-23

### Added
- Every trigger distance slider now accepts 0: a zero range turns that source off (gunfire, shouts, idle chatter, footsteps, sprints, reloads, pain cries, grenades), matching the plain Distance slider's "0 = hidden" behaviour.
- The per-source distances and durations now ship with tuned defaults (further apart and shorter windows overall); the cooling time default is 90 s.

### Fixed
- The mod failed to load on startup (a broken cross-file type reference from the 1.10.2 rewrite), so thermal vision never turned on and the hotkey did nothing.

## [1.10.3] - 2026-10-23

### Fixed
- The mod failed to load on startup (a broken cross-file type reference from the 1.10.2 rewrite), so thermal vision never turned on and the hotkey did nothing.

## [1.10.2] - 2026-10-22

### Changed
- NVG noise defaults to off, so the picture starts clean; the slider can still bring the grain back.
- The Distance tooltip now says the outline is simply hidden past the range (it never faded).

### Fixed
- The menu no longer loses or mislabels a setting when one moves or renamed: every entry is now declared once, and the same declaration drives the menu and the mod itself.

## [1.10.1] - 2026-10-22

### Fixed
- Trigger reveals and the debug label countdowns actually work in game now: sound events (footsteps, gunfire, shouts and the rest) were silently dropped before reaching the trigger system, so neither the wall flash nor the `[fire 4.2s]` suffix could ever appear.
- The Distance setting crops NPC outlines exactly at its value again: outlines applied inside the range no longer linger past it, and setting Distance to the minimum hides every outline.
- Cooling corpses no longer light up as freshly killed after cycling thermal vision (helmet off and on).

## [1.10.0] - 2026-10-22

### Changed
- With "X-ray Triggers" on, the outline lights through walls only while a sound event is live (gunfire, a shout, footsteps and the rest) instead of permanently; between events it behaves like the ordinary distance limited ring.
- Sound-reveal timers are no longer tied to the toggle: with the debug log on, every live reveal shows its countdown on the NPC label whether the toggle is on or off.

### Fixed
- NPC outlines show through the scope glass again: the optics no longer hide the ring while the toggle is off.

## [1.9.1] - 2026-10-22

### Fixed
- X-ray Triggers actually detect sounds again: the mod declaration the loader reads was cut short, so the trigger hooks never attached (gunfire, shouts, footsteps and the rest).
- The hook registration now waits for the mod library to finish initializing instead of giving up on the first frame.
- "X-ray Triggers" off properly hides outlines behind walls again; on keeps the see-through ring plus the sound reveals.

## [1.9.0] - 2026-10-22

### Added
- The settings menu is reorganized into four blocks: Thermal vision, NPC, X-ray Triggers and Diagnostics.

### Changed
- "X-ray Triggers" now work on top of the NPC outlines instead of replacing them: inside the Distance slider the normal outlines stay solid, and each sound-based reveal (gunfire, shouts, chatter, footsteps, reloads, pain cries, grenade throws) additionally rings its NPC through walls at its own range for a few seconds, fading as the window closes.

### Fixed
- Settings values that moved between menu blocks are re-initialized with defaults.

## [1.8.1] - 2026-10-22

### Added
- With the debug log on, the floating NPC labels now also show the active trigger reveal and its live countdown (source, seconds left, range).

## [1.8.0] - 2026-10-22

### Added
- "Show through walls" toggle for the outline ring (on by default; off makes walls and the scope mask hide the contour again).
- Trigger mode inspired by Immersive Threat Highlight: outlines flash on gunfire, combat shouts, idle chatter, footsteps, reloads, pain cries and grenade throws for a few seconds, each with its own duration and reveal range; sprinting bots reveal further than walking ones.

### Fixed
- The Distance slider now crops the outline exactly where it is set, including while aiming through a scope.

## [1.7.11] - 2026-10-22

### Changed
- Outlines are drawn the way proven outline mods do it: a dedicated ghost shell per mesh that ignores the depth buffer, so contours stay visible in scopes at every zoom.

## [1.7.10] - 2026-10-22

### Fixed
- The scope keeps its vanilla picture while the contour works in the scope view; only the lens screen gives way to it.

## [1.7.9] - 2026-10-22

### Fixed
- In the scope view the outline no longer shows through walls, rocks or the scope's own parts; only the lens glass lets it through.

### Changed
- The outline reads as a thinner frame while in the scope view.

## [1.7.8] - 2026-10-22

### Fixed
- In the scope view the NPC outlines are no longer erased by the scope's own glass.

## [1.7.7] - 2026-10-22

### Fixed
- While aiming through a scope, NPC outlines now cover the target regardless of the contour distance limit, so distantscoped targets get their silhouette again.

## [1.7.5] - 2026-10-22

### Fixed
- NPC outlines are visible again when aiming through the glass of a magnifying scope.

## [1.7.4] - 2026-10-21

### Fixed
- The settings menu no longer keeps showing the old names and the options that were removed earlier.
- The settings you change in the menu now survive a restart: they used to be dropped, along with your hotkey, every time the game started again.

## [1.7.3] - 2026-10-21

### Changed
- The settings panel is tidier: the NPC block is called "ESP" and its sliders lost the duplicated "Outline"/"Contour" prefix.
- The "Normal / idle" colour is now called "Default", and the corpse cooling time is now called "Cooling time".
- "Outline rim" now defaults to 2.0 and steps by 0.5.
- The world palette is now changed only with the cycle hotkey; the dropdown next to it is gone.

### Removed
- The "Thermal vision" checkbox: the hotkey is now the only way to turn the thermal layer on and off, so the two can no longer disagree.
- The separate "Contour Range" section: the distance moved into the ESP block.

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
