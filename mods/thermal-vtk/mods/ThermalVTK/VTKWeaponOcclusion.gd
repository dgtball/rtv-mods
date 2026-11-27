extends RefCounted
# Vanilla scope Mask depth barrier, and nothing else. Weapon mesh patching and
# ESP buffer occluders stay disabled: they used to force the whole gun into the
# transparent pass and were removed on purpose.
#
# The Mask shader writes depth with ALPHA = 0 so the scope picture can punch
# through the lens. With PIP off the main camera supplies that picture, and the
# depth write hides our depth-tested ESP/mine overlays inside the lens. In that
# state the surface is swapped to a depth_draw_never copy; PIP restores the
# vanilla barrier because the optic camera draws its own in-scope copy.

const Paths = preload("res://mods/ThermalVTK/VTKPaths.gd")

const MASK_SHADER := "res://Shaders/Mask.gdshader"
const RESWEEP_FRAMES := 90

var _mgr: Node = null
var _connected: bool = false
var _mask_shaders: Dictionary = {}
var _mask_entries: Array = []
var _scope_scoped: bool = false
var _scope_pip: bool = false
var _scope_ready: bool = false
var _resweep_cd: int = 0
# Kept for VTKScopeDebug; weapon patching is off, so both stay at zero.
var _dbg_patched: int = 0
var _dbg_layer_skip: int = 0


func tick() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var scene = tree.current_scene
	if scene != null and scene.name == "Menu":
		return
	var mgr := tree.root.get_node_or_null(Paths.CAMERA_MANAGER) as Node
	if mgr == null:
		if _mgr != null:
			_reset()
		return
	if _mgr != mgr:
		_reset()
		_mgr = mgr
		_connected = true
		if not mgr.child_entered_tree.is_connected(_on_child_added):
			mgr.child_entered_tree.connect(_on_child_added)
		for child in mgr.get_children():
			_walk(child, null)
	elif _connected:
		_resweep_cd -= 1
		if _resweep_cd <= 0:
			_resweep_cd = RESWEEP_FRAMES
			for child in mgr.get_children():
				_walk(child, null)


func _reset() -> void:
	if _mgr != null and is_instance_valid(_mgr) and _mgr.child_entered_tree.is_connected(_on_child_added):
		_mgr.child_entered_tree.disconnect(_on_child_added)
	for e in _mask_entries:
		var mesh = e.get("mesh")
		if mesh == null or not is_instance_valid(mesh):
			continue
		var idx: int = int(e.get("index"))
		if mesh.get_surface_override_material(idx) == e.get("depthless"):
			mesh.set_surface_override_material(idx, e.get("orig"))
		mesh.remove_meta("VTK_MASK")
	_mgr = null
	_connected = false
	_mask_shaders.clear()
	_mask_entries.clear()
	_scope_ready = false
	_resweep_cd = 0


func _on_child_added(node: Node) -> void:
	_walk.call_deferred(node, null)


func _walk(node: Node, att_node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	# A PIP display quad carries its own camera and picture; it must keep its
	# materials and must not receive the main-camera depth swap.
	if node.name == "PIP":
		return
	var next_att := att_node
	if "attachments" in node:
		var candidate = node.get("attachments")
		if candidate is Node:
			next_att = candidate
	if node is MeshInstance3D and _under_attachments(node, next_att):
		_patch_mask(node as MeshInstance3D)
	for c in node.get_children():
		_walk(c, next_att)


func _under_attachments(node: Node, att_node: Node) -> bool:
	var n: Node = node
	while n != null:
		if n.name == "PIP":
			return false
		if (att_node != null and n == att_node) or n.name == "Attachments":
			return true
		n = n.get_parent()
	return false


func _patch_mask(mesh: MeshInstance3D) -> void:
	if mesh.has_meta("VTK_MASK"):
		return
	if mesh.mesh == null:
		return
	var matched := false
	var count: int = mesh.mesh.get_surface_count()
	for i in count:
		var mat: Material = mesh.get_surface_override_material(i)
		if mat == null:
			mat = mesh.mesh.surface_get_material(i)
		if not (mat is ShaderMaterial):
			continue
		var sm := mat as ShaderMaterial
		if sm.shader == null or sm.shader.resource_path.find(MASK_SHADER) == -1:
			continue
		var dup := sm.duplicate() as ShaderMaterial
		dup.shader = _mask_shader(sm.shader)
		_mask_entries.append({
			"mesh": mesh,
			"index": i,
			"orig": mat,
			"depthless": dup,
		})
		matched = true
		# Discovery can happen after the scope is already up; `_reset` clears
		# `_scope_ready`, so use the flags themselves, not the received-state flag.
		if _scope_scoped and not _scope_pip:
			mesh.set_surface_override_material(i, dup)
	# Mark only meshes that really carry the vanilla Mask shader: an empty rig
	# may receive its material later, and the periodic resweep must still see it.
	if matched:
		mesh.set_meta("VTK_MASK", true)


func _mask_shader(src: Shader) -> Shader:
	if src == null:
		return null
	var rid_id: int = src.get_rid().get_id()
	if rid_id in _mask_shaders:
		return _mask_shaders[rid_id]
	var out := Shader.new()
	out.code = src.code.replace("depth_draw_always", "depth_draw_never")
	_mask_shaders[rid_id] = out
	return out


func set_scope_mode(scoped: bool, pip: bool) -> void:
	var live: Array = []
	for e in _mask_entries:
		var mesh = e.get("mesh")
		if mesh != null and is_instance_valid(mesh):
			live.append(e)
	_mask_entries = live
	# Reapply on every call, not only when the flags change. A live run caught a
	# Mask surface back on the vanilla shader while scoped stayed true; one
	# depth-writing surface is enough to erase depth-tested contours in the lens.
	_scope_ready = true
	_scope_scoped = scoped
	_scope_pip = pip
	var depthless := scoped and not pip
	for e in _mask_entries:
		var mesh = e.get("mesh")
		if mesh == null or not is_instance_valid(mesh):
			continue
		var mat: Material = e.get("depthless") if depthless else e.get("orig")
		var idx: int = int(e.get("index"))
		if mesh.get_surface_override_material(idx) != mat:
			mesh.set_surface_override_material(idx, mat)


func set_buffer_occlusion(_enabled: bool, _layer_bit: int = 1 << 19) -> void:
	pass
