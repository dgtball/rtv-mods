extends Node
# Discovers NPCs (RTVModLib AI hooks with a polling fallback), reads faction /
# state, and hands per-NPC draw options to VTKOutline. Owns no
# materials itself; VTKNVG is unaware of it.

const Tracker = preload("res://mods/ThermalVTK/VTKTracker.gd")
const States = preload("res://mods/ThermalVTK/VTKStates.gd")
const Outline = preload("res://mods/ThermalVTK/VTKOutline.gd")
const WeaponOcclusion = preload("res://mods/ThermalVTK/VTKWeaponOcclusion.gd")
const Dbg = preload("res://mods/ThermalVTK/VTKDebug.gd")
const NomadMarkerShader := preload("res://mods/ThermalVTK/VTKNomadMarker.gdshader")

# Polling cadence for state re-reads / fallback discovery (frames).
const POLL_EVERY := 12
const CAP := 24

var enabled: bool = false
# MCM-driven params.
var p_fill := true
var p_fill_alpha := 0.05
var p_decay := 8.0
var p_dist := 60.0
var p_thickness := 0.006
var p_brightness := 0.6
var p_style := 0
var p_rim := 0.42
var p_colors := {
	"state_normal": States.DEFAULT_NORMAL,
	"state_combat": States.DEFAULT_COMBAT,
	"state_defend": States.DEFAULT_DEFEND,
}

var _entries: Dictionary = {}
var _pending: Array = []
var _frame: int = 0
var _outline := Outline.new()
var _weapon := WeaponOcclusion.new()
var _lib = null
var _hook_ids: Array = []
var _player: Node3D = null
var _labels: Dictionary = {}
var _labels_state: Dictionary = {}
var _markers: Dictionary = {}
# Shown when thermal vision, the NVG helmet and the contour ESP are all live
# (the marker belongs to the contour, not the diagnostic log). Set from
# ThermalVTK._apply_mode.
var marker_visible: bool = false
var _dbg_cd: float = 0.0
var _dbg_cand: int = 0
var _dbg_keep: int = 0
var _dbg_applied: int = 0

func _ready() -> void:
	name = "VTKESP"
	get_tree().node_added.connect(_on_node_added)
	_reseed(get_tree().current_scene)
	_register_hooks()

func set_enabled(on: bool) -> void:
	if enabled == on:
		return
	enabled = on
	Dbg.log("ESP", "esp enabled=%s" % str(on))
	if not enabled:
		_outline.clear_all()
		_entries.clear()
		for id in _labels.keys():
			_label_free(id)
		_labels.clear()
		_labels_state.clear()
		for id in _markers.keys():
			_marker_free(id)
		_markers.clear()
	else:
		# Disabling wiped _entries; NPCs already in the scene never fire
		# node_added again, so re-enabling must re-scan or every pre-existing
		# NPC stays undiscovered (outline gone until the map reloads).
		_reseed(get_tree().current_scene)

func npc_count() -> int:
	return _entries.size()

# ---------------------------------------------------------------------------
# Discovery
# ---------------------------------------------------------------------------

func _on_node_added(node: Node) -> void:
	_pending.append(node.get_instance_id())

func _reseed(scene: Node) -> void:
	if scene != null:
		_scan(scene)

func _scan(n: Node) -> void:
	if n == null:
		return
	if _is_bot(n):
		_register(n)
	for c in n.get_children():
		_scan(c)

# Same predicate VTKNVG uses: AI.gd is a Node3D with Activate(), `dead` and
# `mesh`. Trader.gd has Activate() but no `dead`, so it stays out.
func _is_bot(n: Node) -> bool:
	return n is Node3D and n.has_method("Activate") and "dead" in n and "mesh" in n

