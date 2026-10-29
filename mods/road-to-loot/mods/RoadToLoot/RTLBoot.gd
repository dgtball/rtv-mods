extends Node

const Log = preload("res://mods/RoadToLoot/RTLLog.gd")
const ConfigRec = preload("res://mods/RoadToLoot/RTLConfig.gd")
const DebugMod = preload("res://mods/RoadToLoot/RTLDebug.gd")
const Display = preload("res://mods/RoadToLoot/RTLDisplay.gd")

const Roll = preload("res://mods/RoadToLoot/RTLRoll.gd")
const Store = preload("res://mods/RoadToLoot/RTLStore.gd")
const Category = preload("res://mods/RoadToLoot/RTLCategory.gd")
const RTLSidecar = preload("res://mods/RoadToLoot/RTLSidecar.gd")

const MCM_HELPERS := "res://ModConfigurationMenu/Scripts/Doink Oink/MCM_Helpers.tres"

var _lib = null
var _cfg = ConfigRec.new()
var _debug = DebugMod.new()
var _display = Display.new()
var _sidecar_deferred := false
var _sidecar_retry := 0
var _container_watch := 0

var _pending_container: Dictionary = {} # instance_id -> { "sd": slotData, "uid": String, "file": String, "t": int, "a": Array }

func _ready() -> void:
	set_process(true)
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
		_lib.hook("lootcontainer-storage-post", Callable(self, "on_container_storage"), 100)
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
	cfg.set_value("Info", "version", mod_version())

	return cfg

# Version lives in mod.txt; pack.ps1 also drops it into version.txt. Read the
# copy rather than parsing mod.txt, so the number cannot drift from the release.
static func mod_version() -> String:
	var vf := FileAccess.open("res://mods/RoadToLoot/version.txt", FileAccess.READ)
	if vf == null:
		return "unknown"
	var v := vf.get_as_text().strip_edges()
	vf.close()
	return v if v != "" else "unknown"

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

func on_item_initialize(_source, data) -> void:
	if _lib == null or not ("_caller" in _lib):
		return
	var item = _lib._caller
	if item == null or not ("slotData" in item) or item.slotData == null:
		return
	var sd = item.slotData
	# On load vanilla hands Initialize() the saved SlotData, which carries the
	# roll in its metadata (see _patch_character_save). adopt() moves it onto the
	# live copy that Update() just rebuilt.
	if not Store.adopt(sd, data):
		return
	_pending_add_container(sd)
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
	_pending_add_container(item.slotData)
	_display.paint(item)
	_display.invalidate_tooltip()
	return true

func tag_created_loot(item) -> void:
	var slotData = _created_slot()
	if slotData == null or slotData.itemData == null:
		return
	_roll_into(slotData, {"item": item, "rarity_roll": _caller_rarity_roll()})
	_pending_add_container(slotData)
	_queue_sidecar_save()
	call_deferred("_queue_sidecar_save")
	call_deferred("_queue_sidecar_save")

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
	_pending_add_container(slotData)
	_queue_sidecar_save()
	call_deferred("_queue_sidecar_save")

func on_container_storage(containerGrid) -> void:
	if containerGrid == null or _lib == null or not ("_caller" in _lib):
		return
	var container = _lib._caller
	if container == null or not ("storage" in container):
		return
	var stored = container.storage
	if not (stored is Array):
		return
	var nodes: Array = containerGrid.get_children()
	var count: int = nodes.size()
	if stored.size() < count:
		count = stored.size()
	for i in count:
		var node = nodes[i]
		if node == null or not ("slotData" in node) or node.slotData == null:
			continue
		var src = node.slotData
		var t: int = Store.tier(src)
		if t <= 0:
			continue
		var dst = stored[i]
		if dst == null:
			continue
		var uid := RTLSidecar.get_uid(src)
		if uid != "":
			RTLSidecar.set_uid(dst, uid)
		Store.stamp(dst, t, Store.affixes(src))

func _caller_rarity_roll() -> int:
	if _lib == null:
		return 100
	var caller = _lib._caller if "_caller" in _lib else null
	if caller != null and "rarityRoll" in caller:
		return int(caller.rarityRoll)
	return 100

