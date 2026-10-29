# Road To Loot — аффиксы внутри ванильного списка статов (план)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Убрать блок `Passive - <Tier>` и показать аффиксы внутри ванильного списка статов тултипа ванильным шрифтом и кеглем, суммой в существующих строках.

**Architecture:** Строковая логика — чистые функции (`RTLText`) и новый чистый модуль (`RTLRows`), который превращает список аффиксов в готовые строки (порядок, знаки, цвет, исключение `condition`). Вёрстка (`RTLDisplay`) только правит `Value` ванильных строк и клонирует строку `Capacity` для остальных статов. Пул (`RTLPool`) теряет `condition` и получает константы `MERGED`/`ROW_ORDER`.

**Tech Stack:** GDScript 2.0 (Godot 4.6.3), мод Road To Loot (`standalone mods/RoadToLoot`), headless-стенд `.check/check.ps1`.

**Spec:** `docs/superpowers/specs/2026-10-27-road-to-loot-inline-stats-design.md` (заменяет §11.1 и маппинг §11.2 спеки 0.3.0; читать вместе с ними).

## Global Constraints

- Отступы — только табы. Файлы `.gd` в UTF-8.
- Стенд `.check/` лежит под `.gitignore` и не трекается: тесты и `check.ps1` правим на месте, но в коммиты их **не** добавляем (`git add .check/...` упадёт на ignored paths).
- Сцены игры не правим, скрипты игры не оверрайдим; `[hooks]` в `mod.txt` не меняем.
- Аффиксы по-прежнему **не применяются** к геймплею — это только отображение.
- `condition` не существует: ни в `RTLPool`, ни в строках тултипа. Ванильная строка `Condition` остаётся нетронутой.
- Знаки: минус у `stamina_drain`, `thirst_drain`, `hunger_drain`, `sanity_drain`, `noise`, `recoil`; плюс у остальных.
- Цвет значения — `RTLDisplay._border_color(tier)`; подпись всегда белая.
- Подписи и значения — английские литералы (в моде нет локализации), подпись оканчивается двоеточием: `Capacity:`.
- Версия `mod.txt` и `CHANGELOG.md` — задача T8 плана 0.3.0, здесь не трогаем.
- Коммит на задачу, формат сообщения: `RTL 0.3.0 T3b.<n>: <что сделано>`.
- Вердикт теста = есть строка `tests passed`, нет `FAIL`, код выхода 0.

## Review Focus

1. **Дубликат стата в списке аффиксов** (старый сайдкар, ручная правка): сумма, а не перезапись последним значением — иначе игрок увидит один из двух роллов.
2. **Легаси-статы 0.2.x в сейве** (`sway`, `max_hp`, `condition`): мод не падает, легаси-статы идут после статов пула, `condition` не показывается, но не теряется молча в логе при `debug_enabled`.
3. **Слитый стат без ванильной строки** (capacity 0, damage 0, protection у не-Armor): аффикс уходит в свою строку, а не в скрытую ванильную и не теряется.
4. **Тумблер выключен или предмет без тира**: ни одного узла мода и ни одной покрашенной ванильной цифры после предыдущего предмета.
5. **Самая длинная подпись** (`Stamina Drain:`) и длинное значение (`+0.03 HP/s`): значение не уезжает за край панели.

---

### Task 1: Пул без `condition`, константы отображения

**Files:**
- Modify: `standalone mods/RoadToLoot/mods/RoadToLoot/RTLPool.gd`
- Modify: `standalone mods/RoadToLoot/mods/RoadToLoot/RTLStats.gd:3-5`
- Test: `.check/project/tests/test_rtl_pool.gd`, `.check/project/tests/test_rtl_stats.gd`

**Interfaces:**
- Consumes: —
- Produces: `Pool.MERGED: Dictionary` (`{"carry": "Capacity", "damage": "Damage", "insulation": "Insulation", "protection": "Protection"}`), `Pool.ROW_ORDER: Array` (`["recoil", "fire_rate", "low_hp_damage", "regen", "low_hp_regen", "stamina_drain", "thirst_drain", "hunger_drain", "sanity_drain", "noise", "sprint"]`), пул из 15 записей.

- [ ] **Step 1: Переписать `test_rtl_pool.gd` под новое состояние пула**

