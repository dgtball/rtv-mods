# Road To Loot 0.3.0 — живые аффиксы (план)

Дата: 2026-10-26 · Спека: `docs/superpowers/specs/2026-10-26-road-to-loot-affixes-live-design.md` (ред. 2, утверждена)
Срез: T1–T4 + T7–T8 (§15 спеки). 0.4.0 (T5/T6/T9) — оружейное окно, noise, sprint, плитка, `slotdata-update-post` — **не входит**.

## Цель 0.3.0

Аффиксы становятся живыми статами. Работают только с надетых предметов, в тултипе видны всегда.

| Что | Как |
|---|---|
| Дренажи | `character-energy/hydration/mental/stamina-pre/post` — доля от базового поля |
| Реген | `character-health-post` — `regen * delta`, `low_hp_regen` при `<30 HP` |
| `carry` | `interface-updatestats-post` — ёмкость + флаг overweight |
| `insulation` | то же окно — доля от `itemData.insulation` |
| Идентичность | `rtl_uid` в мете `SlotData`; сайдкар v4 по `uid` |
| Пул | 17 записей; `RTLPool.ACTIVE_RELEASE = 1` — только release=1 |

Легаси 0.2.25 (`max_hp`, `sway`, `penetration`, `durability`, `low_hp_regen mult`) — в сайдкаре,
показываются фолбэк-форматтером, в агрегацию не входят.

---

## T1 — Чистый слой

Срок: до того, как `$tests` в `.check/check.ps1` получит первую RTL-запись.

### 1.1 `RTLPool.gd` — гейт по релизу, фильтры, валидация

**Исходное:** 19 записей (есть `sway`, `penetration`, `durability`, `max_hp`, `low_hp_regen unit=mult`).

**Меняем:**
- Добавить поле `release: int = 1` каждой записи. release=1 — 0.3.0; release=2 — 0.4.0.
  Конкретно: `sway/recoil/fire_rate/low_hp_damage/condition(weapon)/noise/sprint/protection/condition(clothing)` → release=2;
  всё остальное → release=1.
- Удалить записи `sway`, `penetration`, `durability`, `max_hp`. Их 4.
- `low_hp_regen`: у existing entry `unit` меняется с `"mult"` на `"rate"`, ranges — `{1:[0.03,0.03],2:[0.05,0.05],3:[0.08,0.08]}`.
- Добавить константу `ACTIVE_RELEASE: int = 1`.

**Новые функции:**

```
static func entries(category: String) -> Array:
    # фильтрует POOL по category + release <= ACTIVE_RELEASE

static func affix_ids(category: String) -> Array:
    # только из отфильтрованных

static func build_affixes(category, tier, item_data, blocked, rng) -> Array:
    # blocked = Array[String] — stat names whose applier failed arity self-check
    # 1. отфильтровать по category + release + tier
    # 2. применить фильтры needs:
    #    - damage>0: item_data.damage > 0
    #    - capacity>0: item_data.capacity > 0
    #    - insulation>0: item_data.insulation > 0
    #    - type Helmet/Armor: item_data.type in ["Helmet","Armor"]
    # 3. исключить blocked
    # 4. ролл n аффиксов по весам, rng последним
```

Сигнатура `build_affixes` меняется! Было `build_affixes(cat, tier, rng)` — теперь `build_affixes(cat, tier, item_data, blocked, rng)`. Вызовы в `RTLRoll.gd` и `RTLBoot.gd` обновить.

`validate()`: новых проблем не должно появиться.

**Тест:** `test_rtl_pool.gd` — состав пула, отсутствие удалённых статов, гейт `ACTIVE_RELEASE`, `validate()` проходит.

### 1.2 `RTLRoll.gd` — адаптация `build_affixes`

**Меняем:** сигнатура `build_affixes(category, tier, item_data, blocked, rng)` (D15). Внутри:
- `Pool.affix_ids(category)` → `Pool.entries(category)` (создать если нет, или использовать новый `build_affixes` пула напрямую)
- фильтры `needs` — из пула (`needs` ключ есть у записи)
- `blocked` — Array[String], имена статов без аппликатора; исключаются перед роллом

