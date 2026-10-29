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
	t_sun_curve()
	t_weather()
	t_light_indoor()
	t_light_winter()
	t_day_factor()
	t_day_mix()
	t_key_gain()
	t_smoothing()
	t_clamps()
	print("")
	if fails == 0:
		print("Daylight tests passed")
		quit(0)
	else:
		print("Daylight tests failed: ", fails)
		quit(1)

func t_sun_curve() -> void:
	ck(near(D.sun_level(0.0), 0.0), "midnight is dark")
	ck(near(D.sun_level(500.0), 0.0), "before sunrise is dark")
	ck(near(D.sun_level(1200.0), 1.0), "noon is full daylight")
	ck(near(D.sun_level(2200.0), 0.0), "after sunset is dark")
	ck(near(D.sun_level(600.0), 0.2593), "summer 06:00 is a partial sunrise")
	ck(near(D.sun_level(700.0), 0.7407), "summer 07:00 is mostly risen")
	ck(near(D.sun_level(2100.0), 0.2593), "summer 21:00 is mostly set")
	ck(near(D.sun_level(800.0, 2), 0.5), "winter 08:00 is halfway through sunrise")
	ck(near(D.sun_level(1200.0, 2), 1.0), "winter noon is full daylight")
	ck(near(D.sun_level(1800.0, 2), 0.2593), "winter 18:00 is mostly set")
	ck(near(D.sun_level(3000.0), 0.2593), "time wraps past 2400 (3000 -> 06:00)")
	ck(near(D.sun_level(-100.0), 0.0), "negative time is still night")

func t_weather() -> void:
	ck(near(D.weather_factor("Neutral"), 1.0), "Neutral is full light")
	ck(near(D.weather_factor("Overcast"), 0.65), "Overcast dims")
	ck(near(D.weather_factor("Rain"), 0.55), "Rain dims more")
	ck(near(D.weather_factor("Storm"), 0.45), "Storm dims most")
	ck(near(D.weather_factor("Unknown"), 1.0), "unknown weather is neutral")

func t_light_indoor() -> void:
	ck(near(D.light_level(1200.0, "Neutral", 1, false, false), 1.0), "outdoor noon is full light")
	ck(near(D.light_level(1200.0, "Neutral", 1, true, false), 0.15), "indoor noon keeps only 15%")
	ck(near(D.light_level(1200.0, "Neutral", 1, false, true), 0.15), "shelter noon keeps only 15%")
	ck(near(D.light_level(0.0, "Neutral", 1, true, false), 0.0), "indoor night stays dark")

func t_light_winter() -> void:
	ck(near(D.light_level(1200.0, "Neutral", 2, false, false), 1.0), "winter noon is full light")
	ck(near(D.light_level(1800.0, "Neutral", 2, false, false), 0.2982), "winter snow adds bounce at dusk")
	ck(near(D.light_level(1800.0, "Neutral", 2, true, false), 0.0389), "indoor winter gets no snow bounce")
	ck(near(D.light_level(0.0, "Neutral", 2, false, false), 0.0), "winter midnight gets no snow bounce")
	ck(near(D.light_level(2100.0, "Neutral", 1, false, false), 0.2593), "summer dusk has no snow bounce")

func t_day_factor() -> void:
	ck(near(D.day_factor(0.0), 1.0), "night leaves vanilla exposure alone")
	ck(near(D.day_factor(1.0), 0.33), "full daylight lowers exposure to 33%")
	ck(near(D.day_factor(0.5), 0.665), "half light is halfway")
	ck(near(D.day_factor(-1.0), 1.0), "negative light clamps to night")
	ck(near(D.day_factor(2.0), 0.33), "overbright clamps to full daylight")

func t_day_mix() -> void:
	ck(near(D.day_mix(1.0), 0.0), "night has no curve")
	ck(near(D.day_mix(0.33), 1.0), "full daylight runs the curve at full strength")
	ck(near(D.day_mix(0.665), 0.5), "half compensation is a half curve")
	ck(near(D.day_mix(0.1), 1.0), "a factor below the floor clamps the curve")

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
	ck(D.light_level(1200.0, "Neutral", 1, false, false) <= 1.0, "light never exceeds 1")
	ck(D.light_level(0.0, "Neutral", 1, false, false) >= 0.0, "light never goes below 0")
	ck(D.day_factor(D.light_level(1200.0, "Storm", 2, false, false)) >= D.MIN_FACTOR, "factor never drops below the floor")
