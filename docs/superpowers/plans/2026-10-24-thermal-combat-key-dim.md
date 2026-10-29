# ThermalVTK: приглушённый боевой ключ + ослабленный wash-гвард — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Убрать крапинки и красную полосу у обода по построению: боевой ключ приглушается `(0,1,1) → (0,0.60,0.72)`, его пост-wash орбита перемеряется в игре (F8/F7), wash-гвард шейдера ослабляется по результату замера — всё одним проходом.

**Architecture:** Ключ `KEY_COMBAT` эмитится контурными шеллами и является мишенью детектора: NVG-шуюдер шейдер на экране сравнивает пиксель с измеренной post-wash орбитой `DET_ST_COMBAT` и подменяет на красный дисплейный цвет. Меняем эмитентный ключ (ванильная wash сгоняет его в приглушённую синь, далёкую от белого), перемериваем орбиту инструментами калибровки и по числам решаем судьбу гварда. Дисплейные цвета не трогаем.

**Tech Stack:** GDScript (Godot 4.6.3), Godot shader (.gdshader), MCM-конфиг не трогается, сборка `pack.ps1` → `ThermalVTK.vmz`.

**Spec:** `docs/superpowers/specs/2026-10-24-thermal-combat-key-dim-design.md`

## Global Constraints

- Отступы `.gd` — только табы; кодировка UTF-8; русский текст держим только в комментариях кода? — нет: комментарии кода — на английском, как весь стиль файлов ThermalVTK (проверить по соседним).
- Версия живёт только в `mod.txt`; `pack.ps1` синхронизирует `mods/ThermalVTK/version.txt` и README. В GDScript версию не дублировать. Целевая версия: **1.17.2**.
- `ThermalVTK.vmz` не трекается git'ом — пак не коммитим; `version.txt` трекается.
- Дисплейные цвета (`DEFAULT_COMBAT`, `set_state_brightness`) и настройки MCM — без изменений. Меняются только эмитентные ключи/Detector-константы/гвард.
- Дисциплина ключей: шелл эмитит *сырой* ключ (`KEY_*`), детектор сравнивает *вымытый* (`DET_*`). Не смешивать: `DET_MINE (0.50, 0.06, 0.94)`, `DET_ST_NORMAL (1.00, 0.21, 0.16)`, `DET_ST_DEFEND (1.00, 0.34, 1.00)`, `DET_NOMAD (0.580, 0.973, 0.584)` — из `VTKNVG.gd`, не пересчитывать и не переписывать.
- Правило попарности: сырые ключи ≥ 0.22 друг от друга (raw RGB), измеренные орбиты ≥ 0.22 друг от друга (washed). Формула: `d = sqrt(Δr² + Δg² + Δb²)`.

## Review Focus

Пять провалов, которые тесты этого плана не покрывают (тестового стенда у ThermalVTK нет — только в игре):

1. Новая вымытая орбита combat садится близко к `DET_MINE` (синее семейство, wash поднимает красный) → контур читается синим как мина. Пин: шаг distance-gate в Task 3 (стоп-гейт плана).
2. Новая орбита садится близко к `DET_NOMAD` (у обоих g=0.60 сырой) → боевой контур воровнится номаду. Пин: тот же шаг gate, отдельная строка расчёта.
3. Орбита перемерена один раз, но wash зависит от яркости сцены — гвард ослаблен зря. Пин: процедура Task 3 (яркий день + дневная компенсация = худший случай, контрольный взгляд ночью) и ручная проверка Task 6.
4. Ротация каналов в прицеле (`scopeRotate`, орбиты) может свести синие ключи. Пин: чек-пункт прицела в Task 6 (PIP вкл/выкл — контур красный, не синий).
5. Протухшие комментарии, описывающие старую механику ( «one channel behind by ~0.18») — пин: шаги правки комментариев в Task 1/4 с grep-проверкой отсутствия старых утверждений.

---

### Task 1: Приглушить `KEY_COMBAT`, добавить кандидата в F8-свип

**Files:**
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKStates.gd:25`
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKCalibration.gd:20-29`

**Interfaces:**
- Consumes: ничего.
- Produces: `KEY_COMBAT := Color(0.0, 0.60, 0.72)` (VTKStates) — VTKOutline читает его через `States.state_key()` без правок кода; кандидат `Color(0.0, 0.60, 0.72)` становится девятым элементом `Calibration.CANDIDATES` (индекс 8), доступен в игре по циклу F8 автоматически (`% Calibration.count()`).

- [ ] **Step 1: Правка `KEY_COMBAT` в `VTKStates.gd`**

Заменить строку 25 и добавить комментарий по образцу блока `KEY_NOMAD` (строки 30-35):

