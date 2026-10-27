extends RefCounted

const Log = preload("res://mods/RoadToLoot/RTLLog.gd")
const Store = preload("res://mods/RoadToLoot/RTLStore.gd")
const Pool = preload("res://mods/RoadToLoot/RTLPool.gd")
const Text = preload("res://mods/RoadToLoot/RTLText.gd")
const Rows = preload("res://mods/RoadToLoot/RTLRows.gd")

const BORDER_NAME := "_rtl_border"
const BORDER_TAG := "rtl_border"
const ROW_NAME := "_rtl_stat"
const ROW_TAG := "rtl_stat"
const ROW_VALUE_MIN_W := 40.0
const COLORS_DEFAULT := {1: Color(0.35, 0.6, 1.0), 2: Color(0.7, 0.4, 1.0), 3: Color(1.0, 0.8, 0.2)}
const COLORS_CONTRAST := {1: Color(0.1, 0.75, 1.0), 2: Color(1.0, 0.2, 0.9), 3: Color(1.0, 0.95, 0.1)}

var _cfg = null
var _host = null
var _scan_frames_remaining: int = 0
var _last_tooltip_item_id: int = 0
var _did_inspect_tooltip: bool = false
var _rows_root = null
var _rows: Array = []
var _merged_values: Array = []
var _last_rows_item_id: int = 0
var _last_merge_item_id: int = 0
var _warned_hidden: bool = false
var _warned_template: bool = false

func configure(cfg) -> void:
	_cfg = cfg

func set_host(h) -> void:
	_host = h

func _iface() -> Node:
	if _host == null:
		return null
	var tree: SceneTree = _host.get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("Map/Core/UI/Interface")

func attach(tree: SceneTree) -> void:
	if not tree.node_added.is_connected(track):
		tree.node_added.connect(track)
	_walk(tree.get_root())
	if not tree.process_frame.is_connected(_scan_after_frame):
		_scan_frames_remaining = 12
		tree.process_frame.connect(_scan_after_frame)

func track(node: Node) -> void:
	if node is Panel and not ("slotData" in node):
		if node.has_signal("ready") and not node.is_connected("ready", Callable(self, "_on_item_ready")):
			node.ready.connect(Callable(self, "_on_item_ready").bind(node), CONNECT_ONE_SHOT)
		return
	if _is_item(node):
		var _t = Store.tier(node.slotData)
		if _t > 0 and _cfg != null and _cfg.debug_enabled:
			var _name: String = "?"
			if node.slotData != null and "itemData" in node.slotData and node.slotData.itemData != null:
				_name = str(node.slotData.itemData.name)
			Log.line("track NONVANILLA item " + _name + " tier=" + str(_t))
		if _cfg == null or _cfg.paint_cells:
			paint(node)
	for child in node.get_children():
		track(child)

func _on_item_ready(node: Node) -> void:
	if _is_item(node) and (_cfg == null or _cfg.paint_cells):
		paint(node)

func _scan_after_frame() -> void:
	if _scan_frames_remaining <= 0:
		var tree: SceneTree = _host.get_tree() if _host != null else null
		if tree != null and tree.process_frame.is_connected(_scan_after_frame):
			tree.process_frame.disconnect(_scan_after_frame)
		return
	_scan_frames_remaining -= 1
	if _host == null:
		return
	var tree: SceneTree = _host.get_tree()
	if tree == null:
		return
	_walk(tree.get_root())

func _walk(node: Node) -> void:
	if _is_item(node):
		if _cfg == null or _cfg.paint_cells:
			paint(node)
	for child in node.get_children():
		_walk(child)

func _is_item(node: Node) -> bool:
	return node is Panel and "slotData" in node

func paint(item) -> void:
	if item == null or item.slotData == null:
		return
	var tier: int = Store.tier(item.slotData)
	if tier <= 0:
		_drop_borders(item, null)
		return
	var overlay = _existing_border(item)
	_drop_borders(item, overlay)
	if overlay == null:
		overlay = Panel.new()
		overlay.name = BORDER_NAME
		overlay.set_meta(BORDER_TAG, true)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		item.add_child(overlay)
		item.move_child(overlay, 0)
	var style := StyleBoxFlat.new()
	style.draw_center = true
	var c: Color = _border_color(tier)
	c.a = 0.22
	style.bg_color = c
	style.set_border_width_all(0)
	overlay.add_theme_stylebox_override("panel", style)

# Nodes queued for deletion keep their slot in the parent until the frame ends,
# so a same-frame recreation of a same-named child is renamed by Godot
# (`_rtl_border2`). Overlays are therefore found and pruned by meta tag.
func _drop_borders(item, keep) -> void:
	for child in item.get_children():
		if child == null or child == keep or not child.has_meta(BORDER_TAG):
			continue
		item.remove_child(child)
		child.queue_free()

func _existing_border(item):
	for child in item.get_children():
		if child != null and child.has_meta(BORDER_TAG):
			return child
	return null

