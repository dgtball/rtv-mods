extends Node

const Rules = preload("res://mods/MoreCatFood/MoreCatFoodRules.gd")
const CatBed = preload("res://mods/MoreCatFood/MoreCatFoodCatBed.gd")
const FEEDER_SCRIPT_PATH := "res://Scripts/CatFeeder.gd"
const FEEDER_SUBCLASS_PATH := "res://mods/MoreCatFood/MoreCatFoodFeeder.gd"
const PATCH_META := "mcf_patched"
const CATBED_PATH := "/root/CatBedTray"
const INTERACTOR_PATH := "/root/Map/Core/Camera/Interactor"
const UI_PATH := "/root/Map/Core/UI/Interface"
const INTERACT_ACTION := "interact"
const HOLD_SECONDS := 0.5

# --- Core ---
var _spinning := false
var _target: Node3D
var _origin_rotation: Vector3
var _origin_position: Vector3
var _origin_scale: Vector3
var _audio: AudioStreamPlayer
var _beat_timer: Timer
var _time := 0.0
var _duration := 12.0

# --- Motion ---
var _bob_amp := 0.04
var _bob_speed := 6.0
var _scale_punch := 1.18
var _current_scale_mult := 1.0
var _squash := 1.0

# --- Clones ---
var _targets: Array[Node3D] = []
var _clones: Array[Node] = []
var _offsets: Array[Vector3] = []
var _clones_spawned := false
var _hidden := false
var _last_state := -1
var _face_yaw := 0.0
var _face_from_yaw := 0.0
var _face_captured := false

# --- Visual Effects ---
var _light: OmniLight3D
var _particles: GPUParticles3D
var _rainbow_hue := 0.0
var _flash_strength := 0.0
var _glow_strength := 0.0
var _material_cache: Dictionary = {}
var _invisible_until: Dictionary = {}  # cat -> time when becomes visible again

# --- Cat Bed tray shim ---
var _cb_active := false
var _cb_swallow := false
var _cb_hold_time := 0.0
var _cb_tray: Node
var _cb_bed: Node
var _cb_slot: Node

func _ready() -> void:
	_audio = AudioStreamPlayer.new()
	add_child(_audio)
	var bytes = FileAccess.get_file_as_bytes(Rules.TRACK_PATH)
	if bytes.size() > 0:
		var stream = AudioStreamOggVorbis.load_from_buffer(bytes)
		if stream:
			_audio.stream = stream
		else:
			push_warning("OIIA: failed to load ogg stream")
	else:
		push_warning("OIIA: track not found at " + Rules.TRACK_PATH)

	_beat_timer = Timer.new()
	_beat_timer.wait_time = Rules.BEAT_INTERVAL
	_beat_timer.one_shot = false
	add_child(_beat_timer)
	_beat_timer.timeout.connect(_on_beat)

	get_tree().node_added.connect(_on_node_added)
	call_deferred("_sweep_tree")

	# Cat Bed runs its press/hold logic at -1000; one step earlier lets the
	# shim hide a tray press that carries our food before cat-bed sees it.
	process_physics_priority = -1001
	set_physics_process(true)

func _on_node_added(node: Node) -> void:
	var script = node.get_script()
	if script == null or str(script.resource_path) != FEEDER_SCRIPT_PATH:
		return
	call_deferred("_patch", node)

func _sweep_tree() -> void:
	_sweep_node(get_tree().root)

func _sweep_node(node: Node) -> void:
	var script = node.get_script()
	if script != null and str(script.resource_path) == FEEDER_SCRIPT_PATH:
		call_deferred("_patch", node)
	for child in node.get_children():
		_sweep_node(child)

func _patch(feeder: Node) -> void:
	if feeder == null or not is_instance_valid(feeder) or feeder.has_meta(PATCH_META):
		return

	var cat = feeder.get("cat")
	var collision = feeder.get("collision")
	var items = feeder.get("feedItems")
	var out: Array = []
	if items != null:
		for item in items:
			out.append(item)

	for path in Rules.FOOD_PATHS:
		var item = load(path)
		if item == null:
			continue
		var found := false
		for existing in out:
			if existing != null and str(existing.resource_path) == str(item.resource_path):
				found = true
				break
		if not found:
			out.append(item)

	var subclass = load(FEEDER_SUBCLASS_PATH)
	if subclass != null:
		feeder.set_script(subclass)

	feeder.set("cat", cat)
	feeder.set("collision", collision)

	var target = feeder.get("feedItems")
	if target is Array:
		for item in out:
			if not target.has(item):
				target.append(item)
	else:
		feeder.set("feedItems", out)

	feeder.set_meta(PATCH_META, true)

