# Furniture: подкатегории и спавн в строительный каталог

> **Спека:** `docs\superpowers\specs\2026-10-10-furniture-catalog-and-subcategories-design.md`
> **Для исполнителя:** исполнять задачи по одной, отмечать `- [ ]`. Тесты пишутся
> до кода (TDD). Коммиты не делаем — по завершении пользователь собирает пак сам
> (`pack.ps1`) и копирует `Loadouts.vmz` в игру.

**Goal:** В пикере шага 2 у полки «Furniture» появляются чипы подкатегорий (5 групп);
спавн мебели из сета идёт в строительный каталог (`catalogGrid`), а не в рюкзак;
8 новых одноразовых чипов сворачиваются в существующие группы; UI-строки локализованы.

**Architecture:** Классификация остаётся в `VTKPicker.gd` (чистая логика, headless-тесты).
Маршрутизация спавна — в `VTKData.gd` (единственное место, знающее про `Interface`).
Подпись кнопки — в `VTKUI.gd`. Переводы — в `VTKLoc.gd`. Ни одной новой привязки к
внутренностям игры, кроме уже используемого `interface.catalogGrid`.

**Tech stack:** GDScript (Godot 4.6.3), PowerShell-стенды `.check\*.ps1`, Python-стенды
`.check\*.py`. Запуск python — через `py` (не `python`).

---

## Global constraints

- Отступы в `.gd` — только табы. Файлы в UTF-8.
- Версия мода живёт только в `loadouts\mod.txt`; цель — `4.10.3`.
- Новая строка UI = новая запись в `RU` того же прохода (`VTKLoc.gd`).
- Английский — исходный язык: ключ `Loc.txt(...)` сам является английской строкой.
- Строка с кавычкой внутри пишется в одинарных кавычках словаря `RU`.
- Godot-бинарь: `D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe`.
- Стенд `check.ps1` копирует `loadouts\mods\VTK\*.gd` в `.check\project\mods\VTK`
  перед прогоном, поэтому правки источника подхватываются сами.

**Команды проверки (запускать из `D:\RTVMOD`):**

```
py .check\layout_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1 -Godot "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe"
py .check\keycheck.py
```

Зелёный статус `check.ps1` = всё из трёх: нет строк `SCRIPT ERROR` / `Parse Error` /
`Invalid call` / `Failed to load script`; есть `tests passed`; код выхода 0.

---

## Task 1: Подкатегории мебели (A)

**Files**
- Modify: `loadouts\mods\VTK\VTKPicker.gd` (`CATEGORIES`, `SUBCATEGORY_ORDER`, новый `FURN_SUB_FOLDERS`, ветка в `subcategory_of`)
- Modify: `.check\project\tests\test_picker.gd`
- Modify: `loadouts\mods\VTK\VTKLoc.gd`

**Тип пути мебели:** `res://Assets/<Папка>/<Файл>_F.tres`. Второй сегмент (`<Папка>`) —
ключ группировки. Неизвестная папка → `""` (предмет остаётся в «All items», без чипа).
Мебель идёт отдельной таблицей, потому что в `SUB_FOLDERS` ключ — предпоследний сегмент
(`.../<Папка>/<Тип>/Обвесы/...`), а у мебели папка стоит во втором сегменте.

- [ ] **Шаг 1. Тесты (сначала — падают).** В `test_picker.gd` в `_init()` добавить
  вызов `t_furn_subcategories()`; добавить функцию после `t_order_subcategories`:

