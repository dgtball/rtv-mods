extends RefCounted

const Store = preload("res://mods/RoadToLoot/RTLStore.gd")

# LootSimulation rebuilds its pickups on every map load, so only the ones it
# just created may roll. A force-table calls SpawnItems() once per item and
# keeps the earlier children, hence the is_stamped filter.
static func fresh_slots(children) -> Array:
	var out: Array = []
	if not (children is Array):
		return out
	for c in children:
		if not is_instance_valid(c):
			continue
		if not ("slotData" in c):
			continue
		var sd = c.slotData
		if sd == null:
			continue
		if not ("itemData" in sd) or sd.itemData == null:
			continue
		if Store.is_stamped(sd):
			continue
		out.append(sd)
	return out