# ===================== Cat Bed tray shim =====================
# cat-bed replaces the feeding box with a tray of its own and feeds from a
# hardcoded list, so our foods never reach the vanilla feeder patch. When the
# CatBedTray autoload is present, intercept the tray press first and stock our
# food as a regular can. Beer is not stocked here: cat-bed rejects it.

func _physics_process(delta: float) -> void:
	if not InputMap.has_action(INTERACT_ACTION):
		return
	if _cb_active:
		_cb_hold_time += delta
		# Keyboard auto-repeat re-arms the action while the key is down.
		if Input.is_action_just_pressed(INTERACT_ACTION):
			Input.action_release(INTERACT_ACTION)
		if not _interact_physically_held():
			_cb_finish_press(false)
		elif _cb_hold_time >= HOLD_SECONDS:
			_cb_finish_press(true)
		return
	if _cb_swallow:
		if _interact_physically_held():
			if Input.is_action_just_pressed(INTERACT_ACTION):
				Input.action_release(INTERACT_ACTION)
			return
		_cb_swallow = false
	if not Input.is_action_just_pressed(INTERACT_ACTION):
		return
	var catbed := _cb_catbed()
	if catbed == null or _cb_feed_blocked(catbed) or not _cb_interaction_ok(catbed):
		return
	var interactor := get_node_or_null(INTERACTOR_PATH)
	if interactor == null:
		return
	var tray := CatBed.looked_tray(interactor)
	if tray != null:
		_cb_on_press(tray)
		return
	var bed := CatBed.looked_bed(interactor)
	if bed == null:
		return
	if catbed.has_method("IsCatOnBed") and not bool(catbed.call("IsCatOnBed", bed)):
		return
	_cb_on_bed_press(bed)

# Takes the press when the player looks at a cat-bed tray and carries one of
# our foods. Returns true when the press was hidden from cat-bed.
func _cb_on_press(tray: Node) -> bool:
	var catbed := _cb_catbed()
	if catbed == null or tray == null or not is_instance_valid(tray):
		return false
	if _cb_feed_blocked(catbed) or not _cb_interaction_ok(catbed):
		return false
	var iface := _cb_interface()
	if iface == null:
		return false
	var grid = iface.get("inventoryGrid")
	if grid == null:
		return false
	var slot := _cb_find_food(grid, false)
	if slot == null:
		return false
	_cb_active = true
	_cb_swallow = true
	_cb_hold_time = 0.0
	_cb_tray = tray
	_cb_slot = slot
	if InputMap.has_action(INTERACT_ACTION):
		Input.action_release(INTERACT_ACTION)
	return true

# Takes the press when the player looks at a cat-bed with the cat on it and we
# carry one of our foods. Cat-bed's own food lookup never sees those items, so
# without this it would swallow the press as a pat.
func _cb_on_bed_press(bed: Node) -> bool:
	var catbed := _cb_catbed()
	if catbed == null or bed == null or not is_instance_valid(bed):
		return false
	var iface := _cb_interface()
	if iface == null:
		return false
	var grid = iface.get("inventoryGrid")
	if grid == null:
		return false
	if not _cb_bed_gate(catbed, bed, grid):
		return false
	var slot := _cb_find_food(grid)
	if slot == null:
		return false
	_cb_active = true
	_cb_swallow = true
	_cb_hold_time = 0.0
	_cb_tray = null
	_cb_bed = bed
	_cb_slot = slot
	if InputMap.has_action(INTERACT_ACTION):
		Input.action_release(INTERACT_ACTION)
	return true

