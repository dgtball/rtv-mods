extends SceneTree

const Labels = preload("res://mods/ThermalVTK/VTKLabels.gd")

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
	t_name_of()
	t_header()
	t_status()
	t_trigger_suffix()
	t_health_frac()
	print("")
	if fails == 0:
		print("tests passed")
		quit(0)
	else:
		print("labels tests failed: ", fails)
		quit(1)

func t_name_of() -> void:
	ck(Labels.name_of("Bandit", "") == "Bandit", "variant name kept without nickname")
	ck(Labels.name_of("Bandit", "   ") == "Bandit", "blank nickname falls back to variant name")
	ck(Labels.name_of("Bandit", " Vanya ") == "Vanya", "nickname wins and is trimmed")

func t_header() -> void:
	ck(Labels.header("Bandit", 42.0) == "Bandit  42 m", "whole metre header")
	ck(Labels.header("Bandit", 42.7) == "Bandit  43 m", "rounded distance")

func t_status() -> void:
	ck(Labels.status(9, false, "") == "Hunt", "bare state name")
	ck(Labels.status(9, true, "") == "Hunt, reloading", "reload suffix")
	ck(Labels.status(9, false, "vs you") == "Hunt vs you", "vs player")
	ck(Labels.status(9, true, "vs Bandit_2") == "Hunt, reloading vs Bandit_2", "reload then vs")

func t_trigger_suffix() -> void:
	ck(Labels.trigger_suffix({}, 10.0) == "", "empty window: empty suffix")
	var win: Dictionary = {"source": "fire", "dist": 50.0, "expires": 13.4, "span": 3.0}
	ck(Labels.trigger_suffix(win, 10.0) == "  [fire 3.4s 50m]", "live window counts down")
	var expired: Dictionary = {"source": "fire", "dist": 50.0, "expires": 9.5, "span": 3.0}
	ck(Labels.trigger_suffix(expired, 10.0) == "", "expired window leaves no suffix")

func t_health_frac() -> void:
	ck(Labels.health_frac(0.0, 100.0) == 0.0, "zero health reads 0")
	ck(Labels.health_frac(50.0, 100.0) == 0.5, "half health")
	ck(Labels.health_frac(200.0, 100.0) == 1.0, "overkill clamps to 1")
	ck(Labels.health_frac(50.0, 0.0) == 1.0, "no max falls back to 1")
