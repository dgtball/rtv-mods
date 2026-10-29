# Vostok Toolkit — публикация на vostokmods.net

**Дата:** 2026-10-12
**Статус:** дизайн согласован; публикация на паузе — в релиз добавляются фичи
Auto-equip и Matches stack in equip (уже в коде)
**Область:** контент карточки мода на сайте + ассеты + changelog + правки репозитория

## Цель

Опубликовать мод **Vostok Toolkit** (`vostok-toolkit`; версия на момент подачи —
по `loadouts/mod.txt`, сейчас `4.15.1`) на https://vostokmods.net/explore/mods так,
чтобы карточка была честной по правилам сайта (Section 3, 7, 8 Content Rules),
понятной англоязычной аудитории и укомплектованной галереей и changelog.

## Принятые решения

1. **Deliverable:** готовый текст карточки + ассеты + changelog.
2. **Позиционирование:** QoL / Fixes / UI. Категория `Cheats` не используется,
   но описание перечисляет все функции правдиво (правила требуют точных
   метаданных; выбор категории — кураторский, а не сокрытие).
3. **Языки:** английский основной, русский — отдельным блоком в конце описания.
4. **Ассеты:** 7 скриншотов в `assets/`; лого/обложка — `Ironman Restart.jpg`.
5. **Changelog:** на сайте один блок `4.15.1 — Initial public release`; в репо
   заводится `CHANGELOG.md` (Keep a Changelog) и ведётся дальше.
6. **Раскрытие ИИ:** согласовано. В описании — строка `Development note:
   built with the assistance of generative AI` (Section 7 Content Rules).
7. **Версия игры:** `0.2.1.0`.
8. **Новые фичи в релизе:** `Auto-equip` и `Matches stack in equip` (реализованы,
   см. `VTKEquip.gd`). Удаление предмета из контекстного меню в этот релиз
   **не входит** (владелец отложил).

## 1. Поля карточки

| Поле | Значение |
|---|---|
| Title | `Vostok Toolkit` |
| Summary (EN) | A quality-of-life toolkit for Road to Vostok — loadout presets, smarter tasks, thermal vision, kill stats, a dynamic killfeed and fast travel, all in one mod. |
| Categories | `UI`, `Gameplay`, `Visuals`, `Fixes & Tweaks` |
| Tags | `Quality of Life`, `Equipment`, `Tools` |
| Game versions | `0.2.1.0` |
| Links → Source | https://github.com/dgtball/VostokToolKit |
| License | MIT (файл `LICENSE` присутствует) |
| Dependency | Metro Mod Loader 3.4.2; MCM (язык, настройки) |
| Cover image | `ironman-restart.jpg` |
| Author | аккаунт сайта (sign-in через Discord), указать как uploader |

## 2. Описание — английская версия (основная)

Порядок фич от «QoL» к «игровым», чтобы не выпячивать cheat-adjacent функции.

```markdown
![](ironman-restart.jpg)

**Vostok Toolkit** bundles a full set of quality-of-life features for Road to
Vostok into a single mod — from saved loadout presets to a reworked task flow,
thermal vision, combat stats and fast travel. The panel and every hotkey are
configured in MCM.

### Loadout Presets
Save your equipment and inventory as a preset, bind it to a hotkey, and
restore a full kit in one press.

![](loadout-presets.jpg)

### Auto-equip
Items with slots are equipped immediately on pickup (MCM toggle).

### Matches stack in equip
Matches stack right into the equipment slot — no extra click.

### Better Tasks
Completed quests clean themselves up, tasks can be handed in partially, and
the Notes tab shows per-item progress with icon rows.

![](better-tasks.jpg)
![](better-notes.jpg)

### Thermal Vision (NVG)
Replaces the night-vision goggles with a thermal view: the world glows by
heat, mines are highlighted and friendly Nomads are marked, so threats stand
out in poor visibility.

![](thermal-vision.jpg)

### Kill Stats & Killfeed
A HUD counter tracks your kills and how many hostiles are currently alive,
and a dynamic killfeed reports combat events as they happen.

![](kill-stats-killfeed.jpg)

### Fast Travel
Move between maps, shelters and traders without the walk.

![](fast-travel.jpg)

### Ironman Restart
On death in Ironman mode, the inactive Load Game button is replaced with a
Restart button that restarts the permadeath run. A bonus Apartments map is
included.

![](ironman-restart.jpg)

---

**Requirements**
- Road to Vostok 0.2.1.0
- Metro Mod Loader 3.4.2
- MCM — for language and per-feature settings

**Default hotkey**
- Toggle panel: `F3` (configurable in MCM)

**Interface language**
- RU / EN, switched in MCM (General → Language)

**Compatibility**
- Compatible with LateStart. Tested alongside ElegantHUD, JCM and other
  common mods. Conflicts are unlikely but not impossible.

**Credits**
- Juuzoz' Cheat Menu [JCM] by juuzoz_ — the starting point for the loadout idea
- Thermal Vision by Vito921 — inspiration for the thermal rework
- Partial Task Hand-In by Ryujiro — inspired partial task hand-in
- and the other modders who keep the game interesting

**Development note**
- This project is developed with the assistance of generative AI.

**License**
- MIT. Community mod, not affiliated with Road to Vostok or its author.
```

