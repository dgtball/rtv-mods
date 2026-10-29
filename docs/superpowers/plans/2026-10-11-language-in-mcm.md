# Перенос языка в MCM и удаление вкладки «Настройки» Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Перенести последнюю настройку мода (язык интерфейса) в MCM типом Dropdown и удалить вкладку «Настройки» целиком; релиз 4.13.7.

**Architecture:** Все правки — в `VTKUI.gd` (чтение/применение языка, чистка вкладок и мёртвых хелперов) плюс чистка осиротевших ключей в `VTKLoc.gd`. Источник правды по языку — `user://MCM/vostok-toolkit/config.ini` (`[Dropdown] language`), как и у остальных настроек; старый `ui_toggles.json` больше не читается и не пишется (миграции нет). Живое применение — в `_mcm_apply`: смена языка пересобирает UI на месте. Чистая логика (`VTKLoc`) не меняется по поведению, только словарь.

**Tech Stack:** GDScript (Godot 4.6.3), Godot headless-стенд `.check/check.ps1`, Python-стенды `.check/layout_check.py` / `keycheck.py` / `encoding_check.py`, PowerShell 5.1.

## Global Constraints

- **Версия релиза — 4.13.7.** Правится только `loadouts/mod.txt` (`version`). `loadouts/mods/VTK/version.txt` и первая версия-строка `README.md` генерируются из `mod.txt` скриптом `pack.ps1` при сборке — руками не трогать.
- **Отступы в `.gd` — только табы**, файлы UTF-8. Никаких пробелов в отступах, никакого mojibake.
- **Локализация:** функция называется `Loc.txt()`, не `tr()`. Ключ словаря сам является английской строкой. Строка с кавычкой пишется в одинарных кавычках.
- **Коммитов по задачам нет: один релизный коммит в Task 3, и только по явному согласию пользователя.** Обычный `git add loadouts/**` запрещён — стейджить только перечисленные в Task 3 файлы (в дереве есть чужая незакоммиченная правка `VTKNVG.gd`, её не трогаем и не теряем).
- **Не трогать чужие незакоммиченные правки** в дереве: `README.md` (строка 7 — версия), `loadouts/mod.txt` (4.13.6), `loadouts/mods/VTK/version.txt` (4.13.6), `loadouts/mods/VTK/VTKNVG.gd` (строка `"node": node`). Правки параллельного процесса; версионные файлы релиз естественно переводит на 4.13.7, `VTKNVG.gd` не трогаем вовсе.
- **Миграции нет:** `ui_toggles.json` на диске не читается, не пишется и не удаляется. После обновления язык у всех — `en` до ручной установки.
- **`docs/` и `.check/` в gitignore** — план, спека, стенды не коммитятся, это норма репозитория.
- **Зелёный статус `check.ps1`** = нет строк `SCRIPT ERROR` / `Parse Error` / `Invalid call` / `Failed to load script` + есть `tests passed` + код выхода 0.
- **Godot headless:** `D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe` (не в PATH, `check.ps1` берёт сам).
- **`py` launcher** (не `python`). Стенды: `py .check\layout_check.py`, `py .check\keycheck.py`, `py .check\encoding_check.py`, `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`.
- **Коммитов по задачам нет** (см. выше). Каждая задача заканчивается прогоном стендов и ручной проверкой в игре; коммит — только в Task 3.
- **Новый headless-тест не добавляем:** логика чтения языка завязана на файл `config.ini` и пересборку сцены, headless её осмысленно не покрывает. Список `$tests` в `check.ps1` не трогаем.

---

