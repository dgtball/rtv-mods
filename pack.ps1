param(
    [string]$Mod = "all",
    [string]$OutDir = ""
)

$ErrorActionPreference = "Stop"

# One row per mod: Slug is the folder under mods\, Folder is the folder name
# inside the .vmz (mods\<Folder>\ at the archive root), Artifact is the historic
# file name the players already install, VersionFile says whether the mod ships
# a version.txt next to its scripts (jcm-freeze does not).
$mods = @(
    @{ Slug = "vostok-toolkit"; Folder = "VTK";        Artifact = "Loadouts.vmz";    VersionFile = $true  },
    @{ Slug = "thermal-vtk";    Folder = "ThermalVTK"; Artifact = "ThermalVTK.vmz";  VersionFile = $true  },
    @{ Slug = "road-to-loot";   Folder = "RoadToLoot"; Artifact = "RoadToLoot.vmz";  VersionFile = $true  },
    @{ Slug = "jcm-freeze";     Folder = "jcm-freeze"; Artifact = "Freeze.vmz";      VersionFile = $false }
)

if (-not $OutDir) { $OutDir = Join-Path $PSScriptRoot "dist" }
if (-not (Test-Path -LiteralPath $OutDir -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
}

if ($Mod -eq "all") {
    $selected = $mods
} else {
    $selected = @($mods | Where-Object { $_.Slug -eq $Mod })
    if ($selected.Count -eq 0) {
        throw "Unknown mod: $Mod. Known: $(($mods | ForEach-Object { $_.Slug }) -join ', ')"
    }
}

Add-Type -AssemblyName "System.IO.Compression"
Add-Type -AssemblyName "System.IO.Compression.FileSystem"
$utf8 = New-Object System.Text.UTF8Encoding($false)

foreach ($m in $selected) {
    $src = Join-Path $PSScriptRoot "mods\$($m.Slug)"
    $modTxt = Join-Path $src "mod.txt"
    if (-not (Test-Path -LiteralPath $modTxt -PathType Leaf)) {
        throw "mod.txt not found: $modTxt"
    }

    Write-Host "=== $($m.Slug) ==="
    $ver = (Select-String -LiteralPath $modTxt -Pattern 'version\s*=\s*"([^"]+)"').Matches.Groups[1].Value
    if ($ver) {
        Write-Host "Version in mod.txt: $ver"
        if ($m.VersionFile) {
            # Own copy inside the mod namespace: at runtime res://mod.txt is shared
            # by every installed mod and may belong to someone else.
            $verFile = Join-Path $src "mods\$($m.Folder)\version.txt"
            [System.IO.File]::WriteAllText($verFile, $ver + "`n", $utf8)
            Write-Host "  + mods/$($m.Folder)/version.txt ($ver)"
        }
        # README: first "**Label:** <digits>" line follows mod.txt.
        $readme = Join-Path $src "README.md"
        if (Test-Path -LiteralPath $readme -PathType Leaf) {
            $rd = [System.IO.File]::ReadAllText($readme, [System.Text.Encoding]::UTF8)
            $rd2 = [regex]::Replace($rd, '(?m)^(\*\*[^*]+:\*\*\s*)[0-9][0-9a-zA-Z.\-]*', ('${1}' + $ver))
            if ($rd2 -ne $rd) {
                [System.IO.File]::WriteAllText($readme, $rd2, $utf8)
                Write-Host "README version synced to $ver"
            }
        }
    }
    else { Write-Warning "mod.txt has no version field: $modTxt" }

    $entries = @(Get-ChildItem -LiteralPath $src -Recurse -File |
        Where-Object {
            ($_.Name -in @("mod.txt", "version.txt") -or $_.Extension -in @(".gd", ".tres", ".tscn", ".gdshader", ".webp", ".png")) -and
            ($_.FullName.Substring($src.Length).TrimStart([char[]]"\/") -notmatch '^(assets|tests)[\\/]')
        } |
        ForEach-Object { $_.FullName.Substring($src.Length).TrimStart([char[]]"\/") -replace "\\", "/" } |
        Sort-Object)

    if ($entries.Count -eq 0) {
        throw "Nothing to pack in $src"
    }

    $outFile = Join-Path $OutDir $m.Artifact
    $tmpZip = Join-Path ([System.IO.Path]::GetTempPath()) ("vtkpack_" + [guid]::NewGuid().ToString("N") + ".vmz")
    $stream = [System.IO.File]::Create($tmpZip)
    $zip = New-Object System.IO.Compression.ZipArchive($stream, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($en in $entries) {
            $srcPath = Join-Path $src ($en -replace "/", "\")
            Write-Host "  + $en"
            if ($en -like "*.gd") {
                # Shipped GDScript is stripped of whole-line comments, blank lines
                # and CR: pure weight saving (about 40%), no code change. The
                # readable sources under mods\<slug>\ stay untouched.
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
            }
            else {
                [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $srcPath, $en, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
            }
        }
    }
    finally {
        $zip.Dispose()
        $stream.Dispose()
    }

    if (Test-Path -LiteralPath $outFile) {
        Remove-Item -LiteralPath $outFile -Force
    }
    Move-Item -LiteralPath $tmpZip -Destination $outFile -Force

    $sizeKb = [math]::Round((Get-Item -LiteralPath $outFile).Length / 1KB, 1)
    Write-Host ""
    Write-Host "Pack done: $outFile ($($entries.Count) entries, $sizeKb KB)"
    Write-Host ""
}
