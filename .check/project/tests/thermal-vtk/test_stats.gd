extends SceneTree

const Stats = preload("res://mods/ThermalVTK/VTKStats.gd")
const SceneProbe = preload("res://mods/ThermalVTK/VTKSceneProbe.gd")
const EspMask = preload("res://mods/ThermalVTK/VTKEspMask.gd")

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
	t_percentile_interpolates()
	t_percentile_keeps_input_order()
	t_percentile_empty()
	t_image_uniform()
	t_image_half_black_half_cream()
	t_image_empty()
	t_probe_rests_dark()
	t_probe_excludes_shells()
	print("")
	if fails == 0:
		print("Stats tests passed")
		quit(0)
	else:
		print("Stats tests failed: ", fails)
		quit(1)

func t_percentile_interpolates() -> void:
	var q_half: Array[float] = [0.5]
	var odd: Array[float] = [1.0, 2.0, 3.0, 4.0, 5.0]
	var p := Stats.percentiles(odd, q_half)
	ck(abs(float(p[0.5]) - 3.0) < 0.0001, "odd n=5, q=0.5 -> 3.0 (exact member)")
	var even: Array[float] = [1.0, 2.0, 3.0, 4.0]
	p = Stats.percentiles(even, q_half)
	ck(abs(float(p[0.5]) - 2.5) < 0.0001, "even n=4, q=0.5 -> 2.5 (interpolated)")
	var q_ends: Array[float] = [0.0, 1.0]
	p = Stats.percentiles(odd, q_ends)
	ck(abs(float(p[0.0]) - 1.0) < 0.0001, "q=0.0 -> minimum")
	ck(abs(float(p[1.0]) - 5.0) < 0.0001, "q=1.0 -> maximum")

func t_percentile_keeps_input_order() -> void:
	var v: Array[float] = [3.0, 1.0, 2.0]
	var q: Array[float] = [0.5]
	Stats.percentiles(v, q)
	ck(v[0] == 3.0 and v[1] == 1.0 and v[2] == 2.0, "input array order preserved")

func t_percentile_empty() -> void:
	var v: Array[float] = []
	var q: Array[float] = [0.5]
	var p := Stats.percentiles(v, q)
	ck(p.is_empty(), "empty input -> empty dictionary")

func t_image_uniform() -> void:
	var img := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 0.5))
	var s := Stats.from_image(img)
	ck(abs(float(s.p05) - 0.5) < 0.01 and abs(float(s.p50) - 0.5) < 0.01 and abs(float(s.p95) - 0.5) < 0.01, "uniform gray: p05 = p50 = p95 ~ 0.5")
	ck(abs(float(s.mean) - 0.5) < 0.01, "uniform gray: mean ~ 0.5")
	ck(float(s.black_share) == 0.0 and float(s.cream_share) == 0.0, "uniform gray: no black, no cream")
	ck(int(s.count) == 64, "8x8 image under max_samples -> all 64 pixels sampled")

func t_image_half_black_half_cream() -> void:
	var img := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0))
	for y in 8:
		for x in range(4, 8):
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0))
	var s := Stats.from_image(img)
	ck(abs(float(s.black_share) - 0.5) < 0.001, "left half black -> black_share ~ 0.5")
	ck(abs(float(s.cream_share) - 0.5) < 0.001, "right half white -> cream_share ~ 0.5")
	ck(abs(float(s.p05)) < 0.001, "half black -> p05 ~ 0")
	ck(abs(float(s.p95) - 1.0) < 0.001, "half white -> p95 ~ 1")

func t_image_empty() -> void:
	ck(Stats.from_image(Image.new()).is_empty(), "blank image (w = 0) -> empty dictionary")
	ck(Stats.from_image(null).is_empty(), "null image -> empty dictionary")

# The probe's rest state is what makes it free when the panel is closed: no
# updates, no 3D, but the shared world and the camera-less private
# environment stay wired so the first measure() is valid.
func t_probe_rests_dark() -> void:
	var probe = SceneProbe.new()
	root.add_child(probe)
	ck(probe._vp.size == Vector2i(64, 36), "probe viewport rests at 64x36")
	ck(probe._vp.disable_3d == true, "probe viewport rests with 3D off")
	ck(probe._vp.render_target_update_mode == SubViewport.UPDATE_DISABLED, "probe viewport rests without updates")
	ck(probe._vp.own_world_3d == false, "probe viewport inherits the game world")
	ck(probe._cam.environment == null, "probe camera carries no private environment")
	probe.free()

func t_probe_excludes_shells() -> void:
	var probe = SceneProbe.new()
	root.add_child(probe)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.cull_mask = 0xFFFFFFFF
	probe._sync_camera(cam)
	var want: int = 0xFFFFFFFF & ~EspMask.LAYER_MASK
	ck(probe._cam.cull_mask == want, "probe camera drops the ESP shell layer")
	ck(cam.cull_mask == 0xFFFFFFFF, "the game camera's mask is untouched")
	probe.free()
	cam.free()
