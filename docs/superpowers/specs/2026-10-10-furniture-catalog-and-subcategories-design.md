# Мебель в пикере: подкатегории и спавн в каталог декора — дизайн

Статус: **предложено, ждёт ревью пользователя**.

## Проблема

1. Полка `Furniture` в шаге 2 «Снаряжение» плоская. `Picker.subcategory_of()`
   рано выходит на `type == "furniture"` (`VTKPicker.gd:381`) и возвращает `""`,
   поэтому чипов подкатегорий нет, а все 46 предметов идут одним списком.
   Ранний выход был поставлен, когда мебель не считалась содержимым сета;
   теперь её надо фильтровать.
2. Мебель спавнится не туда, где живёт в игре. Сейчас и `apply_loadout`, и
   `spawn_gear` кладут предметы в `interface.inventoryGrid` (рюкзак), между тем
   игра хранит мебель в **каталоге декора** (`interface.catalogGrid`) и
   размещает её из него. JCM (референс) для мебели зовёт
   `interface.Create(slotData, interface.catalogGrid, false)`, а для остального
   — `inventoryGrid`.
3. Обновление игры добавило 8 предметов, чьих папок нет в `SUB_FOLDERS` и
   `NO_SUB_FOLDERS`. Каждый даёт сырой одноразовый чип с именем папки.

## Решение A — подкатегории мебели (5 групп)

Новая таблица `FURN_SUB_FOLDERS` в `VTKPicker.gd`, ключ — папка ассета (второй
сегмент пути, у мебели это `res://Assets/<Папка>/...`), значение — имя группы.
Тот же приём, что `SUB_FOLDERS` для предметов, но отдельная таблица: у мебели
другая ветка путей и нет `NO_SUB_FOLDERS`/магазинных суффиксов.

| Группа (ключ = подпись) | Папки (ключи `FURN_SUB_FOLDERS`) | N |
|---|---|---|
| `Storage & Cabinets` | Bookshelf, Cabinet_Medical, Cabinet_Office, Cabinet_Wood, Crate_Military, Crate_Special, Cupboard, Locker, Nightstand | 9 |
| `Seating & Beds` | Bed_Civilian, Bed_Nomad, Bench_Campsite, Chair_Office, Chair_School, Chair_Sun, Sofa_Leather, Stool_Military, Stool_Padded | 9 |
| `Tables & Shelving` | Shelf_Wood, Shelf_Wall, Shelf_Metal, Table_Cabin, Table_Canteen, Table_Kitchen, Table_Office | 7 |
| `Appliances & Electronics` | Fridge, Freezer, Stove, Radio, Television | 5 |
| `Decor` | Calendar, Carpet, Curtains, Dartboard, Painting, Posters, Rack_Coat, Rya, Sign_Border_Zone, Trolley, Pallet, Target_Stand, Weapon_Display | 16 |

Итого 46 — вся мебель из данных (тип `Furniture`).

Изменения в `VTKPicker.gd`:

- `subcategory_of`: вместо раннего `return ""` ветка для furniture — взять
  папку (второй сегмент пути) и вернуть `FURN_SUB_FOLDERS.get(папка, "")`;
  неизвестная папка остаётся без чипа, как и у предметов.
- `SUBCATEGORY_ORDER`: убрать оговорку «минус FURNITURE» в комментарии, в конец
  списка добавить пять имён групп, чтобы порядок чипов внутри полки был
  фиксирован, а не по алфавиту.
- `CATEGORIES`: добавить `["furniture", "Furniture"]` в конец — явная подпись и
  локализация полки вместо `capitalize()`.

## Решение B — спавн мебели в `catalogGrid`

Мебель экипировать нельзя (`slots = []`), поэтому правка не касается
equip-ветки `apply_loadout`.

- Новый хелпер `_is_furniture(res)` в `VTKData.gd`:
  `str(res.get("type")).strip_edges().to_lower() == "furniture"`.
- `_insert_desc` (`VTKData.gd:474`): по `gsd.itemData` определить мебель. Для
  мебели — цель `interface.get("catalogGrid")`, вызов
  `interface.Create(gsd, catalogGrid, false)` без `AutoStack` (мебель
  нестекуемая, автостек ей не нужен). Для остального — прежний
  `_insert(interface, ig, gsd)`.
- Если `catalogGrid` нет или невалиден (каталог ещё не открывался) — тихий
  фолбэк в `inventoryGrid` тем же путём, что обычные предметы, чтобы предмет не
  пропал.
