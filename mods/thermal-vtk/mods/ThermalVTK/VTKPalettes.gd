extends RefCounted
# Thermal palettes as data. One fixed ladder and one output factor; the shader
# receives the active palette's five stops as uniforms and never branches on a
# palette mode. Static-only, no scene access, no load(), so it runs headless.
#
# Classic is verbatim from the 2.4.6 overlay. Amber, forest and ice keep that
# five-stop ladder but shift the hot stops in hue at equal luminance, so heat
# reads as a colour change instead of only a brightness change. Order matches
# the old worldPaletteMode (F6 still cycles 0..3).

const LADDER: Array[float] = [0.0, 0.25, 0.5, 0.75, 1.0]
const OUTPUT := 0.7

const STOPS: Array = [
	[
		Color(0.00, 0.00, 0.03), Color(0.24, 0.10, 0.38), Color(0.65, 0.00, 0.10),
		Color(0.90, 0.65, 0.00), Color(1.00, 1.00, 0.80),
	],
	[
		Color(0.02, 0.01, 0.00), Color(0.32, 0.08, 0.01), Color(0.90, 0.12, 0.02),
		Color(0.93, 0.55, 0.05), Color(1.00, 0.94, 0.62),
	],
	[
		Color(0.00, 0.02, 0.02), Color(0.02, 0.20, 0.12), Color(0.20, 0.34, 0.08),
		Color(0.55, 0.56, 0.12), Color(1.00, 0.90, 0.42),
	],
	[
		Color(0.00, 0.01, 0.04), Color(0.16, 0.07, 0.38), Color(0.42, 0.14, 0.62),
		Color(0.85, 0.45, 0.78), Color(0.95, 0.92, 0.85),
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
