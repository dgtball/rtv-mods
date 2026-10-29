extends SceneTree

const W = preload("res://mods/ThermalVTK/VTKWeaponOcclusion.gd")

func _init() -> void:
	process_frame.connect(_run)

func _run() -> void:
	var map := Node.new()
	map.name = "Map"
	var core := Node.new()
	core.name = "Core"
	var cam := Node.new()
	cam.name = "Camera"
	var mgr := Node.new()
	mgr.name = "Manager"
	map.add_child(core)
	core.add_child(cam)
	cam.add_child(mgr)
	root.add_child(map)
	var lens := MeshInstance3D.new()
	lens.mesh = BoxMesh.new()
	lens.layers = 2
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nrender_mode unshaded, depth_draw_always;"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	lens.material_override = mat
	mgr.add_child(lens)
	var o = W.new()
	o._setup()
	o.set_scope_glass(true)
	print("A mats=", o._glass_mats.size(), " has=", o._glass_mats.has(mat), " never=", mat.shader.code.contains("depth_draw_never"))
	o._swap_glass(mgr, false)
	print("B mats=", o._glass_mats.size(), " always=", mat.shader.code.contains("depth_draw_always"))
	o.set_scope_glass(false)
	print("C mats=", o._glass_mats.size(), " always=", mat.shader.code.contains("depth_draw_always"), " oglass_on=", o._glass_on)
	root.remove_child(map)
	map.free()
	quit(0)
