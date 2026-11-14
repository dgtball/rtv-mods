extends SceneTree

const Outline = preload("res://mods/ThermalVTK/VTKOutline.gd")
const Sh = preload("res://mods/ThermalVTK/VTKShaders.gd")
const S = preload("res://mods/ThermalVTK/VTKStates.gd")

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
	t_overlay_on_mesh()
	t_fill_chain()
	t_recollect_keeps_overlay()
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
	# The overlay only attaches to MeshInstance3D: a MultiMesh/CSG/Decal has no
	# material_overlay to paint, and collecting them only grew empty work and
	# triggered recollects (a bullet decal on a body did it on every hit).
	var mm := MultiMeshInstance3D.new()
	root.add_child(mm)
	var plain := Node3D.new()
	root.add_child(plain)
	var o = Outline.new()
	var out: Array = []
	o._collect(root, out)
	ck(out.size() == 1, "geometry collected (mesh instances only): %d" % out.size())
	ck(out.has(mesh), "an invisible LOD still gets the overlay")
	ck(not out.has(mm), "a MultiMesh has no overlay target")
	root.free()

# The nomad marker and the debug label live under the bot; painting them too
# would put a contour around a contour.
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
# cooling fade from opts, and the material is in place on the first frame.
func t_refresh_sets_state_color() -> void:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	var o = Outline.new()
	o.apply(7, root, {"cat": S.COMBAT, "grow": 0.01, "cool": 0.5, "rim": 1.4})
	var ring: ShaderMaterial = o._items[7]["ring"]
	ck(ring.get_shader_parameter("state_color") == S.KEY_COMBAT, "ring state_color set to the category key")
	ck(is_equal_approx(float(ring.get_shader_parameter("grow")), 0.01), "ring grow set")
	ck(is_equal_approx(float(ring.get_shader_parameter("cool")), 0.5), "ring cool set")
	ck(is_equal_approx(float(ring.get_shader_parameter("rim_power")), 1.4), "ring rim_power set")
	ck(not o._items[7].has("body"), "no body pass on the entry")
	o.clear(7)
	root.free()

# The ring shader writes the raw category key into the main 3D pass; the NVG
# overlay matches the washed pixel and substitutes the display colour. The key
# gain is back: daylight compensation lowers the exposure, so the key has to be
# scaled by the same factor or its washed value drifts out of the detector.
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
	ck(code.contains("vtk_key_gain"), "mask ring scales the key back in daylight")
	ck(not code.contains("floor_alpha"), "mask ring has no coverage floor")
	ck(ring.get_shader_parameter("state_color") == S.KEY_DEFEND, "defend writes the magenta key")
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

# The contour is a material_overlay on the bot's own meshes: it lives in the
# main 3D pass, so the depth test clips it against walls, the weapon and the
# sight glass for free. There is no second world pass and no ghost shell.
func t_overlay_on_mesh() -> void:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	var mm := MultiMeshInstance3D.new()
	root.add_child(mm)
	var o = Outline.new()
	o.apply(3, root, {"cat": S.NORMAL, "grow": 0.01, "cool": 0.0})
	var mat: ShaderMaterial = o._items[3]["mat"]
	ck(mat != null and mat.shader == Sh.mask_ring(), "the ring material is the contour overlay")
	ck(mesh.material_overlay == mat, "the mesh carries the contour as material_overlay")
	ck(mesh.material_override == null, "the source material pipeline is untouched")
	ck(mm.material_overlay == null, "non-mesh geometry gets no overlay")
	ck(o._items[3]["ring"] == mat, "a plain ring is its own ring pass")
	o.clear(3)
	ck(mesh.material_overlay == null, "clear removes the overlay")
	root.free()

