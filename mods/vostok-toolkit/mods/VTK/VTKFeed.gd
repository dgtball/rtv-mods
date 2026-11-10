extends Control
const Paths = preload("res://mods/VTK/VTKPaths.gd")
const Log = preload("res://mods/VTK/VTKLog.gd")
const Hud = preload("res://mods/VTK/VTKHud.gd")
const KC = preload("res://mods/VTK/VTKKillCounter.gd")
const Surface = preload("res://mods/VTK/VTKSurface.gd")
const Items := preload("res://mods/VTK/VTKItemStore.gd")
const Picker = preload("res://mods/VTK/VTKPicker.gd")
const MAX_ROWS := 5
const FEED_DURATION := 5.0
const FADE_TIME := 0.6
const GREEN := Color(0.55, 0.85, 0.55)
const RED := Color(1, 0.45, 0.45)
const GREY := Color(0.75, 0.75, 0.75)
const HS_GOLD := Color(1, 0.84, 0.41)
static func kind_color(kind: String) -> Color:
	if kind == "player" or kind == "nomad":
		return GREEN
	return RED
static func segments(ev: Dictionary, show_distance: bool = true) -> Array:
	var victim := {"text": str(ev.get("victim_name", "")), "color": kind_color(str(ev.get("victim_kind", "")))}
	if bool(ev.get("self_death", false)):
		return [victim, {"icon": "skull"}]
	var out: Array = []
	out.append({"text": str(ev.get("killer_name", "")), "color": kind_color(str(ev.get("killer_kind", "")))})
	if bool(ev.get("grenade", false)):
		out.append({"icon": "grenade"})
	else:
		if str(ev.get("weapon", "")) != "":
			out.append({"icon": "weapon"})
		if bool(ev.get("headshot", false)):
			out.append({"icon": "hs"})
	out.append(victim)
	if show_distance:
		var d := float(ev.get("distance", -1.0))
		if d >= 0.0:
			out.append({"text": "  " + str(int(round(d))) + "m", "color": HS_GOLD})
	return out
static func longest_kill_event(current_best: float, distance: float, threshold: float, enabled: bool) -> Dictionary:
	var best := current_best
	var is_new := distance >= 0.0 and distance > best
	if is_new:
		best = distance
	var msg := ""
	if enabled and distance >= 0.0:
		if is_new and distance >= threshold:
			msg = "New longest kill: " + str(int(round(distance))) + "m"
		elif distance >= threshold:
			msg = "Long shot: " + str(int(round(distance))) + "m"
	return {"new_best": is_new, "best": best, "message": msg}
static func alpha_at(age: float) -> float:
	if age <= FEED_DURATION:
		return 1.0
	var f := (age - FEED_DURATION) / FADE_TIME
	if f >= 1.0:
		return 0.0
	return 1.0 - f
static func push_entry(entries: Array, entry: Dictionary, max_rows: int) -> Array:
	entries.insert(0, entry)
	var dropped: Array = []
	while entries.size() > max_rows:
		dropped.append(entries.pop_back())
	return dropped
static func norm_weapon(s: String) -> String:
	return Items.norm_name(s)
static func streak_after_event(current: int, best: int, ev: Dictionary) -> Dictionary:
	var c := current
	var b := best
	if str(ev.get("killer_kind", "")) == "player":
		c += 1
		if c > b:
			b = c
	return {"current": c, "best": b}
static func streak_reset(best: int) -> Dictionary:
	return {"current": 0, "best": best}