```gdscript
extends SceneTree

const Pool = preload("res://mods/RoadToLoot/RTLPool.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _init() -> void:
	ck(Pool.ACTIVE_RELEASE == 2, "ACTIVE_RELEASE == 2")

	# --- condition снят с обеих категорий ---
	ck(not Pool.affix_ids("weapon").has("condition"), "weapon: condition removed")
	ck(not Pool.affix_ids("clothing").has("condition"), "clothing: condition removed")
	ck(Pool.entry("weapon", "condition").is_empty(), "weapon: no condition entry")
	ck(Pool.entry("clothing", "condition").is_empty(), "clothing: no condition entry")
	ck(Pool.POOL.size() == 15, "POOL: 15 entries")

	# --- релизный гейт: 4 оружейных, 11 одежды ---
	ck(Pool.entries("weapon").size() == 4, "weapon pool: 4 entries")
	ck(Pool.entries("clothing").size() == 11, "clothing pool: 11 entries")

	# --- статы, снятые в 0.3.0 ---
	for gone in ["sway", "penetration", "durability", "max_hp", "condition"]:
		ck(not Pool.affix_ids("weapon").has(gone) and not Pool.affix_ids("clothing").has(gone),
			gone + " gone")

	# --- MERGED: только те, у кого есть ванильная строка ---
	var merge_keys: Array = Pool.MERGED.keys()
	merge_keys.sort()
	ck(merge_keys == ["carry", "damage", "insulation", "protection"], "MERGED keys: " + str(merge_keys))
	ck(Pool.MERGED["carry"] == "Capacity", "MERGED carry -> Capacity")
	ck(Pool.MERGED["damage"] == "Damage", "MERGED damage -> Damage")
	ck(Pool.MERGED["insulation"] == "Insulation", "MERGED insulation -> Insulation")
	ck(Pool.MERGED["protection"] == "Protection", "MERGED protection -> Protection")

	# --- ROW_ORDER: без слитых статов, без повторов ---
	var seen: Array = []
	for stat in Pool.ROW_ORDER:
		ck(not Pool.MERGED.has(stat), "ROW_ORDER has no merged stat: " + str(stat))
		ck(not seen.has(stat), "ROW_ORDER unique: " + str(stat))
		seen.append(stat)

	# --- каждому стату пула назначено правило отображения ---
	for cat in ["weapon", "clothing"]:
		for e in Pool.entries(cat):
			var stat: String = str(e["stat"])
			ck(Pool.MERGED.has(stat) or Pool.ROW_ORDER.has(stat), "display rule for " + cat + "/" + stat)

	# --- и обратное: ROW_ORDER не выдумывает статов ---
	var pool_stats: Array = Pool.affix_ids("weapon") + Pool.affix_ids("clothing")
	for stat in Pool.ROW_ORDER:
		ck(pool_stats.has(stat), "ROW_ORDER stat exists in pool: " + str(stat))

	var problems: Array = Pool.validate()
	ck(problems.is_empty(), "validate(): " + str(problems))

	print("")
	if fails > 0:
		print("FAILED: %d" % fails)
		quit(1)
	else:
		print("tests passed")
		quit(0)
```

- [ ] **Step 2: Прогнать тест, убедиться что падает**

```powershell
Copy-Item "D:\RTVMOD\standalone mods\RoadToLoot\mods\RoadToLoot\*.gd" "D:\RTVMOD\.check\project\mods\RoadToLoot" -Force
D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe --headless --path "D:\RTVMOD\.check\project" --script "res://tests/test_rtl_pool.gd" --quit-after 600
```

Expected: скрипт падает на `Pool.MERGED` (`Parse Error: Cannot find member "MERGED"` / `SCRIPT ERROR`) либо печатает `FAILED: n` — в любом случае **нет** `tests passed`.

- [ ] **Step 3: Удалить обе записи `condition` из `POOL`**

Удалить блоки `{"stat": "condition", "category": "weapon", ... "needs": "damage"}` (строки 20–21) и `{"stat": "condition", "category": "clothing", ...}` (строки 48–49). `POOL` остаётся 15 записей.

- [ ] **Step 4: Добавить константы после `const POOL`**

```gdscript
# MERGED: аффикс вписывается суммой в ванильную строку тултипа, своей строки не получает.
const MERGED := {
	"damage": "Damage",
	"carry": "Capacity",
	"insulation": "Insulation",
	"protection": "Protection",
}

# ROW_ORDER: порядок собственных строк тултипа. Слитые статы сюда не входят.
# Порядок фиксирован, чтобы список не переставлялся от предмета к предмету.
const ROW_ORDER := [
	"recoil", "fire_rate", "low_hp_damage",
	"regen", "low_hp_regen",
	"stamina_drain", "thirst_drain", "hunger_drain", "sanity_drain",
	"noise", "sprint",
]
```

- [ ] **Step 5: Убрать `condition` из `RTLStats.KNOWN_STATS`**

`RTLStats.gd:3-5`: массив без `"condition"` (12 статов).

- [ ] **Step 6: Дописать в `test_rtl_stats.gd` проверку легаси-`condition`**

В фикстуру `s3` (легаси-статы) добавить `{"stat": "condition", "value": 0.20, "unit": "pct"}` и после `ck(not t3.has("sway"), ...)` добавить:

```gdscript
	ck(not t3.has("condition"), "legacy condition ignored")
```

- [ ] **Step 7: Прогнать оба теста**

```powershell
Copy-Item "D:\RTVMOD\standalone mods\RoadToLoot\mods\RoadToLoot\*.gd" "D:\RTVMOD\.check\project\mods\RoadToLoot" -Force
$g="D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe"
& $g --headless --path "D:\RTVMOD\.check\project" --script "res://tests/test_rtl_pool.gd" --quit-after 600
& $g --headless --path "D:\RTVMOD\.check\project" --script "res://tests/test_rtl_stats.gd" --quit-after 600
```

Expected: оба печатают `tests passed`, код 0.

- [ ] **Step 8: Commit**

```bash
git add "standalone mods/RoadToLoot/mods/RoadToLoot/RTLPool.gd" "standalone mods/RoadToLoot/mods/RoadToLoot/RTLStats.gd"
git commit -m "RTL 0.3.0 T3b.1: pool drops condition + MERGED/ROW_ORDER"
```

---

### Task 2: `RTLText` — подписи, знаки, значения, сумма

**Files:**
- Modify: `standalone mods/RoadToLoot/mods/RoadToLoot/RTLText.gd`
- Test: `.check/project/tests/test_rtl_text.gd`

**Interfaces:**
- Consumes: —
- Produces:
  - `RTLText.stat_label(stat: String) -> String` — подпись с двоеточием (`"Stamina Drain:"`)
  - `RTLText.stat_sign(stat: String) -> String` — `"+"` или `"-"`
  - `RTLText.stat_value(stat: String, value: float, unit: String) -> String` — `"-18%"`, `"+0.03 HP/s"`, `"+5kg"`, `"+1"`, `"x1.2"`
  - `RTLText.merged_value(stat: String, value: float, base: float) -> String` — `"120"`, `"+35kg"`, `"Level 2"`
  - Старые `format_line`/`legacy_format`/`format_affix` пока остаются (их удаляет Task 5, когда погаснет последний вызов).

