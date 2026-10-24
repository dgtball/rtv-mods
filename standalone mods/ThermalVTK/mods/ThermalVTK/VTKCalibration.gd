extends RefCounted
# Pure logic: the debug key-calibration sweep. No scene access, no load(), no
# paths into the game, so it runs headless (test_calibration.gd).
#
# Why a sweep: the vanilla NVG washes bright keys toward pastel/white, so the
# body-fill keys and the nomad key cannot be picked on paper -- they have to be
# MEASURED after the wash. The calibration hotkey repaints the NPCs and the
# nomad marker with a candidate, the debug probe reads the washed pixel back,
# and the measurement decides the final keys.
#
# The set is spread around the hue circle at mid value, one dominant channel
# per candidate and the other two kept low: a high sum is what washes out
# (the old nomad key (0.6,1.0,0.6) came out as (1,1,1)). Two of the
# candidates are green -- the nomad marker is the key that has to survive the
# wash best. Every pair stays more than DET_TOL_CORE (0.22) apart in raw RGB,
# so a washed candidate pixel cannot be claimed by another candidate's
# detector; the final key set still has to clear the wider 0.40 world-key
# spacing rule in the washed space (see VTKStates).

const CANDIDATES: Array[Color] = [
	Color(0.60, 0.02, 0.02),
	Color(0.55, 0.38, 0.02),
	Color(0.20, 0.55, 0.02),
	Color(0.02, 0.60, 0.24),
	Color(0.08, 0.34, 0.42),
	Color(0.02, 0.10, 0.60),
	Color(0.34, 0.02, 0.58),
	Color(0.55, 0.10, 0.32),
	Color(0.00, 0.60, 0.72),
	Color(0.00, 0.10, 0.70),
]

# Clamped index: anything outside the sweep falls back to the first candidate.
static func index_of(i: int) -> int:
	if i < 0 or i >= CANDIDATES.size():
		return 0
	return i

static func candidate(i: int) -> Color:
	var idx: int = index_of(i)
	return CANDIDATES[idx]

static func count() -> int:
	return CANDIDATES.size()

# Debug-log label: a probe reading maps back to a candidate through it.
static func label(i: int) -> String:
	var idx: int = index_of(i)
	var c: Color = CANDIDATES[idx]
	return "cand%02d=(%.2f,%.2f,%.2f)" % [idx, c.r, c.g, c.b]
