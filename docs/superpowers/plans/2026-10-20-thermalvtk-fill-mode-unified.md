# ThermalVTK Fill + Unified Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Свести ThermalVTK к одному режиму (CONTOUR): тело NPC заливается цветом стейта, F6 листает палитру мира, а режим FULL, бот-палитра и spotted-flash удаляются полностью.

**Architecture:** Контур уже рисуется `material_overlay`-цепочкой (`VTKOutline`): body (`VTKOutlineBody.gdshader`, render_priority 20) → ring (`VTKOutlineRing.gdshader`, 21). Body-шейдер перестаёт быть бот-палитрой и становится простым `fillColor`-заливщиком; `fillColor` берётся из того же стейт-цвета, что и обводка. Весь mode-B путь (покраска ботов `material_override`, бот-ключи в NVG-шейдере, marker, flash) удаляется вместе с `VTKBot.gdshader`.

**Tech Stack:** Godot 4.6.3, GDScript, Godot shading language (`.gdshader`), headless-тесты через `SceneTree`, MCM (`mod_configuration_menu`).

## Global Constraints

- Версия: **1.6.0** — в одном месте, `standalone mods/ThermalVTK/mod.txt` (`version="1.6.0"`); `version.txt` пишет `pack.ps1`, руками не трогать. Мажор 2.0.0 приберегаем под финал.
- Линейные окончания: `ThermalVTK.gd`, `mod.txt` — **CRLF**; все прочие `.gd`/`.gdshader`/тесты — **LF**. Отступы только табы.
- GDScript strict-typing: `:=` от Variant-выражения даёт `Parse Error: Cannot infer the type` — аннотировать явно (`var x: int = ...`).
- `Object.get()` принимает ровно один аргумент; `get(name, default)` на игровом ресурсе обрывает функцию («Invalid call»). Фолбэк — явной проверкой на `null`.
- `return` внутри `fragment()` шейдера запрещён — только `if`/`else`.
- Тесты регистрируются вручную: массив `$tests` в `.check/check.ps1:105`. Сейчас 22 файла; набор не меняется.
- Прогон: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`. Зелёный = нет `SCRIPT ERROR`/`Parse Error`/`Invalid call`/`Failed to load script`, есть `tests passed`, код 0. Строки `Unicode parsing error ... NUL` (cp1251) и `ObjectDB instances leaked` — не ошибки.
- Сборка: `powershell -ExecutionPolicy Bypass -File pack.ps1` из `standalone mods/ThermalVTK` → `ThermalVTK.vmz` → копия в `D:\SteamLibrary\steamapps\common\Road to Vostok\mods\`.
- Комментарии — английские, стиль существующего кода. Без новых строк локализации (HUD-тосты — англ. литералы).
- Коммиты в план не входят: по `AGENTS.md` коммит только по явному разрешению пользователя. Вместо `git commit` каждый таск заканчивается прогоном `check.ps1`.

---

## File Structure

| Файл | Роль после рефакторинга |
|---|---|
| `mods/ThermalVTK/ThermalVTK.gd` | Autoload-координатор: хоткеи (thermal toggle, palette cycle), MCM-регистрация/применение, конфиг-синк. Режим-машина удалена. |
| `mods/ThermalVTK/VTKStates.gd` | Чистая логика состоянии/категорий/ключей/цветов + `label_text`. Не меняется. |
| `mods/ThermalVTK/VTKTracker.gd` | Чистая математика (cooling, fade, cap). Не меняется. |
| `mods/ThermalVTK/VTKESP.gd` | Дискавери NPC, per-NPC opts, Label3D. Flash и TEMP-зонд удалены; заливка включена. |
| `mods/ThermalVTK/VTKOutline.gd` | Overlay-цепочка: body + ring. `fill_color` вместо flash. |
| `mods/ThermalVTK/VTKOutlineBody.gdshader` | Заливка тела одним `fillColor`, затухание по `cool`. Не бот-палитра. |
| `mods/ThermalVTK/VTKOutlineRing.gdshader` | Обводка (ключ стейта). Не меняется. |
| `mods/ThermalVTK/VTKShaders.gd` | Сборка body/ring вариантов (LOS/wall). Не меняется. |
| `mods/ThermalVTK/VTKNVG.gd` | NVG-оверлей + мины. Бот-путь, PRESETS, `set_bot_paint`, `set_debug_raw` — удалены. Добавлен `set_palette`. |
| `mods/ThermalVTK/VTKNVG.gdshader` | Миров ая палитра + детект ключей стейтов и мин. Бот/marker/debugRaw — удалены. |
| `mods/ThermalVTK/VTKBot.gdshader` | **Удаляется.** |
| `.check/project/tests/test_shaders.gd` | Проверки шейдеров; бот-упоминания удалены, orbit/scopes остаются. |
| `.check/project/tests/test_esp.gd` | Проверки opts; `fill_alpha` — теперь из `p_fill_alpha`. |
| `.check/project/tests/test_outline.gd` | Проверки overlay; добавляется проверка `fill_color`. |

---

### Task 1: Заливка тела цветом стейта (body shader + outline)

**Files:**
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKOutlineBody.gdshader`
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKOutline.gd:97-135`
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKESP.gd:26-37,338-371`
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/ThermalVTK.gd:420-423`
- Test: `.check/project/tests/test_outline.gd`, `.check/project/tests/test_esp.gd`

**Interfaces:**
- Produces: `VTKOutlineBody.gdshader` uniform `vec3 fillColor` (вместо `warmColor/midColor/coldColor/flash_color/flash`); `VTKOutline.refresh` читает `opts["fill_color"]` (`Color`) и `opts["fill_opacity"]` (`float`), пишет `fill_alpha = fill_opacity * alpha`.
- Produces: `VTKESP.p_fill_alpha: float` (дефолт `0.4`); `_opts_for` кладёт `"fill_color"` (стейт-цвет) и `"fill_opacity"` (`0.0` если `p_fill == false`).
- Consumes: `States.DEFAULT_*`/`p_colors`/`p_nomad`.

State-цвет для заливки = тот же, что идёт обводке. Функция-хелпер в `VTKESP`:

```gdscript
func _state_color(cat: int, nomad: bool) -> Color:
	if nomad:
		return p_nomad
	var key: String = States.category_key(cat)
	return p_colors.get(key, States.default_color(cat))