**Новые функции:**
```
static func format_delta(stat, value, tier) -> String
    # форматирование одной строки: "+20% Damage", "−15% Stamina drain", ...
    # pct: sign + int(val*100) + "% " + label
    # rate: "Regen +X.X HP/s"
    # flat: "+X Protection" / "+1 Protection"
    # kg: "+Xkg Carry"
    # legacy mult/hp/sway/penetration — фолбэк: "Sway +X%", "Max HP +X" и т.д.
```

**Тест:** `test_rtl_roll.gd` — фильтры needs/category/blocked, rng последний, все тиры.

### 1.3 `RTLStats.gd` — новая агрегация

**Файла нет — создаём.** Рефакеренс как VTKSurface: `extends RefCounted`, статические функции.

```
static func clothing_totals(slots: Array) -> Dictionary:
    # slots: [{slot_name, slot_data, item_data}]
    # для каждого слота: сложить аффиксы slot_data
    # insulation: total += item_data.insulation * value (доля от базы, §9.2)
    # легаси-статы (max_hp/sway/penetration/durability/low_hp_regen_mult) — игнорировать
    # вернуть {stat: sum}

static func weapon_totals(slot_data) -> Dictionary:
    # один слот, один ствол — не суммировать Primary+Secondary
    # то же что clothing_totals но один slot_data
```

Кеша нет (слотов ≤ 7, пересчёт дешевле инвалидации).

**Тест:** `test_rtl_stats.gd` — `clothing_totals`/`weapon_totals`, insulation от базы, легаси игнорируются, плитка (plate) — это SlotData рига, ролл плитки берётся из `Store.plate_rolls(rig_slot_data)` если nested[index] ещё там.

### 1.4 `RTLText.gd` — форматирование

**Файла нет — создаём.** Статические функции, RefCounted.

```
static func format_affix(a: Dictionary, tier: int, locale: String = "en") -> String:
    # a = {stat, value, unit}
    # tier = 1/2/3 для цвета (но цвет возвращается отдельно)
    # вызывает format_delta / format_line
    # legacy-статы — фолбэк: stat.capitalize() + " " + value

static func format_line(stat: String, value: float, unit: String) -> String:
    # для всех НЕ-mapped статов (stamina_drain, thirst_drain, hunger_drain, sanity_drain, ...)
    # pct: "−15% Stamina drain" (drain всегда отрицательный sign)
    # rate: "+0.05 Regen"

static func legacy_format(stat: String, value: float, unit: String) -> String:
    # для статов не из пула 0.3.0
```

**Тест:** `test_rtl_text.gd` — все 17 статов, фолбэк для legacy.

### 1.5 `RTLPool.gd` — второе дыхание

После создания `RTLStats` и `RTLText` убедиться, что пул:
- проверяется `validate()` без проблем
- `entries()/affix_ids()` фильтруют по `ACTIVE_RELEASE`
- `build_affixes` фильтрует по `needs` из записи и по `blocked`

**После T1** — `.check/check.ps1` получает первую RTL-запись: copy-блок + `--check-only` цикл.

---

## T2 — Идентичность

### 2.1 `RTLSidecar.gd` — I/O с страховкой

**Файла нет — создаём.** Путь — аргумент с дефолтом `user://roadtoloot_moddata.json`, чтобы headless-тест писал в свой файл.

```
extends RefCounted

const CURRENT_VERSION := 4

var _path: String
var _bak_path: String
var _corrupt_prefix: String

func _init(p := "user://roadtoloot_moddata.json"):
    _path = p
    _bak_path = p + ".bak"
    _corrupt_prefix = p + ".corrupt-"

func write(data: Dictionary) -> bool:
    # сериализовать JSON → _write_atomic

func _write_atomic(content: String) -> bool:
    # 1. если _path существует → копировать в .bak
    # 2. записать в .tmp
    # 3. _replace(.tmp, _path); при Windows-ошибке удалить цель, повторить
    # вернуть OK / err

func read() -> Dictionary:
    # прочитать _path; если битый → .corrupt-<ts>, грузить .bak
    # v2/v3 — позиционные ключи → миграция в uid (один раз)
    # v4 — items:{uid:{t,a,p}}

func _migrate_v2_v3_entry(key, entry) -> Dictionary:
    # key = "inv|file|n" | "cat|file|n" | "eq|file|<slot>"
    # сгенерировать uid, записать items[uid] = {t,a,p}
```

