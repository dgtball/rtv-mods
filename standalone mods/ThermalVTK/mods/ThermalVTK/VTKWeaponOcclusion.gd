extends RefCounted
# Weapon overlay-occlusion, ported from NPCESP. The outline overlays output
# ALPHA, so Godot sorts them into the transparent pass; the weapon's original
# materials are opaque and draw first, letting outlines paint over the gun.
# Fix: patch each weapon material to output ALPHA = 1.0 (moves it into the
# transparent pass) and depth_draw_always (keeps self-occlusion), then give it a
# render_priority ABOVE the outlines (30 vs 20/21) so it draws last.
#
# The rig's "Attachments" subtree (sights, lasers) keeps its own alpha and
# priorities: forcing ALPHA = 1.0 on its alpha-masked surfaces turns the
# ocular into an opaque black disc painted over the scope picture. There is
# one change though (1.11.4): the optic surface shaders (Scope/Mask/Objective/
# Reticle/Alpha) render with depth_draw_always, and their near-plane depth
# writes poison the transparent pass for every depth-tested overlay - the
# green nomad marker above a bot's head failed its test across the whole
# scope picture. Those shaders get depth_draw_always -> depth_draw_never
# (token swap only: no blend, no ALPHA, no priority). Other Attachments
# shaders (the laser beam) and everything outside Attachments are untouched.
# Rings need no patch there: their shader compares against the depth texture
# with depth_test_disabled, so the ring survives and follows the scope-driven
# draw order (over the glass while aiming, under it otherwise).
#
# Driven once per frame by VTKESP while the contour ESP is active.

const Dbg = preload("res://mods/ThermalVTK/VTKDebug.gd")
const Paths = preload("res://mods/ThermalVTK/VTKPaths.gd")

var _last_scene_id: int = 0
var _connected: bool = false
var _mgr: Node = null
var _patched_shaders: Dictionary = {}
var _patched_base: Dictionary = {}
var _depth_patched: Dictionary = {}
# Optic surface shaders under Attachments: the ones whose depth_draw_always
# writes near-plane depth into the transparent pass (see module header).
const OPTIC_SHADERS := ["Scope.gdshader", "Mask.gdshader", "Objective.gdshader", "Reticle.gdshader", "Alpha.gdshader"]
var _dbg_patched: int = 0
var _dbg_layer_skip: int = 0
var _missing_logged: bool = false

func tick() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var scene = tree.current_scene
	if scene == null:
		return
	var sid: int = scene.get_instance_id()
	if sid != _last_scene_id:
		# Scene changed: full reset, then fall through to attempt setup.
		_last_scene_id = sid
		_connected = false
		_mgr = null
		_patched_shaders.clear()
		_patched_base.clear()
		_dbg_patched = 0
		_dbg_layer_skip = 0
		_missing_logged = false
	elif _connected:
		return
	if scene.name != "Menu":
		_setup()

func _setup() -> void:
	if _connected:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var mgr: Node = tree.root.get_node_or_null(Paths.CAMERA_MANAGER)
	if mgr == null:
		if not _missing_logged:
			_missing_logged = true
			Dbg.log("WEAPON", "occlusion: no player camera manager found")
		return
	_mgr = mgr
	mgr.child_entered_tree.connect(_on_child_added)
	_connected = true
	for child in mgr.get_children():
		_patch_rig(child)
	Dbg.log("WEAPON", "occlusion attached rigs=%d patched=%d layer_skipped=%d" % [mgr.get_child_count(), _dbg_patched, _dbg_layer_skip])

func _on_child_added(node: Node) -> void:
	_patch_rig.call_deferred(node)

func _patch_rig(rig: Node) -> void:
	if rig == null or not is_instance_valid(rig):
		return
	_patch_node(rig)

