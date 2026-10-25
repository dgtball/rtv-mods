extends Node
# Discovers NPCs (RTVModLib AI hooks with a polling fallback), reads faction /
# state, and hands per-NPC draw options to VTKOutline. Owns no
# materials itself; VTKNVG is unaware of it.

const Tracker = preload("res://mods/ThermalVTK/VTKTracker.gd")
const States = preload("res://mods/ThermalVTK/VTKStates.gd")
const Settings = preload("res://mods/ThermalVTK/VTKSettings.gd")
const Outline = preload("res://mods/ThermalVTK/VTKOutline.gd")
const WeaponOcclusion = preload("res://mods/ThermalVTK/VTKWeaponOcclusion.gd")
const Dbg = preload("res://mods/ThermalVTK/VTKDebug.gd")
const Paths = preload("res://mods/ThermalVTK/VTKPaths.gd")
const ScopeDebug = preload("res://mods/ThermalVTK/VTKScopeDebug.gd")
const Calibration = preload("res://mods/ThermalVTK/VTKCalibration.gd")
const NomadMarkerShader := preload("res://mods/ThermalVTK/VTKNomadMarker.gdshader")

# Polling cadence for state re-reads / fallback discovery (frames).
const POLL_EVERY := 12
const CAP := 24
# Movement speeds above this threshold reveal the bot at the far (sprint)
# distance instead of the walking one (the ITH walk/run/sprint idea).
const RUN_SPEED := 2.0
const SPRINT_SPEED := 4.0

# Two independent layers share one collection pass. `enabled` is gone: the
# contour layer gates rings and the marker, the x-ray layer gates reveals.
var contour_layer: bool = false
var xray_layer: bool = false
# MCM-driven params.
var p_decay := 30.0
var p_dist := 60.0
# The X-ray Triggers toggle state: on = a live trigger window swaps that bot's
# ring to the x-ray shader (through walls). Off = windows are still tagged,
# but the ring never lights up through the wall; labels read them regardless.
var p_trig := true
var p_fire_s := 5.0
var p_fire_d := 100.0
var p_voice_s := 5.0
var p_voice_d := 20.0
var p_idle_s := 2.0
var p_idle_d := 6.0
var p_move_s := 1.5
var p_move_d := 10.0
var p_run_d := 20.0
var p_reload_s := 2.0
var p_reload_d := 12.0
var p_pain_s := 3.0
var p_pain_d := 15.0
var p_nade_s := 6.0
var p_nade_d := 60.0
var p_thickness := 0.006
var p_brightness := 0.6
var p_rim := 2.0

var _entries: Dictionary = {}
var _ids_frame: Array = []
var _ids_stamp: int = -1
var _cand_pool: Array = []
var _cand_refs: Array = []
var _keep_pool: Array = []
var _want: Dictionary = {}
var _want_ids: Array = []
var _stale: Array = []
var _dbg_draw_ms: float = 0.0
var _pending: Array = []
var _frame: int = 0
var _outline := Outline.new()
var _weapon = WeaponOcclusion.new()
var _lib = null
var _hook_ids: Array = []
# RTVModLib_mounted late: other mods (Evolve, JCM) wait for _lib._is_ready
# instead of relying on the meta being present in _ready(). One attempt per
# half second until the hooks go through.
var _hook_wait_cd: float = 0.0
var _labels: Dictionary = {}
var _markers: Dictionary = {}
# Debug key calibration: when it is on, every NPC is painted with the
# candidate key so its post-NVG colour can be measured with the probe.
var p_cal_active: bool = false
var p_cal_index: int = 0
# Shown when thermal vision, the NVG helmet and the contour ESP are all live
# (the marker belongs to the contour, not the diagnostic log). Set from
# ThermalVTK._apply_mode.
var marker_visible: bool = false
var _dbg_cd: float = 0.0
var _dbg_cand: int = 0
var _dbg_keep: int = 0
var _dbg_applied: int = 0
var _scope_dbg_cd: float = 0.0
var _probe_gd: Resource = null

func _ready() -> void:
	name = "VTKESP"
	get_tree().node_added.connect(_on_node_added)
	_reseed(get_tree().current_scene)
	_register_hooks()

