# Раскладка rtv-mods: четыре независимых мода в одном репозитории — дизайн

Дата: 2026-10-29. Область: структура репозитория, git и сборочно-проверочная обвязка.
Код модов (GDScript) не меняется.

## Зачем

Репозиторий задумывался под один мод (Vostok Toolkit, папка `loadouts/`). Сейчас в нём
четыре независимых мода: Vostok Toolkit, ThermalVTK, Road To Loot (бывший LooterShooter)
и Freeze for JCM. Раскладка это не отражает: Toolkit занимает корень и владеет корневыми
`README.md`, `CHANGELOG.md`, `pack.ps1`, `assets/`, а остальные три лежат в
`standalone mods/<Name>/`. Из-за этого непонятно, где что, и часть обвязки вообще не в git.

Цель: одна предсказуемая раскладка, где все четыре мода равноправны, а корень — тонкая
оболочка (индекс, общий стенд, общая сборка). Плюс починка git: репозиторий должен
клонироваться в состояние, из которого мод можно собрать и проверить.

## Что есть сейчас (факты)

- `loadouts/` — Vostok Toolkit: `mod.txt` + `mods/VTK/` (25 скриптов), `CHANGELOG.md`,
  `mods/VTK/version.txt` (генерируется сборкой).
- `standalone mods/ThermalVTK/`, `standalone mods/RoadToLoot/`, `standalone mods/jcm-freeze/`
  — каждый со своим `mod.txt`, `mods/<Name>/`, `README.md`, `CHANGELOG.md`, `pack.ps1`.
- Корневые `README.md` и `CHANGELOG.md` описывают только Toolkit; корневой `CHANGELOG.md`
  остановился на 5.1.1, актуальный (5.2.0) лежит в `loadouts/CHANGELOG.md`.
- **В git нет сборки и стенда:** untracked `pack.ps1`, `AGENTS.md`, `.check/layout_check.py`,
  `.check/project/project.godot`, `.check/project/stubs/*`, `.check/project/Host.gd` и 40 из
  46 тестов. Свежий клон нельзя ни собрать, ни проверить.
- `.gitignore` — allowlist (`/*` + `!`-исключения): новый файл молча остаётся вне git,
  есть мёртвое правило `!/docs/vostokmods/` (папки нет) и `/docs/superpowers/`, хотя файлы
  оттуда уже в индексе.
- Стенд `.check` знает все моды по именам, включая удалённый LooterShooter: 25 мёртвых
  ссылок в `check.ps1`, `layout_check.py` смотрит `standalone mods/LooterShooter/...`,
  6 тестов `test_lsh_*`/`test_serialization` тестируют несуществующий мод.
- `layout_check.py` содержит абсолютные пути `D:\RTVMOD\...` — репозиторий не переносится.
- `jcm-freeze` не покрыт ни парсинг-проверкой (его нет в `check.ps1`), ни тестами; стенд
  кладёт его копию в `.check/project/jcm-freeze/`, а не в `mods/`.
- Четыре `pack.ps1` разъехались по поведению: Toolkit чистит `.gd` от комментариев и пустых
  строк, остальные три — нет (их `.vmz` крупнее); jcm-freeze не пишет `version.txt` и не
  синхронизирует версию в README.
- В корне мусор: пустой файл `Picker`, `tr.txt`, `rtl_check.txt`, `rtlroll.log`,
  `roll_out.txt`, `pool_out.txt`, собранный `Loadouts.vmz`.
- Git: `main` на 43 коммита впереди `origin/main` и на 1 позади (origin удалил папку
  LooterShooter; локально её уже удалил коммит `9836674`). Ветка `origin/audit` полностью
  влита в `main` (её тип — merge-base). Все 5 тегов существуют и на origin.
- Рядом с репозиторием (в git не попадают): `RTVcopy` 11.4 ГБ, `referens` 182 МБ,
  `tools` 168 МБ, `tmp_probe`, `.superpowers` 15 МБ, `superpowers`, пустая `.docs`.

## Цели

