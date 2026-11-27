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
# Going opaque also moves the body ahead of the transparent Mask depth barrier,
# so the copy discards fragments inside the Mask disk: that is the inner rim the
# barrier used to hide. The Mask, the Objective lens and the reticle keep their
# vanilla materials, and no visibility state is rewritten. Vanilla files are
# never edited: the copy lives only in ShaderMaterial overrides and is restored
# on reset.

const Paths = preload("res://mods/ThermalVTK/VTKPaths.gd")
const Dbg = preload("res://mods/ThermalVTK/VTKDebug.gd")

const SCOPE_SHADER := "res://Shaders/Scope.gdshader"
const MASK_SHADER := "res://Shaders/Mask.gdshader"
const ALPHA_LINE := "ALPHA = 1.0;"
const MASK_CENTER := "opticMaskCenter"
const MASK_RADIUS := "opticMaskRadius"
const RESWEEP_FRAMES := 90

# The opaque body is drawn before the transparent Mask depth barrier, so the
# barrier can no longer hide the inner rim. The Mask is a disk centred on the
# optic axis; discard body fragments inside that disk in model space. A
# screen-space projection would only clip one depth, while the inner wall of
# the tube spans most of the optic's length and every zoom level changes the
# projected radius. The two percent margin covers the disk's boundary.
const CLIP_DECL := "uniform vec3 opticMaskCenter;\nuniform float opticMaskRadius;\nvarying vec3 vOpticLocalPos;"
const CLIP_VERTEX := "\tvOpticLocalPos = VERTEX;"
const CLIP_FRAGMENT := "\tif (length(vOpticLocalPos.xy - opticMaskCenter.xy) < opticMaskRadius * 1.02) {\n\t\tdiscard;\n\t}"

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
		# Without the Mask geometry there is no disk to restore; leave the
		# surface alone rather than exposing its inner rim.
		var mask := _mask_geometry(mesh)
		if mask.is_empty():
			continue
		var patched := _scope_material(sm)
		if patched == null:
			continue
		patched.set_shader_parameter(MASK_CENTER, mask.get("center"))
		patched.set_shader_parameter(MASK_RADIUS, mask.get("radius"))
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
	var clipped := _add_mask_clip("\n".join(kept))
	if clipped.is_empty():
		Dbg.log("SCOPE", "scope shader changed; body stays transparent")
		return null
	var out := Shader.new()
	out.code = clipped
	_scope_shaders[rid_id] = out
	return out


func _mask_geometry(node: MeshInstance3D) -> Dictionary:
	if node == null or node.mesh == null:
		return {}
	var mesh := node.mesh
	for i in mesh.get_surface_count():
		var mat: Material = node.get_surface_override_material(i)
		if mat == null:
			mat = mesh.surface_get_material(i)
		if not (mat is ShaderMaterial):
			continue
		var sm := mat as ShaderMaterial
		if sm.shader == null or sm.shader.resource_path.find(MASK_SHADER) == -1:
			continue
		var arrays := mesh.surface_get_arrays(i)
		if not (arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array):
			continue
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if verts.is_empty():
			continue
		var lo := Vector3(1e9, 1e9, 1e9)
		var hi := Vector3(-1e9, -1e9, -1e9)
		for v in verts:
			lo.x = minf(lo.x, v.x)
			lo.y = minf(lo.y, v.y)
			lo.z = minf(lo.z, v.z)
			hi.x = maxf(hi.x, v.x)
			hi.y = maxf(hi.y, v.y)
			hi.z = maxf(hi.z, v.z)
		var center := (lo + hi) * 0.5
		var radius := 0.0
		for v in verts:
			radius = maxf(radius, Vector2(v.x - center.x, v.y - center.y).length())
		if radius <= 0.0:
			continue
		return {"center": center, "radius": radius}
	return {}


func _add_mask_clip(code: String) -> String:
	var lines := code.split("\n")
	var decl_at := -1
	var vertex_at := -1
	var fragment_at := -1
	for i in lines.size():
		var t := lines[i].strip_edges()
		if decl_at == -1 and t == "varying vec3 worldNormal;":
			decl_at = i
		elif vertex_at == -1 and t.begins_with("worldNormal = normalize("):
			vertex_at = i
		elif fragment_at == -1 and t.begins_with("void fragment()"):
			if t.ends_with("{"):
				fragment_at = i
			elif i + 1 < lines.size() and lines[i + 1].strip_edges() == "{":
				fragment_at = i + 1
	if decl_at == -1 or vertex_at == -1 or fragment_at == -1:
		return ""
	var decls := CLIP_DECL.split("\n")
	var vertex := CLIP_VERTEX.split("\n")
	var fragment := CLIP_FRAGMENT.split("\n")
	var out := PackedStringArray()
	for i in lines.size():
		out.append(lines[i])
		if i == decl_at:
			out.append_array(decls)
		elif i == vertex_at:
			out.append_array(vertex)
		elif i == fragment_at:
			out.append_array(fragment)
	return "\n".join(out)


# Kept for callers: the patch is state-independent, so scope state changes do
# nothing here.
func set_scope_mode(_scoped: bool, _pip: bool) -> void:
	pass


func set_buffer_occlusion(_enabled: bool, _layer_bit: int = 1 << 19) -> void:
	pass
