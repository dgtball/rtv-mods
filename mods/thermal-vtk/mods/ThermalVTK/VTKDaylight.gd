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
# The vanilla NVG raises exposure to 2.0/2.5/3.0 by power tier. The palette is
# normalised to the lowest tier, so the picture no longer changes with the
# setting; higher tiers only brighten, so the gain only ever comes down.
const EXPOSURE_REF := 2.0
# Uncompensated frame level the ceiling releases the factor to. Below the
# measured day reference 0.151 (so the ceiling is guaranteed silent by day)
# and above the measured cave frame 0.031 (so it is guaranteed to speak in a
# cave).
const DAY_LEVEL := 0.10
# Division guard for `u` and the ceiling. Not a "no measurement" guard: that
# one lives in VTKNVG, which never computes a ceiling without a frame.
const EPS := 0.0001
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
# Cadence of the frame probe that feeds the ceiling (the panel's `Probe
# cadence` lever).
const FRAME_CADENCE := 1.0
# Adaptive auto-probe cadence (source B): while the measured frame level holds
# still for PROBE_STABLE_FRAMES frames within PROBE_STABLE_TOL, the cadence
# doubles up to PROBE_MAX_MULT x base -- a quiet scene needs no GPU sync per base
# beat anymore -- and a frame change restarts the run at the base.
const PROBE_GROWTH := 2.0
const PROBE_MAX_MULT := 4.0
const PROBE_STABLE_TOL := 0.005
const PROBE_STABLE_FRAMES := 2

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
# sky WHITE, so a naive sum would read a bright sky through a roof. The terms
# come unweighted from estimate_terms() -- the W_* weights are applied here,
# so the panel can show each term's raw contribution.
static func estimate_light(snap: Dictionary) -> float:
	var t := estimate_terms(snap)
	return W_SKY * float(t["sky"]) + W_AMB * float(t["amb"]) + W_SUN * float(t["sun"]) + W_MOON * float(t["moon"]) + W_FOG * float(t["fog"])

# The same sum split into its five terms {sky, amb, sun, moon, fog}. The
# shelter/intro short circuit lives here so estimate_light stays a plain sum.
static func estimate_terms(snap: Dictionary) -> Dictionary:
	if bool(snap.get("shelter", false)) or bool(snap.get("intro", false)):
		return {"sky": 0.0, "amb": 0.0, "sun": 0.0, "moon": 0.0, "fog": 0.0}
	var sky := lum(snap.get("sky_color", Color.BLACK)) * float(snap.get("background_energy", 1.0))
	var amb := lum(snap.get("ambient_color", Color.BLACK)) * float(snap.get("ambient_energy", 1.0))
	var sun := lum(snap.get("sun_color", Color.BLACK)) * float(snap.get("sun_energy", 0.0))
	if int(snap.get("sun_mask", 0)) == 0:
		sun = 0.0
	var moon := lum(snap.get("moon_color", Color.BLACK)) * float(snap.get("moon_energy", 0.0))
	if int(snap.get("moon_mask", 0)) == 0:
		moon = 0.0
	var fog := lum(snap.get("fog_emission", Color.BLACK)) * float(snap.get("fog_density", 0.0))
	return {"sky": sky, "amb": amb, "sun": sun, "moon": moon, "fog": fog}

# Uncompensated frame level: the probe sees the frame through the game's
# Environment, our applied exposure included, so the measurement must be
# divided by `applied` (the current smoothed _day_factor) -- otherwise the
# loop catches itself. The division is guarded by EPS: a zero measurement
# gives u -> 0 and the ceiling pins at 1.0, which is why the "no measurement"
# guard lives in VTKNVG, not here.
static func frame_ceiling(measured: float, applied: float, level := DAY_LEVEL, floor_value := FLOOR) -> float:
	var u := measured / maxf(applied, EPS)
	return clampf(level / maxf(u, EPS), floor_value, 1.0)

# Night gate: the sun is culled -> vanilla exposure. One line, but it is the
# single place "night = vanilla" lives (and the one its test targets).
static func night_gate(factor: float, sun_down: bool) -> float:
	return 1.0 if sun_down else factor

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
# same day mix that drives the palette.
#
# The trim runs for the whole winter season, interiors and shelters included.
# It used to duck out under a roof, and since the value is pushed straight into
# the shader an `indoor` flip stepped the background by 40-50% on a doorway --
# a visible pop, not a trim. With no `indoor`/`shelter` input the step cannot
# come back. The cost is accepted: winter interiors and shelters are darker
# than they were, by the same factor the outdoors already was. The constants
# themselves were not recalibrated here.
#
# `factor` is the effective exposure factor: in dim/overcast winter days the
# strong bright-snow compression (trim_day) crushes mids, so the day target
# eases back toward trim_night as the scene gets dimmer (factor lifted above
# the bright-day TARGET by the ceiling).
static func snow_trim(season: int, mix: float, trim_night := SNOW_TRIM_NIGHT, trim_day := SNOW_TRIM_DAY, factor := FLOOR) -> float:
	if season != SEASON_WINTER:
		return 1.0
	var m := clampf(mix, 0.0, 1.0)
	var dim := clampf((factor - TARGET) / maxf(1.0 - TARGET, 0.001), 0.0, 1.0)
	var day := lerpf(trim_day, trim_night, dim)
	return lerpf(trim_night, day, m)

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
# model in full. Everything downstream (gain, day mix) must use this one
# effective factor, or the palette drifts from the exposure.
static func strength_factor(factor: float, strength: float) -> float:
	return lerpf(1.0, factor, clampf(strength, 0.0, 1.0))

# Exposure tiers above the reference only brighten the frame. Folding that
# into the input gain keeps the palette identical across power tiers while the
# mod never writes Environment.tonemap_exposure. Guards cover a missing or
# broken value from the game; a tier below the reference changes nothing.
static func exposure_norm(exposure: float) -> float:
	if not is_finite(exposure) or exposure <= 0.0:
		return 1.0
	return clampf(EXPOSURE_REF / exposure, 0.1, 1.0)

# One-pole smoothing; `delta` is the frame time.
static func step(current: float, target: float, delta: float, response: float = RESPONSE) -> float:
	if response <= 0.0:
		return target
	var k := 1.0 - exp(-maxf(delta, 0.0) / response)
	return lerpf(current, target, clampf(k, 0.0, 1.0))


# The cadence for the next auto measurement of the frame probe. While the frame
# run is still younger than PROBE_STABLE_FRAMES the base wins; afterwards the
# interval doubles, capped at base x PROBE_MAX_MULT. Pure inputs, so the whole
# adaptive decision lives in this module and stays headless-testable.
static func adaptive_interval(base: float, stable: int, interval: float) -> float:
	if base <= 0.0 or interval <= 0.0:
		return 0.0
	if stable < PROBE_STABLE_FRAMES:
		return base
	return minf(interval * PROBE_GROWTH, base * PROBE_MAX_MULT)