# Mirrors the conditions under which cat-bed leaves a bed press to the vanilla
# Interactor. When it is mid-meal we also show its message and hide the press.
func _cb_bed_gate(catbed: Node, bed: Node, grid: Node) -> bool:
	if _cb_feed_blocked(catbed) or not _cb_interaction_ok(catbed) or _cb_cat_dead(catbed):
		return false
	if catbed.has_method("IsCatOnBed") and not bool(catbed.call("IsCatOnBed", bed)):
		return false
	var hold = catbed.get("_hold_active")
	if hold != null and bool(hold):
		return false
	var swallow = catbed.get("_swallow_presses")
	if swallow != null and bool(swallow):
		return false
	var cooldown = catbed.get("_take_cooldown")
	if cooldown != null and float(cooldown) > 0.0:
		return false
	var awake = catbed.get("_awake_timer")
	var eating = catbed.get("_bed_eating")
	if awake != null and eating != null and float(awake) > 0.0 and bool(eating):
		_cb_msg(catbed, "Cat is eating, do not disturb", Color.WHITE)
		if InputMap.has_action(INTERACT_ACTION):
			Input.action_release(INTERACT_ACTION)
		_cb_swallow = true
		return false
	if catbed.has_method("_find_food_in_grid") and catbed.call("_find_food_in_grid", grid) != null:
		return false
	return true

# Hold on a bed keeps our food and hands the press back to cat-bed's own
# take/pet/recall logic. Short press is filled in by the feeding branch below.
func _cb_finish_bed_press(held: bool) -> void:
	var bed: Node = _cb_bed
	var slot: Node = _cb_slot
	_cb_bed = null
	_cb_slot = null
	if bed == null or not is_instance_valid(bed):
		return
	var catbed := _cb_catbed()
	if catbed == null:
		return
	if held:
		if catbed.has_method("_finish_bed_press"):
			catbed.set("_hold_bed", bed)
			catbed.call("_finish_bed_press", true)
		return

	var iface := _cb_interface()
	var grid = iface.get("inventoryGrid") if iface != null else null
	if grid == null:
		return
	if slot == null or not is_instance_valid(slot) or not grid.is_ancestor_of(slot):
		slot = _cb_find_food(grid)
		if slot == null:
			return

	var path := CatBed.food_path_for_slot(slot)
	var food_name := ""
	var data = slot.get("slotData")
	if data != null and is_instance_valid(data):
		var item = data.get("itemData")
		if item != null and is_instance_valid(item):
			food_name = str(item.get("name"))

	if grid.has_method("Pick"):
		grid.call("Pick", slot)
	elif slot.get_parent() == grid:
		grid.remove_child(slot)
	slot.queue_free()

	var gd = catbed.get("gameData")
	if gd != null:
		gd.set("cat", 100.0)
	if iface != null and iface.has_method("UpdateStats"):
		iface.call("UpdateStats", false)
	_cb_msg(catbed, "Cat Fed (" + food_name + ")", Color.GREEN)
	catbed.set("_bed_eating", true)
	catbed.set("_wander_trigger", true)

	var seconds := 20.0
	var script = catbed.get_script()
	if script != null:
		seconds = float(script.get_script_constant_map().get("BED_FEED_SECONDS", 20.0))
	if catbed.has_method("_wake_cat_on_bed"):
		catbed.call("_wake_cat_on_bed", seconds, "Cat_Eat")

	if CatBed.is_beer_path(path) and not _cb_cat_dead(catbed):
		var cat: Node3D = null
		if catbed.has_method("_find_cat_node"):
			cat = catbed.call("_find_cat_node")
		start_oiia(null, cat)

