extends RefCounted
# Owns ESP contour rendering per NPC. The default path applies display
# materials as `material_overlay` on source meshes in the main 3D pass; buffer
# mode moves that same chain onto shells on the ESP layer via VTKESPBuffer.
# Direct display semantics: outline = translucent body fill (fill_alpha) + ring
# band at the same alpha, fill = translucent body alpha (fill_alpha), xray swaps
# depth_test_disabled variants; color/brightness/cool/grow follow opts. Pass
# order is pinned with render_priority (body floor, ring ceiling) so the tint
# always draws under the band.

const Shaders = preload("res://mods/ThermalVTK/VTKShaders.gd")
const Dbg = preload("res://mods/ThermalVTK/VTKDebug.gd")
const Buf = preload("res://mods/ThermalVTK/VTKESPBuffer.gd")

# Nodes the mod adds under a bot's subtree (marker, debug label, etc.) carry
# this meta: the sweep must skip them.
const NO_CONTOUR_META := "vtk_no_contour"

var _items: Dictionary = {}
var _clear_pool: Array = []
# Off by default: the direct overlay path stays the baseline. Enable only while
# the NVG ESP composite runs, so its camera sees the shells on this layer.
var _buffer_mode: bool = false
var _buffer_layer: int = Buf.LAYER_BIT

func set_buffer_mode(enabled: bool, layer_bit: int = Buf.LAYER_BIT) -> void:
	var layer_changed := layer_bit != _buffer_layer
	if _buffer_mode == enabled and (not enabled or not layer_changed):
		return
	_buffer_mode = enabled
	_buffer_layer = layer_bit
	for id in _items:
		var entry: Dictionary = _items[id]
		if enabled:
			# A source mesh with a leftover display overlay would draw the
			# contour twice: once in the main pass, once from the shell.
			for m in entry.get("meshes", []):
				var src := m as MeshInstance3D
				if src != null and is_instance_valid(src):
					src.material_overlay = null
			Buf.rebuild(entry, entry.get("mat"), layer_bit)
		else:
			Buf.clear(entry)
			_apply_to(entry.get("meshes", []), entry.get("mat"))
	if Dbg.enabled:
		Dbg.log("ESP_OUTLINE", "buffer_mode=%s layer=%d" % [str(enabled), layer_bit])

func buffer_mode() -> bool:
	return _buffer_mode

func has(id: int) -> bool:
	return _items.has(id)

func mesh_count(id: int) -> int:
	var entry: Dictionary = _items.get(id, {})
	if entry.is_empty():
		return -1
	var meshes = entry.get("meshes", [])
	return meshes.size() if meshes is Array else -1

func recollect_info(id: int) -> String:
	var entry: Dictionary = _items.get(id, {})
	if entry.is_empty():
		return ""
	return str(entry.get("last_recollect", ""))

# Snapshot of what the shaders actually hold for one NPC: the real uniforms,
# the shader in use and the tracked mesh count. The per-frame subject log
# reads this instead of the opts it was asked for, so a stale or swapped
# material shows up as itself. The overlay trio (ok/lost/other) reads the
# GeometryInstance3D nodes, not the entry — that is the only way to see a
# contour that is perfect on paper but gone from the screen. Empty for an
# unknown id.
func material_info(id: int) -> Dictionary:
	var entry: Dictionary = _items.get(id, {})
	if entry.is_empty():
		return {}
	var body := entry.get("mat") as ShaderMaterial
	if body == null:
		return {}
	var info := {
		"fill_mode": bool(entry.get("fill_mode", false)),
		"has_ring": entry.get("ring") != null,
		"meshes": mesh_count(id),
		"mat_gen": int(entry.get("mat_gen", 0)),
		"body_grow": float(body.get_shader_parameter("grow")),
		"body_alpha": float(body.get_shader_parameter("alpha")),
		"brightness": float(body.get_shader_parameter("brightness")),
		"cool": float(body.get_shader_parameter("cool")),
		"body_shader": _shader_file(body),
	}
	var col: Variant = body.get_shader_parameter("outline_color")
	info["color"] = col if col is Color else Color.BLACK
	var ok := 0
	var lost := 0
	var other := 0
	var meshes = entry.get("meshes", [])
	if meshes is Array:
		for m in meshes:
			var gi := m as GeometryInstance3D
			if gi == null or not is_instance_valid(gi):
				continue
			if gi.material_overlay == body:
				ok += 1
			elif gi.material_overlay == null:
				lost += 1
			else:
				other += 1
	info["overlay_ok"] = ok
	info["overlay_lost"] = lost
	info["overlay_other"] = other
	var ring := entry.get("ring") as ShaderMaterial
	if ring != null:
		info["ring_grow"] = float(ring.get_shader_parameter("grow"))
		info["ring_alpha"] = float(ring.get_shader_parameter("alpha"))
		info["rim"] = float(ring.get_shader_parameter("rim_power"))
		info["ring_shader"] = _shader_file(ring)
	return info

