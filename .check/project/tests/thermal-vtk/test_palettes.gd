extends SceneTree

const P = preload("res://mods/ThermalVTK/VTKPalettes.gd")

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
	t_count()
	t_classic_matches_246()
	t_every_palette_has_five_stops()
	t_ladder()
	t_luminance_ascends()
	t_index_is_clamped()
	t_stops_are_a_copy()
	print("")
	if fails == 0:
		print("Palette tests passed")
		quit(0)
	else:
		print("Palette tests failed: ", fails)
		quit(1)

func t_count() -> void:
	ck(P.count() == 4, "four palettes")

func t_classic_matches_246() -> void:
	var want: Array[Color] = [
		Color(0.00, 0.00, 0.03), Color(0.24, 0.10, 0.38), Color(0.65, 0.00, 0.10),
		Color(0.90, 0.65, 0.00), Color(1.00, 1.00, 0.80),
	]
	ck(P.stops(0) == want, "classic stops are the 2.4.6 ramp")

func t_every_palette_has_five_stops() -> void:
	for i in P.count():
		ck(P.stops(i).size() == 5, "palette %d has five stops" % i)

func t_ladder() -> void:
	ck(P.LADDER.size() == 5, "ladder has five edges")
	ck(is_equal_approx(P.LADDER[0], 0.0) and is_equal_approx(P.LADDER[4], 1.0), "ladder spans 0..1")
	ck(is_equal_approx(P.output(), 0.7), "output factor is the 2.4.6 0.7")

func t_luminance_ascends() -> void:
	for i in P.count():
		ck(P.is_ascending(i), "palette %d ascends in luminance" % i)
	ck(P.luma(P.stops(0)[1]) < P.luma(P.stops(0)[2]), "classic stop 1 sits below stop 2")

func t_index_is_clamped() -> void:
	ck(P.stops(99) == P.stops(3), "an index past the end clamps to the last palette")
	ck(P.stops(-5) == P.stops(0), "a negative index clamps to the first palette")

func t_stops_are_a_copy() -> void:
	var s := P.stops(0)
	s[0] = Color(1.0, 0.0, 1.0)
	ck(P.stops(0)[0] == Color(0.0, 0.0, 0.03), "mutating the returned array leaves the table alone")
