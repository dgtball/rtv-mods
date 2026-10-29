extends SceneTree

const NVG = preload("res://mods/ThermalVTK/VTKNVG.gd")

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
	ck(absf(env.tonemap_exposure - 0.99) < 0.005, "noon lowers exposure to 33%")
	ck(absf(nvg._day_factor - 0.33) < 0.001, "noon sets the day factor floor")
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
	ck(absf(env.tonemap_exposure - 0.825) < 0.005, "the rewrite is compensated from the new baseline")
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
