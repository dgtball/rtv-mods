extends RefCounted
# Pure colour math for the optic lens. The vanilla PIP post-pass multiplies the
# lens texture by GAIN and remaps it around mid grey with CONTRAST. Compensating
# the contour before that pass keeps its contribution at the configured colour.
# No scene state, no file paths, no load() — like VTKPicker.

const GAIN := 0.8
const CONTRAST := 0.99

static func forward(c: Color) -> Color:
	var r: float = (c.r * GAIN - 0.5) * CONTRAST + 0.5
	var g: float = (c.g * GAIN - 0.5) * CONTRAST + 0.5
	var b: float = (c.b * GAIN - 0.5) * CONTRAST + 0.5
	return Color(r, g, b, c.a)

static func inverse(c: Color) -> Color:
	var r: float = clampf(((c.r - 0.5) / CONTRAST + 0.5) / GAIN, 0.0, 1.0)
	var g: float = clampf(((c.g - 0.5) / CONTRAST + 0.5) / GAIN, 0.0, 1.0)
	var b: float = clampf(((c.b - 0.5) / CONTRAST + 0.5) / GAIN, 0.0, 1.0)
	return Color(r, g, b, c.a)
