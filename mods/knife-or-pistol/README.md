# Knife or Pistol

**Version:** 1.0.0

A small mod that turns the knife slot into a third weapon slot: put a knife or
a pistol in it, and the pistol works like a normal sidearm when you draw it.

## What it does

- The knife slot accepts pistols as well as knives. Drag a pistol from the
  inventory into the slot, and back out, like any other item.
- A pistol in the knife slot is a full weapon: press the knife key to draw it,
  then left click fires, right click aims, `R` reloads, and inspect works.
- Attachments — optic, suppressor, laser — and magazines on that pistol are
  used as usual, and the model updates when you swap a magazine.
- Knives behave exactly as before: the slot still takes them and the knife key
  still slashes.
- Any pistol is accepted, including pistols added by other mods. Rifles, SMGs
  and shotguns are not.

## Install

1. Copy `KnifeOrPistol.vmz` into the game's `mods` folder.
2. Enable the mod in the mod loader and start the game.

## Known behavior

- A weapon in the knife slot does not drain arm stamina: the game tracks that
  only for the two main weapon slots.
- Swapping a magazine by dragging it onto a drawn pistol in the knife slot
  updates the model, but skips the magazine animation.
- The item tooltip lists `Knife` among a pistol's slots.
- Save data is untouched: an item in the knife slot is stored like any other
  slotted item, so saves stay compatible in both directions.

## Build (from the repo)

```powershell
powershell -ExecutionPolicy Bypass -File pack.ps1 -Mod knife-or-pistol
```
