extends RefCounted
# Builds the outline shaders. The .gdshader files carry the through-walls
# variant (depth_test_disabled); the LOS variant is the same code with that one
# token removed, because render_mode is compile-time in Godot. Caching keeps a
# single Shader resource per variant so materials share program state.

const BODY_SRC := preload("res://mods/ThermalVTK/VTKOutlineBody.gdshader")
const RING_SRC := preload("res://mods/ThermalVTK/VTKOutlineRing.gdshader")

static var _body_wall: Shader = null
static var _body_los: Shader = null
static var _ring_wall: Shader = null
static var _ring_los: Shader = null

static func strip_depth_test(code: String) -> String:
	return code.replace("depth_test_disabled, ", "")

static func _ensure() -> void:
	if _body_wall != null:
		return
	_body_wall = BODY_SRC
	var los_body := Shader.new()
	los_body.code = strip_depth_test(BODY_SRC.code)
	_body_los = los_body
	_ring_wall = RING_SRC
	var los_ring := Shader.new()
	los_ring.code = strip_depth_test(RING_SRC.code)
	_ring_los = los_ring

static func body(through_walls: bool) -> Shader:
	_ensure()
	return _body_wall if through_walls else _body_los

static func ring(through_walls: bool) -> Shader:
	_ensure()
	return _ring_wall if through_walls else _ring_los