1. Все четыре мода живут по одной схеме `mods/<slug>/` с одинаковым набором файлов.
2. Корень — оболочка: индекс-README, общий стенд, общая сборка, лицензия.
3. `git clone` даёт рабочее состояние: при наличии Godot 4.6.3 (единственная внешняя
   зависимость) `check.ps1` проходит, `pack.ps1` собирает все четыре `.vmz`.
4. `.gitignore` — обычный список игнорируемого; новый файл виден в `git status`.
5. Сборка и проверка не зависят от абсолютных путей машины.
6. История git линейна и запушена; мёртвая ветка убрана; мёртвые ссылки на LooterShooter
   удалены (кроме одноразовой миграции пути MCM в `RTLBoot.gd`).

## Не-цели

- Не делим на отдельные репозитории (вариант B отклонён: пришлось бы резать историю и
  размножать стенд на 46 тестов).
- Не трогаем код модов, их версии и содержимое `.vmz` (кроме ожидаемого уменьшения размера
  за счёт чистки комментариев там, где её раньше не было).
- Не переписываем историю, не переносим существующие теги и релизы.
- Не двигаем `RTVcopy`/`referens`/`tools` с диска — только игнорируем.
- Не пишем новых тестов (кроме случая, если исполнитель решит добавить парсинг jcm-freeze —
  это делается правкой `check.ps1`, без новых файлов).

## Анти-цели

- Сломать форму архива: внутри `.vmz` обязаны остаться `mod.txt` и `mods/<Name>/` в корне,
  иначе установленные моды и релизы перестанут работать.
- Сделать стенд зависимым от имени папки на диске (`D:\RTVMOD`) или от текущей рабочей
  директории.
- Потерять файл при переезде: каждый перемещённый путь должен быть прослеживаем
  (`git mv`) и проверен диффом.

## Ограничения

- Godot 4.6.3 headless; стенд `.check/project` — единственный Godot-проект для проверок.
- modloader грузит каждый мод независимо, общего кода в рантайме быть не может: копии
  `VTKPaths.gd`/`VTKLog.gd` в ThermalVTK — норма, объединять их не нужно.
- `pack.ps1` вырезает построчные `#`-комментарии и пустые строки из `.gd`; многострочных
  строк в коде нет, трансформация построчная.
- Ветка одна — `main`; работа ведётся в ней, как раньше.

## Подходы

- **A. Один репозиторий, четыре равноправных мода.** `mods/<slug>/`, корень — оболочка.
  Теги и релизы на мод. История сохраняется через `git mv`. Рекомендован и выбран.
- **B. Четыре отдельных репозитория.** Максимальная независимость, но: `filter-repo`,
  четыре копии стенда со стабами, четыре набора тестов, потеря проверки «все моды
  компилируются в одном проекте», повторная раскладка тегов и релизов. Цена выше выигрыша.

## Целевое дерево

```
D:\RTVMOD\
├─ mods\
│  ├─ vostok-toolkit\
│  │  ├─ mod.txt
│  │  ├─ mods\VTK\*.gd, version.txt
│  │  ├─ README.md
│  │  └─ CHANGELOG.md
│  ├─ thermal-vtk\   mod.txt, mods\ThermalVTK\, README.md, CHANGELOG.md
│  ├─ road-to-loot\  mod.txt, mods\RoadToLoot\, README.md, CHANGELOG.md, REFACTOR_SPEC.md
│  └─ jcm-freeze\    mod.txt, mods\jcm-freeze\, README.md, CHANGELOG.md
├─ .check\
│  ├─ check.ps1                  (данные о модах — таблица, один цикл)
│  ├─ layout_check.py            (относительные пути, без LooterShooter)
│  └─ project\                   (Godot-стенд: project.godot, Host.gd, stubs, Scripts)
│     └─ tests\
│        ├─ vostok-toolkit\  (15 тестов)
│        ├─ thermal-vtk\     (17 тестов)
│        └─ road-to-loot\    (9 тестов + 2 файла-опоры)
├─ docs\                         (общая история дизайна: mockups, superpowers\plans, specs)
├─ dist\                         (собранные .vmz, в git не входит)
├─ tools\  referens\  RTVcopy\  tmp_probe\   (локальные, в git не входят)
├─ README.md                     (индекс: четыре мода, ссылки на их README)
├─ pack.ps1                      (-Mod <slug> | -All)
├─ AGENTS.md
├─ LICENSE
└─ .gitignore
```