### Task 1: Язык читается, регистрируется и применяется из MCM; переключатель языка убран из вкладки

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd` — `_register_mcm` (:3403-3405), `_load_lang` (:3036-3050), `_clear_ui`/новый `_rebuild_ui` (:3052), `_mcm_apply` (:3499-3502), `_build_settings_tab` (:3078-3087), удалить `_make_lang_row` (:3099-3148), `_make_seg_btn_style` (:3150-3151), `_on_lang_button` (:3153-3164), `_lang_btns` (:106)
- Modify: `loadouts/mods/VTK/VTKLoc.gd` — удалить `'Interface'`, `'Interface language'`, `'Switch between English and Russian'`
- Modify: `.check/layout_check.py` — FUNCS (:279-280), GONE (:129), PRESENT (:239)

**Interfaces:**
- Produces: MCM Dropdown-ключ `[Dropdown] language` в `config.ini` со значением-ключом словаря (`"en"`/`"ru"`).
- Produces: `_load_lang() -> void` (имя сохранено — вызов `_init_later:213` не трогаем) читает `config.ini` вместо `ui_toggles.json`.
- Produces: `_rebuild_ui() -> void` — пересборка UI с восстановлением открытой вкладки по позиции.
- Consumes: `Loc.DEFAULT`, `Loc.get_lang()`, `Loc.set_lang()` (`VTKLoc.gd`, `set_lang` сам отбрасывает недопустимые коды), `_mcm_key_val` (:3491), `_clear_ui` (:3052), `_build_ui` (:404), `_switch_tab` (:548).

**Контекст:** `_init_later` (:201) зовёт `_load_lang()` (213) до `_register_mcm()` (219). На первом запуске конфига нет → `en`; затем `_register_mcm` пишет `language.value = Loc.get_lang()`. На последующих запусках язык берётся из конфига. `_register_mcm` в конце зовёт `_mcm_apply(ConfigFile.new())` (:3464) — там `want == Loc.get_lang()`, пересборки нет. `_mcm_apply` приходит из MCM на каждое «Apply» пользователя.

- [ ] **Step 1: Зарегистрировать Dropdown `language` в MCM**

В `_register_mcm`, после строки `nvg_debug_probe` (`VTKUI.gd:3405`) и перед `var TP := "02. ThermalVision"` (`:3406`) вставить:

```gdscript
	cfg.set_value("Dropdown", "language", {"name": "Language", "default": Loc.DEFAULT, "value": Loc.get_lang(), "options": {"en": "English", "ru": "Русский"}, "category": CAT, "menu_pos": 2, "tooltip": "Interface language of the Loadouts window. English is the source language."})
```

`menu_pos = 2` — после `key_ui_toggle` (0) и `nvg_debug_probe` (1). `options` как Dictionary → значение трактуется как ключ словаря (`"en"`/`"ru"`); подписи опций — литералы своего языка.

- [ ] **Step 2: Читать язык из `config.ini` в `_load_lang`**

Заменить тело `VTKUI.gd:3036-3050` целиком:

```gdscript
func _load_lang() -> void:
	Loc.set_lang(Loc.DEFAULT)
	var cf := ConfigFile.new()
	if cf.load("user://MCM/vostok-toolkit/config.ini") != OK:
		return
	var d = cf.get_value("Dropdown", "language", {})
	if typeof(d) == TYPE_DICTIONARY:
		Loc.set_lang(str(d.get("value", Loc.DEFAULT)))
```

Файла нет / ключа нет / значение не из словаря → остаётся `en`. `set_lang` валидирует код сам.

- [ ] **Step 3: Добавить `_rebuild_ui` рядом с `_clear_ui`**

После функции `_clear_ui` (`VTKUI.gd:3052-3060`) вставить:

```gdscript
# Пересборка UI на месте после смены языка. Активную вкладку восстанавливаем
# по позиции: _current_tab хранит локализованную строку, а после перевода
# имена вкладок меняются и по имени прежний ключ не находится.
func _rebuild_ui() -> void:
	var idx := -1
	for i in range(_tab_btns.size()):
		if (_tab_btns[i] as Button).text == _current_tab:
			idx = i
			break
	_clear_ui()
	_build_ui()
	if idx >= 0 and idx < _tab_btns.size():
		_switch_tab((_tab_btns[idx] as Button).text)
```

- [ ] **Step 4: Применять язык в `_mcm_apply`**

В `_mcm_apply`, сразу после загрузки конфига (`VTKUI.gd:3502`) и до `_key_ui_toggle` (`:3503`) вставить:

```gdscript
	var want := str(_mcm_key_val(cfg, "Dropdown", "language", Loc.get_lang()))
	if want != Loc.get_lang():
		Loc.set_lang(want)
		if Loc.get_lang() == want:
			_rebuild_ui()