- `spawn_gear` (`VTKData.gd:493`) цель не выбирает сам — она внутри
  `_insert_desc`, поэтому отдельная правка не нужна; меняется только подпись
  уведомления для мебели.
- Подпись кнопки: в `_make_item_cell` (`VTKUI.gd:2636`) для мебели
  `Loc.txt("Spawn into catalog")` вместо `Loc.txt("Spawn into inventory")`.
- Уведомление `spawn_gear`: для мебели `Loc.txt("Spawned to catalog: ")`,
  для остального — прежнее `Loc.txt("Spawned: ")`.
- В `apply_loadout` счётчики считаются по `inventoryGrid`; мебель в каталоге в
  них не попадёт. Добавить отдельный счётчик вставок в каталог и дописать его в
  сообщение `Loc.txt(" · To catalog: ")` (иначе мебель «теряется» в отчёте).

## Решение C — одноразовые чипы (8 предметов)

Все — новые папки обновления; добавляются записи в `SUB_FOLDERS`:

| Предмет | Папка | Тип игры | Группа |
|---|---|---|---|
| Hand Warmer | Hand_Warmer | Medical | `Utility` |
| Suitcase (Driver) | Suitcase_Driver | Lore | `Lore` |
| Air Freshener | Air_Freshener | Misc | `Utilities & Tools` |
| Glue | Glue | Misc | `Utilities & Tools` |
| Leather | Leather | Misc | `Utilities & Tools` |
| Museum Plate | Museum_Plate | Misc | `Utilities & Tools` |
| Radiator Engine | Radiator_Engine | Misc | `Utilities & Tools` |
| Screws | Screws | Misc | `Utilities & Tools` |

Обоснование по данным: `Suitcase_Driver` — `type="Lore"`, лежит в
`Items/Lore/`, подключён как мировой лут (`Loot/Lore/LS_Suitcase_Driver.tscn`).
`Museum_Plate` — `type="Misc"`, ни к чему не подключён; отнесён в общую корзину
`Utilities & Tools` по решению пользователя. После правки сырых чипов в
каталоге не остаётся.

## Локализация

Новые ключи в `VTKLoc.gd` (английский — ключ):

- Полка: `Furniture` → `Мебель`.
- Группы: `Storage & Cabinets`, `Seating & Beds`, `Tables & Shelving`,
  `Appliances & Electronics`, `Decor`.
- Спавн: `Spawn into catalog`, `Spawned to catalog: `, ` · To catalog: `.

`keycheck.py` ловит рассинхрон ключ/словарь; после правки прогнать.

## Точки изменений

| Что | Где |
|---|---|
| `FURN_SUB_FOLDERS`, ветка в `subcategory_of`, `CATEGORIES`, `SUBCATEGORY_ORDER` | `VTKPicker.gd` (51, 152, 376–407) |
| 8 записей новых папок | `VTKPicker.gd` `SUB_FOLDERS` (168) |
| `_is_furniture`, маршрут в `catalogGrid`, счётчик каталога/уведомления | `VTKData.gd` (474, 493, 432) |
| Подпись кнопки «Spawn into catalog» | `VTKUI.gd:2636` |
| Новые строки | `VTKLoc.gd` |

## Проверка

- `test_picker.gd`: для нескольких мебельных папок (`Radio`, `Bed_Civilian`,
  `Carpet`, `Weapon_Display`) `subcategory_of` даёт ожидаемую группу; неизвестная
  папка даёт `""`; каждое имя из `FURN_SUB_FOLDERS` присутствует в
  `SUBCATEGORY_ORDER`. Плюс кейсы на 8 новых записей (`Hand_Warmer` → `Utility`
  и т. д.).
- `py .check\layout_check.py`, `check.ps1` — парсинг и тесты.
- Ручная проверка в игре: мебель из шага 2 и из сохранённого сета попадает в
  каталог декора, а не в рюкзак; подкатегории мебели фильтруют список.
- Версия в `loadouts/mod.txt` поднимается (minor: новая функциональность).

## Отклонено

- Деление мебели по комнатам/темам (Kitchen/Bedroom/Office) — спорные предметы,
  выбран подход «по функции».
- 4 группы как в JCM (без `Appliances & Electronics`, TV/Radio в Decor) —
  пользователь выбрал 5 групп.
- Разбиение Misc на `Survival`/`Materials` как в JCM — пользователь выбрал
  свернуть новые папки в существующие группы.
- Исключение мебели из пикера — мебель остаётся, меняется только место спавна.