Формат: `{v:4, items:{uid:{t:<tier>, a:[...affixes...], p:{nested_index:{file,t,a}}}}}`.

**Тест:** `test_rtl_sidecar.gd` — write/read/roundtrip, `.bak`, `corrupt-<ts>`, v2/v3/v4.

### 2.2 `RTLStore.gd` — uid, plate, copy_meta

**Добавляем:**

```
static func uid(slot_data) -> String:
    var u = slot_data.get_meta("rtl_uid")
    if u != null and u is String: return u
    u = "%016x" % randi() + "%016x" % randi()
    slot_data.set_meta("rtl_uid", u)
    return u

static func plate_rolls(slot_data) -> Dictionary:
    return slot_data.get_meta("rtl_plate") if slot_data.get_meta("rtl_plate") is Dictionary else {}

static func set_plate_roll(slot_data, nested_index: int, file: String, tier: int, affixes: Array) -> void:
    var plate: Dictionary = slot_data.get_meta("rtl_plate")
    if plate == null: plate = {}
    plate[str(nested_index)] = {"file": file, "t": tier, "a": affixes}
    slot_data.set_meta("rtl_plate", plate)

static func clear_plate_roll(slot_data, nested_index: int) -> void:
    var plate: Dictionary = slot_data.get_meta("rtl_plate")
    if plate != null: plate.erase(str(nested_index))

static func copy_meta(target, source) -> void:
    # копировать rtl_uid, rtl_loot_tier, rtl_loot_affixes, rtl_plate из source → target
```

**Тест:** `test_rtl_store.gd` — uid стабилен, `copy_meta`, plate-операции.

### 2.3 Хуки переноса меты

В `RTLBoot._ready` добавить:
```
_lib.hook("item-initialize-post", Callable(self, "on_item_initialize_meta"), 100)
_lib.hook("item-display-post", Callable(self, "on_item_display_meta"), 100)
_lib.hook("lootcontainer-storage-post", Callable(self, "on_container_storage_meta"), 100)
```

```
func on_item_initialize_meta(_source, data) -> void:
    # _caller = Item; data = SlotData из контейнера/сейва
    if _lib == null or not ("_caller" in _lib): return
    var item = _lib._caller
    if item == null or not ("slotData" in item) or item.slotData == null or data == null: return
    Store.copy_meta(item.slotData, data)

func on_item_display_meta(_source, data, _show_returns) -> void:
    # data = SlotData копии в витрине; копируем обратно в slotData (он уже заполнен Item.Display → slotData.Update(data))
    # нас интересует только uid который пришёл из data
    if _lib == null or not ("_caller" in _lib): return
    var item = _lib._caller
    if item == null or not ("slotData" in item) or data == null: return
    Store.copy_meta(item.slotData, data)

func on_container_storage_meta(container_grid) -> void:
    # Storage: containerGrid.get_children()[i] → storage[i]
    if _lib == null or not ("_caller" in _lib): return
    var container = _lib._caller
    if container == null or not ("storage" in container): return
    var children = container_grid.get_children()
    for i in range(min(children.size(), container.storage.size())):
        var child = children[i]
        if child == null or not ("slotData" in child) or child.slotData == null: continue
        Store.copy_meta(container.storage[i], child.slotData)
```

`combine`/`remove`/`combineswap` — НЕ регистрировать в 0.3.0 (T6).

### 2.4 Сайдкар → RTLSidecar

**RTLBoot:** функции `_sidecar_read` / `_sidecar_write` переписать:
- `write`: `var items := {}; for eq/inv/cat: items[uid] = {t,a}`; `Sidecar.write({v:4, items})`
- `read`: `var data = Sidecar.read()`; uid→slotData поиск (сканировать все grids + equipment, сравнивать `get_meta("rtl_uid")`); `Store.stamp(found, t, a)`

