# ThermalVTK 1.5.0 — орбитный детект в PIP-off прицеле + подписи состояния + выпил авто-PIP

## Context

Две утверждённые спеки:

- `docs/superpowers/specs/2026-10-20-thermalvtk-pipoff-orbit-detect-design.md` — обводка
  Contour исчезает/рвётся сквозь увеличенную оптику при `PIP off`; фикс — орбитный
  детект ключа (`{rgb, brg, gbr}`), гейт `isScoped && !PIP`, и полный выпил
  отклонённого авто-PIP.
- `docs/superpowers/specs/2026-10-20-thermalvtk-debug-state-labels-design.md` —
  в режиме `debug_log` над NPC печатать `AI.State` и получившуюся категорию, чтобы
  проверять словарик `VTKStates.gd` в бою.

Обе фичи идут одним релизом **1.5.0** (авто-PIP игрокам не выпускался). Правила
версий, сборки и проверки — `AGENTS.md`.

**Никаких git-коммитов.** Общение с пользователем — по-русски; код и лог — английский.

## Порядок

Каждая задача — атомарный шаг: правка → `check.ps1` зелёный → следующий. Порядок
выбран так, чтобы выпил авто-PIP шёл **первым** — он удаляет мёртвый код до правок
в тех же файлах (`VTKESP.gd`).

---

### Task 1 — Выпил авто-PIP

**Файлы:** `VTKAutoPip.gd` (удалить), `VTKESP.gd`, `ThermalVTK.gd`, `check.ps1`,
`test_autopip.gd` (удалить).

Шаги:

1. Удалить `mods/ThermalVTK/VTKAutoPip.gd` и
   `.check/project/tests/test_autopip.gd`.
2. `.check/check.ps1` — убрать `"res://tests/test_autopip.gd"` из `$tests`
   (`:105-106`).
3. `VTKESP.gd`:
   - убрать `const AutoPip = preload("res://mods/ThermalVTK/VTKAutoPip.gd")` (`:11`);
   - убрать `var p_auto_pip := true` (`:28`) и `var _autopip = null` (`:47`);
   - `_ready()` (`:56`): убрать `var game_data` / `ResourceLoader.exists` /
     `load(Paths.GAME_DATA)` / `AutoPip.new(...)` (`:58-61`) — блок был нужен только
     авто-PIP;
   - `set_enabled(false)` (`:71`): убрать `if _autopip != null: _autopip.release()`
     (`:74-75`);
   - `_process()` (`:195`): убрать `if _autopip != null: _autopip.sync(...)`
     (`:199-200`);
   - `_exit_tree()` (`:177`): убрать `if _autopip != null: _autopip.release()`
     (`:178-179`).
4. `ThermalVTK.gd` (CRLF):
   - убрать `cfg.set_value("Bool", "auto_pip_scope", {...})` (`:295`);
   - убрать `_esp.p_auto_pip = bool(...)` (`:424`).
5. Проверить, что `Paths.GAME_DATA` больше не используется в `VTKESP.gd`
   (в `VTKNVG.gd` он остаётся для `_game_data`, нужного орбите).

**Проверка:** `check.ps1` → зелёный, `test_autopip` пропал из прогона, число
тестов стало 22.

---

### Task 2 — `orbitDist` в шейдере оверлея

**Файл:** `mods/ThermalVTK/VTKNVG.gdshader` (LF).

Шаги:

1. После `debugRaw` (`:28`) добавить `uniform bool scopeRotate = false;`.
2. Перед `void fragment()` (после `ThermalPalette`, `:121`) добавить хелпер —
   **точные свиззлы `brg`/`gbr`, не `grb`** (см. спеку; `grb` = отражение и
   промахивается до 1.106):

```glsl
// PIP off + magnifying scope: the lens path rotates colour channels on screen,
// so a key shows up as its three cyclic rotations. Match the orbit when that can
// happen, plain distance otherwise (zero change off-scope / PIP on).
float orbitDist(vec3 c, vec3 k)
{
	if (!scopeRotate) {
		return distance(c, k);
	}
	float d = distance(c, k);
	d = min(d, distance(c, k.brg));
	d = min(d, distance(c, k.gbr));
	return d;
}
```

3. В ветке `thermalMode` (`:137-146`) заменить источник у всех десяти дистанций:
   `distance(pixelColor.rgb, X)` → `orbitDist(pixelColor.rgb, X)` для `warmKey`,
   `midKey`, `coldKey`, `mineKey`, `markerKey`, `stNormalKey`, `stAlertedKey`,
   `stHuntingKey`, `stCombatKey`, `stNomadKey`. Имена `dWarm`…`dStNomad`, `minD`,
   `minD == dX` и `minD < 0.22` — **не менять**.
