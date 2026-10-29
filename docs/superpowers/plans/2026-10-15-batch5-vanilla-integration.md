# Ванила-интеграция батча 5 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Перевести стыковку мода с ванилой (Kill, Deposits, Travel, Death+Restart) с хрупких эвристик на ванильные события/поля, не меняя видимое игроку поведение.

**Architecture:** Четыре независимых среза, каждый выпускается патчем (4.17.4→4.17.7) и проверяется в игре отдельно. Срез 1 (Kill) первым — он изолирован. Атрибуция киллов переезжает на `AI.variant` (`@export` поле агента). Travel получает хук `compiler-spawn-post` (ванильный `Compiler.Spawn()` — точный момент готовности карты) вместо кадровых гвардов. Death+Restart переходит на сигнал `SceneTree.scene_changed`. Deposits завершает задачу через `Interface.Complete`.

**Tech Stack:** GDScript (Godot 4.6.3), modloader `RTVModLib`, headless-тесты в `.check/project/tests/`, стенды `.check/layout_check.py` и `.check/check.ps1`.

## Global Constraints

- Отступы в `.gd` — **только табы**; кодировка UTF-8.
- **Никаких видимых игроку изменений** поведения; ни новых MCM-настроек.
- Версия поднимается **до** сборки: `loadouts/mod.txt` (`version`), `loadouts/mods/VTK/version.txt`, `README.md`, `CHANGELOG.md`. Формат `Глобальное.Фича.Фикс`.
- Порядок сборки: `py -3 .check\layout_check.py` → `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1` → bump version → `powershell -ExecutionPolicy Bypass -File pack.ps1` → копия `.vmz` в `D:\SteamLibrary\steamapps\common\Road to Vostok\mods`.
- Зелёный `check.ps1` = exit 0 **и** нет строк `SCRIPT ERROR` / `Parse Error` / `Invalid call` / `Failed to load script` **и** есть `tests passed`.
- **Не трогать** `standalone mods/ThermalVTK/` (параллельная сессия).
- `.check/` **вне git** (`.gitignore` строка `/*` игнорирует весь корень; ни один тест никогда не трекался): тесты правим на диске, но **не коммитим** — `git add` без `.check/...`. В коммит идут только `loadouts/mods/VTK/*.gd` и релизные файлы.
- Арность post-хуков: void-метод игры → колбэк ровно `args.size()` аргументов; не-void → `args.size()+1`. Обновлять `test_hooks.gd::t_post_callback_arity`.
- `docs/` — локальная папка (gitignored), спеки/планы не коммитим.
- Поведение боссов (Punisher/Bogeyman = `Boss`-фракция) в батче **не меняется**: не считаются.

---

## File Structure

| Файл | Роль | Срез |
|---|---|---|
| `loadouts/mods/VTK/VTKLog.gd` | +`warn_once` (V11, fail-closed) | 1 |
| `loadouts/mods/VTK/VTKKillCounter.gd` | `_is_agent`/`agent_kind`/`agent_display_name` через `variant` | 1 |
| `loadouts/mods/VTK/VTKHooks.gd` | `_weapon_name_of` (weaponData), Travel-хук, Death-детект, restart | 1/3/4 |
| `.check/project/tests/test_feed.gd` | фейки под `variant` | 1 |
| `.check/project/tests/test_hooks.gd` | фейки AI под `variant`, restart/deposit/arity | 1/2/3/4 |
| `loadouts/mods/VTK/VTKTravel.gd` | прибытие по событию `Compiler.Spawn`, −гварды | 3 |
| `CHANGELOG.md`, `loadouts/mod.txt`, `version.txt`, `README.md` | версии 4.17.4-4.17.7 | 1-4 |

---

## Срез 1 — Kill (V6 + V11) → 4.17.4

### Task 1: V11 fail-closed helper

**Files:**
- Modify: `loadouts/mods/VTK/VTKLog.gd`
- Test: `.check/project/tests/test_feed.gd`

**Interfaces:**
- Produces: `VTKLog.warn_once(path: String, msg: String = "") -> void` — статический, пишет в `print` один раз на `path` (и только при `enabled`). Дальше молчит.

- [ ] **Step 1: Написать падающий тест**