func set_layers(contour: bool, xray: bool) -> void:
	if contour_layer == contour and xray_layer == xray:
		return
	var any_before := _any_layer()
	contour_layer = contour
	xray_layer = xray
	marker_visible = contour
	Dbg.log("ESP", "layers contour=%s xray=%s" % [str(contour), str(xray)])
	if not _any_layer():
		_outline.clear_all()
		_labels_free_all()
		_markers_free_all()
	elif not any_before and is_inside_tree():
		_reseed(get_tree().current_scene)

func _any_layer() -> bool:
	return contour_layer or xray_layer

# MCM snapshot in, MCM-driven params out. Lives-ahead-of-the-tree safe: the
# headless tests instantiate this node without the game around it.
func apply_config(rec) -> void:
	p_decay = rec.corpse_decay
	p_dist = rec.outline_distance
	p_trig = rec.outline_xray
	p_fire_s = rec.fire_s
	p_fire_d = rec.fire_d
	p_voice_s = rec.voice_s
	p_voice_d = rec.voice_d
	p_idle_s = rec.idle_s
	p_idle_d = rec.idle_d
	p_move_s = rec.move_s
	p_move_d = rec.move_d
	p_run_d = rec.run_d
	p_reload_s = rec.reload_s
	p_reload_d = rec.reload_d
	p_pain_s = rec.pain_s
	p_pain_d = rec.pain_d
	p_nade_s = rec.nade_s
	p_nade_d = rec.nade_d
	p_thickness = rec.outline_thickness
	p_brightness = rec.outline_brightness
	p_rim = rec.outline_rim

# Debug key calibration. The candidate key replaces the state key and the
# fill key of every NPC, and the nomad marker repaints with it, so the probe
# measures one candidate at a time.
func set_calibration(active: bool, index: int) -> void:
	p_cal_active = active
	p_cal_index = index
	_cal_apply_marker_key()

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

# The bot predicate: AI.gd is a Node3D with Activate(), `dead` and `mesh`.
# Trader.gd has Activate() but no `dead`, so it stays out. VTKNVG does not use
# it -- that module only looks for NVG/Mine by script path, so the two sweeps
# stay independent on purpose (they run in different modules and must not
# couple through a shared predicate that a game update could break in one place).
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
	if _hook_ids.size() > 0:
		return
	if not Engine.has_meta("RTVModLib"):
		Dbg.log("ESP", "hooks: RTVModLib absent, retrying")
		return
	_lib = Engine.get_meta("RTVModLib")
	if _lib == null:
		Dbg.log("ESP", "hooks: RTVModLib meta null, retrying")
		return
	# The lib mounts its frameworks late; hook registers scheduled before
	# _is_ready never establish dispatch.
	if not bool(_lib.get("_is_ready")):
		Dbg.log("ESP", "hooks: RTVModLib not ready, retrying")
		return
	Dbg.log("ESP", "hooks: RTVModLib ready, registering")
	# Hook names and arities match AI.gd's void methods.
	_hook_ids.append(_lib.hook("ai-activate-pre", _on_ai_activate, 100))
	_hook_ids.append(_lib.hook("ai-deactivate-post", _on_ai_deactivate, 100))
	_hook_ids.append(_lib.hook("ai-changestate-post", _on_ai_changestate, 100))
	_hook_ids.append(_lib.hook("ai-death-post", _on_ai_death, 100))
	# Trigger sources: every callback below is a cheap no-op unless the trigger
	# mode draws from it. Declarated in mod.txt's [hooks] section.
	_hook_ids.append(_lib.hook("ai-playfire-post", _on_ai_playfire, 100))
	_hook_ids.append(_lib.hook("ai-playcombat-post", _on_ai_playcombat, 100))
	_hook_ids.append(_lib.hook("ai-playidle-post", _on_ai_playidle, 100))
	_hook_ids.append(_lib.hook("ai-playfootstep-post", _on_ai_playfootstep, 100))
	_hook_ids.append(_lib.hook("ai-playreload-post", _on_ai_playreload, 100))
	_hook_ids.append(_lib.hook("ai-playdamage-post", _on_ai_playdamage, 100))
	_hook_ids.append(_lib.hook("ai-grenade-post", _on_ai_grenade, 100))
	var bad: Array[int] = []
	for h in _hook_ids:
		if h is int and h < 0:
			bad.append(h)
	Dbg.log("ESP", "hooks: registered %d callbacks ids=%s bad=%s" % [_hook_ids.size(), str(_hook_ids), str(bad)])

