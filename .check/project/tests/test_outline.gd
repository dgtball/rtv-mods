extends SceneTree

const Outline = preload("res://mods/ThermalVTK/VTKOutline.gd")
const Sh = preload("res://mods/ThermalVTK/VTKShaders.gd")

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
	t_refresh_sets_state_key()
	t_material_key_contract()
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
	var mm := MultiMeshInstance3D.new()
	root.add_child(mm)
	var plain := Node3D.new()
	root.add_child(plain)
	var o = Outline.new()
	var out: Array = []
	o._collect(root, out)
	ck(out.has(mesh), "hidden mesh still collected")
	ck(out.has(mm), "multimesh collected")
	ck(not out.has(plain), "non-geometry node skipped")
	root.free()

# The nomad marker and the debug label are our own geometry parented under the
# bot's mesh. If the sweep collects them it hands them the ring overlay, which
# is painted ON TOP of their material, so the nomad key never reaches the
# overlay and the green marker never shows. They carry a meta the sweep honours.
func t_collect_skips_mod_geometry() -> void:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	var marker := MeshInstance3D.new()
	marker.mesh = QuadMesh.new()
	marker.set_meta("vtk_no_contour", true)
	root.add_child(marker)
	# A tagged node's own children are skipped too (the tag prunes the subtree).
	var tagged_parent := Node3D.new()
	tagged_parent.set_meta("vtk_no_contour", true)
	root.add_child(tagged_parent)
	var nested := MeshInstance3D.new()
	nested.mesh = BoxMesh.new()
	tagged_parent.add_child(nested)
	var o = Outline.new()
	var out: Array = []
	o._collect(root, out)
	ck(out.has(mesh), "bot mesh still collected")
	ck(not out.has(marker), "tagged marker mesh skipped")
	ck(not out.has(nested), "children of a tagged node skipped too")
	ck(out.size() == 1, "only the bot mesh is collected")
	root.free()

# The ring carries the detector key (not a drawn colour), grow, rim and the
# cooling fade from opts.
func t_refresh_sets_state_key() -> void:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	var o = Outline.new()
	o.apply(7, root, {"state_key": Color(0, 1, 0), "grow": 0.01, "cool": 0.5, "rim": 1.4})
	var ring: ShaderMaterial = o._items[7]["ring"]
	ck(ring.get_shader_parameter("state_key") == Color(0, 1, 0), "ring state_key set")
	ck(is_equal_approx(float(ring.get_shader_parameter("grow")), 0.01), "ring grow set")
	ck(is_equal_approx(float(ring.get_shader_parameter("cool")), 0.5), "ring cool set")
	ck(is_equal_approx(float(ring.get_shader_parameter("rim_power")), 1.4), "ring rim_power set")
	ck(not o._items[7].has("body"), "no body pass on the entry")
	root.free()

# The shader the outline actually puts on the meshes has to carry the key
# contract: the ring emits the pure state key, because the NVG overlay detects
# that key and swaps in the display colour. The corpse fade is alpha-only, so a
# cooling corpse still reads as its key while the body dissolves.
func t_material_key_contract() -> void:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	var o = Outline.new()
	o.apply(11, root, {"state_key": Color(0, 1, 0), "grow": 0.01, "cool": 0.5})
	var ring: ShaderMaterial = o._items[11]["ring"]
	var ring_code := String(ring.shader.code)
	ck(ring_code.contains("global uniform float vtk_key_gain"), "ring material reads the daylight gain")
	ck(ring_code.contains("ALBEDO = state_key * vtk_key_gain;"), "ring material scales the key by the daylight gain")
	root.free()

# The ring draws on ghost shells: a sibling copy of the mesh receives
# material_override + no_depth_test, so the bot's own material pipeline and the
# depth buffer can never hide it (the way the scope lens z-culled overlays).
# The source mesh keeps its material untouched.
func t_shells() -> void:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	var mm := MultiMeshInstance3D.new()
	root.add_child(mm)
	var o = Outline.new()
	o.apply(3, root, {"state_key": Color(0, 1, 0), "grow": 0.01, "cool": 0.0})
	var pairs: Array = o._items[3]["pairs"]
	ck(pairs.size() == 2, "one pair per collected geometry")
	var shell: MeshInstance3D = pairs[0]["shell"]
	ck(shell != null and is_instance_valid(shell), "mesh got a shell")
	ck(shell.mesh == mesh.mesh, "shell shares the source mesh")
	ck(shell.material_override == o._items[3]["ring"], "shell carries the ring as override")
	ck(shell.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "shell casts no shadow")
	ck(shell.has_meta("vtk_no_contour"), "shell opts out of the sweep")
	ck(shell.get_parent() == root, "shell neighbours the source")
	ck(mesh.material_overlay == null, "source mesh keeps its material")
	var mmp: Dictionary = pairs[1]
	ck(mmp["shell"] == null and bool(mmp["overlay"]), "non-mesh geometry keeps the overlay path")
	ck(mm.material_overlay == o._items[3]["ring"], "multimesh carries the ring overlay")
	o.clear(3)
	ck(not is_instance_valid(shell) or shell.is_queued_for_deletion(), "clear frees the shell")
	var overlay: Material = mm.material_overlay
	if overlay != null:
		ck(mm.material_overlay.get_shader() == null or mm.material_overlay != o._items[3]["ring"], "overlay lifted off the multimesh")
	root.free()