```gdscript
# Combat key, dimmed like KEY_NOMAD: two bright saturated channels are what
# the NVG wash drives toward white, and a fully washed pixel (daylight sky,
# snow) landed inside this key's detector radius -- the red sky band and the
# snow speckles. One dominant channel survives the wash by construction.
const KEY_COMBAT := Color(0.0, 0.60, 0.72)
```

- [ ] **Step 2: Правка кандидата в `VTKCalibration.gd`**

Добавить девятым элементом в `CANDIDATES`:

```gdscript
	Color(0.00, 0.60, 0.72),
```

Заголовочный комментарий `VTKCalibration.gd` остаётся как есть: он требует «every pair > 0.22 (raw)» количественно не перечисляя кандидатов, а все пары нового кандидата проходят (таблица ниже).

Sanity-check (обязателен, по всем парам нового кандидата с восемью существующими ≥ 0.22; вычислить до записи):

| Пара | d |
|---|---|
| (0,0.60,0.72)-(0.60,0.02,0.02) | ≈1.15 |
| (0,0.60,0.72)-(0.55,0.38,0.02) | ≈1.06 |
| (0,0.60,0.72)-(0.20,0.55,0.02) | ≈0.75 |
| (0,0.60,0.72)-(0.02,0.60,0.24) | 0.48 |
| (0,0.60,0.72)-(0.08,0.34,0.42) | ≈0.43 |
| (0,0.60,0.72)-(0.02,0.10,0.60) | ≈0.51 |
| (0,0.60,0.72)-(0.34,0.02,0.58) | ≈0.78 |
| (0,0.60,0.72)-(0.55,0.10,0.32) | ≈1.12 |

- [ ] **Step 3: Проверка**

Run: `Select-String -SimpleMatch '0.60, 0.72' "standalone mods\ThermalVTK\mods\ThermalVTK\VTKStates.gd","standalone mods\ThermalVTK\mods\ThermalVTK\VTKCalibration.gd"`
Expected: по одному вхождению в каждом файле (новый ключ и новый кандидат).

- [ ] **Step 4: Commit**

```bash
git add "standalone mods/ThermalVTK/mods/ThermalVTK/VTKStates.gd" "standalone mods/ThermalVTK/mods/ThermalVTK/VTKCalibration.gd"
git commit -m "ThermalVTK WIP: dim combat key, add wash-robust calibration candidate"
```

### Task 2: Собрать и выложить измерительную сборку

Intermediate-состояние ожидаемо и допустимо: `KEY_COMBAT` уже приглушён, но `DET_ST_COMBAT` ещё старый — боевой контур в этой сборке детектором не подменяется (кольца показывают вымытый сырой ключ). Для замера это неважно: probe читает сырой вымытый пиксель кольца под оверлеем. Сборка — только для сеанса измерений.

**Files:**
- Build: `standalone mods/ThermalVTK/pack.ps1` → `standalone mods/ThermalVTK/ThermalVTK.vmz`
- Deploy: `D:\SteamLibrary\steamapps\common\Road to Vostok\mods\ThermalVTK.vmz`

**Interfaces:**
- Consumes: Task 1 (candidate доступны по F8).
- Produces: установленная в игре сборка для измерений (Task 3).

- [ ] **Step 1: Pack**

Run: `powershell -ExecutionPolicy Bypass -File "standalone mods\ThermalVTK\pack.ps1" -OutFile "D:\SteamLibrary\steamapps\common\Road to Vostok\mods\ThermalVTK.vmz"`
Expected: `Pack done: ... (N entries, ... KB)` без ошибок.

Коммита нет: артефакт не трекается, исходники уже в Task 1.

### Task 3: Сеанс измерений в игре (выполняет человек)

**Files:**
- Modify: этот план-файл (записать числа в чекбоксы ниже)

**Interfaces:**
- Consumes: Task 2 (сборка в игре); debug-инструменты мода (F6 палитра, F7 probe, F8 калибровка).
- Produces: `DET_ST_COMBAT'` (среднее по трём пробам, 3 знака), spread `σ' = max−min` каналов орбиты, четыре расстояния до соседних DET-констант; записаны в Task 3 ниже и потребляются Task 4.

