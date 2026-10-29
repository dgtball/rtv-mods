extends SceneTree

const WeaponOcclusion = preload("res://mods/ThermalVTK/VTKWeaponOcclusion.gd")

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
	t_missing_manager_logged_once()
	t_manager_found_by_path()
	t_skip_scope_lens()
	t_optics_keep_vanilla()
	t_attachments_resolved_by_reference()
	t_late_optics_caught_by_resweep()
	t_optic_script_signal_skipped_not_member()
	t_mask_depth_mode()
	print("")
	if fails == 0:
		print("Weapon tests passed")
		quit(0)
	else:
		print("Weapon tests failed: ", fails)
		quit(1)

# Guards the fix: the manager used to be found by walking group "Player" ->
# parent -> "Camera" -> "Manager". The player's group node is an ID-marker
# nested under Camera, so the lookup never resolved and carved the feature
# dead while logging every frame.
func t_missing_manager_logged_once() -> void:
	var o = WeaponOcclusion.new()
	o._setup()
	ck(o._missing_logged, "missing manager logs once")
	o._setup()
	ck(o._missing_logged, "missing manager stays throttled")
	ck(not o._connected, "stays disconnected without manager")

func t_manager_found_by_path() -> void:
	var map := Node.new()
	map.name = "Map"
	var core := Node.new()
	core.name = "Core"
	var cam := Node.new()
	cam.name = "Camera"
	var mgr := Node.new()
	mgr.name = "Manager"
	map.add_child(core)
	core.add_child(cam)
	cam.add_child(mgr)
	root.add_child(map)

	var rig := MeshInstance3D.new()
	rig.name = "Rig"
	rig.mesh = BoxMesh.new()
	rig.layers = 3
	mgr.add_child(rig)

	var o = WeaponOcclusion.new()
	o._setup()
	ck(o._connected, "manager found via absolute path")
	ck(o._dbg_patched == 1, "rig mesh patched")
	ck(not o._missing_logged, "no false missing log")

	# Synchronous free: a queued map would still own /root/Map for the tests
	# that run in the same frame (the camera path would resolve to it).
	root.remove_child(map)
	map.free()

# The optic assembly lives under the rig's "Attachments" node (ACOG and the
# other sights, lasers). It keeps its own alpha and priorities: forcing
# ALPHA = 1.0 on its alpha-masked surfaces turns the ocular into an opaque
# black disc painted over the scope picture. The attachments subtree keeps its
# materials vanilla; only the Mask depth write is toggled by scope mode (see
# t_mask_depth_mode). The gun body still patches, and the PIP display quads
# stay skipped even outside Attachments.
func t_skip_scope_lens() -> void:
	var o = WeaponOcclusion.new()

	var lens := ShaderMaterial.new()
	var lens_sh := Shader.new()
	lens_sh.resource_path = "res://Shaders/Scope.gdshader"
	lens_sh.code = "shader_type spatial;\nrender_mode depth_draw_always;"
	lens.shader = lens_sh

	var plain := ShaderMaterial.new()
	var plain_sh := Shader.new()
	plain_sh.code = "shader_type spatial;"
	plain.shader = plain_sh

	var rig := Node3D.new()
	rig.name = "Rig"
	var body := MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	rig.add_child(body)
	ck(not o._skip(body, plain), "rig body still patched")

	var att := Node3D.new()
	att.name = "Attachments"
	rig.add_child(att)
	var acog := Node3D.new()
	acog.name = "ACOG"
	att.add_child(acog)
	var optic := MeshInstance3D.new()
	optic.mesh = BoxMesh.new()
	acog.add_child(optic)
	ck(o._skip(optic, lens), "optic glass skipped under Attachments")
	ck(o._skip(optic, plain), "every optic surface skipped, not just the glass")

	var loose := MeshInstance3D.new()
	loose.mesh = BoxMesh.new()
	rig.add_child(loose)
	ck(not o._skip(loose, lens), "a lens outside Attachments still patches")

	var pip := ShaderMaterial.new()
	var pip_sh := Shader.new()
	pip_sh.resource_path = "res://Shaders/PIP.gdshader"
	pip_sh.code = "shader_type spatial;"
	pip.shader = pip_sh
	ck(o._skip(body, pip), "PIP shader skipped")

	rig.free()

