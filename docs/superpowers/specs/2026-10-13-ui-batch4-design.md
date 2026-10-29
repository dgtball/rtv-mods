# Batch 4 — UI-пересборки: единый refresh, дебаунс поиска, кэши, скелет клеток, снятие спавнера

Дата: 2026-10-13
Статус: дизайн утверждён владельцем; спецификация готова к ревью.
Ветка: `audit`.
Источник задач: `docs/audit/vostok-toolkit-4.15.1.md` — S4, P1d, P2a, P2g, S2 (§ UI-пересборки, батч 4, строки 275-281). Плюс решение владельца: снять кнопку спавна в клетке снаряжения.

## Цель

Убрать лишнюю работу при перерисовке UI: сейчас любой чих (шаг `±` в клетке
снаряжения, закрытие панели обвесов, каждый символ поиска) пересобирает больше
узлов, чем нужно, заново считает чистую раскладку и аллоцирует стили. Внешний
вид и поведение не меняются — меняется только объём и частота пересборки.

Шесть правок:

1. **S4** — единый вход `refresh(scope)` с битмаской вместо алиасов
   `_refresh_all`/`_refresh_draft_ui`/`_refresh_pages`/`_refresh_page_gear`.
2. **P1e** (внутри S4) — `_bump_gear` перестаёт пересобирать все страницы,
   обновляет только `GEAR | DONE`.
2. **P1d** — живой поиск дебаунсится, пересборка не на каждый символ.
3. **P2a** — `Picker.equip_layout(Picker.all_slots(...))` считается один раз.
4. **P2g** — `StyleBoxFlat` клеток мемоизируются; фоновые ячейки стены делят стиль.
5. **S2** — общий скелет иконки для клеток предмета/обвеса + общий `TextureRect`.
6. **Спавнер** — удалить кнопку «В инвентарь»/«В каталог» и её путь `_spawn_gear` → `VTKData.spawn_gear`.

Все правки сохраняют видимое поведение, кроме одного намеренного: пропадает
кнопка спавна предмета в обход сэта.

## Что выяснено (факты)

Номера строк — по состоянию `VTKUI.gd` на момент дизайна (3455 строк).

- **Алиасы пересборки**:
  - `_refresh_all` (565) = `_refresh_loadout_list()` + `_refresh_draft_ui()`.
  - `_refresh_draft_ui` (2415) = `_refresh_pages()`, с комментарием: имя оставлено
    ради `_bump_gear`/`_toggle_attachment_panel`.
  - `_refresh_pages` (1559) = `_refresh_page_equipment` + `_refresh_page_gear` +
    `_refresh_page_done` + `_refresh_att_overlay`.
  - `_refresh_page_equipment` (1565) = `_rebuild_target_bar` + `_refresh_slots` +
    `_rebuild_shelves`.
  - `_refresh_page_gear` (1220) → `_refresh_gear_catalog` (1287).
  - `_refresh_loadout_list` (2316) **внутри** зовёт `_refresh_preview()` (2339 и 2401).
- **Потребители (грепом)**: 239 `_refresh_all`; 289 `_refresh_loadout_list`
  (`_end_bind`: чужой бинд снят); 554 `_refresh_att_overlay` (`_show_page`);
  745 `_refresh_preview` (старт, `_build_ui`); 878/880 `_refresh_pages`+
  `_refresh_preview` (каркас редактора); 1022 `_refresh_att_overlay`; 1254/1274
  `_refresh_pages`; 1282 `_refresh_gear_catalog` (`_set_gear_search`); 1355/1429/1443
  `_refresh_gear_catalog` (фасеты); 2055/2059/2064 `_refresh_pages` (сброс/смена цели);
  2146 `_refresh_pages` (`_remove_slot`); 2158 `_refresh_pages` (`_set_target_slot`);
  2410 `_refresh_loadout_list` (`_select_set`); 2435 `_refresh_draft_ui` (`_bump_gear`);
  2452 `_refresh_draft_ui` (`_toggle_attachment_panel`); 2476 `_refresh_draft_ui`
  (`_close_att_overlay`); 2730 `_refresh_pages` (`_after_place`); 2923 `_refresh_pages`
  (тумблер обвеса); 2959 `_refresh_pages` (тумблер обоймы); 3096/3138/3157
  `_refresh_loadout_list`.
