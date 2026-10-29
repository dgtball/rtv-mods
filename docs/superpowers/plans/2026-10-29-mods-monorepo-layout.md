# Реструктуризация rtv-mods: `mods/<slug>` и починка git — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Привести `D:\RTVMOD` к раскладке «четыре равноправных мода в `mods/<slug>/` + тонкий корень» и сделать так, чтобы свежий клон собирался и проверялся без ручной доустановки файлов.

**Architecture:** Переезд папок через `git mv`, вся обвязка (`check.ps1`, `layout_check.py`, `pack.ps1`) переписывается на таблицы модов и пути относительно корня репозитория. Тесты переезжают внутрь Godot-проекта (`.check/project/tests/<slug>/`), потому что `res://` резолвится только от `project.godot`. Сборка становится одной точкой входа `pack.ps1 -Mod|-All` и пишет артефакты в `dist/`, сохраняя исторические имена файлов.

**Tech Stack:** PowerShell 5.1 (сборка, стенд), Python 3 (`layout_check.py`, сверка архивов), Godot 4.6.3 headless (парсинг и тесты), git.

**Spec:** `docs/superpowers/specs/2026-10-29-mods-monorepo-layout-design.md`

## Global Constraints

- Godot — **4.6.3**; запуск headless: `--headless --path .check\project --script res://...`.
- Slug мода = `id` из его `mod.txt`: `vostok-toolkit`, `thermal-vtk`, `road-to-loot`, `jcm-freeze`.
- Папка исходников внутри мода: `VTK`, `ThermalVTK`, `RoadToLoot`, `jcm-freeze`.
- Имена артефактов **не меняются**: `Loadouts.vmz`, `ThermalVTK.vmz`, `RoadToLoot.vmz`, `Freeze.vmz`. Только место — `dist/`.
- Внутри `.vmz` в корне архива обязаны быть `mod.txt` и `mods/<Folder>/`.
- Тесты: 15 (vostok-toolkit), 17 (thermal-vtk), 9 + 2 файла-опоры (road-to-loot). Тесты LooterShooter удаляются.
- Код модов (`*.gd` в `mods/*/mods/*/`) **не меняется** ни в одной задаче. Единственное исключение — пути `preload` в `test_rtl_persist.gd`.
- `git add -A` и `git add .` без ограничителя пути запрещены: только явные пути, иначе в индекс попадёт 11 ГБ `RTVcopy`. Ограниченные формы (`git add -A -- mods .check`) допустимы.
- Язык кода и скриптов — как в репозитории (английские комментарии в скриптах, русские — в `AGENTS.md`).

## Review Focus

1. **Мод выпал из сборки.** Пользователь ставит `.vmz`, а игра его не видит: внутри нет `mod.txt` или `mods/<Folder>/`. Ловится сверкой списка записей архива с базовой линией (Task 5).
2. **Файл потерян при переезде.** `git mv` пропустил скрипт — мод падает на загрузке. Ловится сверкой `git ls-files` до/после и списком записей архива (Task 4, Task 5).
3. **Тест недоступен после переезда.** Путь в `check.ps1` устарел или `preload` внутри теста указывает на старую папку — прогон падает или молча теряет тест. Ловится прогоном `check.ps1` (Task 4).
4. **Обвязка снова выпала из git.** Новый `.gitignore` слишком широкий или забыт `git add` — из клона нельзя проверить мод. Ловится `git ls-files` + прогоном в чистом клоне (Task 3, Task 8).
5. **Абсолютные пути.** `layout_check.py` или `check.ps1` привязаны к `D:\RTVMOD` — на другой машине всё падает. Ловится запуском из `C:\` (Task 4, Task 5).
6. **`version.txt` выпал из git.** После клона и сборки MCM показывает `unknown`. Ловится `git ls-files` в Task 3 и проверкой в Task 8.

---

### Task 1: Свести `main` с origin и убрать мёртвую ветку

**Files:** только git-метаданные, файлы не меняются.

**Interfaces:**
- Produces: линейный `main`, запушенный в `origin/main`; ветки `audit` больше нет.

- [ ] **Step 1: Проверить, что своих несохранённых изменений нет**

Run: `git -C D:\RTVMOD status --porcelain --untracked-files=no`
Expected: пусто. Если есть — остановиться и показать человеку.

- [ ] **Step 2: Зафиксировать, что локальные 43 коммита не содержат удаления LooterShooter, которого нет на origin**

Run: `git -C D:\RTVMOD log --oneline origin/main..HEAD | Measure-Object -Line`
Expected: `Lines : 43` (число может отличаться — запомнить фактическое).

- [ ] **Step 3: Свести с origin перебазированием**

Run: `git -C D:\RTVMOD pull --rebase origin main`
Expected: либо `Successfully rebased`, либо остановка на `3e50d04 Delete standalone mods/LooterShooter directory`.
Если остановка — этот коммит уже сделан локально в `9836674`, поэтому: `git -C D:\RTVMOD rebase --skip`, затем `git -C D:\RTVMOD rebase --continue` при необходимости.
Проверка: `git -C D:\RTVMOD status` — `nothing to commit, working tree clean`, `git -C D:\RTVMOD log --oneline -3` — линейная история без merge-коммита.

- [ ] **Step 4: Запушить**

Run: `git -C D:\RTVMOD push origin main`
Expected: `main -> main`, `git -C D:\RTVMOD status -sb` показывает `## main...origin/main` без `ahead/behind`.

