# Мелкие правки UI батча 4 — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Закрыть семь мелких UI-дефектов, найденных при прогоне 4.17.2 (клетка снаряжения, kill stats, kill feed), и выпустить 4.17.3.

**Architecture:** Все правки локальны и не меняют логику набора: подписи/иконки в клетке снаряжения (`VTKUI.gd`), подложка и нормализация имени в `VTKKillCounter.gd`, две правки словаря `VTKLoc.gd`. Одна новая чистая static-функция (`clean_ai_name`) покрывается headless-тестом. Пропуск в 4.17.2 — это фиксы, не фичи.

**Tech Stack:** Godot 4.6.3, GDScript, modloader Metro 3.4.2. Стенды: `.check\check.ps1` (парсинг + тесты), `.check\layout_check.py`, `.check\keycheck.py`.

## Global Constraints

- Отступы в `.gd` — **только табы**. Файлы в **UTF-8**.
- Версия живёт **только** в `loadouts/mod.txt`; в GDScript не дублируется.
- Локализация: английский ключ = сама английская строка; RU-запись добавляется в том же проходе, что и вызов. Строка с кавычкой пишется в одинарных кавычках.
- Никакой смены поведения сверх семи перечисленных правок; форматы данных не трогаются.
- `docs/` под `/*` в `.gitignore` — эти файлы **не коммитятся** (репозиторная практика важнее шага «commit» скилла).
- Гейты перед релизом обязаны быть зелёными: `layout_check.py` exit 0; `check.ps1` — «Parse check passed», «tests passed», exit 0. `keycheck.py` красный по существующей причине (нет RU у `'Deposit'`) — это не регрессия.
- Целевая версия: **4.17.3** (патч).

---

### Task 1: Короткие подписи тумблера обоймы (пункт A)

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd:1303`
- Modify: `loadouts/mods/VTK/VTKLoc.gd` (убрать `'Empty'` ~:44, добавить `'Empty mag'`/`'Full mag'` рядом с `'Full'`/`'Full magazine'` ~:46-47)

**Interfaces:**
- Consumes: `Loc.txt(key: String) -> String`; `_style_full_btn(b, on, label)` (`VTKUI.gd:1278`).
- Produces: ничего для других задач.

- [ ] **Step 1: Заменить подпись тумблера**

В `VTKUI.gd` строка 1303:

```gdscript
	_style_full_btn(b, on, Loc.txt("Full magazine") if on else Loc.txt("Empty"))
```

→

```gdscript
	_style_full_btn(b, on, Loc.txt("Full mag") if on else Loc.txt("Empty mag"))
```

- [ ] **Step 2: Обновить словарь `VTKLoc.gd`**

Удалить строку `'Empty': 'Пусто',` (она была нужна только тумблеру обоймы, `:44`).

Добавить рядом с `'Full'` (`:46`):

```gdscript
	'Empty mag': 'Пустая',
```

и рядом с `'Full magazine'` (`:47`):

```gdscript
	'Full mag': 'Полная',
```

Ключи `'Full magazine'` (`:47`, ещё используется в `_build_mag_panel:3129`) и `'Full'` (`:46`, кнопка патронов `:1289`) — **оставить**.

- [ ] **Step 3: Проверить ключи (рассинхрон словаря)**

Run: `py -3 .check\keycheck.py`
Expected: `'Empty'` не значится stale (удалён), `'Full mag'`/`'Empty mag'` не значатся missing (используются). Единственная прежняя красная строка про `'Deposit'` остаётся — это не регрессия.

- [ ] **Step 4: Гейты раскладки и парсинга**

Run: `py -3 .check\layout_check.py`
Expected: exit 0.

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `Parse check passed: 16 scripts` (или текущее число), `Tests passed: 9 file(s)`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add loadouts/mods/VTK/VTKUI.gd loadouts/mods/VTK/VTKLoc.gd
git commit -m "fix(vtk): shorten magazine Full/Empty toggle to fit the cell"
```

---

