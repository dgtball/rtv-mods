extends Node
## Two fullscreen spatial quads that palettize the 3D view.
##
## Godot copies the screen texture after opaque geometry and never includes
## transparent materials in that copy. One opaque quad at -128 palettizes the
## world; a second, semi-transparent quad at 12 blends the same palette over
## the transparent optic picture drawn between them (priorities 0/11). Exact-
## colour ESP contours and mine shells draw afterwards at 20/21. Both meshes
## are parented to the current camera and their vertex shader writes clip
## space directly, so they always cover the viewport and are never culled.

const Shaders = preload("res://mods/ThermalVTK/VTKShaders.gd")
const TINT_ALPHA := 0.35

var _mesh: MeshInstance3D = null
var _mat: ShaderMaterial = null
var _tint_mesh: MeshInstance3D = null
var _tint_mat: ShaderMaterial = null


func material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = Shaders.palette()
		# First pass: the opaque world is palettized in full, as before.
		_mat.render_priority = -128
		_mat.set_shader_parameter("paletteAlpha", 1.0)
	return _mat


func tint_material() -> ShaderMaterial:
	if _tint_mat == null:
		_tint_mat = ShaderMaterial.new()
		_tint_mat.shader = Shaders.palette()
		# After vanilla optics (0/11) so the sight picks up the palette,
		# before exact-colour ESP/mines (20/21) so they keep their colours.
		_tint_mat.render_priority = 12
		_tint_mat.set_shader_parameter("paletteAlpha", TINT_ALPHA)
	return _tint_mat


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
	if _tint_mesh == null or not is_instance_valid(_tint_mesh):
		_tint_mesh = _make_mesh("VTKPaletteQuadTint", tint_material())
	_attach_one(cam, _mesh)
	_attach_one(cam, _tint_mesh)


func _attach_one(cam: Camera3D, mesh: MeshInstance3D) -> void:
	if mesh.get_parent() == cam:
		return
	var parent := mesh.get_parent()
	if parent != null:
		parent.remove_child(mesh)
	cam.add_child(mesh)


func set_enabled(on: bool) -> void:
	if _mesh != null and is_instance_valid(_mesh):
		_mesh.visible = on
	if _tint_mesh != null and is_instance_valid(_tint_mesh):
		_tint_mesh.visible = on


func apply(stops: Array, out: float, gain: float, knee: float) -> void:
	_push(material(), stops, out, gain, knee, 1.0)
	_push(tint_material(), stops, out, gain, knee, TINT_ALPHA)


func _push(mat: ShaderMaterial, stops: Array, out: float, gain: float, knee: float, alpha: float) -> void:
	for i in 5:
		var c: Color = stops[i] if i < stops.size() and stops[i] is Color else Color.BLACK
		mat.set_shader_parameter("paletteStop%d" % i, c)
	mat.set_shader_parameter("paletteOut", out)
	mat.set_shader_parameter("inputGain", gain)
	mat.set_shader_parameter("inputKnee", knee)
	mat.set_shader_parameter("paletteAlpha", alpha)