func _register(node: Node) -> void:
	var id := node.get_instance_id()
	if _entries.has(id):
		return
	var variant = node.get("variant")
	var faction := Tracker.read_faction(variant)
	var nomad := Tracker.is_nomad_faction(faction) or String(node.name).contains("Nomad")
	_entries[id] = Tracker.new_entry(id, nomad, _now())
	_entries[id]["node"] = node
	Dbg.log("ESP", "register id=%d nomad=%s name=%s" % [id, str(nomad), node.name])

func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

# ---------------------------------------------------------------------------
# Hooks (best effort) + polling fallback
# ---------------------------------------------------------------------------

func _register_hooks() -> void:
	if not Engine.has_meta("RTVModLib"):
		Dbg.log("ESP", "hooks: RTVModLib absent, polling fallback")
		return
	Dbg.log("ESP", "hooks: RTVModLib present")
	_lib = Engine.get_meta("RTVModLib")
	if _lib == null:
		return
	# Hook names and arities match AI.gd's void methods.
	_hook_ids.append(_lib.hook("ai-activate-pre", _on_ai_activate, 100))
	_hook_ids.append(_lib.hook("ai-deactivate-post", _on_ai_deactivate, 100))
	_hook_ids.append(_lib.hook("ai-changestate-post", _on_ai_changestate, 100))
	_hook_ids.append(_lib.hook("ai-death-post", _on_ai_death, 100))

func _caller() -> Node:
	if _lib != null and _lib.has_method("_caller"):
		return _lib._caller
	return null

func _on_ai_activate(_state: String) -> void:
	var n := _caller()
	if is_instance_valid(n):
		_register(n)

func _on_ai_deactivate() -> void:
	var n := _caller()
	if is_instance_valid(n):
		var id := n.get_instance_id()
		_entries.erase(id)
		_label_free(id)
		Dbg.log("ESP", "deactivate id=%d" % id)

func _on_ai_changestate(_state: String) -> void:
	var n := _caller()
	if not is_instance_valid(n):
		return
	var id := n.get_instance_id()
	if not _entries.has(id):
		_register(n)
	if _entries.has(id):
		Tracker.apply_state(_entries[id], _read_state(n))
		Dbg.log("ESP", "changestate id=%d state=%d" % [id, _read_state(n)])

func _on_ai_death(_direction: Vector3 = Vector3.ZERO, _force: float = 0.0) -> void:
	var n := _caller()
	if not is_instance_valid(n):
		return
	var id := n.get_instance_id()
	if _entries.has(id):
		Tracker.mark_dead(_entries[id], _now())
		Dbg.log("ESP", "death id=%d" % id)

func _exit_tree() -> void:
	for id in _labels.keys():
		_label_free(id)
	_labels.clear()
	_labels_state.clear()
	for id in _markers.keys():
		_marker_free(id)
	_markers.clear()
	if _lib != null:
		for h in _hook_ids:
			_lib.unhook(h)
	_hook_ids.clear()

func _read_state(node: Node) -> int:
	var s = node.get("currentState")
	if s == null:
		return 0
	return int(s)

# ---------------------------------------------------------------------------
# Per-frame draw
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not enabled and not marker_visible:
		# Both layers are off: free any lingering markers before parking, or they
		# would stick until the map reloads (set_enabled's early-return skips the
		# cleanup when the contour was already disabled).
		if not _markers.is_empty():
			for id in _markers.keys():
				_marker_free(id)
			_markers.clear()
		return
	_weapon.tick()
	_labels_sync()
	_markers_sync()
	_frame += 1
	if not _pending.is_empty():
		for node_id in _pending:
			var n := instance_from_id(node_id)
			if n != null and is_instance_valid(n):
				_scan(n)
		_pending.clear()

	var ppos_v = _player_pos()
	if ppos_v == null:
		_dbg_tick(delta, "no player in group Player")
		return
	var ppos: Vector3 = ppos_v
	if enabled:
		_draw(ppos)
	_dbg_tick(delta, "entries=%d cand=%d keep=%d applied=%d ppos=%.1f,%.1f,%.1f" % [_entries.size(), _dbg_cand, _dbg_keep, _dbg_applied, ppos.x, ppos.y, ppos.z])

