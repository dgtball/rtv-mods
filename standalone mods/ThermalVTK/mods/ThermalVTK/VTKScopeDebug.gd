extends RefCounted
# Scoped-view diagnostic. While the diagnostic log is on and the player aims
# through a scope, walk the ray from the camera centre and dump everything it
# crosses (the weapon rig first, then the target), with each surface's shader
# path, render priority, and the outline overlay state on bot meshes. Answers
# "what draws in front of the contour inside the scope" from the live scene,
# not from shader reading.

const Dbg = preload("res://mods/ThermalVTK/VTKDebug.gd")

const MAX_HITS := 8
const MAX_SURF := 6
const BOT_INFO := 3

static func scope_snapshot(gd: Resource, players: Array, esp: Node, weapon) -> void:
	if gd == null:
		Dbg.log("SCOPE", "snapshot: no gameData")
		return
	var scoped := bool(gd.get("isScoped"))
	var pip := bool(gd.get("PIP"))
	var cam: Camera3D = esp.get_viewport().get_camera_3d()
	if cam == null:
		Dbg.log("SCOPE", "snapshot scoped=%s pip=%s no active camera" % [str(scoped), str(pip)])
		return
	var fwd: Vector3 = -cam.global_transform.basis.z
	Dbg.log("SCOPE", "snapshot scoped=%s pip=%s fov=%.1f" % [str(scoped), str(pip), cam.fov])
	_snapshot_raywalk(cam, players)
	_snapshot_entries(esp)
	_snapshot_render(cam, esp)
	_snapshot_ring(cam, weapon)

# Mesh-level walk between the eye and the crosshair target: every geometry in
# the scope cone reports its position, shader and render priority, so the
# occluder drawing over the ring is found in the live scene, not guessed from
# shaders alone.
static func _snapshot_render(cam: Camera3D, esp: Node) -> void:
	var target: Vector3 = Vector3.ZERO
	var target_node: Node = null
	var entries: Dictionary = esp._entries
	var fwd: Vector3 = -cam.global_transform.basis.z
	var best := -1.0
	for id in entries.keys():
		var e: Dictionary = entries[id]
		var node = e.get("node")
		if node == null or not is_instance_valid(node) or not node.is_inside_tree():
			continue
		var to_node: Vector3 = (node as Node3D).global_position - cam.global_position
		var dot_val: float = to_node.normalized().dot(fwd)
		if dot_val > best:
			best = dot_val
			target = (node as Node3D).global_position
			target_node = node
	if target_node == null or best < 0.95:
		return
	var seg: Vector3 = target - cam.global_position
	var depth: float = seg.length()
	var seg_dir := seg / depth
	Dbg.log("SCOPE", "render cone to %s d=%.1f" % [str(target_node.name), depth])
	_walk_render(esp.get_tree().root, cam, seg_dir, depth, target_node)

static func _walk_render(n: Node, cam: Camera3D, seg_dir: Vector3, seg_len: float, target_node: Node) -> void:
	if n == null or not is_instance_valid(n):
		return
	if n == target_node or n.is_ancestor_of(target_node):
		for c in n.get_children():
			_walk_render(c, cam, seg_dir, seg_len, target_node)
		return
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.visible and mi.mesh != null:
			var ab: AABB = mi.global_transform * mi.get_aabb()
			var t := _ray_hit(seg_dir, ab, cam.global_position, seg_len)
			if t > 0.15 and t < seg_len:
				var mat: Material = mi.material_override
				if mat == null:
					mat = mi.get_surface_override_material(0)
				if mat == null and mi.mesh.get_surface_count() > 0:
					mat = mi.mesh.surface_get_material(0)
				var shp := "(none)"
				if mat is ShaderMaterial:
					var sm := mat as ShaderMaterial
					if sm.shader != null:
						shp = sm.shader.resource_path if sm.shader.resource_path != "" else "(runtime)"
				var prio: float = mat.render_priority if mat != null else 0.0
				Dbg.log("SCOPE", "tri d=%.2f node=%s sh=%s prio=%.0f layers=%d" % [t, str(mi.name), shp, prio, mi.layers])
	for c in n.get_children():
		_walk_render(c, cam, seg_dir, seg_len, target_node)

