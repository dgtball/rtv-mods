extends SceneTree

const S = preload("res://mods/ThermalVTK/VTKStates.gd")

# The widest detector radius: the body fill matches with 0.40 (DET_TOL_FILL
# in VTKNVG.gdshader), the rest with 0.22. Two world keys closer than this
# let one detector claim the other's pixels, so this is the floor for the
# distance between ANY two world keys.
const MIN_KEY_SEPARATION := 0.22

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

# Raw 3D distance, the same measure the overlay shader uses (distance(c, k)).
# Color is a built-in type in Godot 4 and has no distance_to() of its own.
func dist(a: Color, b: Color) -> float:
	return Vector3(a.r, a.g, a.b).distance_to(Vector3(b.r, b.g, b.b))

func _init() -> void:
	process_frame.connect(_run)

func _run() -> void:
	t_normal_states()
	t_combat_states()
	t_defend_states()
	t_unknown_defaults_to_normal()
	t_colors()
	t_keys()
	t_world_key_separation()
	print("")
	if fails == 0:
		print("States tests passed")
		quit(0)
	else:
		print("States tests failed: ", fails)
		quit(1)

func t_normal_states() -> void:
	for s in [0, 1, 2, 3, 4, 16]:
		ck(S.category_of(s) == S.NORMAL, "state %d -> NORMAL" % s)

func t_combat_states() -> void:
	for s in [8, 9, 11, 13]:
		ck(S.category_of(s) == S.COMBAT, "state %d -> COMBAT" % s)

func t_defend_states() -> void:
	for s in [5, 6, 7, 10, 12, 14, 15]:
		ck(S.category_of(s) == S.DEFEND, "state %d -> DEFEND" % s)

func t_unknown_defaults_to_normal() -> void:
	ck(S.category_of(-1) == S.NORMAL, "unknown state -1 -> NORMAL")
	ck(S.category_of(99) == S.NORMAL, "unknown state 99 -> NORMAL")

func t_colors() -> void:
	ck(S.DEFAULT_NORMAL != S.DEFAULT_COMBAT, "normal != combat colour")
	ck(S.DEFAULT_COMBAT != S.DEFAULT_DEFEND, "combat != defend colour")

func t_keys() -> void:
	ck(S.state_key(S.NORMAL) == S.KEY_NORMAL, "state_key(NORMAL)")
	ck(S.state_key(S.COMBAT) == S.KEY_COMBAT, "state_key(COMBAT)")
	ck(S.state_key(S.DEFEND) == S.KEY_DEFEND, "state_key(DEFEND)")

func t_world_key_separation() -> void:
	# After 2.2.0 the friendly-nomad marker is a 2D diamond and no longer
	# emits a world key, so the set under test is the three outline keys plus
	# the mine key.
	var all: Array = []
	all.append_array([S.KEY_NORMAL, S.KEY_COMBAT, S.KEY_DEFEND])
	all.append(Color(0.0, 0.0, 1.0)) # MINE_KEY
	var min_sep := 99.0
	var min_pair := ""
	for a in all.size():
		for b in range(a + 1, all.size()):
			var d := dist(all[a], all[b])
			if d < min_sep:
				min_sep = d
				min_pair = "%d,%d" % [a, b]
			ck(d >= MIN_KEY_SEPARATION, "keys %d,%d separated by >= %.2f (got %.3f)" % [a, b, MIN_KEY_SEPARATION, d])
	print("min world-key separation: %.4f (pair %s, rule >= %.2f)" % [min_sep, min_pair, MIN_KEY_SEPARATION])
