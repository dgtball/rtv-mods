extends RefCounted

const META_UID := "rtl_uid"
const META_PLATE := "rtl_plate"

static func get_uid(slotData) -> String:
	if slotData == null:
		return ""
	if slotData.has_meta(META_UID):
		return str(slotData.get_meta(META_UID, ""))
	return ""

static func get_plate(slotData) -> int:
	if slotData == null:
		return 0
	if slotData.has_meta(META_PLATE):
		return int(slotData.get_meta(META_PLATE, 0))
	return 0

static func set_uid(slotData, uid: String) -> void:
	if slotData == null:
		return
	slotData.set_meta(META_UID, uid)

static func set_plate(slotData, plate: int) -> void:
	if slotData == null:
		return
	slotData.set_meta(META_PLATE, plate)

# Returns all sidecar data as a Dictionary {uid, plate}
static func read(slotData) -> Dictionary:
	return {
		"uid": get_uid(slotData),
		"plate": get_plate(slotData)
	}

# Populate slotData from a sidecar dict (used by RTLStore population)
static func populate(slotData, data: Dictionary) -> void:
	if slotData == null:
		return
	if data.has("uid"):
		set_uid(slotData, str(data.get("uid", "")))
	if data.has("plate"):
		set_plate(slotData, int(data.get("plate", 0)))

# Clear slot metadata (called when item is removed/unequipped)
static func clear_slot(slotData) -> void:
	if slotData == null:
		return
	slotData.set_meta(META_UID, "")
	slotData.set_meta(META_PLATE, 0)

# Meta-transfer pre-hook: prepare before game state changes
# slotData = the slot being modified, itemData = the item involved
static func prepare_slot(slotData, itemData=null) -> void:
	# Currently a no-op; exists for future use (e.g. snapshot before equip)
	pass

# Meta-transfer post-hook: commit after game state changes
# slotData = the slot that was modified
static func commit_slot(slotData) -> void:
	# Currently a no-op; exists for future use (e.g. validate after change)
	pass
