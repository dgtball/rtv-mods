extends RefCounted
# Builds the outline shaders. Two ring shaders that share the uniform set:
# the x-ray one (default) and the depth-tested one.

const RING_SRC := preload("res://mods/ThermalVTK/VTKOutlineRing.gdshader")
const RING_OCCLUDED_SRC := preload("res://mods/ThermalVTK/VTKOutlineRingOccluded.gdshader")

static func ring(xray: bool = true) -> Shader:
	return RING_SRC if xray else RING_OCCLUDED_SRC
