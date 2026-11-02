extends RefCounted
# Owns one mask material per NPC and renders it on dedicated ghost shells
# (sibling MeshInstance3D copies, the approach reference outline mods use):
# same mesh/skin/skeleton, transform mirrored every frame, material_override,
# shadow casting off.
#
# Since 2.4.0 the shells write into the ESP mask viewport (VTKEspMask) instead
# of emitting colour keys into the frame. Consequences:
#   - the shells live on LAYER_MASK, so the main camera and the optic's PIP
#     viewport never draw them: only the mask camera does;
#   - the mask camera renders the world too, so the ring is depth-tested
#     against walls, the weapon and the sight glass without any extra work;
#   - the state colour never passes through the tonemap, so it cannot wash;
#   - a live x-ray window swaps the entry to the depth-free mask shader and the
#     category still reaches the screen through the mask.
#
# State and the x-ray flag come in via `opts`.

const Shaders = preload("res://mods/ThermalVTK/VTKShaders.gd")
const States = preload("res://mods/ThermalVTK/VTKStates.gd")
const Dbg = preload("res://mods/ThermalVTK/VTKDebug.gd")
const EspMask = preload("res://mods/ThermalVTK/VTKEspMask.gd")

# Nodes the mod adds under a bot's subtree (the nomad marker, the debug label,
# the ring shells themselves) carry this meta: the sweep must skip them.
const NO_CONTOUR_META := "vtk_no_contour"
const SHELL_NAME := "VTK_Ring"

# id -> {"meshes": Array, "pairs": Array, "ring": ShaderMaterial,
#        "xray_mat": ShaderMaterial, "fill_body": ShaderMaterial,
#        "fill_ring": ShaderMaterial, "node": Node, "child_count": int}
var _items: Dictionary = {}
# While the scope view is active the band thins (SCOPE_RIM), so the magnified
# view keeps a fine frame. The ring is clipped by the sight glass itself: the
# glass is an opaque mesh in the main camera's view, so it wins the depth test
# in the mask too.
const SCOPE_RIM := 6.0
var _scoped: bool = false
var _clear_pool: Array = []
# Fill diagnostics: last log time per entry.
var _fill_log: Dictionary = {}

func has(id: int) -> bool:
	return _items.has(id)

# Collect the NPC's paintable geometry. GeometryInstance3D (not just
# MeshInstance3D) so MultiMesh/CSG parts are covered, and NO layer/visible
# filter: bot geometry sits on render layer 1, and hidden LODs must still carry
# a shell so the LOD that becomes visible already has it. This mirrors
# VTKNVG._collect_meshes, the same sweep the mine path uses.
func _collect(node: Node, out: Array) -> void:
	if node.has_meta(NO_CONTOUR_META):
		return
	if node is GeometryInstance3D:
		out.append(node)
	for c in node.get_children():
		_collect(c, out)

func _build_ring() -> ShaderMaterial:
	var ring_mat := ShaderMaterial.new()
	ring_mat.shader = Shaders.mask_ring()
	return ring_mat

func _build_xray() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = Shaders.mask_xray()
	return mat

# Full-body style needs two materials chained: the body writes stencil 1, the
# ring reads it and paints only outside the body.
func _build_fill_body() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = Shaders.mask_fill()
	return mat

func _build_fill_ring(body_mat: ShaderMaterial) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = Shaders.mask_ring()
	body_mat.next_pass = mat
	return mat

# Which material the shells should carry right now. X-ray wins over the fill:
# a live reveal must punch through walls even in full-body mode.
func _shell_material(entry: Dictionary) -> Material:
	if bool(entry.get("xray", false)):
		var xray_mat: ShaderMaterial = entry.get("xray_mat")
		if xray_mat != null:
			return xray_mat
	if bool(entry.get("fill_mode", false)):
		var body: ShaderMaterial = entry.get("fill_body")
		if body != null:
			return body
	return entry.get("ring")

func _apply_material(entry: Dictionary) -> void:
	var mat := _shell_material(entry)
	for pair in entry.get("pairs", []):
		var shell = pair.get("shell")
		if shell == null or not is_instance_valid(shell):
			continue
		shell.material_override = mat

# Event-driven per-entry flip: idle rings honour walls; when the frame loop
# passes opts["xray"] for a bot with a live trigger window, that bot's ring
# swaps to the depth-free mask shader and the category still reaches the
# screen through the mask. Dedupe by the stored flag so per-frame opts never
# rebuild the material.
func set_entry_xray(id: int, on: bool) -> void:
	var entry = _items.get(id)
	if entry == null:
		return
	if bool(entry.get("xray", false)) == on:
		return
	entry["xray"] = on
	# The material carries its own uniforms; drop the push cache so the next
	# refresh writes the state again.
	entry["p_key"] = null
	entry["p_grow"] = null
	entry["p_rim"] = null
	entry["p_cool"] = null
	_apply_material(entry)