# Optic hardware under Attachments keeps its materials vanilla apart from the
# Mask depth mode covered by t_mask_depth_mode; the Scope/Alpha/Laser surfaces
# here must not move.
func t_optics_keep_vanilla() -> void:
	var o = WeaponOcclusion.new()

	var lens := ShaderMaterial.new()
	var lens_sh := Shader.new()
	lens_sh.resource_path = "res://Shaders/Scope.gdshader"
	lens_sh.code = "shader_type spatial;\nrender_mode depth_draw_always;"
	lens.shader = lens_sh
	lens.render_priority = 1

	var tube := ShaderMaterial.new()
	var tube_sh := Shader.new()
	tube_sh.resource_path = "res://Shaders/Alpha.gdshader"
	tube_sh.code = "shader_type spatial;\nrender_mode blend_mix, depth_draw_always;"
	tube.shader = tube_sh
	tube.render_priority = 11

	var beam := ShaderMaterial.new()
	var beam_sh := Shader.new()
	beam_sh.resource_path = "res://Shaders/Laser.gdshader"
	beam_sh.code = "shader_type spatial;\nrender_mode blend_add, depth_draw_always;"
	beam.shader = beam_sh

	var rig := Node3D.new()
	rig.name = "Rig"
	var att := Node3D.new()
	att.name = "Attachments"
	rig.add_child(att)
	var acog := Node3D.new()
	acog.name = "ACOG"
	att.add_child(acog)

	var glass := MeshInstance3D.new()
	glass.mesh = BoxMesh.new()
	glass.layers = 3
	glass.set_surface_override_material(0, lens)
	acog.add_child(glass)
	var wall := MeshInstance3D.new()
	wall.mesh = BoxMesh.new()
	wall.layers = 3
	wall.set_surface_override_material(0, tube)
	acog.add_child(wall)
	var laser := MeshInstance3D.new()
	laser.mesh = BoxMesh.new()
	laser.layers = 3
	laser.set_surface_override_material(0, beam)
	acog.add_child(laser)

	o._patch_rig(rig)

	ck(glass.get_surface_override_material(0) == lens, "optic glass keeps its vanilla material")
	ck(glass.get_surface_override_material(0).render_priority == 1, "optic glass keeps its vanilla priority")
	ck(glass.get_surface_override_material(0).shader.code.find("depth_draw_always") != -1, "optic glass keeps its depth token")
	var wg: ShaderMaterial = wall.get_surface_override_material(0)
	ck(wg == tube, "optic tube keeps its vanilla material")
	ck(wg.render_priority == 11, "optic tube keeps its vanilla priority")
	var lg: ShaderMaterial = laser.get_surface_override_material(0)
	ck(lg == beam, "laser beam keeps its vanilla material")
	ck(lg.shader.code.find("blend_add") != -1, "laser beam keeps its additive look")

	var body := MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	body.layers = 3
	var plain := ShaderMaterial.new()
	var plain_sh := Shader.new()
	plain_sh.code = "shader_type spatial;\nvoid fragment() {}"
	plain.shader = plain_sh
	body.set_surface_override_material(0, plain)
	rig.add_child(body)
	o._patch_rig(rig)
	ck(body.get_surface_override_material(0).render_priority == 30, "gun body still gets the full patch (prio 30)")

	rig.free()

# The attachments assembly resolves from the rig script's export
# (`attachments: Node3D`) and may carry an arbitrary node name, so the skip
# must work by reference, not by the literal name "Attachments".
func t_attachments_resolved_by_reference() -> void:
	var o = WeaponOcclusion.new()

	var lens := ShaderMaterial.new()
	var lens_sh := Shader.new()
	lens_sh.resource_path = "res://Shaders/Scope.gdshader"
	lens_sh.code = "shader_type spatial;\nrender_mode depth_draw_always;"
	lens.shader = lens_sh
	lens.render_priority = 1

	var src := GDScript.new()
	src.source_code = "extends Node3D\n@export var attachments: Node3D\n"
	src.reload()
	var rig = src.new()
	rig.name = "Rig"
	var assem := Node3D.new()
	assem.name = "Optics"
	rig.add_child(assem)
	rig.attachments = assem
	var acog := Node3D.new()
	assem.add_child(acog)
	var glass := MeshInstance3D.new()
	glass.mesh = BoxMesh.new()
	glass.layers = 3
	glass.set_surface_override_material(0, lens)
	acog.add_child(glass)

	o._patch_rig(rig)

	var og: ShaderMaterial = glass.get_surface_override_material(0)
	ck(og == lens, "referenced assembly: optic glass keeps its vanilla material")
	ck(o._skip(glass, lens, assem), "referenced assembly: full-patch skip honours the export too")
	ck(o._under_attachments(glass, assem), "referenced assembly: depth-skip resolver reads the export")

	rig.free()

