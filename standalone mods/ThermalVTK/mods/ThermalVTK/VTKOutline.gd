extends RefCounted
# Owns one ring material per NPC and renders it on dedicated ghost shells
# (sibling MeshInstance3D copies, the approach reference outline mods use):
# same mesh/skin/skeleton, transform mirrored every frame, material_override,
# shadow casting off. The idle ring is a normal depth-tested overlay, so the
# world and the sight hardware clip it; only a live x-ray window swaps to the
# depth-free shader. State colours and the x-ray flag come in via `opts`.

const Shaders = preload("res://mods/ThermalVTK/VTKShaders.gd")
const States = preload("res://mods/ThermalVTK/VTKStates.gd")
const Dbg = preload("res://mods/ThermalVTK/VTKDebug.gd")

# Nodes the mod adds under a bot's subtree (the nomad marker, the debug label,
# the ring shells themselves) carry this meta: the sweep must skip them, or the
# ring material is assigned on top of their own material and paints over the
# key they emit.
const NO_CONTOUR_META := "vtk_no_contour"
const SHELL_NAME := "VTK_Ring"

# id -> {"meshes": Array, "pairs": Array, "ring": ShaderMaterial,
#        "node": Node, "child_count": int}
var _items: Dictionary = {}
# While the scope view is active the band thins (SCOPE_RIM), so the magnified
# view keeps a fine frame. The idle ring uses the normal depth test; the scope
# Mask controls whether the sight glass writes depth, so the ring shows inside
# the lens when the main camera is the picture and stays hidden inside it when
# the optic camera supplies a PIP picture. The x-ray ring widens the carve only
# while its window is live: with the depth test disabled, the wide value keeps
# scope metal and glass from vanishing the ring.
const SCOPE_RIM := 6.0
const CARVE_XRAY := 0.60
var _scoped: bool = false
# gameData.PIP: the picture-in-picture path. True when Settings keeps the
# optic camera render enabled.
var _pip: bool = false

func has(id: int) -> bool:
	return _items.has(id)

func material_of(id: int) -> Dictionary:
	return _items.get(id, {})

# Collect the NPC's paintable geometry. GeometryInstance3D (not just
# MeshInstance3D) so MultiMesh/CSG parts are covered, and NO layer/visible
# filter: bot geometry sits on render layer 1, and hidden LODs must still carry
# a shell/overlay so the LOD that becomes visible already has it. This mirrors
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
	ring_mat.shader = Shaders.ring()
	return ring_mat

# Event-driven per-entry flip: idle rings honour walls; when the frame loop
# passes opts["xray"] for a bot with a live trigger window, that bot's ring
# swaps to the depth-free shader and punches through walls while the optic
# hardware still hides it. Dedupe by the stored flag so per-frame opts never
# rebuild the material.
func set_entry_xray(id: int, on: bool) -> void:
	var entry = _items.get(id)
	if entry == null:
		return
	if bool(entry.get("xray", false)) == on:
		return
	entry["xray"] = on
	# A shader swap may reset uniforms; drop the push cache so the next refresh
	# writes the state again.
	entry["p_key"] = null
	entry["p_grow"] = null
	entry["p_rim"] = null
	entry["p_cool"] = null
	var ring_mat: ShaderMaterial = entry["ring"]
	if ring_mat == null:
		return
	if on:
		ring_mat.shader = Shaders.ring_xray()
		ring_mat.set_shader_parameter("near_only", true)
		ring_mat.set_shader_parameter("carve", CARVE_XRAY)
	else:
		ring_mat.shader = Shaders.ring()

# The scope flag drives the thin in-scope band. The Mask depth-write toggle
# lives in VTKWeaponOcclusion, driven from the same flags by VTKESP.
func set_scoped(on: bool, pip := false) -> void:
	_scoped = on
	_pip = pip

# PIP comes from the settings menu and may flip while aiming; the Mask toggle
# re-reads it on the next frame.
func set_pip(on: bool) -> void:
	_pip = on

func apply(id: int, node: Node, opts: Dictionary) -> void:
	var meshes: Array = []
	_collect(node, meshes)
	if meshes.is_empty():
		Dbg.log("OUTLINE", "apply id=%d meshes=0 child_count=%d" % [id, node.get_child_count()])
		return
	Dbg.log("OUTLINE", "apply id=%d meshes=%d child_count=%d" % [id, meshes.size(), node.get_child_count()])
	var ring_mat := _build_ring()
	var pairs: Array = []
	for m in meshes:
		pairs.append(_make_shell(m, ring_mat))
	_items[id] = {
		"meshes": meshes, "pairs": pairs, "ring": ring_mat,
		"node": node, "child_count": node.get_child_count(),
		"xray": false,
	}
	refresh(id, opts)

