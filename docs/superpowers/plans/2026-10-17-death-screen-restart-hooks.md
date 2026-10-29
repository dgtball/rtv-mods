# Экран смерти: рестарт по событийным хукам — план реализации

> **Для агентов-исполнителей:** ОБЯЗАТЕЛЬНЫЙ САБ-СКИЛЛ: используйте
> superpowers:subagent-driven-development (рекомендуется) или
> superpowers:executing-plans для пошагового выполнения. Шаги отмечены
> чекбоксами (`- [ ]`).

**Goal:** заменить пофреймовую машину состояний кнопки рестарта на экране смерти
двумя событийными хуками на `Death.gd`, чтобы рестарт появлялся сразу и не
зависел от чтения флагов GameData, которые ваниль стирает при монтировании
сцены.

**Architecture:** состояние экрана смерти принадлежит ванильной сцене Death,
мод его не хранит. `_lib.hook("death-_ready-post", ...)` переименовывает и
раздизейбливает кнопку `Main/Buttons/Load`, когда виден спрайт
`Main/Permadeath`; `_lib.hook("death-_on_load_pressed", ...)` — replace-слот,
который через `_lib.skip_super()` подавляет ванильную загрузку шелтера и
зовёт существующий `_on_restart_pressed`. Латч, проб-логи, таймаут, поиск
кнопки по тексту и восстановление ванильного состояния удаляются.

**Tech Stack:** GDScript (Godot 4.6.3), modloader RTVModLib (`hook`,
`skip_super`, `_caller`), PowerShell-стенды `.check\check.ps1` и
`.check\layout_check.py`.

Спека: `docs/superpowers/specs/2026-10-17-death-screen-restart-hooks-design.md`.

## Global Constraints

- Godot 4.6.3 (`RTVcopy/RTV.pck`, pack format 3); стенд `.check\check.ps1`
  ищет бинарь в PATH, иначе передаётся `-Godot "<путь к
  Godot_*_console.exe>"` (у нас `D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe`).
- Отступы в `.gd` — только табы. Файлы — UTF-8.
- Новый код — без комментариев (обоснования живут в спеке, не в коде).
- Версия живёт только в `loadouts/mod.txt`, поле `version`.
- Список тестов в `.check\check.ps1` (`$tests`) явный; новых тестовых файлов
  этот план не создаёт, поэтому список не меняется.
- Тесты headless: ни путей внутрь игры, ни `load()` игровых ресурсов; игровые
  объекты — заглушки-классы внутри `test_hooks.gd`.
- Трекаемые git-пути: `loadouts/**` и `CHANGELOG.md`. `docs/` — под
  `.gitignore` (`/*` + allowlist), коммитить её не нужно.
- Стиль коммита: `refactor(vtk): ...`, `fix(vtk): ...`, `release: x.y.z`.

---

### Task 1: Событийные хуки вместо поллинга смерти

**Files:**
- Modify: `loadouts/mods/VTK/VTKHooks.gd` (поля 43-76, `_ready` 82-85,
  `_process` 96-99, `_do_register` после 190, блок 121-153, блок 1286-1389,
  тело `_on_restart_pressed` 1399-1431)
- Modify: `loadouts/mod.txt` (секция `[hooks]`)
- Test: `.check/project/tests/test_hooks.gd` (класс `TestHooks` на строке 14,
  раннер `_run` 307-339, `t_ironman_restart_restores_difficulty` 349-381,
  `FakeLib2` 383-388, `t_death_timeout_gives_up` 658-680)

**Interfaces:**
- Consumes: `Paths.LOADER` (VTKPaths), `IRONMAN_MAPS` и `_resolve_start_season()`
  (остаются в `VTKHooks.gd`), `Log.log` (`VTKLog.gd`, preload на строке 3),
  `VTKData.prop(obj, name, default)` (`VTKData.gd`), `_lib._caller`,
  `_lib.skip_super()`.
- Produces (используется в Task 2 при проверке по логу):
  - `_on_death_ready() -> void` — post-хук `Death._ready`
  - `_on_death_load_pressed() -> void` — replace-хук `Death._on_load_pressed`
  - `_on_restart_pressed(gd, root, ironman: bool) -> void` — новая арность

- [ ] **Step 1: Обновить тесты (красная стадия)**

В `.check/project/tests/test_hooks.gd`:

1a. В `t_ironman_restart_restores_difficulty` (строка 364-367) убрать поле и
добавить третий аргумент — было:

```gdscript
	var h = TestHooks.new()
	h._death_is_ironman = true
	root.add_child(h)
	h._on_restart_pressed(gd, null)
```

стало:

```gdscript
	var h = TestHooks.new()
	root.add_child(h)
	h._on_restart_pressed(gd, null, true)
```

1b. Удалить целиком `t_death_timeout_gives_up` (строки 658-680 вместе с
комментарием 658-660 выше функции — он описывает удалённый таймаут).

