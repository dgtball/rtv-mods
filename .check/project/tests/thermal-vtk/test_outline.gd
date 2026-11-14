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
	t_outline_chain_and_uniforms()
	t_fill_single_body_no_ring()
	t_fill_has_no_ring_even_in_xray()
	t_outline_xray_preserves_shape()
	t_toggle_xray_restores_los()
	t_cool_reaches_materials()
	t_scope_rim_compat()
	t_scope_seed_on_late_apply()
	t_overlay_on_mesh()
	t_recollect_keeps_overlay()
	t_clear_not_in()
	print("")
	if fails == 0:
		print("Outline tests passed")
		quit(0)
	else:
		print("Outline tests failed: ", fails)
		quit(1)

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
	ck(out.size() == 1, "geometry collected (mesh instances only): %d" % out.size())
	ck(out.has(mesh), "an invisible LOD still gets the overlay")
	ck(not out.has(mm), "a MultiMesh has no overlay target")
	root.free()

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

func t_outline_chain_and_uniforms() -> void:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	var o = Outline.new()
	o.apply(1, root, {"fill": false, "xray": false, "color": S.DEFAULT_COMBAT, "brightness": 1.2, "alpha": 0.8, "grow": 0.01, "rim": 1.4, "cool": 0.3})
	var body: ShaderMaterial = o._items[1]["mat"]
	var ring: ShaderMaterial = body.next_pass as ShaderMaterial
	ck(mesh.material_overlay == body, "outline applies body overlay to mesh")
	ck(body.shader == Sh.body_los(), "outline body uses body_los shader")
	ck(ring != null and ring.shader == Sh.ring_los(), "outline body has ring_los next_pass")
	ck(is_equal_approx(float(body.get_shader_parameter("alpha")), 0.0), "outline body alpha is mask-only 0")
	ck(body.get_shader_parameter("outline_color") == S.DEFAULT_COMBAT, "outline body carries display color")
	ck(is_equal_approx(float(body.get_shader_parameter("brightness")), 1.2), "outline body brightness set")
	ck(is_equal_approx(float(body.get_shader_parameter("grow")), 0.01), "outline body grow set")
	ck(is_equal_approx(float(body.get_shader_parameter("cool")), 0.3), "outline body cool set")
	ck(ring.get_shader_parameter("outline_color") == S.DEFAULT_COMBAT, "outline ring carries display color")
	ck(is_equal_approx(float(ring.get_shader_parameter("brightness")), 1.2), "outline ring brightness set")
	ck(is_equal_approx(float(ring.get_shader_parameter("alpha")), 0.8), "outline ring alpha/band factor set")
	ck(is_equal_approx(float(ring.get_shader_parameter("grow")), 0.01), "outline ring grow set")
	ck(is_equal_approx(float(ring.get_shader_parameter("rim_power")), 1.4), "outline ring rim set")
	ck(is_equal_approx(float(ring.get_shader_parameter("cool")), 0.3), "outline ring cool set")
	o.clear(1)
	root.free()

func t_fill_single_body_no_ring() -> void:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	var o = Outline.new()
	o.apply(2, root, {"fill": true, "xray": false, "color": S.DEFAULT_DEFEND, "brightness": 1.0, "alpha": 0.4, "grow": 0.01, "cool": 0.2})
	var body: ShaderMaterial = o._items[2]["mat"]
	ck(body.shader == Sh.body_los(), "full-body uses body_los shader")
	ck(body.next_pass == null, "full-body has no ring next_pass")
	ck(body.get_shader_parameter("outline_color") == S.DEFAULT_DEFEND, "full-body sets display color")
	ck(is_equal_approx(float(body.get_shader_parameter("alpha")), 0.4), "full-body sets visible alpha")
	ck(is_equal_approx(float(body.get_shader_parameter("cool")), 0.2), "full-body sets cool")
	o.refresh(2, {"fill": true, "xray": false, "color": S.DEFAULT_NORMAL, "brightness": 0.9, "alpha": 0.6, "grow": 0.02, "cool": 0.5})
	ck(body.get_shader_parameter("outline_color") == S.DEFAULT_NORMAL, "full-body refresh updates color")
	ck(is_equal_approx(float(body.get_shader_parameter("alpha")), 0.6), "full-body refresh updates alpha")
	ck(is_equal_approx(float(body.get_shader_parameter("cool")), 0.5), "full-body refresh updates cool")
	o.clear(2)
	root.free()

func t_fill_has_no_ring_even_in_xray() -> void:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	var o = Outline.new()
	o.apply(10, root, {"cat": S.COMBAT, "fill": true, "xray": true, "color": S.DEFAULT_COMBAT, "alpha": 0.5, "grow": 0.01, "cool": 0.2, "brightness": 1.0})
	var body: ShaderMaterial = o._items[10]["mat"]
	ck(body.shader == Sh.body_xray(), "full-body xray uses body xray shader")
	ck(body.next_pass == null, "full-body xray has no ring")
	ck(body.get_shader_parameter("outline_color") == S.DEFAULT_COMBAT, "full-body xray sets display color")
	ck(is_equal_approx(float(body.get_shader_parameter("alpha")), 0.5), "full-body xray sets alpha")
	o.clear(10)
	root.free()