- [ ] **Step 1: Дописать тесты новых функций в конец `test_rtl_text.gd`** (перед блоком `print("")`)

```gdscript
	# --- stat_label: алиасы и фолбэк ---
	ck(Text.stat_label("carry") == "Carry:", "label carry")
	ck(Text.stat_label("stamina_drain") == "Stamina Drain:", "label stamina_drain")
	ck(Text.stat_label("low_hp_regen") == "Low HP Regen:", "label alias low_hp_regen")
	ck(Text.stat_label("low_hp_damage") == "Low HP Damage:", "label alias low_hp_damage")
	ck(Text.stat_label("fire_rate") == "Fire Rate:", "label alias fire_rate")
	ck(Text.stat_label("max_hp") == "Max HP:", "label alias max_hp")
	ck(Text.stat_label("sway") == "Sway:", "label unknown falls back")

	# --- stat_value: знаки (D6) ---
	ck(Text.stat_value("recoil", 0.18, "pct") == "-18%", "recoil: " + Text.stat_value("recoil", 0.18, "pct"))
	ck(Text.stat_value("noise", 0.20, "pct") == "-20%", "noise: " + Text.stat_value("noise", 0.20, "pct"))
	for stat in ["stamina_drain", "thirst_drain", "hunger_drain", "sanity_drain"]:
		ck(Text.stat_value(stat, 0.12, "pct").begins_with("-"), stat + " negative")
	for stat in ["damage", "fire_rate", "low_hp_damage", "sprint"]:
		ck(Text.stat_value(stat, 0.10, "pct") == "+10%", stat + " positive")

	# --- stat_value: единицы ---
	ck(Text.stat_value("regen", 0.03, "rate") == "+0.03 HP/s", "rate unit")
	ck(Text.stat_value("carry", 5.0, "kg") == "+5kg", "kg unit")
	ck(Text.stat_value("protection", 1.0, "flat") == "+1", "flat unit")
	ck(Text.stat_value("max_hp", 10.0, "hp") == "+10", "hp unit")
	ck(Text.stat_value("sway", 1.2, "mult") == "x1.2", "mult unit")

	# --- каждая запись пула даёт читаемую пару подпись/значение ---
	for cat in ["weapon", "clothing"]:
		for e in Pool.entries(cat):
			var stat: String = str(e["stat"])
			var unit: String = str(e["unit"])
			ck(Text.stat_label(stat).ends_with(":"), "pool label ends with colon: " + stat)
			ck(Text.stat_value(stat, 0.10, unit) != "", "pool value non-empty: " + stat)

	# --- merged_value: сумма с ванильной базой (§6.1 спеки) ---
	ck(Text.merged_value("damage", 0.20, 100.0) == "120", "damage 100 +20%")
	ck(Text.merged_value("insulation", 0.30, 20.0) == "+26", "insulation 20 +30%")
	ck(Text.merged_value("carry", 15.0, 20.0) == "+35kg", "carry 20 +15")
	ck(Text.merged_value("protection", 1.0, 1.0) == "Level 2", "protection 1 +1")
```

В шапке файла добавить preload пула:

```gdscript
const Pool = preload("res://mods/RoadToLoot/RTLPool.gd")
```

- [ ] **Step 2: Прогнать тест, убедиться что падает**

```powershell
Copy-Item "D:\RTVMOD\standalone mods\RoadToLoot\mods\RoadToLoot\*.gd" "D:\RTVMOD\.check\project\mods\RoadToLoot" -Force
D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe --headless --path "D:\RTVMOD\.check\project" --script "res://tests/test_rtl_text.gd" --quit-after 600
```

Expected: `SCRIPT ERROR: Invalid call. Nonexistent function 'stat_label'` и/или `FAILED: n`.

- [ ] **Step 3: Добавить в `RTLText.gd` константы и четыре функции**

```gdscript
const STAT_LABELS := {
	"low_hp_regen": "Low HP Regen",
	"low_hp_damage": "Low HP Damage",
	"fire_rate": "Fire Rate",
	"max_hp": "Max HP",
}

# Меньше — лучше: минус читается как бонус, плюс сбивал бы с толку.
const NEGATIVE_STATS := ["stamina_drain", "thirst_drain", "hunger_drain", "sanity_drain", "noise", "recoil"]

static func stat_label(stat: String) -> String:
	var label: String = STAT_LABELS.get(stat, stat.capitalize().replace("_", " "))
	return label + ":"

static func stat_sign(stat: String) -> String:
	return "-" if NEGATIVE_STATS.has(stat) else "+"

static func stat_value(stat: String, value: float, unit: String) -> String:
	var prefix := stat_sign(stat)
	match unit:
		"pct":
			return "%s%d%%" % [prefix, int(round(absf(value) * 100.0))]
		"rate":
			return "%s%.2f HP/s" % [prefix, absf(value)]
		"kg":
			return "%s%dkg" % [prefix, int(round(absf(value)))]
		"mult":
			return "x%.1f" % absf(value)
		_:
			return "%s%d" % [prefix, int(round(absf(value)))]

# Сумма аффикса с ванильной базой. Формат повторяет ванильные строки:
# Damage — голое число, Insulation — "+N", Capacity — "+Nkg", Protection — "Level N".
static func merged_value(stat: String, value: float, base: float) -> String:
	match stat:
		"damage":
			return str(int(round(base * (1.0 + value))))
		"insulation":
			return "+%d" % int(round(base * (1.0 + value)))
		"carry":
			return "+%dkg" % int(round(base + value))
		"protection":
			return "Level %d" % int(round(base + value))
	return str(int(round(base + value)))
```

- [ ] **Step 4: Прогнать тест до зелёного**

Тот же прогон, что в Step 2. Expected: `tests passed`, код 0.

- [ ] **Step 5: Commit**

