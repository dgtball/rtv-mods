extends CanvasLayer
# The F9 live tuning panel: a daylight calibration instrument, not a settings
# surface. Nine levers over the VTKNVG runtime fields, a source picker
# (Game light vs Measured frame), a readout of both sources at once, and a
# Measure button that renders one probe frame and logs the frame percentiles
# as a PANEL line for the fitting session.
#
# The panel persists nothing. The slider values live in the NVG fields until
# the helmet comes off or the map changes (VTKNVG._reset_daylight returns the
# levers to the model constants), so an accidental tweak cannot outlive the
# session, and no MCM key is involved.
#
# The ThermalVTK autoload owns this node: it creates the panel only while
# the debug log is on and frees it when the log goes off. open()/close() own
# the pause and the process modes EXACTLY -- every change is rolled back from
# the cache, never reset to a guessed default. The abandoned ThermalKey
# branch leaked PROCESS_MODE_ALWAYS into the whole game by "restoring" a
# hardcoded mode; that mistake is the reason this file is careful.

const Daylight = preload("res://mods/ThermalVTK/VTKDaylight.gd")
const Dbg = preload("res://mods/ThermalVTK/VTKDebug.gd")

# Readout cadence: 4 Hz is readable, and the values it shows are smoothed
# anyway (the daylight state itself ticks at 10 Hz).
const READOUT_EVERY := 0.25

var _nvg: Node = null
var _owner: Node = null
var _readout: Label = null
var _measure_label: Label = null
var _source_btn: OptionButton = null
# Lever rows, keyed by the NVG field name: {"slider", "label", "name"}.
var _rows := {}
var _open := false
var _readout_cd := 0.0
# The exact pre-open state that close() restores. The mode dictionary is
# keyed by node and only written when the key is absent: a reopen must not
# record PROCESS_MODE_ALWAYS as the "prior" mode (that is the leak, again).
var _prior_mouse: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _was_paused := false
var _prior_modes := {}

func setup(nvg: Node, owner: Node) -> void:
	_nvg = nvg
	_owner = owner
	name = "VTKLivePanel"
	layer = 20
	var pc := PanelContainer.new()
	pc.name = "Panel"
	pc.anchor_left = 0.0
	pc.anchor_right = 0.0
	pc.anchor_top = 0.0
	pc.anchor_bottom = 0.0
	pc.offset_left = 20.0
	pc.offset_right = 380.0
	pc.offset_top = 40.0
	pc.offset_bottom = 640.0
	add_child(pc)
	var box := VBoxContainer.new()
	box.name = "Column"
	pc.add_child(box)
	var title := Label.new()
	title.text = "ThermalVTK live panel (F9)"
	box.add_child(title)
	_source_btn = OptionButton.new()
	_source_btn.name = "Source"
	_source_btn.add_item("Game light")
	_source_btn.add_item("Measured frame")
	_source_btn.selected = int(_nvg.get("set_daylight_source"))
	_source_btn.item_selected.connect(_on_source_selected)
	box.add_child(_source_btn)
	_readout = Label.new()
	_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_readout)
	_add_slider(box, "Strength", 0.0, 1.0, 0.05, "set_strength")
	_add_slider(box, "Day target", 0.05, 1.0, 0.01, "set_day_target")
	_add_slider(box, "Day floor", 0.01, 1.0, 0.01, "set_day_floor")
	_add_slider(box, "Day trim", 0.40, 1.0, 0.01, "set_day_trim")
	_add_slider(box, "Frame target", 0.05, 0.90, 0.01, "set_frame_target")
	_add_slider(box, "Probe cadence", 0.25, 5.0, 0.25, "set_frame_cadence")
	_add_slider(box, "Highlight knee", 0.30, 1.0, 0.05, "set_highlight_knee")
	_add_slider(box, "World brightness", 1.0, 4.0, 0.05, "set_world")
	_add_slider(box, "NVG brightness", 0.05, 1.0, 0.01, "set_nvg_white")
	var row := HBoxContainer.new()
	row.name = "Buttons"
	box.add_child(row)
	_add_button(row, "Measure", _on_measure)
	_add_button(row, "Reset", _on_reset)
	_add_button(row, "Close", _on_close)
	_measure_label = Label.new()
	_measure_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_measure_label)
	# The probe belongs to VTKNVG now (source B rides on it in a normal game);
	# the panel just asks for a measurement through measure_frame().
	visible = false