# Optic hardware added to the rig after the initial sweep (or any mesh that
# slipped the add signal) is also skipped, and the meta guard keeps re-sweeps
# from touching anything twice.
func t_late_optics_caught_by_resweep() -> void:
	var o = WeaponOcclusion.new()

	var ring_body := ShaderMaterial.new()
	var body_sh := Shader.new()
	body_sh.code = "shader_type spatial;\nvoid fragment() {}"
	ring_body.shader = body_sh

	var lens := ShaderMaterial.new()
	var lens_sh := Shader.new()
	lens_sh.resource_path = "res://Shaders/Scope.gdshader"
	lens_sh.code = "shader_type spatial;\nrender_mode depth_draw_always;"
	lens.shader = lens_sh
	lens.render_priority = 1

	var rig := Node3D.new()
	rig.name = "Rig"
	var att := Node3D.new()
	att.name = "Attachments"
	rig.add_child(att)
	var body := MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	body.layers = 3
	body.set_surface_override_material(0, ring_body)
	rig.add_child(body)

	o._patch_rig(rig)
	ck(body.get_surface_override_material(0).render_priority == 30, "resweep: body patched by the first walk")

	var glass := MeshInstance3D.new()
	glass.mesh = BoxMesh.new()
	glass.layers = 3
	lens.render_priority = 1
	glass.set_surface_override_material(0, lens)
	att.add_child(glass)

	o._resweep(rig)
	ck(glass.get_surface_override_material(0) == lens, "resweep: late optic keeps its vanilla material")
	var body_patched: ShaderMaterial = body.get_surface_override_material(0)
	o._resweep(rig)
	ck(glass.get_surface_override_material(0) == lens, "resweep: late optic stays vanilla across passes")
	ck(body.get_surface_override_material(0) == body_patched, "resweep: meta guard prevents duplicate materials")

	rig.free()

# The optic assemblies carry Optic.gd (a signal named PIP in-game), so the
# PIP display check must match the node NAME only: a script member - signal,
# method or variable - on an optic assembly must not flag scopes as displays.
func t_optic_script_signal_skipped_not_member() -> void:
	var o = WeaponOcclusion.new()

	var lens := ShaderMaterial.new()
	var lens_sh := Shader.new()
	lens_sh.resource_path = "res://Shaders/Scope.gdshader"
	lens_sh.code = "shader_type spatial;\nrender_mode depth_draw_always;"
	lens.shader = lens_sh
	lens.render_priority = 1

	var src := GDScript.new()
	src.source_code = "extends Node3D\nsignal PIP\nfunc PIP2() -> void:\n\tpass\n"
	src.reload()
	var acog = src.new()
	acog.name = "ACOG"

	var rig := Node3D.new()
	rig.name = "Rig"
	var att := Node3D.new()
	att.name = "Attachments"
	rig.add_child(att)
	att.add_child(acog)
	var glass := MeshInstance3D.new()
	glass.mesh = BoxMesh.new()
	glass.layers = 3
	glass.set_surface_override_material(0, lens)
	acog.add_child(glass)

	o._patch_rig(rig)

	var og: ShaderMaterial = glass.get_surface_override_material(0)
	ck(og == lens, "optic with a PIP signal keeps its vanilla material")
	ck(o._under_attachments(glass, att), "optic with a PIP signal resolves under Attachments")

	# A node literally NAMED PIP (the display quad) keeps the skip.
	var display := ShaderMaterial.new()
	display.shader = lens_sh
	var quad := MeshInstance3D.new()
	quad.name = "PIP"
	quad.mesh = BoxMesh.new()
	quad.layers = 3
	quad.set_surface_override_material(0, display)
	acog.add_child(quad)
	o._resweep(acog)
	var qg: ShaderMaterial = quad.get_surface_override_material(0)
	ck(o._under_attachments(quad, att) == false, "a node named PIP is treated as the display quad")
	ck(qg == display, "the display quad keeps its vanilla material")

	rig.free()

func t_mask_depth_mode() -> void:
	var o = WeaponOcclusion.new()
	var rig := Node3D.new()
	rig.name = "Rig"
	var att := Node3D.new()
	att.name = "Attachments"
	rig.add_child(att)
	var mask := ShaderMaterial.new()
	var mask_sh := Shader.new()
	mask_sh.resource_path = "res://Shaders/Mask.gdshader"
	mask_sh.code = "shader_type spatial;\nrender_mode depth_draw_always;\nvoid fragment() {}"
	mask.shader = mask_sh
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.layers = 3
	mesh.set_surface_override_material(0, mask)
	att.add_child(mesh)
	o._patch_rig(rig)
	ck(mesh.get_surface_override_material(0) == mask, "mask starts vanilla before the scope mode is known")
	o.set_scope_mode(true, false)
	var depthless: Material = mesh.get_surface_override_material(0)
	ck(depthless != mask, "no-PIP aiming swaps the Mask material")
	ck(depthless is ShaderMaterial and (depthless as ShaderMaterial).shader.code.contains("depth_draw_never"), "no-PIP Mask stops writing depth")
	o.set_scope_mode(true, true)
	ck(mesh.get_surface_override_material(0) == mask, "PIP aiming restores the vanilla Mask depth write")
	o.set_scope_mode(false, false)
	ck(mesh.get_surface_override_material(0) == mask, "leaving the scope restores the vanilla Mask")
	o.set_scope_mode(true, false)
	var late := MeshInstance3D.new()
	late.mesh = BoxMesh.new()
	late.layers = 3
	late.set_surface_override_material(0, mask)
	att.add_child(late)
	o._resweep(rig)
	var late_cur: Material = late.get_surface_override_material(0)
	ck(late_cur != mask, "late mask follows the current no-PIP mode")
	ck(late_cur is ShaderMaterial and (late_cur as ShaderMaterial).shader.code.contains("depth_draw_never"), "late mask is depthless")
	rig.free()
