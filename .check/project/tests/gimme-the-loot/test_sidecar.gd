extends SceneTree

const Sidecar = preload("res://mods/RoadToLoot/RTLSidecar.gd")
const Boot = preload("res://mods/RoadToLoot/RTLBoot.gd")

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

	# --- sidecar cache: repeated reads reuse the first snapshot ---
	var path := "user://roadtoloot_moddata.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"v": 3, "items": {}, "by_uid": {"u1": {"t": 2, "a": [], "file": "x"}}, "by_ft": {}}))
	f.close()
	var boot := Boot.new()
	var first: Dictionary = boot._sidecar_read()
	ck(first.get("by_uid", {}).has("u1"), "first sidecar read sees u1")
	var f2 := FileAccess.open(path, FileAccess.WRITE)
	f2.store_string(JSON.stringify({"v": 3, "items": {}, "by_uid": {"u2": {"t": 3, "a": [], "file": "y"}}, "by_ft": {}}))
	f2.close()
	var second: Dictionary = boot._sidecar_read()
	ck(second.get("by_uid", {}).has("u1") and not second.get("by_uid", {}).has("u2"),
		"cached sidecar read ignores a file change")
	boot.call("_sidecar_invalidate")
	var third: Dictionary = boot._sidecar_read()
	ck(third.get("by_uid", {}).has("u2"), "invalidate makes the next read see the file")

	# upsert пишет прямо в sidecar и обязан сбросить кэш, иначе новый лут
	# не увидит свои аффиксы в этой же сессии
	boot.call("_sidecar_upsert_uid", "u3", "z", 2, ["frost"])
	var after_upsert: Dictionary = boot._sidecar_read()
	ck(after_upsert.get("by_uid", {}).has("u3"),
		"upsert invalidates the cache so the new roll is visible")

	# кэш отдаётся копией: починки restore-путей не должны оседать в нём
	var shared: Dictionary = boot._sidecar_read()
	var shared_bu: Dictionary = shared.get("by_uid", {})
	shared_bu["ghost"] = {"t": 1, "a": [], "file": "g"}
	var unmutated: Dictionary = boot._sidecar_read()
	ck(not unmutated.get("by_uid", {}).has("ghost"),
		"cached sidecar is returned by value")

	# новая игра удаляет файл и обязана сбросить кэш
	boot.on_new_game(null, null)
	var after_reset: Dictionary = boot._sidecar_read()
	ck(after_reset.is_empty(), "new game clears both sidecar and its cache")

	# поведенческий тест не дотягивается до _sidecar_write: страховка на точки записи
	var boot_src := FileAccess.get_file_as_string("res://mods/RoadToLoot/RTLBoot.gd")
	ck(boot_src.split("_sidecar_invalidate()").size() - 1 >= 4,
		"every sidecar write path invalidates the cache")
	ck(not boot_src.contains("_sidecar_retry"), "five-retry chain is gone")
	ck(boot_src.count("call_deferred(\"_retry_sidecar_save\")") == 1,
		"exactly one deferred sidecar retry remains")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	print("")
	if fails > 0:
		print("FAILED: %d" % fails)
		quit(1)
	else:
		print("tests passed")
		quit(0)
