extends SceneTree

const Pool = preload("res://mods/RoadToLoot/RTLPool.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func ck_range(cat: String, stat: String, tier: int, want: String) -> void:
	var e: Dictionary = Pool.entry(cat, stat)
	var ranges: Dictionary = e.get("ranges", {})
	var got: String = str(ranges.get(tier, []))
	ck(got == want, stat + " T" + str(tier) + " " + want + ": " + got)

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

	# --- 1.2.4: новая матрица значений ---
	ck_range("weapon", "damage", 1, "[1, 5]")
	ck_range("weapon", "damage", 2, "[6, 10]")
	ck_range("weapon", "damage", 3, "[10, 20]")
	ck_range("weapon", "recoil", 1, "[1, 5]")
	ck_range("weapon", "recoil", 2, "[6, 10]")
	ck_range("weapon", "recoil", 3, "[10, 20]")
	ck_range("weapon", "wear", 1, "[5, 10]")
	ck_range("weapon", "wear", 2, "[10, 15]")
	ck_range("weapon", "wear", 3, "[20, 50]")
	ck_range("weapon", "low_hp_damage", 1, "[5, 10]")
	ck_range("weapon", "low_hp_damage", 2, "[10, 15]")
	ck_range("weapon", "low_hp_damage", 3, "[20, 50]")
	ck_range("weapon", "ammo_save", 1, "[5, 10]")
	ck_range("weapon", "ammo_save", 2, "[10, 15]")
	ck_range("weapon", "ammo_save", 3, "[20, 50]")

	ck_range("clothing", "regen", 1, "[0.01, 0.01]")
	ck_range("clothing", "regen", 2, "[0.02, 0.04]")
	ck_range("clothing", "regen", 3, "[0.05, 0.1]")
	ck_range("clothing", "low_hp_regen", 1, "[0.02, 0.02]")
	ck_range("clothing", "low_hp_regen", 2, "[0.04, 0.04]")
	ck_range("clothing", "low_hp_regen", 3, "[0.1, 0.1]")
	ck_range("clothing", "capacity", 1, "[1, 2]")
	ck_range("clothing", "capacity", 2, "[2, 4]")
	ck_range("clothing", "capacity", 3, "[5, 10]")
	ck_range("clothing", "insulation", 1, "[1, 5]")
	ck_range("clothing", "insulation", 2, "[5, 15]")
	ck_range("clothing", "insulation", 3, "[20, 50]")
	ck_range("clothing", "stamina_drain", 1, "[1, 5]")
	ck_range("clothing", "stamina_drain", 2, "[5, 10]")
	ck_range("clothing", "stamina_drain", 3, "[15, 25]")
	ck_range("clothing", "thirst_drain", 1, "[1, 5]")
	ck_range("clothing", "thirst_drain", 2, "[5, 10]")
	ck_range("clothing", "thirst_drain", 3, "[15, 25]")
	ck_range("clothing", "hunger_drain", 1, "[1, 5]")
	ck_range("clothing", "hunger_drain", 2, "[5, 10]")
	ck_range("clothing", "hunger_drain", 3, "[15, 25]")
	ck_range("clothing", "sanity_drain", 1, "[1, 5]")
	ck_range("clothing", "sanity_drain", 2, "[5, 10]")
	ck_range("clothing", "sanity_drain", 3, "[15, 25]")
	ck_range("clothing", "noise", 1, "[1, 5]")
	ck_range("clothing", "noise", 2, "[5, 10]")
	ck_range("clothing", "noise", 3, "[15, 25]")
	ck_range("clothing", "sprint", 1, "[1, 5]")
	ck_range("clothing", "sprint", 2, "[5, 15]")
	ck_range("clothing", "sprint", 3, "[15, 25]")
	ck_range("clothing", "extra_loot", 1, "[1, 1]")
	ck_range("clothing", "extra_loot", 2, "[2, 3]")
	ck_range("clothing", "extra_loot", 3, "[5, 10]")

	# статы, которых матрица не касается, остаются прежними
	ck_range("gadget", "battery_save", 1, "[5, 10]")
	ck_range("gadget", "battery_save", 2, "[20, 50]")
	ck_range("gadget", "battery_save", 3, "[70, 90]")
	var pr: Dictionary = Pool.entry("clothing", "protection")
	ck(pr["ranges"].has(2) and pr["ranges"].has(3) and not pr["ranges"].has(1),
		"protection tiers unchanged")
	ck(Pool.validate().is_empty(), "all ranges are valid")

	# --- флаги: единица flag и веса ---
	ck(str(Pool.entry("weapon", "never_jam").get("unit", "")) == "flag", "never_jam unit flag")
	ck(str(Pool.entry("weapon", "unbreakable").get("unit", "")) == "flag", "unbreakable unit flag")
	ck(float(Pool.entry("weapon", "unbreakable").get("weight", 0.0)) == 0.04, "unbreakable weight 0.04")
	ck(float(Pool.entry("weapon", "never_jam").get("weight", 0.0)) == 0.1, "never_jam weight 0.1")
	ck(not Pool.entry("weapon", "never_jam")["ranges"].has(1), "never_jam starts at Rare")
	ck(not Pool.entry("weapon", "unbreakable")["ranges"].has(1)
		and not Pool.entry("weapon", "unbreakable")["ranges"].has(2), "unbreakable is Legendary only")

	# --- max_hp: расширенные диапазоны 1-5 / 5-15 / 15-30 ---
	var hp: Dictionary = Pool.entry("clothing", "max_hp")
	ck(str(hp["ranges"][1]) == "[1, 5]", "max_hp T1 1-5: " + str(hp["ranges"][1]))
	ck(str(hp["ranges"][2]) == "[5, 15]", "max_hp T2 5-15: " + str(hp["ranges"][2]))
	ck(str(hp["ranges"][3]) == "[15, 30]", "max_hp T3 15-30: " + str(hp["ranges"][3]))

	# --- frost_resistant: только легендарная одежда ---
	var fr: Dictionary = Pool.entry("clothing", "frost_resistant")
	ck(not fr.is_empty(), "frost_resistant exists in clothing")
	ck(fr["ranges"].has(3) and not fr["ranges"].has(1) and not fr["ranges"].has(2),
		"frost_resistant is Legendary only")
	ck(str(fr.get("unit", "")) == "flag", "frost_resistant unit flag")
	ck(Pool.entry("weapon", "frost_resistant").is_empty(), "frost_resistant not on weapons")
	ck(Pool.entry("gadget", "frost_resistant").is_empty(), "frost_resistant not on gadgets")

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

	print("")
	if fails > 0:
		print("FAILED: %d" % fails)
		quit(1)
	else:
		print("tests passed")
		quit(0)
