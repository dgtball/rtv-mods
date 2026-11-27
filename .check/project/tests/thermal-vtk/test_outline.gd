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
	t_overlay_outline_chain_and_uniforms()
	t_ring_band_widens_grow()
	t_wide_band_leaves_body_at_thickness()
	t_material_info()
	t_material_info_reads_real_overlay()
	t_overlay_outline_ignores_stale_fill_flag()
	t_overlay_xray_preserves_shape()
	t_toggle_xray_restores_los()
	t_scope_bypass_swaps_and_restores_pair()
	t_recollect_keeps_scope_bypass()
	t_xray_flag_independent_from_depth_bypass()
	t_overlay_on_mesh()
	t_recollect_keeps_overlay()
	t_recollect_detects_deep_mesh_replacement()
	t_recollect_clears_detached_mesh_overlay()
	t_clear_not_in()
	t_draw_priorities()
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
	ck(out.size() == 2, "all GeometryInstance3D nodes collected: %d" % out.size())
	ck(out.has(mesh), "an invisible LOD still gets the overlay")
	ck(out.has(mm), "a MultiMeshInstance3D is a valid overlay target")
	ck(not out.has(plain), "non-geometry nodes are not collected")
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

func t_overlay_outline_chain_and_uniforms() -> void:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	var o = Outline.new()
	o.apply(1, root, {"xray": false, "color": S.DEFAULT_COMBAT, "brightness": 1.2, "fill_alpha": 0.8, "grow": 0.01, "cool": 0.3, "rim": 1.4})
	var body: ShaderMaterial = o._items[1]["mat"]
	var ring: ShaderMaterial = body.next_pass as ShaderMaterial
	ck(mesh.material_overlay == body, "outline applies body overlay to mesh")
	ck(body.shader == Sh.body_los(), "outline body uses body_los shader")
	ck(ring != null and ring.shader == Sh.ring_los(), "outline body has ring_los next_pass")
	ck(is_equal_approx(float(body.get_shader_parameter("alpha")), 0.8), "outline body carries the fill alpha")
	ck(body.render_priority == 20, "outline body draws above the palette quad")
	ck(ring.render_priority == 21, "outline ring draws above the body")
	ck(body.get_shader_parameter("outline_color") == S.DEFAULT_COMBAT, "outline body carries display color")
	ck(is_equal_approx(float(body.get_shader_parameter("brightness")), 1.2), "outline body brightness set")
	ck(is_equal_approx(float(body.get_shader_parameter("grow")), 0.01), "outline body grow set")
	ck(is_equal_approx(float(body.get_shader_parameter("cool")), 0.3), "outline body cool set")
	ck(ring.get_shader_parameter("outline_color") == S.DEFAULT_COMBAT, "outline ring carries display color")
	ck(is_equal_approx(float(ring.get_shader_parameter("brightness")), 1.2), "outline ring brightness set")
	ck(is_equal_approx(float(ring.get_shader_parameter("alpha")), 0.8), "outline ring alpha set")
	ck(is_equal_approx(float(ring.get_shader_parameter("grow")), 0.01), "outline ring grow set")
	ck(is_equal_approx(float(ring.get_shader_parameter("rim_power")), 1.4), "outline ring rim set")
	ck(body.get_shader_parameter("rim_power") == 1.4, "outline body fill uses the same rim falloff")
	ck(is_equal_approx(float(ring.get_shader_parameter("cool")), 0.3), "outline ring cool set")
	o.clear(1)
	root.free()