- **Поиск**: `_set_search` (2160) пишет `_search_text`, зовёт `_validate_target_filters()`,
  `_rebuild_shelves()`, `_rebuild_target_bar()`. Поле поиска не пересоздаётся
  (текст навешан на `text_changed`), поэтому фокус держится.
- **Кэш раскладки**: `Picker.equip_layout(Picker.all_slots(lists))` считается заново
  в `_refresh_slots` (1586) и `_make_equip_preview` (1738), оба раза из `_db_items`.
  `_load_items()` зовётся один раз на старте (213) — каталог меняется только там.
- **Стили**: `_equip_cell_style` (1595) создаёт новый `StyleBoxFlat` на вызов; в
  клетке вызывается дважды (1622 основной + 1644 hover-колбэк). `_make_inventory_wall`
  (1793) создаёт `StyleBoxFlat` на **каждую** из `rows * INVEN_COLS` фоновых ячеек
  (1812-1821, цвет `#14110c`). Стена может существовать одновременно дважды
  (превью списка и Done) — кэширование **узла** bg-сетки дало бы двойного родителя.
- **Скелет клеток**: `_make_item_cell` (2498) и `_make_att_cell` (2862) собирают
  одинаковую цепочку Panel→CenterContainer(PRESET_FULL_RECT)→VBox→TextureRect→Label
  и грузят иконку через `Picker.item_art`. `_wall_item` (1759) — своя якорная
  раскладка (TextureRect на FULL_RECT + подпись количества в углу), общего стека нет.
- **Спавнер**: ряд В в `_make_item_cell` (2613-2624) создаёт кнопку «В инвентарь»
  / «В каталог» (по `type == "furniture"`), зовёт `_spawn_gear` (2439-2445) →
  `VTKData.spawn_gear` (397-420). `_spawn_gear` больше нигде не вызывается.
- **`layout_check.py`** пинит: PRESENT `"_spawn_gear"` (246), PRESENT
  `"Spawn into inventory"` (251); FUNCS `_make_item_cell` = [ `Loc.txt("Spawn into
  inventory")`, `PRESET_TOP_RIGHT` ] (311-314); FUNCS `_set_search` =
  [`_validate_target_filters()`] (304-305); FUNCS `_refresh_slots` =
  [`Picker.equip_layout`, `_make_equip_grid`] (327-330); FUNCS `_wall_item` =
  [`Picker.item_art`] (335-337). `_spawn_gear` и `"Spawn into inventory"` попадут в
  GONE-контроль (возврат кнопки ловится стендом).
- **`test_spawn.gd`** (`.check/project/tests/`) покрывает `spawn_gear`,
  `_is_furniture`, `_insert_desc`, `_instances`, `_find_free_slot`, `_equip_sd`.
  `_is_furniture` **остаётся** (нужен `_insert_desc` → маршрут в каталог, VTKData:368);
  `_insert_desc`/`_instances`/`_find_free_slot`/`_equip_sd`/`_notify` остаются
  (путь `apply_loadout`). Уходит только `spawn_gear`.
- **Осиротевшие Loc-ключи** после снятия спавнера: `Spawn into inventory`,
  `Spawn into catalog`, `Spawned: `, `Spawned to catalog: `. Ключи
  `→ In inventory: ` / `→ To catalog: ` (VTKLoc 14-15) — это отчёт `apply`, они
  **остаются**.
- **`check.ps1`** держит `$tests` явным списком (строка 80); тесты кладутся в
  `.check/project/tests/`, имя `test_spawn.gd` завязано на заметку AGENTS.

## Раздел 1 — S4 + P1e: единый scoped refresh

Ввести вложенный класс-пространство констант и единственный вход:

