extends SceneTree

const KC = preload("res://mods/VTK/VTKKillCounter.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

class FakeVariant extends RefCounted:
	var faction := 0
	var name := "Bandit"

# Узел-заглушка с той же сигнатурой, что и игровой AI: Node3D + Activate() + dead
# + variant: AIData (источник фракции и имени).
class FakeAgent extends Node3D:
	var dead := false
	var active := true
	var variant = FakeVariant.new()
	var nickname := ""

	func Activate() -> void:
		pass

func _init() -> void:
	process_frame.connect(_run)

func _run() -> void:
	t_agent_kind()
	t_agent_display_name()
	t_feed_segments()
	t_feed_fade()
	t_feed_evict()
	t_feed_hs_svg()
	t_feed_skull_svg()
	t_feed_norm_weapon()
	t_log_warn_once()
	print("")
	if fails == 0:
		print("tests passed")
		quit(0)
	else:
		print("Feed tests failed: ", fails)
		quit(1)

func t_agent_kind() -> void:
	var n := FakeAgent.new()
	root.add_child(n)
	n.variant.faction = 1
	ck(KC.agent_kind(n) == "enemy", "Bandit (faction 1) -> enemy")
	n.variant.faction = 0
	ck(KC.agent_kind(n) == "nomad", "Nomad (faction 0) -> nomad")
	n.variant.faction = 2
	ck(KC.agent_kind(n) == "enemy", "Guard (faction 2) -> enemy")
	n.variant.faction = 4
	ck(KC.agent_kind(n) == "", "Punisher/Bogeyman (faction 4) не считается в счётчике")
	var plain := Node3D.new()
	root.add_child(plain)
	ck(KC.agent_kind(plain) == "", "узел без variant -> пусто")
	n.queue_free()
	plain.queue_free()

func t_agent_display_name() -> void:
	var n := FakeAgent.new()
	root.add_child(n)
	n.variant.name = "Bandit"
	ck(KC.agent_display_name(n) == "Bandit", "variant Bandit -> Bandit")
	n.variant.name = "Nomad"
	ck(KC.agent_display_name(n) == "Nomad", "variant Nomad -> Nomad")
	n.variant.name = "Punisher"
	ck(KC.agent_display_name(n) == "Punisher", "variant Punisher -> Punisher")
	n.queue_free()
	ck(KC.agent_display_name(null) == "NPC", "null -> NPC")
	ck(KC.display_name_of("Nomad", "Mikko") == "Mikko", "никнейм побеждает имя варианта")
	ck(KC.display_name_of("Nomad", "  Mikko  ") == "Mikko", "никнейм обрезается")
	ck(KC.display_name_of("Nomad", "   ") == "Nomad", "пустой никнейм -> имя варианта")
	ck(KC.display_name_of("", "") == "NPC", "оба пустые -> NPC")
	var nomad := FakeAgent.new()
	nomad.variant.name = "Nomad"
	nomad.nickname = "Aino"
	root.add_child(nomad)
	ck(KC.agent_display_name(nomad) == "Aino", "узел с nickname -> никнейм")
	nomad.queue_free()
	var plain := Node3D.new()
	root.add_child(plain)
	ck(KC.agent_display_name(plain) == "NPC", "узел без variant и nickname -> NPC")
	plain.queue_free()

func t_feed_segments() -> void:
	var Feed = preload("res://mods/VTK/VTKFeed.gd")
	var ev := {
		"killer_kind": "player", "killer_name": "Player",
		"victim_kind": "enemy", "victim_name": "Bandit",
		"weapon": "AKM", "headshot": true, "grenade": false, "t": 0,
	}
	var segs: Array = Feed.segments(ev)
	ck(segs.size() == 4, "сегментов 4: имя, оружие, HS, жертва")
	ck(str(segs[0]["text"]) == "Player" and segs[0]["color"] == Feed.GREEN, "игрок зелёный первым")
	ck(str(segs[1]["icon"]) == "weapon", "иконка оружия до HS")
	ck(str(segs[2]["icon"]) == "hs", "HS после оружия")
	ck(str(segs[3]["text"]) == "Bandit" and segs[3]["color"] == Feed.RED, "враг красным")
	# Граната: только иконка гранаты, без оружия и без HS.
	var gr := {
		"killer_kind": "enemy", "killer_name": "Bandit",
		"victim_kind": "nomad", "victim_name": "Nomad",
		"weapon": "F1", "headshot": true, "grenade": true, "t": 0,
	}
	segs = Feed.segments(gr)
	ck(segs.size() == 3, "граната: 3 сегмента")
	ck(str(segs[1]["icon"]) == "grenade", "иконка гранаты вместо оружия")
	# Без оружия и без HS — только два имени.
	var bare := {
		"killer_kind": "player", "killer_name": "Player",
		"victim_kind": "enemy", "victim_name": "Bandit",
		"weapon": "", "headshot": false, "grenade": false, "t": 0,
	}
	segs = Feed.segments(bare)
	ck(segs.size() == 2, "без оружия и HS: только имена")
	# Старая рана: только череп и имя жертвы, подробности игнорируются.
	var self_death := {
		"self_death": true,
		"killer_kind": "", "killer_name": "",
		"victim_kind": "nomad", "victim_name": "Mikko",
		"weapon": "AKM", "headshot": true, "grenade": true, "t": 0,
	}
	segs = Feed.segments(self_death)
	ck(segs.size() == 2, "self_death: ровно имя и череп")
	ck(str(segs[0]["text"]) == "Mikko" and segs[0]["color"] == Feed.GREEN, "self_death: имя жертвы своим цветом")
	ck(str(segs[1]["icon"]) == "skull", "self_death: череп после имени")
	ck(Feed.kind_color("nomad") == Feed.GREEN, "номад зелёный")
	ck(Feed.kind_color("") == Feed.RED, "неизвестный kind красный (hostile fallback)")

func t_feed_fade() -> void:
	var Feed = preload("res://mods/VTK/VTKFeed.gd")
	ck(Feed.alpha_at(0.0) == 1.0, "начало: полностью видно")
	ck(Feed.alpha_at(Feed.FEED_DURATION) == 1.0, "на границе duration ещё видно")
	var mid := Feed.alpha_at(Feed.FEED_DURATION + Feed.FADE_TIME * 0.5)
	ck(absf(mid - 0.5) < 0.001, "середина затухания: alpha 0.5")
	ck(Feed.alpha_at(Feed.FEED_DURATION + Feed.FADE_TIME + 1.0) == 0.0, "после fade: 0")

func t_feed_evict() -> void:
	var Feed = preload("res://mods/VTK/VTKFeed.gd")
	var rows: Array = []
	for i in Feed.MAX_ROWS + 2:
		var dropped: Array = Feed.push_entry(rows, {"id": i}, Feed.MAX_ROWS)
		if i < Feed.MAX_ROWS:
			ck(dropped.is_empty(), "строка " + str(i) + " не вытесняет")
		else:
			ck(dropped.size() == 1 and int(dropped[0]["id"]) == i - Feed.MAX_ROWS,
				"строка " + str(i) + " вытесняет самую старую")
	ck(rows.size() == Feed.MAX_ROWS, "размер ограничен MAX_ROWS")
	ck(int(rows[0]["id"]) == Feed.MAX_ROWS + 1, "свежая строка сверху (индекс 0)")

# HS теперь SVG из макета, а не webp-файл: текстура обязана рендериться
# без файлов игры, иначе лента снова уйдёт в текстовый фолбэк "HS".
func t_feed_hs_svg() -> void:
	var Feed = preload("res://mods/VTK/VTKFeed.gd")
	ck(Feed.HS_SVG.contains("#FFD669"), "цвет HS-SVG совпадает с HS_GOLD")
	var tex = Feed.Surface.svg_texture(Feed.HS_SVG)
	ck(tex is Texture2D and tex.get_width() > 0, "HS-SVG рендерится в текстуру")

func t_feed_skull_svg() -> void:
	var Feed = preload("res://mods/VTK/VTKFeed.gd")
	ck(Feed.SKULL_SVG.contains("#E6E6E6"), "череп рисуется костяным цветом")
	var tex = Feed.Surface.svg_texture(Feed.SKULL_SVG)
	ck(tex is Texture2D and tex.get_width() > 0, "SKULL-SVG рендерится в текстуру")

# Оружие приходит из data.file рига/имени узла (AKS_74U), а в Database лежит
# либо переименованное RGAAN имя, либо путь AKS-74U.tres — без нормализации
# иконки этих стволов не находились.
func t_feed_norm_weapon() -> void:
	var Feed = preload("res://mods/VTK/VTKFeed.gd")
	ck(Feed.norm_weapon("AKS-74U") == Feed.norm_weapon("AKS_74U"), "дефис и подчёркивание равны")
	ck(Feed.norm_weapon("AK-12") == Feed.norm_weapon("ak_12"), "регистр и дефис схлопываются")
	ck(Feed.norm_weapon(" HP DA ") == "hp_da", "пробелы по краям и внутри схлопываются")
	ck(Feed.norm_weapon("M28") == "m28", "простое имя не ломается")
	ck(Feed.norm_weapon("Remington 870") == Feed.norm_weapon("Remington-870"), "пробел и дефис равны")
	ck(Feed.norm_weapon("AKM") != Feed.norm_weapon("AKM_Magazine"), "магазин не путается со стволом")

func t_log_warn_once() -> void:
	var Log = preload("res://mods/VTK/VTKLog.gd")
	Log._warned.clear()
	# Промах при выключенном debug не защёлкивается: включив лог позже, мод
	# всё ещё сообщит о недостающей привязке.
	Log.enabled = false
	Log.warn_once("/root/Off", "behind the gate")
	ck(Log._warned.is_empty(), "warn_once: при выключенном логе след не ставится")
	Log.enabled = true
	Log.warn_once("/root/Nope", "missing A")
	Log.warn_once("/root/Nope", "missing A")
	Log.warn_once("/root/Other", "missing B")
	ck(Log._warned.size() == 2, "warn_once: один след на путь, повтор не плодит")
	ck(Log._warned.has("/root/Nope") and Log._warned.has("/root/Other"), "warn_once: оба пути помечены")
	Log.enabled = false