```bash
git add "standalone mods/RoadToLoot/mods/RoadToLoot/RTLText.gd"
git commit -m "RTL 0.3.0 T3b.2: RTLText stat label/value/merged formatters"
```

---

### Task 3: `RTLRows` — чистая модель строк тултипа

**Files:**
- Create: `standalone mods/RoadToLoot/mods/RoadToLoot/RTLRows.gd`
- Create: `.check/project/tests/test_rtl_rows.gd`
- Modify: `.check/check.ps1:180` (список `$tests`)

**Interfaces:**
- Consumes: `Pool.ROW_ORDER`, `Pool.MERGED` (Task 1); `Text.stat_label`, `Text.stat_value` (Task 2).
- Produces: `RTLRows.build(affixes: Array, merged: Array, color: Color) -> Dictionary` → `{"rows": Array, "skipped": Array}`, где строка = `{"stat": String, "label": String, "value": String, "color": Color}`. `affixes` — формат `RTLStore.affixes()` (`[{stat, value, unit}]`), `merged` — статы, уже вписанные в ванильные строки.

- [ ] **Step 1: Написать `test_rtl_rows.gd`**

```gdscript
extends SceneTree

const Rows = preload("res://mods/RoadToLoot/RTLRows.gd")

const COLOR := Color(1.0, 0.8, 0.2)

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _stats(rows: Array) -> Array:
	var out: Array = []
	for r in rows:
		out.append(str(r["stat"]))
	return out

func _init() -> void:
	var res: Dictionary = Rows.build([], [], COLOR)
	ck(res["rows"].is_empty(), "no affixes: no rows")
	ck(res["skipped"].is_empty(), "no affixes: nothing skipped")

	# порядок задаёт ROW_ORDER, а не порядок аффиксов
	res = Rows.build([
		{"stat": "sprint", "value": 0.08, "unit": "pct"},
		{"stat": "recoil", "value": 0.18, "unit": "pct"},
		{"stat": "regen", "value": 0.03, "unit": "rate"},
	], [], COLOR)
	ck(_stats(res["rows"]) == ["recoil", "regen", "sprint"],
		"order follows ROW_ORDER: " + str(_stats(res["rows"])))

	# слитые статы своих строк не получают
	res = Rows.build([
		{"stat": "carry", "value": 5.0, "unit": "kg"},
		{"stat": "damage", "value": 0.20, "unit": "pct"},
		{"stat": "noise", "value": 0.20, "unit": "pct"},
	], ["carry", "damage"], COLOR)
	ck(_stats(res["rows"]) == ["noise"], "merged stats skipped: " + str(_stats(res["rows"])))

	# слитый стат без ванильной строки -> своя строка (fallback §7.5)
	res = Rows.build([{"stat": "carry", "value": 5.0, "unit": "kg"}], [], COLOR)
	ck(_stats(res["rows"]) == ["carry"], "unmerged carry falls back to a row")
	ck(str(res["rows"][0]["label"]) == "Carry:", "fallback label: " + str(res["rows"][0]["label"]))
	ck(str(res["rows"][0]["value"]) == "+5kg", "fallback value: " + str(res["rows"][0]["value"]))

	# condition не показывается и репортится как skipped
	res = Rows.build([
		{"stat": "condition", "value": 0.20, "unit": "pct"},
		{"stat": "stamina_drain", "value": 0.15, "unit": "pct"},
	], [], COLOR)
	ck(_stats(res["rows"]) == ["stamina_drain"], "condition has no row")
	ck(res["skipped"] == ["condition"], "condition reported as skipped")

	# легаси-статы 0.2.x идут после статов пула, в порядке аффиксов
	res = Rows.build([
		{"stat": "max_hp", "value": 10.0, "unit": "hp"},
		{"stat": "stamina_drain", "value": 0.15, "unit": "pct"},
		{"stat": "sway", "value": 1.2, "unit": "mult"},
	], [], COLOR)
	ck(_stats(res["rows"]) == ["stamina_drain", "max_hp", "sway"],
		"legacy stats appended: " + str(_stats(res["rows"])))

	# дубль стата суммируется, а не перезаписывается
	res = Rows.build([
		{"stat": "carry", "value": 5.0, "unit": "kg"},
		{"stat": "carry", "value": 10.0, "unit": "kg"},
	], [], COLOR)
	ck(res["rows"].size() == 1, "duplicate stat: one row")
	ck(str(res["rows"][0]["value"]) == "+15kg", "duplicate stat sums: " + str(res["rows"][0]["value"]))

	# цвет и знак переносятся в строку
	res = Rows.build([{"stat": "recoil", "value": 0.18, "unit": "pct"}], [], COLOR)
	ck(res["rows"][0]["color"] == COLOR, "row keeps tier colour")
	ck(str(res["rows"][0]["value"]) == "-18%", "row value has sign")

	# мусор во входе не роняет сборку
	res = Rows.build([{"value": 1.0}, "nope", null], [], COLOR)
	ck(res["rows"].is_empty(), "garbage affixes ignored")

	print("")
	if fails > 0:
		print("FAILED: %d" % fails)
		quit(1)
	else:
		print("tests passed")
		quit(0)
```

- [ ] **Step 2: Зарегистрировать тест в `check.ps1`**

В строке 180 список `$tests` начинается с `"res://tests/test_rtl_pool.gd", ...` — добавить `"res://tests/test_rtl_rows.gd"` сразу после `"res://tests/test_rtl_text.gd"`.

- [ ] **Step 3: Прогнать тест, убедиться что падает**

```powershell
D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe --headless --path "D:\RTVMOD\.check\project" --script "res://tests/test_rtl_rows.gd" --quit-after 600
```

Expected: `Failed to load script "res://mods/RoadToLoot/RTLRows.gd"` (файла ещё нет).

