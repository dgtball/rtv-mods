extends CanvasLayer
# Runtime ESP calibration panel (debug tool, default F8). It pauses the game
# while open, applies changes live to VTKESP/materials, and persists nothing:
# Reset restores the settings snapshot captured on open, Close discards nothing
# extra because values are not written to MCM.
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
var _prev_owner_process_mode: int = Node.PROCESS_MODE_INHERIT

# Widgets
var _esp_enabled: CheckBox = null
var _fill_mode: OptionButton = null
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
var _palette_strength: HSlider = null
var _red_hold: HSlider = null

var _suppress: bool = false
var _last_change_log_ms: int = -100000

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
	if _owner != null and is_instance_valid(_owner):
		_prev_owner_process_mode = _owner.process_mode
	# Keep ESP/owner processing while paused so material and NVG-substitution
	# changes (brightness/colors) apply live.
	_esp.process_mode = Node.PROCESS_MODE_ALWAYS
	if _owner != null and is_instance_valid(_owner):
		_owner.process_mode = Node.PROCESS_MODE_ALWAYS
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
	if _owner != null and is_instance_valid(_owner):
		_owner.process_mode = _prev_owner_process_mode
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
		"thickness": float(_esp.p_thickness),
		"brightness": float(_esp.p_brightness),
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
	if _nvg != null and is_instance_valid(_nvg) and _nvg.has_method("mine_color"):
		_saved["c_mine"] = Color(_nvg.mine_color())
	else:
		_saved["c_mine"] = States.DEFAULT_MINE
	if _nvg != null and is_instance_valid(_nvg):
		_saved["palette_strength"] = float(_nvg.get("set_palette_strength")) if _nvg.get("set_palette_strength") != null else 0.58
		_saved["red_hold"] = float(_nvg.get("set_red_hold")) if _nvg.get("set_red_hold") != null else 0.72
	else:
		_saved["palette_strength"] = 0.58
		_saved["red_hold"] = 0.72

func _restore_snapshot() -> void:
	if _esp == null or not is_instance_valid(_esp):
		return
	_esp.p_body_fill = bool(_saved.get("body_fill", false))
	_esp.p_thickness = float(_saved.get("thickness", 0.006))
	_esp.p_brightness = float(_saved.get("brightness", 0.6))
	_esp.p_fill_alpha = float(_saved.get("fill_alpha", 0.4))
	_esp.p_dist = float(_saved.get("dist", 60.0))
	_esp.p_decay = float(_saved.get("decay", 90.0))
	_esp.p_trig = bool(_saved.get("trig", true))
	_esp.p_nomad_marker = bool(_saved.get("nomad", true))
	_esp.p_npc_labels = bool(_saved.get("labels", false))
	_esp.p_color_normal = Color(_saved.get("c_normal", States.DEFAULT_NORMAL))
	_esp.p_color_combat = Color(_saved.get("c_combat", States.DEFAULT_COMBAT))
	_esp.p_color_defend = Color(_saved.get("c_defend", States.DEFAULT_DEFEND))
	_apply_mine_color(Color(_saved.get("c_mine", States.DEFAULT_MINE)))
	if _nvg != null and is_instance_valid(_nvg):
		if _nvg.has_method("set_palette_tuning"):
			_nvg.set_palette_tuning(float(_saved.get("palette_strength", 0.58)), float(_saved.get("red_hold", 0.72)))
		else:
			_nvg.set("set_palette_strength", float(_saved.get("palette_strength", 0.58)))
			_nvg.set("set_red_hold", float(_saved.get("red_hold", 0.72)))
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
	_thickness.value = float(_esp.p_thickness)
	_brightness.value = float(_esp.p_brightness)
	_fill_alpha.value = float(_esp.p_fill_alpha)
	_distance.value = float(_esp.p_dist)
	_cooling.value = float(_esp.p_decay)
	_xray.button_pressed = bool(_esp.p_trig)
	_nomad.button_pressed = bool(_esp.p_nomad_marker)
	_labels.button_pressed = bool(_esp.p_npc_labels)
	_c_normal.color = Color(_esp.p_color_normal)
	_c_combat.color = Color(_esp.p_color_combat)
	_c_defend.color = Color(_esp.p_color_defend)
	if _nvg != null and is_instance_valid(_nvg) and _nvg.has_method("mine_color"):
		_c_mine.color = Color(_nvg.mine_color())
	else:
		_c_mine.color = States.DEFAULT_MINE
	if _palette_strength != null:
		if _nvg != null and is_instance_valid(_nvg):
			var vs = _nvg.get("set_palette_strength")
			_palette_strength.value = float(vs) if vs != null else 0.58
		else:
			_palette_strength.value = 0.58
	if _red_hold != null:
		if _nvg != null and is_instance_valid(_nvg):
			var vh = _nvg.get("set_red_hold")
			_red_hold.value = float(vh) if vh != null else 0.72
		else:
			_red_hold.value = 0.72
	_suppress = false

