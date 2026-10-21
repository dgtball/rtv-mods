extends RefCounted

const Log = preload("res://mods/LooterShooter/LSHLog.gd")
const Store = preload("res://mods/LooterShooter/LSHStore.gd")
const Roll = preload("res://mods/LooterShooter/LSHRoll.gd")
const Pool = preload("res://mods/LooterShooter/LSHPool.gd")

const BORDER_NAME := "_lsh_border"
const BLOCK_NAME := "_lsh_affix_block"
const COLORS_DEFAULT := {1: Color(0.35, 0.6, 1.0), 2: Color(0.7, 0.4, 1.0), 3: Color(1.0, 0.8, 0.2)}
const COLORS_CONTRAST := {1: Color(0.1, 0.75, 1.0), 2: Color(1.0, 0.2, 0.9), 3: Color(1.0, 0.95, 0.1)}

var _cfg = null
var _host = null

func configure(cfg) -> void:
	_cfg = cfg

func set_host(h) -> void:
	_host = h

func attach(tree: SceneTree) -> void:
	if not tree.node_added.is_connected(track):
		tree.node_added.connect(track)
	_walk(tree.get_root())

func track(node: Node) -> void:
	if _is_item(node):
		if _cfg == null or _cfg.paint_cells:
			paint(node)

func _walk(node: Node) -> void:
	if _is_item(node):
		if _cfg == null or _cfg.paint_cells:
			paint(node)
	for child in node.get_children():
		_walk(child)

func _is_item(node: Node) -> bool:
	return node is Panel and "slotData" in node

func paint(item) -> void:
	var existing = item.get_node_or_null(BORDER_NAME)
	var tier: int = 0 if item.slotData == null else Store.tier(item.slotData)
	if tier <= 0:
		if existing != null:
			existing.queue_free()
		return
	var overlay = existing
	if overlay == null:
		overlay = Panel.new()
		overlay.name = BORDER_NAME
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		item.add_child(overlay)
		item.move_child(overlay, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.draw_center = false
	var w: float = 2.0 if _cfg == null else _cfg.border_width
	style.set_border_width_all(int(w))
	style.border_color = _border_color(tier)
	overlay.add_theme_stylebox_override("panel", style)

func _border_color(tier: int) -> Color:
	var palette: Dictionary = COLORS_DEFAULT
	if _cfg != null and _cfg.tier_palette == 1:
		palette = COLORS_CONTRAST
	return palette.get(tier, Color(1, 1, 1, 0))

func apply_tooltip(tooltip) -> void:
	if tooltip == null:
		return
	var item = tooltip.interface.hoverItem if "interface" in tooltip and tooltip.interface != null else null
	if item == null or item.slotData == null:
		_clear_block(tooltip)
		return
	if _cfg != null and not _cfg.show_affix_block:
		_clear_block(tooltip)
		return
	var tier: int = Store.tier(item.slotData)
	if tier <= 0:
		_clear_block(tooltip)
		return
	var info = tooltip.find_child("Info", true, false)
	var vbox = info.get_parent() if info != null else null
	if vbox == null:
		vbox = tooltip.find_child("Elements", true, false)
	if not (vbox is VBoxContainer) and not (vbox is BoxContainer):
		return
	var block = vbox.get_node_or_null(BLOCK_NAME)
	if block == null:
		block = RichTextLabel.new()
		block.name = BLOCK_NAME
		block.bbcode_enabled = true
		block.fit_content = true
		block.scroll_active = false
		block.autowrap_mode = TextServer.AUTOWRAP_WORD
		block.custom_minimum_size = Vector2(256.0, 0.0)
		block.mouse_filter = Control.MOUSE_FILTER_IGNORE
		block.add_theme_font_size_override("normal_font_size", 12)
		vbox.add_child(block)
		var idx: int = 0 if info == null else info.get_index() + 1
		vbox.move_child(block, idx)
	var hex := "#" + _border_color(tier).to_html(false)
	block.text = "[color=" + hex + "]" + Pool.TIER_NAMES.get(tier, "") + "[/color]\n"
	for a in Store.affixes(item.slotData):
		block.text += "[color=#cccccc]" + Roll.format_affix(a) + "[/color]\n"
	block.visible = true

func _clear_block(tooltip) -> void:
	var block = tooltip.find_child(BLOCK_NAME, true, false)
	if block != null:
		block.visible = false

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