uid→slotData поиск при загрузке: O(n²) но n ≤ 63 (все слоты инвентаря), приемлемо при загрузке сейва.

---

## T3 — Тултип

> **Заменено 2026-10-27.** Вёрстка тултипа переехала в
> `docs/superpowers/specs/2026-10-27-road-to-loot-inline-stats-design.md` и
> `docs/superpowers/plans/2026-10-27-road-to-loot-inline-stats.md`: аффиксы
> сливаются в ванильные строки и клонируют строку `Capacity`, заголовок
> `Passive - <Tier>` не существует. §3.1–3.6 ниже не исполнять.

### 3.1 RTLText — форматирование (уже в T1.4)

К этому моменту `RTLText.format_affix(stat, value, unit)` существует и покрыт тестом.

### 3.2 `RTLDisplay.apply_tooltip` — перестройка

**Проблема ред. 1:** вложенный лейбл в ванильную строку; непонятно сколько детей у строки и как называется value-label. Стратегия — **логировать дамп до вёрстки**.

**Добавить в RTLDisplay метод для дампа (убрать после отладки):**
```
func _inspect_tooltip_structure(node: Node, depth: int = 0) -> void:
    if node == null or depth > 3: return
    var indent = "  ".repeat(depth)
    Log.line(indent + node.get_class() + " name=" + str(node.name) + " children=" + str(node.get_child_count()))
    for ch in node.get_children():
        _inspect_tooltip_structure(ch, depth + 1)
```

**В `apply_tooltip` — временный лог при первом входе в незнакомый tooltip (до сброса):**
```
if not _did_inspect_structure:
    _did_inspect_structure = true
    Log.line("=== TOOLTIP STRUCTURE ===")
    _inspect_tooltip_structure(tooltip)
```

**Валидация после дампа (3.3):** структура строк ванили известна — строки типа `Damage`/`Condition`/`Capacity`/`Insulation`/`Protection` имеют `get_child(0)` как value-Label. Наша вставка — sibling-лейбл рядом, не внутри value.

### 3.3 Структура тултипа (по дампу, in-code комментарий)

Vanilla tooltip rows (по `.gd:10-29`):
- Каждая строка — HBoxContainer (напр. `$Panel/Margin/Elements/Damage`)
- Его первый ребёнок `get_child(0)` — Label с текстом (напр. `int(itemData.damage)`)
- При вставке аффикса: **не трогать** `get_child(0)`, добавить sibling-Label рядом

**Mapping (D11):**

| stat | ванильная строка | наш текст |
|---|---|---|
| `damage` | `Damage` | `+20%` рядом с числом |
| `condition` (weapon) | `Condition` | `−40% wear` |
| `capacity`/`carry` | `Capacity` | `+5kg` |
| `insulation` | `Insulation` | `+15%` |
| `protection` | `Protection` | `+1` (T6, не 0.3.0) |
| все остальные | нет маппинга | своя строка после `Type` |

**Идемпотентность** (R9): при смене предмета — снять свой блок. `_last_tooltip_item_id` уже есть. При смене предмета (`_last_tooltip_item_id != item_id`): `_drop_block()`. Блок восстанавливается при следующем `apply_tooltip`.

### 3.4 Убираем заголовок "Passive - Tier"

В текущем `apply_tooltip`: `header.text = "Passive - " + Pool.TIER_NAMES[tier]`. Это **удалить**. Аффиксы идут отдельными строками, tier виден по цвету.

### 3.5 Цвет аффикса — по тиру предмета (D8)

```
const AFFIX_COLORS := {
    1: Color(0.45, 0.7, 1.0),   # common — голубой
    2: Color(0.8, 0.55, 1.0),   # rare — фиолетовый
    3: Color(1.0, 0.82, 0.3),   # legendary — золотой
}
```

Применять к каждой строке-лейблу аффикса. Строка Condition из ванили уже имеет modulate от ванили; нам нужно только вкладывать свою строку.

### 3.6 RTLDisplay._cfg — добавить `show_affix_block` (уже есть)

Проверить: `show_affix_block` — MCM Bool, по умолчанию true. Если false — `_drop_block()` и выйти.

