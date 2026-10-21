extends Node

const Log = preload("res://mods/LooterShooter/LSHLog.gd")
const ConfigRec = preload("res://mods/LooterShooter/LSHConfig.gd")
const DebugMod = preload("res://mods/LooterShooter/LSHDebug.gd")
const Display = preload("res://mods/LooterShooter/LSHDisplay.gd")

const Roll = preload("res://mods/LooterShooter/LSHRoll.gd")
const Store = preload("res://mods/LooterShooter/LSHStore.gd")
const Category = preload("res://mods/LooterShooter/LSHCategory.gd")

const MCM_HELPERS := "res://ModConfigurationMenu/Scripts/Doink Oink/MCM_Helpers.tres"

var _lib = null
var _cfg = ConfigRec.new()
var _debug = DebugMod.new()
var _display = Display.new()

func _ready() -> void:
	register_mcm()
	_debug.configure(_cfg)
	_display.configure(_cfg)
	_display.set_host(self)
	Log.line("booted (debug=" + str(_cfg.debug_enabled) + ")")
	var lib = Engine.get_meta("RTVModLib") if Engine.has_meta("RTVModLib") else null
	if lib == null:
		Log.warn("RTVModLib not found; loot hooks are inactive")
	else:
		_lib = lib
		_lib.hook("lootcontainer-createloot-post", Callable(self, "tag_created_loot"), 100)
		_lib.hook("lootcontainer-ailoot-post", Callable(self, "tag_ai_loot"), 100)
		_lib.hook("tooltip-update-post", Callable(self, "on_tooltip_update"), 100)
		_display.attach(get_tree())

func register_mcm() -> void:
	if not ResourceLoader.exists(MCM_HELPERS):
		_cfg.read(ConfigFile.new())
		return
	var mcm = load(MCM_HELPERS)
	if mcm == null or not mcm.has_method("RegisterConfiguration"):
		_cfg.read(ConfigFile.new())
		return
	var cfg := build_config()
	var path := "user://MCM/lootershooter"
	DirAccess.make_dir_recursive_absolute(path)
	var cfile := path + "/config.ini"
	if FileAccess.file_exists(cfile):
		var existing := ConfigFile.new()
		if existing.load(cfile) == OK:
			merge_user_values(cfg, existing)
	cfg.save(cfile)
	mcm.RegisterConfiguration("lootershooter", "LooterShooter", path, "Per-instance loot rarity and affixes", Callable(self, "apply_config"), self)
	apply_config(ConfigFile.new())

static func build_config() -> ConfigFile:
	var cfg := ConfigFile.new()
	var cat := "01. Display"
	cfg.set_value("Bool", "paint_cells", {"name": "Paint item cells", "default": true, "value": true, "category": cat, "menu_pos": 0, "tooltip": "Tint the inventory cell by loot rarity."})
	cfg.set_value("Bool", "show_affix_block", {"name": "Show affix block in tooltip", "default": true, "value": true, "category": cat, "menu_pos": 1, "tooltip": "List the rolled affixes below the item tooltip."})
	cfg.set_value("Float", "border_width", {"name": "Border width", "default": 2.0, "value": 2.0, "minRange": 1.0, "maxRange": 6.0, "step": 1.0, "category": cat, "menu_pos": 2, "tooltip": "Thickness of the rarity border."})
	cfg.set_value("Dropdown", "tier_palette", {"name": "Rarity palette", "default": 0, "value": 0, "options": {"0": "Default (blue/purple/gold)", "1": "High contrast"}, "category": cat, "menu_pos": 3, "tooltip": "Colour set for the rarity tiers."})
	cfg.set_value("Bool", "hide_vanilla_rarity", {"name": "Hide vanilla rarity line", "default": false, "value": false, "category": cat, "menu_pos": 4, "tooltip": "Hide the vanilla rarity word; the mod's own rarity line still shows."})

	var bal := "02. Balance"
	cfg.set_value("Float", "freq_mult", {"name": "Rarity frequency", "default": 1.0, "value": 1.0, "minRange": 0.5, "maxRange": 2.0, "step": 0.5, "category": bal, "menu_pos": 0, "tooltip": "Scales how often higher tiers appear."})
	cfg.set_value("Bool", "notify_legendary", {"name": "Notify on legendary find", "default": false, "value": false, "category": bal, "menu_pos": 1, "tooltip": "Show an on-screen message when a legendary drops."})
	cfg.set_value("Bool", "env_hint", {"name": "Container context hint", "default": true, "value": true, "category": bal, "menu_pos": 2, "tooltip": "Let military and elite containers shift the odds upward."})

	var dbg := "03. Debug"
	cfg.set_value("Bool", "debug_enabled", {"name": "Debug mode", "default": false, "value": false, "category": dbg, "menu_pos": 0, "tooltip": "Enable the debug tools below."})
	cfg.set_value("Int", "debug_force_tier", {"name": "Force tier (0=off)", "default": 0, "value": 0, "minRange": 0, "maxRange": 3, "step": 1, "category": dbg, "menu_pos": 1, "tooltip": "1=Common, 2=Rare, 3=Legendary."})
	cfg.set_value("Keycode", "debug_reroll_key", {"name": "Re-roll hovered item", "default": 0, "default_type": "Keycode", "value": 0, "category": dbg, "menu_pos": 2, "tooltip": "Press to re-roll the item under the cursor."})
	cfg.set_value("Bool", "log_rolls", {"name": "Log rolls", "default": false, "value": false, "category": dbg, "menu_pos": 3, "tooltip": "Print every loot roll to the log."})
	cfg.set_value("Info", "version", "0.1.0")

	return cfg

