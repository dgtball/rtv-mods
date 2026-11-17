extends RefCounted
# Owns ESP contour rendering per NPC in two modes:
# - NVG-off/overlay mode (direct parity): applies direct display materials as
#   `material_overlay` on the source meshes in the main 3D pass.
# - NVG-on buffer mode: renders shell MeshInstance3D copies (same parent, mesh/
#   skin/skeleton copied) on the ESP buffer layer with direct display materials,
#   keeping source meshes free of ESP overlays so ESP is absent from screen_texture.
#
# Direct display semantics (both modes): outline = mask+ring band with translucent
# ring alpha driven by fill_alpha, fill = translucent body alpha (fill_alpha),
# xray swaps depth_test_disabled variants; color/brightness/cool/grow follow opts.

const Shaders = preload("res://mods/ThermalVTK/VTKShaders.gd")

# Nodes the mod adds under a bot's subtree (the nomad marker, the debug label,
# shells, etc.) carry this meta: the sweep must skip them.
const NO_CONTOUR_META := "vtk_no_contour"
const SHELL_META := "vtk_esp_shell"

var _items: Dictionary = {}
var _clear_pool: Array = []
var _buffer_mode: bool = false
var _buffer_layer_bit: int = 1 << 19

func has(id: int) -> bool:
	return _items.has(id)

func buffer_mode() -> bool:
	return _buffer_mode

func set_buffer_mode(enabled: bool, layer_bit: int = 1 << 19) -> void:
	if _buffer_mode == enabled and _buffer_layer_bit == layer_bit:
		return
	_buffer_mode = enabled
	_buffer_layer_bit = layer_bit
	if enabled:
		for id in _items:
			_enter_buffer(id, _items[id])
	else:
		for id in _items:
			_leave_buffer(id, _items[id])

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

func _material_for(fill: bool, xray: bool) -> Material:
	var body_mat := ShaderMaterial.new()
	body_mat.shader = Shaders.body_xray() if xray else Shaders.body_los()
	if not fill:
		var ring_mat := ShaderMaterial.new()
		ring_mat.shader = Shaders.ring_xray() if xray else Shaders.ring_los()
		body_mat.next_pass = ring_mat
	return body_mat

func _ring_of(mat: Material) -> ShaderMaterial:
	var body := mat as ShaderMaterial
	if body == null:
		return null
	return body.next_pass as ShaderMaterial

func _set_material(entry: Dictionary, mat: Material) -> void:
	entry["mat"] = mat
	entry["ring"] = _ring_of(mat)
	entry["p_color"] = null
	entry["p_brightness"] = null
	entry["p_alpha"] = null
	entry["p_ring_alpha"] = null
	entry["p_grow"] = null
	entry["p_band"] = null
	entry["p_cool"] = null
	entry["p_rim"] = null
	if _buffer_mode:
		_apply_shell_materials(entry)
	else:
		_apply_to(entry.get("meshes", []), mat)

# Overlay-mode write. A null material takes the contour off the source mesh.
func _apply_to(meshes: Array, mat: Material) -> void:
	for m in meshes:
		var mi := m as MeshInstance3D
		if mi != null and is_instance_valid(mi):
			mi.material_overlay = mat

func _shells(entry: Dictionary) -> Array:
	var s = entry.get("shells", [])
	return s if s is Array else []

func _sync_shell(shell: MeshInstance3D, src: MeshInstance3D) -> void:
	shell.global_transform = src.global_transform
	shell.visible = src.visible
	shell.layers = _buffer_layer_bit

func _make_shell(src: MeshInstance3D) -> MeshInstance3D:
	var shell := MeshInstance3D.new()
	shell.set_meta(NO_CONTOUR_META, true)
	shell.set_meta(SHELL_META, true)
	shell.top_level = true
	shell.mesh = src.mesh
	shell.skin = src.skin
	shell.skeleton = src.skeleton
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	src.add_sibling(shell)
	_sync_shell(shell, src)
	return shell

func _apply_shell_materials(entry: Dictionary) -> void:
	var mat: Material = entry.get("mat")
	for s in _shells(entry):
		var shell := s as MeshInstance3D
		if shell != null and is_instance_valid(shell):
			shell.material_override = mat

func _free_shells(entry: Dictionary) -> void:
	for s in _shells(entry):
		var shell := s as MeshInstance3D
		if shell != null and is_instance_valid(shell):
			shell.queue_free()
	entry["shells"] = []

func _enter_buffer(id: int, entry: Dictionary) -> void:
	_apply_to(entry.get("meshes", []), null)
	_rebuild_shells(entry)

func _leave_buffer(id: int, entry: Dictionary) -> void:
	_free_shells(entry)
	_apply_to(entry.get("meshes", []), entry.get("mat"))

func _rebuild_shells(entry: Dictionary) -> void:
	_free_shells(entry)
	if not _buffer_mode:
		return
	var shells: Array = []
	for m in entry.get("meshes", []):
		var src := m as MeshInstance3D
		if src == null or not is_instance_valid(src):
			continue
		shells.append(_make_shell(src))
	entry["shells"] = shells
	_apply_shell_materials(entry)

