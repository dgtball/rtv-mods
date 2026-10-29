# Freeze for JCM — патч 1 «Freeze NPC», план реализации

Дата: 2026-10-19
Спека: `docs/superpowers/specs/2026-10-19-jcm-freeze-design.md`
Объём патча: **только тумблер Freeze NPC** (`jcm-freeze.npc`). «Freeze BTR & Heli» — второй заход, версия `1.1.0`, см. Follow-up.

## Goal

Отдельный мод-аддон `jcm-freeze` (`.vmz`), который ставит на вкладку **AI** JCM один тумблер **Freeze NPC**: пока он включён, вся пехота под `AI.gd` (бандиты, охрана, военные, номады, боссы) замирает статуей — логика, движение и продвижение анимации останавливаются, включая свежий спавн. Выключение оживляет цели. Версия `1.0.0`.

## Architecture / tech stack

- **JCM addon API 1.0**: автолоад `res://jcm-freeze/Main.gd`, регистрация `register_toggle(id, tab, label, default, on_toggled)`, состояние читается через `is_enabled()` (JCM сам хранит его в `jcm_settings.ini`).
- **Metro Mod Loader (modloader.gd)**: один replace-хук `ai-_physics_process`, зарегистрированный один раз при старте; в колбэке решает только булевый флаг `_npc_on`. Хук висит постоянно — гонки «сняли хук, а бот уже заморожен» нет, пул/переход карты/`Activate()` ничего не сбрасывают.
- **Упаковка**: собственный `pack.ps1` внутри `jcm-freeze/` (чистка `.gd`, zip → `Freeze.vmz`).
- **Проверка**: `godot --headless --check-only` по `res://jcm-freeze/Main.gd` на стенде `.check/project`.

## Global constraints

- Отступы в `.gd` — только табы; файлы UTF-8; тексты в коде — английские (как в шаблоне ADDONS.md).
- `Main.gd` — `extends Node`, без `preload`/`load` игровых ресурсов: парсится на чужом стенде без стабов.
- `_lib` и `_jcm` объявляются **без типов** (`var _lib = null`): на типизированной `Node` статический анализатор Godot 4 ругается на `register_toggle`/`has_mod` (в ADDONS.md пример тоже untyped).
- Headless-тестов нет (спека §«Упаковка и проверка», п.5): аддон целиком рантайм-хуки, чистой логики нет.
- Версия — `loadouts/mod.txt` Востока Тулкита не трогаем; версия аддона живёт в `jcm-freeze/mod.txt`.
- `.gitignore` сейчас игнорирует всё (`/*`), кроме allowlist — без правки новый каталог не попадёт в git.
- Коммиты **не делаем**: ведёт пользователь.
- CHANGELOG/README аддона не пишем (YAGNI, спека их не требует).

## Deviation from spec (обязательное, подтверждено по исходникам)

Спека §«Пехота» проектирует `-pre`-хук + `skip_super()`. Это **не работает**: `skip_super()` ставит флаг, но wrapper читает его **только вокруг вызова replace-колбэка** (`modloader.gd:21327–21339`). В void-ветке:

- есть replace-колбэк → вызывается он, и `if !_did_skip: vanilla()` уже после него;
- replace нет → `else` ветка безусловно зовёт vanilla; флаг из `-pre` никуда не читается.

Поэтому заморозка делается **replace-хуком без суффикса** `ai-_physics_process` (база: lowercase-стем скрипта `AI.gd` + имя метода — подтверждено `modloader.gd:7457–7468`, тот же паттерн, что `btr-sensor-post` у JCM). Replace-слот одновладельческий: `hook()` вернёт `-1`, если слот занят; скан всех установленных `.vmz` конфликтов не нашёл, гвард на `-1` всё равно пишем.

Второе следствие: `skip_super()` в колбэке вызывается **только** когда флаг включён; когда выключен — колбэк ничего не делает и vanilla идёт как обычно.

## Interfaces

`Main.gd` (итоговый, обе задачи):

