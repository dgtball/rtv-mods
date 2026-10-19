extends Node

const NPC_ID = "jcm-freeze.npc"
const VEHICLES_ID = "jcm-freeze.vehicles"

var _lib = null
var _jcm = null
var _mcm = null
var _npc_on := false
var _vehicles_on := false
var _bt_audio: Array = []
var _bt_seen: Dictionary = {}
var _heli_audio: Array = []
var _heli_seen: Dictionary = {}


func _ready() -> void:
	if not Engine.has_meta("RTVModLib"):
		push_warning("[Freeze] RTVModLib is not available; addon disabled")
		return
	var lib = Engine.get_meta("RTVModLib")
	if lib.get("_is_ready"):
		_on_lib_ready()
	else:
		lib.frameworks_ready.connect(_on_lib_ready)


func _on_lib_ready() -> void:
	if _lib != null:
		return
	_lib = Engine.get_meta("RTVModLib")
	_jcm = get_node_or_null("/root/jcm")
	if not _lib.has_mod("juuzoz-jcm") or _jcm == null \
			or not _jcm.has_method("supports_addon_api") or not _jcm.supports_addon_api("1.0"):
		push_warning("[Freeze] Freeze needs JCM 3.5.0 or newer; addon disabled")
		return
	if not _lib.has_method("skip_super"):
		push_warning("[Freeze] mod loader has no skip_super(); freeze disabled")
		return

	_jcm.register_toggle(NPC_ID, "AI", "Freeze NPC", false, _on_npc_toggled)
	_npc_on = _jcm.is_enabled(NPC_ID)
	_jcm.register_toggle(VEHICLES_ID, "AI", "Freeze BTR & Heli", false, _on_vehicles_toggled)
	_vehicles_on = _jcm.is_enabled(VEHICLES_ID)
	_register_hooks()
	_mcm = get_node_or_null("/root/jcmFreezeMCM")


func _register_hooks() -> void:
	_try_hook("ai-_physics_process", _on_ai_process)
	_try_hook("btr-_physics_process", _on_btr_process)
	_try_hook("helicopter-_physics_process", _on_heli_process)


func _try_hook(name: String, cb: Callable) -> void:
	var id = _lib.hook(name, cb)
	if id == -1:
		push_warning("[Freeze] %s is owned by another mod; its freeze will not work" % name)


func _on_npc_toggled(enabled: bool) -> void:
	_npc_on = enabled


func _on_vehicles_toggled(enabled: bool) -> void:
	_vehicles_on = enabled
	if not enabled:
		_restore_btr()
		_restore_heli()


func _on_btr_process(_delta) -> void:
	if _vehicles_on:
		_silence_btr()
		_lib.skip_super()


func _on_heli_process(_delta) -> void:
	if _vehicles_on:
		_silence_heli()
		_lib.skip_super()


func _silence_btr() -> void:
	var btr = _lib._caller
	if btr == null or not is_instance_valid(btr):
		return
	var key = btr.get_instance_id()
	if _bt_seen.has(key):
		return
	_bt_seen[key] = true
	_grab_players(btr, ["Audio/Idle", "Audio/Drive", "Audio/Road"], _bt_audio)


func _silence_heli() -> void:
	var heli = _lib._caller
	if heli == null or not is_instance_valid(heli):
		return
	var key = heli.get_instance_id()
	if _heli_seen.has(key):
		return
	_heli_seen[key] = true
	_grab_players(heli, ["Audio"], _heli_audio)


func _grab_players(owner: Node, paths: Array, bag: Array) -> void:
	for path in paths:
		var player = owner.get_node_or_null(path)
		if player == null:
			continue
		bag.append({"node": player, "volume_db": player.volume_db, "playing": player.playing})
		player.stop()


func _restore_btr() -> void:
	_restore_players(_bt_audio)
	_bt_audio.clear()
	_bt_seen.clear()


func _restore_heli() -> void:
	_restore_players(_heli_audio)
	_heli_audio.clear()
	_heli_seen.clear()


func _restore_players(bag: Array) -> void:
	for rec in bag:
		var player = rec["node"]
		if not is_instance_valid(player):
			continue
		player.volume_db = rec["volume_db"]
		if rec["playing"]:
			player.play()


func _on_ai_process(_delta) -> void:
	if _npc_on:
		_lib.skip_super()


func _input(event: InputEvent) -> void:
	if _jcm == null or _mcm == null:
		return
	if not (event is InputEventKey or event is InputEventMouseButton) or not event.pressed:
		return
	if not _hotkey_pressed(event, "freezeNpcKey", _mcm.key_freeze_npc):
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	var gd = _jcm.get("gameData")
	if gd == null or gd.menu or gd.settings:
		return
	_jcm.set_enabled(NPC_ID, not _jcm.is_enabled(NPC_ID))


func _hotkey_pressed(event: InputEvent, action: String, fallback_keycode: int) -> bool:
	if InputMap.has_action(action):
		return event.is_action_pressed(action)
	return event is InputEventKey and not event.echo and event.physical_keycode == fallback_keycode