### Task 2: Обвесы — шестерёнка в левом верхнем углу (пункт B)

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd:1315-1322` (`_make_gear_action_row`), `:2611-2622` (`_make_att_btn`), `:2799-2804` (ветка gear в `_make_item_cell` — вставить шестерёнку после `row_b`, до `drop`)
- Modify: `loadouts/mods/VTK/VTKLoc.gd` (удалить `' rnd.'` ~:18)

**Interfaces:**
- Consumes: `VTKSurface.gear_icon(size: int, color: Color) -> Texture2D` (`VTKSurface.gd:38`); `VTKSurface.GREY` (`VTKSurface.gd:11`); `VTKSurface.style_button(b, accent, danger, ml, mr, mt, mb)`; `_att_panel_needed(info) -> bool`; `_toggle_attachment_panel(path: String)`; `_gold`.
- Produces: `_make_att_btn(desc) -> Button` теперь иконка без текста (та же сигнатура/тип).

- [ ] **Step 1: `_make_att_btn` — иконка вместо текста**

Заменить тело `VTKUI.gd:2611-2622`:

```gdscript
func _make_att_btn(desc) -> Button:
	var path_now := str(desc.get("path", ""))
	var atts = desc.get("attachments") if desc.has("attachments") else []
	var b := Button.new()
	b.icon = VTKSurface.gear_icon(18, _gold if atts.size() > 0 else VTKSurface.GREY)
	b.expand_icon = true
	b.custom_minimum_size = Vector2(20, 20)
	VTKSurface.style_button(b, true, false, 2, 2, 2, 2)
	b.pressed.connect(func(): _toggle_attachment_panel(path_now))
	return b
```

- [ ] **Step 2: `_make_gear_action_row` — убрать обвесную ветку строки B**

Заменить `VTKUI.gd:1315-1322`:

```gdscript
func _make_gear_action_row(path: String, desc: Dictionary) -> Control:
	if _is_magazine(path):
		return _make_full_mag_btn(path, desc)
	if str(_item_info(path).get("type")) == "Ammo":
		return _make_full_ammo_btn(path, desc)
	return null
```

- [ ] **Step 3: `_make_item_cell` — шестерёнка в углу**

В gear-ветке (`_draft != null and gi >= 0`) сразу после блока `row_b` (`VTKUI.gd:2799-2804`) и перед созданием `drop` вставить:

```gdscript
		# Обвесы: шестерёнка в левом верхнем углу, зеркально ✕ справа.
		# Прежняя текстовая «обв.N» занимала строку B и больше не нужна.
		if _att_panel_needed(_item_info(path_now)):
			var gear_btn := _make_att_btn(desc_g)
			cell.add_child(gear_btn)
			gear_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
			gear_btn.offset_left = 2
			gear_btn.offset_top = 2
			gear_btn.offset_right = 22
			gear_btn.offset_bottom = 22
```

Блок `drop` (`:2806-2820`) не трогать: ✕ остаётся `PRESET_TOP_RIGHT` — этого требует тело `_make_item_cell` в `layout_check.py:318`.

- [ ] **Step 4: Удалить ключ `' rnd.'` из словаря**

В `VTKLoc.gd` удалить строку `' rnd.': ' обв.',` (~:18) — её единственный потребитель удалён.

- [ ] **Step 5: Гейты**

Run: `py -3 .check\layout_check.py`
Expected: exit 0 (тело `_make_item_cell` по-прежнему содержит `PRESET_TOP_RIGHT`).

Run: `py -3 .check\keycheck.py`
Expected: `' rnd.'` больше не stale.

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `Parse check passed`, `Tests passed: 9 file(s)`, exit 0.

- [ ] **Step 6: Commit**

```bash
git add loadouts/mods/VTK/VTKUI.gd loadouts/mods/VTK/VTKLoc.gd
git commit -m "feat(vtk): open attachments from a corner gear icon"
```

---

### Task 3: Счётчик по центру, без ввода по клику (пункты C+D)

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd:2784-2793` (комментарий + вызов), `:1324-1350` (`_gear_edit_cap` удалить + `_make_gear_count` переписать), `:1352-1383` (`_open_gear_amount_edit` удалить)

**Interfaces:**
- Consumes: `_gold`; `_make_mini_btn`.
- Produces: `_make_gear_count(cnt: int) -> Control` — **сигнатура изменилась** (убран первый параметр `path`). Единственный вызов — `VTKUI.gd:2793`.

- [ ] **Step 1: Переписать `_make_gear_count` и удалить `_gear_edit_cap`**

Заменить блок `VTKUI.gd:1324-1350` целиком (от комментария `# Потолок...` до закрывающей фигурной скобки `_make_gear_count`) на:

```gdscript
# Число в строке A, по центру между «−» и «+». Голый Control детей не
# раскладывает - число липло к левому верхнему углу; CenterContainer держит
# его посередине. Ввод точного значения убран: поле наезжало на «+».
func _make_gear_count(cnt: int) -> Control:
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(30, 28)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := Label.new()
	lbl.text = str(cnt)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", _gold)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(lbl)
	return holder
```

- [ ] **Step 2: Удалить `_open_gear_amount_edit`**

Удалить `VTKUI.gd:1352-1383` целиком (комментарий `# Клик по числу...` и функцию `_open_gear_amount_edit`).

- [ ] **Step 3: Обновить комментарий строки A и вызов**

`VTKUI.gd:2784-2785`:

```gdscript
		# Строка A: шаг. Число между «−» и «+» кликабельно (ввод точного
		# значения). Дубль ×N убран - число живёт здесь само.
```

→

```gdscript
		# Строка A: шаг «− n +». Дубль ×N убран - число живёт здесь само.
```

`VTKUI.gd:2793`:

```gdscript
		row_a.add_child(_make_gear_count(path_now, cnt_g))
```

→

```gdscript
		row_a.add_child(_make_gear_count(cnt_g))
```

- [ ] **Step 4: Гейты**

Run: `py -3 .check\layout_check.py` — exit 0.
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1` — `Parse check passed`, `Tests passed: 9 file(s)`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add loadouts/mods/VTK/VTKUI.gd
git commit -m "fix(vtk): center gear count and drop click-to-type editing"
```

---

### Task 4: «Только выбранные» без надетого (пункт E)

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd:1574-1580`

**Interfaces:**
- Consumes: `Draft.gear_index_of(path: String) -> int` (`VTKDraft.gd:121`); `_draft`.
- Produces: ничего.

- [ ] **Step 1: Заменить предикат фильтра**

`VTKUI.gd:1574-1580`:

```gdscript
	if _gear_only_selected and _draft != null:
		var picked: Array = []
		for e in found:
			var res_it = e.get("item")
			if res_it != null and _draft.has_path(str(res_it.resource_path)):
				picked.append(e)
		found = picked
```

→

```gdscript
	if _gear_only_selected and _draft != null:
		var picked: Array = []
		for e in found:
			var res_it = e.get("item")
			if res_it != null and _draft.gear_index_of(str(res_it.resource_path)) >= 0:
				picked.append(e)
		found = picked
```

(`has_path` истинно и для экипировки — `VTKDraft.gd:127-130`; `gear_index_of` — только для списка снаряжения.)

- [ ] **Step 2: Гейты**

Run: `py -3 .check\layout_check.py` — exit 0.
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1` — `Parse check passed`, `Tests passed: 9 file(s)`, exit 0.

- [ ] **Step 3: Commit**

```bash
git add loadouts/mods/VTK/VTKUI.gd
git commit -m "fix(vtk): exclude equipped items from Only-selected gear filter"
```

---

### Task 5: Подложка у kill stats (пункт F)

**Files:**
- Modify: `loadouts/mods/VTK/VTKKillCounter.gd:17-41` (`_ready`, `set_enabled`), добавить поле `_panel` рядом с `_label` (`:5`)

**Interfaces:**
- Consumes: `Paths.hud_font()`.
- Produces: поле `_panel: PanelContainer`; видимость счётчика теперь на `_panel`.

- [ ] **Step 1: Добавить поле `_panel`**

`VTKKillCounter.gd:5`:

```gdscript
var _label: Label = null
```

→

```gdscript
var _label: Label = null
var _panel: PanelContainer = null
```

- [ ] **Step 2: Обернуть Label в PanelContainer (`_ready`)**

Заменить `VTKKillCounter.gd:17-29`:

```gdscript
func _ready() -> void:
	name = "VTKKillCounter"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	_label.add_theme_font_size_override("font_size", 13)
	var hud := Paths.hud_font()
	if hud != null:
		_label.add_theme_font_override("font", hud)
	_label.position = Vector2(10, 10)
	_label.visible = false
	add_child(_label)
	get_tree().node_added.connect(_on_node_added)
```

→

