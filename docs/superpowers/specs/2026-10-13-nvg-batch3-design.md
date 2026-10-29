# Batch 3 — NVG: кадр, батч детекта, установка шейдера, debug за флагом

Дата: 2026-10-13
Статус: дизайн утверждён владельцем; спецификация готова к ревью.
Ветка: `audit`.
Источник задач: `docs/audit/vostok-toolkit-4.15.1.md` — P1 (§4 High), P1b (§4 High), P2e (§4 Medium), V4 (§3 Medium), D9 (§2).

## Цель

Починить главный горячий путь мода: NVG-кадр. Сейчас `VTKNVG._process` каждую
рамку обходит всех ботов (включая спящий пул ~12), рекурсивно собирает меши по
поддеревьям, аллоцирует массивы и пишет `material_override` — **даже когда
тепловизор выключен**. Плюс `frame_pre_draw` обходит всё ещё раз, а
`node_added` шлёт `call_deferred` на каждый узел сцены.

Правки:

1. **P1** — ранний выход из кадра при выключенном тепловизоре; снять покраску
   один раз на переходе on→off; позиция игрока и фракция — раз за кадр/кэш;
   пере-свип мешей только при смене числа детей.
2. **P1b** — `frame_pre_draw` работает только когда что-то покрашено.
3. **P2e** — батчить `node_added` в один проход на кадр (отдельно для VTKNVG и
   VTKKillCounter).
4. **V4** — ставить шейдер по событию появления NVG-узла + ограниченный ретрай,
   а не проверять каждый кадр.
5. **D9** — debug-подсистема NVG остаётся под MCM-флагом `nvg_debug_probe`.

Все правки — производительность без смены наблюдаемого поведения. Единственный
риск смены: лаг в 1 кадр при переключении NVG (см. раздел 1).

## Что выяснено (факты)

- **Ванильный `NVG.gd`** (бинарник `RTVcopy/extracted/Scripts/NVG.gdc`,
  реконструирован `_vtk_detok.gd`; в кэше modloader детокенизированного исходника
  нет): `extends Control`, `@onready var overlay = $Overlay`,
  `NVGMaterial = overlay.get_child(0).material` в **await-based** `_ready` (ждёт
  ~0.1 c). `Activate()` ставит `gameData.NVG = true`, `overlay.show()`, tonemap и
  зовёт `NVGMaterial.set_shader_parameter("tint", NVGData.color)`.
- Ваниль **никогда не переприсваивает** `.shader`/материал — кэширует ссылку один
  раз. Значит, наш шейдер теряется только при пересоздании узла (пересборка
  карты), что ловится событием `node_added` и сменой `current_scene`. Per-frame
  re-inspect не нужен.
- `RenderingServer.frame_pre_draw` — сигнал движка (без узла); мод
  переустанавливает покраску после всех `_process` узлов.
- `RTV_SKIP_LIST` в modloader (`Message.gd`): await-based `_ready` — «not verified
  under the coroutine-aware wrapper». `NVG.gd` в skip-списках нет, но его `_ready`
  тоже await-based → декларировать хук на `NVG.gd` рискованно; событийная
  установка надёжнее.
- `Paths.NVG` = `/root/Map/Core/UI/NVG` уже существует в `VTKPaths.gd` — пункт V4
  «путь в константу» выполнен ранее.
- Debug уже полностью за флагом: `_dbg()` гейтит по `set_debug_probe` и только
  тогда открывает `user://loadouts_debug.log`; F4-оверлей и uniform `debugDetect`
  гейтятся `set_debug_probe`; `_probe_pixels`/`_count_friendly`/`_log_trader`
  вызываются только в debug-ветке либо с гейтом внутри.

## Раздел 1 — P1: ранний выход кадра NVG

`VTKNVG._process` (417-459), `_update_bot` (629-697), `_update_mine`, `_clear_paint`.

- Раз за кадр: `on := set_thermal and _nvg_active()` и `ppos := _player_pos()` —
  один вызов на кадр, а не по два на бота (`_update_bot` сейчас зовёт
  `_player_pos()` дважды: маркер + дистанция покраски).
- `_update_bot(id, on, ppos)` принимает позицию аргументом и не зовёт
  `_player_pos` внутри.
