extends RefCounted
# Owns one material_overlay + next_pass chain per NPC mesh and pushes shader
# parameters only when they move (change gate). Overlay chains live on the
# meshes themselves, so nothing here is a scene-tree child except through the
# NPC meshes. Faction/state colours come in via `opts`; this file only draws.

const Shaders = preload("res://mods/ThermalVTK/VTKShaders.gd")
const States = preload("res://mods/ThermalVTK/VTKStates.gd")
const Dbg = preload("res://mods/ThermalVTK/VTKDebug.gd")

# id -> {"meshes": Array, "body": ShaderMaterial, "ring": ShaderMaterial,
#        "wall": bool, "_c": ... change-gate cache}
var _items: Dictionary = {}

func has(id: int) -> bool:
	return _items.has(id)

func material_of(id: int) -> Dictionary:
	return _items.get(id, {})

# Collect the NPC's paintable geometry. GeometryInstance3D (not just
# MeshInstance3D) so MultiMesh/CSG parts are covered, and NO layer/visible
# filter: bot geometry sits on render layer 1, and hidden LODs must still carry
# the overlay so the LOD that becomes visible already has it. This mirrors
# VTKNVG._collect_meshes, the route mode B already proves works.
func _collect(node: Node, out: Array) -> void:
	if node is GeometryInstance3D:
		out.append(node)
	for c in node.get_children():
		_collect(c, out)

func _build_chain(through_walls: bool) -> Array:
	var body_mat := ShaderMaterial.new()
	body_mat.shader = Shaders.body(through_walls)
	body_mat.render_priority = 20
	var ring_mat := ShaderMaterial.new()
	ring_mat.shader = Shaders.ring(through_walls)
	ring_mat.render_priority = 21
	body_mat.next_pass = ring_mat
	return [body_mat, ring_mat]

func apply(id: int, node: Node, opts: Dictionary) -> void:
	var meshes: Array = []
	_collect(node, meshes)
	if meshes.is_empty():
		Dbg.log("OUTLINE", "apply id=%d meshes=0 child_count=%d" % [id, node.get_child_count()])
		return
	Dbg.log("OUTLINE", "apply id=%d meshes=%d child_count=%d" % [id, meshes.size(), node.get_child_count()])
	var wall := bool(opts.get("through_walls", true))
	var chain := _build_chain(wall)
	var body_mat: ShaderMaterial = chain[0]
	var ring_mat: ShaderMaterial = chain[1]
	# render_priority high so overlays draw after the world but before the
	# weapon (patched to priority 30 in Task 10).
	body_mat.render_priority = 20
	ring_mat.render_priority = 21
	for m in meshes:
		(m as GeometryInstance3D).material_overlay = body_mat
	_items[id] = {
		"meshes": meshes, "body": body_mat, "ring": ring_mat, "wall": wall,
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
	var body_mat: ShaderMaterial = entry["body"]
	for m in fresh:
		(m as GeometryInstance3D).material_overlay = body_mat
	entry["meshes"] = fresh
	entry["child_count"] = node.get_child_count()

# Swap the depth variant in place when the through-walls decision flips; the
# overlay assignment does not change, only the two shader resources.
func _set_wall(id: int, entry: Dictionary, wall: bool) -> void:
	if bool(entry.get("wall", wall)) == wall:
		return
	(entry["body"] as ShaderMaterial).shader = Shaders.body(wall)
	(entry["ring"] as ShaderMaterial).shader = Shaders.ring(wall)
	entry["wall"] = wall
	Dbg.log("OUTLINE", "wall id=%d through=%s" % [id, str(wall)])

func refresh(id: int, opts: Dictionary) -> void:
	var entry = _items.get(id)
	if entry == null:
		return
	var node = entry.get("node")
	if node != null and is_instance_valid(node) and node.get_child_count() != int(entry.get("child_count", -1)):
		_recollect(id, entry)
	_set_wall(id, entry, bool(opts.get("through_walls", true)))
	var key: Color = opts.get("state_key", States.KEY_NORMAL)
	var alpha := float(opts.get("alpha", 1.0))
	var grow := float(opts.get("grow", 0.006))
	var flash := float(opts.get("flash", 0.0))
	var foot_y := float(opts.get("foot_y", 0.0))
	var body_h := float(opts.get("body_height", 1.8))
	var cool := float(opts.get("cool", 0.0))
	var fill_alpha := float(opts.get("fill_alpha", 0.4))

	var body_mat: ShaderMaterial = entry["body"]
	var ring_mat: ShaderMaterial = entry["ring"]

	if ring_mat.get_shader_parameter("state_key") != key \
			or ring_mat.get_shader_parameter("grow") == null \
			or not is_equal_approx(float(ring_mat.get_shader_parameter("grow")), grow):
		ring_mat.set_shader_parameter("state_key", key)
		ring_mat.set_shader_parameter("grow", grow)

	if body_mat.get_shader_parameter("fill_alpha") == null or not is_equal_approx(float(body_mat.get_shader_parameter("fill_alpha")), fill_alpha * alpha):
		body_mat.set_shader_parameter("fill_alpha", fill_alpha * alpha)
	if body_mat.get_shader_parameter("cool") == null or not is_equal_approx(float(body_mat.get_shader_parameter("cool")), cool):
		body_mat.set_shader_parameter("cool", cool)
	if body_mat.get_shader_parameter("footY") == null or not is_equal_approx(float(body_mat.get_shader_parameter("footY")), foot_y):
		body_mat.set_shader_parameter("footY", foot_y)
	if body_mat.get_shader_parameter("bodyHeight") == null or not is_equal_approx(float(body_mat.get_shader_parameter("bodyHeight")), body_h):
		body_mat.set_shader_parameter("bodyHeight", body_h)
	if body_mat.get_shader_parameter("flash") == null or not is_equal_approx(float(body_mat.get_shader_parameter("flash")), flash):
		body_mat.set_shader_parameter("flash", flash)
	var flash_col: Color = opts.get("flash_color", Color.WHITE)
	if body_mat.get_shader_parameter("flash_color") != flash_col:
		body_mat.set_shader_parameter("flash_color", flash_col)

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
