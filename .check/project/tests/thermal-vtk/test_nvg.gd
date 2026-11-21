extends SceneTree

const NVG = preload("res://mods/ThermalVTK/VTKNVG.gd")
const Buf = preload("res://mods/ThermalVTK/VTKESPBuffer.gd")

var fails := 0

class FakeGameData extends Resource:
	var NVG: bool = false


# Records the order of the two per-frame calls that decide whether a mine shell
# reaches the buffer. Both overrides delegate to the real implementation.
class OrderNVG extends "res://mods/ThermalVTK/VTKNVG.gd":
	var calls: Array = []

	func _push_esp_composite() -> void:
		calls.append("push")
		super._push_esp_composite()

	func _update_mine(id: int, thermal_on: bool, ppos: Vector3) -> void:
		calls.append("update")
		super._update_mine(id, thermal_on, ppos)


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
	t_mine_highlight_uses_esp_buffer()
	t_esp_composite_demand_includes_mines()
	t_composite_push_follows_mine_paint()
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

func t_mine_highlight_uses_esp_buffer() -> void:
	var nvg = NVG.new()
	root.add_child(nvg)
	var mine := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mine.add_child(mesh)
	root.add_child(mine)
	mine.global_position = Vector3(2.0, 0.0, 0.0)
	nvg._register_mine(mine)
	var id := mine.get_instance_id()
	var entry: Dictionary = nvg._mines[id]
	var shell: MeshInstance3D = Buf.shells(entry)[0]
	ck(shell.layers == Buf.LAYER_BIT, "mine shell lives on the ESP layer")
	ck(shell.material_override == nvg._mat_mine, "mine shell carries the display material")
	mine.global_position = Vector3(4.0, 0.0, 0.0)
	nvg._update_mine(id, true, Vector3.ZERO)
	ck(shell.global_transform == mesh.global_transform, "mine shell follows a moving mine")
	nvg._update_mine(id, true, Vector3.ZERO)
	ck(shell.visible and nvg.painted_mine_count() == 1, "in-range mine paints one shell")
	ck(mesh.material_overlay == null, "source mesh stays clean")
	nvg._update_mine(id, true, Vector3(1000.0, 0.0, 0.0))
	ck(not shell.visible and nvg.painted_mine_count() == 0, "out-of-range mine clears its shell")
	nvg.free()
	mine.free()


# Mines feed the composite demand too: with the contour layer off a painted
# mine must still switch the buffer on, or its shell lands in the main pass.
func t_esp_composite_demand_includes_mines() -> void:
	var nvg = NVG.new()
	root.add_child(nvg)
	nvg.set_thermal = true
	var data := FakeGameData.new()
	data.NVG = true
	nvg._game_data = data
	ck(not nvg.esp_composite_active(), "no contour demand and no mines leaves the composite off")
	var mine := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mine.add_child(mesh)
	root.add_child(mine)
	mine.global_position = Vector3(2.0, 0.0, 0.0)
	nvg._register_mine(mine)
	var id := mine.get_instance_id()
	nvg._update_mine(id, true, Vector3.ZERO)
	ck(nvg.painted_mine_count() == 1, "mine is painted")
	ck(nvg.esp_composite_active(), "painted mines alone keep the composite on without contour demand")
	nvg._update_mine(id, true, Vector3(1000.0, 0.0, 0.0))
	ck(nvg.painted_mine_count() == 0, "mine is no longer painted")
	ck(not nvg.esp_composite_active(), "composite stops once the last mine is out of range")
	nvg.free()
	mine.free()


# A mine that first enters range must be swept before that frame's composite
# decision; with the old order the shell renders once in the main pass and the
# NVG shader palettizes it. Contour demand stays off so only mines can activate
# the buffer, and one real _process frame exercises both call sites together.
func t_composite_push_follows_mine_paint() -> void:
	var nvg := OrderNVG.new()
	root.add_child(nvg)
	nvg.set_thermal = true
	var data := FakeGameData.new()
	data.NVG = true
	nvg._game_data = data
	var mine := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mine.add_child(mesh)
	root.add_child(mine)
	mine.global_position = Vector3(2.0, 0.0, 0.0)
	nvg._register_mine(mine)
	nvg.calls.clear()
	nvg._process(0.016)
	ck(nvg.calls.has("update"), "a frame sweeps the mine")
	ck(nvg.calls.has("push"), "a frame pushes the composite")
	ck(nvg.calls.find("update") < nvg.calls.find("push"), "the composite push follows the mine paint in the same frame")
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
	var world := MeshInstance3D.new()
	world.mesh = BoxMesh.new()
	root.add_child(world)
	var npc := MeshInstance3D.new()
	npc.mesh = BoxMesh.new()
	root.add_child(npc)
	nvg.set_occluder_exclusions({npc.get_instance_id(): true})
	nvg._sync_esp_buffer(false)
	nvg._sync_esp_buffer(true)
	ck(nvg._occ_shells.size() == 1, "one depth-only occluder follows the world mesh")
	var shell: MeshInstance3D = nvg._occ_shells[0] as MeshInstance3D
	ck(shell.get_parent() == world, "occluder is parented to its source so transforms follow")
	ck(shell.layers == Buf.LAYER_BIT, "occluder lives on the ESP layer")
	ck(shell.material_override == nvg._occ_mat, "occluder carries the depth-only material")
	ck(nvg._occ_mat.render_priority == -128, "occluder renders before contour shells")
	nvg.set_occluder_exclusions({world.get_instance_id(): true, npc.get_instance_id(): true})
	ck(nvg._occ_shells.is_empty(), "a new exclusion set drops stale occluders")
	nvg._sync_esp_buffer(false)
	ck(nvg._occ_shells.is_empty(), "inactive buffer keeps no occluders")
	world.free()
	npc.free()
	ck(vp.render_target_update_mode == SubViewport.UPDATE_DISABLED, "inactive buffer costs nothing")
	ck(cam.cull_mask == before, "main camera mask restored")
