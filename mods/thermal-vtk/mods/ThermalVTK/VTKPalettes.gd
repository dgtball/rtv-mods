extends RefCounted
# Thermal palettes as data. One fixed ladder and one output factor; the shader
# receives the active palette's five stops as uniforms and never branches on a
# palette mode. Static-only, no scene access, no load(), so it runs headless.
#
# The colours are verbatim from the 2.4.6 overlay: classic, amber, forest, ice,
# in the same order as the old worldPaletteMode (F6 still cycles 0..3).

const LADDER: Array[float] = [0.0, 0.25, 0.5, 0.75, 1.0]
const OUTPUT := 0.7

const STOPS: Array = [
	[
		Color(0.00, 0.00, 0.03), Color(0.24, 0.10, 0.38), Color(0.65, 0.00, 0.10),
		Color(0.90, 0.65, 0.00), Color(1.00, 1.00, 0.80),
	],
	[
		Color(0.02, 0.01, 0.00), Color(0.25, 0.12, 0.02), Color(0.55, 0.30, 0.05),
		Color(0.80, 0.58, 0.18), Color(1.00, 0.92, 0.70),
	],
	[
		Color(0.00, 0.02, 0.02), Color(0.05, 0.18, 0.12), Color(0.10, 0.38, 0.22),
		Color(0.35, 0.62, 0.30), Color(0.80, 0.95, 0.65),
	],
	[
		Color(0.00, 0.01, 0.04), Color(0.05, 0.12, 0.35), Color(0.10, 0.30, 0.60),
		Color(0.40, 0.65, 0.85), Color(0.85, 0.95, 1.00),
	],
]


static func count() -> int:
	return STOPS.size()


# Clamped and copied: a profile or an F6 wrap can never fault the push, and a
# caller mutating the result cannot corrupt the table for the next frame.
static func stops(index: int) -> Array[Color]:
	var out: Array[Color] = []
	var src: Array = STOPS[clampi(index, 0, STOPS.size() - 1)]
	for c in src:
		out.append(c)
	return out


static func output() -> float:
	return OUTPUT


static func luma(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b


static func is_ascending(index: int) -> bool:
	var ramp: Array[Color] = stops(index)
	for i in range(1, ramp.size()):
		if luma(ramp[i]) <= luma(ramp[i - 1]):
			return false
	return true