func t_ring_band_widens_grow() -> void:
	var root_node := Node3D.new()
	root.add_child(root_node)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root_node.add_child(mesh)
	var o = Outline.new()
	var opts := {"xray": false, "color": S.DEFAULT_NORMAL, "brightness": 1.0, "fill_alpha": 0.6, "grow": 0.01, "band": 0.025, "cool": 0.0}
	o.apply(21, root_node, opts)
	var body: ShaderMaterial = o._items[21]["mat"]
	var ring: ShaderMaterial = body.next_pass as ShaderMaterial
	ck(is_equal_approx(float(body.get_shader_parameter("grow")), 0.01), "body uses only the configured thickness")
	ck(is_equal_approx(float(ring.get_shader_parameter("grow")), 0.035), "ring inflates by thickness plus band")
	o.refresh(21, {"xray": false, "color": S.DEFAULT_NORMAL, "brightness": 1.0, "fill_alpha": 0.6, "grow": 0.01, "band": 0.05, "cool": 0.0})
	ck(is_equal_approx(float(body.get_shader_parameter("grow")), 0.01), "band-only change leaves body thickness alone")
	ck(is_equal_approx(float(ring.get_shader_parameter("grow")), 0.06), "band-only change updates ring grow")
	o.refresh(21, {"xray": false, "color": S.DEFAULT_NORMAL, "brightness": 1.0, "fill_alpha": 0.6, "grow": 0.03, "band": 0.01, "cool": 0.0})
	ck(is_equal_approx(float(body.get_shader_parameter("grow")), 0.03), "configured grow wins over thinner band on mask")
	ck(is_equal_approx(float(ring.get_shader_parameter("grow")), 0.04), "ring keeps visible band width")
	o.refresh(21, {"xray": false, "color": S.DEFAULT_NORMAL, "brightness": 1.0, "fill_alpha": 0.6, "grow": 0.01, "band": 0.0, "cool": 0.0})
	ck(is_equal_approx(float(body.get_shader_parameter("grow")), 0.01), "zero band leaves mask at grow")
	ck(is_equal_approx(float(ring.get_shader_parameter("grow")), 0.01), "zero band collapses ring offset to grow")
	o.clear(21)
	root_node.free()

# The band scales with distance to stay screen-sized. With the stencil mask
# gone it belongs entirely to the ring; the body keeps its configured thickness.
func t_wide_band_leaves_body_at_thickness() -> void:
	var root_node := Node3D.new()
	root.add_child(root_node)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root_node.add_child(mesh)
	var o = Outline.new()
	o.apply(70, root_node, {"xray": false, "color": S.DEFAULT_NORMAL, "brightness": 1.0, "fill_alpha": 0.6, "grow": 0.0005, "band": 0.4, "cool": 0.0})
	var body: ShaderMaterial = o._items[70]["mat"]
	var ring: ShaderMaterial = body.next_pass as ShaderMaterial
	ck(is_equal_approx(float(body.get_shader_parameter("grow")), 0.0005), "a wide band leaves the body at its configured thickness")
	ck(is_equal_approx(float(ring.get_shader_parameter("grow")), 0.4005), "the ring keeps the full band as its visible width")
	o.clear(70)
	root_node.free()

# The per-frame subject log must read what the shaders actually hold, not what
# the opts asked for — material_info is that read-out (real uniforms, shader
# names, ring presence), empty for an unknown id.
func t_material_info() -> void:
	var host := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	host.add_child(mesh)
	var o = Outline.new()
	ck(o.material_info(90).is_empty(), "an unknown id reports no material info")
	o.apply(90, host, {"xray": false, "color": S.DEFAULT_NORMAL, "brightness": 1.0, "fill_alpha": 0.6, "grow": 0.01, "band": 0.025, "cool": 0.0})
	var info: Dictionary = o.material_info(90)
	ck(bool(info.get("has_ring", false)), "outline mode reports the ring pass")
	ck(not info.has("fill_mode"), "no fill mode is reported")
	ck(is_equal_approx(float(info.get("body_grow", -1.0)), 0.01), "info reads the body grow uniform")
	ck(is_equal_approx(float(info.get("ring_grow", -1.0)), 0.035), "info reads the ring grow uniform")
	ck(is_equal_approx(float(info.get("body_alpha", -1.0)), 0.6), "info reads the fill body alpha")
	ck(is_equal_approx(float(info.get("ring_alpha", -1.0)), 0.6), "info reads the ring alpha uniform")
	ck(str(info.get("body_shader", "")) == "VTKEspBody.gdshader", "info names the body shader")
	ck(str(info.get("ring_shader", "")) == "VTKEspRing.gdshader", "info names the ring shader")
	ck(int(info.get("meshes", -1)) == 1, "info counts the tracked meshes")
	ck(is_equal_approx(float(info.get("brightness", -1.0)), 1.0), "info reads the brightness uniform")
	ck(is_equal_approx(float(info.get("cool", -1.0)), 0.0), "info reads the cool uniform")
	ck(is_equal_approx(float(info.get("rim", -1.0)), 2.0), "info reads the rim power uniform")
	ck(info.get("color") == S.DEFAULT_NORMAL, "info reads the display colour")
	ck(int(info.get("overlay_ok", -1)) == 1, "info counts the meshes carrying our material")
	ck(int(info.get("overlay_lost", -1)) == 0, "info counts no lost overlay after a fresh apply")
	ck(int(info.get("overlay_other", -1)) == 0, "info counts no foreign overlay after a fresh apply")
	ck(int(info.get("mat_gen", -1)) == 1, "the first material is generation one")
	o.clear(90)
	host.free()

