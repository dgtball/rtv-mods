extends SceneTree

const Stats = preload("res://mods/RoadToLoot/RTLStats.gd")

func _init() -> void:
	var slots := [
		{
			"slot_name": "Backpack",
			"item_data": {"type": "Armor", "insulation": 20.0},
			"slot_data": {"loot_affixes": [
				{"stat": "carry", "value": 5.0, "unit": "kg"},
				{"stat": "insulation", "value": 0.20, "unit": "pct"}
			]}
		}
	]
	var result = Stats.clothing_totals(slots)
	print("result = ", result)
	print("carry = ", result.get("carry", 999.0))
	print("insulation = ", result.get("insulation", 999.0))
	quit(0)
