# ThermalVTK — диагностический лог контурного ESP

**Дата:** 2026-10-19
**Статус:** утверждён
**Область:** standalone-мод ThermalVTK (контурный путь: `VTKESP`, `VTKOutline`, `VTKWeaponOcclusion`)

## Контекст и мотивация

Багу контура (режим A не рисовал ничего) вскрыли правкой вслепую: фильтр `layers & 2` в `VTKOutline._collect` отсекал все меши ботов (боты на слое 1). Такие молчаливые промахи не ловит ни парсер, ни headless-тесты — только ручной прогон в игре с разбором лога. Сейчас в ThermalVTK нет ни одной диагностической ветки (`push_warning` не в счёт), а при портировании из основного мода штатный probe-канал (`_dbg` в `VTKNVG`) был выпилен.

Цель: дать моду переиспользуемый канал логов и оснастить контурный путь пробами, чтобы сессию можно было разобрать по файлу, а не гадать.

## Принятые решения (из брейншторма)

- **Каркас на будущее + пробы сейчас.** Канал делается общим и остаётся, пробы заводим по контуру.
- **Файл + консоль.** Писать и в файл, и писать `print` (видно в логе игры/консоли модлоадера).
- **Тумблер MCM.** Включение/выключение — Bool в MCM, живьём и с сохранением в `config.ini`.
- **События + периодическая сводка.** Строки на изменения + компактная сводка раз в ~секунду.
- **Покрытие сейчас — только контур** (`VTKESP`, `VTKOutline`, `VTKWeaponOcclusion`).
- **Подход — общий статический синк** (вариант A), как `VTKLog.gd` в основном моде.

## Архитектура

```
standalone mods/ThermalVTK/mods/ThermalVTK/
  VTKDebug.gd            — НОВЫЙ: единый sink логов (статический RefCounted)
  ThermalVTK.gd          — + категория MCM "05. Diagnostics" + set_enabled в _mcm_apply
  VTKESP.gd              — + пробы событий и сводки
  VTKOutline.gd          — + пробы сбора/навешивания/пересбора
  VTKWeaponOcclusion.gd  — + одна сводка (применилось / родитель не найден)
```

Связи: все модули зовут `Dbg.log(tag, msg)`; гейт и файл живут только в `VTKDebug`. Никто, кроме `ThermalVTK._mcm_apply`, не трогает `enabled`.

## Каркас — `VTKDebug.gd`

Статический `RefCounted` без состояния сцены (как `VTKLog.gd`).

```
const LOG_PATH := "user://MCM/thermal-vtk/debug.log"

static var enabled := false
static var _file: FileAccess = null

static func set_enabled(v: bool) -> void
static func log(tag: String, msg: String) -> void
static func fmt(tag: String, msg: String) -> String
static func reset_for_tests() -> void
```

- `set_enabled(true)` — взводит `enabled` и один раз открывает файл (append) с шапкой сессии. `set_enabled(false)` — только снимает гейт, файл не трогает.
- `log(tag, msg)` — no-op, если `enabled == false` (единственный choke-point: гейт проверяется здесь, а не в местах вызова). Иначе лениво открывает файл, пишет одну строку `[<время>][<TAG>] <msg>`, `flush()`, и дублирует в `print`.
- Открытие: `FileAccess.open(LOG_PATH, FileAccess.WRITE_READ)` + `seek_end()` (append, не затирает прошлые сессии). Промах открытия — `push_warning`, без тихого отказа.
- Шапка сессии — одна строка с датой/временем и версией мода: `=== session start <t> v<version> ===`.
- `fmt(tag, msg)` — чистая функция, возвращает `"[<TAG>] <msg>"` (без времени): то, что тестируется headless.
- `reset_for_tests()` — сбрасывает `enabled`/`_file` (закрывает хендл).

## Тумблер MCM