- [ ] **Step 5: Удалить полностью влитую ветку `audit`**

Run: `git -C D:\RTVMOD merge-base --is-ancestor origin/audit main; echo $LASTEXITCODE`
Expected: `0` (ветка — предок `main`). Затем `git -C D:\RTVMOD push origin --delete audit`.
Expected: `- [deleted] audit`.

- [ ] **Step 6: Коммит не нужен** — эта задача ничего не коммитит, только синхронизирует историю.

---

### Task 2: Базовая линия четырёх архивов

**Files:**
- Create: `tmp_probe/baseline/manifest.json` (не в git), `tmp_probe/baseline/sizes.txt`
- Create: `tmp_probe/baseline/manifest.py` (не в git)

**Interfaces:**
- Produces: `tmp_probe/baseline/manifest.json` — `{"<artifact>.vmz": ["entry", ...]}` для всех четырёх архивов до переезда. Task 5 сверяется с ним.

- [ ] **Step 1: Собрать все четыре архива текущими скриптами**

```powershell
cd D:\RTVMOD
powershell -ExecutionPolicy Bypass -File .\pack.ps1
powershell -ExecutionPolicy Bypass -File ".\standalone mods\ThermalVTK\pack.ps1"
powershell -ExecutionPolicy Bypass -File ".\standalone mods\RoadToLoot\pack.ps1"
powershell -ExecutionPolicy Bypass -File ".\standalone mods\jcm-freeze\pack.ps1"
```

Expected: четыре строки `Pack done: ...` и четыре файла: `Loadouts.vmz`,
`standalone mods\ThermalVTK\ThermalVTK.vmz`, `standalone mods\RoadToLoot\RoadToLoot.vmz`,
`standalone mods\jcm-freeze\Freeze.vmz`.

- [ ] **Step 2: Написать скрипт снятия манифеста**

`tmp_probe/baseline/manifest.py`:

```python
import json, pathlib, zipfile

ROOT = pathlib.Path(r"D:\RTVMOD")
MODS = {
    "Loadouts.vmz": ROOT / "Loadouts.vmz",
    "ThermalVTK.vmz": ROOT / "standalone mods/ThermalVTK/ThermalVTK.vmz",
    "RoadToLoot.vmz": ROOT / "standalone mods/RoadToLoot/RoadToLoot.vmz",
    "Freeze.vmz": ROOT / "standalone mods/jcm-freeze/Freeze.vmz",
}

out = {}
for name, path in MODS.items():
    with zipfile.ZipFile(path) as z:
        out[name] = sorted(z.namelist())

dest = ROOT / "tmp_probe/baseline"
dest.mkdir(parents=True, exist_ok=True)
(dest / "manifest.json").write_text(json.dumps(out, indent=1), encoding="utf-8")
print({k: len(v) for k, v in out.items()})
```

- [ ] **Step 3: Снять манифест и размеры**

Run: `py -3 D:\RTVMOD\tmp_probe\baseline\manifest.py`
Expected: словарь с четырьмя ключами и положительными числами, например `{'Loadouts.vmz': 27, 'ThermalVTK.vmz': N, ...}` (точные числа запомнить).

Run: `Get-ChildItem -Recurse -Filter *.vmz D:\RTVMOD | Select-Object FullName,Length | Format-Table -AutoSize`
Expected: четыре файла с размерами; записать их в `tmp_probe/baseline/sizes.txt`.

- [ ] **Step 4: Коммита нет** — всё в `tmp_probe/`, он вне git.

---

### Task 3: `.gitignore` вместо allowlist и отслеживание стенда

**Files:**
- Modify: `.gitignore` (полная замена)
- Add to git: `AGENTS.md`, `pack.ps1`, `.check/layout_check.py`, `.check/project/**` (кроме генерируемого)

**Interfaces:**
- Produces: стенд и сборка в индексе; `.gitignore` — список игнорируемого, а не allowlist. Добавленные пути Task 4 переименует через `git mv`.

- [ ] **Step 1: Записать новый `.gitignore`**

```gitignore
# local-only data: game copy, reference mods, godot builds, probes
/RTVcopy/
/referens/
/tools/
/tmp_probe/
/.superpowers/
/superpowers/
/.docs/
__pycache__/

# build output
/dist/
*.vmz

# godot caches and editor artifacts
.godot/
*.uid
*.bak

# generated by the check stand
/.check/project/mods/
/_gdc_*.txt
/.check/_gdc_*.txt
/.check/inventory-wall-crops/
```

- [ ] **Step 2: Проверить, что ничего нужного не утекло в игнор**

Run: `git -C D:\RTVMOD status --porcelain --untracked-files=all`
Expected: в списке **есть** `AGENTS.md`, `.check/layout_check.py`, `.check/project/project.godot`, `.check/project/tests/*.gd`, `pack.ps1`; **нет** ни одного пути с `RTVcopy/`, `referens/`, `tools/`, `tmp_probe/`, `.godot/`, `*.uid`.
Если появилось лишнее (например `.check/project/.godot/...`) — добавить правило и повторить.

