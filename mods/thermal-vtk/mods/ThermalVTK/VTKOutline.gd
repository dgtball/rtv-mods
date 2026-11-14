extends RefCounted
# Owns one contour material per NPC and renders it on the NPC's own meshes
# through `material_overlay` -- the NPCESP_ex approach. The contour therefore
# lives in the main 3D pass: the depth test clips it against walls, the weapon
# and the sight glass for free, and no second world pass exists anywhere.
#
# The overlay chains:
#   xray : the ring shader with depth_test_disabled (through walls);
#   fill : the body shader (stencil write) -> the ring shader (stencil read,
#          draws strictly outside the body) -- full-body silhouette;
#   ring : the ring shader on its own (stencil read, depth-tested).
#
# State and the x-ray flag come in via `opts`.

const Shaders = preload("res://mods/ThermalVTK/VTKShaders.gd")
const States = preload("res://mods/ThermalVTK/VTKStates.gd")
const Dbg = preload("res://mods/ThermalVTK/VTKDebug.gd")

# Nodes the mod adds under a bot's subtree (the nomad marker, the debug label,
# the overlays themselves) carry this meta: the sweep must skip them.
const NO_CONTOUR_META := "vtk_no_contour"

var _items: Dictionary = {}
var _recols: int = 0
const SCOPE_RIM := 6.0
var _scoped: bool = false
var _clear_pool: Array = []
var _fill_log: Dictionary = {}

func has(id: int) -> bool:
	return _items.has(id)

func shell_count() -> int:
	var n: int = 0
	for id in _items:
		var e: Dictionary = _items[id]
		for m in e.get("meshes", []):
			var mi := m as MeshInstance3D
			if mi != null and is_instance_valid(mi) and mi.material_overlay != null:
				n += 1
	return n

func take_recols() -> int:
	var n: int = _recols
	_recols = 0
	return n

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

func _build_ring() -> ShaderMaterial:
	var ring_mat := ShaderMaterial.new()
	ring_mat.shader = Shaders.mask_ring()
	return ring_mat

func _build_xray() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = Shaders.mask_xray()
	return mat

func _build_fill_body() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = Shaders.mask_fill()
	return mat

func _build_fill_ring(body_mat: ShaderMaterial) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = Shaders.mask_ring()
	body_mat.next_pass = mat
	return mat

# The pass that carries the ring uniforms: in fill mode the body material owns
# `next_pass`, and the ring lives there; everywhere else the material itself is
# the ring. Setting the uniforms on the body in fill mode would silently leave
# the visible band at its shader defaults.
func _ring_of(mat: Material) -> ShaderMaterial:
	var body := mat as ShaderMaterial
	if body == null:
		return null
	var chain := body.next_pass as ShaderMaterial
	if chain != null:
		return chain
	return body

func _material_for(xray: bool, fill: bool) -> Material:
	if xray:
		return _build_xray()
	if fill:
		var body: ShaderMaterial = _build_fill_body()
		_build_fill_ring(body)
		return body
	return _build_ring()

func _set_material(id: int, mat: Material) -> void:
	var entry: Dictionary = _items[id]
	entry["mat"] = mat
	entry["ring"] = _ring_of(mat)
	entry["p_key"] = null
	entry["p_grow"] = null
	entry["p_rim"] = null
	entry["p_cool"] = null
	for m in entry.get("meshes", []):
		var mi := m as MeshInstance3D
		if mi != null:
			mi.material_overlay = mat

