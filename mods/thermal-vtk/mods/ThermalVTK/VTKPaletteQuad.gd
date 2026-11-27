extends Node
## One fullscreen spatial quad that palettizes the 3D view.
##
## Godot copies the screen texture after opaque geometry and never includes
## transparent materials in that copy. The quad therefore runs once at -128,
## before vanilla optics (0/11), and palettizes the world and the weapon model.
## Transparent optics draw afterwards and stay untouched: a second pass over
## them would only blend the palette at partial alpha and wash out the lens.
## Exact-colour ESP contours and mine shells draw later at 20/21. The mesh is
## parented to the current camera and its vertex shader writes clip space
## directly, so it always covers the viewport and is never culled.

const Shaders = preload("res://mods/ThermalVTK/VTKShaders.gd")

var _mesh: MeshInstance3D = null
var _mat: ShaderMaterial = null


func material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = Shaders.palette()
		_mat.render_priority = -128
		_mat.set_shader_parameter("paletteAlpha", 1.0)
	return _mat


func _make_mesh(mesh_name: String, mat: ShaderMaterial) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = mesh_name
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	m.mesh = quad
	# The local quad straddles the camera origin; the custom AABB keeps it
	# inside the frustum even though POSITION bypasses the camera transform.
	m.custom_aabb = AABB(Vector3(-1.0, -1.0, -1.0), Vector3(2.0, 2.0, 2.0))
	m.material_override = mat
	return m


func attach(cam: Camera3D) -> void:
	if cam == null or not is_instance_valid(cam):
		return
	if _mesh == null or not is_instance_valid(_mesh):
		_mesh = _make_mesh("VTKPaletteQuad", material())
	if _mesh.get_parent() == cam:
		return
	var parent := _mesh.get_parent()
	if parent != null:
		parent.remove_child(_mesh)
	cam.add_child(_mesh)


func set_enabled(on: bool) -> void:
	if _mesh != null and is_instance_valid(_mesh):
		_mesh.visible = on


func apply(stops: Array, out: float, gain: float, knee: float) -> void:
	_push(material(), stops, out, gain, knee, 1.0)


func _push(mat: ShaderMaterial, stops: Array, out: float, gain: float, knee: float, alpha: float) -> void:
	for i in 5:
		var c: Color = stops[i] if i < stops.size() and stops[i] is Color else Color.BLACK
		mat.set_shader_parameter("paletteStop%d" % i, c)
	mat.set_shader_parameter("paletteOut", out)
	mat.set_shader_parameter("inputGain", gain)
	mat.set_shader_parameter("inputKnee", knee)
	mat.set_shader_parameter("paletteAlpha", alpha)
