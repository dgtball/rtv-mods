extends RefCounted

const Log = preload("res://mods/RoadToLoot/RTLLog.gd")
const Sidecar = preload("res://mods/RoadToLoot/RTLSidecar.gd")

static func tier(slotData) -> int:
	if slotData == null:
		return 0
	if "loot_tier" in slotData and slotData.loot_tier is int:
		return int(slotData.loot_tier)
	if slotData.has_meta("rtl_loot_tier"):
		return int(slotData.get_meta("rtl_loot_tier"))
	return 0

static func affixes(slotData) -> Array:
	if slotData == null:
		return []
	if "loot_affixes" in slotData and slotData.loot_affixes is Array:
		return slotData.loot_affixes.duplicate(true)
	if slotData.has_meta("rtl_loot_affixes"):
		var m = slotData.get_meta("rtl_loot_affixes")
		if m is Array:
			return m.duplicate(true)
	return []

static func has_tier(slotData) -> bool:
	return tier(slotData) > 0

static func stamp(slotData, tier: int, affixes: Array) -> void:
	if slotData == null:
		Log.warn("stamp: slotData null")
		return
	var arr: Array = affixes if affixes is Array else []
	if "loot_tier" in slotData:
		slotData.loot_tier = tier
	if "loot_affixes" in slotData:
		slotData.loot_affixes = arr.duplicate(true)
	slotData.set_meta("rtl_loot_tier", tier)
	slotData.set_meta("rtl_loot_affixes", arr.duplicate(true))
	if not ("loot_tier" in slotData) and not (slotData.has_meta("rtl_loot_tier") and int(slotData.get_meta("rtl_loot_tier")) == tier):
		Log.warn("stamp FAILED (tier=" + str(tier) + ")")

static func clear(slotData) -> void:
	stamp(slotData, 0, [])
	Sidecar.clear_slot(slotData)
