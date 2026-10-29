# Язык интерфейса в MCM — дизайн

Статус: **предложено, ждёт ревью пользователя**.

Версия релиза: **4.13.7** (решение пользователя — фикс, вкладку считаем
косметикой без ломающих изменений).

## Проблема

Переключение языка — последняя настройка мода, которая живёт вне MCM.
Она хранится в отдельном файле `user://MCM/vostok-toolkit/ui_toggles.json`
(`{"kc": ..., "lang": ...}`) и правится только сегментированной кнопкой во
вкладке «Настройки» самого мода (`_make_lang_row`, `VTKUI.gd:3099`;
`_on_lang_button`, `:3153`). Всё остальное (хоткей UI, thermal/NVG, телепорт,
счётчик убийств, kill feed) уже регистрируется в MCM (`_register_mcm`,
`VTKUI.gd:3394`) и лежит в `user://MCM/vostok-toolkit/config.ini`.

После ухода языка вкладка «Настройки» (`_build_settings_tab`, `:3078`) теряет
смысл: её второй и последний потребитель — тумблер счётчика убийств
(`_kc_toggle`, `:3204`), а он и так пишет в MCM (`_save_mcm_bool`, `:3254`) и
продублирован настройкой `kill_counter_enabled`. Прецедент уже есть:
thermal/NVG/телепорт ранее вынесены из вкладки в MCM (комментарий `:3526`).

## Решение

Язык переезжает в MCM типом **Dropdown**; вкладка «Настройки» удаляется
целиком (источник правды — `config.ini`, как у остальных настроек).

### 1. Регистрация в MCM (`_register_mcm`, `VTKUI.gd:3394`)

В категорию `01. General` (`CAT`, `:3403`) добавить Dropdown-настройку:

```gdscript
cfg.set_value("Dropdown", "language", {
    "name": "Language",
    "default": Loc.DEFAULT,
    "value": Loc.get_lang(),
    "options": {"en": "English", "ru": "Русский"},
    "category": CAT,
    "menu_pos": 2,
    "tooltip": "Interface language of the Loadouts window. English is the source language.",
})
```

- `menu_pos = 2` — после `key_ui_toggle` (0) и `nvg_debug_probe` (1).
- Существующая логика слияния (`:3446-3460`) сохраняет пользовательский
  `value` для уже существующего ключа; новый ключ получает
  `value = Loc.get_lang()` (по умолчанию `en`).
- MCM к типу `Dropdown` требует `name`, `tooltip`, `default`, `options`
  (`MCM_Validation.gd`, `REQUIRED_PROPERTIES`); `options` как Dictionary
  трактует значение как ключ словаря (`"en"`/`"ru"`).
- Подписи опций — литералы «English»/«Русский» на своём языке, как
  `Loc.code_label()` (`VTKLoc.gd:201`); ключом локали не являются.

### 2. Чтение языка (`_load_lang`, `VTKUI.gd:3036`)

Имя функции сохраняется (вызов `_init_later:213` не трогаем), тело
меняется: вместо `ui_toggles.json` читаем `config.ini`.

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

`Loc.set_lang` (`VTKLoc.gd:187`) сам отбрасывает недопустимые коды, поэтому
дополнительная валидация не нужна. Файла нет / ключа нет → остаётся `en`.

### 3. Живое применение и пересборка (`_mcm_apply`, `VTKUI.gd:3499`)

В начале функции (до раннего `return` по NVG на `:3512-3513`, чтобы язык
применялся независимо от состояния NVG):

```gdscript
var want := str(_mcm_key_val(cfg, "Dropdown", "language", Loc.get_lang()))
if want != Loc.get_lang():
    Loc.set_lang(want)
    if Loc.get_lang() == want:
        _rebuild_ui()
```

`_rebuild_ui()` — новый маленький хелпер рядом с `_clear_ui` (`:3052`):

