extends SceneTree

func bounds_of(mesh: Mesh, idx: int) -> AABB:
	var a: PackedVector3Array = mesh.surface_get_arrays(idx)[0]
	if a.is_empty():
		return AABB()
	var lo: Vector3 = a[0]
	var hi: Vector3 = a[0]
	for p in a:
		lo = Vector3(min(lo.x, p.x), min(lo.y, p.y), min(lo.z, p.z))
		hi = Vector3(max(hi.x, p.x), max(hi.y, p.y), max(hi.z, p.z))
	return AABB(lo, hi - lo)

func _init() -> void:
	process_frame.connect(_run)

func _run() -> void:
	for path in [
		"res://Items/Attachments/Vudu/Vudu_Active.tscn",
		"res://Items/Attachments/ACOG/ACOG_Active.tscn",
	]:
		var ps = load(path)
		if ps == null:
			print("skip ", path)
			continue
		var inst = ps.instantiate()
		print("=== ", path.get_file())
		var stack: Array = [inst]
		while stack.size() > 0:
			var n = stack.pop_back()
			for c in n.get_children():
				stack.append(c)
			if not (n is MeshInstance3D):
				continue
			var mi := n as MeshInstance3D
			if mi.mesh == null:
				continue
			var count: int = mi.mesh.get_surface_count()
			for i in count:
				var mm = mi.mesh.surface_get_material(i)
				var shp := "-"
				if mm != null and mm is ShaderMaterial:
					var sm = mm as ShaderMaterial
					shp = sm.shader.resource_path.get_file() if sm.shader != null else "-"
				print("  m=", mi.name, " s", i, " sh=", shp, " pos=", mi.position, " size=", bounds_of(mi.mesh, i).size)
		inst.free()
	quit(0)
