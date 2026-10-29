# Road To Loot — категории по слотам экипировки (план)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Категория предмета (`weapon` / `clothing` / `other`) определяется слотами экипировки из данных игры, а не самодельной таблицей `type`; нож не получает `recoil` и `fire_rate`; `build_affixes` принимает настоящий ресурс `ItemData`.

**Architecture:** `RTLCategory.gd` переписывается в чистый модуль правил (слоты — единственный источник истины, `of_path()` и таблица типов удаляются). Маска статов живёт там же (`stat_allowed`), `RTLRoll.build_affixes` только спрашивает её и не знает имён типов. Перед этим восстанавливается зелёный baseline: снимается аннотация `item_data: Dictionary`, оживляются `needs`-гейты и убираются отладочные логи.

**Tech Stack:** GDScript, Godot 4.6.3 headless (`D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe`), стенд `.check\check.ps1`, Python 3 (`py -3`) для сверки по дампу.

**Spec:** `docs/superpowers/specs/2026-10-28-road-to-loot-slot-categories-design.md`

## Global Constraints

- Файлы `.gd` — UTF-8, отступы только табы, без многострочных строк (`pack.ps1` чистит построчные `#`-комментарии и пустые строки).
- `Object.get()` принимает ровно один аргумент; второй (`default`) на игровом ресурсе падает «Invalid call» и обрывает функцию. Дефолт делается снаружи: `v = item_data.get(name)` → проверка на `null`.
- Зелёный прогон `.check\check.ps1` = нет строк `SCRIPT ERROR` / `Parse Error` / `Invalid call` / `Failed to load script`, есть `tests passed`, код выхода 0.
- Новый тест регистрируется вручную в `$tests` внутри `.check/check.ps1` (строка 180, RTL-группа).
- Версия живёт только в `standalone mods/RoadToLoot/mod.txt`; `mods/RoadToLoot/version.txt` и `README.md` переписывает `pack.ps1` при сборке.
- `CHANGELOG.md` — для игроков: без имён хуков, методов игры, файлов, функций и MCM-ключей; английский; заголовок `## [x.y.z] - YYYY-MM-DD`.
- VTK (`loadouts/mods/VTK`) в этой задаче не меняется. `RTLPool.gd` меняется только возвратом гейта `needs` у записи `capacity` — диапазоны, веса, состав пула и `release` не трогаются.
- `RTLCategory.gd` остаётся без `load()` и без путей внутрь игры, чтобы прогоняться headless.

## Review Focus

1. **Ресурс `ItemData` там, где объявлен `Dictionary`.** Сейчас `build_affixes` рвётся на реальном предмете и возвращает `null`; ожидаемое поведение — массив аффиксов из настоящего ресурса, как из словаря. Тест: Task 1, шаг 2.
2. **Предметы без слотов** (вложения, ствол `KAR-21`, пластины брони) — ожидаемо `other`, а не `weapon`/`clothing` по пути ресурса. Тест: Task 2.
3. **Не-оружие в оружейных слотах** (удочка `Fishing`, гитара и гармошка `Instrument` занимают `Primary`/`Secondary`) — ожидаемо `other`. Тест: Task 2.
4. **Нож** (`type = Knife`, слот `Knife`) — оружие, но без `recoil` и `fire_rate`; на тире 3 выходит 2 аффикса, а не 3. Тест: Task 3.
5. **Поясная сумка** (`type = Belt Pouch`, слот `Belt`) — одежда: одежный пул аффиксов, включая `capacity`. Тест: Task 2.

## Baseline до Task 1

На момент плана `check.ps1` красный на пяти RTL-файлах, все — следы незакоммиченной диагностики и переименования `carry` → `capacity`:

| файл | красные проверки |
|---|---|
| `test_rtl_pool.gd` | `MERGED keys`, `MERGED carry -> Capacity` |
| `test_rtl_roll.gd` | `insulation needs insulation`, `protection needs armor`, `carry rolls when capacity > 0` |
| `test_rtl_stats.gd` | `carry sum = 5` |
| `test_rtl_text.gd` | `label carry aliased to Capacity`, `carry 20 +15`, `carry truncates` |
| `test_rtl_rows.gd` | `fallback label: Carry:` |

