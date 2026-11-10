extends SceneTree

const KC = preload("res://mods/VTK/VTKKillCounter.gd")
const Hud = preload("res://mods/VTK/VTKHud.gd")
const Items = preload("res://mods/VTK/VTKItemStore.gd")
const Item = preload("res://stubs/ItemData.gd")

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
	t_kc_disabled_ignores_nodes()
	t_agent_display_name()
	t_feed_segments()
	t_feed_distance_segment()
	t_feed_fade()
	t_longest_kill_event()
	t_feed_evict()
	t_feed_hs_svg()
	t_feed_norm_weapon()
	t_feed_index_second_pass()
	t_hud_anchor_layout()
	t_hud_block_placement()
	t_hud_font_metrics()
	t_streak_helpers()
	t_log_warn_once()
	t_hud_shared()
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

# Выключенный счётчик не должен ни крутить _process, ни копить в _pending id
# узлов: в _pending раньше попадал любой узел дерева, включая UI мода, хотя
# разбирать его было некому.
func t_kc_disabled_ignores_nodes() -> void:
	var Feed = preload("res://mods/VTK/VTKFeed.gd")
	var block = Feed.new()
	root.add_child(block)
	# Рождается выключенным.
	ck(not block.is_processing(), "рождённый выключенным не крутит _process")
	block.configure(false, false, false)
	ck(not block.is_processing(), "выключенный блок не крутит _process")

	var probe := Node.new()
	root.add_child(probe)
	ck(block._pending.is_empty(), "выключенный блок не копит узлы (в т.ч. UI мода)")

	block.configure(true, true, true)
	ck(block.is_processing(), "включённый блок снова обрабатывается")
	ck(block._pending.is_empty(), "включение не оставляет мусора в _pending")

	var probe2 := Node.new()
	root.add_child(probe2)
	ck(block._pending.size() == 1, "включённый блок копит фиктивный узел в _pending")

	probe.free()
	probe2.free()
	block.free()

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

func t_feed_norm_weapon() -> void:
	var Feed = preload("res://mods/VTK/VTKFeed.gd")
	ck(Feed.norm_weapon("AKS-74U") == Feed.norm_weapon("AKS_74U"), "дефис и подчёркивание равны")
	ck(Feed.norm_weapon("AK-12") == Feed.norm_weapon("ak_12"), "регистр и дефис схлопываются")
	ck(Feed.norm_weapon(" HP DA ") == "hp_da", "пробелы по краям и внутри схлопываются")
	ck(Feed.norm_weapon("M28") == "m28", "простое имя не ломается")
	ck(Feed.norm_weapon("Remington 870") == Feed.norm_weapon("Remington-870"), "пробел и дефис равны")
	ck(Feed.norm_weapon("AKM") != Feed.norm_weapon("AKM_Magazine"), "магазин не путается со стволом")
	ck(Feed.norm_weapon("AKS-74U") == Items.norm_name("AKS-74U"),
		"лента нормализует имя тем же правилом, что и каталог")

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
func t_feed_index_second_pass() -> void:
	var Feed = preload("res://mods/VTK/VTKFeed.gd")
	var renamed: Variant = Item.new()
	renamed.name = "RGAAN Renamed Rifle"
	renamed.resource_path = "res://Items/Weapons/AKS/AKS-74U.tres"
	renamed.type = "Weapon"
	renamed.slots = ["Primary"]
	Items.clear()
	Items.rebuild([renamed])
	ck(Items.item_by_name("AKS_74U") == renamed,
		"vtoroy prokhod po imeni fayla nakhodit pereimenovannyy predmet")
	ck(Feed.norm_weapon("AKS_74U") == Items.norm_name("AKS-74U"),
		"lenta normalizuet imya uzla tem zhe pravilom, chto i katalog")
	Items.clear()

# Плашка, чтение убежища и каденция тика жили двумя копиями в счётчике и ленте:
# контракт общих частей держим здесь, чтобы копии снова не разошлись.
func t_hud_shared() -> void:
	var sb := Hud.plaque_style(1.0, 1.0)
	ck(is_equal_approx(sb.bg_color.a, 0.45), "плашка: чёрный 0.45")
	ck(is_equal_approx(sb.content_margin_left, 6.0) and is_equal_approx(sb.content_margin_right, 6.0),
		"плашка: поля 6 px по горизонтали")
	var bare := Hud.plaque_style()
	ck(is_equal_approx(bare.content_margin_top, 0.0) and is_equal_approx(bare.content_margin_bottom, 0.0),
		"плашка: у ленты без вертикальных полей")
	ck(Hud.in_shelter({"gameData": {"shelter": true}}), "убежище: gameData.shelter = true")
	ck(not Hud.in_shelter({"gameData": {"shelter": false}}), "убежище: shelter = false")
	ck(not Hud.in_shelter({"gameData": null}), "убежище: gameData нет")
	ck(not Hud.in_shelter(null), "убежище: интерфейса нет")
	var ticker = Hud.Ticker.new()
	ck(not ticker.step(0.3), "тикер: 0.3 с — ещё не тик")
	ck(ticker.step(0.3), "тикер: 0.6 с — тик")
	ck(not ticker.step(0.3), "тикер: остаток сброшен, тик снова через 0.5 с")


