extends CanvasLayer
# Runtime ESP calibration panel (debug tool, default F8). It pauses the game
# while open, applies changes live to VTKESP/VTKNVG, and persists nothing: Reset
# restores the settings snapshot captured on open, Close discards nothing extra
# because values are not written to MCM.
#
# The panel exists only while the debug log is on (ThermalVTK gates the hotkey
# and owns the node lifetime).

const States = preload("res://mods/ThermalVTK/VTKStates.gd")
const VTKDebug = preload("res://mods/ThermalVTK/VTKDebug.gd")

var _esp: Node = null
var _nvg: Node = null
var _owner: Node = null
var _open: bool = false
var _toggle_key: int = KEY_F8

var _root: Control = null
var _panel: PanelContainer = null
var _status: Label = null

# Saved runtime state for rollback.
var _saved: Dictionary = {}
var _prev_mouse_mode: int = Input.MOUSE_MODE_VISIBLE
var _prev_paused: bool = false
var _prev_esp_process_mode: int = Node.PROCESS_MODE_INHERIT

# Widgets
var _esp_enabled: CheckBox = null
var _fill_mode: OptionButton = null
var _rim: HSlider = null
var _thickness: HSlider = null
var _brightness: HSlider = null
var _fill_alpha: HSlider = null
var _distance: HSlider = null
var _cooling: HSlider = null
var _xray: CheckBox = null
var _nomad: CheckBox = null
var _labels: CheckBox = null
var _c_normal: ColorPickerButton = null
var _c_combat: ColorPickerButton = null
var _c_defend: ColorPickerButton = null
var _c_mine: ColorPickerButton = null

var _suppress: bool = false

func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false

func setup(esp: Node, nvg: Node, owner: Node, toggle_key: int = KEY_F8) -> void:
	_esp = esp
	_nvg = nvg
	_owner = owner
	_toggle_key = toggle_key if toggle_key != 0 else KEY_F8

func is_open() -> bool:
	return _open

func open() -> void:
	if _open:
		return
	if _esp == null or not is_instance_valid(_esp):
		return
	_snapshot()
	_sync_from_runtime()
	_prev_mouse_mode = Input.mouse_mode
	_prev_paused = get_tree().paused
	_prev_esp_process_mode = _esp.process_mode
	# Keep ESP processing while paused so outline/material changes apply live.
	_esp.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true
	_open = true
	_refresh_status()
	_apply_live()

func close() -> void:
	if not _open:
		return
	visible = false
	_open = false
	if _esp != null and is_instance_valid(_esp):
		_esp.process_mode = _prev_esp_process_mode
	get_tree().paused = _prev_paused
	Input.mouse_mode = _prev_mouse_mode
	# Apply once more on close so the live scene reflects final values.
	_apply_live()

func _snapshot() -> void:
	_saved.clear()
	if _esp == null or not is_instance_valid(_esp):
		return
	_saved = {
		"body_fill": bool(_esp.p_body_fill),
		"rim": float(_esp.p_rim),
		"thickness": float(_esp.p_thickness),
		"fill_alpha": float(_esp.p_fill_alpha),
		"dist": float(_esp.p_dist),
		"decay": float(_esp.p_decay),
		"trig": bool(_esp.p_trig),
		"nomad": bool(_esp.p_nomad_marker),
		"labels": bool(_esp.p_npc_labels),
		"c_normal": Color(_esp.p_color_normal),
		"c_combat": Color(_esp.p_color_combat),
		"c_defend": Color(_esp.p_color_defend),
		"esp_preview_on": bool(_esp.contour_layer or _esp.xray_layer),
	}
	if _nvg != null and is_instance_valid(_nvg):
		_saved["brightness"] = float(_nvg.set_state_brightness)
		_saved["c_mine"] = Color(_nvg.mine_color())
		_saved["nvg_colors"] = Dictionary(_nvg._state_colors).duplicate(true)
	else:
		_saved["brightness"] = 0.6
		_saved["c_mine"] = States.DEFAULT_MINE
		_saved["nvg_colors"] = {}