Причина в коде: в `RTLRoll.build_affixes` все ветки `needs` заменены на `ok = true`, добавлены `DBG`-логи, а у записи `capacity` в пуле снят `"needs"`.

---

### Task 1: Вернуть зелёный baseline и починить `build_affixes`

**Files:**
- Modify: `standalone mods/RoadToLoot/mods/RoadToLoot/RTLRoll.gd:52-106`
- Modify: `standalone mods/RoadToLoot/mods/RoadToLoot/RTLPool.gd:26-27`
- Modify: `standalone mods/RoadToLoot/mods/RoadToLoot/RTLBoot.gd:219,227-229`
- Test: `.check/project/tests/test_rtl_roll.gd`
- Test (устаревшие имена): `.check/project/tests/test_rtl_pool.gd:36-37,43-44`, `test_rtl_stats.gd:15,21,26`, `test_rtl_text.gd:17,51,60-61`, `test_rtl_rows.gd:38,41,45-48,69-70,86-87,90`

**Interfaces:**
- Consumes: `Pool.entries(category)`, `Pool.entry(category, stat)` — без изменений.
- Produces: `Roll.build_affixes(category: String, tier: int, item_data, blocked: Array, rng: RandomNumberGenerator) -> Array` — третий параметр без аннотации, принимает и `Dictionary`, и `ItemData`.

- [ ] **Step 1: Привести четыре теста к имени `capacity`**

Механическая замена `carry` → `capacity` в `.check/project/tests/test_rtl_pool.gd`, `test_rtl_stats.gd`, `test_rtl_text.gd`, `test_rtl_rows.gd` — во всех строках, где `carry` встречается (список выше), включая ожидания `MERGED`:

```gdscript
ck(merge_keys == ["capacity", "damage", "insulation", "protection"], "MERGED keys: " + str(merge_keys))
ck(Pool.MERGED["capacity"] == "Capacity", "MERGED capacity -> Capacity")
ck(str(Pool.MERGED_BASE.get("capacity", "capacity")) == "capacity", "MERGED_BASE capacity -> capacity")
```

В `test_rtl_roll.gd` переименовать только `bare.has("carry")` / `seen.has("carry")` → `"capacity"`; проверки гейтов пока остаются красными.

- [ ] **Step 2: Написать падающие тесты на реальный `ItemData` и на гейты**

В конец `_init()` в `.check/project/tests/test_rtl_roll.gd` (перед `print("")`):

```gdscript
	# §9: третий параметр — реальный ресурс ItemData, а не только Dictionary
	var as_resource: Variant = Resource.new()
	var by_res: Variant = Roll.build_affixes("clothing", 1, as_resource, [], rng)
	ck(by_res is Array and by_res.size() == 1, "ItemData resource does not break build_affixes")
```

`as_resource` объявлен как `Variant` намеренно: со статическим типом Godot отвергает вызов на этапе парсинга, а нам нужен рантайм-путь, как в `RTLBoot.roll_for`.

- [ ] **Step 3: Прогнать и убедиться, что красное**

```powershell
Copy-Item -Path "D:\RTVMOD\standalone mods\RoadToLoot\mods\RoadToLoot\*.gd" -Destination "D:\RTVMOD\.check\project\mods\RoadToLoot" -Force
& "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe" --headless --path "D:\RTVMOD\.check\project" --script res://tests/test_rtl_roll.gd --quit-after 600
```

Ожидается: `FAIL capacity needs capacity`, `FAIL insulation needs insulation`, `FAIL protection needs armor`, `FAIL ItemData resource does not break build_affixes` и строка `Cannot convert argument 3 from Object to Dictionary`.

- [ ] **Step 4: Снять аннотацию, вернуть гейты, убрать отладочные логи**

`RTLRoll.gd`, сигнатура:

```gdscript
static func build_affixes(category: String, tier: int, item_data, blocked: Array, rng: RandomNumberGenerator) -> Array:
```

Фильтр `needs` вместо заглушки `ok = true` (ключевое: поле берётся из `item_data`, поэтому ресурс и словарь ведут себя одинаково):

```gdscript
static func _needs_ok(need: String, item_data) -> bool:
	if need == "":
		return true
	if need == "armor":
		var t: String = ""
		if item_data != null:
			var raw = item_data.get("type")
			if raw != null:
				t = str(raw).strip_edges()
		return t == "Armor" or t == "Helmet"
	if item_data == null:
		return false
	var v = item_data.get(need)
	return v != null and float(v) > 0.0
```

