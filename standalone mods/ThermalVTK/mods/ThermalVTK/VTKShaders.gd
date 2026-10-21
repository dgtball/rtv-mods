extends RefCounted
# Builds the outline shaders. The ring has two compile-time cull variants (front
# / back faces), because render_mode is compile-time in Godot; a cache keeps one
# Shader resource per variant so materials share program state. The body has a
# single variant.

const BODY_SRC := preload("res://mods/ThermalVTK/VTKOutlineBody.gdshader")
const RING_SRC := preload("res://mods/ThermalVTK/VTKOutlineRing.gdshader")

static var _ring_cache: Dictionary = {}

static func body() -> Shader:
	return BODY_SRC

static func _with_cull(code: String, front_faces: bool) -> String:
	if not front_faces:
		return code
	return code.replace("cull_back", "cull_front")

static func ring(front_faces: bool) -> Shader:
	var key := str(front_faces)
	if _ring_cache.has(key):
		return _ring_cache[key]
	var variant := Shader.new()
	variant.code = _with_cull(RING_SRC.code, front_faces)
	_ring_cache[key] = variant
	return variant
