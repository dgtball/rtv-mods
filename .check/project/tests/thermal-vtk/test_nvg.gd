extends SceneTree

const NVG = preload("res://mods/ThermalVTK/VTKNVG.gd")
const Buf = preload("res://mods/ThermalVTK/VTKESPBuffer.gd")

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
	t_mine_color_stored_and_applied()
	t_mine_highlight_uses_main_view_shells()
	t_script_kind_cache()
	t_esp_buffer_lifecycle()
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
	nvg._mines[mine.get_instance_id()] = {"node": mine, "meshes": [], "painted": false}
	mine.free()
	nvg._off_frame_upkeep()
	ck(nvg._mines.is_empty(), "a freed mine is dropped while thermal is off")
	nvg._off_frame_upkeep()
	ck(nvg._mines.is_empty(), "the early return keeps the next pass cheap")
	nvg.free()

# Mine display colour is stored and applied to the shared mine display material.
func t_mine_color_stored_and_applied() -> void:
	var nvg = NVG.new()
	root.add_child(nvg)
	nvg.set_mine_color(Color(0.2, 0.4, 0.9))
	ck(nvg.mine_color() == Color(0.2, 0.4, 0.9), "mine colour is stored")
	var sm := nvg._mat_mine as StandardMaterial3D
	ck(sm != null and sm.albedo_color == Color(0.2, 0.4, 0.9), "mine display material uses mine colour")
	nvg.set_mine_color(Color(0.1, 0.8, 0.3))
	sm = nvg._mat_mine as StandardMaterial3D
	ck(nvg.mine_color() == Color(0.1, 0.8, 0.3), "mine colour updates")
	ck(sm != null and sm.albedo_color == Color(0.1, 0.8, 0.3), "mine display material follows colour updates")
	nvg.free()

# Mines are highlighted in the main view while thermal is on and NVG is worn;
# source meshes get a material overlay (no extra shell nodes).
func t_mine_highlight_uses_main_view_shells() -> void:
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
	ck(not entry.has("shells"), "mine entry has no shell nodes")
	var child_count := mine.get_child_count()
	nvg._update_mine(id, true, Vector3.ZERO)
	ck(mesh.material_override == null, "in-range mine leaves source mesh without override")
	ck(mesh.material_overlay == nvg._mat_mine, "in-range mine paints source mesh with overlay material")
	ck(mine.get_child_count() == child_count, "in-range mine does not add extra nodes")
	nvg._update_mine(id, true, Vector3(1000.0, 0.0, 0.0))
	ck(mesh.material_overlay == null, "out-of-range mine clears overlay")
	nvg._update_mine(id, true, Vector3.ZERO)
	ck(mesh.material_overlay == nvg._mat_mine, "mine repaints overlay on re-entry")
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

func t_esp_buffer_lifecycle() -> void:
	var nvg = NVG.new()
	root.add_child(nvg)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	var before := cam.cull_mask
	ck(nvg.esp_buffer_viewport() == null, "buffer is lazy")
	nvg._sync_esp_buffer(true)
	var vp: SubViewport = nvg.esp_buffer_viewport()
	ck(vp != null and vp.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "active buffer renders")
	ck(vp.size == root.size, "buffer matches screen")
	ck(nvg._esp_cam.cull_mask == Buf.LAYER_BIT, "buffer camera sees only the ESP layer")
	ck(cam.cull_mask == (before & ~Buf.LAYER_BIT), "main camera excludes the ESP layer")
	nvg._sync_esp_buffer(false)
	ck(vp.render_target_update_mode == SubViewport.UPDATE_DISABLED, "inactive buffer costs nothing")
	ck(cam.cull_mask == before, "main camera mask restored")
