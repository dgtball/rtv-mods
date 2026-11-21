extends RefCounted
# ESP shell geometry helper. Shells are copies of source meshes that live on
# their own render layer, so the ESP camera sees them without drawing the world.
# Pure scene-graph work only: no load(), no paths into the game, no state.

const LAYER_BIT := 1 << 19
const SHELL_META := "vtk_esp_shell"
# Same marker the contour sweep in VTKOutline uses: a shell must never be
# picked up as another NPC mesh to outline.
const NO_CONTOUR_META := "vtk_no_contour"
const OCCLUDER_META := "vtk_esp_occluder"

static func shells(entry: Dictionary) -> Array:
	var stored = entry.get("shells", [])
	return stored if stored is Array else []


static func make_shell(src: MeshInstance3D, mat: Material, layer_bit: int) -> MeshInstance3D:
	if src == null or not is_instance_valid(src):
		return null
	var shell := MeshInstance3D.new()
	shell.set_meta(NO_CONTOUR_META, true)
	shell.set_meta(SHELL_META, true)
	shell.top_level = true
	shell.mesh = src.mesh
	shell.skin = src.skin
	shell.skeleton = src.skeleton
	shell.layers = layer_bit
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.material_override = mat
	# Sibling of the source: the skeleton path stays valid, and top_level keeps
	# the shell's transform independent of the source's parent.
	if src.get_parent() != null:
		src.add_sibling(shell)
	else:
		src.add_child(shell)
	sync_shell(shell, src)
	return shell


static func sync_shell(shell: MeshInstance3D, src: MeshInstance3D) -> void:
	if shell == null or src == null or not is_instance_valid(shell) or not is_instance_valid(src):
		return
	shell.global_transform = src.global_transform
	shell.visible = src.visible


# Transform-only follow for shells whose visibility is owned by the caller
# (painted mines gate visibility separately from the source mesh).
static func sync_transform(shell: MeshInstance3D, src: MeshInstance3D) -> void:
	if shell == null or src == null or not is_instance_valid(shell) or not is_instance_valid(src):
		return
	shell.global_transform = src.global_transform


# Depth-only world copy for the ESP buffer. It is a child of the source, so
# moving/animated world geometry drags its occluder along without a per-frame
# transform pass. Skeleton paths are relative to the owning MeshInstance3D and
# therefore have to be rebound after the child is attached.
static func make_occluder(src: MeshInstance3D, mat: Material, layer_bit: int) -> MeshInstance3D:
	if src == null or not is_instance_valid(src) or src.mesh == null:
		return null
	var shell := MeshInstance3D.new()
	shell.name = "VTKESPOccluder"
	shell.set_meta(NO_CONTOUR_META, true)
	shell.set_meta(OCCLUDER_META, true)
	shell.mesh = src.mesh
	shell.skin = src.skin
	shell.layers = layer_bit
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.material_override = mat
	src.add_child(shell)
	var skeleton_path: NodePath = src.skeleton
	if not String(skeleton_path).is_empty():
		var skel := src.get_node_or_null(skeleton_path)
		if skel != null:
			shell.skeleton = shell.get_path_to(skel)
	return shell


static func rebuild(entry: Dictionary, mat: Material, layer_bit: int) -> void:
	clear(entry)
	var made: Array = []
	for m in entry.get("meshes", []):
		var src := m as MeshInstance3D
		if src == null or not is_instance_valid(src):
			continue
		var shell := make_shell(src, mat, layer_bit)
		if shell != null:
			made.append(shell)
	entry["shells"] = made


static func clear(entry: Dictionary) -> void:
	for s in shells(entry):
		var shell := s as MeshInstance3D
		if shell != null and is_instance_valid(shell):
			shell.queue_free()
	entry["shells"] = []
