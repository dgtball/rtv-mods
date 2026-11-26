extends Node
## Fullscreen spatial quad that palettizes the world after the opaque pass.
##
## Godot copies the screen texture after opaque geometry and before transparent
## geometry. This quad is the first transparent pass (render_priority -128):
## vanilla optics (0/11), ESP contours and mine shells (20/21) all draw on top
## with their own colours. The mesh is parented to the current camera and its
## vertex shader writes clip space directly, so it always covers the viewport
## and is never frustum-culled.

const Shaders = preload("res://mods/ThermalVTK/VTKShaders.gd")

var _mesh: MeshInstance3D = null
var _mat: ShaderMaterial = null


func material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = Shaders.palette()
		# First transparent pass: the world is already palettized when vanilla
		# optics (0/11) and exact-colour ESP/mines (20/21) draw on top. Painting
		# after optics made scopes look half-transparent and washed out ESP.
		_mat.render_priority = -128
	return _mat


func attach(cam: Camera3D) -> void:
	if cam == null or not is_instance_valid(cam):
		return
	if _mesh == null or not is_instance_valid(_mesh):
		_mesh = MeshInstance3D.new()
		_mesh.name = "VTKPaletteQuad"
		var quad := QuadMesh.new()
		quad.size = Vector2(2.0, 2.0)
		_mesh.mesh = quad
		# The local quad straddles the camera origin; the custom AABB keeps it
		# inside the frustum even though POSITION bypasses the camera transform.
		_mesh.custom_aabb = AABB(Vector3(-1.0, -1.0, -1.0), Vector3(2.0, 2.0, 2.0))
		_mesh.material_override = material()
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
	var mat := material()
	for i in 5:
		var c: Color = stops[i] if i < stops.size() and stops[i] is Color else Color.BLACK
		mat.set_shader_parameter("paletteStop%d" % i, c)
	mat.set_shader_parameter("paletteOut", out)
	mat.set_shader_parameter("inputGain", gain)
	mat.set_shader_parameter("inputKnee", knee)
