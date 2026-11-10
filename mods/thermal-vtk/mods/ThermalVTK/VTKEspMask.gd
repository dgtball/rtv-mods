extends Node
# ESP mask: a second 3D view of the SAME World3D that carries only the NPC
# shells, never the world's colour as a category. VTKNVG.gdshader samples the
# texture and substitutes the state colour, so exposure, tonemap, weather and
# the thermal palette cannot move it.
#
# World: the SubViewport keeps own_world_3d = false, so it inherits the game's
# World3D through the tree, exactly like the optic's PIP viewport does
# (Scripts/PIP.gd rides a SubViewport inside the optic scene). `world_3d`
# reads null on an inheriting viewport -- that is the "inherit" sentinel, not
# a missing world; use find_world_3d()/Camera3D.get_world_3d() to check.
#
# Depth: the world renders into the mask on purpose. Without it the mask has
# no depth buffer and every ring would draw through walls. The shells then
# depth-test against walls, the weapon and the sight glass exactly as the
# main picture does. The mask's own Environment is plain (linear tonemap, no
# glow, no fog) so the emitted category colour stays exact.
#
# Optics: the mask camera mirrors whichever camera produces the main picture.
# Non-PIP scope zoom is free (fov is copied every frame). With PIP the lens
# is an opaque mesh right in front of the main camera, so it occludes the
# shells in the mask: no ESP inside the sight glass (a separate task).
#
# The mask sits on its own render layer (LAYER_MASK). The scope viewport's
# cull mask is 1,3,4 (Scripts/Optic.gd), so the shells are invisible there
# and the mask camera is the only consumer.

# Bit 21 is unused by the game (1 = world, 2 = rig, 3..4 = scope cull mask).
const LAYER_MASK := 1 << 20
# Camera near/far are copied per frame; these are only the fallback before the
# first sync (the mask is disabled until then anyway).
const FALLBACK_NEAR := 0.05
const FALLBACK_FAR := 4000.0
const START_SIZE := Vector2i(320, 180)

# 1.0 full, 0.75, 0.5. At 1:1 linear is equivalent to nearest in practice,
# and at a reduced scale it keeps the upscale soft instead of blocky.
var _scaling: float = 1.0
# The mask runs at the picture's own resolution and with the same MSAA. The
# ring edge is a hard `discard` silhouette, so anything less turns it blurry
# or jagged: this is the picture, not a coverage buffer. Saving cost here is
# the wrong trade -- the demand gate is what makes the pass affordable.
#
# Only rings inside the ESP reach matter, so the mask camera does not need the
# game's far plane. Clipping the world at reach + margin skips every distant
# mesh the mask can never show.
const FAR_MARGIN := 10.0
const MIN_REACH := 30.0

var _vp: SubViewport = null
var _cam: Camera3D = null
var _env: Environment = null
var _texture: Texture2D = null
var _enabled: bool = false
var _size: Vector2i = Vector2i.ZERO
var _synced: bool = false
# 0 = copy the picture camera's far plane; >0 = cap it at reach + FAR_MARGIN.
var _reach: float = 0.0

func _ready() -> void:
	name = "VTKEspMask"
	_vp = SubViewport.new()
	_vp.name = "MaskViewport"
	# Inherit the game world; the mask camera is the only 3D camera here.
	_vp.own_world_3d = false
	_vp.transparent_bg = false
	_vp.size = START_SIZE
	# MSAA 4x on purpose: the shells are hard silhouettes, and the sample
	# coverage is what antialiases the ring. Lowering it visibly steps the
	# contour edge.
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	# The mask only needs coarse depth: its own lights' shadow maps are pure
	# overhead (the shells are unshaded), so suppress the positional shadow
	# atlas and raise LOD bias. Occlusion culling is free if occluders exist.
	_vp.positional_shadow_atlas_size = 0
	_vp.use_occlusion_culling = true
	_vp.mesh_lod_threshold = 0.2
	_vp.use_taa = false
	_vp.use_debanding = false
	_vp.disable_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)

	_env = Environment.new()

	_cam = Camera3D.new()
	_cam.name = "MaskCamera"
	_cam.environment = _env
	_cam.cull_mask = LAYER_MASK
	_cam.near = FALLBACK_NEAR
	_cam.far = FALLBACK_FAR
	_vp.add_child(_cam)
	# `current` only takes effect once the camera is inside the viewport: set it
	# after add_child, or the mask viewport renders with no camera at all.
	_cam.current = true
	_apply_enabled_state()