- [ ] **Step 4: Написать `RTLRows.gd`**

```gdscript
extends RefCounted

# Строки тултипа для аффиксов: суммирование, порядок, исключения, формат.
# Ни узлов, ни load(), ни путей внутрь игры — чистая логика, покрыта test_rtl_rows.gd.

const Pool = preload("res://mods/RoadToLoot/RTLPool.gd")
const Text = preload("res://mods/RoadToLoot/RTLText.gd")

# Статы, которые не показываются в тултипе вовсе (§D2 спеки).
const HIDDEN := ["condition"]

# affixes: [{stat, value, unit}] из RTLStore.affixes()
# merged: статы, уже вписанные в ванильные строки — своей строки им не нужно.
# Возвращает {rows: [{stat, label, value, color}], skipped: [stat]}.
static func build(affixes: Array, merged: Array, color: Color) -> Dictionary:
	var values: Dictionary = {}
	var units: Dictionary = {}
	for a in affixes:
		if not (a is Dictionary):
			continue
		var stat: String = str(a.get("stat", ""))
		if stat == "":
			continue
		values[stat] = float(values.get(stat, 0.0)) + float(a.get("value", 0.0))
		if not units.has(stat):
			units[stat] = str(a.get("unit", "pct"))
	var rows: Array = []
	var skipped: Array = []
	var done: Dictionary = {}
	for stat in Pool.ROW_ORDER:
		if not values.has(stat) or merged.has(stat):
			continue
		done[stat] = true
		rows.append(_row(stat, values, units, color))
	for stat in values.keys():
		if done.has(stat) or merged.has(stat):
			continue
		if HIDDEN.has(stat):
			skipped.append(stat)
			continue
		rows.append(_row(stat, values, units, color))
	return {"rows": rows, "skipped": skipped}

static func _row(stat: String, values: Dictionary, units: Dictionary, color: Color) -> Dictionary:
	return {
		"stat": stat,
		"label": Text.stat_label(stat),
		"value": Text.stat_value(stat, float(values[stat]), str(units.get(stat, "pct"))),
		"color": color,
	}
```

- [ ] **Step 5: Прогнать тест до зелёного**

```powershell
Copy-Item "D:\RTVMOD\standalone mods\RoadToLoot\mods\RoadToLoot\*.gd" "D:\RTVMOD\.check\project\mods\RoadToLoot" -Force
D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe --headless --path "D:\RTVMOD\.check\project" --script "res://tests/test_rtl_rows.gd" --quit-after 600
```

Expected: `tests passed`, код 0.

- [ ] **Step 6: Commit**

```bash
git add "standalone mods/RoadToLoot/mods/RoadToLoot/RTLRows.gd"
git commit -m "RTL 0.3.0 T3b.3: RTLRows pure tooltip row model"
```

---

### Task 4: `RTLDisplay` — строки вместо блока

**Files:**
- Modify: `standalone mods/RoadToLoot/mods/RoadToLoot/RTLDisplay.gd`

**Interfaces:**
- Consumes: `Pool.MERGED` (Task 1), `Text.merged_value` (Task 2), `Rows.build(affixes, merged, color)` (Task 3).
- Produces: `apply_tooltip(hint)` без блока; `clear_tooltip()` и `invalidate_tooltip()` снимают строки и возвращают ванильные цвета. Публичный API модуля не меняется — `RTLBoot` править не нужно.

- [ ] **Step 1: Заменить константы и поля блока на константы и поля строк**

Удалить `PASSIVE_BOX_NAME`, `PASSIVE_TAG`, `_box`, `_last_tooltip_box_item_id`. Добавить:

```gdscript
const Rows = preload("res://mods/RoadToLoot/RTLRows.gd")

const ROW_NAME := "_rtl_stat"
const ROW_TAG := "rtl_stat"
const ROW_VALUE_MIN_W := 40.0
```

```gdscript
var _rows_root = null
var _rows: Array = []
var _merged_values: Array = []
var _last_rows_item_id: int = 0
var _warned_hidden: bool = false
```

- [ ] **Step 2: Переписать хвост `apply_tooltip`**

От строки `# Read sidecar data for uid/plate` до конца функции (`Log.line("inserted passive box: ...")`) — заменить на:

```gdscript
	var type_node = tooltip.get("type")
	if type_node == null:
		type_node = tooltip.get_node_or_null("Panel/Margin/Elements/Type")
	var parent = type_node.get_parent() if type_node != null else tooltip.get_node_or_null("Panel/Margin/Elements")
	if parent == null:
		_clear_all()
		if not _did_inspect_tooltip:
			_did_inspect_tooltip = true
			Log.line("apply_tooltip: no Elements (tooltip=" + str(tooltip) + ")")
			_inspect_tooltip(tooltip)
		return
	# Ванильный Update() перезапускается каждые 10 физических кадров и каждый раз
	# возвращает ванильные тексты, поэтому сумма пересчитывается на каждом вызове.
	var merged: Array = _apply_merges(parent, item, tier)
	_sync_rows(parent, item, tier, item_id, merged)
```

Вызовы `_drop_block()` в трёх ранних выходах (`item == null`, `tier <= 0`, `show_affix_block == false`) заменить на `_clear_all()`.

Дамп `_inspect_tooltip` остаётся только на аварийной ветке (не нашли `Elements`): это диагностика поломки после апдейта игры, а не постоянный лог, поэтому под `debug_enabled` его не заводим.

- [ ] **Step 3: Добавить новые методы, удалить методы блока**

Удалить `_drop_block`, `_sweep_boxes`. Добавить:

```gdscript
# affix stat -> суммарное значение. Два ролла одного стата (легаси-сейв,
# ручная правка) складываются, а не перезаписываются.
func _affix_map(item) -> Dictionary:
	var out: Dictionary = {}
	for a in Store.affixes(item.slotData):
		if not (a is Dictionary):
			continue
		var stat: String = str(a.get("stat", ""))
		if stat == "":
			continue
		out[stat] = float(out.get(stat, 0.0)) + float(a.get("value", 0.0))
	return out

# Ванильная база строки: ItemData.damage/capacity/insulation/protection.
func _base_value(item, stat: String) -> float:
	if item == null or not ("slotData" in item) or item.slotData == null:
		return 0.0
	if not ("itemData" in item.slotData):
		return 0.0
	var data = item.slotData.itemData
	if data == null or not (stat in data):
		return 0.0
	return float(data.get(stat))

# Возвращает статы, вписанные в ванильные строки: своим строкам они не нужны.
# Строка не найдена/скрыта или база нулевая — стат остаётся в списке как своя строка.
func _apply_merges(parent, item, tier: int) -> Array:
	_clear_merges()
	var out: Array = []
	var by_stat: Dictionary = _affix_map(item)
	var color := _border_color(tier)
	for stat in Pool.MERGED:
		if not by_stat.has(stat):
			continue
		var row = parent.find_child(str(Pool.MERGED[stat]), false, false)
		if row == null or not (row is Label) or row.get_child_count() == 0 or not row.visible:
			continue
		var base: float = _base_value(item, stat)
		if base <= 0.0:
			continue
		var value = row.get_child(0)
		value.text = Text.merged_value(stat, float(by_stat[stat]), base)
		value.modulate = color
		_merged_values.append(value)
		out.append(stat)
	return out

func _clear_merges() -> void:
	for v in _merged_values:
		if is_instance_valid(v):
			v.modulate = Color(1, 1, 1, 1)
	_merged_values.clear()

func _sync_rows(parent, item, tier: int, item_id: int, merged: Array) -> void:
	var built: Dictionary = Rows.build(Store.affixes(item.slotData), merged, _border_color(tier))
	var specs: Array = built["rows"]
	if _cfg != null and _cfg.debug_enabled and not built["skipped"].is_empty() and not _warned_hidden:
		_warned_hidden = true
		Log.line("tooltip: affix stats not shown: " + str(built["skipped"]))
	if _rows_root != parent or _last_rows_item_id != item_id or _rows.size() != specs.size():
		_remove_rows()
		_sweep_rows(parent)
		_build_rows(parent, specs)
		_rows_root = parent
		_last_rows_item_id = item_id
		return
	for i in range(specs.size()):
		_write_row(_rows[i], specs[i])
	_rows_root = parent
```

- [ ] **Step 4: Добавить сборку узлов строк**

```gdscript
# Клон ванильной строки Capacity: шрифт, кегль и сдвиг значения достаются
# бесплатно. Сдвиг пересчитывается от ширины текста, как это сделано в сцене.
func _build_rows(parent, specs: Array) -> void:
	if specs.is_empty():
		return
	var template = parent.find_child("Capacity", false, false)
	if template == null or not (template is Label) or template.get_child_count() == 0:
		Log.warn("tooltip: no Capacity row to clone; affix rows skipped")
		return
	var template_value = template.get_child(0)
	var template_w: float = _text_width(template, template.text)
	var index: int = _rows_index(parent)
	for spec in specs:
		var row = template.duplicate()
		row.name = ROW_NAME
		row.set_meta(ROW_TAG, true)
		row.visible = true
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.text = str(spec["label"])
		var value = row.get_child(0)
		var shift: float = _text_width(row, row.text) - template_w
		value.offset_left = template_value.offset_left + shift
		value.offset_right = value.offset_left + ROW_VALUE_MIN_W
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(row)
		parent.move_child(row, index)
		index += 1
		_rows.append(row)
		_write_row(row, spec)

func _write_row(row, spec: Dictionary) -> void:
	if row == null or not is_instance_valid(row) or row.get_child_count() == 0:
		return
	row.text = str(spec["label"])
	var value = row.get_child(0)
	value.text = str(spec["value"])
	value.modulate = spec["color"]

func _text_width(node, text: String) -> float:
	var font = node.get_theme_font("font")
	if font == null:
		return 0.0
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, node.get_theme_font_size("font_size")).x

# Строки идут на место блока: перед Nested, иначе в конец списка.
func _rows_index(parent) -> int:
	var nested = parent.find_child("Nested", false, false)
	if nested != null:
		return nested.get_index()
	return parent.get_child_count()

func _remove_rows() -> void:
	_last_rows_item_id = 0
	_rows.clear()
	var parent = _rows_root
	_rows_root = null
	if parent == null or not is_instance_valid(parent):
		return
	_sweep_rows(parent)

# remove_child до queue_free: удаляемый узел занимает слот до конца кадра,
# и замена с тем же именем получает суффикс `_rtl_stat2`.
func _sweep_rows(parent) -> void:
	for child in parent.get_children():
		if child != null and child.has_meta(ROW_TAG):
			parent.remove_child(child)
			child.queue_free()

func _clear_all() -> void:
	_remove_rows()
	_clear_merges()
```

- [ ] **Step 5: Починить `clear_tooltip` и `invalidate_tooltip`**

```gdscript
func invalidate_tooltip() -> void:
	_last_rows_item_id = 0

func clear_tooltip() -> void:
	_last_tooltip_item_id = 0
	_clear_all()
```

