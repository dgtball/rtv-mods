extends SceneTree

const Outline = preload("res://mods/ThermalVTK/VTKOutline.gd")
const Sh = preload("res://mods/ThermalVTK/VTKShaders.gd")
const S = preload("res://mods/ThermalVTK/VTKStates.gd")
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
	t_collect_default_layer()
	t_collect_all_geometry()
	t_collect_skips_mod_geometry()
	t_refresh_sets_state_color()
	t_material_mask_contract()
	t_scope_thin_rim()
	t_scope_seed_on_late_apply()
	t_shells()
	t_shell_recollect()
	t_entry_xray()
	t_clear_not_in()
	print("")
	if fails == 0:
		print("Outline tests passed")
		quit(0)
	else:
		print("Outline tests failed: ", fails)
		quit(1)

# The bug this guards: _collect used to require render layer bit 2, so bots on
# the default layer 1 were never collected and the whole contour drew nothing.
func t_collect_default_layer() -> void:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	var o = Outline.new()
	var out: Array = []
	o._collect(root, out)
	ck(out.size() == 1 and out[0] == mesh, "default-layer mesh collected")
	root.free()

func t_collect_all_geometry() -> void:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.visible = false
	root.add_child(mesh)
	# A shell is a sibling copy of a mesh, so a MultiMesh/CSG/Decal has nothing
	# to mirror: collecting them only grew empty pairs and triggered recollects
	# (a bullet decal on a body did it on every hit).
	var mm := MultiMeshInstance3D.new()
	root.add_child(mm)
	var plain := Node3D.new()
	root.add_child(plain)
	var o = Outline.new()
	var out: Array = []
	o._collect(root, out)
	ck(out.size() == 1, "geometry collected (mesh instances only): %d" % out.size())
	ck(out.has(mesh), "an invisible LOD still carries a shell")
	ck(not out.has(mm), "a MultiMesh has no sibling shell")
	root.free()

# The nomad marker and the debug label live under the bot; painting them too
# would put a ring around a ring.
func t_collect_skips_mod_geometry() -> void:
	var root := Node3D.new()
	var bot := MeshInstance3D.new()
	bot.mesh = BoxMesh.new()
	root.add_child(bot)
	var marker := MeshInstance3D.new()
	marker.mesh = QuadMesh.new()
	marker.set_meta(Outline.NO_CONTOUR_META, true)
	var nested := MeshInstance3D.new()
	nested.mesh = BoxMesh.new()
	marker.add_child(nested)
	root.add_child(marker)
	var o = Outline.new()
	var out: Array = []
	o._collect(root, out)
	ck(out.size() == 1, "only the bot mesh is collected")
	root.free()

# The ring carries the mask category (not a drawn colour), grow, rim and the
# cooling fade from opts.
func t_refresh_sets_state_color() -> void:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	var o = Outline.new()
	o.apply(7, root, {"cat": S.COMBAT, "grow": 0.01, "cool": 0.5, "rim": 1.4})
	var ring: ShaderMaterial = o._items[7]["ring"]
	ck(ring.get_shader_parameter("state_color") == S.MASK_COMBAT, "ring state_color set to the category mask key")
	ck(is_equal_approx(float(ring.get_shader_parameter("grow")), 0.01), "ring grow set")
	ck(is_equal_approx(float(ring.get_shader_parameter("cool")), 0.5), "ring cool set")
	ck(is_equal_approx(float(ring.get_shader_parameter("rim_power")), 1.4), "ring rim_power set")
	ck(not o._items[7].has("body"), "no body pass on the entry")
	o.clear(7)
	root.free()

# The mask shader writes the pure channel key; the NVG overlay reads the
# dominant channel and substitutes the display colour. The old daylight key
# gain is meaningless here: the mask never passes through the tonemap.
func t_material_mask_contract() -> void:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	var o = Outline.new()
	o.apply(11, root, {"cat": S.DEFEND, "grow": 0.01, "cool": 0.5})
	var ring: ShaderMaterial = o._items[11]["ring"]
	var code := String(ring.shader.code)
	ck(code.contains("uniform vec3 state_color"), "mask ring declares state_color")
	ck(code.contains("stencil_mode read"), "mask ring reads the body stencil")
	ck(not code.contains("vtk_key_gain"), "mask ring has no daylight key gain")
	ck(not code.contains("state_key"), "mask ring has no detector key")
	ck(ring.get_shader_parameter("state_color") == S.MASK_DEFEND, "defend writes the blue channel")
	o.clear(11)
	root.free()

