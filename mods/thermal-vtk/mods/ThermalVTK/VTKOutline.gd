extends RefCounted
# Owns direct-color contour materials per NPC and renders them on the NPC's own
# meshes through `material_overlay` in the main 3D pass.
#
# Shape and depth mode are independent:
#   outline (fill=false): body shader (stencil write, mask-only, alpha 0) with a
#          next_pass ring shader (stencil read, visible band outside the body)
#   full-body (fill=true): body shader only (visible tint), no ring
#   xray=true preserves shape and only swaps LOS shaders for depth_test_disabled
#          XRAY variants.

const Shaders = preload("res://mods/ThermalVTK/VTKShaders.gd")

# Nodes the mod adds under a bot's subtree (the nomad marker, the debug label,
# the overlays themselves) carry this meta: the sweep must skip them.
const NO_CONTOUR_META := "vtk_no_contour"

var _items: Dictionary = {}
const SCOPE_RIM := 6.0
var _scoped: bool = false
var _clear_pool: Array = []

func has(id: int) -> bool:
	return _items.has(id)

func _collect(node: Node, out: Array) -> void:
	if node.has_meta(NO_CONTOUR_META):
		return
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		_collect(c, out)

func _child_count(node: Node) -> int:
	var n: int = 0
	for c in node.get_children():
		if not c.has_meta(NO_CONTOUR_META):
			n += 1
	return n

func _same_meshes(old: Array, fresh: Array) -> bool:
	if old.size() != fresh.size():
		return false
	for i in old.size():
		if old[i] != fresh[i]:
			return false
	return true

func _build_body(los: bool) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = Shaders.body_los() if los else Shaders.body_xray()
	return mat

func _build_ring(los: bool) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = Shaders.ring_los() if los else Shaders.ring_xray()
	return mat

func _material_for(fill: bool, xray: bool) -> ShaderMaterial:
	var los: bool = not xray
	var body := _build_body(los)
	if not fill:
		body.next_pass = _build_ring(los)
	return body

# Visible ring pass when present (outline chain), else null for full-body.
func _ring_of(mat: Material) -> ShaderMaterial:
	var body := mat as ShaderMaterial
	if body == null:
		return null
	return body.next_pass as ShaderMaterial

func _set_material(entry: Dictionary, mat: ShaderMaterial) -> void:
	entry["mat"] = mat
	entry["ring"] = _ring_of(mat)
	entry["p_color"] = null
	entry["p_brightness"] = null
	entry["p_grow"] = null
	entry["p_rim"] = null
	entry["p_cool"] = null
	entry["p_alpha_body"] = null
	entry["p_alpha_ring"] = null
	_apply_to(entry.get("meshes", []), mat)

# The one overlay write. A null material takes the contour off the mesh.
func _apply_to(meshes: Array, mat: Material) -> void:
	for m in meshes:
		var mi := m as MeshInstance3D
		if mi != null and is_instance_valid(mi):
			mi.material_overlay = mat

func apply(id: int, node: Node, opts: Dictionary) -> void:
	var meshes: Array = []
	_collect(node, meshes)
	var xray: bool = bool(opts.get("xray", false))
	var fill: bool = bool(opts.get("fill", false))
	var mat := _material_for(fill, xray)
	_items[id] = {
		"node": node,
		"meshes": meshes,
		"mat": mat,
		"ring": _ring_of(mat),
		"fill_mode": fill,
		"xray": xray,
		"child_count": _child_count(node),
		"p_color": null,
		"p_brightness": null,
		"p_grow": null,
		"p_rim": null,
		"p_cool": null,
		"p_alpha_body": null,
		"p_alpha_ring": null,
	}
	_apply_to(meshes, mat)
	# Seed the uniforms in the same frame: the first draw of a fresh bot must
	# already carry its category, not the shader default.
	refresh(id, opts)