1c. Добавить три класса-заглушки и три теста в конец файла, рядом с
`FakeLib2`/`FakeSim` (перед `func _run()`, либо после `t_equip_*` — важно лишь,
чтобы `_run` их видел):

```gdscript
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
```

Поля-ссылки в `FakeDeath` (`pd`/`btn`/`blocker`) нужны, чтобы не читать свойства
через `get_node()` на базовом типе `Node` — это Parse Error
(`AGENTS.md`, «Подвох анализатора Godot 4»). Имена узлов в дереве при этом
остаются ванильными: `Main/Permadeath`, `Main/Buttons/Load`, `Blocker`.

1d. В раннере `_run` (строка 317-318) заменить:

```gdscript
	t_ironman_restart_restores_difficulty()
	t_death_timeout_gives_up()
```

на:

```gdscript
	t_ironman_restart_restores_difficulty()
	t_death_ready_unlocks_restart_for_permadeath()
	t_death_load_pressed_runs_restart()
	t_death_load_pressed_defers_to_vanilla()
```

- [ ] **Step 2: Убедиться, что тесты падают**

Run:
```
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```
Expected: `--- test_hooks.gd ---` с `FAIL`, `Invalid call`, либо
`VERDICT: FAIL test_hooks.gd` — методов `_on_death_ready` и
`_on_death_load_pressed` ещё нет, а `_on_restart_pressed` ещё двухарный.

- [ ] **Step 3: Удалить поля и поллинг из `VTKHooks.gd`**

3a. Удалить поле `_death_is_ironman` (строка 43).

3b. Заменить блок 45-76 (комментарий «The death screen ships its own...»,
поля `_death_load_*`, `DEATH_FIND_TIMEOUT_MS`, `_death_find_since`,
`_death_gave_up`, `DEATH_PROBE_MS`, `_death_probe_at`, комментарий про
`_death_scene_flag`, `_death_scene_flag`, комментарий «The death screen was
never handled...», `_death_latched`, `_gd_missing_logged`) на:

```gdscript
var _gd_node = null
```

`_gd_node` остаётся: его читает `_resolve_gamedata()` (109-119), которая нужна
`_on_newgame_post` (220) и `_on_weapon_name`-пути (821).

3c. В `_ready` удалить строку подключения сигнала — было:

```gdscript
func _ready() -> void:
	name = "VTKHooks"
	get_tree().scene_changed.connect(_on_scene_changed)
	Log.log("[VTK] Hooks node ready, RTVModLib=" + str(Engine.has_meta("RTVModLib")))
```

стало:

```gdscript
func _ready() -> void:
	name = "VTKHooks"
	Log.log("[VTK] Hooks node ready, RTVModLib=" + str(Engine.has_meta("RTVModLib")))
```

3d. В `_process` удалить вызов поллинга — было:

```gdscript
func _process(_delta: float) -> void:
	if not _registered:
		_try_register()
	_poll_death()
```

стало:

```gdscript
func _process(_delta: float) -> void:
	if not _registered:
		_try_register()
```

3e. Удалить функцию `_poll_death` целиком (строки 121-153).

- [ ] **Step 4: Зарегистрировать хуки в `_do_register`**

После строки `_lib.hook("compiler-spawn-post", _on_compiler_spawn)` (строка
190) добавить:

```gdscript
	_lib.hook("death-_ready-post", _on_death_ready)
	_lib.hook("death-_on_load_pressed", _on_death_load_pressed)
```

Идентификаторы не складываем в `_hooks_*`: хуки постоянные, как
`controller-_physics_process-post` и `loader-newgame-post`, которые в этом же
списке регистрируются без сохранения id.

- [ ] **Step 5: Заменить блок 1286-1389 на два хука**

Удалить целиком: `_handle_death_screen` (1286), комментарий 1303-1305,
`_death_scene_root` (1324-1331), `_on_scene_changed` (1333-1337),
`_death_scene_present` (1339-1340), `_find_load_button` (1342-1356),
`_repurpose_load_button` (1358-1371), `_restore_load_button` (1373-1389).
Вместо них:

```gdscript
func _on_death_ready() -> void:
	var death = _lib._caller if _lib else null
	if death == null:
		return
	var pd = death.get_node_or_null("Main/Permadeath")
	if pd == null:
		Log.log("[VTK] death: Main/Permadeath not found; leaving vanilla death screen")
		return
	if not pd.visible:
		return
	var btn = death.get_node_or_null("Main/Buttons/Load")
	if btn == null:
		Log.log("[VTK] death: Main/Buttons/Load not found; leaving vanilla death screen")
		return
	btn.text = "Restart"
	btn.disabled = false

func _on_death_load_pressed() -> void:
	var death = _lib._caller if _lib else null
	if death == null:
		return
	var pd = death.get_node_or_null("Main/Permadeath")
	if pd == null:
		Log.log("[VTK] death: Main/Permadeath not found; vanilla Load runs")
		return
	if not pd.visible:
		return
	_lib.skip_super()
	var blocker = death.get_node_or_null("Blocker")
	if blocker != null:
		blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	if death.has_method("PlayClick"):
		death.PlayClick()
	_on_restart_pressed(VTKData.prop(death, "gameData", null), death, true)
```