func _apply_mine_color(c: Color) -> void:
	if _nvg != null and is_instance_valid(_nvg) and _nvg.has_method("set_mine_color"):
		_nvg.set_mine_color(c)

func _on_changed(_v = null) -> void:
	if _suppress or _esp == null or not is_instance_valid(_esp):
		return
	_esp.p_body_fill = (_fill_mode.selected == 1)
	_esp.p_thickness = float(_thickness.value)
	_esp.p_brightness = float(_brightness.value)
	_esp.p_fill_alpha = float(_fill_alpha.value)
	_esp.p_dist = float(_distance.value)
	_esp.p_decay = float(_cooling.value)
	_esp.p_trig = bool(_xray.button_pressed)
	_esp.p_nomad_marker = bool(_nomad.button_pressed)
	_esp.p_npc_labels = bool(_labels.button_pressed)
	_esp.p_color_normal = Color(_c_normal.color)
	_esp.p_color_combat = Color(_c_combat.color)
	_esp.p_color_defend = Color(_c_defend.color)
	_apply_mine_color(Color(_c_mine.color) if _c_mine != null else States.DEFAULT_MINE)
	if _nvg != null and is_instance_valid(_nvg):
		var vs := float(_palette_strength.value) if _palette_strength != null else 0.58
		var vh := float(_red_hold.value) if _red_hold != null else 0.72
		if _nvg.has_method("set_palette_tuning"):
			_nvg.set_palette_tuning(vs, vh)
		else:
			_nvg.set("set_palette_strength", vs)
			_nvg.set("set_red_hold", vh)
	_refresh_status()
	_apply_live()
	var now_ms := Time.get_ticks_msec()
	if VTKDebug.enabled and now_ms - _last_change_log_ms >= 400:
		_last_change_log_ms = now_ms
		var mode := "FILL" if _fill_mode != null and _fill_mode.selected == 1 else "OUTLINE"
		var esp_on := _esp_enabled == null or bool(_esp_enabled.button_pressed)
		VTKDebug.log("ESP_PANEL", "change mode=%s esp_enabled=%s xray=%s distance=%.1f contour=%s xray_layer=%s" % [
			mode, str(esp_on), str(bool(_xray.button_pressed if _xray != null else false)),
			float(_distance.value if _distance != null else 0.0),
			str(bool(_esp.contour_layer)), str(bool(_esp.xray_layer)),
		])
		if _esp.has_method("dump_distance_debug"):
			_esp.dump_distance_debug("panel_change")