В цикле: `var need: String = str(e.get("needs", ""))` и `if _needs_ok(need, item_data): filtered.append(e)`.

Удалить из `RTLRoll.gd` все `Log.line("DBG ...")` и `Log.line(">>> ...")`, а также ставший ненужным `const Log = preload(...)`.

`RTLBoot.gd`: удалить `Log.line(">>> ENTER roll_for")`, `Log.line("CALL build_affixes ...")`, `Log.line("AFTER build_affixes ...")` (строки 219, 227-229); `DEBUG roll_for` под `_debug.should_log()` оставить.

`RTLPool.gd`, запись `capacity`: вернуть `"needs": "capacity"`:

```gdscript
	{"stat": "capacity", "category": "clothing", "unit": "kg", "weight": 0.9,
		"ranges": {1: [2, 5], 2: [5, 8], 3: [8, 10]}, "release": 1, "needs": "capacity"},
```

- [ ] **Step 5: Прогнать пять RTL-тестов**

Той же командой из шага 3, подставляя `test_rtl_pool.gd`, `test_rtl_roll.gd`, `test_rtl_stats.gd`, `test_rtl_text.gd`, `test_rtl_rows.gd`.

Ожидается в каждом: `tests passed`, ни одного `FAIL`, ни одного `SCRIPT ERROR`.

- [ ] **Step 6: Коммит**

```powershell
cd "D:\RTVMOD"
git add ".check/project/tests/test_rtl_pool.gd" ".check/project/tests/test_rtl_roll.gd" ".check/project/tests/test_rtl_stats.gd" ".check/project/tests/test_rtl_text.gd" ".check/project/tests/test_rtl_rows.gd" "standalone mods/RoadToLoot/mods/RoadToLoot/RTLRoll.gd" "standalone mods/RoadToLoot/mods/RoadToLoot/RTLPool.gd" "standalone mods/RoadToLoot/mods/RoadToLoot/RTLBoot.gd"
git commit -m "RTL 0.3.0: build_affixes takes real ItemData, needs gates restored"
```

---

### Task 2: Категории по слотам

**Files:**
- Modify (переписать): `standalone mods/RoadToLoot/mods/RoadToLoot/RTLCategory.gd` (целиком, 40 строк)
- Create: `.check/project/tests/test_rtl_category.gd`
- Modify: `.check/check.ps1:180` (регистрация теста в `$tests`)

**Interfaces:**
- Consumes: ничего из Task 1 (модуль самостоятелен).
- Produces:
  - `Category.of_item(itemData) -> String` — `"weapon"` / `"clothing"` / `"other"`; принимает `Dictionary` и `ItemData`, `null` → `"other"`.
  - `Category.rollable(itemData) -> bool` — `of_item(itemData) != OTHER`.
  - Константы `WEAPON`, `CLOTHING`, `OTHER`, `WEAPON_SLOTS`, `CLOTHING_SLOTS`, `NON_WEAPON_TYPES`.
  - `of_path()` больше не существует — Task 3 и `RTLBoot.global` на него не ссылаются.

- [ ] **Step 1: Написать падающий тест**

Create `.check/project/tests/test_rtl_category.gd`:

```gdscript
extends SceneTree

const Cat = preload("res://mods/RoadToLoot/RTLCategory.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _init() -> void:
	# оружие
	ck(Cat.of_item({"type": "Weapon", "slots": ["Primary"]}) == Cat.WEAPON, "rifle -> weapon")
	ck(Cat.of_item({"type": "Weapon", "slots": ["Primary", "Secondary"]}) == Cat.WEAPON, "pistol -> weapon")
	ck(Cat.of_item({"type": "Knife", "slots": ["Knife"]}) == Cat.WEAPON, "knife -> weapon")
	# путь ресурса больше ничего не решает: ствол KAR-21 лежит в /Weapons/, но это вложение
	ck(Cat.of_item({"type": "Attachment", "slots": [],
		"resource_path": "res://Items/Weapons/KAR-21/KAR-21_Barrel.tres"}) == Cat.OTHER,
		"weapon path does not make a weapon")
	# одежда
	ck(Cat.of_item({"type": "Clothing", "slots": ["Torso"]}) == Cat.CLOTHING, "clothing torso -> clothing")
	ck(Cat.of_item({"type": "Clothing", "slots": ["Head"]}) == Cat.CLOTHING, "clothing head -> clothing")
	ck(Cat.of_item({"type": "Backpack", "slots": ["Backpack"]}) == Cat.CLOTHING, "backpack -> clothing")
	ck(Cat.of_item({"type": "Rig", "slots": ["Rig"]}) == Cat.CLOTHING, "rig -> clothing")
	ck(Cat.of_item({"type": "Helmet", "slots": ["Helmet"]}) == Cat.CLOTHING, "helmet -> clothing")
	ck(Cat.of_item({"type": "Belt Pouch", "slots": ["Belt"]}) == Cat.CLOTHING, "belt pouch -> clothing")
	# прочее
	ck(Cat.of_item({"type": "Armor", "slots": []}) == Cat.OTHER, "armor plate -> other")
	ck(Cat.of_item({"type": "Attachment", "slots": []}) == Cat.OTHER, "attachment -> other")
	ck(Cat.of_item({"type": "Grenade", "slots": ["Grenade_1", "Grenade_2"]}) == Cat.OTHER, "grenade -> other")
	ck(Cat.of_item({"type": "Electronics", "slots": ["Light"]}) == Cat.OTHER, "flashlight -> other")
	ck(Cat.of_item({"type": "Misc", "slots": ["Map"]}) == Cat.OTHER, "map -> other")
	ck(Cat.of_item({"type": "Fishing", "slots": ["Primary", "Secondary"]}) == Cat.OTHER, "fishing rod -> other")
	ck(Cat.of_item({"type": "Instrument", "slots": ["Primary", "Secondary"]}) == Cat.OTHER, "guitar -> other")
	# грязный вход
	ck(Cat.of_item(null) == Cat.OTHER, "null -> other")
	ck(Cat.of_item({}) == Cat.OTHER, "empty dict -> other")
	ck(Cat.of_item({"type": " Misc", "slots": []}) == Cat.OTHER, "leading space type -> other")
	ck(Cat.of_item({"slots": ["Primary"]}) == Cat.WEAPON, "missing type, weapon slot -> weapon")
	# rollable
	ck(Cat.rollable({"type": "Weapon", "slots": ["Primary"]}), "rifle rollable")
	ck(Cat.rollable({"type": "Knife", "slots": ["Knife"]}), "knife rollable")
	ck(Cat.rollable({"type": "Belt Pouch", "slots": ["Belt"]}), "belt pouch rollable")
	ck(not Cat.rollable({"type": "Armor", "slots": []}), "armor plate not rollable")
	ck(not Cat.rollable({"type": "Attachment", "slots": []}), "attachment not rollable")
	ck(not Cat.rollable(null), "null not rollable")

	print("")
	if fails > 0:
		print("FAILED: %d" % fails)
		quit(1)
	else:
		print("tests passed")
		quit(0)
```

- [ ] **Step 2: Прогнать и убедиться, что красное**

```powershell
& "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe" --headless --path "D:\RTVMOD\.check\project" --script res://tests/test_rtl_category.gd --quit-after 600
```

Ожидается: `FAIL knife -> weapon`, `FAIL belt pouch -> clothing`, `FAIL weapon path does not make a weapon`, `FAIL fishing rod -> other` и `FAILED: N`.

- [ ] **Step 3: Переписать `RTLCategory.gd`**