func _dbg_tick(delta: float, msg: String) -> void:
	_dbg_cd -= delta
	if _dbg_cd > 0.0:
		return
	_dbg_cd = 1.0
	Dbg.log("ESP", msg)

# ---------------------------------------------------------------------------
# Debug state labels (only while the diagnostic log is on)
# ---------------------------------------------------------------------------
# Debug state labels are shown whenever the diagnostic log is on, regardless of
# thermal vision or the NVG helmet: they are a diagnostic, not a gameplay layer.

func _labels_sync() -> void:
	if not Dbg.enabled:
		for id in _labels.keys():
			_label_free(id)
		_labels.clear()
		_labels_state.clear()
		return
	for id in _entries.keys():
		var e: Dictionary = _entries[id]
		var node = e.get("node")
		if node == null or not is_instance_valid(node) or not node.is_inside_tree():
			_label_free(id)
			continue
		# Dead NPCs keep their entry (for cooling) but drop the label: a corpse
		# with a state readout is noise. Read the node's own `dead` too, so the
		# label goes even if the death hook did not fire.
		if bool(e.get("dead", false)) or bool(node.get("dead")):
			_label_free(id)
			continue
		var state := _read_state(node)
		if not _labels.has(id):
			_label_make(id, e, node, state)
		elif int(_labels_state.get(id, -1)) != state:
			var lbl = _labels[id]
			if is_instance_valid(lbl):
				lbl.text = States.label_text(state, bool(e.get("nomad", false)))
				lbl.visible = enabled
			_labels_state[id] = state
	# Drop labels whose entry is gone (deactivate raced the loop above).
	for id in _labels.keys():
		if not _entries.has(id):
			_label_free(id)

func _label_make(id: int, e: Dictionary, node: Node, state: int) -> void:
	var mesh = node.get("mesh")
	var parent: Node = node
	var y := 1.9
	if mesh is Node3D:
		parent = mesh
		y = (mesh as Node3D).get_aabb().end.y + 0.1
	var lbl := Label3D.new()
	lbl.text = States.label_text(state, bool(e.get("nomad", false)))
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.render_priority = 40
	lbl.font_size = 32
	lbl.outline_size = 12
	lbl.position = Vector3(0.0, y, 0.0)
	lbl.visible = enabled
	parent.add_child(lbl)
	_labels[id] = lbl
	_labels_state[id] = state

func _label_free(id: int) -> void:
	if _labels.has(id):
		var lbl = _labels[id]
		if is_instance_valid(lbl):
			lbl.queue_free()
		_labels.erase(id)
	_labels_state.erase(id)

# ---------------------------------------------------------------------------
# Friendly-nomad diamond marker (while thermal + NVG are on)
# ---------------------------------------------------------------------------

func _markers_sync() -> void:
	if not marker_visible:
		for id in _markers.keys():
			_marker_free(id)
		_markers.clear()
		return
	for id in _entries.keys():
		var e: Dictionary = _entries[id]
		if not bool(e.get("nomad", false)):
			if _markers.has(id):
				_marker_free(id)
			continue
		var node = e.get("node")
		if node == null or not is_instance_valid(node) or not node.is_inside_tree():
			_marker_free(id)
			continue
		# Dead nomads keep their entry (for cooling) but drop the marker.
		if bool(e.get("dead", false)) or bool(node.get("dead")):
			_marker_free(id)
			continue
		if not _markers.has(id):
			_marker_make(id, node)
	for id in _markers.keys():
		if not _entries.has(id):
			_marker_free(id)