4. Гвард маркера (`:149-151`) оставить: он уже читает орбитную `dMark`.
5. `else`-ветка (`:197`): `distance(pixelColor.rgb, mineKey) < 0.15` →
   `orbitDist(pixelColor.rgb, mineKey) < 0.15`.

**Проверка:** `check.ps1` → `t_nvg_contour_reads_mines` и
`t_state_keys_in_overlay` по-прежнему зелёные (проверка шейдеров через `.code`).

---

### Task 3 — Гейт `scopeRotate` в `VTKNVG.gd`

**Файл:** `mods/ThermalVTK/VTKNVG.gd` (LF).

Шаги:

1. Рядом с `_debug_raw` (`:138`) добавить:
   `var _scope_rotate: bool = false` (кэш последнего выставленного значения, чтобы
   не дёргать `set_shader_parameter` каждый кадр).
2. В кэш кадра: `_process()` (`:359`) читать флаг один раз и, **только при изменении**,
   пушить uniform. Источник — уже загруженный `_game_data`; читать одной ногой
   (`Object.get()` принимает ровно один аргумент):

```gdscript
var want := false
if _game_data != null and _game_data.has_method("get"):
	want = bool(_game_data.get("isScoped"))
	if want:
		var pip = _game_data.get("PIP")
		if pip == null or bool(pip):
			want = false
if want != _scope_rotate:
	_scope_rotate = want
	if _installed and _nvg_mat_node != null and is_instance_valid(_nvg_mat_node):
		var m = _nvg_mat_node.get("material")
		if m is ShaderMaterial:
			(m as ShaderMaterial).set_shader_parameter("scopeRotate", _scope_rotate)
```

   `get("isScoped")`/`get("PIP")` — **один** аргумент (`Object.get` иначе «Invalid
   call» и обрыв функции); это совпадает со стилем `_nvg_active()` (`:348-350`).

   (Первоисточник — `GameData.tres`, кэш `_game_data` в `VTKNVG.gd:151-152`.)
3. `_apply_uniforms()` (`:307`) — рядом с `debugRaw` (`:340`) добавить
   `nvg_mat.set_shader_parameter("scopeRotate", _scope_rotate)`, чтобы после
   переустановки материала униформ не остался на дефолте `false`, пока
   `_process` не поймает изменение.

**Проверка:** `check.ps1` зелёный. В игре (PIP off, прицел) — `scopeRotate`
переключается; вне прицела и в PIP on — uniform остаётся `false`.

---

### Task 4 — Подписи состояния: чистая логика

**Файл:** `mods/ThermalVTK/VTKStates.gd` (LF).

Шаги:

1. Добавить имена стейтов в порядке `AI.gd:95` (0..16):
   `Idle, Wander, Loot, Guard, Patrol, Cover, Hide, Ambush, Combat, Hunt, Defend,
   Attack, Vantage, Grenade, Lurk, Switch, Group`.
2. Добавить `static func state_name(state)` — фолбэк `"State" + str(state)`.
3. Добавить `static func category_name(cat)` — `NORMAL/ALERTED/HUNTING/COMBAT`.
4. Добавить `static func label_text(state, nomad)` —
   `"%s\n%s" % [state_name(state), "NOMAD" if nomad else category_name(category_of(state))]`.

**Проверка:** `check.ps1` зелёный (парсинг `VTKStates.gd`).

---

### Task 5 — Подписи: `Label3D` над NPC

**Файл:** `mods/ThermalVTK/VTKESP.gd` (LF).

Шаги:

1. Состояние: `var _labels: Dictionary = {}` (`id -> Label3D`) и
   `var _labels_state: Dictionary = {}` (`id -> int`).
2. `_label_make(entry, node)` — создать `Label3D`:
   - родитель — `node.mesh` (`AI.gd:25` `@export var mesh: MeshInstance3D`), иначе
     сам `node`;
   - позиция `Vector3(0, mesh.get_aabb().end.y + 0.1, 0)` (фолбэк `Y = 1.9`);
   - `billboard = BaseMaterial3D.BILLBOARD_ENABLED`, `no_depth_test = true`,
     `render_priority = 40`, `outline_size` умеренный, `font_size ~ 32`;
   - `text = States.label_text(_read_state(node), nomad)` где `nomad` —
     `bool(entry.get("nomad", false))`.
