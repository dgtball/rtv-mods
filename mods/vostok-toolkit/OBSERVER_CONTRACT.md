# VTK observation contract — v1

Shared document between **Vostok Toolkit (VTK)** and **RTV Mini HUD**, published
here as the reference for any mod that observes VTK's kill events. Scope is
deliberately narrow: only the surface an observer reads. Everything else in VTK
(UI, MCM, teleport, deposits, seasons, loadouts) is out of contract and may
change in any release without notice.

Marker: `const OBSERVER_CONTRACT := 1` in `mods/VTK/VTKHooks.gd`.

---

## 1. Versioning rule

| Event | Bump `OBSERVER_CONTRACT`? |
|---|---|
| Lethal gate logic changes (what counts as a kill) | **Yes** |
| Dedup behaviour changes (one event per death) | **Yes** |
| `kill_event` payload keys, types or meaning change | **Yes** |
| Signal names change, or emit timing/ordering changes | **Yes** |
| New unrelated hooks, UI, MCM, perf work, refactors | No |
| VTK release version (5.6.4 → 5.7.0 → 6.0.0) | No |

The marker is independent of the VTK release version. Mini HUD should read the
marker and accept **only** values it was written against; anything higher means
"re-verify before trusting", not "assume compatible".

Current agreed value: **1**. Baseline build: **5.6.4** (same contract surface as
5.6.3; the only difference relevant here is that 5.6.4 gives the feed node the
explicit name `VTKFeed`).

---

## 2. Hooks VTK registers for observation

All three are registered through `RTVModLib.hook(name, callback)` with the
**default priority 100**, so they are ordinary pre hooks, not replace hooks.

| Hook channel | VTK callback | Vanilla signature | Callback arity |
|---|---|---|---|
| `ai-weapondamage-pre` | `_on_ai_weapon_damage` | `WeaponDamage(hitbox: String, damage: float, vector: Vector3, id: Node3D)` | 4 |
| `ai-explosiondamage-pre` | `_on_ai_explosion` | `ExplosionDamage(direction, id: Node3D)` | 2 |
| `ai-death-pre` | `_on_ai_death` | `Death(direction, force)` | 2 |

VTK registers **no** `ai-death-post`, and **no** replace hook on any of the three
channels. The victim is always `_lib._caller`, never an argument.

### Ordering facts Mini HUD may rely on

1. Pre hooks run **before** the vanilla method body. For `Death` this matters
   because vanilla's first statement is `dead = true`; the pre hook is the last
   moment the original state is observable.
2. Dispatch is ordered by priority ascending. **Ties are not guaranteed** —
   the modloader sorts with a non-stable `sort_custom`, so two mods at priority
   100 have no defined relative order. Do not build assumptions on tie order.
3. VTK's `kill_event` is emitted **synchronously inside `ai-death-pre`**, i.e.
   still before the vanilla body runs. Any listener therefore observes the
   world in its pre-death state.
4. A void vanilla method dispatches `args.size()` arguments; a non-void one
   dispatches `args.size() + 1` (trailing `_result`). `Callable.callv` with a
   mismatched arity is a **silent no-op** in Godot 4.6.3 — no error, no log.
   VTK keeps the exact arities above; a third party copying a callback should
   do the same.

---

## 3. Side effects of VTK's pre hooks

The guarantee covers the **whole VTK-owned synchronous path**: the three pre
hooks, `kill_event.emit()`, and the feed listener (`VTKFeed._on_kill_event`)
with everything it calls. On that path VTK:

- does not write AI state (`dead`, `health`, `variant`, transform), and does not
  modify the damage/death arguments it receives;
- does not call back into vanilla damage or death, and does not dispatch hooks
  or re-emit Metro events;
- does not add, remove or reorder hooks, and does not replace or free the
  objects being observed;
- returns nothing and never sets `skip_super`.

The listener's work inside `ai-death-pre` is UI only: labels, icons and textures
built from the payload. It is synchronous, so it delays the vanilla body; that is
why it stays short (the only non-trivial cost is the first SVG rasterisation,
which is cached in static variables for the rest of the process).

