extends Node

const Log = preload("res://mods/RoadToLoot/RTLLog.gd")
const ConfigRec = preload("res://mods/RoadToLoot/RTLConfig.gd")
const DebugMod = preload("res://mods/RoadToLoot/RTLDebug.gd")
const Display = preload("res://mods/RoadToLoot/RTLDisplay.gd")

const Roll = preload("res://mods/RoadToLoot/RTLRoll.gd")
const Store = preload("res://mods/RoadToLoot/RTLStore.gd")
const Category = preload("res://mods/RoadToLoot/RTLCategory.gd")
const Sidecar = preload("res://mods/RoadToLoot/RTLSidecar.gd")

const MCM_HELPERS := "res://ModConfigurationMenu/Scripts/Doink Oink/MCM_Helpers.tres"

var _lib = null
var _cfg = ConfigRec.new()
var _debug = DebugMod.new()
var _display = Display.new()

func _ready() -> void:
	Log.clear()
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
		_lib.hook("tooltip-info-post", Callable(self, "on_tooltip_info"), 100)
		_lib.hook("item-initialize-post", Callable(self, "on_item_initialize"), 100)
		_lib.hook("loader-savecharacter-post", Callable(self, "on_save_character"), 100)
		_lib.hook("loader-loadcharacter-post", Callable(self, "on_load_character"), 100)
		_lib.hook("loader-newgame-post", Callable(self, "on_new_game"), 100)
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
	var path := "user://MCM/road-to-loot"
	_migrate_mcm_dir("user://MCM/lootershooter", path)
	DirAccess.make_dir_recursive_absolute(path)
	var cfile := path + "/config.ini"
	if FileAccess.file_exists(cfile):
		var existing := ConfigFile.new()
		if existing.load(cfile) == OK:
			merge_user_values(cfg, existing)
	cfg.save(cfile)
	mcm.RegisterConfiguration("road-to-loot", "Road To Loot", path, "Per-instance loot rarity and affixes", Callable(self, "apply_config"), self)
	apply_config(ConfigFile.new())

static func _migrate_mcm_dir(old_path: String, new_path: String) -> void:
	if not DirAccess.dir_exists_absolute(old_path):
		return
	if DirAccess.dir_exists_absolute(new_path):
		return
	DirAccess.make_dir_recursive_absolute(new_path)
	var dir := DirAccess.open(old_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir():
			DirAccess.copy_absolute(old_path + "/" + f, new_path + "/" + f)
		f = dir.get_next()
	dir.list_dir_end()
static func build_config() -> ConfigFile:
	var cfg := ConfigFile.new()
	var cat := "01. Display"
	cfg.set_value("Bool", "paint_cells", {"name": "Paint item cells", "default": true, "value": true, "category": cat, "menu_pos": 0, "tooltip": "Tint the inventory cell by loot rarity."})
	cfg.set_value("Bool", "show_affix_block", {"name": "Show affixes in tooltip", "default": true, "value": true, "category": cat, "menu_pos": 1, "tooltip": "Merge the rolled affixes into the item stat list."})
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
	cfg.set_value("Info", "version", "0.2.29")

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
		var path := "user://MCM/road-to-loot/config.ini"
		if FileAccess.file_exists(path):
			var c := ConfigFile.new()
			c.load(path)
			_cfg.read(c)
	if cfg != null and not cfg.get_sections().is_empty():
		_cfg.read(cfg)
	_debug.configure(_cfg)
	_display.configure(_cfg)

func on_tooltip_update(hint) -> void:
	_display.apply_tooltip(hint)

func on_tooltip_info(_info) -> void:
	_display.clear_tooltip()

# Item.Initialize(source, data) copies vanilla fields only — SlotData.Update()
# does not carry meta — so the roll has to follow the item node. The hook fires
# after Initialize, and `_caller` is the item being built; `data` is the
# SlotData it was copied from (the container slot or the loaded save slot).
func on_item_initialize(_source, data) -> void:
	if _lib == null or not ("_caller" in _lib):
		return
	var item = _lib._caller
	if item == null or not ("slotData" in item) or item.slotData == null or data == null:
		return
	var t: int = Store.tier(data)
	if t <= 0:
		return
	Store.stamp(item.slotData, t, Store.affixes(data))
	Sidecar.commit_slot(item.slotData)
	_display.paint(item)

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
			 "affixes": Roll.build_affixes(Category.of_item(item.slotData.itemData), 1, item.slotData.itemData, [], RandomNumberGenerator.new())}
	Store.stamp(item.slotData, r["tier"], r["affixes"])
	Sidecar.commit_slot(item.slotData)
	_display.paint(item)
	_display.invalidate_tooltip()
	return true