# Full body is a flat silhouette fill with no contour ring: the body pass paints
# the whole silhouette with the category key and the NVG shader substitutes a
# flat display colour (semi-transparent). No next_pass chain is used.
func t_fill_chain() -> void:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	var o = Outline.new()
	o.apply(4, root, {"cat": S.COMBAT, "fill": true, "grow": 0.01, "fill_alpha": 0.4})
	var body: ShaderMaterial = o._items[4]["mat"]
	var ring: ShaderMaterial = o._items[4]["ring"]
	ck(body.shader == Sh.mask_fill(), "fill mode uses the body fill shader")
	ck(ring == body, "full-body fill has no contour ring pass")
	ck(body.next_pass == null, "full-body fill has no next_pass chain")
	ck(mesh.material_overlay == body, "the fill overlay is applied to the mesh")
	ck(body.get_shader_parameter("state_color") == S.KEY_COMBAT, "the body paints the category key")
	ck(is_equal_approx(float(body.get_shader_parameter("grow")), 0.01), "grow reaches the body fill")
	ck(is_equal_approx(float(body.get_shader_parameter("alpha")), 0.4), "fill alpha reaches the body fill")
	o.refresh(4, {"cat": S.DEFEND, "fill": true, "grow": 0.02, "cool": 0.4, "fill_alpha": 0.6})
	ck(body.get_shader_parameter("state_color") == S.KEY_DEFEND, "refresh repaints the body")
	ck(is_equal_approx(float(body.get_shader_parameter("cool")), 0.4), "refresh reaches the body cool")
	ck(is_equal_approx(float(body.get_shader_parameter("grow")), 0.02), "refresh updates grow")
	ck(is_equal_approx(float(body.get_shader_parameter("alpha")), 0.6), "refresh updates fill alpha")
	o.refresh(4, {"cat": S.DEFEND, "fill": false, "grow": 0.02, "rim": 0.0, "cool": 0.4})
	ck(mesh.material_overlay != null and (mesh.material_overlay as ShaderMaterial).shader == Sh.mask_ring(), "leaving fill mode restores the outline ring")
	o.clear(4)
	root.free()

# Recollect on child-count growth re-sweeps the rig, but the material is kept:
# only a newly appeared mesh has to receive it. The vanilla AI adds and removes
# a direct child on most steps (audio players, identifier), so re-applying the
# overlay to every mesh on each event would churn the render tree.
func t_recollect_keeps_overlay() -> void:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	var o = Outline.new()
	o.apply(5, root, {"cat": S.NORMAL, "grow": 0.01, "cool": 0.0})
	var mat: ShaderMaterial = o._items[5]["mat"]
	# A non-geometry direct child only moves the count: keep the mesh list.
	root.add_child(Node3D.new())
	o.refresh(5, {"cat": S.NORMAL, "grow": 0.01, "cool": 0.0})
	ck(o._items[5]["meshes"].size() == 1, "the mesh list is unchanged")
	var extra := MeshInstance3D.new()
	extra.mesh = QuadMesh.new()
	root.add_child(extra)
	o.refresh(5, {"cat": S.NORMAL, "grow": 0.01, "cool": 0.0})
	ck(o._items[5]["meshes"].size() == 2, "recollect picked up the new mesh")
	ck(mesh.material_overlay == mat, "the known mesh keeps its overlay")
	ck(extra.material_overlay == mat, "the new mesh got the same overlay")
	# Our own marker must never look like a game-side child count change.
	var marker := MeshInstance3D.new()
	marker.set_meta(Outline.NO_CONTOUR_META, true)
	root.add_child(marker)
	ck(o._child_count(root) == 3, "mod geometry is excluded from the child count")
	o.clear(5)
	root.free()

# A live trigger window swaps that bot's overlay to the depth-free mask shader;
# the idle ring keeps the normal depth test.
func t_entry_xray() -> void:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	var o = Outline.new()
	o.apply(6, root, {"cat": S.NORMAL, "grow": 0.01, "cool": 0.0})
	var ring: ShaderMaterial = o._items[6]["ring"]
	ck(ring.shader == Sh.mask_ring(), "the ring keeps the depth-tested mask shader")
	ck(mesh.material_overlay == ring, "the idle mesh carries the ring")
	o.refresh(6, {"cat": S.NORMAL, "grow": 0.01, "cool": 0.0, "xray": true})
	var xmat: ShaderMaterial = o._items[6]["mat"]
	ck(xmat.shader == Sh.mask_xray(), "the x-ray material is the depth-free mask shader")
	ck(mesh.material_overlay == xmat, "a live window swaps the overlay to x-ray")
	o.refresh(6, {"cat": S.NORMAL, "grow": 0.01, "cool": 0.0, "xray": true})
	ck(o._items[6]["mat"] == xmat, "same value keeps the material")
	o.refresh(6, {"cat": S.NORMAL, "grow": 0.01, "cool": 0.0})
	ck(mesh.material_overlay == o._items[6]["mat"], "closing the window restores the ring")
	ck((mesh.material_overlay as ShaderMaterial).shader == Sh.mask_ring(), "the restored material is the ring")
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