func _process(_delta: float) -> void:
	if _container_watch <= 0:
		return
	_container_watch -= 1
	if _pending_container.size() > 0:
		_sidecar_write()
		try_restore_container()
		return
	# Idle watching: don't run full sidecar scan/writes every frame
	if _container_watch == 12 or _container_watch == 6 or _container_watch == 1:
		try_restore_container()
	return

func _pending_add_container(slotData) -> void:
	if slotData == null:
		return
	if not ("itemData" in slotData) or slotData.itemData == null:
		return
	var t: int = Store.tier(slotData)
	if t <= 0:
		return
	var id: int = slotData.get_instance_id()
	var file := str(slotData.itemData.file)
	if file.is_empty():
		return
	var uid := RTLSidecar.get_uid(slotData)
	var found_in_prev := false
	if uid == "":
		var prev := _sidecar_read()
		var pbu = prev.get("by_uid", {})
		if pbu is Dictionary:
			for puk in pbu.keys():
				var pe = pbu[puk]
				if pe is Dictionary and str(pe.get("file", "")) == file and int(pe.get("t", 0)) == t:
					RTLSidecar.set_uid(slotData, str(puk))
					uid = str(puk)
					found_in_prev = true
					break
	if uid == "":
		uid = RTLSidecar.ensure_uid(slotData)
	if found_in_prev:
		return
	_pending_container[id] = {
		"sd": slotData,
		"uid": uid,
		"file": file,
		"t": t,
		"a": Store.affixes(slotData).duplicate(true)
	}
	_queue_sidecar_save()

func _queue_sidecar_save() -> void:
	_container_watch = 60
	if _sidecar_deferred:
		return
	_sidecar_deferred = true
	call_deferred("_flush_sidecar_save")

func try_restore_container() -> void:
	var iface = _iface()
	if iface == null:
		return
	var container_node = iface.get_node_or_null("Container")
	if container_node != null:
		var data := _sidecar_read()
		if not data.is_empty():
			_apply_all_under("cont", container_node, data)
			return
	var cont = _get_container_grid(iface)
	if cont == null:
		return
	var data := _sidecar_read()
	if data.is_empty():
		return
	_apply_grid("cont", cont, data)

func _flush_sidecar_save() -> void:
	_sidecar_deferred = false
	if _pending_container.size() > 0:
		_sidecar_write()
		try_restore_container()
	else:
		# When opening/rebuilding container grid, avoid full _sidecar_write() scan
		try_restore_container()
	_container_watch = max(_container_watch, 15)
	if _sidecar_retry < 5:
		_sidecar_retry += 1
		call_deferred("_retry_sidecar_save")

func _retry_sidecar_save() -> void:
	if _pending_container.size() > 0:
		_sidecar_write()
	try_restore_container()

func _roll_into(slotData, ctx: Dictionary) -> void:
	if slotData == null or slotData.itemData == null:
		return
	if not Category.rollable(slotData.itemData):
		return
	var r: Dictionary = roll_for(slotData.itemData, ctx, RandomNumberGenerator.new())
	if r["tier"] <= 0 and Store.has_tier(slotData):
		return
	Store.stamp(slotData, r["tier"], r["affixes"])
	var uid := RTLSidecar.get_uid(slotData)
	if uid == "":
		uid = RTLSidecar.ensure_uid(slotData)
	if _debug.should_log():
		Log.line("roll " + str(slotData.itemData.name) + " by_uid=" + uid + " tier=" + str(r["tier"]) + " affixes=" + str(r["affixes"]))
	_sidecar_upsert_uid(uid, str(slotData.itemData.file), int(r["tier"]), r["affixes"])
	_queue_sidecar_save()

func _sidecar_upsert_uid(uid: String, file: String, tier: int, affixes: Array) -> void:
	if uid == "" or file == "":
		return
	var prev := _sidecar_read()
	var bu = prev.get("by_uid", {})
	if not (bu is Dictionary):
		bu = {}
	var items_prev = prev.get("items", {})
	if not (items_prev is Dictionary):
		items_prev = {}
	var by_ft_prev = prev.get("by_ft", {})
	if not (by_ft_prev is Dictionary):
		by_ft_prev = {}
	var new_bu: Dictionary = bu.duplicate(true)
	new_bu[uid] = {"t": tier, "a": affixes.duplicate(true), "file": file}
	var f = FileAccess.open(SIDECAR_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"v": SIDECAR_VERSION, "items": items_prev, "by_uid": new_bu, "by_ft": by_ft_prev}))
	f.close()

