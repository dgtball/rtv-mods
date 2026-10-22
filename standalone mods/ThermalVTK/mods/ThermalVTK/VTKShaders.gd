extends RefCounted
# Builds the outline shaders. One ring shader (the silhouette), a plain
# resource shared by every NPC material.

const RING_SRC := preload("res://mods/ThermalVTK/VTKOutlineRing.gdshader")

static func ring() -> Shader:
	return RING_SRC
