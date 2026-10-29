# Мелкие правки UI батча 4 (обнаружены в игре)

Дата: 2026-10-14
Целевая версия: 4.17.3 (патч: правки существующего функционала, без новых фич и без смены формата данных)

## Проблема

Прогон 4.17.2 в игре выявил семь мелких дефектов в UI-слое, добавленном в батче 4
(клетка снаряжения, kill stats, kill feed). Все — косметика/эргономика, логика набора
не меняется.

**A. Тумблер обоймы вылезает за клетку.** Кнопка `_make_full_mag_btn` (`VTKUI.gd:1300`)
рисует `Loc.txt("Full magazine") if on else Loc.txt("Empty")` через `_style_full_btn`
(`VTKUI.gd:1278`). Текст «● Полная обойма» при шрифте темы шире `GEAR_CELL_W = 128`
(`VTKUI.gd:1099`) — кнопка выходит за пределы клетки.

**B. Кнопка обвесов — длинная текстовая.** `_make_att_btn` (`VTKUI.gd:2611`) даёт кнопку
`Loc.txt(" rnd.") + N` в ряду B клетки. Занимает строку, текст вместо иконки.

**C. Клик по числу открывает поле ввода.** `_make_gear_count` (`VTKUI.gd:1332`) по клику
на `Label` открывает `LineEdit` (`_open_gear_amount_edit`, `:1354`). Поле наезжает на «+»
и мешает; фича на практике не нужна.

**D. Число в степпере прижато влево.** `holder` в `_make_gear_count` — голый `Control`
(не контейнер), поэтому дочерний `Label` встаёт в левый верхний угол; `size_flags` и
`horizontal_alignment` вне контейнера не действуют. Вид: `− N ......... +` вместо
`− ..... N ..... +`.

**E. «Только выбранные» показывает надетое.** `_rebuild_gear_grid` (`VTKUI.gd:1574`)
фильтрует по `_draft.has_path(...)`, а `has_path` истинно и для экипировки
(`VTKDraft.has_path:127`, зовёт `equip_slot_of`). В списке «Снаряжение» появляются
предметы из слотов экипировки — путает.

**F. Kill stats не видно на солнце.** `VTKKillCounter._ready` (`VTKKillCounter.gd:17`)
рисует голый `Label` цветом `#e6d9b3` без подложки; на светлом фоне надписи теряются.

**G. KillFeed: хвост `_N` у имён.** `agent_display_name` (`VTKKillCounter.gd:105`) для
идентификатора `AI_Nomad_2` делает `substr(3)` → `Nomad_2`. Хвост `_<цифры>` попадает в
ленту.

## Цели

1. Тумблер обоймы — короткая подпись, влезает в клетку.
2. Обвесы открываются иконкой-шестернёй в **левом верхнем углу** клетки (зеркально ✕ справа),
   без текста и без tooltip.
3. Клик по числу больше не открывает ввод; количество меняется только «−/+».
4. Число стоит по центру между «−» и «+».
5. «Только выбранные» в Снаряжении показывает **только** элементы списка снаряжения, без надетого.
6. У Kill stats — полупрозрачная тёмная подложка (как у строки KillFeed).
7. В ленте убийств имена без хвоста `_<цифры>`.

## Не-цели

- Не трогаем логику сета: `Draft`, применение, стек, клампы, `full_mag`, `count`.
- Не трогаем шаг 1 (каталог/экипировка) и экипировочную сетку.
- Не меняем позицию и логику Kill stats/ленты сверх подложки и нормализации имени.
- Не трогаем панель обвесов (`_build_att_panel`/`_build_mag_panel`) и тумблер внутри оверлея.
- Не вводим новых настроек MCM.

## Дизайн

### 1. Короткие подписи тумблера обоймы

`_make_full_mag_btn` (`VTKUI.gd:1300`):

```gdscript
_style_full_btn(b, on, Loc.txt("Full mag") if on else Loc.txt("Empty mag"))
```

Новые ключи в `VTKLoc.RU`: `'Full mag'` → `'Полная'`, `'Empty mag'` → `'Пустая'`.
Ключ `'Full'` занят кнопкой патронов «Full · N» (`_make_full_ammo_btn:1289`) и его RU
`'Полный'` (мужской род) — поэтому отдельные ключи, а не переиспользование.
Точку `●` (даёт `_style_full_btn`) сохраняем.