func _apply_live() -> void:
	if _esp == null or not is_instance_valid(_esp):
		return
	# Runtime preview toggle: allow disabling ESP layers to compare with
	# another mod, without touching saved MCM settings.
	var preview_on := _esp_enabled == null or bool(_esp_enabled.button_pressed)
	if not preview_on:
		VTKDebug.log("ESP_LAYER", "esp_panel preview_off esp_enabled=false xray_ui=%s" % [
			str(_xray == null or bool(_xray.button_pressed)),
		])
		_esp.set_layers(false, false, "esp_panel_preview_off")
	elif _owner != null and is_instance_valid(_owner) and _owner.has_method("_set_esp_layers_for_preview"):
		_owner._set_esp_layers_for_preview(_xray == null or bool(_xray.button_pressed))
	elif _owner != null and is_instance_valid(_owner) and _owner.has_method("_apply_mode"):
		_owner._apply_mode()
	else:
		_esp.set_layers(true, _xray == null or bool(_xray.button_pressed), "esp_panel_fallback")
	if _esp.has_method("refresh_outlines_now"):
		_esp.refresh_outlines_now()

func _refresh_status() -> void:
	if _status == null:
		return
	var mode := "FILL" if _fill_mode != null and _fill_mode.selected == 1 else "OUTLINE"
	var esp_on := _esp_enabled == null or bool(_esp_enabled.button_pressed)
	# Both sliders only reach the fill body: in outline mode the contour is the
	# ring and brightness comes from the plain Brightness slider. Greying them
	# out stops "it does nothing" reports from an outline session.
	var fill_on := _fill_mode != null and _fill_mode.selected == 1
	if _fill_alpha != null:
		_fill_alpha.editable = true
	_status.text = "ESP: %s  |  Mode: %s  |  Thickness %.4f  Bright %.2f  Fill %.2f  Dist %.0f  Cool %.0f" % [
		"ON" if esp_on else "OFF",
		mode,
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
	_thickness = _add_slider(v, "Thickness (rim/offset)", 0.0005, 0.02, 0.0005, 0.0005)
	_brightness = _add_slider(v, "Brightness", 0.1, 3.0, 0.1, 0.7)
	_fill_alpha = _add_slider(v, "fill_alpha", 0.05, 1.0, 0.05, 0.6)
	_distance = _add_slider(v, "Distance", 0.0, 300.0, 10.0, 60.0)
	_cooling = _add_slider(v, "Cooling time (s)", 0.0, 180.0, 1.0, 70.0)

	v.add_child(HSeparator.new())
	_xray = _add_check(v, "X-ray triggers", false)
	_nomad = _add_check(v, "Nomad marker", true)
	_labels = _add_check(v, "NPC labels (debug)", true)
	_fill_mode.selected = 1

	v.add_child(HSeparator.new())
	var cl := Label.new()
	cl.text = "State / marker colors"
	v.add_child(cl)
	_c_normal = _add_color(v, "Normal", States.DEFAULT_NORMAL)
	_c_combat = _add_color(v, "Combat", States.DEFAULT_COMBAT)
	_c_defend = _add_color(v, "Defend", States.DEFAULT_DEFEND)
	_c_mine = _add_color(v, "Mine", States.DEFAULT_MINE)

	v.add_child(HSeparator.new())
	var wl := Label.new()
	wl.text = "World palette (NVG, runtime only)"
	v.add_child(wl)
	_palette_strength = _add_slider(v, "Strength", 0.0, 1.0, 0.05, 0.58)
	_red_hold = _add_slider(v, "Red hold", 0.0, 1.0, 0.05, 0.72)

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
	parts.append("contour_layer=%s" % str(bool(_esp.contour_layer)))
	parts.append("xray_layer=%s" % str(bool(_esp.xray_layer)))
	parts.append("thickness=%.4f" % float(_thickness.value))
	parts.append("brightness=%.3f" % bright)
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
	if _palette_strength != null:
		parts.append("palette_strength=%.3f" % float(_palette_strength.value))
	if _red_hold != null:
		parts.append("red_hold=%.3f" % float(_red_hold.value))
	VTKDebug.log("ESP_PANEL", "snapshot " + " ".join(parts))
	if _esp.has_method("dump_distance_debug"):
		_esp.dump_distance_debug("panel_snapshot")

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