3. `_labels_sync()` — один проход по `_entries`:
   - `not VTKDebug.enabled` → снести все метки, выйти (гейт `debug_log`);
   - нет метки / узел недействителен → создать; метка есть, а записи нет → снести;
   - `_read_state(node) != _labels_state[id]` → переписать `text` (только при смене).
4. Точки вызова:
   - `_process()` — сразу после `_weapon.tick()` (`:198`), **до** ранних `return`;
   - `set_enabled(false)` — рядом с `_outline.clear_all()` (`:72`);
   - `_on_ai_deactivate()` — после `_entries.erase(...)` (`:154`);
   - `_exit_tree()` — снести оставшиеся.
5. `VTKDebug.gd` **не трогаем** — читаем публичный `static var enabled` (`:8`).

**Проверка:** `check.ps1` зелёный. В игре: `Debug log` on → над NPC две строки;
off → исчезают мгновенно.

---

### Task 6 — Тесты

**Файлы:** `.check/project/tests/test_states.gd`, `test_shaders.gd` (LF).

Шаги:

1. `test_states.gd` — новая `t_labels()` (вызвать из `_run()`):
   `state_name(0)=="Idle"`, `state_name(4)=="Patrol"`, `state_name(16)=="Group"`,
   `state_name(99)` не пуст, `category_name(2)=="HUNTING"`,
   `category_name(99)=="NORMAL"`, `label_text(9,false)=="Hunt\nHUNTING"`,
   `label_text(5,false)=="Cover\nALERTED"`, `label_text(5,true)=="Cover\nNOMAD"`.
2. `test_shaders.gd` — расширить `t_state_keys_in_overlay()`:
   - `code.contains("scopeRotate")` (uniform объявлен);
   - `code.contains("orbitDist")` (хелпер есть);
   - стабильные токены свиззла: `code.contains("k.brg")` и `code.contains("k.gbr")`;
   - **регресс-гвард:** `not code.contains("k.grb")`;
   - существует хотя бы одна `orbitDist(pixelColor.rgb,` (замена `distance`).

**Проверка:** `check.ps1` → `Tests passed: 22 file(s)` (было 23, минус `test_autopip`).

---

### Task 7 — Версия, CHANGELOG, сборка, установка

Шаги:

1. `mods/ThermalVTK/mod.txt` — версия `1.5.0` (уже стоит; подтвердить).
2. `CHANGELOG.md` — переписать секцию `[1.5.0] - 2026-10-19` → дата выпуска и
   видимый игроку эффект:
   - **Added:** Debug labels — in the debug log mode, each NPC shows its AI state
     and assigned colour category.
   - **Fixed:** Contour outline disappearing or changing colour through magnifying
     scopes while the game's PIP rendering is off.
   - Удалить **обе** строки про авто-PIP (`Added` про scoped rendering и `Added`
     «"Auto-PIP in scope" option») — не выпускались.
2. `README.md` — поле `**Version:** 1.5.0` (`:3`) уже актуально; подтвердить.
4. Тесты (не забыть — это тот же `check.ps1`): он покрывает и `layout_check.py`
   для Loadouts не относится к ThermalVTK.
5. Сборка: `powershell -ExecutionPolicy Bypass -File pack.ps1` → `ThermalVTK.vmz`;
   скопировать в `D:\SteamLibrary\steamapps\common\Road to Vostok\mods\`.
6. Удалить untracked скриншот `standalone mods\ThermalVTK\20261019185252_1.jpg`
   (артефакт зонда Task 6).

---

## Проверка релиза (ручная, в игре)

1. PIP off + NVG + прицел на NPC, 5 карт: **Contour** — обводка видна сквозь
   прицел правильным цветом стейта (не розовая «клякса», не пропадает).
2. Без прицела / PIP on / FULL (F6): поведение не изменилось.
3. `Debug log` on: над NPC сырой стейт и категория; номад → `NOMAD`; off → пропали.
4. `config.ini` после запуска: ключ `auto_pip_scope` отсутствует.

## Риски

- Ложняк орбиты на яркой зелени/ретикле (см. риски спеки) — наблюдать, при
  необходимости поджать порог `0.22`.
- `Label3D` высота по AABB bind-позы — может снести; правится константой.
- Выпил авто-PIP — если пользователь передумает, `VTKAutoPip.gd` восстанавливается
  из git-истории (файл был в рабочем дереве, не в коммите — проверить).
