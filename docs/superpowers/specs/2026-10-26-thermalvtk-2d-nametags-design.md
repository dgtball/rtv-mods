# ThermalVTK — 2D-подписи над NPC и отдельный тумблер ромба номада

**Дата:** 2026-10-26
**Статус:** на утверждении
**Связанные спеки:** заменяет `2026-10-20-thermalvtk-debug-state-labels-design.md` (подписи Label3D); опирается на `2026-10-25-thermalvtk-2.1.0-perf-xray-layers-design.md`.
**Версия:** 2.2.0

## Что и зачем

Подписи сейчас — это `Label3D`: 3D-геометрия, поэтому они проходят через canvas-шейдер тепловизора (`hint_screen_texture` в `VTKNVG.gdshader`) и перекрашиваются палитрой; на дистанции шрифт мылится; набор полей беден — сырой стейт и категория. Теперь меняем способ отрисовки целиком.

Идея берётся из JCM (`referens/JCM_v3.6.0.vmz`, `JCMESP.gd`): ESP рисуется в `Control._draw()` и лежит на своём `CanvasLayer` — нарисованное попадает в кадр уже после post-обработки экрана. Там цвет и текст остаются ровно такими, какими их уложили. Никаких ключей, детекторов, `NO_CONTOUR_META`. Заодно уходит per-instance стоимость: вместо `Label3D` + квад-меша на каждого NPC — один full-rect Control на весь экран.

Что делаем: подписи переезжают в 2D-слой; набор полей — имя, дистанция, здоровье, состояние с «vs», reloading. Ромб номада тоже переезжает в 2D и получает отдельный тумблер в MCM.

Согласовано с тобой: MCM-полей под поля подписей нет. Гейт — существующий `debug_log` (ключ `[Bool] debug_log` в CAT5): включил — видишь подписи, выключил — не видишь. Отдельный ключ — только у ромба номада.

## Решения

| Аспект | Решение |
|---|---|
| Гейт подписей | `VTKDebug.enabled` (ключ `[Bool] debug_log`), как в 1.5.0. Новых ключей нет |
| Гейт ромба | `contour_layer` (как сейчас) и новый ключ `nomad_marker` (Bool, def true, CAT1). Выключенное легально — ромба просто нет |
| Расположение слоя | Свой `CanvasLayer(layer = 1)` → `Control` на весь экран, `mouse_filter = IGNORE`. Ниже игрового UI не опускаем: thermal-оверлей читает `hint_screen_texture`, всё, что нарисовано до него (в т.ч. `layer = -1`, как у JCM), снова прогоняется через палитру |
| Видимость слоя | Не рисуем, когда нет камеры/игрока; `gameData.menu`, `gameData.settings`, `gameData.isDead`, `gameData.isTransitioning`; и когда нечего рисовать — иначе дёргаем `_draw` 60 раз в секунду зря |
| Кого подписываем | Ровно тот набор, которому в этом кадре рисуется обводка — `_want` из `VTKESP._draw()` (`Distance` + `CAP` 24 + живые x-ray окна). Мёртвые и выбывшие — нет; иначе с сотней NPC на карте получится стена текста |
| Кто собирает | `VTKESP` читает узел (health/variant/state/reload/sensor/priority) и кладёт «факты» в массив; `VTKLabels.gd` (чистый) составляет строки; `VTKLabelLayer.gd` проецирует и рисует |
| Цвет текста | display-цвет категории (`color_normal`/`color_combat`/`color_defend` из MCM) — подпись совпадает с обводкой; рисуем после шейдера, цвет доходит как есть |
| Строки | первая: `Bandit  42 m`; вторая: `Hunting, reloading vs you`, `Hunting vs Bandit_5`, `Patrolling`. При живом окне триггера — суффикс `[fire 2.4s 50m]` как сейчас |
| Здоровье | тонкая полоска под первой строкой (фикс width, заливка `health/max`), зелёный→красный. Без цифр — полоска читается быстрее на бегу |
| Ромб номада | 2D-ромб над головой через `draw_colored_polygon`, цвет `Color(0.30, 1.0, 0.35)` — прежний display-цвет. LOS-рейкаст и правило «x-ray окно показывает сквозь стену» сохраняются 1:1 |
| Калибровка | Остаётся для обводок. `KEY_NOMAD`, `DET_NOMAD` и ветка детекции номада в шейдере удаляются как мёртвые: ромб больше не эмитит key |