- [ ] **Step 3: Добавить обвязку явными путями**

```powershell
cd D:\RTVMOD
git add .gitignore AGENTS.md pack.ps1
git add .check/check.ps1 .check/layout_check.py
git add .check/project/project.godot
git add .check/project/Host.gd .check/project/inspect.gd .check/project/debug_glass.gd
git add .check/project/debug_names.gd .check/project/repro_load.gd .check/project/tools_detok.gd
git add .check/project/stubs .check/project/Scripts .check/project/tests
git add docs/mockups docs/superpowers
git rm --cached -q .check/project/tests/test_seasons_headless.gd.stub
git status --short
```

Expected: в индексе только `A`-строки перечисленного, ни одного `RTVcopy|tools|referens`.
`docs/superpowers` добавляется по дизайну (строка «Всё остальное — в git, включая … `docs/mockups`,
`docs/superpowers`»): раньше папка была в игноре, теперь это часть истории репозитория.
`.stub` — мусор от отладочной заготовки, Task 4 его удалит; в индекс он попасть не должен.

- [ ] **Step 4: Проверить содержимое индекса на тяжесть**

Run: `git -C D:\RTVMOD ls-files | Select-String -Pattern '^(RTVcopy|referens|tools|tmp_probe|\.superpowers)/'`
Expected: пусто.

Run: `git -C D:\RTVMOD ls-files | Measure-Object -Line`
Expected: `305` (было 104; добавляется стенд, `docs/mockups`, `docs/superpowers`). Число запомнить —
Task 4 сверяет его же после переезда (переезд файлов не добавляет и не удаляет).

- [ ] **Step 5: Убедиться, что стенд всё ещё работает на старых путях**

Run: `py -3 .check\layout_check.py`
Expected: отчёт без `FAIL`, код выхода 0.

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `Parse check passed`, все `VERDICT: ok`, `Tests passed: 46 file(s)`, код выхода 0.

- [ ] **Step 6: Коммит**

```powershell
git commit -m "chore(git): track build and test harness"
```

---

### Task 4: Переезд модов и тестов, новые `check.ps1` и `layout_check.py`

**Files:**
- Move: `loadouts/` → `mods/vostok-toolkit/`; `assets/` → `mods/vostok-toolkit/assets/`; `README.md` → `mods/vostok-toolkit/README.md`; `standalone mods/{ThermalVTK,RoadToLoot,jcm-freeze}/` → `mods/{thermal-vtk,road-to-loot,jcm-freeze}/`
- Move: `.check/project/tests/<мод>*.gd` → `.check/project/tests/<slug>/`
- Modify: `.check/check.ps1`, `.check/layout_check.py`, `.check/project/tests/road-to-loot/test_rtl_persist.gd`
- Delete: тесты LooterShooter, `.bak`, отладочные заготовки

**Interfaces:**
- Consumes: отслеживаемый стенд из Task 3.
- Produces: путь источника мода — `mods/<slug>/mods/<Folder>`; путь теста — `res://tests/<slug>/test_*.gd`; таблица `$mods` в `check.ps1` с полями `Slug`/`Folder`/`Tests`; `layout_check.py` без абсолютных путей.

- [ ] **Step 1: Переехать папки модов**

```powershell
cd D:\RTVMOD
New-Item -ItemType Directory -Force -Path mods | Out-Null
git mv loadouts mods/vostok-toolkit
git rm -r assets
git mv README.md mods/vostok-toolkit/README.mdgit mv "standalone mods/ThermalVTK" mods/thermal-vtk
git mv "standalone mods/RoadToLoot" mods/road-to-loot
git mv "standalone mods/jcm-freeze" mods/jcm-freeze
git status --short
```

Expected: только `R`-строки (renames) без `D`+`??`; папка `standalone mods` пустая.
`git rm -r assets` даёт `D`-строки на 8 jpg — это намеренно (пользователь отказался от них).
Ссылки на `assets/` в `mods/vostok-toolkit/README.md` чистятся **в этом же коммите**, иначе
промежуточный коммит ссылается на удалённые файлы (Task 6 Step 2 переехал сюда).

- [ ] **Step 2: Проверить, что переехало всё**

Инвариант: переезд не меняет число отслеживаемых файлов. Снять число до (в конце Task 3) и
после:

Run: `git -C D:\RTVMOD ls-files | Measure-Object -Line`
Expected: те же `305`, что после коммита Task 3 — переезд файлов не добавляет и не удаляет.
Проверено: до коммита (после всех удалений Task 4) остаётся `282` = 305 − 8 `assets` − 6 LSH-тестов
− `test_serialization.gd` − 8 отладочных заготовок − `.check/project/Scripts/SlotData.gd`.

Run: `Get-ChildItem D:\RTVMOD\mods -Directory | Select-Object -ExpandProperty Name`
Expected: `jcm-freeze`, `road-to-loot`, `thermal-vtk`, `vostok-toolkit`.

- [ ] **Step 3: Разложить тесты по модам**