---

## T4 — Аппликаторы

### 4.1 `RTLApply.gd` — новый файл, владелец хуков

```
extends RefCounted

var _host: Node         # RTLBoot
var _cfg                # ConfigRec
var _live: bool = false  # master switch from MCM

# Константы приоритетов (D21): 1000 — после ванили, 2000 — после Evolve (999)
# Все post — 2000; pre — 2000 или 1000 для updatestats
```

**Self-check арностей (D20, §12.3):** при регистрации каждого хука — проверить `cb.get_argument_count()`. Если ожидаемая арность не совпадает → `Log.warn("RTL: hook X arity mismatch — stat Y disabled")`, stat не выпадает (попадает в `blocked`). `test_rtl_arity.gd` проверяет таблицу §12.1 против зарегистрированных колбэков.

**Важно:** post для non-void (PlateCheck/HelmetCheck, AILoot, CombineSwap, Remove) получает `args + [_result]`. Для void (Health, Energy, …) — ровно арность.

### 4.2 MCM — флаг `live_stats`

В `RTLConfig.gd` добавить:
```
var live_stats: bool = true
var debug_live_stats: bool = false
```

В `RTLConfig.read`:
```
live_stats = _b(cfg, "live_stats", live_stats)
debug_live_stats = _b(cfg, "debug_live_stats", debug_live_stats)
```

В `build_config` (RTLBoot):
```
cfg.set_value("Bool", "live_stats", {"name": "Enable live stat effects", "default": true,
    "value": true, "category": bal, "menu_pos": 3,
    "tooltip": "Apply stat effects (drain, regen, carry…). Tooltip always shows."})
cfg.set_value("Bool", "debug_live_stats", {"name": "Debug live stats log", "default": false,
    "value": false, "category": dbg, "menu_pos": 4,
    "tooltip": "Print every stat application to the log."})
```

В `RTLApply`:
```
func apply_config(cfg: ConfigFile) -> void:
    if cfg == null: _live = true; return
    _live = cfg.get_value("Bool", "live_stats", true) if cfg.has_section_key("Bool", "live_stats") else true
    # _cfg.debug_live_stats тоже прочитать
```

### 4.3 Аппликатор дренажей (§9.1)

```
# character-energy-pre/post → hunger_drain
# character-hydration-pre/post → thirst_drain
# character-mental-pre/post → sanity_drain
# character-stamina-pre/post → stamina_drain
```

Общий примитив:
```
# pre: _before[field] = gameData.<field>; _blocked = false
# post: drained = _before[field] - gameData.<field>
#       if drained <= 0 or gameData.<field> <= 0: return
#       gameData.<field> = _before[field] - drained * (1 - x)
#       где x = sum(affix.value) для данного stat
```

`Stamina`Special: оба `bodyStamina` и `armStamina` в одном вызове. Pre сохраняет оба, post восстанавливает оба.

### 4.4 Аппликатор регена (§9.1b)

`character-health-post(delta)`:
```
# if gameData.isDead: return
# var healed = 0.0
# сумма regen × delta
# if gameData.health < 30.0: healed += low_hp_regen × delta
# if healed <= 0.0: return
# gameData.health = minf(gameData.health + healed, 100.0)
```
`Clamp()` в том же кадре гарантирует ≤ 100.

### 4.5 Аппликатор carry/insulation (§9.2)

`interface-updatestats-post(updateLabels)` — это корутина, post приходит **на кадр позже**.

```
# interface.currentInventoryCapacity += carry_sum
# if updateLabels:
#     пересчитать weight/capacity labels
# всегда, вне updateLabels:
#     if weight > capacity: character.Overweight(true) else: Overweight(false)
```

`insulation`:
```
# eq_total = sum(item.insulation * x)  # доля от базы
# interface.character.insulation = clampf(1.0 - eq_total / 100.0, 0.0, 1.0)
# if updateLabels: обновить insulation label
```

Guard: `is_instance_valid(interface.character)` — сцена могла смениться за кадр.

### 4.6 Лог аппликаций (§9.9)