func _shader_file(m: ShaderMaterial) -> String:
	if m == null or m.shader == null:
		return ""
	return m.shader.resource_path.get_file()

func _collect(node: Node, out: Array) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.has_meta(NO_CONTOUR_META):
		return
	if node is GeometryInstance3D and is_instance_valid(node):
		out.append(node)
	for c in node.get_children():
		_collect(c, out)

func _child_count(node: Node) -> int:
	var n: int = 0
	if node == null or not is_instance_valid(node):
		return 0
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

func _valid_meshes(meshes: Array) -> Array:
	var out: Array = []
	for m in meshes:
		if m == null or not is_instance_valid(m):
			continue
		var gi := m as GeometryInstance3D
		if gi != null:
			out.append(gi)
	return out

func _material_for(fill: bool, xray: bool) -> Material:
	var body_mat := ShaderMaterial.new()
	body_mat.shader = Shaders.body_xray() if xray else Shaders.body_los()
	# Keep the translucent fill under the ring band whatever order the
	# transparent queue picks for the camera. Priorities are the primary
	# sort key: body at the floor, ring at the ceiling pin body -> ring.
	# -128 is reserved for the depth-only world occluders in the ESP buffer.
	body_mat.render_priority = -127
	if not fill:
		var ring_mat := ShaderMaterial.new()
		ring_mat.shader = Shaders.ring_xray() if xray else Shaders.ring_los()
		ring_mat.render_priority = 127
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
	entry["mat_gen"] = int(entry.get("mat_gen", 0)) + 1
	entry["p_color"] = null
	entry["p_brightness"] = null
	entry["p_alpha"] = null
	entry["p_ring_alpha"] = null
	entry["p_grow"] = null
	entry["p_band"] = null
	entry["p_cool"] = null
	entry["p_rim"] = null
	_apply_to(entry.get("meshes", []), mat)
	if _buffer_mode:
		# A material swap (fill/xray toggle) must reach the shells too: they
		# carry the display chain, not the source meshes.
		Buf.rebuild(entry, mat, _buffer_layer)

# Overlay-mode write. A null material takes the contour off the source mesh.
# In buffer mode a MeshInstance3D is represented by its shell on the ESP layer
# and must stay clean here. Other GeometryInstance3D types have no shell
# counterpart (a shell only copies mesh/skin/skeleton), so they keep the direct
# overlay path even while buffer mode is on.
func _apply_to(meshes: Array, mat: Material) -> void:
	for m in meshes:
		if m == null or not is_instance_valid(m):
			continue
		if _buffer_mode and m is MeshInstance3D:
			continue
		var gi := m as GeometryInstance3D
		if gi != null:
			gi.material_overlay = mat

# Per-frame shell follow. Buf.rebuild queues the old shells for deletion and
# makes new ones, so it cannot run every frame; mirroring its source order here
# keeps the transform/visibility current without that churn.
func _sync_shells(entry: Dictionary) -> void:
	var shells: Array = Buf.shells(entry)
	var idx: int = 0
	for m in entry.get("meshes", []):
		var src := m as MeshInstance3D
		if src == null or not is_instance_valid(src):
			continue
		if idx >= shells.size():
			break
		Buf.sync_shell(shells[idx] as MeshInstance3D, src)
		idx += 1

func apply(id: int, node: Node, opts: Dictionary) -> void:
	var meshes: Array = []
	_collect(node, meshes)
	var xray: bool = bool(opts.get("xray", false))
	var fill: bool = bool(opts.get("fill", false))
	var mat: Material = _material_for(fill, xray)
	# Generation counts material creations for this id across re-applies, so a
	# mid-session swap is visible in the subject log as a step, not a reset.
	var prev: Dictionary = _items.get(id, {})
	_items[id] = {
		"node": node,
		"meshes": meshes,
		"mat": mat,
		"ring": _ring_of(mat),
		"mat_gen": int(prev.get("mat_gen", 0)) + 1,
		"fill_mode": fill,
		"xray": xray,
		"child_count": _child_count(node),
		"last_recollect": "",
		"p_color": null,
		"p_brightness": null,
		"p_alpha": null,
		"p_ring_alpha": null,
		"p_grow": null,
		"p_band": null,
		"p_cool": null,
		"p_rim": null,
	}
	if Dbg.enabled:
		Dbg.log("ESP_OUTLINE", "apply id=%d meshes=%d children=%d" % [id, meshes.size(), _child_count(node)])
	_apply_to(meshes, mat)
	if _buffer_mode:
		Buf.rebuild(_items[id], mat, _buffer_layer)
	# Seed the uniforms in the same frame: the first draw of a fresh bot must
	# already carry its display state, not the shader default.
	refresh(id, opts)