В `.check/project/tests/test_feed.gd` добавить в `_run()` вызов `t_log_warn_once()` и функцию:

```gdscript
func t_log_warn_once() -> void:
	var Log = preload("res://mods/VTK/VTKLog.gd")
	Log._warned.clear()
	Log.warn_once("/root/Nope", "missing A")
	Log.warn_once("/root/Nope", "missing A")
	Log.warn_once("/root/Other", "missing B")
	ck(Log._warned.size() == 2, "warn_once: один след на путь, повтор не плодит")
	ck(Log._warned.has("/root/Nope") and Log._warned.has("/root/Other"), "warn_once: оба пути помечены")
```

- [ ] **Step 2: Прогнать — убедиться, что падает**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: FAIL — `Invalid call. Nonexistent function 'warn_once'` в test_feed.

- [ ] **Step 3: Реализовать**

`VTKLog.gd`:

```gdscript
extends RefCounted
## Единая точка отладочного вывода мода.
## По умолчанию выключена: print() в релизе - это шум в консоли и логе игры,
## а также утечка внутренних путей. Включается галочкой "Debug log" в MCM.

static var enabled := false
static var _warned: Dictionary = {}

static func log(msg) -> void:
	if enabled:
		print(msg)

## Единый fail-closed резолв привязок внутрь игры: о промахе сообщаем один
## раз на путь (V11), чтобы обновление игры не превращалось в молчание.
static func warn_once(path: String, msg: String = "") -> void:
	if _warned.has(path):
		return
	_warned[path] = true
	if enabled:
		print("[VTK][WARN] " + (msg if msg != "" else ("missing: " + path)))
```

- [ ] **Step 4: Прогнать — зелёный**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: PASS, `tests passed`.

- [ ] **Step 5: Commit**

```bash
git add loadouts/mods/VTK/VTKLog.gd
git commit -m "feat(vtk): add fail-closed warn_once helper (V11)"
```

### Task 2: Атрибуция киллов через `AI.variant`

**Files:**
- Modify: `loadouts/mods/VTK/VTKKillCounter.gd:79-170`
- Modify: `loadouts/mods/VTK/VTKHooks.gd:778-784`
- Test: `.check/project/tests/test_feed.gd`, `.check/project/tests/test_hooks.gd`

**Interfaces:**
- Consumes: `warn_once` (Task 1).
- Produces: `VTKKillCounter._is_agent(n) -> bool` (теперь `n is Node3D and "variant" in n`); `agent_kind(n) -> String` (по `variant.faction`: `0→"nomad"`, `4→""`, иначе `"enemy"`); `agent_display_name(n) -> String` (по `variant.name`).

**Ванильные ориентиры (проверено):** `AI.gd:20 @export var identifier: Node3D`, `AI.gd:60 var variant: AIData`, `AI.gd:66 var weaponData: WeaponData`, `AI.gd:1178 hitCollider.ApplyDamage(..., identifier)`. `AIData.Faction` (headless probe): `Nomad:0, Bandit:1, Guard:2, Military:3, Boss:4`. `variant.name` у ресурсов: `Bandit/Nomad/Guard/Military/Punisher/Bogeyman` (Punisher и Bogeyman — `faction=4`).

- [ ] **Step 1: Обновить фейки и написать тесты под `variant`**

В `.check/project/tests/test_feed.gd` заменить класс `FakeAgent` на:

```gdscript
class FakeVariant extends RefCounted:
	var faction := 0
	var name := "Bandit"

class FakeAgent extends Node3D:
	var dead := false
	var active := true
	var variant = FakeVariant.new()

	func Activate() -> void:
		pass
```

В `t_agent_kind()` задавать фракцию явно (`n.variant.faction = 1`/`0`/`2`/`4`) вместо переименований; проверки те же (`enemy`/`nomad`/`enemy`/`""`). Узел без `variant` (обычный `Node3D`) → `""`.

В `t_agent_display_name()` задавать `n.variant.name` ("Bandit"/"Nomad"/"Punisher") вместо `n.name`/`n.boss`/ребёнка-модели; `null → "NPC"`.

