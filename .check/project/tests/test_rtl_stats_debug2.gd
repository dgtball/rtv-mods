extends SceneTree

const Stats = preload("res://mods/RoadToLoot/RTLStats.gd")

func _init() -> void:
	# Debug: stamina_drain test
	var test_slots: Array = []
	test_slots.append({
		"slot_name": "Armor",
		"item_data": {"type": "Armor", "insulation": 10.0},
		"slot_data": {"loot_affixes": [{"stat": "stamina_drain", "value": 0.10, "unit": "pct"}]}
	})
	test_slots.append({
		"slot_name": "Helmet",
		"item_data": {"type": "Helmet", "insulation": 5.0},
		"slot_data": {"loot_affixes": [{"stat": "stamina_drain", "value": 0.05, "unit": "pct"}]}
	})
	var r = Stats.clothing_totals(test_slots)
	print("stamina result = ", r)
	print("stamina_drain = ", r.get("stamina_drain", 999.0))

	# Debug: weapon_totals
	var ws = {"loot_affixes": [{"stat": "recoil", "value": 0.12, "unit": "pct"}]}
	var wr = Stats.weapon_totals(ws)
	print("weapon result = ", wr)
	print("recoil = ", wr.get("recoil", 999.0))

	quit(0)
