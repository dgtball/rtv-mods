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
# ocular into an opaque black disc painted over the scope picture. A depth-
# token swap experiment (1.11.4-1.12.3) went further and darkened the lens
# itself: the vanilla depth behaviour of the Scope/Mask/Objective shaders
# shapes the scope picture, so the attachments subtree keeps its materials
# EXACTLY vanilla (1.12.4). Neither the ring nor the nomad marker needs the
# swap either: their shaders carry depth_test_disabled and draw by scope-
# driven priority.
#
# Driven once per frame by VTKESP while the contour ESP is active.

const Dbg = preload("res://mods/ThermalVTK/VTKDebug.gd")
const Paths = preload("res://mods/ThermalVTK/VTKPaths.gd")

var _last_scene_id: int = 0
var _connected: bool = false
var _mgr: Node = null
var _patched_shaders: Dictionary = {}
var _patched_base: Dictionary = {}
# How often (frames) the cheap meta-guarded resweep re-walks the rigs; catches
# meshes that landed after the add signal or before we attached.
const RESWEEP_FRAMES := 90
var _dbg_patched: int = 0
var _dbg_layer_skip: int = 0
var _resweep_cd: int = 0
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
		_resweep_cd = 0
		_missing_logged = false
	elif _connected:
		_resweep_cd -= 1
		if _resweep_cd <= 0:
			_resweep_cd = RESWEEP_FRAMES
			_resweep(_mgr)
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
	_patch_node(rig, null)

# Periodic meta-guarded re-walk: patches exactly what the first pass missed
# (a mesh that landed without an add signal, or while the feature detached).
func _resweep(rig: Node) -> void:
	if rig == null or not is_instance_valid(rig):
		return
	_patch_node(rig, null)

func _patch_node(node: Node, att_node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	# The rig script carries the assembly as a real reference (the export
	# `attachments: Node3D`), so name-based matching stays a fallback only.
	var asm: Node = node.get("attachments")
	if asm != null:
		att_node = asm
	if node is MeshInstance3D:
		_patch_mesh(node as MeshInstance3D, att_node)
	for child in node.get_children():
		_patch_node(child, att_node)

func _patch_mesh(mesh: MeshInstance3D, att_node: Node) -> void:
	if mesh.mesh == null:
		return
	if mesh.has_meta("VTK_OCC"):
		return
	if (mesh.layers & 2) == 0:
		_dbg_layer_skip += 1
		mesh.set_meta("VTK_OCC", true)
		return
	var hops := 0
	var n: Node = mesh
	var trail := ""
	while n != null and hops < 16:
		var mark: String = "E" if (att_node != null and n == att_node) or n.name == "Attachments" else ""
		trail += ("|" if hops > 0 else "") + str(n.name) + mark
		n = n.get_parent()
		hops += 1
	Dbg.log("WEAPON", "patch %s chain=%s" % [mesh.name, trail])
	mesh.set_meta("VTK_OCC", true)
	if _under_attachments(mesh, att_node):
		# Everything inside the assembly stays vanilla: the scope picture is
		# shaped by the optic shaders' own depth behaviour (see module header).
		return
	var count: int = mesh.mesh.get_surface_count()
	for i in count:
		var mat: Material = mesh.get_surface_override_material(i)
		if mat == null:
			mat = mesh.mesh.surface_get_material(i)
		if mat == null:
			continue
		if _skip(mesh, mat, att_node):
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

func _skip(mesh: MeshInstance3D, mat: Material, att_node: Node = null) -> bool:
	var node: Node = mesh
	while node != null:
		# The PIP display quads are NODES named PIP; script members must not
		# count - the optic assemblies carry Optic.gd, whose signal is also
		# called PIP, and that used to gloss the whole Attachments subtree.
		if node.name == "PIP":
			return true
		if att_node != null and node == att_node:
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

# True iff the mesh sits inside the attachments assembly - the node the rig
# script exports as `attachments`, or (as a fallback) one literally named
# "Attachments" - without a display quad named PIP above it: a PIP display
# quad inside an assembly must not get the depth swap, the plain skip keeps
# it untouched. Only the node NAME may match: script members (variables,
# signals, methods) read false - the optic assemblies carry Optic.gd whose
# signal is also called PIP.
func _under_attachments(mesh: MeshInstance3D, att_node: Node) -> bool:
	var node: Node = mesh
	var att := false
	while node != null:
		if node.name == "PIP":
			return false
		if att_node != null and node == att_node:
			att = true
		if node.name == "Attachments":
			att = true
		node = node.get_parent()
	return att

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
# Optic assembly hardware keeps its materials vanilla - no swap machinery

