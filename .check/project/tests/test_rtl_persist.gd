extends SceneTree

const Store = preload("res://mods/RoadToLoot/RTLStore.gd")
const Sidecar = preload("res://mods/RoadToLoot/RTLSidecar.gd")
const ProbeSlot = preload("res://tests/rtl_probe_slot.gd")
const ProbeSave = preload("res://tests/rtl_probe_save.gd")

const PATH := "user://rtl_persist_probe.tres"

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _init() -> void:
	var live = ProbeSlot.new()
	live.itemData = "AKM"
	live.condition = 88
	Store.stamp(live, 3, [
		{"stat": "damage", "unit": "pct", "value": 0.2},
		{"stat": "recoil", "unit": "pct", "value": 0.1},
	])
	Sidecar.set_uid(live, "AKM|1717000000|424242")
	Sidecar.set_plate(live, 2)

	# --- vanilla SaveCharacter: a fresh SlotData filled through Update() ---
	var saved = ProbeSlot.new()
	saved.Update(live)
	ck(Store.tier(saved) == 0, "Update() on its own loses the roll")
	Store.mirror(live, saved)
	ck(Store.tier(saved) == 3, "mirroring fills the copy that gets written")
	ck(Store.affixes(saved).size() == 2, "mirroring fills the affixes too")

	# --- write it the way the game writes Character.tres ---
	var save = ProbeSave.new()
	save.inventory.append(saved)
	var err: int = ResourceSaver.save(save, PATH)
	ck(err == OK, "save file written")

	var back = ResourceLoader.load(PATH)
	ck(back != null, "save file loads")
	if back == null:
		_finish()
		return

	var raw = back.get("inventory")
	ck(raw is Array, "save carries an inventory array")
	var items: Array = raw if raw is Array else []
	ck(items.size() == 1, "one item in the save")
	if items.is_empty():
		_finish()
		return

	var loaded = items[0]
	ck(str(loaded.itemData) == "AKM", "vanilla fields survive the round trip")
	ck(Store.tier(loaded) == 3, "tier survives the round trip")
	ck(Store.affixes(loaded).size() == 2, "affixes survive the round trip")
	ck(str(Store.affixes(loaded)[0].get("stat", "")) == "damage", "affix payload survives the round trip")
	ck(Sidecar.get_uid(loaded) == "AKM|1717000000|424242", "uid survives the round trip")
	ck(Sidecar.get_plate(loaded) == 2, "plate survives the round trip")

	# --- vanilla LoadCharacter: fresh SlotData + Update() on the live item ---
	var shown = ProbeSlot.new()
	shown.Update(loaded)
	ck(Store.tier(shown) == 0, "Update() on load loses the roll as well")
	Store.mirror(loaded, shown)
	ck(Store.tier(shown) == 3, "mirroring restores the roll on load")
	ck(Store.affixes(shown).size() == 2, "mirroring restores the affixes on load")

	# --- a second save/load pass keeps one unchanged roll ---
	var again = ProbeSlot.new()
	again.Update(shown)
	Store.mirror(shown, again)
	ck(Store.tier(again) == 3, "re-saving keeps the tier")
	ck(Store.affixes(again).size() == 2, "re-saving keeps the affix count")
	ck(Sidecar.get_uid(again) == "AKM|1717000000|424242", "re-saving keeps the uid")

	# --- an item that never rolled stays unrolled ---
	var plain = ProbeSlot.new()
	plain.itemData = "Bandage"
	var plain_saved = ProbeSlot.new()
	plain_saved.Update(plain)
	ck(not Store.mirror(plain, plain_saved), "an unrolled item copies nothing")
	ck(Store.tier(plain_saved) == 0, "an unrolled item stays unrolled")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	_finish()

func _finish() -> void:
	print("")
	if fails > 0:
		print("FAILED: %d" % fails)
		quit(1)
	else:
		print("tests passed")
		quit(0)
