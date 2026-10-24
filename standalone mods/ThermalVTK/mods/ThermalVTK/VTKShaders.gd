extends RefCounted
# Builds the outline shaders. The idle ring uses the normal depth test so the
# world, the weapon and the sight hardware clip it; the x-ray ring swaps to the
# depth-free variant only while a trigger window is live.

const RING_DEPTH_SRC := preload("res://mods/ThermalVTK/VTKOutlineRingDepth.gdshader")
const RING_XRAY_SRC := preload("res://mods/ThermalVTK/VTKOutlineRingOccluded.gdshader")

static func ring() -> Shader:
	return RING_DEPTH_SRC

static func ring_xray() -> Shader:
	return RING_XRAY_SRC