# The overlay read-out answers "what is actually on the meshes": the entry
# can still describe a perfect contour while a rebuild left a foreign
# material or nothing at all on the GeometryInstance3D. The subject log must
# see that gap, or it would report the ideal while the screen shows none.
func t_material_info_reads_real_overlay() -> void:
	var host := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	host.add_child(mesh)
	var o = Outline.new()
	o.apply(92, host, {"xray": false, "color": S.DEFAULT_NORMAL, "brightness": 1.0, "fill_alpha": 0.6, "grow": 0.01, "band": 0.025, "cool": 0.0})
	var info: Dictionary = o.material_info(92)
	ck(int(info.get("overlay_ok", -1)) == 1, "a fresh apply puts our material on every mesh")
	ck(int(info.get("overlay_lost", -1)) == 0, "a fresh apply loses nothing")
	ck(int(info.get("overlay_other", -1)) == 0, "a fresh apply has no foreign overlay")

	# A foreign material sits on the mesh: the entry stays perfect, the screen
	# does not — only the real-overlay read-out can tell them apart.
	mesh.material_overlay = ShaderMaterial.new()
	info = o.material_info(92)
	ck(int(info.get("overlay_ok", -1)) == 0, "a foreign overlay is not counted as ours")
	ck(int(info.get("overlay_other", -1)) == 1, "a foreign overlay is reported as other")
	ck(int(info.get("overlay_lost", -1)) == 0, "a foreign overlay is not lost")
	ck(bool(info.get("has_ring", false)), "the entry still reports its ring")

	# Overlay wiped entirely (recollect miss, node rebuild).
	mesh.material_overlay = null
	info = o.material_info(92)
	ck(int(info.get("overlay_lost", -1)) == 1, "a wiped overlay is reported as lost")
	ck(int(info.get("overlay_ok", -1)) == 0, "a wiped overlay is not ours")

	# Regenerating the material bumps the generation and re-arms the meshes.
	o.apply(92, host, {"xray": true, "color": S.DEFAULT_NORMAL, "brightness": 1.0, "fill_alpha": 0.6, "grow": 0.01, "band": 0.025, "cool": 0.0})
	info = o.material_info(92)
	ck(int(info.get("mat_gen", -1)) == 2, "swapping the material bumps the generation")
	ck(info.has("ring_grow") and info.has("ring_alpha"), "the outline always reports ring uniforms")
	ck(str(info.get("body_shader", "")) == "VTKEspBodyXray.gdshader", "the swapped shader is reported")
	ck(int(info.get("overlay_ok", -1)) == 1, "the regenerated material is back on the mesh")
	o.clear(92)
	host.free()