func _caller() -> Node:
	# modloader 3.4.2 exposes the dispatch source as a script variable, not a
	# method: has_method("_caller") was always false in game, so every hook
	# handler silently worked with a null node (trigger tags, death marks and
	# the countdown labels never reached the entries). Object.get reads the
	# variable directly and tolerates a missing key with null.
	if _lib == null:
		return null
	var n = _lib.get("_caller")
	if n is Node:
		return n
	return null

func _on_ai_activate(_state: String) -> void:
	Dbg.log("HOOK", "activate")
	var n := _caller()
	if is_instance_valid(n):
		_register(n)

func _on_ai_deactivate() -> void:
	Dbg.log("HOOK", "deactivate")
	var n := _caller()
	if is_instance_valid(n):
		var id := n.get_instance_id()
		_entries.erase(id)
		_label_free(id)
		Dbg.log("ESP", "deactivate id=%d" % id)

func _on_ai_changestate(_state: String) -> void:
	Dbg.log("HOOK", "changestate")
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
	Dbg.log("HOOK", "death")
	var n := _caller()
	if not is_instance_valid(n):
		return
	var id := n.get_instance_id()
	if _entries.has(id):
		Tracker.mark_dead(_entries[id], _now())
		Dbg.log("ESP", "death id=%d" % id)

# ---------------------------------------------------------------------------
# Trigger sources (Immersive Threat Highlight idea): a shot, a shout, idle
# chatter, steps, a reload, a pain cry and a thrown grenade each tag the
# caller's entry with a timed reveal window.
# ---------------------------------------------------------------------------

func _on_ai_playfire() -> void:
	_trig_event("fire", p_fire_s, p_fire_d)

func _on_ai_playcombat() -> void:
	_trig_event("voice", p_voice_s, p_voice_d)

func _on_ai_playidle() -> void:
	_trig_event("idle", p_idle_s, p_idle_d)

func _on_ai_playfootstep() -> void:
	var source := "walk"
	var dist := p_move_d
	var n := _caller()
	if is_instance_valid(n):
		var speed = n.get("movementSpeed")
		if speed != null and float(speed) >= SPRINT_SPEED:
			source = "run"
			dist = p_run_d
	_trig_event(source, p_move_s, dist)

func _on_ai_playreload() -> void:
	_trig_event("reload", p_reload_s, p_reload_d)

func _on_ai_playdamage() -> void:
	_trig_event("pain", p_pain_s, p_pain_d)

func _on_ai_grenade(phase: int) -> void:
	Dbg.log("HOOK", "grenade phase=%d" % phase)
	if phase != 2:
		return
	_trig_event("grenade", p_nade_s, p_nade_d)

# Telemetry around the trigger reveal: the tag itself and the registered id
# go to the diagnostic log, so a crash during load leaves the last statement.
func _trig_event(source: String, span: float, dist: float) -> void:
	Dbg.log("HOOK", "play %s" % source)
	if span <= 0.0:
		return
	# A zero reveal radius turns the source off (matches the outline's own
	# 0 = hidden semantics): the sound never reaches the player.
	if dist <= 0.0:
		return
	var n := _caller()
	if not is_instance_valid(n):
		return
	var id := n.get_instance_id()
	if not _entries.has(id):
		_register(n)
	if _entries.has(id):
		Tracker.tag_trig(_entries[id], source, dist, _now() + span, span)
		Dbg.log("ESP", "trig id=%d source=%s span=%.1f dist=%.0f" % [id, source, span, dist])