Если `_cfg.debug_live_stats` (не `debug_enabled`):
```
[RTL] hunger_drain -0.15 (x=0.15) → hydration 85.3
[RTL] carry +5 → capacity 15.0 → 20.0 (overweight=false)
```
Одна строка на применение, не на кадр.

---

## T7 — Стенд

### 7.1 RTL в `.check/check.ps1`

После LooterShooter-блока (после :64) добавить:

```powershell
# Road To Loot
$rtlSrc = Join-Path (Split-Path $checkRoot -Parent) "standalone mods\RoadToLoot\mods\RoadToLoot"
$rtlDst = Join-Path $proj "mods\RoadToLoot"
if (Test-Path -LiteralPath $rtlSrc -PathType Container) {
    if (Test-Path -LiteralPath $rtlDst) { Remove-Item -LiteralPath $rtlDst -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $rtlDst | Out-Null
    Copy-Item -Path (Join-Path $rtlSrc "*.gd") -Destination $rtlDst -Force
    Copy-Item -Path (Join-Path $rtlSrc "*.tres") -Destination $rtlDst -Force -ErrorAction SilentlyContinue
    Copy-Item -Path (Join-Path $rtlSrc "*.gdshader") -Destination $rtlDst -Force -ErrorAction SilentlyContinue
}
```

Цикл `--check-only` после LSH-цикла (после :126):
```powershell
if (Test-Path -LiteralPath $rtlDst -PathType Container) {
    $rtlScripts = Get-ChildItem -LiteralPath $rtlDst -Filter "*.gd" | Sort-Object Name
    foreach ($s in $rtlScripts) {
        $res = "res://mods/RoadToLoot/" + $s.Name
        $out = & $Godot --headless --path $proj --check-only --script $res 2>&1 | Out-String
        $bad = ($LASTEXITCODE -ne 0) -or ($out -match "SCRIPT ERROR|Parse Error|Failed to load script")
        if ($bad) {
            $fail++
            Write-Host "FAIL  RoadToLoot/$($s.Name)"
            Write-Host $out.Trim()
        } else {
            Write-Host "ok    RoadToLoot/$($s.Name)"
        }
    }
}
```

**Важно:** RTL добавляется в стенд **до** T8. Иначе `.vmz` собирается без прогона.

### 7.2 RTL-тесты в `$tests`

Добавлять **после** написания каждого теста (в порядке T1→T4): `test_rtl_pool.gd`, `test_rtl_roll.gd`, `test_rtl_stats.gd`, `test_rtl_text.gd`, `test_rtl_sidecar.gd`, `test_rtl_store.gd`, `test_rtl_arity.gd`.

```
$tests = @(
    ...  # существующие тесты
    "res://tests/test_rtl_pool.gd",
    "res://tests/test_rtl_roll.gd",
    "res://tests/test_rtl_stats.gd",
    "res://tests/test_rtl_text.gd",
    "res://tests/test_rtl_sidecar.gd",
    "res://tests/test_rtl_store.gd",
    "res://tests/test_rtl_arity.gd",
)
```

`$tests` — явный список. Отсутствие файла → `throw` — гарантия что тест существует до попадания в список.

### 7.3 Порядок добавления тестов

1. **После T1.1** (`RTLPool` гейт): `$tests` + `test_rtl_pool.gd` + `test_rtl_roll.gd`
2. **После T1.3** (`RTLStats`): + `test_rtl_stats.gd`
3. **После T1.4** (`RTLText`): + `test_rtl_text.gd`
4. **После T2.1** (`RTLSidecar`): + `test_rtl_sidecar.gd`
5. **После T2.2** (`RTLStore`): + `test_rtl_store.gd`
6. **После T4.1** (`RTLApply` self-check): + `test_rtl_arity.gd`

Прогон стенда после каждого добавления — зелёный значит всё в порядке.

---

## T8 — Релиз 0.3.0

### 8.1 `mod.txt`