## Что удаляется

- `mods/ThermalVTK/VTKNomadMarker.gdshader` — весь файл; ромб теперь 2D.
- `VTKESP.gd`: `_labels`, `_labels_sync`, `_label_make`, `_label_free`, `_labels_free_all`, `_label_text`, `_markers`, `_markers_sync`, `_marker_make`, `_marker_free`, `_marker_key`, `_cal_apply_marker_key`, `_anchor_above`.
- `VTKStates.gd`: `KEY_NOMAD`, `label_text`.
- `VTKNVG.gd`: `DET_NOMAD`, `set_nomad_color`, два `set_shader_parameter` в `_apply_uniforms`.
- `VTKNVG.gdshader`: `uniform nomadKey/nomadColor`, `dNom`, ветка замены, упоминания в комментариях.
- `VTKCalibration.gd`: только комментарий про кандидата #3 и sweep — список `CANDIDATES` не трогаем (зелёные кандидаты ещё пригодятся).

## Новое

### `mods/ThermalVTK/VTKLabels.gd` — чистый `RefCounted` (без сцены и `load()`)

- `static func name_of(variant_name: String, nickname: String) -> String` — никнейм, если не пустой, иначе `variant.name`.
- `static func header(name: String, dist: float) -> String` — `"Bandit  42 m"` (округление `int(round)`).
- `static func status(state: int, reloading: bool, vs: String) -> String`.
- `vs` вычисляется в `VTKESP` и приходит готовым: пусто для не-боевых стейтов; `"vs you"`, если `sensor.priority` в группе `Player`; `"vs Bandit_5"`, если у `owner` вариант и он не игрок (как `_state_text` в JCM).
- `static func trigger_suffix(win: Dictionary, now: float) -> String` — при живом окне: `"  [fire 2.4s 50m]"` (пусто иначе).
- `static func health_frac(health: float, max_health: float) -> float` — кламп 0..1; при `max <= 0` → 1.0.

Вторая строка собирается из `(state_name, ", reloading" при reload, " vs <who>" при vs)`.

### `mods/ThermalVTK/VTKLabelLayer.gd` — `extends Control`

- `set_frame(items: Array, diamonds: Array) -> void`, `clear() -> void`.
- `_draw()`: камера из viewport; для каждого item — unproject `anchor` (3D); тень через `draw_string_outline(font, origin, line, ..., 14, 4, Color(0,0,0,0.8))`, затем `draw_string(..., line, ...)` цветом категории (alpha пониженный на дальних: 1.0 → 0.7 к `Distance`); полоска здоровья. Ромбы — `draw_colored_polygon` в 4 вершинах, как в VTKNomadMarker.
- `_ready()`: full-rect anchors, `mouse_filter = MOUSE_FILTER_IGNORE`, `name = "VTKLabelLayer"`.

### `mods/ThermalVTK/VTKESP.gd`

- Убираются Label3D/marker-меш-пути.
- Создаём `_overlay_layer: CanvasLayer` (`layer = 1`) и `_overlay: Control` в `_ready()`; освобождаем в `_exit_tree()`.
- `p_nomad_marker: bool` из `apply_config`.
- `_overlay_sync(now)` вызывается в `_process` после `_draw()`:
  1. если `Dbg.enabled` — item на каждый id в `_want` (anchor 3D, header/status/trigger suffix, цвет display-категории, health frac, reload);
  2. diamonds: на каждую живую nomad-запись (не только `_want`) с LOS-проверками, если `p_nomad_marker`, плюс x-ray окно показывает сквозь;
  3. `_overlay.set_frame(items, diamonds)`, иначе `clear()`.
- `_head_world(node) -> Vector3` вместо `_anchor_above`: та же логика AABB `mesh.end.y + 0.1` в локали меша, фолбэк на `node.global_position + 1.9`.
- `set_calibration()` больше не касается ромбов (ромб теперь 2D и не эмитит key); только `_cal_apply` для обводок.

### `mods/ThermalVTK/VTKSettings.gd`

- В `DESCRIPTORS`: `{"sect": "Bool", "key": "nomad_marker", "name": "Friendly-nomad diamond", "def": true, "cat": "01. ThermalVision", "pos": 10, "tip": "Draw a small diamond over friendly nomads while thermal vision is on. Independent of the debug log."}`
- `Rec.nomad_marker: bool = true`, строка в `read()`.

### `ThermalVTK.gd`

