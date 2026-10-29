class_name RTLProbeSlot
extends Resource

# Stand-in for the game's SlotData. Update() copies vanilla fields only, which
# is exactly why a roll stored as metadata used to vanish on every save/load:
# the fresh SlotData that SaveCharacter builds never saw it.

@export var itemData: String = ""
@export var condition: int = 0

func Update(src) -> void:
	itemData = src.itemData
	condition = src.condition
