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
	t_day_lowers_exposure()
	t_night_is_untouched()
	t_dark_scene_is_untouched()
	t_overbright_hits_the_floor()
	t_target_lever_moves_the_day()
	t_strength_zero_keeps_vanilla()
	t_shelter_short_circuits()
	t_missing_world_keeps_vanilla()
	t_snapshot_reads_world()
	t_vanilla_rewrite_rebaselines()
	t_toggle_restores_exposure()
	t_day_trim_from_mix()
	t_refresh_snaps_without_lag()
	t_source_b_writes_loop_factor()
	t_source_b_seeds_from_a()
	t_source_b_measured_updates_loop()
	t_source_b_reseeds_after_reset()
	t_source_b_night_stays_vanilla()
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
# under test does NOT re-read the world: these tests drive the exposure from a
# known E, and only the snapshot test touches the tree itself.
func _reset(nvg, env: Environment, sim: FakeSim, e: float, season: int = 1) -> void:
	sim.season = season
	nvg._sim_season = season
	nvg._sim_indoor = false
	nvg._sim_shelter = false
	nvg._sim_cd = 999.0
	nvg._light_est = e
	nvg._last_exposure = -1.0
	nvg._day_factor = 1.0
	nvg._day_mix = 0.0
	nvg._key_gain = 1.0
	nvg._factor_a = 1.0
	nvg._vanilla_exposure = 3.0
	nvg.set_day_target = Daylight.TARGET
	nvg.set_day_floor = Daylight.FLOOR
	nvg.set_day_trim = Daylight.DAY_TRIM
	env.tonemap_exposure = 3.0

func t_day_lowers_exposure() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	var sim: FakeSim = w["sim"]
	_reset(nvg, env, sim, 1.0)
	nvg._daylight_tick(1.0)
	ck(absf(env.tonemap_exposure - 0.66) < 0.005, "a bright scene lowers exposure to 22%")
	ck(absf(nvg._day_factor - 0.22) < 0.001, "the day factor lands on TARGET")
	ck(absf(nvg._day_mix - 1.0) < 0.001, "the shader curve runs at full strength")
	ck(nvg._key_gain > 3.0, "the key gain rises to compensate")
	w["map"].free()

func t_night_is_untouched() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	var sim: FakeSim = w["sim"]
	_reset(nvg, env, sim, 0.03)
	nvg._daylight_tick(1.0)
	ck(is_equal_approx(env.tonemap_exposure, 3.0), "night keeps the vanilla exposure")
	ck(is_equal_approx(nvg._key_gain, 1.0), "night keeps the key gain at 1")
	ck(is_equal_approx(nvg._day_mix, 0.0), "night leaves the curve off")
	w["map"].free()

func t_dark_scene_is_untouched() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	var sim: FakeSim = w["sim"]
	_reset(nvg, env, sim, 0.15)
	nvg._daylight_tick(1.0)
	ck(is_equal_approx(env.tonemap_exposure, 3.0), "a scene below TARGET is not touched")
	ck(is_equal_approx(nvg._day_factor, 1.0), "a scene below TARGET keeps factor 1.0")
	w["map"].free()

func t_overbright_hits_the_floor() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	var sim: FakeSim = w["sim"]
	_reset(nvg, env, sim, 2.0)
	nvg._daylight_tick(1.0)
	ck(absf(env.tonemap_exposure - 0.36) < 0.005, "a blinding scene bottoms out at the floor")
	ck(absf(nvg._day_factor - Daylight.FLOOR) < 0.001, "the day factor stops at the floor")
	w["map"].free()

func t_target_lever_moves_the_day() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	var sim: FakeSim = w["sim"]
	_reset(nvg, env, sim, 1.0)
	nvg.set_day_target = 0.40
	nvg._daylight_tick(1.0)
	ck(absf(env.tonemap_exposure - 1.20) < 0.005, "a higher target raises the noon exposure")
	ck(absf(nvg._day_factor - 0.40) < 0.001, "the day factor follows the target lever")
	w["map"].free()

func t_strength_zero_keeps_vanilla() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	var sim: FakeSim = w["sim"]
	_reset(nvg, env, sim, 1.0)
	nvg.set_strength = 0.0
	nvg._daylight_tick(1.0)
	ck(is_equal_approx(env.tonemap_exposure, 3.0), "strength 0 keeps the vanilla exposure")
	ck(is_equal_approx(nvg._day_mix, 0.0), "strength 0 leaves the curve off")
	w["map"].free()

func t_shelter_short_circuits() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	var world: FakeWorld = w["world"]
	_reset(nvg, env, w["sim"], 1.0)
	# A bright outdoor scene would land on 0.66; the shelter gate must win.
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 1.0
	env.background_energy_multiplier = 0.0
	env.volumetric_fog_density = 0.0
	world.shelter = true
	nvg._sim_cd = 0.0
	nvg._daylight_tick(1.0)
	ck(is_equal_approx(env.tonemap_exposure, 3.0), "a shelter keeps the vanilla exposure")
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
	nvg._last_exposure = -1.0
	nvg._day_factor = 1.0
	nvg._sim_cd = 0.0
	nvg._daylight_tick(1.0)
	ck(nvg._day_factor == 1.0, "no environment: the day factor stays vanilla")
	ck(nvg._light_est == 0.0, "no environment: the estimate is zero")
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