# In the scope the band thins to a frame: rim_power is forced to 6.0 while the
# slider keeps 2.0 outside.
func t_scope_thin_rim() -> void:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	var o = Outline.new()
	var opts := {"cat": S.NORMAL, "grow": 0.01, "rim": 2.0, "cool": 0.0}
	o.apply(7, root, opts)
	var ring: ShaderMaterial = o._items[7]["ring"]
	ck(ring.shader == Sh.mask_ring(), "idle ring uses the depth-tested mask shader")
	ck(is_equal_approx(float(ring.get_shader_parameter("rim_power")), 2.0), "ring uses the slider rim outside the scope")
	o.set_scoped(true)
	o.refresh(7, opts)
	ck(ring.shader == Sh.mask_ring(), "depth-tested ring survives scope entry")
	ck(is_equal_approx(float(ring.get_shader_parameter("rim_power")), 6.0), "rim forced to 6.0 in the scope")
	o.set_scoped(false)
	o.refresh(7, opts)
	ck(is_equal_approx(float(ring.get_shader_parameter("rim_power")), 2.0), "rim restored on scope exit")
	o.clear(7)
	root.free()

# A bot discovered inside the scope view gets the current scope state straight
# away: apply seeds the material from the scope state, not from stale defaults.
func t_scope_seed_on_late_apply() -> void:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	var o = Outline.new()
	o.set_scoped(true)
	o.apply(9, root, {"cat": S.NORMAL, "grow": 0.01, "cool": 0.0})
	var ring: ShaderMaterial = o._items[9]["ring"]
	ck(is_equal_approx(float(ring.get_shader_parameter("rim_power")), 6.0), "late apply picks up the scoped rim")
	o.set_scoped(false)
	ck(ring.shader == Sh.mask_ring(), "the scope flip keeps the depth-tested shader")
	o.clear(9)
	root.free()

# The ring draws on ghost shells: a sibling copy of the mesh receives
# material_override, so the bot's own material pipeline cannot hide it. The
# shells live on the mask layer only, so no picture camera draws them; the
# source mesh keeps its material untouched.
func t_shells() -> void:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	var mm := MultiMeshInstance3D.new()
	root.add_child(mm)
	var o = Outline.new()
	o.apply(3, root, {"cat": S.NORMAL, "grow": 0.01, "cool": 0.0})
	var pairs: Array = o._items[3]["pairs"]
	ck(pairs.size() == 1, "one pair per collected mesh")
	var shell: MeshInstance3D = pairs[0]["shell"]
	ck(shell != null and is_instance_valid(shell), "mesh got a shell")
	ck(shell.mesh == mesh.mesh, "shell shares the source mesh")
	ck(shell.layers == EspMask.LAYER_MASK, "shell lives on the mask layer only")
	ck((shell.layers & 1) == 0, "shell is invisible to the world camera")
	ck(shell.material_override == o._items[3]["ring"], "shell carries the ring as override")
	ck(shell.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "shell casts no shadow")
	ck(shell.has_meta("vtk_no_contour"), "shell opts out of the sweep")
	ck(shell.get_parent() == root, "shell neighbours the source")
	ck(mesh.material_overlay == null, "source mesh keeps its material")
	ck(mm.material_overlay == null, "non-mesh geometry is not collected and keeps its own material")
	o.clear(3)
	ck(not is_instance_valid(shell) or shell.is_queued_for_deletion(), "clear frees the shell")
	root.free()

