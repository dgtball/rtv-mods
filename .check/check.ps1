param(
    [string]$Godot = ""
)

$ErrorActionPreference = "Stop"

$checkRoot = $PSScriptRoot
$proj = Join-Path $checkRoot "project"
$modSrc = Join-Path (Split-Path $checkRoot -Parent) "loadouts\mods\VTK"
$modDst = Join-Path $proj "mods\VTK"

if (-not $Godot) {
    $candidates = @(
        "Godot_v4.6.3-stable_win64_console.exe",
        "godot.exe",
        "godot4.exe"
    )
    $found = $null
    foreach ($c in $candidates) {
        $cmd = Get-Command $c -ErrorAction SilentlyContinue
        if ($cmd) { $found = $cmd.Source; break }
    }
    if (-not $found) {
        $repoRoot = Split-Path $checkRoot -Parent
        $found = Get-ChildItem -Path (Join-Path $repoRoot "tools") -Filter "*_console.exe" -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty FullName
    }
    if (-not $found) { throw "Godot binary not found. Pass -Godot <path to Godot_*_console.exe>" }
    $Godot = $found
}

if (-not (Test-Path -LiteralPath $Godot -PathType Leaf)) { throw "Godot binary not found: $Godot" }
if (-not (Test-Path -LiteralPath $modSrc -PathType Container)) { throw "Mod sources not found: $modSrc" }

Write-Host "Godot: $Godot"
& $Godot --headless --version

if (Test-Path -LiteralPath $modDst) { Remove-Item -LiteralPath $modDst -Recurse -Force }
New-Item -ItemType Directory -Force -Path $modDst | Out-Null
Copy-Item -Path (Join-Path $modSrc "*.gd") -Destination $modDst -Force
Copy-Item -Path (Join-Path $modSrc "*.tres") -Destination $modDst -Force -ErrorAction SilentlyContinue
Copy-Item -Path (Join-Path $modSrc "*.gdshader") -Destination $modDst -Force -ErrorAction SilentlyContinue

