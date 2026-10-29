extends SceneTree

const WeaponOcclusion = preload("res://mods/ThermalVTK/VTKWeaponOcclusion.gd")

func _init() -> void:
	var o = WeaponOcclusion.new()
	var ring_body := ShaderMaterial.new()
	var body_sh := Shader.new()
	body_sh.code = "shader_type spatial;\nvoid fragment() {}"
	ring_body.shader = body_sh
	var lens := ShaderMaterial.new()
	var lens_sh := Shader.new()
	lens_sh.resource_path = "res://Shaders/Scope.gdshader"
	lens_sh.code = "shader_type spatial;\nrender_mode depth_draw_always;"
	lens.shader = lens_sh
	lens.render_priority = 1
	var rig := Node3D.new()
	rig.name = "Rig"
	var att := Node3D.new()
	att.name = "Attachments"
	rig.add_child(att)
	var body := MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	body.layers = 3
	body.set_surface_override_material(0, ring_body)
	rig.add_child(body)
	root.add_child(rig)
	o._patch_rig(rig)
	print("after patch body=", body.get_surface_override_material(0).get_instance_id())
	var glass := MeshInstance3D.new()
	glass.mesh = BoxMesh.new()
	glass.layers = 3
	glass.set_surface_override_material(0, lens)
	att.add_child(glass)
	o._resweep(rig)
	print("after sweep2 body=", body.get_surface_override_material(0).get_instance_id(), " glass=", glass.get_surface_override_material(0).get_instance_id(), " lens=", lens.get_instance_id())
	var marked: bool = body.has_meta("VTK_OCC")
	print("body meta: ", marked)
	o._resweep(rig)
	print("after sweep3 body=", body.get_surface_override_material(0).get_instance_id(), " bodymeta=", body.has_meta("VTK_OCC"))
	rig.free()
	quit(0)