```gdscript
extends Node

const NPC_ID = "jcm-freeze.npc"

var _lib = null
var _jcm = null
var _npc_on := false


func _ready() -> void:
	if not Engine.has_meta("RTVModLib"):
		push_warning("[Freeze] RTVModLib is not available; addon disabled")
		return
	var lib = Engine.get_meta("RTVModLib")
	if lib.get("_is_ready"):
		_on_lib_ready()
	else:
		lib.frameworks_ready.connect(_on_lib_ready)


func _on_lib_ready() -> void:
	if _lib != null:
		return
	_lib = Engine.get_meta("RTVModLib")
	_jcm = get_node_or_null("/root/jcm")
	if not _lib.has_mod("juuzoz-jcm") or _jcm == null \
			or not _jcm.has_method("supports_addon_api") or not _jcm.supports_addon_api("1.0"):
		push_warning("[Freeze] Freeze needs JCM 3.5.0 or newer; addon disabled")
		return
	if not _lib.has_method("skip_super"):
		push_warning("[Freeze] mod loader has no skip_super(); freeze disabled")
		return

	_jcm.register_toggle(NPC_ID, "AI", "Freeze NPC", false, _on_npc_toggled)
	_npc_on = _jcm.is_enabled(NPC_ID)
	_register_hooks()


func _register_hooks() -> void:
	var id = _lib.hook("ai-_physics_process", _on_ai_process)
	if id == -1:
		push_warning("[Freeze] ai-_physics_process is owned by another mod; Freeze NPC will not work")


func _on_npc_toggled(enabled: bool) -> void:
	_npc_on = enabled


func _on_ai_process(_delta) -> void:
	if _npc_on:
		_lib.skip_super()
```

Потребляемый API (проверен в JCM 3.5.0 / ADDONS.md / modloader.gd):

| Вызов | Источник |
|---|---|
| `Engine.get_meta("RTVModLib")`, `lib.get("_is_ready")`, `lib.frameworks_ready` | modloader.gd:179; ADDONS.md §Example |
| `_lib.has_mod("juuzoz-jcm")`, `_lib.hook(name, cb) -> int`, `_lib.skip_super()` | modloader.gd:14654, 14515, 14638 |
| `_jcm.supports_addon_api("1.0")`, `register_toggle(...)`, `is_enabled(id)` | JCM Main.gd:844, 859, 887 |

Почему `_on_ai_process(_delta)` принимает ровно один аргумент: wrapper вызывает replace через `callv(args)` (`modloader.gd:21333`), а `AI.gd:410` — `func _physics_process(delta: float) -> void:` (1 аргумент). Несовпадение арности — молчаливый no-op (AGENTS.md).

---

### Task 1 — Каркас аддона и тумблер (без хука)

**Files**
- `.gitignore` — правка allowlist.
- `jcm-freeze/mod.txt` — новый.
- `jcm-freeze/pack.ps1` — новый.
- `jcm-freeze/jcm-freeze/Main.gd` — новый (регистрация + флаг, **без** `_register_hooks()`).

**Steps**

1. `.gitignore`: после `!/standalone mods/` добавить `!/jcm-freeze/`; после `/standalone mods/**/*.vmz` — `/jcm-freeze/*.vmz`.
2. `jcm-freeze/mod.txt`:

   ```ini
   [mod]
   name="Freeze for JCM"
   id="jcm-freeze"
   version="1.0.0"

   [dependencies]
   required=["juuzoz-jcm"]

   [autoload]
   jcmFreeze="res://jcm-freeze/Main.gd"
   ```