```gdscript
func t_furn_subcategories() -> void:
	ck(P.subcategory_of("res://Assets/Radio/Radio_F.tres", "Furniture") == "Appliances & Electronics",
		"мебель: радио в технику")
	ck(P.subcategory_of("res://Assets/Bed_Civilian/Bed_Civilian_F.tres", "Furniture") == "Seating & Beds",
		"мебель: кровать в сиденья")
	ck(P.subcategory_of("res://Assets/Carpet/Carpet_Rag_F.tres", "Furniture") == "Decor",
		"мебель: ковёр в декор")
	ck(P.subcategory_of("res://Assets/Weapon_Display/Weapon_Display_F.tres", "Furniture") == "Decor",
		"мебель: стойка для оружия в декор")
	ck(P.subcategory_of("res://Assets/Bookshelf/Bookshelf_F.tres", "Furniture") == "Storage & Cabinets",
		"мебель: шкаф в хранение")
	ck(P.subcategory_of("res://Assets/Table_Cabin/Table_Cabin_F.tres", "Furniture") == "Tables & Shelving",
		"мебель: стол в столы")
	# Неизвестная папка остаётся без чипа, а не падает и не липнет к чужой группе.
	ck(P.subcategory_of("res://Assets/Unknown_Thing/Unknown_Thing_F.tres", "Furniture") == "",
		"неизвестная мебель без чипа")
	# Каждое значение таблицы обязано быть в порядке строк фильтров, иначе чип
	# отрисуется, но строки в UI под него не будет и группа пропадёт молча.
	for v in P.FURN_SUB_FOLDERS.values():
		ck(P.SUBCATEGORY_ORDER.has(v), "группа мебели в порядке: " + str(v))
```

  Прогнать `check.ps1` — тест должен упасть (нет `FURN_SUB_FOLDERS`).

- [ ] **Шаг 2. `FURN_SUB_FOLDERS`.** В `VTKPicker.gd` после объявления `SUB_FOLDERS`
  добавить таблицу (43 ключа, 46 предметов; `&` в значениях — обычный символ):

```gdscript
# Подкатегории мебели. Путь мебели: res://Assets/<Папка>/..._F.tres, поэтому
# ключ — второй сегмент пути, а не предпоследний, как в SUB_FOLDERS. Папка,
# которой нет в таблице, остаётся без чипа.
const FURN_SUB_FOLDERS := {
	"Bookshelf": "Storage & Cabinets",
	"Cabinet_Medical": "Storage & Cabinets",
	"Cabinet_Office": "Storage & Cabinets",
	"Cabinet_Wood": "Storage & Cabinets",
	"Crate_Military": "Storage & Cabinets",
	"Crate_Special": "Storage & Cabinets",
	"Cupboard": "Storage & Cabinets",
	"Locker": "Storage & Cabinets",
	"Nightstand": "Storage & Cabinets",
	"Bed_Civilian": "Seating & Beds",
	"Bed_Nomad": "Seating & Beds",
	"Bench_Campsite": "Seating & Beds",
	"Chair_Office": "Seating & Beds",
	"Chair_School": "Seating & Beds",
	"Chair_Sun": "Seating & Beds",
	"Sofa_Leather": "Seating & Beds",
	"Stool_Military": "Seating & Beds",
	"Stool_Padded": "Seating & Beds",
	"Shelf_Metal": "Tables & Shelving",
	"Shelf_Wall": "Tables & Shelving",
	"Shelf_Wood": "Tables & Shelving",
	"Table_Cabin": "Tables & Shelving",
	"Table_Canteen": "Tables & Shelving",
	"Table_Kitchen": "Tables & Shelving",
	"Table_Office": "Tables & Shelving",
	"Freezer": "Appliances & Electronics",
	"Fridge": "Appliances & Electronics",
	"Radio": "Appliances & Electronics",
	"Stove": "Appliances & Electronics",
	"Television": "Appliances & Electronics",
	"Calendar": "Decor",
	"Carpet": "Decor",
	"Curtains": "Decor",
	"Dartboard": "Decor",
	"Painting": "Decor",
	"Pallet": "Decor",
	"Posters": "Decor",
	"Rack_Coat": "Decor",
	"Rya": "Decor",
	"Sign_Border_Zone": "Decor",
	"Target_Stand": "Decor",
	"Trolley": "Decor",
	"Weapon_Display": "Decor",
}
```

- [ ] **Шаг 3. `subcategory_of`.** Найти в функции ранний выход по мебели
  (`if ... == "furniture": return ""`) и заменить его на разбор пути:

```gdscript
	# Мебель: папка — второй сегмент пути (res://Assets/<Папка>/...).
	if str(type).strip_edges().to_lower() == "furniture":
		var fsegs: PackedStringArray = path.trim_prefix("res://").split("/")
		if fsegs.size() >= 2:
			return str(FURN_SUB_FOLDERS.get(fsegs[1], ""))
		return ""
```