Everything else VTK does (window, tabs, teleport, deposits, seasons, loadouts) is
outside this path and free to evolve.

### `ai-weapondamage-pre` / `ai-explosiondamage-pre`

Record one entry in `_last_damager[victim_instance_id]`:

```
{t, hitbox, killer_kind, killer_name, weapon, [grenade: true]}
```

`killer_kind` is `"player"` when the attacker node is in group `Player`,
otherwise the agent kind, otherwise `"enemy"`. The entry survives the attacker
(only the victim id is keyed), which is why the record is self-contained.

### `ai-death-pre`

In this exact order:

1. **Dedup, before the gate.** If `_seen_deaths` already has the victim's
   instance id, return. Otherwise insert it. This is why a second explosion on a
   corpse cannot produce a second event.
2. **Lethal gate** — `VTKKillCounter.death_is_lethal(dead_before, health, explosion)`:
   - `dead_before == null` → not lethal
   - `dead_before == true` → not lethal (corpse)
   - `explosion == true` → lethal (explosions never touch `health`)
   - otherwise `health` must be numeric and finite with `health <= 0.0`
3. If not lethal: drop the damage record, return. **No signal, no counter tick.**
4. `_resolve_kill()` builds the payload, then the damage record is dropped.
5. If `killer_kind == "player"`: `_kill_count += 1`.
6. `kill_event.emit(ev)` — for player kills *and* for self/NPC deaths.

The counter and the feed read the same single decision, so they cannot disagree.

### Housekeeping

`controller-_physics_process-post` runs at most every 500 ms and only when a map
is non-empty: it prunes `_seen_deaths` entries older than 10 minutes and
`_last_damager` entries whose node was freed.

`reset_kills()` clears the counter and both maps. It is called on:

- a new run (`loader-newgame-post`) — a death restart lands here too;
- a map change — but this one is driven by the feed node's `_process`, so it only
  happens while at least one HUD feature is enabled. With the whole HUD off, the
  10-minute TTL is the only expiry.

A shelter trip reloads the map, so it resets the same way a map change does.
`death-_ready-post` emits `player_died` but does not touch the dedup maps.

---

## 4. `kill_event(ev: Dictionary)` payload

Always present, always these types:

| Key | Type | Meaning |
|---|---|---|
| `self_death` | `bool` | The hit record is older than 15 s — the NPC died on its own |
| `killer_kind` | `String` | `"player"`, an agent kind, or `""` for self death |
| `killer_name` | `String` | Display name; `"Player"` (or the configured name) for the player |
| `victim_kind` | `String` | Agent kind of the victim |
| `victim_name` | `String` | Display name of the victim |
| `weapon` | `String` | Weapon name when resolvable, otherwise `""` |
| `headshot` | `bool` | Hitbox string was `head` |
| `grenade` | `bool` | Explosion kill, or the weapon is in `Grenades/` |
| `t` | `int` | `Time.get_ticks_msec()` at emit |
| `distance` | `float` | Metres, player kills only; `-1.0` otherwise |

Ten keys, no more and no less in v1.

Two different cases hide behind "the victim died without a live hit record":

- **No record at all** (killed by something VTK never observed, e.g. a hazard or
  a scripted death) → `_resolve_kill` returns empty, so **no event is emitted**.
  VTK does not fabricate a self-death event here.
- **Record older than 15 s** (`HIT_WINDOW_MSEC`) → `self_death == true`, with an
  empty killer. The NPC outlived the hit that VTK saw.

Guarantees:

- At most **one** `kill_event` per AI instance id per dedup window. The window
  ends when the entry expires (10 min) or when `reset_kills()` clears it; see
  §3 housekeeping.
- Emitted for every accepted death, including self deaths and NPC-on-NPC kills
  (`killer_kind` is then not `"player"`).
- Every event that increments the kill counter also emits the signal.
- Never emitted for a corpse hit, never emitted twice for the same death.
- `self_death == true` implies `killer_kind == ""` and `distance == -1.0`.
- Emitted **before** the vanilla `Death` body runs, so `ai.dead` is still `false`
  and `ai.health` is already `<= 0` for weapon kills at the moment listeners run.