```gdscript
extends RefCounted

const WEAPON := "weapon"
const CLOTHING := "clothing"
const OTHER := "other"

const WEAPON_SLOTS := ["Primary", "Secondary", "Knife"]
const CLOTHING_SLOTS := ["Backpack", "Rig", "Helmet", "Head", "Torso", "Legs", "Belt", "Feet", "Hands"]
const NON_WEAPON_TYPES := ["Fishing", "Instrument"]

static func _field_str(itemData, field: String) -> String:
	if itemData == null:
		return ""
	var raw = itemData.get(field)
	if raw == null:
		return ""
	var s := str(raw)
	return s.strip_edges()

static func _slots(itemData) -> Array:
	if itemData == null:
		return []
	var raw = itemData.get("slots")
	if raw is Array:
		return raw
	return []

static func _has_any(slots: Array, allowed: Array) -> bool:
	for s in slots:
		var ss := str(s).strip_edges()
		if allowed.has(ss):
			return true
	return false

static func of_item(itemData) -> String:
	if itemData == null:
		return OTHER
	var t := _field_str(itemData, "type")
	if NON_WEAPON_TYPES.has(t):
		return OTHER
	var slots := _slots(itemData)
	if _has_any(slots, WEAPON_SLOTS):
		return WEAPON
	if _has_any(slots, CLOTHING_SLOTS):
		return CLOTHING
	return OTHER

static func rollable(itemData) -> bool:
	return of_item(itemData) != OTHER
```

Удалить `WEAPON_TYPES`, `CLOTHING_TYPES`, `of_path()`. Весь фолбэк по `resource_path` убираем — категория определяется только слотами.

Порядок в `of_item`: `null` → `OTHER`; `_field_str(itemData, "type").strip_edges()` в `NON_WEAPON_TYPES` → `OTHER`; слоты ∩ `WEAPON_SLOTS` → `WEAPON`; слоты ∩ `CLOTHING_SLOTS` → `CLOTHING`; иначе `OTHER`. Таблица `WEAPON_TYPES`/`CLOTHING_TYPES` и `of_path()` удаляются.

- [ ] **Step 4: Прогнать новый тест**

Команда шага 2. Ожидается `tests passed`.

- [ ] **Step 5: Зарегистрировать тест в стенде**

В `.check/check.ps1:180` дописать `"res://tests/test_rtl_category.gd"` в RTL-группу `$tests` (рядом с `test_rtl_pool.gd`).

- [ ] **Step 6: Сверить раскладку с дампом**

```powershell
py -3 "D:\RTVMOD\tools\probe\simulate_slot_rules.py"
```

Ожидается: `weapon 32`, `clothing 39`, `other 200` по всем 271 предметам; в списке изменений — `+ Belt Pouch`, `+ Knife`, `- Armor`, `- Attachment`.

- [ ] **Step 7: Убедиться, что `of_path` больше нигде нет**

```powershell
Select-String -Path "D:\RTVMOD\standalone mods\RoadToLoot\mods\RoadToLoot\*.gd" -Pattern "of_path"
```

Ожидается: пустой вывод (код выхода 1 у `Select-String` — это норма, совпадений нет).

- [ ] **Step 8: Полный прогон стенда**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\RTVMOD\.check\check.ps1"
```

Ожидается: `Parse check passed: 25 scripts`, у `test_rtl_category.gd` — `VERDICT: ok`, ни одного `VERDICT: FAIL`, код выхода 0.

- [ ] **Step 9: Коммит**

```powershell
cd "D:\RTVMOD"
git add "standalone mods/RoadToLoot/mods/RoadToLoot/RTLCategory.gd" ".check/project/tests/test_rtl_category.gd" ".check/check.ps1"
git commit -m "RTL 0.3.0: category from equipment slots"
```

---

### Task 3: Маска статов для ножа

**Files:**
- Modify: `standalone mods/RoadToLoot/mods/RoadToLoot/RTLCategory.gd` (добавить `stat_allowed` и константы)
- Modify: `standalone mods/RoadToLoot/mods/RoadToLoot/RTLRoll.gd:89-96` (фильтр перед `blocked`)
- Test: `.check/project/tests/test_rtl_category.gd`, `.check/project/tests/test_rtl_roll.gd`

**Interfaces:**
- Consumes: `Category.of_item` (Task 2), `Roll.build_affixes` с неаннотированным `item_data` (Task 1).
- Produces: `Category.stat_allowed(itemData, stat: String) -> bool` — `false` только для `recoil`/`fire_rate` при `type == "Knife"`; `null` → `true`.

- [ ] **Step 1: Написать падающие тесты**

В `.check/project/tests/test_rtl_category.gd` перед `print("")`:

```gdscript
	# маска ножа
	ck(not Cat.stat_allowed({"type": "Knife", "slots": ["Knife"]}, "recoil"), "knife: recoil masked")
	ck(not Cat.stat_allowed({"type": "Knife", "slots": ["Knife"]}, "fire_rate"), "knife: fire_rate masked")
	ck(Cat.stat_allowed({"type": "Knife", "slots": ["Knife"]}, "damage"), "knife: damage allowed")
	ck(Cat.stat_allowed({"type": "Knife", "slots": ["Knife"]}, "low_hp_damage"), "knife: low_hp_damage allowed")
	ck(Cat.stat_allowed({"type": "Weapon", "slots": ["Primary"]}, "recoil"), "rifle: recoil allowed")
	ck(Cat.stat_allowed(null, "recoil"), "null item: no mask")