Процедура (из вариативности wash'а берём худший случай, см. слабое место в доке):

- [ ] **Step 1: Подготовка сцены (день)**

Вариант с яркой дневной сценой открытого неба + снегом (зимний вариант карты предпочесть). В настройках Diagnostics включить Debug log; термал-зрение включить хоткеем; **дневную компенсацию включить** — это обычная конфигурация игры, замер должен отражать то, что видят игроки, а яркий день — худший случай для wash. Без прицела, PIP выкл.

- [ ] **Step 2: Прокрасить кандидатом**

F8 по циклу, пока диагностический лог не напечатает `cand08=(0.00,0.60,0.72)`. Все боты окрашиваются этим кандидатом.

- [ ] **Step 3: Три пробы F7**

Нацелиться цетральным пикселем на кольцо окрашенного бота поблизости (кольцо должно занимать заметную часть центра), кадр стабилен (motion-gated), F7. Повторить трижды при чуть разной точке прицеливания по кольцу. Записать три чтения из лога (`PROBE ... raw-thermal`):

- probe 1: R=0.184 G=0.224 B=0.247
- probe 2 (со спины): R=0.086 G=0.098 B=0.090
- probe 3 (сбоку): R=0.396 G=0.424 B=0.400

- [ ] **Step 4: Среднее и spread**

Посчитать `DET' = avg(3)` по каналам, 3 знака; `σ' = max−min`. Записать здесь:

- DET_ST_COMBAT' = (0.222, 0.249, 0.246), σ' = 0.027
- СВОД по отдельным пробам: σ₁=0.063, σ₂=0.012, σ₃=0.028; яркость по каналам
  скачет ×4.6 между пробами (0.09→0.42) — орбита нестабильна по углу/освещению.
- Отдельная проба vs среднее: probe1 d=0.045 (внутри), probe2 d=0.256 (ВНЕ
  0.22), probe3 d=0.291 (ВНЕ 0.22) — один детектор не покрывает все три пробы.

- [ ] **Step 5: Distance-gate (СТОП-ГЕЙТ)**

Просчитать `d = sqrt(Δr²+Δg²+Δb²)` от DET' до всех четырёх:

- vs `DET_MINE (0.50,0.06,0.94)`: d = 0.771
- vs `DET_ST_NORMAL (1.00,0.21,0.16)`: d = 0.784
- vs `DET_ST_DEFEND (1.00,0.34,1.00)`: d = 1.087
- vs `DET_NOMAD (0.580,0.973,0.584)`: d = 0.876

Все > 0.22 — формально гейт ПРОЙДЕН. Но фактическая пригодность — нет
(см. Outline and Task 3 status).

**Task 3 status: STOP — кандидат отвергнут по существу.** Wash свёл
`(0,0.60,0.72)` в нейтральную серость: расхождение каналов орбиты 0.027, и до
нее Добираются ПЛЕСЕНЬ цветов термальной палитры, оцененная по континууму
сегментов палитры ×0.7 (шейдер ThermalPalette, чистые остановки): Classic
c1×0.7=(0.21,0.084,0.315), d=0.189; Forest c2×0.7=(0.07,0.266,0.154), d=0.179 —
оба внутри 0.22, т.е. фоновые полосы luminance ~0.25–0.35 легально
заявляются боевым детектором (ложные красные на рельефе). Плюс две из трёх
проб ВНЕ радиуса собственного среднего — боевой контур не детектируется
стабильно даже по самому себе. Грамматика KEY_NOMAD подтверждена: выживает
доминантный канал при двух около-нулевых; (0,0.60,0.72) имеет ВТОРОЙ канал
0.60 — он и свелись. Следующий шаг — переговоры с партнёром (новые кандидаты
или возврат яркого ключа), план Task 4 ждёт решения.

- [ ] **Step 6: Контрольный взгляд ночью**

Выключить калибровку (Shift+F8), ночью взглянуть на боевого бота: контур читается, не путается с миной (мина — чистый синий, боевой — синь с зелёным подтоном). Результат: ок / описать проблему.

- [ ] **Step 7: Commit**

```bash
git add docs/superpowers/plans/2026-10-24-thermal-combat-key-dim.md
git commit -m "ThermalVTK: measured post-wash combat orbit (gate passed)"
```

### Task 4: Финализировать `DET_ST_COMBAT` и гвард по числам

**Files:**
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKNVG.gd:50-59`
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKNVG.gdshader:175-186`

**Interfaces:**
- Consumes: Task 3 (числа из этого план-файла; файл читается непосредственно).
- Produces: финальные `DET_ST_COMBAT`, порог/удаление гварда; потребляется Task 5 (релиз).

- [ ] **Step 1: Обновить `DET_ST_COMBAT` и комментарий в `VTKNVG.gd`**

Строку 58 заменить на измеренное значение (3 знака), в комментарии (строки 50-56) строку про combat переписать по факту:

```gdscript
# combat (0.00,0.60,0.72)->(<значения probe, 2 знака>)
const DET_ST_COMBAT := Color(<r>, <g>, <b>)
```

Остальные строки комментария (normal/defend/nomad) не трогать.

- [ ] **Step 2: Гвард в `VTKNVG.gdshader` — по уровню σ' (слои из спеки)**

Выбрать ровно одну ветку по σ' из Task 3:

- **σ' ≥ 0.30** — блок удалить целиком (строки `float washSpread … dStC = 99.0;`), комментарий (строки 175-181) заменить на:

```text
// No wash guard: the combat key is dim (one dominant channel), so a fully
// washed pixel (sky, snow) converges far from its post-NVG orbit -- the red
// band and speckles died with the bright key, not with a runtime filter.
```

- **0.12 ≤ σ' < 0.30** — порог `0.10` → `0.04`, комментарий дополнить: dim key survives by construction; guard remains as a cheap margin, not the mechanism.
- **σ' < 0.12** — не трогать (откат к варианту C спеки), комментарий не менять.

В обеих «правимых» ветках упоминание «one channel behind by ~0.18» удалить — оно описывает старый ключ (Review Focus №5).

- [ ] **Step 3: Проверка протухших комментариев**

Run: `Select-String -SimpleMatch '0.18' "standalone mods\ThermalVTK\mods\ThermalVTK\VTKNVG.gdshader"`
Expected: 0 вхождений (при σ' ≥ 0.12 ветках правки), или 0 вхождений строки `washSpread` при σ' ≥ 0.30.

Also: `Select-String -SimpleMatch '1.0, 1.0' "standalone mods\ThermalVTK\mods\ThermalVTK\VTKStates.gd"` → 0 вхождений (старый ключ был `Color(0.0, 1.0, 1.0)`).

- [ ] **Step 4: Commit**

```bash
git add "standalone mods/ThermalVTK/mods/ThermalVTK/VTKNVG.gd" "standalone mods/ThermalVTK/mods/ThermalVTK/VTKNVG.gdshader"
git commit -m "ThermalVTK: remeasured combat detector orbit, wash guard per measurement"
```

### Task 5: Версия 1.17.2, CHANGELOG, финальный пак и деплой

**Files:**
- Modify: `standalone mods/ThermalVTK/mod.txt:4`
- Modify: `standalone mods/ThermalVTK/CHANGELOG.md` (верхняя секция)
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/version.txt` (генерирует pack.ps1)
- Build: `standalone mods/ThermalVTK/pack.ps1` → `ThermalVTK.vmz` → копия в `D:\SteamLibrary\steamapps\common\Road to Vostok\mods`

**Interfaces:**
- Consumes: Task 4 (все правки кода готовы).
- Produces: релиз 1.17.2 в игре.

- [ ] **Step 1: `mod.txt`**

`version="1.17.2"`.

- [ ] **Step 2: CHANGELOG**

Новая запись после `# Changelog` (KaC, английский, player-visible; версия и дата совпадают с `mod.txt` / день сборки). Вторая строка — только при ветке σ' ≥ 0.30 (гвард удалён); при оставленном гварде её не писать:

```markdown
## [1.17.2] - 2026-10-24

### Fixed
- The last red speckles on bright snow and the red rim band at the eyepiece edge are gone for good: the combat outline key now sits outside the path the night-vision wash takes bright pixels through, instead of relying on a filter that patched it.
- Bright pixels can no longer be mistaken for the combat outline at all, so the error filter that patched the sky is retired.
```

- [ ] **Step 3: Pack и копия**

Run: `powershell -ExecutionPolicy Bypass -File "standalone mods\ThermalVTK\pack.ps1"`
Expected: `Version in mod.txt: 1.17.2`, `README version synced`, `Pack done`. Затем скопировать `ThermalVTK.vmz` в папку модов игры.

- [ ] **Step 4: Commit**

```bash
git add "standalone mods/ThermalVTK/mod.txt" "standalone mods/ThermalVTK/CHANGELOG.md" "standalone mods/ThermalVTK/mods/ThermalVTK/version.txt"
git commit -m "ThermalVTK 1.17.2: combat key calibrated out of the wash path"
```

### Task 6: Ручная проверка в игре (выполняет человек)

**Files:** нет изменений.

- [ ] **Step 1: Яркий день, открытое небо/снег:** ни красной полосы у обода, ни крапинок на снегу. Если в Task 4 гвард был удалён (σ' ≥ 0.30) — этот пункт критический для отката; при оставленном гварде — обычная проверка.
- [ ] **Step 2: Боевые боты:** контур красный, детектируется на дистанции (в т.ч. у границы Distance).
- [ ] **Step 3: Прицел, PIP вкл/выкл:** контур красный, не синий (мина), не зелёный (номад).
- [ ] **Step 4: Мины синие, номад-маркер зелёный, нормал/дефенд контуры без изменений.**
- [ ] **Step 5: Ночь:** боевой контур читается; крапинок нет.

Любой провал: записать сюда, план возвращается на шаг Task 3/4 (перемерить или вернуть гвард полностью).
