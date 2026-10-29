param(
    [string]$Godot = ""
)

$ErrorActionPreference = "Stop"

$checkRoot = $PSScriptRoot
$repoRoot = Split-Path $checkRoot -Parent
$proj = Join-Path $checkRoot "project"

# One row per mod: Slug is the folder under mods\, Folder is the folder name
# inside the .vmz (mods\<Folder>\ at the archive root), Tests is the subfolder
# of .check\project\tests\ holding this mod's test scripts.
$mods = @(
    @{ Slug = "vostok-toolkit"; Folder = "VTK";         Tests = "vostok-toolkit" },
    @{ Slug = "thermal-vtk";    Folder = "ThermalVTK";  Tests = "thermal-vtk" },
    @{ Slug = "road-to-loot";   Folder = "RoadToLoot";  Tests = "road-to-loot" },
    @{ Slug = "jcm-freeze";     Folder = "jcm-freeze";  Tests = $null }
)

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
        $found = Get-ChildItem -Path (Join-Path $repoRoot "tools") -Filter "*_console.exe" -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty FullName
    }
    if (-not $found) { throw "Godot binary not found. Pass -Godot <path to Godot_*_console.exe>" }
    $Godot = $found
}

if (-not (Test-Path -LiteralPath $Godot -PathType Leaf)) { throw "Godot binary not found: $Godot" }

Write-Host "Godot: $Godot"
& $Godot --headless --version

foreach ($m in $mods) {
    $src = Join-Path $repoRoot "mods\$($m.Slug)\mods\$($m.Folder)"
    if (-not (Test-Path -LiteralPath $src -PathType Container)) { throw "Mod sources not found: $src" }
    $dst = Join-Path $proj "mods\$($m.Folder)"
    if (Test-Path -LiteralPath $dst) { Remove-Item -LiteralPath $dst -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $dst | Out-Null
    Copy-Item -Path (Join-Path $src "*.gd") -Destination $dst -Force
    Copy-Item -Path (Join-Path $src "*.tres") -Destination $dst -Force -ErrorAction SilentlyContinue
    Copy-Item -Path (Join-Path $src "*.gdshader") -Destination $dst -Force -ErrorAction SilentlyContinue
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
$checked = 0
foreach ($m in $mods) {
    $dst = Join-Path $proj "mods\$($m.Folder)"
    $scripts = Get-ChildItem -LiteralPath $dst -Filter "*.gd" | Sort-Object Name
    foreach ($s in $scripts) {
        $res = "res://mods/$($m.Folder)/" + $s.Name
        $out = & $Godot --headless --path $proj --check-only --script $res 2>&1 | Out-String
        $bad = ($LASTEXITCODE -ne 0) -or ($out -match "SCRIPT ERROR|Parse Error|Failed to load script")
        $checked++
        if ($bad) {
            $fail++
            Write-Host "FAIL  $($m.Folder)/$($s.Name)"
            Write-Host $out.Trim()
        } else {
            Write-Host "ok    $($m.Folder)/$($s.Name)"
        }
    }
}

Write-Host ""
if ($fail -ne 0) {
    Write-Warning "Parse check failed: $fail of $checked scripts"
    exit 1
}

Write-Host "Parse check passed: $checked scripts"

# Test order is explicit: each test boots its own headless Godot, so an aborted
# _init() only takes down that one script and the run keeps going.
$tests = [ordered]@{
    "vostok-toolkit" = @(
        "res://tests/vostok-toolkit/test_composite.gd", "res://tests/vostok-toolkit/test_config.gd",
        "res://tests/vostok-toolkit/test_data.gd", "res://tests/vostok-toolkit/test_deposits.gd",
        "res://tests/vostok-toolkit/test_draft.gd", "res://tests/vostok-toolkit/test_equip.gd",
        "res://tests/vostok-toolkit/test_feed.gd", "res://tests/vostok-toolkit/test_hooks.gd",
        "res://tests/vostok-toolkit/test_items.gd", "res://tests/vostok-toolkit/test_notes.gd",
        "res://tests/vostok-toolkit/test_picker.gd", "res://tests/vostok-toolkit/test_seasons.gd",
        "res://tests/vostok-toolkit/test_session.gd", "res://tests/vostok-toolkit/test_spawn.gd",
        "res://tests/vostok-toolkit/test_travel.gd")
    "thermal-vtk" = @(
        "res://tests/thermal-vtk/test_calibration.gd", "res://tests/thermal-vtk/test_daylight.gd",
        "res://tests/thermal-vtk/test_daylight_runtime.gd", "res://tests/thermal-vtk/test_debug.gd",
        "res://tests/thermal-vtk/test_esp.gd", "res://tests/thermal-vtk/test_label_layout.gd",
        "res://tests/thermal-vtk/test_labels.gd", "res://tests/thermal-vtk/test_nvg.gd",
        "res://tests/thermal-vtk/test_outline.gd", "res://tests/thermal-vtk/test_preset.gd",
        "res://tests/thermal-vtk/test_probe.gd", "res://tests/thermal-vtk/test_profile.gd",
        "res://tests/thermal-vtk/test_settings.gd", "res://tests/thermal-vtk/test_shaders.gd",
        "res://tests/thermal-vtk/test_states.gd", "res://tests/thermal-vtk/test_tracker.gd",
        "res://tests/thermal-vtk/test_weapon.gd")
    "road-to-loot" = @(
        "res://tests/road-to-loot/test_rtl_category.gd", "res://tests/road-to-loot/test_rtl_persist.gd",
        "res://tests/road-to-loot/test_rtl_pool.gd", "res://tests/road-to-loot/test_rtl_roll.gd",
        "res://tests/road-to-loot/test_rtl_rows.gd", "res://tests/road-to-loot/test_rtl_stats.gd",
        "res://tests/road-to-loot/test_rtl_text.gd", "res://tests/road-to-loot/test_sidecar.gd",
        "res://tests/road-to-loot/test_store.gd")
}
$tests = @($tests.Values | ForEach-Object { $_ })

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
    # Three signals required: the script exits 0, it never printed FAIL or an
    # engine error, and it did print "tests passed". A silent aborted body used
    # to look like a pass because only the "tests passed" line was checked.
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