3. `jcm-freeze/pack.ps1` (адаптация корневого: без version.txt/README-синхрона, фильтр `mod.txt` + `.gd`, `$src = $PSScriptRoot`):

   ```powershell
   param(
       [string]$OutFile = ""
   )

   $ErrorActionPreference = "Stop"

   $src = $PSScriptRoot
   if (-not $OutFile) {
       $OutFile = Join-Path $PSScriptRoot "Freeze.vmz"
   }

   $modTxt = Join-Path $src "mod.txt"
   if (Test-Path -LiteralPath $modTxt) {
       $ver = (Select-String -LiteralPath $modTxt -Pattern 'version\s*=\s*"([^"]+)"').Matches.Groups[1].Value
       if ($ver) { Write-Host "Version in mod.txt: $ver" }
       else { Write-Warning "mod.txt has no version field" }
   } else {
       Write-Warning "mod.txt not found in $src"
   }

   $entries = @(Get-ChildItem -LiteralPath $src -Recurse -File |
       Where-Object { $_.Name -eq "mod.txt" -or $_.Extension -eq ".gd" } |
       ForEach-Object { $_.FullName.Substring($src.Length).TrimStart([char[]]"\/") -replace "\\", "/" } |
       Sort-Object)

   if ($entries.Count -eq 0) { throw "Nothing to pack in $src" }

   Add-Type -AssemblyName "System.IO.Compression"
   Add-Type -AssemblyName "System.IO.Compression.FileSystem"

   $tmpZip = Join-Path ([System.IO.Path]::GetTempPath()) ("freeze_" + [guid]::NewGuid().ToString("N") + ".vmz")
   $stream = [System.IO.File]::Create($tmpZip)
   $zip = New-Object System.IO.Compression.ZipArchive($stream, [System.IO.Compression.ZipArchiveMode]::Create)
   $utf8 = New-Object System.Text.UTF8Encoding($false)
   try {
       foreach ($en in $entries) {
           $srcPath = Join-Path $src ($en -replace "/", "\")
           Write-Host "  + $en"
           if ($en -like "*.gd") {
               $lines = [System.IO.File]::ReadAllText($srcPath, [System.Text.Encoding]::UTF8) -split "\r?\n"
               $kept = New-Object System.Collections.Generic.List[string]
               foreach ($ln in $lines) {
                   $t = $ln.Trim()
                   if ($t -eq "" -or $t.StartsWith("#")) { continue }
                   $kept.Add($ln.TrimEnd())
               }
               $bytes = $utf8.GetBytes([string]::Join("`n", $kept) + "`n")
               $entry = $zip.CreateEntry($en, [System.IO.Compression.CompressionLevel]::Optimal)
               $es = $entry.Open()
               $es.Write($bytes, 0, $bytes.Length)
               $es.Dispose()
           } else {
               [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $srcPath, $en, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
           }
       }
   }
   finally {
       $zip.Dispose()
       $stream.Dispose()
   }

   if (Test-Path -LiteralPath $OutFile) { Remove-Item -LiteralPath $OutFile -Force }
   Move-Item -LiteralPath $tmpZip -Destination $OutFile -Force

   $sizeKb = [math]::Round((Get-Item -LiteralPath $OutFile).Length / 1KB, 1)
   Write-Host ""
   Write-Host "Pack done: $OutFile ($($entries.Count) entries, $sizeKb KB)"
   ```

4. `jcm-freeze/jcm-freeze/Main.gd` — код из Interfaces, но **без** строки `_register_hooks()` в `_on_lib_ready` и без функций `_register_hooks`/`_on_ai_process`.

**Verification**

Парсинг-стенд (копия Main.gd в чужой проект, `--check-only`):

```powershell
$godot = "D:\RTVMOD\tools\4.6.3\Godot_v4.6.3-stable_win64_console.exe"
$proj = "D:\RTVMOD\.check\project"
New-Item -ItemType Directory -Force -Path "$proj\jcm-freeze" | Out-Null
Copy-Item "D:\RTVMOD\jcm-freeze\jcm-freeze\Main.gd" "$proj\jcm-freeze\Main.gd" -Force
$ErrorActionPreference = "Continue"
& $godot --headless --path $proj --import 2>&1 | Out-Null
$out = & $godot --headless --path $proj --check-only --script "res://jcm-freeze/Main.gd" 2>&1 | Out-String
if (($LASTEXITCODE -ne 0) -or ($out -match "SCRIPT ERROR|Parse Error|Failed to load script")) { Write-Host $out; exit 1 } else { Write-Host "ok jcm-freeze/Main.gd" }
```

Ожидаемый вывод: `ok jcm-freeze/Main.gd`.