```

Проверка `Loc.get_lang() == want` после `set_lang` защищает от цикла на неизвестном коде: невалидное значение ничего не меняет и пересборки нет. Блок стоит до раннего `return` по NVG (`:3512-3513`), поэтому язык применяется независимо от состояния NVG.

- [ ] **Step 5: Убрать секцию языка из `_build_settings_tab`**

Заменить тело `_build_settings_tab` (`VTKUI.gd:3078-3087`) на:

```gdscript
func _build_settings_tab(parent: VBoxContainer) -> void:
	_make_settings_header(parent, Loc.txt("Modules"))
	_kc_btn = _make_toggle_row(parent, Loc.txt("Kill counter"), Loc.txt("Shows the kill counter in the interface"), _kc_toggle)
```

(Удалены `_lang_btns.clear()`, `HSeparator`, заголовок `Interface` и вызов `_make_lang_row`. Секция `Modules` и тумблер счётчика остаются — они уйдут целиком в Task 2.)

- [ ] **Step 6: Удалить мёртвые языковые хелперы и поле**

- Удалить `func _make_lang_row(...)` целиком (`VTKUI.gd:3099-3148`).
- Удалить `func _make_seg_btn_style(...)` целиком (`:3150-3151`).
- Удалить `func _on_lang_button(...)` целиком (`:3153-3164`).
- Удалить `var _lang_btns: Array = []` (`:106`).

`VTKSurface.panel`, `_attach_motion`, `_gold` используются и в других местах — не удалять.

- [ ] **Step 7: Почистить осиротевшие ключи локали**

Ключи больше не вызываются (`Loc.txt("Interface")` ушёл вместе с секцией, языковая строка удалена). Убедиться:

```powershell
rg -n --fixed-strings 'Loc.txt("Interface")' loadouts\mods\VTK
rg -n --fixed-strings 'Interface language' loadouts\mods\VTK
rg -n --fixed-strings 'Switch between English and Russian' loadouts\mods\VTK
```

Ожидается: совпадения только внутри `VTKLoc.gd` (сам словарь). Удалить из `VTKLoc.gd` записи:
- `'Interface': 'Интерфейс',` (:178)
- `'Interface language': 'Язык интерфейса',` (:52)
- `'Switch between English and Russian': 'Переключение между английским и русским',` (:181)

`'Modules'`, `'Kill counter'`, `'Shows the kill counter in the interface'` пока используются вкладкой — удаляются в Task 2.

- [ ] **Step 8: Обновить `layout_check.py`**

- В `FUNCS` удалить запись `_make_lang_row` (`:279-280`) — иначе `NOFUNC`.
- В `GONE` (перед `]` на строке 129) добавить:

```python
    # 4.13.7: язык переехал в MCM, переключатель ушёл из вкладки - возвращать
    # его функции и ключи локали нельзя.
    "_make_lang_row",
    "_make_seg_btn_style",
    "_on_lang_button",
    "_lang_btns",
    'Loc.txt("Interface language")',
    'Loc.txt("Switch between English and Russian")',
    'Loc.txt("Interface")',
```

- В `PRESENT` (перед `]` на строке 239) добавить:

```python
    "Dropdown",
    '"language"',
```

- [ ] **Step 8b: Прогнать стенды**

```powershell
py .check\layout_check.py
py .check\keycheck.py
py .check\encoding_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```

Expected: у каждого код выхода 0; `layout_check` печатает `RESULT: символы раскладки на месте`; `keycheck` — 0 `missing` (удалённые ключи не «висят»); `check.ps1` — `tests passed`.

- [ ] **Step 9: Ручная проверка в игре**

Собрать пак и скопировать (см. Task 3, шаги 1-4), затем в игре: MCM → Vostok Toolkit → General → есть Dropdown **Language** (English/Русский); смена пересобирает интерфейс мода на месте и не сбрасывает открытую вкладку; вкладка «Настройки» больше не имеет строки языка; язык переживает перезапуск.

---

### Task 2: Удалить вкладку «Настройки» целиком

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd` — `tabs` (:505), вызов `_build_settings_tab` (:541), `_init_later` (:206, :215), `_apply_hud` (:3212-3216), `_register_mcm` без MCM (:3395-3398), комментарий (:1954); удалить `_build_settings_tab` (:3078-3087), `_make_settings_header` (:3089-3097), `_make_toggle_row` (:3165-3199), `_kc_toggle` (:3201-3208), `_save_toggles` (:3020-3034), `_restore_toggles` (:3062-3076), `_save_mcm_bool` (:3252-3268); удалить `TOGGLE_CFG` (:3018), `_kc_btn` (:3016), `_kc_active` (:3009)
- Modify: `loadouts/mods/VTK/VTKLoc.gd` — удалить `'Settings'`, `'Interface'` (если останется), `'Modules'`, `'Kill counter'`, `'Shows the kill counter in the interface'`
- Modify: `README.md` — строка 31
- Modify: `.check/layout_check.py` — GONE (:129)

