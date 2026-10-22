extends RefCounted
# Owns one ring material per NPC and renders it on dedicated ghost shells
# (sibling MeshInstance3D copies, the approach reference outline mods use):
# same mesh/skin/skeleton, transform mirrored every frame, material_override,
# no_depth_test on the node, shadow casting off. The ring shader ignores the
# depth buffer, so the shells stay visible in the scope view as well.
# Non-mesh geometry (MultiMesh/CSG) keeps a material_overlay on the source.
# State colours come in via `opts`; this file only draws.

const Shaders = preload("res://mods/ThermalVTK/VTKShaders.gd")
const States = preload("res://mods/ThermalVTK/VTKStates.gd")
const Dbg = preload("res://mods/ThermalVTK/VTKDebug.gd")

# Nodes the mod adds under a bot's subtree (the nomad marker, the debug label,
# the ring shells themselves) carry this meta: the sweep must skip them, or the
# ring material is assigned on top of their own material and paints over the
# key they emit.
const NO_CONTOUR_META := "vtk_no_contour"
const SHELL_NAME := "VTK_Ring"

# id -> {"meshes": Array, "pairs": Array, "ring": ShaderMaterial,
#        "node": Node, "child_count": int}
var _items: Dictionary = {}
# While the scope view is active the band thins (SCOPE_RIM), so the magnified
# view keeps a fine frame. The shader itself never changes any more: it always
# ignores depth.
const SCOPE_RIM := 6.0
var _bypass: bool = false

func has(id: int) -> bool:
	return _items.has(id)

func material_of(id: int) -> Dictionary:
	return _items.get(id, {})

# Collect the NPC's paintable geometry. GeometryInstance3D (not just
# MeshInstance3D) so MultiMesh/CSG parts are covered, and NO layer/visible
# filter: bot geometry sits on render layer 1, and hidden LODs must still carry
# a shell/overlay so the LOD that becomes visible already has it. This mirrors
# VTKNVG._collect_meshes, the same sweep the mine path uses.
func _collect(node: Node, out: Array) -> void:
	if node.has_meta(NO_CONTOUR_META):
		return
	if node is GeometryInstance3D:
		out.append(node)
	for c in node.get_children():
		_collect(c, out)

func _build_ring() -> ShaderMaterial:
	var ring_mat := ShaderMaterial.new()
	ring_mat.shader = Shaders.ring()
	ring_mat.render_priority = 21
	return ring_mat

# The same flag still drives the thin in-scope band; no shader swap happens.
# No-op while the flag does not move.
func set_depth_bypass(on: bool) -> void:
	_bypass = on

func apply(id: int, node: Node, opts: Dictionary) -> void:
	var meshes: Array = []
	_collect(node, meshes)
	if meshes.is_empty():
		Dbg.log("OUTLINE", "apply id=%d meshes=0 child_count=%d" % [id, node.get_child_count()])
		return
	Dbg.log("OUTLINE", "apply id=%d meshes=%d child_count=%d" % [id, meshes.size(), node.get_child_count()])
	var ring_mat := _build_ring()
	var pairs: Array = []
	for m in meshes:
		pairs.append(_make_shell(m, ring_mat))
	_items[id] = {
		"meshes": meshes, "pairs": pairs, "ring": ring_mat,
		"node": node, "child_count": node.get_child_count(),
	}
	refresh(id, opts)

# Ghost shell beside each mesh: the depth-tested world cannot kill it because
# both the node flag and the shader drop the depth test, and the shell sits
# outside the rig material pipeline, so the scope view cannot cull it either.
func _make_shell(src: GeometryInstance3D, ring_mat: ShaderMaterial) -> Dictionary:
	var pair := {"src": src, "shell": null, "overlay": false}
	if src is MeshInstance3D:
		var mi := src as MeshInstance3D
		var shell := MeshInstance3D.new()
		shell.name = SHELL_NAME
		shell.mesh = mi.mesh
		shell.skin = mi.skin
		shell.skeleton = mi.skeleton
		shell.transform = mi.transform
		shell.material_override = ring_mat
		shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shell.set_meta(NO_CONTOUR_META, true)
		var p := mi.get_parent()
		if p == null:
			shell.queue_free()
			return pair
		p.add_child(shell)
		pair["shell"] = shell
		return pair
	src.material_overlay = ring_mat
	pair["overlay"] = true
	return pair