# Third-party code may still hand over the old opts key. The contour must
# ignore it: one body+ring chain, fresnel on the body, fill alpha on the ring.
func t_overlay_outline_ignores_stale_fill_flag() -> void:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	var o = Outline.new()
	o.apply(2, root, {"fill": true, "xray": false, "color": S.DEFAULT_DEFEND, "brightness": 1.0, "fill_alpha": 0.4, "grow": 0.01, "cool": 0.2})
	var body: ShaderMaterial = o._items[2]["mat"]
	var ring := body.next_pass as ShaderMaterial
	ck(ring != null, "a stale fill flag cannot remove the ring pass")
	ck(float(body.get_shader_parameter("rim_power")) > 0.0, "the body keeps the outline fresnel")
	ck(is_equal_approx(float(ring.get_shader_parameter("alpha")), 0.4), "the ring carries fill alpha")
	o.clear(2)
	root.free()

func t_overlay_xray_preserves_shape() -> void:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	var o = Outline.new()
	o.apply(3, root, {"xray": true, "color": S.DEFAULT_NORMAL, "brightness": 1.0, "fill_alpha": 0.7, "grow": 0.01, "rim": 2.0, "cool": 0.1})
	var body: ShaderMaterial = o._items[3]["mat"]
	var ring: ShaderMaterial = body.next_pass as ShaderMaterial
	ck(body.shader == Sh.body_xray(), "outline xray body uses body_xray shader")
	ck(ring != null and ring.shader == Sh.ring_xray(), "outline xray keeps ring_xray shape")
	ck(is_equal_approx(float(body.get_shader_parameter("alpha")), 0.7), "outline xray body carries the fill alpha")
	ck(body.get_shader_parameter("rim_power") == 2.0, "outline xray body keeps rim falloff")
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
	o.apply(4, root, {"xray": false, "color": S.DEFAULT_DEFEND, "brightness": 1.0, "fill_alpha": 0.9, "grow": 0.01, "rim": 1.5, "cool": 0.0})
	o.refresh(4, {"xray": true, "color": S.DEFAULT_DEFEND, "brightness": 1.0, "fill_alpha": 0.9, "grow": 0.01, "rim": 1.5, "cool": 0.0})
	var xbody: ShaderMaterial = o._items[4]["mat"]
	ck(xbody.shader == Sh.body_xray(), "toggled xray uses body_xray")
	ck((xbody.next_pass as ShaderMaterial).shader == Sh.ring_xray(), "toggled xray keeps ring_xray")
	o.refresh(4, {"xray": false, "color": S.DEFAULT_DEFEND, "brightness": 1.0, "fill_alpha": 0.9, "grow": 0.01, "rim": 1.5, "cool": 0.0})
	var lbody: ShaderMaterial = o._items[4]["mat"]
	ck(lbody.shader == Sh.body_los(), "xray off restores body_los")
	ck((lbody.next_pass as ShaderMaterial).shader == Sh.ring_los(), "xray off restores ring_los")
	o.clear(4)
	root.free()

func scope_opts(depth_bypass: bool, xray: bool = false) -> Dictionary:
	return {"xray": xray, "depth_bypass": depth_bypass, "color": S.DEFAULT_NORMAL,
		"brightness": 1.0, "fill_alpha": 0.4, "grow": 0.01, "band": 0.0, "cool": 0.0, "rim": 2.0}

# In an optic without PIP the body and ring must both ignore the vanilla
# depth barrier; leaving the scope restores the ordinary pair on the same mesh.
func t_scope_bypass_swaps_and_restores_pair() -> void:
	var host := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	host.add_child(mesh)
	var o = Outline.new()
	o.apply(401, host, scope_opts(true))
	var body: ShaderMaterial = o._items[401]["mat"]
	ck(body.shader == Sh.body_xray(), "scope without PIP uses the depth-test-disabled body")
	ck((body.next_pass as ShaderMaterial).shader == Sh.ring_xray(), "scope without PIP uses the xray ring")
	o.refresh(401, scope_opts(false))
	var back: ShaderMaterial = o._items[401]["mat"]
	ck(back.shader == Sh.body_los(), "leaving the scope restores the LOS body")
	ck((back.next_pass as ShaderMaterial).shader == Sh.ring_los(), "leaving the scope restores the LOS ring")
	ck(mesh.material_overlay == back, "the restored material is back on the mesh")
	o.clear(401)
	host.free()

