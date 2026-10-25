extends RefCounted
# Pure tracker state + maths: entry lifecycle, state-category change gate,
# corpse cooling, nearest-N cap, faction classification.
# `now` is a caller-supplied clock (seconds), so nothing here touches the tree
# and every rule is headless-testable (test_tracker.gd).

const States = preload("res://mods/ThermalVTK/VTKStates.gd")
# Faction ints from the AI variant: 0 is the friendly faction (Nomads).
const FACTION_NOMAD := 0
const FACTION_HOSTILE := 1

static func is_nomad_faction(faction: int) -> bool:
	return faction == FACTION_NOMAD

# Reads the int faction out of an AI variant resource (or a plain Dictionary).
# One-arg Object.get only: a two-arg call on a game resource aborts the function.
static func read_faction(variant: Variant) -> int:
	if variant == null:
		return FACTION_HOSTILE
	if variant is Dictionary:
		return int(variant.get("faction", FACTION_HOSTILE))
	if variant is Object:
		var v: Variant = variant.get("faction")
		if v == null:
			return FACTION_HOSTILE
		return int(v)
	return FACTION_HOSTILE

static func new_entry(id: int, nomad: bool, now: float) -> Dictionary:
	return {
		"id": id,
		"cat": States.NORMAL,
		"nomad": nomad,
		"dead": false,
		"death_ts": 0.0,
		"last_seen": now,
	}

# Returns true only when the awareness category actually changed, so the
# renderer can push colour/alpha only then (NPCESP's change gate).
static func apply_state(e: Dictionary, state: int) -> bool:
	var cat: int = States.category_of(state)
	if int(e.get("cat", -1)) == cat:
		return false
	e["cat"] = cat
	return true

static func mark_dead(e: Dictionary, now: float) -> void:
	if bool(e.get("dead", false)):
		return
	e["dead"] = true
	e["death_ts"] = now

# ---------------------------------------------------------------------------
# Trigger mode (the Immersive Threat Highlight idea): instead of an always-on
# outline, a source event (gunfire, shout, steps, ...) tags the entry with a
# timed window; the ring lives for the window and fades over its tail.
# ---------------------------------------------------------------------------

# Event priority when several overlap: the loudest recent one wins. Walk and
# Sprint are different footsteps of the same source (the label tells them
# apart); sprint runs with reload's tier.
const TRIG_PRIORITY := {"fire": 6, "grenade": 5, "voice": 4, "pain": 3, "reload": 2, "run": 2, "walk": 1, "idle": 0}

static func tag_trig(e: Dictionary, source: String, dist: float, expires_at: float, span: float) -> void:
	var trig: Dictionary = e.get("trig", {})
	trig[source] = {"dist": dist, "expires": expires_at, "span": span}
	e["trig"] = trig

# The active window: highest priority among the unexpired, latest expiry
# breaks ties. Expired windows are erased (the Dictionary stays clean).
# Returns {} when the entry has nothing to show.
static func pick_trig(e: Dictionary, now: float) -> Dictionary:
	var trig: Dictionary = e.get("trig", {})
	if trig.is_empty():
		return {}
	var best_source := ""
	var best: Dictionary = {}
	var best_pri := -1
	var best_exp := 0.0
	for source_value in trig.keys():
		var source := str(source_value)
		var win: Dictionary = trig[source]
		if float(win.get("expires", 0.0)) <= now:
			trig.erase(source)
			continue
		var pri: int = TRIG_PRIORITY.get(source, 0)
		var exp: float = float(win.get("expires", 0.0))
		if pri > best_pri or (pri == best_pri and exp > best_exp):
			best_source = source
			best = {"source": source, "dist": float(win.get("dist", 0.0)), "expires": exp, "span": float(win.get("span", 1.0))}
			best_pri = pri
			best_exp = exp
	e["trig"] = trig
	return best

# 1 right after the tag, 0 when the window is spent. Same shape as ITH's
# remaining/duration alpha; callers feed it into the cold factor so the ring
# melts away over the tail.
static func fade_factor(ev: Dictionary, now: float) -> float:
	var span: float = float(ev.get("span", 1.0))
	if span <= 0.0:
		return 0.0
	return clampf((float(ev.get("expires", 0.0)) - now) / span, 0.0, 1.0)

# Heat still held: 0 right at death, 1 fully cooled after decay_s.
static func cool_factor(e: Dictionary, now: float, decay_s: float) -> float:
	if not bool(e.get("dead", false)) or decay_s <= 0.0:
		return 0.0
	return clampf((now - float(e.get("death_ts", 0.0))) / decay_s, 0.0, 1.0)

# candidates: Array of {"id": int, "dist": float}. Returns the nearest `cap` ids.
static func pick_nearest(candidates: Array, cap: int) -> Array:
	var sorted: Array = candidates.duplicate()
	sorted.sort_custom(func(a, b): return float(a["dist"]) < float(b["dist"]))
	var out: Array = []
	var n: int = mini(cap, sorted.size())
	for i in n:
		out.append(sorted[i]["id"])
	return out
