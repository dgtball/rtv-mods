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
	t_display_defaults()
	t_palette_hexes()
	t_state_names()
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

func t_display_defaults() -> void:
	var cols := [S.DEFAULT_NORMAL, S.DEFAULT_COMBAT, S.DEFAULT_DEFEND]
	ck(S.DEFAULT_NORMAL != S.DEFAULT_COMBAT, "normal != combat colour")
	ck(S.DEFAULT_COMBAT != S.DEFAULT_DEFEND, "combat != defend colour")
	ck(S.DEFAULT_NORMAL != S.DEFAULT_DEFEND, "normal != defend colour")
	for c in cols:
		ck(c.a > 0.99, "state display colour %s is opaque" % str(c))

func t_palette_hexes() -> void:
	ck(S.DEFAULT_NORMAL == Color8(17, 240, 4), "normal default is #11f004")
	ck(S.DEFAULT_COMBAT == Color8(242, 46, 38), "combat default is #f22e26")
	ck(S.DEFAULT_DEFEND == Color8(223, 245, 28), "defend default is #dff51c")
	ck(S.DEFAULT_MINE == Color8(9, 46, 246), "mine default is #092ef6")

func t_state_names() -> void:
	ck(S.STATE_NAMES.size() == 17, "all AI states are named")
	ck(S.state_name(0) == "Idle", "state 0 is Idle")
	ck(S.state_name(16) == "Group", "state 16 is Group")
	ck(S.state_name(-1) == "State-1", "unknown state name falls back")
	ck(S.state_name(99) == "State99", "out-of-range state name falls back")

func t_mine_colour_differs() -> void:
	ck(S.DEFAULT_MINE != S.DEFAULT_NORMAL and S.DEFAULT_MINE != S.DEFAULT_COMBAT and S.DEFAULT_MINE != S.DEFAULT_DEFEND,
		"the mine colour differs from every state colour")
	ck(S.DEFAULT_MINE.a > 0.99, "the mine colour is opaque")