func tag_created_loot(item) -> void:
	var slotData = _created_slot()
	if slotData == null or slotData.itemData == null:
		return
	var uid: String = str(slotData.itemData.file) + "-" + str(randi())
	var plate: int = randi() % 10 + 1
	Sidecar.populate(slotData, {"uid": uid, "plate": plate})
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
	var uid: String = str(slotData.itemData.file) + "-" + str(randi())
	var plate: int = randi() % 10 + 1
	Sidecar.populate(slotData, {"uid": uid, "plate": plate})
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
	var affixes: Array = Roll.build_affixes(cat, tier, itemData, [], rng)
	Log.line("ROLL affix=" + str(affixes.size()))
	if _debug.should_log():
		Log.line("DEBUG roll_for cat=" + cat + " tier=" + str(tier) + " name=" + str(itemData.get("name")) + " type=" + str(itemData.get("type")) + " path=" + str(itemData.get("resource_path")))
	return {"tier": tier, "affixes": affixes}
func _iface() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var scene = tree.current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("/root/Map/Core/UI/Interface")

# --- Sidecar ----------------------------------------------------------------
# SlotData.Update() copies vanilla fields only, so a roll cannot ride along
# inside the save: writing extra fields into Character.tres is exactly what
# broke inventory loading in 0.2.24. The roll is kept beside the save instead,
# keyed by what the vanilla loader rebuilds from it -- item file plus the
# order the item appears in its grid, or item file plus the equipment slot
# name. Loader.SaveCharacter() walks interface.*Grid.get_children() and
# Loader.LoadCharacter() recreates them in that same order, so the keys line
# up across a save/load round trip. Character.tres itself is never written.
const SIDECAR_PATH := "user://roadtoloot_moddata.json"
const SIDECAR_TMP := "user://roadtoloot_moddata.json.tmp"
const SIDECAR_VERSION := 2

func _collect_grid(kind: String, grid, out: Dictionary) -> void:
	if grid == null:
		return
	var seen: Dictionary = {}
	for item in grid.get_children():
		if item == null or not ("slotData" in item) or item.slotData == null:
			continue
		var itemData = item.slotData.itemData
		if itemData == null:
			continue
		var file: String = str(itemData.file)
		var n: int = int(seen.get(file, 0))
		seen[file] = n + 1
		var t: int = Store.tier(item.slotData)
		if t <= 0:
			continue
		out[kind + "|" + file + "|" + str(n)] = {"t": t, "a": Store.affixes(item.slotData)}

# The Equipment node also holds plain UI sections (headers, stat rows); the
# vanilla save loop skips them with `if equipmentSlot is Slot`, and so must we,
# otherwise a header with children would be read as an equipped item.
func _is_equipment_slot(slot) -> bool:
	if slot == null or not (slot is Node):
		return false
	var script = slot.get_script()
	return script != null and str(script.get_global_name()) == "Slot"

func _collect_slots(kind: String, equipment, out: Dictionary) -> void:
	if equipment == null:
		return
	for slot in equipment.get_children():
		if not _is_equipment_slot(slot) or slot.get_child_count() == 0:
			continue
		var item = slot.get_child(0)
		if item == null or not ("slotData" in item) or item.slotData == null:
			continue
		var itemData = item.slotData.itemData
		if itemData == null:
			continue
		var t: int = Store.tier(item.slotData)
		if t <= 0:
			continue
		out[kind + "|" + str(itemData.file) + "|" + str(slot.name)] = {"t": t, "a": Store.affixes(item.slotData)}

func _apply_grid(kind: String, grid, data: Dictionary) -> void:
	if grid == null:
		return
	var seen: Dictionary = {}
	for item in grid.get_children():
		if item == null or not ("slotData" in item) or item.slotData == null:
			continue
		var itemData = item.slotData.itemData
		if itemData == null:
			continue
		var file: String = str(itemData.file)
		var n: int = int(seen.get(file, 0))
		seen[file] = n + 1
		var entry = data.get(kind + "|" + file + "|" + str(n))
		if not (entry is Dictionary):
			continue
		var entry_tier: int = int(entry.get("t", 0))
		if entry_tier <= 0:
			continue
		# Never clobber a freshly stamped tier with stale saved data.
		if Store.tier(item.slotData) > 0:
			continue
		Store.stamp(item.slotData, entry_tier, entry.get("a", []))
		Sidecar.commit_slot(item.slotData)
		_display.paint(item)