`t_clean_ai_name()` **удалить** вместе с её вызовом и телом (функция `clean_ai_name` удаляется — имя теперь из `variant.name`).

В `.check/project/tests/test_hooks.gd` класс `FakeAgent2` дополнить полем `var variant = FakeVariant.new()`, и рядом добавить тот же `class FakeVariant` (если ещё не определён в файле). В `t_kill_event`/`t_marker_attacker`/`t_explosion_kill` выставлять `variant` у врагов:

```gdscript
# жертва Bandit:
victim.variant.faction = 1
victim.variant.name = "Bandit"
# номад-маркер:
nomad.variant.faction = 0
nomad.variant.name = "Nomad"
```

Проверки в `t_marker_attacker` сохранить: `killer_kind == "nomad"`, `killer_name == "Nomad"`, `victim_kind == "enemy"`, `weapon == "AKS-74U"`.

- [ ] **Step 2: Прогнать — убедиться, что падает**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: FAIL — `agent_kind` по-прежнему читает имена; фейки с `variant` не влияют.

- [ ] **Step 3: Переписать `VTKKillCounter.gd`**

Заменить блок `:79-170` (константы `SCRIPT_NOMAD`/`SCRIPTS_ENEMY`/`MODEL_NAMES`, `_is_agent`, `agent_kind`, `clean_ai_name`, `agent_display_name`, `_identities`) на:

```gdscript
# Игровой агент AI.gd несёт @export identifier+var variant: AIData (AI.gd:20/60),
# а не только Activate/dead. variant - устойчивый маркер агента и источник
# фракции/имени, в отличие от duck-typing по методам и разбора имён узлов.
static func _is_agent(n: Node) -> bool:
	return n is Node3D and "variant" in n

# AIData.Faction (headless probe): Nomad 0, Bandit 1, Guard 2, Military 3, Boss 4.
const FACTION_NOMAD := 0
const FACTION_BOSS := 4

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

static func agent_display_name(n: Node) -> String:
	if n == null or not is_instance_valid(n):
		return "NPC"
	var v = n.get("variant")
	if v != null:
		var vn := str(v.get("name")).strip_edges()
		if vn != "":
			return vn
	return "NPC"
```

- [ ] **Step 4: `_weapon_name_of` — сначала ванильное поле, потом запасной список**

`VTKHooks.gd:778-784`:

```gdscript
func _weapon_name_of(n: Node) -> String:
	# AI.gd:66 weaponData: WeaponData; имя ствола - weaponData.name.
	if n != null and is_instance_valid(n) and "weaponData" in n:
		var wd = n.get("weaponData")
		if wd != null and "name" in wd:
			var s := str(wd.get("name")).strip_edges()
			if s != "":
				return s
	for p in ["currentWeaponName", "weaponName", "currentWeapon", "weapon", "equippedWeapon", "activeWeapon"]:
		if p in n:
			var s2 := _weapon_str(n.get(p))
			if s2 != "":
				return s2
	return ""
```

- [ ] **Step 5: Прогнать — зелёный**

Run: `py -3 .check\layout_check.py` → exit 0.
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1` → `tests passed`.

- [ ] **Step 6: Commit**

```bash
git add loadouts/mods/VTK/VTKKillCounter.gd loadouts/mods/VTK/VTKHooks.gd
git commit -m "refactor(vtk): attribute kills from AI.variant instead of name archaeology (V6)"
```

### Task 3: Release 4.17.4

**Files:** `CHANGELOG.md`, `loadouts/mod.txt`, `loadouts/mods/VTK/version.txt`, `README.md`

- [ ] **Step 1: CHANGELOG** — добавить вверху:

```markdown
## [4.17.4] - 2026-10-15

### Fixed
- Kill attribution is more reliable for unusual weapon and explosion kills.
```

- [ ] **Step 2: Версии** — `loadouts/mod.txt` `version="4.17.4"`; `loadouts/mods/VTK/version.txt` → `4.17.4`; `README.md` — действующая версия → `4.17.4`.

- [ ] **Step 3: Стенды**

Run: `py -3 .check\layout_check.py` → exit 0.
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1` → `tests passed`.

- [ ] **Step 4: Собрать**