- [ ] **Шаг 4. `CATEGORIES`.** В конец массива `CATEGORIES` добавить пару
  `["furniture", "Furniture"]`.

- [ ] **Шаг 5. `SUBCATEGORY_ORDER`.** В конец массива (после `"Lore"`) добавить
  пять имён; обновить комментарий, что хвост списка — группы мебели:

```gdscript
	"Storage & Cabinets", "Seating & Beds", "Tables & Shelving",
	"Appliances & Electronics", "Decor",
```

- [ ] **Шаг 6. Локализация.** В `VTKLoc.gd` добавить в `RU`:
  - `'Furniture': 'Мебель',` — рядом с прочими подписями категорий (после `'Full magazine'`);
  - в блок подкатегорий (после `'Lore': 'Лор',`) — пять групп:

```gdscript
	'Storage & Cabinets': 'Хранение',
	'Seating & Beds': 'Сиденья и кровати',
	'Tables & Shelving': 'Столы и полки',
	'Appliances & Electronics': 'Техника',
	'Decor': 'Декор',
```

- [ ] **Шаг 7. Проверка.** `check.ps1` зелёный; `py .check\keycheck.py` →
  `RESULT: every Loc.txt() key has a RU entry` (0 missing).
- [ ] **Шаг 8.** `layout_check.py` (список `GONE`/`PRESENT` не трогаем — раскладка
  не менялась) и `py .check\mojibake_scan.py` (новый русский текст).
- [ ] Задача 1 закрыта.

---

## Task 2: Свернуть одноразовые чипы (C)

**Files**
- Modify: `loadouts\mods\VTK\VTKPicker.gd` (`SUB_FOLDERS`)
- Modify: `.check\project\tests\test_picker.gd`

Найдено ровно 8 чипов, каждый показывает одну строку. Маппинг согласован с дизайном:
`Suitcase_Driver` — `type = "Lore"` (лут в `Loot/Lore/LS_Suitcase_Driver.tscn`), поэтому
в `Lore`; `Museum_Plate` — `type = "Misc"`, отдельного потребителя нет → в общий
`Utilities & Tools`; `Hand_Warmer` → `Utility` (медицина).

- [ ] **Шаг 1. Тесты (сначала — падают).** В `t_furn_subcategories` не добавляем;
  добавить отдельную функцию `t_merged_subcategories` и вызов в `_init()`:

```gdscript
func t_merged_subcategories() -> void:
	ck(P.subcategory_of("res://Assets/Medical/Hand_Warmer/Hand_Warmer.tres", "Medical") == "Utility",
		"грелка сворачивается в мелочи")
	ck(P.subcategory_of("res://Assets/Lore/Suitcase_Driver/Suitcase_Driver.tres", "Lore") == "Lore",
		"водительский чемоданчик остаётся в лоре")
	for sub in ["Air_Freshener", "Glue", "Leather", "Museum_Plate", "Radiator_Engine", "Screws"]:
		var got := P.subcategory_of("res://Assets/Misc/" + sub + "/" + sub + ".tres", "Misc")
		ck(got == "Utilities & Tools", "мелочь без группы -> хозтовары: " + sub)
```

  Прогнать `check.ps1` — падает.

- [ ] **Шаг 2. Записи в `SUB_FOLDERS`.** Добавить 8 строк (порядок в словаре не
  важен, вставить рядом с существующими ключами Misc/Medical/Lore):

```gdscript
	"Hand_Warmer": "Utility",
	"Suitcase_Driver": "Lore",
	"Air_Freshener": "Utilities & Tools",
	"Glue": "Utilities & Tools",
	"Leather": "Utilities & Tools",
	"Museum_Plate": "Utilities & Tools",
	"Radiator_Engine": "Utilities & Tools",
	"Screws": "Utilities & Tools",
```

- [ ] **Шаг 3. Проверка.** `check.ps1` зелёный. `keycheck.py` без `unused`-строк
  (все значения — существующие ключи `RU`).
- [ ] Задача 2 закрыта.

---