```gdscript
class RefreshScope:
	const EQUIP := 1      # target bar + сетка экипировки + полки
	const GEAR := 2       # фасеты + каталог снаряжения
	const DONE := 4       # страница Done
	const OVERLAY := 8    # панель обвесов
	const LIST := 16      # рейл сэтов
	const PREVIEW := 32   # правая колонка превью
	const PAGES := EQUIP | GEAR | DONE | OVERLAY

func refresh(scope: int) -> void:
	if scope & RefreshScope.EQUIP: _refresh_page_equipment()
	if scope & RefreshScope.GEAR: _refresh_gear_catalog()
	if scope & RefreshScope.DONE: _refresh_page_done()
	if scope & RefreshScope.OVERLAY: _refresh_att_overlay()
	if scope & RefreshScope.LIST: _refresh_loadout_list()
	if scope & RefreshScope.PREVIEW: _refresh_preview()
```

- Удаляем `_refresh_all`, `_refresh_draft_ui`, `_refresh_pages`, `_refresh_page_gear`.
  `_refresh_page_equipment`/`_refresh_page_done`/`_refresh_att_overlay`/
  `_refresh_gear_catalog`/`_refresh_slots` остаются приватными рабочими функциями.
- Из `_refresh_loadout_list` убираем внутренние `_refresh_preview()` (2339, 2401):
  превью становится явной областью. Вызовы `LIST` дополняются `PREVIEW` там, где
  превью сейчас ожидается.
- Ремап вызовов (узкое вместо полного, где это доказано составом):

| Строка | Было | Станет | Почему |
|---|---|---|---|
| 239 | `_refresh_all()` | `refresh(PAGES | LIST | PREVIEW)` | панель открыта — всё |
| 289 | `_refresh_loadout_list()` | `refresh(LIST | PREVIEW)` | карточка сета + превью |
| 554, 1022 | `_refresh_att_overlay()` | `refresh(OVERLAY)` | панель обвесов |
| 745 | `_refresh_preview()` | `refresh(PREVIEW)` | старт, до постройки страниц |
| 878/880 | `_refresh_pages()`+`_refresh_preview()` | `refresh(PAGES | PREVIEW)` | каркас редактора |
| 1254, 1274 | `_refresh_pages()` | `refresh(PAGES)` | состав набора |
| 1282 | `_refresh_gear_catalog()` | `refresh(GEAR)` | поиск по каталогу снаряжения |
| 1355, 1429, 1443 | `_refresh_gear_catalog()` | `refresh(GEAR)` | фасеты снаряжения |
| 2055, 2059, 2064 | `_refresh_pages()` | `refresh(EQUIP)` | только цель/полки |
| 2146, 2158 | `_refresh_pages()` | `refresh(PAGES)` | консервативно |
| 2410 | `_refresh_loadout_list()` | `refresh(LIST | PREVIEW)` | `_select_set` |
| 2435 | `_refresh_draft_ui()` | `refresh(GEAR | DONE)` | **P1e**: шаг `±` |
| 2452, 2476 | `_refresh_draft_ui()` | `refresh(OVERLAY)` | тумблер/закрытие обвесов |
| 2730, 2923, 2959 | `_refresh_pages()` | `refresh(PAGES)` | консервативно |
| 3096, 3138, 3157 | `_refresh_loadout_list()` | `refresh(LIST | PREVIEW)` | save/edit/delete |

- Строки 2055/2059/2064 (сброс/set цели) сужены до `EQUIP` сознательно: они
  меняют `_target_cat`/`_target_sub`, влияющие только на `_rebuild_shelves` и
  чипы цели, а не на каталог снаряжения. Проверяется ручным чеком (фасеты шага 2
  не должны «залипать»).
- `_select_set` (2403-2410) сбрасывает черновик и в ветке-иначе зовёт
  `_refresh_loadout_list()`: после снятия внутреннего `_refresh_preview()` это
  должно стать `refresh(LIST | PREVIEW)` — иначе выбор сета без черновика
  оставит превью от прошлого сета.

Риск: пропущенная область → устаревший кусок UI (например, `±` не обновит
счётчик в сводке Done, если забыть `DONE`). Страховка — ручной чек-лист.

## Раздел 2 — P1d: дебаунс живого поиска

- Один `Timer` (дочерний узел, `one_shot = true`, `wait_time ≈ 0.12`), создаётся
  один раз в `_build_page_equipment`; `timeout` зовёт `_apply_search`.