func _border_color(tier: int) -> Color:
	var palette: Dictionary = COLORS_DEFAULT
	if _cfg != null and _cfg.tier_palette == 1:
		palette = COLORS_CONTRAST
	return palette.get(tier, Color(1, 1, 1, 0))

func _inspect_tooltip(node: Node, depth: int = 0, path: String = "") -> void:
	if node == null or depth > 3:
		return
	var indent := ""
	for i in range(depth):
		indent += "  "
	Log.line(indent + path + node.get_class() + " name=" + str(node.name))
	for child in node.get_children():
		_inspect_tooltip(child, depth + 1, path + node.name + "/")

# `hint` is what the tooltip hook delivers: the hovered Item, not the Tooltip
# node (Tooltip.Update(item) is void, so the post-callback receives `item`).
func apply_tooltip(hint) -> void:
	var tooltip = _tooltip_node(hint)
	if tooltip == null:
		return
	if _cfg != null and _cfg.hide_vanilla_rarity:
		var vanilla_rarity = tooltip.get("rarity")
		if vanilla_rarity != null:
			vanilla_rarity.visible = false
	var item = null
	var iface = tooltip.get("interface")
	if iface != null:
		item = iface.get("hoverItem")
	if item == null and _is_item(hint):
		item = hint
	var item_id: int = item.get_instance_id() if item is Object else 0
	if item == null or item.slotData == null:
		_clear_all()
		return
	var tier: int = Store.tier(item.slotData)
	if tier > 0 and _last_tooltip_item_id != item_id:
		_last_tooltip_item_id = item_id
		Log.line("apply_tooltip item=" + str(item) + " tier=" + str(tier))
	if tier <= 0:
		_clear_all()
		return
	if _cfg != null and not _cfg.show_affix_block:
		_clear_all()
		return
	var type_node = tooltip.get("type")
	if type_node == null:
		type_node = tooltip.get_node_or_null("Panel/Margin/Elements/Type")
	var parent = type_node.get_parent() if type_node != null else tooltip.get_node_or_null("Panel/Margin/Elements")
	if parent == null:
		_clear_all()
		if not _did_inspect_tooltip:
			_did_inspect_tooltip = true
			Log.line("apply_tooltip: no Elements (tooltip=" + str(tooltip) + ")")
			_inspect_tooltip(tooltip)
		return
	# Ванильный Update() перезапускается каждые 10 физических кадров и каждый раз
	# возвращает ванильные тексты, поэтому сумма пересчитывается на каждом вызове.
	var merged: Array = _apply_merges(parent, item, tier)
	_sync_rows(parent, item, tier, item_id, merged)

# Tooltip.Update() is void -> the hook hands us `item`. The Item knows its
# Interface (set in Item.Initialize) and the Interface owns the Tooltip node.
func _tooltip_node(hint) -> Node:
	if hint == null:
		return null
	if hint is Node and hint.get("type") is Node:
		return hint
	if "interface" in hint and hint.interface != null:
		var from_item = hint.interface.get("tooltip")
		if from_item != null:
			return from_item
	var iface = _iface()
	if iface == null:
		return null
	return iface.get("tooltip")

# Строки пересобираются при следующем наведении (используется отладочным рероллом).
func invalidate_tooltip() -> void:
	_last_rows_item_id = 0

# Info tooltips reuse the same nodes as item tooltips; clear the rows so a
# stale affix list never shows up under a plain info panel.
func clear_tooltip() -> void:
	_last_tooltip_item_id = 0
	_last_merge_item_id = 0
	_clear_all()

# affix stat -> суммарное значение. Сумма живёт в чистой модели строк,
# чтобы тултип и строки не разошлись в округлении.
func _affix_map(item) -> Dictionary:
	return Rows.totals(Store.affixes(item.slotData))

# Ванильная база строки: ItemData.damage/capacity/insulation/protection.
# Имя поля берётся из MERGED_BASE: у carry база лежит в `capacity`.
func _base_value(item, stat: String) -> float:
	if item == null or not ("slotData" in item) or item.slotData == null:
		return 0.0
	if not ("itemData" in item.slotData):
		return 0.0
	var data = item.slotData.itemData
	if data == null:
		return 0.0
	var field: String = str(Pool.MERGED_BASE.get(stat, stat))
	if not (field in data):
		return 0.0
	var raw = data.get(field)
	return float(raw) if raw != null else 0.0

