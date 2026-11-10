extends SceneTree

# Гейт смертельного удара живёт целиком в pre-хуке: до ванильного тела
# AI.Death видно исходное состояние. Труп приходит с dead = true, а ваниль
# ставит dead = true только внутри Death — поэтому одного чтения dead хватает.
# Оружейный урон вычитает health и зовёт Death лишь при health <= 0; взрыв
# зовёт Death напрямую, не трогая health, — для него проверяется только dead.
# Мини-HUD делает то же самое, но со снимками реестра; здесь 3 чтения свойств.

const KC = preload("res://mods/VTK/VTKKillCounter.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

class FakeVariant extends RefCounted:
	var faction := 1
	var name := "Bandit"

class FakeAgent extends Node3D:
	var dead := false
	var health := 100
	var active := true
	var variant = FakeVariant.new()
	var nickname := ""

	func Activate() -> void:
		pass

class FakeLib:
	var _caller = null

class TestHooks extends "res://mods/VTK/VTKHooks.gd":
	pass

func _init() -> void:
	process_frame.connect(_run)

# Ванильный путь: WeaponDamage вычитает health и зовёт Death только при
# health <= 0; ExplosionDamage зовёт Death без правки health. Pre-хук видит
# состояние ДО тела Death, поэтому dead ставим уже после вызова — как ваниль.
func _die_pre(h, lib, ai, explosion := false, damage := 50.0) -> void:
	if not explosion:
		ai.health -= damage
	lib._caller = ai
	h._on_ai_death(Vector3.ZERO, 10.0)
	ai.dead = true

func _run() -> void:
	t_gate_predicate()
	t_weapon_kill_counted()
	t_corpse_not_counted()
	t_explosion_counted_with_health()
	t_live_weapon_rejected()
	t_non_player_event_only()
	t_second_death_ignored()
	t_reset_clears_state()
	if fails == 0:
		print("Death gate tests passed")
		quit(0)
	else:
		print("Death gate tests failed: ", fails)
		quit(1)

func t_gate_predicate() -> void:
	ck(KC.death_is_lethal(false, 0, false), "живой + health 0 — смертельный удар")
	ck(KC.death_is_lethal(false, -12.5, false), "живой + health < 0 — смертельный удар")
	ck(KC.death_is_lethal(false, 100, true), "живой + взрыв — смерть без урона здоровью")
	ck(not KC.death_is_lethal(true, 0, false), "мёртвый до удара — не убийство")
	ck(not KC.death_is_lethal(true, 0, true), "мёртвый + взрыв — труп не считается")
	ck(not KC.death_is_lethal(false, 20, false), "живой + health > 0 — не смертельно")
	ck(not KC.death_is_lethal(null, 0, false), "нет dead — не считаем")
	ck(not KC.death_is_lethal(false, null, false), "нет health — не считаем")
	ck(not KC.death_is_lethal(false, "0", false), "health не число — не считаем")
	ck(not KC.death_is_lethal(false, NAN, false), "NaN — не считаем")

func t_weapon_kill_counted() -> void:
	var evs: Array = []
	var h = TestHooks.new()
	root.add_child(h)
	h.connect("kill_event", func(ev: Dictionary) -> void: evs.append(ev))
	var lib := FakeLib.new()
	h._lib = lib

	var victim := FakeAgent.new()
	root.add_child(victim)
	var player := FakeAgent.new()
	player.add_to_group("Player")
	root.add_child(player)

	lib._caller = victim
	h._on_ai_weapon_damage("Head", 120.0, Vector3.ZERO, player)
	_die_pre(h, lib, victim, false, 120.0)

	ck(evs.size() == 1, "pre-хук сам рождает событие смертельного выстрела")
	ck(h.get_kill_count() == 1, "смертельный выстрел посчитан")
	if evs.size() == 1:
		ck(str(evs[0]["killer_kind"]) == "player", "убийца — player")
		ck(bool(evs[0]["headshot"]), "hitbox Head -> headshot")
	ck(h._last_damager.is_empty(), "после смерти запись о ране снята")

	victim.free()
	player.free()
	h.queue_free()

func t_corpse_not_counted() -> void:
	var evs: Array = []
	var h = TestHooks.new()
	root.add_child(h)
	h.connect("kill_event", func(ev: Dictionary) -> void: evs.append(ev))
	var lib := FakeLib.new()
	h._lib = lib

	var victim := FakeAgent.new()
	victim.dead = true
	victim.health = 0
	root.add_child(victim)
	var player := FakeAgent.new()
	player.add_to_group("Player")
	root.add_child(player)

	# Второй взрыв/выстрел по трупу: ванильный ExplosionDamage не проверяет dead.
	lib._caller = victim
	h._on_ai_weapon_damage("Chest", 50.0, Vector3.ZERO, player)
	_die_pre(h, lib, victim, false, 50.0)

	ck(evs.is_empty(), "смерть трупа не даёт события")
	ck(h.get_kill_count() == 0, "смерть трупа не считается")
	ck(h._last_damager.is_empty(), "отказ снимает запись о ране")

	victim.free()
	player.free()
	h.queue_free()

func t_explosion_counted_with_health() -> void:
	var evs: Array = []
	var h = TestHooks.new()
	root.add_child(h)
	h.connect("kill_event", func(ev: Dictionary) -> void: evs.append(ev))
	var lib := FakeLib.new()
	h._lib = lib

	var victim := FakeAgent.new()
	root.add_child(victim)
	var player := FakeAgent.new()
	player.add_to_group("Player")
	root.add_child(player)

	lib._caller = victim
	h._on_ai_explosion(Vector3.ZERO, player)
	# health остаётся 100: взрыв убивает мимо вычитания здоровья.
	_die_pre(h, lib, victim, true)

	ck(evs.size() == 1, "взрыв при health 100 даёт событие")
	ck(h.get_kill_count() == 1, "взрыв при health 100 посчитан")
	if evs.size() == 1:
		ck(bool(evs[0]["grenade"]), "взрыв помечен гранатой")

	victim.free()
	player.free()
	h.queue_free()

func t_live_weapon_rejected() -> void:
	var evs: Array = []
	var h = TestHooks.new()
	root.add_child(h)
	h.connect("kill_event", func(ev: Dictionary) -> void: evs.append(ev))
	var lib := FakeLib.new()
	h._lib = lib

	var victim := FakeAgent.new()
	root.add_child(victim)
	var player := FakeAgent.new()
	player.add_to_group("Player")
	root.add_child(player)

	# Чужой мод позвал Death на живом AI, не вычтя здоровье.
	lib._caller = victim
	h._on_ai_weapon_damage("Chest", 10.0, Vector3.ZERO, player)
	_die_pre(h, lib, victim, false, 10.0)

	ck(evs.is_empty(), "живой AI после удара не считается убитым")
	ck(h.get_kill_count() == 0, "живой AI не тикает счётчик")
	ck(h._last_damager.is_empty(), "отказ снимает запись о ране")

	victim.free()
	player.free()
	h.queue_free()

func t_non_player_event_only() -> void:
	var evs: Array = []
	var h = TestHooks.new()
	root.add_child(h)
	h.connect("kill_event", func(ev: Dictionary) -> void: evs.append(ev))
	var lib := FakeLib.new()
	h._lib = lib

	var victim := FakeAgent.new()
	root.add_child(victim)
	var bandit := FakeAgent.new()
	root.add_child(bandit)

	lib._caller = victim
	h._on_ai_weapon_damage("Chest", 120.0, Vector3.ZERO, bandit)
	_die_pre(h, lib, victim, false, 120.0)

	ck(evs.size() == 1, "убийство AI-vs-AI даёт событие")
	ck(h.get_kill_count() == 0, "убийство AI-vs-AI не тикает счётчик игрока")
	if evs.size() == 1:
		ck(str(evs[0]["killer_kind"]) == "enemy", "убийца — enemy")

	victim.free()
	bandit.free()
	h.queue_free()

func t_second_death_ignored() -> void:
	var evs: Array = []
	var h = TestHooks.new()
	root.add_child(h)
	h.connect("kill_event", func(ev: Dictionary) -> void: evs.append(ev))
	var lib := FakeLib.new()
	h._lib = lib

	var victim := FakeAgent.new()
	root.add_child(victim)
	var player := FakeAgent.new()
	player.add_to_group("Player")
	root.add_child(player)
	lib._caller = victim
	h._on_ai_weapon_damage("Chest", 120.0, Vector3.ZERO, player)
	_die_pre(h, lib, victim, false, 120.0)
	_die_pre(h, lib, victim, false, 120.0)

	ck(evs.size() == 1, "вторая смерть не даёт второго события")
	ck(h.get_kill_count() == 1, "вторая смерть не задирает счётчик")

	victim.free()
	player.free()
	h.queue_free()

func t_reset_clears_state() -> void:
	var h = TestHooks.new()
	root.add_child(h)
	var lib := FakeLib.new()
	h._lib = lib

	var victim := FakeAgent.new()
	root.add_child(victim)
	var player := FakeAgent.new()
	player.add_to_group("Player")
	root.add_child(player)
	lib._caller = victim
	h._on_ai_weapon_damage("Chest", 120.0, Vector3.ZERO, player)
	_die_pre(h, lib, victim, false, 120.0)
	ck(h.get_kill_count() == 1, "до сброса килл посчитан")

	h.reset_kills()
	ck(h.get_kill_count() == 0, "reset_kills обнуляет счётчик")
	ck(h._seen_deaths.is_empty(), "reset_kills чистит дедуп")
	ck(h._last_damager.is_empty(), "reset_kills чистит записи о ранах")

	victim.free()
	player.free()
	h.queue_free()