```

- [ ] **Step 1: Переписать body-шейдер**

Заменить `VTKOutlineBody.gdshader` целиком:

```glsl
shader_type spatial;
render_mode unshaded, cull_back, depth_test_disabled, depth_draw_never;

// Body fill for the contour ESP. A DISPLAY shader: it paints the NPC's state
// colour (a flat tint set per NPC from VTKESP._opts_for) onto material_overlay.
// `cool` fades a corpse out -- albedo dims and alpha drops to zero as the body
// cools, so outline and fill disappear together. `bodyHeight` keeps the fade
// independent of the mesh's own vertical scale. The `depth_test_disabled`
// token is stripped at load to build the LOS variant (VTKShaders.gd).
uniform vec3 fillColor : source_color = vec3(1.0, 0.72, 0.28);
uniform float fill_alpha : hint_range(0.0, 1.0, 0.01) = 0.4;
uniform float cool : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float footY = 0.0;
uniform float bodyHeight = 1.8;

void fragment() {
	ALBEDO = fillColor * mix(1.0, 0.15, cool);
	ALPHA = fill_alpha * (1.0 - cool);
}
```

> Плоский fade: альбедо тускнеет, alpha линейно падает по `cool` до нуля, так что заливка и обводка гаснут вместе. `footY`/`bodyHeight` остаются в uniform-списке как есть, хотя `fragment()` их больше не читает: `VTKOutline.refresh` всё равно их шлёт, и удалять их из `refresh` в этом таске не нужно (лишний uniform — не ошибка).

- [ ] **Step 2: Обновить `VTKOutline.refresh`**

В `VTKOutline.gd` в `refresh` (строки 105-135) удалить `flash`/`flash_color`-блок и добавить `fill_color`:

```gdscript
	var key: Color = opts.get("state_key", States.KEY_NORMAL)
	var alpha := float(opts.get("alpha", 1.0))
	var grow := float(opts.get("grow", 0.006))
	var foot_y := float(opts.get("foot_y", 0.0))
	var body_h := float(opts.get("body_height", 1.8))
	var cool := float(opts.get("cool", 0.0))
	var fill_alpha := float(opts.get("fill_alpha", 0.0))
	var fill_col: Color = opts.get("fill_color", Color(1.0, 0.72, 0.28))
