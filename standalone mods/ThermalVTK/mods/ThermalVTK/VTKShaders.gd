extends RefCounted
# Builds the outline shaders. One ring shader (the silhouette): it ignores the
# depth buffer permanently, so the contour reads through walls and scopes.

const RING_SRC := preload("res://mods/ThermalVTK/VTKOutlineRing.gdshader")

static func ring() -> Shader:
	return RING_SRC
