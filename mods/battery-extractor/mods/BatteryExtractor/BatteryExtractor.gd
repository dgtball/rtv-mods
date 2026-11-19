extends Node

const RULES := preload("res://mods/BatteryExtractor/BatteryRules.gd")
const BATTERIES_PATH := "res://Items/Electronics/Batteries/Batteries.tres"
const CONTEXT_HOOK := "context-update-post"
const CHARGE_HOOK := "interface-charge-post"

var _lib = null
var _partial_item = null
var _button = null
var _context = null


func _ready() -> void:
	if not Engine.has_meta("RTVModLib"):
		return
	_lib = Engine.get_meta("RTVModLib")
	if _lib.get("_is_ready"):
		_register()
	else:
		_lib.frameworks_ready.connect(_register)


func _register() -> void:
	if _lib == null:
		return
	_lib.hook(CONTEXT_HOOK, Callable(self, "_on_context_update"))
	_lib.hook(CHARGE_HOOK, Callable(self, "_on_charge_post"))


# The context node is cached because a button press has no hook caller of its
# own. Iterate from the hook each time so a rebuilt Interface cannot leave us
# pointing at a freed node.
func _interface():
	var ctx = _context
	if ctx == null or not is_instance_valid(ctx):
		return null
	var iface = ctx.get("interface")
	if iface == null or not is_instance_valid(iface):
		return null
	return iface


func _ensure_button(ctx) -> Button:
	if _button != null and is_instance_valid(_button):
		return _button
	var buttons = ctx.get_node_or_null("Panel/Margin/Buttons")
	if buttons == null or not (buttons is Node):
		return null
	var btn := Button.new()
	btn.name = "BatteryExtractorExtract"
	btn.text = "Extract battery"
	btn.focus_mode = Control.FOCUS_NONE
	for child in buttons.get_children():
		if child is Button:
			btn.add_theme_font_size_override("font_size", child.get_theme_font_size("font_size"))
			break
	btn.pressed.connect(_on_extract_pressed)
	buttons.add_child(btn)
	_button = btn
	return btn


func _hide_button() -> void:
	if _button != null and is_instance_valid(_button):
		_button.hide()


# context-update is void -> exactly one argument. The optional trailing
# parameter is arity insurance: callv with a missing defaulted argument works,
# while an unexpected extra argument is a silent no-op in Godot 4.6.3.
func _on_context_update(_slot_data, _result = null) -> void:
	var ctx = _lib._caller if _lib else null
	if ctx == null or not is_instance_valid(ctx):
		return
	_context = ctx
	var iface = ctx.get("interface")
	if iface == null or not is_instance_valid(iface):
		_hide_button()
		return
	var item = iface.get("contextItem")
	if item == null or not is_instance_valid(item):
		_hide_button()
		return
	var sd = item.get("slotData")
	if sd == null:
		_hide_button()
		return
	var data = sd.get("itemData")
	if data == null:
		_hide_button()
		return
	if not RULES.is_target(str(data.get("file"))):
		_hide_button()
		return
	if not RULES.can_extract(sd.get("condition")):
		_hide_button()
		return
	var btn := _ensure_button(ctx)
	if btn == null:
		return
	btn.show()


func _ensure_partial_item():
	if _partial_item == null:
		var base = load(BATTERIES_PATH)
		if base == null:
			return null
		var dup = base.duplicate()
		if not RULES.mark_partial(dup):
			return null
		_partial_item = dup
	return _partial_item


func _on_extract_pressed() -> void:
	var iface = _interface()
	if iface == null:
		return
	var item = iface.get("contextItem")
	if item == null or not is_instance_valid(item):
		return
	var sd = item.get("slotData")
	if sd == null:
		return
	var data = sd.get("itemData")
	if data == null or not RULES.is_target(str(data.get("file"))):
		return
	var condition = sd.get("condition")
	if not RULES.can_extract(condition):
		return
	var partial = _ensure_partial_item()
	if partial == null:
		return
	var new_sd = SlotData.new()
	new_sd.itemData = partial
	new_sd.condition = RULES.charge_for(condition)
	new_sd.amount = 0
	var grid = iface.get("contextGrid")
	if grid == null:
		grid = iface.get("inventoryGrid")
	iface.Create(new_sd, grid, true)
	sd.set("condition", 0)
	if item.has_method("UpdateDetails"):
		item.UpdateDetails()
	iface.HideContext()
	iface.PlayAttach()


# Charge is void with two arguments; the trailing default is the same arity
# insurance as above. Vanilla sets condition = 100 only after the progress bar
# completes, so queue a one-shot that overwrites it with the stored charge.
# Ordinary batteries carry no marker and never reach this code.
func _on_charge_post(target_item, source_item, _result = null) -> void:
	if source_item == null or not is_instance_valid(source_item):
		return
	var sd = source_item.get("slotData")
	if sd == null:
		return
	if not RULES.is_partial(sd.get("itemData")):
		return
	var iface = _lib._caller if _lib else null
	if iface == null or not is_instance_valid(iface):
		return
	var progress = iface.get("activeProgress")
	if progress == null or not is_instance_valid(progress):
		return
	if not progress.has_signal("completed"):
		return
	var charge: float = RULES.charge_for(sd.get("condition"))
	progress.completed.connect(_apply_partial_charge.bind(target_item, charge), Object.CONNECT_ONE_SHOT)


func _apply_partial_charge(target_item, charge) -> void:
	if target_item == null or not is_instance_valid(target_item):
		return
	var iface = target_item.get("interface")
	if iface != null and is_instance_valid(iface):
		var gd = iface.get("gameData")
		if gd != null and bool(gd.get("isDead")):
			return
	var sd = target_item.get("slotData")
	if sd == null:
		return
	sd.set("condition", charge)
	if target_item.has_method("UpdateDetails"):
		target_item.UpdateDetails()
