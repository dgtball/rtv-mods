extends RefCounted

const Log = preload("res://mods/RoadToLoot/RTLLog.gd")
const Sidecar = preload("res://mods/RoadToLoot/RTLSidecar.gd")

static func tier(slotData) -> int:
	if slotData == null:
		return 0
	if "loot_tier" in slotData and slotData.loot_tier is int:
		return int(slotData.loot_tier)
	if slotData.has_meta("rtl_loot_tier"):
		return int(slotData.get_meta("rtl_loot_tier"))
	return 0

static func affixes(slotData) -> Array:
	if slotData == null:
		return []
	if "loot_affixes" in slotData and slotData.loot_affixes is Array:
		return slotData.loot_affixes.duplicate(true)
	if slotData.has_meta("rtl_loot_affixes"):
		var m = slotData.get_meta("rtl_loot_affixes")
		if m is Array:
			return m.duplicate(true)
	return []

static func has_tier(slotData) -> bool:
	return tier(slotData) > 0

# True once RTL has written a roll onto this slot -- including a Common roll,
# which is tier 0 and therefore invisible to has_tier(). The world-loot path
# needs this: a force-table calls SpawnItems() once per item and reaches the
# earlier pickups again.
static func is_stamped(slotData) -> bool:
	if slotData == null:
		return false
	return slotData.has_meta("rtl_loot_tier")

static func stamp(slotData, tier: int, affixes: Array) -> void:
	if slotData == null:
		Log.warn("stamp: slotData null")
		return
	var arr: Array = affixes if affixes is Array else []
	if "loot_tier" in slotData:
		slotData.loot_tier = tier
	if "loot_affixes" in slotData:
		slotData.loot_affixes = arr.duplicate(true)
	slotData.set_meta("rtl_loot_tier", tier)
	slotData.set_meta("rtl_loot_affixes", arr.duplicate(true))
	if not ("loot_tier" in slotData) and not (slotData.has_meta("rtl_loot_tier") and int(slotData.get_meta("rtl_loot_tier")) == tier):
		Log.warn("stamp FAILED (tier=" + str(tier) + ")")

static func clear(slotData) -> void:
	stamp(slotData, 0, [])
	Sidecar.clear_slot(slotData)

# Copies the mod's own data (roll + identity) from one SlotData to another.
# Vanilla rebuilds SlotData through Update(), which copies vanilla fields only,
# so every such copy is a place where a roll would silently disappear.
static func mirror(src, dst) -> bool:
	if src == null or dst == null:
		return false
	var t: int = tier(src)
	if t <= 0:
		return false
	stamp(dst, t, affixes(src))
	var uid := Sidecar.get_uid(src)
	if uid != "":
		Sidecar.set_uid(dst, uid)
	var plate := Sidecar.get_plate(src)
	if plate > 0:
		Sidecar.set_plate(dst, plate)
	return true

# Fills a freshly initialized SlotData from the copy vanilla hands to
# Item.Initialize(). That copy has been through Update(), so the roll lives
# there only if the save itself carried it. Returns true when the item has a roll.
static func adopt(dst, src) -> bool:
	if dst == null:
		return false
	if tier(dst) <= 0:
		if src == null or tier(src) <= 0:
			return false
		stamp(dst, tier(src), affixes(src))
	if src != null:
		if Sidecar.get_uid(dst) == "":
			var uid := Sidecar.get_uid(src)
			if uid != "":
				Sidecar.set_uid(dst, uid)
		if Sidecar.get_plate(dst) <= 0:
			var plate := Sidecar.get_plate(src)
			if plate > 0:
				Sidecar.set_plate(dst, plate)
	return tier(dst) > 0

# Vanilla builds every saved SlotData with a fresh SlotData + Update(), which
# copies vanilla fields only, so metadata never reaches the save. mirror_list()
# puts the roll back on the saved copies index by index -- the order the caller
# iterated live nodes must match the order vanilla appended them. Returns how
# many rolls were copied.
static func mirror_list(live: Array, saved: Array) -> int:
	var n: int = mini(live.size(), saved.size())
	var done := 0
	for i in n:
		if mirror(live[i], saved[i]):
			done += 1
	return done
