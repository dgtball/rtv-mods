# ThermalVTK 1.10.0 — X-ray Triggers rework (Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Разъединить семантику тумблера X-ray Triggers: триггер-система (теги + отсчёт в надписях) работает всегда, тумблер управляет только вспышкой ринга сквозь стену, а окклюдед-шейдер сам сравнивает глубину, чтобы стекло прицела не прятало ринг.

**Architecture:** `VTKOutline` хранит xray-флаг на entry и свапает шейдер ринга по entry (opts["xray"] из кадра рисования). `VTKESP`: `_trig_event` тегирует всегда, `_label_text` показывает суффикс по факту окна, `_draw` ставит `cool`+`xray` только при включённом тумблере. Окклюдед-шейдер переходит на `depth_test_disabled` + ручное `DEPTH_TEXTURE`-сравнение с отсечением камеры-прикреплённой геометрии (стекло прицела).

**Tech Stack:** Godot 4.6.3 GDScript + spatial shaders, headless-тесты в `D:\RTVMOD\.check\project`, PowerShell-гейты.

## Global Constraints

- Отступы в `.gd` — ТОЛЬКО табы. После правки нет смешанных пробелов.
- Гейт-команды (обе зелёные после каждой задачи):
  - `powershell -NoProfile -ExecutionPolicy Bypass -File "D:\RTVMOD\.check\check.ps1"` — должен напечатать `Tests passed: 31 file(s)`, без `FAIL`/`SCRIPT ERROR`/`Parse Error`.
  - `-Commands`: `py -3 "D:\RTVMOD\.check\layout_check.py"` — напечатать `RESULT: ...` без провалов.
- Коммит — один, в финальной задаче (конвенция репо: один релиз = один коммит). Только пути `standalone mods/ThermalVTK/**`; не коммитить `test_*` (`.check` не трекается) и `standalone mods/ThermalVTK/debug.log`.
- Сборка ТОЛЬКО собственным скриптом мода: `powershell -ExecutionPolicy Bypass -File "D:\RTVMOD\standalone mods\ThermalVTK\pack.ps1"`; корневой `D:\RTVMOD\pack.ps1` пакует vostok-toolkit — его не трогать. После пака скрипт сам синхронизирует `README.md` и `mods/ThermalVTK/version.txt`.
- Ключ конфига остаётся `outline_xray` (Bool, `outline_xray` name "X-ray Triggers"), значения не переезжают.
- Комментарии в коде — английские, стиль существующих файлов.
- Версия живёт только в `standalone mods/ThermalVTK/mod.txt` (поле `version`).

Спека: `docs/superpowers/specs/2026-10-22-thermalvtk-xray-triggers-rework-design.md`.

---

### Task 1: ThermalVTK — убрать применение глобального set_xray; test_profile чистка

**Files:**
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/ThermalVTK.gd:396-400`
- Modify: `D:\RTVMOD\.check\project\tests\test_profile.gd` (FakeESP + assertion)

**Interfaces:**
- Consumes: `_esp.p_trig` (bool, VTKESP), `_mcm_key_val(cfg, "Bool", "outline_xray", true)`.
- Produces: `_mcm_apply` больше не зовёт `_esp.set_xray` ни в каком темпе. Later tasks rely on: `p_trig` = «вспышки по окнам включены» (остаётся из `outline_xray`).

- [ ] **Step 1: Правка `ThermalVTK.gd` — удалить вызов set_xray, обновить комментарий**

Старый фрагмент (строки 396–400):

```gdscript
		# outline_xray is the "X-ray Triggers" toggle: on = the ring ignores the
		# depth buffer plus the event reveals knock through walls; off = the
		# occluded ring keeps walls and the scope mask in play.
		_esp.set_xray(bool(_mcm_key_val(cfg, "Bool", "outline_xray", true)))
		_esp.p_trig = bool(_mcm_key_val(cfg, "Bool", "outline_xray", true))
```

Новый фрагмент:

```gdscript
		# outline_xray is the "X-ray Triggers" toggle: it gates only the ring
		# flash through the wall. Trigger windows themselves (tags and the
		# debug label countdown) run regardless of the toggle.
		_esp.p_trig = bool(_mcm_key_val(cfg, "Bool", "outline_xray", true))