func _restore_snapshot() -> void:
	if _esp == null or not is_instance_valid(_esp):
		return
	_esp.p_body_fill = bool(_saved.get("body_fill", false))
	_esp.p_rim = float(_saved.get("rim", 2.0))
	_esp.p_thickness = float(_saved.get("thickness", 0.006))
	_esp.p_fill_alpha = float(_saved.get("fill_alpha", 0.4))
	_esp.p_dist = float(_saved.get("dist", 60.0))
	_esp.p_decay = float(_saved.get("decay", 90.0))
	_esp.p_trig = bool(_saved.get("trig", true))
	_esp.p_nomad_marker = bool(_saved.get("nomad", true))
	_esp.p_npc_labels = bool(_saved.get("labels", false))
	_esp.p_color_normal = Color(_saved.get("c_normal", States.DEFAULT_NORMAL))
	_esp.p_color_combat = Color(_saved.get("c_combat", States.DEFAULT_COMBAT))
	_esp.p_color_defend = Color(_saved.get("c_defend", States.DEFAULT_DEFEND))
	if _nvg != null and is_instance_valid(_nvg):
		_nvg.set_state_brightness = float(_saved.get("brightness", 0.6))
		var cols = _saved.get("nvg_colors", {})
		if cols is Dictionary and not cols.is_empty():
			_nvg.set_state_colors(cols)
		_nvg.set_mine_color(Color(_saved.get("c_mine", States.DEFAULT_MINE)))
	_apply_nvg_side()
	_sync_from_runtime()
	if _esp_enabled != null:
		_esp_enabled.button_pressed = bool(_saved.get("esp_preview_on", true))
	_refresh_status()
	_apply_live()

func _sync_from_runtime() -> void:
	if _esp == null or not is_instance_valid(_esp):
		return
	_suppress = true
	if _esp_enabled != null:
		_esp_enabled.button_pressed = bool(_esp.contour_layer or _esp.xray_layer)
	_fill_mode.selected = 1 if bool(_esp.p_body_fill) else 0
	_rim.value = float(_esp.p_rim)
	_thickness.value = float(_esp.p_thickness)
	_fill_alpha.value = float(_esp.p_fill_alpha)
	_distance.value = float(_esp.p_dist)
	_cooling.value = float(_esp.p_decay)
	_xray.button_pressed = bool(_esp.p_trig)
	_nomad.button_pressed = bool(_esp.p_nomad_marker)
	_labels.button_pressed = bool(_esp.p_npc_labels)
	_c_normal.color = Color(_esp.p_color_normal)
	_c_combat.color = Color(_esp.p_color_combat)
	_c_defend.color = Color(_esp.p_color_defend)
	if _nvg != null and is_instance_valid(_nvg):
		_brightness.value = float(_nvg.set_state_brightness)
		_c_mine.color = Color(_nvg.mine_color())
	else:
		_brightness.value = 0.6
		_c_mine.color = States.DEFAULT_MINE
	_suppress = false

func _apply_nvg_side() -> void:
	if _nvg == null or not is_instance_valid(_nvg):
		return
	if _esp != null and is_instance_valid(_esp):
		_nvg.set_esp_fill(bool(_esp.p_body_fill), float(_esp.p_fill_alpha))
		_nvg.set_state_colors({
			"state_normal": Color(_esp.p_color_normal),
			"state_combat": Color(_esp.p_color_combat),
			"state_defend": Color(_esp.p_color_defend),
		})
	_nvg.set_mine_color(_c_mine.color if _c_mine != null else States.DEFAULT_MINE)

func _on_changed(_v = null) -> void:
	if _suppress or _esp == null or not is_instance_valid(_esp):
		return
	_esp.p_body_fill = (_fill_mode.selected == 1)
	_esp.p_rim = float(_rim.value)
	_esp.p_thickness = float(_thickness.value)
	_esp.p_fill_alpha = float(_fill_alpha.value)
	_esp.p_dist = float(_distance.value)
	_esp.p_decay = float(_cooling.value)
	_esp.p_trig = bool(_xray.button_pressed)
	_esp.p_nomad_marker = bool(_nomad.button_pressed)
	_esp.p_npc_labels = bool(_labels.button_pressed)
	_esp.p_color_normal = Color(_c_normal.color)
	_esp.p_color_combat = Color(_c_combat.color)
	_esp.p_color_defend = Color(_c_defend.color)
	if _nvg != null and is_instance_valid(_nvg):
		_nvg.set_state_brightness = float(_brightness.value)
		_nvg.set_mine_color(Color(_c_mine.color))
	_apply_nvg_side()
	_refresh_status()
	_apply_live()

