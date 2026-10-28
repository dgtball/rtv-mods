extends RefCounted

const WEAPON := "weapon"
const CLOTHING := "clothing"
const OTHER := "other"

const WEAPON_TYPES := ["Weapon", "Melee", "Tool"]
const CLOTHING_TYPES := ["Armor", "Helmet", "Rig", "Gloves", "Boots", "Arm", "Leg", "Waist", "Mask", "Belt", "Shirt", "Pants", "Vest", "Jacket", "Coat", "Hood", "Backpack"]

static func of_path(path: String) -> String:
	var p := path.to_lower()
	if p == "":
		return OTHER
	if p.contains("/weapons/"):
		return WEAPON
	if p.contains("/clothing/") or p.contains("/armor/") or p.contains("/helmets/"):
		return CLOTHING
	return OTHER

static func of_item(itemData) -> String:
	if itemData == null:
		return OTHER
	var t: String = str(itemData.get("type")) if "type" in itemData else ""
	if WEAPON_TYPES.has(t):
		return WEAPON
	if CLOTHING_TYPES.has(t):
		return CLOTHING
	var path: String = str(itemData.get("resource_path")) if "resource_path" in itemData else ""
	return of_path(path)

static func rollable(itemData) -> bool:
	if itemData == null:
		return false
	var sub: String = str(itemData.get("subtype")) if "subtype" in itemData else ""
	if sub.to_lower() == "magazine":
		return false
	var name: String = str(itemData.get("name")) if "name" in itemData else ""
	if name.to_lower().ends_with("magazine") or name.to_lower().ends_with("magazine "):
		return false
	return of_item(itemData) != OTHER