# Recollect on child-count growth re-sweeps the rig, but it is incremental: a
# shell whose source is still there is reused, only a newly appeared mesh gets
# a new one. The vanilla AI adds and removes a direct child on most steps and
# lines (audio players, identifier), so free-and-recreate here churned 10-23
# MeshInstance3D per event, several times per second per bot.
func t_shell_recollect() -> void:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	var o = Outline.new()
	o.apply(5, root, {"cat": S.NORMAL, "grow": 0.01, "cool": 0.0})
	var old_shell: MeshInstance3D = o._items[5]["pairs"][0]["shell"]
	ck(o.take_recols() == 0, "apply is not a recollect")
	# A non-geometry direct child only moves the count: keep every shell.
	root.add_child(Node3D.new())
	o.refresh(5, {"cat": S.NORMAL, "grow": 0.01, "cool": 0.0})
	ck(is_instance_valid(old_shell) and not old_shell.is_queued_for_deletion(), "a non-geometry child keeps the shell")
	ck(o.take_recols() == 0, "a non-geometry child rebuilds nothing")
	ck(o._items[5]["pairs"].size() == 1, "the pair list is unchanged")
	var extra := MeshInstance3D.new()
	extra.mesh = QuadMesh.new()
	root.add_child(extra)
	o.refresh(5, {"cat": S.NORMAL, "grow": 0.01, "cool": 0.0})
	var shells: Array = []
	for c in root.get_children():
		if c.is_queued_for_deletion():
			continue
		if c is MeshInstance3D and c.has_meta("vtk_no_contour"):
			shells.append(c)
	ck(shells.size() == 2, "recollect added exactly one shell for the new mesh")
	ck(is_instance_valid(old_shell) and not old_shell.is_queued_for_deletion(), "the known mesh keeps its shell")
	ck(o._items[5]["pairs"][0]["shell"] == old_shell, "the reused pair still points at the old shell")
	ck(o._items[5]["pairs"][1]["src"] == extra, "the new mesh got the new pair")
	ck(o.take_recols() == 1, "one real rebuild was counted")
	# Our own shells must never look like a game-side child count change.
	ck(o._child_count(root) == 3, "mod shells are excluded from the child count")
	o.clear(5)
	root.free()

# A live trigger window swaps that bot's shell material to the depth-free mask
# shader; the idle ring keeps the normal depth test.
func t_entry_xray() -> void:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	var o = Outline.new()
	o.apply(6, root, {"cat": S.NORMAL, "grow": 0.01, "cool": 0.0})
	var ring: ShaderMaterial = o._items[6]["ring"]
	var xmat: ShaderMaterial = o._items[6]["xray_mat"]
	var shell: MeshInstance3D = o._items[6]["pairs"][0]["shell"]
	ck(ring.shader == Sh.mask_ring(), "the ring keeps the depth-tested mask shader")
	ck(shell.material_override == ring, "idle shell carries the ring")
	o.set_entry_xray(6, true)
	ck(shell.material_override == xmat, "a live window swaps the shell to the x-ray material")
	ck(xmat.shader == Sh.mask_xray(), "the x-ray material is the depth-free mask shader")
	o.set_entry_xray(6, true)
	ck(shell.material_override == xmat, "same value keeps the material")
	o.set_entry_xray(6, false)
	ck(shell.material_override == ring, "closing the window restores the ring")
	o.refresh(6, {"cat": S.NORMAL, "grow": 0.01, "cool": 0.0, "xray": true})
	ck(shell.material_override == xmat, "opts xray swaps the material")
	o.refresh(6, {"cat": S.NORMAL, "grow": 0.01, "cool": 0.0})
	ck(shell.material_override == ring, "opts without xray restores the ring")
	o.clear(6)
	root.free()

func t_clear_not_in() -> void:
	var a := Node3D.new()
	a.add_child(MeshInstance3D.new())
	(a.get_child(0) as MeshInstance3D).mesh = BoxMesh.new()
	var b := Node3D.new()
	b.add_child(MeshInstance3D.new())
	(b.get_child(0) as MeshInstance3D).mesh = BoxMesh.new()
	var o = Outline.new()
	o.apply(1, a, {})
	o.apply(2, b, {})
	o.clear_not_in({1: true})
	ck(o.has(1), "kept id survives")
	ck(not o.has(2), "absent id is cleared")
	o.clear_not_in({})
	ck(not o.has(1), "an empty keep clears everything")
	var c := Node3D.new()
	c.add_child(MeshInstance3D.new())
	(c.get_child(0) as MeshInstance3D).mesh = BoxMesh.new()
	o.apply(3, c, {})
	o.clear_not_in({3: true})
	ck(o.has(3), "the later clear leaves nothing stale behind")
	a.free()
	b.free()
	c.free()
