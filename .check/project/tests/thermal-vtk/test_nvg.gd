extends SceneTree

const NVG = preload("res://mods/ThermalVTK/VTKNVG.gd")
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
	t_dirty_batches_setters()
	t_mine_retry_is_bounded()
	t_off_upkeep_clears_dead_mines()
	t_esp_compositor_gate()
	t_mine_colour_and_keys_reach_material()
	t_mine_highlight_emits_key_material()
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
	nvg.set_state_colors({"state_normal": Color.RED})
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
	nvg._mines[mine.get_instance_id()] = {"node": mine, "meshes": []}
	mine.free()
	nvg._off_frame_upkeep()
	ck(nvg._mines.is_empty(), "a freed mine is dropped while thermal is off")
	nvg._off_frame_upkeep()
	ck(nvg._mines.is_empty(), "the early return keeps the next pass cheap")
	nvg.free()

# The ESP buffer compositor is gated like the old substitution demand: the
# layer switch arms it, per-frame demand enables it, and either going off must
# clear the composite flag so no stale buffer frame lingers.
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
	# Transitional: substitution demand (espOn) still follows the same gate.
	nvg.set_esp_layer(true)
	ck(mat.get_shader_parameter("espOn") == false, "layers armed without demand leave the substitution off")
	ck(not nvg.esp_composite_active(), "demand gates compositing")
	ck(mat.get_shader_parameter("espComposite") == false, "composite flag stays off without demand")
	nvg.set_esp_demand(true)
	ck(nvg.esp_composite_active(), "demand enables compositing")
	ck(mat.get_shader_parameter("espOn") == true, "demand enables substitution (transitional)")
	ck(mat.get_shader_parameter("espComposite") == true, "overlay material receives composite enable")
	ck(mat.get_shader_parameter("espTex") != null, "overlay material receives ESP buffer texture")
	var cam: Camera3D = root.get_camera_3d()
	if cam != null:
		ck((cam.cull_mask & NVG.ESP_BUFFER_LAYER_BIT) == 0, "main camera excludes layer 20 while compositing")
	nvg.set_esp_demand(false)
	ck(not nvg.esp_composite_active(), "demand off stops compositing")
	ck(mat.get_shader_parameter("espComposite") == false, "overlay material clears composite flag on demand off")
	ck(mat.get_shader_parameter("espOn") == false, "overlay material clears substitution on demand off")
	if cam != null:
		ck((cam.cull_mask & NVG.ESP_BUFFER_LAYER_BIT) != 0, "main camera layer 20 is restored when compositing stops")
	nvg.set_esp_layer(false)
	nvg._nvg_mat_node = null
	nvg._installed = false
	nvg.free()
	rect.free()

# The mine display colour and the measured detector targets live on the overlay
# material, and the overlay is rebuilt on every map load: a value set once must
# survive that rebuild.
func t_mine_colour_and_keys_reach_material() -> void:
	var nvg = NVG.new()
	root.add_child(nvg)
	nvg.set_mine_color(Color(0.2, 0.4, 0.9))
	ck(nvg.mine_color() == Color(0.2, 0.4, 0.9), "mine colour is stored without a material")
	var rect := ColorRect.new()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://mods/ThermalVTK/VTKNVG.gdshader")
	rect.material = mat
	nvg._nvg_mat_node = rect
	nvg._installed = true
	nvg._apply_uniforms()
	ck(mat.get_shader_parameter("mineColor") == Color(0.2, 0.4, 0.9), "mine colour reaches the overlay material")
	ck(mat.get_shader_parameter("stNormalKey") == NVG.DET_ST_NORMAL, "the washed normal key reaches the overlay material")
	ck(mat.get_shader_parameter("stCombatKey") == NVG.DET_ST_COMBAT, "the washed combat key reaches the overlay material")
	ck(mat.get_shader_parameter("stDefendKey") == NVG.DET_ST_DEFEND, "the washed defend key reaches the overlay material")
	ck(mat.get_shader_parameter("mineKey") == NVG.DET_MINE, "the washed mine key reaches the overlay material")
	nvg._nvg_mat_node = null
	rect.free()
	nvg.free()

func t_mine_highlight_emits_key_material() -> void:
	var nvg = NVG.new()
	root.add_child(nvg)
	nvg.set_mines = true
	nvg.set_thermal = true
	var mine := Node3D.new()
	mine.global_position = Vector3(2.0, 0.0, 0.0)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mine.add_child(mesh)
	root.add_child(mine)
	nvg._register_mine(mine)
	var id := mine.get_instance_id()
	ck(nvg._mines.has(id), "mine registered")
	nvg._update_mine(id, true, Vector3.ZERO)
	ck(mesh.material_override == nvg._mat_mine, "in-range mine gets key override material")
	ck(nvg._mat_mine.albedo_color == NVG.MINE_KEY, "mine material emits detection key")
	nvg._update_mine(id, true, Vector3(1000.0, 0.0, 0.0))
	ck(mesh.material_override == null, "out-of-range mine clears")
	nvg._update_mine(id, true, Vector3.ZERO)
	ck(mesh.material_override == nvg._mat_mine, "mine repaints on re-entry")
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