func refresh(id: int, opts: Dictionary) -> void:
	var entry: Dictionary = _items.get(id)
	if entry == null:
		return
	var node: Node = entry.get("node")
	var fresh: Array = []
	if node != null and is_instance_valid(node):
		_collect(node, fresh)
		var stored: Array = _valid_meshes(entry.get("meshes", []))
		var fresh_count := _child_count(node)
		var changed := int(entry.get("child_count", -1)) != fresh_count or not _same_meshes(stored, fresh)
		if changed:
			_recollect(id, entry, fresh, fresh_count)
			# _recollect may update entry state; continue with uniform refresh.
	if not _items.has(id):
		return
	entry = _items.get(id)
	if entry == null:
		return
	var xray: bool = bool(opts.get("xray", false))
	var fill: bool = bool(opts.get("fill", false))
	if bool(entry.get("xray", false)) != xray or bool(entry.get("fill_mode", false)) != fill:
		entry["xray"] = xray
		entry["fill_mode"] = fill
		_set_material(entry, _material_for(fill, xray))
		entry = _items.get(id, entry)
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
		var body_grow: float = grow
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
	var p_rim = entry.get("p_rim")
	if p_rim == null or not is_equal_approx(float(p_rim), rim):
		# Outline weights the body fill by the same fresnel as the band, so
		# the silhouette glows at its edges while the centre keeps its detail.
		# Fill mode keeps a flat tint by disabling the body falloff.
		body_mat.set_shader_parameter("rim_power", 0.0 if fill else rim)
		if ring_mat != null:
			ring_mat.set_shader_parameter("rim_power", rim)
		entry["p_rim"] = rim
	# Direct display (or the shell's display material in buffer mode): the body
	# always carries the fill alpha (that is the translucent tint inside the
	# contour), the ring carries it only in outline mode where it draws the band.
	var body_alpha: float = fill_alpha
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
	# Reassert overlays on valid tracked meshes so state changes do not leave
	# partial/stale application (overlay-only baseline).
	_apply_to(_valid_meshes(entry.get("meshes", [])), entry.get("mat"))
	if _buffer_mode:
		_sync_shells(entry)

func _recollect(id: int, entry: Dictionary, fresh: Array = [], fresh_count: int = -1) -> void:
	var node: Node = entry.get("node")
	if node == null or not is_instance_valid(node):
		return
	var old_meshes: Array = _valid_meshes(entry.get("meshes", []))
	if fresh.is_empty() and fresh_count < 0:
		_collect(node, fresh)
		fresh_count = _child_count(node)
	elif fresh_count < 0:
		fresh_count = _child_count(node)
	var old_children: int = int(entry.get("child_count", -1))
	entry["child_count"] = fresh_count
	if _same_meshes(old_meshes, fresh):
		entry["meshes"] = fresh
		_apply_to(fresh, entry.get("mat"))
		if _buffer_mode:
			_sync_shells(entry)
		return
	entry["last_recollect"] = "%d->%d" % [old_meshes.size(), fresh.size()]
	if Dbg.enabled:
		var nname := "?"
		if is_instance_valid(node):
			nname = str((node as Node).name)
		Dbg.log("ESP_OUTLINE", "recollect id=%d name=%s meshes=%d->%d children=%d->%d" % [
			id, nname, old_meshes.size(), fresh.size(), old_children, fresh_count
		])
	# Remove overlay from meshes no longer tracked.
	for m in old_meshes:
		if m == null or not is_instance_valid(m):
			continue
		var gi := m as GeometryInstance3D
		if gi == null:
			continue
		if not fresh.has(gi):
			gi.material_overlay = null
	entry["meshes"] = fresh
	_apply_to(fresh, entry.get("mat"))
	if _buffer_mode:
		Buf.rebuild(entry, entry.get("mat"), _buffer_layer)

func clear(id: int) -> void:
	var entry: Dictionary = _items.get(id)
	if entry == null:
		return
	if _buffer_mode:
		Buf.clear(entry)
	_apply_to(entry.get("meshes", []), null)
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
