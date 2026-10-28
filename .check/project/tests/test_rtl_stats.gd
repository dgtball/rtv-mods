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
			{"stat": "max_hp", "value": 10.0, "unit": "hp"},
			{"stat": "sway", "value": 0.15, "unit": "pct"},
			{"stat": "condition", "value": 0.20, "unit": "pct"},
			{"stat": "regen", "value": 0.05, "unit": "rate"},
		]}
	})
	var t3: Dictionary = Stats.clothing_totals(s3)
	ck(not t3.has("max_hp"), "legacy max_hp ignored")
	ck(not t3.has("sway"), "legacy sway ignored")
	ck(not t3.has("condition"), "legacy condition ignored")
	ck(abs(t3.get("regen", 0.0) - 0.05) < 0.001, "regen IS in totals")

	# --- пустые ---
	var t4: Dictionary = Stats.clothing_totals([])
	ck(t4.is_empty(), "empty slots: empty")

	var t5: Dictionary = Stats.weapon_totals({})
	ck(t5.is_empty(), "empty weapon: empty")

	print("")
	if fails > 0:
		print("FAILED: %d" % fails)
		quit(1)
	else:
		print("tests passed")
		quit(0)