- Категория **`05. Diagnostics`**, ключ `Bool debug_log` («Debug log»), `default = false`, тултип про диагностику контура.
- В `ThermalVTK._mcm_apply` сразу после разрешения `cfg` (когда конфиг уже загружен с диска):
  `VTKDebug.set_enabled(bool(_mcm_key_val(cfg, "Bool", "debug_log", false)))`.
  Ставится до работы с NVG, чтобы канал поднялся даже при отсутствии NVG.
- Ветка `_apply_defaults` (MCM-хелперы недоступны) логи не включает — канал молчит по умолчанию.
- `VTKDebug` преload'ится в `ThermalVTK.gd`, `VTKESP.gd`, `VTKOutline.gd`, `VTKWeaponOcclusion.gd`.

## Пробы

### `VTKESP.gd`

- `set_enabled`: `esp enabled=<bool>`.
- `_register_hooks`: один раз `hooks: RTVModLib present=<bool>` — хуки или polling-фолбэк.
- `_register`: `register id=<id> nomad=<bool> name=<node.name>`.
- `_on_ai_deactivate`: `deactivate id=<id>`.
- `_on_ai_changestate`: `changestate id=<id> state=<int>`.
- `_on_ai_death`: `death id=<id>`.
- Сводка раз в ~60 кадров: `tick entries=<n> cand=<n> keep=<n> applied=<n> ppos=<x,y,z>`. Счётчики собираются в `_draw` и хранятся в полях.
- Отдельная строка, если игрок не найден в группе `Player` (`no player in group Player`) — троттлится.

### `VTKOutline.gd`

- `apply`: `apply id=<id> meshes=<n> child_count=<n>`. Ключевая строка диагностики: `meshes=0` прямо объясняет невидимый контур.
- `_recollect`: `recollect id=<id> child_count=<a>-><b> meshes=<n>`.
- `_set_wall`: `wall id=<id> through=<bool>` (только при флипе).
- Событие через `Dbg.enabled`-гейт прежде, чем строить строку (в горячих путях — сборка/навешивание).

### `VTKWeaponOcclusion.gd`

- Одна сводка без спама: применилось к оружию / родитель не найден (`weapon-occlusion: attached` / `weapon-occlusion: no parent`).

## Тестирование

- Новый headless-тест `.check/project/tests/test_debug.gd`:
  - `VTKDebug.fmt("ESP", "x") == "[ESP] x"`.
  - При `enabled == false` вызов `log()` **не создаёт** файл в `user://`.
  - При `enabled == true` `log()` создаёт файл, и его содержимое содержит записанную строку.
  - `reset_for_tests()` закрывает хендл и снимает гейт.
  - Тест удаляет `LOG_PATH` в начале и в конце прогона, чтобы состояние прошлых сессий не влияло на проверки.
- Тест добавляется в `$tests` в `.check/check.ps1` (список явный).
- Полный прогон `.check/check.ps1`: парсинг всех скриптов + тесты зелёные (нет `SCRIPT ERROR`/`Parse Error`/`Invalid call`/`Failed to load script`, есть `tests passed`, код выхода 0).

## Версия и поставка

- Версия `1.2.1 → 1.3.0` (новая функциональность, обратно совместима) в `mod.txt`.
- Запись в `CHANGELOG.md` (English, видимый игроку эффект): опция Debug log под Diagnostics, пишет диагностический лог контурного ESP в файл.
- `pack.ps1` → `ThermalVTK.vmz`, копия в `D:\SteamLibrary\steamapps\common\Road to Vostok\mods`.

## Как пользоваться

1. Включить «Debug log» в MCM (категория `05. Diagnostics`).
2. Воспроизвести в игре (режим A, подойти к NPC-хосту).
3. Прочитать `%APPDATA%\Road to Vostok\MCM\thermal-vtk\debug.log` (`user://MCM/thermal-vtk/debug.log`). Сессии дописываются, каждая начинается со строки `=== session start ... ===`.
