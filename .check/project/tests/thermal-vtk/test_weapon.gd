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
	t_optics_are_never_touched()
	print("")
	if fails == 0:
		print("Weapon tests passed")
		quit(0)
	else:
		print("Weapon tests failed: ", fails)
		quit(1)

# Optics render exactly like the base game: the module is an explicit no-op.
# Callers and VTKScopeDebug rely only on the stable API and safe debug fields.
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

func _clear_rigs() -> void:
	for c in root.get_children():
		if c.name == "Map":
			c.free()

func _five_surface_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	verts.append(Vector3(-1.0, -1.0, 0.0))
	verts.append(Vector3(1.0, -1.0, 0.0))
	verts.append(Vector3(0.0, 1.0, 0.0))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	var m := ArrayMesh.new()
	for i in 5:
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

# Mirrors a real optic: Scope, Reticle, Mask, Objective, second Reticle.
func _optic_rig() -> MeshInstance3D:
	_clear_rigs()
	var map := Node.new()
	map.name = "Map"
	root.add_child(map)
	var core := Node.new()
	core.name = "Core"
	map.add_child(core)
	var cam := Node.new()
	cam.name = "Camera"
	core.add_child(cam)
	var mgr := Node.new()
	mgr.name = "Manager"
	cam.add_child(mgr)
	var att := Node3D.new()
	att.name = "Attachments"
	mgr.add_child(att)
	var mi := MeshInstance3D.new()
	mi.name = "Optic"
	mi.mesh = _five_surface_mesh()
	att.add_child(mi)
	var scope := ShaderMaterial.new()
	scope.shader = load("res://Shaders/Scope.gdshader") as Shader
	var reticle := ShaderMaterial.new()
	reticle.shader = load("res://Shaders/Reticle.gdshader") as Shader
	var mask := ShaderMaterial.new()
	mask.shader = load("res://Shaders/Mask.gdshader") as Shader
	var objective := ShaderMaterial.new()
	objective.shader = load("res://Shaders/Objective.gdshader") as Shader
	var reticle2 := ShaderMaterial.new()
	reticle2.shader = reticle.shader
	mi.set_surface_override_material(0, scope)
	mi.set_surface_override_material(1, reticle)
	mi.set_surface_override_material(2, mask)
	mi.set_surface_override_material(3, objective)
	mi.set_surface_override_material(4, reticle2)
	return mi

# The regression that started the whole chain: swapping the Mask, hiding the
# post-mask layers or rewriting the Objective lens made the sight show junk and
# broke the zoom with PIP on. No scope state may change a single material now.
func t_optics_are_never_touched() -> void:
	var mi := _optic_rig()
	var before: Array = []
	for i in 5:
		before.append(mi.get_surface_override_material(i))
	var o = WeaponOcclusion.new()
	o.tick()
	var states := [
		[true, false],
		[true, true],
		[false, true],
		[false, false],
	]
	var clean := true
	for s in states:
		o.set_scope_mode(bool(s[0]), bool(s[1]))
		for i in 5:
			if mi.get_surface_override_material(i) != before[i]:
				clean = false
	ck(clean, "no scope state replaces an optic material")
	var shaders := true
	for i in 5:
		var mat := mi.get_surface_override_material(i) as ShaderMaterial
		if mat == null or mat.shader == null:
			shaders = false
			continue
		if mat.shader.resource_path.find("res://Shaders/") == -1:
			shaders = false
	ck(shaders, "every optic surface still runs its vanilla shader")