`_resolve_start_season()` (1391-1397) не трогаем.

- [ ] **Step 6: Заменить тело `_on_restart_pressed` на трёхарный вариант**

Было (1399-1431): сигнатура `(gd, root)`, чистка полей `_death_*` в начале,
обращения к `_death_is_ironman` в теле. Стало:

```gdscript
func _on_restart_pressed(gd, root, ironman: bool) -> void:
	Log.log("[VTK] Restart: starting new game...")
	if gd == null:
		Log.log("[VTK] Restart: no GameData, aborting")
		return
	gd.set("isDead", false)
	gd.set("previousMap", "")
	var start_map = "Cabin"
	if ironman:
		start_map = IRONMAN_MAPS[randi() % IRONMAN_MAPS.size()]
		gd.set("difficulty", 3)
	gd.set("currentMap", start_map)
	var ldr = get_node_or_null(Paths.LOADER)
	if ldr == null:
		Log.log("[VTK] Restart: ERROR - Loader not found")
		return
	var difficulty := 1
	if ironman:
		difficulty = 3
	elif gd.get("difficulty") != null:
		difficulty = int(gd.get("difficulty"))
	ldr.call("NewGame", difficulty, _resolve_start_season())
	ldr.LoadScene(start_map)
	Log.log("[VTK] Restart: loading " + start_map + " ironman=" + str(ironman))
```

Комментарий 1426-1428 про `NewGame`/`LoadScene` удаляем: по правилу «без
комментариев», а его смысл перенесён в спеку.

- [ ] **Step 7: Добавить Death.gd в wrap surface**

В `loadouts/mod.txt` секция `[hooks]` получает третью строку — стало:

```
[hooks]
res://Scripts/Context.gd = Update
res://Scripts/Pickup.gd = Interact
res://Scripts/Interface.gd = ContextTake, ContextSplit
res://Scripts/Death.gd = _ready, _on_load_pressed
```

- [ ] **Step 8: Прогнать стенды**

Run:
```
py -3 .check\layout_check.py
```
Expected: `GONE: ..., GONE_RE: 1, PRESENT: ..., FUNCS: ..., HOOKS_GONE: 4` и
`RESULT: символы раскладки на месте`, код выхода 0. Ни один удалённый символ не
был в `PRESENT`/`FUNCS`, а новые имена не пересекаются с `HOOKS_GONE`.

Run:
```
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```
Expected: `Parse check passed: N scripts`, по каждому тесту
`VERDICT: ok`, в конце `Tests passed: 14 file(s)`, код выхода 0. В выводе
`test_hooks.gd` — строки `ok` для всех четырёх death-проверок и `Hooks tests
passed`.

- [ ] **Step 9: Коммит**

```bash
git add loadouts/mods/VTK/VTKHooks.gd loadouts/mod.txt
git commit -m "refactor(vtk): restart death screen via Death.gd event hooks"
```

---

### Task 2: Релиз 4.17.23

**Files:**
- Modify: `loadouts/mod.txt` (поле `version`)
- Modify: `CHANGELOG.md` (новый раздел сверху)
- Build: `Loadouts.vmz` через `pack.ps1`

**Interfaces:**
- Consumes: рабочее состояние Task 1 (зелёные стенды).
- Produces: обновлённый `Loadouts.vmz` для `D:\SteamLibrary\steamapps\common\Road to Vostok\mods`.

- [ ] **Step 1: Поднять версию**

В `loadouts/mod.txt` заменить `version="4.17.22"` на `version="4.17.23"`.

- [ ] **Step 2: Запись в CHANGELOG**

В `CHANGELOG.md` после шапки (строки 1-5) добавить:

```markdown
## [4.17.23] - 2026-10-17

### Fixed

- The Restart button on the death screen now appears immediately and reliably (it could previously stay as the vanilla Load Game button).
```

- [ ] **Step 3: Сборка**

Run:
```
powershell -ExecutionPolicy Bypass -File pack.ps1
```
Expected: в выводе версия `4.17.23`; `Loadouts.vmz` перезаписан.

- [ ] **Step 4: Установка в игру**

Скопировать `Loadouts.vmz` в `D:\SteamLibrary\steamapps\common\Road to Vostok\mods`.

- [ ] **Step 5: Проверка в игре (ручная)**

1. Ironman-забег: умереть. Кнопка сразу подписана `Restart` и активна;
   клик запускает новый забег на карте из `IRONMAN_MAPS`.
2. Обычная смерть: кнопка остаётся `Load game`; при отсутствии сохранённого
   шелтера она по-прежнему неактивна.
3. В логе: `[VTK] Registering hooks...` без предупреждений про
   `death-...`, и нет сообщений `Main/Permadeath not found`.

- [ ] **Step 6: Коммит**

```bash
git add loadouts/mod.txt CHANGELOG.md
git commit -m "release: 4.17.23"
```