func apply(id: int, node: Node, opts: Dictionary) -> void:
	var meshes: Array = []
	_collect(node, meshes)
	var xray: bool = bool(opts.get("xray", false))
	var fill: bool = bool(opts.get("fill", false))
	var mat: Material = _material_for(fill, xray)
	_items[id] = {
		"node": node,
		"meshes": meshes,
		"shells": [],
		"mat": mat,
		"ring": _ring_of(mat),
		"fill_mode": fill,
		"xray": xray,
		"child_count": _child_count(node),
		"p_color": null,
		"p_brightness": null,
		"p_alpha": null,
		"p_ring_alpha": null,
		"p_grow": null,
		"p_band": null,
		"p_cool": null,
		"p_rim": null,
	}
	if _buffer_mode:
		_rebuild_shells(_items[id])
	else:
		_apply_to(meshes, mat)
	# Seed the uniforms in the same frame: the first draw of a fresh bot must
	# already carry its display state, not the shader default.
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
	var display: Color = opts.get("color", Color(1.0, 0.0, 0.0, 1.0))
	var brightness: float = float(opts.get("brightness", 1.0))
	var fill_alpha: float = clampf(float(opts.get("fill_alpha", opts.get("alpha", 0.4))), 0.0, 1.0)
	var grow: float = float(opts.get("grow", 0.006))
	var band: float = maxf(float(opts.get("band", 0.0)), 0.0)
	var cool: float = float(opts.get("cool", 0.0))
	var rim: float = float(opts.get("rim", 2.0))
	var body_mat: ShaderMaterial = entry.get("mat") as ShaderMaterial
	var ring_mat: ShaderMaterial = entry.get("ring") as ShaderMaterial
	if body_mat == null:
		return
	var p_color = entry.get("p_color")
	if p_color == null or p_color != display:
		body_mat.set_shader_parameter("outline_color", display)
		if ring_mat != null:
			ring_mat.set_shader_parameter("outline_color", display)
		entry["p_color"] = display
	var p_brightness = entry.get("p_brightness")
	if p_brightness == null or not is_equal_approx(float(p_brightness), brightness):
		body_mat.set_shader_parameter("brightness", brightness)
		if ring_mat != null:
			ring_mat.set_shader_parameter("brightness", brightness)
		entry["p_brightness"] = brightness
	var p_grow = entry.get("p_grow")
	var p_band = entry.get("p_band")
	if p_grow == null or not is_equal_approx(float(p_grow), grow) or p_band == null or not is_equal_approx(float(p_band), band):
		var body_grow: float = maxf(grow, band)
		if fill:
			body_mat.set_shader_parameter("grow", body_grow)
		else:
			body_mat.set_shader_parameter("grow", body_grow)
			if ring_mat != null:
				ring_mat.set_shader_parameter("grow", body_grow + band)
		entry["p_grow"] = grow
		entry["p_band"] = band
	var p_cool = entry.get("p_cool")
	if p_cool == null or not is_equal_approx(float(p_cool), cool):
		body_mat.set_shader_parameter("cool", cool)
		if ring_mat != null:
			ring_mat.set_shader_parameter("cool", cool)
		entry["p_cool"] = cool
	if ring_mat != null:
		var p_rim = entry.get("p_rim")
		if p_rim == null or not is_equal_approx(float(p_rim), rim):
			ring_mat.set_shader_parameter("rim_power", rim)
			entry["p_rim"] = rim
	# Direct display: fill = translucent body alpha, outline = mask body + ring alpha.
	var body_alpha: float = fill_alpha if fill else 0.0
	var ring_alpha: float = fill_alpha if not fill else 0.0
	var p_alpha = entry.get("p_alpha")
	if p_alpha == null or not is_equal_approx(float(p_alpha), body_alpha):
		body_mat.set_shader_parameter("alpha", body_alpha)
		entry["p_alpha"] = body_alpha
	if ring_mat != null:
		var p_ring_alpha = entry.get("p_ring_alpha")
		if p_ring_alpha == null or not is_equal_approx(float(p_ring_alpha), ring_alpha):
			ring_mat.set_shader_parameter("alpha", ring_alpha)
			entry["p_ring_alpha"] = ring_alpha
	if _buffer_mode:
		var meshes: Array = entry.get("meshes", [])
		var shells: Array = _shells(entry)
		for i in shells.size():
			var shell := shells[i] as MeshInstance3D
			if shell == null or not is_instance_valid(shell):
				continue
			if i < meshes.size():
				var src := meshes[i] as MeshInstance3D
				if src != null and is_instance_valid(src):
					_sync_shell(shell, src)

func _recollect(id: int, entry: Dictionary) -> void:
	var node: Node = entry.get("node")
	if node == null or not is_instance_valid(node):
		return
	var fresh: Array = []
	_collect(node, fresh)
	entry["child_count"] = _child_count(node)
	if _same_meshes(entry.get("meshes", []), fresh):
		if _buffer_mode:
			_apply_shell_materials(entry)
		return
	entry["meshes"] = fresh
	if _buffer_mode:
		_rebuild_shells(entry)
	else:
		_apply_to(fresh, entry.get("mat"))

func clear(id: int) -> void:
	var entry: Dictionary = _items.get(id)
	if entry == null:
		return
	_apply_to(entry.get("meshes", []), null)
	_free_shells(entry)
	_items.erase(id)

func clear_all() -> void:
	clear_not_in({})

func clear_not_in(keep: Dictionary) -> void:
	_clear_pool.clear()
	for id in _items:
		if not keep.has(id):
			_clear_pool.append(id)
	for id in _clear_pool:
		clear(id)