```powershell
cd D:\RTVMOD\.check\project\tests
New-Item -ItemType Directory -Force -Path vostok-toolkit,thermal-vtk,road-to-loot | Out-Null

$vtk = @('test_composite','test_config','test_data','test_deposits','test_draft','test_equip',
         'test_feed','test_hooks','test_items','test_notes','test_picker','test_seasons',
         'test_session','test_spawn','test_travel')
$thermal = @('test_calibration','test_daylight','test_daylight_runtime','test_debug','test_esp',
             'test_label_layout','test_labels','test_nvg','test_outline','test_preset','test_probe',
             'test_profile','test_settings','test_shaders','test_states','test_tracker','test_weapon')
$rtl = @('test_rtl_category','test_rtl_persist','test_rtl_pool','test_rtl_roll','test_rtl_rows',
         'test_rtl_stats','test_rtl_text','test_sidecar','test_store')

foreach ($n in $vtk)     { git mv "$n.gd" "vostok-toolkit/$n.gd" }
foreach ($n in $thermal) { git mv "$n.gd" "thermal-vtk/$n.gd" }
foreach ($n in $rtl)     { git mv "$n.gd" "road-to-loot/$n.gd" }
git mv rtl_probe_save.gd road-to-loot/rtl_probe_save.gd
git mv rtl_probe_slot.gd road-to-loot/rtl_probe_slot.gd
```

Expected: `git status --short` — `R`-строки; в `tests/` верхнего уровня не осталось ни одного `test_*.gd` из списков.

- [ ] **Step 4: Удалить тесты LooterShooter и мусор**

```powershell
cd D:\RTVMOD\.check\project\tests
git rm -f test_lsh_category.gd test_lsh_config.gd test_lsh_pool.gd test_lsh_roll.gd test_lsh_slotdata.gd test_serialization.gd
Remove-Item -Force test_rtl_roll.gd.bak,test_rtl_rows.gd.bak,test_rtl_text.gd.bak -ErrorAction SilentlyContinue
$scratch = @('test_rtl_stats_debug','test_rtl_stats_debug2','test_sidecar_debug','test_seasons_headless',
             'probe_in','probe_in2','probe_resweep','probe_vec')
foreach ($n in $scratch) {
    if (Test-Path "$n.gd") { Move-Item -Force "$n.gd" D:\RTVMOD\tmp_probe\ -ErrorAction SilentlyContinue }
    Remove-Item -Force "$n.gd.uid","$n.gd.stub" -ErrorAction SilentlyContinue
}
```

Expected: `Get-ChildItem D:\RTVMOD\.check\project\tests -Name` — три папки и ни одного `.bak`/`.stub`;
в `tmp_probe/` появились 8 отладочных файлов.

Затем убрать осиротевшие `.uid` в корне `tests/` (они не отслеживаются и пересоздаются Godot):

Run: `Remove-Item -Force D:\RTVMOD\.check\project\tests\*.uid -ErrorAction SilentlyContinue`

- [ ] **Step 5: Поправить пути `preload` в `test_rtl_persist.gd`**

`test_rtl_persist.gd` прелоадит `res://tests/rtl_probe_save.gd` и `res://tests/rtl_probe_slot.gd`.
Заменить оба на `res://tests/road-to-loot/rtl_probe_save.gd` и `res://tests/road-to-loot/rtl_probe_slot.gd`.
Проверка: `Select-String -Path D:\RTVMOD\.check\project\tests\road-to-loot\test_rtl_persist.gd -Pattern 'res://tests/'`
Expected: ровно две строки, обе с `road-to-loot/`.

- [ ] **Step 6: Переписать `check.ps1` на таблицу модов**

Заменить блоки `$modSrc/$modDst`, `$altSrc/$altDst`, `$lshSrc/$lshDst`, `$rtlSrc/$rtlDst` на таблицу:

```powershell
$repoRoot = Split-Path $checkRoot -Parent
$mods = @(
    @{ Slug = "vostok-toolkit"; Folder = "VTK";         Tests = "vostok-toolkit" },
    @{ Slug = "thermal-vtk";    Folder = "ThermalVTK";  Tests = "thermal-vtk" },
    @{ Slug = "road-to-loot";   Folder = "RoadToLoot";  Tests = "road-to-loot" },
    @{ Slug = "jcm-freeze";     Folder = "jcm-freeze";  Tests = $null }
)
```

Цикл копирования: для каждой записи `$src = Join-Path $repoRoot "mods\$($m.Slug)\mods\$($m.Folder)"`,
`$dst = Join-Path $proj "mods\$($m.Folder)"`; если `$src` нет — `throw "Mod sources not found: $src"`;
`Remove-Item $dst -Recurse -Force` если есть; создать; копировать `*.gd`, `*.tres`, `*.gdshader`
(все через `-ErrorAction SilentlyContinue`, кроме `.gd`).

Цикл парсинга: по тем же записям, `res://mods/<Folder>/<name>.gd`, вердикт прежний
(`SCRIPT ERROR|Parse Error|Failed to load script` или ненулевой код).

Список тестов — хеш-таблица с явными путями:

