extends SceneTree

const WeaponOcclusion = preload("res://mods/ThermalVTK/VTKWeaponOcclusion.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _init() -> void:
	process_frame.connect(_run)

func _run() -> void:
	t_stub_api_and_noop()
	t_scope_debug_fields()
	print("")
	if fails == 0:
		print("Weapon tests passed")
		quit(0)
	else:
		print("Weapon tests failed: ", fails)
		quit(1)

# 2.10.x diagnostic baseline: weapon occlusion is an explicit no-op stub.
# Main-pass patching and buffer occluders stay disabled/removed; callers and
# VTKScopeDebug rely only on the stable API and safe debug fields.
func t_stub_api_and_noop() -> void:
	var o = WeaponOcclusion.new()
	ck(o != null, "weapon occlusion constructs")
	ck(o.has_method("tick"), "tick exists")
	ck(o.has_method("set_scope_mode"), "set_scope_mode exists")
	ck(o.has_method("set_buffer_occlusion"), "set_buffer_occlusion exists")
	# No-op calls must be safe in any order/state.
	o.tick()
	o.set_scope_mode(true, false)
	o.set_scope_mode(false, true)
	o.set_scope_mode(true, true)
	o.set_scope_mode(false, false)
	o.set_buffer_occlusion(true, 1 << 19)
	o.set_buffer_occlusion(false, 1 << 19)
	o.tick()
	ck(int(o.get("_dbg_patched")) == 0, "stub reports no patched surfaces")
	ck(int(o.get("_dbg_layer_skip")) == 0, "stub reports no layer skips")

func t_scope_debug_fields() -> void:
	var o = WeaponOcclusion.new()
	# VTKScopeDebug reads these fields for diagnostics; keep them present/safe.
	ck("_mgr" in o, "stub exposes _mgr for scope debug")
	ck(o.get("_mgr") == null, "stub manager is null")
	ck("_dbg_patched" in o, "stub exposes _dbg_patched for scope debug")
	ck("_dbg_layer_skip" in o, "stub exposes _dbg_layer_skip for scope debug")
	ck(int(o.get("_dbg_patched")) == 0, "dbg_patched defaults to 0")
	ck(int(o.get("_dbg_layer_skip")) == 0, "dbg_layer_skip defaults to 0")
