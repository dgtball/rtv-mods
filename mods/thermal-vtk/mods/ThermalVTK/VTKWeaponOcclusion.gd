extends RefCounted
# One job only: move the sight body out of the transparent pipeline.
#
# `Scope.gdshader` already writes ALPHA = 1.0, so the optic body looks solid but
# is still a transparent material. Transparent materials never enter the opaque
# screen copy that the world palette samples, which is why ACOG/HMR/Vudu keep
# their vanilla colours while the gun and the hands are palettized. Dropping
# that single line makes the surface opaque: the look is unchanged, but the
# body now lands in the copy and the palette recolours it like everything else.
#
# Nothing else is touched. The Mask, the Objective lens, the reticle and the
# tube keep their vanilla materials, and no visibility state is rewritten.

const Paths = preload("res://mods/ThermalVTK/VTKPaths.gd")
const Dbg = preload("res://mods/ThermalVTK/VTKDebug.gd")

const SCOPE_SHADER := "res://Shaders/Scope.gdshader"
const ALPHA_LINE := "ALPHA = 1.0;"
const RESWEEP_FRAMES := 90

var _mgr: Node = null
var _connected: bool = false
var _scope_shaders: Dictionary = {}
var _entries: Array = []
var _resweep_cd: int = 0
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
		# A rig can receive its materials a moment after the mesh appears, so a
		# cheap resweep repairs surfaces the first walk saw untextured.
		_resweep_cd -= 1
		if _resweep_cd <= 0:
			_resweep_cd = RESWEEP_FRAMES
			for child in mgr.get_children():
				_walk(child, null)


func _reset() -> void:
	if _mgr != null and is_instance_valid(_mgr) and _mgr.child_entered_tree.is_connected(_on_child_added):
		_mgr.child_entered_tree.disconnect(_on_child_added)
	for e in _entries:
		var mesh = e.get("mesh")
		if mesh == null or not is_instance_valid(mesh):
			continue
		var idx: int = int(e.get("index"))
		if mesh.get_surface_override_material(idx) == e.get("patched"):
			mesh.set_surface_override_material(idx, e.get("orig"))
	_mgr = null
	_connected = false
	_scope_shaders.clear()
	_entries.clear()
	_dbg_patched = 0
	_resweep_cd = 0


func _on_child_added(node: Node) -> void:
	_walk.call_deferred(node, null)


func _walk(node: Node, att_node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	# A PIP display quad carries its own camera and picture; it must keep its
	# materials.
	if node.name == "PIP":
		return
	var next_att := att_node
	if "attachments" in node:
		var candidate = node.get("attachments")
		if candidate is Node:
			next_att = candidate
	if node is MeshInstance3D and _under_attachments(node, next_att):
		_patch_scope(node as MeshInstance3D)
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


func _patch_scope(mesh: MeshInstance3D) -> void:
	if mesh.mesh == null:
		return
	var count: int = mesh.mesh.get_surface_count()
	for i in count:
		var mat: Material = mesh.get_surface_override_material(i)
		if mat == null:
			mat = mesh.mesh.surface_get_material(i)
		if not (mat is ShaderMaterial):
			continue
		var sm := mat as ShaderMaterial
		if sm.shader == null or sm.shader.resource_path.find(SCOPE_SHADER) == -1:
			continue
		var patched := _scope_material(sm)
		if patched == null:
			continue
		mesh.set_surface_override_material(i, patched)
		_record(mesh, i, mat, patched)


func _record(mesh: MeshInstance3D, index: int, orig: Material, patched: Material) -> void:
	for e in _entries:
		if e.get("mesh") == mesh and int(e.get("index")) == index:
			e["orig"] = orig
			e["patched"] = patched
			return
	_entries.append({
		"mesh": mesh,
		"index": index,
		"orig": orig,
		"patched": patched,
	})
	_dbg_patched = _entries.size()


func _scope_material(src: ShaderMaterial) -> ShaderMaterial:
	var sh := _scope_shader(src.shader)
	if sh == null:
		return null
	var dup := src.duplicate() as ShaderMaterial
	dup.shader = sh
	return dup


func _scope_shader(src: Shader) -> Shader:
	if src == null:
		return null
	var rid_id: int = src.get_rid().get_id()
	if rid_id in _scope_shaders:
		return _scope_shaders[rid_id]
	var kept := PackedStringArray()
	var dropped := false
	for line in src.code.split("\n"):
		if line.strip_edges() == ALPHA_LINE:
			dropped = true
			continue
		kept.append(line)
	if not dropped:
		# The vanilla shader changed upstream: leave the sight alone rather than
		# feed Godot a copy we no longer understand.
		Dbg.log("SCOPE", "scope shader has no " + ALPHA_LINE + " line; body stays transparent")
		return null
	var out := Shader.new()
	out.code = "\n".join(kept)
	_scope_shaders[rid_id] = out
	return out


# Kept for callers: the patch is state-independent, so scope state changes do
# nothing here.
func set_scope_mode(_scoped: bool, _pip: bool) -> void:
	pass


func set_buffer_occlusion(_enabled: bool, _layer_bit: int = 1 << 19) -> void:
	pass
