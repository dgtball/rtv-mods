# Freeze for JCM

**Version:** 1.2.0

An addon for **JCM (JuuZo's Cheat Menu)** that freezes the game's moving
pieces on demand — NPCs, the BTR, and the helicopter. Useful for screenshots,
testing, or pausing the action without touching the console.

## What it does

- **Freeze NPC** — stops every NPC in place. Frozen characters become static:
  the AI simply stops ticking, so animations, patrols, and attacks all halt
  until you switch it back on.
- **Freeze BTR & Heli** — freezes the BTR and the event helicopter mid-flight.
  The BTR's engine loop and the helicopter's rotor sound are muted while frozen
  and return the moment you unfreeze, so a stopped vehicle is also silent.
- **Hotkey** — bind a key in MCM to toggle **Freeze NPC** without opening the
  menu. Default is **Numpad 4**; the hotkey is ignored while a menu, the
  settings screen, or a text field is open.
- Everything lives on JCM's **AI** tab, alongside the rest of the toggles, and
  your choices are saved between sessions.

## Requirements

- **JCM (JuuZo's Cheat Menu)** — the menu this addon plugs into.
- **MCM (Mod Configuration Menu)** — required for the hotkey binding.

## Install

1. Install JCM and MCM first.
2. Copy `Freeze.vmz` into the game's `mods` folder.
3. Enable the mod in the mod loader and start the game.
4. Open JCM, go to the **AI** tab, and flip the toggles you want.

## Controls

- `Freeze NPC` / `Freeze BTR & Heli` — toggles on the AI tab.
- `Toggle Freeze NPC` hotkey — **Numpad 4** by default; rebindable in MCM under
  *Hotkeys*.

## Known behavior

- A frozen helicopter won't clean itself up while frozen — unfreeze it to let
  it resume and leave the area normally.
- Rockets fired by the helicopter keep flying; only the vehicle itself is
  frozen.

## Build (from the repo)

```powershell
powershell -ExecutionPolicy Bypass -File pack.ps1
```
