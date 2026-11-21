extends RefCounted
# Builds the direct-color stencil contour shaders. The body pass writes the
# stencil and can render the silhouette fill; the ring pass reads the stencil
# and draws only the grown band outside the body.

const BODY_LOS_SRC := preload("res://mods/ThermalVTK/VTKEspBody.gdshader")
const BODY_XRAY_SRC := preload("res://mods/ThermalVTK/VTKEspBodyXray.gdshader")
const RING_LOS_SRC := preload("res://mods/ThermalVTK/VTKEspRing.gdshader")
const RING_XRAY_SRC := preload("res://mods/ThermalVTK/VTKEspRingXray.gdshader")
const OCCLUDER_SRC := preload("res://mods/ThermalVTK/VTKEspOccluder.gdshader")

static func body_los() -> Shader:
	return BODY_LOS_SRC

static func body_xray() -> Shader:
	return BODY_XRAY_SRC

static func ring_los() -> Shader:
	return RING_LOS_SRC

static func ring_xray() -> Shader:
	return RING_XRAY_SRC

# Invisible world copy drawn into the ESP buffer only to write depth before the
# contour shells. Keeping it here puts every shader artifact in one store.
static func occluder() -> Shader:
	return OCCLUDER_SRC

