extends RefCounted
# Pure daylight model for NVG exposure compensation. No scene access, no
# load(), no paths into the game, so it runs headless (test_daylight.gd).
#
# The vanilla NVG raises Environment.tonemap_exposure to 2.0/2.5/3.0 whenever
# the helmet is worn. That is tuned for darkness: in daylight the frame hits
# the top of the tonemap curve and snow/sky turn into a white field.
#
# The model normalises the LEVEL of the frame, not a guessed time-of-day: the
# game's own light state is folded into one scalar E (roughly the median
# luminance the scene would have), and the exposure is scaled by
# `factor = clamp(TARGET / E, FLOOR, 1.0)`. Every daytime scene -- clear noon,
# overcast, fog, snow, dusk -- then lands on the same palette position, and
# the compensation is one-sided: it only ever LOWERS the exposure, so night
# (E <= TARGET) is exactly vanilla.

const TARGET := 0.22
const FLOOR := 0.12
# Winter background trim. Night is the 2026-10-24 Minefield snow-field
# measurement; day is fitted 2026-11-11 from the owner's PANEL measurements
# (winter noon snow field, raw p50 0.679) so the winter day palette sits
# mid-ladder beside summer instead of pinned on the cream ceiling.
const SNOW_TRIM_DAY := 0.48
const SNOW_TRIM_NIGHT := 0.60
# Daylight highlight trim, calibrated 2026-11-11 from the owner's PANEL
# measurements. 0.62 (solved 0.6217, rounded) puts the summer-noon palette
# p50 at 0.489 with p95 0.958 under the 0.97 cream line, keeps the darkest
# passing scene (street seen from a window) at p50 0.363 above the 0.35
# floor, and leaves the night picture untouched -- day_trim(0) is 1.0 by
# construction.
const DAY_TRIM := 0.62

const RESPONSE := 1.5
# Feedback loop (source B): how hard a measured frame pulls the factor.
const FEEDBACK_GAIN := 0.6
# Target raw p50 of the frame for the measured-frame source, and its cadence.
const FRAME_TARGET := 0.47
const FRAME_CADENCE := 1.0

# Weights of the source-A light terms. Unit for now: the fit against the
# owner's PANEL measurements is a follow-up commit, so the instrument starts
# from an unweighted sum.
const W_SKY := 1.0
const W_AMB := 1.0
const W_SUN := 1.0
const W_MOON := 1.0
const W_FOG := 1.0

# The game ships two seasons and the sim field is binary: 1 summer, 2 winter.
# Vostok Toolkit maps its four seasons onto the same field (VTKSeasonDriver.gd:56
# writes 2 for winter and 1 for everything else), so ThermalVTK stays correct
# with and without the toolkit installed.
const SEASON_SUMMER := 1
const SEASON_WINTER := 2

# Luminance weights, copied from VTKNVG.gdshader's rawLuminance dot product.
# The shader is the source of truth for what the player sees, so the model
# folds the same quantity the instrument measures.
static func lum(c: Variant) -> float:
	if not (c is Color):
		return 0.0
	var col: Color = c
	return 0.299 * col.r + 0.587 * col.g + 0.114 * col.b

# The compensation factor for a scene whose level is `e`. One-sided: at or
# below TARGET the vanilla exposure stays (1.0), above it the factor drops
# toward FLOOR. A non-positive `e` is night, never a division by zero.
static func factor_for_light(e: float, target := TARGET, floor_value := FLOOR) -> float:
	if e <= 0.0:
		return 1.0
	return clampf(target / e, floor_value, 1.0)

# Fold the game's light state into one level scalar. The snapshot keys and
# their defaults are the contract with VTKNVG._snapshot. Shelter and intro
# short-circuit to zero: World.Static() blacks the ambient out but makes the
# sky WHITE, so a naive sum would read a bright sky through a roof.
static func estimate_light(snap: Dictionary) -> float:
	if bool(snap.get("shelter", false)) or bool(snap.get("intro", false)):
		return 0.0
	var sky := lum(snap.get("sky_color", Color.BLACK)) * float(snap.get("background_energy", 1.0))
	var amb := lum(snap.get("ambient_color", Color.BLACK)) * float(snap.get("ambient_energy", 1.0))
	var sun := lum(snap.get("sun_color", Color.BLACK)) * float(snap.get("sun_energy", 0.0))
	if int(snap.get("sun_mask", 0)) == 0:
		sun = 0.0
	var moon := lum(snap.get("moon_color", Color.BLACK)) * float(snap.get("moon_energy", 0.0))
	if int(snap.get("moon_mask", 0)) == 0:
		moon = 0.0
	var fog := lum(snap.get("fog_emission", Color.BLACK)) * float(snap.get("fog_density", 0.0))
	return W_SKY * sky + W_AMB * amb + W_SUN * sun + W_MOON * moon + W_FOG * fog

