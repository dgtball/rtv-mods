extends SceneTree

const NVG = preload("res://mods/ThermalVTK/VTKNVG.gd")

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
	t_dirty_batches_setters()
	t_mine_retry_is_bounded()
	t_off_upkeep_clears_dead_mines()
	t_esp_compositor_gate()
	t_mine_color_stored_and_applied()
	t_mine_highlight_uses_buffer_shells()
	t_script_kind_cache()
	print("")
	if fails == 0:
		print("NVG tests passed")
		quit(0)
	else:
		print("NVG tests failed: ", fails)
		quit(1)

# The uniforms used to be pushed every 0.1 s whether anything changed or not.
# A setter only marks the material dirty; the next tick pushes once.
func t_dirty_batches_setters() -> void:
	var nvg = NVG.new()
	root.add_child(nvg)
	nvg.set_palette_mode(2)
	ck(nvg._dirty, "a setter marks the uniforms dirty")
	nvg._apply_uniforms()
	ck(not nvg._dirty, "a push clears the flag")
	nvg.set_thermal_enabled(true)
	ck(nvg._dirty, "thermal toggle marks dirty")
	nvg.free()

# A mine whose visual never appears used to be swept on every tick forever.
func t_mine_retry_is_bounded() -> void:
	var nvg = NVG.new()
	root.add_child(nvg)
	var mine := Node3D.new()
	root.add_child(mine)
	nvg._register_mine(mine)
	var id := mine.get_instance_id()
	ck(nvg._mine_watch.has(id), "a visual-less mine is parked")
	for i in NVG.MINE_RETRY_LIMIT:
		nvg._retry_mines()
	ck(not nvg._mine_watch.has(id), "the park is dropped after the retry limit")
	ck(not nvg._mines.has(id), "it never becomes a painted mine")
	nvg.free()
	mine.free()

func t_off_upkeep_clears_dead_mines() -> void:
	var nvg = NVG.new()
	root.add_child(nvg)
	var mine := Node3D.new()
	root.add_child(mine)
	nvg._mines[mine.get_instance_id()] = {"node": mine, "meshes": [], "shells": [], "painted": false}
	mine.free()
	nvg._off_frame_upkeep()
	ck(nvg._mines.is_empty(), "a freed mine is dropped while thermal is off")
	nvg._off_frame_upkeep()
	ck(nvg._mines.is_empty(), "the early return keeps the next pass cheap")
	nvg.free()

# DIAGNOSTIC 2.10.7 (preserved in 2.10.9 palette build): ESP buffer/compositor
# is force-disabled to isolate native crashes. Gating API still exists but must
# not activate compositing or buffer-driven camera exclusion.
func t_esp_compositor_gate() -> void:
	var nvg = NVG.new()
	root.add_child(nvg)
	ck(nvg.esp_buffer_layer() == 20, "ESP buffer reserves visual layer 20")
	var rect := ColorRect.new()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://mods/ThermalVTK/VTKNVG.gdshader")
	rect.material = mat
	root.add_child(rect)
	nvg._nvg_mat_node = rect
	nvg._installed = true
	nvg.set_esp_layer(true)
	ck(not nvg.esp_composite_active(), "diagnostic: layer armed without demand leaves compositing off")
	ck(mat.get_shader_parameter("espComposite") == false, "diagnostic: composite flag stays off without demand")
	nvg.set_esp_demand(true)
	ck(not nvg.esp_composite_active(), "diagnostic: demand does not enable compositing")
	ck(mat.get_shader_parameter("espComposite") == false, "diagnostic: overlay material keeps composite disabled")
	var cam: Camera3D = root.get_camera_3d()
	if cam != null:
		ck((cam.cull_mask & NVG.ESP_BUFFER_LAYER_BIT) != 0, "diagnostic: main camera layer 20 mask unchanged when compositor is disabled")
	nvg.set_esp_demand(false)
	ck(not nvg.esp_composite_active(), "diagnostic: demand off keeps compositing off")
	ck(mat.get_shader_parameter("espComposite") == false, "diagnostic: overlay material remains non-composite")
	nvg.set_esp_layer(false)
	ck(not nvg.esp_composite_active(), "diagnostic: layer off keeps compositing off")
	nvg._nvg_mat_node = null
	nvg._installed = false
	nvg.free()
	rect.free()

