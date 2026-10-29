extends SceneTree

const Store = preload("res://mods/RoadToLoot/RTLStore.gd")
const World = preload("res://mods/RoadToLoot/RTLWorld.gd")

var fails := 0

# RefCounted stand-ins instead of Nodes: fresh_slots only reads properties, and
# Nodes left unparented at quit would leak into the ObjectDB warning. Slot keeps
# itemData untyped: Task 2 hands it a fake ItemData that answers get(), while
# fresh_slots only compares it against null.
class Marker extends RefCounted:
	pass

class Slot extends RefCounted:
	var itemData = null

class Pickup extends RefCounted:
	var slotData = null

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _slot(item):
	var sd = Slot.new()
	sd.itemData = item
	return sd

func _init() -> void:
	# --- dirty input ---
	ck(World.fresh_slots([]).is_empty(), "empty children -> empty")
	ck(World.fresh_slots(null).is_empty(), "null children -> empty")
	ck(World.fresh_slots([null]).is_empty(), "null child is skipped")
	# LootSimulation._ready() frees get_child(0); that marker has no slotData.
	ck(World.fresh_slots([Marker.new()]).is_empty(), "marker without slotData is skipped")
	var empty := Pickup.new()
	ck(World.fresh_slots([empty]).is_empty(), "pickup without slotData is skipped")
	var no_item := Pickup.new()
	no_item.slotData = Slot.new()
	ck(World.fresh_slots([no_item]).is_empty(), "slotData without itemData is skipped")

	# --- a fresh pickup is selected ---
	var fresh := Pickup.new()
	var sd = _slot("AKM")
	fresh.slotData = sd
	var picked: Array = World.fresh_slots([Marker.new(), fresh])
	ck(picked.size() == 1, "fresh pickup is selected")
	ck(picked[0] == sd, "the slotData itself is returned, not the node")

	# --- a rolled pickup is skipped (force tables call SpawnItems repeatedly) ---
	var rolled := Pickup.new()
	var rsd = _slot("Mosin")
	Store.stamp(rsd, 2, [])
	rolled.slotData = rsd
	ck(World.fresh_slots([rolled]).is_empty(), "already rolled pickup is skipped")
	ck(World.fresh_slots([Marker.new(), fresh, rolled]).size() == 1,
		"mixed list keeps only the fresh pickup")

	# --- a Common roll is tier 0 but still a roll: skip it too ---
	var common := Pickup.new()
	var csd = _slot("Mosin")
	Store.stamp(csd, 0, [])
	common.slotData = csd
	ck(World.fresh_slots([common]).is_empty(), "tier-0 stamped pickup is skipped")

	print("")
	if fails > 0:
		print("FAILED: %d" % fails)
		quit(1)
	else:
		print("tests passed")
		quit(0)