# Ghost shell beside each mesh: the depth-tested world cannot kill it because
# both the node flag and the shader drop the depth test, and the shell sits
# outside the rig material pipeline, so the scope view cannot cull it either.
func _make_shell(src: GeometryInstance3D, ring_mat: ShaderMaterial) -> Dictionary:
	var pair := {"src": src, "shell": null, "overlay": false}
	if src is MeshInstance3D:
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
		shell.layers = mi.layers
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
		# Cached per-frame visibility: the refresh loop must not read every
		# source, but a mesh hidden at spawn must keep its ring hidden too.
		pair["v"] = mi.visible
		return pair
	src.material_overlay = ring_mat
	pair["overlay"] = true
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

# Mirror the rig by hand: pooled bots and LOD swaps move the sources, and the
# shells are plain copies, not bone-driven children. Called from the ESP frame.
func sync() -> void:
	for id in _items:
		for pair in _items[id].get("pairs", []):
			var src = pair.get("src")
			var shell = pair.get("shell")
			if shell == null or src == null:
				continue
			if is_instance_valid(src) and is_instance_valid(shell):
				shell.transform = (src as Node3D).transform

func _free_pairs(id: int) -> void:
	var entry: Dictionary = _items[id]
	var ring_mat: ShaderMaterial = entry["ring"]
	for pair in entry.get("pairs", []):
		var shell = pair.get("shell")
		if shell != null and is_instance_valid(shell):
			shell.queue_free()
		elif bool(pair.get("overlay", false)):
			var src = pair.get("src")
			if src != null and is_instance_valid(src) and (src as GeometryInstance3D).material_overlay == ring_mat:
				(src as GeometryInstance3D).material_overlay = null

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
	# Fresh shells copy their source's visible flag, which is wrong while the
	# trigger layer is parked hidden. Re-apply the cached mode instead of
	# paying for a per-frame loop.
	if entry.get("vis") != null and not bool(entry["vis"]):
		for pair in pairs:
			var shell = pair.get("shell")
			if shell != null and is_instance_valid(shell):
				shell.visible = false

func refresh(id: int, opts: Dictionary) -> void:
	var entry = _items.get(id)
	if entry == null:
		return
	set_entry_xray(id, bool(opts.get("xray", false)))
	var node = entry.get("node")
	if node != null and is_instance_valid(node) and node.get_child_count() != int(entry.get("child_count", -1)):
		_recollect(id, entry)
	var key: Color = opts.get("state_key", States.KEY_NORMAL)
	var grow := float(opts.get("grow", 0.006))
	var cool := float(opts.get("cool", 0.0))

	var ring_mat: ShaderMaterial = entry["ring"]

	# Compare the last pushed value instead of reading the uniform back: a
	# get_shader_parameter round-trip per NPC per frame was pure overhead, and
	# the state key only moves when the bot's category changes.
	if entry.get("p_key") != key:
		ring_mat.set_shader_parameter("state_key", key)
		entry["p_key"] = key
	if entry.get("p_grow") == null or not is_equal_approx(float(entry["p_grow"]), grow):
		ring_mat.set_shader_parameter("grow", grow)
		entry["p_grow"] = grow

	var rim := SCOPE_RIM if _scoped else float(opts.get("rim", 1.0))
	if entry.get("p_rim") == null or not is_equal_approx(float(entry["p_rim"]), rim):
		ring_mat.set_shader_parameter("rim_power", rim)
		entry["p_rim"] = rim

	if entry.get("p_cool") == null or not is_equal_approx(float(entry["p_cool"]), cool):
		ring_mat.set_shader_parameter("cool", cool)
		entry["p_cool"] = cool

	# Trigger mode drives per-frame visibility through opts; the shells are
	# plain scene nodes, so the world cannot do it for us. Per-frame range
	# mirroring is not needed: AISpawner calls Initialize() (which assigns the
	# LOD ranges) before our first draw, and _recollect re-copies on a rig
	# rebuild. Reading every source each frame doubled the draw loop cost.
	var show: bool = bool(opts.get("visible", true))
	if entry.get("vis") == null or bool(entry["vis"]) != show:
		entry["vis"] = show
		for pair in entry.get("pairs", []):
			var shell = pair.get("shell")
			if shell != null and is_instance_valid(shell):
				shell.visible = show and bool(pair.get("v", true))

func clear(id: int) -> void:
	var entry = _items.get(id)
	if entry == null:
		return
	_free_pairs(id)
	_items.erase(id)

func clear_all() -> void:
	for id in _items.keys():
		clear(id)

# Drop entries whose node is gone (targets no longer in `valid_ids`).
func prune_missing(valid_ids: Dictionary) -> void:
	for id in _items.keys():
		if not valid_ids.has(id):
			clear(id)