static func _ray_hit(dir: Vector3, ab: AABB, from: Vector3, far: float) -> float:
	var tmin := -INF
	var tmax := INF
	var ox := [from.x, from.y, from.z]
	var dx := [dir.x, dir.y, dir.z]
	var lox := [ab.position.x, ab.position.y, ab.position.z]
	var six := [ab.size.x, ab.size.y, ab.size.z]
	for axis in 3:
		var lo: float = lox[axis]
		var hi: float = lo + six[axis]
		if abs(dx[axis]) < 0.000001:
			if ox[axis] < lo or ox[axis] > hi:
				return -1.0
			continue
		var t1: float = (lo - ox[axis]) / dx[axis]
		var t2: float = (hi - ox[axis]) / dx[axis]
		if t1 > t2:
			var tmp: float = t1
			t1 = t2
			t2 = tmp
		if t1 > tmin:
			tmin = t1
		if t2 < tmax:
			tmax = t2
		if tmin > tmax:
			return -1.0
	if tmax < 0.0 or tmin > far:
		return -1.0
	return tmin if tmin > 0.0 else 0.0

static func _snapshot_raywalk(cam: Camera3D, players: Array) -> void:
	var space := cam.get_world_3d().direct_space_state
	if space == null:
		Dbg.log("SCOPE", "ray: no space state")
		return
	var fwd: Vector3 = -cam.global_transform.basis.z
	var from := cam.global_position
	for i in MAX_HITS:
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from + fwd * 0.05, from + fwd * 200.0))
		if hit.is_empty():
			Dbg.log("SCOPE", "ray: clear beyond %.2f" % from.distance_to(cam.global_position))
			return
		var d: float = cam.global_position.distance_to(hit["position"])
		var col = hit.get("collider")
		if players.has(col):
			Dbg.log("SCOPE", "ray d=%.2f player body (skipped)" % d)
			from = hit["position"] + fwd * 0.1
			continue
		_desc_collider(col, d)
		if d > 80.0:
			return
		from = hit["position"] + fwd * 0.1

static func _desc_collider(col: Variant, d: float) -> void:
	var head := "ray d=%.2f" % d
	if col == null:
		Dbg.log("SCOPE", head + " collider null")
		return
	head += " class=%s node=%s" % [col.get_class(), str(col.name)]
	var sc = col.get_script()
	if sc != null:
		head += " script=" + str(sc.resource_path)
	Dbg.log("SCOPE", head)
	if col is MeshInstance3D:
		_mesh_surfaces(col as MeshInstance3D, "ray")

static func _mesh_surfaces(mi: MeshInstance3D, tag: String) -> void:
	var head := tag + " m=" + str(mi.name) + " layers=" + str(mi.layers) + " vis=" + str(mi.is_visible_in_tree())
	# Ancestry trail for the rig listing: names the attachment assembly even
	# when it is not literally called "Attachments".
	var p := mi.get_parent()
	var hops := 0
	while p != null and hops < 6:
		head += " " + str(p.name)
		if p.get("attachments") != null:
			head += "(att)"
		p = p.get_parent()
		hops += 1
	if mi.mesh == null:
		Dbg.log("SCOPE", head + " mesh=null")
		return
	var sc: int = mi.mesh.get_surface_count()
	var n := sc if sc < MAX_SURF else MAX_SURF
	for i in n:
		Dbg.log("SCOPE", head + _surf_desc(mi, i))
	_desc_overlay(mi, head)

