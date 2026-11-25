extends SceneTree

const D = preload("res://mods/ThermalVTK/VTKDaylight.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func near(a: float, b: float, eps: float = 0.001) -> bool:
	return absf(a - b) <= eps

func _init() -> void:
	process_frame.connect(_run)

func _run() -> void:
	t_factor_for_light()
	t_estimate_light()
	t_estimate_terms()
	t_night_gate()
	t_day_mix_target()
	t_day_trim_mix()
	t_snow_trim_mix()
	t_exposure_norm()
	t_smoothing()
	t_clamps()
	print("")
	if fails == 0:
		print("Daylight tests passed")
		quit(0)
	else:
		print("Daylight tests failed: ", fails)
		quit(1)

func t_factor_for_light() -> void:
	ck(near(D.factor_for_light(1.0), 0.22), "clear noon lands on TARGET")
	ck(near(D.factor_for_light(0.5), 0.44), "half the light doubles the factor")
	ck(near(D.factor_for_light(0.25), 0.88), "a quarter of the light is 0.88")
	ck(near(D.factor_for_light(0.2), 1.0), "below TARGET the vanilla exposure stays")
	ck(near(D.factor_for_light(0.0), 1.0), "zero light never divides by zero")
	ck(near(D.factor_for_light(-5.0), 1.0), "negative light clamps to vanilla")
	ck(near(D.factor_for_light(2.0), D.FLOOR), "a blinding frame hits the floor")
	ck(near(D.factor_for_light(1.0, 0.40), 0.40), "an explicit target is the noon factor")
	ck(near(D.factor_for_light(1.0, 0.22, 1.0), 1.0), "floor 1.0 is the vanilla exposure")
	ck(not is_nan(D.factor_for_light(0.0)), "zero light stays finite")

func t_estimate_light() -> void:
	ck(near(D.estimate_light({}), 0.0), "an empty snapshot estimates nothing")
	ck(near(D.estimate_light({"shelter": true, "ambient_color": Color(1, 1, 1), "ambient_energy": 1.0}), 0.0), "shelter short-circuits to zero")
	ck(near(D.estimate_light({"intro": true, "ambient_color": Color(1, 1, 1), "ambient_energy": 1.0}), 0.0), "intro short-circuits to zero")
	ck(near(D.estimate_light({"ambient_color": Color(1, 1, 1), "ambient_energy": 1.0}), 1.0), "ambient light is read")
	ck(near(D.estimate_light({"ambient_color": Color(1, 0, 0), "ambient_energy": 1.0}), 0.299), "luminance uses the shader weights")
	ck(near(D.estimate_light({"ambient_color": null, "ambient_energy": 1.0}), 0.0), "a missing colour contributes nothing")
	ck(near(D.estimate_light({"sky_color": Color(1, 1, 1), "background_energy": 0.5}), 0.5), "sky colour scales by the background energy")
	ck(near(D.estimate_light({"sun_color": Color(1, 1, 1), "sun_energy": 1.0, "sun_mask": 0}), 0.0), "a culled sun adds nothing")
	ck(near(D.estimate_light({"sun_color": Color(1, 1, 1), "sun_energy": 1.0, "sun_mask": 1}), 1.0), "an active sun adds its energy")
	ck(near(D.estimate_light({"moon_color": Color(1, 1, 1), "moon_energy": 1.0, "moon_mask": 1}), 1.0), "an active moon adds its energy")
	ck(near(D.estimate_light({"fog_emission": Color(1, 1, 1), "fog_density": 0.5}), 0.5), "fog emission scales by density")
	ck(near(D.estimate_light({"ambient_color": Color(1, 1, 1), "ambient_energy": 1.0, "sky_color": Color(1, 1, 1), "background_energy": 1.0}), 2.0), "the terms sum with unit weights")

func t_night_gate() -> void:
	ck(near(D.night_gate(0.12, true), 1.0), "a sunless sky restores the vanilla exposure")
	ck(near(D.night_gate(0.12, false), 0.12), "a live sun keeps the compensation factor")
	ck(near(D.night_gate(1.0, true), 1.0), "the gate never lifts above vanilla")

func t_estimate_terms() -> void:
	var t: Dictionary = D.estimate_terms({})
	ck(near(float(t["sky"]) + float(t["amb"]) + float(t["sun"]) + float(t["moon"]) + float(t["fog"]), 0.0), "an empty snapshot has zero terms")
	var s: Dictionary = D.estimate_terms({"ambient_color": Color(1, 1, 1), "ambient_energy": 1.0, "sun_color": Color(1, 1, 1), "sun_energy": 0.5, "sun_mask": 1})
	ck(near(float(s["amb"]), 1.0), "the ambient term is read")
	ck(near(float(s["sun"]), 0.5), "the sun term is read")
	ck(near(D.estimate_light({"ambient_color": Color(1, 1, 1), "ambient_energy": 1.0, "sun_color": Color(1, 1, 1), "sun_energy": 0.5, "sun_mask": 1}), 1.5), "estimate_light is the sum of the terms")
	var sh: Dictionary = D.estimate_terms({"shelter": true, "ambient_color": Color(1, 1, 1), "ambient_energy": 1.0})
	ck(near(float(sh["amb"]), 0.0), "shelter zeroes every term")
	ck(near(float(sh["sun"]), 0.0), "shelter zeroes the sun term too")

func t_day_mix_target() -> void:
	ck(near(D.day_mix(1.0), 0.0), "night has no curve")
	ck(near(D.day_mix(0.22), 1.0), "TARGET runs the curve at full strength")
	ck(near(D.day_mix(0.61), 0.5), "half compensation is a half curve")
	ck(near(D.day_mix(0.1), 1.0), "a factor below TARGET clamps the curve")
	ck(near(D.day_mix(1.0, 1.0), 0.0), "target 1.0 does not divide by zero")
	ck(not is_nan(D.day_mix(1.0, 1.0)), "target 1.0 keeps the mix finite")

func t_day_trim_mix() -> void:
	ck(near(D.day_trim(0.0), 1.0), "night leaves the palette alone")
	ck(near(D.day_trim(1.0), 0.62), "full mix applies the 2026-11-11 DAY_TRIM")
	ck(near(D.day_trim(1.0, 0.5), 0.5), "an explicit trim is applied at full mix")
	ck(near(D.day_trim(0.0, 0.5), 1.0), "an explicit trim sleeps at zero mix")
	ck(near(D.day_trim(0.5, 0.5), 0.75), "half mix lands halfway")

func t_snow_trim_mix() -> void:
	ck(near(D.snow_trim(2, 0.0), D.SNOW_TRIM_NIGHT), "winter night keeps the night trim")
	ck(near(D.snow_trim(2, 1.0), D.SNOW_TRIM_DAY), "winter day keeps the day trim")
	ck(near(D.snow_trim(2, 0.5), 0.54), "the winter trim blends by mix")
	ck(near(D.snow_trim(1, 1.0), 1.0), "summer has no snow trim")
	ck(near(D.snow_trim(1, 0.0), 1.0), "summer night has no snow trim either")
	ck(near(D.snow_trim(2, 1.0, 0.5, 0.9), 0.9), "explicit winter trims are honoured")
	ck(near(D.snow_trim(2, -1.0), D.SNOW_TRIM_NIGHT), "a mix below zero clamps to night")
	ck(near(D.snow_trim(2, 2.0), D.SNOW_TRIM_DAY), "a mix above one clamps to day")
	# Brightness-aware dimming: when the light estimate lifts the factor above
	# the bright-day TARGET, the scene is genuinely dimmer and the winter trim
	# eases back toward the night trim instead of crushing mids.
	ck(near(D.snow_trim(2, 1.0, D.SNOW_TRIM_NIGHT, D.SNOW_TRIM_DAY, D.TARGET), D.SNOW_TRIM_DAY), "bright winter day at TARGET keeps the day trim")
	ck(near(D.snow_trim(2, 1.0, D.SNOW_TRIM_NIGHT, D.SNOW_TRIM_DAY, 1.0), D.SNOW_TRIM_NIGHT), "very dim winter day eases to the night trim")
	ck(near(D.snow_trim(2, 1.0, D.SNOW_TRIM_NIGHT, D.SNOW_TRIM_DAY, 0.38), D.SNOW_TRIM_DAY + (D.SNOW_TRIM_NIGHT - D.SNOW_TRIM_DAY) * ((0.38 - D.TARGET) / (1.0 - D.TARGET))), "a dimmer-day factor eases the winter trim")
	ck(near(D.snow_trim(2, 0.5, D.SNOW_TRIM_NIGHT, D.SNOW_TRIM_DAY, 1.0), D.SNOW_TRIM_NIGHT), "dim winter half-mix stays at the night trim")

func t_exposure_norm() -> void:
	ck(near(D.exposure_norm(2.0), 1.0), "the reference tier normalises to 1")
	ck(near(D.exposure_norm(2.5), 0.8), "2.5 normalises to 0.8")
	ck(near(D.exposure_norm(3.0), 2.0 / 3.0), "3.0 normalises to two thirds")
	ck(near(D.exposure_norm(1.0), 1.0), "below the reference the norm stops at 1")
	ck(near(D.exposure_norm(0.0), 1.0), "zero exposure is a guard, not a division")
	ck(near(D.exposure_norm(-1.0), 1.0), "negative exposure is a guard")
	ck(near(D.exposure_norm(NAN), 1.0), "NaN exposure is a guard")

func t_smoothing() -> void:
	var one := D.step(1.0, 0.33, 1.5, 1.5)
	ck(near(one, 0.5765, 0.001), "1.5 s response covers 63% of the way")
	ck(one > 0.33 and one < 1.0, "smoothing never overshoots")
	ck(near(D.step(1.0, 0.33, 0.0), 1.0), "zero delta does not move")
	ck(near(D.step(1.0, 0.33, 5.0, 0.0), 0.33), "zero response snaps")
	ck(near(D.step(0.5, 0.5, 1.0), 0.5), "equal values stay put")
	ck(near(D.step(0.5, 1.0, 100.0), 1.0, 0.001), "a long delta converges")

func t_clamps() -> void:
	ck(D.factor_for_light(1.0) >= D.FLOOR, "the factor never drops below the floor")
	ck(D.factor_for_light(0.05) <= 1.0, "the factor never exceeds the vanilla exposure")
