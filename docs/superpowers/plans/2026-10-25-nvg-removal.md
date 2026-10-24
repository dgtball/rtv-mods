# Вырезание NVG из loadouts — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Жёстко вырезать тепловизор (NVG) из loadouts, чтобы там осталось только ядро (сеты/телепорт/заметки/вклады). ThermalVTK получается отдельным готовым модом; loadouts — полностью независимым. Осуществляется как 5.2.0.

**Architecture:** Жёсткий вырез: три файла убираем, FeatureHost/Config/MCM шлифуем, `apply_config` перестраивается, release 5.2.0, smoke-test партнёра, merge.

**Tech Stack:** GDScript/Godot 4 (loadouts), PowerShell pack (`pack.ps1`), `.check\check.ps1`, `layout_check.py`.

**Spec:** `docs/superpowers/specs/2026-10-25-nvg-removal-design.md`

## Global Constraints (глобальные ограничения)

- Отступы — табы; комментарии — factual English; без мёртвых заглушек/`pass`.
- `mod.txt`: `version="5.2.0"`, `[dependencies] optional=[]` — независимый.
- `VTKConfig`: 22 → 11 полей (после удаления thermal/nvg). `test_config` под 11.
- `apply_config`: только HUD → equip → travel, без раннего `return` от отсутствующих NVG-props.
- `thermal_winter_auto/dim` удаляются вместе с NVG (термальная сторона).
- `VTKSeasonDriver`/`VTKSeasons` не трогаем (независимые).
- `pack.ps1` 26 → 23 скриптов.
- `docs/` у gitignore → коммит с `git add -f`.

## Review Focus — степени риска

No-test-stand; failures, most likely first:

1. `apply_config` теряет HUD/equip/travel после удаления блока — старый ранний `return`. Новый делает 3 вещи в порядке. (T2)
2. Dangling preload `const NVG := preload(...)` ломает parse при запуске. (T1 grep gate)
3. Stale field refs `_nvg_node`/`_apply_nvg`/`_thermal_active` → parse failure. (T2)
4. test_config drift — удаление 12 keys из схемы не из теста = FAIL, и наоборот defaults-without-asserts. Парное согласование. (T4)
5. pack glob 26 → 23. (T4–T5)

---

### Task 1: Удаление файлов NVG-подсистемы

**Files:** Delete 3 files.

- [ ] **Step 1:** Удалить `loadouts/mods/VTK/VTKNVG.gd`, `VTKNVG.gdshader`, `VTKBot.gdshader`.
- [ ] **Step 2:** Grep-проверка (ожидание 0):

```powershell
Select-String -Path "loadouts\mods\VTK\*.gd" -Pattern "VTKNVG|VTKBot.gdshader|NVG" | Where-Object { -not $_.Line.Trim().StartsWith('#') } | Measure-Object
```
- [ ] **Step 3:** Commit

```powershell
git add -A "loadouts\mods\VTK\VTKNVG.gd" "loadouts\mods\VTK\VTKNVG.gdshader" "loadouts\mods\VTK\VTKBot.gdshader"
git commit -m "loadouts: delete NVG/thermal subsystem files"
```

### Task 2: Перекрут Feature host

**Files:** Modify `loadouts/mods/VTK/VTKFeatureHost.gd`.

- [ ] **Step 1:** Удалить в порядке: L15 `const NVG`, field `_nvg_node`, fields `_thermal_active`/`_mines_active`, методы `_ensure_nvg`, `nvg()`, `_apply_nvg_settings`, `set_thermal`.
  `apply_config`: убрать `nvg_node` local, early return, NVG-props, `set_thermal`; retain `set_hud`, `set_equip`, `set_travel_unlocked`.
- [ ] **Step 2:** Verify grep removed symbols → 0.
- [ ] **Step 3:** Commit.

### Task 3: Чистка Config + MCM

**Files:** Modify `loadouts/mods/VTK/VTKConfig.gd`, `loadouts/mods/VTK/VTKMCMBridge.gd`, verify `VTKUI.gd`.