func t_outline_xray_preserves_shape() -> void:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	var o = Outline.new()
	o.apply(3, root, {"fill": false, "xray": true, "color": S.DEFAULT_NORMAL, "brightness": 1.0, "alpha": 0.7, "grow": 0.01, "rim": 2.0, "cool": 0.1})
	var body: ShaderMaterial = o._items[3]["mat"]
	var ring: ShaderMaterial = body.next_pass as ShaderMaterial
	ck(body.shader == Sh.body_xray(), "outline xray body uses body_xray shader")
	ck(ring != null and ring.shader == Sh.ring_xray(), "outline xray keeps ring_xray shape")
	ck(is_equal_approx(float(body.get_shader_parameter("alpha")), 0.0), "outline xray body remains mask-only")
	ck(is_equal_approx(float(ring.get_shader_parameter("alpha")), 0.7), "outline xray ring keeps alpha")
	ck(is_equal_approx(float(ring.get_shader_parameter("cool")), 0.1), "outline xray ring keeps cool")
	o.clear(3)
	root.free()

func t_toggle_xray_restores_los() -> void:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	var o = Outline.new()
	o.apply(4, root, {"fill": false, "xray": false, "color": S.DEFAULT_DEFEND, "brightness": 1.0, "alpha": 0.9, "grow": 0.01, "rim": 1.5, "cool": 0.0})
	var body: ShaderMaterial = o._items[4]["mat"]
	var ring: ShaderMaterial = body.next_pass as ShaderMaterial
	o.refresh(4, {"fill": false, "xray": true, "color": S.DEFAULT_DEFEND, "brightness": 1.0, "alpha": 0.9, "grow": 0.01, "rim": 1.5, "cool": 0.0})
	var xbody: ShaderMaterial = o._items[4]["mat"]
	ck(xbody.shader == Sh.body_xray(), "toggled xray uses body_xray")
	ck((xbody.next_pass as ShaderMaterial).shader == Sh.ring_xray(), "toggled xray keeps ring_xray")
	o.refresh(4, {"fill": false, "xray": false, "color": S.DEFAULT_DEFEND, "brightness": 1.0, "alpha": 0.9, "grow": 0.01, "rim": 1.5, "cool": 0.0})
	var lbody: ShaderMaterial = o._items[4]["mat"]
	ck(lbody.shader == Sh.body_los(), "xray off restores body_los")
	ck((lbody.next_pass as ShaderMaterial).shader == Sh.ring_los(), "xray off restores ring_los")
	o.clear(4)
	root.free()

func t_cool_reaches_materials() -> void:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	var o = Outline.new()
	o.apply(5, root, {"fill": false, "xray": false, "color": S.DEFAULT_COMBAT, "brightness": 1.0, "alpha": 1.0, "grow": 0.01, "rim": 1.0, "cool": 0.25})
	var body: ShaderMaterial = o._items[5]["mat"]
	var ring: ShaderMaterial = body.next_pass as ShaderMaterial
	ck(is_equal_approx(float(body.get_shader_parameter("cool")), 0.25), "cool reaches outline body")
	ck(is_equal_approx(float(ring.get_shader_parameter("cool")), 0.25), "cool reaches outline ring")
	o.refresh(5, {"fill": false, "xray": false, "color": S.DEFAULT_COMBAT, "brightness": 1.0, "alpha": 1.0, "grow": 0.01, "rim": 1.0, "cool": 0.6})
	ck(is_equal_approx(float(body.get_shader_parameter("cool")), 0.6), "cool refresh reaches outline body")
	ck(is_equal_approx(float(ring.get_shader_parameter("cool")), 0.6), "cool refresh reaches outline ring")
	o.refresh(5, {"fill": true, "xray": false, "color": S.DEFAULT_COMBAT, "brightness": 1.0, "alpha": 0.5, "grow": 0.01, "cool": 0.4})
	var fill: ShaderMaterial = o._items[5]["mat"]
	ck(is_equal_approx(float(fill.get_shader_parameter("cool")), 0.4), "cool reaches full-body material")
	o.clear(5)
	root.free()

