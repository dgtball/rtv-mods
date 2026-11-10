extends RefCounted
## Хост фич: владеет ленивыми узлами (хуки, телепорт, HUD) и их тумблерами.
## HUD теперь один блок VTKFeed, включающий счётчик, серию и ленту.

const Hooks := preload("res://mods/VTK/VTKHooks.gd")
const Travel := preload("res://mods/VTK/VTKTravel.gd")
const Feed := preload("res://mods/VTK/VTKFeed.gd")
const ConfigRec := preload("res://mods/VTK/VTKConfig.gd")

var _root: Node = null

var _hooks: Node = null
var _travel: Node = null
var _hud_node = null
var _hud_canvas = null

var _counter_enabled: bool = true
var _feed_enabled: bool = true
var _streak_enabled: bool = true
var _hud_anchor: String = "top_left"
var _hud_offset_x: int = ConfigRec.DEFAULTS["hud_offset_x"]
var _hud_offset_y: int = ConfigRec.DEFAULTS["hud_offset_y"]
var _hud_font_size: int = ConfigRec.DEFAULTS["hud_font_size"]
var _show_kill_distance: bool = ConfigRec.DEFAULTS["show_kill_distance"]
var _longshot_distance_meters: int = ConfigRec.DEFAULTS["longshot_distance_meters"]
var _player_name: String = "Player"

func _init(root: Node) -> void:
	_root = root

func _ensure_hooks() -> void:
	if _hooks != null and is_instance_valid(_hooks):
		return
	_hooks = Hooks.new()
	_root.add_child(_hooks)
	_hooks.set_player_name(_player_name)

func travel() -> Node:
	_ensure_travel()
	if _travel == null or not is_instance_valid(_travel):
		return null
	return _travel

func set_equip(enabled: bool) -> void:
	if _hooks == null or not is_instance_valid(_hooks):
		return
	_hooks.set_equip_enabled(enabled)

func set_hud(counter: bool, feed: bool, streak: bool) -> void:
	_counter_enabled = counter
	_feed_enabled = feed
	_streak_enabled = streak
	_apply_hud()

func set_hud_layout(anchor: String, offset_x: int, offset_y: int, font_size: int) -> void:
	_hud_anchor = anchor
	_hud_offset_x = offset_x
	_hud_offset_y = offset_y
	_hud_font_size = font_size
	_apply_hud()

func set_travel_unlocked(only: bool) -> void:
	var t := travel()
	if t != null:
		t.set_unlocked_only(only)
	if _root != null and _root.has_method("refresh_teleport_rows"):
		_root.call("refresh_teleport_rows")

func apply_config(c: ConfigRec) -> void:
	_counter_enabled = c.kill_counter_enabled
	_feed_enabled = c.kill_feed_enabled
	_streak_enabled = c.kill_streak_enabled
	_hud_anchor = c.hud_anchor
	_hud_offset_x = c.hud_offset_x
	_hud_offset_y = c.hud_offset_y
	_hud_font_size = c.hud_font_size
	_show_kill_distance = c.show_kill_distance
	_longshot_distance_meters = c.longshot_distance_meters
	_player_name = c.player_name
	if _hooks != null and is_instance_valid(_hooks):
		_hooks.set_player_name(_player_name)
		if _hooks.has_method("apply_season_config"):
			_hooks.call("apply_season_config")
	set_equip(c.auto_equip)
	set_travel_unlocked(c.tp_unlocked_shelters_only)
	_apply_hud()

func _ensure_travel() -> void:
	if _travel != null and is_instance_valid(_travel):
		return
	_travel = Travel.new()
	_root.add_child(_travel)

func _apply_hud() -> void:
	var any := _counter_enabled or _feed_enabled or _streak_enabled
	if any:
		_ensure_hud()
		if _hud_node != null and is_instance_valid(_hud_node):
			_hud_node.configure(_counter_enabled, _feed_enabled, _streak_enabled)
			_hud_node.apply_layout(_hud_anchor, _hud_offset_x, _hud_offset_y, _hud_font_size)
			if _hud_node.has_method("apply_distance_settings"):
				_hud_node.apply_distance_settings(_show_kill_distance, _longshot_distance_meters)
	else:
		if _hud_node != null and is_instance_valid(_hud_node):
			_hud_node.configure(false, false, false)

func _ensure_hud() -> void:
	if _hud_node != null and is_instance_valid(_hud_node):
		return
	var tree := _root.get_tree()
	if tree == null:
		return
	if _hud_canvas == null or not is_instance_valid(_hud_canvas):
		_hud_canvas = CanvasLayer.new()
		_hud_canvas.name = "VTKKC_Canvas"
		_hud_canvas.layer = 9999
		_hud_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
		tree.root.add_child(_hud_canvas)
	if _hud_node == null or not is_instance_valid(_hud_node):
		_hud_node = Feed.new()
		# Имя — контрактный якорь для внешних наблюдателей (RTV Mini HUD ищет
		# ленту по пути /root/VTKKC_Canvas/VTKFeed). Без него Godot даёт
		# сгенерированное @Control@N, которое меняется от запуска к запуску.
		_hud_node.name = "VTKFeed"
		_hud_canvas.add_child(_hud_node)