```gdscript
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

`_clear_ui` не сбрасывает `_current_tab`, но чистит `_tab_btns`; `_build_ui`
заканчивается `_switch_tab(Loc.txt("Sets"))` (`:544`). Восстанавливать
открытую вкладку **по имени нельзя**: `_current_tab` хранит локализованную
строку (`"Sets"`/`"Teleport"`), а после смены языка имена меняются
(«Сеты»/«Телепорт»), и `_tab_containers.has(tab)` не найдёт ключ. Поэтому
запоминаем **позицию** активной кнопки в `_tab_btns` до пересборки и
возвращаемся на неё после. HUD/NVG живут на `get_tree().root`, не в
`_ui_nodes`, и пересборку переживают.

Проверка `Loc.get_lang() == want` после `set_lang` защищает от цикла на
неизвестном коде (например `"fr"`): невалидное значение ничего не меняет и
пересборки нет.

### 4. Удаление вкладки «Настройки»

- `tabs` (`:505`): список становится `[Loc.txt("Sets"), Loc.txt("Teleport")]`.
- Убрать вызов `_build_settings_tab(_tab_containers[Loc.txt("Settings")])`
  (`:541`).
- Удалить ставший мёртвым код:
  `_build_settings_tab` (`:3078`), `_make_settings_header` (`:3089`),
  `_make_lang_row` (`:3099`), `_make_seg_btn_style` (`:3150`),
  `_on_lang_button` (`:3153`), `_make_toggle_row` (`:3165`),
  `_kc_toggle` (`:3204`), `_save_toggles` (`:3020`),
  `_restore_toggles` (`:3062`).
- Удалить объявления: `_lang_btns` (`:106`), `_kc_btn` (`:3016`),
  `_kc_active` (`:3009`), `TOGGLE_CFG` (`:3018`).
- `_apply_hud` (`:3212`) упрощается — убираются строки про `_kc_active` и
  `_kc_btn`, остаются `_set_counter_enabled(_kc_mcm)` и
  `_set_feed_enabled(_feed_mcm)`.
- Ветка «MCM не установлен» (`_register_mcm:3395-3398`): вместо
  `_kc_mcm = _kc_active` просто вызвать `_apply_hud()` (значения по
  умолчанию `_kc_mcm`/`_feed_mcm` уже `true`).
- Комментарии-ссылки на удалённое поправить: `_init_later` (`:206` — убрать
  `_restore_toggles`), `_build_page_done` (`:1954` — убрать упоминание
  `_restore_toggles`).

`_attach_row_hover` (`:994`) используется и вне вкладки (`:915`, `:1388`,
`:1664`, `:2377`, `:3564`) — остаётся.

### 5. Локаль (`VTKLoc.gd`)

После удаления вкладки становятся stale (единственный потребитель — вкладка
«Настройки») и удаляются из `RU`:

- `'Settings'` (`:107`) — имя вкладки.
- `'Interface'` (`:169`) — заголовок секции.
- `'Modules'` (`:170`) — заголовок секции.
- `'Interface language'` (`:52`) — метка строки.
- `'Shows the kill counter in the interface'` (`:172`) — подпись тумблера.
- `'Switch between English and Russian'` (`:316`-соседний ключ) — подпись.
- `'Kill counter'` (`:55`) — использовался только как метка тумблера
  (в MCM имя настройки — литерал `"Kill counter"`, не ключ локали).

Новых ключей нет. `keycheck.py` валится только на отсутствующих переводах
(`missing`), stale — предупреждение, но по регламенту чистим.

### 5a. README (`README.md`)

Строка 31 сейчас утверждает, что язык хранится в `ui_toggles.json` —
обновить: язык выставляется в MCM (General → Language). Прочие строки о
`ui_toggles.json` (если останутся) привести в соответствие.

## Точки изменений

| Что | Где |
|---|---|
| Dropdown `language` в `CAT` | `VTKUI.gd:3403-3405` |
| Чтение `config.ini` вместо json | `VTKUI.gd:3036-3050` |
| Язык + пересборка в `_mcm_apply` | `VTKUI.gd:3499` |
| `_rebuild_ui` (новый) | `VTKUI.gd` рядом с `_clear_ui:3052` |
| `tabs` минус Settings | `VTKUI.gd:505` |
| Убрать вызов `_build_settings_tab` | `VTKUI.gd:541` |
| Удалить функции вкладки/языка | `VTKUI.gd:3020-3208` |
| Упростить `_apply_hud` | `VTKUI.gd:3212` |
| Ветка без MCM | `VTKUI.gd:3395-3398` |
| Комментарии `:206`, `:1954` | `VTKUI.gd` |
| Loc: удалить stale-ключи | `VTKLoc.gd` |
| Стенд раскладки: GONE/FUNCS/PRESENT | `.check/layout_check.py` |
| README: язык в MCM | `README.md` |
| Версия | `loadouts/mod.txt`, `loadouts/mods/VTK/version.txt` |

## Локализация

Ключи `Settings`, `Interface`, `Modules`, `Interface language`,
`Shows the kill counter in the interface`, `Switch between English and
Russian`, `Kill counter` удаляются как осиротевшие. Новых ключей нет: подписи
опций Dropdown — литералы своего языка, имя/tooltip настройки MCM — обычные
английские строки (MCM их не локализует, как и у остальных настроек).

## Стенды

`.check/layout_check.py`:

- `GONE`: добавить маркеры возврата удалённого —
  `_build_settings_tab`, `_make_settings_header`, `_make_lang_row`,
  `_make_seg_btn_style`, `_make_toggle_row`, `_kc_toggle`, `_save_toggles`,
  `_restore_toggles`, `TOGGLE_CFG`, `ui_toggles.json`,
  `Loc.txt("Settings")`.
- `FUNCS` (`:279-280`): запись `("_make_lang_row", …)` удалить — иначе
  `NOFUNC`.
- `PRESENT`: добавить маркеры новой регистрации — `"Dropdown"` и
  `'"language"'`.
- `GONE_RE`, `HOOKS_GONE` не трогаем.

`check.ps1`, `keycheck.py`, `encoding_check.py` — правок кода не требуют.
Новый headless-тест не добавляем: логика чтения языка завязана на файл
`config.ini` и пересборку сцены, headless её не покрывает осмысленно.

## Проверка

- `python .check\layout_check.py` — GONE/PRESENT/FUNCS зелёные.
- `python .check\keycheck.py` — 0 missing (удалённые ключи не «висят»).
- `python .check\encoding_check.py` — PROBLEMS: 0.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1` —
  парсинг всех `.gd` + headless-тесты (`tests passed`, код 0, без
  `SCRIPT ERROR`/`Parse Error`/`Invalid call`/`Failed to load script`).
- Ручная проверка в игре:
  - вкладок две — «Сеты» и «Телепорт»; вкладки «Настройки» нет;
  - в MCM (General) есть Dropdown «Language» (English/Русский); смена
    пересобирает интерфейс мода на выбранном языке на месте;
  - язык переживает перезапуск (значение из `config.ini`);
  - счётчик убийств и kill feed по-прежнему включаются из MCM;
  - thermal/NVG/телепорт применяются как раньше.

## Вне области

- Миграции нет: старый `ui_toggles.json` не читается и не пишется, на диске
  не трогается. После обновления язык у всех — `en` до ручной установки.
- Формат `VTKsets.json`, логика сетов, депозитов, Notes, хуков — без
  изменений.
- Незакоммиченные правки параллельного процесса (бамп 4.13.6 и строка
  `"node": node` в `VTKNVG.gd`) не трогаются; релизный коммит включит их как
  есть.
- Версия в `loadouts/mod.txt` и `loadouts/mods/VTK/version.txt` — поднять до
  4.13.7 перед сборкой.