# Short press stocks our food; hold keeps cat-bed's "take a can back".
func _cb_finish_press(held: bool) -> void:
	_cb_active = false
	if _cb_bed != null:
		_cb_finish_bed_press(held)
		return
	var tray: Node = _cb_tray
	var slot: Node = _cb_slot
	_cb_tray = null
	_cb_slot = null
	if tray == null or not is_instance_valid(tray):
		return
	var catbed := _cb_catbed()
	if catbed == null:
		return
	if held:
		if catbed.has_method("TrayTake"):
			catbed.call("TrayTake", tray)
		return

	var iface := _cb_interface()
	var grid = iface.get("inventoryGrid") if iface != null else null
	if grid == null:
		return

	var path := ""
	if slot != null and is_instance_valid(slot) and grid.is_ancestor_of(slot):
		path = CatBed.food_path_for_slot(slot)
	if path == "":
		slot = _cb_find_food(grid, false)
		if slot == null:
			# The food vanished during the hold: let cat-bed do its normal pass.
			if catbed.has_method("TrayAdd"):
				catbed.call("TrayAdd", tray)
			return
		path = CatBed.food_path_for_slot(slot)

	var codes := str(catbed.call("TrayCodes", tray)) if catbed.has_method("TrayCodes") else ""
	var capacity := int(catbed.call("Capacity")) if catbed.has_method("Capacity") else 6
	var stock := codes.length()
	if stock >= capacity:
		_cb_msg(catbed, "The tray is full [" + str(stock) + "/" + str(capacity) + "]", Color.RED)
		if iface != null and iface.has_method("PlayError"):
			iface.call("PlayError")
		return

	var food_name := ""
	var data = slot.get("slotData")
	if data != null and is_instance_valid(data):
		var item = data.get("itemData")
		if item != null and is_instance_valid(item):
			food_name = str(item.get("name"))

	if grid.has_method("Pick"):
		grid.call("Pick", slot)
	elif slot.get_parent() == grid:
		grid.remove_child(slot)
	slot.queue_free()

	catbed.call("_set_tray_codes", tray, CatBed.tray_codes_after_add(codes))
	if iface != null and iface.has_method("UpdateStats"):
		iface.call("UpdateStats", false)
	_cb_msg(catbed, "Tray stocked: " + food_name + " [" + str(stock + 1) + "/" + str(capacity) + "]", Color.GREEN)
	if catbed.has_method("_play_pickup"):
		catbed.call("_play_pickup")

func _cb_catbed() -> Node:
	return get_node_or_null(CATBED_PATH)

func _cb_interface() -> Node:
	return get_node_or_null(UI_PATH)

func _cb_find_food(grid: Node, beer_allowed := true) -> Node:
	for child in grid.get_children():
		if child == null or not is_instance_valid(child):
			continue
		var path := CatBed.food_path_for_slot(child)
		if path == "":
			continue
		if not beer_allowed and CatBed.is_beer_path(path):
			continue
		return child
	return null

func _cb_feed_blocked(catbed: Node) -> bool:
	var gd = catbed.get("gameData")
	if gd == null:
		return false
	for key in ["decor", "freeze", "isPlacing", "isOccupied"]:
		var value = gd.get(key)
		if value != null and bool(value):
			return true
	return false

func _cb_interaction_ok(catbed: Node) -> bool:
	var gd = catbed.get("gameData")
	if gd == null:
		return true
	var value = gd.get("interaction")
	return value == null or bool(value)

func _cb_cat_dead(catbed: Node) -> bool:
	var gd = catbed.get("gameData")
	if gd == null:
		return false
	var value = gd.get("catDead")
	return value != null and bool(value)

func _cb_msg(catbed: Node, text: String, color: Color) -> void:
	if catbed != null and catbed.has_method("_msg"):
		catbed.call("_msg", text, color)

# Input.action_release hides the press from the game, after which the action
# reads as released until the next key event, so the hold is read from the
# physical key/button bound to it (same trick as cat-bed).
func _interact_physically_held() -> bool:
	if not InputMap.has_action(INTERACT_ACTION):
		return false
	for event in InputMap.action_get_events(INTERACT_ACTION):
		if event is InputEventKey:
			var code: int = int(event.physical_keycode)
			if code != KEY_NONE and Input.is_physical_key_pressed(code):
				return true
			code = int(event.keycode)
			if code != KEY_NONE and Input.is_key_pressed(code):
				return true
		elif event is InputEventMouseButton:
			if Input.is_mouse_button_pressed(event.button_index):
				return true
		elif event is InputEventJoypadButton:
			if Input.is_joy_button_pressed(event.device, event.button_index):
				return true
	return false

# ===================== OIIA =====================

