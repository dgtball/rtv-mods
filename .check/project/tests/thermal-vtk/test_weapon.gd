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
	t_mask_only_api_and_disabled_patching()
	t_scope_debug_fields()
	t_mask_depth_swap_when_scoped_without_pip()
	t_late_mask_material_is_picked_up_on_resweep()
	t_pip_mask_is_never_touched()
	t_reset_restores_and_allows_rediscovery()
	t_scope_reapply_repairs_overwritten_mask()
	t_objective_lens_leaves_palette_pass()
	t_objective_patched_on_discovery()
	t_multiple_masks_keep_reticle_between_them()
	t_reset_restores_objective_lens()
	t_dead_entries_are_pruned()
	print("")
	if fails == 0:
		print("Weapon tests passed")
		quit(0)
	else:
		print("Weapon tests failed: ", fails)
		quit(1)

# Weapon mesh patching and buffer occluders stay disabled: only the vanilla
# scope Mask depth barrier is swapped. With PIP off the main camera supplies the
# picture, so a depth-writing Mask hides our depth-tested ESP/mines inside the
# lens; the scoped, non-PIP state must use the depthless shader instead.
func t_mask_only_api_and_disabled_patching() -> void:
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
	ck(int(o.get("_dbg_patched")) == 0, "weapon surface patching stays disabled")
	ck(int(o.get("_dbg_layer_skip")) == 0, "buffer occluders stay disabled")

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


func _fixture_shader() -> Shader:
	var shader := load("res://Shaders/Mask.gdshader") as Shader
	ck(shader != null, "mask fixture shader loads")
	return shader


func _scope_fixture_shader() -> Shader:
	var shader := load("res://Shaders/Scope.gdshader") as Shader
	ck(shader != null, "scope fixture shader loads")
	return shader


func _manager_of(node: Node) -> Node:
	var n: Node = node.get_parent()
	while n != null:
		if n.name == "Manager":
			return n
		n = n.get_parent()
	return null


func _mask_rig(with_mask := true) -> MeshInstance3D:
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
	var rig := Node3D.new()
	rig.name = "Rig"
	mgr.add_child(rig)
	var att := Node3D.new()
	att.name = "Attachments"
	rig.add_child(att)
	var mask := MeshInstance3D.new()
	mask.name = "Mask"
	mask.layers = 2
	mask.mesh = QuadMesh.new()
	att.add_child(mask)
	if with_mask:
		var sm := ShaderMaterial.new()
		sm.shader = _fixture_shader()
		mask.set_surface_override_material(0, sm)
	return mask

func _mask_code(mask: MeshInstance3D) -> String:
	var mat := mask.get_surface_override_material(0) as ShaderMaterial
	if mat == null or mat.shader == null:
		return ""
	return mat.shader.code

func t_mask_depth_swap_when_scoped_without_pip() -> void:
	var mask := _mask_rig()
	var o = WeaponOcclusion.new()
	o.tick()
	var original := _mask_code(mask)
	ck("depth_draw_always" in original, "scope mask starts with the vanilla depth write")
	ck(o.get("_mgr") != null, "tick attaches to the camera manager without a current scene")
	o.set_scope_mode(true, false)
	var depthless := _mask_code(mask)
	ck("depth_draw_never" in depthless, "scoped without PIP disables the mask depth barrier")
	o.set_scope_mode(true, true)
	ck(_mask_code(mask) == original, "PIP restores the vanilla mask depth barrier")
	o.set_scope_mode(false, false)
	ck(_mask_code(mask) == original, "unscoped restores the vanilla mask depth barrier")
	ck(int(o.get("_dbg_patched")) == 0, "weapon surface patching stays disabled")
	ck(int(o.get("_dbg_layer_skip")) == 0, "attachment mask is not counted as a skipped weapon surface")


func t_late_mask_material_is_picked_up_on_resweep() -> void:
	_clear_rigs()
	var mask := _mask_rig(false)
	var o = WeaponOcclusion.new()
	o.set_scope_mode(true, false)
	o.tick()
	ck(o.get("_mgr") != null, "late-mask test attaches to the camera manager")
	var sm := ShaderMaterial.new()
	sm.shader = _fixture_shader()
	mask.set_surface_override_material(0, sm)
	o.set("_resweep_cd", 1)
	o.tick()
	ck("depth_draw_never" in _mask_code(mask), "a Mask material assigned after the first walk is swapped on resweep")


func t_pip_mask_is_never_touched() -> void:
	_clear_rigs()
	var mask := _mask_rig()
	var pip := Node3D.new()
	pip.name = "PIP"
	mask.get_parent().add_child(pip)
	mask.reparent(pip)
	var original := _mask_code(mask)
	var o = WeaponOcclusion.new()
	o.tick()
	o.set_scope_mode(true, false)
	ck(_mask_code(mask) == original, "a Mask under PIP keeps its vanilla depth write")


func t_reset_restores_and_allows_rediscovery() -> void:
	_clear_rigs()
	var mask := _mask_rig()
	var o = WeaponOcclusion.new()
	o.tick()
	o.set_scope_mode(true, false)
	ck("depth_draw_never" in _mask_code(mask), "manager-loss test sees the scoped depthless mask")
	var mgr := _manager_of(mask)
	var parent: Node = mgr.get_parent()
	parent.remove_child(mgr)
	o.tick()
	ck(not mask.has_meta("VTK_MASK"), "reset removes the marker so the mesh can be rediscovered")
	parent.add_child(mgr)
	o.tick()
	o.set_scope_mode(false, false)
	ck("depth_draw_always" in _mask_code(mask), "rediscovered mask returns to the vanilla depth barrier")


