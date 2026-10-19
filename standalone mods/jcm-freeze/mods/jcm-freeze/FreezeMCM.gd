extends Node

const MOD_ID = "jcm-freeze"
const KEY_ID = "freezeNpcKey"

var key_freeze_npc: Key = KEY_KP_4
var _mcm_config = null


func _ready() -> void:
	if not Engine.has_meta("RTVModLib"):
		return
	var lib = Engine.get_meta("RTVModLib")
	if lib.get("_is_ready"):
		_register()
	else:
		lib.frameworks_ready.connect(_register)


func _register() -> void:
	var lib = Engine.get_meta("RTVModLib")
	if not lib.has_mod("doinkoink-mcm"):
		return

	_mcm_config = MCM_Config.new(MOD_ID, "Freeze for JCM",
			"Freeze NPCs and vehicles on demand.", _on_mcm_saved, self)

	_mcm_config.CreateKeycodeValue(KEY_ID, "Toggle Freeze NPC",
			"Turns Freeze NPC on or off without opening the menu.",
			key_freeze_npc, MCM_Config.MCM_Key_Types.KEY) \
		.setCategory("Hotkeys")

	_mcm_config.RegisterMod()


func _on_mcm_saved(config: ConfigFile) -> void:
	key_freeze_npc = _mcm_value(config, "Keycode", KEY_ID, key_freeze_npc)


func _mcm_value(config: ConfigFile, section: String, key: String, fallback):
	if config.has_section_key(section, key):
		var entry = config.get_value(section, key)
		if entry is Dictionary and entry.has("value"):
			return entry["value"]
	return fallback