# The mask costs a second world pass, so it only renders while a ring is on
# screen: ThermalVTK arms the layers and polls VTKESP.wants_mask each frame
# (see _push_mask_gate).
func set_enabled(on: bool) -> void:
	if _enabled == on:
		return
	_enabled = on
	_apply_enabled_state()

# Split from the switch because _ready may run AFTER the first set_enabled (a
# node added from another node's _ready, or before the tree iterates): the
# viewport has to pick the stored state up itself.
func _apply_enabled_state() -> void:
	_synced = false
	if _vp == null:
		return
	_vp.disable_3d = not _enabled
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if _enabled else SubViewport.UPDATE_DISABLED

func is_enabled() -> bool:
	return _enabled

# Longest distance any ring can sit at (the ESP Distance slider or a live
# x-ray window). The mask camera clips the world there instead of at the
# picture camera's far plane, which is what makes the second pass affordable
# outdoors. 0 restores the plain copy.
func set_reach(distance: float) -> void:
	_reach = maxf(distance, 0.0)

func _far_for(cam: Camera3D) -> float:
	if _reach <= 0.0:
		return cam.far
	return minf(cam.far, maxf(MIN_REACH, _reach + FAR_MARGIN))

# The texture the NVG material binds to `esp_mask`. Stable across frames.
# Fractional resolution dial. 1.0 = picture resolution, 0.5/0.75 lower
# the load at the cost of softer ring edges.
func set_scale(scale: float) -> void:
	if scale < 0.5:
		scale = 0.5
	if scale > 1.0:
		scale = 1.0
	if is_equal_approx(scale, _scaling):
		return
	_scaling = scale
	_size = Vector2i.ZERO

# The texture the NVG material binds to `esp_mask`. Stable across frames.
func texture() -> Texture2D:
	if _vp == null:
		return null
	if _texture == null:
		_texture = _vp.get_texture()
	return _texture

func _viewport_size(main: Viewport) -> Vector2i:
	var r := main.get_visible_rect().size
	if r.x < 1.0 or r.y < 1.0:
		return Vector2i.ZERO
	var w := int(r.x * _scaling)
	var h := int(r.y * _scaling)
	if w < 1:
		w = 1
	if h < 1:
		h = 1
	return Vector2i(w, h)

# Mirror the picture camera every frame. All the projection fields the game
# animates for the scope (fov, offsets, frustum) are copied, so the mask follows
# the zoom without knowing anything about the optic.
func sync(main: Viewport) -> void:
	if not _enabled or _vp == null or _cam == null or main == null:
		return
	var cam := main.get_camera_3d()
	if cam == null:
		return
	var size := _viewport_size(main)
	if size == Vector2i.ZERO:
		return
	if size != _size:
		_size = size
		_vp.size = size
	_synced = true
	_cam.global_transform = cam.global_transform
	_cam.projection = cam.projection
	_cam.fov = cam.fov
	_cam.size = cam.size
	_cam.near = cam.near
	_cam.far = _far_for(cam)
	_cam.keep_aspect = cam.keep_aspect
	_cam.h_offset = cam.h_offset
	_cam.v_offset = cam.v_offset
	_cam.frustum_offset = cam.frustum_offset
	# Camera3D.cull_mask defaults to every layer, so the game camera would draw
	# the shells (in the mask material, straight into the picture) unless its
	# mask bit is cleared. Nothing else in the game uses this bit, and clearing
	# it is idempotent: do it here, once per frame, instead of hoping the game
	# camera is configured.
	var world_mask := cam.cull_mask & ~LAYER_MASK
	if cam.cull_mask != world_mask:
		cam.cull_mask = world_mask
	# The world must render (depth), the shells must pass, and nothing else may
	# be added: the mask camera only differs from the picture camera by the
	# extra shell layer.
	_cam.cull_mask = world_mask | LAYER_MASK

func has_camera() -> bool:
	return _synced
