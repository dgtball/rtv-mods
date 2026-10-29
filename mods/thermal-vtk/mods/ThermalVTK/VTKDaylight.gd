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

const MIN_FACTOR := 0.33
const RESPONSE := 1.5
const INDOOR_FACTOR := 0.15
const SNOW_BONUS := 0.15
# Winter background trim, measured 2026-10-24 in the Minefield snow field.
const SNOW_TRIM_DAY := 0.80
const SNOW_TRIM_NIGHT := 0.60

const WEATHER_FACTORS := {
	"Neutral": 1.0,
	"Overcast": 0.65,
	"Rain": 0.55,
	"Storm": 0.45,
}

# 0..1 daylight, with sunrise/sunset moved for the winter season.
static func sun_level(time: float, season: int = 1) -> float:
	var dawn_a := 5.0
	var dawn_b := 8.0
	var dusk_a := 19.0
	var dusk_b := 22.0
	if season == 2:
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

static func light_level(time: float, weather: String, season: int, indoor: bool, shelter: bool) -> float:
	var light := sun_level(time, season) * weather_factor(weather)
	if indoor or shelter:
		light *= INDOOR_FACTOR
	elif season == 2:
		# Snow bounces daylight, it does not create any: scale the current
		# light so winter midnight stays exactly as dark as summer midnight.
		light = minf(1.0, light * (1.0 + SNOW_BONUS))
	return clampf(light, 0.0, 1.0)

# 1.0 at night (vanilla exposure untouched), MIN_FACTOR at full daylight.
static func day_factor(light: float) -> float:
	return lerpf(1.0, MIN_FACTOR, clampf(light, 0.0, 1.0))

# Winter-only background trim for the thermal palette. Snow bounces far more
# amplified light than any summer surface, so the whole winter frame lands in
# the red-to-cream third of the palette: probes measured night dirt at
# luminance 0.365 (t 0.62, red) and bright snow at 0.559 (t 0.95, cream) --
# no cold colors left on screen. The trim multiplies the effective
# thermalDarken so the same range re-spreads down the ladder: at night 0.60
# the dirt reads t 0.37 (purple) and the snow tops out near t 0.57 (amber);
# by day 0.80 gives the pinned snow headroom off the t = 1.0 ceiling. Keys
# are unaffected: substitution happens before the palette. Blended by the
# same light level that drives exposure, 1.0 everywhere else.
static func snow_trim(season: int, indoor: bool, shelter: bool, light: float) -> float:
	if season != 2 or indoor or shelter:
		return 1.0
	return lerpf(SNOW_TRIM_NIGHT, SNOW_TRIM_DAY, clampf(light, 0.0, 1.0))

# 0 at night, 1 at full daylight: how hard the shader tone curve should lift
# the background before the thermal palette.
static func day_mix(factor: float) -> float:
	return clampf((1.0 - factor) / (1.0 - MIN_FACTOR), 0.0, 1.0)

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