```gdscript
func _ready() -> void:
	name = "VTKKillCounter"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Подложка: без неё светлый HUD на солнце съедает надпись. Тот же приём,
	# что у строки ленты (VTKFeed): чёрный 0.45 + узкие поля.
	_panel = PanelContainer.new()
	_panel.position = Vector2(10, 10)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.45)
	sb.content_margin_left = 6.0
	sb.content_margin_right = 6.0
	sb.content_margin_top = 1.0
	sb.content_margin_bottom = 1.0
	_panel.add_theme_stylebox_override("panel", sb)
	_label = Label.new()
	_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	_label.add_theme_font_size_override("font_size", 13)
	var hud := Paths.hud_font()
	if hud != null:
		_label.add_theme_font_override("font", hud)
	_panel.add_child(_label)
	_panel.visible = false
	add_child(_panel)
	get_tree().node_added.connect(_on_node_added)
```

- [ ] **Step 3: Переключить видимость на панель (`set_enabled`)**

`VTKKillCounter.gd:33`:

```gdscript
	_label.visible = v
```

→

```gdscript
	_panel.visible = v
```

Остальное в `set_enabled` (сброс счётчиков и `_label.text = ""`) — без изменений.

- [ ] **Step 4: Гейты**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1` — `Parse check passed`, `Tests passed: 9 file(s)`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add loadouts/mods/VTK/VTKKillCounter.gd
git commit -m "fix(vtk): add a backdrop to kill stats for daylight legibility"
```

---

### Task 6: Хвост `_N` в именах ленты (пункт G) — TDD

**Files:**
- Modify: `loadouts/mods/VTK/VTKKillCounter.gd` (добавить `clean_ai_name`, применить в `agent_display_name:113`)
- Modify: `.check/project/tests/test_feed.gd` (добавить `t_clean_ai_name`, вызвать в `_run`)

**Interfaces:**
- Consumes: `_identities(n)` (`VTKKillCounter.gd:123`).
- Produces: `clean_ai_name(s: String) -> String` (static) — срезает хвост из цифр (и предшествующее подчёркивание).

- [ ] **Step 1: Написать падающий тест**

В `.check/project/tests/test_feed.gd` в `_run()` добавить вызов после `t_agent_display_name()` (`:28`):

```gdscript
	t_clean_ai_name()
```

И добавить функцию (например, после `t_agent_display_name`, `:81`):

```gdscript
# Пул клеит инстансам имена вида AI_Nomad_2; хвост не должен попадать в ленту.
func t_clean_ai_name() -> void:
	ck(KC.clean_ai_name("Nomad_2") == "Nomad", "хвост _2 срезан")
	ck(KC.clean_ai_name("Bandit7") == "Bandit", "хвост 7 без подчёркивания срезан")
	ck(KC.clean_ai_name("Nomad") == "Nomad", "имя без хвоста не меняется")
	ck(KC.clean_ai_name("") == "", "пусто -> пусто")
	var n := FakeAgent.new()
	root.add_child(n)
	n.name = "AI_Nomad_2"
	ck(KC.agent_display_name(n) == "Nomad", "AI_Nomad_2 -> Nomad")
	n.queue_free()
```

- [ ] **Step 2: Прогнать — тест обязан упасть**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: FAIL. `test_feed.gd` даёт «Invalid call» (метод `clean_ai_name` ещё не существует) → `VERDICT: FAIL`, exit 1.

- [ ] **Step 3: Реализовать `clean_ai_name` и применить**

В `VTKKillCounter.gd` добавить перед `agent_display_name` (перед `:105`):

```gdscript
# "Nomad_2"/"Nomad7" -> "Nomad": пул игровых AI клеит к имени узла номер,
# который не является частью фракции. Срезаем хвостовые цифры, а стоящее
# прямо перед ними подчёркивание - вместе с ними.
static func clean_ai_name(s: String) -> String:
	var i := s.length()
	while i > 0 and s.unicode_at(i - 1) >= 48 and s.unicode_at(i - 1) <= 57:
		i -= 1
	if i < s.length() and i > 0 and s.unicode_at(i - 1) == 95:
		i -= 1
	return s.substr(0, i)
```

Применить в `agent_display_name:113`:

```gdscript
		if s.begins_with("AI_"):
			return s.substr(3)
```

→

```gdscript
		if s.begins_with("AI_"):
			return clean_ai_name(s.substr(3))
```

- [ ] **Step 4: Прогнать — тест обязан пройти**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `Tests passed: 9 file(s)`, exit 0 (в т.ч. новые строки `ok` из `t_clean_ai_name`).

- [ ] **Step 5: Commit**

```bash
git add loadouts/mods/VTK/VTKKillCounter.gd .check/project/tests/test_feed.gd
git commit -m "fix(vtk): strip pool suffix from enemy names in the kill feed"
```

