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
	var time: float = 1200.0
	var weather: String = "Neutral"
	var season: int = 1

class FakeData extends Resource:
	var indoor: bool = false
	var shelter: bool = false
	var NVG: bool = false

# The real _ready loads GameData.tres and wires the game tree; the exposure
# logic only needs _installed and the environment, so skip the setup.
class TestNVG extends "res://mods/ThermalVTK/VTKNVG.gd":
	func _ready() -> void:
		pass

func _init() -> void:
	process_frame.connect(_run)

func _run() -> void:
	t_noon_lowers_exposure()
	t_night_is_untouched()
	t_indoor_is_only_trimmed()
	t_vanilla_rewrite_rebaselines()
	t_toggle_restores_exposure()
	t_day_floor_deepens_shadows()
	t_day_trim_darkens_background()
	t_day_trim_default_calibration()
	t_refresh_snaps_without_lag()
	t_reset_returns_levers()
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
	var world := Node.new()
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
	return {"map": map, "env": env, "sim": sim, "nvg": nvg}

func _reset(nvg, env: Environment, sim: FakeSim, time: float, season: int = 1) -> void:
	sim.time = time
	sim.weather = "Neutral"
	sim.season = season
	nvg._last_exposure = -1.0
	nvg._day_factor = 1.0
	nvg._day_mix = 0.0
	nvg._key_gain = 1.0
	nvg._vanilla_exposure = 3.0
	env.tonemap_exposure = 3.0

func t_noon_lowers_exposure() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	var sim: FakeSim = w["sim"]
	_reset(nvg, env, sim, 1200.0)
	nvg._daylight_tick(1.0)
	ck(absf(env.tonemap_exposure - 0.66) < 0.005, "noon lowers exposure to 22%")
	ck(absf(nvg._day_factor - 0.22) < 0.001, "noon sets the day factor floor")
	ck(absf(nvg._day_mix - 1.0) < 0.001, "noon runs the shader curve at full strength")
	ck(nvg._key_gain > 3.0, "noon raises the key gain to compensate")
	w["map"].free()

func t_night_is_untouched() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	var sim: FakeSim = w["sim"]
	_reset(nvg, env, sim, 0.0, 2)
	nvg._daylight_tick(1.0)
	ck(is_equal_approx(env.tonemap_exposure, 3.0), "winter midnight keeps vanilla exposure")
	ck(is_equal_approx(nvg._key_gain, 1.0), "winter midnight keeps the key gain at 1")
	ck(is_equal_approx(nvg._day_mix, 0.0), "winter midnight leaves the curve off")
	w["map"].free()

func t_indoor_is_only_trimmed() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	var sim: FakeSim = w["sim"]
	var data: FakeData = nvg._game_data
	data.indoor = true
	_reset(nvg, env, sim, 1200.0)
	nvg._daylight_tick(1.0)
	ck(env.tonemap_exposure > 2.5, "indoor noon keeps most of the exposure")
	ck(env.tonemap_exposure < 3.0, "indoor noon still trims a little")
	data.indoor = false
	w["map"].free()

func t_vanilla_rewrite_rebaselines() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	var sim: FakeSim = w["sim"]
	_reset(nvg, env, sim, 1200.0)
	nvg._daylight_tick(1.0)
	env.tonemap_exposure = 2.5
	nvg._daylight_tick(0.016)
	ck(absf(nvg._vanilla_exposure - 2.5) < 0.001, "vanilla ResetCheck rewrites become the baseline")
	ck(absf(env.tonemap_exposure - 0.55) < 0.005, "the rewrite is compensated from the new baseline")
	w["map"].free()

func t_toggle_restores_exposure() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	var sim: FakeSim = w["sim"]
	_reset(nvg, env, sim, 1200.0)
	nvg._daylight_tick(1.0)
	nvg._restore_exposure()
	ck(is_equal_approx(env.tonemap_exposure, 3.0), "toggle off hands the exposure back")
	ck(is_equal_approx(nvg._key_gain, 1.0), "toggle off clears the key gain")
	ck(nvg._last_exposure < 0.0, "toggle off forgets the written value")
	w["map"].free()