Сборка и установка:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File D:\RTVMOD\jcm-freeze\pack.ps1
Copy-Item D:\RTVMOD\jcm-freeze\Freeze.vmz "D:\SteamLibrary\steamapps\common\Road to Vostok\mods\" -Force
```

Ожидаемый вывод pack: `Version in mod.txt: 1.0.0`, `+ mod.txt`, `+ jcm-freeze/Main.gd`, `Pack done: ... (2 entries, N KB)`.

**In-game gate 1** (запускает пользователь): JCM → вкладка **AI** → внизу под разделителем тумблер **Freeze NPC**; щёлкается, в логе нет ошибок; после рестарта состояние сохранено. Заморозки пока нет — это норма (хук не ставился). При снятии `JCM.vmz` аддон модлоадер не грузит (`required` зависимость) — проверить один раз.

---

### Task 2 — Заморозка пехоты (replace-хук)

**Files**
- `jcm-freeze/mod.txt` — добавить `[hooks]`.
- `jcm-freeze/jcm-freeze/Main.gd` — добавить регистрацию хука и колбэк.

**Steps**

1. `mod.txt` — добавить секцию (декларирует wrap-поверхность; сам callback регистрируется `hook()` в рантайме — оба заявления обязательны, см. контракт `modloader.gd:14510–14514`):

   ```ini
   [hooks]
   res://Scripts/AI.gd = _physics_process
   ```

2. `Main.gd` — добавить в конец `_on_lib_ready` строку `_register_hooks()`, и:

   ```gdscript
   func _register_hooks() -> void:
   	var id = _lib.hook("ai-_physics_process", _on_ai_process)
   	if id == -1:
   		push_warning("[Freeze] ai-_physics_process is owned by another mod; Freeze NPC will not work")


   func _on_ai_process(_delta) -> void:
   	if _npc_on:
   		_lib.skip_super()
   ```

   Обязательно литеральная строка `"ai-_physics_process"`: модлоадер сканирует исходники аддонов на `.hook("...")` и по ней резолвит `res://Scripts/AI.gd` (`modloader.gd:7001–7017`, `7457–7468`). Имя, собранное в рантайме, зарегистрируется, но «никогда не выстрелит» без заявления в `[hooks]`.

**Verification**

Тот же парсинг-стенд (команда из Task 1, ожидаемо `ok jcm-freeze/Main.gd`), затем pack + install (команды Task 1; вывод pack теперь `3 entries`).

**In-game gate 2** (запускает пользователь):
- карта с бандитами: Freeze NPC **on** → все боты мгновенно статуи (без дыхания/покачивания), **off** → оживают;
- свежий спавн при включённом тумблере замораживается на первом кадре;
- мёртвые тела и пул неактивных ботов не трогаются (у них `active=false`, vanilla всё равно ранит `if !active: return`, наш колбэк трогать ничего не должен);
- переход карты при включённом тумблере: заморозка продолжает работать;
- рестарт игры: JCM восстанавливает состояние, аддон продолжает замораживать;
- в логе нет `[Freeze]`-предупреждений; если есть `[Freeze] ai-_physics_process is owned...` — сообщить (конфликт replace-слота);
- если после переключения слышно/видно, что «модлоадер перезапустился» — это ожидаемый rebuild hook pack после установки нового мода.

**Known risk из спеки**: у AI анимация продвигается вручную (`AI.gd:548–563`, `animator.advance()`), а `Deactivate()`/`Freeze()` ставят `callback_mode = MANUAL` (`AI.gd:166–167`, `188–189`); сцены ботов лежат в бинарных `.tscn` — дефолтный callback mode непроверяем. Если в gate 2 видны остаточные подвижки (дыхание) — обсудить с пользователем фолбек (в колбэке глушить `animator` через `_lib._caller`), до этого фолбека не пишем.

---

## Follow-up (не в этом патче, версия 1.1.0)

«Freeze BTR & Heli» (`jcm-freeze.vehicles`), тот же паттерн: replace-хуки `btr-_physics_process` и `helicopter-_physics_process` + `[hooks]` для `res://Scripts/BTR.gd` и `res://Scripts/Helicopter.gd`, общий флаг `_vehicles_on`, оба тумблера регистрируются в `_on_lib_ready`. Открытые пункты:
- у BTR: скрипт сам зовёт `Audio(delta)` (`BTR.gd:146–154`) — проверить в игре, не продолжает ли звучать движок; фолбек — глушить аудио-узлы через `_lib._caller`;
- у Helicopter: наличие `_physics_process` не подтверждено (файл бинарный, headless-проба не отработала) — проверить при реализации: если метода нет, движение может жить в `_process`/физике, тогда `process_mode = DISABLED` на корень через `_caller` + трекинг узлов.

## Открытые вопросы

Нет. Коммиты по завершении — только по явной команде пользователя.