**Interfaces:**
- Consumes: после Task 1 единственный потребитель вкладки — тумблер счётчика убийств, продублированный MCM-настройкой `kill_counter_enabled`; `_apply_hud` (:3212) зовётся из `_mcm_apply`.
- Produces: `tabs = [Loc.txt("Sets"), Loc.txt("Teleport")]`; вкладок две.

**Контекст:** `_apply_hud` станет единственной точкой применения HUD; `_kc_active` (зеркало из json) исчезает — состояние приходит только из `_kc_mcm`. `_save_mcm_bool` вызывался лишь из `_kc_toggle`, вместе с ним уходит.

- [ ] **Step 1: Убрать вкладку из списка и её сборку**

Заменить `VTKUI.gd:505`:

```gdscript
	var tabs = [Loc.txt("Sets"), Loc.txt("Teleport")]
```

Удалить строку `VTKUI.gd:541`:

```gdscript
	_build_settings_tab(_tab_containers[Loc.txt("Settings")])
```

- [ ] **Step 2: Удалить функции вкладки, тумблера и работы с json**

Удалить целиком:
- `func _build_settings_tab(...)` (`:3078-3087`)
- `func _make_settings_header(...)` (`:3089-3097`)
- `func _make_toggle_row(...)` (`:3165-3199`)
- `func _kc_toggle(...)` (`:3201-3208`, включая комментарий `:3201-3203`)
- `func _save_toggles(...)` (`:3020-3034`)
- `func _restore_toggles(...)` (`:3062-3076`)
- `func _save_mcm_bool(...)` (`:3252-3268`, включая комментарий `:3252-3253`)

Класс `ToggleSwitch` (`:1921-...`) **остаётся**: им пользуется `_build_mag_panel` (`:2979`), вне вкладки.

- [ ] **Step 3: Удалить мёртвые объявления и мёртвый вызов**

- Удалить `const TOGGLE_CFG := "user://MCM/vostok-toolkit/ui_toggles.json"` (`:3018`).
- Удалить `var _kc_btn: Node = null` (`:3016`).
- Удалить `var _kc_active: bool = false` (`:3009`).
- Удалить вызов `_restore_toggles()` в `_init_later` (`:215`).
- Комментарий `VTKUI.gd:206-207` переписать без `_restore_toggles`:

```gdscript
	# Обе миграции - до _load_items и _register_mcm: обеим нужен готовый
	# каталог MCM/vostok-toolkit.
```

Оставшийся комментарий `VTKUI.gd:3270` (`# поэтому состояние кладём прямо в него...`) не ссылается на удалённое — не трогать.

- [ ] **Step 4: Упростить `_apply_hud`**

Заменить тело `_apply_hud` (`VTKUI.gd:3212-3216`) и обновить комментарий (`:3210-3211`):

```gdscript
# Единая точка применения обоих HUD-виджетов. Зовётся только из _mcm_apply:
# состояние приходит из MCM, отдельного UI-тумблера больше нет.
func _apply_hud() -> void:
	_set_counter_enabled(_kc_mcm)
	_set_feed_enabled(_feed_mcm)
```

- [ ] **Step 5: Ветка «MCM не установлен»**

Заменить `VTKUI.gd:3395-3398`:

```gdscript
	if not ResourceLoader.exists("res://ModConfigurationMenu/Scripts/Doink Oink/MCM_Helpers.tres"):
		_apply_hud()
		return
```

(`_kc_mcm`/`_feed_mcm` по умолчанию `true` — тот же результат, что был.)

