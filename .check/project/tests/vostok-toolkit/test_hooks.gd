extends SceneTree

const Hooks = preload("res://mods/VTK/VTKHooks.gd")
const KC = preload("res://mods/VTK/VTKKillCounter.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

class TestHooks extends "res://mods/VTK/VTKHooks.gd":
	pass

class SeasonSpy extends TestHooks:
	var applies := 0

	func _season_apply() -> void:
		applies += 1

class FakeLoaderNotes extends Node:
	var notes: Array = []
	var saved: Array = []

	func LoadTaskNotes() -> Array:
		return notes

	func SaveTaskNotes(task, add: bool) -> void:
		saved.append([task, add])
		if not add and notes.has(task):
			notes.erase(task)

class FakeNoteCard extends Node:
	var taskData = null

class FakeNotesIface extends Node:
	var notesList = null

# Заглушка RTVModLib: считает вызовы и отдаёт различимые хэндлы, как настоящий.
class FakeHookLib extends Node:
	var names: Array = []
	var ids: Array = []

	func hook(hook_name: String, _cb) -> int:
		var id := ids.size() + 1
		names.append(hook_name)
		ids.append(id)
		return id

func t_task_note_removed_on_complete() -> void:
	var ldr := FakeLoaderNotes.new()
	ldr.name = "Loader"
	root.add_child(ldr)
	var h = TestHooks.new()
	root.add_child(h)

	var note := {"name": "Duty Calls", "trader": "Doctor"}
	ldr.notes = [note]

	h._on_task_completed({"name": "Other", "trader": "Doctor"})
	ck(ldr.saved.is_empty(), "чужая задача заметку не трогает")

	h._on_task_completed(note)
	ck(ldr.saved.size() == 1 and ldr.saved[0][1] == false, "сдача задачи удаляет заметку")
	ck(not ldr.notes.has(note), "заметка убрана из списка")

	ldr.free()
	h.queue_free()

# Контракт лоадера: post-колбэк обязан совпасть по арности с методом, иначе
# вызов молча не состоится (в Godot 4.6.3 Callable.callv с лишними аргументами
# не бросает ошибку, а становится no-op). Для void-методов post-хук получает
# ровно аргументы метода; для не-void — args + _result. Так сломались
# interface-initializetasks-post (void, ждал args+_result) и
# interface-startinput-post: _on_tasks_startinput() брал лишний _result, и
# кнопка Deposit не включалась.
# Словарь ниже - полный список всех 25 колбэков: новый хук добавляется сюда же,
# иначе он тихо выпадет из проверки арности. _on_notes_rendered держит 1 из-за
# дефолта _result = null (X1, 5.3.5).
func t_post_callback_arity() -> void:
	var h = TestHooks.new()
	root.add_child(h)
	var expected := {
		"_on_tasks_startinput": 1,
		"_on_tasks_rendered": 0,
		"_on_notes_rendered": 1,
		"_on_context_update_post": 1,
		"_on_task_completed": 1,
		"_on_newgame_post": 2,
		"_on_loadcharacter_post": 0,
		"_on_compiler_spawn": 0,
		"_on_pickup_interact_post": 0,
		"_on_controller_process": 1,
		"_on_fasttransfer_post": 0,
		"_on_contexttransfer_post": 0,
		"_on_release_post": 0,
		"_on_death_ready": 0,
		"_on_death_load_pressed": 0,
		"_on_ai_weapon_damage": 4,
		"_on_ai_explosion": 2,
		"_on_ai_death": 2,
		"_on_task_complete_pressed": 0,
		"_on_context_take_replace": 0,
		"_on_context_split_replace": 0,
		"_on_pickup_interact_pre": 0,
		"_on_fasttransfer_pre": 0,
		"_on_contexttransfer_pre": 0,
		"_on_grab_pre": 0,
	}
	for m in expected:
		var argc := Callable(h, m).get_argument_count()
		ck(argc == int(expected[m]), "post-колбэк %s принимает %d аргумент(ов)" % [m, int(expected[m])])
	h.queue_free()

class FakeCtx extends Node:
	var interface = null

# Удаление — ванильная кнопка Destroy с удержанием, но ванила показывает её
# только в декоре. Для предмета в гриде мод показывает ту же кнопку вне декора
# и переименовывает в Delete; своей VTKDelete не держит. Сброс Progress нужен,
# чтобы открытие меню не начиналось с накопленного прошлого значения.
func t_context_destroy_shown_in_grid() -> void:
	var h = TestHooks.new()
	root.add_child(h)
	var ctx := FakeCtx.new()
	ctx.name = "Ctx"
	root.add_child(ctx)
	var panel := Control.new(); panel.name = "Panel"; ctx.add_child(panel)
	var margin := Control.new(); margin.name = "Margin"; panel.add_child(margin)
	var box := VBoxContainer.new(); box.name = "Buttons"; margin.add_child(box)
	var destroy := Button.new(); destroy.name = "Destroy"; box.add_child(destroy)
	var prog := ProgressBar.new(); prog.name = "Progress"; destroy.add_child(prog)
	prog.value = 55.0
	destroy.hide()

	var c := _mk_iface2()
	var item := FakeItem.new()
	item.slotData = FakeSD.new()
	c["ig"].add_child(item)
	c["iface"].set("contextItem", item)
	c["iface"].set("contextGrid", c["ig"])
	ctx.interface = c["iface"]
	var lib := FakeLib2.new(); lib._caller = ctx
	h._lib = lib

	h._on_context_update_post(item.slotData)
	ck(destroy.visible, "Destroy показывается для предмета в гриде")
	ck(destroy.text == "Delete", "подпись кнопки — Delete")
	ck(prog.value == 0.0, "прогресс сброшен на открытии меню")
	ck(box.get_node_or_null("VTKDelete") == null, "своей VTKDelete мод не создаёт")

	destroy.hide()
	c["iface"].set("contextGrid", null)
	h._on_context_update_post(item.slotData)
	ck(not destroy.visible, "вне грида Destroy не показываем")

	ctx.free()
	c["iface"].free()
	h.queue_free()

# Кнопка Deposit стоит рядом с ванильными Start Delivery/Complete и обязана
# нести тот же размер шрифта, что и они: ванила задаёт его персональным
# theme_override, а не темой, поэтому без override наша кнопка выпадала бы
# крупнее. Размер берём у соседа, пропуская VTK*-кнопки.
func t_deposit_button_font_matches_sibling() -> void:
	var h = TestHooks.new()
	root.add_child(h)
	var card := Node.new()
	card.name = "Card"
	var margin := Node.new(); margin.name = "Margin"; card.add_child(margin)
	var elems := Node.new(); elems.name = "Elements"; margin.add_child(elems)
	var box := GridContainer.new(); box.name = "Buttons"; elems.add_child(box)
	var vtkjunk := Button.new(); vtkjunk.name = "VTKOther"
	vtkjunk.add_theme_font_size_override("font_size", 99)
	box.add_child(vtkjunk)
	var vanilla := Button.new(); vanilla.name = "Complete"
	vanilla.add_theme_font_size_override("font_size", 27)
	box.add_child(vanilla)
	var btn = h._make_deposit_button(card)
	ck(btn != null, "Deposit-кнопка создаётся")
	ck(btn.get_theme_font_size("font_size") == 27,
		"Deposit-шрифт совпадает с ванильной кнопкой, VTK-сосед пропущен")
	var empty := GridContainer.new()
	ck(h._sibling_button_font_size(empty) == 12, "без ванильного соседа фолбэк 12")
	empty.free()
	card.free()
	h.queue_free()

# E-07: связка депозита — леджер сохраняется ДО списания, и при сбое персиста
# предметы остаются у игрока. Фейки заменяют TraderSave/Interface; DepositHooks
# перехватывает _ledger/_ledger_set, FakeDepGrid фиксирует факт списания.
class FakeDepSD:
	var itemData = null
	var amount := 1

class FakeDepCell extends Control:
	var slotData = null
	var selected := false

class FakeDepGrid extends Control:
	var picked: Array = []

	func Pick(node) -> void:
		picked.append(node)

class FakeDepIface extends Node:
	var inputTarget = null
	var inventoryGrid = null

class FakeDepCard extends Node:
	var interface = null
	var taskData = null
	var inputGrid = null

	func CanComplete() -> void:
		pass

class DepositHooks extends "res://mods/VTK/VTKHooks.gd":
	var persisted: Array = []
	var persist_ok := true
	var ledger_data: Dictionary = {}

	func _ledger() -> Dictionary:
		return ledger_data

	func _ledger_set(data: Dictionary) -> bool:
		persisted.append(data)
		return persist_ok

	func _render_task_card(_iface, _card, _traders = null) -> void:
		pass

# Задача требует 3 сигареты, в инвентаре выбрана 1.
func _deposit_fixture() -> Dictionary:
	var card := FakeDepCard.new()
	var iface := FakeDepIface.new()
	card.interface = iface
	iface.inputTarget = card
	card.taskData = {"resource_path": "res://Tasks/Cigs.tres", "name": "Cigs", "trader": "Doctor"}
	var in_grid := FakeDepGrid.new()
	card.add_child(in_grid)
	card.inputGrid = in_grid
	var in_cell := FakeDepCell.new()
	in_cell.slotData = FakeDepSD.new()
	in_cell.slotData.itemData = {"file": "Cigarettes", "name": "Cigarettes"}
	in_cell.slotData.amount = 3
	in_grid.add_child(in_cell)
	var inv_grid := FakeDepGrid.new()
	iface.add_child(inv_grid)
	iface.inventoryGrid = inv_grid
	var inv_cell := FakeDepCell.new()
	inv_cell.selected = true
	inv_cell.slotData = FakeDepSD.new()
	inv_cell.slotData.itemData = {"file": "Cigarettes", "name": "Cigarettes"}
	inv_cell.slotData.amount = 1
	inv_grid.add_child(inv_cell)
	return {"card": card, "iface": iface, "inv_grid": inv_grid, "inv_cell": inv_cell}

func t_deposit_ledger_before_consume() -> void:
	var h := DepositHooks.new()
	root.add_child(h)
	var f := _deposit_fixture()

	h._on_deposit_pressed(f["card"])
	ck(h.persisted.size() == 1, "успешный вклад: леджер сохраняется ровно раз")
	ck(f["inv_grid"].picked.size() == 1, "успешный вклад: предмет списан")

	h.free()
	f["card"].free()
	f["iface"].free()

func t_deposit_aborts_when_persist_fails() -> void:
	var h := DepositHooks.new()
	h.persist_ok = false
	root.add_child(h)
	var f := _deposit_fixture()

	h._on_deposit_pressed(f["card"])
	ck(h.persisted.size() == 1, "сбой персиста: леджер всё равно записан (попытка)")
	ck(f["inv_grid"].picked.is_empty(), "сбой персиста: предмет НЕ списан")
	ck(int(f["inv_cell"].slotData.amount) == 1, "сбой персиста: ячейка не тронута")

	h.free()
	f["card"].free()
	f["iface"].free()

# Миниатюрная замена Loader: рестарт обязан не только стереть сейвы, но и
# вызвать NewGame(), который заново создаёт World/Character/Traders/Cabin/Tent.
# Без Traders.tres LoadTrader/SaveTrader/LoadTaskNotes молча выходят — квесты
# и заметки не переживают рестарт.
class FakeLoader extends Node:
	var new_game_called := false
	var new_game_difficulty := -1
	var new_game_season := -1
	var format_save_called := false
	var loaded_scene := ""

	func NewGame(difficulty: int, season: int) -> void:
		new_game_called = true
		new_game_difficulty = difficulty
		new_game_season = season

	func FormatSave() -> void:
		format_save_called = true

	func LoadScene(scene: String) -> void:
		loaded_scene = scene

# Миниатюрная замена GameData: _on_restart_pressed пишет виталины как
# свойства (gd.health = ...), поэтому нужны настоящие поля, а не Dictionary.
class FakeGD:
	var health := 0.0
	var armStamina := 0.0
	var bodyStamina := 0.0
	var energy := 0.0
	var hydration := 0.0
	var mental := 0.0
	var temperature := 0.0
	var oxygen := 0.0
	var difficulty := 1
	var permadeath := false
	var shelter := false
	var isDead := false
	var tutorial := false
	var currentMap := ""
	var previousMap := ""
	var bleeding := false
	var fracture := false
	var rupture := false
	var burn := false
	var frostbite := false
	var insanity := false
	var dehydration := false
	var headshot := false
	var poisoning := false

# Тело теста ждёт первый кадр: _on_restart_pressed делает
# get_node_or_null("/root/Loader"), а абсолютный путь работает только
# из активного дерева сцены, которого в _init ещё нет.
func _init() -> void:
	process_frame.connect(_run)

func _run() -> void:
	t_kill_event()
	t_player_name()
	t_attacker_snapshot()
	t_damage_record_ttl()
	t_sweep_is_throttled()
	t_kill_counter_birth_in_disabled()
	t_marker_attacker()
	t_explosion_kill()
	t_player_rig_weapon()
	t_context_destroy_shown_in_grid()
	t_deposit_button_font_matches_sibling()
	t_deposit_ledger_before_consume()
	t_deposit_aborts_when_persist_fails()
	t_weapon_name_from_weapondata()
	t_ironman_restart_restores_difficulty()
	t_death_ready_unlocks_restart_for_permadeath()
	t_death_load_pressed_runs_restart()
	t_dynamic_restart_stays_dynamic()
	t_season_apply_is_throttled()
	t_death_load_pressed_defers_to_vanilla()
	t_task_note_removed_on_complete()
	t_completed_note_card_is_dropped()
	t_completed_note_drops_open_card()
	t_startinput_renders_only_target()
	t_traders_read_once_per_pass()
	t_ledger_from_resource()
	t_gc_ledger_once()
	t_selected_stacks_skips_queued_cells()
	t_post_callback_arity()
	t_hook_handles_are_counted()
	t_equip_pickup_free()
	t_equip_pickup_merge()
	t_equip_pickup_partial_leftover()
	t_equip_pickup_failed_no_move()
	t_equip_pickup_wrong_type_no_move()
	t_context_split_slot()
	t_context_take_slot()
	t_context_grid_defers_to_vanilla()
	t_equip_container_double_click()
	t_equip_container_context()
	t_equip_container_drag()
	t_equip_container_failed_no_move()
	print("")
	if fails == 0:
		print("Hooks tests passed")
		quit(0)
	else:
		print("Hooks tests failed: ", fails)
		quit(1)

# После смерти в ironman Death._ready делает gameData.Reset(): difficulty
# падает с 3 на 1, а LoadWorld возвращает permadeath только при difficulty==3
# в World.tres. Рестарт обязан звать Loader.NewGame(): он форматирует сейв и
# заново пишет World/Character/Traders/Cabin/Tent. Без Traders.tres квесты и
# заметки молча не сохраняются, без World.tres день падает в 0.
class FakeSim extends Node:
	var season := 1

func t_ironman_restart_restores_difficulty() -> void:
	var gd := FakeGD.new()
	gd.difficulty = 1
	gd.isDead = true
	gd.permadeath = false
	gd.shelter = false

	var sim := FakeSim.new()
	sim.name = "Simulation"
	sim.season = 2
	root.add_child(sim)
	var loader := FakeLoader.new()
	loader.name = "Loader"
	root.add_child(loader)

	var h = TestHooks.new()
	root.add_child(h)
	h._on_restart_pressed(gd, true)

	ck(loader.new_game_called, "ironman-рестарт зовёт Loader.NewGame")
	ck(loader.new_game_difficulty == 3, "NewGame получает difficulty 3")
	ck(loader.new_game_season == 2, "сезон берётся из /root/Simulation")
	# shelter/permadeath здесь НЕ проверяем: их по имени сцены выставляет
	# Loader.LoadScene (Loader.gd:252-361), а не мод. Проверяем только то,
	# что мод реально задаёт перед NewGame/LoadScene.
	ck(gd.difficulty == 3,
		"ironman-рестарт восстанавливает difficulty=3, иначе LoadWorld не вернёт permadeath после перехода")
	ck(gd.isDead == false, "ironman-рестарт снимает isDead")

	sim.free()
	loader.free()
	h.queue_free()

# Dynamic-забег после смерти обязан остаться Dynamic: _resolve_start_season
# отдавал только ванильный сезон Simulation (1/2), и NewGame стартовал обычный
# забег - сезоны переставали циклиться.
func t_dynamic_restart_stays_dynamic() -> void:
	var gd := FakeGD.new()
	gd.difficulty = 3
	gd.isDead = true

	var sim := FakeSim.new()
	sim.name = "Simulation"
	sim.season = 2
	root.add_child(sim)
	var loader := FakeLoader.new()
	loader.name = "Loader"
	root.add_child(loader)

	var h = TestHooks.new()
	root.add_child(h)
	h._dyn_enabled = true
	h._on_restart_pressed(gd, true)

	ck(loader.new_game_called, "dynamic-рестарт зовёт NewGame")
	ck(loader.new_game_season == 3, "dynamic-рестарт сохраняет Dynamic (сезон 3), а не ванильный")

	sim.free()
	loader.free()
	h.queue_free()

# Сезон меняется раз в season_cycle_days: опрос /root/Simulation каждый кадр
# ни к чему. _process накапливает delta и применяет сезон не чаще, чем раз в
# SEASON_APPLY_SEC; немедленные вызовы (spawn/new_run/resume) остаются как были.
func t_season_apply_is_throttled() -> void:
	var h := SeasonSpy.new()
	root.add_child(h)
	h._registered = true      # не ходим в _try_register из теста
	h._dyn_enabled = true

	h._process(0.1)
	h._process(0.1)
	ck(h.applies == 0, "первые кадры сезон не применяют")

	h._process(0.4)
	ck(h.applies == 1, "через SEASON_APPLY_SEC сезон применяется один раз")

	h._process(0.1)
	ck(h.applies == 1, "следующий кадр не повторяет применение")

	# Второй проход: после окна SEASON_APPLY_SEC сезон применяется снова.
	h._season_poll = TestHooks.SEASON_APPLY_SEC
	h._process(0.0)
	ck(h.applies == 2, "второй проход через SEASON_APPLY_SEC применяет снова")

	h.queue_free()

class FakeLib2:
	var _caller = null
	var skipped := false

	func skip_super() -> void:
		skipped = true

class FakeDeath extends Control:
	var gameData = null
	var pd: Sprite2D = null
	var btn: Button = null
	var blocker: Panel = null

func _fake_death(permadeath_visible: bool) -> FakeDeath:
	var death := FakeDeath.new()
	death.name = "Death"
	var main := Control.new()
	main.name = "Main"
	death.pd = Sprite2D.new()
	death.pd.name = "Permadeath"
	death.pd.visible = permadeath_visible
	var buttons := Control.new()
	buttons.name = "Buttons"
	death.btn = Button.new()
	death.btn.name = "Load"
	death.btn.text = "Load game"
	death.btn.disabled = true
	death.blocker = Panel.new()
	death.blocker.name = "Blocker"
	buttons.add_child(death.btn)
	main.add_child(death.pd)
	main.add_child(buttons)
	death.add_child(main)
	death.add_child(death.blocker)
	return death

func t_death_ready_unlocks_restart_for_permadeath() -> void:
	var h = TestHooks.new()
	root.add_child(h)
	var lib := FakeLib2.new()
	h._lib = lib

	var death := _fake_death(true)
	root.add_child(death)
	lib._caller = death
	h._on_death_ready()
	ck(death.btn.text == "Restart", "пермадэт: кнопка переименована в Restart")
	ck(death.btn.disabled == false, "пермадэт: кнопка раздизейблена")

	var plain := _fake_death(false)
	root.add_child(plain)
	lib._caller = plain
	h._on_death_ready()
	ck(plain.btn.text == "Load game", "обычная смерть: текст кнопки не тронут")
	ck(plain.btn.disabled == true, "обычная смерть: disabled не тронут")

	death.queue_free()
	plain.queue_free()
	h.queue_free()

func t_death_load_pressed_runs_restart() -> void:
	var sim := FakeSim.new()
	sim.name = "Simulation"
	sim.season = 2
	root.add_child(sim)
	var loader := FakeLoader.new()
	loader.name = "Loader"
	root.add_child(loader)

	var h = TestHooks.new()
	root.add_child(h)
	var lib := FakeLib2.new()
	h._lib = lib

	var gd := FakeGD.new()
	var death := _fake_death(true)
	death.gameData = gd
	root.add_child(death)
	lib._caller = death

	h._on_death_load_pressed()
	ck(lib.skipped, "пермадэт: super подавлен")
	ck(loader.new_game_called, "пермадэт: рестарт зовёт Loader.NewGame")
	ck(loader.new_game_difficulty == 3, "пермадэт: difficulty 3")
	ck(loader.new_game_season == 2, "пермадэт: сезон из /root/Simulation")
	ck(gd.isDead == false, "пермадэт: isDead снят")
	ck(death.blocker.mouse_filter == Control.MOUSE_FILTER_STOP,
		"пермадэт: блокер глотает повторный клик")

	death.queue_free()
	sim.free()
	loader.free()
	h.queue_free()

func t_death_load_pressed_defers_to_vanilla() -> void:
	var loader := FakeLoader.new()
	loader.name = "Loader"
	root.add_child(loader)

	var h = TestHooks.new()
	root.add_child(h)
	var lib := FakeLib2.new()
	h._lib = lib

	var death := _fake_death(false)
	death.gameData = FakeGD.new()
	root.add_child(death)
	lib._caller = death

	h._on_death_load_pressed()
	ck(not lib.skipped, "обычная смерть: super не подавлен")
	ck(not loader.new_game_called, "обычная смерть: NewGame не зовётся")

	death.queue_free()
	loader.free()
	h.queue_free()

# Ванильный путь смерти: WeaponDamage вычитает health и зовёт Death только при
# health <= 0; ExplosionDamage зовёт Death без правки health. Мод решает всё в
# pre-хуке (до тела Death), поэтому dead = true ставим уже после вызова.
func _die_native(h, lib, ai, explosion := false, damage := 50.0) -> void:
	if not explosion:
		ai.health -= damage
	lib._caller = ai
	h._on_ai_death(Vector3.ZERO, 10.0)
	ai.dead = true

func t_kill_event() -> void:
	var evs: Array = []
	var h = TestHooks.new()
	root.add_child(h)
	h.connect("kill_event", func(ev: Dictionary) -> void: evs.append(ev))

	var lib := FakeLib2.new()
	h._lib = lib

	# Игрок убивает AI: запись из weapondamage моложе окна.
	var victim := FakeAgent2.new()
	victim.name = "AI_Bandit"
	victim.variant.faction = 1
	victim.variant.name = "Bandit"
	root.add_child(victim)
	var player := FakeAgent2.new()
	player.name = "PlayerHand"
	player.add_to_group("Player")
	root.add_child(player)
	lib._caller = victim
	h._on_ai_weapon_damage("Head", 35.0, Vector3.ZERO, player)
	_die_native(h, lib, victim, false, 120.0)
	ck(evs.size() == 1, "одно событие на смерть")
	if evs.size() == 1:
		var ev: Dictionary = evs[0]
		ck(str(ev["killer_kind"]) == "player", "убийца — player")
		ck(str(ev["victim_name"]) == "Bandit", "жертва названа Bandit")
		ck(bool(ev["headshot"]), "hitbox Head -> headshot")
		ck(not bool(ev["grenade"]), "обычное убийство не граната")

	# Дедуп: та же жертва умирает второй раз — событие одно.
	_die_native(h, lib, victim, false, 120.0)
	ck(evs.size() == 1, "повторная смерть не даёт второго события")
	# Немедленно освобождаем: иначе её имя "AI_Bandit" займёт следующий
	# узел с тем же именем (add_child авто-переименует дубль в @Node3D@N).
	victim.free()

	# AI убивает AI: Bandit бьёт Nomad.
	var victim2 := FakeAgent2.new()
	victim2.name = "AI_Nomad"
	victim2.variant.faction = 0
	victim2.variant.name = "Nomad"
	root.add_child(victim2)
	var bandit := FakeAgent2.new()
	bandit.name = "AI_Bandit"
	bandit.variant.faction = 1
	bandit.variant.name = "Bandit"
	root.add_child(bandit)
	lib._caller = victim2
	h._on_ai_weapon_damage("Chest", 50.0, Vector3.ZERO, bandit)
	_die_native(h, lib, victim2, false, 120.0)
	ck(evs.size() == 2, "AI-vs-AI событие есть")
	if evs.size() == 2:
		ck(str(evs[1]["killer_name"]) == "Bandit", "убийца Bandit")
		ck(str(evs[1]["victim_name"]) == "Nomad", "жертва Nomad")
		ck(str(evs[1]["killer_kind"]) == "enemy", "bandit -> enemy (красный)")
		ck(str(evs[1]["victim_kind"]) == "nomad", "nomad -> nomad (зелёный)")

	# Старая рана: NPC умер сам. Строка есть, но без убийцы — только череп + имя.
	var victim3 := FakeAgent2.new()
	victim3.name = "AI_Bandit"
	victim3.variant.faction = 1
	victim3.variant.name = "Bandit"
	root.add_child(victim3)
	var count_before := h.get_kill_count()
	lib._caller = victim3
	h._on_ai_weapon_damage("Chest", 10.0, Vector3.ZERO, bandit)
	h._last_damager[victim3.get_instance_id()] = {
		"t": Time.get_ticks_msec() - 60000, "hitbox": "Chest",
		"killer_kind": "enemy", "killer_name": "Bandit", "weapon": "AKM",
	}
	_die_native(h, lib, victim3, false, 120.0)
	ck(evs.size() == 3, "старая рана даёт событие")
	if evs.size() == 3:
		ck(bool(evs[2]["self_death"]), "старая рана помечена self_death")
		ck(str(evs[2]["killer_kind"]) == "" and str(evs[2]["killer_name"]) == "", "у старой раны нет убийцы")
		ck(str(evs[2]["victim_name"]) == "Bandit", "жертва названа и в строке «сам»")
		ck(str(evs[2]["weapon"]) == "" and not bool(evs[2]["headshot"]), "подробности старой раны не показываются")
	ck(h.get_kill_count() == count_before, "старая рана не тикает счётчик")

	# Свежая запись без убийцы (id был null): строки нет, как и раньше.
	var victim4 := FakeAgent2.new()
	victim4.name = "AI_Bandit"
	root.add_child(victim4)
	lib._caller = victim4
	h._last_damager[victim4.get_instance_id()] = {
		"t": Time.get_ticks_msec(), "hitbox": "", "killer_kind": "",
		"killer_name": "", "weapon": "",
	}
	_die_native(h, lib, victim4, false, 120.0)
	ck(evs.size() == 3, "свежая запись без убийцы не показывается")

	# Записи нет вообще (смерть пришла мимо weapondamage): строки нет.
	var victim5 := FakeAgent2.new()
	victim5.name = "AI_Bandit"
	root.add_child(victim5)
	_die_native(h, lib, victim5, false, 120.0)
	ck(evs.size() == 3, "смерть без записи не показывается")

	victim2.queue_free()
	bandit.queue_free()
	victim3.queue_free()
	victim4.queue_free()
	victim5.queue_free()
	player.queue_free()
	h.queue_free()

# Запись живёт, пока жива жертва, поэтому атакующий может умереть раньше неё.
# Имя снимается в момент раны; живая ссылка к моменту смерти уже невалидна.
func t_attacker_snapshot() -> void:
	var evs: Array = []
	var h = TestHooks.new()
	root.add_child(h)
	h.connect("kill_event", func(ev: Dictionary) -> void: evs.append(ev))
	var lib := FakeLib2.new()
	h._lib = lib

	var victim := FakeAgent2.new()
	victim.name = "AI_Nomad"
	victim.variant.faction = 0
	victim.variant.name = "Nomad"
	victim.nickname = "Mikko"
	root.add_child(victim)
	var bandit := FakeAgent2.new()
	bandit.name = "AI_Bandit"
	bandit.variant.faction = 1
	bandit.variant.name = "Bandit"
	root.add_child(bandit)

	lib._caller = victim
	h._on_ai_weapon_damage("Chest", 40.0, Vector3.ZERO, bandit)
	bandit.free()
	_die_native(h, lib, victim, false, 120.0)

	ck(evs.size() == 1, "освобождённый атакующий не теряет килл")
	if evs.size() == 1:
		ck(str(evs[0]["killer_name"]) == "Bandit", "имя убийцы из снимка")
		ck(str(evs[0]["victim_name"]) == "Mikko", "жертва-номад названа никнеймом")

	victim.free()
	h.queue_free()

# 15 с — порог свежести, а не время жизни записи: иначе смерть от старой раны
# нечем описать и строка «череп» не появляется никогда.
func t_damage_record_ttl() -> void:
	var h = TestHooks.new()
	root.add_child(h)
	var lib := FakeLib2.new()
	h._lib = lib
	var controller := FakeAgent2.new()
	controller.name = "AI_Controller"
	root.add_child(controller)
	lib._caller = controller

	var victim := FakeAgent2.new()
	victim.name = "AI_Bandit"
	root.add_child(victim)
	var iid := victim.get_instance_id()
	lib._caller = victim
	h._on_ai_weapon_damage("Chest", 10.0, Vector3.ZERO, null)
	h._last_damager[iid]["t"] = Time.get_ticks_msec() - 60000

	lib._caller = controller
	h._sweep_at = -100000
	h._on_controller_process(0.1)
	ck(h._last_damager.has(iid), "запись живой жертвы переживает окно 15 с")

	var gone := FakeAgent2.new()
	gone.name = "AI_Gone"
	root.add_child(gone)
	var gone_id := gone.get_instance_id()
	lib._caller = gone
	h._on_ai_weapon_damage("Chest", 10.0, Vector3.ZERO, null)
	gone.free()
	lib._caller = controller
	h._sweep_at = -100000
	h._on_controller_process(0.1)
	ck(not h._last_damager.has(gone_id), "запись освобождённой жертвы вычищается")

	victim.free()
	controller.free()
	h.queue_free()

func t_sweep_is_throttled() -> void:
	var h = TestHooks.new()
	root.add_child(h)
	var lib := FakeLib2.new()
	h._lib = lib
	var controller := FakeAgent2.new()
	root.add_child(controller)
	lib._caller = controller

	var stale := 1000000   # id заведомо несуществующего узла
	# Устаревшая запись — старше TTL обхода (600 с), а не «минуту назад»: порог
	# свежести раны (15 с) к чистке _seen_deaths отношения не имеет.
	var old := Time.get_ticks_msec() - TestHooks.SEEN_DEATHS_TTL_MSEC - 60000
	h._sweep_at = -100000   # first sweep must not wait for the 500 ms window
	h._seen_deaths[stale] = old
	h._on_controller_process(0.1)
	ck(not h._seen_deaths.has(stale), "первый обход чистит устаревшую запись")

	h._seen_deaths[stale] = old
	h._on_controller_process(0.1)
	ck(h._seen_deaths.has(stale), "следующий кадр подряд словари не обходит")

	h._sweep_at = -100000
	h._on_controller_process(0.1)
	ck(not h._seen_deaths.has(stale), "после окна обход снова идёт")

	controller.free()
	h.queue_free()

class FakeVariant extends RefCounted:
	var faction := 0
	var name := "Bandit"

class FakeAgent2 extends Node3D:
	var dead := false
	var health := 100
	var active := true
	var variant = FakeVariant.new()
	var nickname := ""
	var weapon = null

	func Activate() -> void:
		pass

# Игра отдаёт атакующего как ID-маркер (.../Identifier/ID), а не агента.
# Раньше маркер проваливал _is_agent -> kind "" -> fallback "enemy":
# имя Nomad резолвилось через owner, а цвет горел красным.
func t_marker_attacker() -> void:
	var evs: Array = []
	var h = TestHooks.new()
	root.add_child(h)
	h.connect("kill_event", func(ev: Dictionary) -> void: evs.append(ev))
	var lib := FakeLib2.new()
	h._lib = lib

	var victim := FakeAgent2.new()
	victim.name = "AI_Guard"
	victim.variant.faction = 2
	victim.variant.name = "Guard"
	root.add_child(victim)

	var nomad := FakeAgent2.new()
	nomad.name = "AI_Nomad_2"
	nomad.variant.faction = 0
	nomad.variant.name = "Nomad"
	nomad.weapon = "AKS-74U"
	root.add_child(nomad)
	# Цепочка маркера как в игре: agent/Skeleton3D/Identifier/ID.
	var skel := Node3D.new()
	skel.name = "Skeleton3D"
	nomad.add_child(skel)
	var ident := Node3D.new()
	ident.name = "Identifier"
	skel.add_child(ident)
	var marker := Node3D.new()
	marker.name = "ID"
	ident.add_child(marker)

	lib._caller = victim
	h._on_ai_weapon_damage("Head", 30.0, Vector3.ZERO, marker)
	_die_native(h, lib, victim, false, 120.0)

	ck(evs.size() == 1, "маркер-атакующий: событие есть")
	if evs.size() == 1:
		var ev: Dictionary = evs[0]
		ck(str(ev["killer_kind"]) == "nomad", "маркер поднимается до агента: nomad, не enemy")
		ck(str(ev["killer_name"]) == "Nomad", "имя берётся у агента-предка, хвост _2 срезан")
		ck(str(ev["weapon"]) == "AKS-74U", "оружие берётся у агента-предка")
		ck(str(ev["victim_kind"]) == "enemy", "жертва Guard -> enemy")

	nomad.free()
	victim.free()
	h.queue_free()

# Граната бьёт мимо ai-weapondamage: только ai-explosiondamage
# (probe Task 1, п.4: caller=жертва, id=Area бросившего, grpP=true).
# Без него взрывной килл не попадает ни в счётчик, ни в ленту.
func t_explosion_kill() -> void:
	var evs: Array = []
	var h = TestHooks.new()
	root.add_child(h)
	h.connect("kill_event", func(ev: Dictionary) -> void: evs.append(ev))
	var lib := FakeLib2.new()
	h._lib = lib

	var victim := FakeAgent2.new()
	victim.name = "AI_Bandit"
	victim.variant.faction = 1
	victim.variant.name = "Bandit"
	root.add_child(victim)
	var player := FakeAgent2.new()
	player.name = "PlayerHand"
	player.add_to_group("Player")
	root.add_child(player)

	lib._caller = victim
	h._on_ai_explosion(Vector3.ZERO, player)
	# Взрыв убивает без вычитания health: хватает перехода dead.
	_die_native(h, lib, victim, true)

	ck(evs.size() == 1, "гранатный килл: событие есть")
	if evs.size() == 1:
		var ev: Dictionary = evs[0]
		ck(str(ev["killer_kind"]) == "player", "граната от игрока -> player")
		ck(bool(ev["grenade"]), "EXP -> граната в ленте")
		ck(str(ev["weapon"]) == "", "имени оружия у EXP нет")
	ck(h.get_kill_count() == 1, "гранатный килл посчитан счётчиком")

	# Дедуп и счётчик: та же жертва умирает второй раз.
	_die_native(h, lib, victim, true)
	ck(evs.size() == 1, "гранатный килл не задублирован")
	ck(h.get_kill_count() == 1, "счётчик не задрался на повторе")

	victim.free()
	player.free()
	h.queue_free()

# Ни GameData, ни узел игрока не несут имени оружия: настоящее — WeaponRig
# под Camera/Manager, у него data.file (probe: AKM, M4A1, Jaeger_140).
func t_player_rig_weapon() -> void:
	var h = TestHooks.new()
	root.add_child(h)

	var map := Node3D.new()
	map.name = "Map"
	root.add_child(map)
	var core := Node3D.new()
	core.name = "Core"
	map.add_child(core)
	var cam := Node3D.new()
	cam.name = "Camera"
	core.add_child(cam)
	var mgr := Node3D.new()
	mgr.name = "Manager"
	cam.add_child(mgr)

	var hidden := FakeRig.new()
	hidden.name = "AKM_Rig"
	hidden.data = {"file": "AKM"}
	hidden.visible = false
	mgr.add_child(hidden)
	var current := FakeRig.new()
	current.name = "M4A1_Rig"
	current.data = {"file": "M4A1"}
	mgr.add_child(current)

	ck(h._rig_weapon_name() == "M4A1",
		"оружие игрока берётся из видимого WeaponRig data.file")
	current.data = {"file": "AKM"}
	hidden.visible = true
	ck(h._rig_weapon_name() == "AKM",
		"если риг несколько, берётся видимый")
	hidden.data = {}
	ck(h._rig_weapon_name() == "AKM",
		"риг без data.file пропускается")

	map.free()
	h.queue_free()

class FakeRig extends Node3D:
	var data: Dictionary = {}

class FakeWeaponHolder extends Node:
	var weaponData = null

# E-09: ветка weaponData.name в _weapon_name_of (фолбэк имени оружия) ранее не
# была покрыта — фикстуры рига давали только data.file.
func t_weapon_name_from_weapondata() -> void:
	var h = TestHooks.new()
	root.add_child(h)

	var n := FakeWeaponHolder.new()
	n.weaponData = {"name": "  AKM  "}
	ck(h._weapon_name_of(n) == "AKM", "имя оружия из weaponData.name обрезается")

	var blank := FakeWeaponHolder.new()
	blank.weaponData = {}
	ck(h._weapon_name_of(blank) == "", "пустой weaponData -> пусто")

	var plain := Node.new()
	ck(h._weapon_name_of(plain) == "", "без weaponData и фолбэк-свойств -> пусто")

	n.free()
	blank.free()
	plain.free()
	h.queue_free()

class FakeSD extends RefCounted:
	var itemData = null
	var amount = 1

class FakeItem extends Node:
	var slotData = null
	var details_updated := false
	var selected := false

	func UpdateDetails() -> void:
		details_updated = true

class FakeSlot extends Node:
	var hint := ""

class FakeGrid extends Node:
	var picked: Array = []

	func Pick(n) -> void:
		picked.append(n)

class FakePickup extends Node:
	var slotData = null
	var interface = null

class FakeIface extends Node:
	var inventoryGrid = null
	var equipment = null
	var equipped: Array = []
	var stats_calls := 0
	var created: Array = []
	var contextItem = null
	var contextSlot = null
	var contextGrid = null
	var hoverItem = null
	var hoverGrid = null
	var containerGrid = null

	func Equip(node, sl) -> void:
		equipped.append([node, str(sl.name)])
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		sl.add_child(node)

	func UpdateStats(_force) -> void:
		stats_calls += 1

	func PlayEquip() -> void:
		pass

	func PlayStack() -> void:
		pass

	func Reset() -> void:
		pass

	func HideContext() -> void:
		pass

	func AutoStack(sd, grid) -> bool:
		if grid == null or sd == null:
			return false
		var res = sd.get("itemData")
		if res == null:
			return false
		var maxa := int(res.get("maxAmount"))
		var amt := int(sd.get("amount"))
		for el in grid.get_children():
			if not is_instance_valid(el):
				continue
			var esd = el.get("slotData")
			if esd == null or str(esd.get("itemData").get("file", "")) != str(res.get("file", "")):
				continue
			var room := maxa - int(esd.get("amount"))
			if room <= 0:
				continue
			if amt <= room:
				esd.set("amount", int(esd.get("amount")) + amt)
				return true
			esd.set("amount", int(esd.get("amount")) + room)
			sd.set("amount", amt - room)
			return Create(sd, grid, false)
		return false

	func Create(sd, grid, _use_drop) -> bool:
		created.append(sd)
		if grid == null:
			return false
		var it := FakeItem.new()
		it.slotData = sd
		grid.add_child(it)
		return true

func _mk_iface2() -> Dictionary:
	var iface := FakeIface.new()
	iface.name = "Interface"
	var ig := FakeGrid.new()
	ig.name = "inventoryGrid"
	iface.inventoryGrid = ig
	iface.add_child(ig)
	var equip := Node.new()
	equip.name = "Equipment"
	iface.equipment = equip
	iface.add_child(equip)
	root.add_child(iface)
	return {"iface": iface, "ig": ig, "equip": equip}

func _mk_pickup(iface, sd) -> FakePickup:
	var p := FakePickup.new()
	p.name = "Pickup"
	p.slotData = sd
	p.interface = iface
	root.add_child(p)
	return p

# Свободный слот: подбор уносит подобранное количество из инвентаря в слот.
func t_equip_pickup_free() -> void:
	var h = TestHooks.new()
	root.add_child(h)
	var c := _mk_iface2()
	var lib := FakeLib2.new()
	h._lib = lib
	var rifle := {"file": "AKM", "name": "AKM", "slots": ["Primary"]}
	var primary := FakeSlot.new(); primary.name = "Primary"; primary.hint = "Primary"
	c["equip"].add_child(primary)

	var psd := FakeSD.new(); psd.itemData = rifle; psd.amount = 1
	var p := _mk_pickup(c["iface"], psd)
	lib._caller = p
	h._on_pickup_interact_pre()
	# симуляция ванильного Create: предмет лёг в свободную клетку инвентаря
	var gun := FakeItem.new()
	var gsd := FakeSD.new(); gsd.itemData = rifle; gsd.amount = 1; gun.slotData = gsd
	c["ig"].add_child(gun)
	p.queue_free()
	h._on_pickup_interact_post()
	ck(c["iface"].equipped.size() == 1 and c["iface"].equipped[0][1] == "Primary", "подбор в свободный слот -> Equip")
	h.queue_free()
	c["iface"].free()

# Занятый слот того же типа: подобранное докладывается, отложенное не трогаем.
func t_equip_pickup_merge() -> void:
	var h = TestHooks.new()
	root.add_child(h)
	var c := _mk_iface2()
	var lib := FakeLib2.new()
	h._lib = lib
	var matches := {"file": "Matches", "name": "Matches", "slots": ["Matches"], "stackable": true, "maxAmount": 300, "defaultAmount": 10}
	var mslot := FakeSlot.new(); mslot.name = "Matches"; mslot.hint = "Matches"
	c["equip"].add_child(mslot)
	var occ := FakeItem.new()
	var osd := FakeSD.new(); osd.itemData = matches; osd.amount = 20; occ.slotData = osd
	mslot.add_child(occ)

	var psd := FakeSD.new(); psd.itemData = matches; psd.amount = 20
	var p := _mk_pickup(c["iface"], psd)
	lib._caller = p
	h._on_pickup_interact_pre()
	# симуляция ванильного AutoStack: подобрано 20, в инвентаре уже лежало 10
	var inc := FakeItem.new()
	var isd := FakeSD.new(); isd.itemData = matches; isd.amount = 30; inc.slotData = isd
	c["ig"].add_child(inc)
	p.queue_free()
	h._on_pickup_interact_post()
	ck(int(isd.amount) == 10, "уносим только подобранное: 10 отложенных остаются")
	ck(int(c["equip"].get_child(0).get_child(0).slotData.amount) == 40, "экипированный стек вырос на 20")
	h.queue_free()
	c["iface"].free()

# Свободный слот, в инвентаре излишек: в слот уходит подобранное, остаток
# возвращается в инвентарь.
func t_equip_pickup_partial_leftover() -> void:
	var h = TestHooks.new()
	root.add_child(h)
	var c := _mk_iface2()
	var lib := FakeLib2.new()
	h._lib = lib
	var matches := {"file": "Matches", "name": "Matches", "slots": ["Matches"], "stackable": true, "maxAmount": 300}
	var mslot := FakeSlot.new(); mslot.name = "Matches"; mslot.hint = "Matches"
	c["equip"].add_child(mslot)

	var psd := FakeSD.new(); psd.itemData = matches; psd.amount = 20
	var p := _mk_pickup(c["iface"], psd)
	lib._caller = p
	h._on_pickup_interact_pre()
	var inc := FakeItem.new()
	var isd := FakeSD.new(); isd.itemData = matches; isd.amount = 30; inc.slotData = isd
	c["ig"].add_child(inc)
	p.queue_free()
	h._on_pickup_interact_post()
	ck(c["iface"].equipped.size() == 1, "подобранное ушло в слот")
	ck(int(c["equip"].get_child(0).get_child(0).slotData.amount) == 20, "в слот ушло ровно подобранное")
	var left := 0
	for ch in c["ig"].get_children():
		left += int(ch.get("slotData").get("amount"))
	ck(left == 10, "отложенные 10 вернулись в инвентарь")
	h.queue_free()
	c["iface"].free()

# Неудачный подбор (узел не удалён) и не-экипировка не двигают ничего.
func t_equip_pickup_failed_no_move() -> void:
	var h = TestHooks.new()
	root.add_child(h)
	var c := _mk_iface2()
	var lib := FakeLib2.new()
	h._lib = lib
	var rifle := {"file": "AKM", "name": "AKM", "slots": ["Primary"]}
	var primary := FakeSlot.new(); primary.name = "Primary"; primary.hint = "Primary"
	c["equip"].add_child(primary)

	var psd := FakeSD.new(); psd.itemData = rifle; psd.amount = 1
	var p := _mk_pickup(c["iface"], psd)
	lib._caller = p
	h._on_pickup_interact_pre()
	var gun := FakeItem.new()
	var gsd := FakeSD.new(); gsd.itemData = rifle; gsd.amount = 1; gun.slotData = gsd
	c["ig"].add_child(gun)
	# подбор не удался: узел не в queue_free
	h._on_pickup_interact_post()
	ck(c["iface"].equipped.is_empty(), "неудачный подбор (PlayError) ничего не экипирует")
	h.queue_free()
	c["iface"].free()

func t_equip_pickup_wrong_type_no_move() -> void:
	var h = TestHooks.new()
	root.add_child(h)
	var c := _mk_iface2()
	var lib := FakeLib2.new()
	h._lib = lib
	var beer := {"file": "Beer", "name": "Beer", "slots": []}
	var psd := FakeSD.new(); psd.itemData = beer; psd.amount = 1
	var p := _mk_pickup(c["iface"], psd)
	lib._caller = p
	h._on_pickup_interact_pre()
	p.queue_free()
	h._on_pickup_interact_post()
	ck(c["iface"].equipped.is_empty(), "не экипировка -> слот не трогаем")
	h.queue_free()

# Take/Split из слота экипировки: ванильные ContextTake/ContextSplit в слоте
# молча выходят (contextGrid == null). Возвращаем долю стака в инвентарь.
func t_context_split_slot() -> void:
	var h = TestHooks.new()
	root.add_child(h)
	var c := _mk_iface2()
	var lib := FakeLib2.new()
	h._lib = lib
	lib._caller = c["iface"]
	var matches := {"file": "Matches", "name": "Matches", "slots": ["Matches"], "stackable": true, "maxAmount": 300, "defaultAmount": 10}
	var slot := FakeSlot.new(); slot.name = "Matches"; slot.hint = "Matches"
	c["equip"].add_child(slot)
	var item := FakeItem.new()
	var isd := FakeSD.new(); isd.itemData = matches; isd.amount = 40; item.slotData = isd
	slot.add_child(item)
	c["iface"].set("contextItem", item)
	c["iface"].set("contextSlot", slot)
	c["iface"].set("contextGrid", null)
	h._on_context_split_replace()
	ck(int(isd.amount) == 20, "Split делит стек в слоте пополам")
	ck(c["iface"].created.size() == 1 and int(c["iface"].created[0].get("amount")) == 20, "доля ушла в инвентарь")
	ck(lib.skipped, "Split пропускает ванильное тело (skip_super)")
	h.queue_free()
	c["iface"].free()

func t_context_take_slot() -> void:
	var h = TestHooks.new()
	root.add_child(h)
	var c := _mk_iface2()
	var lib := FakeLib2.new()
	h._lib = lib
	lib._caller = c["iface"]
	var matches := {"file": "Matches", "name": "Matches", "slots": ["Matches"], "stackable": true, "maxAmount": 300, "defaultAmount": 10}
	var slot := FakeSlot.new(); slot.name = "Matches"; slot.hint = "Matches"
	c["equip"].add_child(slot)
	var item := FakeItem.new()
	var isd := FakeSD.new(); isd.itemData = matches; isd.amount = 40; item.slotData = isd
	slot.add_child(item)
	c["iface"].set("contextItem", item)
	c["iface"].set("contextSlot", slot)
	c["iface"].set("contextGrid", null)
	h._on_context_take_replace()
	ck(int(isd.amount) == 30, "Take снимает defaultAmount из слота")
	ck(c["iface"].created.size() == 1 and int(c["iface"].created[0].get("amount")) == 10, "доля ушла в инвентарь")
	ck(lib.skipped, "Take пропускает ванильное тело")
	h.queue_free()
	c["iface"].free()

# Предмет в гриде (contextGrid != null): мод не вмешивается, тело ванили идёт.
func t_context_grid_defers_to_vanilla() -> void:
	var h = TestHooks.new()
	root.add_child(h)
	var c := _mk_iface2()
	var lib := FakeLib2.new()
	h._lib = lib
	lib._caller = c["iface"]
	var matches := {"file": "Matches", "name": "Matches", "slots": ["Matches"], "stackable": true, "maxAmount": 300, "defaultAmount": 10}
	var item := FakeItem.new()
	var isd := FakeSD.new(); isd.itemData = matches; isd.amount = 40; item.slotData = isd
	c["ig"].add_child(item)
	c["iface"].set("contextItem", item)
	c["iface"].set("contextGrid", c["ig"])
	c["iface"].set("contextSlot", null)
	h._on_context_split_replace()
	ck(int(isd.amount) == 40, "предмет в гриде -> ванильное поведение (не трогаем)")
	ck(not lib.skipped, "супер не пропускается для грида")
	ck(c["iface"].created.is_empty(), "в гриде доля создаётся ванильным кодом, не нами")
	h.queue_free()
	c["iface"].free()

# --- Авто-экип из контейнера -------------------------------------------------
# Грид контейнера назван "containerGrid" и лежит под узлом "Container" — именно
# по имени родителя FastTransfer/ContextTransfer узнают направление переноса.
func _mk_container(iface) -> Dictionary:
	var cont := Node.new(); cont.name = "Container"; iface.add_child(cont)
	var cgrid := FakeGrid.new(); cgrid.name = "containerGrid"; cont.add_child(cgrid)
	iface.containerGrid = cgrid
	return {"node": cont, "grid": cgrid}

# Двойной клик (FastTransfer): предмет переехал из контейнера в инвентарь ->
# уходит в слот.
func t_equip_container_double_click() -> void:
	var h = TestHooks.new(); root.add_child(h)
	var c := _mk_iface2()
	var lib := FakeLib2.new(); h._lib = lib
	var rifle := {"file": "AKM", "name": "AKM", "slots": ["Primary"], "maxAmount": 1}
	var primary := FakeSlot.new(); primary.name = "Primary"; primary.hint = "Primary"
	c["equip"].add_child(primary)
	var k := _mk_container(c["iface"])
	var citem := FakeItem.new()
	var csd := FakeSD.new(); csd.itemData = rifle; csd.amount = 0; citem.slotData = csd
	k["grid"].add_child(citem)
	c["iface"].set("hoverGrid", k["grid"])
	c["iface"].set("hoverItem", citem)
	lib._caller = c["iface"]
	h._on_fasttransfer_pre()
	# ванильный AutoPlace: предмет переехал в инвентарь
	k["grid"].remove_child(citem)
	c["ig"].add_child(citem)
	h._on_fasttransfer_post()
	ck(c["iface"].equipped.size() == 1 and c["iface"].equipped[0][1] == "Primary",
		"двойной клик из контейнера -> Equip")
	h.queue_free()
	c["iface"].free()

# Контекстное Transfer (ContextTransfer) ведёт себя так же, но источник —
# contextItem/contextGrid.
func t_equip_container_context() -> void:
	var h = TestHooks.new(); root.add_child(h)
	var c := _mk_iface2()
	var lib := FakeLib2.new(); h._lib = lib
	var rifle := {"file": "AKM", "name": "AKM", "slots": ["Primary"], "maxAmount": 1}
	var primary := FakeSlot.new(); primary.name = "Primary"; primary.hint = "Primary"
	c["equip"].add_child(primary)
	var k := _mk_container(c["iface"])
	var citem := FakeItem.new()
	var csd := FakeSD.new(); csd.itemData = rifle; csd.amount = 0; citem.slotData = csd
	k["grid"].add_child(citem)
	c["iface"].set("contextGrid", k["grid"])
	c["iface"].set("contextItem", citem)
	lib._caller = c["iface"]
	h._on_contexttransfer_pre()
	k["grid"].remove_child(citem)
	c["ig"].add_child(citem)
	h._on_contexttransfer_post()
	ck(c["iface"].equipped.size() == 1 and c["iface"].equipped[0][1] == "Primary",
		"контекстное Transfer из контейнера -> Equip")
	h.queue_free()
	c["iface"].free()

# Перетаскивание (Grab/Release): предмет из контейнера уронили в инвентарь.
func t_equip_container_drag() -> void:
	var h = TestHooks.new(); root.add_child(h)
	var c := _mk_iface2()
	var lib := FakeLib2.new(); h._lib = lib
	var rifle := {"file": "AKM", "name": "AKM", "slots": ["Primary"], "maxAmount": 1}
	var primary := FakeSlot.new(); primary.name = "Primary"; primary.hint = "Primary"
	c["equip"].add_child(primary)
	var k := _mk_container(c["iface"])
	var citem := FakeItem.new()
	var csd := FakeSD.new(); csd.itemData = rifle; csd.amount = 0; citem.slotData = csd
	k["grid"].add_child(citem)
	c["iface"].set("hoverGrid", k["grid"])
	c["iface"].set("hoverItem", citem)
	lib._caller = c["iface"]
	h._on_grab_pre()
	# ванильный Release: Place перенёс предмет в инвентарь
	k["grid"].remove_child(citem)
	c["ig"].add_child(citem)
	h._on_release_post()
	ck(c["iface"].equipped.size() == 1 and c["iface"].equipped[0][1] == "Primary",
		"перетаскивание из контейнера в инвентарь -> Equip")
	h.queue_free()
	c["iface"].free()

# Неудачный перенос: предмет остался в контейнере (родитель не инвентарь,
# узел не помечен на удаление) -> слот не трогаем.
func t_equip_container_failed_no_move() -> void:
	var h = TestHooks.new(); root.add_child(h)
	var c := _mk_iface2()
	var lib := FakeLib2.new(); h._lib = lib
	var rifle := {"file": "AKM", "name": "AKM", "slots": ["Primary"], "maxAmount": 1}
	var primary := FakeSlot.new(); primary.name = "Primary"; primary.hint = "Primary"
	c["equip"].add_child(primary)
	var k := _mk_container(c["iface"])
	var citem := FakeItem.new()
	var csd := FakeSD.new(); csd.itemData = rifle; csd.amount = 0; citem.slotData = csd
	k["grid"].add_child(citem)
	c["iface"].set("hoverGrid", k["grid"])
	c["iface"].set("hoverItem", citem)
	lib._caller = c["iface"]
	h._on_fasttransfer_pre()
	# перенос не удался (PlayError): предмет остался в контейнере
	h._on_fasttransfer_post()
	ck(c["iface"].equipped.is_empty(), "неудачный перенос из контейнера ничего не экипирует")
	h.queue_free()
	c["iface"].free()

# Слияние стека (AutoStack): контейнерный узел удаляется, инвентарный стек
# растёт — в слот уходит ровно перенесённое количество.
func t_equip_container_stack_merge() -> void:
	var h = TestHooks.new(); root.add_child(h)
	var c := _mk_iface2()
	var lib := FakeLib2.new(); h._lib = lib
	var matches := {"file": "Matches", "name": "Matches", "slots": ["Matches"], "stackable": true, "maxAmount": 300, "defaultAmount": 10}
	var mslot := FakeSlot.new(); mslot.name = "Matches"; mslot.hint = "Matches"
	c["equip"].add_child(mslot)
	var occ := FakeItem.new()
	var osd := FakeSD.new(); osd.itemData = matches; osd.amount = 20; occ.slotData = osd
	mslot.add_child(occ)
	var k := _mk_container(c["iface"])
	var citem := FakeItem.new()
	var csd := FakeSD.new(); csd.itemData = matches; csd.amount = 20; citem.slotData = csd
	k["grid"].add_child(citem)
	c["iface"].set("hoverGrid", k["grid"])
	c["iface"].set("hoverItem", citem)
	lib._caller = c["iface"]
	h._on_fasttransfer_pre()
	# ванильный AutoStack: в инвентаре стек 10 + перенесённые 20 = 30, узел удалён
	var inc := FakeItem.new()
	var isd := FakeSD.new(); isd.itemData = matches; isd.amount = 30; inc.slotData = isd
	c["ig"].add_child(inc)
	citem.queue_free()
	h._on_fasttransfer_post()
	ck(int(isd.amount) == 10, "слияние: в инвентаре остаются отложенные 10")
	ck(int(c["equip"].get_child(0).get_child(0).slotData.amount) == 40,
		"слияние: экипированный стек вырос на перенесённые 20")
	h.queue_free()
	c["iface"].free()

# Х3: ваниль строит карточки из LoadTaskNotes() ДО post-хука, поэтому сданная
# заметка висела на экране до переоткрытия вкладки. Данные при этом уже
# почищены - терялась только строка.
func t_completed_note_card_is_dropped() -> void:
	var h = TestHooks.new()
	root.add_child(h)
	var ldr := FakeLoaderNotes.new()
	ldr.name = "Loader"
	root.add_child(ldr)
	var note := {"name": "Duty Calls", "trader": "Doctor"}
	ldr.notes = [note]

	var card = FakeNoteCard.new()
	card.taskData = {"name": "Duty Calls", "trader": "Doctor"}
	root.add_child(card)

	h._prune_note_cards([card], ldr.notes, {"doctor": {"Duty Calls": true}}, ldr)
	ck(card.is_queued_for_deletion(), "сданная заметка убирается сразу")
	ck(ldr.saved.size() == 1 and ldr.saved[0][1] == false, "и стирается из сейва заметок")

	var live = FakeNoteCard.new()
	live.taskData = {"name": "Still here", "trader": "Doctor"}
	root.add_child(live)
	h._prune_note_cards([live], [], {}, ldr)
	ck(not live.is_queued_for_deletion(), "несданная заметка остаётся в списке")

	h.free()
	ldr.free()

# Х3: сдача задачи происходит не на вкладке Notes, а карточки уже построены
# и висят в скрытом списке. Ваниль перерисовывает их только по нажатию вкладки,
# поэтому сданная карточка должна уйти из списка в момент сдачи.
func t_completed_note_drops_open_card() -> void:
	var h = TestHooks.new()
	root.add_child(h)
	var ldr := FakeLoaderNotes.new()
	ldr.name = "Loader"
	root.add_child(ldr)

	var map := Node.new(); map.name = "Map"; root.add_child(map)
	var core := Node.new(); core.name = "Core"; map.add_child(core)
	var ui := Node.new(); ui.name = "UI"; core.add_child(ui)
	var iface := FakeNotesIface.new(); iface.name = "Interface"; ui.add_child(iface)
	var list := Node.new(); iface.add_child(list)
	iface.notesList = list

	var completed_task := {"name": "Duty Calls", "trader": "Doctor"}
	var card := FakeNoteCard.new()
	card.taskData = completed_task
	list.add_child(card)
	var other := FakeNoteCard.new()
	other.taskData = {"name": "Still here", "trader": "Doctor"}
	list.add_child(other)

	h._on_task_completed(completed_task)
	ck(card.is_queued_for_deletion(), "сданная заметка исчезает из открытой вкладки сразу")
	ck(not other.is_queued_for_deletion(), "остальные карточки Notes остаются")

	h.free()
	map.free()
	ldr.free()

# Х7/Д4: queue_free отложен до конца кадра, поэтому ячейка, уже помеченная
# на удаление, остаётся "валидной" и "выбранной" - и попадала во вклад,
# который commit фиксирует ДО списания.
func t_selected_stacks_skips_queued_cells() -> void:
	var h := TestHooks.new()
	root.add_child(h)
	var iface := FakeIface.new()
	root.add_child(iface)
	var grid := Node.new()
	iface.add_child(grid)
	iface.inventoryGrid = grid

	var live := FakeItem.new()
	live.selected = true
	live.slotData = FakeSD.new()
	live.slotData.amount = 0
	live.slotData.itemData = {"file": "Cigarettes", "name": "Cigarettes"}
	grid.add_child(live)

	var dead := FakeItem.new()
	dead.selected = true
	dead.slotData = FakeSD.new()
	dead.slotData.itemData = {"file": "Cigarettes", "name": "Cigarettes"}
	grid.add_child(dead)
	dead.queue_free()

	var out := h._selected_stacks(iface)
	ck(out.size() == 1, "ячейка, помеченная на удаление, не попадает в выборку")
	ck(out.size() == 1 and out[0]["ref"] == live, "живая выбранная ячейка осталась")
	ck(out.size() == 1 and int(out[0]["amount"]) == 1, "amount 0 (нестакуемый) считается за один")

	iface.free()
	h.free()

# X6: лог считал сумму пяти массивов и +2, то есть печатал 22 при 25 хуках - и
# врал ещё до всякой поломки. Единственная честная цифра - число хэндлов,
# вернувшихся из hook(), поэтому их надо складывать в одном месте.
func t_hook_handles_are_counted() -> void:
	var h = TestHooks.new()
	root.add_child(h)
	var lib := FakeHookLib.new()
	root.add_child(lib)
	h._lib = lib
	h._do_register()
	ck(lib.names.size() == 25, "регистрируются все 25 хуков")
	ck(h._hook_ids.size() == lib.names.size(), "каждый hook() кладёт хэндл в _hook_ids")
	var seen := {}
	for id in h._hook_ids:
		seen[id] = true
	ck(seen.size() == h._hook_ids.size(), "хэндлы различимы")
	var uniq := {}
	for n in lib.names:
		uniq[n] = true
	ck(uniq.size() == lib.names.size(), "имена хуков не повторяются")
	h._do_register()
	ck(lib.names.size() == 25, "повторный _do_register не регистрирует хуки заново")
	h.queue_free()
	lib.queue_free()

# П1: клик по карточке задачи меняет только inputTarget, то есть disabled у
# Deposit/Complete одной карточки. Полный проход списка на каждый клик - работа
# в мусор, а с леджером и Traders.tres - ещё и чтение файла на карточку.
class RenderSpy extends TestHooks:
	var drawn: Array = []

	func _render_task_card(_iface, card, _traders = null) -> void:
		drawn.append(card)

class TaskIface extends Node:
	var taskList = null
	var inputTarget = null

func t_startinput_renders_only_target() -> void:
	var h := RenderSpy.new()
	root.add_child(h)
	var iface := TaskIface.new()
	root.add_child(iface)
	iface.taskList = GridContainer.new()
	iface.add_child(iface.taskList)
	var lib := FakeLib2.new()
	lib._caller = iface
	h._lib = lib
	var a := FakeNoteCard.new()
	var b := FakeNoteCard.new()
	iface.taskList.add_child(a)
	iface.taskList.add_child(b)
	iface.inputTarget = a

	h._on_tasks_startinput(a)
	ck(h.drawn.size() == 1, "StartInput рисует одну карточку, а не весь список")
	if h.drawn.size() == 1:
		ck(h.drawn[0] == a, "рисуется именно карточка-цель")

	iface.free()
	h.queue_free()

# П2: Traders.tres - файл на диске, а _traders() его грузит. Полный проход
# списка читал его на каждую карточку; теперь один раз и отдаёт дальше.
class TradersSpy extends TestHooks:
	var calls := 0
	var traders_obj = null
	var seen: Array = []

	func _traders(force_reload: bool = false) -> Variant:
		calls += 1
		return traders_obj

	# GC леджера читает тот же файл; к этому тесту его чтения отношения не
	# имеют, поэтому заглушено.
	func _gc_ledger_once() -> void:
		pass

	func _render_task_card(_iface, card, traders = null) -> void:
		seen.append(traders)

func t_traders_read_once_per_pass() -> void:
	var h := TradersSpy.new()
	root.add_child(h)
	var iface := TaskIface.new()
	root.add_child(iface)
	iface.taskList = GridContainer.new()
	iface.add_child(iface.taskList)
	for i in range(3):
		iface.taskList.add_child(FakeNoteCard.new())
	var lib := FakeLib2.new()
	lib._caller = iface
	h._lib = lib
	var save := Resource.new()
	save.set_meta("vtk_deposits", {"res://Task.tres": {0: 1}})
	h.traders_obj = save

	h._on_tasks_rendered()
	ck(h.calls == 1, "Traders.tres читается один раз на проход, а не на карточку")
	ck(h.seen.size() == 3, "проход рисует все живые карточки")
	if h.seen.size() == 3:
		ck(h.seen[0] == save and h.seen[2] == save, "в карточки передан тот же ресурс")

	h.calls = 0
	h.seen.clear()
	h._on_tasks_rendered()
	ck(h.calls == 1, "повторный проход тоже читает файл один раз")

	iface.free()
	h.queue_free()

func t_ledger_from_resource() -> void:
	var h := TestHooks.new()
	root.add_child(h)
	ck(h._ledger_from(null).is_empty(), "нет TraderSave -> пустой леджер")
	var save := Resource.new()
	save.set_meta("vtk_deposits", {"k": {0: 2}})
	ck(int(h._ledger_from(save)["k"][0]) == 2, "леджер берётся из переданного ресурса")
	save.set_meta("vtk_deposits", "broken")
	ck(h._ledger_from(save).is_empty(), "не-словарь в мете -> пустой леджер")
	h.queue_free()

# П3: ключи леджера не появляются и не исчезают в течение сессии (только с
# апдейтом игры), а _resource_exists - обращение к ФС. Проверяем один раз.
class GcSpy extends TestHooks:
	var ledger_data: Dictionary = {}
	var writes := 0

	func _ledger() -> Dictionary:
		return ledger_data

	func _ledger_set(_data: Dictionary) -> bool:
		writes += 1
		return true

	func _resource_exists(_path: String) -> bool:
		return false

func t_gc_ledger_once() -> void:
	var h := GcSpy.new()
	root.add_child(h)
	h._gc_ledger_once()
	ck(h.writes == 0, "пустой леджер: GC ничего не пишет")
	ck(not h._gc_done, "пустой леджер не защёлкивает GC")

	h.ledger_data = {"res://Gone.tres": {0: 1}}
	h._gc_ledger_once()
	ck(h.writes == 1, "первый проход чистит ключ несуществующего ресурса")
	ck(h._gc_done, "проход отмечен")

	h.ledger_data = {"res://Gone2.tres": {0: 1}}
	h._gc_ledger_once()
	ck(h.writes == 1, "повторный проход уже не проверяет ключи")

	h.queue_free()

func t_kill_counter_birth_in_disabled() -> void:
	var Feed = preload("res://mods/VTK/VTKFeed.gd")
	var block = Feed.new()
	root.add_child(block)
	ck(not block.is_processing(), "rozhdyonnyy vyklyuchennyy ne krutit _process")
	block.configure(false, false, false)
	ck(not block.is_processing(), "vyklyuchennyy blok ne krutit _process")

	var probe = Node.new()
	root.add_child(probe)
	ck(block._pending.is_empty(), "vyklyuchennyy blok ne kopit uzly")

	block.configure(true, true, true)
	ck(block.is_processing(), "vklyuchennyy blok snova obrabatyvaetsya")
	ck(block._pending.is_empty(), "vklyuchenie ne ostavlyaet musora")

	var probe2 = Node.new()
	root.add_child(probe2)
	ck(block._pending.size() == 1, "vklyuchennyy blok kopit fiktivnyy uzel")

	probe.free()
	probe2.free()
	block.free()

# Ник игрока живёт в записи о ране, рядом с именем AI-убийцы: лента остаётся
# самодостаточным снимком и ничего не знает о конфиге.
func t_player_name() -> void:
	var evs: Array = []
	var h = TestHooks.new()
	root.add_child(h)
	h.connect("kill_event", func(ev: Dictionary) -> void: evs.append(ev))
	h._lib = FakeLib2.new()
	var player := FakeAgent2.new()
	player.add_to_group("Player")
	root.add_child(player)

	var v1 := FakeAgent2.new()
	v1.name = "AI_Bandit"
	v1.variant.faction = 1
	root.add_child(v1)
	h.set_player_name("Vasya")
	h._lib._caller = v1
	h._on_ai_weapon_damage("Chest", 10.0, Vector3.ZERO, player)
	_die_native(h, h._lib, v1, false, 120.0)

	var v2 := FakeAgent2.new()
	v2.name = "AI_Bandit"
	v2.variant.faction = 1
	root.add_child(v2)
	h._lib._caller = v2
	h._on_ai_explosion(Vector3.ZERO, player)
	_die_native(h, h._lib, v2, true)

	var v3 := FakeAgent2.new()
	v3.name = "AI_Bandit"
	v3.variant.faction = 1
	root.add_child(v3)
	h.set_player_name("   ")
	h._lib._caller = v3
	h._on_ai_weapon_damage("Chest", 10.0, Vector3.ZERO, player)
	_die_native(h, h._lib, v3, false, 120.0)

	ck(evs.size() == 3, "три события игрока")
	if evs.size() == 3:
		ck(str(evs[0]["killer_name"]) == "Vasya", "ник в оружейном килле")
		ck(str(evs[1]["killer_name"]) == "Vasya" and bool(evs[1]["grenade"]), "ник в гранатном килле")
		ck(str(evs[2]["killer_name"]) == "Player", "пустой ник -> Player")

	v1.free()
	v2.free()
	v3.free()
	player.free()
	h.queue_free()
