# ThermalVTK — единый режим: заливка тел в цвете стейта, отказ от FULL, F6 → палитра

**Дата:** 2026-10-20
**Статус:** на утверждении
**Связанные:** `2026-10-20-thermalvtk-pipoff-orbit-detect-design.md`,
`2026-10-20-thermalvtk-debug-state-labels-design.md`
**Версия:** 1.6.0 (minor: новое поведение + удаление фич; мажор 2.0.0 приберегаем под финал)

## Что и зачем

Свести мод к **одному режиму**. Сейчас F6 переключает FULL (бот-палитра через подмену
материала ботов, ключи читает NVG-оверлей) ↔ CONTOUR (термомир + обводка). Режим FULL
больше не нужен — его функцию (видно тела) забирает **заливка тела в цвете стейта**,
нарисованная тем же `material_overlay`, что и обводка. Заодно:

- `Body fill` перестаёт быть мёртвым: в коде `fill_alpha` захардкожен `0.0`, т.е.
  тумблер в MCM ни на что не влиял;
- добавляется MCM-слайдер плотности заливки, чтобы играться;
- `Spotted flash` и `Bot colour`/`Distance` удаляются как мёртвый вес;
- **F6 переназначается на цикл палитры мира** (Classic→Amber→Forest→Ice), синхрон с
  MCM-дропдауном.

## Целевая модель

Один режим. `Thermal vision` (тумблер/хоткей) + NVG надет → термомир (палитра) +
тела NPC заливкой в цвете стейта + обводка тем же цветом; мины подсвечены.
Понятие «FULL mode» отсутствует.

## Изменения

### Палитра: F6 как хоткей цикла (`ThermalVTK.gd`)

- В MCM секции 01 вместо-рядом с `key_thermal_toggle` добавить
  `Keycode key_palette_cycle` (дефолт `KEY_F6`).
- `KEY_MODE`/`_mode_full_thermal`/`_toggle_mode`/ветки FULL в `_apply_mode` — удалить.
- Новый `_cycle_palette()`: Classic→Amber→Forest→Ice по кругу; обновляет
  `_nvg.set_palette(...)`, `_notify(...)` (англ. литерал, как принято для HUD-тостов),
  и пишет выбор в `thermal_state.cfg` (ключ `world_palette`, целое 0..3) через
  `_save_state`.
- Хозяин значения — `thermal_state.cfg`: при старте `_cycle_palette` берёт
  старт из сохранённого индекса. MCM-дропдаун остаётся для тонкой настройки и
  продолжает работать через `_mcm_apply` (его значение — база, если в state-файле
  пусто; чтобы не расходились, `_mcm_apply` применяет палитру к NVG, а `_cycle_palette`
  — поверх). `VTKNVG.gd` получает публичный `set_palette(mode: int)` (сейчас
  `set_palette` — поле, выставляемое только из `_mcm_apply`).

### Заливка: цвет стейта (`VTKOutlineBody.gdshader`, `VTKOutline.gd`)

- `VTKOutlineBody.gdshader`: убрать `warmColor`/`midColor`/`coldColor` и banded
  cooling-ladder; добавить `uniform vec3 fillColor`. Формула:
  `ALBEDO = fillColor * mix(1.0, 0.15, cool)`, `ALPHA = fill_alpha * (1.0 - cool)`.
  На `cool == 1` заливка прозрачна. Заголовочный комментарий переписать (шейдер
  больше не «cooling-ladder», а простой `fillColor`).
- `VTKOutline.gd`: `refresh` принимает `fill_color` в `opts`, гоняет
  `fill_alpha = fill_opacity * alpha`; убрать `flash`/`flash_color`.
- `VTKESP._opts_for`: вместо `"fill_alpha": 0.0` кладём `p_fill_alpha`,
  `"fill_color": <цвет стейта>` (тот же, что обводка: `st*Color`/`nomad`);
  `Body fill` (Bool) остаётся мастер-выключателем: off → alpha 0.

### Трупы

`cool` (`Tracker.cool_factor`) уже едет в шейдер. Заливка и обводка гаснут по `cool`
за `Corpse cooling time`. Banded-лестницы больше нет — только яркостное затухание.
Проверить, что ring-шейдер уже гасится по `cool` (если нет — добавить `mix` по alpha).

### Резка mode-B кода