```

Далее: body-параметры — `fill_alpha * alpha`, `cool`, `footY`, `bodyHeight`, `fillColor`; блок с `flash`/`flash_color` (строки 131-135) удалить целиком.

```gdscript
	if body_mat.get_shader_parameter("fill_alpha") == null or not is_equal_approx(float(body_mat.get_shader_parameter("fill_alpha")), fill_alpha * alpha):
		body_mat.set_shader_parameter("fill_alpha", fill_alpha * alpha)
	if body_mat.get_shader_parameter("cool") == null or not is_equal_approx(float(body_mat.get_shader_parameter("cool")), cool):
		body_mat.set_shader_parameter("cool", cool)
	if body_mat.get_shader_parameter("footY") == null or not is_equal_approx(float(body_mat.get_shader_parameter("footY")), foot_y):
		body_mat.set_shader_parameter("footY", foot_y)
	if body_mat.get_shader_parameter("bodyHeight") == null or not is_equal_approx(float(body_mat.get_shader_parameter("bodyHeight")), body_h):
		body_mat.set_shader_parameter("bodyHeight", body_h)
	if body_mat.get_shader_parameter("fillColor") != fill_col:
		body_mat.set_shader_parameter("fillColor", fill_col)
```

- [ ] **Step 3: Написать падающий тест на `fill_color`**

В `.check/project/tests/test_outline.gd` заменить тело `t_refresh_sets_state_key`:

```gdscript
func t_refresh_sets_state_key() -> void:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	var o = Outline.new()
	o.apply(7, root, {"state_key": Color(0, 1, 0), "grow": 0.01, "fill_alpha": 0.4, "fill_color": Color(1, 0, 0)})
	var ring: ShaderMaterial = o.material_of(7)["ring"]
	var body: ShaderMaterial = o.material_of(7)["body"]
	ck(ring.get_shader_parameter("state_key") == Color(0, 1, 0), "ring state_key set")
	ck(is_equal_approx(float(ring.get_shader_parameter("grow")), 0.01), "ring grow set")
	ck(is_equal_approx(float(body.get_shader_parameter("fill_alpha")), 0.4), "body fill_alpha from opts")
	var fc: Variant = body.get_shader_parameter("fillColor")
	ck(fc is Color and (fc as Color).is_equal_approx(Color(1, 0, 0)), "body fillColor from opts")
	root.free()
```

- [ ] **Step 4: Прогнать тест — должен упасть**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `test_outline.gd` VERDICT FAIL с `FAIL body fillColor from opts` (шейдер ещё не имеет `fillColor`).

- [ ] **Step 5: Реализовать `p_fill_alpha` и `_opts_for`**

В `VTKESP.gd`: добавить поле после `p_fill` (строка 18):

```gdscript
var p_fill_alpha := 0.4
```

Удалить `p_flash` (строка 22) и `p_flash_color` (строка 23).

Переписать хвост `_opts_for` (строки 338-364): убрать `flash`/`flash_color`, добавить `fill_color`/`fill_opacity`:

```gdscript
func _opts_for(e: Dictionary, node: Node, dist: float, now: float) -> Dictionary:
	var cool := Tracker.cool_factor(e, now, p_decay)
	var alpha := Tracker.distance_alpha(dist, p_dist)
	var nomad := bool(e.get("nomad", false))
	var cat: int = int(e.get("cat", States.NORMAL))
	var key: Color = States.KEY_NOMAD if nomad else States.state_key(cat)
	var foot_y: float = (node as Node3D).global_position.y
	return {
		"cat": cat,
		"nomad": nomad,
		"state_key": key,
		"alpha": alpha,
		"cool": cool,
		"through_walls": p_through > 0.0 and dist <= p_through,
		"foot_y": foot_y,
		"body_height": 1.8,
		"brightness": p_brightness,
		"grow": p_thickness,
		"fill_alpha": p_fill_alpha if p_fill else 0.0,
		"fill_color": _state_color(cat, nomad),
	}