- `_set_search(t)`: `_search_text = t`, `_search_debounce.start()`. Больше ничего.
- `_apply_search()`: `_validate_target_filters()`, `refresh(EQUIP)` (target bar +
  полки; поле поиска не пересоздаётся → курсор сохраняется).
- Поиск всё ещё «живой», но пересборка идёт не на каждый символ. Таймер один и
  переиспользуется — аллокаций на нажатие нет.

Риск: микро-задержка перед обновлением сетки (~0.12 c). Принято.

## Раздел 2а — P2a: кэш раскладки экипировки

- Поля `_equip_cells: Array`, `_equip_cols: int`, `_equip_rows: int`.
- `_load_items()` (213) в конце строит раскладку из `_db_items` один раз:
  списки `slots` всех предметов → `Picker.equip_layout(Picker.all_slots(lists))`
  → сохраняет `cells`/`cols`/`rows`.
- `_refresh_slots` (1570) и `_make_equip_preview` (1734) читают поля вместо
  повторного вызова `Picker.equip_layout(Picker.all_slots(...))`.
- Инвалидация не нужна: `_db_items` меняется только в `_load_items`.
- Функция-строитель (например `_build_equip_layout()`) зовётся из `_load_items`;
  если массив пуст (страховка на случай порядка инициализации) — строит по месту.

## Раздел 3 — P2g: кэш стилей

- `_equip_cell_style` мемоизируется в словаре `_equip_styles` по ключу
  `(active?1:0) | (hover?2:0) | (occupied?4:0)` — не более 8 комбинаций.
  Стили общие, но не мутируются: клетки только кладут их через
  `add_theme_stylebox_override`.
- `_make_inventory_wall` использует один общий `StyleBoxFlat` для всех фоновых
  ячеек вместо `StyleBoxFlat.new()` в цикле (1817-1820), сняв 64+ аллокации на
  каждую сборку стены.
- Кэш узла bg-сетки **не делаем** (двойной родитель при одновременных превью и
  Done). При смене темы/палитры в рантайме кэш не инвалидируется — палитра
  статична на сессию.

## Раздел 4 — S2: общий скелет клеток

- `_icon_stack(host: Control, art: Texture2D, icon_min: Vector2, name_text: String,
  name_size: int, name_color: Color, name_lines: int) -> VBoxContainer` — создаёт
  CenterContainer(FULL_RECT), VBox, `_art_texture_rect(art, icon_min)` и подпись;
  возвращает VBox, чтобы клетка дописала свои ряды (`_make_item_cell` — счётчик,
  «− n +», ✕; `_make_att_cell` — ничего сверх).
- `_art_texture_rect(art: Texture2D, min_size: Vector2) -> TextureRect` —
  TextureRect со `STRETCH_KEEP_ASPECT_CENTERED`, `EXPAND_IGNORE_SIZE`,
  `size_flags_horizontal = SIZE_SHRINK_CENTER`, `mouse_filter = IGNORE`, с уже
  применённым `Picker.item_art`. Используется и `_wall_item` (общая часть — только
  эта функция; у `_wall_item` остаётся своя якорная раскладка).
- `_make_item_cell` и `_make_att_cell` переводятся на `_icon_stack`. Текст подписи
  и цвет остаются параметрами (у att — `#aaa`/серый, у item — имя предмета).

## Раздел 5 — снятие спавнера

- `_make_item_cell`: удалить ряд В (2613-2624) — кнопку `spawn_btn`, переменную
  `is_furn`, локальный текст. Высоту in-draft gear-клетки `192` (2507) уменьшить
  под два оставшихся ряда; точное значение подбирается и **проверяется в игре**
  (стенд высоты не видит). Ориентир — 168-176.
- `VTKUI.gd`: удалить `_spawn_gear` (2438-2445).
- `VTKData.gd`: удалить `spawn_gear` (393-420) вместе с его комментарием.
- `VTKLoc.gd`: удалить ключи `Spawn into inventory`, `Spawn into catalog`,
  `Spawned: `, `Spawned to catalog: `. Ключи `→ In inventory: `/`→ To catalog: `
  и функцию `_is_furniture` сохранить.
