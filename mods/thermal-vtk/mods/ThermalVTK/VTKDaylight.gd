extends RefCounted
# Pure daylight model for NVG exposure compensation. No scene access, no
# load(), no paths into the game, so it runs headless (test_daylight.gd).
#
# The vanilla NVG raises Environment.tonemap_exposure to 2.0/2.5/3.0 whenever
# the helmet is worn. That is tuned for darkness: in daylight the frame hits
# the top of the tonemap curve and snow/sky turn into a white field. The model
# turns the world's light level into a multiplier for that exposure and a
# matching key gain, so the detector keys keep their night-time on-screen
# colour while the background stops clipping.

const MIN_FACTOR := 0.22
const RESPONSE := 1.5
const INDOOR_FACTOR := 0.15
# A blocked sky ray: roof, canopy or deep shadow. Softer than an interior.
const COVER_FACTOR := 0.45
const SNOW_BONUS := 0.15
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

const WEATHER_FACTORS := {
	"Neutral": 1.0,
	"Overcast": 0.65,
	"Rain": 0.55,
	"Storm": 0.45,
}

# The game ships two seasons and the sim field is binary: 1 summer, 2 winter.
# Vostok Toolkit maps its four seasons onto the same field (VTKSeasonDriver.gd:56
# writes 2 for winter and 1 for everything else), so ThermalVTK stays correct
# with and without the toolkit installed.
const SEASON_SUMMER := 1
const SEASON_WINTER := 2

# 0..1 daylight, with sunrise/sunset moved for the winter season.
static func sun_level(time: float, season: int = SEASON_SUMMER) -> float:
	var dawn_a := 5.0
	var dawn_b := 8.0
	var dusk_a := 19.0
	var dusk_b := 22.0
	if season == SEASON_WINTER:
		dawn_a = 7.0
		dawn_b = 9.0
		dusk_a = 16.0
		dusk_b = 19.0
	var hours := fmod(maxf(time, 0.0), 2400.0) / 100.0
	var rise := smoothstep(dawn_a, dawn_b, hours)
	var fall := 1.0 - smoothstep(dusk_a, dusk_b, hours)
	return clampf(rise * fall, 0.0, 1.0)

static func weather_factor(weather: String) -> float:
	return float(WEATHER_FACTORS.get(weather, 1.0))

static func light_level(time: float, weather: String, season: int, indoor: bool, shelter: bool, covered: bool = false) -> float:
	var light := sun_level(time, season) * weather_factor(weather)
	if indoor or shelter:
		light *= INDOOR_FACTOR
	elif covered:
		# Under a roof or in deep shade there is no open sky to bounce snow
		# light, so the winter bonus stays out of this branch.
		light *= COVER_FACTOR
	elif season == SEASON_WINTER:
		# Snow bounces daylight, it does not create any: scale the current
		# light so winter midnight stays exactly as dark as summer midnight.
		light = minf(1.0, light * (1.0 + SNOW_BONUS))
	return clampf(light, 0.0, 1.0)

# 1.0 at night (vanilla exposure untouched), MIN_FACTOR at full daylight.
# The floor rides as a tail argument so the live panel can probe it without
# touching the shipped default.
static func day_factor(light: float, floor_value := MIN_FACTOR) -> float:
	return lerpf(1.0, floor_value, clampf(light, 0.0, 1.0))

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
# same light level that drives exposure, 1.0 everywhere else.
static func snow_trim(season: int, indoor: bool, shelter: bool, light: float, trim_night := SNOW_TRIM_NIGHT, trim_day := SNOW_TRIM_DAY) -> float:
	if season != SEASON_WINTER or indoor or shelter:
		return 1.0
	return lerpf(trim_night, trim_day, clampf(light, 0.0, 1.0))

# Daylight background trim: blends toward `day` by RAW light, the same blend
# snow_trim uses -- not by the strength/floor-aware day_mix the shader sees.
# The ends are what matter: night stays 1.0 (palette untouched), full day
# applies the trim in full. DAY_TRIM = 0.62 is the 2026-11-11 calibration;
# see the constant block for the scenes it was fitted against.
static func day_trim(light: float, day := DAY_TRIM) -> float:
	return lerpf(1.0, day, day_mix(day_factor(light)))

# 0 at night, 1 at full daylight: how hard the shader tone curve should lift
# the background before the thermal palette. The denominator is guarded: a
# floor of 1.0 must yield 0.0, not NaN.
static func day_mix(factor: float, floor_value := MIN_FACTOR) -> float:
	var d := maxf(1.0 - floor_value, 0.05)
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