- [ ] **Step 6: Прогнать стенд парсинга по RTL**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\RTVMOD\.check\check.ps1"
```

Expected: `ok    RoadToLoot/RTLDisplay.gd` в блоке parse-check, `Parse check passed`, все тесты `VERDICT: ok`, в конце `Tests passed`. Если в выводе есть `SCRIPT ERROR|Parse Error|Invalid call` — задача не закрыта.

- [ ] **Step 7: Ручная проверка в игре**

```powershell
cd "D:\RTVMOD\standalone mods\RoadToLoot"
powershell -ExecutionPolicy Bypass -File pack.ps1
Copy-Item ".\RoadToLoot.vmz" "D:\SteamLibrary\steamapps\common\Road to Vostok\mods" -Force
```

Дальше по чек-листу (MCM: debug mode + force tier, если удобнее):

1. Оружие с тиром: `Damage` показывает сумму, цифра цветом тира; `Recoil`/`Fire Rate` — отдельные строки тем же шрифтом и кеглем, что `Damage`.
2. Одежда с тиром: `Capacity` — `+Nkg` суммой, `Insulation` — сумма, дренажи — отдельные строки.
3. Заголовка `Passive - …` нет ни на одном предмете.
4. Тултип открыт 10+ секунд: строки не размножаются, значения не плывут.
5. Навести на второй предмет (и на предмет без тира): чужих строк нет, ванильные цифры не остались покрашенными.
6. Инфо-панель (`Tooltip.Info`) после предмета: строк мода нет.
7. `show_affix_block = false` в MCM: ни одной строки мода, тултип как без мода.
8. Самое длинное: `Stamina Drain:` / `Hunger Drain:` и `+0.03 HP/s` — значение внутри панели, не за краем и не налезает на подпись.

- [ ] **Step 8: Commit**

```bash
git add "standalone mods/RoadToLoot/mods/RoadToLoot/RTLDisplay.gd"
git commit -m "RTL 0.3.0 T3b.4: inline affix rows and merged vanilla values"
```

---

### Task 5: Убрать мёртвое форматирование и мёртвую ветку `needs`

**Files:**
- Modify: `standalone mods/RoadToLoot/mods/RoadToLoot/RTLText.gd`
- Modify: `standalone mods/RoadToLoot/mods/RoadToLoot/RTLRoll.gd:63-82,140-181`
- Test: `.check/project/tests/test_rtl_text.gd`, `.check/project/tests/test_rtl_roll.gd`

**Interfaces:**
- Consumes: — (последний вызов `Text.format_affix` ушёл в Task 4)
- Produces: `RTLText` без `format_line`/`legacy_format`/`format_affix`; `RTLRoll` без `format_affix`/`format_delta` и без ветки `need == "damage"`.

Это задача на удаление кода, а не на новое поведение: красного теста у неё нет. Гейт — стенд парсинга: уцелевший вызов удалённой *статической* функции (`Text.format_affix`) — это `SCRIPT ERROR`/`Parse Error` при компиляции модуля, а не тихий no-op.

- [ ] **Step 1: Переписать `test_rtl_roll.gd`**

```gdscript
extends SceneTree

