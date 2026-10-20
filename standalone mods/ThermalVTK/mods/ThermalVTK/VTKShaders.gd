extends RefCounted
# Builds the outline shaders. The .gdshader files carry the through-walls
# variant (depth_test_disabled); the LOS variant is the same code with that one
# token removed, because render_mode is compile-time in Godot. Caching keeps a
# single Shader resource per variant so materials share program state.

const BODY_SRC := preload("res://mods/ThermalVTK/VTKOutlineBody.gdshader")
const RING_SRC := preload("res://mods/ThermalVTK/VTKOutlineRing.gdshader")

static var _body_wall: Shader = null
static var _body_los: Shader = null
static var _ring_cache: Dictionary = {}

static func strip_depth_test(code: String) -> String:
	return code.replace("depth_test_disabled, ", "")

static func _ensure() -> void:
	if _body_wall != null:
		return
	_body_wall = BODY_SRC
	var los_body := Shader.new()
	los_body.code = strip_depth_test(BODY_SRC.code)
	_body_los = los_body

static func body(through_walls: bool) -> Shader:
	_ensure()
	return _body_wall if through_walls else _body_los

static func _with_cull(code: String, front_faces: bool) -> String:
	if not front_faces:
		return code
	return code.replace("cull_back", "cull_front")

static func ring(through_walls: bool, front_faces: bool) -> Shader:
	_ensure()
	var key := "%s_%s" % [str(through_walls), str(front_faces)]
	if _ring_cache.has(key):
		return _ring_cache[key]
	var variant := Shader.new()
	var code := _with_cull(RING_SRC.code, front_faces)
	if not through_walls:
		code = strip_depth_test(code)
	variant.code = code
	_ring_cache[key] = variant
	return variant