$altSrc = Join-Path (Split-Path $checkRoot -Parent) "standalone mods\ThermalVTK\mods\ThermalVTK"
$altDst = Join-Path $proj "mods\ThermalVTK"
if (Test-Path -LiteralPath $altSrc -PathType Container) {
    if (Test-Path -LiteralPath $altDst) { Remove-Item -LiteralPath $altDst -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $altDst | Out-Null
    Copy-Item -Path (Join-Path $altSrc "*.gd") -Destination $altDst -Force -ErrorAction SilentlyContinue
    Copy-Item -Path (Join-Path $altSrc "*.gdshader") -Destination $altDst -Force -ErrorAction SilentlyContinue
}

$lshSrc = Join-Path (Split-Path $checkRoot -Parent) "standalone mods\LooterShooter\mods\LooterShooter"
$lshDst = Join-Path $proj "mods\LooterShooter"
if (Test-Path -LiteralPath $lshSrc -PathType Container) {
    if (Test-Path -LiteralPath $lshDst) { Remove-Item -LiteralPath $lshDst -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $lshDst | Out-Null
    Copy-Item -Path (Join-Path $lshSrc "*.gd") -Destination $lshDst -Force -ErrorAction SilentlyContinue
    $lshSub = Join-Path $lshSrc "Scripts"
    if (Test-Path -LiteralPath $lshSub -PathType Container) {
        New-Item -ItemType Directory -Force -Path (Join-Path $lshDst "Scripts") | Out-Null
        Copy-Item -Path (Join-Path $lshSub "*.gd") -Destination (Join-Path $lshDst "Scripts") -Force -ErrorAction SilentlyContinue
    }
}

# LooterShooter's SlotData override extends the vanilla res://Scripts path; the
# stand's stand-in for that script lives at .check/project/Scripts/SlotData.gd
# (hand-maintained, like the stubs) and must NOT be overwritten here.

$rtlSrc = Join-Path (Split-Path $checkRoot -Parent) "standalone mods\RoadToLoot\mods\RoadToLoot"
$rtlDst = Join-Path $proj "mods\RoadToLoot"
if (Test-Path -LiteralPath $rtlSrc -PathType Container) {
    if (Test-Path -LiteralPath $rtlDst) { Remove-Item -LiteralPath $rtlDst -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $rtlDst | Out-Null
    Copy-Item -Path (Join-Path $rtlSrc "*.gd") -Destination $rtlDst -Force
}

# Wipe the whole .godot cache, not just the class cache. The editor cache holds
# already-compiled dependency data, so a script that was broken in a previous run
# could still verify "ok" against its stale compiled copy -- which is exactly how
# a typo'd constant slipped through and took VTKUI down with it. Force a
# clean recompile every run so the check reflects the sources on disk.
$godotCache = Join-Path $proj ".godot"
if (Test-Path -LiteralPath $godotCache) { Remove-Item -LiteralPath $godotCache -Recurse -Force }

$ErrorActionPreference = "Continue"
& $Godot --headless --path $proj --import 2>&1 | Out-Null

$fail = 0
$scripts = Get-ChildItem -LiteralPath $modDst -Filter "*.gd" | Sort-Object Name
foreach ($s in $scripts) {
    $res = "res://mods/VTK/" + $s.Name
    $out = & $Godot --headless --path $proj --check-only --script $res 2>&1 | Out-String
    $bad = ($LASTEXITCODE -ne 0) -or ($out -match "SCRIPT ERROR|Parse Error|Failed to load script")
    if ($bad) {
        $fail++
        Write-Host "FAIL  $($s.Name)"
        Write-Host $out.Trim()
    } else {
        Write-Host "ok    $($s.Name)"
    }
}

if (Test-Path -LiteralPath $altDst -PathType Container) {
    $altScripts = Get-ChildItem -LiteralPath $altDst -Filter "*.gd" | Sort-Object Name
    foreach ($s in $altScripts) {
        $res = "res://mods/ThermalVTK/" + $s.Name
        $out = & $Godot --headless --path $proj --check-only --script $res 2>&1 | Out-String
        $bad = ($LASTEXITCODE -ne 0) -or ($out -match "SCRIPT ERROR|Parse Error|Failed to load script")
        if ($bad) {
            $fail++
            Write-Host "FAIL  ThermalVTK/$($s.Name)"
            Write-Host $out.Trim()
        } else {
            Write-Host "ok    ThermalVTK/$($s.Name)"
        }
    }
}

if (Test-Path -LiteralPath $lshDst -PathType Container) {
    $lshScripts = Get-ChildItem -LiteralPath $lshDst -Filter "*.gd" | Sort-Object Name
    foreach ($s in $lshScripts) {
        $res = "res://mods/LooterShooter/" + $s.Name
        $out = & $Godot --headless --path $proj --check-only --script $res 2>&1 | Out-String
        $bad = ($LASTEXITCODE -ne 0) -or ($out -match "SCRIPT ERROR|Parse Error|Failed to load script")
        if ($bad) {
            $fail++
            Write-Host "FAIL  LooterShooter/$($s.Name)"
            Write-Host $out.Trim()
        } else {
            Write-Host "ok    LooterShooter/$($s.Name)"
        }
    }
    $lshSubDst = Join-Path $lshDst "Scripts"
    if (Test-Path -LiteralPath $lshSubDst -PathType Container) {
        $lshSubScripts = Get-ChildItem -LiteralPath $lshSubDst -Filter "*.gd" | Sort-Object Name
        foreach ($s in $lshSubScripts) {
            $res = "res://mods/LooterShooter/Scripts/" + $s.Name
            $out = & $Godot --headless --path $proj --check-only --script $res 2>&1 | Out-String
            $bad = ($LASTEXITCODE -ne 0) -or ($out -match "SCRIPT ERROR|Parse Error|Failed to load script")
            if ($bad) {
                $fail++
                Write-Host "FAIL  LooterShooter/Scripts/$($s.Name)"
                Write-Host $out.Trim()
            } else {
                Write-Host "ok    LooterShooter/Scripts/$($s.Name)"
            }
        }
    }
}

if (Test-Path -LiteralPath $rtlDst -PathType Container) {
    $rtlScripts = Get-ChildItem -LiteralPath $rtlDst -Filter "*.gd" | Sort-Object Name
    foreach ($s in $rtlScripts) {
        $res = "res://mods/RoadToLoot/" + $s.Name
        $out = & $Godot --headless --path $proj --check-only --script $res 2>&1 | Out-String
        $bad = ($LASTEXITCODE -ne 0) -or ($out -match "SCRIPT ERROR|Parse Error|Failed to load script")
        if ($bad) {
            $fail++
            Write-Host "FAIL  RoadToLoot/$($s.Name)"
            Write-Host $out.Trim()
        } else {
            Write-Host "ok    RoadToLoot/$($s.Name)"
        }
    }
}

Write-Host ""
if ($fail -ne 0) {
    Write-Warning "Parse check failed: $fail of $($scripts.Count) scripts"
    exit 1
}

Write-Host "Parse check passed: $($scripts.Count) scripts"

# ������ ������� ����� ������ ����������: ����� ����������� ���� �������� �� ���
# ������ ������, ������� ���������� ��������� ����.
$tests = @("res://tests/test_draft.gd", "res://tests/test_picker.gd", "res://tests/test_hooks.gd", "res://tests/test_feed.gd", "res://tests/test_spawn.gd", "res://tests/test_notes.gd", "res://tests/test_deposits.gd", "res://tests/test_data.gd", "res://tests/test_equip.gd", "res://tests/test_composite.gd", "res://tests/test_travel.gd", "res://tests/test_items.gd", "res://tests/test_config.gd", "res://tests/test_session.gd", "res://tests/test_seasons.gd", "res://tests/test_states.gd", "res://tests/test_tracker.gd", "res://tests/test_shaders.gd", "res://tests/test_outline.gd", "res://tests/test_debug.gd", "res://tests/test_weapon.gd",
        "res://tests/test_esp.gd", "res://tests/test_preset.gd", "res://tests/test_profile.gd", "res://tests/test_lsh_slotdata.gd", "res://tests/test_lsh_pool.gd", "res://tests/test_lsh_roll.gd", "res://tests/test_lsh_category.gd", "res://tests/test_lsh_config.gd", "res://tests/test_probe.gd", "res://tests/test_calibration.gd", "res://tests/test_settings.gd", "res://tests/test_daylight.gd", "res://tests/test_daylight_runtime.gd", "res://tests/test_nvg.gd", "res://tests/test_labels.gd", "res://tests/test_label_layout.gd",
        "res://tests/test_rtl_pool.gd", "res://tests/test_rtl_roll.gd", "res://tests/test_rtl_stats.gd", "res://tests/test_rtl_text.gd", "res://tests/test_rtl_rows.gd", "res://tests/test_rtl_category.gd", "res://tests/test_sidecar.gd", "res://tests/test_store.gd", "res://tests/test_rtl_persist.gd")
foreach ($t in $tests) {
    $tp = Join-Path $proj ($t -replace '^res://', '' -replace '/', '\')
    if (-not (Test-Path -LiteralPath $tp -PathType Leaf)) { throw "Test script missing: $t" }
}

$fail = 0
foreach ($t in $tests) {
    $name = Split-Path $t -Leaf
    Write-Host "--- $name ---"
    # Cap frames: an aborted _init() never reaches quit(), and without this the
    # runner would spin forever instead of letting the verdict logic fire.
    $tout = & $Godot --headless --path $proj --script $t --quit-after 600 2>&1 | Out-String
    Write-Host $tout.Trim()
    # ��� �������� ��������: ������ ������ _init() ��������� �������� �� quit(),
    # � Godot ������� � 0, ���� ���� �� ���������. ������� ������� ��������� ��
    # ��� ��������� �����: ���� ������ ������, ��� "FAIL", ��� ������ �������.
    $ok_line = $tout -match "tests passed"
    $broke = ($tout -match "FAIL") -or ($tout -match "SCRIPT ERROR|Parse Error|Invalid call|Failed to load script")
    if (($LASTEXITCODE -ne 0) -or $broke -or (-not $ok_line)) {
        Write-Host "VERDICT: FAIL  $name"
        $fail++
    } else {
        Write-Host "VERDICT: ok    $name"
    }
}
if ($fail -ne 0) {
    Write-Warning "Tests failed: $fail file(s)"
    exit 1
}
Write-Host "Tests passed: $($tests.Count) file(s)"
