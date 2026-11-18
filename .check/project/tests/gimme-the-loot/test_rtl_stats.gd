extends SceneTree

const Stats = preload("res://mods/RoadToLoot/RTLStats.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _init() -> void:
	# --- capacity + insulation в одном слоте ---
	var s1: Array = []
	s1.append({
		"slot_name": "Backpack",
		"item_data": {"type": "Armor", "insulation": 20.0},
		"slot_data": {"loot_affixes": [
			{"stat": "capacity", "value": 5.0, "unit": "kg"},
			{"stat": "insulation", "value": 0.20, "unit": "pct"}
		]}
	})
	var t1: Dictionary = Stats.clothing_totals(s1)
	ck(abs(t1.get("capacity", 0.0) - 5.0) < 0.001, "capacity sum = 5")
	ck(abs(t1.get("insulation", 0.0) - 4.0) < 0.001, "insulation = 20*0.20 = 4.0")

	# --- stamina_drain из двух слотов ---
	var s2: Array = []
	s2.append({
		"slot_name": "Armor",
		"item_data": {"type": "Armor", "insulation": 10.0},
		"slot_data": {"loot_affixes": [{"stat": "stamina_drain", "value": 0.10, "unit": "pct"}]}
	})
	s2.append({
		"slot_name": "Helmet",
		"item_data": {"type": "Helmet", "insulation": 5.0},
		"slot_data": {"loot_affixes": [{"stat": "stamina_drain", "value": 0.05, "unit": "pct"}]}
	})
	var t2: Dictionary = Stats.clothing_totals(s2)
	ck(abs(t2.get("stamina_drain", 0.0) - 0.15) < 0.001, "stamina_drain 0.10+0.05=0.15")

	# --- weapon_totals: один слот, recoil ---
	var ws1 := {"loot_affixes": [{"stat": "recoil", "value": 0.12, "unit": "pct"}]}
	var wr1: Dictionary = Stats.weapon_totals(ws1)
	ck(abs(wr1.get("recoil", 0.0) - 0.12) < 0.001, "weapon_totals recoil=0.12")

	# --- weapon_totals: второй слот, recoil=0.20 ---
	var ws2 := {"loot_affixes": [{"stat": "recoil", "value": 0.20, "unit": "pct"}]}
	var wr2: Dictionary = Stats.weapon_totals(ws2)
	ck(abs(wr2.get("recoil", 0.0) - 0.20) < 0.001, "weapon_totals second slot recoil=0.20")

	# --- легаси: max_hp и sway игнорируются ---
	var s3: Array = []
	s3.append({
		"slot_name": "Armor",
		"item_data": {"type": "Armor", "insulation": 0.0},
		"slot_data": {"loot_affixes": [
			{"stat": "sway", "value": 10.0, "unit": "hp"},
			{"stat": "sway", "value": 0.15, "unit": "pct"},
			{"stat": "condition", "value": 0.20, "unit": "pct"},
			{"stat": "regen", "value": 0.05, "unit": "rate"},
		]}
	})
	var t3: Dictionary = Stats.clothing_totals(s3)
	ck(not t3.has("sway"), "legacy sway ignored")
	ck(not t3.has("sway"), "legacy sway ignored")
	ck(not t3.has("condition"), "legacy condition ignored")
	ck(abs(t3.get("regen", 0.0) - 0.05) < 0.001, "regen IS in totals")

	# --- пустые ---
	var t4: Dictionary = Stats.clothing_totals([])
	ck(t4.is_empty(), "empty slots: empty")

	var t5: Dictionary = Stats.weapon_totals({})
	ck(t5.is_empty(), "empty weapon: empty")

	# --- эффект-хелперы: «меньше — лучше» и «больше — лучше» ---
	ck(abs(Stats.reduction_factor({"recoil": 0.12}, "recoil") - 0.88) < 0.001, "reduction_factor recoil 0.12 -> 0.88")
	ck(abs(Stats.reduction_factor({}, "recoil") - 1.0) < 0.001, "reduction_factor missing -> 1.0")
	ck(abs(Stats.reduction_factor({"recoil": 1.4}, "recoil") - 0.0) < 0.001, "reduction_factor has no 0.5 cap")
	ck(abs(Stats.reduction_factor({"recoil": -0.2}, "recoil") - 1.0) < 0.001, "reduction_factor clamps at 1")
	ck(abs(Stats.bonus_factor({"damage": 0.2}, "damage") - 1.2) < 0.001, "bonus_factor damage 0.2 -> 1.2")
	ck(abs(Stats.bonus_factor({}, "damage") - 1.0) < 0.001, "bonus_factor missing -> 1.0")
	ck(abs(Stats.bonus_factor({"sprint": -2.0}, "sprint")) < 0.001, "bonus_factor clamps at 0")

	# --- урон: damage + low_hp_damage только на низком HP ---
	ck(abs(Stats.damage_factor({"damage": 0.2, "low_hp_damage": 0.3}, false) - 1.2) < 0.001, "damage_factor normal")
	ck(abs(Stats.damage_factor({"damage": 0.2, "low_hp_damage": 0.3}, true) - 1.5) < 0.001, "damage_factor low hp is uncapped")
	ck(abs(Stats.damage_factor({}, false) - 1.0) < 0.001, "damage_factor no affixes")

	# --- порог низкого HP ---
	ck(Stats.is_low_hp(30.0), "is_low_hp at 30")
	ck(not Stats.is_low_hp(30.5), "is_low_hp above 30")
	ck(not Stats.is_low_hp(0.0), "is_low_hp dead is false")
	ck(Stats.is_low_hp(60.0, 200.0), "is_low_hp scales with max hp")

	# --- capacity всегда неотрицателен ---
	ck(abs(Stats.capacity_bonus({"capacity": 7.0}) - 7.0) < 0.001, "capacity_bonus 7")
	ck(abs(Stats.capacity_bonus({"capacity": -3.0})) < 0.001, "capacity_bonus clamps at 0")

	# --- sprint и noise теперь входят в суммы одежды ---
	var s4: Array = []
	s4.append({
		"slot_name": "Legs",
		"item_data": {"type": "Clothing", "insulation": 0.0},
		"slot_data": {"loot_affixes": [
			{"stat": "sprint", "value": 0.08, "unit": "pct"},
			{"stat": "noise", "value": 0.20, "unit": "pct"},
		]}
	})
	var t6: Dictionary = Stats.clothing_totals(s4)
	ck(abs(t6.get("sprint", 0.0) - 0.08) < 0.001, "sprint is summed")
	ck(abs(t6.get("noise", 0.0) - 0.20) < 0.001, "noise is summed")

	# --- ammo_save: известный стат и сумма ---
	ck(Stats.KNOWN_STATS.has("ammo_save"), "ammo_save is a known stat")
	var wa: Dictionary = Stats.weapon_totals({"loot_affixes": [
		{"stat": "ammo_save", "value": 0.12, "unit": "pct"},
		{"stat": "ammo_save", "value": 0.03, "unit": "pct"},
	]})
	ck(abs(float(wa.get("ammo_save", 0.0)) - 0.15) < 0.001, "weapon_totals sums ammo_save")
	ck(abs(Stats.ammo_save_chance(wa) - 0.15) < 0.001, "ammo_save_chance = 0.15")
	ck(abs(Stats.ammo_save_chance({"ammo_save": 5.0}) - 1.0) < 0.001, "ammo_save_chance caps at 1.0, not 0.9")
	ck(abs(Stats.ammo_save_chance({}) - 0.0) < 0.001, "ammo_save_chance empty totals = 0")

	# --- shot_spent_round: таблица истинности ---
	ck(Stats.shot_spent_round(30, 29, true, true), "auto: amount dropped -> spent")
	ck(Stats.shot_spent_round(1, 0, true, false), "single: amount dropped -> spent")
	ck(Stats.shot_spent_round(0, 0, true, false), "manual last round: chamber emptied -> spent")
	ck(not Stats.shot_spent_round(30, 30, true, true), "cooldown or malfunction: nothing changed")
	ck(not Stats.shot_spent_round(0, 0, false, false), "empty auto: nothing changed")
	ck(not Stats.shot_spent_round(5, 5, false, false), "idle: nothing changed")

	# --- капы сняты: остаются только границы области определения ---
	ck(abs(Stats.bonus_factor({"damage": 5.0}, "damage") - 6.0) < 0.001, "bonus_factor has no per-stat cap")
	ck(abs(Stats.bonus_factor({"sprint": 3.0}, "sprint") - 4.0) < 0.001, "sprint is uncapped")
	ck(abs(Stats.bonus_factor({"max_hp": 3.0}, "max_hp") - 4.0) < 0.001, "max_hp is uncapped")
	ck(abs(Stats.damage_factor({"damage": 3.0}, false) - 4.0) < 0.001, "damage_factor has no 1.0 cap")
	ck(abs(Stats.damage_factor({"low_hp_damage": 1.0}, true) - 2.0) < 0.001, "low_hp_damage has no 0.2 cap")
	ck(abs(Stats.capacity_bonus({"capacity": 80.0}) - 80.0) < 0.001, "capacity has no 50 cap")
	ck(abs(Stats.capacity_bonus({"capacity": -5.0})) < 0.001, "capacity still floors at 0")

	# --- новые статы в белом списке ---
	for st in ["never_jam", "unbreakable", "battery_save"]:
		ck(Stats.KNOWN_STATS.has(st), st + " is a known stat")
	ck(Stats.PER_SLOT_STATS == ["battery_save"], "battery_save is per-slot")

	# --- has_flag ---
	var flags := [{"stat": "never_jam", "value": 1.0, "unit": "flag"}]
	ck(Stats.has_flag(flags, "never_jam"), "has_flag finds the flag")
	ck(not Stats.has_flag(flags, "unbreakable"), "has_flag misses another stat")
	ck(not Stats.has_flag([{"stat": "never_jam", "value": 0.0}], "never_jam"), "zero flag is off")
	ck(not Stats.has_flag([], "never_jam"), "empty affixes have no flag")
	ck(not Stats.has_flag([null, "nope"], "never_jam"), "garbage is ignored")

	# --- unbreakable_step: захват, заморозка, ремонт ---
	var cap: Dictionary = Stats.unbreakable_step(-1.0, 73.0)
	ck(bool(cap["changed"]) and absf(float(cap["base"]) - 73.0) < 0.001 and absf(float(cap["condition"]) - 73.0) < 0.001,
		"capture stores the current condition")
	var drop: Dictionary = Stats.unbreakable_step(73.0, 40.0)
	ck(bool(drop["changed"]) and absf(float(drop["condition"]) - 73.0) < 0.001 and absf(float(drop["base"]) - 73.0) < 0.001,
		"wear is restored to the base")
	var repair: Dictionary = Stats.unbreakable_step(73.0, 100.0)
	ck(bool(repair["changed"]) and absf(float(repair["base"]) - 100.0) < 0.001 and absf(float(repair["condition"]) - 100.0) < 0.001,
		"repair raises the base")
	var same: Dictionary = Stats.unbreakable_step(73.0, 73.0)
	ck(not bool(same["changed"]), "equal condition is a no-op")

	# --- battery_factor: читает только аффиксы этого гаджета ---
	var bat := [{"stat": "battery_save", "value": 0.9, "unit": "pct"}]
	ck(absf(Stats.battery_factor(bat) - 0.1) < 0.001, "90% battery_save leaves 10% drain")
	ck(absf(Stats.battery_factor([]) - 1.0) < 0.001, "no affix: full drain")
	ck(absf(Stats.battery_factor([{"stat": "battery_save", "value": 1.5}]) - 0.0) < 0.001,
		"battery_factor floors at zero")
	ck(absf(Stats.battery_factor([{"stat": "battery_save", "value": -0.2}]) - 1.0) < 0.001,
		"negative battery_save is ignored by the clamp")

	# --- гаджетные тоталы: комфорт считается, battery_save — нет ---
	var g1: Array = []
	g1.append({
		"slot_name": "Time",
		"item_data": {"type": "Electronics", "insulation": 0.0},
		"slot_data": {"loot_affixes": [
			{"stat": "extra_loot", "value": 0.03, "unit": "pct"},
			{"stat": "sanity_drain", "value": 0.05, "unit": "pct"},
			{"stat": "battery_save", "value": 0.9, "unit": "pct"},
		]}
	})
	var gt: Dictionary = Stats.clothing_totals(g1)
	ck(absf(float(gt.get("extra_loot", 0.0)) - 0.03) < 0.001, "gadget extra_loot is summed")
	ck(absf(float(gt.get("sanity_drain", 0.0)) - 0.05) < 0.001, "gadget sanity_drain is summed")
	ck(not gt.has("battery_save"), "battery_save never enters the shared totals")

	print("")
	if fails > 0:
		print("FAILED: %d" % fails)
		quit(1)
	else:
		print("tests passed")
		quit(0)