- [ ] **Step 6: Починить комментарий у `ToggleSwitch`**

Заменить `VTKUI.gd:1954`:

```gdscript
	# button_pressed для совместимости с CheckButton-вызовами.
```

- [ ] **Step 7: Почистить осиротевшие ключи локали**

Свериться, что ключи больше не вызываются:

```powershell
rg -n --fixed-strings 'Loc.txt("Settings")' loadouts\mods\VTK
rg -n --fixed-strings 'Loc.txt("Modules")' loadouts\mods\VTK
rg -n --fixed-strings 'Loc.txt("Kill counter")' loadouts\mods\VTK
rg -n --fixed-strings 'Shows the kill counter in the interface' loadouts\mods\VTK
```

Ожидается: совпадения только внутри `VTKLoc.gd`. Удалить из `VTKLoc.gd`: `'Settings'` (:107), `'Interface'` (:178, если ещё не удалён), `'Modules'` (:179), `'Kill counter'` (`:55`), `'Shows the kill counter in the interface'` (`:180`).

- [ ] **Step 8: Обновить README**

Заменить строку 31 `README.md`:

```
- Сеты хранятся в `user://MCM/vostok-toolkit/VTKsets.json`; язык интерфейса — в MCM (General → Language).
```

Прочие упоминания `ui_toggles.json` в README удалить/привести в соответствие (проверить `rg -n --fixed-strings 'ui_toggles.json' README.md`).

- [ ] **Step 9: Дополнить GONE в `layout_check.py`**

В список `GONE` (перед закрывающей `]`, к записям Task 1) добавить:

```python
    # 4.13.7: вкладка «Настройки» удалена, её тумблер и json-хранилище тоже —
    # возврат любого из этих символов = откат плана.
    "_build_settings_tab",
    "_make_settings_header",
    "_make_toggle_row",
    "_kc_toggle",
    "_save_toggles",
    "_restore_toggles",
    "_save_mcm_bool",
    "TOGGLE_CFG",
    "ui_toggles.json",
    'Loc.txt("Settings")',
    "_kc_btn",
    "_kc_active",
