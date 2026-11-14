extends RefCounted
# Builds the contour overlay shaders. The ring and the body fill are chained
# through material_overlay (the NPCESP_ex approach): the body pass writes the
# stencil, the ring pass reads it and draws the band, and the NVG overlay
# substitutes the display colour from the category key the main pass wrote,
# so no key has to survive the tonemap.

const MASK_RING_SRC := preload("res://mods/ThermalVTK/VTKEspMaskRing.gdshader")
const MASK_FILL_SRC := preload("res://mods/ThermalVTK/VTKEspMaskFill.gdshader")
const MASK_XRAY_SRC := preload("res://mods/ThermalVTK/VTKEspMaskXray.gdshader")

static func mask_ring() -> Shader:
	return MASK_RING_SRC

static func mask_fill() -> Shader:
	return MASK_FILL_SRC

static func mask_xray() -> Shader:
	return MASK_XRAY_SRC
