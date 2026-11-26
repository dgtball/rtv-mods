extends SceneTree

const ESP = preload("res://mods/ThermalVTK/VTKESP.gd")
const Settings = preload("res://mods/ThermalVTK/VTKSettings.gd")
const S = preload("res://mods/ThermalVTK/VTKStates.gd")
const Outline = preload("res://mods/ThermalVTK/VTKOutline.gd")
const Sh = preload("res://mods/ThermalVTK/VTKShaders.gd")
const Tracker = preload("res://mods/ThermalVTK/VTKTracker.gd")
const Labels = preload("res://mods/ThermalVTK/VTKLabels.gd")
const Dbg = preload("res://mods/ThermalVTK/VTKDebug.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

# The contour opts are built by _fill_opts into a caller-owned dictionary; the
# test just reads the result.
func opts_of(esp, e: Dictionary) -> Dictionary:
	var opts: Dictionary = {}
	esp._fill_opts(opts, e, 0.0)
	return opts

class FakeBot extends Node3D:
	var dead := false
	var mesh: Node = null
	var variant = null
	var movementSpeed := 0.0
	func Activate(_state: String = "") -> void:
		pass

class FakeLib extends RefCounted:
	var _caller: Node = null

func _init() -> void:
	process_frame.connect(_run)

func _run() -> void:
	t_reenable_reseeds()
	t_toggle_keeps_death_time()
	t_hook_caller_reads_var()
	t_zero_dist_never_tags()
	t_distance_crops()
	t_label_suffix_independent()
	t_opts_contour_key()
	t_outline_opts_use_unified_defaults()
	t_opts_brightness_thermal_mix()
	t_band_is_zero_at_every_distance()
	t_outline_ring_matches_body()
	t_outline_xray_keeps_ring()
	t_no_through_walls_opt()
	t_dead_node_marks_entry()
	t_los_excludes_self()
	t_distance_crops_corpses()
	t_xray_window_skips_cap()
	t_opts_reuse_updates()
	t_candidate_pool_reused()
	t_label_reads_stored_window()
	t_xray_layer_without_contour()
	t_layers_drive_marker()
	t_wants_contour()
	t_weapon_runs_without_contour()
	t_subject_is_nearest_candidate()
	t_no_perframe_subject_log()
	t_crosshair_target()
	print("")
	if fails == 0:
		print("ESP tests passed")
		quit(0)
	else:
		print("ESP tests failed: ", fails)
		quit(1)

# Guards the fix: set_enabled(false) used to wipe _entries, and a corpse
# re-registered on the next enable was marked dead right NOW (its `dead` node
# flag was already up), so every cooled body switched back to freshly-killed
# warm after cycling thermal vision. The entry — and its death timestamp —
# must survive the toggle.
func t_toggle_keeps_death_time() -> void:
	var scene := Node3D.new()
	scene.name = "Map_toggle"
	var bot := FakeBot.new()
	bot.name = "AI_Bandit_toggle"
	scene.add_child(bot)
	root.add_child(scene)
	current_scene = scene

	var esp = ESP.new()
	esp.name = "VTKESP_toggle"
	root.add_child(esp)
	esp.p_dist = 60.0
	bot.global_position = Vector3(2.0, 0.0, 0.0)
	bot.dead = true
	esp._draw(Vector3.ZERO)
	var id := bot.get_instance_id()
	ck(bool(esp._entries[id].get("dead", false)), "corpse marked dead before the toggle")
	var ts: float = float(esp._entries[id].get("death_ts", 0.0))
	ck(ts > 0.0, "death timestamp exists")
	esp.set_layers(false, false)
	esp.set_layers(true, false)
	ck(esp._entries.size() == 1, "toggle keeps the entry")
	if not esp._entries.has(id):
		ck(false, "entry survived the toggle")
		esp.free()
		scene.queue_free()
		return
	ck(float(esp._entries[id].get("death_ts", 0.0)) == ts, "death timestamp survives the toggle")
	esp._draw(Vector3.ZERO)
	ck(float(esp._entries[id].get("death_ts", 0.0)) == ts, "redraw does not reset the corpse clock")

	esp.free()
	scene.queue_free()

# The Distance slider crops the outline exactly where it is set: a ring that
# was applied while the bot was inside the range must be cleared once the bot
# leaves it (or Distance is lowered), otherwise low settings leave stale rings
# behind and minimum Distance hid nothing (1.10.0 report).
func t_distance_crops() -> void:
	var scene := Node3D.new()
	scene.name = "Map_crop"
	var bot := FakeBot.new()
	bot.name = "AI_Bandit_crop"
	scene.add_child(bot)
	root.add_child(scene)
	current_scene = scene

	var esp = ESP.new()
	esp.name = "VTKESP_crop"
	root.add_child(esp)
	esp.set_layers(true, false)
	esp.p_trig = false
	esp.p_dist = 5.0
	var rmesh := MeshInstance3D.new()
	rmesh.mesh = BoxMesh.new()
	bot.add_child(rmesh)
	var id := bot.get_instance_id()
	bot.global_position = Vector3(0.0, 0.0, -2.0)
	esp._draw(Vector3.ZERO)
	ck(esp._outline.has(id), "ring applied inside Distance")
	bot.global_position = Vector3(0.0, 0.0, -50.0)
	esp._draw(Vector3.ZERO)
	ck(not esp._outline.has(id), "ring cleared outside Distance")
	bot.global_position = Vector3(0.0, 0.0, -2.0)
	esp._draw(Vector3.ZERO)
	ck(esp._outline.has(id), "ring reapplied on re-entry")

	esp.free()
	scene.queue_free()

# Enable/disable must keep the discovered NPCs listed (1.10.1: set_enabled no
# longer wipes _entries), so both directions keep discovery.
func t_reenable_reseeds() -> void:
	var scene := Node3D.new()
	scene.name = "Map"
	var bot := FakeBot.new()
	bot.name = "AI_Bandit"
	scene.add_child(bot)
	root.add_child(scene)
	current_scene = scene

	var esp = ESP.new()
	esp.name = "VTKESP"
	root.add_child(esp)
	ck(esp._entries.size() == 1, "bot discovered on ready")
	esp.set_layers(true, false)
	ck(esp._entries.size() == 1, "enable keeps discovery")
	esp.set_layers(false, false)
	ck(esp._entries.size() == 1, "disable keeps the entry")
	esp.set_layers(true, false)
	ck(esp._entries.size() == 1, "re-enable keeps discovery")

	esp.free()
	scene.queue_free()

# The hook layer has to read its caller the way modloader 3.4.2 exposes it: a
# script variable, not a method. has_method("_caller") returned false in game,
# so every hook handler silently returned null and the trigger tags, the death
# marks and the countdown labels never reached the entries — even though the
# A zero reveal radius silences the trigger source (the 0 = off semantics).
# _trig_event is node-coupled (hook caller, entries), so the guard is pinned
# on the source the same way the probe/calibration tests pin their wiring.
# Only the one guard exists in the module (checked), so a targeted string is exact.
func t_zero_dist_never_tags() -> void:
	var src := FileAccess.get_file_as_string("res://mods/ThermalVTK/VTKESP.gd").replace("\r\n", "\n")
	ck(src.count("if dist <= 0.0:") == 1, "exactly one reveal-radius guard exists")
	ck(src.contains("\t# A zero reveal radius turns the source off (matches the outline's own\n\t# 0 = hidden semantics): the sound never reaches the player.\n\tif dist <= 0.0:\n\t\treturn"),
		"the trigger event bails before tagging when the reveal radius is 0")

func t_hook_caller_reads_var() -> void:
	var scene := Node3D.new()
	scene.name = "Map_caller"
	var bot := FakeBot.new()
	bot.name = "AI_Bandit_caller"
	bot.movementSpeed = 0.0
	scene.add_child(bot)
	root.add_child(scene)
	current_scene = scene

	var esp = ESP.new()
	esp.name = "VTKESP_caller"
	var lib := FakeLib.new()
	esp._lib = lib
	lib._caller = bot
	esp.set_layers(true, false)
	ck(esp._caller() == bot, "_caller() reads the library's caller variable")

	esp._on_ai_playfootstep()
	var id := bot.get_instance_id()
	ck(esp._entries.has(id), "footstep hook registers the caller")
	if not esp._entries.has(id):
		ck(false, "entry was created by the hook")
		esp.free()
		scene.queue_free()
		return
	var ev: Dictionary = Tracker.pick_trig(esp._entries[id], esp._now())
	ck(ev.is_empty() == false and str(ev.get("source", "")) == "walk", "slow footsteps tag a Walk window")

	# A sprinting bot lands a separate Sprint window: the label has to tell
	# the two movement kinds apart, since their settings differ.
	var sprint := FakeBot.new()
	sprint.name = "AI_Bandit_sprint"
	sprint.movementSpeed = 4.0
	lib._caller = sprint
	esp._on_ai_playfootstep()
	var sid := sprint.get_instance_id()
	ck(esp._entries.has(sid), "footstep hook registers the sprinter")
	var sev: Dictionary = Tracker.pick_trig(esp._entries[sid], esp._now())
	ck(sev.is_empty() == false and str(sev.get("source", "")) == "run", "sprint footsteps tag a Sprint window")

	esp.free()
	scene.queue_free()

# The countdown suffix lives while a trigger window is open, regardless of the
# X-ray toggle: p_trig gates the ring flash only. Labels follow the debug log.
func t_label_suffix_independent() -> void:
	var esp = ESP.new()
	esp.p_trig = false
	var node := Node3D.new()
	var e := {"nomad": false, "dead": false}
	var now := float(Time.get_ticks_msec()) / 1000.0
	Tracker.tag_trig(e, "fire", 50.0, now + 3.0, 3.0)
	var win: Dictionary = Tracker.pick_trig(e, now)
	var with_trig := Labels.trigger_suffix(win, now)
	ck(with_trig.contains("[fire"), "label carries the countdown with p_trig off")
	ck(with_trig.contains("3."), "countdown shows the seconds left")
	var e2 := {"nomad": false, "dead": false}
	ck(Labels.trigger_suffix(Tracker.pick_trig(e2, now), now) == "", "no window, no suffix")
	esp.free()

	# Residue regression: beyond Distance the frame loop only touches the bot in
	# the skip branch, so if that branch left the x-ray flag set, an expired
	# window kept the ring swapped (through walls) for as long as the bot stayed
	# out of Distance — the setting promises a plain occluded ring between
	# events.
	var rscene := Node3D.new()
	rscene.name = "Map_residue"
	var rbot := FakeBot.new()
	rbot.name = "AI_Bandit_residue"
	rscene.add_child(rbot)
	var rmesh := MeshInstance3D.new()
	rmesh.mesh = BoxMesh.new()
	rbot.add_child(rmesh)
	root.add_child(rscene)
	current_scene = rscene

	var resp = ESP.new()
	resp.name = "VTKESP_residue"
	root.add_child(resp)
	resp.set_layers(true, true)
	ck(resp._entries.size() == 1, "residue bot discovered")
	resp.p_trig = true
	resp.p_dist = 5.0
	rbot.global_position = Vector3(0.0, 0.0, -50.0)
	var rid := rbot.get_instance_id()
	var rnow := float(Time.get_ticks_msec()) / 1000.0
	# Live window with a reveal range (100 m) well past Distance (5 m).
	Tracker.tag_trig(resp._entries[rid], "fire", 100.0, rnow + 60.0, 60.0)
	resp._draw(Vector3.ZERO)
	var rmat: ShaderMaterial = resp._outline._items[rid]["mat"]
	ck(resp._outline.has(rid) and rmat.shader == Sh.body_xray(), "reveal past Distance goes through walls")
	ck(resp._outline._items[rid]["ring"] != null, "outline reveal keeps the ring pass")
	ck(rmesh.material_overlay == rmat, "reveal past Distance paints the bot mesh")
	# Expire the window: Time stays real (no fake clock), so tag the same way a
	# timeout ages it — expires behind now. pick_trig erases it and the frame
	# loop reaches the bot only through the skip branch. 1.10.1: the skip
	# branch also crops the outline, so the expired bot keeps no ring at all
	# (Distance zeroing must hide it entirely).
	Tracker.tag_trig(resp._entries[rid], "fire", 100.0, rnow - 1.0, 60.0)
	resp._draw(Vector3.ZERO)
	ck(not resp._outline.has(rid), "expired window releases the bot behind Distance")

	resp.free()
	rscene.queue_free()

func t_opts_contour_key() -> void:
	var esp = ESP.new()
	esp.name = "VTKESP_opts"
	root.add_child(esp)
	var hostile := opts_of(esp, {"cat": S.COMBAT, "nomad": false})
	ck(hostile.get("color") == S.DEFAULT_COMBAT, "hostile combat uses combat display color")
	ck(not hostile.has("key"), "contour opts carry no key")
	ck(not hostile.has("direct"), "contour opts carry no direct flag")
	ck(not hostile.has("state_key"), "the old detector key name is gone")
	ck(not hostile.has("nomad"), "nomad is not duplicated into the contour opts")
	for k in ["cat", "color", "brightness", "fill_alpha", "grow", "cool", "xray"]:
		ck(hostile.has(k), "contour opts include %s" % k)
	ck(not hostile.has("fill"), "contour opts carry no fill mode flag")
	ck(not hostile.has("alpha"), "the contour opts carry no alpha to blend the key with")
	ck(not hostile.has("rim"), "the ring has no rim falloff")
	ck(not hostile.has("fill_grow"), "fill grow lives in the shader, not in opts")
	ck(hostile.has("band"), "contour opts carry the ring band")
	var normal := opts_of(esp, {"cat": S.NORMAL, "nomad": true})
	ck(normal.get("color") == S.DEFAULT_NORMAL, "normal uses normal display color")
	var defend := opts_of(esp, {"cat": S.DEFEND, "nomad": false})
	ck(defend.get("color") == S.DEFAULT_DEFEND, "defend uses defend display color")
	ck(not esp.has_method("set_render_to_buffer"), "render-to-buffer API removed in overlay-only baseline")
	ck(not esp.has_method("render_to_buffer"), "render_to_buffer accessor removed in overlay-only baseline")
	esp.free()

# One contour path: the shared defaults drive ESP, and brightness is never
# capped by a mode that no longer exists.
func t_outline_opts_use_unified_defaults() -> void:
	var esp = ESP.new()
	esp.name = "VTKESP_outline_defaults"
	root.add_child(esp)
	ck(absf(esp.p_thickness - Settings.OUTLINE_THICKNESS) < 0.000001, "ESP thickness starts from the shared default")
	ck(absf(esp.p_brightness - Settings.OUTLINE_BRIGHTNESS) < 0.000001, "ESP brightness starts from the shared default")
	ck(absf(esp.p_fill_alpha - Settings.FILL_ALPHA) < 0.000001, "ESP fill alpha starts from the shared default")
	ck(esp.get("p_body_fill") == null, "ESP has no body fill field")
	esp.p_brightness = 1.2
	var opts := opts_of(esp, {"cat": S.COMBAT, "nomad": false})
	ck(opts.get("color") == S.DEFAULT_COMBAT, "outline opts keep the display color")
	ck(not opts.has("fill"), "no fill flag is emitted")
	ck(not opts.has("alpha"), "outline opts carry no alpha field")
	ck(absf(float(opts.get("brightness", -1.0)) - 1.2) < 0.000001, "brightness above one is not clamped")
	ck(absf(float(opts.get("fill_alpha", -1.0)) - Settings.FILL_ALPHA) < 0.000001, "opts carry the shared fill alpha")
	ck(esp.get("p_thermal_mix") == null, "ESP has no thermal mix field")
	esp.free()

func t_opts_brightness_thermal_mix() -> void:
	var esp = ESP.new()
	esp.name = "VTKESP_mix"
	root.add_child(esp)
	esp.p_fill_alpha = 0.5
	esp.p_brightness = 1.2
	var opts := opts_of(esp, {"cat": S.NORMAL, "nomad": false})
	ck(not opts.has("alpha"), "fill strength is not a per-entry alpha")
	ck(absf(float(opts.get("fill_alpha", -1.0)) - 0.5) < 0.001, "fill_alpha comes from ESP field")
	ck(absf(float(opts.get("brightness", 0.0)) - 1.2) < 0.001, "brightness comes from ESP field")
	esp.p_fill_alpha = 0.8
	opts = opts_of(esp, {"cat": S.NORMAL, "nomad": false})
	ck(absf(float(opts.get("fill_alpha", -1.0)) - 0.8) < 0.001, "fill_alpha tracks ESP field")
	esp.free()

# The band is the distance-compensated extra ring inflation. With it pinned at
# zero the ring sits exactly on the body silhouette: the visible line is the
# fresnel falloff, with no outward halo growing on distant NPCs.
func t_band_is_zero_at_every_distance() -> void:
	var esp = ESP.new()
	root.add_child(esp)
	esp.p_thickness = 0.012
	for d in [3.0, 30.0, 120.0]:
		var opts := opts_of(esp, {"cat": S.NORMAL, "dist": d})
		ck(absf(float(opts.get("grow", 0.0)) - 0.012) < 0.000001, "the opts carry the configured thickness at %f m" % d)
		ck(is_equal_approx(float(opts.get("band", -1.0)), 0.0), "the band stays zero at %f m" % d)
	ck(is_equal_approx(esp._band_for(120.0), 0.0), "the band source itself returns zero")
	esp.free()

# With the band pinned at zero the ring must sit on the body silhouette, so a
# distant NPC cannot grow an outward halo.
func t_outline_ring_matches_body() -> void:
	var esp = ESP.new()
	root.add_child(esp)
	esp.p_thickness = 0.012
	var opts := opts_of(esp, {"cat": S.NORMAL, "nomad": false, "dist": 30.0})
	var bot := Node3D.new()
	bot.name = "AI_Band"
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	bot.add_child(mesh)
	root.add_child(bot)
	var o = Outline.new()
	o.apply(91, bot, opts)
	var body: ShaderMaterial = o._items[91]["mat"]
	var ring: ShaderMaterial = body.next_pass as ShaderMaterial
	ck(ring != null, "outline mode still builds the ring pass")
	if ring != null:
		ck(is_equal_approx(float(ring.get_shader_parameter("grow")), float(body.get_shader_parameter("grow"))), "the ring sits on the body silhouette")
	o.clear_all()
	esp.free()
	bot.free()

func t_outline_xray_keeps_ring() -> void:
	var scene := Node3D.new()
	scene.name = "Map_outline_xray"
	var bot := FakeBot.new()
	bot.name = "AI_Bandit_outline_xray"
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	bot.add_child(mesh)
	scene.add_child(bot)
	root.add_child(scene)
	current_scene = scene
	bot.global_position = Vector3(0.0, 0.0, -3.0)
	var esp = ESP.new()
	esp.name = "VTKESP_outline_xray"
	root.add_child(esp)
	esp.set_layers(true, true)
	esp.p_trig = true
	esp.p_dist = 60.0
	var id := bot.get_instance_id()
	var now := esp._now()
	Tracker.tag_trig(esp._entries[id], "fire", 100.0, now + 60.0, 60.0)
	esp._draw(Vector3.ZERO)
	ck(esp._outline.has(id), "outline xray reveal draws")
	var entry: Dictionary = esp._outline._items[id]
	var mat: ShaderMaterial = entry["mat"]
	ck(mat != null and mat.shader == Sh.body_xray(), "outline xray uses body xray shader")
	ck(entry.get("ring") != null, "outline xray keeps its ring")
	ck(mat.shader != Sh.ring_xray(), "the body material stays distinct from the ring")
	esp.free()
	scene.queue_free()

# The nomad marker paints its key through a shader uniform, so the
# calibration has to rewrite that uniform on the live markers.
func t_no_through_walls_opt() -> void:
	var esp = ESP.new()
	var opts := opts_of(esp, {"cat": S.NORMAL, "nomad": false})
	ck(not opts.has("through_walls"), "through_walls opt removed")
	ck(not opts.has("fill_style"), "fill_style opt removed")
	esp.free()

# The ai-death-post hook is unreliable in game; _draw must also mark the entry
# dead from the node's own `dead` flag, otherwise corpse cooling never starts.
func t_dead_node_marks_entry() -> void:
	var scene := Node3D.new()
	scene.name = "Map_dead"
	var bot := FakeBot.new()
	bot.name = "AI_Bandit_dead"
	scene.add_child(bot)
	root.add_child(scene)
	current_scene = scene

	var esp = ESP.new()
	esp.name = "VTKESP_dead"
	root.add_child(esp)
	esp.set_layers(true, false)
	ck(esp._entries.size() == 1, "dead-test bot discovered")

	var id := bot.get_instance_id()
	var e: Dictionary = esp._entries[id]
	ck(bool(e.get("dead", false)) == false, "entry alive before bot dies")
	bot.dead = true
	# Drive one draw pass with a player position so the entry loop runs.
	esp._draw(Vector3.ZERO)
	ck(bool(e.get("dead", false)) == true, "node dead flag marks the entry dead on draw")
	ck(esp._entries[id].has("death_ts") and float(esp._entries[id]["death_ts"]) > 0.0, "death timestamp set")

	esp.free()
	scene.queue_free()
func t_distance_crops_corpses() -> void:
	var scene := Node3D.new()
	scene.name = "Map_corpse_dist"
	var bot := FakeBot.new()
	bot.name = "AI_Bandit_corpse_dist"
	scene.add_child(bot)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	bot.add_child(mesh)
	root.add_child(scene)
	current_scene = scene
	var esp = ESP.new()
	esp.name = "VTKESP_corpse_dist"
	root.add_child(esp)
	esp.set_layers(true, false)
	esp.p_trig = false
	esp.p_dist = 5.0
	bot.dead = true
	bot.global_position = Vector3(0.0, 0.0, -50.0)
	esp._draw(Vector3.ZERO)
	ck(not esp._outline.has(bot.get_instance_id()), "far corpse gets no ring")
	bot.global_position = Vector3(0.0, 0.0, -2.0)
	esp._draw(Vector3.ZERO)
	ck(esp._outline.has(bot.get_instance_id()), "near corpse still gets its cooling ring")
	esp.free()
	scene.queue_free()

func t_xray_window_skips_cap() -> void:
	var scene := Node3D.new()
	scene.name = "Map_xray_cap"
	root.add_child(scene)
	current_scene = scene
	var ids: Array = []
	for i in 26:
		var b := FakeBot.new()
		b.name = "AI_Bandit_cap_%d" % i
		var m := MeshInstance3D.new()
		m.mesh = BoxMesh.new()
		b.add_child(m)
		scene.add_child(b)
		b.global_position = Vector3(0.0, 0.0, -float(i + 1))
		ids.append(b.get_instance_id())
	var esp = ESP.new()
	esp.name = "VTKESP_xray_cap"
	root.add_child(esp)
	esp.set_layers(true, true)
	esp.set_layers(true, true)
	esp.p_trig = true
	esp.p_dist = 100.0
	var far: FakeBot = scene.get_child(25)
	Tracker.tag_trig(esp._entries[far.get_instance_id()], "fire", 100.0, esp._now() + 60.0, 60.0)
	esp._draw(Vector3.ZERO)
	ck(esp._outline.has(far.get_instance_id()), "a reveal beyond the cap still draws")
	ck(esp._outline._items.size() == 25, "24 idle rings plus the reveal")
	esp.free()
	scene.queue_free()

func t_opts_reuse_updates() -> void:
	var scene := Node3D.new()
	scene.name = "Map_opts_reuse"
	var bot := FakeBot.new()
	bot.name = "AI_Bandit_opts"
	scene.add_child(bot)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	bot.add_child(mesh)
	root.add_child(scene)
	current_scene = scene
	var esp = ESP.new()
	esp.name = "VTKESP_opts_reuse"
	root.add_child(esp)
	esp.set_layers(true, false)
	esp.p_dist = 100.0
	esp._frame = 1
	var id := bot.get_instance_id()
	esp._draw(Vector3.ZERO)
	var first: Dictionary = esp._entries[id].get("opts")
	ck(first != null, "draw stores the options on the record")
	Tracker.apply_state(esp._entries[id], 8)
	esp._draw(Vector3.ZERO)
	var second: Dictionary = esp._entries[id].get("opts")
	ck(is_same(second, first), "the dictionary object is reused")
	ck(second.get("color") == S.DEFAULT_COMBAT, "the reused dictionary carries the new state")
	esp.free()
	scene.queue_free()

func t_candidate_pool_reused() -> void:
	var scene := Node3D.new()
	scene.name = "Map_pool"
	var near := FakeBot.new()
	near.name = "AI_Bandit_near"
	var far := FakeBot.new()
	far.name = "AI_Bandit_far"
	for b in [near, far]:
		var m := MeshInstance3D.new()
		m.mesh = BoxMesh.new()
		b.add_child(m)
		scene.add_child(b)
	root.add_child(scene)
	current_scene = scene
	near.global_position = Vector3(0.0, 0.0, -1.0)
	far.global_position = Vector3(0.0, 0.0, -9.0)
	var esp = ESP.new()
	esp.name = "VTKESP_pool"
	root.add_child(esp)
	esp.set_layers(true, false)
	esp.p_dist = 100.0
	esp._draw(Vector3.ZERO)
	ck(int(esp._cand_pool[0]["dist"]) == 1, "the pool keeps the collection order")
	ck(esp._cand_refs.size() == 2, "the reference array is sized to the collection")
	esp._draw(Vector3.ZERO)
	ck(int(esp._cand_pool[0]["dist"]) == 1, "a second frame did not reorder the pool")
	ck(esp._outline.has(near.get_instance_id()) and esp._outline.has(far.get_instance_id()), "both rings applied")
	esp.free()
	scene.queue_free()

func t_label_reads_stored_window() -> void:
	var esp = ESP.new()
	root.add_child(esp)
	var node := Node3D.new()
	root.add_child(node)
	var e := {"nomad": false, "dead": false}
	var now := esp._now()
	e["win"] = {"source": "fire", "dist": 50.0, "expires": now + 9.0, "span": 9.0}
	var txt: String = Labels.trigger_suffix(e.get("win", {}), now)
	ck(txt.contains("[fire"), "the stored window reaches the label")
	ck(txt.contains("9."), "the stored countdown is used")
	esp.free()
	node.free()
class FakeWeapon extends RefCounted:
	var ticks := 0
	var modes: Array = []
	func tick() -> void:
		ticks += 1
	func set_scope_mode(scoped: bool, pip: bool) -> void:
		modes.append([scoped, pip])

func t_xray_layer_without_contour() -> void:
	var scene := Node3D.new()
	scene.name = "Map_xray_layer"
	var bot := FakeBot.new()
	bot.name = "AI_Bandit_xray_layer"
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	bot.add_child(mesh)
	scene.add_child(bot)
	root.add_child(scene)
	current_scene = scene
	bot.global_position = Vector3(0.0, 0.0, -40.0)
	var esp = ESP.new()
	esp.name = "VTKESP_xray_layer"
	root.add_child(esp)
	esp.p_dist = 5.0
	esp.p_trig = true
	esp.set_layers(false, true)
	var id := bot.get_instance_id()
	var now := esp._now()
	Tracker.tag_trig(esp._entries[id], "fire", 100.0, now + 60.0, 60.0)
	esp._draw(Vector3.ZERO)
	ck(esp._outline.has(id), "reveal draws with the contour off")
	var mat: ShaderMaterial = esp._outline._items[id]["mat"]
	ck(mat != null and mat.shader == Sh.body_xray(), "the reveal swaps the overlay to the depth-free material")
	ck(esp._outline._items[id]["ring"] != null, "outline reveal keeps its ring")
	ck(mesh.material_overlay == mat, "the revealed mesh carries it")
	Tracker.tag_trig(esp._entries[id], "fire", 100.0, now - 1.0, 60.0)
	esp._draw(Vector3.ZERO)
	ck(not esp._outline.has(id), "an expired window clears the ring")
	esp.free()
	scene.queue_free()

func t_layers_drive_marker() -> void:
	var esp = ESP.new()
	root.add_child(esp)
	esp.set_layers(true, false)
	ck(esp.contour_layer and esp.marker_visible, "contour on shows the marker")
	esp.set_layers(false, true)
	ck(not esp.contour_layer and esp.xray_layer, "x-ray alone is a live layer")
	ck(not esp.marker_visible, "the marker belongs to the contour")
	esp.set_layers(false, false)
	ck(not esp.contour_layer and not esp.xray_layer, "both layers can be off")
	esp.free()

# ESP content demand: contours/reveals wanted this frame drive NVG buffer
# compositing and rendering. No NPC in range and no live reveal means no ESP
# content is needed. The want set is released by draw/clear_not_in, not by the
# demand going false.
func t_wants_contour() -> void:
	var scene := Node3D.new()
	scene.name = "Map_wants_contour"
	var bot := FakeBot.new()
	bot.name = "AI_Bandit_wants_contour"
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	bot.add_child(mesh)
	scene.add_child(bot)
	root.add_child(scene)
	current_scene = scene
	bot.global_position = Vector3(0.0, 0.0, -50.0)
	var esp = ESP.new()
	esp.name = "VTKESP_wants_contour"
	root.add_child(esp)
	esp.p_trig = false
	esp.p_dist = 5.0
	esp.set_layers(true, false)
	esp._draw(Vector3.ZERO)
	ck(not esp.wants_contour(), "an empty range demands no ESP content")
	bot.global_position = Vector3(0.0, 0.0, -2.0)
	esp._draw(Vector3.ZERO)
	ck(esp.wants_contour(), "a contour in range demands ESP content")
	bot.global_position = Vector3(0.0, 0.0, -50.0)
	esp._draw(Vector3.ZERO)
	ck(not esp.wants_contour(), "a contour outside Distance does not demand ESP content")
	# The gate never touches the want set: the outline is freed by clear_not_in,
	# not by the demand going false.
	ck(not esp._outline.has(bot.get_instance_id()), "the far contour is released by the draw")
	esp.p_dist = 60.0
	esp._draw(Vector3.ZERO)
	ck(esp.wants_contour(), "a contour inside Distance demands ESP content again")
	# X-ray alone: a live reveal keeps ESP content wanted even though the
	# contour layer is off.
	esp.set_layers(false, true)
	esp.p_trig = true
	Tracker.tag_trig(esp._entries[bot.get_instance_id()], "fire", 100.0, esp._now() + 60.0, 60.0)
	esp._draw(Vector3.ZERO)
	ck(esp.wants_contour(), "a live reveal demands ESP content")
	esp.set_layers(false, false)
	ck(not esp.wants_contour(), "layers off demands nothing")
	esp.free()
	scene.queue_free()

func t_weapon_runs_without_contour() -> void:
	var scene := Node3D.new()
	scene.name = "Map_weapon_layer"
	root.add_child(scene)
	current_scene = scene
	var esp = ESP.new()
	esp.name = "VTKESP_weapon_layer"
	root.add_child(esp)
	var w := FakeWeapon.new()
	esp._weapon = w
	esp.set_layers(false, true)
	esp._process(0.016)
	ck(w.ticks == 1, "weapon tick runs for the x-ray layer")
	ck(w.modes.size() == 1, "scope mode is pushed once")
	esp.free()
	scene.queue_free()
# The subject log follows ONE npc: the nearest candidate inside Distance.
# Dead / out-of-range / contour-off must move or drop the subject, otherwise
# the log would spread across every bot and turn into porridge.
func t_subject_is_nearest_candidate() -> void:
	var scene := Node3D.new()
	scene.name = "Map_subj"
	var near := FakeBot.new()
	near.name = "AI_Bandit_near"
	var far := FakeBot.new()
	far.name = "AI_Bandit_far"
	scene.add_child(near)
	scene.add_child(far)
	root.add_child(scene)
	current_scene = scene

	var esp = ESP.new()
	esp.name = "VTKESP_subj"
	root.add_child(esp)
	esp.p_trig = false
	esp.p_dist = 60.0
	var m1 := MeshInstance3D.new()
	m1.mesh = BoxMesh.new()
	near.add_child(m1)
	var m2 := MeshInstance3D.new()
	m2.mesh = BoxMesh.new()
	far.add_child(m2)
	esp.set_layers(true, false)
	near.global_position = Vector3(0.0, 0.0, -3.0)
	far.global_position = Vector3(0.0, 0.0, -30.0)
	esp._draw(Vector3.ZERO)
	ck(esp._subject_id() == near.get_instance_id(), "subject is the nearest candidate")

	near.dead = true
	esp._draw(Vector3.ZERO)
	ck(esp._subject_id() == far.get_instance_id(), "a corpse is not a subject")

	far.global_position = Vector3(0.0, 0.0, -300.0)
	esp._draw(Vector3.ZERO)
	ck(esp._subject_id() == 0, "nobody inside Distance leaves no subject")

	esp.set_layers(false, false)
	far.global_position = Vector3(0.0, 0.0, -30.0)
	esp._draw(Vector3.ZERO)
	ck(esp._subject_id() == 0, "contour off means no subject")

	esp.free()
	scene.queue_free()

# The per-frame ESP_SUBJ row was a 2.10.25 investigation aid for the pass-order
# bug. With that fixed it only spoils the log: dist is in the dedup signature,
# so a moving subject writes a line every frame. The logger must stay gone.
func t_no_perframe_subject_log() -> void:
	var f := FileAccess.open("res://mods/ThermalVTK/VTKESP.gd", FileAccess.READ)
	ck(f != null, "the ESP source is readable")
	if f == null:
		return
	var src := f.get_as_text()
	f.close()
	ck(not src.contains("ESP_SUBJ"), "the subject log tag is gone")
	ck(not src.contains("_dbg_subject"), "the per-frame subject logger is gone")
	ck(not src.contains("_log_subject"), "the subject sink helper is gone")

func los_force(esp, id: int) -> void:
	esp._frame = (esp.LOS_EVERY - (id % esp.LOS_EVERY)) % esp.LOS_EVERY

func t_los_excludes_self() -> void:
	var body := CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	body.add_child(shape)
	var nested := StaticBody3D.new()
	nested.add_child(CollisionShape3D.new())
	(nested.get_child(0) as CollisionShape3D).shape = BoxShape3D.new()
	body.add_child(nested)
	var esp = ESP.new()
	var rids: Array[RID] = []
	esp._subtree_rids(body, rids)
	ck(rids.size() == 2, "both collision objects collected")
	ck(rids.has(body.get_rid()), "the root body rid is included")
	ck(rids.has(nested.get_rid()), "a nested body rid is included")
	esp.free()
	body.free()
func t_parked_trigger_does_not_register() -> void:
	var scene := Node3D.new()
	scene.name = "Map_parked_hook"
	var bot := FakeBot.new()
	bot.name = "AI_Bandit_parked_hook"
	scene.add_child(bot)
	root.add_child(scene)
	current_scene = scene
	var esp = ESP.new()
	esp.name = "VTKESP_parked_hook"
	root.add_child(esp)
	var lib := FakeLib.new()
	lib._caller = bot
	esp._lib = lib
	esp.set_layers(false, false)
	esp._entries.erase(bot.get_instance_id())
	esp._on_ai_playfire()
	ck(not esp._entries.has(bot.get_instance_id()), "a parked layer ignores the trigger")
	esp.set_layers(true, false)
	esp._entries.erase(bot.get_instance_id())
	esp._on_ai_playfire()
	ck(esp._entries.has(bot.get_instance_id()), "a live layer registers the caller again")
	esp.free()
	scene.queue_free()

# F10 needs the bot under the crosshair, not the nearest bot in Euclidean
# range: a bot far off to the side must not steal the key from the one the
# player is looking at.
func t_crosshair_target() -> void:
	root.size = Vector2i(800, 600)
	var cam := Camera3D.new()
	root.add_child(cam)
	var center := cam.unproject_position(Vector3(0.0, 0.0, -10.0))
	var candidates := [
		{"id": 1, "pos": Vector3(0.0, 0.0, -10.0)},
		{"id": 2, "pos": Vector3(20.0, 0.0, -10.0)},
	]
	ck(ESP.pick_target_id(candidates, cam, center, 80.0) == 1, "bot under the crosshair wins")
	ck(ESP.pick_target_id([], cam, center, 80.0) == -1, "empty candidate list has no target")
	cam.free()