# The ThermalKey _add_slider pattern: a caption label that live-updates with
# the value, plus the slider. The initial value comes from the CURRENT NVG
# field through set_value_no_signal, so opening the panel never nudges
# anything and closing it keeps whatever was dragged.
func _add_slider(box: Control, caption: String, mn: float, mx: float, step: float, field: String) -> void:
	var v := _lever(field)
	var l := Label.new()
	l.text = "%s: %.2f" % [caption, v]
	box.add_child(l)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.set_value_no_signal(clampf(v, mn, mx))
	box.add_child(s)
	s.value_changed.connect(func(val: float) -> void:
		l.text = "%s: %.2f" % [caption, val]
	)
	s.value_changed.connect(_on_lever.bind(field))
	_rows[field] = {"slider": s, "label": l, "name": caption}

func _add_button(row: Control, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	row.add_child(b)

func _lever(field: String) -> float:
	if _nvg == null or not is_instance_valid(_nvg):
		return 0.0
	return float(_nvg.get(field))

# Every lever change runs the same sequence: write the field, refresh the
# daylight state at once (refresh_daylight_now carries its own guards, so
# this is a harmless recompute for the uniform levers), then force a uniform
# push so the non-daylight levers land too.
func _on_lever(_value: float, field: String) -> void:
	if _nvg == null or not is_instance_valid(_nvg):
		return
	_nvg.set(field, _value)
	_nvg.refresh_daylight_now()
	_nvg.set("_dirty", true)
	_nvg._apply_uniforms()

# The source picker: switching to the measured frame seeds the feedback loop
# from the light estimate inside VTKNVG (see _sync_probe), so the picture does
# not jump. refresh_daylight_now applies the newly active source at once.
func _on_source_selected(idx: int) -> void:
	if _nvg == null or not is_instance_valid(_nvg):
		return
	_nvg.set("set_daylight_source", idx)
	_nvg.refresh_daylight_now()
	_nvg.set("_dirty", true)
	_nvg._apply_uniforms()

func is_open() -> bool:
	return _open

func open() -> void:
	if _open or _nvg == null or not is_instance_valid(_nvg):
		return
	_open = true
	# Cache the pre-open state BEFORE any change: close() rolls back exactly
	# this, not a guess.
	_prior_mouse = Input.mouse_mode
	_was_paused = get_tree().paused
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED
	get_tree().paused = true
	# The panel, the NVG tick and the autoload must keep running while the
	# game is paused: the readout needs the daylight tick to move, and F9 has
	# to keep reaching the autoload to close the panel again.
	_force_always(self)
	_force_always(_nvg)
	if _owner != null and is_instance_valid(_owner):
		_force_always(_owner)
	visible = true
	_readout_cd = 0.0
	_sync_sliders()

func close() -> void:
	if not _open:
		return
	_open = false
	# Exact rollback, in the reverse order of open(): the process modes from
	# the cache (then the cache goes -- a reopen records fresh priors), the
	# pause, the mouse, and only then the panel itself. The lever values stay:
	# the panel is a measurement tool, not a setting.
	for n in _prior_modes.keys():
		if n != null and is_instance_valid(n):
			n.process_mode = _prior_modes[n]
	_prior_modes.clear()
	get_tree().paused = _was_paused
	Input.mouse_mode = _prior_mouse
	visible = false

func _force_always(n: Node) -> void:
	if n == null or not is_instance_valid(n):
		return
	if not _prior_modes.has(n):
		_prior_modes[n] = n.process_mode
	n.process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if not _open:
		return
	_readout_cd -= delta
	if _readout_cd > 0.0:
		return
	_readout_cd = READOUT_EVERY
	_refresh_readout()

func _refresh_readout() -> void:
	if _nvg == null or not is_instance_valid(_nvg):
		return
	var e := _exposure()
	var e_txt := "-" if e < 0.0 else "%.2f" % e
	var src := "frame" if int(_nvg.get("set_daylight_source")) == 1 else "light"
	_readout.text = "src %s | E %.3f frame %.3f\nfactor %.3f (A %.3f B %.3f) mix %.2f bgTrim %.2f exp %s\nworld %.2f knee %.2f strength %.2f helmet %d thermal %d" % [
		src, float(_nvg.get("_light_est")), float(_nvg.get("_frame_l")),
		float(_nvg.get("_day_factor")), float(_nvg.get("_factor_a")), float(_nvg.get("_factor_b")),
		float(_nvg.get("_day_mix")),
		float(_nvg.get("_snow_trim")) * float(_nvg.get("_day_trim")), e_txt,
		float(_nvg.get("set_world")), float(_nvg.get("set_highlight_knee")), float(_nvg.get("set_strength")),
		1 if _nvg.nvg_active() else 0,
		1 if bool(_nvg.get("set_thermal")) else 0,
	]

# The live tonemap exposure the frame is rendered with, or -1 when the
# environment is not resolved (main menu, map change).
func _exposure() -> float:
	if _nvg == null or not is_instance_valid(_nvg):
		return -1.0
	var env = _nvg._environment()
	if env == null or not (env is Environment):
		return -1.0
	return (env as Environment).tonemap_exposure

# Resync the sliders and their captions with the current NVG fields without
# emitting signals: used on open (after MCM rewrote the fields) and after
# Reset.
func _sync_sliders() -> void:
	if _nvg == null or not is_instance_valid(_nvg):
		return
	if _source_btn != null:
		_source_btn.selected = int(_nvg.get("set_daylight_source"))
	for field in _rows.keys():
		var row: Dictionary = _rows[field]
		var s: HSlider = row["slider"]
		var l: Label = row["label"]
		var v: float = _lever(field)
		s.set_value_no_signal(clampf(v, s.min_value, s.max_value))
		l.text = "%s: %.2f" % [row["name"], v]

func _on_close() -> void:
	close()

# One probe frame, percentiles of it, and the PANEL line into the debug log:
# the whole calibration instrument in one button press. The probe lives on
# VTKNVG (measure_frame); the line format is fixed -- the fitting session
# parses it by whitespace.
func _on_measure() -> void:
	if _nvg == null or not is_instance_valid(_nvg):
		return
	var stats: Dictionary = await _nvg.measure_frame()
	if stats.is_empty():
		var fail := "measure failed (no camera or blank frame)"
		_measure_label.text = fail
		Dbg.log("PANEL", fail)
		return
	var line := _panel_line(stats)
	_measure_label.text = line
	Dbg.log("PANEL", line)

# light/factor/mix/trims/exp are the daylight state the levers produced;
# measured is the last frame the probe read (source B's input); raw p* are the
# probe frame percentiles BEFORE the thermal curve; pal p* push the same
# percentiles through the palette-input mirror at the current levers, i.e.
# where the palette would put them.
func _panel_line(stats: Dictionary) -> String:
	var snow: float = float(_nvg.get("_snow_trim"))
	var day: float = float(_nvg.get("_day_trim"))
	var mix: float = float(_nvg.get("_day_mix"))
	var darken: float = float(_nvg.get("set_world")) * snow * day
	var knee: float = float(_nvg.get("set_highlight_knee"))
	return "E=%.3f factor=%.2f measured=%.3f mix=%.2f snowTrim=%.2f dayTrim=%.2f exp=%.2f helmet=%d thermal=%d | raw p05=%.3f p25=%.3f p50=%.3f p75=%.3f p95=%.3f mean=%.3f black=%.3f cream=%.3f n=%d | pal p05=%.3f p50=%.3f p95=%.3f" % [
		float(_nvg.get("_light_est")), float(_nvg.get("_day_factor")), float(_nvg.get("_frame_l")), mix, snow, day, _exposure(),
		1 if _nvg.nvg_active() else 0,
		1 if bool(_nvg.get("set_thermal")) else 0,
		float(stats.p05), float(stats.p25), float(stats.p50), float(stats.p75), float(stats.p95),
		float(stats.mean), float(stats.black_share), float(stats.cream_share), int(stats.count),
		Daylight.palette_input(float(stats.p05), darken, knee, mix),
		Daylight.palette_input(float(stats.p50), darken, knee, mix),
		Daylight.palette_input(float(stats.p95), darken, knee, mix),
	]

# Reset puts every lever back: the MCM snapshot the autoload caches (the
# levers that live in MCM) and then the model constants MCM does not carry.
# The source flag is not a lever -- it is a comparison choice -- so it stays.
# One push at the end, and the sliders resync.
func _on_reset() -> void:
	if _nvg == null or not is_instance_valid(_nvg):
		return
	if _owner != null and is_instance_valid(_owner) and _owner.get("_rec") != null:
		_nvg.apply_config(_owner.get("_rec"))
	_nvg.set("set_day_target", Daylight.TARGET)
	_nvg.set("set_day_floor", Daylight.FLOOR)
	_nvg.set("set_day_trim", Daylight.DAY_TRIM)
	_nvg.set("set_frame_target", Daylight.FRAME_TARGET)
	_nvg.set("set_frame_cadence", Daylight.FRAME_CADENCE)
	_nvg.refresh_daylight_now()
	_nvg.set("_dirty", true)
	_nvg._apply_uniforms()
	_sync_sliders()