Run: `powershell -ExecutionPolicy Bypass -File pack.ps1`
Expected: печатает `4.17.4`, создаёт `Loadouts.vmz`.

- [ ] **Step 5: Установить**

```powershell
Copy-Item -LiteralPath "Loadouts.vmz" -Destination "D:\SteamLibrary\steamapps\common\Road to Vostok\mods\Loadouts.vmz" -Force
```

- [ ] **Step 6: Commit**

```bash
git add CHANGELOG.md loadouts/mod.txt loadouts/mods/VTK/version.txt README.md
git commit -m "release: 4.17.4"
```

- [ ] **Step 7: Ручная проверка в игре (человек)** — убить Nomad/Bandit/Guard/Military (счётчик растёт, лента верна), хедшот, граната, ИИ-об-ИИ не считается, босс (Punisher/Bogeyman) не считается. Только после успеха — Срез 2.

---

## Срез 2 — Deposits (V3) → 4.17.5

### Task 4: Завершение задачи через `Interface.Complete`

**Files:**
- Modify: `loadouts/mods/VTK/VTKHooks.gd:1239-1267` (`_on_task_complete_pressed`)
- Test: `.check/project/tests/test_hooks.gd`

**Interfaces:**
- Consumes: `VTKDeposits.apply/coverage/is_covered` (без изменений), `_card_covered` (без изменений).
- Produces: `_on_task_complete_pressed()` завершает покрытую задачу ванильным `Interface.Complete(taskData)` (после `StartInput(card)`), без ручных `inputTarget`/`isInputting`/`GetOutputItems`/`ResetInput` и без повторного `CompleteTask`/`UpdateTraderInfo`.

**Ванильные ориентиры (проверено):** `Task.gd:149 _on_complete_pressed` = `Completed(); interface.Complete(taskData)`. `Interface.gd:1460 Complete(data)` = `trader.CompleteTask(inputTarget.taskData)` + `UpdateTraderInfo()` + `DestroyInputItems(data)` + `GetOutputItems()` + `ResetInput()`. `Interface.gd:1416 StartInput(target)` ставит `inputTarget=target`. `CanComplete`/`AddInputItem` уже используются в рендере.

**Примечание по спеке:** пометку ячеек оставляем собственной (`_paint_cell` рисует ✓-бейдж, которого у ванильного `AddInputItem` нет); частичный вклад не отображается на целые ячейки `inputGrid`. Поэтому V3 реализуется **только** через ванильный путь завершения.

- [ ] **Step 1: Проверить существующий тест завершения**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: зелёный до правок (baseline). Тесты `_on_task_complete_pressed` сейчас покрывают только арность/наличие, логику завершения — в игре.

- [ ] **Step 2: Переписать `_on_task_complete_pressed`**

```gdscript
func _on_task_complete_pressed() -> void:
	var card = _lib._caller if _lib else null
	if card == null or not is_instance_valid(card) or not _card_covered(card):
		return
	var iface = card.get("interface")
	if iface == null or not is_instance_valid(iface):
		return
	var task_data = card.get("taskData")
	if task_data == null:
		return
	# Ванильный путь завершения задачи: StartInput ставит inputTarget=card,
	# Complete сам делает CompleteTask/UpdateTraderInfo/DestroyInputItems/
	# GetOutputItems/ResetInput. Вклад уже списал предметы, поэтому удалять
	# нечего и повторного CompleteTask нет.
	if iface.has_method("StartInput"):
		iface.call("StartInput", card)
	if card.has_method("Completed"):
		card.Completed()
	if iface.has_method("Complete"):
		iface.call("Complete", task_data)
	if _lib != null:
		_lib.skip_super()
	_render_task_card(iface, card)
```

- [ ] **Step 3: Прогнать — зелёный**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1` → `tests passed`.

- [ ] **Step 4: Commit**

```bash
git add loadouts/mods/VTK/VTKHooks.gd
git commit -m "refactor(vtk): complete tasks via vanilla Interface.Complete (V3)"
```

### Task 5: Release 4.17.5

- [ ] **Step 1: CHANGELOG** — вверху:

```markdown
## [4.17.5] - 2026-10-15