Slug = `id` из `mod.txt`: `vostok-toolkit`, `thermal-vtk`, `road-to-loot`, `jcm-freeze`.
Единственное место правды об имени папки — `id` в `mod.txt`; скрипты берут его оттуда.

## Карта переезда

| Откуда | Куда |
|---|---|
| `loadouts/` | `mods/vostok-toolkit/` |
| `loadouts/CHANGELOG.md` | `mods/vostok-toolkit/CHANGELOG.md` (с влитой историей из корневого, см. ниже) |
| корневой `README.md` | `mods/vostok-toolkit/README.md`; новый корневой — индекс |
| корневой `CHANGELOG.md` | влит в `mods/vostok-toolkit/CHANGELOG.md`, корневой удалён |
| корневой `pack.ps1` | переписан в общий `pack.ps1` в корне |
| `assets/` (8 jpg) | удалить: скриншоты не нужны в репозитории (остаются в истории git) |
| `standalone mods/ThermalVTK/` | `mods/thermal-vtk/` |
| `standalone mods/RoadToLoot/` | `mods/road-to-loot/` |
| `standalone mods/jcm-freeze/` | `mods/jcm-freeze/` |
| `*/pack.ps1` (четыре копии) | удалены, заменены корневым `pack.ps1 -Mod` |
| `.check/project/tests/test_<мод>*.gd` | `.check/project/tests/<slug>/` — **внутри** Godot-проекта, `res://` остаётся рабочим |
| `.check/project/tests/rtl_probe_{save,slot}.gd` | `.check/project/tests/road-to-loot/` — их прелоадит `test_rtl_persist` |
| `.check/project/tests/*.bak`, `probe_*.gd`, `test_*debug*.gd`, `test_seasons_headless.gd(.stub)` | удалить (`.bak`) / перенести в `tmp_probe/` (не нужны прогону) |
| `check_nul_scan.py`, `check_vmz.py` | `tools/` (локальные утилиты, из git выпадают) |
| `Picker` (0 байт), `tr.txt`, `rtl_check.txt`, `rtlroll.log`, `roll_out.txt`, `pool_out.txt`, `Loadouts.vmz` | удалить |
| `docs/mockups/`, `docs/superpowers/` | остаются на месте |

Разбивка тестов по результатам анализа `res://mods/...` внутри каждого файла:

- `vostok-toolkit` (15): composite, config, data, deposits, draft, equip, feed, hooks, items,
  notes, picker, seasons, session, spawn, travel.
- `thermal-vtk` (17): calibration, daylight, daylight_runtime, debug, esp, label_layout, labels,
  nvg, outline, preset, probe, profile, settings, shaders, states, tracker, weapon.
- `road-to-loot` (9): rtl_category, rtl_persist, rtl_pool, rtl_roll, rtl_rows, rtl_stats, rtl_text,
  sidecar, store — плюс файлы-опоры `rtl_probe_save.gd`, `rtl_probe_slot.gd` (их прелоадит
  `test_rtl_persist.gd`; они едут в ту же папку и остаются в git).
- Тесты LooterShooter (`test_lsh_*`, `test_serialization`) удаляются вместе с модом.
- В прогон не входят и в git не нужны: `test_rtl_stats_debug*.gd`, `test_sidecar_debug.gd`,
  `test_seasons_headless.gd` (прелоадит `test_seasons.gd` — это отладочный вариант) и её
  `.stub`, а также `probe_in.gd`, `probe_in2.gd`, `probe_resweep.gd`, `probe_vec.gd` —
  ни один тест на них не ссылается. Всё это уезжает в `tmp_probe/`.

Правило на будущее: тест мода лежит в `.check/project/tests/<slug>/`, а файл, который тест
прелоадит, — рядом с ним, а не в общей свалке.

**Почему тесты остаются внутри `.check/project/`:** `project.godot` — корень Godot-проекта,
и `check.ps1` запускает каждый тест как `--path .check/project --script res://tests/<...>.gd`.
Папка `tests/` вне проекта сделала бы все 41 тест недоступными без копирования на каждом
прогоне. `<slug>` внутри `project/tests/` даёт и разделение по модам, и рабочий `res://`.