```

- [ ] **Step 1b: Тултип `outline_xray` под новую семантику** (строка 238)

Старая строка (`"tooltip"`, однострочный `cfg.set_value`):

```gdscript
	cfg.set_value("Bool", "outline_xray", {"name": "X-ray Triggers", "default": true, "value": true, "category": CAT, "menu_pos": 3, "tooltip": "On top of the ESP, event reveals knock out through walls: gunfire, shouts, idle chatter, footsteps, reloads, pain cries and grenade throws ring the NPC for a few seconds at their own reveal range (sliders in the X-ray Triggers tab)."})
```

Новая (имя, ключ, категории и menu_pos прежние; меняется только tooltip):

```gdscript
	cfg.set_value("Bool", "outline_xray", {"name": "X-ray Triggers", "default": true, "value": true, "category": CAT, "menu_pos": 3, "tooltip": "While on, the NPC ring lights up through walls only while a sound event is live: gunfire, shouts, idle chatter, footsteps, reloads, pain cries or grenade throws. Between events the outline stays a normal ring behind walls. The reveal timers themselves show on the debug labels regardless of this toggle."})
```

- [ ] **Step 2: Правка `test_profile.gd` — FakeESP без set_xray**

Удалить объявление `var p_xray: bool = true` (строка 102) и блок (строки 119–126):

```gdscript
	var xray_calls: int = 0
	var enabled: bool = false
	var marker_visible: bool = false
	func set_enabled(v: bool) -> void:
		enabled = v
	func set_xray(v: bool) -> void:
		p_xray = v
		xray_calls += 1
```

заменить на:

```gdscript
	var enabled: bool = false
	var marker_visible: bool = false
	func set_enabled(v: bool) -> void:
		enabled = v
```

(строку `var enabled` и ниже оставить один раз).

- [ ] **Step 3: Удалить assertion, который больше не выполняется**

Строка `ck(esp.xray_calls == 1, "the x-ray switch is applied once")` — удалить целиком.

- [ ] **Step 4: Гейт**

Run: обе команды из Global Constraints.
Expected: `check.ps1` — `Profile tests passed`, общий `Tests passed: 31 file(s)`; layout — ok.

---

### Task 2: VTKOutline — per-entry xray вместо глобального

**Files:**
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKOutline.gd` (поле `_xray`, `_build_ring`, `set_xray`, `apply`, `refresh`)
- Modify: `D:\RTVMOD\.check\project\tests\test_outline.gd` (замена `t_xray_swap` → `t_entry_xray`)

**Interfaces:**
- Consumes: `Shaders.ring(bool)` (VTKShaders, без изменений), opts из `VTKESP._opts_for`.
- Produces: п./сигнатуры — `set_entry_xray(id: int, on: bool) -> void`; `apply()` строит ring из окклюдед-шейдера и кладёт `"xray": false` в entry; `refresh(id, opts)` реагирует на `opts["xray"]`. VTKESP (Task 3) будет присылать `opts["xray"] = true`.

- [ ] **Step 1: Правки `VTKOutline.gd`**

a) Удалить поле и комментарий (строки 28–30):

```gdscript
var _bypass: bool = false
# X-ray is how the ring stays alive in the scope view; user-tunable.
var _xray: bool = true
```

заменить на:

```gdscript
var _bypass: bool = false
```

b) `_build_ring()` — всегда окклюдед:

```gdscript
func _build_ring() -> ShaderMaterial:
	var ring_mat := ShaderMaterial.new()
	ring_mat.shader = Shaders.ring(false)
	ring_mat.render_priority = 21
	return ring_mat
```

c) Удалить глобальный `set_xray` целиком (строки 58–67: комментарий "Depth-tested vs x-ray ring...", func set_xray с телом).

d) Новый per-entry метод (вставить на место удаляемого `set_xray`):

```gdscript
# Event-driven per-entry swap: idle rings stay occluded; when the frame loop
# passes opts["xray"] for a bot with a live trigger window, only that bot's
# ring lights up through walls. Dedupe by the stored flag so per-frame opts
# never reassign the same shader.
func set_entry_xray(id: int, on: bool) -> void:
	var entry = _items.get(id)
	if entry == null:
		return
	if bool(entry.get("xray", false)) == on:
		return
	entry["xray"] = on
	var ring_mat: ShaderMaterial = entry["ring"]
	if ring_mat != null:
		ring_mat.shader = Shaders.ring(on)
```

