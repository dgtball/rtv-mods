extends RefCounted

# Applies loot tier+affixes to slotData.
# Coordinates Store.stamp (tier/affixes) and Sidecar.populate (uid/plate).

const Log = preload("res://mods/RoadToLoot/RTLLog.gd")
const Store = preload("res://mods/RoadToLoot/RTLStore.gd")
const Sidecar = preload("res://mods/RoadToLoot/RTLSidecar.gd")

# Stamp tier and affixes into slotData (calls Store.stamp).
# This does NOT handle uid/plate — use stamp_with_meta() for that.
static func stamp(slotData, tier: int, affixes: Array) -> void:
	if slotData == null:
		Log.warn("Apply.stamp: slotData null")
		return
	Store.stamp(slotData, tier, affixes)

# Full stamp: tier+affixes + uid/plate from sidecar data dict.
# data = {tier, affixes, uid?, plate?}
static func stamp_with_meta(slotData, data: Dictionary) -> void:
	if slotData == null:
		return
	var tier: int = int(data.get("tier", 0))
	var affixes: Array = data.get("affixes", []) if data.get("affixes") is Array else []
	Store.stamp(slotData, tier, affixes)
	# uid/plate via Sidecar
	if data.has("uid") or data.has("plate"):
		Sidecar.populate(slotData, data)

# Clear slot: tier=0, affixes=[], uid/plate cleared.
static func clear(slotData) -> void:
	if slotData == null:
		return
	Store.clear(slotData)

# Check if slot has non-zero tier (has loot applied)
static func has_loot(slotData) -> bool:
	return Store.has_tier(slotData)