- **Переход on→off** (прошлый кадр `on`, текущий `off`): один проход снятия —
  `material_override = null` на все меши ботов и мин, скрыть Nomad-маркеры
  (`_clear_paint()`). Флаг прошлого состояния хранить в поле.
- **Покой при off** (переход уже сделан): дорогую часть не выполняем — ни
  `_sweep_bot_meshes`, ни запись `material_override`, ни сборку `fresh: Array`.
- **Death clock работает всегда** (консервативно): даже при off читаем
  `node.dead` и лэтчим `e["recorded"]/e["death"]` в первый кадр смерти. Иначе
  бот, убитый при выключенном тепловизоре, при включении получил бы `death`
  задним числом и светился бы дольше `DEATH_COOLDOWN`. Стоимость — одно поле на
  бота, без обхода поддерева.
- `_is_friendly` кэшируется в записи (`e["friendly"]`). Фракция приходит из
  `variant` (`AIData`), который может быть `null` в момент регистрации →
  пересчитываем, пока `variant == null`; как только резолвится — кэш постоянен.
- `_sweep_bot_meshes` только когда `node.get_child_count()` изменился с прошлого
  свипа (`e["child_count"]`). Это лечит «меши добавились позже» (ради чего свип
  был каждый кадр), но убирает рекурсию в покое.
- `_tick_cd` (TICK, 0.1 c) сохраняется для `_apply_uniforms`, `_retry_mines` и
  debug-summary; кадровая покраска от тика не зависит (как и сейчас).

Риск: 1 кадр сырых key-пикселей при резком включении NVG, если меши были
пересобраны в тот же кадр; принято (аудит: «лаг в 1 кадр при переключении»).

## Раздел 2 — P1b: `frame_pre_draw` только при наличии покраски

`VTKNVG._frame_pre_draw` (704-728).

- Ввести `var _paint_on := false`; `_process` ставит `true`, если `on` и хотя бы
  один бот покрашен, иначе `false`.
- `_frame_pre_draw`: `if not _paint_on: return` вместо `if not set_thermal: return`.
  Убирает обход всех ботов и мешей, когда тепловизор включён, но красить нечего
  (нет ботов в радиусе/нет ботов вовсе).
- Логика переустановки покраски внутри не меняется.

## Раздел 3 — P2e: батч `node_added`

Общий приём: `_on_node_added` только кладёт `instance_id` в буфер; `_process`
(раз за кадр) одним проходом разбирает буфер через существующий `_deferred_check`.

- **VTKNVG** (`_on_node_added` 293-294, `_deferred_check` 297-314):
  - `var _pending: Array[int] = []`; `_on_node_added` → `_pending.append(node.get_instance_id())`
    (без `call_deferred`).
  - `_process` в начале зовёт `_drain_pending()`: для каждого id — `_deferred_check(id)`,
    затем `_pending.clear()`.
  - Семантика та же: к моменту дренажа узел уже в дереве; `instance_from_id` +
    `is_inside_tree()` фильтруют освобождённые.
- **VTKKillCounter** (`_on_node_added` 24,39; `_deferred_check` 39-42):
  - тот же буфер; `_process` дренит до гейта `if not _enabled`; при `not _enabled`
    буфер очищается и разбор не идёт (классифицировать нечего).
  - `_reseed` (полный скан) не трогаем: он только на старте и смене карты.

Риск: потерять узел, появившийся и удалённый между кадрами. Смягчение: буфер
разбирается каждый кадр; узлы, что не успели, и сейчас терялись (`call_deferred`
тоже откладывает). Детект по-прежнему проверяется в игре.

## Раздел 4 — V4: событийная установка шейдера

`VTKNVG._try_install_shader` (329-364), `_process` (418), `_scan_node`/`_deferred_check`,
`_reseed`.

- Убрать `_try_install_shader()` из `_process`.
- Ставить при обнаружении NVG-узла: `_scan_node`/`_deferred_check` (путь
  заканчивается `NVG.gd`) уже зовут `_try_install_shader()`; `_reseed` покрывает
  узлы, что существовали до нашего `_ready`.
