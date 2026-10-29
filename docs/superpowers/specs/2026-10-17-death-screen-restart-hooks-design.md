# Экран смерти: рестарт по событийным хукам Death.gd

Дата: 2026-10-17
Целевая версия: 4.17.23 (патч)

Источник: сравнение с модом SES (`referens/SES/SeasonExpansionSystem/Main.gd:505-529`)
и разбор ванильной сцены Death. Продолжение линии батча 5
(`docs/superpowers/specs/2026-10-15-batch5-vanilla-integration-design.md`,
раздел Death+Restart).

## Контекст

Кнопка рестарта на экране смерти сейчас держится на пофреймовой машине
состояний в `VTKHooks.gd`:

- `_process` → `_poll_death()` (`VTKHooks.gd:96-99`, `:121-153`) каждый кадр
  читает `isDead`/`permadeath` из GameData;
- флаги выживают один кадр, потому что ванильный `Death.gd:39` в `_ready`
  вызывает `gameData.Reset()` (`GameData.gd:157`), который обнуляет
  `permadeath`, `difficulty` и `season`. Отсюда латч `_death_latched`,
  проб-логи и таймаут `DEATH_FIND_TIMEOUT_MS = 20000`;
- `_find_load_button` (`:1342-1356`) ищет кнопку **по тексту** `"load game"` по
  всему дереву сцены Death, `_repurpose_load_button` (`:1358-1371`) снимает её
  коннекты и вешает свой, `_restore_load_button` (`:1373-1389`) возвращает
  ванильное состояние при выходе из экрана.

Паттерн SES показал более дешёвый способ работать с одноразовыми сценами:
идентификация узла по пути, аддитивная мутация, идемпотентная переприсановка
без восстановления. Сцена Death умирает вместе со смертью игрока, поэтому
весь механизм восстановления и латчей не нужны, если состояние брать из самой
сцены.

Вспомогательные факты, на которых строится дизайн:

- Дерево сцены (проверено инстанцией `res://Scenes/Death.tscn` headless):
  `Death/Main/Buttons/Load`, `Death/Main/Buttons/Menu`,
  `Death/Main/Buttons/Quit`, `Death/Main/Permadeath` (Sprite2D),
  `Death/Blocker` (Panel).
- `Death.gd:31-35` показывает или прячет `$Main/Permadeath` по
  `gameData.permadeath` **до** вызова `Reset()` на строке 39. Спрайт —
  зеркало режима на момент монтирования сцены, и ванька его больше не трогает.
- `Death.gd:46-49` выключает кнопку Load, когда `Loader.ValidateShelter() == ""`,
  то есть ровно в пермадэт-ране без сохранённого шелтера: без раздизейбла
  рестарт недостижим.
- `Death.gd:54-59` в `_on_load_pressed` грузит шелтер, ставит
  `Blocker.mouse_filter = MOUSE_FILTER_STOP` и играет клик.
- `_lib._caller` на время диспатча равен экземпляру обёрнутого скрипта
  (`modloader.gd:190`, `:21278`), то есть из replace-хука доступны узлы сцены,
  `gameData` и `PlayClick()`.

## Цели

1. Рестарт на экране смерти — по событиям сцены Death, без пофреймового
   чтения флагов GameData.
2. Идентификация кнопки и режима — по путям узлов сцены, а не по тексту
   кнопки.
3. Удалить латч, проб-логи, таймаут, снимок коннектов и восстановление
   ванильного состояния.
4. Сохранить поведение рестарта: та же стартовая карта для ironman, то же
   `Loader.NewGame(difficulty, season)`, тот же сброс `isDead`/`previousMap`.

## Не-цели

- Разлочка сезона Dynamic в меню нового игры (отложена пользователем).
- Любая смена UX: текст кнопки `Restart`, поведение без пермадэта и
  disabled-состояние без шелтера остаются как сейчас.
- Фолбек-панель смерти (`_build_fallback_panel` и др.) не возвращается —
  эти имена остаются в `HOOKS_GONE` стенда `layout_check.py`.

## Решения

### 1. Два хука на `Death.gd`

```gdscript
_lib.hook("death-_ready-post", _on_death_ready)
_lib.hook("death-_on_load_pressed", _on_death_load_pressed)
```

Имена по грамматике модлоадера `<скрипт>-<метод>` плюс суффикс
(`modloader.gd:14503-14514`); replace-слот без суффикса, как у существующего
`task-_on_complete_pressed` (`VTKHooks.gd:188`). Wrap surface добавляет
`Death.gd` по литеральному `.hook()` в исходнике (`modloader.gd:6998-7026`),
плюс строка для явности в `[hooks]` `mod.txt`:

```
res://Scripts/Death.gd = _ready, _on_load_pressed
```

### 2. `_on_death_ready` — событийная замена поллинга

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
```

Правило логирования: **промах пути** (узла нет) — одна строка; **спрайт скрыт**
(обычная смерть) — молча. Ветка «скрыт» оставляет экран смерти полностью
ванильным: обычная смерть по-прежнему грузит шелтер, а при отсутствии шелтера
кнопка остаётся disabled — это ванильное поведение, а не потеря.

### 3. `_on_death_load_pressed` — replace-хук с `skip_super`

```gdscript
func _on_death_load_pressed() -> void:
	var death = _lib._caller if _lib else null
	if death == null:
		return
	var pd = death.get_node_or_null("Main/Permadeath")
	if pd == null or not pd.visible:
		if pd == null:
			Log.log("[VTK] death: Main/Permadeath not found; vanilla Load runs")
		return
	if _lib != null:
		_lib.skip_super()
	var blocker = death.get_node_or_null("Blocker")
	if blocker != null:
		blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	if death.has_method("PlayClick"):
		death.PlayClick()
	_on_restart_pressed(VTKData.prop(death, "gameData", null), death, true)
