extends SceneTree

class SlotDataStub:
	var _meta := {}
	func meta_has(k: String) -> bool: return k in _meta
	func meta_get(k: String, def=null): return _meta.get(k, def)
	func meta_set(k: String, v) -> void: _meta[k] = v

const Sidecar = preload("res://mods/RoadToLoot/RTLSidecar.gd")

func _init() -> void:
	var sd := SlotDataStub.new()
	sd.meta_set("rtl_uid", "uid-from-meta")
	sd.meta_set("rtl_plate", 3)

	print("meta_has rtl_uid: ", sd.meta_has("rtl_uid"))
	print("meta_get rtl_uid: ", sd.meta_get("rtl_uid", "DEFAULT"))
	print("meta keys: ", sd._meta.keys())

	var uid_val = Sidecar.get_uid(sd)
	print("get_uid result: [", uid_val, "] uid_val=='':", uid_val == "")

	var d = Sidecar.read(sd)
	print("Sidecar.read result: ", d)
	print("d.get(uid,EMPTY): [", d.get("uid", "EMPTY"), "]")

	quit(0)
