extends SceneTree

const Pool = preload("res://mods/RoadToLoot/RTLPool.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _init() -> void:
	ck(Pool.ACTIVE_RELEASE == 3, "ACTIVE_RELEASE == 3")

	# --- condition снят с обеих категорий ---
	ck(not Pool.affix_ids("weapon").has("condition"), "weapon: condition removed")
	ck(not Pool.affix_ids("clothing").has("condition"), "clothing: condition removed")
	ck(Pool.entry("weapon", "condition").is_empty(), "weapon: no condition entry")
	ck(Pool.entry("clothing", "condition").is_empty(), "clothing: no condition entry")
	ck(Pool.POOL.size() == 21, "POOL: 21 entries")

	# --- релизный гейт: 7 оружейных, 14 одежды, 3 гаджетных ---
	ck(Pool.entries("weapon").size() == 7, "weapon pool: 7 entries")
	ck(Pool.entries("clothing").size() == 14, "clothing pool: 14 entries")
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
	ck(float(wr["ranges"][1][0]) == 10.0 and float(wr["ranges"][1][1]) == 20.0, "wear T1 10-20")
	ck(float(wr["ranges"][2][0]) == 20.0 and float(wr["ranges"][2][1]) == 35.0, "wear T2 20-35")
	ck(float(wr["ranges"][3][0]) == 35.0 and float(wr["ranges"][3][1]) == 60.0, "wear T3 35-60")

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

	print("")
	if fails > 0:
		print("FAILED: %d" % fails)
		quit(1)
	else:
		print("tests passed")
		quit(0)
