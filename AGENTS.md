# Road to Vostok mods — правила сборки и версионирования

## Раскладка репозитория

Один репозиторий — несколько модов. Папка мода — `mods/<slug>/`, где slug = поле `id` из её `mod.txt`; внутри мода ровно один свой префикс имён папок `mods/<Folder>/` (он же — namespace внутри `.vmz`).

Скриптов `.gd` под `mods/` — 58: `vostok-toolkit` 25, `thermal-vtk` 18, `road-to-loot` 13, `jcm-freeze` 2. Сверять перед сборкой: `Get-ChildItem -Recurse -Filter *.gd D:\RTVMOD\mods | Measure-Object`.

| Путь | Назначение |
|---|---|
| `README.md` | корневой индекс: по одному блоку на мод — описание и актуальная версия |
| `pack.ps1` | единственный сборщик: `pack.ps1 -Mod <slug>` или `-All`; артефакты кладёт в `dist/` под историческими именами `Loadouts.vmz`/`ThermalVTK.vmz`/`RoadToLoot.vmz`/`Freeze.vmz`; `.gd` при упаковке чистится от построчных `#`-комментариев, пустых строк и CR (вес ~на 40% меньше), исходники не меняются |
| `AGENTS.md` | этот документ: правила, общие для всех модов репозитория |
| `.check/` | headless-стенд: парсинг/компиляция `.gd` и тесты; в пак не попадает |
| `docs/` | макеты UI и планы/спеки фич |
| `mods/vostok-toolkit/` | мод Vostok Toolkit (VTK): сеты, deposits, NVG, счётчик убийств, телепорт |
| `mods/thermal-vtk/` | мод ThermalVTK: тепловизор и контурный ESP |
| `mods/road-to-loot/` | мод Road To Loot (RTL): генерация лута с аффиксами |
| `mods/jcm-freeze/` | мод jcm-freeze |

Внутри папки мода — только:

| Файл/папка | Что это |
|---|---|
| `mod.txt` | имя, `id`, `version`, автолоад, `[hooks]`; единственное место с версией |
| `mods/<Folder>/` | исходники мода, ровно то, что пакуется (`VTK`, `ThermalVTK`, `RoadToLoot`, `jcm-freeze` — списки в `$mods` у `pack.ps1` и `check.ps1`) |
| `README.md` | карточка мода: сборка при упаковке синхронизирует в ней строку версии с `mod.txt` |
| `CHANGELOG.md` | история изменений для игроков (у каждого мода свой) |
| `REFACTOR_SPEC.md` | только у `road-to-loot` |

Правила раскладки:

1. slug мода = поле `id` из его `mod.txt`: `vostok-toolkit`, `thermal-vtk`, `road-to-loot`, `jcm-freeze`.
2. Новая фича мода живёт в его папке; на корне ничего от мода не лежит.
3. Новый мод = новая папка `mods/<slug>/` с `mod.txt` и `mods/<Folder>/` плюс по одной строке в `$mods`-таблицах `check.ps1` (Slug/Folder/Tests) и `pack.ps1` (Slug/Folder/Artifact).
4. Тесты — только в `.check/project/tests/<slug>/`, имена `test_*.gd`; файл-опора для тестов лежит рядом с ними (`rtl_probe_save.gd`/`rtl_probe_slot.gd` у road-to-loot). Сейчас 41 файл: 15 `vostok-toolkit` + 17 `thermal-vtk` + 9 `road-to-loot`; у `jcm-freeze` headless-тестов нет.
5. Релиз — тег `<slug>-<version>`.
6. `version.txt` для трёх модов с файлом версии (у `jcm-freeze` его нет) генерируется сборкой в `mods/<slug>/mods/<Folder>/version.txt` и отслеживается git — в рантайме `res://mod.txt` общий на все установленные моды, файл страхует от чужого `mod.txt`.
7. Артефакты сборки — только в `dist/`; в папку модов игры копируются оттуда.

Игнорируется git (не трекается, могут лежать локально): `dist/` — сборка, `RTVcopy/` — копия игры для сверки, `tools/` — бинарник Godot, `referens/`, `tmp_probe/`, `superpowers/`, `.superpowers/`, `.docs/`.

## Скрипты vostok-toolkit

| Путь | Назначение |
|---|---|
| `mods/vostok-toolkit/mods/VTK/` | двадцать пять скриптов мода, префикс `VTK` |
| `mods/vostok-toolkit/mods/VTK/VTKSurface.gd` | слоёные SVG-поверхности: статический `RefCounted`, прелоадится `const` из `VTKUI.gd` |
| `mods/vostok-toolkit/mods/VTK/VTKNotes.gd` | логика Notes: группировка предметов, признак сдачи, построение строк иконок, прогресс вкладов (variant A); чистые функции тестируются headless |
| `mods/vostok-toolkit/mods/VTK/VTKDeposits.gd` | чистая логика леджера вкладов (`task_key`/`normalize_slots`/`coverage`/`apply`/`clear_task`/`prune_missing`/`is_covered`); headless-тест `test_deposits.gd` |
| `mods/vostok-toolkit/mods/VTK/VTKItemStore.gd` | каталог предметов: список, индекс `resource_path`, кеши info и иконок; статический `RefCounted`, как `VTKSurface`; headless-тест `test_items.gd` |
| `mods/vostok-toolkit/mods/VTK/VTKTeleportTab.gd` | вкладка «Телепорт»: экземпляр `RefCounted`, владеет тремя боксами; `travel`/`game_data` — аргументы, `hover`/`motion` (`_attach_row_hover`/`_attach_motion`) — инъекция Callable из `VTKUI.gd` |
| `mods/vostok-toolkit/mods/VTK/VTKFeatureHost.gd` | хост фич: владеет ленивыми узлами (`_hooks`/`_nvg_node`/`_travel`/`_kc_node`/`_feed_node`/`_hud_canvas`) и тумблерами; создаётся с родителем-VTKUI, потому что дети обязаны лежать под `/root/VTKUI`; применяет весь разобранный MCM-конфиг разом через `apply_config` |
| `mods/vostok-toolkit/mods/VTK/VTKConfig.gd` | типизированный срез MCM-конфига: 19 полей с дефолтами и `read(cfg)`; статический `RefCounted`, без состояния сцены; headless-тест `test_config.gd` |
| `mods/vostok-toolkit/mods/VTK/VTKMCMBridge.gd` | мост MCM: регистрация настроек, свёртка `config.ini`, разбор в `VTKConfig` и делегирование в хост; `rebuild_ui`/`set_key_ui_toggle` — инъекция Callable из `VTKUI.gd` |
| `mods/vostok-toolkit/mods/VTK/VTKSetsRail.gd` | вкладка «Сеты», рейл-половина: список сетов, выбор активного, захват хоткея и превью состава; экземпляр `RefCounted`, создаётся с родителем-VTKUI (`VTKSetsRail.new(self)`) ради общих сцен; `_ui` — ссылка на узел VTKUI, `refresh_rail` — инъекция Callable из `VTKUI.gd` |
| `mods/vostok-toolkit/mods/VTK/VTKLoadoutSession.gd` | состояние редактора сета: владеет черновиком (`draft`), страницей мастера, целью шага 1, фильтрами и поиском шага 2, открытой панелью обвесов и последним положенным предметом; чистый `RefCounted` без `load()`/путей внутрь игры, headless-тест `test_session.gd` |
| `mods/vostok-toolkit/mods/VTK/VTKEditor.gd` | редактор сета (мастер шагов): экземпляр `RefCounted`, создаётся с родителем-VTKUI (`Editor.new(self)`); владеет сеткой экипировки, каталогом шага 2, оверлеем обвесов и страницей «Готово»; поля VTKUI читает через `_ui.`, `refresh` делегирует обратно; тестов нет — UI-сборка |