### Fixed
- Depositing items into a task is more robust and no longer interferes with the vanilla task flow.
```

- [ ] **Step 2: Версии** — `mod.txt`/`version.txt`/`README.md` → `4.17.5`.

- [ ] **Step 3: Стенды** — `py -3 .check\layout_check.py` → 0; `check.ps1` → `tests passed`.

- [ ] **Step 4: Сборка** — `powershell -ExecutionPolicy Bypass -File pack.ps1` (печатает `4.17.5`); скопировать `.vmz` в папку модов.

- [ ] **Step 5: Commit**

```bash
git add CHANGELOG.md loadouts/mod.txt loadouts/mods/VTK/version.txt README.md
git commit -m "release: 4.17.5"
```

- [ ] **Step 6: Ручная проверка в игре (человек)** — частичный и полный стек; Доктор (нестакающиеся) и Generalist; награды выдаются; Notes обновляется на месте; прогресс сходится с Tasks. После успеха — Срез 3.

---

## Срез 3 — Travel (V1, V9, V12, V13) → 4.17.6

### Task 6: Прибытие по событию `Compiler.Spawn`, −кадровые гварды

**Files:**
- Modify: `loadouts/mods/VTK/VTKTravel.gd` (`_teleport_internal`, `_wait_scene_change`, `_await_map_ready`, `_close_interfaces`, константы)
- Modify: `loadouts/mods/VTK/VTKHooks.gd` (`_do_register` + обработчик прибытия)
- Test: `.check/project/tests/test_hooks.gd`

**Interfaces:**
- Produces: `VTKHooks` регистрирует `_lib.hook("compiler-spawn-post", _on_compiler_spawn)`; **сигнал** `VTKHooks.travel_arrived` (`signal travel_arrived()`), который эмитится из `_on_compiler_spawn`. `VTKTravel` ждёт `VTKHooks.travel_arrived`.
- Vanilla: `Compiler.gd:59 func Spawn()` — void (колбэк `compiler-spawn-post` получает 0 аргументов).

**Ванильные ориентиры:** `Compiler._ready` ставит `isCaching=true`; `_physics_process:47` снимает и зовёт `Spawn()`; `Spawn():205-220` ставит контроллер по `previousMap`+группе `Transition` и снимает `isTransitioning/isOccupied/freeze`. `SceneTree.scene_changed` — сигнал смены сцены.

- [ ] **Step 1: Добавить ожидание по событию в `VTKHooks`**

В `VTKHooks.gd` рядом с `signal kill_event`:

```gdscript
signal travel_arrived
```

В `_do_register()` (после `_lib.hook("loader-newgame-post", _on_newgame_post)`):

```gdscript
	_lib.hook("compiler-spawn-post", _on_compiler_spawn)
```

И обработчик:

```gdscript
# Compiler.Spawn() - точный момент готовности карты: контроллер уже расставлен
# ванилой (Compiler.gd:205-220). Телепорт ждёт именно это, а не крутит кадры.
func _on_compiler_spawn() -> void:
	travel_arrived.emit()
```

Обновить лог-счётчик хуков в конце `_do_register` (`:205`): `+ 1)` → `+ 2)` — `compiler-spawn-post` не хранится в массиве, как и `controller-_physics_process-post`, поэтому к сумме массивов прибавляется ещё один.

- [ ] **Step 2: Добавить обновление арности в тест**

В `.check/project/tests/test_hooks.gd` в словарь `expected` функции `t_post_callback_arity` добавить:

```gdscript
		"_on_compiler_spawn": 0,