func t_scope_reapply_repairs_overwritten_mask() -> void:
	_clear_rigs()
	var mask := _mask_rig()
	var o = WeaponOcclusion.new()
	o.tick()
	o.set_scope_mode(true, false)
	ck("depth_draw_never" in _mask_code(mask), "mask starts depthless while scoped without PIP")
	# The live log caught one Mask surface back on the vanilla shader while the
	# scope state never changed. A state-change-only swap cannot repair that.
	var put_back := ShaderMaterial.new()
	put_back.shader = _fixture_shader()
	mask.set_surface_override_material(0, put_back)
	o.set_scope_mode(true, false)
	ck("depth_draw_never" in _mask_code(mask), "an overwritten mask is restored without a scope state change")

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
	scope.shader = _scope_fixture_shader()
	var reticle := ShaderMaterial.new()
	reticle.shader = load("res://Shaders/Reticle.gdshader") as Shader
	var mask := ShaderMaterial.new()
	mask.shader = _fixture_shader()
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


func _is_hidden(mat: Material) -> bool:
	return "ALPHA = 0.0" in _code_of(mat)


func _is_transparent_lens(mat: Material) -> bool:
	var code := _code_of(mat)
	return "ALPHA = 1.0" in code and "depth_draw_always" in code


func t_objective_lens_leaves_palette_pass() -> void:
	var mi := _optic_rig()
	var keep := mi.get_surface_override_material(1)
	var objective := mi.get_surface_override_material(3)
	var reticle2 := mi.get_surface_override_material(4)
	var o = WeaponOcclusion.new()
	o.tick()
	o.set_scope_mode(true, false)
	ck(mi.get_surface_override_material(1) == keep, "the main reticle before the mask stays visible")
	ck("depth_draw_never" in _code_of(mi.get_surface_override_material(2)), "mask stays depthless in the same state")
	var lens := mi.get_surface_override_material(3)
	ck(lens != objective, "objective lens gets its own runtime material")
	ck(_is_transparent_lens(lens), "objective writes alpha and keeps its depth write")
	ck(not _is_hidden(lens), "objective lens is not turned into a hole")
	ck(_is_hidden(mi.get_surface_override_material(4)), "second reticle behind the mask is hidden")
	o.set_scope_mode(true, true)
	ck(mi.get_surface_override_material(3) == lens, "PIP keeps the objective lens material")
	ck(mi.get_surface_override_material(4) == reticle2, "PIP restores the second reticle")
	o.set_scope_mode(false, false)
	ck(mi.get_surface_override_material(3) == lens, "unscoped keeps the objective lens material")
	ck(mi.get_surface_override_material(4) == reticle2, "unscoped restores the second reticle")


func t_objective_patched_on_discovery() -> void:
	var mi := _optic_rig()
	var objective := mi.get_surface_override_material(3)
	var o = WeaponOcclusion.new()
	o.tick()
	var lens := mi.get_surface_override_material(3)
	ck(lens != objective, "objective is patched as soon as the rig is discovered")
	ck(_is_transparent_lens(lens), "discovered objective is already outside the opaque pass")


func t_multiple_masks_keep_reticle_between_them() -> void:
	var mi := _optic_rig()
	# A second Mask surface before the reticle must not move the hidden range
	# onto the main reticle; only layers after the last Mask are extras.
	var front_mask := ShaderMaterial.new()
	front_mask.shader = _fixture_shader()
	mi.set_surface_override_material(0, front_mask)
	var keep := mi.get_surface_override_material(1)
	var o = WeaponOcclusion.new()
	o.tick()
	o.set_scope_mode(true, false)
	ck(mi.get_surface_override_material(1) == keep, "reticle between two masks stays visible")
	ck(_is_transparent_lens(mi.get_surface_override_material(3)), "objective after the last mask leaves the palette pass")
	ck(_is_hidden(mi.get_surface_override_material(4)), "last layer after two masks is hidden")


func t_reset_restores_objective_lens() -> void:
	var mi := _optic_rig()
	var objective := mi.get_surface_override_material(3)
	var o = WeaponOcclusion.new()
	o.tick()
	ck(mi.get_surface_override_material(3) != objective, "objective is patched before the manager disappears")
	var mgr := _manager_of(mi)
	var parent: Node = mgr.get_parent()
	parent.remove_child(mgr)
	o.tick()
	ck(mi.get_surface_override_material(3) == objective, "reset restores the vanilla objective material")


func t_dead_entries_are_pruned() -> void:
	_clear_rigs()
	var mask := _mask_rig()
	var o = WeaponOcclusion.new()
	o.tick()
	o.set_scope_mode(true, false)
	ck((o.get("_mask_entries") as Array).size() == 1, "one live Mask entry is tracked")
	mask.free()
	o.set_scope_mode(false, false)
	ck((o.get("_mask_entries") as Array).size() == 0, "freed Mask entries are pruned on scope change")
