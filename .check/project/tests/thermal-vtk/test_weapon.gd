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
	t_api_is_safe()
	t_scope_debug_fields()
	t_scope_body_leaves_transparent_pass()
	t_other_optic_surfaces_keep_vanilla_materials()
	t_patch_restores_on_reset()
	t_resweep_repairs_a_reassigned_material()
	t_shader_without_alpha_is_left_alone()
	t_scope_body_receives_mask_clip_geometry()
	t_scope_shader_clips_inside_the_mask_disk()
	print("")
	if fails == 0:
		print("Weapon tests passed")
		quit(0)
	else:
		print("Weapon tests failed: ", fails)
		quit(1)

# Callers and VTKScopeDebug rely only on the stable API and safe debug fields.
func t_api_is_safe() -> void:
	var o = WeaponOcclusion.new()
	ck(o != null, "weapon occlusion constructs")
	ck(o.has_method("tick"), "tick exists")
	ck(o.has_method("set_scope_mode"), "set_scope_mode exists")
	ck(o.has_method("set_buffer_occlusion"), "set_buffer_occlusion exists")
	# Calls must be safe in any order/state.
	o.tick()
	o.set_scope_mode(true, false)
	o.set_scope_mode(false, true)
	o.set_scope_mode(true, true)
	o.set_scope_mode(false, false)
	o.set_buffer_occlusion(true, 1 << 19)
	o.set_buffer_occlusion(false, 1 << 19)
	o.tick()
	ck(int(o.get("_dbg_patched")) == 0, "no rig means no patched surfaces")
	ck(int(o.get("_dbg_layer_skip")) == 0, "buffer occluders stay disabled")

func t_scope_debug_fields() -> void:
	var o = WeaponOcclusion.new()
	# VTKScopeDebug reads these fields for diagnostics; keep them present/safe.
	ck("_mgr" in o, "exposes _mgr for scope debug")
	ck(o.get("_mgr") == null, "manager is null before the first tick")
	ck("_dbg_patched" in o, "exposes _dbg_patched for scope debug")
	ck("_dbg_layer_skip" in o, "exposes _dbg_layer_skip for scope debug")
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

func _mask_clip_mesh() -> ArrayMesh:
	var scope := PackedVector3Array()
	scope.append(Vector3(0.0, 0.05, -0.05))
	scope.append(Vector3(0.0433, -0.025, -0.05))
	scope.append(Vector3(-0.0433, -0.025, -0.05))
	var mask := PackedVector3Array()
	mask.append(Vector3(0.02, 0.0, -0.1))
	mask.append(Vector3(0.0, 0.02, -0.1))
	mask.append(Vector3(0.0, -0.02, -0.1))
	mask.append(Vector3(0.0, -0.02, -0.1))
	mask.append(Vector3(0.0, 0.02, -0.1))
	mask.append(Vector3(-0.02, 0.0, -0.1))
	var other := PackedVector3Array()
	other.append(Vector3(-1.0, -1.0, 0.0))
	other.append(Vector3(1.0, -1.0, 0.0))
	other.append(Vector3(0.0, 1.0, 0.0))
	var m := ArrayMesh.new()
	for arr in [scope, other, mask, other, other]:
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = arr
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return m

# Mirrors a real optic: Scope, Reticle, Mask, Objective, second Reticle.
func _optic_rig(mesh: Mesh = null) -> MeshInstance3D:
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
	mi.mesh = mesh if mesh != null else _five_surface_mesh()
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

func _code_of(mat: Material) -> String:
	if mat == null or not (mat is ShaderMaterial):
		return ""
	var sm := mat as ShaderMaterial
	if sm.shader == null:
		return ""
	return sm.shader.code

