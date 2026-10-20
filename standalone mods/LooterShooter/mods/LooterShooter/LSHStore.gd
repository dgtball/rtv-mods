extends RefCounted

static func tier(slotData) -> int:
	if slotData == null or not ("loot_tier" in slotData):
		return 0
	return int(slotData.loot_tier)

static func affixes(slotData) -> Array:
	if slotData == null or not ("loot_affixes" in slotData):
		return []
	return slotData.loot_affixes

static func has_tier(slotData) -> bool:
	return tier(slotData) > 0

static func stamp(slotData, tier: int, affixes: Array) -> void:
	if slotData == null or not ("loot_tier" in slotData):
		return
	slotData.loot_tier = tier
	slotData.loot_affixes = affixes

static func clear(slotData) -> void:
	stamp(slotData, 0, [])
