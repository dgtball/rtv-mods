extends Resource

# Stand-in for the game's CharacterSave: a resource holding a typed array of
# sub-resources, saved to and loaded from a .tres file. The real save types the
# arrays as Array[SlotData], so the probe uses a typed array too.

@export var inventory: Array[RTLProbeSlot] = []