---

## 5. Signals on `VTKUI/VTKHooks`

| Signal | Emitted from | Meaning |
|---|---|---|
| `kill_event(ev)` | `ai-death-pre` | Accepted death, see above |
| `player_died` | `death-_ready-post` | Vanilla death screen is ready |
| `new_game_started` | `loader-newgame-post` | A new run was created |
| `travel_arrived` | `compiler-spawn-post` | Map finished spawning |

VTK connects at most one listener to `kill_event` itself: the feed node's
`_on_kill_event`, flags `0`, and `VTKFeed._hooks` points back at the `VTKHooks`
node. Any additional connection is Mini HUD's own; VTK never iterates or
re-emits foreign connections.

### Where the feed node lives

- Canvas: `/root/VTKKC_Canvas` — a `CanvasLayer` (layer 9999,
  `PROCESS_MODE_ALWAYS`) created by VTK's feature host. It is **not** a child of
  `/root/VTKUI`; the `VTKHooks` node is, the canvas is not.
- Feed: `/root/VTKKC_Canvas/VTKFeed` — the canvas's only child, script
  `res://mods/VTK/VTKFeed.gd`. The node name is explicit from **5.6.4** on. In
  5.6.3 and earlier the node was unnamed and Godot generated `@Control@N`, which
  changes between runs; a check that must also cover those builds should match on
  the script path instead of the name.
- The canvas and the feed exist only after at least one HUD feature has been
  enabled once. With all three HUD features off from the start there is no
  canvas, no feed and no `kill_event` connection; `VTKHooks` still emits and
  nobody listens. That is a valid state, not a broken install.
- Disabling the HUD after the feed was created does not disconnect it: the
  handler stays connected and returns early while nothing is enabled. Do not
  treat "connection present, no rows appearing" as a failure.

---

## 6. What Mini HUD can verify cheaply

Structural checks, no source hashing:

1. `VTKHooks.gd` exposes `OBSERVER_CONTRACT` and it equals `1`.
2. The `ai-death-pre` row has priority `100`, owner path `VTKUI/VTKHooks`,
   callback `_on_ai_death`, and `owner._lib` is the live modloader.
3. `kill_event` has at most one connection whose callable object is
   `/root/VTKKC_Canvas/VTKFeed` — or, on 5.6.3 and earlier, the canvas child
   whose script is `res://mods/VTK/VTKFeed.gd` — with flags `0`; if present,
   `_hooks` on that object is the `VTKHooks` node. Zero connections is valid when
   the HUD has never been enabled.
4. No replace hooks on `ai-weapondamage`, `ai-explosiondamage`, `ai-death`.
5. Payload shape: all ten keys present with the declared types.

Behaviour checks that need a live run:

6. Two `ai-death-pre` calls on the same node → one `kill_event`.
7. `dead == true` before the call → no `kill_event`.
8. Weapon damage with `health > 0` → no `kill_event`.
9. Explosion with no `health` change → `kill_event` with `grenade == true`.
10. `killer_kind == "player"` → counter increments by exactly one.

VTK runs headless tests for 6–10 on every change, so a regression that breaks
the contract fails our build before it ships. Those tests are ours and not part
of this document; Mini HUD does not need to duplicate them. What Mini HUD needs
is the cheap "is the surface still shaped as expected" check above.

---

## 7. Not covered by this contract

- VTK release version, or any mapping from it to the contract version.
- Source file hashes of any VTK script.
- Hooks unrelated to death observation (25 registered in total).
- MCM keys and values, `config.ini`, saved sets, deposit ledger.
- UI appearance and layout: window, tabs, HUD widget styling, HUD position,
  offset and font size. The node *identity* used in §5 is in scope; how it looks
  and where it sits is not.
- Behaviour of other mods on the same channels.

If an integrator needs one of these pinned, it should become a separate, explicit
agreement rather than an implicit dependency.