```

Удалить `_player_visible` (строки 366-371).

- [ ] **Step 6: Проводка MCM в `ThermalVTK.gd`**

В `_mcm_apply` (строки 420-423) заменить flash-строки на fill-opacity:

```gdscript
		_esp.p_fill = bool(_mcm_key_val(cfg, "Bool", "outline_body_fill", true))
		_esp.p_fill_alpha = float(_mcm_key_val(cfg, "Float", "fill_opacity", 0.4))
		_esp.p_brightness = float(_mcm_key_val(cfg, "Float", "outline_brightness", 0.6))
```

Удалить строки `_esp.p_flash = ...` и `_esp.p_flash_color = ...`.

В `_register_mcm` (секция `CAT2`, строки 289-294): заменить tooltip `outline_body_fill` и добавить `fill_opacity`; удалить `outline_pvisible`/`pvisible_color`:

```gdscript
	cfg.set_value("Bool", "outline_body_fill", {"name": "Body fill", "default": true, "value": true, "category": CAT2, "menu_pos": 1, "tooltip": "Fill the NPC body with its state colour inside the outline."})
	cfg.set_value("Float", "fill_opacity", {"name": "Fill opacity", "default": 0.4, "value": 0.4, "minRange": 0.0, "maxRange": 1.0, "step": 0.05, "category": CAT2, "menu_pos": 2, "tooltip": "How solid the body fill is. 0 = outline only."})
	cfg.set_value("Float", "corpse_decay", {"name": "Corpse cooling time", "default": 8.0, "value": 8.0, "minRange": 0.0, "maxRange": 30.0, "step": 1.0, "category": CAT2, "menu_pos": 3, "tooltip": "Seconds a dead NPC's outline takes to cool from warm to cold."})
	cfg.set_value("Float", "outline_thickness", {"name": "Outline thickness", "default": 0.006, "value": 0.006, "minRange": 0.0, "maxRange": 0.05, "step": 0.001, "category": CAT2, "menu_pos": 4, "tooltip": "How far the outline band grows beyond the body."})
	cfg.set_value("Float", "outline_brightness", {"name": "Outline brightness", "default": 0.6, "value": 0.6, "minRange": 0.1, "maxRange": 3.0, "step": 0.1, "category": CAT2, "menu_pos": 5, "tooltip": "Brightness multiplier on the outline colour."})
```

(`menu_pos` сдвигаются, чтобы не было дыр.)

- [ ] **Step 7: Обновить `test_esp.gd`**

В `t_opts_state_key` (строки 62-73) заменить проверку fill-alpha:

```gdscript
func t_opts_state_key() -> void:
	var esp = ESP.new()
	esp.name = "VTKESP_opts"
	root.add_child(esp)
	var node := Node3D.new()
	root.add_child(node)
	var hostile := esp._opts_for({"cat": S.COMBAT, "nomad": false}, node, 10.0, 0.0)
	ck(hostile["state_key"] == S.KEY_COMBAT, "hostile combat keys combat")
	ck(is_equal_approx(float(hostile["fill_alpha"]), 0.4), "fill_alpha defaults to 0.4")
	ck((hostile["fill_color"] as Color).is_equal_approx(esp.p_colors["state_combat"]), "fill_color matches state colour")
	esp.p_fill = false
	var off := esp._opts_for({"cat": S.COMBAT, "nomad": false}, node, 10.0, 0.0)
	ck(is_equal_approx(float(off["fill_alpha"]), 0.0), "body fill off drops fill_alpha to 0")
	var nomad := esp._opts_for({"cat": S.NORMAL, "nomad": true}, node, 10.0, 0.0)
	ck(nomad["state_key"] == S.KEY_NOMAD, "nomad keys nomad")
	ck((nomad["fill_color"] as Color).is_equal_approx(esp.p_nomad), "nomad fill_color is the nomad colour")
	esp.free()
	node.free()
