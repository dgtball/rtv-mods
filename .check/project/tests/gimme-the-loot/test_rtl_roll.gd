extends SceneTree

const Pool = preload("res://mods/RoadToLoot/RTLPool.gd")
const Roll = preload("res://mods/RoadToLoot/RTLRoll.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _init() -> void:
	ck(Pool.ACTIVE_RELEASE == 2, "ACTIVE_RELEASE == 2")

	# --- condition снят с обеих категорий ---
	ck(not Pool.affix_ids("weapon").has("condition"), "weapon: condition removed")
	ck(not Pool.affix_ids("clothing").has("condition"), "clothing: condition removed")
	ck(Pool.entry("weapon", "condition").is_empty(), "weapon: no condition entry")
	ck(Pool.entry("clothing", "condition").is_empty(), "clothing: no condition entry")
	ck(Pool.POOL.size() == 18, "POOL: 18 entries")

	# --- релизный гейт: 5 оружейных, 13 одежды ---
	ck(Pool.entries("weapon").size() == 5, "weapon pool: 5 entries")
	ck(Pool.entries("clothing").size() == 13, "clothing pool: 13 entries")

	# --- статы, снятые в 0.3.0 ---
	for gone in ["sway", "penetration", "durability", "condition"]:
		ck(not Pool.affix_ids("weapon").has(gone) and not Pool.affix_ids("clothing").has(gone),
			gone + " gone")

	# --- MERGED: только те, у кого есть ванильная строка ---
	var merge_keys: Array = Pool.MERGED.keys()
	merge_keys.sort()
	ck(merge_keys == ["capacity", "damage", "insulation", "protection"], "MERGED keys: " + str(merge_keys))
	ck(Pool.MERGED["capacity"] == "Capacity", "MERGED capacity -> Capacity")
	ck(Pool.MERGED["damage"] == "Damage", "MERGED damage -> Damage")
	ck(Pool.MERGED["insulation"] == "Insulation", "MERGED insulation -> Insulation")
	ck(Pool.MERGED["protection"] == "Protection", "MERGED protection -> Protection")

	# --- MERGED_BASE: поле ItemData, из которого берётся база ---
	# Имя стата и имя поля расходятся только у capacity.
	ck(str(Pool.MERGED_BASE.get("capacity", "capacity")) == "capacity", "MERGED_BASE capacity -> capacity")
	for stat in Pool.MERGED.keys():
		var field: String = str(Pool.MERGED_BASE.get(stat, stat))
		ck(field != "", "base field for " + str(stat))
	ck(Pool.MERGED_BASE.keys().size() == 1, "MERGED_BASE: only capacity is remapped")

	# --- ROW_ORDER: без слитых статов, без повторов ---
	var seen: Array = []
	for stat in Pool.ROW_ORDER:
		ck(not Pool.MERGED.has(stat), "ROW_ORDER has no merged stat: " + str(stat))
		ck(not seen.has(stat), "ROW_ORDER unique: " + str(stat))
		seen.append(stat)

	# --- каждому стату пула назначено правило отображения ---
	for cat in ["weapon", "clothing"]:
		for e in Pool.entries(cat):
			var stat: String = str(e["stat"])
			ck(Pool.MERGED.has(stat) or Pool.ROW_ORDER.has(stat), "display rule for " + cat + "/" + stat)

	# --- и обратное: ROW_ORDER не выдумывает статов ---
	var pool_stats: Array = Pool.affix_ids("weapon") + Pool.affix_ids("clothing")
	for stat in Pool.ROW_ORDER:
		ck(pool_stats.has(stat), "ROW_ORDER stat exists in pool: " + str(stat))

	var problems: Array = Pool.validate()
	ck(problems.is_empty(), "validate(): " + str(problems))

	# нож: пул урезан до damage + low_hp_damage
	var knife := {"type": "Knife", "slots": ["Knife"], "damage": 20.0}
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 5
	var kn: Array = Roll.build_affixes("weapon", 3, knife, [], rng2)
	var kn_stats: Array = []
	for a in kn:
		kn_stats.append(a["stat"])
	ck(not kn_stats.has("recoil"), "knife: no recoil: " + str(kn_stats))
	ck(not kn_stats.has("fire_rate"), "knife: no fire_rate: " + str(kn_stats))
	ck(kn.size() == 2, "knife tier=3: damage + low_hp_damage: " + str(kn_stats))

	# ammo_save: огнестрел, проценты, три тира
	var ammo: Dictionary = Pool.entry("weapon", "ammo_save")
	ck(not ammo.is_empty(), "ammo_save in weapon pool")
	ck(str(ammo.get("unit", "")) == "pct", "ammo_save unit pct")
	ck(str(ammo.get("needs", "")) == "firearm", "ammo_save needs firearm")
	ck(float(ammo.get("weight", 0.0)) == 0.6, "ammo_save weight 0.6")
	var ar: Dictionary = ammo.get("ranges", {})
	ck(ar.has(1) and ar.has(2) and ar.has(3), "ammo_save ranges cover all tiers")
	if ar.has(1) and ar.has(2) and ar.has(3):
		ck(float(ar[1][0]) == 5.0 and float(ar[1][1]) == 10.0, "ammo_save T1 5-10")
		ck(float(ar[2][0]) == 10.0 and float(ar[2][1]) == 15.0, "ammo_save T2 10-15")
		ck(float(ar[3][0]) == 15.0 and float(ar[3][1]) == 50.0, "ammo_save T3 15-50")
	ck(Pool.ROW_ORDER.has("ammo_save"), "ROW_ORDER has ammo_save")
	ck(Pool.ROW_ORDER.find("ammo_save") == Pool.ROW_ORDER.find("wear") + 1, "ammo_save follows wear")

	# нож не получает ammo_save ни на одном тире
	var knife_no_ammo := true
	for tier in [1, 2, 3]:
		for s in range(60):
			var rgk := RandomNumberGenerator.new()
			rgk.seed = s
			for a in Roll.build_affixes("weapon", tier, knife, [], rgk):
				if str(a["stat"]) == "ammo_save":
					knife_no_ammo = false
	ck(knife_no_ammo, "knife never rolls ammo_save")

	# огнестрел его получает
	var rifle := {"type": "Weapon", "slots": ["Primary"], "damage": 30.0, "recoil": 4.0}
	var rifle_seen := false
	for s in range(200):
		var rgr := RandomNumberGenerator.new()
		rgr.seed = s
		for a in Roll.build_affixes("weapon", 3, rifle, [], rgr):
			if str(a["stat"]) == "ammo_save":
				rifle_seen = true
	ck(rifle_seen, "firearm can roll ammo_save")

	# --- количество аффиксов: диапазоны по тирам ---
	ck(Roll.COUNT_RANGES[0] == [0, 0], "vanilla tier: 0 affixes")
	ck(Roll.COUNT_RANGES[1] == [1, 2], "common: 1-2 affixes")
	ck(Roll.COUNT_RANGES[2] == [2, 3], "rare: 2-3 affixes")
	ck(Roll.COUNT_RANGES[3] == [3, 5], "legendary: 3-5 affixes")
	var rng0 := RandomNumberGenerator.new()
	ck(Roll.affix_count(0, rng0) == 0, "affix_count(0) = 0")
	ck(Roll.affix_count(9, rng0) == 0, "affix_count(unknown) = 0")
	for tier in [1, 2, 3]:
		var lo: int = Roll.COUNT_RANGES[tier][0]
		var hi: int = Roll.COUNT_RANGES[tier][1]
		var rgc := RandomNumberGenerator.new()
		rgc.seed = 1000 + tier
		var mn := 99
		var mx := -1
		for i in 500:
			var n: int = Roll.affix_count(tier, rgc)
			mn = mini(mn, n)
			mx = maxi(mx, n)
		ck(mn == lo and mx == hi, "tier %d count spans %d..%d (got %d..%d)" % [tier, lo, hi, mn, mx])

	# --- обрезка по пулу ---
	var knife_ok := true
	for s in range(50):
		var rgk2 := RandomNumberGenerator.new()
		rgk2.seed = s
		if Roll.build_affixes("weapon", 3, knife, [], rgk2).size() != 2:
			knife_ok = false
	ck(knife_ok, "knife tier 3 truncates to its 2 stats")

	# `rifle` объявлен выше в этом же тесте (блок Task 2) — переиспользуем его:
	# повторный `var rifle` в той же функции не скомпилируется.
	var rmin := 99
	var rmax := -1
	for s in range(200):
		var rgr := RandomNumberGenerator.new()
		rgr.seed = s
		var rn: int = Roll.build_affixes("weapon", 3, rifle, [], rgr).size()
		rmin = mini(rmin, rn)
		rmax = maxi(rmax, rn)
	ck(rmin == 3 and rmax == 5, "firearm tier 3 rolls 3..5 affixes (got %d..%d)" % [rmin, rmax])

	var shirt := {"type": "Clothing", "slots": ["Torso"], "insulation": 10.0}
	var cmin := 99
	var cmax := -1
	for s in range(200):
		var rgq := RandomNumberGenerator.new()
		rgq.seed = s
		var cn: int = Roll.build_affixes("clothing", 3, shirt, [], rgq).size()
		cmin = mini(cmin, cn)
		cmax = maxi(cmax, cn)
	ck(cmin == 3 and cmax == 5, "clothing tier 3 rolls 3..5 affixes (got %d..%d)" % [cmin, cmax])

	print("")
	if fails > 0:
		print("FAILED: %d" % fails)
		quit(1)
	else:
		print("tests passed")
		quit(0)
