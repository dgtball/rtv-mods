extends RefCounted
# Builds the outline shaders. The idle ring uses the normal depth test so the
# world, the weapon and the sight hardware clip it; the x-ray ring swaps to the
# depth-free variant only while a trigger window is live.

const RING_DEPTH_SRC := preload("res://mods/ThermalVTK/VTKOutlineRingDepth.gdshader")
const RING_XRAY_SRC := preload("res://mods/ThermalVTK/VTKOutlineRingOccluded.gdshader")
# Full-body style: body pass writes stencil 1, ring pass draws outside it.
const BODY_FILL_SRC := preload("res://mods/ThermalVTK/VTKOutlineBodyFill.gdshader")
const RING_STENCIL_SRC := preload("res://mods/ThermalVTK/VTKOutlineRingStencil.gdshader")

static func ring() -> Shader:
	return RING_DEPTH_SRC

static func ring_xray() -> Shader:
	return RING_XRAY_SRC

static func body_fill() -> Shader:
	return BODY_FILL_SRC

static func ring_stencil() -> Shader:
	return RING_STENCIL_SRC