### 2. Шестерёнка обвесов в левый верхний угол

`_make_att_btn` (`VTKUI.gd:2611`) становится иконкой без текста:

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

`VTKSurface.gear_icon(size, color)` (`VTKSurface.gd:38`) уже существует (используется в
метке вложения у экипировки, `VTKUI.gd:1873`) — новых SVG нет. Tooltip не ставим.

`_make_gear_action_row` (`VTKUI.gd:1315`) перестаёт отдавать обвесную кнопку в ряд B
(остаются mag/ammo, иначе `null`):

```gdscript
if _is_magazine(path):
	return _make_full_mag_btn(path, desc)
if str(_item_info(path).get("type")) == "Ammo":
	return _make_full_ammo_btn(path, desc)
return null
```

В gear-ветке `_make_item_cell` (`VTKUI.gd:2779`) кнопка-шестерёнка добавляется в угол
клетки тем же приёмом, что и ✕ (anchors+offsets), но `PRESET_TOP_LEFT`:

```gdscript
if _att_panel_needed(_item_info(path_now)):
	var gear_btn := _make_att_btn(desc_g)
	cell.add_child(gear_btn)
	gear_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	gear_btn.offset_left = 2
	gear_btn.offset_top = 2
	gear_btn.offset_right = 22
	gear_btn.offset_bottom = 22
```

✕ остаётся `PRESET_TOP_RIGHT` — стенд `layout_check.py:318` требует `PRESET_TOP_RIGHT`
в теле `_make_item_cell`, поэтому прежний крестик не убираем.

### 3-4. Центрированный, некликабельный счётчик

`_make_gear_count` (`VTKUI.gd:1332`) — `holder` из `Control` в `CenterContainer`,
удаляем `gui_input` и открытие редактора:

```gdscript
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

`CenterContainer` центрирует число между «−» и «+». Параметр `path` больше не нужен —
сигнатура `_make_gear_count(cnt)`; вызов `_make_item_cell:2793` обновить на
`_make_gear_count(cnt_g)`.

Удалить осиротевшие `_open_gear_amount_edit` (`VTKUI.gd:1354-1383`) и `_gear_edit_cap`
(`:1326-1328`) — они нужны были только вводу числа.

### 5. «Только выбранные» без надетого

`_rebuild_gear_grid` (`VTKUI.gd:1574-1580`): фильтр по `_draft.has_path(...)` заменить на
только-снаряжение:

```gdscript
if _gear_only_selected and _draft != null:
	var picked: Array = []
	for e in found:
		var res_it = e.get("item")
		if res_it != null and _draft.gear_index_of(str(res_it.resource_path)) >= 0:
			picked.append(e)
	found = picked
```

`gear_index_of` (`VTKDraft.gd:121`) истинно только для элементов списка снаряжения —
экипировка исключается.

### 6. Подложка Kill stats

`VTKKillCounter._ready` (`VTKKillCounter.gd:17`): `Label` оборачиваем в `PanelContainer`
со `StyleBoxFlat` (чёрный 0.45, как строка ленты — `VTKFeed.gd:130-136`). Новое поле
`var _panel: PanelContainer = null`.

```gdscript
func _ready() -> void:
	name = "VTKKillCounter"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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

`set_enabled` (`:31`): переключать видимость `_panel` вместо `_label`
(`_panel.visible = v`; обнуление счётчиков и `_label.text = ""` — как есть). Панель чуть
сдвигает низ текста вниз (padding ≈ 2px) — при необходимости позицию `(10,10)` уменьшить
до `(10,8)` после проверки в игре.

### 7. Хвост `_N` в именах ленты

В `VTKKillCounter.gd` добавить чистую static-нормализацию и применить её к имени из `AI_`:

```gdscript
# "Nomad_2"/"Nomad2" -> "Nomad": у пулов игра клеит хвост к имени узла.
static func clean_ai_name(s: String) -> String:
	var i := s.length()
	while i > 0 and s.unicode_at(i - 1) >= 48 and s.unicode_at(i - 1) <= 57:
		i -= 1
	if i < s.length() and i > 0 and s.unicode_at(i - 1) == 95:  # '_'
		i -= 1
	return s.substr(0, i)
```

В `agent_display_name` (`:105`) ветку `AI_` заменить на
`return clean_ai_name(s.substr(3))`. Модельные имена (`Bandit`, `Nomad`, `Punisher`,
`NPC`) цифр не несут — не трогаем.

