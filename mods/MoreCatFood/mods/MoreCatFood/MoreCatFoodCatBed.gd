extends RefCounted

# Чистая логика совместимости с Cat Bed + Food Tray. Никаких путей внутрь игры
# и никаких обращений к autoload'у cat-bed: всё приходит аргументами, чтобы
# правила можно было прогнать headless.

const Rules = preload("res://mods/MoreCatFood/MoreCatFoodRules.gd")

const TRAY_GROUP := "CatBedTrayTray"
const INTERACTABLE_GROUP := "Interactable"
const CAN_CODE := "F"

static func food_path_for_slot(slot: Object) -> String:
	if slot == null or not is_instance_valid(slot):
		return ""
	var data = slot.get("slotData")
	if data == null or not is_instance_valid(data):
		return ""
	var item = data.get("itemData")
	if item == null or not is_instance_valid(item):
		return ""
	var path := str(item.get("resource_path"))
	if Rules.FOOD_PATHS.has(path):
		return path
	return ""

static func is_beer_path(path: String) -> bool:
	return Rules.is_beer_path(path)

static func tray_codes_after_add(codes: String) -> String:
	return codes + CAN_CODE

static func looked_tray(interactor: Node) -> Node:
	if interactor == null or not is_instance_valid(interactor):
		return null
	var target = interactor.get("target")
	if target == null or not is_instance_valid(target) or not (target is Node):
		return null
	if not target.is_in_group(INTERACTABLE_GROUP):
		return null
	var station = target.get("owner")
	if station == null or not is_instance_valid(station) or not (station is Node):
		return null
	if not station.is_in_group(TRAY_GROUP):
		return null
	return station