## Регламент версий

Формат: `Глобальное.Фича.Фикс` (`MAJOR.MINOR.PATCH`).

| Компонент | Когда повышаем | Пример |
|---|---|---|
| **Глобальное** (major) | несовместимое изменение: удаление или переименование фич, вкладок, настроек, хоткеев; смена формата сохранённых данных | `1.20.1 → 2.0.0` |
| **Фича** (minor) | новая функциональность, обратная совместимость сохранена | `2.0.0 → 2.1.0` |
| **Фикс** (patch) | баги и рефакторинг без изменения поведения | `2.0.0 → 2.0.1` |

Правила:

1. Версия живёт в одном месте — `mods/<slug>/mod.txt`, поле `version`. Внесли изменение в мод — внесли изменение в его `mod.txt`.
2. Перед сборкой версия обязательно проверена и при необходимости поднята. `pack.ps1` печатает версию из `mod.txt` перед упаковкой — сверяйтесь с этим выводом.
3. В GDScript версия **не дублируется**: ни `MOD_VERSION`, ни `ESP_VERSION` в коде держать не нужно. MCM берёт её из `res://mod.txt` в рантайме и только для отображения, логика на версию не завязана.
4. `user://MCM/vostok-toolkit/config.ini` синхронизируется по ключам, а не по версии (`_register_mcm`): ключи, которых больше нет в коде, удаляются; существующие сохраняют пользовательские значения; секция `Info` перезаписывается. Следствие: удаление настройки из кода автоматически чистит конфиг пользователя, отдельный мажорный релиз для этого не нужен.
5. Сохранённые сеты лежат в `user://MCM/vostok-toolkit/VTKsets.json`. Они переживают любой релиз, если формат записей не менялся; при смене формата нужна миграция.

Файл сетов пишется атомарно и с подстраховкой: `save_all` сериализует payload, копирует предыдущую версию в `VTKsets.json.bak`, пишет в `VTKsets.json.tmp` и переносит `.tmp` на место основного (`_replace`; на Windows rename поверх файла может упасть — тогда цель удаляется и rename повторяется). `get_all` при нечитаемом основном файле переносит его в `VTKsets.json.corrupt-<unixtime>` (байты сохраняются для разбора) и грузит `.bak`; повторные `get_all` дубликатов не плодят, потому что основной уже перемещён. Отсутствие данных (`_read_payload` вернул `null`) — это «файл негоден», в отличие от пустого массива «сетов нет».

Имя папки MCM раньше было `loadouts`, потом мод переименовали в `vostok-toolkit`. Старая папка нужна только как источник одноразовой миграции `_migrate_mcm_dir` (`VTKUI.gd`): она копирует содержимое и выходит, если папка назначения уже есть. Поэтому в коде путь `MCM/loadouts` встречается только там, а читать живые данные надо из `MCM/vostok-toolkit`.

Файл сетов назывался `loadouts.json`, теперь `VTKsets.json` — под префикс `VTK*`, как остальные сущности мода. Старое имя живёт только в `VTKData.LEGACY_SAVE_FILE`: одноразовая миграция `migrate_save_file` копирует `loadouts.json` и `loadouts.json.bak` в новые имена и выходит, если `VTKsets.json` уже есть. Формат записи не менялся, миграция переносит байты как есть. Вне этой функции старого имени в коде быть не должно — включая отладочную подпись пути в UI.

Скрипты и автолоад переименованы в `VTK*`/`VTKUI`. Держать в связке, иначе мод развалится молча:

