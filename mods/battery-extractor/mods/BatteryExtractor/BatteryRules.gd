extends RefCounted

const TARGET_FILES: Array = ["Polaris", "Narva", "Phoenix", "PV7", "Casette_Player"]
const PARTIAL_META := "battery_extractor_partial"
const PARTIAL_DISPLAY := "Battery (partial)"


static func is_target(file: String) -> bool:
	return TARGET_FILES.has(file)


static func can_extract(condition) -> bool:
	var value: Variant = _number(condition)
	if value == null:
		return false
	return value > 0.0


static func charge_for(condition) -> float:
	var value: Variant = _number(condition)
	if value == null:
		return 0.0
	return clampf(value, 0.0, 100.0)


static func mark_partial(item_data) -> bool:
	if item_data == null or not (item_data is Object):
		return false
	item_data.set_meta(PARTIAL_META, true)
	item_data.set("display", PARTIAL_DISPLAY)
	item_data.set("showCondition", true)
	item_data.set("stackable", false)
	item_data.set("maxAmount", 0)
	return true


static func is_partial(item_data) -> bool:
	if item_data == null or not (item_data is Object):
		return false
	if not item_data.has_meta(PARTIAL_META):
		return false
	return bool(item_data.get_meta(PARTIAL_META))


static func _number(value) -> Variant:
	if value is int or value is float:
		return float(value)
	return null