```

- [ ] **Step 8: Прогнать тесты — зелёный**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `Tests passed: 22 file(s)`, `Parse check passed: 26 scripts`.

---

### Task 2: F6 → цикл палитры мира; удаление режима FULL

**Files:**
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/ThermalVTK.gd:12-29,49-104,277,282-285,407-410,432-442`
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKNVG.gd:96-141,740-753`
- Test: `.check/project/tests/` — тестов нет (координатор + UI), проверка ручная.

**Interfaces:**
- Consumes: `VTKNVG.set_palette: int` (поле, уже есть) — новый публичный сеттер `set_palette_mode(mode: int)`.
- Produces: `ThermalVTK._cycle_palette()`; state-ключ `world_palette` (int 0..3) в `thermal_state.cfg`; MCM `Keycode key_palette_cycle` (дефолт `KEY_F6`).
- Removes: `_mode_full_thermal`, `KEY_MODE`, `_toggle_mode`, `full_thermal_mode` в state-файле, `VTKNVG.set_bot_paint`/`bot_paint`/`_bots_painted`/`_clear_bot_paint`, `VTKNVG.set_debug_raw`/`_debug_raw`, MCM `thermal_bot_preset`/`thermal_far_distance`, `VTKNVG.set_bot_preset`/`set_far_distance`.

- [ ] **Step 1: Добавить `set_palette_mode` в `VTKNVG.gd`**

После `set_state_colors` (строка 751) добавить:

```gdscript
func set_palette_mode(mode: int) -> void:
	set_palette = mode
	_apply_uniforms()
	_tick_cd = 0.0
```

- [ ] **Step 2: Хоткеи и state в `ThermalVTK.gd`**

Удалить `const KEY_MODE := KEY_F6` (строка 12) и весь TEMP-зонд (строки 13-15, 112-241: `KEY_PROBE`, `CAL_KEYS`, `_probe_busy`, `_run_ring_probe`, `_probe_diff`, а также вызов в `_unhandled_input` строки 57-60). Добавить:

```gdscript
const PALETTE_COUNT := 4
```

Поле `_key_palette_cycle` рядом с `_key_thermal_toggle` (строка 19):

```gdscript
var _key_palette_cycle: int = KEY_F6
```

Удалить поле `_mode_full_thermal` (строка 23). Убрать чтение `full_thermal_mode` в `_ready` (строки 28-29).

Переписать `_unhandled_input` (строки 49-65):

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k := event as InputEventKey
	if _key_palette_cycle != 0 and (k.keycode == _key_palette_cycle or k.physical_keycode == _key_palette_cycle):
		_cycle_palette()
		get_viewport().set_input_as_handled()
		return
	if _key_thermal_toggle == 0:
		return
	if k.keycode == _key_thermal_toggle or k.physical_keycode == _key_thermal_toggle:
		_toggle_thermal()
		get_viewport().set_input_as_handled()
```

Заменить `_toggle_mode` (строки 76-81) на:

```gdscript
const PALETTE_NAMES: Array[String] = ["Classic", "Amber", "Forest", "Ice"]

func _cycle_palette() -> void:
	if _nvg == null or not is_instance_valid(_nvg):
		return
	var mode: int = (int(_nvg.set_palette) + 1) % PALETTE_COUNT
	_nvg.set_palette_mode(mode)
	_notify("World palette: " + PALETTE_NAMES[mode], Color(0.6, 0.8, 1.0))
	_save_state("world_palette", mode)
```

