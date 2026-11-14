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
	t_esp_demand_gate()
	t_mine_colour_and_keys_reach_material()
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

# The substitution reads the frame itself, so there is no second pass to arm:
# the layer switch plus the per-frame demand decide whether the shader samples
# the screen, and either one going off must clear the uniform right away
# instead of freezing on the last frame.
func t_esp_demand_gate() -> void:
	var nvg = NVG.new()
	root.add_child(nvg)
	var rect := ColorRect.new()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://mods/ThermalVTK/VTKNVG.gdshader")
	rect.material = mat
	nvg._nvg_mat_node = rect
	nvg.set_esp_layer(true)
	ck(mat.get_shader_parameter("espOn") == false, "layers armed without demand leave the substitution off")
	ck(not nvg._esp_render_on(), "the render switch follows the demand")
	nvg.set_esp_demand(true)
	ck(nvg._esp_render_on(), "demand turns the substitution on")
	ck(mat.get_shader_parameter("espOn") == true, "the overlay material sees the demand")
	nvg.set_esp_demand(false)
	ck(not nvg._esp_render_on(), "demand off stops the substitution")
	ck(mat.get_shader_parameter("espOn") == false, "the overlay material is cleared on demand off")
	nvg.set_esp_layer(false)
	nvg._nvg_mat_node = null
	rect.free()
	nvg.free()

# The mine display colour and the measured detector targets live on the overlay
# material, and the overlay is rebuilt on every map load: a value set once must
# survive that rebuild, which is why the setter stores it and _apply_uniforms
# re-pushes it. Checked against a real ShaderMaterial so a renamed uniform
# cannot pass silently.
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

# The script verdict is cached per script, not per node: the map load queues
# thousands of nodes from the same few scripts.
func t_script_kind_cache() -> void:
	var nvg = NVG.new()
	root.add_child(nvg)
	var script := GDScript.new()
	script.resource_path = "res://Scripts/NVG.gd"
	script.source_code = "extends Node
func _ready(): pass"
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