# Реворк вкладки Notes: иконки предметов + автоочистка сданных (4.11.0)

Дата: 2026-10-09.
Статус: принято (brainstorming с пользователем, макет `docs/mockups/notes-icons/index.html`).
Область: только игровая вкладка Notes. Частичная сдача квестов — отдельное ТЗ, сюда не входит.

## Цель

Две правки во вкладке Notes игры (Tools → Notes, `Interface._on_notes_pressed` → `InitializeNotes`):

1. **Иконки вместо текста.** В карточке заметки (`Task.tscn`) вместо строк `Deliver: item, item, item`
   и `Receive: ...` — ряд иконок предметов (вариант A макета): иконка + бейдж `×N` при нескольких
   одинаковых, название предмета в тултипе.
2. **Автоочистка.** Сданный квест исчезает из Notes: сразу в момент сдачи и, как страховка,
   при каждом открытии вкладки.

## Контекст игры (что выяснено)

- `InitializeNotes()` заново создаёт карточки на каждое открытие вкладки: чистит `notesList`,
  берёт `Loader.LoadTaskNotes()`, сортирует по `trader`, для каждой задачи инстанцирует `Task.tscn`,
  кладёт в `notesList`, зовёт `newTask.InitializeNote(taskData, self)` и `newTask.Note()`.
- `TaskData` (`res://Scripts/TaskData.gd`): `trader`, `name`, `difficulty`, `description`,
  `deliver: Array`, `receive: Array`. `deliver`/`receive` — массивы `ItemData`; количество кодируется
  повторами (`["Saline","Saline","Saline"]` = 3 шт). У части задач (`Nordic Pine`, `Getting Hot`, …)
  оба массива пусты — они завершаются не сдачей предметов.
- `ItemData` несёт `icon: CompressedTexture2D`, `resource_path`, `name`.
- Прогресс: `user://Traders.tres` (`TraderSave`) хранит `taskNotes: Array[TaskData]` (заметки) и
  списки сданных имён по торговцам: `generalist`, `doctor`, `gunsmith`, `driver`, `hunter`, `grandma`.
  `taskData.trader` («Doctor», «Generalist», …) совпадает с именем списка в нижнем регистре.
- `Trader.CompleteTask(taskData)` добавляет `taskData.name` в список торговца и сохраняет его;
  из `taskNotes` задачу **не** удаляет — отсюда и «зависшие» заметки.
- Карточка `Task.tscn`:
  `PanelContainer → [Highlight, Margin → Elements → Title(+Add/Remove), Difficulty, Description,`
  `Input(Label "Deliver:" + ребёнок Items Label), Input_Grid, Output(+Items), Output_Grid, Hint, Buttons]`.
  В режиме заметки показывается текстовый `Items`; гриды — слоты сдачи у торговца.
- `Loader.SaveTaskNotes(task, add)` / `Loader.LoadTaskNotes()` — API заметок; удаление опознаёт
  задачу по идентичности ресурса (`taskNotes.has(task)`), а ресурсы кэшируются по пути, поэтому
  задача из UI торговца и из `taskNotes` — один и тот же инстанс.

## Точка интеграции

Хуки RTVModLib (мода-лоадер, `modloader.gd`), регистрируются в `VTKHooks._do_register()` рядом
с существующими четырьмя:

- `interface-initializenotes-post` — метод void; колбэк без аргументов, `_lib._caller` = узел `Interface`.
- `trader-completetask-post` — `CompleteTask(taskData)`; колбэк получает `task_data`, `_lib._caller` = узел `Trader`.

Ограничения механизма (соблюдены):

- Имя хука — `<скрипт>-<метод>-pre|post` в нижнем регистре; регистрация сама метод не оборачивает.
  Wrap-surface фиксируется при `_generate_hook_pack` сканированием **литеральных** `.hook("...")`
  в исходниках мода — поэтому имена задаём строковыми литералами, как и текущие.
- Оба метода void → колбэки без завершающего `_result` (на void-обёртках диспатчится `_dispatch`, не `_dispatch_post`).

## Новый модуль `VTKNotes.gd`

Префикс `VTK`, как остальные сущности. Делится на чистую логику (headless, по образцу `Picker`/`Draft`)
и склейку с деревом. Доступ к игровым объектам — через `get(...)` (как `KC._is_agent`), чтобы
чистая часть тестировалась без ресурсов игры.

Чистая логика (без узлов):

- `group_items(items: Array) -> Array` — группирует `deliver`/`receive` по `resource_path`
  (fallback — `name`), сохраняет порядок первого появления, возвращает `[{ "item", "count" }]`.
- `completed_lists(traders) -> Dictionary` — читает шесть списков (`traders.get("generalist", [])`
  и т.д.) в `{trader_lower: {task_name: true}}`.
- `is_completed(task_data, completed) -> bool` — `completed.get(str(task_data.get("trader")).to_lower(), {}).has(task_data.get("name"))`.
- `find_note(notes: Array, task_data) -> Variant` — первый элемент `notes`, совпавший по `name`+`trader` (для точной идентичности при удалении).
- `badge_text(count: int) -> String` — `×N` при `N > 1`, иначе пусто.

