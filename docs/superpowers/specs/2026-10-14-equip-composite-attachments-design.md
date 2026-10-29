# Composite оружия с обвесами в клетках экипировки

Дата: 2026-10-14
Целевая версия: 4.17.0 (новая функциональность → minor)

## Проблема

Клетка экипировки рисует предмет одной обрезанной иконкой (`Picker.item_art` от `res.icon`).
Оружие с обвесами выглядит так же, как оружие без них: навешанные прицел/магазин/дуло не видны.
Отдельный бейдж с числом обвесов (вариант D из обсуждения) показывает только их количество, не состав.

Ваниль в экране персонажа (TAB) показывает оружие **вместе с обвесами**. Нашли как: это не картинка,
а сцена `tetris` из ресурса оружия.

## Данные ресурса (проверено headless)

- Оружие `type == "Weapon"`. Ресурс несёт `tetris` — `PackedScene`, корень `Sprite2D` с текстурой,
  равной `res.icon` (`Icon_<File>.png`). У корня **по одному дочернему `Sprite2D` на каждый совместимый
  обвес**, имя ребёнка == поле `file` ресурса обвеса (`ACOG`, `AKM_Magazine`, `PBS`, …). Дети лежат
  заранее расставленными в 64-пиксельной сетке (свои `position`/`scale`/`rotation`).
- Пакеты масштаб+смещение на ресурсе оружия (по классам навешанного):
  `magazineScale/Offset`, `opticScale/Offset`, `suppressorScale/Offset`,
  `magazineOpticScale/Offset`, `magazineSuppressorScale/Offset`, `opticSuppressorScale/Offset`,
  `fullyModdedScale/Offset`. Скалярные `*Scale` — float; одиночные `*Offset` — float, парные — `Vector2`.
  Пример AKM: `suppressorScale=0.45`, `fullyModdedOffset=(-20, 0)`.
- `res.size` — габарит в единицах сетки (AKM `(6,2)`, Vest `(3,4)`).
- **Композитных детей нет** ни у оружия вне `Weapon`, ни у ригов/шлемов/рюкзаков:
  `Vest_Fishing`, `K19`, `Helmet_Police` → `tetris` есть, детей 0. Плита/визор картинкой не рисуются.
- Класс обвеса берём из `subtype` ресурса: `Optic` → optic, `Muzzle` → suppressor, `Magazine` → magazine
  (ровно как `Item.UpdateAttachments`/`UpdateSprite`).
- В драфте обвесы хранятся **путями** (`VTKDraft.set_attachments`). `file`/`subtype` достаются через
  `_item_info(path).resource`.
- Плиту берут не все риги: `K19.compatible` = 5 плит, `Vest_Fishing.compatible` = 0.

## Цели

1. Клетки оружия (Primary/Secondary) в экипировке, превью и на странице «Готово» рисуют сцену `tetris`
   с включёнными спрайтами навешанных обвесов и правильным пакетом масштаб+смещение. Поворот для
   непистолетного оружия — как сейчас (`_rotates_icon`).
2. Клеткам, где вложение есть, но композита в игре нет (Rig/плита, NVG, Player), — **голая шестерёнка ⚙**
   (без числа) в левом верхнем углу как признак наличия вложения.
3. Мелкие правки того же батча: убрать золотую точку занятости; ✕ увести в правый верхний угол и
   увеличить по размеру клетки; на странице «Готово» у кнопки хоткея убрать `font_size`-оверрайд.

## Не-цели

- Композит для не-оружейных слотов не делаем: игра его не рисует.
- Плиту/визор картинкой не рисуем — только признак ⚙.
- Число обвесов на маркере не показываем: у рига одна плита, у NVG/Player вложение единично, у оружия
  состав виден на модели.
- Каталог (шаг 1), полки, стена инвентаря остаются на `Picker.item_art` — там базовые предметы без сета.

## Дизайн

### Чистая функция выбора пакета — `VTKPicker.gd`

```
static func attachment_class(subtype) -> String      # "optic" | "muzzle" | "magazine" | ""
static func composite_pack(res, classes: Array) -> Dictionary
    # -> {"scale": float, "offset": Vector2}
```

- `attachment_class` — по `subtype` (`Optic`/`Muzzle`/`Magazine`), иначе `""`.
- `composite_pack` берёт `res` (оружие) и набор классов, читает `opticsScale`-поля через `res.get(...)`
  и повторяет ванильную цепочку `Item.UpdateSprite`:
  | Набор | Scale | Offset |
  |---|---|---|
  | только magazine | `magazineScale` | `magazineOffset` |
  | только optic | `opticScale` | `opticOffset` |
  | только muzzle | `suppressorScale` | `suppressorOffset` |
  | magazine+optic | `magazineOpticScale` | `magazineOpticOffset` |
  | magazine+muzzle | `magazineSuppressorScale` | `magazineSuppressorOffset` |
  | optic+muzzle | `opticSuppressorScale` | `opticSuppressorOffset` |
  | все три | `fullyModdedScale` | `fullyModdedOffset` |
  | ничего | `0.5` | `Vector2.ZERO` |
- Скалярные одиночные offset приводятся к `Vector2` (ось выбирает вызывающий при повороте — как ваниль).
- Функция чистая: ни `load()`, ни путей внутрь игры — только поля переданного ресурса. Тестируется headless
  на фейковом ресурсе. Формат `res.get(field, default)` устойчив к отсутствию поля (не падает на пустом).

### Рендер в клетке — `VTKUI.gd::_make_equip_cell`

Ветка выбора отрисовки (заменяет текущий блок `tex := _item_icon(...)` / `CenterContainer`):