const GRENADE_SVG := "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"32\" height=\"32\"><ellipse cx=\"16\" cy=\"20\" rx=\"9\" ry=\"10\" fill=\"#6f7a5a\" stroke=\"#3d4433\" stroke-width=\"2\"/><rect x=\"13\" y=\"6\" width=\"6\" height=\"5\" rx=\"1\" fill=\"#8a8f7a\" stroke=\"#3d4433\" stroke-width=\"1.5\"/><path d=\"M19 8 q7 1 7 7\" fill=\"none\" stroke=\"#c9c2b2\" stroke-width=\"2\"/><path d=\"M26 15 l0 4\" fill=\"none\" stroke=\"#c9c2b2\" stroke-width=\"2\"/></svg>"
const HS_SVG := "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"32\" height=\"32\"><circle cx=\"16\" cy=\"16\" r=\"11\" fill=\"none\" stroke=\"#FFD669\" stroke-width=\"2.5\"/><circle cx=\"16\" cy=\"16\" r=\"3.5\" fill=\"#FFD669\"/><path d=\"M16 1v7M16 24v7M1 16h7M24 16h7\" fill=\"none\" stroke=\"#FFD669\" stroke-width=\"2.5\"/></svg>"
var _counter_enabled: bool = false
var _feed_enabled: bool = false
var _streak_enabled: bool = false
var _font_size: int = 16
var _anchor: String = "top_left"
var _offset: Vector2 = Vector2(10, 90)
var _feed_root: VBoxContainer = null
var _cfg_mtime: int = 0
var _cfg_check_cd: float = 0.0
var _kills: int = 0
var _alive_cnt: int = 0
var _nomad_cnt: int = 0
var _current_streak: int = 0
var _best_streak: int = 0
var _best_kill_distance: float = 0.0
var _show_kill_distance: bool = true
var _longshot_distance_meters: int = 100
var _agents: Dictionary = {}
var _pending: Array[int] = []
var _rows: Array = []
var _ticker := Hud.Ticker.new()
var _was_shelter: bool = false
var _scene_ref: Node = null
var _iface: Node = null
var _hooks: Node = null
var _counter_panel: PanelContainer = null
var _counter_label: Label = null
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_counter_panel = PanelContainer.new()
	_counter_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_counter_panel.add_theme_stylebox_override("panel", Hud.plaque_style(1.0, 1.0))
	_counter_panel.visible = false
	_counter_label = Label.new()
	_counter_label.text = ""
	_counter_label.visible = false
	_counter_label.add_theme_font_size_override("font_size", _font_size)
	var hud_font = Paths.hud_font()
	if hud_font != null:
		_counter_label.add_theme_font_override("font", hud_font)
	_counter_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	_counter_panel.add_child(_counter_label)
	add_child(_counter_panel)
	Hud.place_block(_counter_panel, "top_left", 10, 10)
	_feed_root = VBoxContainer.new()
	_feed_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feed_root.add_theme_constant_override("separation", 2)
	_feed_root.visible = false
	add_child(_feed_root)
	_place_hud()
	call_deferred("_place_hud")
	set_process(false)
	visible = false
	get_tree().node_added.connect(_on_node_added)
	_connect_hooks()

func _connect_hooks() -> void:
	if _hooks != null and is_instance_valid(_hooks):
		return
	var p = get_node_or_null(Paths.UI_ROOT)
	if p == null:
		Log.warn_once(Paths.UI_ROOT, "kill feed: VTKUI autoload missing")
		return
	var h = Paths.hooks_node(p)
	if h == null or not h.has_signal("kill_event"):
		Log.warn_once(Paths.UI_ROOT + "/" + Paths.HOOKS, "kill feed: VTKHooks.kill_event missing")
		return
	_hooks = h
	h.connect("kill_event", Callable(self, "_on_kill_event"))
	if h.has_signal("player_died"):
		h.connect("player_died", Callable(self, "_on_player_died"))
	if h.has_signal("new_game_started"):
		h.connect("new_game_started", Callable(self, "_on_new_game"))