func _patch_node(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node is MeshInstance3D:
		_patch_mesh(node as MeshInstance3D)
	for child in node.get_children():
		_patch_node(child)

func _patch_mesh(mesh: MeshInstance3D) -> void:
	if mesh.mesh == null:
		return
	if (mesh.layers & 2) == 0:
		_dbg_layer_skip += 1
		return
	if _under_attachments(mesh):
		_patch_depth_never(mesh)
		return
	var count: int = mesh.mesh.get_surface_count()
	for i in count:
		var mat: Material = mesh.get_surface_override_material(i)
		if mat == null:
			mat = mesh.mesh.surface_get_material(i)
		if mat == null:
			continue
		if _skip(mesh, mat):
			continue
		if mat is ShaderMaterial:
			var sm: ShaderMaterial = mat as ShaderMaterial
			var new_mat: ShaderMaterial = sm.duplicate() as ShaderMaterial
			new_mat.shader = _patch_shader(sm.shader)
			new_mat.render_priority = 30
			mesh.set_surface_override_material(i, new_mat)
		elif mat is BaseMaterial3D:
			mesh.set_surface_override_material(i, _patch_base(mat as BaseMaterial3D))
		else:
			var new_mat: Material = mat.duplicate()
			new_mat.render_priority = 30
			mesh.set_surface_override_material(i, new_mat)
	_dbg_patched += count

func _skip(mesh: MeshInstance3D, mat: Material) -> bool:
	var node: Node = mesh
	while node != null:
		if "PIP" in node:
			return true
		# Sights and lasers keep their vanilla materials: their alpha masks
		# shape the scope picture, and patching them paints an opaque disc
		# over it.
		if node.name == "Attachments":
			return true
		node = node.get_parent()
	if mat is ShaderMaterial:
		var sm: ShaderMaterial = mat as ShaderMaterial
		if sm.shader != null:
			var sp: int = sm.shader.resource_path.find("PIP.gdshader")
			if sp != -1:
				return true
	return false

# True iff the mesh sits under an "Attachments" node WITHOUT a "PIP" node
# above it (a PIP display quad inside an assembly must not get the depth
# swap - the plain skip keeps it untouched).
func _under_attachments(mesh: MeshInstance3D) -> bool:
	var node: Node = mesh
	var att := false
	while node != null:
		if "PIP" in node:
			return false
		if node.name == "Attachments":
			att = true
		node = node.get_parent()
	return att

# Depth-token swap only: alpha, blend and priorities stay vanilla, so the
# alpha-mask hardware keeps shaping the scope picture; dropping the depth
# writes unblocks depth-tested overlays (the nomad marker) inside it.
func _patch_depth_never(mesh: MeshInstance3D) -> void:
	var count: int = mesh.mesh.get_surface_count()
	for i in count:
		var mat: Material = mesh.get_surface_override_material(i)
		if mat == null:
			mat = mesh.mesh.surface_get_material(i)
		if mat == null or not (mat is ShaderMaterial):
			continue
		var sm: ShaderMaterial = mat as ShaderMaterial
		if sm.shader == null or not _optic_shader(sm.shader):
			continue
		var new_mat: ShaderMaterial = sm.duplicate() as ShaderMaterial
		new_mat.shader = _depth_never_shader(sm.shader)
		mesh.set_surface_override_material(i, new_mat)

func _optic_shader(src: Shader) -> bool:
	var fn: String = src.resource_path.substr(src.resource_path.rfind("/") + 1)
	return OPTIC_SHADERS.has(fn)

func _depth_never_shader(src: Shader) -> Shader:
	if src == null:
		return null
	var rid_id: int = src.get_rid().get_id()
	if rid_id in _depth_patched:
		return _depth_patched[rid_id]
	var code: String = src.code
	var out := src
	# Only the always-writes token blocks the transparent pass for other
	# depth-tested overlays; anything else (incl. missing tokens) stays.
	if code.begins_with("shader_type spatial") and code.find("depth_draw_always") != -1:
		out = Shader.new()
		out.code = code.replace("depth_draw_always", "depth_draw_never")
	_depth_patched[rid_id] = out
	return out

func _patch_base(src: BaseMaterial3D) -> BaseMaterial3D:
	var rid_id: int = src.get_rid().get_id()
	if rid_id in _patched_base:
		return _patched_base[rid_id]
	var new_mat: BaseMaterial3D = src.duplicate() as BaseMaterial3D
	var albedo: Color = new_mat.albedo_color
	new_mat.albedo_color = Color(albedo.r, albedo.g, albedo.b, 1.0)
	new_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	new_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	new_mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	new_mat.render_priority = 30
	_patched_base[rid_id] = new_mat
	return new_mat

# Patch a weapon shader to render in the transparent pass at priority=30.
func _patch_shader(src: Shader) -> Shader:
	if src == null:
		return null
	var rid_id: int = src.get_rid().get_id()
	if rid_id in _patched_shaders:
		return _patched_shaders[rid_id]

	var code: String = src.code
	if not code.begins_with("shader_type spatial"):
		_patched_shaders[rid_id] = src
		return src

	var patched: String = code

	var rm_start: int = patched.find("render_mode ")
	if rm_start >= 0:
		var rm_end: int = patched.find(";", rm_start)
		if rm_end > rm_start:
			var rm_content: String = patched.substr(rm_start + 12, rm_end - rm_start - 12)
			var new_tokens: String = ""
			for tok in rm_content.split(","):
				var t: String = tok.strip_edges()
				if t == "" or t.begins_with("depth_draw") or t.begins_with("blend_"):
					continue
				if new_tokens != "":
					new_tokens += ", "
				new_tokens += t
			if new_tokens != "":
				new_tokens += ", "
			new_tokens += "depth_draw_always, blend_mix"
			patched = patched.substr(0, rm_start) + "render_mode " + new_tokens + patched.substr(rm_end)
	else:
		var st_semi: int = patched.find(";")
		if st_semi >= 0:
			patched = patched.substr(0, st_semi + 1) + "\nrender_mode depth_draw_always, blend_mix;" + patched.substr(st_semi + 1)

	var frag_start: int = patched.find("void fragment()")
	if frag_start < 0:
		var s := Shader.new()
		s.code = patched
		_patched_shaders[rid_id] = s
		return s

	var brace_start: int = patched.find("{", frag_start)
	if brace_start < 0:
		_patched_shaders[rid_id] = src
		return src

	var depth: int = 0
	var brace_end: int = -1
	for idx in range(brace_start, patched.length()):
		if patched[idx] == '{':
			depth += 1
		elif patched[idx] == '}':
			depth -= 1
			if depth == 0:
				brace_end = idx
				break

	if brace_end < 0:
		_patched_shaders[rid_id] = src
		return src

	var frag_body: String = patched.substr(brace_start, brace_end - brace_start)
	if "ALPHA" not in frag_body:
		patched = patched.substr(0, brace_end) + "\tALPHA = 1.0;\n" + patched.substr(brace_end)

	var out := Shader.new()
	out.code = patched
	_patched_shaders[rid_id] = out
	return out