func _apply_slots(kind: String, equipment, data: Dictionary) -> void:
	if equipment == null:
		return
	for slot in equipment.get_children():
		if not _is_equipment_slot(slot) or slot.get_child_count() == 0:
			continue
		var item = slot.get_child(0)
		if item == null or not ("slotData" in item) or item.slotData == null:
			continue
		var itemData = item.slotData.itemData
		if itemData == null:
			continue
		var entry = data.get(kind + "|" + str(itemData.file) + "|" + str(slot.name))
		if not (entry is Dictionary):
			continue
		var entry_tier: int = int(entry.get("t", 0))
		if entry_tier <= 0:
			continue
		# Never clobber a freshly stamped tier with stale saved data.
		if Store.tier(item.slotData) > 0:
			continue
		Store.stamp(item.slotData, entry_tier, entry.get("a", []))
		Sidecar.commit_slot(item.slotData)
		_display.paint(item)

# A missing interface means the grids do not exist yet: keep the previous file
# instead of overwriting it with an empty roll set.
func _sidecar_write() -> void:
	var iface = _iface()
	if iface == null:
		return
	var item_count: int = 0
	for grid in [iface.get("inventoryGrid"), iface.get("catalogGrid")]:
		if grid != null:
			item_count += grid.get_child_count()
	var equipment = iface.get("equipment")
	if equipment != null:
		for slot in equipment.get_children():
			item_count += slot.get_child_count()
	# An interface without a single item means the scene is mid-transition and
	# the loader has not rebuilt the grids yet: keep the previous rolls instead
	# of replacing them with an empty set.
	if item_count == 0:
		return
	var items: Dictionary = {}
	_collect_grid("inv", iface.get("inventoryGrid"), items)
	_collect_grid("cat", iface.get("catalogGrid"), items)
	_collect_slots("eq", iface.get("equipment"), items)
	var f = FileAccess.open(SIDECAR_TMP, FileAccess.WRITE)
	if f == null:
		Log.warn("sidecar: cannot open " + SIDECAR_TMP)
		return
	f.store_string(JSON.stringify({"v": SIDECAR_VERSION, "items": items}))
	f.close()
	var err := _replace(SIDECAR_TMP, SIDECAR_PATH)
	if err != OK:
		Log.warn("sidecar: replace failed (code " + str(err) + ")")
		return
	if _debug.should_log():
		Log.line("sidecar: wrote " + str(items.size()) + " rolls")

# Rename over an existing file; Windows can refuse, so drop the target first.
static func _replace(from_path: String, to_path: String) -> int:
	var g_from := ProjectSettings.globalize_path(from_path)
	var g_to := ProjectSettings.globalize_path(to_path)
	var err := DirAccess.rename_absolute(g_from, g_to)
	if err == OK:
		return OK
	DirAccess.remove_absolute(g_to)
	return DirAccess.rename_absolute(g_from, g_to)

func _sidecar_read() -> Dictionary:
	if not FileAccess.file_exists(SIDECAR_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SIDECAR_PATH))
	if not (parsed is Dictionary):
		Log.warn("sidecar: unreadable, ignoring")
		return {}
	if int(parsed.get("v", 0)) != SIDECAR_VERSION:
		return {}
	var items = parsed.get("items")
	if not (items is Dictionary):
		return {}
	return items

# SaveCharacter()/LoadCharacter() take no arguments, so their post-callbacks
# get none either: Callable.callv() silently drops a callback with the wrong
# arity, which would switch the hook off without any error.
func on_save_character() -> void:
	_sidecar_write()

func on_load_character() -> void:
	var data := _sidecar_read()
	if data.is_empty():
		return
	var iface = _iface()
	if iface == null:
		return
	_apply_grid("inv", iface.get("inventoryGrid"), data)
	_apply_grid("cat", iface.get("catalogGrid"), data)
	_apply_slots("eq", iface.get("equipment"), data)
	if _debug.should_log():
		Log.line("sidecar: restored " + str(data.size()) + " rolls")

# NewGame(difficulty, season) is void and takes two arguments.
func on_new_game(_difficulty, _season) -> void:
	if FileAccess.file_exists(SIDECAR_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SIDECAR_PATH))
	Log.line("sidecar: cleared for a new run")
