extends "res://Scripts/SlotData.gd"

@export var loot_tier: int = 0
@export var loot_affixes: Array = []

func Update(slotData) -> void:
	super.Update(slotData)
	loot_tier = slotData.loot_tier
	loot_affixes = slotData.loot_affixes.duplicate(true)

func Reset() -> void:
	super.Reset()
	loot_tier = 0
	loot_affixes.clear()