func start_oiia(feeder: Node = null, direct_cat: Node3D = null) -> void:
	if _spinning:
		return

	var cat_node: Variant = direct_cat
	if not (cat_node is Node3D) and feeder != null and is_instance_valid(feeder):
		cat_node = feeder.get("cat")
	if cat_node == null or not (cat_node is Node3D):
		var cats = get_tree().get_nodes_in_group("Cat")
		if cats.size() > 0 and cats[0] is Node3D:
			cat_node = cats[0]
		else:
			push_warning("OIIA: cat node not found")
			return

	_target = cat_node
	_origin_rotation = _target.rotation
	_origin_position = _target.position
	_origin_scale = _target.scale
	_time = 0.0
	_current_scale_mult = 1.0
	_squash = 1.0
	_spinning = true
	_clones_spawned = false
	_hidden = false
	_last_state = -1
	_face_captured = false
	_targets = [_target]
	_offsets = [Vector3.ZERO]
	_invisible_until.clear()

	_setup_effects(_target)

	var start_animator := _target.get_node_or_null("Animator") as AnimationTree
	if start_animator != null:
		start_animator.set("active", false)

	_duration = 12.0
	if _audio != null and _audio.stream != null:
		_duration = _audio.stream.get_length()
		_audio.play()

	_beat_timer.wait_time = Rules.BEAT_INTERVAL
	_beat_timer.start()
	# Таймер должен замирать вместе с игрой: иначе пауза в меню отсчитает
	# финал раньше покадрового времени и кот застынет над коробкой.
	get_tree().create_timer(_duration, false).timeout.connect(stop_oiia)

	print("OIIA OIIA started!")

func _setup_effects(cat: Node3D) -> void:
	# Light
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.85, 0.6)
	_light.light_energy = 0.0
	_light.omni_range = 5.0
	_light.shadow_enabled = false
	add_child(_light)
	_light.position = Vector3(0, 0.45, 0)

	# Smoke particles
	_particles = GPUParticles3D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 45.0
	mat.initial_velocity_min = 0.5
	mat.initial_velocity_max = 1.6
	mat.gravity = Vector3(0, 0.3, 0)
	mat.scale_min = 0.12
	mat.scale_max = 0.35
	mat.color = Color(0.65, 0.65, 0.7, 0.55)
	_particles.process_material = mat
	_particles.amount = 40
	_particles.lifetime = 1.3
	_particles.emitting = true
	cat.add_child(_particles)
	_particles.position = Vector3(0, 0.05, 0)

func _set_cat_state(cat: Node3D, want: int) -> void:
	if want < 0 or not is_instance_valid(cat):
		return
	var animator := cat.get_node_or_null("Animator") as AnimationTree
	if animator != null and bool(animator.get("active")):
		animator.set("active", false)
	var anims := cat.get_node_or_null("Animations") as AnimationPlayer
	if anims != null:
		var anim_name := Rules.state_anim(want)
		if anims.get_assigned_animation() != anim_name or not anims.is_playing():
			anims.play(anim_name)
	cat.set("currentState", want)

func _spawn_clones() -> void:
	if _clones_spawned or not is_instance_valid(_target):
		return
	_clones_spawned = true
	_target.visible = true

	var half := Rules.CLONE_SPACING * 0.5
	var corners: Array[Vector3] = [
		Vector3(-half, 0.0, -half),
		Vector3( half, 0.0, -half),
		Vector3( half, 0.0,  half),
		Vector3(-half, 0.0,  half),
	]

	_offsets[0] = corners[0]
	_target.position = _origin_position + corners[0] + Vector3(0.0, Rules.lift_at(_time), 0.0)

	var want := Rules.cat_state_at(_time)
	for i in range(1, 4):
		var cat := _target.duplicate() as Node3D
		_target.get_parent().add_child(cat)
		var yaw := deg_to_rad(Rules.CLONE_ANGLE_STEP_DEG * float(i))
		cat.rotation = _target.rotation + Vector3(0.0, yaw, 0.0)
		cat.scale = _origin_scale
		cat.position = _origin_position + corners[i] + Vector3(0.0, Rules.lift_at(_time), 0.0)
		cat.visible = true
		_set_cat_state(cat, want)
		_clones.append(cat)
		_targets.append(cat)
		_offsets.append(corners[i])