- **`VTKNVG.gd`:** `_bots`, `_update_bot`, `_collect_meshes`, `_clear_bot_paint`,
  `_bots_painted`, бот-ветки `_scan`/`_process`, `BOT_PRESETS`, `DET_WARM/MID/COLD`,
  `set_bot_paint`, `set_debug_raw`/`_debug_raw`. Остаётся `_mines`/`DET_MINE`,
  `set_mines_enabled`, `set_thermal_enabled`, `set_state_colors`, `set_palette`,
  `_nvg_active`, `_scope_rotate`.
- **`VTKNVG.gdshader`:** `warmKey`/`midKey`/`coldKey`, `warmColor`/`midColor`/`coldColor`,
  бот-ветки детекта, `debugRaw`, `markNomads`/`markerKey`/`markerColor`. Остаётся
  `mineKey`, 5 `st*Key`+`st*Color`, палитра, `scopeRotate`+`orbitDist`, стирание мины.
- **`VTKESP.gd`:** `p_flash`, `p_flash_color`, `_player_visible`, `flash` из opts;
  TEMP-зонд `key_override_on`/`key_override` (Task 6) — тоже удалить.
- **`VTKShaders.gd`:** без структурных изменений (те же два варианта body/ring).

### MCM после резки

- **01. ThermalVision** — `key_thermal_toggle`, `key_palette_cycle` (новый),
  `nvg_noise`, `nvg_white`, `thermal_enabled`, `thermal_mines`, `thermal_palette`,
  `thermal_world`. Удаляются `thermal_bot_preset`, `thermal_far_distance`.
- **02. Contour ESP** — `outline_enabled`, `outline_body_fill` (Bool),
  `fill_opacity` (Float 0..1, дефолт 0.4, новый), `corpse_decay`, `outline_thickness`,
  `outline_brightness`. Удаляются `outline_pvisible`, `pvisible_color`.
- **03/04/05** — без изменений.

`_sync_config` вычистит удалённые ключи из `config.ini` игрока самостоятельно.

### Тесты

- `test_shaders.gd`: в `t_state_keys_in_overlay` убрать бот-ключи/marker, оставить
  `st*Key`/`st*Color`, `dStN`/`dStNomad`, `scopeRotate`/`orbitDist`. `t_shaders_compile`,
  `t_nvg_contour_reads_mines`, `t_palette_four_modes` — остаются. Проверить, что
  `strip_depth_test` не завязан на удаляемые uniform.
- `test_esp.gd`, `test_outline.gd`, `test_tracker.gd`, `test_states.gd` — убрать
  упоминания flash/бот-палитры/marker, если есть.
- `check.ps1` — набор файлов тот же.

## Вне объёма

- Обводка сквозь оптику (PIP off) — оставлена как есть по решению пользователя.
- Подписи состояния над NPC — уже сделано (1.5.x); над мёртвыми убраны.

## Риски

1. **Смена палитры при NVG on** требует `_apply_uniforms`-путь; `set_palette` должен
   пережать uniform `worldPaletteMode` немедленно, иначе смена видна только на
   следующем install/refresh. Проверяется в игре.
2. **`fillColor` для заливки** должен совпасть со стейт-цветом обводки (один источник
   в `_opts_for`), иначе тело и контур разъедутся по цвету.
3. **Резка бот-пути** массовая — не задеть `_mines` (общий `_scan`/`_reseed`/`_pending`
   с бот-ветками: бот-ветку убрать, mine оставить).
4. **Порядок применения F6-палитры и MCM**: хозяин — state-файл, но `_mcm_apply`
   тоже пишет палитру; при рассинхроне побеждать должен последний явный выбор
   пользователя (F6 пишет в state, `_mcm_apply` — только при явном изменении меню).

## Проверка

1. `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1` → зелёный,
   набор тестов тот же, нет `SCRIPT ERROR`/`Parse Error`/`Invalid call`.
2. `pack.ps1` → `ThermalVTK.vmz` → install.
3. В игре (NVG + Thermal on):
   - тело NPC залито цветом стейта, обводка тем же цветом;
   - `Fill opacity` в MCM меняет плотность; `Body fill` off → только обводка;
   - `Corpse cooling time` → труп тускнеет и исчезает;
   - F6 листает палитру мира, MCM-дропдаун остаётся синхронным;
   - FULL-режима нет, F6 не переключает режимы;
   - `config.ini` после запуска: нет `thermal_bot_preset`/`thermal_far_distance`/
     `outline_pvisible`/`pvisible_color`.