e) В `apply()` — запись entry получает `"xray": false`:

```gdscript
	_items[id] = {
		"meshes": meshes, "pairs": pairs, "ring": ring_mat,
		"node": node, "child_count": int,
	}
```

заменить на:

```gdscript
	_items[id] = {
		"meshes": meshes, "pairs": pairs, "ring": ring_mat,
		"node": node, "child_count": node.get_child_count(),
		"xray": false,
	}
```

f) В начале `refresh(id, opts)` (часть после получения entry, до `var cool := ...) добавить:

```gdscript
	set_entry_xray(id, bool(opts.get("xray", false)))
```

g) Комментарий над `SCOPE_RIM` (строки 24–27) переписать:

```gdscript
# While the scope view is active the band thins (SCOPE_RIM), so the magnified
# view keeps a fine frame. The shader itself never changes on the scope flag.
```

(строка `# any more: it always ignores depth.` удаляется).

- [ ] **Step 2: Тест в `test_outline.gd`**

a) В шапку теста добавить preload:

```gdscript
const Sh = preload("res://mods/ThermalVTK/VTKShaders.gd")
```

b) В `_run()` список вызовов: `t_xray_swap()` заменить на `t_entry_xray()` (строка вызова между `t_shell_recollect()` и `t_opts_visible()`).

c) Функцию `t_xray_swap` (строки 232–246) заменить целиком на:

```gdscript
# Guards the 1.10.0 rework: the ring stays occluded by default, and only the
# entry with a live trigger window swaps to the x-ray shader — the old global
# set_xray is gone.
func t_entry_xray() -> void:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	var o = Outline.new()
	o.apply(6, root, {"state_key": Color(0, 1, 0), "grow": 0.01, "cool": 0.0})
	var xmat: ShaderMaterial = o.material_of(6)["ring"]
	ck(xmat.shader == Sh.ring(false), "default ring is occluded")
	o.set_entry_xray(6, true)
	ck(xmat.shader == Sh.ring(true), "entry swap lights x-ray")
	o.set_entry_xray(6, true)
	ck(xmat.shader == Sh.ring(true), "same value keeps x-ray")
	o.set_entry_xray(6, false)
	ck(xmat.shader == Sh.ring(false), "off returns to occluded")
	o.refresh(6, {"state_key": Color(0, 1, 0), "grow": 0.01, "cool": 0.0, "xray": true})
	ck(xmat.shader == Sh.ring(true), "opts xray drives the swap")
	o.refresh(6, {"state_key": Color(0, 1, 0), "grow": 0.01, "cool": 0.0})
	ck(xmat.shader == Sh.ring(false), "opts without xray returns to occluded")
	root.free()
```

- [ ] **Step 3: Гейт** — команды из Global Constraints, expected: `Outline tests passed`, общий зелёный.

---

### Task 3: VTKESP — семантика: теги всегда, суффикс по окну, opts["xray"]

**Files:**
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKESP.gd` (`p_xray`, `set_xray`, `_trig_event`, `_label_text`, `_draw`)
- Modify: `D:\RTVMOD\.check\project\tests\test_esp.gd` (удалить `t_set_xray`, добавить `t_label_suffix_independent`)

**Interfaces:**
- Consumes: `Tracker.tag_trig(e, source, dist, expires_at, span)`, `Tracker.pick_trig(e, now) -> Dictionary` (keys: `source`, `dist`, `expires`, `span`), `Tracker.fade_factor(ev, now) -> float`, `Outline.refresh(opts["xray"])` (Task 2), `p_trig` (Task 1 semantic: только вспышками — теги от неё больше не зависят).
- Produces: `_trig_event(source, span, dist)` — тег всегда при span>0; `_label_text` без p_trig-гейта; `_draw` — `opts["xray"]/["cool"]` только при `p_trig`.

- [ ] **Step 1: `VTKESP.gd` правки**

a) Удалить поле `p_xray` и его комментарий (строки 28–31):

```gdscript
# X-ray ring (shader without the depth test) + the trigger reveals. Both
# belong to the "X-ray Triggers" MCM toggle: on = through walls, off = the
# occluded ring keeps walls and the scope mask in play.
var p_xray := true
```

b) Комментарий над `p_trig` переписать (строки 32–35):

```gdscript
# The X-ray Triggers toggle state: on = a live trigger window swaps that bot's
# ring to the x-ray shader (through walls). Off = windows are still tagged,
# but the ring never lights up through the wall; labels read them regardless.
var p_trig := true
```

c) Удалить метод `set_xray` (добавленный в 1.9.3, строки ~119–126: комментарий + `func set_xray` с телом).

d) `_trig_event` — тег всегда, p_trig-гейта больше нет. Это (строка 295):

```gdscript
func _trig_event(source: String, span: float, dist: float) -> void:
	Dbg.log("HOOK", "play %s" % source)
	if not p_trig or span <= 0.0:
		return
