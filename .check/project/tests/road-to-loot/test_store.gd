extends SceneTree

const Sidecar = preload("res://mods/RoadToLoot/RTLSidecar.gd")
const Store = preload("res://mods/RoadToLoot/RTLStore.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _init() -> void:
	# --- defaults on a slot that never rolled ---
	var empty := Object.new()
	ck(Store.tier(empty) == 0, "tier defaults to 0")
	ck(Store.affixes(empty).is_empty(), "affixes default to empty")
	ck(not Store.has_tier(empty), "has_tier false without a roll")
	ck(Store.tier(null) == 0, "tier(null) is 0")
	ck(Store.affixes(null).is_empty(), "affixes(null) is empty")

	# --- stamp writes tier + affixes ---
	var sd := Object.new()
	Store.stamp(sd, 2, [{"stat": "damage", "unit": "pct", "value": 0.15}])
	ck(Store.tier(sd) == 2, "stamp stores tier")
	ck(Store.has_tier(sd), "has_tier true after stamp")
	ck(Store.affixes(sd).size() == 1, "stamp stores affixes")
	ck(str(Store.affixes(sd)[0].get("stat", "")) == "damage", "affix payload preserved")

	# --- affixes() hands out a copy, not the live array ---
	var copy: Array = Store.affixes(sd)
	copy.clear()
	ck(Store.affixes(sd).size() == 1, "affixes returns a copy")

	# --- stamp tolerates a null slot ---
	Store.stamp(null, 1, [])
	ck(true, "stamp(null) does not crash")

	# --- clear wipes both the roll and the identity ---
	var cl := Object.new()
	Store.stamp(cl, 3, [{"stat": "recoil"}])
	Sidecar.set_uid(cl, "to-be-cleared")
	Sidecar.set_plate(cl, 9)
	Store.clear(cl)
	ck(Store.tier(cl) == 0, "clear removes the tier")
	ck(Sidecar.get_uid(cl) == "", "clear removes the uid")
	ck(Sidecar.get_plate(cl) == 0, "clear removes the plate")

	# --- mirror: the whole point of the save fix ---
	var src := Object.new()
	Store.stamp(src, 3, [{"stat": "damage", "unit": "pct", "value": 0.2}])
	Sidecar.set_uid(src, "AKM|1|2")
	Sidecar.set_plate(src, 4)
	var dst := Object.new()
	ck(Store.mirror(src, dst), "mirror reports a roll was copied")
	ck(Store.tier(dst) == 3, "mirror copies the tier")
	ck(Store.affixes(dst).size() == 1, "mirror copies the affixes")
	ck(Sidecar.get_uid(dst) == "AKM|1|2", "mirror copies the uid")
	ck(Sidecar.get_plate(dst) == 4, "mirror copies the plate")

	# --- mirror leaves an unrolled source alone ---
	var plain := Object.new()
	var plain_dst := Object.new()
	ck(not Store.mirror(plain, plain_dst), "mirror returns false without a roll")
	ck(Store.tier(plain_dst) == 0, "mirror does not invent a roll")
	ck(not Store.mirror(null, plain_dst), "mirror(null, dst) returns false")
	ck(not Store.mirror(src, null), "mirror(src, null) returns false")

	# --- mirror over a target that already rolled keeps the source roll ---
	var overwritten := Object.new()
	Store.stamp(overwritten, 1, [])
	Store.mirror(src, overwritten)
	ck(Store.tier(overwritten) == 3, "mirror overwrites a stale tier")

	# --- mirror_list: the shape SaveCharacter actually needs ---
	var live_a := Object.new()
	Store.stamp(live_a, 3, [{"stat": "damage"}])
	var live_b := Object.new()
	var live_c := Object.new()
	Store.stamp(live_c, 2, [{"stat": "regen"}])
	var saved_a := Object.new()
	var saved_b := Object.new()
	var saved_c := Object.new()
	ck(Store.mirror_list([live_a, live_b, live_c], [saved_a, saved_b, saved_c]) == 2, "mirror_list reports two rolls")
	ck(Store.tier(saved_a) == 3, "mirror_list copies the first roll")
	ck(Store.tier(saved_b) == 0, "mirror_list leaves an unrolled item unrolled")
	ck(Store.tier(saved_c) == 2, "mirror_list copies a later roll")
	ck(Store.mirror_list([], []) == 0, "mirror_list on empty lists is a no-op")
	ck(Store.mirror_list([live_a], []) == 0, "mirror_list tolerates a shorter saved list")
	ck(Store.mirror_list([], [saved_a]) == 0, "mirror_list tolerates a shorter live list")
	var null_kept := Object.new()
	ck(Store.mirror_list([null], [null_kept]) == 0, "mirror_list skips a null live entry")

	# --- adopt fills an empty target from a copy ---
	var fresh := Object.new()
	ck(Store.adopt(fresh, src), "adopt fills an empty target")
	ck(Store.tier(fresh) == 3, "adopt copies the tier")
	ck(Sidecar.get_uid(fresh) == "AKM|1|2", "adopt copies the uid")

	# --- adopt never overwrites a roll the target already has ---
	var kept := Object.new()
	Store.stamp(kept, 2, [{"stat": "regen"}])
	Sidecar.set_uid(kept, "own-uid")
	ck(Store.adopt(kept, src), "adopt reports a roll on the target")
	ck(Store.tier(kept) == 2, "adopt keeps the target tier")
	ck(str(Store.affixes(kept)[0].get("stat", "")) == "regen", "adopt keeps the target affixes")
	ck(Sidecar.get_uid(kept) == "own-uid", "adopt keeps the target uid")

	# --- adopt without a source roll ---
	var nothing := Object.new()
	ck(not Store.adopt(nothing, plain), "adopt returns false without a source roll")
	ck(not Store.adopt(null, src), "adopt(null, src) returns false")
	ck(Store.adopt(fresh, null), "adopt on an already-rolled target works with no source")

	print("")
	if fails > 0:
		print("FAILED: %d" % fails)
		quit(1)
	else:
		print("tests passed")
		quit(0)