# The scope flag drives the thin in-scope band.
func set_scoped(on: bool) -> void:
	_scoped = on

func apply(id: int, node: Node, opts: Dictionary) -> void:
	var meshes: Array = []
	_collect(node, meshes)
	if meshes.is_empty():
		Dbg.log("OUTLINE", "apply id=%d meshes=0 child_count=%d" % [id, node.get_child_count()])
		return
	Dbg.log("OUTLINE", "apply id=%d meshes=%d child_count=%d" % [id, meshes.size(), node.get_child_count()])
	var ring_mat := _build_ring()
	var xray_mat := _build_xray()
	var fill_body := _build_fill_body()
	var fill_ring := _build_fill_ring(fill_body)
	var pairs: Array = []
	for m in meshes:
		pairs.append(_make_shell(m, ring_mat))
	_items[id] = {
		"meshes": meshes, "pairs": pairs, "ring": ring_mat, "xray_mat": xray_mat,
		"fill_body": fill_body, "fill_ring": fill_ring, "fill_mode": false,
		"node": node, "child_count": node.get_child_count(),
		"xray": false,
	}
	refresh(id, opts)

# Ghost shell beside each mesh. It carries only the mask layer, so no picture
# camera draws it; the mask camera (cull mask | LAYER_MASK) does, and its depth
# buffer already holds the world, which is what clips the ring.
func _make_shell(src: GeometryInstance3D, ring_mat: ShaderMaterial) -> Dictionary:
	var pair := {"src": src, "shell": null}
	if not (src is MeshInstance3D):
		# A non-mesh instance has no sibling to copy: it would have to piggyback
		# on material_overlay, which would then draw in the main camera too.
		# NPC rigs are MeshInstance3D; log once per entry and move on.
		return pair
	var mi := src as MeshInstance3D
	var shell := MeshInstance3D.new()
	shell.name = SHELL_NAME
	shell.mesh = mi.mesh
	shell.skin = mi.skin
	shell.skeleton = mi.skeleton
	shell.transform = mi.transform
	shell.material_override = ring_mat
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Ghost shells must follow the source's visibility rules. The game LODs
	# its rig with GeometryInstance3D.visibility_range_end (see AI.gd), which
	# a sibling copy does not inherit: without this the hidden LOD's shell
	# keeps drawing at every distance, doubling the transparent geometry.
	shell.layers = EspMask.LAYER_MASK
	shell.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	shell.visible = mi.visible
	_mirror_range(mi, shell)
	var fade = mi.get("visibility_range_fade_mode")
	if fade != null:
		shell.set("visibility_range_fade_mode", fade)
	shell.set_meta(NO_CONTOUR_META, true)
	var p := mi.get_parent()
	if p == null:
		shell.queue_free()
		return pair
	p.add_child(shell)
	pair["shell"] = shell
	return pair

# The game assigns LOD ranges in AI.Initialize(), after the rig is in the tree,
# so the shell inherits a real range only if it is copied late enough. Run at
# creation and on every recollect (rig rebuild), not per frame: reading every
# source each frame cost more than the transient mismatch it prevented.
func _mirror_range(src: GeometryInstance3D, shell: MeshInstance3D) -> void:
	if shell.visibility_range_begin != src.visibility_range_begin:
		shell.visibility_range_begin = src.visibility_range_begin
		shell.visibility_range_begin_margin = src.visibility_range_begin_margin
	if shell.visibility_range_end != src.visibility_range_end:
		shell.visibility_range_end = src.visibility_range_end
		shell.visibility_range_end_margin = src.visibility_range_end_margin

func _free_pairs(id: int) -> void:
	var entry: Dictionary = _items[id]
	for pair in entry.get("pairs", []):
		var shell = pair.get("shell")
		if shell != null and is_instance_valid(shell):
			shell.queue_free()

# The rig is assembled/rewired at runtime (AI.Initialize, LOD/gear swaps), and
# pooled bots are reused with a rebuilt subtree, so a one-shot snapshot goes
# stale. Mirror VTKNVG: re-sweep when the child count moves and re-apply.
func _recollect(id: int, entry: Dictionary) -> void:
	var node = entry.get("node")
	if node == null or not is_instance_valid(node):
		return
	var before := int(entry.get("child_count", -1))
	_free_pairs(id)
	var fresh: Array = []
	_collect(node, fresh)
	Dbg.log("OUTLINE", "recollect id=%d child_count=%d->%d meshes=%d" % [id, before, node.get_child_count(), fresh.size()])
	if fresh.is_empty():
		return
	var ring_mat: ShaderMaterial = entry["ring"]
	var pairs: Array = []
	for m in fresh:
		pairs.append(_make_shell(m, ring_mat))
	entry["pairs"] = pairs
	entry["meshes"] = fresh
	entry["child_count"] = node.get_child_count()
	# Rebuilt shells start plain: re-apply a live reveal or fill to the new ones.
	if bool(entry.get("xray", false)) or bool(entry.get("fill_mode", false)):
		_apply_material(entry)