```

(если словарь хранит имена колбэков → число ожидаемых аргументов).

- [ ] **Step 3: Переписать ожидание прибытия в `VTKTravel.gd`**

`SCENE_WAIT_FRAMES`/`_wait_scene_change`/`_await_map_ready` оставить на месте (`SCENE_WAIT_FRAMES` — страховочный предел на смену сцены, `_await_map_ready` — фолбек). Захардкоженный таймер 0.35 c и опрос `isCaching` больше не основной путь: заменить хвост `_teleport_internal` (от `var prev_id` до `if loader.has_method("SaveWorld")`) на ожидание сигнала `travel_arrived` из `VTKHooks` (эмитится на `compiler-spawn-post`), подключаясь к сигналу ДО `LoadScene`, чтобы не пропустить эмит:

```gdscript
func _teleport_internal(target_map: String, final_offset: Variant, dest_label: String = "") -> void:
	if _busy:
		_message(Loc.txt("Teleport already in progress"), Color.YELLOW)
		return
	if game_data != null and bool(game_data.get("tutorial")):
		_message(Loc.txt("Teleport unavailable in the tutorial"), Color.RED)
		return
	var loader := _loader()
	if loader == null or not loader.has_method("LoadScene"):
		_message(Loc.txt("Scene loader not found"), Color.RED)
		return
	_has_look_at = false
	_busy = true
	var actual_current := _current_map_name()
	_close_interfaces()
	_save_before_transition(target_map, loader)
	if game_data != null:
		if bool(game_data.get("shelter")) and loader.has_method("SaveShelter"):
			loader.SaveShelter(actual_current)
		game_data.set("previousMap", actual_current)
		game_data.set("currentMap", target_map)
	var prev_id := 0
	var scene := get_tree().current_scene
	if scene != null:
		prev_id = scene.get_instance_id()
	var hooks := _hooks()
	var wait_hook := hooks != null and hooks.has_signal("travel_arrived")
	var arrived_flag := [false]
	var cb := func(): arrived_flag[0] = true
	if wait_hook:
		hooks.connect("travel_arrived", cb)
	loader.LoadScene(target_map)
	if not await _wait_scene_change(prev_id):
		if wait_hook:
			hooks.disconnect("travel_arrived", cb)
		_busy = false
		_message(Loc.txt("Scene failed to load: ") + target_map, Color.RED)
		return
	var arrived := true
	if wait_hook:
		var guard := 0
		while not arrived_flag[0] and guard < SCENE_WAIT_FRAMES:
			await get_tree().process_frame
			guard += 1
		hooks.disconnect("travel_arrived", cb)
		if arrived_flag[0]:
			arrived = is_inside_tree()
		else:
			arrived = await _await_map_ready()
	else:
		arrived = await _await_map_ready()
	if not arrived:
		_busy = false
		var label0 := dest_label if dest_label == "" else " (" + dest_label + ")"
		_message(Loc.txt("Map ") + target_map + Loc.txt(" failed to load") + label0, Color.RED)
		return
	if loader.has_method("SaveWorld"):
		loader.SaveWorld()
	var point: Variant = _resolve_final_offset(final_offset)
	if point is Vector3:
		_place_player(point)
	elif final_offset is Callable:
		_busy = false
		_message(Loc.txt("Trader not found: ") + dest_label + Loc.txt(" (you are on ") + target_map + ")", Color.RED)
		return
	_busy = false
	var dest := target_map if dest_label == "" else target_map + " (" + dest_label + ")"
	_message(Loc.txt("Teleport: ") + dest, Color.GREEN)


func _hooks() -> Node:
	var ui := get_node_or_null("/root/VTKUI")
	if ui != null:
		return ui.get_node_or_null("VTKHooks")
	return null
```

> Путь подтверждён: `VTKFeed.gd:85` и `VTKKillCounter.gd:137-139` ищут ровно `/root/VTKUI` → `get_node_or_null("VTKHooks")`. `_await_arrival` из плана убран — ожидание сигнала инлайнится прямо в `_teleport_internal` (флаг `arrived_flag` + `while`).

- [ ] **Step 4: Убрать избыточную запись `isOccupied`**

В `_close_interfaces()` заменить хвост:

```gdscript
	if game_data != null:
		game_data.set("interface", false)
		game_data.set("isOccupied", false)
```

на:

```gdscript
	if game_data != null:
		game_data.set("interface", false)
```

Почему только `isOccupied`: ванильный `Compiler.Spawn()` сам делает `gameData.isOccupied = false` (`Compiler.gd:219`), так что прямая запись мода здесь избыточна. Запись `game_data.set("interface", false)` **оставляем** — `Interface.Close()` её НЕ сбрасывает (`Interface.Close()` `:454` → `Reset()` `:3351` трогают `isCrafting`/`isInputting`, но не `gameData.interface`); флаг `gameData.interface` снимает только `UIManager.Return()` (`UIManager.gd:64-68`), а мод вызывает `Interface.Close()` напрямую (ветка `if iface.has_method("Close")`). Убрав эту запись, мы бы оставили `interface=true` после телепорта с открытым инвентарём и заморозили игрока.

- [ ] **Step 5: Прогнать стенды**

Run: `py -3 .check\layout_check.py` → exit 0.
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1` → `tests passed`.

