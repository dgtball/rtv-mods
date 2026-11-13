extends RefCounted
# Ring of recent mine detonations, used to attribute an explosion kill that the
# vanilla `AI.ExplosionDamage` reports without a thrower (id == null).
# Pure helpers: no load(), no game paths, so headless tests cover them.

const WINDOW_MSEC := 1000
const BLAST_RADIUS := 11.0
const RING_CAP := 8

# Record one detonation. Records older than WINDOW_MSEC (counted from the new
# blast, not from the wall clock) are dropped first, then the ring is capped.
static func record(ring: Array, pos: Vector3, t: int, h: float, player: bool, cap: int = RING_CAP) -> Array:
	var out: Array = []
	for rec in ring:
		if t - int(rec.get("t", 0)) > WINDOW_MSEC:
			continue
		out.append(rec)
	out.append({"pos": pos, "t": t, "h": h, "player": player})
	while out.size() > cap:
		out.pop_front()
	return out

# Nearest covering blast for a victim, or {} when nothing matches.
# Boundaries are inclusive: age == WINDOW_MSEC and dist == BLAST_RADIUS still hit.
static func match(ring: Array, victim_pos: Vector3, now: int) -> Dictionary:
	var best: Dictionary = {}
	var best_dist := -1.0
	for rec in ring:
		if now - int(rec.get("t", 0)) > WINDOW_MSEC:
			continue
		var pos: Vector3 = rec.get("pos", Vector3.ZERO)
		var h: float = float(rec.get("h", 0.0))
		var dist := (pos + Vector3(0.0, h, 0.0)).distance_to(victim_pos)
		if dist > BLAST_RADIUS:
			continue
		if best_dist < 0.0 or dist < best_dist:
			best_dist = dist
			best = {"player": bool(rec.get("player", false))}
	return best

static func prune(ring: Array, now: int) -> Array:
	var out: Array = []
	for rec in ring:
		if now - int(rec.get("t", 0)) > WINDOW_MSEC:
			continue
		out.append(rec)
	return out