- Ограниченный ретрай: `var _install_retry := 0`; если NVG-узел найден, но
  `overlay.get_child_count() == 0` / материал ещё не готов (await-based `_ready`),
  ставим `_install_retry = INSTALL_RETRY_FRAMES` (~60 кадров ≈ 1 c). `_process`
  уменьшает счётчик и зовёт `_try_install_shader()`, пока он > 0. На успех
  `_install_retry = 0` — дальше ноль обращений за кадр.
- Пересборка карты: узел NVG освобождается, `_process` детектит смену
  `current_scene` → `_reseed` → новый NVG → установка (при необходимости — новый
  ретрай).
- Фоллбэк `get_node_or_null(Paths.NVG)` внутри `_try_install_shader` сохраняем, но
  он вызывается только из обнаружения/ретрая, не каждый кадр.
- Декларированный хук на `NVG.gd` **не делаем** (await-based `_ready`, см. факты).

## Раздел 5 — D9: debug остаётся за флагом

- Ничего не удаляем и не меняем в поведении: вся debug-подсистема уже под
  `nvg_debug_probe` (`set_debug_probe`), F4-оверлей и `debugDetect` — тоже.
- Шейдер `VTKNVG.gdshader` не трогаем (P3d: полноэкранный, только при NVG on).
- Вне области: переименование `user://loadouts_debug.log` и удаление ~30 `print()`
  — по решению владельца оставляем.

## Тесты и проверка

- Стенд: `py .check\layout_check.py` (python в этой системе — заглушка WindowsApps,
  запускать через `py`) — зелёный; `powershell -NoProfile -ExecutionPolicy Bypass
  -File .check\check.ps1` — 16 скриптов + все тесты, код 0.
- Headless-тесты для этих правок не добавляем: изменения рантайм-кадровые
  (SceneTree/RenderingServer), чистой логики не появляется. Существующие тесты
  обязаны остаться зелёными (особенно `test_hooks.gd`, `test_feed.gd` —
  классификация VTKKillCounter).
- Ручной игровой чек:
  1. NVG вкл/выкл: зелёный NVG и тепловизор появляются/гаснут, без постоянной
     сырой засветки.
  2. Боты светятся в радиусе, после смерти остывают от конечностей внутрь и
     гаснут через `DEATH_COOLDOWN`.
  3. Дружественный Nomad: ▼ появляется в радиусе свечения, скрыт при off.
  4. Мины подсвечиваются в радиусе.
  5. Смена карты (travel): NVG продолжает работать (шейдер переустановлен на
     новом узле).
  6. Kill HUD/фид: счётчики верны после спавна ботов и убийств.
  7. Debug off → `user://loadouts_debug.log` не растёт, F4 ничего не делает;
     Debug on → сводка/`_probe_pixels` работают.

## Версия и файлы

- Версия `4.16.1 → 4.16.2` (patch: производительность, видимого поведения не
  меняем). Затрагиваются `loadouts/mod.txt`, `loadouts/mods/VTK/version.txt`,
  `README.md` (синхронит `pack.ps1`), `CHANGELOG.md` (секция `## [4.16.2]`,
  `### Changed` — «Minor performance improvements and internal cleanup.»).
- Код: `loadouts/mods/VTK/VTKNVG.gd` (основное),
  `loadouts/mods/VTK/VTKKillCounter.gd` (батч).
- `mod.txt` секция `[hooks]` не меняется: новых хуков нет.
- `AGENTS.md` (вне git): при желании дополнить заметку о NVG — событийная
  установка шейдера, батч `node_added`, debug за флагом.

## Вне области

- `VTKNVG.gdshader` (P3d: полноэкранный, только при NVG on).
- Удаление debug-подсистемы (D9 решён: оставить за флагом).
- Хук на `NVG.gd` (отклонён: await-based `_ready`).
- Остальные батчи: 4 (UI-пересборки), 5 (ванила-интеграция), 6 (декомпозиция).

## Решения владельца (recap)

- **D9** — debug оставить под MCM-флагом `nvg_debug_probe`; шейдер не трогать.
- **V4** — событийная установка (node_added) + ограниченный ретрай; без
  декларированного хука на `NVG.gd`.
- **P2e** — раздельные батчи для VTKNVG и VTKKillCounter.
- **P1** — death clock работает и при выключенном тепловизоре (консервативно).
