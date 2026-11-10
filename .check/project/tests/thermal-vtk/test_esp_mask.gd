extends SceneTree

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
	await t_layer()
	await t_lifecycle()
	await t_camera_sync()
	await t_reach()
	print("")
	if fails == 0:
		print("ESP mask tests passed")
		quit(0)
	else:
		print("ESP mask tests failed: ", fails)
		quit(1)

# The mask layer must be a free bit: 1 is the world, 2 the rig and 3..4 are in
# the optic camera's cull mask, so a shell on any of those would leak into the
# main picture or into the scope view.
func t_layer() -> void:
	var l: int = EspMask.LAYER_MASK
	ck(l > 0, "mask layer is set")
	ck((l & (l - 1)) == 0, "mask layer is a single bit")
	for used in [1, 2, 4, 8]:
		ck((l & used) == 0, "mask layer does not overlap game layer %d" % used)

# Off by default: the mask costs a second world pass, so nothing renders until
# the contour layer asks for it.
func t_lifecycle() -> void:
	var m = EspMask.new()
	root.add_child(m)
	await process_frame
	ck(not m.is_enabled(), "mask starts disabled")
	ck(m._vp.render_target_update_mode == SubViewport.UPDATE_DISABLED, "disabled mask does not render")
	ck(m._vp.disable_3d, "disabled mask skips 3D")
	ck(m._vp.msaa_3d == Viewport.MSAA_4X, "mask keeps the picture's MSAA for a smooth ring edge")
	ck(m._vp.own_world_3d == false, "mask inherits the game world")
	ck(m._vp.find_world_3d() == root.find_world_3d(), "mask renders the same World3D as the game")
	m.set_enabled(true)
	ck(m.is_enabled(), "mask enables")
	ck(m._vp.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "enabled mask renders every frame")
	ck(not m._vp.disable_3d, "enabled mask renders 3D")
	ck(m.texture() != null, "mask exposes a viewport texture")
	m.set_enabled(false)
	ck(m._vp.render_target_update_mode == SubViewport.UPDATE_DISABLED, "mask stops rendering when disabled")
	m.queue_free()
	await process_frame

# The mask camera is a copy of the picture camera: transform, fov and the
# projection fields the scope animates, plus the shell layer.
func t_camera_sync() -> void:
	var main := SubViewport.new()
	main.size = Vector2i(640, 360)
	root.add_child(main)
	var cam := Camera3D.new()
	cam.position = Vector3(1.0, 2.0, 3.0)
	cam.rotation = Vector3(0.1, 0.2, 0.3)
	cam.fov = 37.0
	cam.near = 0.07
	cam.far = 512.0
	cam.cull_mask = 1 | 2
	cam.current = true
	main.add_child(cam)
	var m = EspMask.new()
	root.add_child(m)
	await process_frame
	ck(main.get_camera_3d() == cam, "picture camera is current")
	# The game camera defaults to every layer; the mask bit must be taken off
	# it, or the shells (mask materials) would draw straight into the picture.
	cam.cull_mask = 1 | 2 | EspMask.LAYER_MASK
	m.set_enabled(true)
	m.sync(main)
	await process_frame
	var mc: Camera3D = m._cam
	ck(mc.global_transform.origin.is_equal_approx(cam.global_transform.origin), "mask camera copies the position")
	ck(is_equal_approx(mc.fov, 37.0), "mask camera copies fov (scope zoom)")
	ck(is_equal_approx(mc.near, 0.07) and is_equal_approx(mc.far, 512.0), "mask camera copies near/far")
	ck(mc.projection == cam.projection, "mask camera copies the projection mode")
	ck((cam.cull_mask & EspMask.LAYER_MASK) == 0, "picture camera drops the shell layer")
	ck((mc.cull_mask & 1) != 0 and (mc.cull_mask & 2) != 0, "mask camera renders everything the picture camera does")
	ck((mc.cull_mask & EspMask.LAYER_MASK) != 0, "mask camera also renders the shell layer")
	# The mask is the picture, not a coverage buffer: full resolution, or the
	# ring edge goes soft.
	ck(m._vp.size == Vector2i(640, 360), "mask viewport matches the picture size")
	ck(m.has_camera(), "sync reports a live camera")
	ck(m._cam.far == 512.0, "reach unset copies the picture camera far plane")
	m.set_reach(60.0)
	m.sync(main)
	ck(m._cam.far == 70.0, "set_reach clips the mask camera to reach + margin")
	m.set_enabled(false)
	m.queue_free()
	main.queue_free()
	await process_frame


# Demand gate: the second world pass must not run while nothing is visible.
func t_reach() -> void:
	var main := SubViewport.new()
	main.size = Vector2i(640, 360)
	root.add_child(main)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 0)
	cam.fov = 90.0
	cam.near = 0.1
	cam.far = 1000.0
	cam.cull_mask = 1 | 2
	main.add_child(cam)
	var m = EspMask.new()
	root.add_child(m)
	await process_frame
	ck(not m.is_enabled(), "mask starts disabled before demand")
	m.set_reach(60.0)
	m.set_enabled(true)
	m.sync(main)
	ck(m._cam.far == 70.0, "mask camera far follows reach")
	m.set_enabled(false)
	m.queue_free()
	main.queue_free()
	await process_frame