func t_day_floor_deepens_shadows() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	var sim: FakeSim = w["sim"]
	_reset(nvg, env, sim, 1200.0)
	nvg.set_day_floor = 0.10
	nvg._daylight_tick(1.0)
	ck(absf(env.tonemap_exposure - 0.30) < 0.005, "floor 0.10 deepens noon to 10% exposure")
	ck(absf(nvg._day_factor - 0.10) < 0.001, "floor 0.10 snaps the day factor")
	ck(absf(nvg._day_mix - 1.0) < 0.001, "floor 0.10 keeps the curve at full strength")
	w["map"].free()

func t_day_trim_darkens_background() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	var sim: FakeSim = w["sim"]
	_reset(nvg, env, sim, 1200.0, 2)
	nvg.set_day_trim = 0.5
	nvg._daylight_tick(1.0)
	ck(absf(nvg._day_trim - 0.5) < 0.001, "winter noon applies the day trim")
	ck(absf(nvg._snow_trim - Daylight.SNOW_TRIM_DAY) < 0.001, "winter noon keeps the snow trim")
	w["map"].free()
	var w2 := _world()
	var nvg2 = w2["nvg"]
	var env2: Environment = w2["env"]
	var sim2: FakeSim = w2["sim"]
	_reset(nvg2, env2, sim2, 0.0, 2)
	nvg2.set_day_trim = 0.5
	nvg2._daylight_tick(1.0)
	ck(absf(nvg2._day_trim - 1.0) < 0.001, "winter midnight sleeps the day trim")
	ck(absf(nvg2._snow_trim - Daylight.SNOW_TRIM_NIGHT) < 0.001, "winter midnight keeps the night snow trim")
	w2["map"].free()

func t_day_trim_default_calibration() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	var sim: FakeSim = w["sim"]
	_reset(nvg, env, sim, 1200.0)
	nvg._daylight_tick(1.0)
	ck(absf(nvg._day_trim - 0.62) < 0.001, "default DAY_TRIM applies the 2026-11-11 calibration")
	ck(absf(env.tonemap_exposure - 0.66) < 0.005, "default floor keeps the noon exposure")
	w["map"].free()

func t_refresh_snaps_without_lag() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	var sim: FakeSim = w["sim"]
	var data: FakeData = nvg._game_data
	data.NVG = true
	_reset(nvg, env, sim, 1200.0)
	nvg._daylight_tick(1.0)
	ck(absf(env.tonemap_exposure - 0.66) < 0.005, "noon settles at 22% exposure")
	nvg.set_day_floor = 0.10
	nvg._daylight_tick(0.016)
	ck(absf(env.tonemap_exposure - 0.66) < 0.02, "a bare tick only creeps toward the new floor")
	nvg.refresh_daylight_now()
	ck(absf(env.tonemap_exposure - 0.30) < 0.005, "refresh snaps to the new floor at once")
	w["map"].free()

func t_reset_returns_levers() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	var sim: FakeSim = w["sim"]
	_reset(nvg, env, sim, 1200.0, 2)
	nvg.set_day_floor = 0.10
	nvg.set_day_trim = 0.5
	nvg._daylight_tick(1.0)
	ck(absf(nvg._day_trim - 0.5) < 0.001, "lever trim applied before the reset")
	nvg._reset_daylight()
	ck(absf(nvg.set_day_floor - Daylight.MIN_FACTOR) < 0.001, "reset returns the floor lever to the constant")
	ck(absf(nvg.set_day_trim - Daylight.DAY_TRIM) < 0.001, "reset returns the trim lever to the constant")
	ck(absf(nvg._day_trim - 1.0) < 0.001, "reset clears the applied day trim")
	w["map"].free()