# Mine display colour is stored and applied to the shared mine shell material even
# before/after overlay install changes.
func t_mine_color_stored_and_applied() -> void:
	var nvg = NVG.new()
	root.add_child(nvg)
	nvg.set_mine_color(Color(0.2, 0.4, 0.9))
	ck(nvg.mine_color() == Color(0.2, 0.4, 0.9), "mine colour is stored")
	var sm := nvg._mat_mine as StandardMaterial3D
	ck(sm != null and sm.albedo_color == Color(0.2, 0.4, 0.9), "mine shell material uses mine colour")
	nvg.set_mine_color(Color(0.1, 0.8, 0.3))
	sm = nvg._mat_mine as StandardMaterial3D
	ck(nvg.mine_color() == Color(0.1, 0.8, 0.3), "mine colour updates")
	ck(sm != null and sm.albedo_color == Color(0.1, 0.8, 0.3), "mine shell material follows colour updates")
	nvg.free()

func t_mine_highlight_uses_buffer_shells() -> void:
	var nvg = NVG.new()
	root.add_child(nvg)
	nvg.set_mine_color(Color(0.2, 0.4, 0.9))
	nvg.set_mines = true
	nvg.set_thermal = true
	var mine := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mine.add_child(mesh)
	root.add_child(mine)
	mine.global_position = Vector3(2.0, 0.0, 0.0)
	nvg._register_mine(mine)
	var id := mine.get_instance_id()
	ck(nvg._mines.has(id), "mine registered")
	var entry: Dictionary = nvg._mines.get(id, {})
	var shells: Array = entry.get("shells", [])
	ck(shells.size() == 1, "mine buffer shell is created for source mesh")
	var shell: MeshInstance3D = shells[0] if shells.size() == 1 else null
	nvg._update_mine(id, true, Vector3.ZERO)
	ck(mesh.material_override == null, "in-range mine leaves source mesh without override")
	ck(shell != null and is_instance_valid(shell) and shell.visible, "in-range mine shows buffer shell")
	ck(shell != null and shell.layers == NVG.ESP_BUFFER_LAYER_BIT, "mine shell renders on ESP buffer layer")
	ck(shell != null and bool(shell.get_meta(NVG.MINE_SHELL_META, false)), "mine shell is tagged for mine buffer rendering")
	ck(shell != null and shell.material_override == nvg._mat_mine, "mine shell uses direct mine display material")
	nvg._update_mine(id, true, Vector3(1000.0, 0.0, 0.0))
	ck(mesh.material_override == null, "out-of-range mine keeps source mesh clear")
	ck(shell != null and is_instance_valid(shell) and not shell.visible, "out-of-range mine hides buffer shell")
	nvg._update_mine(id, true, Vector3.ZERO)
	ck(mesh.material_override == null, "mine re-entry does not touch source mesh override")
	ck(shell != null and is_instance_valid(shell) and shell.visible, "mine repaints buffer shell on re-entry")
	nvg.free()
	mine.free()

# The script verdict is cached per script, not per node: the map load queues
# thousands of nodes from the same few scripts.
func t_script_kind_cache() -> void:
	var nvg = NVG.new()
	root.add_child(nvg)
	var script := GDScript.new()
	script.resource_path = "res://Scripts/NVG.gd"
	script.source_code = "extends Node\nfunc _ready(): pass"
	script.reload()
	var a := Node.new()
	var b := Node.new()
	a.set_script(script)
	b.set_script(script)
	ck(nvg._script_kind_for(a) == 1, "an NVG script reads as NVG")
	ck(nvg._script_kind_for(b) == 1, "the second node reuses the verdict")
	ck(nvg._script_kind_for(Node.new()) == 0, "a scriptless node reads as foreign")
	ck(nvg._script_kind.size() == 1, "only the resolved script is cached; a null script short-circuits")
	nvg.free()
	a.free()
	b.free()