func _apply_live() -> void:
	if _nvg != null and is_instance_valid(_nvg):
		_nvg._dirty = true
		if _nvg.has_method("_apply_uniforms"):
			_nvg._apply_uniforms()
	if _esp != null and is_instance_valid(_esp):
		# Runtime preview toggle: allow disabling ESP layers to compare with
		# another mod, without touching saved MCM settings.
		if _esp_enabled != null and not bool(_esp_enabled.button_pressed):
			_esp.set_layers(false, false)
		else:
			if _owner != null and is_instance_valid(_owner) and _owner.has_method("_apply_mode"):
				_owner._apply_mode()
		if _esp.has_method("refresh_outlines_now"):
			_esp.refresh_outlines_now()
		# Keep NVG fill mode in sync with ESP's current body_fill/alpha.
		if _nvg != null and is_instance_valid(_nvg) and _nvg.has_method("set_esp_fill"):
			_nvg.set_esp_fill(bool(_esp.p_body_fill), float(_esp.p_fill_alpha))

func _refresh_status() -> void:
	if _status == null:
		return
	var mode := "FILL" if _fill_mode != null and _fill_mode.selected == 1 else "OUTLINE"
	var esp_on := _esp_enabled == null or bool(_esp_enabled.button_pressed)
	_status.text = "ESP: %s  |  Mode: %s  |  Rim %.2f  Thickness %.4f  Bright %.2f  Alpha %.2f  Dist %.0f  Cool %.0f" % [
		"ON" if esp_on else "OFF",
		mode,
		_rim.value if _rim != null else 0.0,
		_thickness.value if _thickness != null else 0.0,
		_brightness.value if _brightness != null else 0.0,
		_fill_alpha.value if _fill_alpha != null else 0.0,
		_distance.value if _distance != null else 0.0,
		_cooling.value if _cooling != null else 0.0,
	]

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.35)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -360
	_panel.offset_right = 360
	_panel.offset_top = -320
	_panel.offset_bottom = 320
	_root.add_child(_panel)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 620)
	_panel.add_child(scroll)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	scroll.add_child(v)

	var title := Label.new()
	title.text = "ESP Live Tuning (runtime only, not saved)"
	v.add_child(title)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_status)

	v.add_child(HSeparator.new())

	_esp_enabled = _add_check(v, "ESP enabled (preview)", true)
	_fill_mode = _add_option(v, "Mode", ["Outline", "FILL (flat body)"])
	_rim = _add_slider(v, "Rim", 0.0, 6.0, 0.5, 2.0)
	_thickness = _add_slider(v, "Thickness (grow)", 0.0005, 0.02, 0.0005, 0.006)
	_brightness = _add_slider(v, "State brightness", 0.1, 3.0, 0.1, 0.6)
	_fill_alpha = _add_slider(v, "Fill alpha", 0.05, 1.0, 0.05, 0.4)
	_distance = _add_slider(v, "Distance", 0.0, 300.0, 10.0, 60.0)
	_cooling = _add_slider(v, "Cooling time (s)", 0.0, 180.0, 1.0, 90.0)

	v.add_child(HSeparator.new())
	_xray = _add_check(v, "X-ray triggers", true)
	_nomad = _add_check(v, "Nomad marker", true)
	_labels = _add_check(v, "NPC labels (debug)", false)

	v.add_child(HSeparator.new())
	var cl := Label.new()
	cl.text = "State / marker colors"
	v.add_child(cl)
	_c_normal = _add_color(v, "Normal", States.DEFAULT_NORMAL)
	_c_combat = _add_color(v, "Combat", States.DEFAULT_COMBAT)
	_c_defend = _add_color(v, "Defend", States.DEFAULT_DEFEND)
	_c_mine = _add_color(v, "Mine", States.DEFAULT_MINE)

	v.add_child(HSeparator.new())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var reset_btn := Button.new()
	reset_btn.text = "Reset"
	reset_btn.pressed.connect(_restore_snapshot)
	row.add_child(reset_btn)
	var log_btn := Button.new()
	log_btn.text = "Log snapshot"
	log_btn.pressed.connect(_log_snapshot)
	row.add_child(log_btn)
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(close)
	row.add_child(close_btn)

	var hint := Label.new()
	hint.text = "Changes apply live and are not saved to MCM. Reset restores values from panel open."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)

