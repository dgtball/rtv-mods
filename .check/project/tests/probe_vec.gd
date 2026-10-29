extends SceneTree

const WeaponOcclusion = preload("res://mods/ThermalVTK/VTKWeaponOcclusion.gd")

func _init() -> void:
	process_frame.connect(_run)

func _run() -> void:
	process_frame.disconnect(_run)
	var o2 = WeaponOcclusion.new()
	o2._mgr = root
	var cam2 := Camera3D.new()
	cam2.fov = 75.0
	root.add_child(cam2)
	cam2.global_position = Vector3.ZERO
	var holder2 := Node3D.new()
	holder2.global_position = Vector3(0, 0, -200.0)
	holder2.rotation = Vector3(PI / 2.0, 0.0, 0.0)
	root.add_child(holder2)
	var mask2 := ShaderMaterial.new()
	var mask2_sh := Shader.new()
	mask2_sh.resource_path = "res://Shaders/Mask.gdshader"
	mask2_sh.code = "shader_type spatial;\nvoid fragment() {}"
	mask2.shader = mask2_sh
	var disc := CylinderMesh.new()
	disc.top_radius = 20.0
	disc.bottom_radius = 20.0
	disc.height = 0.5
	var mi2 := MeshInstance3D.new()
	mi2.mesh = disc
	mi2.set_surface_override_material(0, mask2)
	holder2.add_child(mi2)
	cam2.make_current()
	var arr: Array = disc.surface_get_arrays(0)
	var vs = arr[Mesh.ARRAY_VERTEX]
	print("DBG verts=", vs.size())
	for i in [0, 1, int(vs.size() / 2), vs.size() - 1]:
		var w: Vector3 = mi2.global_transform * vs[i]
		var p: Vector2 = cam2.unproject_position(w)
		print("DBG v=", vs[i], " w=", w, " p=", p, " vp=", cam2.get_viewport().get_visible_rect().size)
	var clip3: Dictionary = o2.measure_scope_clip(cam2)
	print("DBG clip=", clip3)
	holder2.free()
	cam2.free()
	quit(0)