static func _surf_desc(mi: MeshInstance3D, i: int) -> String:
	var mat: Material = mi.get_surface_override_material(i)
	if mat == null and mi.mesh != null:
		mat = mi.mesh.surface_get_material(i)
	if mat == null:
		return " s%d=null" % i
	if mat is ShaderMaterial:
		var sm := mat as ShaderMaterial
		var sp := "(runtime)"
		if sm.shader != null:
			sp = sm.shader.resource_path if sm.shader.resource_path != "" else "(runtime)"
		return " s%d=%s sh=%s prio=%d" % [i, mat.get_class(), sp, sm.render_priority]
	if mat is BaseMaterial3D:
		var bm := mat as BaseMaterial3D
		return " s%d=Base3D prio=%d alpha=%d" % [i, bm.render_priority, bm.transparency]
	return " s%d=%s prio=%d" % [i, mat.get_class(), mat.render_priority]

static func _desc_overlay(mi: MeshInstance3D, head: String) -> void:
	var ov: Material = mi.material_overlay
	if ov == null:
		return
	var d := " overlay=" + ov.get_class()
	if ov is ShaderMaterial:
		var osm := ov as ShaderMaterial
		if osm.shader != null:
			d += " sh=%s prio=%d grow=%s rim=%s" % [osm.shader.resource_path, osm.render_priority, str(osm.get_shader_parameter("grow")), str(osm.get_shader_parameter("rim_power"))]
			d += " ALPHA_now=" + str(osm.get_shader_parameter("cool"))
	Dbg.log("SCOPE", head + d)

static func _snapshot_entries(esp: Node) -> void:
	var entries: Dictionary = esp._entries
	var outline = esp._outline
	var shown := 0
	for id in entries.keys():
		if shown >= BOT_INFO:
			break
		var e: Dictionary = entries[id]
		var node = e.get("node")
		if node == null or not is_instance_valid(node) or not node.is_inside_tree():
			continue
		shown += 1
		var base := "bot name=%s dead=%s dist=%.1f" % [str(node.name), str(bool(e.get("dead", false))), float(e.get("dist", -1.0))]
		var items: Dictionary = outline._items
		var it: Dictionary = items.get(id, {})
		var meshes: Array = it.get("meshes", [])
		Dbg.log("SCOPE", base + " meshes=" + str(meshes.size()) + " ring=" + str(it.get("ring") != null))
		var nm := meshes.size() if meshes.size() < BOT_INFO else BOT_INFO
		for j in nm:
			var m = meshes[j]
			if m == null or not is_instance_valid(m):
				continue
			var head := base + " mesh#" + str(j) + " m=" + str((m as Node).name)
			var ov: Material = (m as MeshInstance3D).material_overlay
			if ov == null:
				Dbg.log("SCOPE", head + " overlay=null")
				continue
			if ov is ShaderMaterial:
				var osm := ov as ShaderMaterial
				Dbg.log("SCOPE", head + " overlay sh=%s prio=%d rim=%s" % [str(osm.shader.resource_path) if osm.shader != null else "?", osm.render_priority, str(osm.get_shader_parameter("rim_power"))])
			else:
				Dbg.log("SCOPE", head + " overlay=" + ov.get_class())

static func _snapshot_ring(cam: Camera3D, weapon) -> void:
	if weapon == null:
		Dbg.log("SCOPE", "rig: no weapon module")
		return
	var mgr = weapon._mgr
	if mgr == null or not is_instance_valid(mgr):
		Dbg.log("SCOPE", "rig: no camera manager attached")
		return
	Dbg.log("SCOPE", "rig children=%d patched=%d depth=%d skipped=%d" % [mgr.get_child_count(), weapon._dbg_patched, weapon._dbg_depth, weapon._dbg_layer_skip])
	for child in mgr.get_children():
		_list_front_meshes(child, cam)

static func _list_front_meshes(n: Node, cam: Camera3D) -> void:
	if n == null or not is_instance_valid(n):
		return
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.is_visible_in_tree() and mi.mesh != null:
			var ab: AABB = mi.global_transform * mi.get_aabb()
			var fwd: Vector3 = -cam.global_transform.basis.z
			var d: float = (ab.get_center() - cam.global_position).dot(fwd)
			var diag := ab.size.length()
			if d > -diag * 0.5 and d - diag * 0.5 < 5.0:
				_mesh_surfaces(mi, "rig")
	for c in n.get_children():
		_list_front_meshes(c, cam)