func _add_option(parent: Control, label_text: String, items: Array) -> OptionButton:
	var h := HBoxContainer.new()
	parent.add_child(h)
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size = Vector2(220, 0)
	h.add_child(l)
	var ob := OptionButton.new()
	for it in items:
		ob.add_item(str(it))
	ob.item_selected.connect(func(_i): _on_changed())
	h.add_child(ob)
	return ob

func _add_slider(parent: Control, label_text: String, mn: float, mx: float, step: float, def: float) -> HSlider:
	var h := HBoxContainer.new()
	parent.add_child(h)
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size = Vector2(220, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.value = def
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(320, 0)
	s.value_changed.connect(_on_changed)
	h.add_child(s)
	var val := Label.new()
	val.custom_minimum_size = Vector2(70, 0)
	val.text = str(def)
	s.value_changed.connect(func(v): val.text = "%.3f" % v)
	h.add_child(val)
	return s

func _add_check(parent: Control, label_text: String, def: bool) -> CheckBox:
	var cb := CheckBox.new()
	cb.text = label_text
	cb.button_pressed = def
	cb.toggled.connect(func(_v): _on_changed())
	parent.add_child(cb)
	return cb

func _add_color(parent: Control, label_text: String, def: Color) -> ColorPickerButton:
	var h := HBoxContainer.new()
	parent.add_child(h)
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size = Vector2(220, 0)
	h.add_child(l)
	var cp := ColorPickerButton.new()
	cp.color = def
	cp.custom_minimum_size = Vector2(120, 28)
	cp.color_changed.connect(func(_c): _on_changed())
	h.add_child(cp)
	return cp

func _color_hex(c: Color) -> String:
	return "#%02x%02x%02x" % [int(round(c.r * 255.0)), int(round(c.g * 255.0)), int(round(c.b * 255.0))]

func _log_snapshot() -> void:
	if _esp == null or not is_instance_valid(_esp):
		return
	var mode := "FILL" if _fill_mode != null and _fill_mode.selected == 1 else "OUTLINE"
	var esp_on := _esp_enabled == null or bool(_esp_enabled.button_pressed)
	var bright := float(_brightness.value) if _brightness != null else 0.0
	var mine_c: Color = _c_mine.color if _c_mine != null else States.DEFAULT_MINE
	var parts: Array[String] = []
	parts.append("mode=%s" % mode)
	parts.append("esp_enabled=%s" % str(esp_on))
	parts.append("rim=%.3f" % float(_rim.value))
	parts.append("thickness=%.4f" % float(_thickness.value))
	parts.append("state_brightness=%.3f" % bright)
	parts.append("fill_alpha=%.3f" % float(_fill_alpha.value))
	parts.append("distance=%.1f" % float(_distance.value))
	parts.append("cooling=%.1f" % float(_cooling.value))
	parts.append("xray=%s" % str(bool(_xray.button_pressed)))
	parts.append("nomad=%s" % str(bool(_nomad.button_pressed)))
	parts.append("labels=%s" % str(bool(_labels.button_pressed)))
	parts.append("normal=%s" % _color_hex(_c_normal.color))
	parts.append("combat=%s" % _color_hex(_c_combat.color))
	parts.append("defend=%s" % _color_hex(_c_defend.color))
	parts.append("mine=%s" % _color_hex(mine_c))
	VTKDebug.log("ESP_PANEL", "snapshot " + " ".join(parts))

func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
			return
		# Toggle key closes the panel even while the tree is paused.
		if _toggle_key != 0 and (k.keycode == _toggle_key or k.physical_keycode == _toggle_key):
			if _owner != null and is_instance_valid(_owner) and _owner.has_method("_toggle_esp_panel"):
				_owner._toggle_esp_panel()
			else:
				close()
			get_viewport().set_input_as_handled()
			return
	# While open the panel owns the input; prevent game actions.
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		get_viewport().set_input_as_handled()