# Mirror the rig by hand: pooled bots and LOD swaps move the sources, and the
# shells are plain copies, not bone-driven children. Called from the ESP frame.
func sync() -> void:
	for id in _items:
		for pair in _items[id].get("pairs", []):
			var src = pair.get("src")
			var shell = pair.get("shell")
			if shell == null or src == null:
				continue
			if is_instance_valid(src) and is_instance_valid(shell):
				shell.transform = (src as Node3D).transform

func _free_pairs(id: int) -> void:
	var entry: Dictionary = _items[id]
	var ring_mat: ShaderMaterial = entry["ring"]
	for pair in entry.get("pairs", []):
		var shell = pair.get("shell")
		if shell != null and is_instance_valid(shell):
			shell.queue_free()
		elif bool(pair.get("overlay", false)):
			var src = pair.get("src")
			if src != null and is_instance_valid(src) and (src as GeometryInstance3D).material_overlay == ring_mat:
				(src as GeometryInstance3D).material_overlay = null

# The rig is assembled/rewired at runtime (AI.Initialize, LOD/gear swaps), and
# pooled bots are reused with a rebuilt subtree, so a one-shot snapshot goes
# stale. Mirror VTKNVG: re-sweep when the child count moves and re-apply.
func _recollect(id: int, entry: Dictionary) -> void:
	var node = entry.get("node")
	if node == null or not is_instance_valid(node):
		return
	var before := int(entry.get("child_count", -1))
	_free_pairs(id)
	var fresh: Array = []
	_collect(node, fresh)
	Dbg.log("OUTLINE", "recollect id=%d child_count=%d->%d meshes=%d" % [id, before, node.get_child_count(), fresh.size()])
	if fresh.is_empty():
		return
	var ring_mat: ShaderMaterial = entry["ring"]
	var pairs: Array = []
	for m in fresh:
		pairs.append(_make_shell(m, ring_mat))
	entry["pairs"] = pairs
	entry["meshes"] = fresh
	entry["child_count"] = node.get_child_count()

func refresh(id: int, opts: Dictionary) -> void:
	var entry = _items.get(id)
	if entry == null:
		return
	var node = entry.get("node")
	if node != null and is_instance_valid(node) and node.get_child_count() != int(entry.get("child_count", -1)):
		_recollect(id, entry)
	var key: Color = opts.get("state_key", States.KEY_NORMAL)
	var grow := float(opts.get("grow", 0.006))
	var cool := float(opts.get("cool", 0.0))

	var ring_mat: ShaderMaterial = entry["ring"]

	if ring_mat.get_shader_parameter("state_key") != key \
			or ring_mat.get_shader_parameter("grow") == null \
			or not is_equal_approx(float(ring_mat.get_shader_parameter("grow")), grow):
		ring_mat.set_shader_parameter("state_key", key)
		ring_mat.set_shader_parameter("grow", grow)

	var rim := SCOPE_RIM if _bypass else float(opts.get("rim", 1.0))
	if ring_mat.get_shader_parameter("rim_power") == null or not is_equal_approx(float(ring_mat.get_shader_parameter("rim_power")), rim):
		ring_mat.set_shader_parameter("rim_power", rim)

	if ring_mat.get_shader_parameter("cool") == null or not is_equal_approx(float(ring_mat.get_shader_parameter("cool")), cool):
		ring_mat.set_shader_parameter("cool", cool)

func clear(id: int) -> void:
	var entry = _items.get(id)
	if entry == null:
		return
	_free_pairs(id)
	_items.erase(id)

func clear_all() -> void:
	for id in _items.keys():
		clear(id)

# Drop entries whose node is gone (targets no longer in `valid_ids`).
func prune_missing(valid_ids: Dictionary) -> void:
	for id in _items.keys():
		if not valid_ids.has(id):
			clear(id)
