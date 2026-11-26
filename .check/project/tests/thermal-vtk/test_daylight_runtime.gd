extends SceneTree

const NVG = preload("res://mods/ThermalVTK/VTKNVG.gd")
const Daylight = preload("res://mods/ThermalVTK/VTKDaylight.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

class FakeSim extends Node:
	var season: int = 1
	var time: float = 600.0
	var day: int = 1

class FakeData extends Resource:
	var indoor: bool = false
	var shelter: bool = false
	var NVG: bool = false

# Mirrors the vanilla World node's light surface: the flags, the two
# directional lights and the sky ShaderMaterial. skyMaterial defaults to null
# on purpose -- then _snapshot falls back to env.sky.sky_material, and env.sky
# is unset here, so every runtime test also proves the `env.sky != null` guard.
class FakeWorld extends Node:
	var shelter: bool = false
	var intro: bool = false
	var sunLight: DirectionalLight3D = null
	var moonLight: DirectionalLight3D = null
	var skyMaterial: ShaderMaterial = null

# The real _ready loads GameData.tres and wires the game tree; the exposure
# logic only needs _installed and the environment, so skip the setup.
class TestNVG extends "res://mods/ThermalVTK/VTKNVG.gd":
	func _ready() -> void:
		pass

func _init() -> void:
	process_frame.connect(_run)

func _run() -> void:
	t_day_lowers_the_input_gain()
	t_night_is_untouched()
	t_dark_scene_is_untouched()
	t_overbright_hits_the_floor()
	t_target_lever_moves_the_day()
	t_strength_zero_keeps_vanilla()
	t_shelter_short_circuits()
	t_missing_world_keeps_vanilla()
	t_snapshot_reads_world()
	t_day_trim_from_mix()
	t_snow_trim_ignores_indoor()
	t_refresh_snaps_without_lag()
	t_night_gate_is_vanilla()
	t_sun_down_from_snapshot()
	t_time_scale_applies_while_live()
	t_time_scale_clamps_to_the_range()
	t_time_scale_resets_when_not_live()
	t_time_scale_rolls_over_hhmm()
	t_reset_returns_levers()
	t_power_tier_stops_moving_the_picture()
	t_bad_exposure_is_a_guard()
	t_exposure_is_read_only()
	print("")
	if fails == 0:
		print("Daylight runtime tests passed")
		quit(0)
	else:
		print("Daylight runtime tests failed: ", fails)
		quit(1)

func _world() -> Dictionary:
	# Each test rebuilds the tree; the previous Simulation lives at /root and
	# would otherwise win the absolute lookup as "Simulation2" is not the path.
	var old_sim := root.get_node_or_null("Simulation")
	if old_sim != null:
		old_sim.free()
	var old_map := root.get_node_or_null("Map")
	if old_map != null:
		old_map.free()
	var map := Node.new()
	map.name = "Map"
	root.add_child(map)
	var world := FakeWorld.new()
	world.name = "World"
	map.add_child(world)
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	world.add_child(we)
	var env := Environment.new()
	env.tonemap_exposure = 3.0
	we.environment = env
	var sim := FakeSim.new()
	sim.name = "Simulation"
	root.add_child(sim)
	var nvg := TestNVG.new()
	root.add_child(nvg)
	nvg.set_process(false)
	nvg._installed = true
	nvg._game_data = FakeData.new()
	return {"map": map, "world": world, "env": env, "sim": sim, "nvg": nvg}

# Seed the cached scene level directly and park the sim cadence so the tick
# under test does NOT re-read the world: these tests drive the model from a
# known E, and only the snapshot test touches the tree itself.
func _reset(nvg, env: Environment, sim: FakeSim, e: float, season: int = 1) -> void:
	sim.season = season
	nvg._sim_season = season
	nvg._sim_indoor = false
	nvg._sim_shelter = false
	nvg._sim_cd = 999.0
	nvg._light_est = e
	nvg._day_factor = 1.0
	nvg._day_mix = 0.0
	nvg._day_seeded = false
	nvg._factor_a = 1.0
	nvg._sun_down = false
	nvg._input_gain = 1.0
	nvg.set_day_target = Daylight.TARGET
	nvg.set_day_floor = Daylight.FLOOR
	nvg.set_day_trim = Daylight.DAY_TRIM
	env.tonemap_exposure = 2.0

func t_day_lowers_the_input_gain() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	var sim: FakeSim = w["sim"]
	_reset(nvg, env, sim, 1.0)
	nvg._daylight_tick(1.0)
	ck(is_equal_approx(env.tonemap_exposure, 2.0), "a bright scene leaves the exposure alone")
	ck(absf(nvg._day_factor - 0.22) < 0.001, "the day factor lands on TARGET")
	var want: float = nvg.set_world * nvg._snow_trim * nvg._day_trim * Daylight.QUAD_FLOOR
	ck(absf(nvg._input_gain - want) < 0.001, "the input gain folds world, trims and the linear-stage floor")
	w["map"].free()

func t_night_is_untouched() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	var sim: FakeSim = w["sim"]
	_reset(nvg, env, sim, 0.03)
	nvg._daylight_tick(1.0)
	ck(is_equal_approx(env.tonemap_exposure, 2.0), "night leaves the exposure alone")
	ck(is_equal_approx(nvg._day_mix, 0.0), "night leaves the curve off")
	ck(absf(nvg._input_gain - nvg.set_world) < 0.001, "night gain is the world brightness")
	w["map"].free()

func t_dark_scene_is_untouched() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	var sim: FakeSim = w["sim"]
	_reset(nvg, env, sim, 0.15)
	nvg._daylight_tick(1.0)
	ck(is_equal_approx(env.tonemap_exposure, 2.0), "a scene below TARGET is not touched")
	ck(is_equal_approx(nvg._day_factor, 1.0), "a scene below TARGET keeps factor 1.0")
	ck(absf(nvg._input_gain - nvg.set_world) < 0.001, "the gain stays at world brightness")
	w["map"].free()

func t_overbright_hits_the_floor() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	var sim: FakeSim = w["sim"]
	_reset(nvg, env, sim, 2.0)
	nvg._daylight_tick(1.0)
	ck(is_equal_approx(env.tonemap_exposure, 2.0), "a blinding scene leaves the exposure alone")
	ck(absf(nvg._day_factor - Daylight.FLOOR) < 0.001, "the day factor stops at the floor")
	var want: float = nvg.set_world * nvg._snow_trim * nvg._day_trim * Daylight.QUAD_FLOOR
	ck(absf(nvg._input_gain - want) < 0.001, "the quad gain bottoms out at the shallower linear-stage floor")
	w["map"].free()

func t_target_lever_moves_the_day() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	var sim: FakeSim = w["sim"]
	_reset(nvg, env, sim, 1.0)
	nvg.set_day_target = 0.80
	nvg._daylight_tick(1.0)
	ck(absf(nvg._day_factor - 0.80) < 0.001, "the day factor follows the target lever")
	var want: float = nvg.set_world * nvg._snow_trim * nvg._day_trim * 0.80
	ck(absf(nvg._input_gain - want) < 0.001, "the quad gain follows a target above its floor")
	w["map"].free()

func t_strength_zero_keeps_vanilla() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	var sim: FakeSim = w["sim"]
	_reset(nvg, env, sim, 1.0)
	nvg.set_strength = 0.0
	nvg._daylight_tick(1.0)
	ck(is_equal_approx(env.tonemap_exposure, 2.0), "strength 0 keeps the exposure")
	ck(is_equal_approx(nvg._day_mix, 0.0), "strength 0 leaves the curve off")
	ck(absf(nvg._input_gain - nvg.set_world) < 0.001, "strength 0 leaves the plain world gain")
	w["map"].free()

func t_shelter_short_circuits() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	var world: FakeWorld = w["world"]
	_reset(nvg, env, w["sim"], 1.0)
	# A bright outdoor scene would land on the day factor; the shelter gate wins.
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 1.0
	env.background_energy_multiplier = 0.0
	env.volumetric_fog_density = 0.0
	world.shelter = true
	nvg._sim_cd = 0.0
	nvg._daylight_tick(1.0)
	ck(is_equal_approx(env.tonemap_exposure, 2.0), "a shelter keeps the exposure")
	ck(nvg._sim_shelter == true, "the shelter flag is read from the world")
	ck(nvg._light_est == 0.0, "the shelter estimate is zero")
	w["map"].free()

func t_missing_world_keeps_vanilla() -> void:
	var old_map := root.get_node_or_null("Map")
	if old_map != null:
		old_map.free()
	var nvg := TestNVG.new()
	root.add_child(nvg)
	nvg.set_process(false)
	nvg._installed = true
	nvg._game_data = FakeData.new()
	nvg._day_factor = 1.0
	nvg._sim_cd = 0.0
	nvg._daylight_tick(1.0)
	ck(nvg._day_factor == 1.0, "no environment: the day factor stays vanilla")
	ck(nvg._light_est == 0.0, "no environment: the estimate is zero")
	ck(absf(nvg._input_gain - nvg.set_world) < 0.001, "no environment: the gain falls back to the reference exposure")
	nvg.free()

func t_snapshot_reads_world() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	var world: FakeWorld = w["world"]
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 1.0
	env.background_energy_multiplier = 0.0
	env.volumetric_fog_density = 0.0
	var snap: Dictionary = nvg._snapshot()
	ck(absf(Daylight.estimate_light(snap) - 1.0) < 0.01, "the snapshot reads the ambient light")
	var mat := ShaderMaterial.new()
	mat.set_shader_parameter("skyColor", Color(1, 1, 1))
	world.skyMaterial = mat
	env.background_energy_multiplier = 1.0
	snap = nvg._snapshot()
	ck(absf(Daylight.estimate_light(snap) - 2.0) < 0.01, "the sky colour comes from skyMaterial")
	var sun := DirectionalLight3D.new()
	world.add_child(sun)
	world.sunLight = sun
	sun.light_cull_mask = 0
	snap = nvg._snapshot()
	ck(absf(Daylight.estimate_light(snap) - 2.0) < 0.01, "a culled sun adds nothing")
	sun.light_cull_mask = 1
	snap = nvg._snapshot()
	ck(absf(Daylight.estimate_light(snap) - 3.0) < 0.01, "an active sun adds its energy")
	world.shelter = true
	snap = nvg._snapshot()
	ck(absf(Daylight.estimate_light(snap)) < 0.01, "shelter short-circuits the estimate")
	w["map"].free()

func t_day_trim_from_mix() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	var sim: FakeSim = w["sim"]
	_reset(nvg, env, sim, 1.0, 2)
	nvg.set_day_trim = 0.5
	nvg._daylight_tick(1.0)
	ck(absf(nvg._day_trim - 0.5) < 0.001, "winter day applies the day trim")
	ck(absf(nvg._snow_trim - Daylight.SNOW_TRIM_DAY) < 0.001, "winter day keeps the snow trim")
	w["map"].free()
	var w2 := _world()
	var nvg2 = w2["nvg"]
	var env2: Environment = w2["env"]
	var sim2: FakeSim = w2["sim"]
	_reset(nvg2, env2, sim2, 0.03, 2)
	nvg2.set_day_trim = 0.5
	nvg2._daylight_tick(1.0)
	ck(absf(nvg2._day_trim - 1.0) < 0.001, "winter night sleeps the day trim")
	ck(absf(nvg2._snow_trim - Daylight.SNOW_TRIM_NIGHT) < 0.001, "winter night keeps the night snow trim")
	w2["map"].free()

func t_refresh_snaps_without_lag() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	var sim: FakeSim = w["sim"]
	var data: FakeData = nvg._game_data
	data.NVG = true
	_reset(nvg, env, sim, 1.0)
	nvg._daylight_tick(1.0)
	var settled: float = nvg._input_gain
	ck(absf(nvg._day_factor - 0.22) < 0.001, "a bright scene settles on TARGET")
	nvg.set_day_target = 0.5
	nvg._daylight_tick(0.016)
	ck(nvg._input_gain > settled, "a bare tick only creeps toward the new target")
	ck(nvg._day_factor < 0.5, "the creeping factor has not arrived yet")
	nvg.refresh_daylight_now()
	ck(absf(nvg._day_factor - 0.5) < 0.001, "refresh snaps to the new target at once")
	var want: float = nvg.set_world * nvg._snow_trim * nvg._day_trim * 0.5
	ck(absf(nvg._input_gain - want) < 0.001, "the gain follows the snapped factor")
	w["map"].free()

func t_reset_returns_levers() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	var sim: FakeSim = w["sim"]
	_reset(nvg, env, sim, 1.0, 2)
	nvg.set_day_target = 0.5
	nvg.set_day_trim = 0.5
	nvg._daylight_tick(1.0)
	nvg._reset_daylight()
	ck(absf(nvg.set_day_target - Daylight.TARGET) < 0.001, "reset returns the target lever to the constant")
	ck(absf(nvg.set_day_floor - Daylight.FLOOR) < 0.001, "reset returns the floor lever to the constant")
	ck(absf(nvg.set_day_trim - Daylight.DAY_TRIM) < 0.001, "reset returns the trim lever to the constant")
	ck(absf(nvg._day_trim - 1.0) < 0.001, "reset clears the applied day trim")
	ck(absf(nvg._input_gain - nvg.set_world) < 0.001, "reset refreshes the gain to the plain world brightness")
	w["map"].free()

func t_night_gate_is_vanilla() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	var sim: FakeSim = w["sim"]
	var data: FakeData = nvg._game_data
	data.NVG = true
	_reset(nvg, env, sim, 1.209)
	nvg._day_factor = 0.18
	nvg._sun_down = true
	nvg.refresh_daylight_now()
	ck(is_equal_approx(env.tonemap_exposure, 2.0), "a sunless sky leaves the exposure alone")
	ck(is_equal_approx(nvg._day_mix, 0.0), "night leaves the curve off")
	ck(is_equal_approx(nvg._day_trim, 1.0), "night leaves the palette trim off")
	ck(absf(nvg._input_gain - nvg.set_world) < 0.001, "night gain is the world brightness")
	w["map"].free()

func t_sun_down_from_snapshot() -> void:
	var w := _world()
	var nvg = w["nvg"]
	ck(nvg._compute_sun_down({"sun_present": true, "sun_mask": 0}), "a culled sun is down")
	ck(not nvg._compute_sun_down({"sun_present": true, "sun_mask": 1048575}), "a live sun is up")
	ck(nvg._compute_sun_down({"moon_mask": 1}), "without a sun the lit moon means night")
	ck(not nvg._compute_sun_down({"moon_mask": 0}), "without any light the gate stays silent")
	w["map"].free()

func t_time_scale_applies_while_live() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	var sim: FakeSim = w["sim"]
	var data: FakeData = nvg._game_data
	data.NVG = true
	sim.time = 600.0
	sim.day = 1
	_reset(nvg, env, sim, 1.0)
	nvg.set_time_scale = 2.5
	nvg._daylight_tick(1.0)
	ck(absf(sim.time - 600.25) < 0.001, "time scale advances the simulation clock without Engine.time_scale")
	ck(Engine.time_scale == 1.0, "Engine.time_scale stays at 1.0")
	ck(sim.day == 1, "the day does not roll over inside the same hour")
	w["map"].free()

func t_time_scale_clamps_to_the_range() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	var sim: FakeSim = w["sim"]
	var data: FakeData = nvg._game_data
	data.NVG = true
	sim.time = 600.0
	_reset(nvg, env, sim, 1.0)
	nvg.set_time_scale = 20.0
	nvg._daylight_tick(1.0)
	ck(absf(sim.time - 601.5) < 0.001, "the time scale clamps to the top of the range")
	nvg.set_time_scale = 0.5
	nvg._daylight_tick(1.0)
	ck(absf(sim.time - 601.5) < 0.001, "the time scale clamps to the bottom of the range")
	w["map"].free()

func t_time_scale_resets_when_not_live() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	var sim: FakeSim = w["sim"]
	var data: FakeData = nvg._game_data
	data.NVG = true
	sim.time = 600.0
	_reset(nvg, env, sim, 1.0)
	nvg.set_time_scale = 4.0
	nvg._daylight_tick(1.0)
	ck(absf(sim.time - 600.5) < 0.001, "the time scale lever advances while the compensation is live")
	nvg.set_daylight = false
	nvg._daylight_tick(1.0)
	ck(absf(sim.time - 600.5) < 0.001, "the clock does not advance when the compensation is off")
	ck(Engine.time_scale == 1.0, "Engine.time_scale stays at 1.0")
	w["map"].free()

func t_time_scale_rolls_over_hhmm() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	var sim: FakeSim = w["sim"]
	var data: FakeData = nvg._game_data
	data.NVG = true
	sim.time = 2359.0
	sim.day = 3
	_reset(nvg, env, sim, 1.0)
	nvg.set_time_scale = 7.0
	nvg._daylight_tick(2.0)
	ck(absf(sim.time - 1.0) < 0.001, "advancing past midnight rolls the HHMM clock")
	ck(sim.day == 4, "advancing past midnight increments the day")
	w["map"].free()

func t_snow_trim_ignores_indoor() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	var sim: FakeSim = w["sim"]
	_reset(nvg, env, sim, 1.0, 2)
	nvg._daylight_tick(1.0)
	ck(absf(nvg._snow_trim - Daylight.SNOW_TRIM_DAY) < 0.001, "a winter day keeps the day snow trim")
	nvg._sim_indoor = true
	nvg._daylight_tick(0.016)
	ck(absf(nvg._snow_trim - Daylight.SNOW_TRIM_DAY) < 0.001, "walking under a roof does not move the trim")
	nvg._sim_shelter = true
	nvg._daylight_tick(0.016)
	ck(absf(nvg._snow_trim - Daylight.SNOW_TRIM_DAY) < 0.001, "a shelter does not move the trim either")
	nvg._sim_shelter = false
	nvg._sim_season = 1
	nvg._daylight_tick(0.016)
	ck(absf(nvg._snow_trim - 1.0) < 0.001, "summer stays untrimmed even under a roof")
	w["map"].free()
	var w2 := _world()
	var nvg2 = w2["nvg"]
	var env2: Environment = w2["env"]
	var sim2: FakeSim = w2["sim"]
	_reset(nvg2, env2, sim2, 0.03, 2)
	nvg2._sim_indoor = true
	nvg2._daylight_tick(1.0)
	ck(absf(nvg2._snow_trim - Daylight.SNOW_TRIM_NIGHT) < 0.001, "a winter night indoors takes the night trim")
	w2["map"].free()

func t_power_tier_stops_moving_the_picture() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	var sim: FakeSim = w["sim"]
	_reset(nvg, env, sim, 0.03)
	env.tonemap_exposure = 2.0
	nvg._daylight_tick(1.0)
	var at_two: float = nvg._input_gain
	env.tonemap_exposure = 3.0
	nvg._daylight_tick(1.0)
	var at_three: float = nvg._input_gain
	ck(at_two > at_three, "a brighter tier lowers the gain")
	ck(absf(at_three - at_two * (2.0 / 3.0)) < 0.001, "the gain follows the tier by the exposure ratio")
	ck(is_equal_approx(env.tonemap_exposure, 3.0), "the tier value is left untouched")
	w["map"].free()

func t_bad_exposure_is_a_guard() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	_reset(nvg, env, w["sim"], 1.0)
	env.tonemap_exposure = 0.0
	nvg._daylight_tick(1.0)
	ck(is_finite(nvg._input_gain) and nvg._input_gain > 0.0, "a zero exposure cannot poison the gain")
	w["map"].free()

func t_exposure_is_read_only() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	_reset(nvg, env, w["sim"], 1.0)
	env.tonemap_exposure = 1.5
	nvg._daylight_tick(1.0)
	ck(is_equal_approx(env.tonemap_exposure, 1.5), "the daylight model never writes the exposure")
	w["map"].free()
