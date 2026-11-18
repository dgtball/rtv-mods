extends RefCounted

const WEAPON := "weapon"
const CLOTHING := "clothing"
const GADGET := "gadget"
const OTHER := "other"

const WEAPON_SLOTS := ["Primary", "Secondary", "Knife"]
const CLOTHING_SLOTS := ["Backpack", "Rig", "Helmet", "Head", "Torso", "Legs", "Belt", "Feet", "Hands"]
const GADGET_BATTERY_SLOTS := ["Light", "NVG", "Player"]
const GADGET_COMFORT_SLOTS := ["Time", "Map"]
const NON_WEAPON_TYPES := ["Fishing", "Instrument"]
const KNIFE_TYPE := "Knife"
const KNIFE_BLOCKED := ["recoil", "fire_rate", "wear", "unbreakable"]

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
	if _has_any(slots, GADGET_BATTERY_SLOTS) or _has_any(slots, GADGET_COMFORT_SLOTS):
		return GADGET
	return OTHER

# Какой аффиксный набор получает гаджет: батарейный или комфортный.
static func gadget_kind(itemData) -> String:
	if itemData == null:
		return ""
	var slots := _slots(itemData)
	if _has_any(slots, GADGET_BATTERY_SLOTS):
		return "battery"
	if _has_any(slots, GADGET_COMFORT_SLOTS):
		return "comfort"
	return ""

# unbreakable: оружие (кроме ножа), шлем и разгрузка. Пластина без SlotData
# сюда не попадает, её прочность защищает разгрузка.
static func is_durable(itemData) -> bool:
	if itemData == null:
		return false
	var cat := of_item(itemData)
	if cat == WEAPON:
		return _field_str(itemData, "type") != KNIFE_TYPE
	if cat != CLOTHING:
		return false
	var t := _field_str(itemData, "type")
	return t == "Helmet" or t == "Rig"

static func rollable(itemData) -> bool:
	return of_item(itemData) != OTHER

static func is_firearm(itemData) -> bool:
	if of_item(itemData) != WEAPON:
		return false
	return _field_str(itemData, "type") != KNIFE_TYPE

static func stat_allowed(itemData, stat: String) -> bool:
	if itemData == null:
		return true
	if not KNIFE_BLOCKED.has(stat):
		return true
	return _field_str(itemData, "type") != KNIFE_TYPE