- [ ] **Step 1: VTKConfig.gd** — удалить 12 полей (+read lines): `nvg_debug_probe, thermal_enabled, thermal_mines, thermal_mark_nomads, thermal_winter_auto, thermal_winter_dim, thermal_palette, thermal_world, thermal_bot_preset, thermal_far_distance, nvg_noise, nvg_white`. Док-коммент «22 ключа» → «11 ключей».
- [ ] **Step 2: MCMBridge** — удалить `var TP := "02. ThermalVision"`; удалить `.set_value` thermal/nvg/nvg_debug_probe (lines ~30-41, 54); `apply_config` MCMBridge — убрать `nvg_node.* c.*`.
- [ ] **Step 3: Verify grep `_features.nvg` → 0.**
- [ ] **Step 4: Commit.

### Task 4: Тесты + проверки

**Files:** Modify `.check/project/tests/test_config.gd`; Run `layout_check.py`, `check.ps1`.

- [ ] **Step 1: Rewrite `test_config.gd`**
  - `t_empty_cfg_keeps_defaults`: убрать 12 asserts (NVG/thermal field defaults).
  - `t_dict_value_wins`: убрать `nvg_noise` строку.
  - `t_missing_key_uses_default`: заменить thermal_world assert на season_cycle_days.
  - `t_primitive_and_plain_string_fall_back`: заменить `thermal_mines` string fallback → `season_enabled`/`kill_feed_enabled`.
  - `t_full_round_trip`: убрать 12 cfg.set_value thermal/nvg lines + 12 ck lines.
  - `t_float_int_coercion`: заменить `thermal_palette` на `season_cycle_days`.
- [ ] **Step 2: layout_check** `py -3 .check\layout_check.py` → 0.
- [ ] **Step 3: check** `powershell -File .check\check.ps1` → tests passed, exit 0.
- [ ] **Step 4: Commit.

### Task 5: Release 5.2.0 + ship

**Files:** `loadouts/mod.txt`, `loadouts/CHANGELOG.md`, `loadouts/README.md`, `pack.ps1` → `Loadouts.vmz`.

- [ ] **Step 1:** `mod.txt` → `version="5.2.0"` (dependence unchanged).
- [ ] **Step 2:** CHANGELOG `## [5.2.0] - 2026-10-25`, category `### Removed`: bullet «Тепловизор … moved to standalone ThermalVTK mod; теперь только [link].»
- [ ] **Step 3:** README (if thermal section) → update pointer.
- [ ] **Step 4:** Pack+deploy 23 entries to game mods dir.
- [ ] **Step 5:** Партнёр smoke test: loadouts/teleport/notes/deposits работают, без NVG-крашей, MCM без ThermalVision, config.ini авто-чистится (old thermal values gone).
- [ ] **Step 6:** Ledger + final review self-note.

### Task 6 (partner): Merge prep

- [ ] Partner reports PASS → merge main fast-forward; delete branch; optional cleanup worktree.
- [ ] FAIL → triage.

---

## Self-review checklist (выполняет исполнитель)

1. Spec coverage: goals → T1/T2; config → T3; tests/checks → T4; release → T5.
2. Step scan: каждая метка оканчивается на проверке.
3. Type consistency: apply_config(c: ConfigRec) типизирован; removed symbols no references.
4. Review Focus: (1) apply_config перестройка → T2; (2) preload grep → T1; (3) stale-field grep → T2/T3; (4) test_config agreeing → T4; (5) pack 23 → T4/T5.
5. Proportion: plan ≈ spec size; patch steps mostly grep-gated.

---

## Rulings (what I decided)

- **Версия minor 5.2.0** несмотря на удаление — партнёр directive («хотю убедиться, что косяков не возникнет»). (AGENTS says major must trigger; user overridden)
- **Не объявляем** ThermalVTK как зависимость — мод независим.
- **debug_log** flag остаётся (дебаг общего назначения); **_dbg_f** alive with logging hooks.
- Удаляем **только** thermal-flavored ключи — **сохраняем season_*** (season-engine/loadout-premium semantics).
- NVG log-path gone with deletion (no references after).
- **Не** трогаем `VTKSeasonDriver`/`VTKSeasons` (партнёр directive; season engine/loadout-cosmetic).
- Config autoclean без migration (rule 4).
- Никакого отдельного rollback — git защищает.
- CHANGELOG category `### Removed` per Keep-a-Changelog.

---

## Execution Handoff

Plan saved to `docs/superpowers/plans/2026-10-25-nvg-removal.md`. Review it; tell me if captures. Выбираем **Native** (ты ранее выбрал Native для loadouts), если подтвержден — начинаю T1.

Одно пожелание на согласование (чтоб не казалось, что «тираж я почему думал): в T3 чистка Config удаляет 12 keys. **Под affirm** — go.