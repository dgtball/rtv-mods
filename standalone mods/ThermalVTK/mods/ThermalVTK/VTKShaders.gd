extends RefCounted
# Builds the outline shaders. One ring shader serves both modes: the x-ray
# flag and the camera-attached carve (the metres in front of the camera that
# never hide the ring) live in uniforms, so the runtime flip never loses state
# and a retune is a parameter change, not a second resource.

const RING_OCCLUDED_SRC := preload("res://mods/ThermalVTK/VTKOutlineRingOccluded.gdshader")

static func ring() -> Shader:
	return RING_OCCLUDED_SRC