# Recollect on child-count growth frees the stale shells and builds fresh
# ones, and the shells never double up.
func t_shell_recollect() -> void:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	var o = Outline.new()
	o.apply(5, root, {"state_key": Color(0, 1, 0), "grow": 0.01, "cool": 0.0})
	var old_shell: MeshInstance3D = o._items[5]["pairs"][0]["shell"]
	var extra := MeshInstance3D.new()
	extra.mesh = QuadMesh.new()
	root.add_child(extra)
	o.refresh(5, {"state_key": Color(0, 1, 0), "grow": 0.01, "cool": 0.0})
	var shells: Array = []
	for c in root.get_children():
		if c.is_queued_for_deletion():
			continue
		if c is MeshInstance3D and c.has_meta("vtk_no_contour"):
			shells.append(c)
	ck(shells.size() == 2, "recollect rebuilt exactly one shell per mesh")
	ck(not is_instance_valid(old_shell) or old_shell.is_queued_for_deletion(), "stale shell freed on recollect")
	root.free()

# In the scope the band thins to a frame: rim_power is forced to 6.0 while the
# slider keeps 2.0 outside; the carve stays narrow, so scope metal hides the
# ring by the depth compare, and the glass lets it through by draw order.
func t_scope_thin_rim() -> void:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	var o = Outline.new()
	var opts := {"state_key": Color(0, 1, 0), "grow": 0.01, "rim": 2.0, "cool": 0.0}
	o.apply(7, root, opts)
	var ring: ShaderMaterial = o._items[7]["ring"]
	ck(ring.shader == Sh.ring(), "idle ring uses the depth-tested shader")
	ck(is_equal_approx(float(ring.get_shader_parameter("rim_power")), 2.0), "ring uses the slider rim outside the scope")
	o.set_scoped(true)
	o.refresh(7, opts)
	ck(ring.shader == Sh.ring(), "depth-tested ring survives scope entry")
	ck(is_equal_approx(float(ring.get_shader_parameter("rim_power")), 6.0), "rim forced to 6.0 in the scope")
	o.set_scoped(false)
	o.refresh(7, opts)
	ck(is_equal_approx(float(ring.get_shader_parameter("rim_power")), 2.0), "rim restored on scope exit")
	root.free()

# With PIP on the scope picture is the optic camera's own render, which shows
# the ring's ghost shells by itself. The main-camera ring paints over the
# glass only in the no-PIP path (it IS the in-scope picture there); with PIP
# on it must drop under the glass, or the picture shows the ring twice.
# A bot discovered inside the scope view gets the current scope state straight
# away: apply seeds the material from the scope state, not from stale defaults.
func t_scope_seed_on_late_apply() -> void:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	var o = Outline.new()
	o.set_scoped(true)
	o.apply(9, root, {"state_key": Color(0, 1, 0), "grow": 0.01, "cool": 0.0})
	var ring: ShaderMaterial = o._items[9]["ring"]
	ck(is_equal_approx(float(ring.get_shader_parameter("rim_power")), 6.0), "late apply picks up the scoped rim")
	o.set_scoped(false)
	ck(ring.shader == Sh.ring(), "the scope flip keeps the depth-tested shader")
	root.free()

# A live trigger window swaps that bot's ring to the depth-free x-ray shader;
# the idle ring keeps the normal depth test.
func t_entry_xray() -> void:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	var o = Outline.new()
	o.apply(6, root, {"state_key": Color(0, 1, 0), "grow": 0.01, "cool": 0.0})
	var xmat: ShaderMaterial = o._items[6]["ring"]
	ck(xmat.shader == Sh.ring(), "default ring honours walls")
	o.set_entry_xray(6, true)
	ck(xmat.shader == Sh.ring_xray(), "entry flip swaps to the x-ray shader")
	ck(bool(xmat.get_shader_parameter("near_only")), "entry flip lights the x-ray uniform")
	ck(is_equal_approx(float(xmat.get_shader_parameter("carve")), 0.60), "x-ray carve covers the near hardware")
	o.set_entry_xray(6, true)
	ck(xmat.shader == Sh.ring_xray(), "same value keeps x-ray")
	o.set_entry_xray(6, false)
	ck(xmat.shader == Sh.ring(), "off returns to the depth-tested shader")
	o.refresh(6, {"state_key": Color(0, 1, 0), "grow": 0.01, "cool": 0.0, "xray": true})
	ck(xmat.shader == Sh.ring_xray(), "opts xray drives the swap")
	o.refresh(6, {"state_key": Color(0, 1, 0), "grow": 0.01, "cool": 0.0})
	ck(xmat.shader == Sh.ring(), "opts without xray returns to the depth-tested shader")
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
