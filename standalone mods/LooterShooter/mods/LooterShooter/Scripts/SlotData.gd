extends "res://Scripts/SlotData.gd"

@export var loot_tier: int = 0
var loot_affixes: Array = []

func Update(slotData) -> void:
	super.Update(slotData)
	if "loot_tier" in slotData:
		loot_tier = slotData.loot_tier
	if "loot_affixes" in slotData:
		if slotData.loot_affixes is Array:
			loot_affixes = slotData.loot_affixes.duplicate(true)
		else:
			loot_affixes = []

func Reset() -> void:
	super.Reset()
	loot_tier = 0
	loot_affixes.clear()