```powershell
$tests = [ordered]@{
    "vostok-toolkit" = @(
        "res://tests/vostok-toolkit/test_composite.gd", "res://tests/vostok-toolkit/test_config.gd",
        "res://tests/vostok-toolkit/test_data.gd", "res://tests/vostok-toolkit/test_deposits.gd",
        "res://tests/vostok-toolkit/test_draft.gd", "res://tests/vostok-toolkit/test_equip.gd",
        "res://tests/vostok-toolkit/test_feed.gd", "res://tests/vostok-toolkit/test_hooks.gd",
        "res://tests/vostok-toolkit/test_items.gd", "res://tests/vostok-toolkit/test_notes.gd",
        "res://tests/vostok-toolkit/test_picker.gd", "res://tests/vostok-toolkit/test_seasons.gd",
        "res://tests/vostok-toolkit/test_session.gd", "res://tests/vostok-toolkit/test_spawn.gd",
        "res://tests/vostok-toolkit/test_travel.gd")
    "thermal-vtk" = @(
        "res://tests/thermal-vtk/test_calibration.gd", "res://tests/thermal-vtk/test_daylight.gd",
        "res://tests/thermal-vtk/test_daylight_runtime.gd", "res://tests/thermal-vtk/test_debug.gd",
        "res://tests/thermal-vtk/test_esp.gd", "res://tests/thermal-vtk/test_label_layout.gd",
        "res://tests/thermal-vtk/test_labels.gd", "res://tests/thermal-vtk/test_nvg.gd",
        "res://tests/thermal-vtk/test_outline.gd", "res://tests/thermal-vtk/test_preset.gd",
        "res://tests/thermal-vtk/test_probe.gd", "res://tests/thermal-vtk/test_profile.gd",
        "res://tests/thermal-vtk/test_settings.gd", "res://tests/thermal-vtk/test_shaders.gd",
        "res://tests/thermal-vtk/test_states.gd", "res://tests/thermal-vtk/test_tracker.gd",
        "res://tests/thermal-vtk/test_weapon.gd")
    "road-to-loot" = @(
        "res://tests/road-to-loot/test_rtl_category.gd", "res://tests/road-to-loot/test_rtl_persist.gd",
        "res://tests/road-to-loot/test_rtl_pool.gd", "res://tests/road-to-loot/test_rtl_roll.gd",
        "res://tests/road-to-loot/test_rtl_rows.gd", "res://tests/road-to-loot/test_rtl_stats.gd",
        "res://tests/road-to-loot/test_rtl_text.gd", "res://tests/road-to-loot/test_sidecar.gd",
        "res://tests/road-to-loot/test_store.gd")
}
$tests = $tests.Values | ForEach-Object { $_ }
```

Дальше неизменные части: проверка существования файлов (`throw "Test script missing: $t"`),
прогон `--script $t --quit-after 600`, вердикт (`tests passed`, нет `FAIL`/`SCRIPT ERROR|Parse
Error|Invalid call|Failed to load script`, код 0), финальный `Tests passed: N file(s)`.
Удалить из файла все упоминания `LooterShooter` и `lsh`.

- [ ] **Step 7: Убрать старые копии в стенде и проверить `SlotData`**

```powershell
Remove-Item -Recurse -Force D:\RTVMOD\.check\project\mods\LooterShooter -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force D:\RTVMOD\.check\project\jcm-freeze -ErrorAction SilentlyContinue
Select-String -Path D:\RTVMOD\.check\project\tests\*\*.gd -Pattern 'Scripts/SlotData|res://Scripts/'
```

Expected: если совпадений нет — удалить `.check/project/Scripts/SlotData.gd` и саму папку `Scripts`
(`git rm -r .check/project/Scripts`); если есть — оставить как есть и записать это в отчёт.

- [ ] **Step 8: Переписать `layout_check.py` на относительные пути**

`MODULES_GLOB = str(pathlib.Path(__file__).resolve().parent.parent / "mods" / "vostok-toolkit" / "mods" / "VTK" / "*.gd")`.
Удалить `LSH_GLOB`, `LSH_GLOB_SUB` и все их использования; проверки `GONE`/`PRESENT`/`FUNCS`
остаются только по Toolkit. Проверка: `Select-String -Path D:\RTVMOD\.check\layout_check.py -Pattern 'D:\\\\RTVMOD|LooterShooter|LSH'`
Expected: пусто.

- [ ] **Step 9: Прогнать стенд на новой раскладке**