Переписать `_apply_mode` (строки 83-89) без ветки FULL:

```gdscript
func _apply_mode() -> void:
	if _esp != null and is_instance_valid(_esp):
		_esp.set_enabled(_thermal_enabled and _outline_enabled and _nvg_active())
```

- [ ] **Step 3: Старт-палитра и MCM-регистрация**

В `_ready` (строка 27) читать сохранённую палитру и применять её при загрузке конфига. Добавить поле:

```gdscript
var _saved_palette: int = -1
```

`_ready`:

```gdscript
func _ready() -> void:
	var saved_pal = _read_state("world_palette", null)
	_saved_palette = int(saved_pal) if saved_pal != null else -1
	_register_mcm()
```

В `_mcm_apply` заменить (строка 407-410):

```gdscript
	if _saved_palette >= 0:
		_nvg.set_palette = _saved_palette
	else:
		_nvg.set_palette = _palette_mode_from_cfg(cfg)
	_nvg.set_world = float(_mcm_key_val(cfg, "Float", "thermal_world", 1.70))
```

Удалить строки `_nvg.set_bot_preset = ...` и `_nvg.set_far_distance = ...` (409-410).

В `_register_mcm` (секция CAT): добавить `key_palette_cycle` после `key_thermal_toggle`; удалить `thermal_bot_preset`/`thermal_far_distance` (строки 284-285):

```gdscript
	cfg.set_value("Keycode", "key_palette_cycle", {"name": "Hotkey: Cycle world palette", "default": KEY_F6, "default_type": "Keycode", "value": KEY_F6, "category": CAT, "menu_pos": 1, "tooltip": "Press in game to cycle the world thermal palette."})
```

Сдвинуть `menu_pos` последующих ключей CAT на −1 (nvg_noise 1→2, ... thermal_world 10→9).

В `_mcm_apply` прочитать хоткей (рядом со строкой 392):

```gdscript
	_key_palette_cycle = int(_mcm_key_val(cfg, "Keycode", "key_palette_cycle", KEY_F6))
```

- [ ] **Step 4: Удалить bot-paint из `VTKNVG.gd`**

В `VTKNVG.gd` удалить: `set_bot_paint` (629-639), `bot_paint` (113), `_bots_painted` (114), `_clear_bot_paint` (617-626), `set_debug_raw`/`_debug_raw` (137-149), константы `BOT_WARM_KEY`/`BOT_MID_KEY`/`BOT_COLD_KEY`/`BOT_PRESETS`/`BOT_PRESET_NAMES`/`DET_WARM`/`DET_MID`/`DET_COLD`, `set_bot_preset`/`set_far_distance` поля (102,107), `BOT_SHADER_RES` (32) и загрузку `_bot_shader` (165-166), поля `_bot_shader` (125).

В `_apply_uniforms` — удалить блок `warmKey/midKey/coldKey` (328-330) и хвост с `BOT_PRESETS` (345-348), а также `debugRaw` (343).

В `_process` (404-424) — заменить блок `if on:`/`elif`:

```gdscript
	if on:
		_paint_on = false
		for id in _mines.keys():
			_update_mine(id, true, ppos)
	elif _was_on or _paint_on:
		_clear_paint()
		_paint_on = false
	_was_on = on
```

- [ ] **Step 5: Прогнать тесты**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: зелёный, `Parse check passed: 26 scripts`.

---

### Task 3: Выпил mode-B из `VTKNVG.gd` (боты, marker, `_collect_meshes`-бот-путь)

**Files:**
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKNVG.gd:29-49,113-127,186-268,444-568,569-668,715-721`
- Delete: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKBot.gdshader`

