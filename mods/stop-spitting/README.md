# Stop Spitting

**Version:** 1.0.0

A small mod that stops the nomads from spitting. Two of their idle noises are
spits; this mod removes those two clips and leaves every other nomad sound
exactly as the game ships it.

## What it does

- The nomads no longer spit: `Nomad_Random_11.wav` and `Nomad_Random_17.wav` are
  taken out of their idle voice set.
- Everything else stays: the other 39 idle noises, the combat shouts, the pain
  and the death sounds are the game's own.
- It covers all three nomad variants (`AI_Nomad_A/B/C`) and every nomad that
  spawns, because they all share one voice set.
- No other faction's voices are touched.

## Install

1. Copy `StopSpitting.vmz` into the game's `mods` folder.
2. Enable the mod in the mod loader and start the game.

## How it works

Each nomad carries an `AIData` resource with one `AudioEvent` per voice set, and
the voice player picks a random clip out of the event's clip list. The mod
watches the scene tree for nomad nodes, takes the two spit clips out of the idle
list, in place, and does the same for every other nomad it meets. The clip list
is shared between all nomads, so one change covers them all.

Nothing is hooked or replaced, no game file is written to disk, and the clips
come back if the mod is removed.

## Build (from the repo)

```powershell
powershell -ExecutionPolicy Bypass -File pack.ps1 -Mod stop-spitting
```
