extends RefCounted

const KNIFE_SLOT := "Knife"
const WEAPON_TYPE := "weapon"
const PISTOL_SUBTYPE := "pistol"

# Reads a field from an item resource or a plain Dictionary. Godot's Object.get()
# takes exactly one argument, so no default is passed here.
static func prop(src, key: String) -> Variant:
	if src == null:
		return null
	return src.get(key)

static func _field(src, key: String) -> String:
	return str(prop(src, key)).strip_edges().to_lower()

static func is_pistol(item_data) -> bool:
	return _field(item_data, "type") == WEAPON_TYPE \
		and _field(item_data, "subtype") == PISTOL_SUBTYPE

static func has_knife_slot(slots) -> bool:
	if not (slots is Array):
		return false
	return slots.has(KNIFE_SLOT)

# Appends into the caller's array (itemData.slots) instead of building a new one,
# so the live resource keeps the added slot.
static func add_knife_slot(slots) -> bool:
	if not (slots is Array):
		return false
	if slots.has(KNIFE_SLOT):
		return false
	slots.append(KNIFE_SLOT)
	return true

static func should_alias(drawn_knife: bool, slot_count: int, item_data) -> bool:
	return drawn_knife and slot_count > 0 and is_pistol(item_data)
