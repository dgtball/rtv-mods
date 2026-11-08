extends SceneTree

const Appl = preload("res://mods/RoadToLoot/RTLStatsApplicator.gd")
const Stats = preload("res://mods/RoadToLoot/RTLStats.gd")

class FakeItem extends Node:
	var slotData = null

class FakeSlotData extends Resource:
	var itemData = null

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _make_slot(slot_data) -> Node:
	var slot := Node.new()
	var item := FakeItem.new()
	item.slotData = slot_data
	slot.add_child(item)
	return slot

func _init() -> void:
	# пустое или неподходящее снаряжение
	ck(Appl.totals_from_equipment(null).is_empty(), "null equipment -> empty")
	ck(Appl.totals_from_equipment({}).is_empty(), "non-node equipment -> empty")

	# обычный SlotData-словарь: одежда считается, оружие и пустой слот — нет
	var equipment := Node.new()
	equipment.add_child(_make_slot({
		"itemData": {"type": "Clothing", "slots": ["Torso"], "insulation": 50.0},
		"loot_affixes": [
			{"stat": "insulation", "value": 0.2, "unit": "pct"},
			{"stat": "capacity", "value": 5.0, "unit": "kg"},
			{"stat": "stamina_drain", "value": 0.1, "unit": "pct"},
			{"stat": "foo_stat", "value": 3.0, "unit": "flat"},
		],
	}))
	equipment.add_child(_make_slot({
		"itemData": {"type": "Weapon", "slots": ["Primary"]},
		"loot_affixes": [{"stat": "damage", "value": 0.2, "unit": "pct"}],
	}))
	equipment.add_child(Node.new())

	var totals: Dictionary = Appl.totals_from_equipment(equipment)
	ck(abs(totals.get("insulation", 0.0) - 10.0) < 0.001, "insulation = base 50 * 0.2")
	ck(abs(totals.get("capacity", 0.0) - 5.0) < 0.001, "capacity = 5")
	ck(abs(totals.get("stamina_drain", 0.0) - 0.1) < 0.001, "stamina_drain = 0.1")
	ck(not totals.has("damage"), "weapon affix does not leak into clothing")
	ck(not totals.has("foo_stat"), "stat outside the pool is ignored")

	# ресурс SlotData: аффиксы лежат только в метаданных (как после adopt)
	var slot_data := FakeSlotData.new()
	slot_data.itemData = {"type": "Clothing", "slots": ["Legs"], "insulation": 20.0}
	slot_data.set_meta("rtl_loot_affixes", [{"stat": "insulation", "value": 0.5, "unit": "pct"}])
	var meta_equipment := Node.new()
	meta_equipment.add_child(_make_slot(slot_data))
	var meta_totals: Dictionary = Appl.totals_from_equipment(meta_equipment)
	ck(abs(meta_totals.get("insulation", 0.0) - 10.0) < 0.001, "resource slot: meta affix 20 * 0.5")

	# два предмета складываются
	var pair := Node.new()
	pair.add_child(_make_slot({
		"itemData": {"type": "Clothing", "slots": ["Head"], "insulation": 0.0},
		"loot_affixes": [{"stat": "stamina_drain", "value": 0.05, "unit": "pct"}],
	}))
	pair.add_child(_make_slot({
		"itemData": {"type": "Clothing", "slots": ["Feet"], "insulation": 0.0},
		"loot_affixes": [{"stat": "stamina_drain", "value": 0.07, "unit": "pct"}],
	}))
	var pair_totals: Dictionary = Appl.totals_from_equipment(pair)
	ck(abs(pair_totals.get("stamina_drain", 0.0) - 0.12) < 0.001, "two items sum up")
	ck(abs(Stats.reduction_factor(pair_totals, "stamina_drain") - 0.88) < 0.001,
		"totals feed the drain factor")

	equipment.free()
	meta_equipment.free()
	pair.free()

	print("")
	if fails > 0:
		print("FAILED: %d" % fails)
		quit(1)
	else:
		print("tests passed")
		quit(0)
