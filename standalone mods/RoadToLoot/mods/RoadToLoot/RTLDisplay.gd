extends RefCounted

const Log = preload("res://mods/RoadToLoot/RTLLog.gd")
const Store = preload("res://mods/RoadToLoot/RTLStore.gd")
const Roll = preload("res://mods/RoadToLoot/RTLRoll.gd")
const Pool = preload("res://mods/RoadToLoot/RTLPool.gd")
const Sidecar = preload("res://mods/RoadToLoot/RTLSidecar.gd")

const BORDER_NAME := "_rtl_border"
const BORDER_TAG := "rtl_border"
const PASSIVE_BOX_NAME := "_rtl_passive_box"
const PASSIVE_TAG := "rtl_passive"
const COLORS_DEFAULT := {1: Color(0.35, 0.6, 1.0), 2: Color(0.7, 0.4, 1.0), 3: Color(1.0, 0.8, 0.2)}
const COLORS_CONTRAST := {1: Color(0.1, 0.75, 1.0), 2: Color(1.0, 0.2, 0.9), 3: Color(1.0, 0.95, 0.1)}

var _cfg = null
var _host = null
var _scan_frames_remaining: int = 0
var _last_tooltip_item_id: int = 0
var _last_tooltip_box_item_id: int = 0
var _did_inspect_tooltip: bool = false
var _box = null

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
		_drop_block()
		return
	var tier: int = Store.tier(item.slotData)
	if tier > 0 and _last_tooltip_item_id != item_id:
		_last_tooltip_item_id = item_id
		Log.line("apply_tooltip item=" + str(item) + " tier=" + str(tier))
	if tier <= 0:
		_drop_block()
		return
	if _cfg != null and not _cfg.show_affix_block:
		_drop_block()
		return
	# Read sidecar data for uid/plate (available for T3 tooltip display)
	var sidecar_data: Dictionary = Sidecar.read(item.slotData)
	var type_node = tooltip.get("type")
	if type_node == null:
		type_node = tooltip.find_child("Type", true, false)
	var parent = type_node.get_parent() if type_node != null else null
	if parent == null:
		parent = tooltip.find_child("Elements", true, false)
	if parent == null:
		_drop_block()
		if not _did_inspect_tooltip:
			_did_inspect_tooltip = true
			Log.line("apply_tooltip: no parent (type=" + str(type_node) + ")")
			_inspect_tooltip(tooltip)
		return

	# The tooltip is refreshed several times per second while hovering. The
	# block is ours, so leave it alone once it is built for this item: clearing
	# it here made it disappear before the tooltip delay even elapsed. The check
	# is on our own reference plus its parent, not on the node name: a
	# queued-for-deletion sibling makes Godot rename the replacement to
	# `_rtl_passive_box2`, and a name lookup then never matched again (the block
	# grew on every refresh). The parent check covers a rebuilt tooltip: the old
	# box is still alive but no longer inside the body we are writing into.
	if _box != null and is_instance_valid(_box) and _last_tooltip_box_item_id == item_id and _box.get_parent() == parent:
		return
	_drop_block()
	var box = VBoxContainer.new()
	box.name = PASSIVE_BOX_NAME
	box.set_meta(PASSIVE_TAG, true)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	var header = Label.new()
	header.text = "Passive - " + str(Pool.TIER_NAMES.get(tier, ""))
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(header)
	for a in Store.affixes(item.slotData):
		var line = Label.new()
		line.text = Roll.format_affix(a)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(line)
	parent.add_child(box)
	if type_node != null:
		parent.move_child(box, type_node.get_index() + 1)
	_box = box
	_last_tooltip_box_item_id = item_id
	Log.line("inserted passive box: " + str(item) + " tier=" + str(tier) + " type=" + str(type_node) + " parent=" + str(parent))

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

# Drop the block so the next hover builds it again (used by the debug re-roll).
func invalidate_tooltip() -> void:
	_last_tooltip_box_item_id = 0

# Info tooltips reuse the same nodes as item tooltips; clear the block so a
# stale affix list never shows up under a plain info panel.
func clear_tooltip() -> void:
	_last_tooltip_item_id = 0
	_drop_block()

# Remove our block from the tooltip. Detaching before queue_free() is what
# keeps the name free: a node queued for deletion still occupies its sibling
# slot until the end of the frame, so a box added right after it gets renamed.
func _drop_block() -> void:
	_last_tooltip_box_item_id = 0
	var old = _box
	_box = null
	if old == null or not is_instance_valid(old):
		return
	var parent = old.get_parent()
	if parent != null:
		parent.remove_child(old)
		_sweep_boxes(parent)
	old.queue_free()

# Leftovers from an earlier tooltip object (or from the rename bug) would stay
# in the tree otherwise: find_child() by name cannot see a renamed box.
func _sweep_boxes(parent) -> void:
	for child in parent.get_children():
		if child != null and child.has_meta(PASSIVE_TAG):
			parent.remove_child(child)
			child.queue_free()

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