func t_vanilla_rewrite_rebaselines() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	var sim: FakeSim = w["sim"]
	_reset(nvg, env, sim, 1.0)
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
	_reset(nvg, env, sim, 1.0)
	nvg._daylight_tick(1.0)
	nvg._restore_exposure()
	ck(is_equal_approx(env.tonemap_exposure, 3.0), "toggle off hands the exposure back")
	ck(is_equal_approx(nvg._key_gain, 1.0), "toggle off clears the key gain")
	ck(nvg._last_exposure < 0.0, "toggle off forgets the written value")
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
	ck(absf(env.tonemap_exposure - 0.66) < 0.005, "a bright scene settles at 22% exposure")
	nvg.set_day_target = 0.5
	nvg._daylight_tick(0.016)
	ck(absf(env.tonemap_exposure - 0.66) < 0.02, "a bare tick only creeps toward the new target")
	nvg.refresh_daylight_now()
	ck(absf(env.tonemap_exposure - 1.50) < 0.005, "refresh snaps to the new target at once")
	w["map"].free()

func t_reset_returns_levers() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	var sim: FakeSim = w["sim"]
	_reset(nvg, env, sim, 1.0, 2)
	nvg.set_day_target = 0.5
	nvg.set_day_trim = 0.5
	nvg.set_daylight_source = 1
	nvg._daylight_tick(1.0)
	nvg._reset_daylight()
	ck(absf(nvg.set_day_target - Daylight.TARGET) < 0.001, "reset returns the target lever to the constant")
	ck(absf(nvg.set_day_floor - Daylight.FLOOR) < 0.001, "reset returns the floor lever to the constant")
	ck(absf(nvg.set_day_trim - Daylight.DAY_TRIM) < 0.001, "reset returns the trim lever to the constant")
	ck(absf(nvg.set_frame_target - Daylight.FRAME_TARGET) < 0.001, "reset returns the frame target to the constant")
	ck(absf(nvg.set_frame_cadence - Daylight.FRAME_CADENCE) < 0.001, "reset returns the probe cadence to the constant")
	ck(nvg.set_daylight_source == 1, "the source flag survives a reset")
	ck(absf(nvg._day_trim - 1.0) < 0.001, "reset clears the applied day trim")
	w["map"].free()

func t_source_b_writes_loop_factor() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	var sim: FakeSim = w["sim"]
	_reset(nvg, env, sim, 1.0)
	nvg.set_daylight_source = 1
	# An already-running loop: the write must use its factor, not re-seed.
	nvg._factor_b_live = true
	nvg._factor_b = 0.5
	nvg._day_factor = 0.5
	nvg._daylight_tick(1.0)
	ck(absf(env.tonemap_exposure - 1.5) < 0.005, "source B writes the loop factor, not the light estimate")
	w["map"].free()

func t_source_b_seeds_from_a() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	var sim: FakeSim = w["sim"]
	_reset(nvg, env, sim, 0.55)
	nvg.set_daylight_source = 1
	nvg._target_factor()
	ck(absf(nvg._factor_a - 0.40) < 0.001, "the fresh light estimate gives factor 0.40")
	ck(absf(nvg._factor_b - 0.40) < 0.001, "the first read of source B seeds the loop from source A")
	w["map"].free()

func t_source_b_measured_updates_loop() -> void:
	var w := _world()
	var nvg = w["nvg"]
	_reset(nvg, w["env"], w["sim"], 1.0)
	nvg.set_frame_target = 0.25
	nvg._factor_b = 0.5
	nvg._on_probe_measured({"p50": 0.5})
	ck(nvg._factor_b < 0.5, "a frame brighter than target lowers the loop factor")
	ck(nvg._factor_b >= Daylight.FLOOR, "the loop factor stays above the floor")
	nvg._on_probe_measured({})
	ck(nvg._factor_b < 0.5, "an empty measurement leaves the loop alone")
	w["map"].free()

func t_source_b_reseeds_after_reset() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	var sim: FakeSim = w["sim"]
	_reset(nvg, env, sim, 1.0)
	nvg.set_daylight_source = 1
	nvg._daylight_tick(1.0)
	# A settled loop, then a map change: _reset_daylight drops the loop back to
	# vanilla while the source flag stays on B. Without a re-seed the picture
	# would sit bright for a full probe cadence and then ramp for seconds.
	nvg._factor_b = 0.40
	nvg._reset_daylight()
	nvg._sim_cd = 999.0
	nvg._light_est = 1.0
	nvg._daylight_tick(1.0)
	ck(absf(nvg._factor_b - 0.22) < 0.005, "the loop re-seeds from the light estimate after a reset")
	ck(absf(env.tonemap_exposure - 0.66) < 0.005, "the re-seed reaches the exposure on the same frame")
	w["map"].free()

func t_source_b_night_stays_vanilla() -> void:
	var w := _world()
	var nvg = w["nvg"]
	var env: Environment = w["env"]
	_reset(nvg, env, w["sim"], 0.03)
	nvg.set_daylight_source = 1
	nvg._factor_b = 1.0
	nvg._daylight_tick(1.0)
	ck(is_equal_approx(env.tonemap_exposure, 3.0), "source B leaves the night exposure vanilla")
	w["map"].free()
