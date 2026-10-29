extends SceneTree

const Roll = preload("res://mods/LooterShooter/LSHRoll.gd")
const Pool = preload("res://mods/LooterShooter/LSHPool.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _init() -> void:
	ck(Roll.normalize_context({}) == "default", "empty ctx -> default")
	ck(Roll.normalize_context({"corpse": true}) == "corpse", "corpse ctx")
	ck(Roll.normalize_context({"joker": true}) == "joker", "joker ctx")
	ck(Roll.normalize_context({"rarity_roll": 10}) == "rare", "low roll -> rare")
	ck(Roll.normalize_context({"rarity_roll": 80}) == "default", "high roll -> default")

	var w: Array = Roll.tier_weights({"rarity_roll": 80}, 1.0, 0)
	ck(is_equal_approx(w[0], 0.60) and is_equal_approx(w[1], 0.30), "default weights van/common")
	ck(is_equal_approx(w[2], 0.09) and is_equal_approx(w[3], 0.01), "default weights rare/leg")

	var forced: Array = Roll.tier_weights({"rarity_roll": 80}, 1.0, 3)
	ck(forced == [0.0, 0.0, 0.0, 1.0], "forced legendary")

	ck(Roll.pick_tier([0.0, 0.0, 0.0, 1.0], 0.99) == 3, "pick legendary")
	ck(Roll.pick_tier([1.0, 0.0, 0.0, 0.0], 0.5) == 0, "pick vanilla")
	ck(Roll.pick_tier([0.0, 1.0, 0.0, 0.0], 0.0) == 1, "zero weight skipped")
	ck(Roll.pick_tier([0.25, 0.25, 0.25, 0.25], 0.9) == 3, "even split picks last bucket past 0.75")

	ck(Roll.affix_count(0) == 0 and Roll.affix_count(1) == 1, "count tier 0/1")
	ck(Roll.affix_count(2) == 2 and Roll.affix_count(3) == 3, "count tier 2/3")

	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var affixes: Array = Roll.build_affixes("weapon", 3, rng)
	ck(affixes.size() == 3, "legendary weapon -> 3 affixes")
	var stats: Array = []
	for a in affixes:
		stats.append(a["stat"])
	check_distinct(stats, "affix stats distinct")
	for a in affixes:
		var e: Dictionary = Pool.entry("weapon", a["stat"])
		ck(not e.is_empty(), "affix in pool: " + a["stat"])
		ck(a["value"] >= 0.0, "value non-negative: " + a["stat"])
	var dmg: Dictionary = Roll.build_affixes_from("weapon", 1, "damage", rng)
	ck(dmg["value"] >= 0.05 and dmg["value"] <= 0.15, "common damage fraction in range")

	var c2: Array = Roll.build_affixes("clothing", 2, rng)
	ck(c2.size() == 2, "rare clothing -> 2 affixes")

	ck(Roll.format_affix({"stat": "damage", "value": 0.12, "unit": "pct"}) == "+12% Damage",
			"format damage +12% Damage")
	ck(Roll.format_affix({"stat": "recoil", "value": -0.18, "unit": "pct"}) == "-18% Recoil",
			"format recoil -18% Recoil")
	ck(Roll.format_affix({"stat": "regen", "value": 0.03, "unit": "rate"}) == "Regen +0.03 HP/s",
			"format regen line")
	ck(Roll.format_affix({"stat": "penetration", "value": 1.0, "unit": "flat"}) == "+1 Penetration",
			"format penetration flat")

	print("")
	if fails == 0:
		print("LSH Roll tests passed")
		quit(0)
	else:
		print("LSH Roll tests failed: ", fails)
		quit(1)

func check_distinct(arr: Array, msg: String) -> void:
	var seen: Array = []
	for x in arr:
		if seen.has(x):
			fails += 1
			print("FAIL  ", msg, " (dup ", x, ")")
			return
		seen.append(x)
	print("ok    ", msg)