| Что | Где |
|---|---|
| ключ автолоада `VTKUI` | `mod.txt`, секция `[autoload]` |
| `name = "VTKUI"` | `VTKUI.gd` |
| `get_node_or_null("/root/VTKUI")` | `VTKKillCounter.gd` |
| `signal kill_event` + `get_node_or_null("/root/VTKUI")` → `VTKHooks` | `VTKFeed.gd` |
| `name = "VTKHooks"` + `Paths.HOOKS` (узел-ребёнок VTKUI) | `VTKHooks.gd`; ищут `VTKTravel.gd`, `VTKFeed.gd`, `VTKKillCounter.gd` |
| `const Loc = preload("res://mods/VTK/VTKLoc.gd")` | `VTKUI.gd` |
| `const VTKSurface := preload("res://mods/VTK/VTKSurface.gd")` | `VTKUI.gd` |
| `const Items := preload("res://mods/VTK/VTKItemStore.gd")` | `VTKUI.gd` |
| `const TeleportTab := preload("res://mods/VTK/VTKTeleportTab.gd")` | `VTKUI.gd` |
| `const Features := preload("res://mods/VTK/VTKFeatureHost.gd")` | `VTKUI.gd` |
| `const MCMBridge := preload("res://mods/VTK/VTKMCMBridge.gd")` | `VTKUI.gd` |
| `const SetsRail := preload("res://mods/VTK/VTKSetsRail.gd")` | `VTKUI.gd` |
| `const Session := preload("res://mods/VTK/VTKLoadoutSession.gd")` | `VTKUI.gd` |
| `const Editor := preload("res://mods/VTK/VTKEditor.gd")` | `VTKUI.gd` |
| `preload("res://mods/VTK/...")` ×14 | `VTKUI.gd` |

`VTKPicker.gd` и `VTKDraft.gd` — чистая логика выбора предметов: ни `load()`, ни путей внутрь игры, поэтому тестируются headless. `VTKUI.gd` зовёт их как `Picker.*` / `Draft.*`; всё, что знает про ресурсы, остаётся в `VTKUI.gd`.

Счётчик `preload` в таблице падает сам собой при каждом переименовании: сверять с `Select-String -SimpleMatch 'preload('` по `VTKUI.gd`. Полный прогон по всем `mods\vostok-toolkit\mods\VTK\*.gd` даст больше — остальные скрипты грузят свои зависимости сами (`VTKPaths.gd` в семи файлах, `VTKLog.gd` в шести — в том числе двум HUD-виджетам он нужен для `warn_once` при провалившейся привязке), так что жёсткой арифметики между числами нет, ориентир — свежий `grep`.

Путь `/root/VTKUI` — единственное место, где ошибка не бросается: `get_node_or_null` вернёт `null`, и счётчик убийств просто перестанет считать, без ошибки в логе. Стенд `.check` такое пропускает — это рантайм-путь, а не `preload`. Остальные привязки рвутся громко на первой сборке.

## Локализация

Английский — исходный язык: **ключ словаря сам является английской строкой**, поэтому отсутствующий перевод деградирует до читаемого английского, а не ломает вёрстку. Переключатель — MCM `Dropdown` (`[Dropdown] language` в `user://MCM/vostok-toolkit/config.ini`, значение — ключ словаря `"en"`/`"ru"`), по умолчанию `en`; `ui_toggles.json` больше не читается и не пишется.

Правила:

1. Локализуется только обвязка мода. Имена предметов, типы (`Consumable`/`Consumables`), названия карт, убежищ и трейдеров приходят из `Database` и используются как есть: перевод сломал бы поиск по предметам.
2. Функция называется `Loc.txt()`, а не `tr()`. `Object.tr()` — встроенный ремаппинг переводов Godot, перекрытие даёт Parse Error.
3. Строка, содержащая кавычку, пишется в одинарных кавычках (`'a "b"'`). В двойных `"a \"b\""` кавычка закрывается раньше времени и ломает словарь.
4. Новая строка в UI = новая запись в `RU` того же прохода. Проверка `keycheck.py` ловит рассинхрон: ключ есть в вызовах, но нет в словаре — русский молча остался бы английским.
5. Локализуется только собственное окно мода. Строки, которые мод вставляет в интерфейс игры (кнопка `Deposit`, подписи в карточках задач/заметок) и в HUD-уведомления (`Loader.Message()` — тосты применения сета и телепорта), остаются английскими литералами: ни `Loc.txt`, ни записи в `RU`, чтобы не мешать английскому UI игры.

Имена файлов менять можно только вместе с этими ссылками: `preload` резолвится на этапе компиляции и в уже собранном `.vmz` запечён.

## Частичная сдача заданий (deposits)

Вклад предметов в задание сверх ванильной сдачи. Оркестрация — в `VTKHooks.gd`, чистая математика — в `VTKDeposits.gd` (headless-тест `test_deposits.gd`).

- Леджер вкладов — мета `vtk_deposits` на `TraderSave` (`user://Traders.tres` и `MultiSaveSlots/*/Traders.tres`): `{task_key: {slot_index: amount}}`. `task_key` — `resource_path` ресурса `TaskData`, с фолбеком на `name::trader`, если пути нет. Ключ совпадает у карточки Tasks и карточки Notes, поэтому обе вкладки считают один и тот же вклад.
- `Notes` (variant A) строится из `Loader.LoadTaskNotes()` → `traders.taskNotes`; это те же `TaskData`, что и в Tasks, поэтому `resource_path` и ключи сходятся. Прогресс — по строкам иконок с чипом `got / need`.
- Вклад фиксируется через `VTKDeposits.commit`: сперва сохраняется леджер (`_ledger_set` → `ResourceSaver.save`, результат проверяется), и только при успехе `take` отдаётся на списание (`_consume`). Сбой сохранения возвращает пустой `take` — предметы остаются у игрока, вклад не фиксируется. Обратный порядок (списать, затем сохранить, игнорируя код) приводил к потере предметов без записи вклада.
- Кнопка `Deposit` живёт в `Task/Margin/Elements/Buttons` (`GridContainer`, `columns = 3`): ванильные `Input`/`Complete` плюс третий столбец. Столбцы там content-based, поэтому ширины разъезжаются; `_balance_buttons` считает максимум `get_combined_minimum_size()` по Control-детям и присваивает его всем, выравнивая столбцы. Зовётся в конце `_make_deposit_button`.
- Notes-карточку надо перерисовывать **на месте** после вклада (`_refresh_notes_for` из `_on_deposit_pressed`), иначе открытая вкладка Notes показывает устаревший прогресс до переинициализации. `VTKNotes.augment_note` поэтому идемпотентен: `_remove_blocks` сносит прежние блоки `VTKNoteDeliver`/`VTKNoteReward` (`find_child(name, true, false)`) перед повторной вставкой, иначе ряд рос бы при каждом вызове. Не перерисовывать — а обновлять: удалять карточку целиком нельзя, она принадлежит ванили.
- `_on_notes_rendered`/`_render_all_tasks` обходят только `_live_children` (`is_queued_for_deletion()` отфильтрован): `TaskList` при переинициализации держит фантомные ячейки, помеченные на `queue_free`, и по ним прогресс строился бы из мёртвых данных.
- Нестакающиеся предметы игра хранит с `amount = 0` (`Task.Initialize` проставляет `amount` только при `defaultAmount != 0`, а `Loader.LoadCharacter` пишет `defaultAmount`), поэтому `_selected_stacks` обязан клампить ячейку инвентаря до одного предмета: `if amt < 1: amt = 1`. Иначе `apply()` (`VTKDeposits.gd`) пропускает запись как пустую, и `Deposit` молча ничего не делает — так отвалилась сдача у Доктора, где все деливери нестакающиеся (у Generalist проходили только оставшиеся в стеке).
- GC леджера (`_gc_ledger` из `_on_tasks_rendered`, чистая часть — `VTKDeposits.prune_missing`): ключи-`resource_path`, чей ресурс больше не существует, выкидываются — их оставляет апдейт игры, переименовавший или удаливший задачу. Прунаем **по существованию файла** (`ResourceLoader.exists`), а не по списку `traders.taskNotes`: задача может быть сдана с карточки Tasks, не попав в Notes (в Notes её добавляет кнопка `Add`), и прунинг по списку стёр бы валидный вклад. Ключи-фолбэки (`name::trader`) не проверяются и остаются. Запись в сейв — только если что-то удалилось.

