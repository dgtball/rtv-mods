extends SceneTree

const Probe = preload("res://mods/ThermalVTK/VTKProbe.gd")
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
	t_center_pixel()
	t_format()
	t_probe_module()
	t_hotkey_wiring()
	print("")
	if fails == 0:
		print("Probe tests passed")
		quit(0)
	else:
		print("Probe tests failed: ", fails)
		quit(1)

func t_center_pixel() -> void:
	ck(Probe.center_pixel(Vector2i(1920, 1080)) == Vector2i(960, 540), "centre of 1920x1080")
	ck(Probe.center_pixel(Vector2i(1280, 720)) == Vector2i(640, 360), "centre of 1280x720")
	# An odd size has no exact middle, so the probe takes the pixel below it.
	ck(Probe.center_pixel(Vector2i(1921, 1081)) == Vector2i(960, 540), "centre of odd 1921x1081")
	ck(Probe.center_pixel(Vector2i(1, 1)) == Vector2i(0, 0), "centre of 1x1")
	ck(Probe.center_pixel(Vector2i.ZERO) == Vector2i.ZERO, "centre of an empty frame")

func t_format() -> void:
	ck(Probe.format(Color(0.1, 0.2, 0.3), "raw-thermal") == "probe raw-thermal rgb=(0.100, 0.200, 0.300)",
		"format keeps the hint and three decimals")
	ck(Probe.format(Color(0.0, 0.0, 0.0), "raw-nvg").contains("rgb=(0.000, 0.000, 0.000)"),
		"format of a black pixel")
	ck(Probe.format(Color(1.0, 1.0, 1.0), "raw-nvg").contains("rgb=(1.000, 1.000, 1.000)"),
		"format of a white pixel")

# The frame readback needs a drawn frame, which the headless stand never
# produces, so the wait is asserted on the source.
func t_probe_module() -> void:
	var src := FileAccess.get_file_as_string("res://mods/ThermalVTK/VTKProbe.gd")
	ck(src.contains("await RenderingServer.frame_post_draw"), "probe waits for a drawn frame")
	ck(src.contains("get_texture()") and src.contains("get_image()"), "probe reads the frame back")
	ck(src.contains("get_pixelv(center_pixel("), "probe reads the centre pixel")

# The probe is a debug tool: it must stay silent unless the user turned the
# debug log on, and the hotkey has to be reachable from the MCM. The game
# paths are not available headless, so both are checked on the source.
func t_hotkey_wiring() -> void:
	var src := FileAccess.get_file_as_string("res://mods/ThermalVTK/ThermalVTK.gd")
	ck(src.contains("func _probe_center"), "probe handler exists")
	ck(src.contains("if not VTKDebug.enabled"), "probe is gated on the debug log")
	ck(Settings.mcm_config().has_section_key("Keycode", "key_debug_probe"),
		"MCM registers the probe key")
	ck(src.contains("_key_debug_probe = rec.key_debug_probe"), "MCM value is read back")
	var mod = ThermalMod.new()
	ck(mod._key_debug_probe == KEY_F7, "probe key defaults to F7")
	mod.free()