**Interfaces:**
- Removes: `_bots`, `_register_bot`, `_sweep_bot_meshes`, `_is_friendly`, `_update_bot`, `_off_frame_upkeep`-бот-часть, `_clear_paint`-бот-часть, `_frame_pre_draw`-бот-часть, `_is_bot` (только NVG-копия), `_bot_shader`, `_bots_painted`. `_mines`/`_register_mine`/`_update_mine`/`_retry_mines`/`_collect_meshes`/`_key_material`/`_key_set` — остаются.

- [ ] **Step 1: Убрать бот-дискавери**

В `_scan_node` (196-207) и `_deferred_check` (244-261) удалить ветки `elif _is_bot(n): _register_bot(n)`. Удалить `_is_bot` (267-268), `_register_bot` (444-467), `_sweep_bot_meshes` (475-482), `_is_friendly` (485-493), `_update_bot` (496-567).

- [ ] **Step 2: Упростить upkeep/paint**

`_off_frame_upkeep` (574-593) — оставить только блок по `_mines`:

```gdscript
func _off_frame_upkeep() -> void:
	for id in _mines.keys():
		var e = _mines.get(id)
		if e == null or not is_instance_valid(e.get("node")):
			_mines.erase(id)
```

`_clear_paint` (598-614) — только мины:

```gdscript
func _clear_paint() -> void:
	for id in _mines.keys():
		var e = _mines.get(id)
		if e == null:
			continue
		for m in e.get("meshes", []):
			if is_instance_valid(m):
				(m as GeometryInstance3D).material_override = null
```

`_frame_pre_draw` (646-668) — удалить целиком; отключить подключение `RenderingServer.frame_pre_draw.connect(_frame_pre_draw)` (179).

Поле `_paint_on` (134) — оставить: `_clear_paint` всё ещё нужен для мин при on→off.

- [ ] **Step 3: Обновить шапку-комментарий**

Переписать блок комментариев 4-27 и 34-49: убрать описание бот-ключей, VTKBot, DET_WARM/MID/COLD. Оставить архитектуру: оверлей заменяет ванильный шейдер; мины несут ключ; детект событийный.

- [ ] **Step 4: Удалить `VTKBot.gdshader`**

Удалить файл `standalone mods/ThermalVTK/mods/ThermalVTK/VTKBot.gdshader`.

- [ ] **Step 5: Прогнать тесты**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: зелёный.

---

### Task 4: Выпил бот/marker/debugRaw из `VTKNVG.gdshader`

**Files:**
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKNVG.gdshader:24-73,138-226`

**Interfaces:**
- Removes: uniforms `debugRaw`, `markNomads`, `markerKey`, `markerColor`, `warmKey`/`midKey`/`coldKey`, `warmColor`/`midColor`/`coldColor`. `mineKey`/`mineColor`/`st*Key`/`st*Color`/`scopeRotate`/`orbitDist` — остаются.

- [ ] **Step 1: Удалить бот-uniforms и ветки**

Удалить uniform-блоки (строка 25-28 `debugRaw`; 32 `markNomads`; 38-53 marker + bot-keys/colors). Удалить `dWarm`/`dMid`/`dCold` (152-154), `dMark` (156), marker-gate (164-166), bot-ветку `else` (191-200), а `minD` — пересобрать:

```glsl
		float dMine = orbitDist(pixelColor.rgb, mineKey);
		float dStN = orbitDist(pixelColor.rgb, stNormalKey);
		float dStA = orbitDist(pixelColor.rgb, stAlertedKey);
		float dStH = orbitDist(pixelColor.rgb, stHuntingKey);
		float dStC = orbitDist(pixelColor.rgb, stCombatKey);
		float dStNomad = orbitDist(pixelColor.rgb, stNomadKey);
		float minD = min(dMine, min(min(dStN, dStA), min(min(dStH, dStC), dStNomad)));
```

Убрать `if (minD == dMark)` и bot-`else` из цепочки `subColor`. Удалить `debugRaw`-ветку хвоста (219-225), оставив:

```glsl
	COLOR = mix(vec4(0.0, 0.0, 0.0, 1.0), color, goggleMask);
