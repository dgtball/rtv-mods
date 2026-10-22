extends RefCounted
# Owns one material_overlay (the silhouette ring) per NPC mesh and pushes shader
# parameters only when they move (change gate). Overlays live on the meshes
# themselves, so nothing here is a scene-tree child except through the NPC
# meshes. State colours come in via `opts`; this file only draws.

const Shaders = preload("res://mods/ThermalVTK/VTKShaders.gd")
const States = preload("res://mods/ThermalVTK/VTKStates.gd")
const Dbg = preload("res://mods/ThermalVTK/VTKDebug.gd")

# Nodes the mod adds under a bot's subtree (the nomad marker, the debug label)
# carry this meta: the sweep must skip them, or the ring overlay is assigned on
# top of their own material and paints over the key they emit.
const NO_CONTOUR_META := "vtk_no_contour"

# id -> {"meshes": Array, "ring": ShaderMaterial,
#        "node": Node, "child_count": int}
var _items: Dictionary = {}
# While the scope view is active the ring swaps to the depth-test-disabled
# shader variant: the scope lens writes depth a few centimetres from the eye
# and would z-cull every ring behind it. Uniforms are shared, so the swap
# never loses state.
var _bypass: bool = false

func has(id: int) -> bool:
	return _items.has(id)

func material_of(id: int) -> Dictionary:
	return _items.get(id, {})

# Collect the NPC's paintable geometry. GeometryInstance3D (not just
# MeshInstance3D) so MultiMesh/CSG parts are covered, and NO layer/visible
# filter: bot geometry sits on render layer 1, and hidden LODs must still carry
# the overlay so the LOD that becomes visible already has it. This mirrors
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
	ring_mat.shader = Shaders.ring_scope() if _bypass else Shaders.ring()
	ring_mat.render_priority = 21
	return ring_mat

# Flips every live ring between the depth-tested shader and the scope variant.
# No-op while the flag does not move.
func set_depth_bypass(on: bool) -> void:
	if on == _bypass:
		return
	_bypass = on
	for id in _items:
		var ring_mat: ShaderMaterial = _items[id]["ring"]
		if ring_mat != null and is_instance_valid(ring_mat):
			ring_mat.shader = Shaders.ring_scope() if on else Shaders.ring()

func apply(id: int, node: Node, opts: Dictionary) -> void:
	var meshes: Array = []
	_collect(node, meshes)
	if meshes.is_empty():
		Dbg.log("OUTLINE", "apply id=%d meshes=0 child_count=%d" % [id, node.get_child_count()])
		return
	Dbg.log("OUTLINE", "apply id=%d meshes=%d child_count=%d" % [id, meshes.size(), node.get_child_count()])
	var ring_mat := _build_ring()
	for m in meshes:
		(m as GeometryInstance3D).material_overlay = ring_mat
	_items[id] = {
		"meshes": meshes, "ring": ring_mat,
		"node": node, "child_count": node.get_child_count(),
	}
	refresh(id, opts)

# The rig is assembled/rewired at runtime (AI.Initialize, LOD/gear swaps), and
# pooled bots are reused with a rebuilt subtree, so a one-shot snapshot goes
# stale. Mirror VTKNVG: re-sweep when the child count moves and re-apply.
func _recollect(id: int, entry: Dictionary) -> void:
	var node = entry.get("node")
	if node == null or not is_instance_valid(node):
		return
	var before := int(entry.get("child_count", -1))
	for m in entry.get("meshes", []):
		if is_instance_valid(m):
			(m as GeometryInstance3D).material_overlay = null
	var fresh: Array = []
	_collect(node, fresh)
	Dbg.log("OUTLINE", "recollect id=%d child_count=%d->%d meshes=%d" % [id, before, node.get_child_count(), fresh.size()])
	if fresh.is_empty():
		return
	var ring_mat: ShaderMaterial = entry["ring"]
	for m in fresh:
		(m as GeometryInstance3D).material_overlay = ring_mat
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

	var rim := float(opts.get("rim", 1.0))
	if ring_mat.get_shader_parameter("rim_power") == null or not is_equal_approx(float(ring_mat.get_shader_parameter("rim_power")), rim):
		ring_mat.set_shader_parameter("rim_power", rim)

	if ring_mat.get_shader_parameter("cool") == null or not is_equal_approx(float(ring_mat.get_shader_parameter("cool")), cool):
		ring_mat.set_shader_parameter("cool", cool)

func clear(id: int) -> void:
	var entry = _items.get(id)
	if entry == null:
		return
	for m in entry.get("meshes", []):
		if is_instance_valid(m):
			(m as GeometryInstance3D).material_overlay = null
	_items.erase(id)

func clear_all() -> void:
	for id in _items.keys():
		clear(id)

# Drop entries whose node is gone (targets no longer in `valid_ids`).
func prune_missing(valid_ids: Dictionary) -> void:
	for id in _items.keys():
		if not valid_ids.has(id):
			clear(id)
