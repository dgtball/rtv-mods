extends RefCounted

const Pool = preload("res://mods/RoadToLoot/RTLPool.gd")
const Log = preload("res://mods/RoadToLoot/RTLLog.gd")

const CONTEXT_WEIGHTS := {
	"default": [0.60, 0.30, 0.09, 0.01],
	"rare":    [0.35, 0.40, 0.20, 0.05],
	"corpse":  [0.45, 0.35, 0.15, 0.05],
	"joker":   [0.15, 0.35, 0.35, 0.15],
}

static func normalize_context(ctx: Dictionary) -> String:
	if bool(ctx.get("joker", false)):
		return "joker"
	if bool(ctx.get("corpse", false)):
		return "corpse"
	var roll: int = int(ctx.get("rarity_roll", 100))
	if roll <= 25:
		return "rare"
	return "default"

static func tier_weights(ctx: Dictionary, freq_mult: float, forced: int) -> Array:
	if forced >= Pool.COMMON and forced <= Pool.LEGENDARY:
		var out := [0.0, 0.0, 0.0, 0.0]
		out[forced] = 1.0
		return out
	var base: Array = CONTEXT_WEIGHTS[normalize_context(ctx)]
	var mul: float = maxf(0.0, freq_mult)
	var scaled_nonvan: float = float(base[1]) * mul + float(base[2]) * mul + float(base[3]) * mul
	var van: float = 1.0 - scaled_nonvan
	if van < 0.0:
		van = 0.0
	var out_arr: Array = [van, float(base[1]) * mul, float(base[2]) * mul, float(base[3]) * mul]
	var sum: float = float(out_arr[0]) + float(out_arr[1]) + float(out_arr[2]) + float(out_arr[3])
	if sum <= 0.0:
		return [1.0, 0.0, 0.0, 0.0]
	return [float(out_arr[0]) / sum, float(out_arr[1]) / sum, float(out_arr[2]) / sum, float(out_arr[3]) / sum]

static func pick_tier(weights: Array, r: float) -> int:
	var acc: float = 0.0
	for tier in range(weights.size()):
		acc += float(weights[tier])
		if r < acc:
			return tier
	return weights.size() - 1

static func affix_count(tier: int) -> int:
	return clampi(tier, 0, 3)

static func build_affixes(category: String, tier: int, item_data: Dictionary, blocked: Array, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var n: int = affix_count(tier)
	if n <= 0:
		return out
	# candidates filtered by release (Pool.entries already filters by ACTIVE_RELEASE)
	var pool_all := Pool.entries(category)
	var candidates: Array = []
	for e in pool_all:
		if e["ranges"].has(tier):
			candidates.append(e)

	# Apply needs filters
	var filtered: Array = []
	for e in candidates:
		var need: String = e.get("needs", "")
		var ok: bool = true
		if need == "capacity":
			var v = item_data.get("capacity")
			ok = float(v if v != null else 0) > 0
		elif need == "insulation":
			var v = item_data.get("insulation")
			ok = float(v if v != null else 0) > 0
		elif need == "armor":
			var v = item_data.get("type")
			ok = (str(v if v != null else "") == "Armor" or str(v if v != null else "") == "Helmet")
		if ok:
			filtered.append(e)
	candidates = filtered

	# Exclude blocked (stats whose applier failed arity self-check)
	if not blocked.is_empty():
		filtered = []
		for e in candidates:
			if not blocked.has(e["stat"]):
				filtered.append(e)
		candidates = filtered

	# Pick n without replacement
	var pool: Array = candidates.duplicate()
	for i in range(n):
		if pool.is_empty():
			break
		var e: Dictionary = _weighted_pick(pool, rng)
		pool.erase(e)
		out.append(_roll_one(e, tier, rng))
	return out

static func build_affixes_from(category: String, tier: int, stat: String, rng: RandomNumberGenerator) -> Dictionary:
	var e: Dictionary = Pool.entry(category, stat)
	if e.is_empty() or not e["ranges"].has(tier):
		return {}
	return _roll_one(e, tier, rng)

static func _weighted_pick(pool: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total: float = 0.0
	for e in pool:
		total += float(e["weight"])
	var r: float = rng.randf() * total
	var acc: float = 0.0
	for e in pool:
		acc += float(e["weight"])
		if r <= acc:
			return e
	return pool[pool.size() - 1]

static func _roll_one(e: Dictionary, tier: int, rng: RandomNumberGenerator) -> Dictionary:
	var r: Array = e["ranges"][tier]
	var lo: float = float(r[0])
	var hi: float = float(r[1])
	var unit: String = e["unit"]
	var value: float
	if unit == "flat":
		value = float(rng.randi_range(int(lo), int(hi)))
	elif unit == "mult":
		value = lo
	else:
		value = rng.randf_range(lo, hi)
		if unit == "pct":
			value *= 0.01
		elif unit == "hp" or unit == "kg":
			value = float(int(round(value)))
		elif unit == "rate":
			value = snappedf(value, 0.01)
	return {"stat": e["stat"], "value": value, "unit": unit}
