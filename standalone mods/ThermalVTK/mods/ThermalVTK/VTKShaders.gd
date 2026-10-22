extends RefCounted
# Builds the outline shaders. One ring shader (the silhouette), a plain
# resource shared by every NPC material.

const RING_SRC := preload("res://mods/ThermalVTK/VTKOutlineRing.gdshader")
const RING_SCOPE_SRC := preload("res://mods/ThermalVTK/VTKOutlineRingScope.gdshader")

static func ring() -> Shader:
	return RING_SRC

# Same uniform set as ring(); swaps in while the scope view is active.
static func ring_scope() -> Shader:
	return RING_SCOPE_SRC