# Возвращает статы, вписанные в ванильные строки: своим строкам они не нужны.
# Строка не найдена/скрыта или база нулевая — стат остаётся в списке как своя строка.
func _apply_merges(parent, item, tier: int) -> Array:
	var iid: int = item.get_instance_id()
	if _last_merge_item_id != iid:
		_clear_merges()
		_last_merge_item_id = iid
	else:
		_clear_merges_values()
	var out: Array = []
	var by_stat: Dictionary = Rows.totals(Store.affixes(item.slotData))
	var color := _border_color(tier)
	for stat in Pool.MERGED:
		if not by_stat.has(stat):
			continue
		var row_name: String = str(Pool.MERGED[stat])
		var row = parent.find_child(row_name, false, false)
		if row == null or not (row is Label) or row.get_child_count() == 0 or not row.visible:
			continue
		var base_key: String = Pool.MERGED_BASE.get(stat, stat)
		var base: float = _base_value(item, base_key)
		if base <= 0.0:
			continue
		var value = row.get_child(0)
		value.text = Text.merged_value(stat, float(by_stat[stat]), base)
		value.modulate = color
		_merged_values.append(value)
		out.append(stat)
	return out

# Ваниль не сбрасывает modulate у значений: без этого цифра осталась бы
# покрашенной после перехода на предмет без тира.
func _clear_merges() -> void:
	_clear_merges_values()
	_last_merge_item_id = 0

func _clear_merges_values() -> void:
	for v in _merged_values:
		if is_instance_valid(v):
			v.modulate = Color(1, 1, 1, 1)
	_merged_values.clear()

func _sync_rows(parent, item, tier: int, item_id: int, merged: Array) -> void:
	var built: Dictionary = Rows.build(Store.affixes(item.slotData), merged, _border_color(tier))
	var specs: Array = built["rows"]
	if _cfg != null and _cfg.debug_enabled and not built["skipped"].is_empty() and not _warned_hidden:
		_warned_hidden = true
		Log.line("tooltip: affix stats not shown: " + str(built["skipped"]))
	if _rows_root != parent or _last_rows_item_id != item_id or _rows.size() != specs.size():
		_remove_rows()
		_sweep_rows(parent)
		_build_rows(parent, specs)
		_rows_root = parent
		_last_rows_item_id = item_id
		return
	for i in range(specs.size()):
		_write_row(_rows[i], specs[i])
	_rows_root = parent

# Клон ванильной строки Capacity: шрифт, кегль и сдвиг значения достаются
# бесплатно. Сдвиг пересчитывается от ширины текста, как это сделано в сцене.
func _build_rows(parent, specs: Array) -> void:
	if specs.is_empty():
		return
	var template = parent.find_child("Capacity", false, false)
	if template == null or not (template is Label) or template.get_child_count() == 0:
		if not _warned_template:
			_warned_template = true
			Log.warn("tooltip: no Capacity row to clone; affix rows skipped")
		return
	var template_value = template.get_child(0)
	var template_w: float = _text_width(template, template.text)
	var index: int = _rows_index(parent)
	for spec in specs:
		var row = template.duplicate()
		row.name = ROW_NAME
		row.set_meta(ROW_TAG, true)
		row.visible = true
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.text = str(spec["label"])
		# add_child до замера: отсоединённая копия не видит тему сцены, и ширина
		# подписи считалась бы фолбэк-шрифтом, а не Lora 12 из Theme.tres.
		parent.add_child(row)
		parent.move_child(row, index)
		index += 1
		var value = row.get_child(0)
		var shift: float = _text_width(row, row.text) - template_w
		value.offset_left = template_value.offset_left + shift
		value.offset_right = value.offset_left + ROW_VALUE_MIN_W
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rows.append(row)
		_write_row(row, spec)

func _write_row(row, spec: Dictionary) -> void:
	if row == null or not is_instance_valid(row) or row.get_child_count() == 0:
		return
	row.text = str(spec["label"])
	var value = row.get_child(0)
	value.text = str(spec["value"])
	value.modulate = spec["color"]

func _text_width(node, text: String) -> float:
	var font = node.get_theme_font("font")
	if font == null:
		return 0.0
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, node.get_theme_font_size("font_size")).x

# Строки идут на место блока: перед Nested, иначе в конец списка.
func _rows_index(parent) -> int:
	var nested = parent.find_child("Nested", false, false)
	if nested != null:
		return nested.get_index()
	return parent.get_child_count()

func _remove_rows() -> void:
	_last_rows_item_id = 0
	_rows.clear()
	var parent = _rows_root
	_rows_root = null
	if parent == null or not is_instance_valid(parent):
		return
	_sweep_rows(parent)

# remove_child до queue_free: удаляемый узел занимает слот до конца кадра,
# и замена с тем же именем получает суффикс `_rtl_stat2`.
func _sweep_rows(parent) -> void:
	for child in parent.get_children():
		if child != null and child.has_meta(ROW_TAG):
			parent.remove_child(child)
			child.queue_free()

func _clear_all() -> void:
	_remove_rows()
	_clear_merges()

func reroll_hovered(tree: SceneTree) -> bool:
	var iface = tree.get_root().get_node_or_null("Map/Core/UI/Interface")
	if iface == null:
		return false
	var item = iface.hoverItem if "hoverItem" in iface else null
	if item == null or item.slotData == null:
		return false
	if _host == null or not _host.has_method("reroll_item"):
		return false
	return _host.reroll_item(item)