> **Пометка:** `Auto-equip` и `Matches stack in equip` — без скринов (механика,
> скринами не показать). Удаление предмета в этот релиз не входит.

## 3. Описание — русский блок (в конце, после `---`)

Текст согласован владельцем (его редакция). Единицы на проверку помечены ниже.

```markdown
---

## Vostok Toolkit (RU)

**Vostok Toolkit** объединяет набор quality-of-life функций для Road to Vostok в одном моде: сохранённые сеты снаряжения, переработан функционал заданий, тепловизор, боевую статистику и быстрое перемещение. Панель и функции настраиваются в MCM.

### Сеты (Loadout Presets)
Сохрани экипировку и инвентарь как сет, назначь горячую клавишу и используй одним нажатием.

### Автоэкипировка (Auto-equip)
Предметы со слотами надеваются сразу при подборе (тогл в MCM).

### Спички в экипировке (Matches stack in equip)
Спички стакаются сразу в слоте экипировки.

### Better Tasks
Выполненные задания самоочищаются, задания можно сдавать по частям, вкладка Notes показывает прогресс по предметам рядами иконок.

### Тепловизор (NVG)
Заменяет ПНВ на Тепловизор: Мины подсвечиваются, противники заметны при плохой видимости, кочевникам добавлен маркер ▼.

### Счётчик убитых и Killfeed
HUD-счётчик отслеживает убийства и число живых противников, а динамичная лента убийств сообщает о боевых событиях по ходу.

### Телепорт (Fast Travel)
Перемещение между картами, убежищами и торговцами без ходьбы.

### Ironman Restart
После смерти в Ironman неактивная кнопка Load Game заменяется кнопкой Restart, перезапускающей permadeath-забег. Бонусом добавлена карта Apartments.

**Требования**
- Road to Vostok 0.2.1.0
- Metro Mod Loader 3.4.2
- MCM — язык, настройки функций

**Язык интерфейса**
- RU / EN, переключается в MCM (General → Language)
```

Правки в RU-тексте внесены (подтверждено владельцем): пробел после
двоеточия в `Тепловизор: Мины`, `маркет` → `маркер`, `Вкладка` → `вкладка`.

## 4. Changelog

### Вкладка на сайте

```
4.15.1 — Initial public release

Added:
- Loadout presets with hotkey binding
- Auto-equip: items with slots are equipped on pickup (MCM toggle)
- Matches and other stackables top up the equipped slot without extra clicks
- Better Tasks: completed-quest auto-cleanup, partial hand-in, Notes icon rows
- Thermal vision (NVG): world heat glow, mine highlighting, friendly markers
- Kill stats HUD and dynamic killfeed
- Fast travel between maps, shelters and traders
- Ironman Restart button and the Apartments map
- RU / EN interface language switch in MCM
```

### `CHANGELOG.md` в репо (Keep a Changelog)

