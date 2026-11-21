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

# Vanilla fits an equipped sprite by width only when the item is strictly wider
# than the slot. A square 2x2 pistol in the 2x1 knife slot has width == slot width,
# so it keeps base scale and its 128px height spills out of the 64px slot.
# Return the height-fit scale for that case, or -1 when vanilla already handled it.
static func knife_icon_scale(item_data, slot_size, current_scale: float) -> float:
	var item_size = prop(item_data, "size")
	var sprite_w: float
	var sprite_h: float
	if item_size is Vector2:
		sprite_w = item_size.x * 64.0
		sprite_h = item_size.y * 64.0
	elif item_size is Dictionary:
		sprite_w = float(item_size.get("x", 0.0)) * 64.0
		sprite_h = float(item_size.get("y", 0.0)) * 64.0
	else:
		return -1.0
	var slot_w: float
	var slot_h: float
	if slot_size is Vector2:
		slot_w = slot_size.x
		slot_h = slot_size.y
	elif slot_size is Dictionary:
		slot_w = float(slot_size.get("x", 0.0))
		slot_h = float(slot_size.get("y", 0.0))
	else:
		return -1.0
	if sprite_w > slot_w or sprite_h <= slot_h:
		return -1.0
	var fit: float = slot_h / (sprite_h * 2.0)
	if fit >= current_scale:
		return -1.0
	return fit
