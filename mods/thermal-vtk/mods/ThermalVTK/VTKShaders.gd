extends RefCounted
# Builds the ESP mask shaders. The ring and the body fill write a category
# colour into the mask viewport (VTKEspMask.gd); the NVG overlay substitutes
# the display colour from that mask, so no key has to survive the tonemap.

const MASK_RING_SRC := preload("res://mods/ThermalVTK/VTKEspMaskRing.gdshader")
const MASK_FILL_SRC := preload("res://mods/ThermalVTK/VTKEspMaskFill.gdshader")
const MASK_XRAY_SRC := preload("res://mods/ThermalVTK/VTKEspMaskXray.gdshader")

static func mask_ring() -> Shader:
	return MASK_RING_SRC

static func mask_fill() -> Shader:
	return MASK_FILL_SRC

static func mask_xray() -> Shader:
	return MASK_XRAY_SRC