```markdown
# Changelog

All notable changes to Vostok Toolkit are documented here.
Format based on Keep a Changelog; versioning: MAJOR.MINOR.PATCH.

## [4.15.1] - 2026-10-12

### Added
- Initial public release on Vostok Mods
- Loadout presets with hotkey binding
- Auto-equip: items with slots are equipped on pickup (MCM toggle)
- Matches and other stackables top up the equipped slot without extra clicks
- Better Tasks: completed-quest auto-cleanup, partial hand-in, Notes icon rows
- Thermal vision (NVG): world heat glow, mine highlighting, friendly markers
- Kill stats HUD and dynamic killfeed
- Fast travel between maps, shelters and traders
- Ironman Restart button and the Apartments map
- RU / EN interface language switch in MCM
```

## 5. Ассеты и галерея

Скриншоты в `assets/` (1920×1082). Предлагается переименовать в kebab-case без
пробелов и `&` — стабильные пути для README и загрузки:

| Текущее имя | Новое имя | Роль |
|---|---|---|
| `Ironman Restart.jpg` | `ironman-restart.jpg` | обложка/лого + фича |
| `Loadout Presets.jpg` | `loadout-presets.jpg` | фича |
| `Better Tasks.jpg` | `better-tasks.jpg` | фича |
| `Better Notes.jpg` | `better-notes.jpg` | фича (под Better Tasks) |
| `Thermal Vision.jpg` | `thermal-vision.jpg` | фича |
| `Kill Stats & Killfeed.jpg` | `kill-stats-killfeed.jpg` | фича |
| `Fast Travel.jpg` | `fast-travel.jpg` | фича |

Порядок загрузки в галерею совпадает с порядком фич в описании; обложка —
`ironman-restart.jpg`. Сайт ресайзит изображения сам (`_ipx`), требований к
размеру не предъявляет; 1920×1082 подходит.

## 6. Правки репозитория

- **Новый** `CHANGELOG.md` (см. п.4).
- `README.md`: убрать заглушку `дополнить`, добавить EN-описание, вставки
  скриншотов, фичи Auto-equip / Matches stack in equip, благодарности и
  лицензию к той же формулировке, что на сайте.
- `assets/`: переименование 7 файлов в kebab-case; `assets/logo.jpg` уже удалён
  из рабочего дерева — обложка переходит на `ironman-restart.jpg`.
- `loadouts/mod.txt` — версия уже поднята до `4.15.1` (фичи в коде). Правки
  документации/ассетов версию не бампают.

## 7. Шаги публикации на сайте

1. Sign in (Discord).
2. Создать мод: Title, Summary.
3. Проставить Categories и Tags.
4. Game version: `0.2.1.0`.
5. Загрузить `Loadouts.vmz` как версию `4.15.1` (собрать `pack.ps1`).
6. Загрузить скриншоты в галерею; обложка — `ironman-restart.jpg`.
7. Вставить описание (EN + RU), инлайн-картинки указывают на загруженные
   галерейные URL в порядке фич.
8. Links → Source code = GitHub.
9. License: MIT.
10. Changelog: блок `4.15.1`.
11. Development note — строка про ИИ.

## 8. Вне области / открытые пункты

- Файл мода (`.vmz`) я не собираю и не загружаю — это делает владелец на сайте.
- Discord-хэндл в Authors: сайт связывает автора с аккаунтом загрузки,
  отдельное поле не планируется.
- Скрины: `Auto-equip` и `Matches stack in equip` — без картинок (механика).
  Удаление предмета в релиз не входит, скрин не нужен.
- Точные размеры обложки/лимиты загрузки уточняются на самой форме при подаче.
- **Известные поправки к плану реализации (внести при возобновлении):**
  - Task 1: файлы в `assets/` ещё не в git (untracked), а `assets/logo.jpg`
    удалён — `git mv` не сработает, нужен `Rename-Item` + `git add`/`git rm`.
  - Task 3/5: `docs/` в `.gitignore` (в whitelist только `assets/` и `loadouts/`)
    — `git add docs/vostokmods/listing.md` упадёт; нужно `!/docs/` в `.gitignore`
    либо force-add, либо хранить `listing.md` вне репо.
  - Тест авто-экипировки `test_equip.gd` ещё не добавлен в `.check/check.ps1`.