const Roll = preload("res://mods/RoadToLoot/RTLRoll.gd")
const Pool = preload("res://mods/RoadToLoot/RTLPool.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _stats(affixes: Array) -> Array:
	var out: Array = []
	for a in affixes:
		out.append(str(a.get("stat", "")))
	return out

func _init() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	ck(Roll.build_affixes("clothing", 1, {}, [], rng).size() == 1, "clothing tier=1: 1 affix")
	ck(Roll.build_affixes("clothing", 0, {}, [], rng).size() == 0, "tier=0: 0 affixes")
	rng.seed = 123
	ck(Roll.build_affixes("clothing", 3, {}, [], rng).size() == 3, "tier=3: 3 affixes")

	# weapon-пул больше не пуст (4 стата release=2)
	rng.seed = 42
	ck(Roll.build_affixes("weapon", 2, {}, [], rng).size() == 2, "weapon tier=2: 2 affixes")

	# condition не ролится ни в одной категории
	var with_bases := {"capacity": 20.0, "insulation": 20.0, "damage": 30.0, "type": "Armor"}
	var seen: Array = []
	rng.seed = 7
	for i in range(200):
		for cat in ["weapon", "clothing"]:
			for stat in _stats(Roll.build_affixes(cat, 3, with_bases, [], rng)):
				if not seen.has(stat):
					seen.append(stat)
	ck(not seen.has("condition"), "condition never rolls: " + str(seen))
	ck(seen.size() >= 12, "rolls reach most of the pool: " + str(seen.size()))

	# needs-гейты живы
	var bare: Array = []
	rng.seed = 11
	for i in range(200):
		for stat in _stats(Roll.build_affixes("clothing", 3, {}, [], rng)):
			if not bare.has(stat):
				bare.append(stat)
	ck(not bare.has("carry"), "carry needs capacity")
	ck(not bare.has("insulation"), "insulation needs insulation")
	ck(not bare.has("protection"), "protection needs armor")
	ck(seen.has("carry"), "carry rolls when capacity > 0")
	ck(seen.has("protection"), "protection rolls for Armor")

	print("")
	if fails > 0:
		print("FAILED: %d" % fails)
		quit(1)
	else:
		print("tests passed")
		quit(0)
```

- [ ] **Step 2: Удалить из `test_rtl_text.gd` проверки удаляемых функций**

Убрать блоки `format_line`, `legacy_format`, `format_affix` (строки до `stat_label`-блока). Новые проверки `stat_label`/`stat_value`/`merged_value` остаются.

- [ ] **Step 3: Удалить `format_affix` и `format_delta` из `RTLRoll.gd`**

Строки 140–181 (`format_affix`, комментарий и `format_delta`) удалить целиком.

- [ ] **Step 4: Удалить мёртвую ветку `need == "damage"` в `RTLRoll.build_affixes`**

В цикле фильтра по `needs` убрать:

```gdscript
		if need == "damage":
			var v = item_data.get("damage")
			ok = float(v if v != null else 0) > 0
```

(`carry`/`insulation`/`armor` остаются: единственный потребитель `damage` был у снятого `condition`.)

- [ ] **Step 5: Удалить `format_line`, `legacy_format`, `format_affix` из `RTLText.gd`**

Файл содержит только новые `stat_label`/`stat_sign`/`stat_value`/`merged_value` и их константы.

- [ ] **Step 6: Прогнать стенд**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\RTVMOD\.check\check.ps1"
```

Expected: `Parse check passed` (в том числе `ok    RoadToLoot/RTLText.gd` и `ok    RoadToLoot/RTLRoll.gd`), `VERDICT: ok` у всех, в конце `Tests passed`. Упавший `Parse check` со `SCRIPT ERROR` на `format_delta`/`format_affix` значит, что где-то остался вызов — найти его и убрать, а не возвращать функцию.

- [ ] **Step 7: Прогнать два затронутых теста точечно**

```powershell
$g="D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe"
& $g --headless --path "D:\RTVMOD\.check\project" --script "res://tests/test_rtl_text.gd" --quit-after 600
& $g --headless --path "D:\RTVMOD\.check\project" --script "res://tests/test_rtl_roll.gd" --quit-after 600
```

Expected: оба печатают `tests passed`.

- [ ] **Step 8: Commit**

```bash
git add "standalone mods/RoadToLoot/mods/RoadToLoot/RTLText.gd" "standalone mods/RoadToLoot/mods/RoadToLoot/RTLRoll.gd"
git commit -m "RTL 0.3.0 T3b.5: drop dead formatters and needs=damage branch"
```

---

### Task 6: Подпись тумблера в MCM и документы

**Files:**
- Modify: `standalone mods/RoadToLoot/mods/RoadToLoot/RTLBoot.gd:83`
- Modify: `docs/superpowers/plans/2026-10-26-road-to-loot-affixes-0.3.0.md` (§T3, §8.2)

**Interfaces:**
- Consumes: —
- Produces: ключ `show_affix_block` с новым `name`/`tooltip`; в плане 0.3.0 — пометка, что T3 заменён, и обновлённые строки CHANGELOG для T8.

- [ ] **Step 1: Переписать `name`/`tooltip` у `show_affix_block`**

Строка 83 `RTLBoot.gd`:

```gdscript
	cfg.set_value("Bool", "show_affix_block", {"name": "Show affixes in tooltip", "default": true, "value": true, "category": cat, "menu_pos": 1, "tooltip": "Merge the rolled affixes into the item stat list."})
```

Ключ `show_affix_block` не переименовывать: иначе у пользователя сбросится `value` (слияние конфига идёт по ключам).

- [ ] **Step 2: Пометить T3 плана 0.3.0 как заменённый**

Сразу под `## T3 — Тултип` (строка 264) вставить:

```markdown
> **Заменено 2026-10-27.** Вёрстка тултипа переехала в
> `docs/superpowers/specs/2026-10-27-road-to-loot-inline-stats-design.md` и
> `docs/superpowers/plans/2026-10-27-road-to-loot-inline-stats.md`: аффиксы
> сливаются в ванильные строки и клонируют строку `Capacity`, заголовок
> `Passive - <Tier>` не существует. §3.1–3.6 ниже не исполнять.
```

- [ ] **Step 3: Обновить §8.2 (CHANGELOG для 0.3.0)**

В блоке `## [0.3.0]` (строки 549–558) заменить строку

```markdown
- Affix pool gated by release (0.3.0: regen, low_hp_regen, carry, stamina_drain, insulation, thirst_drain, hunger_drain, sanity_drain).
```

на две:

```markdown
- Rarity affixes appear inside the item stat list, in the game's own font.
- Affix pool (15 stats): regen, low_hp_regen, carry, stamina_drain, insulation, thirst_drain, hunger_drain, sanity_drain, noise, sprint, protection, damage, recoil, fire_rate, low_hp_damage.
```

`condition` в §8.2 не упоминается — проверять нечего, но если после правок T8 список разойдётся с `RTLPool.POOL`, правильный источник — пул.

- [ ] **Step 4: Прогнать стенд**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\RTVMOD\.check\check.ps1"
```

Expected: `Parse check passed`, `Tests passed`.

- [ ] **Step 5: Commit**

```bash
git add "standalone mods/RoadToLoot/mods/RoadToLoot/RTLBoot.gd" docs/superpowers/plans/2026-10-26-road-to-loot-affixes-0.3.0.md
git commit -m "RTL 0.3.0 T3b.6: MCM wording + supersede old tooltip task"
```

---

## Файлы

| Файл | Что | Задача |
|---|---|---|
| `RTLPool.gd` | edit | T3b.1 |
| `RTLStats.gd` | edit | T3b.1 |
| `RTLText.gd` | edit | T3b.2, T3b.5 |
| `RTLRows.gd` | create | T3b.3 |
| `RTLDisplay.gd` | edit | T3b.4 |
| `RTLRoll.gd` | edit | T3b.5 |
| `RTLBoot.gd` | edit | T3b.6 |
| `.check/check.ps1` | edit | T3b.3 |
| `.check/project/tests/test_rtl_pool.gd` | edit | T3b.1 |
| `.check/project/tests/test_rtl_stats.gd` | edit | T3b.1 |
| `.check/project/tests/test_rtl_text.gd` | edit | T3b.2, T3b.5 |
| `.check/project/tests/test_rtl_rows.gd` | create | T3b.3 |
| `.check/project/tests/test_rtl_roll.gd` | edit | T3b.5 |
| `docs/superpowers/plans/2026-10-26-…0.3.0.md` | edit | T3b.6 |

## Вне объёма

- Применение аффиксов к геймплею (следующая задача после 0.3.0).
- Версия в `mod.txt`, `CHANGELOG.md`, `README.md` — T8 плана 0.3.0.
- `RTLApply`/сайдкар/хуки — не трогаем.
