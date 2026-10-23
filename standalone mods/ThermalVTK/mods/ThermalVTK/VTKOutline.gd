extends RefCounted
# Owns one ring material per NPC and renders it on dedicated ghost shells
# (sibling MeshInstance3D copies, the approach reference outline mods use):
# same mesh/skin/skeleton, transform mirrored every frame, material_override,
# no_depth_test on the node, shadow casting off. The ring shader does its own
# depth compare (the auto test cannot tell the scope glass from a wall), so
# the shells survive the rig's own material pipeline and the scope view.
# State colours and the x-ray flag come in via `opts`; this file only draws.

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
# view keeps a fine frame. The carve stays narrow: opaque scope hardware hides
# the ring by the depth compare, in and out of the scope (1.11.4: the old
# 0.10/0.60 values either spilled over the rim or exempted the rim entirely;
# near eyeball bits are the only zone left exempt). The glass lets the ring
# through by DRAW ORDER, not by depth (it supplies none to the compare).
# The x-ray ring widens the carve only while its window is live: with the
# compare disabled, the wide value is what keeps scope metal and glass from
# vanishing the ring (or duplicating it over the PIP-on picture).
const SCOPE_RIM := 6.0
const CARVE_SCOPED := 0.03
const CARVE_FREE := 0.03
const CARVE_XRAY := 0.60
# Draw order against the scope optics (transparent pass, higher = later):
# every optic glass/reticle surface sits at 0..1 (Scope/Reticle 1, Mask/
# Objective 0) and the ACOG tube (Alpha) at 11, so a ring at 6 paints OVER the
# glass (the in-scope picture) while the tube paints OVER the ring (the spill
# beyond the lens goes away, 1.11.4). A ring at 0 is painted over by the whole
# optic (the weapon-lowered case, no bleed-through).
# With PIP on the scope picture is the optic camera's own render: the ring is
# visible in the picture through the ghost shells, so the main-camera ring
# drops under the glass, or the picture shows it twice.
const RING_PRIO_FREE := 0
const RING_PRIO_SCOPED := 6
var _scoped: bool = false
# gameData.PIP: the picture-in-picture path. True when Settings keeps the
# optic camera render enabled.
var _pip: bool = false

# Draw order for every live ring: over the scope glass only while aiming
# without PIP (there the main render IS the in-scope picture); with PIP the
# optic camera supplies the picture, so the main ring stays under the glass.
func _ring_prio() -> int:
	return RING_PRIO_SCOPED if (_scoped and not _pip) else RING_PRIO_FREE

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
	ring_mat.render_priority = _ring_prio()
	# Seed from the current scope state: a bot discovered inside the scope
	# view must not wait a frame for set_scoped/set_entry_xray to catch up.
	ring_mat.set_shader_parameter("near_only", false)
	ring_mat.set_shader_parameter("carve", CARVE_SCOPED if _scoped else CARVE_FREE)
	return ring_mat

# Event-driven per-entry flip: idle rings honour walls; when the frame loop
# passes opts["xray"] for a bot with a live trigger window, that bot's ring
# punches through walls while camera-attached glass keeps hiding it. The x-ray
# flag moved from a shader swap to the near_only uniform here: one shader, no
# lost uniforms on the flip. Dedupe by the stored flag so per-frame opts never
# reassign the same uniforms.
func set_entry_xray(id: int, on: bool) -> void:
	var entry = _items.get(id)
	if entry == null:
		return
	if bool(entry.get("xray", false)) == on:
		return
	entry["xray"] = on
	var ring_mat: ShaderMaterial = entry["ring"]
	if ring_mat != null:
		ring_mat.set_shader_parameter("near_only", on)
		ring_mat.set_shader_parameter("carve", CARVE_XRAY if on else CARVE_FREE)
		# Walls stay punched through by the near_only uniform, and the draw
		# order is the same scope rule as for idle rings: over the glass
		# while aiming, under it with the weapon lowered.
		ring_mat.render_priority = _ring_prio()

# The scope flag drives the thin in-scope band and pushes the carve AND the
# draw order to every live ring material: while aiming without PIP the ring
# paints over the scope glass, otherwise the glass paints over the ring.
# No-op while neither flag moves.
func set_scoped(on: bool, pip := false) -> void:
	if _scoped == on and _pip == pip:
		return
	_scoped = on
	_pip = pip
	_push_scope()

# PIP comes from the settings menu and may flip while aiming: re-derive the
# draw order only.
func set_pip(on: bool) -> void:
	if _pip == on:
		return
	_pip = on
	_push_scope()

func _push_scope() -> void:
	var carve := CARVE_SCOPED if _scoped else CARVE_FREE
	var prio := _ring_prio()
	for id in _items:
		var ring_mat = _items[id].get("ring")
		if ring_mat != null:
			(ring_mat as ShaderMaterial).render_priority = prio
			if not bool(_items[id].get("xray", false)):
				(ring_mat as ShaderMaterial).set_shader_parameter("carve", carve)

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
		shell.set_meta(NO_CONTOUR_META, true)
		var p := mi.get_parent()
		if p == null:
			shell.queue_free()
			return pair
		p.add_child(shell)
		pair["shell"] = shell
		return pair
	src.material_overlay = ring_mat
	pair["overlay"] = true
	return pair

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

	if ring_mat.get_shader_parameter("state_key") != key \
			or ring_mat.get_shader_parameter("grow") == null \
			or not is_equal_approx(float(ring_mat.get_shader_parameter("grow")), grow):
		ring_mat.set_shader_parameter("state_key", key)
		ring_mat.set_shader_parameter("grow", grow)

	var rim := SCOPE_RIM if _scoped else float(opts.get("rim", 1.0))
	if ring_mat.get_shader_parameter("rim_power") == null or not is_equal_approx(float(ring_mat.get_shader_parameter("rim_power")), rim):
		ring_mat.set_shader_parameter("rim_power", rim)

	if ring_mat.get_shader_parameter("cool") == null or not is_equal_approx(float(ring_mat.get_shader_parameter("cool")), cool):
		ring_mat.set_shader_parameter("cool", cool)

	# Trigger mode drives per-frame visibility through opts; the shells are
	# plain scene nodes, so the world cannot do it for us.
	var show: bool = bool(opts.get("visible", true))
	for pair in entry.get("pairs", []):
		var shell = pair.get("shell")
		if shell != null and is_instance_valid(shell):
			shell.visible = show

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
