extends SceneTree

const S = preload("res://mods/ThermalVTK/VTKStates.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _init() -> void:
	process_frame.connect(_run)

func _run() -> void:
	t_normal_states()
	t_combat_states()
	t_defend_states()
	t_unknown_defaults_to_normal()
	t_colors()
	t_keys()
	t_keys_are_distinct()
	t_mine_colour_differs()
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
	ck(S.state_key(99) == S.KEY_NORMAL, "unknown category falls back to NORMAL")

# The detector matches the CLOSEST washed key, so the raw keys only have to be
# distinct and bright enough to survive the NVG wash; the washed-space spacing
# rule belongs to VTKNVG.DET_ST_* (test_nvg). Two-channel keys are fine here.
func t_keys_are_distinct() -> void:
	var keys := [S.KEY_NORMAL, S.KEY_COMBAT, S.KEY_DEFEND]
	for i in keys.size():
		ck(keys[i].r + keys[i].g + keys[i].b > 0.5, "key %d is bright enough to survive the wash" % i)
		for j in range(i + 1, keys.size()):
			ck(keys[i] != keys[j], "keys %d and %d differ" % [i, j])

# The mine is painted whole by its own material and is not a state: its display
# colour must not collide with any category colour, or the two would be
# unreadable on screen.
func t_mine_colour_differs() -> void:
	ck(S.DEFAULT_MINE != S.DEFAULT_NORMAL and S.DEFAULT_MINE != S.DEFAULT_COMBAT and S.DEFAULT_MINE != S.DEFAULT_DEFEND,
		"the mine colour differs from every state colour")
	ck(S.DEFAULT_MINE.a > 0.99, "the mine colour is opaque")
