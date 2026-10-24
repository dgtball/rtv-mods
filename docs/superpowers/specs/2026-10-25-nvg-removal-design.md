# Вырезание тепловизора из основного мода (Vostok Toolkit) — спека

Дата: 2026-10-24 · Мод: Vostok Toolkit (loadouts) · Размер: проект

## Намерение и зачем

Тепловизор родился внутри этого мода и с тех пор полностью переехал в независимый **ThermalVTK** (свой шейдер, настройки, датчики, калибровка, тесты, уже в релизе 1.17.x). Таскать его обратно больше страшнее чем убрать: проблемы 2026-10-24 (перенасыщение зимнего фона днём и ночью) были починены в ThermalVTK без прикосновения к loadouts. Задача — вернуть loadouts к его ядру: сеты, телепорт, заметки, вклады, экипировка, а тепловидение оставить единственному специализированному моду. Два мода, две независимые трассы релизов.

## Цели

- NVG/тепловизор полностью вырезан из loadouts: нет оверлей-шейдера, тепло-подсветки ботов, мин, nomad-маркера, авто-тускловки зимы, тепловой категории в MCM.
- Настройки `thermal_*`/`nvg_*` исчезают из `VTKConfig` (MCM config.ini чистится автоматически при следующем запуске 5.2.0 — правило #4).
- Два мода независимы: loadouts не объявляет зависимость от ThermalVTK, удаление ключей автопочистит конфиг пользователя.
- `VTKSeasonDriver`/`VTKSeasons` и другие модули остаются — они season-engine/loadout-косметика без thermal.
- `VTKFeatureHost` остаётся хостом только для хуков/телепорта/HUD/kill-counter/feed; весь `_nvg`-путь уходит.

## Не-цели / анти-цели

- Не оставлять резервные заглушки/`pass` — это хуже выреза (мертвый код притаскивает ломаные прелоды и вес).
- Не трогать standalone ThermalVTK (другой модуль, уже shipped).
- Не удалять `VTKSeasonDriver`/`VTKSeasons` — эти независимы (уже подтверждено).

## Ограничения

- **Версия 5.2.0** (наша директива: «хочу убедиться, что косяков не возникнет»; важнейší/баг-правка сохранена как 5.x).
- `mod.txt`: `[dependencies] optional=[]` остаётся — независимый.
- `VTKConfig`: 22 поля → 11; `test_config` переписывается под 11.
- `VTKFeatureHost.apply_config`: HUD → equip → travel — и никаких `if nvg_node == null: return` с ветвящимися gates; NVG-блок снят.
- Pack 26 скриптов → 23 после удаления.
- Отступы — табы; комментарии — factual, English. `docs/` за gitignored — `git add -f`.

## Применимые потоки

- Автоочистка MCM config: при выходе ключа из кода `.register_mcm` удаляет его из `user://MCM/vostok-toolkit/config.ini` (правило 4); `Info` переписывается.
- `_register_mcm` свёртка cfg: просто снимаем line ~30-41 и 54 (nvg_debug_probe).
- Автономные тесты: `.check` не знает про VTKNVG (нет preload'а VTKFeatureHost). check.ps1 делает preflight — если `VTKNVG.gd` удаляется, скрипт не ломается.

## Task list (preview)

**T1 Delete NVG subsystem** — удалить `VTKNVG.gd`, `VTKNVG.gdshader`, `VTKBot.gdshader`; grep-проверка ссылок.

**T2 Feature host rewires** — снять `const NVG`, `_nvg_node`, `_ensure_nvg`, `nvg()`, `_thermal_active/_mines_active`, `_apply_nvg_settings`, `set_thermal`; чисто HUD/equip/travel в apply_config.

**T3 Config + MCM** — убрать 12 полей + read lines + MCM registration; VTKUI не ссылается на nvg.

**T4 Tests + checks** — переписать test_config (32 ассерта → 11), layout_check, check.ps1 green.

**T5 Release 5.2.0** — mod.txt 5.2.0; CHANGELOG Added Removed; README → ThermalVTK ссылка; pack + deploy; партнёр — smoke test (loadouts/teleport/notes/deposits без NVG и без краша).

## Поля, которые уходят (12)

`nvg_debug_probe, thermal_enabled, thermal_mines, thermal_mark_nomads, thermal_winter_auto, thermal_winter_dim, thermal_palette, thermal_world, thermal_bot_preset, thermal_far_distance, nvg_noise, nvg_white`.

## Поля, что остаются (11)

`key_ui_toggle, language, auto_equip, debug_log, tp_unlocked_shelters_only, kill_counter_enabled, kill_feed_enabled, season_enabled, season_start, season_cycle_days, season_visuals`.

## Безопасность / regression-class

1. **apply_config больше не применяет НИЧЕГО thermal** после удаления — нужно, чтобы HUD/equip/travel **по-прежнему применялись** (старый ранний `return`). T2 явно убирает early return.
2. **В dangling preload `const NVG := preload(...)`** сломает FeatureHost уже в parse. T1/T2 grep-gate.
3. **stale field reference `_nvg_node` в `_ensure_nvg`/`nvg()`/`_apply_nvg_settings`** — grep перед commit.
4. **test_config drift** — ассерты должны согласоваться в паре.
5. **Pack с glob** — удаление 3 файлов просто их дропнет; ожидание 23 записей.

## Явная пометка по winter-vs-движок

- `VTKSeasonDriver`/`VTKSeasons` НЕ тронуты (сезонный движок для loadout-cosmetics). `thermal_winter_auto`/`dim` были thermal-nvg side, и они ушли с ним (по нашей директиве).

## Безопасность, оставить дальше

- Не rollback-guard, git коммиты сохраняют state.
- `debug_log` flag остаётся (общий дебаг), `season_*` остаётся (сезонный UI).
- NVG-enabled debug logs dying with VTKNVG deletion — runtime msg `_dbg` context pretty to assay remnants in VTKLog.
- Co cleanup of `_dbg_f` could be done, but MVP keeps it (log calls still work).

## Следующий шаг

Утверждаешь спеку — я пишу实施方案 (6 задач, wiring-lists по файлам), затем Native-execution (как с 1.17.x патчём). Если что-то не так в списке полей — поправлю перед планом.
