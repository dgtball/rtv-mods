extends RefCounted

const WEAPON := "weapon"
const CLOTHING := "clothing"
const OTHER := "other"

const WEAPON_TYPES := ["Weapon"]
const CLOTHING_TYPES := ["Armor", "Helmet", "Rig"]

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
	return of_item(itemData) != OTHER