Примечание: `.check/` не коммитится в удалённый репозиторий (под `.gitignore`-allowlist), но локальный трекинг теста ведём для истории. Если `git add` проигнорирует путь — использовать `git add -f` только для `loadouts/mods/VTK/VTKKillCounter.gd`, а тест оставить локальным (согласуется с практикой репозитория).

---

### Task 7: Релиз 4.17.3

**Files:**
- Modify: `loadouts/mod.txt:4`
- Modify: `CHANGELOG.md` (новая секция сверху)
- Regenerated by `pack.ps1`: `loadouts/mods/VTK/version.txt`, `README.md`

**Interfaces:**
- Consumes: артефакт `pack.ps1`; папка модов игры.
- Produces: `Loadouts.vmz` 4.17.3.

- [ ] **Step 1: Поднять версию**

`loadouts/mod.txt:4`:

```ini
version="4.17.2"
```

→

```ini
version="4.17.3"
```

- [ ] **Step 2: Записать CHANGELOG**

Над строкой `## [4.17.2] - 2026-10-14` (`CHANGELOG.md:7`) вставить:

```markdown
## [4.17.3] - 2026-10-14

### Changed

- The magazine Full/Empty toggle is shorter and fits the gear item's cell.
- Attachments now open from a gear icon in the cell's corner.
- The gear count is centered between − and +; click-to-type amount was removed.

### Fixed

- "Only selected" on the Gear tab no longer lists items already worn in equipment.
- Kill stats got a background so they stay readable in daylight.
- The kill feed no longer appends a number suffix to enemy or Nomad names.
```

- [ ] **Step 3: Собрать пак**

Run: `powershell -ExecutionPolicy Bypass -File pack.ps1`
Expected: вывод `Version in mod.txt: 4.17.3`, синк `mods/VTK/version.txt` и `README.md`, `Pack done: ...Loadouts.vmz (N entries, ... KB)`.

- [ ] **Step 4: Финальные гейты на собранном состоянии**

Run: `py -3 .check\layout_check.py` — exit 0.
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1` — `Parse check passed`, `Tests passed: 9 file(s)`, exit 0.

- [ ] **Step 5: Развернуть в игру**

```powershell
Copy-Item -LiteralPath "D:\RTVMOD\Loadouts.vmz" -Destination "D:\SteamLibrary\steamapps\common\Road to Vostok\mods\Loadouts.vmz" -Force
```

- [ ] **Step 6: Commit**

```bash
git add loadouts/mod.txt loadouts/mods/VTK/version.txt README.md CHANGELOG.md
git commit -m "release: 4.17.3"
```

- [ ] **Step 7: Ручная проверка в игре (чеклист)**

1. Тумблер обоймы умещается в клетку и читается в обоих состояниях.
2. У клетки с обвесами шестерёнка в левом верхнем углу открывает панель; золотая при выбранных обвесах, серая без.
3. Клик по числу ничего не открывает; «−/+» меняют количество.
4. Число стоит по центру между «−» и «+».
5. «Только выбранные» в Снаряжении не показывает надетое.
6. Надписи Kill stats видны на светлом фоне (если съехали вниз — `_panel.position.y` 10 → 8).
7. В ленте убийств имена без `_N`.

---

## Self-Review

**Spec coverage:** A→Task 1; B→Task 2; C→Task 3; D→Task 3; E→Task 4; F→Task 5; G→Task 6; версия/CHANGELOG/пак→Task 7. Все семь пунктов и релиз покрыты.

**Placeholder scan:** плейсхолдеров нет — каждый шаг несёт готовый код или точную команду/ожидание.

**Type consistency:** `_make_gear_count(cnt: int) -> Control` — объявлена в Task 3 и её единственный вызов там же обновлён (:2793). `clean_ai_name(s: String) -> String` — объявлена в Task 6, там же используется. `_panel: PanelContainer` — объявлен в Task 5 до использования в `_ready`/`set_enabled`. `_make_att_btn(desc) -> Button` сохраняет сигнатуру/тип при смене содержимого.

## Execution Handoff

План сохранён в `docs/superpowers/plans/2026-10-14-batch4-ui-fixes.md`. Варианты исполнения:

1. **Subagent-Driven (рекомендуется)** — свежий сабагент на задачу, ревью между задачами.
2. **Inline** — выполнение в этой сессии через executing-plans.