```

`skip_super` подавляет ванильную загрузку шелтера (`Death.gd:54-55`). Блокер и
клик повторяют ванильный `_on_load_pressed` — иначе рестарт можно нажать
дважды во время фейда, и клик пропадает.

### 4. `_on_restart_pressed` получает явный `ironman`

Сигнатура `_on_restart_pressed(gd, root, ironman: bool)` вместо чтения поля
`_death_is_ironman` (`VTKHooks.gd:1399-1431`). Тело меняется только в этом:
выбор `IRONMAN_MAPS`, `difficulty = 3` и `permadeath = true` остаются как есть.
Имя и место вызова сохраняются — их держит `test_hooks.gd`.

`_resolve_start_season()` (`:1391`) и `patch_world_difficulty` (`:228`) не
меняются.

### 5. Удаляемое

Функции: `_poll_death` (`:121`), `_handle_death_screen` (`:1286`),
`_death_scene_root` (`:1327`), `_on_scene_changed` (`:1336`),
`_find_load_button` (`:1342`), `_repurpose_load_button` (`:1358`),
`_restore_load_button` (`:1373`).

Поля: `_death_latched`, `_death_scene_flag`, `_death_is_ironman`,
`_death_find_since`, `_death_gave_up`, `_death_load_btn`,
`_death_load_orig_text`, `_death_load_orig_disabled`, `_death_load_orig_conns`,
`_death_probe_at`, `_gd_missing_logged`.

Константы: `DEATH_FIND_TIMEOUT_MS`, `DEATH_PROBE_MS`.

Прочее: подключение `get_tree().scene_changed.connect(_on_scene_changed)`
(`:84`) и вызов `_poll_death()` из `_process` (`:99`) — там остаётся только
`_try_register()`.

Килл-счётчик не задет: счётчики убийств и хуки `ai-*` живут отдельно.

### 6. Ошибки и деградация

Правило по трём исходам: нет `_lib._caller` — молча; узла нет — одна строка в
лог через `Log.log` (`VTKHooks.gd:3`, preload есть и в тестах); спрайт скрыт —
молча. Сцена одноразовая, так что повторного спама не будет.

Если в обновлении игры уберут `$Main/Permadeath` или переименуют кнопку,
рестарт молча исчезнет, но ванильная смерть останется рабочей. Это
осознанная деградация, тот же риск, что принимает SES.

## Тесты

`.check/project/tests/test_hooks.gd`, все headless, без игровых ресурсов.

Изменяется `t_ironman_restart_restores_difficulty` (`:349`): вызов
`_on_restart_pressed(gd, null)` → `_on_restart_pressed(gd, null, true)`;
поля `_death_is_ironman` больше нет.

Удаляется `t_death_timeout_gives_up` (`:661`) — тестировал удалённый таймаут.

Добавляются два теста на существующем `FakeLib2` (`:383`, поля `_caller` и
`skip_super()`), с заглушкой дерева Death (`Control` со спрайтом и кнопкой):

- `t_death_ready_unlocks_restart_for_permadeath`: спрайт виден →
  `text == "Restart"` и `disabled == false`; спрайт скрыт → `text == "Load
  game"` и `disabled` не тронуты.
- `t_death_load_pressed_runs_restart_only_for_permadeath`: спрайт виден →
  `skip_super` отработал и фейковый `Loader` получил `NewGame` с
  `difficulty == 3`; спрайт скрыт → ни `skip_super`, ни `NewGame`.

## Выкатка

1. `py -3 .check\layout_check.py` — новые имена не попадают в `HOOKS_GONE`,
   удалённые не значатся в `PRESENT`.
2. `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1` —
   парсинг и полный прогон тестов.
3. `loadouts/mod.txt`: `version="4.17.23"`, строка `[hooks]` для `Death.gd`.
4. Строка в `CHANGELOG.md` в группу `### Fixed`, по-английски, видимым
   эффектом (что рестарт появляется сразу и надёжно).
5. `pack.ps1`, копия `Loadouts.vmz` в папку модов игры.
6. Ручная проверка в игре: ironman-смерть (кнопка сразу `Restart`, клик,
   рестарт с картой ironman), смерть без пермадэта (кнопка `Load game` и
   disabled при отсутствии шелтера), в логе `[VTK] Registering hooks...` и
   отсутствие сообщений про нерезолвящиеся префиксы `death-...`.

## Риски

- Пути `Main/Permadeath` и `Main/Buttons/Load` сломаются при перетряске
  сцены в апдейте игры — рестарт перестанет работать тихо. Принимается:
  ванильная смерть остаётся рабочей, откат — `git revert` одного коммита.
- Wrap surface обновляется при пересканировании модов (`modloader.gd:1744`),
  то есть новый `.vmz` должен быть установлен, иначе хуки зарегистрируются, но
  не сработают (регистрация без обёртки — молчаливый no-op по арности).
  Проверяется по логу `[Hooks] ... scanned .hook() call(s) resolved ...`.