func _exit_tree() -> void:
	_labels_free_all()
	_markers_free_all()
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
	_hook_wait_cd -= delta
	if _hook_ids.is_empty() and _hook_wait_cd <= 0.0:
		_hook_wait_cd = 0.5
		_register_hooks()
	if not _any_layer():
		_weapon.set_scope_mode(false, false)
		if not _pending.is_empty():
			_pending.clear()
		_markers_free_all()
		return
	_weapon.tick()
	var scoped := _scoped_now()
	var pip := _pip_now()
	_outline.set_scoped(scoped)
	_weapon.set_scope_mode(scoped and _any_layer(), pip)
	_scope_probe(delta)
	_frame += 1
	if not _pending.is_empty():
		for node_id in _pending:
			var n := instance_from_id(node_id)
			if n != null and is_instance_valid(n) and n.is_inside_tree() and _is_bot(n):
				_register(n)
		_pending.clear()
	# Collection before the consumers: labels and markers read the flags and
	# the window this pass stores on the record.
	var ppos_v = _player_pos()
	if ppos_v != null:
		var ppos: Vector3 = ppos_v
		if _any_layer():
			_draw(ppos)
	_labels_sync()
	_markers_sync()
	_dbg_tick(delta, ppos_v)

func _dbg_tick(delta: float, ppos: Variant) -> void:
	_dbg_cd -= delta
	if _dbg_cd > 0.0:
		return
	_dbg_cd = 1.0
	if not Dbg.enabled:
		return
	var where := "no player in group Player"
	if ppos != null:
		var p: Vector3 = ppos
		where = "ppos=%.1f,%.1f,%.1f" % [p.x, p.y, p.z]
	Dbg.log("ESP", "entries=%d cand=%d keep=%d applied=%d draw=%.2fms %s" % [_entries.size(), _dbg_cand, _dbg_keep, _dbg_applied, _dbg_draw_ms, where])
func _gd_cached() -> Resource:
	if _probe_gd == null and ResourceLoader.exists(Paths.GAME_DATA):
		_probe_gd = load(Paths.GAME_DATA)
	return _probe_gd

# The scope view itself; PIP rides along in the same read. Both flags go to
# the outline and the weapon module: with PIP on the optic camera supplies the
# in-scope picture, and the Mask depth write hides the main-camera ring inside
# the lens, so the picture does not show it twice.
func _scoped_now() -> bool:
	var gd := _gd_cached()
	if gd == null:
		return false
	var v = gd.get("isScoped")
	return v != null and bool(v)

func _pip_now() -> bool:
	var gd := _gd_cached()
	if gd == null:
		return false
	var v = gd.get("PIP")
	return v != null and bool(v)

# While the diagnostic log is on and the scope view is active, dump what the
# camera sees (VTKScopeDebug): the ray walk reports the geometry between the
# camera and whatever the crosshair reaches, with shaders and priorities.
func _scope_probe(delta: float) -> void:
	if not Dbg.enabled:
		return
	_scope_dbg_cd -= delta
	if _scope_dbg_cd > 0.0:
		return
	_scope_dbg_cd = 0.5
	var gd := _gd_cached()
	if gd == null:
		return
	var scoped_v = gd.get("isScoped")
	if scoped_v == null or not bool(scoped_v):
		return
	ScopeDebug.scope_snapshot(gd, get_tree().get_nodes_in_group("Player"), self, _weapon)

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
		return
	for id in _ids_for_frame():
		if not _entries.has(id):
			continue
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
		var txt := _label_text(e, node, state)
		if not _labels.has(id):
			_label_make(id, e, node, txt)
		else:
			var lbl = _labels[id]
			if is_instance_valid(lbl):
				lbl.text = txt
				lbl.visible = true
	# Drop labels whose entry is gone (deactivate raced the loop above).
	for id in _labels.keys():
		if not _entries.has(id):
			_label_free(id)