- [ ] **Step 6: Commit**

```bash
git add loadouts/mods/VTK/VTKTravel.gd loadouts/mods/VTK/VTKHooks.gd
git commit -m "refactor(vtk): travel waits for vanilla Compiler.Spawn instead of frame guards (V1)"
```

### Task 7: Release 4.17.6

- [ ] **Step 1: CHANGELOG** — вверху:

```markdown
## [4.17.6] - 2026-10-15

### Fixed
- Map travel and shelter teleport are more reliable across scene changes.
```

- [ ] **Step 2: Версии** → `4.17.6`.
- [ ] **Step 3: Стенды** — оба зелёные.
- [ ] **Step 4: Сборка** — `pack.ps1`; копия `.vmz`.
- [ ] **Step 5: Commit** — `release: 4.17.6`.
- [ ] **Step 6: Ручная проверка в игре (человек)** — карта, убежище (off/on), три трейдера, туда/обратно, нет зависания «Teleport in progress». После успеха — Срез 4.

---

## Срез 4 — Death+Restart (V2, V10, V8, V9, V12, V13) → 4.17.7

### Task 8: Детект смерти по смене сцены, типизированный GameData, чистка рестарта

**Files:**
- Modify: `loadouts/mods/VTK/VTKHooks.gd` (`_resolve_gamedata:108-121`, `_poll_death:123-155`, `_on_restart_pressed:1406-1443`, `_wipe_saves_for_restart:1380-1403`; `_ready`)
- Test: `.check/project/tests/test_hooks.gd:260-307`

**Interfaces:**
- Produces: `_resolve_gamedata() -> Variant` (только типизированный `load`); `_death_scene_present()` берётся из факта смены сцены на `Death` (сигнал `scene_changed`); `_wipe_saves_for_restart` удалён.

**Ванильные ориентиры:** смерть → `Character.gd:370 Loader.LoadScene("Death")`, сцена `Death` становится `current_scene`. `Loader.LoadScene` выставляет `shelter`/`permadeath` по имени сцены (`Loader.gd:252-361`).

- [ ] **Step 1: Типизированный GameData (V8)**

Заменить `_resolve_gamedata` (`:108-121`):

```gdscript
func _resolve_gamedata() -> Variant:
	if _gd_node != null and is_instance_valid(_gd_node):
		return _gd_node
	if ResourceLoader.exists(GAME_DATA_RES):
		var direct = load(GAME_DATA_RES)
		if direct != null:
			_gd_node = direct
	return _gd_node
```

Строку `_gd_missing_logged` и её лог в `_poll_death` можно оставить.

- [ ] **Step 2: Детект сцены `Death` по сигналу**

В `_ready()` добавить:

```gdscript
	get_tree().scene_changed.connect(_on_scene_changed)
```

Рядом добавить поле и обработчик; `_death_scene_present` заменить на чтение флага:

```gdscript
var _death_scene_flag: bool = false

func _on_scene_changed() -> void:
	var cs := get_tree().current_scene
	_death_scene_flag = cs != null and cs.name == "Death"

func _death_scene_present() -> bool:
	return _death_scene_flag
```

(удалить `DEATH_SCENE_POLL_MS`, `_death_scene_at`, `_death_scene_hit`).

- [ ] **Step 3: Убрать мёртвый wipe (V10a)**

Удалить функцию `_wipe_saves_for_restart` (`:1380-1403`) и ветку `else: _wipe_saves_for_restart()` в `_on_restart_pressed`; вызов `ldr.call("NewGame", ...)` сделать безусловным:

```gdscript
	ldr.call("NewGame", difficulty, _resolve_start_season())
	ldr.LoadScene(start_map)
```

- [ ] **Step 4: Убрать избыточные записи (V10b)**

