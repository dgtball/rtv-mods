extends RefCounted

const WEAPON := "weapon"
const CLOTHING := "clothing"
const OTHER := "other"

const WEAPON_SLOTS := ["Primary", "Secondary", "Knife"]
const CLOTHING_SLOTS := ["Backpack", "Rig", "Helmet", "Head", "Torso", "Legs", "Belt", "Feet", "Hands"]
const NON_WEAPON_TYPES := ["Fishing", "Instrument"]
const KNIFE_TYPE := "Knife"
const KNIFE_BLOCKED := ["recoil", "fire_rate"]

static func _field_str(itemData, field: String) -> String:
	if itemData == null:
		return ""
	var raw = itemData.get(field)
	if raw == null:
		return ""
	var s := str(raw)
	return s.strip_edges()

static func _slots(itemData) -> Array:
	if itemData == null:
		return []
	var raw = itemData.get("slots")
	if raw is Array:
		return raw
	return []

static func _has_any(slots: Array, allowed: Array) -> bool:
	for s in slots:
		var ss := str(s).strip_edges()
		if allowed.has(ss):
			return true
	return false

static func of_item(itemData) -> String:
	if itemData == null:
		return OTHER
	var t := _field_str(itemData, "type")
	if NON_WEAPON_TYPES.has(t):
		return OTHER
	var slots := _slots(itemData)
	if _has_any(slots, WEAPON_SLOTS):
		return WEAPON
	if _has_any(slots, CLOTHING_SLOTS):
		return CLOTHING
	return OTHER

static func rollable(itemData) -> bool:
	return of_item(itemData) != OTHER

static func stat_allowed(itemData, stat: String) -> bool:
	if itemData == null:
		return true
	if not KNIFE_BLOCKED.has(stat):
		return true
	return _field_str(itemData, "type") != KNIFE_TYPE