func refresh(id: int, opts: Dictionary) -> void:
	var entry = _items.get(id)
	if entry == null:
		return
	set_entry_xray(id, bool(opts.get("xray", false)))
	set_entry_fill(id, bool(opts.get("fill", false)))
	var node = entry.get("node")
	if node != null and is_instance_valid(node) and node.get_child_count() != int(entry.get("child_count", -1)):
		_recollect(id, entry)
	var color: Color = States.mask_key(int(opts.get("cat", States.NORMAL)))
	var grow := float(opts.get("grow", 0.006))
	var cool := float(opts.get("cool", 0.0))

	var ring_mat: ShaderMaterial = entry["ring"]
	var xray_mat: ShaderMaterial = entry.get("xray_mat")
	var pulse := 0.0

	# Compare the last pushed value instead of reading the uniform back: a
	# get_shader_parameter round-trip per NPC per frame was pure overhead, and
	# the category only moves when the bot's category changes.
	if entry.get("p_key") != color:
		ring_mat.set_shader_parameter("state_color", color)
		if xray_mat != null:
			xray_mat.set_shader_parameter("state_color", color)
		entry["p_key"] = color
	if entry.get("p_grow") == null or not is_equal_approx(float(entry["p_grow"]), grow):
		ring_mat.set_shader_parameter("grow", grow)
		if xray_mat != null:
			xray_mat.set_shader_parameter("grow", grow)
		entry["p_grow"] = grow

	var rim_user := float(opts.get("rim", 1.0))
	if Dbg.enabled and rim_user <= 0.01 and int(_fill_log.get(id, -1)) != int(opts.get("cat", 0)):
		var t_ms := Time.get_ticks_msec()
		if t_ms - int(_fill_log.get(id, -100000)) >= 2000:
			_fill_log[id] = int(opts.get("cat", 0))
			Dbg.log("FILL", "id=%d cat=%d color=%.2f/%.2f/%.2f rim=%.2f xray=%s" % [id, int(opts.get("cat", 0)), color.r, color.g, color.b, rim_user, str(bool(opts.get("xray", false)))])
	# Rim 0 is the full-body fill mode, and the scope band override must not
	# replace it: the fill has to show in the optic exactly where it is tested.
	var rim := SCOPE_RIM if (_scoped and rim_user > 0.01) else rim_user
	if entry.get("p_rim") == null or not is_equal_approx(float(entry["p_rim"]), rim):
		ring_mat.set_shader_parameter("rim_power", rim)
		if xray_mat != null:
			xray_mat.set_shader_parameter("rim_power", rim)
		entry["p_rim"] = rim

	if entry.get("p_cool") == null or not is_equal_approx(float(entry["p_cool"]), cool):
		ring_mat.set_shader_parameter("cool", cool)
		if xray_mat != null:
			xray_mat.set_shader_parameter("cool", cool)
		entry["p_cool"] = cool

	# The full-body pair shares the same category and rim feel.
	var fill_body: ShaderMaterial = entry.get("fill_body")
	var fill_ring: ShaderMaterial = entry.get("fill_ring")
	if fill_body != null and fill_ring != null:
		fill_body.set_shader_parameter("state_color", color)
		fill_body.set_shader_parameter("cool", cool)
		fill_body.set_shader_parameter("grow", float(opts.get("fill_grow", 0.004)))
		fill_body.set_shader_parameter("alpha", float(opts.get("fill_alpha", 0.85)))
		fill_ring.set_shader_parameter("state_color", color)
		fill_ring.set_shader_parameter("grow", grow)
		fill_ring.set_shader_parameter("rim_power", rim)
		fill_ring.set_shader_parameter("cool", cool)
	# The reveal belongs to the shell material swap; nothing to push per frame.
	entry["p_pulse"] = pulse

func set_entry_fill(id: int, on: bool) -> void:
	var entry = _items.get(id)
	if entry == null:
		return
	if bool(entry.get("fill_mode", false)) == on:
		return
	entry["fill_mode"] = on
	_apply_material(entry)

func clear(id: int) -> void:
	var entry = _items.get(id)
	if entry == null:
		return
	_free_pairs(id)
	_items.erase(id)

func clear_all() -> void:
	for id in _items.keys():
		clear(id)

func clear_not_in(keep: Dictionary) -> void:
	_clear_pool.clear()
	for id in _items:
		if not keep.has(id):
			_clear_pool.append(id)
	for id in _clear_pool:
		clear(id)