func _place_hud() -> void:
	var vs: Vector2 = get_viewport().size
	if vs.x <= 0.0 or vs.y <= 0.0:
		call_deferred("_place_hud")
		return
	const line_width := 420.0
	const max_entries := 5
	var w := line_width
	var h := float(max_entries * (_font_size + 18))
	var ox := float(_offset.x)
	var oy := float(_offset.y)
	var px := 0.0
	var py := 0.0
	match _anchor:
		"top_left":
			px = ox
			py = oy
		"top_center":
			px = vs.x * 0.5 - (w * 0.5) + ox
			py = oy
		"top_right":
			px = vs.x - w - ox
			py = oy
		"center_left":
			px = ox
			py = vs.y * 0.5 - (h * 0.5) + oy
		"center":
			px = vs.x * 0.5 - (w * 0.5) + ox
			py = vs.y * 0.5 - (h * 0.5) + oy
		"center_right":
			px = vs.x - w - ox
			py = vs.y * 0.5 - (h * 0.5) + oy
		"bottom_left":
			px = ox
			py = vs.y - h - oy
		"bottom_center":
			px = vs.x * 0.5 - (w * 0.5) + ox
			py = vs.y - h - oy
		"bottom_right":
			px = vs.x - w - ox
			py = vs.y - h - oy
		_:
			px = ox
			py = oy
	_feed_root.anchor_left = 0.0
	_feed_root.anchor_right = 0.0
	_feed_root.anchor_top = 0.0
	_feed_root.anchor_bottom = 0.0
	_feed_root.offset_left = 0.0
	_feed_root.offset_right = 0.0
	_feed_root.offset_top = 0.0
	_feed_root.offset_bottom = 0.0
	_feed_root.size = Vector2(w, 0.0)
	_feed_root.custom_minimum_size = Vector2(w, 0.0)
	_feed_root.position = Vector2(px, py)
	_write_feed_log()

func _any_enabled() -> bool:
	return _counter_enabled or _feed_enabled or _streak_enabled
func set_enabled(v: bool) -> void:
	configure(v, v, v)
func configure(counter: bool, feed: bool, streak: bool) -> void:
	_counter_enabled = counter
	_feed_enabled = feed
	_streak_enabled = streak
	var any := _any_enabled()
	visible = any
	set_process(any)
	if not any:
		clear()
		_current_streak = 0
		_best_kill_distance = 0.0
	else:
		_connect_hooks()
		var current := get_tree().current_scene
		_scene_ref = current
		_reseed()
	_counter_panel.visible = _counter_enabled
	_counter_label.add_theme_font_size_override("font_size", _font_size)
	_counter_label.visible = _counter_enabled
	_feed_root.visible = _feed_enabled or _streak_enabled
	_place_hud()
	_apply_texts()
func apply_layout(anchor: String, offset_x: int, offset_y: int, font_size: int) -> void:
	_anchor = anchor
	_offset = Vector2(offset_x, offset_y)
	var fs := clampi(font_size, 12, 32)
	if fs != _font_size and not _rows.is_empty():
		clear()
	_font_size = fs
	_place_hud()
	_feed_root.visible = _feed_enabled or _streak_enabled
	_counter_panel.visible = _counter_enabled
	_apply_fonts()
	_counter_label.visible = _counter_enabled
	_apply_texts()
func _apply_fonts() -> void:
	_counter_label.add_theme_font_size_override("font_size", _font_size)
	var hud_font = Paths.hud_font()
	if hud_font != null:
		_counter_label.add_theme_font_override("font", hud_font)
	_counter_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
func _apply_stats_visibility() -> void:
	_counter_panel.visible = _counter_enabled
func apply_distance_settings(show_kill_distance: bool, longshot_distance_meters: int) -> void:
	_show_kill_distance = show_kill_distance
	_longshot_distance_meters = clampi(longshot_distance_meters, 75, 150)
func _apply_texts() -> void:
	_apply_fonts()
	if _was_shelter:
		_counter_label.text = "Shelter"
	else:
		_counter_label.text = KC.counter_text(_kills, _alive_cnt, _nomad_cnt)
	_counter_panel.visible = _counter_enabled
	_counter_label.visible = _counter_enabled
func _on_node_added(node: Node) -> void:
	if not _any_enabled():
		return
	_pending.append(node.get_instance_id())