func refresh(id: int, opts: Dictionary) -> void:
	var entry: Dictionary = _items.get(id)
	if entry == null:
		return
	var node: Node = entry.get("node")
	if node == null or not is_instance_valid(node) or _child_count(node) != int(entry.get("child_count", -1)):
		_recollect(id, entry)
	var xray: bool = bool(opts.get("xray", false))
	var fill: bool = bool(opts.get("fill", false))
	if bool(entry.get("xray", false)) != xray or bool(entry.get("fill_mode", false)) != fill:
		entry["xray"] = xray
		entry["fill_mode"] = fill
		_set_material(entry, _material_for(fill, xray))
	var color: Color = opts.get("color", Color(1.0, 0.0, 0.0, 1.0))
	var brightness: float = float(opts.get("brightness", 1.0))
	var alpha: float = float(opts.get("alpha", 0.4))
	var grow: float = float(opts.get("grow", 0.006))
	var cool: float = float(opts.get("cool", 0.0))
	var rim_user: float = float(opts.get("rim", 1.0))
	var body_mat: ShaderMaterial = entry.get("mat") as ShaderMaterial
	var ring_mat: ShaderMaterial = entry.get("ring") as ShaderMaterial
	if body_mat == null:
		return
	var body_alpha: float = 0.0 if not fill else alpha
	if entry.get("p_color") == null or entry.get("p_color") != color:
		body_mat.set_shader_parameter("outline_color", color)
		if ring_mat != null:
			ring_mat.set_shader_parameter("outline_color", color)
		entry["p_color"] = color
	if entry.get("p_brightness") == null or not is_equal_approx(float(entry.get("p_brightness")), brightness):
		body_mat.set_shader_parameter("brightness", brightness)
		if ring_mat != null:
			ring_mat.set_shader_parameter("brightness", brightness)
		entry["p_brightness"] = brightness
	if entry.get("p_grow") == null or not is_equal_approx(float(entry.get("p_grow")), grow):
		body_mat.set_shader_parameter("grow", grow)
		if ring_mat != null:
			ring_mat.set_shader_parameter("grow", grow)
		entry["p_grow"] = grow
	if entry.get("p_cool") == null or not is_equal_approx(float(entry.get("p_cool")), cool):
		body_mat.set_shader_parameter("cool", cool)
		if ring_mat != null:
			ring_mat.set_shader_parameter("cool", cool)
		entry["p_cool"] = cool
	if entry.get("p_alpha_body") == null or not is_equal_approx(float(entry.get("p_alpha_body")), body_alpha):
		body_mat.set_shader_parameter("alpha", body_alpha)
		entry["p_alpha_body"] = body_alpha
	if ring_mat != null:
		var rim: float = SCOPE_RIM if (_scoped and rim_user > 0.01) else rim_user
		if entry.get("p_rim") == null or not is_equal_approx(float(entry.get("p_rim")), rim):
			ring_mat.set_shader_parameter("rim_power", rim)
			entry["p_rim"] = rim
		if entry.get("p_alpha_ring") == null or not is_equal_approx(float(entry.get("p_alpha_ring")), alpha):
			ring_mat.set_shader_parameter("alpha", alpha)
			entry["p_alpha_ring"] = alpha
	else:
		entry["p_rim"] = null
		entry["p_alpha_ring"] = null

func set_scoped(on: bool) -> void:
	_scoped = on

func _recollect(id: int, entry: Dictionary) -> void:
	var node: Node = entry.get("node")
	if node == null or not is_instance_valid(node):
		return
	var fresh: Array = []
	_collect(node, fresh)
	# The count is re-sampled either way: a non-geometry child (audio player,
	# identifier) moves it on most AI steps, and re-sweeping on every one of
	# those is exactly what this guard exists to absorb.
	entry["child_count"] = _child_count(node)
	if _same_meshes(entry.get("meshes", []), fresh):
		return
	entry["meshes"] = fresh
	_apply_to(fresh, entry.get("mat"))

func clear(id: int) -> void:
	var entry: Dictionary = _items.get(id)
	if entry == null:
		return
	_apply_to(entry.get("meshes", []), null)
	_items.erase(id)

# Same pool dance as clear_not_in: erasing while iterating _items skips entries.
func clear_all() -> void:
	clear_not_in({})

func clear_not_in(keep: Dictionary) -> void:
	_clear_pool.clear()
	for id in _items:
		if not keep.has(id):
			_clear_pool.append(id)
	for id in _clear_pool:
		clear(id)