```

В `.check/project/tests/test_rtl_roll.gd` перед `print("")`:

```gdscript
	# нож: пул урезан до damage + low_hp_damage
	var knife := {"type": "Knife", "slots": ["Knife"], "damage": 20.0}
	rng.seed = 5
	var kn: Array = Roll.build_affixes("weapon", 3, knife, [], rng)
	var kn_stats: Array = _stats(kn)
	ck(not kn_stats.has("recoil"), "knife: no recoil: " + str(kn_stats))
	ck(not kn_stats.has("fire_rate"), "knife: no fire_rate: " + str(kn_stats))
	ck(kn.size() == 2, "knife tier=3: damage + low_hp_damage: " + str(kn_stats))
```

- [ ] **Step 2: Прогнать и убедиться, что красное**

```powershell
Copy-Item -Path "D:\RTVMOD\standalone mods\RoadToLoot\mods\RoadToLoot\*.gd" -Destination "D:\RTVMOD\.check\project\mods\RoadToLoot" -Force
& "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe" --headless --path "D:\RTVMOD\.check\project" --script res://tests/test_rtl_roll.gd --quit-after 600
```

Ожидается: `FAIL knife: no recoil`, `FAIL knife: no fire_rate`, `FAIL knife tier=3` (сейчас 3 аффикса); `test_rtl_category.gd` красный, потому что `stat_allowed` ещё нет (не грузится как метод класса).

- [ ] **Step 3: Добавить маску в `RTLCategory.gd`**

```gdscript
const KNIFE_TYPE := "Knife"
const KNIFE_BLOCKED := ["recoil", "fire_rate"]

static func stat_allowed(itemData, stat: String) -> bool:
	if itemData == null:
		return true
	if not KNIFE_BLOCKED.has(stat):
		return true
	return _field_str(itemData, "type") != KNIFE_TYPE
```

- [ ] **Step 4: Применить маску в `RTLRoll.build_affixes`**

Новый фильтр между `needs` и `blocked`:

```gdscript
	# Маска категории: нож не усиливает отдачу и темп (RTL не знает имён типов)
	filtered = []
	for e in candidates:
		if Category.stat_allowed(item_data, str(e["stat"])):
			filtered.append(e)
	candidates = filtered
```

- [ ] **Step 5: Прогнать оба теста**

Команда шага 2, затем та же для `res://tests/test_rtl_category.gd`. Ожидается `tests passed` в обоих.

- [ ] **Step 6: Коммит**

```powershell
cd "D:\RTVMOD"
git add "standalone mods/RoadToLoot/mods/RoadToLoot/RTLCategory.gd" "standalone mods/RoadToLoot/mods/RoadToLoot/RTLRoll.gd" ".check/project/tests/test_rtl_category.gd" ".check/project/tests/test_rtl_roll.gd"
git commit -m "RTL 0.3.0: knives skip recoil and fire_rate affixes"
```

---

### Task 4: Релиз 0.3.0

**Files:**
- Modify: `standalone mods/RoadToLoot/mod.txt:4`
- Modify: `standalone mods/RoadToLoot/CHANGELOG.md:1`
- Create: `tools/probe/probe_rtl_categories.gd`

**Interfaces:**
- Consumes: `Category.of_item` (Task 2), `Category.stat_allowed` (Task 3).
- Produces: собранный `standalone mods/RoadToLoot/RoadToLoot.vmz` версии `0.3.0`.

- [ ] **Step 1: Поднять версию**

`mod.txt`: `version="0.2.29"` → `version="0.3.0"`. `version.txt` и `README.md` не трогать — их перепишет `pack.ps1`.

- [ ] **Step 2: Добавить секцию в `CHANGELOG.md`**