Склейка с деревом (нужен рантайм; headless не тестируется):

- `augment_note(card: Node) -> void` — находит `Margin/Elements`; для секций `Input` и `Output`
  скрывает вложенный текст `Items` (и гриды `Input_Grid`/`Output_Grid`, если видны) и вставляет ряд
  иконок сразу после соответствующего заголовка. Пустой список — секцию не трогаем.
- `build_icon_row(entries: Array) -> Control` — `HFlowContainer`; плитка: контейнер 52×52 с
  `TextureRect` иконки, `Label` бейджа (`×N`, если >1) и `tooltip_text` = имя предмета. Без иконки —
  текстовый фоллбэк по имени.
Обход `notesList` и удаление сданных (через `Loader`) живут в `VTKHooks._on_notes_rendered`:
`VTKNotes` остаётся без `load()` и путей внутрь игры, а доступ к `/root/Loader` — в хуке (как сейчас).

Карточка `Task` отдаёт ссылки напрямую: `taskData`, `inputItems`, `outputItems`, `inputGrid`, `outputGrid`.

## Поведение

### Отрисовка (`interface-initializenotes-post`)

1. `notes = Loader.LoadTaskNotes()`, `traders = load("user://Traders.tres")`,
   `completed = VTKNotes.completed_lists(traders)` (при `traders == null` — пустой словарь).
2. Для каждой карточки `notesList`: `task_data = card.get("taskData")`.
   - если `is_completed(task_data, completed)`: `inst = find_note(notes, task_data)`, при `inst != null`
     → `Loader.SaveTaskNotes(inst, false)`; затем `card.queue_free()`;
   - иначе `augment_note(card)`.
3. Заголовки `Deliver:`/`Receive:` (`Input`/`Output` Label) остаются; скрывается только текст `Items`.
4. Ряд иконок — `HFlowContainer` (перенос длинных списков), плитка: иконка, `×N`, тултип.

### Автоочистка (две точки)

- **Немедленно:** `trader-completetask-post(task_data)` → `inst = find_note(Loader.LoadTaskNotes(), task_data)`,
  при находке `Loader.SaveTaskNotes(inst, false)`. (Карточки в этот момент нет — Notes не открыт при
  сдаче; чистим только данные.)
- **Страховка:** та же проверка внутри `interface-initializenotes-post` (см. выше). Ловит задачи,
  завершённые в обход `Trader.CompleteTask` (событийные/локационные), и заметки, оставшиеся от
  сессий до установки мода.

Доступ к `Loader` — `get_node_or_null("/root/Loader")`, вызов `SaveTaskNotes` через `call`
(шаблон из `VTKHooks`).

## Края и устойчивость

- Задача без `deliver`/`receive` — карточка не меняется (ванильный вид).
- Предмет без иконки — текстовый фоллбэк по имени.
- Больше 7 разных предметов — перенос строк (`HFlowContainer`), фиксированного числа слотов нет.
- Имена предметов не локализуются (из `Database`; правило AGENTS).
- Чужой мод на тот же хук — оба post-колбэка выполнятся (post-слот не эксклюзивен).
- Ноды и поля достаём через `get_node_or_null`/`get(...)`: отсутствие узла или поля — тихий пропуск.
- Нет `user://Traders.tres` — `LoadTaskNotes`/`SaveTaskNotes` выходят сами; UI-путь не падает.

## Тесты и стенды

- Чистая часть `VTKNotes` — headless `test_notes.gd`: группировка и порядок `group_items`, counts,
  `completed_lists`/`is_completed`/`find_note`, `badge_text`. Добавить в список тестов `.check/check.ps1`.
- `python .check\layout_check.py` и `.check/check.ps1` — зелёные.
- UI-склейка и хуки — рантайм-пути: проверка в игре вручную (иконки Deliver/Receive, очистка при
  сдаче и при открытии).

## Версия и файлы

- Версия `4.10.3 → 4.11.0` (новая функциональность, обратная совместимость сохранена):
  `loadouts/mod.txt`, `loadouts/mods/VTK/version.txt`, `README.md`.
- Новый `loadouts/mods/VTK/VTKNotes.gd`.
- `loadouts/mods/VTK/VTKHooks.gd` — +2 хука и колбэки (ссылки на id держим рядом с `_hooks_kc`).
- Новый `.check/project/tests/test_notes.gd`; строка в списке тестов `.check/check.ps1`.
- `AGENTS.md` — новый файл `VTKNotes.gd` (префикс, роль, тестируемость); синхронизировать заметку
  о числе `preload`, если новый `const` появится в `VTKHooks.gd`.

## Вне области

- Частичная сдача квестов уровня PartialTasks — отдельное ТЗ (следующий цикл brainstorming).
- Пересборка самой карточки заметки (заголовок, сложность, описание, кнопка Remove) — не трогаем.
- Локализация имён предметов.
