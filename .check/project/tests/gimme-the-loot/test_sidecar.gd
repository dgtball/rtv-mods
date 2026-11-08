extends SceneTree

const Sidecar = preload("res://mods/RoadToLoot/RTLSidecar.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _init() -> void:
	# --- basic storage: Object has native get_meta/set_meta ---
	var sd := Object.new()
	Sidecar.set_uid(sd, "item-uid-123")
	Sidecar.set_plate(sd, 5)
	ck(Sidecar.get_uid(sd) == "item-uid-123", "get_uid after set")
	ck(Sidecar.get_plate(sd) == 5, "get_plate after set")

	# --- empty state (fresh Object) ---
	var sd2 := Object.new()
	ck(Sidecar.get_uid(sd2) == "", "uid defaults to empty string")
	ck(Sidecar.get_plate(sd2) == 0, "plate defaults to 0")

	# --- clear_slot ---
	Sidecar.clear_slot(sd)
	ck(Sidecar.get_uid(sd) == "", "uid cleared")
	ck(Sidecar.get_plate(sd) == 0, "plate cleared")

	# --- read() returns populated dict ---
	sd2.set_meta("rtl_uid", "uid-from-meta")
	sd2.set_meta("rtl_plate", 3)
	var sd2_dict: Dictionary = Sidecar.read(sd2)
	ck(sd2_dict is Dictionary, "read returns Dictionary")
	ck(sd2_dict.get("uid", "") == "uid-from-meta", "read uid from meta")
	ck(sd2_dict.get("plate", 0) == 3, "read plate from meta")

	# --- empty slot ---
	var sd3 := Object.new()
	var empty_dict: Dictionary = Sidecar.read(sd3)
	ck(empty_dict.get("uid", "") == "", "read empty slot: uid=''")
	ck(empty_dict.get("plate", 0) == 0, "read empty slot: plate=0")

	# --- populate from dict ---
	var sd4 := Object.new()
	Sidecar.populate(sd4, {"uid": "populated-uid", "plate": 7})
	ck(Sidecar.get_uid(sd4) == "populated-uid", "populate sets uid")
	ck(Sidecar.get_plate(sd4) == 7, "populate sets plate")

	# --- populate overwrites previous ---
	Sidecar.populate(sd4, {"uid": "new-uid", "plate": 99})
	ck(Sidecar.get_uid(sd4) == "new-uid", "populate overwrites uid")
	ck(Sidecar.get_plate(sd4) == 99, "populate overwrites plate")

	# --- populate ignores unknown keys ---
	Sidecar.populate(sd4, {"unknown_key": 123, "uid": "only-uid"})
	ck(Sidecar.get_uid(sd4) == "only-uid", "populate ignores unknown keys")
	ck(Sidecar.get_plate(sd4) == 99, "populate keeps old plate for unknown key")

	# --- set_uid/set_plate no-op on null ---
	Sidecar.set_uid(null, "x")
	Sidecar.set_plate(null, 1)
	ck(true, "set_uid/set_plate no-op on null (no crash)")

	# --- read on null ---
	var null_dict: Dictionary = Sidecar.read(null)
	ck(null_dict.get("uid", "") == "", "read(null) returns uid=''")
	ck(null_dict.get("plate", 0) == 0, "read(null) returns plate=0")

	print("")
	if fails > 0:
		print("FAILED: %d" % fails)
		quit(1)
	else:
		print("tests passed")
		quit(0)
