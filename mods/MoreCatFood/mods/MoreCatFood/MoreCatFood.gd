extends Node

const Rules = preload("res://mods/MoreCatFood/MoreCatFoodRules.gd")
const FEEDER_SCRIPT_PATH := "res://Scripts/CatFeeder.gd"
const FEEDER_SUBCLASS_PATH := "res://mods/MoreCatFood/MoreCatFoodFeeder.gd"
const PATCH_META := "mcf_patched"

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
var _emission_strength := 0.0
var _material_cache: Dictionary = {}
var _invisible_until: Dictionary = {}  # cat -> time when becomes visible again

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

# ===================== OIIA =====================

func start_oiia(feeder: Node) -> void:
	if _spinning or feeder == null or not is_instance_valid(feeder):
		return

	var cat_node = feeder.get("cat")
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
	get_tree().create_timer(_duration).timeout.connect(stop_oiia)

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

# ---------- Effects helpers ----------

func _apply_rainbow_and_emission(cat: Node3D, delta: float) -> void:
	_rainbow_hue = fmod(_rainbow_hue + delta * 0.38, 1.0)
	var col := Color.from_hsv(_rainbow_hue, 0.7, 1.0)
	_apply_cat_look(cat, col, _emission_strength)

# Один материал на surface: ключ instance_id меша + индекс поверхности.
# Копируем исходный материал один раз и трогаем только подсветку краёв:
# текстуры и альбедо кота остаются ванильными.
func _apply_cat_look(node: Node, color: Color, emission: float) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh := child as MeshInstance3D
			var count := mesh.mesh.get_surface_count() if mesh.mesh != null else 0
			for i in range(count):
				var key := str(mesh.get_instance_id()) + ":" + str(i)
				var rec = _material_cache.get(key)
				if rec == null:
					var channel := "surface"
					var original: Material = mesh.get_surface_override_material(i)
					if mesh.material_override != null:
						channel = "override"
						original = mesh.material_override
					var tinted: StandardMaterial3D
					if original is StandardMaterial3D:
						tinted = (original as StandardMaterial3D).duplicate() as StandardMaterial3D
					else:
						tinted = StandardMaterial3D.new()
						if original != null and "albedo_color" in original:
							tinted.albedo_color = original.get("albedo_color")
					rec = {
						"mesh": mesh,
						"surface": i,
						"channel": channel,
						"original": original,
						"tinted": tinted,
					}
					_material_cache[key] = rec
					if channel == "override":
						mesh.material_override = tinted
					else:
						mesh.set_surface_override_material(i, tinted)
				var mat: StandardMaterial3D = rec["tinted"] as StandardMaterial3D
				mat.rim_enabled = emission > 0.01
				mat.rim = clampf(emission * 0.12, 0.0, 0.3)
				mat.rim_tint = 0.0
				mat.emission_enabled = emission > 0.01
				mat.emission = color
				mat.emission_energy_multiplier = clampf(emission * 0.08, 0.0, 0.25)
		_apply_cat_look(child, color, emission)

# Возвращает ровно те материалы, которые занял забег, и чистит их записи.
func _clear_cat_look(node: Node) -> void:
	var affected: Array[Node] = [node]
	for child in node.find_children("*", "", true, false):
		affected.append(child)
	var to_erase: Array[String] = []
	for key in _material_cache.keys():
		var rec = _material_cache[key]
		if not affected.has(rec["mesh"]):
			continue
		var mesh: MeshInstance3D = rec["mesh"] as MeshInstance3D
		if is_instance_valid(mesh):
			if rec["channel"] == "override":
				mesh.material_override = rec["original"]
			else:
				mesh.set_surface_override_material(int(rec["surface"]), rec["original"])
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

	# Emission grows toward peak (clamp weight: lerpf extrapolates on large deltas)
	if _time > 26.0 and _time < 55.0:
		_emission_strength = lerpf(_emission_strength, 2.8, clampf(delta * 1.5, 0.0, 1.0))
	else:
		_emission_strength = lerpf(_emission_strength, 0.0, clampf(delta * 3.0, 0.0, 1.0))

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
		cat.position = Vector3(
			_origin_position.x + (off.x + jitter.x) * (1.0 - merge),
			_origin_position.y + h,
			_origin_position.z + (off.z + jitter.z) * (1.0 - merge)
		)
		cat.scale = scale_now * Rules.scale_wave(_time, i)
		_apply_rainbow_and_emission(cat, delta)

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
		_light.light_energy = lerpf(_light.light_energy, 0.5 + _flash_strength * 6.0 + _emission_strength * 0.4, clampf(delta * 9.0, 0.0, 1.0))

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
	var run_origin_position: Vector3 = _origin_position
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
		run_target.position = run_origin_position
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