func _drain_pending() -> void:
	if _pending.is_empty():
		return
	for id in _pending:
		_deferred_check(id)
	_pending.clear()
func _deferred_check(node_id: int) -> void:
	if not _any_enabled():
		return
	var n := instance_from_id(node_id)
	if n == null or not is_instance_valid(n) or not n.is_inside_tree():
		return
	var kind := KC.agent_kind(n)
	if kind != "":
		_agents[node_id] = kind
func _reseed() -> void:
	_agents.clear()
	if _scene_ref == null:
		return
	_scan(_scene_ref)
func _scan(n: Node) -> void:
	var kind := KC.agent_kind(n)
	if kind != "":
		_agents[n.get_instance_id()] = kind
	for c in n.get_children():
		_scan(c)
func _get_iface() -> Node:
	if _iface != null and is_instance_valid(_iface):
		return _iface
	var root = get_tree().root
	_iface = root.get_node_or_null(Paths.INTERFACE)
	return _iface
func _get_hooks() -> Node:
	return _hooks
func _in_shelter() -> bool:
	return Hud.in_shelter(_get_iface())
func _reset_counters() -> void:
	_kills = 0
	_alive_cnt = 0
	_nomad_cnt = 0
	var hooks = _get_hooks()
	if hooks != null and is_instance_valid(hooks) and hooks.has_method("reset_kills"):
		hooks.reset_kills()
func _tick() -> void:
	var hooks = _get_hooks()
	if hooks != null and is_instance_valid(hooks) and hooks.has_method("get_kill_count"):
		_kills = hooks.get_kill_count()
	_alive_cnt = 0
	_nomad_cnt = 0
	var stale: Array = []
	for iid in _agents.keys():
		var a = instance_from_id(iid)
		if a == null or not is_instance_valid(a):
			stale.append(iid)
			continue
		if bool(a.get("dead")):
			continue
		if not ("active" in a) or not bool(a.get("active")):
			continue
		if _agents[iid] == "nomad":
			_nomad_cnt += 1
		else:
			_alive_cnt += 1
	for iid in stale:
		_agents.erase(iid)
	_apply_texts()
func _on_kill_event(ev: Dictionary) -> void:
	if not _any_enabled() or _was_shelter:
		return
	if _feed_enabled:
		_add_row(ev)
	if _streak_enabled:
		var was_player := str(ev.get("killer_kind", "")) == "player"
		var prev := _current_streak
		var res := streak_after_event(_current_streak, _best_streak, ev)
		_current_streak = int(res["current"])
		_best_streak = int(res["best"])
		if was_player and _current_streak > prev and (_current_streak % 5) == 0:
			_add_note("🔥 " + str(_current_streak) + " kill streak")
	if _streak_enabled and str(ev.get("killer_kind", "")) == "player":
		var lr := longest_kill_event(_best_kill_distance, float(ev.get("distance", -1.0)), float(_longshot_distance_meters), true)
		_best_kill_distance = float(lr["best"])
		var msg := str(lr["message"])
		if msg != "":
			_add_note(msg)
func _on_player_died() -> void:
	if _streak_enabled:
		_current_streak = 0
	_best_kill_distance = 0.0
	_apply_texts()
func _on_new_game() -> void:
	_current_streak = 0
	_best_kill_distance = 0.0