```

- [ ] **Step 2: Обновить шапку**

Переписать шапку 3-13: убрать marker/bot, оставить «мины + контурные ключи стейтов».

- [ ] **Step 3: Прогнать тесты**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: зелёный. `t_state_keys_in_overlay` уже проверяет `st*`/`orbitDist`; если он ссылается на удалённые имена — поправить в Task 5.

---

### Task 5: Зачистка тестов

**Files:**
- Modify: `.check/project/tests/test_shaders.gd:64-78`

**Interfaces:**
- Consumes: `VTKNVG.gdshader` без бот/marker.

- [ ] **Step 1: Обновить `t_state_keys_in_overlay`**

Убедиться, что проверяет только живые uniform'ы (`st*Key`, `st*Color`, `dStN`, `dStNomad`, `scopeRotate`, `orbitDist`, `k.brg`/`k.gbr`, `not k.grb`). Строки про bot/marker (если введены в Task 4) удалить.

- [ ] **Step 2: Прогнать тесты**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `Tests passed: 22 file(s)`.

---

### Task 6: Версия, CHANGELOG, сборка, установка

**Files:**
- Modify: `standalone mods/ThermalVTK/mod.txt:3`
- Modify: `standalone mods/ThermalVTK/CHANGELOG.md`

**Interfaces:**
- Выход: `ThermalVTK.vmz` без `VTKBot.gdshader`; `mod.txt` `version="1.6.0"`.

- [ ] **Step 1: Поднять версию**

`mod.txt`: `version="1.6.0"` (файл CRLF — править, сохраняя CRLF).

- [ ] **Step 2: CHANGELOG**

Добавить в начало `CHANGELOG.md`:

```markdown
## [1.6.0] - 2026-10-20

### Added
- A Fill opacity slider for the NPC body fill; the body now fills with the NPC's state colour.

### Changed
- F6 now cycles the world thermal palette instead of switching thermal modes.

### Removed
- The separate FULL thermal mode; contour is now the only mode.
- The Bot colour, Distance and Spotted flash settings.
```

- [ ] **Step 3: Прогнать стенды**

Run: `py -3 .check\layout_check.py` (если применимо к ThermalVTK) и `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: зелёный.

- [ ] **Step 4: Собрать**

Run: `powershell -ExecutionPolicy Bypass -File pack.ps1` (workdir `standalone mods/ThermalVTK`)
Expected: печатает `Version in mod.txt: 1.6.0`; `ThermalVTK.vmz` без `VTKBot.gdshader`.

- [ ] **Step 5: Установить**

Скопировать `ThermalVTK.vmz` в `D:\SteamLibrary\steamapps\common\Road to Vostok\mods\`.

- [ ] **Step 6: Ручная проверка в игре**

Чек-лист из спеки: заливка цветом стейта; `Fill opacity` меняет плотность; `Body fill` off → только обводка; трупы тускнеют; F6 листает палитру и совпадает с MCM; FULL нет; `config.ini` без `thermal_bot_preset`/`thermal_far_distance`/`outline_pvisible`/`pvisible_color`.

---

## Self-Review

**Spec coverage:** палитра F6 (Task 2), заливка цветом стейта (Task 1), трупы (Task 1 shader `cool`), резка mode-B кода (Tasks 2-4), MCM резка (Tasks 1,2), тесты (Tasks 1,5), версия/CHANGELOG/сборка (Task 6). Пробелов нет.

**Placeholder scan:** все шаги с кодом; ручных «сделать похоже» нет. Единственное место с выбором — Step 1 Task 1 (вариант alpha); решение зафиксировано (плоский fade).

**Type consistency:** `set_palette_mode` (Task 2) vs `set_palette`-поле — согласовано; `p_fill_alpha` (Task 1 Step 5) совпадает с `_mcm_apply` (Task 1 Step 6); `fill_color`/`fill_opacity` в `_opts_for` (Task 1) совпадают с `refresh` (Task 1 Step 2).