## Стенд

`check.ps1` переписывается на таблицу модов и один цикл:

```powershell
$mods = @(
    @{ Slug = "vostok-toolkit"; Folder = "VTK";         Tests = "vostok-toolkit" },
    @{ Slug = "thermal-vtk";    Folder = "ThermalVTK";  Tests = "thermal-vtk" },
    @{ Slug = "road-to-loot";   Folder = "RoadToLoot";  Tests = "road-to-loot" },
    @{ Slug = "jcm-freeze";     Folder = "jcm-freeze";  Tests = $null }
)
```

- Источник — `mods/<slug>/mods/<Folder>`, копия — `.check/project/mods/<Folder>`
  (jcm-freeze тоже переезжает в `mods/`, отдельная папка в корне проекта больше не нужна).
- Список тестов остаётся явным (правило из AGENTS: новый тест добавляется руками), но
  группируется по моду: `$tests["vostok-toolkit"] = @("res://tests/vostok-toolkit/test_...gd")`.
- `.check/project/mods/` — генерируемая папка: она в `.gitignore`, `check.ps1` стирает и
  пересоздаёт её на каждом прогоне, поэтому рабочее дерево после прогона остаётся чистым.
- Проверка вердикта прежняя: нет `SCRIPT ERROR`/`Parse Error`/`Invalid call`/`Failed to load
  script`, есть `tests passed`, код выхода 0.
- `.check/project/Scripts/SlotData.gd` — стаб ванильного пути для LooterShooter. После
  удаления его тестов проверить, ссылается ли на него хоть один оставшийся тест; если нет —
  удалить вместе с папкой.
- `layout_check.py`: пути считаются от `Path(__file__).resolve().parent.parent`; глоб —
  **только Toolkit** (`mods/vostok-toolkit/mods/*/*.gd`), как сейчас, списки `GONE`/`PRESENT`/
  `FUNCS` относятся к его UI; `LSH_GLOB*` удаляются. Глоб по всем модам не годится: правило
  `DUP` (одна функция в двух файлах) конфликтует с разрешёнными копиями `VTKPaths.gd`/
  `VTKLog.gd` между модами.

## Сборка

Один корневой `pack.ps1`. Таблица модов задаёт три вещи: папку источника, имя артефакта и
нужен ли моду `version.txt`.

| slug | артефакт | version.txt |
|---|---|---|
| `vostok-toolkit` | `Loadouts.vmz` | да |
| `thermal-vtk` | `ThermalVTK.vmz` | да |
| `road-to-loot` | `RoadToLoot.vmz` | да |
| `jcm-freeze` | `Freeze.vmz` | нет |

- `-Mod <slug>` собирает один мод, `-All` (по умолчанию) — все, найденные по `mods/*/mod.txt`.
- **Имена артефактов не меняются** (`Loadouts.vmz`, а не `vostok-toolkit.vmz`): на них
  ссылаются README всех четырёх модов, страницы модов и уже опубликованные релизы. Меняется
  только место — `dist/`. Переименование — отдельное решение для отдельного релиза.
- Версия читается из `mod.txt`; `version.txt` пишется для модов с флагом «да» и остаётся
  **отслеживаемым файлом** (иначе первый же клон после сборки получил бы `unknown` в MCM:
  `VTKMCMBridge.version()` читает `res://mods/VTK/version.txt`). jcm-freeze его не получает —
  в его архиве набора файлов не меняется.
- Строка `**Version:**` в README правится, только если она есть.
- `.gd` чистятся от комментариев и пустых строк для всех модов (сейчас только Toolkit) —
  поведение выравнивается, размер остальных `.vmz` падает.
- Результат — `dist/<артефакт>.vmz`. Корневой `Loadouts.vmz` больше не создаётся.
- Шаг установки из AGENTS меняется: копировать из `dist/`.

## .gitignore

Allowlist заменяется списком игнорируемого:

```
/RTVcopy/
/referens/
/tools/
/tmp_probe/
/.superpowers/
/superpowers/
/.docs/
__pycache__/
/dist/
*.vmz
.godot/
*.uid
*.bak

# генерируемое стендом и выгрузки из игры
/.check/project/mods/
/.check/_gdc_*.txt
/.check/inventory-wall-crops/
```

`.check/project/mods/` — копии исходников, которые `check.ps1` пересоздаёт на каждом прогоне;
`_gdc_*.txt` — дампы ванильных классов, `inventory-wall-crops/` — 14 картинок-вырезок, никем не
используемые. Для первой папки игнор обязателен, иначе после прогона дерево станет грязным;
две другие можно так же перенести в `tmp_probe/` — исполнитель решает, но в git они не идут.

Всё остальное — в git, включая `AGENTS.md`, `pack.ps1`, `layout_check.py`, `.check/project/`
(без `.godot`), `docs/mockups`, `docs/superpowers`. Тесты перестают быть полу-отслеженными.

## Git: ремонт и коммиты

1. `git fetch --all --prune`; `git pull --rebase origin main`. Upstream-коммит
   `3e50d04 Delete standalone mods/LooterShooter directory` станет пустым (то же удаление уже
   сделано локально в `9836674`) — при остановке `git rebase --skip`, проверить, что рабочее
   дерево чисто, история линейна.
2. `git push origin main` — 43 коммита уезжают.
3. Удалить мёртвую ветку: `git push origin --delete audit`.
4. Дальше — серия коммитов, каждый осмысленный и проверяемый:
   - `chore(git): track build and test harness` — `.gitignore` на новый вид, добавить
     `AGENTS.md`, `pack.ps1`, `layout_check.py`, `.check/project/*`, `docs/mockups`.
   - `refactor(layout): move mods into mods/<slug>` — `git mv` четырёх модов и `assets/`,
     переписанные `check.ps1`/`layout_check.py`/`pack.ps1`, удалённые копии `pack.ps1`.
     Один коммит, потому что до переписывания скриптов стенд не работает.
   - `chore: root README index, per-mod changelogs, drop junk` — новый корневой README,
     влитый changelog Toolkit, удаление мусора, `tmp_probe` для отладочных заготовок.
   - `docs(agents): rewrite paths and structure rules` — `AGENTS.md` под новую раскладку.
5. Теги на текущее состояние (после того как всё зелёное): `vostok-toolkit-5.2.0`,
   `road-to-loot-0.3.4`, `thermal-vtk-2.2.0`, `jcm-freeze-1.2.0`. Старые
   (`v4.7.2`, `v4.8.3`, `v5.1.2`, `vtk-4.17.7`, `thermalvtk-1.1.0`) не трогаем.

## Документация

- `README.md` в корне — индекс: что за репозиторий, четыре мода по строке (что делает,
  текущая версия), ссылки на `mods/<slug>/README.md`, как собрать (`pack.ps1 -All`, `dist/`),
  как проверить (`layout_check.py`, `check.ps1`), лицензия. Отдельным блоком —
  **предусловия**: Godot 4.6.3 и Python 3 (для `layout_check.py`), с указанием, что `check.ps1`
  ищет Godot в `PATH` или в `tools/` и принимает `-Godot <путь>`. `tools/` в git не входит,
  поэтому «клон → проверка» требует установленного Godot — это документируется, а не
  считается нулевой настройкой.
- `mods/vostok-toolkit/README.md` — прежний корневой README, ссылки на картинки становятся
  `assets/...` (папка переехала вместе с ним).
- `mods/vostok-toolkit/CHANGELOG.md` — 5.2.0 из `loadouts/CHANGELOG.md` сверху, ниже
  восстановленная история 5.0.1–5.1.1 из корневого `CHANGELOG.md` (дубли версий схлопнуть,
  порядок по убыванию).