### Локализация

`VTKLoc.RU`:
- добавить `'Full mag'` → `'Полная'`, `'Empty mag'` → `'Пустая'`;
- удалить ставшие неиспользуемыми `' rnd.'` (`:18`) и `'Empty'` (`:44`) — `keycheck.py`
  иначе пометит их как stale.

## Точки изменения

| Файл | Что |
|---|---|
| `loadouts/mods/VTK/VTKUI.gd` | `_make_full_mag_btn` (подписи), `_make_att_btn` (иконка), `_make_gear_action_row` (убрать обвесную ветку), `_make_item_cell` (шестерёнка в углу; вызов счётчика), `_make_gear_count` (CenterContainer, без клика), удалить `_open_gear_amount_edit`/`_gear_edit_cap`, `_rebuild_gear_grid` (фильтр) |
| `loadouts/mods/VTK/VTKKillCounter.gd` | подложка (`_panel`), `clean_ai_name` + `agent_display_name` |
| `loadouts/mods/VTK/VTKLoc.gd` | +`'Full mag'`/`'Empty mag'`, −`' rnd.'`/`'Empty'` |
| `.check/project/tests/` | тест `clean_ai_name` (headless) |
| `CHANGELOG.md` | `## [4.17.3]` |
| `loadouts/mod.txt`, `loadouts/mods/VTK/version.txt`, `README.md` | 4.17.3 (в таске релиза) |

`VTKSurface.gd` не меняется (`gear_icon` уже есть). Стенды `layout_check.py` — правок
списков не требуют (`PRESET_TOP_RIGHT` в `_make_item_cell` сохраняем).

## CHANGELOG (видимый игроку эффект)

`## [4.17.3] - 2026-10-14`

### Changed
- «Magazine Full/Empty toggle is shorter and fits the gear cell.»
- «Attachments now open from a gear icon in the cell's corner.»
- «Gear count is centered between − and +; click-to-type removed.»

### Fixed
- «"Only selected" no longer lists items already worn in equipment.»
- «Kill stats got a background so they stay readable in daylight.»
- «Kill feed no longer appends a number suffix to enemy or Nomad names.»

## Тестирование

- Headless (`check.ps1`): новый тест `clean_ai_name` — `"Nomad_2"`→`"Nomad"`,
  `"Bandit7"`→`"Bandit"`, `"Nomad"`→`"Nomad"`, `"AI_"`→`""`. Тест добавить в `$tests`
  (`.check/check.ps1:105`); имя файла — `test_killcounter.gd` (или влить в существующий
  `test_feed.gd`). Функция чистая, статическая — грузится headless.
- `layout_check.py` — зелёный без правок списков.
- `keycheck.py` — без новых stale: `' rnd.'`/`'Empty'` удалены, `'Full mag'`/`'Empty mag'`
  используются в коде.
- Ручная проверка в игре:
  1. Тумблер обоймы умещается в клетку, читается в обоих состояниях.
  2. У клетки с обвесами шестерёнка в левом верхнем углу открывает панель; цвет золотой
     при наличии выбранных обвесов, серый без.
  3. Клик по числу ничего не открывает; «−/+» меняют количество.
  4. Число по центру между «−» и «+».
  5. «Только выбранные» в Снаряжении не показывает надетое.
  6. Надписи Kill stats видны на светлом фоне.
  7. В ленте убийств имена без `_N`.

## Риски

- **Позиция Kill stats**: подложка добавляет ~2px по вертикали (content margin). Если
  надпись слегка съедет вниз — поправить `_panel.position.y` (10 → 8). Проверяется глазами.
- **`_make_gear_count` без `path`**: если позже понадобится редактирование по пути, сигнатуру
  придётся вернуть; сейчас `path` в теле не использовался ни для чего, кроме ввода (удаляемого).
- **Шестерёнка в углу**: `Button` с `icon` рисует иконку по центру кнопки; при
  `STYLE_*` темы иконка может смещаться — `expand_icon = true` и `custom_minimum_size`
  (20×20) держат её; проверяется глазами.
- **Точный вид хвоста**: пользователь сообщил `_N`; `clean_ai_name` срезает и `_N`, и голый
  `N`. Если в игре хвост окажется иным (например, `@N`), нормализацию дополнить.

## Открытые вопросы

Нет.