```

- [ ] **Step 10: Проверить**

```powershell
py .check\layout_check.py
py .check\keycheck.py
py .check\encoding_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```

Expected: у каждого код выхода 0; `layout_check` — `RESULT: символы раскладки на месте`; `keycheck` — 0 `missing`; `check.ps1` — `tests passed`.

- [ ] **Step 11: Ручная проверка в игре**

В игре: вкладок ровно две — «Сеты» и «Телепорт»; вкладки «Настройки» нет; счётчик убийств и kill feed включаются/выключаются из MCM (раздел KillFeed) и применяются сразу; thermal/NVG/телепорт работают как раньше; хоткей UI из MCM применяется.

---

### Task 3: Версия 4.13.7, сборка, копия в игру, релизный коммит

**Files:**
- Modify: `loadouts/mod.txt` (`version`)
- Generated: `loadouts/mods/VTK/version.txt`, `README.md` (строка 7), `Loadouts.vmz` — всё пишет `pack.ps1`
- Staged: `loadouts/mods/VTK/VTKUI.gd`, `loadouts/mods/VTK/VTKLoc.gd`, `loadouts/mod.txt`, `loadouts/mods/VTK/version.txt`, `README.md`, `loadouts/mods/VTK/VTKNVG.gd`

**Interfaces:** `pack.ps1` печатает версию из `mod.txt`, переписывает `loadouts/mods/VTK/version.txt` и синхронизирует первую «**Label:** <digits>» строку README.

- [ ] **Step 1: Поднять версию**

В `loadouts/mod.txt` заменить `version="4.13.6"` на `version="4.13.7"`.

- [ ] **Step 2: Прогнать все стенды**

```powershell
py .check\layout_check.py
py .check\keycheck.py
py .check\encoding_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```

Expected: у каждого код выхода 0; `check.ps1` печатает `tests passed`.

- [ ] **Step 3: Собрать пак**

```powershell
powershell -ExecutionPolicy Bypass -File pack.ps1
```

Expected: вывод содержит `Version in mod.txt: 4.13.7`, `+ mods/VTK/version.txt (4.13.7)`, создан `Loadouts.vmz`. (pack.ps1 также синхронизирует версию в README.md — строка 7 станет `4.13.7`.)

- [ ] **Step 4: Скопировать пак в игру**

```powershell
Copy-Item -LiteralPath "D:\RTVMOD\Loadouts.vmz" -Destination "D:\SteamLibrary\steamapps\common\Road to Vostok\mods\Loadouts.vmz" -Force
```

Проверить рейл: в игре версия показывает `v4.13.7`.

- [ ] **Step 5: Финальная ручная проверка в игре**

Пройти разом: вкладок две; Dropdown Language в MCM General переключает язык на месте и переживает перезапуск; счётчик убийств и kill feed — из MCM; thermal/NVG/телепорт/хоткей работают.

- [ ] **Step 6: Релизный коммит (по явному согласию пользователя)**

Стейджить **только** файлы мода и релиза (не `git add -A`):

```powershell
git add loadouts/mods/VTK/VTKUI.gd loadouts/mods/VTK/VTKLoc.gd loadouts/mod.txt loadouts/mods/VTK/version.txt README.md
git status --short
git diff --cached --stat
```

Проверить `git status`: `VTKNVG.gd` остаётся как чужая правка (не в индексе), если пользователь не попросил иначе.

Затем (только после согласия пользователя):

```powershell
git commit -m "feat: язык интерфейса в MCM, вкладка «Настройки» удалена (4.13.7)"
```

Если пользователь просит включить правку `VTKNVG.gd` «как есть» — добавить `loadouts/mods/VTK/VTKNVG.gd` в стейджинг перед коммитом.

---

## Self-Review

**Spec coverage** (по `2026-10-11-language-in-mcm-design.md`):
1. Регистрация Dropdown `language` в `CAT`, `menu_pos 2` → Task 1 Step 1. ✅
2. `_load_lang` читает `config.ini`, имя сохранено → Task 1 Step 2. ✅
3. `_mcm_apply` — живое применение + `_rebuild_ui` по позиции вкладки, до раннего return по NVG → Task 1 Steps 3-4. ✅
4. Удаление вкладки целиком (tabs, вызов, функции, decls, ветка без MCM, комментарии, `_apply_hud`) → Task 2. ✅
5. Локаль: удалить `Settings`, `Interface`, `Interface language`, `Modules`, `Shows the kill counter in the interface`, `Switch between English and Russian`, `Kill counter`; новых ключей нет → Task 1 Step 7 + Task 2 Step 7. ✅
6. README: язык в MCM → Task 2 Step 8. ✅
7. `layout_check.py`: GONE/FUNCS/PRESENT → Task 1 Step 9, Task 2 Step 9. ✅
8. Версия 4.13.7 + pack + копия → Task 3. ✅

**Отклонения от спеки (осознанные):**
- Спека не назвала `_save_mcm_bool` среди удаляемого, но он вызывался только из `_kc_toggle` и после Task 2 становится мёртвым — удаляется (Task 2 Step 2).
- Спека держала `_lang_btns` в общем списке удаления; перенёс в Task 1 вместе с языковым ряд (там он и осиротел).
- Коммитов по задачам нет (установка пользователя — один релизный коммит) → только Task 3 Step 6.

**Placeholder scan:** нет TODO/TBD; все шаги содержат точный код/команды.

**Type consistency:** `_rebuild_ui()` — новая функция без аргументов и возврата; зовётся из `_mcm_apply` (Void) и всё. `_load_lang()` сигнатура не менялась (`-> void`). `_apply_hud()` — по-прежнему `-> void`, без `_kc_btn`/`_kc_active`. `_mcm_key_val(cfg, "Dropdown", "language", Loc.get_lang())` — 4-й аргумент Variant, возвращает `value` из словаря (String). `_tab_btns[i] as Button` — элементы массива всегда `Button` (`:507-515`).

**Риск, незакрытый спекой:** после Task 1 (до Task 2) вкладка «Настройки» содержит только заголовок `Modules` и тумблер счётчика — промежуточное состояние, но полностью рабочее; закрывается Task 2. Если `config.ini` пользователя правится вручную до релиза и `[Dropdown] language` содержит `"fr"`, `set_lang` отбросит значение, пересборки нет — ожидаемо.