static func merge_user_values(cfg: ConfigFile, existing: ConfigFile) -> void:
	for section in cfg.get_sections():
		for key in cfg.get_section_keys(section):
			var new_v = cfg.get_value(section, key)
			if existing.has_section_key(section, key) and new_v is Dictionary:
				var old_v = existing.get_value(section, key)
				if old_v is Dictionary and old_v.has("value"):
					new_v["value"] = old_v["value"]
					cfg.set_value(section, key, new_v)

func apply_config(cfg: ConfigFile) -> void:
	if cfg == null or cfg.get_sections().is_empty():
		var path := "user://MCM/lootershooter/config.ini"
		if FileAccess.file_exists(path):
			var c := ConfigFile.new()
			c.load(path)
			_cfg.read(c)
	if cfg != null and not cfg.get_sections().is_empty():
		_cfg.read(cfg)
	_debug.configure(_cfg)
	_display.configure(_cfg)

func on_tooltip_update(tooltip) -> void:
	_display.apply_tooltip(tooltip)

func _input(event: InputEvent) -> void:
	if _debug.matches_reroll(event):
		if _display.reroll_hovered(get_tree()):
			Log.line("rerolled hovered item")

func reroll_item(item) -> bool:
	if item == null or item.slotData == null:
		return false
	var ctx := {"rarity_roll": 100}
	if _debug.force_tier() == 0:
		ctx["rarity_roll"] = randi_range(1, 100)
	var r: Dictionary = roll_for(item.slotData.itemData, ctx, RandomNumberGenerator.new())
	if r["tier"] <= 0:
		r = {"tier": Roll.pick_tier(Roll.tier_weights(ctx, _cfg.freq_mult, 1), randf()),
			 "affixes": Roll.build_affixes(Category.of_item(item.slotData.itemData), 1, RandomNumberGenerator.new())}
	Store.stamp(item.slotData, r["tier"], r["affixes"])
	_display.paint(item)
	return true

func tag_created_loot(item) -> void:
	var slotData = _created_slot()
	if slotData == null or slotData.itemData == null:
		return
	_roll_into(slotData, {"item": item, "rarity_roll": _caller_rarity_roll()})

func _created_slot():
	if _lib == null:
		return null
	var caller = _lib._caller if "_caller" in _lib else null
	if caller == null or not ("loot" in caller):
		return null
	var loot = caller.loot
	if loot is Array and loot.size() > 0:
		return loot[loot.size() - 1]
	return null

func tag_ai_loot(slotData) -> void:
	if slotData == null or slotData.itemData == null:
		return
	var ctx := {"rarity_roll": _caller_rarity_roll()}
	_roll_into(slotData, ctx)

func _caller_rarity_roll() -> int:
	if _lib == null:
		return 100
	var caller = _lib._caller if "_caller" in _lib else null
	if caller != null and "rarityRoll" in caller:
		return int(caller.rarityRoll)
	return 100

func _roll_into(slotData, ctx: Dictionary) -> void:
	if slotData == null or slotData.itemData == null:
		return
	if not Category.rollable(slotData.itemData):
		return
	var r: Dictionary = roll_for(slotData.itemData, ctx, RandomNumberGenerator.new())
	if r["tier"] <= 0 and Store.has_tier(slotData):
		return
	Store.stamp(slotData, r["tier"], r["affixes"])
	if _debug.should_log():
		Log.line("roll " + str(slotData.itemData.name) + " tier=" + str(r["tier"])
				+ " affixes=" + str(r["affixes"]))

func roll_for(itemData, ctx: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var cat: String = Category.of_item(itemData)
	if cat == Category.OTHER:
		return {"tier": 0, "affixes": []}
	var rarity_roll: int = int(ctx.get("rarity_roll", 100))
	var ctx_dict := {"rarity_roll": rarity_roll, "corpse": bool(ctx.get("corpse", false)), "joker": bool(ctx.get("joker", false))}
	var weights: Array = Roll.tier_weights(ctx_dict, _cfg.freq_mult, _debug.force_tier())
	var tier: int = Roll.pick_tier(weights, rng.randf())
	var affixes: Array = Roll.build_affixes(cat, tier, rng)
	return {"tier": tier, "affixes": affixes}