```

заменить на:

```gdscript
func _trig_event(source: String, span: float, dist: float) -> void:
	Dbg.log("HOOK", "play %s" % source)
	if span <= 0.0:
		return
```

e) `_label_text` — суффикс независимо от тумблера:

```gdscript
func _label_text(e: Dictionary, node: Node, state: int) -> String:
	var txt := States.label_text(state, bool(e.get("nomad", false)))
	# The countdown suffix is window-driven only: the X-ray toggle governs the
	# ring flash, labels follow the debug log like every other readout.
	var now := _now()
	var ev: Dictionary = Tracker.pick_trig(e, now)
	if not ev.is_empty():
		var left: float = max(0.0, float(ev.get("expires", 0.0)) - now)
		txt += "  [%s %.1fs %.0fm]" % [str(ev.get("source", "")), left, float(ev.get("dist", 0.0))]
	return txt
```

f) `_draw` (строки 601–611):

```gdscript
		var dead := bool(e.get("dead", false))
		var trig_opts: Dictionary = {}
		if p_trig and not dead:
			# X-ray triggers are additive: inside the slider the normal ESP ring
			# does the work already; a live window only extends past it, up to
			# its own reveal distance, fading over the tail of its span.
			var ev: Dictionary = Tracker.pick_trig(e, now)
			if not ev.is_empty() and dist > limit and dist <= float(ev.get("dist", 0.0)):
				trig_opts["cool"] = clampf(1.0 - Tracker.fade_factor(ev, now), 0.0, 1.0)
```

заменить на:

```gdscript
		var dead := bool(e.get("dead", false))
		var trig_opts: Dictionary = {}
		if not dead:
			# A live window is read by labels regardless of the toggle; the
			# x-ray swap (through walls, past Distance up to the reveal range)
			# happens only when the "X-ray Triggers" toggle is on.
			var ev: Dictionary = Tracker.pick_trig(e, now)
			if p_trig and not ev.is_empty() and dist <= float(ev.get("dist", 0.0)):
				trig_opts["cool"] = clampf(1.0 - Tracker.fade_factor(ev, now), 0.0, 1.0)
				trig_opts["xray"] = true
```

(окружащая строка `if dist > limit and not dead and trig_opts.is_empty(): continue` — прежняя.)

- [ ] **Step 2: `test_esp.gd` правки**

a) Удалить вызов `t_set_xray()` из `_run()` и функцию `t_set_xray` целиком (добавленная в 1.9.3, комментарий Guards the 1.9.3 fix...).

b) В шапку добавить preload (рядом с ESP/S/Cal/Outline):

```gdscript
const Tracker = preload("res://mods/ThermalVTK/VTKTracker.gd")
```

c) Новый тест (вставить перед `t_opts_state_key`), проверяет независимость суффикса:

```gdscript
# The countdown suffix lives while a trigger window is open, regardless of the
# X-ray toggle: p_trig gates the ring flash only. Labels follow the debug log.
func t_label_suffix_independent() -> void:
	var esp = ESP.new()
	esp.p_trig = false
	var node := Node3D.new()
	var e := {"nomad": false, "dead": false}
	var now := float(Time.get_ticks_msec()) / 1000.0
	Tracker.tag_trig(e, "fire", 50.0, now + 3.0, 3.0)
	var with_trig := esp._label_text(e, node, 0)
	ck(with_trig.contains("[fire"), "label carries the countdown with p_trig off")
	ck(with_trig.contains("3."), "countdown shows the seconds left")
	esp.p_trig = true
	ck(esp._label_text(e, node, 0).contains("[fire"), "toggle on keeps the suffix")
	var e2 := {"nomad": false, "dead": false}
	ck(not esp._label_text(e2, node, 0).contains("["), "no window, no suffix")
	esp.free()