# Debug label text: the NPC's state (and, in trigger mode, the active reveal
# window with its remaining seconds and configured range). Recomposed every
# frame, so the countdown ticks live.
func _label_text(e: Dictionary, node: Node, state: int) -> String:
	var txt := States.label_text(state, bool(e.get("nomad", false)))
	# The countdown suffix is window-driven only: the X-ray toggle governs the
	# ring flash, labels follow the debug log like every other readout.
	var now := _now()
	var ev: Dictionary = Tracker.EMPTY_WINDOW
	if e.has("win"):
		ev = e["win"]
	else:
		ev = Tracker.pick_trig(e, now)
	if not ev.is_empty():
		var left: float = max(0.0, float(ev.get("expires", 0.0)) - now)
		txt += "  [%s %.1fs %.0fm]" % [str(ev.get("source", "")), left, float(ev.get("dist", 0.0))]
	return txt

func _label_make(id: int, e: Dictionary, node: Node, txt: String) -> void:
	var anchor := _anchor_above(node)
	var lbl := Label3D.new()
	lbl.text = txt
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.render_priority = 40
	lbl.font_size = 32
	lbl.outline_size = 12
	lbl.position = Vector3(0.0, float(anchor["y"]), 0.0)
	lbl.visible = true
	lbl.set_meta(Outline.NO_CONTOUR_META, true)
	(anchor["parent"] as Node).add_child(lbl)
	_labels[id] = lbl

# Where a label/marker hangs: above the bot's own mesh when it has one (so the
# overlay on that mesh skips our tagged geometry), above the bot root otherwise.
func _anchor_above(node: Node) -> Dictionary:
	var mesh = node.get("mesh")
	var parent: Node = node
	var y := 1.9
	if mesh is Node3D:
		parent = mesh
		y = (mesh as Node3D).get_aabb().end.y + 0.1
	return {"parent": parent, "y": y}

func _label_free(id: int) -> void:
	if _labels.has(id):
		var lbl = _labels[id]
		if is_instance_valid(lbl):
			lbl.queue_free()
		_labels.erase(id)

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
	var anchor := _anchor_above(node)
	# A key-emitting mesh instead of a Label3D: the marker paints the nomad key
	# colour, so the NVG overlay detects it and substitutes the display colour.
	# A green Label3D was re-coloured by the thermal palette ramp instead.
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.18, 0.18)
	mi.mesh = quad
	# Keep the contour collector off our own geometry: the marker is a child of
	# the bot mesh, so the sweep would otherwise hand it the body-fill overlay
	# and paint over the nomad key before the overlay could substitute it.
	mi.set_meta(Outline.NO_CONTOUR_META, true)
	var mat := ShaderMaterial.new()
	mat.shader = NomadMarkerShader
	mat.render_priority = 41
	# The marker key is written here instead of being left to the shader
	# default, so the calibration cycle can repaint the live markers.
	mat.set_shader_parameter("nomad_key", _marker_key())
	mi.material_override = mat
	mi.position = Vector3(0.0, float(anchor["y"]), 0.0)
	# The quad is billboarded inside the shader (MeshInstance3D has no
	# billboard property in Godot 4). The default depth test is kept, so the
	# marker does not read through walls.
	(anchor["parent"] as Node).add_child(mi)
	_markers[id] = mi

func _marker_free(id: int) -> void:
	if _markers.has(id):
		var mi = _markers[id]
		if is_instance_valid(mi):
			mi.queue_free()
		_markers.erase(id)

# The key the nomad marker paints: the calibration candidate while the
# calibration is on, the normal nomad key otherwise.
func _marker_key() -> Color:
	if p_cal_active:
		return Calibration.candidate(p_cal_index)
	return States.KEY_NOMAD

# Rewrites the marker key on the live markers, so a calibration step repaints
# them without waiting for the markers to be rebuilt.
func _cal_apply_marker_key() -> void:
	var key: Color = _marker_key()
	for id in _markers.keys():
		var mi = _markers[id]
		if mi == null or not is_instance_valid(mi):
			continue
		var mat = mi.material_override
		if mat is ShaderMaterial:
			(mat as ShaderMaterial).set_shader_parameter("nomad_key", key)

func _ids_for_frame() -> Array:
	if _ids_stamp != _frame:
		_ids_frame = _entries.keys()
		_ids_stamp = _frame
	return _ids_frame

func _want_add(id: int) -> void:
	if not _want.has(id):
		_want[id] = true
		_want_ids.append(id)