# Bots can gain a mesh mid-scope: the depth mode must survive that recollection
# instead of falling back to LOS on the newly drawn part.
func t_recollect_keeps_scope_bypass() -> void:
	var host := Node3D.new()
	host.add_child(MeshInstance3D.new())
	var o = Outline.new()
	o.apply(402, host, scope_opts(true))
	var mat: ShaderMaterial = o._items[402]["mat"]
	var extra := MeshInstance3D.new()
	extra.mesh = BoxMesh.new()
	host.add_child(extra)
	o.refresh(402, scope_opts(true))
	ck(o._items[402]["mat"] == mat, "recollect does not swap the scope material")
	ck(o._items[402]["meshes"].size() == 2, "recollect picked up the new mesh")
	ck(extra.material_overlay == mat, "the new mesh gets the same xray material")
	o.clear(402)
	host.free()

func t_xray_flag_independent_from_depth_bypass() -> void:
	var host := Node3D.new()
	var o = Outline.new()
	o.apply(403, host, scope_opts(false, true))
	ck(o._items[403]["mat"].shader == Sh.body_xray(), "the x-ray trigger alone still uses xray")
	o.refresh(403, scope_opts(true, false))
	ck(o._items[403]["mat"].shader == Sh.body_xray(), "depth bypass alone uses xray")
	o.refresh(403, scope_opts(false, false))
	ck(o._items[403]["mat"].shader == Sh.body_los(), "both flags off restores LOS")
	o.clear(403)
	host.free()

func t_overlay_on_mesh() -> void:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	var mm := MultiMeshInstance3D.new()
	root.add_child(mm)
	var o = Outline.new()
	o.apply(13, root, {"xray": false, "color": S.DEFAULT_NORMAL, "brightness": 1.0, "fill_alpha": 1.0, "grow": 0.01, "cool": 0.0})
	var body: ShaderMaterial = o._items[13]["mat"]
	ck(mesh.material_overlay == body, "mesh carries contour as material_overlay")
	ck(mesh.material_override == null, "source material pipeline untouched")
	ck(mm.material_overlay == body, "all geometry gets the overlay")
	ck(body.next_pass != null, "outline entry has ring pass")
	o.clear(13)
	ck(mesh.material_overlay == null, "clear removes overlay")
	ck(mm.material_overlay == null, "clear removes overlay from all geometry")
	root.free()

func t_recollect_keeps_overlay() -> void:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	var o = Outline.new()
	o.apply(5, root, {"xray": false, "color": S.DEFAULT_NORMAL, "brightness": 1.0, "fill_alpha": 1.0, "grow": 0.01, "cool": 0.0})
	var mat: ShaderMaterial = o._items[5]["mat"]
	root.add_child(Node3D.new())
	o.refresh(5, {"xray": false, "color": S.DEFAULT_NORMAL, "brightness": 1.0, "fill_alpha": 1.0, "grow": 0.01, "cool": 0.0})
	ck(o._items[5]["meshes"].size() == 1, "mesh list unchanged for non-geometry child")
	var extra := MeshInstance3D.new()
	extra.mesh = QuadMesh.new()
	root.add_child(extra)
	o.refresh(5, {"xray": false, "color": S.DEFAULT_NORMAL, "brightness": 1.0, "fill_alpha": 1.0, "grow": 0.01, "cool": 0.0})
	ck(o._items[5]["meshes"].size() == 2, "recollect picked up new mesh")
	ck(mesh.material_overlay == mat, "known mesh keeps overlay")
	ck(extra.material_overlay == mat, "new mesh got same overlay")
	var marker := MeshInstance3D.new()
	marker.set_meta(Outline.NO_CONTOUR_META, true)
	root.add_child(marker)
	ck(o._child_count(root) == 3, "mod geometry excluded from child count")
	o.clear(5)
	root.free()

