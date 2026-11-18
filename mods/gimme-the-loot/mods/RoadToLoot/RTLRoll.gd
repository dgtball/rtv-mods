extends RefCounted

const Pool = preload("res://mods/RoadToLoot/RTLPool.gd")
const Category = preload("res://mods/RoadToLoot/RTLCategory.gd")

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

# Сколько аффиксов просит тир. Верхняя граница может быть недостижима:
# build_affixes обрезает её по числу доступных статов.
const COUNT_RANGES := {0: [0, 0], 1: [1, 2], 2: [2, 3], 3: [3, 5]}

# unbreakable взаимоисключается с never_jam и wear: рядом с замороженной
# прочностью wear мёртв, а never_jam уже покрывает поломку. Побеждает тот, кого
# выбрали раньше; конфликтующие записи уходят из пула до следующего пика.
const CONFLICTS := {
	"unbreakable": ["never_jam", "wear"],
	"never_jam": ["unbreakable"],
	"wear": ["unbreakable"],
}

static func affix_count(tier: int, rng: RandomNumberGenerator) -> int:
	if not COUNT_RANGES.has(tier):
		return 0
	var r: Array = COUNT_RANGES[tier]
	return rng.randi_range(int(r[0]), int(r[1]))

static func _needs_ok(need: String, item_data) -> bool:
	if need == "":
		return true
	if need == "armor":
		var t: String = ""
		if item_data != null:
			var raw = item_data.get("type")
			if raw != null:
				t = str(raw).strip_edges()
		return t == "Armor" or t == "Helmet"
	if need == "firearm":
		return Category.is_firearm(item_data)
	if need == "battery":
		return Category.gadget_kind(item_data) == "battery"
	if need == "comfort":
		# одежда использует те же extra_loot/sanity_drain, что и часы с картой
		return Category.of_item(item_data) == Category.CLOTHING or Category.gadget_kind(item_data) == "comfort"
	if need == "durable":
		return Category.is_durable(item_data)
	if item_data == null:
		return false
	var v = item_data.get(need)
	return v != null and float(v) > 0.0

static func build_affixes(category: String, tier: int, item_data, blocked: Array, rng: RandomNumberGenerator, condition: float = -1.0) -> Array:
	var out: Array = []
	var n: int = affix_count(tier, rng)
	if n <= 0:
		return out
	# candidates filtered by release (Pool.entries already filters by ACTIVE_RELEASE)
	var candidates: Array = []
	var all_e = Pool.entries(category)
	for e in all_e:
		if e["ranges"].has(tier):
			candidates.append(e)

	# Apply needs filters
	var filtered: Array = []
	for e in candidates:
		var need: String = str(e.get("needs", ""))
		if _needs_ok(need, item_data):
			filtered.append(e)
	candidates = filtered

	# Маска категории: нож не усиливает отдачу и темп (RTL не знает имён типов)
	filtered = []
	for e in candidates:
		if Category.stat_allowed(item_data, str(e["stat"])):
			filtered.append(e)
	candidates = filtered

	# unbreakable на оружии: только пока прочность выше половины. Броня всегда
	# спавнится со 100%, поэтому её гейт не касается.
	filtered = []
	for e in candidates:
		if str(e["stat"]) == "unbreakable" and Category.of_item(item_data) == Category.WEAPON and condition <= 50.0:
			continue
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
	n = mini(n, candidates.size())
	if n <= 0:
		return out
	var pool: Array = candidates.duplicate()
	for i in range(n):
		if pool.is_empty():
			break
		var e: Dictionary = _weighted_pick(pool, rng)
		pool.erase(e)
		out.append(_roll_one(e, tier, rng, condition))
		var blocked_next: Array = []
		for taken in out:
			for c in CONFLICTS.get(str(taken.get("stat", "")), []):
				blocked_next.append(c)
		if not blocked_next.is_empty():
			var kept: Array = []
			for cand in pool:
				if not blocked_next.has(str(cand["stat"])):
					kept.append(cand)
			pool = kept
	return out

static func build_affixes_from(category: String, tier: int, stat: String, rng: RandomNumberGenerator, condition: float = -1.0) -> Dictionary:
	var e: Dictionary = Pool.entry(category, stat)
	if e.is_empty() or not e["ranges"].has(tier):
		return {}
	return _roll_one(e, tier, rng, condition)

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

static func _roll_one(e: Dictionary, tier: int, rng: RandomNumberGenerator, condition: float = -1.0) -> Dictionary:
	var r: Array = e["ranges"][tier]
	var lo: float = float(r[0])
	var hi: float = float(r[1])
	var unit: String = e["unit"]
	var value: float
	if unit == "flag":
		value = 1.0
	elif unit == "flat":
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
	var out := {"stat": e["stat"], "value": value, "unit": unit}
	if str(e["stat"]) == "unbreakable":
		out["base"] = condition if condition >= 0.0 else 100.0
	return out