func _apply_state() -> void:
	var want := Rules.cat_state_at(_time)
	if want < 0 or want == _last_state:
		return
	_last_state = want
	for cat in _targets:
		_set_cat_state(cat, want)

func _merge_factor() -> float:
	if _time < Rules.MERGE_START:
		return 0.0
	return Rules.smooth01((_time - Rules.MERGE_START) / (Rules.MERGE_END - Rules.MERGE_START))

# Слияние закончено — копий больше нет, остаётся только исходный кот.
func _clear_clones() -> void:
	for cat in _clones:
		if not is_instance_valid(cat):
			continue
		_clear_cat_look(cat)
		(cat as Node).queue_free()
	if not _targets.is_empty():
		(_targets[0] as Node3D).visible = true
	_targets.resize(1)
	_offsets.resize(1)
	_clones.clear()
	_invisible_until.clear()

# ---------- Effects helpers ----------

# Оверрайд меша один на все поверхности — для него одна запись на меш;
# поверхностные оверрайды — по записи на поверхность. Копируем исходный
# материал один раз, но не меняем его внешний вид: текстуры и альбедо кота
# остаются ванильными, цвет даёт только OmniLight.
func _apply_cat_look(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh := child as MeshInstance3D
			var count := mesh.mesh.get_surface_count() if mesh.mesh != null else 0
			if mesh.material_override != null:
				_tint_cached_material(mesh, "override:" + str(mesh.get_instance_id()), "override", 0, mesh.material_override)
			else:
				for i in range(count):
					_tint_cached_material(mesh, str(mesh.get_instance_id()) + ":" + str(i), "surface", i, mesh.get_surface_override_material(i))
		_apply_cat_look(child)

func _tint_cached_material(mesh: MeshInstance3D, key: String, channel: String, surface: int, original: Material) -> void:
	var base: Material = original
	if base == null:
		base = mesh.get_active_material(surface)
	# Игровой шейдер не трогаем: подмена его пустым StandardMaterial3D
	# сжирает текстуру и альфу — отсюда белая маска на морде кота.
	if base is ShaderMaterial:
		return
	var entry = _material_cache.get(key)
	if entry == null:
		var tinted: StandardMaterial3D
		if base is StandardMaterial3D:
			tinted = (base as StandardMaterial3D).duplicate() as StandardMaterial3D
		else:
			tinted = StandardMaterial3D.new()
			if base != null and "albedo_color" in base:
				tinted.albedo_color = base.get("albedo_color")
		entry = {
			"mesh": mesh,
			"surface": surface,
			"channel": channel,
			"original": original,
			"tinted": tinted,
		}
		_material_cache[key] = entry
		_set_cached_material(mesh, channel, surface, tinted)
	var mat: StandardMaterial3D = entry["tinted"] as StandardMaterial3D
	mat.rim_enabled = false
	mat.emission_enabled = false

func _set_cached_material(mesh: MeshInstance3D, channel: String, surface: int, mat: Material) -> void:
	if channel == "override":
		mesh.material_override = mat
	else:
		mesh.set_surface_override_material(surface, mat)

# Возвращает ровно те материалы, которые занял забег, и чистит их записи.
func _clear_cat_look(node: Node) -> void:
	var affected: Array[Node] = [node]
	for child in node.find_children("*", "", true, false):
		affected.append(child)
	var to_erase: Array[String] = []
	for key in _material_cache.keys():
		var entry = _material_cache[key]
		if not affected.has(entry["mesh"]):
			continue
		var mesh: MeshInstance3D = entry["mesh"] as MeshInstance3D
		if is_instance_valid(mesh):
			_set_cached_material(mesh, str(entry["channel"]), int(entry["surface"]), entry["original"])
		to_erase.append(str(key))
	for key in to_erase:
		_material_cache.erase(key)

func _do_flash() -> void:
	_flash_strength = 1.0
	if _light:
		_light.light_energy = 7.0
		_light.light_color = Color.from_hsv(_rainbow_hue, 0.8, 1.0)

func _make_random_invisible() -> void:
	if _targets.is_empty():
		return
	var candidates: Array[Node3D] = []
	for cat in _targets:
		if is_instance_valid(cat) and cat.visible and not _invisible_until.has(cat):
			candidates.append(cat)
	if candidates.is_empty():
		return
	var victim: Node3D = candidates[randi() % candidates.size()]
	victim.visible = false
	_invisible_until[victim] = _time + randf_range(1.1, 2.0)

func _update_invisibility() -> void:
	var to_remove: Array = []
	for cat in _invisible_until.keys():
		if _time >= _invisible_until[cat]:
			if is_instance_valid(cat):
				cat.visible = true
			to_remove.append(cat)
	for cat in to_remove:
		_invisible_until.erase(cat)

# ---------- Beat & Process ----------

func _on_beat() -> void:
	if not _spinning or not is_instance_valid(_target):
		return

	var spin := Rules.spin_factor(_time)
	if spin < 0.01:
		return

	var impulse := deg_to_rad(Rules.BEAT_IMPULSE_DEG)
	var hop := 0.035 * (1.0 - _merge_factor())

	for i in range(_targets.size()):
		var cat: Node3D = _targets[i]
		if not is_instance_valid(cat):
			continue
		if i == 0 and _time >= Rules.SPIN_BOX_START and _time < Rules.CLONE_REVEAL_AT:
			continue
		cat.rotate_y(impulse)
		var h := Rules.lift_at(_time)
		if _time >= Rules.CLONE_REVEAL_AT:
			# Бит-подскок не должен пробивать пол 0.32 и потолок хаоса.
			h = clampf(Rules.cat_height(_time, i) + hop, Rules.LIFT_HEIGHT, Rules.CHAOS_LIFT_CENTER + Rules.CHAOS_LIFT_AMP)
		cat.position.y = _origin_position.y + h

	_current_scale_mult = _scale_punch
	_squash = 0.72
	_do_flash()

	if _time > 34.0 and randf() < 0.28:
		_make_random_invisible()

func _process(delta: float) -> void:
	if not _spinning:
		return
	if not is_instance_valid(_target):
		stop_oiia()
		return

	_time += delta

	if not _hidden and _time >= Rules.CLONE_HIDE_AT:
		_hidden = true
		_target.visible = false

	if _hidden and not _clones_spawned and _time >= Rules.CLONE_REVEAL_AT:
		_spawn_clones()

	_apply_state()
	_update_invisibility()
	if _time >= Rules.CLONE_CLEAR_AT and not _clones.is_empty():
		_clear_clones()

	# Light-only glow grows toward peak (clamp weight: lerpf extrapolates on large deltas)
	if _time > 26.0 and _time < 55.0:
		_glow_strength = lerpf(_glow_strength, 2.8, clampf(delta * 1.5, 0.0, 1.0))
	else:
		_glow_strength = lerpf(_glow_strength, 0.0, clampf(delta * 3.0, 0.0, 1.0))

	var merge := _merge_factor()
	var lift := Rules.lift_at(_time)
	var bob := 0.0
	if _time < Rules.SPIN_BOX_START:
		bob = sin(_time * _bob_speed) * _bob_amp * (1.0 - merge)
	var chaos := Rules.chaos_amount(_time)
	var orbit := Rules.orbit_scale(_flash_strength, merge)

	_current_scale_mult = lerpf(_current_scale_mult, 1.0, clampf(delta * 8.0, 0.0, 1.0))
	_squash = lerpf(_squash, 1.0, clampf(delta * 7.0, 0.0, 1.0))
	var stretch := Vector3(1.0 / maxf(_squash, 0.15), _squash, 1.0 / maxf(_squash, 0.15))
	var scale_now := _origin_scale * _current_scale_mult * stretch

	var spin := Rules.SPIN_SPEED * Rules.spin_factor(_time) * delta
	var facing := _time >= Rules.SPIN_BOX_START and _time < Rules.CLONE_REVEAL_AT and not _clones_spawned

	if facing:
		if not _face_captured:
			_face_captured = true
			_face_from_yaw = _target.rotation.y
		var k := Rules.smooth01((_time - Rules.SPIN_BOX_START) / (Rules.SPIN_BOX_END - Rules.SPIN_BOX_START))
		_target.rotation.y = lerp_angle(_face_from_yaw, _face_yaw, k)

	for i in range(_targets.size()):
		var cat: Node3D = _targets[i]
		if not is_instance_valid(cat):
			continue
		if not (i == 0 and facing):
			cat.rotate_y(spin)

		var off: Vector3 = _offsets[i] * orbit
		var jitter: Vector3 = Rules.chaos_offset(i, _time) * chaos
		var h := lift + bob
		if _time >= Rules.CLONE_REVEAL_AT:
			h = Rules.cat_height(_time, i)
		if i == 0:
			h = lerpf(h, 0.0, Rules.descent_factor(_time))
		cat.position = Vector3(
			_origin_position.x + (off.x + jitter.x) * (1.0 - merge),
			_origin_position.y + h,
			_origin_position.z + (off.z + jitter.z) * (1.0 - merge)
		)
		cat.scale = scale_now * Rules.scale_wave(_time, i)
		_rainbow_hue = fmod(_rainbow_hue + delta * 0.38, 1.0)
		_apply_cat_look(cat)

	# Light & flash — один свет в центре четверки
	_flash_strength = lerpf(_flash_strength, 0.0, clampf(delta * 5.5, 0.0, 1.0))
	if _light:
		var center := Vector3.ZERO
		var count := 0
		for cat in _targets:
			if is_instance_valid(cat):
				center += (cat as Node3D).global_position
				count += 1
		if count > 0:
			_light.global_position = center / float(count) + Vector3(0.0, 0.45, 0.0)
		_light.light_energy = lerpf(_light.light_energy, 0.5 + _flash_strength * 6.0 + _glow_strength * 0.4, clampf(delta * 9.0, 0.0, 1.0))

func stop_oiia() -> void:
	if not _spinning:
		return

	_spinning = false
	_beat_timer.stop()
	if _audio != null:
		_audio.stop()

	# Capture this run's nodes and transforms before the await: another beer
	# fed during the final 0.9 s starts a new run and overwrites the fields.
	var run_target: Node3D = _target
	var run_origin_rotation: Vector3 = _origin_rotation
	var run_origin_scale: Vector3 = _origin_scale
	var run_clones: Array = _clones.duplicate()
	var run_light: OmniLight3D = _light
	var run_particles: GPUParticles3D = _particles

	# === Final look at camera + ForceMeow (only original) ===
	if is_instance_valid(run_target):
		run_target.visible = true
		# Face the player camera if possible
		var cam := get_viewport().get_camera_3d()
		if cam:
			var dir := cam.global_position - run_target.global_position
			dir.y = 0.0
			if dir.length() > 0.01:
				run_target.look_at(run_target.global_position + dir, Vector3.UP)

		# Meow
		if run_target.has_method("ForceMeow"):
			run_target.call("ForceMeow")
		else:
			var meow_node = run_target.get_node_or_null("Meow") or run_target
			if meow_node and meow_node.has_method("ForceMeow"):
				meow_node.call("ForceMeow")

		# Final flash
		_do_flash()
		if run_particles:
			run_particles.amount = 70
			run_particles.emitting = true

	# Small delay so the final moment can be seen
	await get_tree().create_timer(0.9).timeout

	var same_run := (_light == run_light)
	# Restore the ending run unless a new run reused the very same cat.
	if is_instance_valid(run_target) and (same_run or _target != run_target):
		_clear_cat_look(run_target)
		run_target.rotation = run_origin_rotation
		run_target.scale = run_origin_scale
		var animator := run_target.get_node_or_null("Animator") as AnimationTree
		if animator != null:
			animator.set("active", true)
		run_target.set("currentState", Rules.STATE_IDLE)

	for cat in run_clones:
		if is_instance_valid(cat):
			(cat as Node).queue_free()
	if is_instance_valid(run_light):
		run_light.queue_free()
	if is_instance_valid(run_particles):
		run_particles.queue_free()

	_clones.clear()
	if same_run:
		_material_cache.clear()
		_targets.clear()
		_offsets.clear()
		_invisible_until.clear()
		_clones_spawned = false
		_hidden = false
		_last_state = -1
		_target = null

	print("OIIA ended")