func _marker_make(id: int, node: Node) -> void:
	var mesh = node.get("mesh")
	var parent: Node = node
	var y := 1.9
	if mesh is Node3D:
		parent = mesh
		y = (mesh as Node3D).get_aabb().end.y + 0.1
	# A key-emitting mesh instead of a Label3D: the marker paints the nomad key
	# colour, so the NVG overlay detects it and substitutes the display colour.
	# A green Label3D was re-coloured by the thermal palette ramp instead.
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.18, 0.18)
	mi.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = NomadMarkerShader
	mat.render_priority = 41
	mi.material_override = mat
	mi.position = Vector3(0.0, y, 0.0)
	# The quad is billboarded inside the shader (MeshInstance3D has no
	# billboard property in Godot 4). The default depth test is kept, so the
	# marker does not read through walls.
	parent.add_child(mi)
	_markers[id] = mi

func _marker_free(id: int) -> void:
	if _markers.has(id):
		var lbl = _markers[id]
		if is_instance_valid(lbl):
			lbl.queue_free()
		_markers.erase(id)

func _draw(ppos: Vector3) -> void:
	var now := _now()
	# Prune invalid entries first
	for id in _entries.keys():
		var e: Dictionary = _entries[id]
		var node = e.get("node")
		if node == null or not is_instance_valid(node) or not node.is_inside_tree():
			_outline.clear(id)
			_entries.erase(id)
	var cands: Array = []
	var opts_by_id: Dictionary = {}
	var valid: Dictionary = {}
	for id in _entries.keys():
		var e: Dictionary = _entries[id]
		var node = e.get("node")
		if node == null or not is_instance_valid(node) or not node.is_inside_tree():
			continue
		valid[id] = true
		# Mark death from the node itself when the ai-death-post hook missed:
		# the hook is unreliable in game, and without this the corpse never cools.
		if not bool(e.get("dead", false)) and bool(node.get("dead")):
			Tracker.mark_dead(e, now)
		var pos: Vector3 = (node as Node3D).global_position
		var dist := ppos.distance_to(pos)
		if dist > p_dist and not e.get("dead", false):
			continue
		e["dist"] = dist
		cands.append({"id": id, "dist": dist})
		if _frame % POLL_EVERY == 0:
			Tracker.apply_state(e, _read_state(node))
		opts_by_id[id] = _opts_for(e, node, dist, now)
	for id in _entries.keys():
		if not valid.has(id):
			_outline.clear(id)
	var keep: Array = Tracker.pick_nearest(cands, CAP)
	if keep.size() < cands.size():
		for c in cands:
			if c["id"] not in keep:
				valid.erase(c["id"])
				_outline.clear(c["id"])
	var applied := 0
	for id in keep:
		if not valid.has(id) or not _entries.has(id):
			continue
		var e: Dictionary = _entries[id]
		var node = e.get("node")
		var opts: Dictionary = opts_by_id[id]
		if not _outline.has(id):
			_outline.apply(id, node, opts)
		else:
			_outline.refresh(id, opts)
		applied += 1
	_dbg_cand = cands.size()
	_dbg_keep = keep.size()
	_dbg_applied = applied

func _opts_for(e: Dictionary, node: Node, dist: float, now: float) -> Dictionary:
	var cool := Tracker.cool_factor(e, now, p_decay)
	var alpha := Tracker.distance_alpha(dist, p_dist)
	var nomad := bool(e.get("nomad", false))
	var cat: int = int(e.get("cat", States.NORMAL))
	var key: Color = States.state_key(cat)
	var foot_y: float = (node as Node3D).global_position.y
	return {
		"cat": cat,
		"nomad": nomad,
		"state_key": key,
		"alpha": alpha,
		"cool": cool,
		"front_faces": p_style == 0,
		"outline_style": p_style,
		"rim": p_rim,
		"foot_y": foot_y,
		"body_height": 1.8,
		"brightness": p_brightness,
		"grow": p_thickness,
		"fill_key": States.fill_key(cat),
		"fill_on": p_fill,
	}

func _player_pos() -> Variant:
	var players := get_tree().get_nodes_in_group("Player")
	for p in players:
		if p is Node3D:
			return (p as Node3D).global_position
	return null