# The sight body is the only surface that changes: it must leave the
# transparent pipeline (no ALPHA write) while keeping its depth write, because
# that is what puts it into the opaque copy the palette samples.
func t_scope_body_leaves_transparent_pass() -> void:
	var mi := _optic_rig()
	var vanilla := mi.get_surface_override_material(0)
	var o = WeaponOcclusion.new()
	o.tick()
	var body := mi.get_surface_override_material(0)
	ck(body != vanilla, "scope body gets its own runtime material")
	ck("ALPHA = 1.0;" not in _code_of(body), "scope body no longer writes alpha")
	ck("depth_draw_always" in _code_of(body), "scope body keeps its depth write")
	ck(int(o.get("_dbg_patched")) == 1, "one surface reported as patched")

func t_other_optic_surfaces_keep_vanilla_materials() -> void:
	var mi := _optic_rig()
	var before: Array = []
	for i in range(1, 5):
		before.append(mi.get_surface_override_material(i))
	var o = WeaponOcclusion.new()
	o.tick()
	o.set_scope_mode(true, false)
	var same := true
	for i in range(1, 5):
		if mi.get_surface_override_material(i) != before[i - 1]:
			same = false
	ck(same, "reticle, mask, objective and tube keep their vanilla materials")
	ck("ALPHA" in _code_of(mi.get_surface_override_material(1)), "the reticle stays transparent")

func t_patch_restores_on_reset() -> void:
	var mi := _optic_rig()
	var vanilla := mi.get_surface_override_material(0)
	var o = WeaponOcclusion.new()
	o.tick()
	ck(mi.get_surface_override_material(0) != vanilla, "body is patched while the rig lives")
	var mgr := _manager_of(mi)
	var parent: Node = mgr.get_parent()
	parent.remove_child(mgr)
	o.tick()
	ck(mi.get_surface_override_material(0) == vanilla, "manager loss restores the vanilla body")
	ck(int(o.get("_dbg_patched")) == 0, "restored rig reports no patched surfaces")

func t_resweep_repairs_a_reassigned_material() -> void:
	var mi := _optic_rig()
	var vanilla := mi.get_surface_override_material(0)
	var o = WeaponOcclusion.new()
	o.tick()
	# Vanilla optics can put its own material back when the sight is rebuilt.
	mi.set_surface_override_material(0, vanilla)
	for i in 95:
		o.tick()
	ck(mi.get_surface_override_material(0) != vanilla, "resweep patches a reassigned body again")

func t_shader_without_alpha_is_left_alone() -> void:
	var src := Shader.new()
	src.code = "shader_type spatial;\nvoid fragment() {\n\tALBEDO = vec3(1.0);\n}\n"
	var o = WeaponOcclusion.new()
	ck(o._scope_shader(src) == null, "a shader without the alpha line is never rewritten")

# The opaque body must still be clipped by the Mask disk, exactly as the
# transparent body was clipped by the Mask depth barrier before 2.10.50.
func t_scope_body_receives_mask_clip_geometry() -> void:
	var mi := _optic_rig(_mask_clip_mesh())
	var o = WeaponOcclusion.new()
	o.tick()
	var body := mi.get_surface_override_material(0)
	var center = body.get_shader_parameter("opticMaskCenter")
	var radius = body.get_shader_parameter("opticMaskRadius")
	ck(center is Vector3, "mask centre is published to the body material")
	ck(radius is float, "mask radius is published to the body material")
	if center is Vector3:
		ck((center as Vector3).distance_to(Vector3(0.0, 0.0, -0.1)) < 0.0001, "mask centre matches the fixture")
	if radius is float:
		ck(absf(float(radius) - 0.02) < 0.0001, "mask radius matches the fixture")

func t_scope_shader_clips_inside_the_mask_disk() -> void:
	var mi := _optic_rig(_mask_clip_mesh())
	var o = WeaponOcclusion.new()
	o.tick()
	var code := _code_of(mi.get_surface_override_material(0))
	ck("POSITION" in code, "clip uses the local vertex position")
	ck("discard" in code, "clip discards fragments inside the lens")
	ck("opticMaskRadius" in code, "clip radius comes from the mask geometry")
	ck("SCREEN_UV" not in code, "clip does not depend on the projection or zoom")

func _manager_of(node: Node) -> Node:
	var n: Node = node.get_parent()
	while n != null:
		if n.name == "Manager":
			return n
		n = n.get_parent()
	return null
