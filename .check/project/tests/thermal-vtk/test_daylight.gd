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
	t_frame_ceiling()
	t_night_gate()
	t_day_mix_target()
	t_day_trim_mix()
	t_snow_trim_mix()
	t_key_gain()
	t_smoothing()
	t_palette_input()
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

func t_frame_ceiling() -> void:
	# u = measured / applied -- несжатый уровень кадра. Потолок отпускает ровно
	# до DAY_LEVEL и никогда выше ванили.
	ck(near(D.frame_ceiling(0.03, 0.12), 0.40, 0.01), "a cave frame lifts the ceiling to DAY_LEVEL / u")
	ck(near(D.frame_ceiling(0.03, 1.0), 1.0), "an uncompensated dark frame hits the vanilla ceiling")
	ck(near(D.frame_ceiling(0.20, 0.12), D.FLOOR), "a bright frame hits the floor")
	ck(near(D.frame_ceiling(0.10, 0.12), D.FLOOR, 0.005), "a frame on DAY_LEVEL lands on the floor")
	ck(near(D.frame_ceiling(0.03, 0.12, 0.20), 0.80, 0.01), "an explicit level moves the ceiling")
	ck(near(D.frame_ceiling(0.03, 0.12, 0.10, 1.0), 1.0), "floor 1.0 disables the release")
	ck(D.frame_ceiling(0.151, 0.22) < 0.22, "a day-level frame keeps the ceiling under source A")
	ck(not is_nan(D.frame_ceiling(0.03, 0.0)), "zero applied never divides by zero")
	ck(D.frame_ceiling(0.03, 0.0) >= D.FLOOR, "a degenerate division stops at the floor")

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
	ck(near(D.snow_trim(2, false, false, 0.0), D.SNOW_TRIM_NIGHT), "winter night keeps the night trim")
	ck(near(D.snow_trim(2, false, false, 1.0), D.SNOW_TRIM_DAY), "winter day keeps the day trim")
	ck(near(D.snow_trim(2, false, false, 0.5), 0.54), "the winter trim blends by mix")
	ck(near(D.snow_trim(1, false, false, 1.0), 1.0), "summer has no snow trim")
	ck(near(D.snow_trim(2, true, false, 1.0), 1.0), "an indoor winter scene has no snow trim")
	ck(near(D.snow_trim(2, false, true, 1.0), 1.0), "a shelter has no snow trim")
	ck(near(D.snow_trim(2, false, false, 1.0, 0.5, 0.9), 0.9), "explicit winter trims are honoured")

func t_palette_input() -> void:
	ck(near(D.palette_input(0.5, 1.7, 0.6, 0.0), 0.85), "mix 0: shoulder and lift off, raw darken only")
	ck(near(D.palette_input(0.2, 1.0, 0.6, 1.0), 1.0 - pow(0.8, 1.6)), "below the knee: full lift")
	ck(near(D.palette_input(0.8, 1.0, 0.6, 1.0), 1.0 - pow(0.25, 1.6)), "above the knee: shoulder then lift")
	ck(near(D.palette_input(1.0, 1.0, 0.6, 1.0), 1.0 - pow(0.1, 1.6)), "the x = 1.0 boundary takes the linear shoulder")
	var prev := -1.0
	var mono := true
	var raw := 0.0
	while raw <= 1.2 + 0.0001:
		var out: float = D.palette_input(raw, 1.2, 0.6, 0.5)
		if out < prev - 0.0001:
			mono = false
		prev = out
		raw += 0.05
	ck(mono, "output never decreases across the 0..1.2 sweep")

func t_key_gain() -> void:
	ck(near(D.key_gain(1.0), 1.0), "night key gain is 1")
	ck(near(D.key_gain(0.33), 3.0303, 0.001), "full daylight gain restores the key")
	ck(near(D.key_gain(0.0), 100.0, 0.001), "zero factor is clamped, not divided by zero")
	ck(near(D.key_gain(0.5), 2.0), "half exposure doubles the key")

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
