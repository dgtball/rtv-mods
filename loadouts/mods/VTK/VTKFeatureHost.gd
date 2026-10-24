extends RefCounted
## Хост фич: владеет ленивыми узлами (хуки, телепорт, HUD) и их тумблерами.
## Вынесен из VTKUI (батч 6e, R4a).
##
## Родитель приходит в _init и обязан быть VTKUI: дети создаются через
## _root.add_child, потому что три места ищут узел хуков по имени
## /root/VTKUI/VTKHooks (VTKTravel, VTKFeed, VTKKillCounter). get_node_or_null
## вернёт null молча - хуки, фид и счётчик просто перестанут работать, без
## ошибки в логе.
##
## Имена методов сохранены от VTKUI: их держит layout_check (PRESENT на
## func _apply_hud( и func _ensure_hud().

const Hooks := preload("res://mods/VTK/VTKHooks.gd")
const Travel := preload("res://mods/VTK/VTKTravel.gd")
const KillCounter := preload("res://mods/VTK/VTKKillCounter.gd")
const Feed := preload("res://mods/VTK/VTKFeed.gd")
const ConfigRec := preload("res://mods/VTK/VTKConfig.gd")

var _root: Node = null

var _hooks: Node = null
var _travel: Node = null
var _kc_node: Control = null
var _feed_node = null
var _hud_canvas = null

var _kc_mcm: bool = true
var _feed_mcm: bool = true

func _init(root: Node) -> void:
	_root = root

func _ensure_hooks() -> void:
	if _hooks != null and is_instance_valid(_hooks):
		return
	_hooks = Hooks.new()
	_root.add_child(_hooks)

func travel() -> Node:
	_ensure_travel()
	if _travel == null or not is_instance_valid(_travel):
		return null
	return _travel

func set_equip(enabled: bool, debug_probe: bool) -> void:
	if _hooks == null or not is_instance_valid(_hooks):
		return
	_hooks.set_equip_enabled(enabled)
	_hooks.set_equip_debug(debug_probe)

func set_hud(counter: bool, feed: bool) -> void:
	_kc_mcm = counter
	_feed_mcm = feed
	_apply_hud()

func set_travel_unlocked(only: bool) -> void:
	var t := travel()
	if t != null:
		t.set_unlocked_only(only)

# Применение всего разобранного MCM-конфига разом. Порядок: HUD ->
# автоэкип -> телепорт (термал удалён в 5.2.0).
func apply_config(c: ConfigRec) -> void:
	set_hud(c.kill_counter_enabled, c.kill_feed_enabled)
	set_equip(c.auto_equip, c.nvg_debug_probe)
	set_travel_unlocked(c.tp_unlocked_shelters_only)

func _ensure_travel() -> void:
	if _travel != null and is_instance_valid(_travel):
		return
	_travel = Travel.new()
	_root.add_child(_travel)

# Единая точка применения обоих HUD-виджетов. Зовётся из apply_config и из
# VTKMCMBridge.register, когда MCM не установлен: состояние приходит из MCM,
# отдельного UI-тумблера больше нет.
func _apply_hud() -> void:
	_set_counter_enabled(_kc_mcm)
	_set_feed_enabled(_feed_mcm)

func _set_counter_enabled(v: bool) -> void:
	if v:
		_ensure_hud()
		_kc_node.set_enabled(true)
	elif _kc_node != null and is_instance_valid(_kc_node):
		_kc_node.set_enabled(false)

func _set_feed_enabled(v: bool) -> void:
	if v:
		_ensure_hud()
		_feed_node.set_enabled(true)
	elif _feed_node != null and is_instance_valid(_feed_node):
		_feed_node.set_enabled(false)

# Один CanvasLayer на оба виджета; лениво, пока хотя бы один не включён.
func _ensure_hud() -> void:
	if _kc_node != null and is_instance_valid(_kc_node) \
			and _feed_node != null and is_instance_valid(_feed_node):
		return
	var tree := _root.get_tree()
	if tree == null:
		return
	if _hud_canvas == null or not is_instance_valid(_hud_canvas):
		_hud_canvas = CanvasLayer.new()
		_hud_canvas.name = "VTKKC_Canvas"
		_hud_canvas.layer = 9999
		tree.root.add_child(_hud_canvas)
	if _kc_node == null or not is_instance_valid(_kc_node):
		_kc_node = KillCounter.new()
		_hud_canvas.add_child(_kc_node)
	if _feed_node == null or not is_instance_valid(_feed_node):
		_feed_node = Feed.new()
		_hud_canvas.add_child(_feed_node)