Run: `py -3 D:\RTVMOD\.check\layout_check.py`
Expected: без `FAIL`, код 0.

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File D:\RTVMOD\.check\check.ps1`
Expected: `Parse check passed`, `ok` для всех скриптов четырёх модов (включая `jcm-freeze`), все
`VERDICT: ok`, `Tests passed: 41 file(s)`, код 0.

- [ ] **Step 10: Проверить переносимость**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File D:\RTVMOD\.check\check.ps1` с `workdir = C:\`
Expected: тот же зелёный результат (пути считаются от `$PSScriptRoot`).

Run: `py -3 D:\RTVMOD\.check\layout_check.py` с `workdir = C:\`
Expected: код 0 — в скрипте не осталось абсолютных путей.

- [ ] **Step 11: Коммит**

```powershell
cd D:\RTVMOD
git add -A -- mods .check
git status --short
git commit -m "refactor(layout): move mods into mods/<slug>, tests into project/tests/<slug>"
```

Expected перед коммитом: только `R`/`D`/`M` внутри `mods/` и `.check/`.

---

### Task 5: Один `pack.ps1` на четыре мода

**Files:**
- Modify: `pack.ps1` (полная перезапись)
- Delete: `mods/thermal-vtk/pack.ps1`, `mods/road-to-loot/pack.ps1`, `mods/jcm-freeze/pack.ps1`

**Interfaces:**
- Consumes: `mods/<slug>/mods/<Folder>` из Task 4.
- Produces: `pack.ps1 -Mod <slug>` / `-All`; артефакты `dist/<Artifact>.vmz`; `version.txt` пишется для `vostok-toolkit`, `thermal-vtk`, `road-to-loot`.

- [ ] **Step 1: Удалить четыре копии сборщика**

```powershell
cd D:\RTVMOD
git rm -f "mods/thermal-vtk/pack.ps1" "mods/road-to-loot/pack.ps1" "mods/jcm-freeze/pack.ps1"
```
(корневой `pack.ps1` переписывается на следующем шаге)

- [ ] **Step 2: Переписать корневой `pack.ps1`**

Таблица:

```powershell
$mods = @(
    @{ Slug = "vostok-toolkit"; Folder = "VTK";        Artifact = "Loadouts.vmz";    VersionFile = $true  },
    @{ Slug = "thermal-vtk";    Folder = "ThermalVTK"; Artifact = "ThermalVTK.vmz";  VersionFile = $true  },
    @{ Slug = "road-to-loot";   Folder = "RoadToLoot"; Artifact = "RoadToLoot.vmz";  VersionFile = $true  },
    @{ Slug = "jcm-freeze";     Folder = "jcm-freeze"; Artifact = "Freeze.vmz";      VersionFile = $false }
)
```

Параметры: `param([string]$Mod = "all", [string]$OutDir = "")`. `$OutDir` по умолчанию
`Join-Path $PSScriptRoot "dist"`; создать, если нет. `$Mod` = `all` → все записи; иначе —
ровно одна, и если slug не найден — `throw "Unknown mod: $Mod"`.

Для каждой записи:
- `$src = Join-Path $PSScriptRoot "mods\$($m.Slug)"`; если нет `$src\mod.txt` — `throw`.
- версия из `mod.txt` (`'version\s*=\s*"([^"]+)"'`), иначе `Write-Warning`.
- если `VersionFile` — писать `$src\mods\$($m.Folder)\version.txt` (UTF-8 без BOM, `$ver + "`n"`).
- синхронизировать `**Version:**` в `$src\README.md`, если там есть такая строка.
- записи архива: `Get-ChildItem $src -Recurse -File`, фильтр — имя `mod.txt`/`version.txt`
  или расширение `.gd|.tres|.tscn|.gdshader|.webp|.png`; **исключить** всё, что начинается
  с `assets/`, а также `README.md`/`CHANGELOG.md`/`REFACTOR_SPEC.md`; относительные пути
  через `/`, сортировка.
- `.gd` чистятся от построчных `#`-комментариев и пустых строк, строки склеиваются `\n`
  (логика переносится из текущего корневого `pack.ps1` без изменений).
- архив пишется во временный файл и переносится в `$OutDir\$($m.Artifact)`; печать
  `Pack done: <путь> (<n> entries, <kb> KB)`.

- [ ] **Step 3: Собрать всё и убедиться, что появилось четыре архива**

Run: `powershell -ExecutionPolicy Bypass -File D:\RTVMOD\pack.ps1 -All`
Expected: четыре строки `Pack done: ...\dist\<Artifact>.vmz`; `Get-ChildItem D:\RTVMOD\dist`
показывает `Loadouts.vmz`, `ThermalVTK.vmz`, `RoadToLoot.vmz`, `Freeze.vmz`.

- [ ] **Step 4: Сверить манифесты с базовой линией**

```powershell
py -3 -c "import json,zipfile,pathlib; b=json.loads(pathlib.Path(r'D:\RTVMOD\tmp_probe\baseline\manifest.json').read_text(encoding='utf-8')); d={n:sorted(zipfile.ZipFile(pathlib.Path(r'D:\RTVMOD\dist')/n).namelist()) for n in b}; print({k:(v==b[k]) for k,v in d.items()}); [print(k, set(b[k])^set(d[k])) for k in b if set(b[k])!=set(d[k])]"
```

Expected: `{'Loadouts.vmz': True, 'ThermalVTK.vmz': True, 'RoadToLoot.vmz': True, 'Freeze.vmz': True}`
и ни одного расхождения. Любое `False` — остановиться: набор файлов в архиве изменился.

- [ ] **Step 5: Проверить, что содержимое Toolkit не изменилось, а остальные похудели**

Run: `py -3 -c "import zipfile,pathlib; z=zipfile.ZipFile(r'D:\RTVMOD\dist\Loadouts.vmz'); print([ (n, len(z.read(n))) for n in z.namelist() if n.endswith('.gd')][:3])"`
Expected: те же длины `.gd`, что у `Loadouts.vmz` в корне (собран до переезда).

