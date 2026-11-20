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
	ck(Pool.ACTIVE_RELEASE == 4, "ACTIVE_RELEASE == 4")

	# --- condition снят с обеих категорий ---
	ck(not Pool.affix_ids("weapon").has("condition"), "weapon: condition removed")
	ck(not Pool.affix_ids("clothing").has("condition"), "clothing: condition removed")
	ck(Pool.entry("weapon", "condition").is_empty(), "weapon: no condition entry")
	ck(Pool.entry("clothing", "condition").is_empty(), "clothing: no condition entry")
	ck(Pool.POOL.size() == 22, "POOL: 22 entries")

	# --- релизный гейт: 7 оружейных, 15 одежды, 3 гаджетных ---
	ck(Pool.entries("weapon").size() == 7, "weapon pool: 7 entries")
	ck(Pool.entries("clothing").size() == 15, "clothing pool: 15 entries")
	ck(Pool.entries("gadget").size() == 3, "gadget pool: 3 entries")

	# --- статы, снятые в 0.3.0 ---
	for gone in ["sway", "penetration", "durability", "condition"]:
		ck(not Pool.affix_ids("weapon").has(gone) and not Pool.affix_ids("clothing").has(gone),
			gone + " gone")

	# --- новые статы и их категории ---
	ck(Pool.affix_ids("weapon").has("never_jam"), "weapon: never_jam")
	ck(Pool.affix_ids("weapon").has("unbreakable"), "weapon: unbreakable")
	ck(Pool.affix_ids("clothing").has("unbreakable"), "clothing: unbreakable")
	ck(Pool.affix_ids("gadget").has("battery_save"), "gadget: battery_save")
	ck(Pool.affix_ids("gadget").has("extra_loot"), "gadget: extra_loot")
	ck(Pool.affix_ids("gadget").has("sanity_drain"), "gadget: sanity_drain")
	ck(not Pool.affix_ids("gadget").has("never_jam"), "gadget: no never_jam")
	ck(Pool.entry("clothing", "unbreakable") == Pool.entry("weapon", "unbreakable"),
		"unbreakable is one shared entry")
	ck(Pool.entry("clothing", "extra_loot") == Pool.entry("gadget", "extra_loot"),
		"extra_loot is one shared entry")

	# --- wear теперь сопротивление, а не ускорение износа ---
	var wr: Dictionary = Pool.entry("weapon", "wear")
	ck(float(wr["ranges"][1][0]) == 5.0 and float(wr["ranges"][1][1]) == 10.0, "wear T1 5-10")
	ck(float(wr["ranges"][2][0]) == 10.0 and float(wr["ranges"][2][1]) == 15.0, "wear T2 10-15")
	ck(float(wr["ranges"][3][0]) == 20.0 and float(wr["ranges"][3][1]) == 50.0, "wear T3 20-50")

	# --- флаги: единица flag и веса ---
	ck(str(Pool.entry("weapon", "never_jam").get("unit", "")) == "flag", "never_jam unit flag")
	ck(str(Pool.entry("weapon", "unbreakable").get("unit", "")) == "flag", "unbreakable unit flag")
	ck(float(Pool.entry("weapon", "unbreakable").get("weight", 0.0)) == 0.04, "unbreakable weight 0.04")
	ck(float(Pool.entry("weapon", "never_jam").get("weight", 0.0)) == 0.1, "never_jam weight 0.1")
	ck(not Pool.entry("weapon", "never_jam")["ranges"].has(1), "never_jam starts at Rare")
	ck(not Pool.entry("weapon", "unbreakable")["ranges"].has(1)
		and not Pool.entry("weapon", "unbreakable")["ranges"].has(2), "unbreakable is Legendary only")

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
	for cat in Pool.CATEGORIES:
		for e in Pool.entries(cat):
			var stat: String = str(e["stat"])
			ck(Pool.MERGED.has(stat) or Pool.ROW_ORDER.has(stat), "display rule for " + cat + "/" + stat)

	# --- и обратное: ROW_ORDER не выдумывает статов ---
	var pool_stats: Array = []
	for cat in Pool.CATEGORIES:
		pool_stats.append_array(Pool.affix_ids(cat))
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
		ck(float(ar[3][0]) == 20.0 and float(ar[3][1]) == 50.0, "ammo_save T3 20-50")
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

	# --- never_jam: только огнестрел, с Rare ---
	var torch := {"type": "Electronics", "slots": ["Light"]}
	var gadget_map := {"type": "Misc", "slots": ["Map"]}
	var torch_stats: Array = []
	var map_stats: Array = []
	for s in range(120):
		var rgt := RandomNumberGenerator.new()
		rgt.seed = s
		for a in Roll.build_affixes("gadget", 3, torch, [], rgt, -1.0):
			torch_stats.append(str(a["stat"]))
		var rgm := RandomNumberGenerator.new()
		rgm.seed = s
		for a in Roll.build_affixes("gadget", 3, gadget_map, [], rgm, -1.0):
			map_stats.append(str(a["stat"]))
	ck(not torch_stats.is_empty(), "flashlight rolls something")
	ck(not torch_stats.has("extra_loot"), "flashlight never rolls extra_loot: " + str(torch_stats))
	ck(not torch_stats.has("sanity_drain"), "flashlight never rolls sanity_drain")
	ck(torch_stats.has("battery_save"), "flashlight rolls battery_save")
	ck(map_stats.has("extra_loot"), "map rolls extra_loot")
	ck(map_stats.has("sanity_drain"), "map rolls sanity_drain")
	ck(not map_stats.has("battery_save"), "map never rolls battery_save")

	var never_jam_rifle := false
	var never_jam_common := false
	for s in range(200):
		var rgn := RandomNumberGenerator.new()
		rgn.seed = s
		for a in Roll.build_affixes("weapon", 3, rifle, [], rgn, 100.0):
			if str(a["stat"]) == "never_jam":
				never_jam_rifle = true
		var rgn1 := RandomNumberGenerator.new()
		rgn1.seed = s
		for a in Roll.build_affixes("weapon", 1, rifle, [], rgn1, 100.0):
			if str(a["stat"]) == "never_jam":
				never_jam_common = true
	ck(never_jam_rifle, "rifle can roll never_jam")
	ck(not never_jam_common, "never_jam never rolls at Common")

	# --- unbreakable: гейт condition > 50 только для оружия ---
	var ub_low := false
	var ub_none := false
	var ub_high := false
	for s in range(300):
		var rgul := RandomNumberGenerator.new()
		rgul.seed = s
		for a in Roll.build_affixes("weapon", 3, rifle, [], rgul, 40.0):
			if str(a["stat"]) == "unbreakable":
				ub_low = true
		var rgun := RandomNumberGenerator.new()
		rgun.seed = s
		for a in Roll.build_affixes("weapon", 3, rifle, [], rgun, -1.0):
			if str(a["stat"]) == "unbreakable":
				ub_none = true
		var rguh := RandomNumberGenerator.new()
		rguh.seed = s
		for a in Roll.build_affixes("weapon", 3, rifle, [], rguh, 100.0):
			if str(a["stat"]) == "unbreakable":
				ub_high = true
	ck(not ub_low, "unbreakable never rolls at condition 40")
	ck(not ub_none, "unbreakable never rolls without a condition")
	ck(ub_high, "unbreakable rolls above 50")

	# --- unbreakable на шлеме: condition не нужен, база = 100 ---
	var helmet := {"type": "Helmet", "slots": ["Helmet"]}
	var ub_helmet := false
	var ub_base_ok := true
	for s in range(300):
		var rgh := RandomNumberGenerator.new()
		rgh.seed = s
		for a in Roll.build_affixes("clothing", 3, helmet, [], rgh, -1.0):
			if str(a["stat"]) == "unbreakable":
				ub_helmet = true
				if int(a.get("base", -1)) != 100:
					ub_base_ok = false
	ck(ub_helmet, "helmet can roll unbreakable without a condition")
	ck(ub_base_ok, "helmet unbreakable base is 100")

	# --- база оружия = прочность подбора ---
	var ub_weapon_base := -1
	for s in range(400):
		var rgb := RandomNumberGenerator.new()
		rgb.seed = s
		for a in Roll.build_affixes("weapon", 3, rifle, [], rgb, 73.0):
			if str(a["stat"]) == "unbreakable":
				ub_weapon_base = int(a.get("base", -1))
	ck(ub_weapon_base == 73, "weapon unbreakable base is the drop condition: " + str(ub_weapon_base))

	# --- исключения: unbreakable не встречается с never_jam/wear ---
	var conflict := false
	for s in range(600):
		var rgc := RandomNumberGenerator.new()
		rgc.seed = s
		var got: Array = []
		for a in Roll.build_affixes("weapon", 3, rifle, [], rgc, 100.0):
			got.append(str(a["stat"]))
		if got.has("unbreakable") and (got.has("never_jam") or got.has("wear")):
			conflict = true
	ck(not conflict, "unbreakable never coexists with never_jam or wear")

	# --- флаг: value 1.0, единица flag ---
	var flag_seen := false
	for s in range(400):
		var rgf := RandomNumberGenerator.new()
		rgf.seed = s
		for a in Roll.build_affixes("weapon", 3, rifle, [], rgf, 100.0):
			if str(a["stat"]) == "never_jam":
				flag_seen = true
				ck(float(a.get("value", 0.0)) == 1.0, "never_jam value is 1.0")
				ck(str(a.get("unit", "")) == "flag", "never_jam keeps the flag unit")
	ck(flag_seen, "flag affix seen in the sample")

	print("")
	if fails > 0:
		print("FAILED: %d" % fails)
		quit(1)
	else:
		print("tests passed")
		quit(0)
