# More cat food

**Version:** 1.0.8

A small mod that adds a 60-second OIIA dance to cat feeding stations.

## What it does

- Feeding a station with the special item starts a choreographed dance with music.
- The special foods also work in the Cat Bed food tray: Beer starts the dance right away, the others simply fill the tray.
- The special foods can feed the cat from the Cat Bed as well. Beer starts the dance there too; holding the interaction key still pets, takes or recalls the cat as usual.
- The cat lifts off, spins, sits and lies back down on the beat.
- Halfway through, three more cats appear and the four of them dance in a square.
- Colored flashes pulse from the middle of the group.
- The show ends with the cats merging, the extra cats disappearing and the original cat settling into the box.

Ordinary food keeps its normal feeding behavior and is listed in the station prompt as usual. The special item is not advertised in the prompt.

Food put into the Cat Bed tray is stored as ordinary cat food, so taking it back returns ordinary cat food.

## Install

1. Copy `MoreCatFood.vmz` into the game's `mods` folder.
2. Enable the mod in the mod loader and start the game.

## Build (from the repo)

```powershell
powershell -ExecutionPolicy Bypass -File pack.ps1 -Mod MoreCatFood
```
