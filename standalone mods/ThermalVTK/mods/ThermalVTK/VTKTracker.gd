extends RefCounted
# Pure tracker state + maths: entry lifecycle, state-category change gate,
# corpse cooling, distance fade, nearest-N cap, faction classification.
# `now` is a caller-supplied clock (seconds), so nothing here touches the tree
# and every rule is headless-testable (test_tracker.gd).

const States = preload("res://mods/ThermalVTK/VTKStates.gd")
const FADE_START_RATIO := 0.5
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

# Heat still held: 0 right at death, 1 fully cooled after decay_s.
static func cool_factor(e: Dictionary, now: float, decay_s: float) -> float:
	if not bool(e.get("dead", false)) or decay_s <= 0.0:
		return 0.0
	return clampf((now - float(e.get("death_ts", 0.0))) / decay_s, 0.0, 1.0)

# Full alpha inside FADE_START_RATIO of the range, then linear to 0 at max.
static func distance_alpha(dist: float, max_dist: float) -> float:
	if max_dist <= 0.0 or dist >= max_dist:
		return 0.0
	var fade_start: float = max_dist * FADE_START_RATIO
	if dist <= fade_start:
		return 1.0
	return clampf(1.0 - (dist - fade_start) / (max_dist - fade_start), 0.0, 1.0)

# candidates: Array of {"id": int, "dist": float}. Returns the nearest `cap` ids.
static func pick_nearest(candidates: Array, cap: int) -> Array:
	var sorted: Array = candidates.duplicate()
	sorted.sort_custom(func(a, b): return float(a["dist"]) < float(b["dist"]))
	var out: Array = []
	var n: int = mini(cap, sorted.size())
	for i in n:
		out.append(sorted[i]["id"])
	return out