```

и в `_run()` между `t_set_xray`-слотом и `t_opts_state_key()` вставить вызов `t_label_suffix_independent()`.

- [ ] **Step 3: Гейт** — обе команды, expected: `ESP tests passed`, общий зелёный.

---

### Task 4: Окклюдед-шейдер — ручное depth-сравнение (стекло прицела не прятает ринг)

**Files:**
- Modify: `standalone mods/ThermalVTK/mods/ThermalVTK/VTKOutlineRingOccluded.gdshader` (полный rewrite)
- Modify: `D:\RTVMOD\.check\project\tests\test_shaders.gd` (`t_ring_xray_contract`)

**Interfaces:**
- Consumes: юниформа из Outline (`state_key`, `grow`, `rim_power`, `cool` — без изменений).
- Produces: шейдер, который сам решает скрывать ли фрагмент; рендер-паритет с x-ray (4 юниформа).

- [ ] **Step 1: Полный новый текст `VTKOutlineRingOccluded.gdshader`**

```glsl
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, depth_test_disabled;

// Depth-comparing variant of the silhouette ring. The auto depth test cannot
// tell the scope lens from a wall: the lens sits centimetres from the eye and
// z-culls every ring behind it. So the shader drops the auto test and does
// its own comparison: an occluder closer than the fragment hides the ring,
// unless the occluder is nearer than EXCLUDE_M metres - the band where only
// camera-attached geometry (the scope lens, objects pressed against the
// camera) can live. Uniform parity with VTKOutlineRing.gdshader matters: the
// runtime flip keeps all state without re-reading opts.
uniform vec3 state_key : source_color = vec3(1.0, 0.0, 0.0);
uniform float grow : hint_range(0.0, 0.15, 0.001) = 0.006;
uniform float rim_power : hint_range(0.0, 6.0, 0.1) = 1.0;
uniform float cool : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

// Occluders closer than this are camera-attached, not walls.
const float EXCLUDE_M = 0.25;

void vertex() {
	VERTEX += NORMAL * grow;
}

// NDC depth -> metres in front of the camera (reversed-Z, Forward+).
float depth_metres(float ndc) {
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, ndc, 1.0);
	return -view.z / view.w;
}

void fragment() {
	// Same edge measure as the x-ray ring: |dot| small at the silhouette,
	// abs() keeps the band symmetric.
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = 1.0 - facing;
	ALBEDO = state_key;
	ALPHA = pow(edge, rim_power) * (1.0 - cool);

	float scene_m = depth_metres(texture(depth_tex, SCREEN_UV).r);
	float frag_m = depth_metres(FRAGCOORD.z);
	// The shell is grown along the normals, so the band over the model's own
	// surface sits slightly behind the model front: the bias absorbs that.
	float bias = max(grow * 4.0, 0.02);
	if ((scene_m < frag_m - bias) && (scene_m > EXCLUDE_M)) {
		ALPHA = 0.0;
	}
}
```

- [ ] **Step 2: `test_shaders.gd` — `t_ring_xray_contract` обновление строк 53–56**

Старые строки:

```gdscript
	ck(main.contains("depth_test_disabled"), "x-ray ring ignores the depth buffer")
	ck(main.contains("depth_draw_never"), "x-ray ring never writes depth itself")
	ck(not occ.contains("depth_test_disabled"), "occluded ring keeps the depth test")
	ck(occ.contains("depth_draw_never"), "occluded ring never writes depth either")
```

новые:

```gdscript
	ck(main.contains("depth_test_disabled"), "x-ray ring ignores the depth buffer")
	ck(main.contains("depth_draw_never"), "x-ray ring never writes depth itself")
	ck(occ.contains("depth_test_disabled"), "occluded ring drops the auto test for manual compare")
	ck(occ.contains("hint_depth_texture"), "occluded ring reads the scene depth")
	ck(occ.contains("EXCLUDE_M"), "occluded ring excludes camera-attached geometry")
	ck(not main.contains("hint_depth_texture"), "x-ray ring stays depth-free")
	ck(occ.contains("depth_draw_never"), "occluded ring never writes depth either")
