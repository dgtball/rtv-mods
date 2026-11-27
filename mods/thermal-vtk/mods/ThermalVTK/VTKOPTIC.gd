extends RefCounted
# Pure colour math for the optic lens. The vanilla PIP post-pass multiplies the
# lens texture by GAIN and remaps it around mid grey with CONTRAST. Compensating
# the contour before that pass keeps its contribution at the configured colour.
# Godot renders in linear space and `source_color` uniforms convert sRGB values,
# so the forward/inverse math lives in linear light and only compensate() crosses
# the sRGB boundary. No scene state, no file paths, no load() — like VTKPicker.

const GAIN := 0.8
const CONTRAST := 0.99

static func forward(c: Color) -> Color:
	var r: float = (c.r * GAIN - 0.5) * CONTRAST + 0.5
	var g: float = (c.g * GAIN - 0.5) * CONTRAST + 0.5
	var b: float = (c.b * GAIN - 0.5) * CONTRAST + 0.5
	return Color(r, g, b, c.a)

static func inverse(c: Color) -> Color:
	var r: float = maxf(((c.r - 0.5) / CONTRAST + 0.5) / GAIN, 0.0)
	var g: float = maxf(((c.g - 0.5) / CONTRAST + 0.5) / GAIN, 0.0)
	var b: float = maxf(((c.b - 0.5) / CONTRAST + 0.5) / GAIN, 0.0)
	# A channel above 1 cannot be sent through an 8-bit colour, but clamping it
	# alone would change the hue. Scaling every channel keeps their ratios.
	var peak: float = maxf(r, maxf(g, b))
	if peak > 1.0:
		r /= peak
		g /= peak
		b /= peak
	return Color(r, g, b, c.a)

# sRGB colour authored in VTKStates -> sRGB colour to hand to a
# `uniform vec3 : source_color`. The shader converts it back to linear light,
# where the vanilla PIP pass sees the inverse of the target colour.
static func compensate(c: Color) -> Color:
	var linear: Color = c.srgb_to_linear()
	return inverse(linear).linear_to_srgb()