## Task 3: Спавн мебели в `catalogGrid` (B)

**Files**
- Modify: `loadouts\mods\VTK\VTKData.gd` (`_is_furniture`, `_insert_desc`, `_grid_count`, `spawn_gear`, цикл gear в `apply_loadout`)
- Modify: `loadouts\mods\VTK\VTKUI.gd` (подпись кнопки в `_make_item_cell`)
- Modify: `loadouts\mods\VTK\VTKLoc.gd`
- Modify: `.check\project\tests\test_spawn.gd`

**Референс JCM:** мебель вставляется `interface.Create(slotData, interface.catalogGrid, false)`,
остальное — `interface.Create(slotData, inventoryGrid, true)`. Текущий `_insert` зовёт
`Create(gsd, ig, true)`; его сигнатуру и поведение не меняем.

- [ ] **Шаг 1. Тесты (сначала — падают).** В `test_spawn.gd` в `_run()` добавить
  `t_is_furniture()` перед `t_insert_desc()`; добавить функцию:

```gdscript
# Распознавание мебели по type ресурса. Словарь-описание тоже подходит:
# у него есть .get, как у Resource.
func t_is_furniture() -> void:
	ck(VTKData._is_furniture({"type": "Furniture"}), "Furniture распознана")
	ck(VTKData._is_furniture({"type": " Furniture "}), "пробелы и регистр снимаются")
	ck(not VTKData._is_furniture({"type": "Weapon"}), "оружие не мебель")
	ck(not VTKData._is_furniture({"type": "Consumables"}), "еда не мебель")
	ck(not VTKData._is_furniture({}), "пустое описание не мебель")
	ck(not VTKData._is_furniture(null), "null не мебель")
```

  Прогнать `check.ps1` — падает (нет `_is_furniture`).

- [ ] **Шаг 2. `_is_furniture` + `_grid_count`.** В `VTKData.gd` рядом с `_insert`
  добавить:

```gdscript
# Мебель нельзя выдавать в рюкзак: игра ждёт её в строительном каталоге
# (interface.catalogGrid), как это делает JCM.
static func _is_furniture(res) -> bool:
	if res == null:
		return false
	return str(res.get("type")).strip_edges().to_lower() == "furniture"

# Число слотов сетки — для отчёта «сколько ушло в каталог».
static func _grid_count(grid) -> int:
	if grid == null or not is_instance_valid(grid):
		return 0
	var n := 0
	for c in grid.get_children():
		if is_instance_valid(c) and c.get("slotData") != null:
			n += 1
	return n
```

- [ ] **Шаг 3. `_insert_desc`.** Добавить выбор сетки. Кэш каталога берём один раз
  до цикла (с защитой от `interface == null`, иначе падает headless-тест
  `_insert_desc(null, null, ...)`):

```gdscript
static func _insert_desc(interface, ig, desc: Dictionary) -> int:
	var placed := 0
	var n := _instances(desc)
	var one := desc
	if n > 1 and not desc.has("count"):
		one = desc.duplicate()
		one["amount"] = 1.0
	var catalog = null
	if interface != null and is_instance_valid(interface):
		catalog = interface.get("catalogGrid")
	for i in range(n):
		var gsd = _build_slot_data(one)
		if gsd == null:
			break
		if catalog != null and _is_furniture(gsd.get("itemData")):
			interface.Create(gsd, catalog, false)
		else:
			_insert(interface, ig, gsd)
		placed += 1
	return placed
```

- [ ] **Шаг 4. `spawn_gear` — сообщение.** Определить мебель по загруженному
  ресурсу, выбрать ключ уведомления:

```gdscript
	var res = load(str(desc.get("path", "")))
	var key := "Spawned to catalog: " if _is_furniture(res) else "Spawned: "
	Notify(key + ...)
```

  (сохранить существующий формат остальных веток; изменить только выбор ключа).

- [ ] **Шаг 5. `apply_loadout` — «To catalog: N».** Обернуть цикл `gear`:

```gdscript
	var cat_grid = interface.get("catalogGrid")
	var cat_before := _grid_count(cat_grid)
	for desc in gear:
		if typeof(desc) != TYPE_DICTIONARY:
			continue
		_insert_desc(interface, ig, desc)
	var to_catalog := _grid_count(cat_grid) - cat_before
```

  В итоговую строку уведомления добавить ` + Loc.txt(" · To catalog: ") + str(to_catalog)`,
  когда `to_catalog > 0` (в остальных случаях строку не показывать).

- [ ] **Шаг 6. `VTKUI.gd` — подпись кнопки.** В `_make_item_cell` (там, где
  `spawn_btn.text = Loc.txt("Spawn into inventory")`) выбрать ключ по типу предмета:

```gdscript
	spawn_btn.text = Loc.txt("Spawn into catalog") if str(item.get("type")).strip_edges().to_lower() == "furniture" else Loc.txt("Spawn into inventory")
```

  (если строка длинная — вынести в `var is_furn := ...` перед присваиванием).

- [ ] **Шаг 7. Локализация.** В `VTKLoc.gd` добавить в `RU`:

```gdscript
	'Spawn into catalog': 'В каталог',
	'Spawned to catalog: ': 'Заспавнено в каталог: ',
	' · To catalog: ': ' · В каталог: ',
```

- [ ] **Шаг 8. Проверка.** `check.ps1` зелёный. `keycheck.py` → 0 missing.
- [ ] **Ручная проверка в игре (не покрывается стендом):** заспавнить сет с мебелью
  из шага 2 — предмет появляется в строительном каталоге (клавиша постройки), не в
  рюкзаке; всплывает текст «Заспавнено в каталог: …». Снаряжение по-прежнему уходит
  в инвентарь. Кнопка у мебели подписана «В каталог».
- [ ] Задача 3 закрыта.

---

## Task 4: Версия и полная проверка

**Files**
- Modify: `loadouts\mod.txt` (`version`)

- [ ] **Шаг 1.** Поднять `version` в `loadouts\mod.txt` с `4.10.2` до `4.10.3`
  (фикс+фича без смены формата сохранений; пользователь указал именно `4.10.3`).
- [ ] **Шаг 2. Полный прогон:**

```
py .check\layout_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1 -Godot "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe"
py .check\keycheck.py
py .check\mojibake_scan.py
```

  Все три условия `check.ps1` выполнены (нет `SCRIPT ERROR`/`Parse Error`/`Invalid call`/
  `Failed to load script`; есть `tests passed`; exit 0).
- [ ] **Шаг 3. Сборка (по запросу пользователя).**
  `powershell -ExecutionPolicy Bypass -File pack.ps1` — сверить напечатанную версию
  с `4.10.3`, забрать `Loadouts.vmz`. Копирование в папку модов игры — за пользователем.
- [ ] Задача 4 закрыта.

---

## Self-review

- **Спека:** A → Task 1 (5 групп, таблица, ветка, порядок, категория); B → Task 3
  (маршрут `catalogGrid`, подпись кнопки, счётчик, локализация); C → Task 2 (8 влитых
  чипов); версия → Task 4. Покрыто.
- **Тестируемость:** `FURN_SUB_FOLDERS`, ветка `subcategory_of`, `_is_furniture` —
  headless. Маршрут спавна в игре не тестируется стендом (нет `Interface`) — отсюда
  явная ручная проверка в Task 3.
- **Типы:** `fsegs` аннотирован `PackedStringArray`; `_is_furniture(res)` без аннотации —
  принимает `Resource`/`Dictionary`/`null`; `_grid_count(grid)` без аннотации — вернёт
  `0` при `null`, что важно для headless-теста с `interface == null`.
- **Согласованность имён:** ключи групп = значения `FURN_SUB_FOLDERS` = элементы
  `SUBCATEGORY_ORDER` = ключи `RU`; проверяется `keycheck.py` (dynamic keys из
  `SUBCATEGORY_ORDER`) и тестом `t_furn_subcategories` (`SUBCATEGORY_ORDER.has`).
- **Риск:** если у реального пути мебели второй сегмент окажется не папкой ассета, все
  46 предметов получат `""` — тогда сначала подтвердить путь пробой
  `_vtk_probe_furn.gd`, потом править индекс сегмента.
