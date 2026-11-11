extends Node
# The daylight calibration instrument: a tiny 64x36 SubViewport that shares
# the game's World3D, so it sees exactly the picture the screen shader
# paints over. measure() mirrors the picture camera, renders one frame,
# reads it back and hands the image to VTKStats. At rest the viewport is
# dark: 3D off, no updates, zero cost until a measurement is asked for.
#
# The probe camera carries NO Environment of its own on purpose: it
# inherits the game's WorldEnvironment through the shared world, which is
# the whole point -- the measured luminance must include the NVG tonemap
# exposure the shader compensates for. A private Environment would measure
# a different picture than the one on screen.
#
# ESP shells live on EspMask.LAYER_MASK and are excluded from the probe's
# cull mask: the instrument measures the world, not the overlay. The game
# camera's own mask belongs to VTKEspMask; this module only reads it.

const EspMask = preload("res://mods/ThermalVTK/VTKEspMask.gd")
const Stats = preload("res://mods/ThermalVTK/VTKStats.gd")

# 16:9 and ~2.3k samples: coarse enough for a ~13 ms readback on button
# press, fine enough for stable p05/p95 of the frame.
const SIZE := Vector2i(64, 36)

var _vp: SubViewport = null
var _cam: Camera3D = null

func _ready() -> void:
	name = "VTKSceneProbe"
	_vp = SubViewport.new()
	_vp.name = "ProbeViewport"
	# Same recipe as VTKEspMask._ready, minus everything pictorial: the
	# probe never renders at rest and carries no lights or shadows of its
	# own -- only the measured picture matters.
	_vp.own_world_3d = false
	_vp.transparent_bg = false
	_vp.size = SIZE
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	_vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_vp.positional_shadow_atlas_size = 0
	_vp.use_taa = false
	_vp.use_debanding = false
	_vp.disable_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)

	_cam = Camera3D.new()
	_cam.name = "ProbeCamera"
	# No environment here (see the header): the shared world's WorldEnvironment
	# must reach the probe frame untouched.
	_cam.cull_mask = 0xFFFFFFFF & ~EspMask.LAYER_MASK
	_vp.add_child(_cam)
	# `current` only takes effect once the camera is inside the viewport: set
	# it after add_child, or the viewport renders with no camera at all.
	_cam.current = true

# Render exactly one frame of the shared world from the picture camera's
# pose and return Stats.from_image() of it. Async by necessity: the render
# lands after the current frame's draw, and the readback needs the finished
# pixels. Returns {} when there is nothing to measure (no tree, no camera,
# no viewport, unreadable frame). Pause-safe: process_frame and
# frame_post_draw are tree signals and rendering runs while paused, so the
# panel works from the pause menu too.
func measure(main: Viewport) -> Dictionary:
	if _vp == null or _cam == null:
		return {}
	if main == null or not is_inside_tree():
		return {}
	var cam := main.get_camera_3d()
	if cam == null:
		return {}
	_sync_camera(cam)
	_vp.disable_3d = false
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = readback(_vp.get_texture())
	var out: Dictionary = Stats.from_image(img)
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.disable_3d = true
	return out

# Read a texture back into an Image. A viewport's frame lives in its
# texture: SubViewport has no get_image() in 4.6, and calling that ghost
# API aborts measure() mid-flight -- the panel then reports nothing while
# the viewport stays hot. Static and texture-in, so it runs headless on a
# live ImageTexture (test_stats.gd); a null texture reads back as null,
# which Stats.from_image treats as nothing to measure.
static func readback(tex: Texture2D) -> Image:
	if tex == null:
		return null
	return tex.get_image()

# Copy the picture camera's pose and optics wholesale -- the same list
# VTKEspMask.sync mirrors, with two probe-specific differences: `far` comes
# straight from the game camera (the instrument wants the whole frame, not
# the reach-clipped mask view), and `attributes` rides along so anything
# the game applies through camera attributes matches the picture. The game
# camera is read-only here: EspMask owns clearing its cull mask.
func _sync_camera(cam: Camera3D) -> void:
	_cam.global_transform = cam.global_transform
	_cam.projection = cam.projection
	_cam.fov = cam.fov
	_cam.size = cam.size
	_cam.near = cam.near
	_cam.far = cam.far
	_cam.keep_aspect = cam.keep_aspect
	_cam.h_offset = cam.h_offset
	_cam.v_offset = cam.v_offset
	_cam.frustum_offset = cam.frustum_offset
	_cam.attributes = cam.attributes
	_cam.cull_mask = cam.cull_mask & ~EspMask.LAYER_MASK