1. `res := _cell_resource(src)`. Если `res != null`, `res.get("tetris") != null` и
   `str(res.get("type")) == "Weapon"` → **композит**:
   - `var scene = res.get("tetris")`; `var node: Node2D = scene.instantiate()`.
   - Собрать множество `file` навешанных обвесов: для каждого пути из `src["attachments"]`
     `res_file = _item_info(path).resource.get("file")`, класс — из `subtype`.
   - Спрятать всех детей, показать тех, чей `name` в множестве `file`.
   - `composite_pack(res, classes)` → `scale`/`offset`.
   - Фит: база `res.size` (сетка) × 64; при `_rotates_icon` — поменять местами оси; равномерный масштаб
     `fit = min((w_cell - pad)/base_x, (h_cell - pad)/base_y)`; итоговый масштаб узла
     `fit * pack.scale / 0.5`; смещение пакета — в 64-пространстве, домножается на `fit`.
   - `node.rotation_degrees = -90` при `_rotates_icon`, иначе 0; центрируется в клетке.
   - Узел добавляется в `box` первым (ниже глифа и ✕). `clip_contents` клетки обрезает вылеты (дуло).
2. Иначе — прежний путь: `tex := _item_icon(...)`; есть текстура → `CenterContainer` + `TextureRect`
   с `Picker.item_art`; нет — `Label` с именем слота.

### Глиф присутствия

- Рисуется, когда у слота непустой `attachments` **и** ветка композита не сработала (Rig/NVG/Player).
- Отдельный `Panel`/`TextureRect` из `VTKSurface.svg_texture` — голая шестерёнка золотым, без числа, в
  левом верхнем углу. Размер по клетке по `max(w,h)`: `>= 6` → L, `4..5` → M, `= 2` → S, `= 1` → XS
  (фактически встречаются S для 2×2/2×1 и XS для 1×1; L/M — фолбэк, если композит почему-то не сработал).
- Глиф в `VTKSurface.gd`: новая `static func gear_icon(size: int, color: Color) -> Texture2D`,
  собирает SVG-строку и отдаёт через `svg_texture` (кэш общий). Своя иконка, а не символ шрифта: шрифт
  игры может не содержать U+2699.

### Правки клетки

- Убрать `_make_dot` из `_make_equip_cell` (строки ~1702–1708). Сам `_make_dot` оставить — он ещё нужен
  на полке (`VTKUI.gd:1397`).
- ✕ (`_make_mini_btn`) — правый верхний угол, размер по клетке: L 26, M/S 22, XS 18; шрифт 14/12/10.
  Сейчас 16×16 в левом верхнем углу.

### Кнопка хоткея на странице «Готово»

- `_build_page_done` (строка 1538): убрать `_bind_btn.add_theme_font_size_override("font_size", 10)`.
  Кнопка идёт через `_apply_qk_btn` → `VTKSurface.style_button` и без оверрайда совпадёт по высоте с
  «Save loadout»/«Cancel».

## Точки изменения

| Файл | Что |
|---|---|
| `loadouts/mods/VTK/VTKPicker.gd` | `attachment_class`, `composite_pack` (новые, чистые) |
| `loadouts/mods/VTK/VTKSurface.gd` | `gear_icon` (SVG-шестерёнка) |
| `loadouts/mods/VTK/VTKUI.gd` | `_make_equip_cell` (композит + глиф + ✕ + удаление точки), `_build_page_done` (оверрайд), хелперы фита/пака |
| `loadouts/mods/VTK/VTKLoc.gd` | ключи, если понадобятся (вероятно, нет) |
| `.check/project/tests/` | новый `test_composite.gd` или дополнение к `test_picker.gd`; добавить в `$tests` в `check.ps1` |
| `loadouts/mod.txt` + `version.txt` + `README.md` | версия 4.17.0 |
| `CHANGELOG.md` | запись 4.17.0 |

## Тестирование

- Headless (`test_composite.gd` / `test_picker.gd`):
  - `attachment_class` для `Optic`/`Muzzle`/`Magazine`/прочего.
  - `composite_pack` на фейковом ресурсе с полями — все 8 наборов дают верные scale/offset.
  - Пакет на пустом ресурсе (нет полей) не падает, отдаёт базу 0.5/ZERO.
- Стенды `layout_check.py` и `check.ps1` — без изменений в списках, должны остаться зелёными.
- Ручная проверка в игре:
  - Primary/Secondary: 0 / 1 / 3 обвеса; пистолет vs винтовка (поворот); вылет дула обрезается клеткой.
  - Превью сета и страница «Готово» показывают то же.
  - Rig с плитой (напр. K19) и без (Vest_Fishing) — ⚙ есть/нет; NVG; Helmet — без глифа.
  - «Assign key» в один рост с соседней кнопкой.

## Риски

- **Кадрирование**: `tetris`-корень — та же текстура, что `icon`, но прежний путь обрезает прозрачные
  поля. Композит не обрезает; базой берём `res.size` (как ваниль). Оружие может выглядеть чуть мельче —
  смотрим глазами; при нужде подкрутить `pad`.
- **Смещение пакета в координатах 64-сетки** при повороте: одиночные offset — скаляр, парные — `Vector2`
  с уже переставленными осями в ваниле; повторяем как есть.
- **Инстанс на пересборку**: клеток ≤ ~20, оружий ≤ 2 — дёшево; кэш не заводим (YAGNI).
- **Отсутствие поля** у части оружия: читаем через `res.get(field, default)`.

## Открытые вопросы

Нет.

## Макет

Визуальный референс (вне репозитория, `docs/` под ignore): `docs/mockups/equip-cell-corners.html` —
composite оружия, голый ⚙ на Rig/NVG, положение ✕, кнопка «Assign key».