func t_hud_anchor_layout() -> void:
	var Hud = preload("res://mods/VTK/VTKHud.gd")
	var Feed = preload("res://mods/VTK/VTKFeed.gd")
	ck(Hud.ANCHOR_KEYS.size() == 6, "6 presetov yakorya")
	var l = Hud.anchor_layout("top_left")
	ck(l["anchor"] == Vector2(0, 0), "top_left anchor")
	ck(l["grow_h"] == Control.GROW_DIRECTION_END and l["grow_v"] == Control.GROW_DIRECTION_END, "top_left grow")
	ck(l["sx"] == 1 and l["sy"] == 1, "top_left sign")
	l = Hud.anchor_layout("bottom_right")
	ck(l["anchor"] == Vector2(1, 1), "bottom_right anchor")
	ck(l["sx"] == -1 and l["sy"] == -1, "bottom_right sign")
	l = Hud.anchor_layout("nope")
	ck(l["anchor"] == Vector2(0, 0), "invalid -> top_left")
	var c = Control.new()
	root.add_child(c)
	Hud.place_block(c, "top_right", 10, 20)
	ck(is_equal_approx(c.anchor_left, 1.0), "place anchor x")
	ck(is_equal_approx(c.offset_left, -10.0), "place offset sign x")
	c.free()

func t_hud_block_placement() -> void:
	var Feed = preload("res://mods/VTK/VTKFeed.gd")
	var block = Feed.new()
	root.add_child(block)
	var cp: Control = block._counter_panel
	var feed: Control = block._feed_root
	ck(cp.anchor_left == 0.0 and cp.anchor_top == 0.0, "counter stays anchored top_left (absolute mode)")
	ck(cp.position == Vector2(10.0, 10.0), "counter fixed at (10, 10)")
	for preset in Hud.ANCHOR_KEYS:
		block.apply_layout(preset, 10, 90, 16)
		ck(feed.custom_minimum_size.x == 420.0, "feed fixed width 420 (%s)" % preset)
		ck(feed.get_parent() != null, "feed has parent for %s" % preset)
	ck(cp.position == Vector2(10.0, 10.0), "counter stays fixed across feed moves")
	block.free()

func t_hud_font_metrics() -> void:
	var Hud = preload("res://mods/VTK/VTKHud.gd")
	ck(is_equal_approx(Hud.row_height(17.0), 23.0), "row_height(17)=23")
	ck(is_equal_approx(Hud.icon_size(17.0), 16.0), "icon_size(17)=16")
	ck(Hud.hs_fallback_size(17) == 11, "hs_fallback_size(17)=11")

func t_streak_helpers() -> void:
	var Feed = preload("res://mods/VTK/VTKFeed.gd")
	var evp = {"killer_kind": "player"}
	var r = Feed.streak_after_event(2, 2, evp)
	ck(int(r["current"]) == 3 and int(r["best"]) == 3, "igrok +1 i best")
	var eve = {"killer_kind": "enemy"}
	r = Feed.streak_after_event(3, 5, eve)
	ck(int(r["current"]) == 3 and int(r["best"]) == 5, "vrag bez izmeneniy best sokhranyayetsya")
	var rr = Feed.streak_reset(7)
	ck(int(rr["current"]) == 0 and int(rr["best"]) == 7, "reset current=0 best sokhranyayetsya")

func t_feed_distance_segment() -> void:
	var Feed = preload("res://mods/VTK/VTKFeed.gd")
	var ev := {
		"killer_kind": "player", "killer_name": "Player",
		"victim_kind": "enemy", "victim_name": "Bandit",
		"weapon": "AKM", "headshot": true, "grenade": false, "t": 0,
		"distance": 120.0,
	}
	ck(Feed.segments(ev, true).size() == 5, "distance segment added")
	ck(Feed.segments(ev, false).size() == 4, "show_distance=false hides distance")
	var selfev := {"self_death": true, "victim_kind": "enemy", "victim_name": "Bandit", "distance": 120.0, "t": 0}
	ck(Feed.segments(selfev, true).size() == 2, "self-death ignores distance segment")

func t_longest_kill_event() -> void:
	var Feed = preload("res://mods/VTK/VTKFeed.gd")
	var r = Feed.longest_kill_event(0.0, 120.0, 100.0, true)
	ck(bool(r["new_best"]) and is_equal_approx(float(r["best"]), 120.0), "first kill sets best and new_best")
	ck(str(r["message"]) == "New longest kill: 120m", "record toast")
	r = Feed.longest_kill_event(120.0, 110.0, 100.0, true)
	ck((not bool(r["new_best"])) and str(r["message"]) == "Long shot: 110m", "below record but far -> long shot")
	r = Feed.longest_kill_event(120.0, 80.0, 100.0, true)
	ck(str(r["message"]) == "", "below threshold -> no toast")
	r = Feed.longest_kill_event(120.0, 130.0, 100.0, false)
	ck(is_equal_approx(float(r["best"]), 130.0) and str(r["message"]) == "", "disabled: best updates, no toast")
	r = Feed.longest_kill_event(120.0, -1.0, 100.0, true)
	ck(is_equal_approx(float(r["best"]), 120.0) and str(r["message"]) == "", "no distance leaves best untouched")