# Deep mesh replacement: direct child count stays the same but a nested mesh
# instance is replaced; refresh must detect the new mesh set and apply overlay.
func t_recollect_detects_deep_mesh_replacement() -> void:
	var root := Node3D.new()
	var holder := Node3D.new()
	root.add_child(holder)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	holder.add_child(mesh)
	var o = Outline.new()
	o.apply(50, root, {"xray": false, "color": S.DEFAULT_NORMAL, "brightness": 1.0, "fill_alpha": 1.0, "grow": 0.01, "cool": 0.0})
	var mat: ShaderMaterial = o._items[50]["mat"]
	ck(mesh.material_overlay == mat, "deep mesh initially outlined")
	var repl := MeshInstance3D.new()
	repl.mesh = QuadMesh.new()
	holder.remove_child(mesh)
	holder.add_child(repl)
	mesh.free()
	# Same root direct child count (holder still there), but tracked mesh changed.
	o.refresh(50, {"xray": false, "color": S.DEFAULT_NORMAL, "brightness": 1.0, "fill_alpha": 1.0, "grow": 0.01, "cool": 0.0})
	ck(o._items[50]["meshes"].size() == 1, "recollect keeps one tracked mesh after deep replacement")
	ck(o._items[50]["meshes"][0] == repl, "recollect tracks the replaced mesh instance")
	ck(repl.material_overlay == mat, "replaced mesh receives overlay")
	o.clear(50)
	root.free()

# A mesh removed from the tracked subtree (still valid elsewhere) must lose its
# overlay on recollect so outlines do not stick to detached meshes.
func t_recollect_clears_detached_mesh_overlay() -> void:
	var root := Node3D.new()
	var holder := Node3D.new()
	root.add_child(holder)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	holder.add_child(mesh)
	var detached_root := Node3D.new()
	var o = Outline.new()
	o.apply(51, root, {"xray": false, "color": S.DEFAULT_NORMAL, "brightness": 1.0, "fill_alpha": 1.0, "grow": 0.01, "cool": 0.0})
	var mat: ShaderMaterial = o._items[51]["mat"]
	ck(mesh.material_overlay == mat, "tracked mesh outlined before detach")
	holder.remove_child(mesh)
	detached_root.add_child(mesh)
	o.refresh(51, {"xray": false, "color": S.DEFAULT_NORMAL, "brightness": 1.0, "fill_alpha": 1.0, "grow": 0.01, "cool": 0.0})
	ck(o._items[51]["meshes"].is_empty(), "detached mesh no longer tracked")
	ck(mesh.material_overlay == null, "detached mesh overlay cleared on recollect")
	o.clear(51)
	detached_root.free()
	root.free()

func t_clear_not_in() -> void:
	var a := Node3D.new()
	a.add_child(MeshInstance3D.new())
	(a.get_child(0) as MeshInstance3D).mesh = BoxMesh.new()
	var b := Node3D.new()
	b.add_child(MeshInstance3D.new())
	(b.get_child(0) as MeshInstance3D).mesh = BoxMesh.new()
	var o = Outline.new()
	o.apply(1, a, {"color": S.DEFAULT_NORMAL})
	o.apply(2, b, {"color": S.DEFAULT_NORMAL})
	o.clear_not_in({1: true})
	ck(o.has(1), "kept id survives")
	ck(not o.has(2), "absent id is cleared")
	o.clear_not_in({})
	ck(not o.has(1), "empty keep clears everything")
	var c := Node3D.new()
	c.add_child(MeshInstance3D.new())
	(c.get_child(0) as MeshInstance3D).mesh = BoxMesh.new()
	o.apply(3, c, {"color": S.DEFAULT_NORMAL})
	o.clear_not_in({3: true})
	ck(o.has(3), "later clear leaves nothing stale behind")
	a.free()
	b.free()
	c.free()

func t_draw_priorities() -> void:
	var src := FileAccess.get_file_as_string("res://mods/ThermalVTK/VTKOutline.gd")
	ck(src.contains("body_mat.render_priority = 20"), "contour body draws above the palette")
	ck(src.contains("ring_mat.render_priority = 21"), "contour ring draws above the body")
	ck(not src.contains("render_priority = -128"), "no stale palette-floor priority in outline")