## Арность post-хуков

`modloader.gd` вызывает post-колбэки по-разному для **void** и **не-void** методов:

| Метод игры | Что ждёт колбэк |
|---|---|
| void | ровно `args.size()` аргументов |
| не-void | `args.size() + 1` (последний — `_result`) |

Реализация: `_dispatch` (`callv(args)`) для void, `_dispatch_post` (`args + [_result]`) для не-void.

**Критично:** `Callable.callv` при несовпадении арности в Godot 4.6.3 — **молчаливый no-op**: ни вызова, ни ошибки, ни `SCRIPT ERROR`. Поэтому лишний `_result` на void-методе не падает, а тихо отключает хук — включая `_on_deposit_pressed`, если уехала арность соседнего колбэка. Стенд `.check` такого не ловит (это рантайм, а не парсинг). Регрессия `d2b4c4f` добавила `_result` всем без разбора — откатили до точных арностей. Список ожиданий держит `test_hooks.gd` (`t_post_callback_arity`).

## CHANGELOG

`CHANGELOG.md` — документ для игроков, не для разработчиков. Правила:

1. Пишем **видимый игроку эффект**, а не реализацию: ни имён хуков и методов игры (`Pickup.Interact()`), ни файлов/функций (`_get_iface`), ни удаления мёртвого кода, ни названий MCM-ключей.
2. Одна строка — одно изменение, коротко, без жаргона.
3. Группы `### Added` / `### Changed` / `### Fixed` (Keep a Changelog); заголовок релиза — `## [x.y.z] - YYYY-MM-DD`, версия совпадает с `mod.txt`.
4. Внутренние чистки, рефакторинг и микрооптимизации сворачиваем в «Minor performance improvements» или не упоминаем.
5. Язык — английский, как исходный язык мода.
6. У каждого мода свой `CHANGELOG.md` (`mods/<slug>/CHANGELOG.md`); файл отслеживается git, не забывать коммитить его вместе с версией.

## Сборка

1. Прогнать стенд раскладки: `py -3 .check\layout_check.py`.
2. Прогнать стенд парсинга: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`.
3. Поднять версию в `mods/<slug>/mod.txt`.
4. Запустить `powershell -ExecutionPolicy Bypass -File pack.ps1 -Mod <slug>` (или `-All` для всех модов сразу).
5. Скопировать артефакт из `dist/` (`Loadouts.vmz`/`ThermalVTK.vmz`/`RoadToLoot.vmz`/`Freeze.vmz`) в папку модов игры `D:\SteamLibrary\steamapps\common\Road to Vostok\mods`.

`pack.ps1` при упаковке чистит `.gd` от построчных `#`-комментариев, пустых строк и CR (шейдеры не трогает: в них `#` — препроцессор). Исходники не меняются, вес `.vmz` падает примерно на 40%. Трансформация построчная и потому безопасна: многострочных строк (`"""`) в коде нет, а строки кода остаются дословно.

## Проверка