- В `_mcm_apply`: `_esp.apply_config(rec)` уже есть — нужно только, чтобы `apply_config` читал ключ. Никаких иных изменений.

### Тесты и стенд

- Новый `.check/project/tests/test_labels.gd` — чистые функции `VTKLabels`.
- `test_esp.gd`: убрать `t_calibration_marker_key`, `t_nomad_marker_lifecycle`, `t_los_*` (привязанные к `MeshInstance3D` маркеру) → переписать под item-feed.
- `test_states.gd`: убрать проверки `label_text`; проверку `KEY_NOMAD` из `t_fill_and_nomad_keys`.
- `test_shaders.gd`: снять `t_nomad_detector_*`, аллокацию `VTKNomadMarker.gdshader`, проверку `nomad_key`.
- `test_settings.gd`: default `nomad_marker == true`, чтение из профиля.
- `check.ps1`: добавить `"res://tests/test_labels.gd"` в `$tests` (и uid-файл по образцу).

### `mod.txt`

- `version = "2.2.0"` (новая функциональность: 2D подписи, новый MCM-ключ — minor bump).

### `CHANGELOG.md`

```
## [2.2.0] - 2026-10-26

### Changed
- NPC nametags (shown together with the debug log) are now drawn as a 2D overlay, so they stay crisp and follow their own colour instead of being repainted by the thermal palette.
### Added
- An independent toggle for the friendly-nomad diamond (MCM, under the thermal vision section) — on by default.
```

## Инварианты, которые нельзя ломать

1. Слой на `layer = 1`, никогда `-1`: иначе палитра съест текст.
2. Ромб по-прежнему подчиняется LOS. Не срезать raycast, даже когда «вроде работает через стены» — это основа UX.
3. `_want` считается до построения подписей; подписи не расширяют набор обводок, не тянут CAP за собой и не добавляют ботов за пределами `Distance`.
4. Не создаём узлов под меш NPC. Вся 2D-геометрия живёт на одном Control → главный выигрыш по памяти/FPS.
5. Мёртвых не подписываем (`dead` → skip, как раньше).
6. `mods/ThermalVTK/version.txt` синкается `pack.ps1`; версию в gd не дублируем.

## Риски (только в игре, стенды не ловят)

1. **Порядок слоёв.** Если на какой-то сцене игровой NVG-оверлей на `CanvasLayer` > 1, текст уйдёт под него. Проверка: текст сохраняет цвет; если цвета исчезают — правим порядок, а не шейдер.
2. **PIP-прицел.** Подписи проецируются главной камерой, поэтому внутри увеличенной картинки линзы их не будет (отдельный рендер). Если захотим и там — отдельный проход через SubViewport.
3. **Высота якоря.** AABB скиннинг-меша в bind-позе может снести текст вверх/вниз — лечится константой в `_head_world`, проверяется на первом NPC в игре.
4. **Шрифт.** Размер/outline — константы; на 1080p может оказаться тонко. Корректируем в `_draw` при первом прогоне.
5. **Подпись читается сквозь стену.** Если текст попадёт на уже белый фон тепловизора, пониженная alpha на дальних поможет. Если плохо — dark backing (`draw_rect` за блоком) без изменения структуры.

## Вне рамок

- 2D-обводки/рамки (силуэт остаётся 3D) — согласовано.
- Стрелки к NPC за экраном, «упрощённый» режим, номера спавна — фичи JCM; у нас их и не было.
- Новые MCM-ключи под поля подписей — согласовано, их не делаем.
- Daylight-компенсация, иконка NVG, шейдеры палитры — не трогаем.

## Как проверяем (после реализации)

1. `.check\check.ps1` зелёный — в списке есть `test_labels.gd`; нет `SCRIPT ERROR`/`Parse Error`/`Invalid call`.
2. В игре: `debug_log` on → над NPC чистый по цвету текст и подпись в цвете категории, полоска здоровья; бот, охотящийся на игрока → `Hunting vs you`; релоад появляется и исчезает; `debug_log` off → подписи исчезли в тот же кадр; сняли NVG или выключили ESP → подписей нет.
3. Ромб: MCM `nomad_marker` on/off меняет его на ходу; стена скрывает; живой x-ray показывает сквозь.
4. В тепловизоре текст не перекрашивается палитрой и не мылится на дистанции.
5. Нагрузка: карта с десятками NPC и включённым debug — FPS не проседает (проверить узким местом), потому что нет per-NPC узлов/Label3D.