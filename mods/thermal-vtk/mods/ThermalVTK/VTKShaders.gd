extends RefCounted
# Builds the direct-color stencil contour shaders. The body pass writes the
# stencil and can render the silhouette fill; the ring pass reads the stencil
# and draws only the grown band outside the body.
#
# Key shader variants remain available for legacy/substitution paths still
# referenced elsewhere until later migration tasks remove them.

const BODY_LOS_SRC := preload("res://mods/ThermalVTK/VTKEspBody.gdshader")
const BODY_XRAY_SRC := preload("res://mods/ThermalVTK/VTKEspBodyXray.gdshader")
const RING_LOS_SRC := preload("res://mods/ThermalVTK/VTKEspRing.gdshader")
const RING_XRAY_SRC := preload("res://mods/ThermalVTK/VTKEspRingXray.gdshader")

const BODY_LOS_KEY_SRC := preload("res://mods/ThermalVTK/VTKEspBodyKey.gdshader")
const BODY_XRAY_KEY_SRC := preload("res://mods/ThermalVTK/VTKEspBodyXrayKey.gdshader")
const RING_LOS_KEY_SRC := preload("res://mods/ThermalVTK/VTKEspRingKey.gdshader")
const RING_XRAY_KEY_SRC := preload("res://mods/ThermalVTK/VTKEspRingXrayKey.gdshader")

static func body_los() -> Shader:
	return BODY_LOS_SRC

static func body_xray() -> Shader:
	return BODY_XRAY_SRC

static func ring_los() -> Shader:
	return RING_LOS_SRC

static func ring_xray() -> Shader:
	return RING_XRAY_SRC

static func body_los_key() -> Shader:
	return BODY_LOS_KEY_SRC

static func body_xray_key() -> Shader:
	return BODY_XRAY_KEY_SRC

static func ring_los_key() -> Shader:
	return RING_LOS_KEY_SRC

static func ring_xray_key() -> Shader:
	return RING_XRAY_KEY_SRC