```
[mod]
name="Road To Loot"
id="road-to-loot"
version="0.3.0"

[autoload]
RTL="res://mods/RoadToLoot/RTLBoot.gd"

[hooks]
res://Scripts/LootContainer.gd = CreateLoot, AILoot, Storage
res://Scripts/Item.gd = Initialize, Display
res://Scripts/Loader.gd = SaveCharacter, LoadCharacter, NewGame
res://Scripts/Tooltip.gd = Update, Info
res://Scripts/Character.gd = Health, Energy, Hydration, Mental, Stamina
res://Scripts/Interface.gd = UpdateStats
```

### 8.2 `CHANGELOG.md`

```markdown
## [0.3.0] - 2026-10-26

### Added
- Live stat system: drain, regen, carry, and insulation now have real effects.
- Rarity affixes appear inside the item stat list, in the game's own font.
- Affix pool (15 stats): regen, low_hp_regen, carry, stamina_drain, insulation, thirst_drain, hunger_drain, sanity_drain, noise, sprint, protection, damage, recoil, fire_rate, low_hp_damage.
- `rtl_uid` persistent identity per item; sidecar v4 with backup.

### Fixed
- Drain and regen no longer require manual re-roll on equip.
```

### 8.3 `RTLBoot.build_config` — версия

Строка `"Info", "version", "0.2.25"` → `"Info", "version", "0.3.0"`.

### 8.4 `pack.ps1`

Проверить: RTL есть в copy-блоке (если `pack.ps1` копирует моды). Если нет — добавить. Сборка: `powershell -ExecutionPolicy Bypass -File pack.ps1`.

### 8.5 Ручной чек-лист §15.1

| # | Проверка | Ожидание |
|---|---|---|
| 1 | Ролл надетого предмета виден в статах (дренаж, ёмкость, тепло) | значение меняется |
| 2 | Ролл в рюкзаке **не** применяется, но строка в тултипе есть | статы не меняются |
| 3 | Save → load: роллы на месте в рюкзаке и в контейнере |uid сохранился |
| 4 | Снял/надел — статы вернулись к базе и применились заново | снятие = 0 |
| 5 | Два одинаковых предмета: перестановка не переносит ролл | uid стабилен |
| 6 | Тултип открыт 10+ сек — не растёт и не показывает чужой | idempotent |
| 7 | Перегруз: `carry` меняет и ёмкость, и флаг `overweight` | оба сработали |
| 8 | Смерть/рестарт: статы не остаются, лог без `SCRIPT ERROR` | clean |

---

## Файлы 0.3.0

| Файл | Действие | Задача |
|---|---|---|
| `RTLPool.gd` | edit | T1.1 |
| `RTLRoll.gd` | edit | T1.2 |
| `RTLStats.gd` | **создать** | T1.3 |
| `RTLText.gd` | **создать** | T1.4 |
| `RTLSidecar.gd` | **создать** | T2.1 |
| `RTLStore.gd` | edit | T2.2 |
| `RTLBoot.gd` | edit | T2.3, T2.4, T4, T8 |
| `RTLDisplay.gd` | edit | T3 |
| `RTLApply.gd` | **создать** | T4.1–4.5 |
| `RTLConfig.gd` | edit | T4.2 |
| `mod.txt` | edit | T8.1 |
| `CHANGELOG.md` | edit | T8.2 |
| `test_rtl_pool.gd` | **создать** | T7.2 |
| `test_rtl_roll.gd` | **создать** | T7.2 |
| `test_rtl_stats.gd` | **создать** | T7.2 |
| `test_rtl_text.gd` | **создать** | T7.2 |
| `test_rtl_sidecar.gd` | **создать** | T7.2 |
| `test_rtl_store.gd` | **создать** | T7.2 |
| `test_rtl_arity.gd` | **создать** | T7.2 |
| `.check/check.ps1` | edit | T7.1 |

**Создано файлов:** 6 (`RTLStats`, `RTLText`, `RTLSidecar`, `RTLApply` + 7 тестов).
**Изменено:** 6.

---

## Примечание: почему не subagent-driven

Plan короткий (~250 строк), задачи T1–T8 сидят в одном модуле (`standalone mods/RoadToLoot/`). Нет независимых подзадач, которые можно распараллелить: каждая следующая задача читает артефакты предыдущей. Нативное исполнение — один проход, ты следишь за прогоном стенда после каждой задачи.