- У остальных модов `README.md`/`CHANGELOG.md` уже свои, не трогаем.
- `AGENTS.md`: переписать пути (`loadouts/` → `mods/vostok-toolkit/`, `.check/project/tests`
  → `.check/project/tests/<slug>`), добавить раздел «Реструктуризация репозитория» с правилами:
  slug = `id` из `mod.txt`; версия — только в `mod.txt` (`version.txt` рядом с исходниками —
  генерируемый сборкой и отслеживаемый файл, руками не правится); тег `<slug>-<version>`;
  новый мод = новая папка `mods/<slug>/` + строка в таблицах `check.ps1` и `pack.ps1`; тесты
  мода — только в `.check/project/tests/<slug>/`; в `mods/<slug>/` не кладётся ничего, кроме
  `mod.txt`, `mods/<Folder>/`, `README.md`, `CHANGELOG.md` и (для Road To Loot)
  `REFACTOR_SPEC.md`: сборщик берёт только `mod.txt`, `version.txt` и разрешённые расширения,
  но лишний файл в папке всё равно сбивает с толку.

## Проверка

Перед переездом — зафиксировать базовую линию: собрать все четыре `.vmz` текущими скриптами,
сохранить списки записей архивов (без байтов) и размеры.

После переезда:

1. `py -3 .check\layout_check.py` — без ошибок.
2. `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1` — все моды парсятся,
   все тесты `VERDICT: ok`, код выхода 0.
3. `powershell -ExecutionPolicy Bypass -File pack.ps1 -All` — четыре архива в `dist/`.
4. Сверить списки записей архивов с базовой линией: набор путей и `mods/<Name>/` идентичны.
   Для Toolkit содержимое `.gd` обязано совпасть с прежним; для остальных трёх — содержимое
   равно «строкам без комментариев и пустых строк», размер меньше.
5. `git status` чистый, `git log` линейный, `origin/main` содержит всё.
6. Проверка переносимости: запустить `layout_check.py` и `check.ps1` из другой рабочей
   директории (`workdir C:\`) — пути не должны сломаться.
7. Проверка «как у нового пользователя»: склонировать репозиторий во временную папку, при
   установленном Godot 4.6.3 прогнать `check.ps1` и `pack.ps1 -All`. Единственное допустимое
   вмешательство — `-Godot <путь>`, если бинаря нет в `PATH`; это предусловие, а не поломка.

## Мои решения (можно оспорить)

- Slug папок = `id` из `mod.txt` (`thermal-vtk`, а не `ThermalVTK`): одна схема, скрипты
  читают id, а не угадывают имя.
- `assets/` удаляется вместе с содержимым: в README Toolkit остаётся текст без картинок,
  ссылки на скриншоты и упоминание папки убираются.
- Сборка кладёт результат в `dist/`, а не в корень, но **имена артефактов не меняются**
  (`Loadouts.vmz`, `ThermalVTK.vmz`, `RoadToLoot.vmz`, `Freeze.vmz`).
- Тесты остаются внутри Godot-проекта, `.check/project/tests/<slug>/`, а не выносятся
  в `.check/tests/`: иначе `res://` перестаёт резолвиться и нужна копирующая прослойка.
- `version.txt` остаётся отслеживаемым файлом: без него свежий клон после сборки показывал бы
  `unknown` в MCM. jcm-freeze его не получает.
- Комментарии из `.gd` чистятся для всех модов, не только для Toolkit.
- jcm-freeze получает парсинг-проверку в стенде; тестов ему не пишем.
- `layout_check.py` остаётся проверкой только Toolkit (глоб по всем модам сломал бы правило
  `DUP` из-за разрешённых копий общих хелперов).
- Тяжёлые папки (`RTVcopy`, `tools`, `referens`) остаются на месте под игнором.
- Старые теги не переименовываем, новая схема действует с этого момента.

## Оставлено исполнителю

- Порядок и формулировки коммитов, точные тексты нового корневого README и влитого
  changelog.
- Нужно ли добавлять в `check.ps1` отдельную строку на будущие тесты jcm-freeze (сейчас
  `Tests = $null`).
- Судьба неиспользуемых файлов стенда (`debug_glass.gd`, `inspect.gd`, `probe_gear.gd`,
  `repro_load.gd`, `tools_detok.gd`, `.check/_gdc_*.txt`, `.check/inventory-wall-crops/`):
  оставить в стенде (полезны) или перенести в `tools/` / `tmp_probe/`; в git они не идут в
  любом случае.
- Теги ставятся после зелёной проверки; если решим не тегировать сейчас — не блокер.