Первой после `# Changelog`:

```markdown
## [0.3.0] - 2026-10-28

### Added
- Knives and belt pouches can now drop with a rarity and passive affixes.

### Changed
- Armour plates and weapon attachments no longer drop with a rarity.

### Fixed
- Affixes now actually roll on found items (previously the roll failed and items
  came out without them).
- Knives no longer roll recoil or fire rate bonuses, which they cannot use.
```

Записи 0.2.26–0.2.29 в файле отсутствуют; восстанавливать их — не входит в задачу.

- [ ] **Step 3: Написать end-to-end пробу по реальным ресурсам**

Create `tools/probe/probe_rtl_categories.gd`:

```gdscript
extends SceneTree

# Проба на настоящих ItemData: правила категорий проверяются на ресурсах игры,
# а не на словарях из тестов стенда. Пишет счётчики и список ножей.

const Category = preload("res://mods/RoadToLoot/RTLCategory.gd")
const WEAPON_SLOTS := ["Primary", "Secondary", "Knife"]

var _counts := {"weapon": 0, "clothing": 0, "other": 0}
var _slots_only := 0
var _out: FileAccess

func _init() -> void:
	_out = FileAccess.open("res://_vtk_rtl_categories.txt", FileAccess.WRITE)
	_walk("res://Items")
	_out.store_line("weapon=%d clothing=%d other=%d" % [_counts["weapon"], _counts["clothing"], _counts["other"]])
	_out.store_line("with_slots=%d" % _slots_only)
	_out.close()
	quit(0)

func _walk(dir_path: String) -> void:
	# обход как в tools/probe/dump_item_types.gd: DirAccess + *.tres.remap
	...

func _report(res_path: String) -> void:
	# ResourceLoader.load; slots непустой -> _slots_only += 1, счётчик категории
	# для каждого предмета в слотах Primary/Secondary/Knife проверить
	# Category.stat_allowed на recoil/fire_rate и записать строку при нарушении
	...
```

- [ ] **Step 4: Прогнать пробу**

```powershell
New-Item -ItemType Directory -Force -Path "D:\RTVMOD\RTVcopy\extracted\mods\RoadToLoot" | Out-Null
Copy-Item -Path "D:\RTVMOD\standalone mods\RoadToLoot\mods\RoadToLoot\*.gd" -Destination "D:\RTVMOD\RTVcopy\extracted\mods\RoadToLoot" -Force
& "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe" --headless --path "D:\RTVMOD\RTVcopy\extracted" -s "D:\RTVMOD\tools\probe\probe_rtl_categories.gd"
Get-Content "D:\RTVMOD\RTVcopy\extracted\_vtk_rtl_categories.txt"
Remove-Item -Recurse -Force "D:\RTVMOD\RTVcopy\extracted\mods"
```

Ожидается: `weapon=32 clothing=39 other=16` (только предметы со слотами) и `with_slots=87`. Код выхода Godot — 1 из-за отсутствующего автолоада `res://Resources/Database.tscn`; это норма для дампа, смотреть надо в файл.

- [ ] **Step 5: Полный прогон стенда**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\RTVMOD\.check\check.ps1"
```

Ожидается: `Parse check passed: 25 scripts`, ни одного `VERDICT: FAIL`, код выхода 0.

- [ ] **Step 6: Собрать мод**

```powershell
powershell -ExecutionPolicy Bypass -File "D:\RTVMOD\standalone mods\RoadToLoot\pack.ps1"
```

Ожидается строка `Version in mod.txt: 0.3.0` и созданный `RoadToLoot.vmz`.

- [ ] **Step 7: Проверить сборку изнутри**

```powershell
py -3 "D:\RTVMOD\tools\probe\read_vmz_roll.py"
```

Ожидается: `vmz mod.txt version: 0.3.0`, `category in vmz: True`, и строка `static func build_affixes(...)` **без** `item_data: Dictionary`.

- [ ] **Step 8: Коммит**

```powershell
cd "D:\RTVMOD"
git add "standalone mods/RoadToLoot/mod.txt" "standalone mods/RoadToLoot/CHANGELOG.md" "tools/probe/probe_rtl_categories.gd"
git commit -m "RTL 0.3.0: slot categories, knife mask, release notes"
```