```

Остальные assertions функции (scope variant is gone, single ring pair, both ship) не трогать.

- [ ] **Step 3: Гейт** — обе команды, expected: `Shaders tests passed`, общий зелёный.

---

### Task 5: Релиз 1.10.0

**Files:**
- Modify: `standalone mods/ThermalVTK/mod.txt` (version)
- Modify: `standalone mods/ThermalVTK/CHANGELOG.md`
- Modify: `standalone mods/ThermalVTK/README.md` (версия — синхронизируется pack.ps1 автоматически)
- Modify: `D:\RTVMOD\.superpowers\sdd\2026-10-21-thermalvtk-1.7.1\progress.md`

**Interfaces:** финальная задача — релизная обвязка, новых интерфейсов не вводит.

- [ ] **Step 1: Версия**

`mod.txt`: `version="1.9.3"` → `version="1.10.0"`.

- [ ] **Step 2: CHANGELOG.md — добавить секцию перед `## [1.9.1]`**

```markdown
## [1.10.0] - 2026-10-22

### Changed
- With "X-ray Triggers" on, the outline lights through walls only while a sound event is live (gunfire, a shout, footsteps and the rest) instead of permanently; between events it behaves like the ordinary distance limited ring.
- Sound-reveal timers are no longer tied to the toggle: with the debug log on, every live reveal shows its countdown on the NPC label whether the toggle is on or off.

### Fixed
- NPC outlines show through the scope glass again: the optics no longer hide the ring while the toggle is off.
```

- [ ] **Step 3: Полные гейты** (обе команды из Global Constraints), expected: всё зелёное, `Tests passed: 31 file(s)`.

- [ ] **Step 4: Сборка и установка**

```powershell
powershell -ExecutionPolicy Bypass -File "D:\RTVMOD\standalone mods\ThermalVTK\pack.ps1"
Copy-Item "D:\RTVMOD\standalone mods\ThermalVTK\ThermalVTK.vmz" "D:\SteamLibrary\steamapps\common\Road to Vostok\mods\ThermalVTK.vmz" -Force
```

Expected: pack печатает `version = 1.10.0`; результирующий ThermalVTK.vmz в mods ~42 КБ (содержимое ThermalVTK, 19 entries).

- [ ] **Step 5: Коммит**

```powershell
git -C "D:\RTVMOD" add -- "standalone mods/ThermalVTK/mod.txt" "standalone mods/ThermalVTK/CHANGELOG.md" "standalone mods/ThermalVTK/README.md" "standalone mods/ThermalVTK/mods/ThermalVTK/version.txt" "standalone mods/ThermalVTK/mods/ThermalVTK/ThermalVTK.gd" "standalone mods/ThermalVTK/mods/ThermalVTK/VTKESP.gd" "standalone mods/ThermalVTK/mods/ThermalVTK/VTKOutline.gd" "standalone mods/ThermalVTK/mods/ThermalVTK/VTKOutlineRingOccluded.gdshader"
git -C "D:\RTVMOD" commit -m "feat(thermalvtk): 1.10.0 - event-driven x-ray flashes, scope-glass depth compare"
```

Не добавлять: `standalone mods/ThermalVTK/debug.log`, `standalone mods/LooterShooter/**`.

- [ ] **Step 6: Ledger**

Append в `D:\RTVMOD\.superpowers\sdd\2026-10-21-thermalvtk-1.7.1\progress.md` запись об 1.10.0: что сделано, гейты, vmz size, коммит-хэш из `git log --oneline -1`, статус ручной проверки (pending: in-game).

- [ ] **Step 7: Ручная проверка игроком (после его сессии)**

Чеклист для пользователя в игре:
1. ESP ON, X-ray Triggers OFF, тепловизор ON → смотреть в оптику на NPC: ринг виден.
2. X-ray OFF → ринг за стеной прячется, Distance ограничивает.
3. X-ray ON, в покое → ринг обычный (за стеной прятается).
4. Выстрел/шаги бота в радиусе события → ринг вспыхивает сквозь стену + в надписи `[fire 4.2s 100m]`, гаснет с окном.
5. В оптике с окном → вспышка тоже видна (x-ray-шейдер игнорирует глубину).
Если в оптике ринг всё ещё не виден → передать скрин/данные; план Б (по согласованию): при `_scoped_now()` принудительно свапать entry в x-ray-шейдер.