func t_scope_rim_compat() -> void:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	var o = Outline.new()
	var opts := {"fill": false, "xray": false, "color": S.DEFAULT_NORMAL, "brightness": 1.0, "alpha": 1.0, "grow": 0.01, "rim": 2.0, "cool": 0.0}
	o.apply(7, root, opts)
	var ring: ShaderMaterial = (o._items[7]["mat"] as ShaderMaterial).next_pass as ShaderMaterial
	ck(is_equal_approx(float(ring.get_shader_parameter("rim_power")), 2.0), "ring uses rim outside scope")
	o.set_scoped(true)
	o.refresh(7, opts)
	ring = (o._items[7]["mat"] as ShaderMaterial).next_pass as ShaderMaterial
	ck(is_equal_approx(float(ring.get_shader_parameter("rim_power")), 6.0), "rim forced in scope")
	o.set_scoped(false)
	o.refresh(7, opts)
	ring = (o._items[7]["mat"] as ShaderMaterial).next_pass as ShaderMaterial
	ck(is_equal_approx(float(ring.get_shader_parameter("rim_power")), 2.0), "rim restored after scope")
	o.clear(7)
	root.free()

func t_scope_seed_on_late_apply() -> void:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	var o = Outline.new()
	o.set_scoped(true)
	o.apply(9, root, {"fill": false, "xray": false, "color": S.DEFAULT_NORMAL, "brightness": 1.0, "alpha": 1.0, "grow": 0.01, "cool": 0.0})
	var ring: ShaderMaterial = (o._items[9]["mat"] as ShaderMaterial).next_pass as ShaderMaterial
	ck(is_equal_approx(float(ring.get_shader_parameter("rim_power")), 6.0), "late apply picks up scoped rim")
	o.set_scoped(false)
	o.clear(9)
	root.free()

func t_overlay_on_mesh() -> void:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	var mm := MultiMeshInstance3D.new()
	root.add_child(mm)
	var o = Outline.new()
	o.apply(13, root, {"fill": false, "xray": false, "color": S.DEFAULT_NORMAL, "brightness": 1.0, "alpha": 1.0, "grow": 0.01, "cool": 0.0})
	var body: ShaderMaterial = o._items[13]["mat"]
	ck(mesh.material_overlay == body, "mesh carries contour as material_overlay")
	ck(mesh.material_override == null, "source material pipeline untouched")
	ck(mm.material_overlay == null, "non-mesh geometry gets no overlay")
	ck(body.next_pass != null, "outline entry has ring pass")
	o.clear(13)
	ck(mesh.material_overlay == null, "clear removes overlay")
	root.free()

func t_recollect_keeps_overlay() -> void:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	var o = Outline.new()
	o.apply(5, root, {"fill": false, "xray": false, "color": S.DEFAULT_NORMAL, "brightness": 1.0, "alpha": 1.0, "grow": 0.01, "cool": 0.0})
	var mat: ShaderMaterial = o._items[5]["mat"]
	root.add_child(Node3D.new())
	o.refresh(5, {"fill": false, "xray": false, "color": S.DEFAULT_NORMAL, "brightness": 1.0, "alpha": 1.0, "grow": 0.01, "cool": 0.0})
	ck(o._items[5]["meshes"].size() == 1, "mesh list unchanged for non-geometry child")
	var extra := MeshInstance3D.new()
	extra.mesh = QuadMesh.new()
	root.add_child(extra)
	o.refresh(5, {"fill": false, "xray": false, "color": S.DEFAULT_NORMAL, "brightness": 1.0, "alpha": 1.0, "grow": 0.01, "cool": 0.0})
	ck(o._items[5]["meshes"].size() == 2, "recollect picked up new mesh")
	ck(mesh.material_overlay == mat, "known mesh keeps overlay")
	ck(extra.material_overlay == mat, "new mesh got same overlay")
	var marker := MeshInstance3D.new()
	marker.set_meta(Outline.NO_CONTOUR_META, true)
	root.add_child(marker)
	ck(o._child_count(root) == 3, "mod geometry excluded from child count")
	o.clear(5)
	root.free()

func t_clear_not_in() -> void:
	var a := Node3D.new()
	a.add_child(MeshInstance3D.new())
	(a.get_child(0) as MeshInstance3D).mesh = BoxMesh.new()
	var b := Node3D.new()
	b.add_child(MeshInstance3D.new())
	(b.get_child(0) as MeshInstance3D).mesh = BoxMesh.new()
	var o = Outline.new()
	o.apply(1, a, {"fill": false, "color": S.DEFAULT_NORMAL})
	o.apply(2, b, {"fill": false, "color": S.DEFAULT_NORMAL})
	o.clear_not_in({1: true})
	ck(o.has(1), "kept id survives")
	ck(not o.has(2), "absent id is cleared")
	o.clear_not_in({})
	ck(not o.has(1), "empty keep clears everything")
	var c := Node3D.new()
	c.add_child(MeshInstance3D.new())
	(c.get_child(0) as MeshInstance3D).mesh = BoxMesh.new()
	o.apply(3, c, {"fill": false, "color": S.DEFAULT_NORMAL})
	o.clear_not_in({3: true})
	ck(o.has(3), "later clear leaves nothing stale behind")
	a.free()
	b.free()
	c.free()