- Игра собрана на **Godot 4.6.3** (`RTVcopy/RTV.pck`, pack format 3).
- Отступы в `.gd` — только табы. Перед сборкой убедиться, что нет смешанных пробелов и что скобки сбалансированы.
- Стенд `.check/check.ps1` копирует `.gd` всех модов из `mods/<slug>/mods/<Folder>/` (список в таблице `$mods` стенда) во временный проект и прогоняет `godot --headless --check-only` по каждому файлу. Бинарь ищется в PATH, иначе передаётся через `-Godot "<путь к Godot_*_console.exe>"`. Папка назначения в `.check/project/mods/` очищается перед каждой копировкой, так что удалённые скрипты там не накапливаются.
- Стенд ловит ошибки парсинга и компиляции, но не проверяет работу в игре: пути внутрь игры, нити и готовность сцен остаются на ручную проверку.
- Авто-экип висит на ванильном событии подбора `Pickup.Interact()` (хуки `pickup-interact-pre/-post`), а не на отличии количества в инвентаре: игра при перекладывании временно пересобирает узлы, дельта это ловила. Оба hook void -> колбэки без `_result` (см. `t_post_callback_arity`). Take/Split в слоте экипировки — replace-хуки `interface-contexttake`/`interface-contextsplit` (`skip_super` только когда `contextGrid == null`); декларация обёрток в `[hooks]` (`mod.txt`).
- Стенд гоняет и тесты — `test_*.gd` из `.check/project/tests/<slug>/`, сейчас 41 файл: 15 `vostok-toolkit`, 17 `thermal-vtk`, 9 `road-to-loot` (у `jcm-freeze` headless-тестов нет); списки `$tests` в `check.ps1` явные, по одному на мод в таблице `$mods` — новый тест добавляется туда вручную, а `test_hooks.gd` запускает тело теста на первом кадре (`process_frame`), потому что `_on_restart_pressed` делает `get_node_or_null("/root/Loader")` — абсолютный путь работает только из активного дерева. Зелёный статус значит **всё** из трёх: нет строк `SCRIPT ERROR` / `Parse Error` / `Invalid call` / `Failed to load script`, есть строка `tests passed`, код выхода 0. Раньше проверялась только вторая строка, и `Invalid call` внутри теста глушил функцию, печатал `passed` и выходил с кодом 0 — падение выглядело как успех.
- `.check\layout_check.py` сверяет раскладку picker по всем модулям `mods/vostok-toolkit/mods/VTK/*.gd` (глоб, не только `VTKUI.gd`: после декомпозиции монолита символы живут в разных файлах): список `GONE` (символы, которых быть не должно — кнопка `+ Add`, `_gear_grid_open`, `_cat_color`, префиксы `[x] `/`[ ] `, список слотов `_side_slots_box`/`_make_slot_row`) и список `PRESENT` (которые должны быть — `_page_columns`, `_make_facet_row`, `_done_equip_col`, с 4.9.0 — сетка экипировки `_equip_grid_box`/`_make_equip_cell`/`_make_body_zone`/`BodySilhouette`). `GONE`/`GONE_RE` проверяются по каждому модулю отдельно, `PRESENT` — хотя бы в одном, `FUNCS` — по телу функции в том модуле, где она определена, плюс варнинг `DUP`, если функция объявлена больше чем в одном модуле (след выноса — забытая копия в монолите). Комментарии не разбираются, поэтому упоминание имени живого `GONE`-символа в тексте тоже считается провалом — в комментариях эти имена не пишем. Списки пополняются вместе с задачами плана; забытый символ в `GONE` поймает возврат кнопки, а пропущенный в `PRESENT` — исчезновение колонки. Список `HOOKS_GONE` (удалённая фолбек-панель смерти: `_build_fallback_panel`, `_on_menu_pressed`, `_on_quit_pressed`, `_death_restart_btn`) сканируется отдельно от `GONE` (оба смотрят все модули) — оставлен ради явной группировки и счётчика в отчёте.
- `VTKSurface.gd` — статический `RefCounted` без состояния сцены: поверхности и иконки собираются из SVG, `svg_texture` грузит SVG **из строки** через `Image.load_svg_from_string` и отдаёт `ImageTexture` — ни одного `load()` и ни одного файла из игры. Поэтому слои переживают любой апдейт игры, а кэш (`_textures`, `_surfaces`) живёт в static-переменных и сбрасывается через `clear_cache()`.
- `VTKItemStore.gd` — каталог предметов, тоже статический `RefCounted`: список, индекс `resource_path`, кеши info и иконок. Наполняется из `VTKUI._load_items` (`Items.clear()` до чтения базы, `Items.rebuild(db.master.items)` после), читается как `Items.all()`/`Items.index_of()`. `load()` в нём остался для дисковых фолбэков (путь не попал в индекс, PNG рядом с предметом), поэтому дисковые ветки headless не покрыты, а остальное — в `test_items.gd`. Форвардеры `_item_info`/`_item_icon` обязаны остаться на `VTKUI`: `VTKFeed` зовёт `ui.call("_item_icon", item)`, а ~15 внутренних вызовов `_item_info` намеренно не переписывались.
- Перенос функции в другой модуль ломает `layout_check.py` только тогда, когда меняется её имя: `GONE`/`HOOKS_GONE` сканируют каждый модуль, а `PRESENT` — все сразу (при переезде каталога запись `_attachment_resource` заменена на `attachment_resource`).
- `VTKTeleportTab.gd` — первая вынесенная вкладка, шаблон для следующих (`VTKSetsRail`, `VTKEditor`): модуль владеет своими боксами, игровые объекты (`travel`, `game_data`) приходят аргументом, а общие примитивы UI — инъекцией `Callable` (`hover`/`motion`, потому что `_attach_motion` тянет `_tween_scale` VTKUI, а объявить вторую копию нельзя — `DUP` стенда ловит одноимённые функции в разных модулях). Имена функций модуля совпадают с прежними в VTKUI: `layout_check` держит `PRESENT` на `_make_tp_column` и `FUNCS` по телам `_build_teleport_tab`/`_make_tp_column`, так что переименование при выносе ломает стенд. Порядок сохранён: узел телепорта теперь обеспечивает хост (`_features._ensure_travel()`), а VTKUI зовёт его до `_build_teleport_tab` и до `_refresh_teleport_tab` (раньше `_ensure_travel()` был внутри обеих). Тестов нет: модуль — UI-сборка без чистой логики, покрывать нечего.
- `VTKFeatureHost.gd` (R4a) — хост фич, тоже `RefCounted`, но с родителем: `Features.new(self)` в `_init_later` **до** `_build_ui`, потому что вкладка телепорта и lazy-тумблеры берут у него узлы. Владеет `_hooks`/`_nvg_node`/`_travel`/`_kc_node`/`_feed_node`/`_hud_canvas` и тумблерами. **Критично:** детей создаёт через `_root.add_child`, поэтому они остаются под `/root/VTKUI`, а узел хуков — с именем `VTKHooks` (три тихих шва: `VTKTravel.gd:189`, `VTKFeed.gd:92`, `VTKKillCounter.gd:144`). Вынести `add_child` из VTKUI нельзя — путь `/root/VTKUI` резолвится `get_node_or_null`, промах не бросает ошибку, и мод разваливается молча (стенд `.check` такое не ловит). API применения MCM: `set_hud(counter, feed)`, `set_equip(enabled, debug)`, `set_travel_unlocked(only)`, `set_thermal(thermal, mines)`; чтение — `nvg()`/`travel()`. Имена `_apply_hud`/`_ensure_hud` сохранены — их держит `PRESENT`. Грабли: `nvg()`/`travel()` на типе `RefCounted` возвращают Variant, поэтому `var x := _features.nvg()` не компилируется (`Parse Error: Cannot infer the type`) — аннотировать явно (`var nvg: Node = ...`).
- `VTKMCMBridge.gd` + `VTKConfig.gd` (R4b) — перенос MCM из VTKUI. Мост владеет регистрацией настроек, свёрткой `config.ini` (секции и ключи свежие, `Info` перезаписывается, пользовательские `value` живут) и разбором в типизированный `VTKConfig` (19 полей с дефолтами + `read(cfg)`, семантика прежнего `_mcm_key_val` теперь внутри `VTKConfig._val`). **Побайтовая точность — главное требование:** регистрация перенесена дословно (сверено диффом с `_register_mcm` из git, отличаются только намеренные ренеймы), а слияние/удаление устаревших секций и ключей не тронуто вовсе. Дефолты полей `VTKConfig` обязаны совпадать с регистрационными литералами в мосте — сверяем вручную, потому что регистрация несёт ещё `name`/`tooltip`/`menu_pos`, которые в рекорд не тянем. Применение — `features.apply_config(c)` в хосте, порядок прежний (HUD → автоэкип → телепорт → пропсы NVG → термал), с тем же ранним `return`, когда NVG ещё не поднялся (термал тогда не применяется). VTKUI держит только `var _mcm`/`var _features` и `_set_key_ui_toggle`; `_rebuild_ui` уходит в мост Callable'ом. Грабли: `var c: ConfigRec = ConfigRec.new()` и `var want: String = c.language` — `:=` на Variant снова Parse Error, аннотировать явно. `VTKConfig` покрыт headless-тестом `test_config.gd`: словарь с `value`, примитив, чистая строка, недостающий ключ, приведение Int/Float.
- `VTKSetsRail.gd` (R5) — рейл-половина вкладки «Сеты», `RefCounted` с родителем: `SetsRail.new(self)` в `_init_later` **до** `_build_ui`, потому что `_build_sets_pane` зовёт `_rail._build_loadouts_tab`/`_right_box`/`_refresh_preview`. Владеет рейлом, выбором активного сета, bind-состоянием (`_bind_target`/`_bind_pending`/`_bind_btn`/`_done_bind_btn`/`_pending_qk`/`_editing_name`) и превью-композицией. Граница выбрана «рейл + превью»: `_make_equip_preview`/`_make_inventory_panel` **остаются в VTKUI** (их зависимости `_make_equip_grid`/`_build_equip_layout` общие с сеткой редактора), поэтому rail зовёт их как `_ui._make_equip_preview(eq)`. Обратные вызовы rail→VTKUI — через ссылку `_ui` (untyped, как `_tp_tab.hover`): `_ui._edit_loadout`/`_ui._delete_loadout`/`_ui._start_new_draft`/`_ui._cancel_draft`/`_ui._draft`/`_ui._attach_row_hover`/`_ui._attach_motion`/`_ui._is_toggle_event`. VTKUI→rail — `_rail.*` (fields/methods на `RefCounted` работают динамически; падает только `:=` на Variant): `_build_sets_pane` (заменил `_build_loadouts_tab`), `_input` (bind-кластер; первым делом `if _rail == null: return`, потому что `_rail` создаётся в отложенном `_init_later`), `refresh` (LIST/PREVIEW → `_rail._refresh_loadout_list`/`_refresh_preview`), `_build_editor` (сброс bind), `_build_page_done`/`_refresh_page_done`, `_save_loadout`/`_start_new_draft`/`_cancel_draft`/`_edit_loadout`/`_delete_loadout` (`_rail._editing_name`/`_pending_qk`/`_apply_qk_btn`). Внутренний класс `CreateCard` уехал в rail целиком. Перерисовку rail→UI делает инъекция `refresh_rail` (`Callable(self, "_refresh_rail")` в `_init_later`; `_refresh_rail` = `refresh(LIST | PREVIEW)`), потому что `refresh` остаётся в VTKUI. Адаптации при переносе: `_gold` → `VTKSurface.GOLD`, `refresh(LIST|PREVIEW)` → `refresh_rail.call()`. `layout_check` держит `FUNCS` по `_build_loadouts_tab` (`row.add_child(rail_panel)`/`rail_panel.add_child(_rail_box)`/`row.add_child(_right_box)`), `_build_set_preview` (`_make_equip_preview(eq)`/`_make_inventory_panel(gear)`/`if fill else Control.SIZE_SHRINK_BEGIN`) и `_refresh_preview` (`_make_control_column(Loc.txt("Controls")`/`Loc.txt("Delete")`/`head_sep`) — матчинг по подстроке, поэтому `_ui._make_equip_preview(eq)` засчитывается. Тестов нет: UI-сборка без чистой логики. VTKUI.gd 3183 → 2803 строки (CRLF сохранён).
- `VTKLoadoutSession.gd` (R6a) — состояние редактора сета, вынесенное из VTKUI: `RefCounted` без `load()`/путей внутрь игры (headless-тест `test_session.gd`). Владеет `draft` (тип `Draft`), `page`, `target_slot`/`target_cat`/`target_sub`, `search_text`/`gear_search`, `gear_facet_key`/`gear_sub_key`/`gear_only_selected`/`gear_subs_collapsed`, `open_equip_att`/`open_gear_att`/`last_placed`. Методы разом закрывают S5/S6: `reset_picker_state()`, `attachment_target()` (ветвление `page == 1` в одном месте), `set_attachment_target()`/`toggle_attachment_target()`/`clear_attachments()`, `new_draft()`/`clear_draft()`/`edit_draft(d)`. Создаётся `_session = Session.new()` в `_init_later` **до** `_build_ui` (в тот же момент, что `_rail`), поэтому гвард `_input` по `_rail != null` покрывает и `_session`. Ссылки переехали с полей на `_session.<имя>`: 14 объявлений удалено из VTKUI вместе с их док-комментариями; `_reset_picker_state()` из VTKUI убран в пользу `_session.reset_picker_state()`. `VTKSetsRail` зовёт `_ui._session.draft` (было `_ui._draft`). Грабли те же: `var x := _session.X` на `RefCounted`-поле — Parse Error, аннотировать явно (`var on: bool = ...`, `var slot: String = ...`, `var desc: Dictionary = ...`). `layout_check` `PRESENT`: скаляры переименованы в голые (`target_cat`/`target_sub`/`gear_facet_key`/`gear_sub_key`/`gear_subs_collapsed`/`gear_only_selected`/`open_equip_att`/`open_gear_att`/`last_placed`), `FUNCS` `_rebuild_gear_grid` тоже. VTKUI 2803 → 2753 строки.
- `VTKEditor.gd` (R6b) — редактор сета, вынесенный из VTKUI целиком (мастер шагов, сетка экипировки, каталог шага 2, оверлей обвесов, страница «Готово»). `RefCounted` с родителем: `Editor.new(self)` в `_init_later` **до** `_build_ui`. VTKUI остаётся диспетчером `refresh` (держит `RefreshScope`), редактор дёргает его через `_ui.refresh(...)`. Общие с редактором поля экипировки (`_equip_cells`/`_equip_cols`/`_equip_rows`/`_equip_styles`/`_inven_bg_style`) и `_build_equip_layout` **остались в VTKUI** — редактор читает их как `_ui.`. `RefreshScope.*` в редакторе заменены локальными константами `R_EQUIP/R_GEAR/R_DONE/R_OVERLAY/R_LIST/R_PREVIEW/R_PAGES` (1/2/4/8/16/32/15), потому что `RefreshScope` объявлен в VTKUI. `VTKSetsRail` зовёт `_ui._editor._make_equip_preview`/`_make_inventory_panel`. `layout_check` держит `PRESENT`/`FUNCS` по прежним именам. Фикс: кнопка хоткея на «Готово» держит стабильную `_ui._rail._done_bind_btn`, а не `_bind_btn` (та обнуляется в `_handle_bind_key` после первого захвата, и повторный клик уходил в `null`). VTKUI 2753 → 601 строка, VTKEditor 2174 строки. Тестов нет — UI-сборка без чистой логики.
- Телепорт обязан звать `Loader.SaveWorld()` **до** `Loader.LoadScene()`: при загрузке карты `Compiler.Spawn()` зовёт `Loader.LoadWorld()`, а тот восстанавливает `Simulation.*` (время/день/погоду) из `user://World.tres`. Без предварительной записи телепорт откатывает время к последнему сохранению мира (ванильный переход делает так же — `SAVE: World` перед сменой сцены). Проверяется по логу игры: `SAVE: World` должен идти **перед** `LOAD: World`.
- NVG-оверлей ставится событийно: `node_added`/`_reseed` находят ванильный `NVG.gd`, `.shader` подменяется по инспекции; если `Overlay` ещё не готов (await-based `_ready` ждёт ~0.1 c), работает ограниченный ретрай `INSTALL_RETRY_FRAMES` (~60 кадров). Ваниль никогда не переприсваивает материал — значит, per-frame re-inspect не нужен, установка повторяется только при пересборке карты. Кадровая покраска тепловизора выходит рано, когда `set_thermal` или `gameData.NVG` выключены; при off работает только дешёвый `_off_frame_upkeep` (чистит мёртвых и лэтчит death clock). `node_added` не дёргает `call_deferred` на каждый узел, а батчится в `_pending` (VTKNVG и VTKKillCounter) и разбирается раз за кадр. Кэш фракции живёт в записи бота (`friendly_resolved`), свип мешей — по смене `child_count`.
- `Picker.item_art` — кроп прозрачных полей иконки: `AtlasTexture` на **оригинальном** ресурсе (`filter_clip` снимает размытие по краю), кэш по `instance_id`. Живёт в `VTKPicker.gd` и покрыт headless-тестами, поэтому правило «VTKPicker — чистая логика» не нарушается: ни `load()`, ни путей внутрь игры — только `Texture2D`/`Image`, приходящие аргументом.
- `VTKNotes.gd` — чистая логика Notes (группировка по `resource_path`, признак сдачи по `TraderSave`, построение плиток иконок из переданных `Texture2D`): ни `load()`, ни путей внутрь игры, потому покрыт headless-тестом `test_notes.gd`. Карточки Notes — ванильный `Task.tscn`; мод добавляет ряд иконок через `augment_note`, не трогая сцену. Версию не дублирует.
- Категориальных цветов в UI мода нет. Остались только точки занятости в строке слота и подсветка активной строки фасета: палитра `_type_colors` удалена, потому что цвет не давал группе нового смысла и требовал держать словарь ради одной строки текста.
- От аннотаций на переменных-узлах зависит парсинг: `_page_columns` возвращает `HBoxContainer`, поэтому `_equip_box` и `_gear_box` объявлены как `HBoxContainer`, а не `VBoxContainer`, иначе Parse Error на присваивании. `_done_summary` после Task 8 — тоже `HBoxContainer`.
- `LineEdit.gui_input` Godot обрывает при потере фокуса, поэтому живой поиск вешается на `text_changed`, а не на `gui_input`. На `Control`-клетках `gui_input` работает и держится.
- Сплайс больших кусков `VTKUI.gd` делать только поиском конца **вперёд** от начала: секционные маркеры вроде `# ============== TAB:` встречаются и выше функции, и общий поиск по файлу вырезал полфайла. Откат — снапшот в `%TEMP%\opencode\vtk-snap-*`.
- Игровой класс `SlotData` в стенде — заглушка (`.check/project/stubs/SlotData.gd`). Остальные игровые сущности берутся через `get()` / `has_method()`, поэтому лишних ошибок анализатор не даёт.
- Подвох анализатора Godot 4: функция без аннотации возврата, у которой есть путь `return null`, получает тип `null`. Дальше `x["key"]` или `x.method()` — уже Parse Error, и скрипт целиком не грузится. Лечится явной аннотацией (`-> Variant`, `-> Node`).
- `Object.get()` принимает ровно один аргумент: `obj.get(name, default)` на игровом ресурсе (`SlotData`, `GameData`, itemData) в debug падает «Invalid call» и **обрывает** функцию, а в release лишний аргумент молча игнорируется — поэтому баг не виден в игре, но всплывает в headless-тестах. Для чтения свойства с фолбэком — `VTKData.prop(obj, name, default)` (годится и для `Dictionary`).
- Жёсткие пути внутрь игры (`/root/Map/Core/UI/Interface`, `inventoryGrid`, `SlotData`, группа `AISpawner`, `res://Scripts/Mine.gd`) ломаются при обновлениях. После апдейта игры проверять их первыми.
- Подкатегории берутся из `resource_path`, а таблица хранит только имена папок: жёсткие пути внутрь игры ломаются при апдейте. Магазин опознаётся суффиксом (`*_Magazine`, `*_Mag`, `*_Drum`), часть ствола — `*_Barrel`, потому что у `KAR-21` и `Makarov` папка одна на два смысла.
- `type` в данных игры не согласован: `Consumable` (2 предмета — `Energy_Drink`, `Water_Bottle`) рядом с `Consumables` (39), плюс у `Sticks` — `" Misc"` с ведущим пробелом. Поэтому `Picker.category_of()` делает `strip_edges().to_lower()` и прогоняет через `CATEGORY_ALIASES`. Иначе фасет «Еда» распадался на две строки: подпись берётся из `CATEGORY_LABELS` (`VTKUI.gd`), где есть только ключ `consumable`, и вторая строка показывала сырой `consumables`. Сводить надо в `category_of`, а не в подписи — иначе две строки с одинаковым именем останутся. Прогон `type` по всем 246 предметам делается headless-скриптом (см. следующий пункт).
- Реальные поля ресурсов игры (`size`, `capacity`, `type`, `subtype`, `slots`) читаются headless, без запуска игры: `D:\RTVMOD\RTVcopy\extracted` — это полноценный Godot-проект (в корне `project.binary`), и `Godot_*_console.exe --headless --path "D:\RTVMOD\RTVcopy\extracted" -s <скрипт>.gd` его поднимает. Файлы на диске лежат как `.tres.remap`, поэтому обходить папки нужно по `*.tres.remap`, а грузить путь без `.remap`. Пара `.tres`, зависимая от музыкальных треков, в копии не резолвится — её ошибки на выхлопе можно игнорировать.
- Детокенизированные исходники игры пишет сам modloader: `%APPDATA%\Road to Vostok\modloader_hooks\vanilla\Scripts\*.gd` (функция `_detokenize_script`). Это **настоящий** исходник игры, не дамп строк: по нему сверять ванильные методы, сигнатуры и порядок полей. Источник — кэш modloader'а; для данных ресурсов (`.tres`) по-прежнему `RTVcopy/extracted`.
- У `ScrollContainer` минимальная высота 0: содержимое скроллится, а сам он место не занимает. Высоту область под предметы получает только от `custom_minimum_size` либо от вертикального `SIZE_EXPAND_FILL`, и флаг обязан дойти по всей цепочке до `_editor_panel` — снимать его с промежуточного контейнера нельзя. Потеря флага схлопывает полки в ноль, и сетка пропадает целиком при полностью рабочих данных; стенд это не ловит, потому что парсинг и тесты проходят. Отсюда два независимых требования: растягивание (`_page_wrap`, `_page_columns`) и пол по высоте (`shelves_scroll.custom_minimum_size`). Проверяется списком `FUNCS` в `layout_check.py` — по телу функции, а не по вхождению строки в файле.
- Слоты `Primary`/`Secondary` в игре занимает не только оружие: удилище (`type = Fishing`), гитара и губная гармошка (`type = Instrument`) тоже помечены ими, поэтому без правила `Picker.category_allowed` в фильтр шага 1 к `Weapons` доезжали лишние чипы. Правило живёт в `VTKPicker.gd`, а не в `VTKUI.gd`, чтобы тестироваться headless.
- Левая колонка шага «Экипировка» с 4.9.0 — сетка с силуэтом тела (S1): широкие клетки оружия `_make_weapon_cell`, зона тела с прозрачными клетками поверх силуэта `_make_body_zone` + `BodySilhouette` (Panel'ы со `StyleBoxFlat`, без текстур), мелкие слоты `_make_equip_cell`. Раскладка (какие слоты в какой зоне) — `Picker.equip_layout()` в `VTKPicker.gd`, чистая и headless-тестируемая: UI берёт зоны из неё, а не держит свой список слотов. Клетки прозрачны (рамка `_equip_cell_style`), силуэт просвечивает; высота зоны тела запечена (4×`EQ_CELL_H` + 3×`EQ_GAP`), иначе `GridContainer` схлопнул бы ряды. Клик по клетке — тот же `_on_slot_row_input`, занятая получает ✕ сверху слева.
- `VTKLoc.gd` держит только живые ключи: `keycheck.py` помечает неиспользуемые как stale, и их можно удалять. Перенос шага 1 на сетку (4.9.0) оставил без потребителя ключ `Slots` — его удалили.
- Число колонок сетки считается от ширины в `_make_grid_columns`, а не задаётся константой: `GridContainer` без пересчёта давал четыре колонки в любом окне. Пересчёт вешается на `resized`, иначе на первом показе ширина нулевая и получается одна колонка.
- Файлы `.gd` хранятся в UTF-8. PowerShell-консоль искажает кириллицу при выводе, поэтому текст читать байтами или через UTF-8 report-файл, а не глазами по консоли.
- Мод уже один раз пострадал от двойного кодирования: русский текст прошёл через cp1251 и стал `РЎРµС‚`. Симптомы: `С„`, `Р°`, `вЂ”`. Починка — `s.encode('cp1251').decode('utf-8')`, но часть строк бывает смешанной с C1-управляющими (`U+0098`) и такой round-trip не проходит, их приходится чинить руками. Любой новый русский текст проверять сканером, а не на глаз.