# Source B: one step of the measured-frame loop. A frame on target holds the
# factor; a brighter frame lowers it; a darker one raises it, but never above
# 1.0 (the clamp, not the step direction, is what keeps it one-sided). A
# blank or non-finite measurement leaves the factor alone.
static func feedback_factor(factor: float, measured: float, target_l: float, gain := FEEDBACK_GAIN) -> float:
	if measured <= 0.0 or not is_finite(measured):
		return 1.0
	return clampf(factor * pow(target_l / measured, gain), FLOOR, 1.0)

# Winter-only background trim for the thermal palette. Snow bounces far more
# amplified light than any summer surface, so the whole winter frame lands in
# the red-to-cream third of the palette: probes measured night dirt at
# luminance 0.365 (t 0.62, red) and bright snow at 0.559 (t 0.95, cream) --
# no cold colors left on screen. The trim multiplies the effective
# thermalDarken so the same range re-spreads down the ladder: at night 0.60
# the dirt reads t 0.37 (purple) and the snow tops out near t 0.57 (amber);
# by day 0.48 (2026-11-11 calibration, riding DAY_TRIM 0.62) the noon snow
# field reads p50 0.49 mid-ladder instead of pinned on the ceiling. Keys
# are unaffected: substitution happens before the palette. Blended by the
# same day mix that drives the palette, 1.0 everywhere else.
static func snow_trim(season: int, indoor: bool, shelter: bool, mix: float, trim_night := SNOW_TRIM_NIGHT, trim_day := SNOW_TRIM_DAY) -> float:
	if season != SEASON_WINTER or indoor or shelter:
		return 1.0
	return lerpf(trim_night, trim_day, clampf(mix, 0.0, 1.0))

# Daylight background trim: blends toward `day` by the day mix, the same mix
# the shader sees. The ends are what matter: night stays 1.0 (palette
# untouched), full day applies the trim in full. DAY_TRIM = 0.62 is the
# 2026-11-11 calibration; see the constant block for the scenes it was fitted
# against.
static func day_trim(mix: float, day := DAY_TRIM) -> float:
	return lerpf(1.0, day, clampf(mix, 0.0, 1.0))

# 0 at night, 1 at full daylight: how hard the shader tone curve should lift
# the background before the thermal palette. The denominator is guarded: a
# target of 1.0 must yield 0.0, not NaN.
static func day_mix(factor: float, target := TARGET) -> float:
	var d := maxf(1.0 - target, 0.05)
	return clampf((1.0 - factor) / d, 0.0, 1.0)

# Daylight strength: 0 leaves the vanilla exposure untouched, 1 applies the
# model in full. Everything downstream (exposure, key gain, day mix) must use
# this one effective factor, or the ring colour drifts from the exposure.
static func strength_factor(factor: float, strength: float) -> float:
	return lerpf(1.0, factor, clampf(strength, 0.0, 1.0))

# Restores a key's pre-tonemap radiance: exposure is multiplied by `factor`,
# so the emitted key is divided by it. At alpha 1 the on-screen key is then
# exactly the night-time value, which keeps the detector calibration valid.
static func key_gain(factor: float) -> float:
	return 1.0 / maxf(factor, 0.01)

# One-pole smoothing; `delta` is the frame time.
static func step(current: float, target: float, delta: float, response: float = RESPONSE) -> float:
	if response <= 0.0:
		return target
	var k := 1.0 - exp(-maxf(delta, 0.0) / response)
	return lerpf(current, target, clampf(k, 0.0, 1.0))

# Mirror of the thermal branch in VTKNVG.gdshader: hiShoulder over the
# unclamped raw luminance, the clamp, then the soft lift. The shader is the
# SOURCE OF TRUTH -- copy it verbatim, no extra clamps of our own, because
# the instrument must agree with the shader even in its sharp corners. When
# the shader changes, this mirror and its control-point tests move in the
# same commit.
static func palette_input(raw_l: float, darken: float, knee: float, mix_value: float) -> float:
	var k := lerpf(1.0, knee, mix_value)
	var x := raw_l * darken
	if k < 0.999 and x > k:
		var slope := 0.75
		var top := k + slope * (1.0 - k)
		var cap := minf(0.98, top + 0.18)
		if x <= 1.0:
			x = k + (x - k) * slope
		else:
			x = top + (cap - top) * (1.0 - exp(-(x - 1.0) * slope / (cap - top)))
	var lum := clampf(x, 0.0, 1.0)
	if mix_value > 0.0:
		var lifted := 1.0 - pow(1.0 - lum, 1.6)
		lum = lerpf(lum, lifted, mix_value)
	return lum
