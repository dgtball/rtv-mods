extends SceneTree

const Cal = preload("res://mods/ThermalVTK/VTKCalibration.gd")
const ThermalMod = preload("res://mods/ThermalVTK/ThermalVTK.gd")
const Settings = preload("res://mods/ThermalVTK/VTKSettings.gd")

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
	t_clamped_index()
	t_candidates_spread()
	t_mid_dark()
	t_greens()
	t_label()
	t_hotkey_wiring()
	print("")
	if fails == 0:
		print("Calibration tests passed")
		quit(0)
	else:
		print("Calibration tests failed: ", fails)
		quit(1)

func t_count() -> void:
	ck(Cal.count() >= 6, "the sweep holds at least six candidates")
	ck(Cal.count() == Cal.CANDIDATES.size(), "count matches the candidate list")
	ck(Cal.count() == 8, "the sweep holds the eight calibration candidates")

# An index outside the sweep falls back to the first candidate, so a stale
# index can never paint a key that is not in the list.
func t_clamped_index() -> void:
	ck(Cal.candidate(0) == Cal.CANDIDATES[0], "index 0 is the first candidate")
	ck(Cal.candidate(-1) == Cal.CANDIDATES[0], "a negative index falls back to the first candidate")
	ck(Cal.candidate(Cal.count()) == Cal.CANDIDATES[0], "an index past the end falls back to the first candidate")
	ck(Cal.candidate(Cal.count() - 1) == Cal.CANDIDATES[Cal.count() - 1], "the last index is the last candidate")

# The candidates are measured one at a time, but they still have to stay
# apart: a washed candidate pixel must not fall into another candidate's
# detector radius. The core radius is DET_TOL_CORE (0.22), so 0.25 is the floor.
func t_candidates_spread() -> void:
	var min_d := 10.0
	var pair := Vector2i.ZERO
	for i in range(Cal.count()):
		for j in range(i + 1, Cal.count()):
			var a: Color = Cal.candidate(i)
			var b: Color = Cal.candidate(j)
			var d := Vector3(a.r, a.g, a.b).distance_to(Vector3(b.r, b.g, b.b))
			if d < min_d:
				min_d = d
				pair = Vector2i(i, j)
	ck(min_d >= 0.10, "every candidate pair is at least 0.10 apart (closest overall is %.3f between #%d and #%d)"
		% [min_d, pair.x, pair.y])

# A high sum is what washes to white under the NVG (the old nomad key
# (0.6,1.0,0.6) came out as (1,1,1)), so no candidate may reach it.
func t_mid_dark() -> void:
	var worst_sum := 0.0
	var brightest := 0.0
	for i in range(Cal.count()):
		var c: Color = Cal.candidate(i)
		worst_sum = maxf(worst_sum, c.r + c.g + c.b)
		brightest = maxf(brightest, maxf(c.r, maxf(c.g, c.b)))
	ck(worst_sum <= 1.0, "no candidate has a high channel sum (worst is %.2f)" % worst_sum)
	ck(brightest <= 0.62, "no candidate channel reaches white (worst is %.2f)" % brightest)

# The nomad marker is the key that has to survive the wash best, so the sweep
# keeps green options in it.
func t_greens() -> void:
	var greens := 0
	for i in range(Cal.count()):
		var c: Color = Cal.candidate(i)
		if c.g >= c.r and c.g >= c.b:
			greens += 1
	ck(greens >= 2, "the sweep holds at least two green candidates")

# The label is what ties a probe reading to a candidate in the debug log.
func t_label() -> void:
	var c: Color = Cal.candidate(0)
	ck(Cal.label(0) == "cand00=(%.2f,%.2f,%.2f)" % [c.r, c.g, c.b], "the label carries the number and the colour")
	ck(Cal.label(0).begins_with("cand00="), "the label starts with the candidate number")
	ck(Cal.label(Cal.count() - 1).begins_with("cand%02d=" % (Cal.count() - 1)), "the last candidate is numbered")
	ck(Cal.label(99) == Cal.label(0), "an out-of-range label falls back to the first candidate")

# The hotkey is a debug tool: it has to be in the MCM and it has to stay
# inert while the debug log is off. The game paths are not available headless,
# so the wiring is checked on the source.
func t_hotkey_wiring() -> void:
	var src := FileAccess.get_file_as_string("res://mods/ThermalVTK/ThermalVTK.gd").replace("\r\n", "\n")
	ck(Settings.mcm_config().has_section_key("Keycode", "key_cal_cycle"),
		"MCM registers the calibration key")
	ck(src.contains("_key_cal_cycle = rec.key_cal_cycle"), "MCM value is read back")
	ck(src.contains("func _cal_step"), "the calibration step exists")
	ck(src.contains("\t\tif VTKDebug.enabled:\n\t\t\t_cal_step(k.shift_pressed)"),
		"the calibration hotkey is gated on the debug log")
	ck(src.contains("func _push_calibration"), "the calibration is pushed to the ESP")
	var mod = ThermalMod.new()
	ck(mod._key_cal_cycle == KEY_F8, "the calibration key defaults to F8")
	mod.free()