func _draw(ppos: Vector3) -> void:
	var t0: int = 0
	if Dbg.enabled:
		t0 = Time.get_ticks_usec()
	var now := _now()
	_ids_frame = _entries.keys()
	_ids_stamp = _frame
	_stale.clear()
	_want.clear()
	_want_ids.clear()
	var used := 0
	for id in _ids_frame:
		if not _entries.has(id):
			continue
		var e: Dictionary = _entries[id]
		var node = e.get("node")
		if node == null or not is_instance_valid(node) or not node.is_inside_tree():
			_outline.clear(id)
			_stale.append(id)
			continue
		if not bool(e.get("dead", false)) and bool(node.get("dead")):
			Tracker.mark_dead(e, now)
		var dist: float = ppos.distance_to((node as Node3D).global_position)
		e["dist"] = dist
		var win: Dictionary = Tracker.EMPTY_WINDOW
		if not bool(e.get("dead", false)):
			win = Tracker.pick_trig(e, now)
		e["win"] = win
		var xray: bool = xray_layer and p_trig and not win.is_empty() and dist <= float(win.get("dist", 0.0))
		e["xray_live"] = xray
		if _frame % POLL_EVERY == 0:
			Tracker.apply_state(e, _read_state(node))
		if contour_layer and dist <= p_dist:
			var c: Dictionary
			if used < _cand_pool.size():
				c = _cand_pool[used]
			else:
				c = {}
				_cand_pool.append(c)
			c["id"] = id
			c["dist"] = dist
			used += 1
		if xray:
			_want_add(id)
	for id in _stale:
		_entries.erase(id)
	_cand_refs.resize(used)
	for i in used:
		_cand_refs[i] = _cand_pool[i]
	var keep: Array = Tracker.pick_nearest(_cand_refs, CAP, _keep_pool)
	for id in keep:
		_want_add(id)
	var applied := 0
	for id in _want_ids:
		if not _entries.has(id):
			continue
		var e: Dictionary = _entries[id]
		var node = e.get("node")
		if node == null or not is_instance_valid(node):
			continue
		var opts = e.get("opts")
		if opts == null:
			opts = {}
			e["opts"] = opts
		_fill_opts(opts, e, now)
		if _outline.has(id):
			_outline.refresh(id, opts)
		else:
			_outline.apply(id, node, opts)
		applied += 1
	_outline.clear_not_in(_want)
	_dbg_cand = used
	_dbg_keep = keep.size()
	_dbg_applied = applied
	if Dbg.enabled:
		_dbg_draw_ms = float(Time.get_ticks_usec() - t0) / 1000.0

func _opts_for(e: Dictionary, node: Node, now: float) -> Dictionary:
	var opts: Dictionary = {}
	_fill_opts(opts, e, now)
	return opts

func _fill_opts(opts: Dictionary, e: Dictionary, now: float) -> void:
	var cool := Tracker.cool_factor(e, now, p_decay)
	var win: Dictionary = e.get("win", Tracker.EMPTY_WINDOW)
	var xray := bool(e.get("xray_live", false))
	if xray and not win.is_empty():
		cool = clampf(1.0 - Tracker.fade_factor(win, now), 0.0, 1.0)
	var cat: int = int(e.get("cat", States.NORMAL))
	var key: Color = States.state_key(cat)
	if p_cal_active:
		key = Calibration.candidate(p_cal_index)
	opts["cat"] = cat
	opts["nomad"] = bool(e.get("nomad", false))
	opts["state_key"] = key
	opts["cool"] = cool
	opts["rim"] = p_rim
	opts["brightness"] = p_brightness
	opts["grow"] = p_thickness
	opts["xray"] = xray

func _labels_free_all() -> void:
	for id in _labels.keys():
		_label_free(id)
	_labels.clear()

func _markers_free_all() -> void:
	for id in _markers.keys():
		_marker_free(id)
	_markers.clear()

func _player_pos() -> Variant:
	var players := get_tree().get_nodes_in_group("Player")
	for p in players:
		if p is Node3D:
			return (p as Node3D).global_position
	return null