В `_on_restart_pressed` удалить строки, которые уже выставляет `LoadScene`:

```gdscript
		gd.set("shelter", false)
		gd.set("permadeath", true)
```
и
```gdscript
		gd.set("shelter", true)
		gd.set("permadeath", false)
```

Оставить `gd.set("isDead", false)`, `gd.set("previousMap", "")`, выбор `start_map`, `gd.set("difficulty", 3)` в ironman-ветке (проверка в игре подтвердит, нужна ли она — см. Step 6).

- [ ] **Step 5: Обновить тесты рестарта**

В `.check/project/tests/test_hooks.gd`:
- `t_ironman_restart_restores_difficulty` (`:260-292`): убрать проверки `gd.permadeath` (`:284`) и `gd.shelter` (`:288`) — их выставляет `LoadScene`, а не мод. Оставить `new_game_called`, `new_game_difficulty == 3`, `new_game_season == 2`, `not h.wiped`, `gd.isDead == false`, `gd.difficulty == 3`.
- Удалить фолбек-кейс (`:294-304`) и класс `FakeLoaderNoNew` (он больше не создаётся): рестарт без `Loader.NewGame` невозможен.

- [ ] **Step 6: Прогнать стенды**

Run: `py -3 .check\layout_check.py` → exit 0.
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1` → `tests passed`.

- [ ] **Step 7: Commit**

```bash
git add loadouts/mods/VTK/VTKHooks.gd
git commit -m "refactor(vtk): event-driven death detection and typed GameData (V2/V8/V10)"
```

### Task 9: Release 4.17.7

- [ ] **Step 1: CHANGELOG** — вверху:

```markdown
## [4.17.7] - 2026-10-15

### Fixed
- The death screen and restart are more reliable, especially in ironman.
```

- [ ] **Step 2: Версии** → `4.17.7`.
- [ ] **Step 3: Стенды** — оба зелёные.
- [ ] **Step 4: Сборка** — `pack.ps1`; копия `.vmz`.
- [ ] **Step 5: Commit** — `release: 4.17.7`.
- [ ] **Step 6: Ручная проверка в игре (человек)** — обычная смерть → Restart → новая игра; ironman-смерть (Apartments/Terminal/Airfield) → Restart в случайной ironman-карте, permadeath сохраняется; не-ironman продолжение не ломается; `SaveWorld`/`SaveShelter` после рестарта корректны. Если `difficulty=3` оказалась нужна — вернуть, это не видимое изменение, а корректность.

---

## Self-Review

**1. Покрытие спека:**
- V6 (Kill) → Task 2. V11 → Task 1. ✔
- V3 (Deposits) → Task 4 (сужено до ванильного завершения; пометка ячеек оставлена — обосновано в Task 4). ✔
- V1/V9/V12/V13-travel (Travel) → Task 6. ✔
- V2/V8/V10/V9/V12/V13-death (Death+Restart) → Task 8. ✔
- Версии/CHANGELOG/сборка → Tasks 3/5/7/9. ✔
- Ручные чек-листы → финальные шаги каждого среза. ✔

**2. Плейсхолдеры:** в Task 6 есть пометка «уточнить путь до VTKHooks» — это описание условия, не placeholder в коде: конкретный путь (`/root/VTKUI` → `VTKHooks`) указан там же. Формулировка `_hooks()` в примере помечена как место правки.

**3. Согласованность имён:** `warn_once(path,msg)`, `travel_arrived` (signal), `_on_compiler_spawn`, `_await_arrival(hooks)`, `Faction` 0/4, `FakeVariant` — используются одинаково во всех задачах.

**4. Открытые probe (закрыты в плане):** enum `AIData.Faction` (0-4), поле имени оружия (`weaponData.name`), `variant.name` — проверены headless. Остаются рантайм-проверки в игре (хук `compiler-spawn-post` на первой загрузке, достаточность `Interface.Close`, нужда в `difficulty=3`).

**5. Расхождение со спеком (исправлено):** V3 в спеке упоминал `Task.AddInputItem` для пометки ячеек — в плане от этого отказано (частичный вклад не ложится на целые ячейки `inputGrid`, а ✓-бейдж — визуал мода). Спек следует поправить тем же проходом.
