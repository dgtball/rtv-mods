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
	t_mine_direct_material_gating()
	t_mine_material_clears_on_free()
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
	nvg._mines[mine.get_instance_id()] = {"node": mine, "meshes": []}
	mine.free()
	nvg._off_frame_upkeep()
	ck(nvg._mines.is_empty(), "a freed mine is dropped while thermal is off")
	nvg._off_frame_upkeep()
	ck(nvg._mines.is_empty(), "the early return keeps the next pass cheap")
	nvg.free()

# Mines render with the direct display mine colour on intended meshes while
# thermal is on, the mine toggle is on and the mine is in range; distance exit,
# toggle off and thermal off clear the override.
func t_mine_direct_material_gating() -> void:
	var nvg = NVG.new()
	root.add_child(nvg)
	var mine := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mine.add_child(mesh)
	root.add_child(mine)
	nvg._register_mine(mine)
	var id := mine.get_instance_id()
	ck(nvg._mines.has(id), "a mine with a mesh registers")
	ck(mesh.material_override == null, "registered mine starts unpainted")
	var col := Color(0.2, 0.4, 0.9)
	nvg.set_mine_color(col)
	nvg.set_thermal = true
	nvg.set_mines = true
	nvg.set_glow_distance = 10.0
	nvg._update_mine(id, true, Vector3.ZERO)
	ck(mesh.material_override != null, "enabled thermal mine in range is painted")
	var mat := mesh.material_override as StandardMaterial3D
	ck(mat != null and mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "mine highlight is unshaded")
	ck(mat != null and mat.albedo_color == col, "mine highlight uses display mine colour")
	ck(mat != null and mat.emission_enabled and mat.emission == col, "mine highlight emits display mine colour")
	nvg._update_mine(id, true, Vector3(100, 0, 0))
	ck(mesh.material_override == null, "out-of-range mine clears")
	nvg._update_mine(id, true, Vector3.ZERO)
	ck(mesh.material_override != null, "mine repaints on re-entry")
	nvg.set_mines = false
	nvg._update_mine(id, true, Vector3.ZERO)
	ck(mesh.material_override == null, "mine toggle off clears")
	nvg.set_mines = true
	nvg._update_mine(id, true, Vector3.ZERO)
	ck(mesh.material_override != null, "mine toggle on repaints in range")
	nvg.set_thermal_enabled(false)
	ck(mesh.material_override == null, "thermal off clears the painted mine")
	nvg.free()
	mine.free()

func t_mine_material_clears_on_free() -> void:
	var nvg = NVG.new()
	root.add_child(nvg)
	var mine := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mine.add_child(mesh)
	root.add_child(mine)
	nvg._register_mine(mine)
	var id := mine.get_instance_id()
	nvg.set_mine_color(Color(0.9, 0.2, 0.7))
	nvg._update_mine(id, true, Vector3.ZERO)
	ck(mesh.material_override != null, "mine painted before removal")
	mine.free()
	nvg._off_frame_upkeep()
	ck(not nvg._mines.has(id), "freed mine entry is removed")
	nvg.free()

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