- `test_spawn.gd`: удалить `t_spawn_no_game` (единственная точка, зовущая
  `spawn_gear`) и её вызов из `_run`. Остальные тесты остаются. Имя файла не
  меняем (минимум шевеления в `check.ps1`/AGENTS); при желании — отдельным шагом.

## Стенды

- **`layout_check.py`** правим осознанно:
  - PRESENT → GONE: `"_spawn_gear"` (246), `"Spawn into inventory"` (251) —
    добавлением в `GONE`-набор; возврат кнопки/функции ловится стендом.
  - FUNCS `_make_item_cell` (311): убрать `Loc.txt("Spawn into inventory")`,
    оставить `PRESET_TOP_RIGHT` (✕ в углу).
  - FUNCS `_set_search` (304): требование `_validate_target_filters()` переезжает
    на `_apply_search`; для `_set_search` пин — `_search_debounce`.
  - FUNCS `_refresh_slots` (327): `Picker.equip_layout` переезжает на строитель
    кэша (`_build_equip_layout`/`_load_items`); для `_refresh_slots` остаётся
    `_make_equip_grid` + обращение к кэшу.
  - FUNCS `_wall_item` (335): `Picker.item_art` переезжает на `_art_texture_rect`;
    для `_wall_item` оставить признак якорной раскладки (`STRETCH_KEEP_ASPECT_CENTERED`).
  - Добавить PRESENT для `refresh(`/`RefreshScope` (новый вход должен существовать).
- **`check.ps1`**: список `$tests` (80) не меняется по составу файлов; `test_spawn.gd`
  остаётся, но короче. Гейт: нет `SCRIPT ERROR`/`Parse Error` / `Invalid call` /
  `Failed to load script`, есть `tests passed`, код 0.
- Новых headless-тестов не заводим: правки — узлы/сцена, чистой логики не
  появляется; `RefreshScope` — константы. Существующие тесты обязаны остаться
  зелёными.

## Ручная проверка в игре

1. Шаг `±` в клетке снаряжения: число в клетке и в сводке Done обновляются, прочие
   страницы не мигают.
2. Поиск отзывчив, курсор не теряется, фильтры-чипы и полки сужаются.
3. Панель обвесов открывается/закрывается, превью списка и Done рисуются.
4. Высотa клетки снаряжения без пустого низа.
5. Кнопки «В инвентарь»/«В каталог» нет ни на одной клетке; сдача (deposits) и
   Apply сэта работают.
6. Переключение сэтов/страниц/фасетов — без пустых или залипших областей.

## Версия и файлы

- Версия `4.16.2 → 4.16.3` (patch: пересборки, видимого поведения не меняем, кроме
  намеренного снятия кнопки). Затрагиваются `loadouts/mod.txt`,
  `loadouts/mods/VTK/version.txt`, `README.md` (синхронит `pack.ps1`), `CHANGELOG.md`:
  `### Changed` — «Minor performance improvements and internal cleanup.»,
  `### Removed` — «the "Spawn into inventory/catalog" button on gear cells».
- Код: `loadouts/mods/VTK/VTKUI.gd` (основное), `loadouts/mods/VTK/VTKData.gd`
  (снятие `spawn_gear`), `loadouts/mods/VTK/VTKLoc.gd` (мёртвые ключи).
- Стенды (вне git): `.check/layout_check.py`, `.check/project/tests/test_spawn.gd`.
- `mod.txt` секция `[hooks]` не меняется: новых хуков нет.
- `AGENTS.md` (вне git): дополнить заметку о едином refresh и снятии спавнера.

## Вне области

- Батчи 5 (ванила-интеграция) и 6 (декомпозиция монолита).
- Разбиение `VTKUI.gd`, пул клеток (P3a), реестр путей (D6/D10).
- Кэш **узла** bg-сетки стены (отклонён: двойной родитель).
- Переименование `test_spawn.gd` (оставлено как есть).

## Решения владельца (recap)

- Объём: **S4 + P1d + P1e + P2a + P2g + S2** + снятие спавнера.
- Refresh-API: **битмаска int** (`RefreshScope`).
- S2: **общий скелет-хелпер**, а не полная фабрика с параметрами.
- Спавнер: снять; `test_spawn.gd` чистим, имя не меняем; высота клетки — на ручную
  проверку.