func roll_for(itemData, ctx: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var cat: String = Category.of_item(itemData)
	if cat == Category.OTHER:
		return {"tier": 0, "affixes": []}
	var rarity_roll: int = int(ctx.get("rarity_roll", 100))
	var ctx_dict := {"rarity_roll": rarity_roll, "corpse": bool(ctx.get("corpse", false)), "joker": bool(ctx.get("joker", false))}
	var weights: Array = Roll.tier_weights(ctx_dict, _cfg.freq_mult, _debug.force_tier())
	var tier: int = Roll.pick_tier(weights, rng.randf())
	var affixes: Array = Roll.build_affixes(cat, tier, itemData, [], rng)
	return {"tier": tier, "affixes": affixes}

func _iface() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var scene = tree.current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("/root/Map/Core/UI/Interface")

const SIDECAR_PATH := "user://roadtoloot_moddata.json"
const SIDECAR_TMP := "user://roadtoloot_moddata.json.tmp"
const SIDECAR_VERSION := 3
const CHARACTER_PATH := "user://Character.tres"

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

func _collect_all_under(kind: String, root: Node, out: Dictionary, by_uid_out: Dictionary = {}, for_write: bool = false) -> void:
	if root == null:
		return
	var seen: Dictionary = {}
	var stack: Array = [root]
	while stack.size() > 0:
		var cur = stack.pop_back()
		if cur == null:
			continue
		for c in cur.get_children():
			if c == null:
				continue
			stack.push_back(c)
			if "slotData" in c and c.slotData != null and c.slotData.itemData != null:
				var slotData_c = c.slotData
				var itemData = slotData_c.itemData
				if kind == "cont":
					var pid_c: int = slotData_c.get_instance_id()
					if _pending_container.has(pid_c):
						_pending_container.erase(pid_c)
					var t_c := Store.tier(slotData_c)
					if t_c > 0 and by_uid_out != null:
						var uid_c := ""
						if for_write:
							uid_c = RTLSidecar.get_uid(slotData_c)
						else:
							uid_c = RTLSidecar.ensure_uid(slotData_c)
						if uid_c != "":
							var file_c := str(itemData.file)
							if file_c != "":
								by_uid_out[uid_c] = {"t": t_c, "a": Store.affixes(slotData_c).duplicate(true), "file": file_c}
					continue
				var file: String = str(itemData.file)
				var n: int = int(seen.get(file, 0))
				seen[file] = n + 1
				var t: int = Store.tier(slotData_c)
				if t <= 0:
					continue
				out[kind + "|" + file + "|" + str(n)] = {"t": t, "a": Store.affixes(slotData_c)}

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
	if grid == null or data.is_empty():
		return
	var by_uid: Dictionary = {}
	if data.has("by_uid") and data["by_uid"] is Dictionary:
		by_uid = data["by_uid"]
	var by_ft: Dictionary = {}
	if data.has("by_ft") and data["by_ft"] is Dictionary:
		by_ft = data["by_ft"]
	var seen: Dictionary = {}
	var used_ft: Dictionary = {}
	for item in grid.get_children():
		if item == null or not ("slotData" in item) or item.slotData == null:
			continue
		var slotData = item.slotData
		var itemData = slotData.itemData
		if itemData == null:
			continue
		if kind == "cont":
			var uid = RTLSidecar.get_uid(slotData)
			if uid != "" and by_uid.has(uid):
				var entry_uid = by_uid[uid]
				if entry_uid is Dictionary:
					RTLSidecar.set_uid(slotData, uid)
					Store.stamp(slotData, int(entry_uid.get("t", 0)), entry_uid.get("a", []))
					_display.paint(item)
					continue
			var t_cur := Store.tier(slotData)
			var file_cand := str(itemData.file)
			if t_cur > 0 and by_ft is Dictionary:
				var ftk_cand := file_cand + "|" + str(t_cur)
				if by_ft.has(ftk_cand) and by_ft[ftk_cand] is Array:
					var arr_c = by_ft[ftk_cand]
					var idx := int(used_ft.get(ftk_cand, 0))
					if arr_c is Array and idx < arr_c.size():
						var cand = arr_c[idx]
						if cand is Dictionary:
							var na = cand.get("a", [])
							var nuid = str(cand.get("uid", ""))
							if nuid != "":
								RTLSidecar.set_uid(slotData, nuid)
								if not by_uid.has(nuid):
									by_uid[nuid] = {"t": t_cur, "a": na, "file": file_cand}
							Store.stamp(slotData, t_cur, na)
							_display.paint(item)
							used_ft[ftk_cand] = idx + 1
							continue
			# fallback: search by_uid by file+tier
			if t_cur > 0 and by_uid is Dictionary:
				for puk in by_uid.keys():
					var pe = by_uid[puk]
					if pe is Dictionary and str(pe.get("file", "")) == file_cand and int(pe.get("t", 0)) == t_cur:
						RTLSidecar.set_uid(slotData, str(puk))
						Store.stamp(slotData, int(pe.get("t", 0)), pe.get("a", []))
						_display.paint(item)
						break
				continue
		var file: String = str(itemData.file)
		var n: int = int(seen.get(file, 0))
		seen[file] = n + 1
		# The roll now travels inside the save itself. The positional sidecar key
		# is a fallback for saves written by older builds, so it must never
		# overwrite a roll that came from metadata: the key is "Nth item with this
		# file" and a reshuffled grid would hand it to a different item.
		if Store.has_tier(slotData):
			continue
		var entry = data.get(kind + "|" + file + "|" + str(n))
		if not (entry is Dictionary):
			var items_dict = data.get("items", null)
			if items_dict is Dictionary:
				entry = items_dict.get(kind + "|" + file + "|" + str(n))
		if not (entry is Dictionary):
			continue
		Store.stamp(slotData, int(entry.get("t", 0)), entry.get("a", []))
		_display.paint(item)

func _apply_all_under(kind: String, root: Node, data: Dictionary) -> void:
	if root == null or data.is_empty():
		return
	var by_uid: Dictionary = {}
	if data.has("by_uid") and data["by_uid"] is Dictionary:
		by_uid = data["by_uid"]
	var by_ft: Dictionary = {}
	if data.has("by_ft") and data["by_ft"] is Dictionary:
		by_ft = data["by_ft"]
	var items_dict_fallback: Dictionary = {}
	if data.has("items") and data["items"] is Dictionary:
		items_dict_fallback = data["items"]
	var seen: Dictionary = {}
	var used_ft: Dictionary = {}
	var stack: Array = [root]
	while stack.size() > 0:
		var cur = stack.pop_back()
		if cur == null:
			continue
		for c in cur.get_children():
			if c == null:
				continue
			stack.push_back(c)
			if "slotData" in c and c.slotData != null and c.slotData.itemData != null:
				var slotData_c = c.slotData
				var itemData = slotData_c.itemData
				if kind == "cont":
					var uid_c = RTLSidecar.get_uid(slotData_c)
					if uid_c != "" and by_uid.has(uid_c):
						var entry_uid_c = by_uid[uid_c]
						if entry_uid_c is Dictionary:
							RTLSidecar.set_uid(slotData_c, uid_c)
							Store.stamp(slotData_c, int(entry_uid_c.get("t", 0)), entry_uid_c.get("a", []))
							_display.paint(c)
							continue
					var t_cur_c := Store.tier(slotData_c)
					if t_cur_c > 0 and by_ft is Dictionary:
						var file_cand_c := str(itemData.file)
						var ftk_cand_c := file_cand_c + "|" + str(t_cur_c)
						if by_ft.has(ftk_cand_c) and by_ft[ftk_cand_c] is Array:
							var arr_c2 = by_ft[ftk_cand_c]
							var idx_c := int(used_ft.get(ftk_cand_c, 0))
							if arr_c2 is Array and idx_c < arr_c2.size():
								var cand_c = arr_c2[idx_c]
								if cand_c is Dictionary:
									var nuid_c := str(cand_c.get("uid", ""))
									if nuid_c != "":
										RTLSidecar.set_uid(slotData_c, nuid_c)
									Store.stamp(slotData_c, t_cur_c, cand_c.get("a", []))
									_display.paint(c)
									used_ft[ftk_cand_c] = idx_c + 1
									if nuid_c != "" and not by_uid.has(nuid_c):
										by_uid[nuid_c] = {"t": t_cur_c, "a": cand_c.get("a", []), "file": file_cand_c}
									continue
				var file: String = str(itemData.file)
				var n: int = int(seen.get(file, 0))
				seen[file] = n + 1
				var entry = data.get(kind + "|" + file + "|" + str(n))
				if not (entry is Dictionary):
					entry = items_dict_fallback.get(kind + "|" + file + "|" + str(n))
				if not (entry is Dictionary):
					continue
				Store.stamp(slotData_c, int(entry.get("t", 0)), entry.get("a", []))
				_display.paint(c)

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
		# Same rule as _apply_grid: metadata wins, the sidecar only fills gaps
		# left by saves written by older builds.
		if Store.has_tier(item.slotData):
			continue
		var key := kind + "|" + str(itemData.file) + "|" + str(slot.name)
		var entry = data.get(key)
		if not (entry is Dictionary):
			# _sidecar_read() nests the positional keys under "items", so the
			# top-level lookup above always misses. Without this fallback the
			# equipment half of every legacy save stayed unrolled.
			var items_dict = data.get("items", null)
			if items_dict is Dictionary:
				entry = items_dict.get(key)
		if not (entry is Dictionary):
			continue
		Store.stamp(item.slotData, int(entry.get("t", 0)), entry.get("a", []))
		_display.paint(item)

func _get_container_grid(iface) -> Node:
	if iface == null:
		return null
	var c = iface.get("Container")
	if c == null:
		c = iface.get_node_or_null("Container")
	if c != null and c.get_child_count() > 0:
		# try direct grid children
		for child in c.get_children():
			if child == null:
				continue
			var cn = str(child.name).to_lower()
			if child.get_child_count() >= 0 and ("grid" in cn or child.has_method("get_children")):
				# prefer nodes that look like grids (have item children)
				if child.get_child_count() > 0:
					var first = child.get_child(0)
					if first != null and ("slotData" in first):
						return child
		# fallback: first child
		var first_child = c.get_child(0)
		if first_child != null and ("slotData" in first_child or first_child.get_child_count() >= 0):
			# if first child has slotData items maybe it's the grid
			if first_child.get_child_count() > 0:
				var fc = first_child.get_child(0)
				if fc != null and ("slotData" in fc):
					return first_child
			# or maybe items are direct children? unlikely
			return first_child
		return c
	return c

func _sidecar_write() -> void:
	var iface = _iface()
	Log.line("[RTL-DBG] _sidecar_write: iface=" + str(iface) + " (null=" + str(iface == null) + ")")
	if iface == null:
		return

	var inv = iface.get("inventoryGrid")
	var cat = iface.get("catalogGrid")
	var eqp = iface.get("equipment")
	var cont = _get_container_grid(iface)
	var items: Dictionary = {}
	_collect_grid("inv", iface.get("inventoryGrid"), items)
	_collect_grid("cat", iface.get("catalogGrid"), items)
	_collect_slots("eq", iface.get("equipment"), items)
	var container_node = iface.get_node_or_null("Container")
	var by_uid: Dictionary = {}
	var scanned_live_by_uid := false
	var prev_raw: Dictionary = _sidecar_read()
	Log.line("[RTL-DBG] _sidecar_write: prev sidecar size=" + str(prev_raw.size()))
	var prev_by_uid: Dictionary = {}
	if prev_raw.has("by_uid") and prev_raw["by_uid"] is Dictionary:
		prev_by_uid = prev_raw["by_uid"]
	var prev_by_ft: Dictionary = {}
	if prev_raw.has("by_ft") and prev_raw["by_ft"] is Dictionary:
		prev_by_ft = prev_raw["by_ft"]
	# merge pending container loot
	var pending_added := 0
	if _pending_container.size() > 0:
		for pid in _pending_container.keys().duplicate():
			var e = _pending_container[pid]
			if not is_instance_valid(e.get("sd", null)):
				_pending_container.erase(pid)
				continue
			var sd_e = e["sd"]
			if sd_e == null or not ("itemData" in sd_e) or sd_e.itemData == null:
				_pending_container.erase(pid)
				continue
			var t2 := Store.tier(sd_e)
			if t2 <= 0:
				_pending_container.erase(pid)
				continue
			var file2 := str(sd_e.itemData.file)
			if file2.is_empty():
				file2 = str(e.get("file", ""))
			if file2.is_empty():
				continue
			var uid_e := str(e.get("uid", ""))
			if uid_e == "":
				uid_e = RTLSidecar.get_uid(sd_e)
			if uid_e == "":
				for puk in prev_by_uid.keys():
					var pe = prev_by_uid[puk]
					if pe is Dictionary and str(pe.get("file", "")) == file2 and int(pe.get("t", 0)) == t2:
						uid_e = str(puk)
						if uid_e != "":
							RTLSidecar.set_uid(sd_e, uid_e)
							e["uid"] = uid_e
							break
			if uid_e == "":
				_pending_container.erase(pid)
				continue
			if prev_by_uid.has(uid_e):
				RTLSidecar.set_uid(sd_e, uid_e)
				e["uid"] = uid_e
				_pending_container.erase(pid)
				continue
			if by_uid.has(uid_e):
				_pending_container.erase(pid)
				continue
			if container_node != null:
				_collect_all_under("cont", container_node, items, by_uid, true)
			else:
				_collect_grid("cont", cont, items)
			scanned_live_by_uid = true
			by_uid[uid_e] = {"t": t2, "a": Store.affixes(sd_e).duplicate(true), "file": file2}
			var ftk2 := file2 + "|" + str(t2)
			if not (prev_by_ft.has(ftk2) and prev_by_ft[ftk2] is Array):
				prev_by_ft[ftk2] = []
			if prev_by_ft[ftk2] is Array:
				prev_by_ft[ftk2].append({"uid": uid_e, "a": Store.affixes(sd_e).duplicate(true)})
			pending_added += 1
			_pending_container.erase(pid)
			continue
	else:
		by_uid = {}
	if container_node != null:
		_collect_all_under("cont", container_node, items, by_uid, true)
	elif cont != null:
		_collect_grid("cont", cont, items)
	Log.line("[RTL-DBG] _sidecar_write: collected rolls=" + str(items.size()))
	var prev_items: Dictionary = {}
	if prev_raw.has("items") and prev_raw["items"] is Dictionary:
		prev_items = prev_raw["items"]
	var merged: Dictionary = prev_items.duplicate(true)
	for k in items.keys():
		merged[k] = items[k]
	var merged_by_uid: Dictionary = prev_by_uid.duplicate(true)
	# Merge live by_uid from scans
	for uk in by_uid.keys():
		var new_e = by_uid[uk]
		if not (new_e is Dictionary):
			continue
		if merged_by_uid.has(uk):
			var old_e = merged_by_uid[uk]
			if old_e is Dictionary:
				var old_a = old_e.get("a", [])
				var new_a = new_e.get("a", [])
				if (old_a is Array and old_a.size() > 0) and (new_a is Array and new_a.size() == 0):
					continue
		merged_by_uid[uk] = new_e
	# Also scan all current slotData to rebuild mapping from live objects
	var all_slots: Array = []
	if iface != null:
		_scan_collect_slots(iface, all_slots)
	if container_node != null:
		_scan_collect_slots(container_node, all_slots)
	for sd in all_slots:
		if sd == null: continue
		if not ("itemData" in sd) or sd.itemData == null: continue
		var t_live := Store.tier(sd)
		if t_live <= 0: continue
		var u_live := RTLSidecar.get_uid(sd)
		if u_live == "": continue
		var f_live := str(sd.itemData.file)
		if f_live == "": continue
		var a_live := Store.affixes(sd)
		if not merged_by_uid.has(u_live):
			merged_by_uid[u_live] = {"t": t_live, "a": a_live, "file": f_live}
		else:
			var me = merged_by_uid[u_live]
			if me is Dictionary:
				var ma = me.get("a", [])
				if (ma is Array and ma.size() == 0) and (a_live is Array and a_live.size() > 0):
					me["a"] = a_live
					me["t"] = t_live
					me["file"] = f_live
					merged_by_uid[u_live] = me
	Log.line("[RTL-DBG] _sidecar_write: after merge size=" + str(merged.size()) + " by_uid=" + str(merged_by_uid.size()) + " (_container_watch=" + str(_container_watch) + ")")
	if merged.is_empty() and merged_by_uid.is_empty():
		Log.line("[RTL-DBG] _sidecar_write: SKIP WRITE (no rolls)")
		return
	if merged.size() == prev_items.size() and merged_by_uid.size() == prev_by_uid.size() and pending_added == 0:
		if _container_watch <= 0:
			Log.line("[RTL-DBG] _sidecar_write: SKIP WRITE (no new rolls and not watching)")
			return
		Log.line("[RTL-DBG] _sidecar_write: SKIP WRITE (watching but unchanged)")
		return
	var f = FileAccess.open(SIDECAR_TMP, FileAccess.WRITE)
	if f == null:
		Log.warn("sidecar: cannot open " + SIDECAR_TMP)
		return
	var by_ft_out: Dictionary = prev_by_ft.duplicate(true)
	if not (by_ft_out is Dictionary):
		by_ft_out = {}
	f.store_string(JSON.stringify({"v": SIDECAR_VERSION, "items": merged, "by_uid": merged_by_uid, "by_ft": by_ft_out}))
	f.close()
	var err := _replace(SIDECAR_TMP, SIDECAR_PATH)
	if err != OK:
		Log.warn("sidecar: replace failed (code " + str(err) + ")")
		return
	Log.line("[RTL-DBG] _sidecar_write: wrote items=" + str(merged.size()) + " by_uid=" + str(merged_by_uid.size()) + " (prev_items=" + str(prev_items.size()) + " prev_by_uid=" + str(prev_by_uid.size()) + " new=" + str(items.size()) + ")")
	if _debug.should_log():
		Log.line("sidecar: wrote " + str(merged.size()) + " rolls (new=" + str(items.size()) + ")")

static func _replace(from_path: String, to_path: String) -> int:
	var g_from := ProjectSettings.globalize_path(from_path)
	var g_to := ProjectSettings.globalize_path(to_path)
	var err := DirAccess.rename_absolute(g_from, g_to)
	if err == OK:
		return OK
	DirAccess.remove_absolute(g_to)
	return DirAccess.rename_absolute(g_from, g_to)

func _scan_collect_slots(node: Node, out: Array) -> void:
	if node == null:
		return
	if "slotData" in node and node.slotData != null:
		out.append(node.slotData)
	for c in node.get_children():
		if c != null:
			_scan_collect_slots(c, out)

func _sidecar_read() -> Dictionary:
	if not FileAccess.file_exists(SIDECAR_PATH):
		return {}
	var txt := FileAccess.get_file_as_string(SIDECAR_PATH)
	var parsed = JSON.parse_string(txt)
	if not (parsed is Dictionary):
		Log.warn("sidecar: unreadable, ignoring")
		return {}
	var v := int(parsed.get("v", 0))
	if v != SIDECAR_VERSION and v != 2:
		return {}
	if parsed.has("items") and parsed["items"] is Dictionary:
		var out := {}
		out["items"] = parsed["items"]
		if parsed.has("by_uid") and parsed["by_uid"] is Dictionary:
			out["by_uid"] = parsed["by_uid"]
		else:
			out["by_uid"] = {}
		if parsed.has("by_ft") and parsed["by_ft"] is Dictionary:
			out["by_ft"] = parsed["by_ft"]
		else:
			out["by_ft"] = {}
		return out
	if parsed.has("by_uid") and parsed["by_uid"] is Dictionary and parsed.has("items") and parsed["items"] is Dictionary:
		var out2 := {}
		out2["items"] = parsed["items"]
		out2["by_uid"] = parsed["by_uid"]
		out2["by_ft"] = parsed.get("by_ft", {})
		return out2
	return {}

func on_save_character() -> void:
	Log.line("[RTL-DBG] HOOK on_save_character called")
	# Runs on every character save, not only while a container is open: the
	# metadata pass is what keeps the roll inside the save file itself.
	_patch_character_save()
	if _pending_container.is_empty() and _container_watch <= 0:
		Log.line("[RTL-DBG] HOOK on_save_character: SKIP sidecar write (no pending)")
		return
	_sidecar_write()

# SaveCharacter() builds a fresh SlotData per item with Update(), and Update()
# copies vanilla fields only -- the roll's metadata never makes it in. The save
# has already hit the disk by the time this runs, so reload it, put the rolls
# back on the saved copies in vanilla's own order, and write it again.
func _patch_character_save() -> void:
	var iface = _iface()
	if iface == null:
		return
	if not ResourceLoader.exists(CHARACTER_PATH):
		return
	var character = ResourceLoader.load(CHARACTER_PATH, "", ResourceLoader.CACHE_MODE_REPLACE)
	if character == null or not ("inventory" in character):
		return
	var inventory = character.get("inventory")
	var equipment = character.get("equipment")
	var catalog = character.get("catalog")
	var copied := 0
	if inventory is Array:
		copied += Store.mirror_list(_live_grid_slots(iface.get("inventoryGrid")), inventory)
	if equipment is Array:
		copied += Store.mirror_list(_live_equip_slots(iface.get("equipment")), equipment)
	if catalog is Array:
		copied += Store.mirror_list(_live_grid_slots(iface.get("catalogGrid")), catalog)
	if copied <= 0:
		return
	var err := ResourceSaver.save(character, CHARACTER_PATH)
	if err != OK:
		Log.warn("save: could not write the roll into Character.tres (code " + str(err) + ")")
		return
	Log.line("save: mirrored " + str(copied) + " roll(s) into Character.tres")

# Vanilla's loop: every child of the grid becomes one saved SlotData, in child
# order, with no filtering. null keeps the indexes aligned.
func _live_grid_slots(grid) -> Array:
	var out: Array = []
	if grid == null:
		return out
	for item in grid.get_children():
		if item != null and ("slotData" in item):
			out.append(item.slotData)
		else:
			out.append(null)
	return out

# Vanilla's loop: only real Slot nodes that hold an item contribute an entry.
func _live_equip_slots(equipment) -> Array:
	var out: Array = []
	if equipment == null:
		return out
	for slot in equipment.get_children():
		if not _is_equipment_slot(slot) or slot.get_child_count() == 0:
			continue
		var item = slot.get_child(0)
		if item != null and ("slotData" in item):
			out.append(item.slotData)
		else:
			out.append(null)
	return out

func on_load_character() -> void:
	Log.line("[RTL-DBG] HOOK on_load_character called")
	var data := _sidecar_read()
	var data_count := 0
	if data is Dictionary:
		if data.has("items") and data["items"] is Dictionary:
			data_count += data["items"].size()
		if data.has("by_uid") and data["by_uid"] is Dictionary:
			data_count += data["by_uid"].size()
	Log.line("[RTL-DBG] on_load_character: data.size=" + str(data_count))
	if data.is_empty():
		return
	var iface = _iface()
	Log.line("[RTL-DBG] on_load_character: iface=" + str(iface))
	if iface == null:
		return
	Log.line("[RTL-DBG] on_load_character: about to apply grid/cat/slots/cont")
	_apply_grid("inv", iface.get("inventoryGrid"), data)
	_apply_grid("cat", iface.get("catalogGrid"), data)
	var container_node2 = iface.get_node_or_null("Container")
	if container_node2 != null:
		_apply_all_under("cont", container_node2, data)
	else:
		_apply_grid("cont", _get_container_grid(iface), data)
	_apply_slots("eq", iface.get("equipment"), data)
	if _debug.should_log():
		Log.line("sidecar: restored " + str(data_count) + " rolls")

func on_new_game(_difficulty, _season) -> void:
	if FileAccess.file_exists(SIDECAR_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SIDECAR_PATH))
	Log.line("sidecar: cleared for a new run")
