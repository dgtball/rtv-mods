param(
    [string]$OutFile = ""
)

$ErrorActionPreference = "Stop"

$src = Join-Path $PSScriptRoot "loadouts"
if (-not (Test-Path -LiteralPath $src -PathType Container)) {
    throw "Source folder not found: $src"
}
if (-not $OutFile) {
    $OutFile = Join-Path $PSScriptRoot "Loadouts.vmz"
}

$modTxt = Join-Path $src "mod.txt"
if (Test-Path -LiteralPath $modTxt) {
    $ver = (Select-String -LiteralPath $modTxt -Pattern 'version\s*=\s*"([^"]+)"').Matches.Groups[1].Value
    if ($ver) {
        Write-Host "Version in mod.txt: $ver"
        # Own copy inside the mod namespace: at runtime res://mod.txt is shared
        # by every installed mod and may belong to someone else.
        $verFile = Join-Path $src "mods\VTK\version.txt"
        [System.IO.File]::WriteAllText($verFile, $ver + "`n", (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "  + mods/VTK/version.txt ($ver)"
        # README: first "**Label:** <digits>" line follows mod.txt.
        $readme = Join-Path $PSScriptRoot "README.md"
        if (Test-Path -LiteralPath $readme) {
            $rd = [System.IO.File]::ReadAllText($readme, [System.Text.Encoding]::UTF8)
            $rd2 = [regex]::Replace($rd, '(?m)^(\*\*[^*]+:\*\*\s*)[0-9][0-9a-zA-Z.\-]*', ('${1}' + $ver))
            if ($rd2 -ne $rd) {
                [System.IO.File]::WriteAllText($readme, $rd2, (New-Object System.Text.UTF8Encoding($false)))
                Write-Host "README version synced to $ver"
            }
        }
    }
    else { Write-Warning "mod.txt has no version field" }
} else {
    Write-Warning "mod.txt not found in $src"
}

$entries = @(Get-ChildItem -LiteralPath $src -Recurse -File |
    Where-Object { $_.Name -in @("mod.txt", "version.txt") -or $_.Extension -in @(".gd", ".tres", ".tscn", ".gdshader", ".webp", ".png") } |
    ForEach-Object { $_.FullName.Substring($src.Length).TrimStart([char[]]"\/") -replace "\\", "/" } |
    Sort-Object)

if ($entries.Count -eq 0) {
    throw "Nothing to pack in $src"
}

Add-Type -AssemblyName "System.IO.Compression"
Add-Type -AssemblyName "System.IO.Compression.FileSystem"

$tmpZip = Join-Path ([System.IO.Path]::GetTempPath()) ("loadouts_" + [guid]::NewGuid().ToString("N") + ".vmz")
$stream = [System.IO.File]::Create($tmpZip)
$zip = New-Object System.IO.Compression.ZipArchive($stream, [System.IO.Compression.ZipArchiveMode]::Create)
$utf8 = New-Object System.Text.UTF8Encoding($false)
try {
    foreach ($en in $entries) {
        $srcPath = Join-Path $src ($en -replace "/", "\")
        Write-Host "  + $en"
        if ($en -like "*.gd") {
            # Shipped GDScript is stripped of whole-line comments, blank lines
            # and CR: pure weight saving (about 40%), no code change. The
            # readable sources in loadouts/ stay untouched.
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

if (Test-Path -LiteralPath $OutFile) {
    Remove-Item -LiteralPath $OutFile -Force
}
Move-Item -LiteralPath $tmpZip -Destination $OutFile -Force

$sizeKb = [math]::Round((Get-Item -LiteralPath $OutFile).Length / 1KB, 1)
Write-Host ""
Write-Host "Pack done: $OutFile ($($entries.Count) entries, $sizeKb KB)"