Run: `Get-Item D:\RTVMOD\dist\*.vmz | Select-Object Name,Length`
Expected: `ThermalVTK.vmz`, `RoadToLoot.vmz`, `Freeze.vmz` меньше, чем их размеры в
`tmp_probe/baseline/sizes.txt` (снятие комментариев); `Loadouts.vmz` — в пределах ±2% от базового.

- [ ] **Step 6: Коммит**

```powershell
cd D:\RTVMOD
git add pack.ps1
git commit -m "build: single pack.ps1 for all mods, artifacts into dist/"
```

---

### Task 6: Корневой README-индекс, changelog Toolkit, уборка мусора

**Files:**
- Create: `README.md` (новый, индекс)
- Modify: `mods/vostok-toolkit/CHANGELOG.md` (влита история из корневого), `mods/vostok-toolkit/README.md` (ссылки на картинки)
- Delete: корневой `CHANGELOG.md`, `Picker`, `tr.txt`, `rtl_check.txt`, `rtlroll.log`, `roll_out.txt`, `pool_out.txt`, `Loadouts.vmz`
- Move: `check_nul_scan.py`, `check_vmz.py` → `tools/`

**Interfaces:**
- Consumes: артефакты в `dist/` и пути из Task 4.
- Produces: корневой `README.md` — единственная точка входа в репозиторий.

- [ ] **Step 1: Влить историю changelog**

Взять содержимое корневого `CHANGELOG.md` (записи 5.0.1–5.1.1) и вставить в
`mods/vostok-toolkit/CHANGELOG.md` после записи 5.2.0 и 5.1.2, по убыванию версий; дубли
версий оставить в одном экземпляре (текст — из корневого, он подробнее).

Проверка: `Select-String -Path D:\RTVMOD\mods\vostok-toolkit\CHANGELOG.md -Pattern '^## \[5\.' | Measure-Object`
Expected: в списке есть `5.2.0`, `5.1.2`, `5.1.1`, `5.1.0`, `5.0.1` без повторов.

- [ ] **Step 2: Убрать из README Toolkit ссылки на удалённые картинки**

Удалить строку `![Ironman Restart](assets/ironman-restart.jpg)` (строка 5) и пункт
`- \`assets/\` — images for the README and the Vostok Mods listing` из раздела
«Repository layout» (строка 42). Больше `assets/` в README не упоминается.

Run: `Select-String -Path D:\RTVMOD\mods\vostok-toolkit\README.md -Pattern 'assets/|\.jpg'`
Expected: пусто. Файлы картинок остаются в истории git (`git show <sha>:assets/<file>.jpg`),
их можно вернуть, если понадобятся для страницы мода.

- [ ] **Step 3: Написать корневой README-индекс**

Содержание: заголовок «Road to Vostok mods», одна строка о назначении репозитория, таблица
четырёх модов (`Мод | Что делает | Версия | README`), ссылки вида
`mods/vostok-toolkit/README.md`; блок «Building» (`pack.ps1 -Mod <slug>` / `-All`, результат
в `dist/`, имена файлов); блок «Checking» (`layout_check.py`, `check.ps1`, Godot 4.6.3 в `PATH`
или `-Godot <путь>`, Python 3); лицензия MIT. Версии в таблице — из `mod.txt` каждого мода.

- [ ] **Step 4: Убрать мусор и перенести утилиты**

```powershell
cd D:\RTVMOD
git rm -f CHANGELOG.md
Remove-Item -Force Picker,tr.txt,rtl_check.txt,rtlroll.log,roll_out.txt,pool_out.txt,Loadouts.vmz -ErrorAction SilentlyContinue
Move-Item -Force check_nul_scan.py,check_vmz.py D:\RTVMOD\tools\ -ErrorAction SilentlyContinue
```

Expected: `Get-ChildItem D:\RTVMOD -File` — только `.gitignore`, `AGENTS.md`, `LICENSE`,
`README.md`, `pack.ps1`.

- [ ] **Step 5: Коммит**

```powershell
git add README.md mods/vostok-toolkit/CHANGELOG.md
git commit -m "docs: root README index, merged toolkit changelog, drop root junk"
```

---

### Task 7: `AGENTS.md` под новую раскладку

**Files:**
- Modify: `AGENTS.md`

**Interfaces:**
- Consumes: пути из Task 4 и таблицы из Task 4/5.
- Produces: актуальный документ, по которому следующий агент не ищет `loadouts/`.

- [ ] **Step 1: Заменить пути**

- `loadouts/mods/VTK/` → `mods/vostok-toolkit/mods/VTK/`
- `loadouts/mod.txt` → `mods/vostok-toolkit/mod.txt`
- `loadouts/CHANGELOG.md` → `mods/vostok-toolkit/CHANGELOG.md`
- `standalone mods/<Name>/mods/<Name>/` → `mods/<slug>/mods/<Folder>/`
- `.check/project/tests/test_*.gd` → `.check/project/tests/<slug>/test_*.gd`
- `Loadouts.vmz` → `dist/Loadouts.vmz`
- `py -3 .check\layout_check.py`, `check.ps1` — пути не меняются.

**Внимание:** `user://MCM/loadouts` — это имя папки MCM в профиле игрока, не путь репозитория.
Его не трогать; правило о миграции `_migrate_mcm_dir` оставить как есть.