func _add_row(ev: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	row.custom_minimum_size.y = Hud.row_height(_font_size)
	for seg in segments(ev, _show_kill_distance):
		if seg.has("text"):
			var lbl := Label.new()
			lbl.text = str(seg["text"])
			lbl.add_theme_font_size_override("font_size", _font_size)
			lbl.add_theme_color_override("font_color", seg["color"])
			var hud := Paths.hud_font()
			if hud != null:
				lbl.add_theme_font_override("font", hud)
			row.add_child(lbl)
		else:
			_add_icon(row, str(seg["icon"]), ev)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.add_theme_stylebox_override("panel", Hud.plaque_style())
	panel.add_child(row)
	_feed_root.add_child(panel)
	var dropped: Array = push_entry(_rows, {"node": panel, "age": 0.0}, MAX_ROWS)
	for old in dropped:
		var n = old.get("node")
		if n != null and is_instance_valid(n):
			n.queue_free()
	_place_hud()
func _add_note(text: String) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	row.custom_minimum_size.y = Hud.row_height(_font_size)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", _font_size)
	lbl.add_theme_color_override("font_color", HS_GOLD)
	var hud_font = Paths.hud_font()
	if hud_font != null:
		lbl.add_theme_font_override("font", hud_font)
	row.add_child(lbl)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.add_theme_stylebox_override("panel", Hud.plaque_style())
	panel.add_child(row)
	_feed_root.add_child(panel)
	var dropped: Array = push_entry(_rows, {"node": panel, "age": 0.0}, MAX_ROWS)
	for old in dropped:
		var n = old.get("node")
		if n != null and is_instance_valid(n):
			n.queue_free()
	_place_hud()
func _add_icon(row: HBoxContainer, icon: String, ev: Dictionary) -> void:
	if icon == "weapon":
		var w := str(ev.get("weapon", ""))
		var tex := _weapon_texture(w)
		if tex != null:
			_add_tex(row, tex, 4.0)
			return
		if w != "":
			var wl := Label.new()
			wl.text = w
			wl.add_theme_font_size_override("font_size", _font_size)
			wl.add_theme_color_override("font_color", GREY)
			var hud2 := Paths.hud_font()
			if hud2 != null:
				wl.add_theme_font_override("font", hud2)
			row.add_child(wl)
		return
	if icon == "skull":
		var skull_lbl := Label.new()
		skull_lbl.text = "💀"
		skull_lbl.add_theme_font_size_override("font_size", _font_size)
		skull_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
		var skull_font := Paths.hud_font()
		if skull_font != null:
			skull_lbl.add_theme_font_override("font", skull_font)
		row.add_child(skull_lbl)
		return
	if icon == "grenade":
		_add_tex(row, Surface.svg_texture(GRENADE_SVG))
		return
	if icon == "hs":
		var tex := _hs_texture()
		if tex != null:
			_add_tex(row, tex)
			return
		var lbl := Label.new()
		lbl.text = "HS"
		lbl.add_theme_font_size_override("font_size", Hud.hs_fallback_size(_font_size))
		lbl.add_theme_color_override("font_color", HS_GOLD)
		var hud_hs := Paths.hud_font()
		if hud_hs != null:
			lbl.add_theme_font_override("font", hud_hs)
		row.add_child(lbl)
func _add_tex(row: HBoxContainer, tex: Texture2D, width_mul: float = 1.0) -> void:
	if tex == null:
		return
	var iv := TextureRect.new()
	iv.texture = tex
	iv.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	iv.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	iv.custom_minimum_size = Vector2(Hud.icon_size(_font_size) * width_mul, Hud.icon_size(_font_size))
	iv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(iv)
func _hs_texture() -> Texture2D:
	return Surface.svg_texture(HS_SVG)
func _weapon_texture(weapon: String) -> Texture2D:
	if weapon == "":
		return null
	var item = Items.item_by_name(weapon)
	if item == null:
		return null
	var ui = get_node_or_null(Paths.UI_ROOT)
	var icon = null
	if ui != null and ui.has_method("_item_icon"):
		icon = ui.call("_item_icon", item)
	if icon is Texture2D:
		return Picker.item_art(icon)
	if "icon" in item and item["icon"] is Texture2D:
		return Picker.item_art(item["icon"])
	return null
func clear() -> void:
	for e in _rows:
		var n = e.get("node")
		if n != null and is_instance_valid(n):
			n.queue_free()
	_rows.clear()
func _process(delta: float) -> void:
	var current := get_tree().current_scene
	var map_changed := current != _scene_ref
	_scene_ref = current

	_cfg_check_cd -= delta
	if _cfg_check_cd <= 0.0:
		_cfg_check_cd = 1.0
		_poll_config_file()
		_write_feed_log()
	_drain_pending()
	if not _any_enabled():
		return
	if map_changed:
		_reset_counters()
		_current_streak = 0
		clear()
	if not _ticker.step(delta):
		if _was_shelter:
			return
		if _rows.is_empty():
			return
		for e in _rows:
			e["age"] = float(e["age"]) + delta
		var i := 0
		while i < _rows.size():
			var e = _rows[i]
			var a := alpha_at(float(e["age"]))
			var n = e.get("node")
			if n != null and is_instance_valid(n):
				n.modulate.a = a
			if a <= 0.0:
				if n != null and is_instance_valid(n):
					n.queue_free()
				_rows.remove_at(i)
				continue
			i += 1
		return
	var in_shelter := _in_shelter()
	if in_shelter and not _was_shelter:
		_reset_counters()
		_current_streak = 0
		clear()
	_was_shelter = in_shelter
	var hdr_map_changed := map_changed
	if _was_shelter:
		_apply_texts()
		return
	if hdr_map_changed and _scene_ref != null:
		_reseed()
		_place_hud()
	_tick()
	if _rows.is_empty():
		return
	for e in _rows:
		e["age"] = float(e["age"]) + delta
	var i := 0
	while i < _rows.size():
		var e = _rows[i]
		var a := alpha_at(float(e["age"]))
		var n = e.get("node")
		if n != null and is_instance_valid(n):
			n.modulate.a = a
		if a <= 0.0:
			if n != null and is_instance_valid(n):
				n.queue_free()
			_rows.remove_at(i)
			continue
		i += 1


func _poll_config_file() -> void:
	var path := "user://MCM/vostok-toolkit/config.ini"
	var mt := FileAccess.get_modified_time(path)
	if mt == 0:
		return
	if mt == _cfg_mtime:
		return
	_cfg_mtime = mt
	var cf := ConfigFile.new()
	if not cf.load(path) == OK:
		return
	var a := "top_left"
	var dx := int(_offset.x)
	var dy := int(_offset.y)
	var fs := _font_size
	var data = cf.get_value("Dropdown", "hud_anchor", {})
	if typeof(data) == TYPE_DICTIONARY and data.has("value"):
		a = str(data["value"])
	data = cf.get_value("Int", "hud_offset_x", {})
	if typeof(data) == TYPE_DICTIONARY and data.has("value"):
		dx = int(data["value"])
	data = cf.get_value("Int", "hud_offset_y", {})
	if typeof(data) == TYPE_DICTIONARY and data.has("value"):
		dy = int(data["value"])
	data = cf.get_value("Int", "hud_font_size", {})
	if typeof(data) == TYPE_DICTIONARY and data.has("value"):
		fs = int(data["value"])
	if not Hud.ANCHOR_KEYS.has(a):
		a = "top_left"
	_anchor = a
	_offset = Vector2(clampi(dx, -1000, 1000), clampi(dy, -1000, 1000))
	_font_size = clampi(fs, 12, 32)
	data = cf.get_value("Bool", "show_kill_distance", {})
	if typeof(data) == TYPE_DICTIONARY and data.has("value"):
		_show_kill_distance = bool(data["value"])
	data = cf.get_value("Int", "longshot_distance_meters", {})
	if typeof(data) == TYPE_DICTIONARY and data.has("value"):
		_longshot_distance_meters = clampi(int(data["value"]), 75, 150)
	_apply_fonts()
	_place_hud()

func _write_feed_log() -> void:
	var f := FileAccess.open("user://VTK_feed.log", FileAccess.WRITE)
	if f == null:
		return
	f.store_string("anchor=%s offset=%s fs=%d feed.pos=%s feed.size=%s\n" % [_anchor, str(_offset), _font_size, str(_feed_root.position), str(_feed_root.size)])
	f.close()

