extends RefCounted
# Статические хелперы агентов. Узловая логика счётчика (скан, _pending, _tick)
# переехала в VTKFeed: один блок владеет всем счетом. Здесь остаются только
# чистые функции, которые читает VTKHooks и тесты.
const Hud = preload("res://mods/VTK/VTKHud.gd")

# AIData.Faction (headless probe): Nomad 0, Bandit 1, Guard 2, Military 3, Boss 4.
const FACTION_NOMAD := 0
const FACTION_BOSS := 4

static func _is_agent(n: Node) -> bool:
	return n is Node3D and "variant" in n

static func agent_kind(n: Node) -> String:
	if not _is_agent(n):
		return ""
	var v = n.get("variant")
	if v == null:
		return ""
	var f := int(v.get("faction"))
	if f == FACTION_NOMAD:
		return "nomad"
	if f == FACTION_BOSS:
		return ""
	return "enemy"

# Гейт смертельного удара: pre-хук смерти видит состояние до ванильного
# AI.Death, post-хук — после. Ваниль ставит dead = true первой строкой, поэтому
# «мёртв ли он» проверяется переходом false -> true в одном событии. Оружейный
# урон вычитает health и зовёт Death только при health <= 0; взрыв зовёт Death
# напрямую, не трогая health, — для него одного перехода dead достаточно.
# null/строка/NaN здоровьем не считаются: без доказательства не тикаем.
static func death_is_lethal(dead_before, health, explosion: bool) -> bool:
	if dead_before == null or bool(dead_before):
		return false
	if explosion:
		return true
	if health == null or not (health is int or health is float):
		return false
	var hp := float(health)
	if not is_finite(hp):
		return false
	return hp <= 0.0

static func display_name_of(variant_name: String, nickname: String) -> String:
	var n := nickname.strip_edges()
	if n != "":
		return n
	var v := variant_name.strip_edges()
	if v != "":
		return v
	return "NPC"

static func agent_display_name(n: Node) -> String:
	if n == null or not is_instance_valid(n):
		return "NPC"
	var vname := ""
	var nick := ""
	if "variant" in n:
		var v = n.get("variant")
		if v != null:
			var raw = v.get("name")
			if raw != null:
				vname = str(raw)
	if "nickname" in n:
		var raw_nick = n.get("nickname")
		if raw_nick != null:
			nick = str(raw_nick)
	return display_name_of(vname, nick)

static func counter_text(kills: int, alive: int, nomads: int) -> String:
	return "Killed: " + str(kills) + "   Enemies: " + str(alive) + "   Nomads: " + str(nomads)