- [ ] **Step 2: Добавить раздел «Раскладка репозитория»**

Одна таблица: корень (индекс, `pack.ps1`, `AGENTS.md`, `.check/`, `docs/`) и четыре папки
`mods/<slug>/` с содержимым. Правила: slug = `id` из `mod.txt`; в папке мода только
`mod.txt`, `mods/<Folder>/`, `README.md`, `CHANGELOG.md` (+ `REFACTOR_SPEC.md` у Road To Loot);
новая фича мода — в его папке; новый мод = новая папка + строка в таблицах `check.ps1` и
`pack.ps1`; тесты — только в `.check/project/tests/<slug>/`, файл-опора — рядом с тестом;
тег `<slug>-<version>`; `version.txt` генерируется сборкой и отслеживается git; артефакты
только в `dist/`.

- [ ] **Step 3: Обновить числовые утверждения**

- число `preload` в `VTKUI.gd` — сверить: `Select-String -SimpleMatch 'preload(' D:\RTVMOD\mods\vostok-toolkit\mods\VTK\VTKUI.gd | Measure-Object`.
- число тестов: 41 файл (15 + 17 + 9).
- число скриптов модов: `Get-ChildItem -Recurse -Filter *.gd D:\RTVMOD\mods | Measure-Object`.

- [ ] **Step 4: Проверить, что старых путей не осталось**

Run: `Select-String -Path D:\RTVMOD\AGENTS.md -Pattern 'loadouts[/\\]mods|loadouts[/\\]mod\.txt|loadouts[/\\]CHANGELOG|standalone mods'`
Expected: пусто. Отдельно убедиться, что упоминания `MCM/loadouts` на месте:
`Select-String -Path D:\RTVMOD\AGENTS.md -Pattern 'MCM/loadouts'` — непустой результат.

- [ ] **Step 5: Коммит**

```powershell
git add AGENTS.md
git commit -m "docs(agents): rewrite paths and mod layout rules"
```

---

### Task 8: Теги, пуш и проверка «как у нового пользователя»

**Files:** только git-метаданные.

**Interfaces:**
- Consumes: всё предыдущее.
- Produces: запушенный `main` с тегами `<slug>-<version>`; подтверждение, что клон собирается и проходит проверки.

- [ ] **Step 1: Финальный локальный прогон**

Run: `py -3 D:\RTVMOD\.check\layout_check.py`
Expected: код 0.

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File D:\RTVMOD\.check\check.ps1`
Expected: `Tests passed: 41 file(s)`, код 0.

Run: `powershell -ExecutionPolicy Bypass -File D:\RTVMOD\pack.ps1 -All`
Expected: четыре архива в `dist/`, манифесты совпадают с базовой линией (команда из Task 5 Step 4).

- [ ] **Step 2: Убедиться, что дерево чистое**

Run: `git -C D:\RTVMOD status --short`
Expected: пусто (собранные `.vmz` — в `dist/`, он в игноре).

- [ ] **Step 3: Поставить теги**

```powershell
cd D:\RTVMOD
git tag vostok-toolkit-5.2.0
git tag thermal-vtk-2.2.0
git tag road-to-loot-0.3.4
git tag jcm-freeze-1.2.0
git tag --list "*-*"
```

Expected: четыре новых тега в списке, старые (`v4.7.2`, `v4.8.3`, `v5.1.2`, `vtk-4.17.7`,
`thermalvtk-1.1.0`) на месте.

- [ ] **Step 4: Запушить коммиты и теги**

```powershell
git push origin main
git push origin vostok-toolkit-5.2.0 thermal-vtk-2.2.0 road-to-loot-0.3.4 jcm-freeze-1.2.0
git status -sb
```

Expected: `## main...origin/main` без `ahead/behind`.

- [ ] **Step 5: Клонировать во временную папку и прогнать там**

Найти бинарь Godot (в клоне `tools/` не будет — он вне git):

Run: `Get-ChildItem D:\RTVMOD\tools -Recurse -Filter "*_console.exe" | Select-Object -First 1 -ExpandProperty FullName`
Expected: путь вида `D:\RTVMOD\tools\4.6.3\...\Godot_v4.6.3-stable_win64_console.exe`.

```powershell
git clone D:\RTVMOD C:\Users\home\AppData\Local\Temp\opencode\rtv-clone
cd C:\Users\home\AppData\Local\Temp\opencode\rtv-clone
Test-Path mods\vostok-toolkit\mods\VTK\version.txt   # Expected: True (файл в git, не генерируется после клона)
py -3 .check\layout_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1 -Godot "<найденный путь>"
powershell -ExecutionPolicy Bypass -File pack.ps1 -All
```

Expected: `layout_check` без ошибок; `check.ps1` — `Parse check passed` + `Tests passed: 41 file(s)`;
`pack.ps1 -All` — четыре архива в `dist/`, `Loadouts.vmz` собран из того же `version.txt`.
Ни одного ручного копирования файлов, кроме пути к Godot через `-Godot`.

- [ ] **Step 6: Убрать временный клон**

Run: `Remove-Item -Recurse -Force C:\Users\home\AppData\Local\Temp\opencode\rtv-clone`