func apply(id: int, node: Node, opts: Dictionary) -> void:
	var meshes: Array = []
	_collect(node, meshes)
	var xray: bool = bool(opts.get("xray", false))
	var fill: bool = bool(opts.get("fill", false))
	var mat: Material = _material_for(xray, fill)
	_items[id] = {
			"node": node,
			"meshes": meshes,
			"mat": mat,
			"ring": _ring_of(mat),
			"fill_mode": fill,
			"xray": xray,
			"child_count": _child_count(node),
			"p_key": null,
			"p_grow": null,
			"p_rim": null,
			"p_cool": null,
		}
	for m in meshes:
		var mi := m as MeshInstance3D
		if mi != null:
			mi.material_overlay = mat
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
		_set_material(id, _material_for(xray, fill))
	var color: Color = opts.get("key", States.state_key(int(opts.get("cat", States.NORMAL))))
	var grow: float = float(opts.get("grow", 0.006))
	var cool: float = float(opts.get("cool", 0.0))
	var body_mat: ShaderMaterial = entry.get("mat") as ShaderMaterial
	var ring_mat: ShaderMaterial = entry.get("ring") as ShaderMaterial
	if ring_mat == null:
		ring_mat = body_mat
	if body_mat == null or ring_mat == null:
		return
	var p_key = entry.get("p_key")
	if p_key == null or p_key != color:
		# Both passes write the key: the body paints the silhouette (and marks
		# the stencil) while the ring paints the band around it, so the NVG
		# detector must find the same colour in either.
		body_mat.set_shader_parameter("state_color", color)
		ring_mat.set_shader_parameter("state_color", color)
		entry["p_key"] = color
	var p_grow = entry.get("p_grow")
	if p_grow == null or not is_equal_approx(float(p_grow), grow):
		body_mat.set_shader_parameter("grow", grow)
		ring_mat.set_shader_parameter("grow", grow)
		entry["p_grow"] = grow
	var rim_user: float = float(opts.get("rim", 1.0))
	if Dbg.enabled and rim_user <= 0.01 and int(_fill_log.get(id, -1)) != int(opts.get("cat", 0)):
		var t_ms: int = Time.get_ticks_msec()
		if t_ms - int(_fill_log.get(id, -100000)) >= 2000:
			_fill_log[id] = int(opts.get("cat", 0))
			Dbg.log("FILL", "id=%d cat=%d color=%.2f/%.2f/%.2f rim=%.2f xray=%s" % [id, int(opts.get("cat", 0)), color.r, color.g, color.b, rim_user, str(bool(opts.get("xray", false)))])
	var rim: float = SCOPE_RIM if (_scoped and rim_user > 0.01) else rim_user
	if entry.get("p_rim") == null or not is_equal_approx(float(entry.get("p_rim")), rim):
		ring_mat.set_shader_parameter("rim_power", rim)
		entry["p_rim"] = rim
	if entry.get("p_cool") == null or not is_equal_approx(float(entry.get("p_cool")), cool):
		body_mat.set_shader_parameter("cool", cool)
		ring_mat.set_shader_parameter("cool", cool)
		entry["p_cool"] = cool

func set_entry_xray(id: int, on: bool) -> void:
	var entry: Dictionary = _items.get(id)
	if entry == null:
		return
	if bool(entry.get("xray", false)) == on:
		return
	entry["xray"] = on
	_set_material(id, _material_for(on, bool(entry.get("fill_mode", false))))

func set_scoped(on: bool) -> void:
	_scoped = on

func set_entry_fill(id: int, on: bool) -> void:
	var entry: Dictionary = _items.get(id)
	if entry == null:
		return
	if bool(entry.get("fill_mode", false)) == on:
		return
	entry["fill_mode"] = on
	_set_material(id, _material_for(bool(entry.get("xray", false)), on))

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
	_recols += 1
	var mat: Material = entry.get("mat")
	for m in fresh:
		var mi := m as MeshInstance3D
		if mi != null:
			mi.material_overlay = mat

func _free_pairs(id: int) -> void:
	var entry: Dictionary = _items[id]
	for m in entry.get("meshes", []):
		var mi := m as MeshInstance3D
		if mi != null and is_instance_valid(mi):
			mi.material_overlay = null

func clear(id: int) -> void:
	var entry: Dictionary = _items[id]
	if entry == null:
		return
	_free_pairs(id)
	_items.erase(id)

func clear_all() -> void:
	for id in _items:
		clear(id)

func clear_not_in(keep: Dictionary) -> void:
	_clear_pool.clear()
	for id in _items:
		if not keep.has(id):
			_clear_pool.append(id)
	for id in _clear_pool:
		clear(id)
