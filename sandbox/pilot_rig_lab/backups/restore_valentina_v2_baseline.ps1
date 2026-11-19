<#
.SYNOPSIS
    Restaura el snapshot inmutable "valentina_v2_clean_baseline" de Valentina v2.
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File sandbox/pilot_rig_lab/backups/restore_valentina_v2_baseline.ps1 -MetaOnly
    powershell -ExecutionPolicy Bypass -File sandbox/pilot_rig_lab/backups/restore_valentina_v2_baseline.ps1 -DryRun
#>
param(
    [switch]$MetaOnly,
    [switch]$ShadersOnly,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$snapDir = Join-Path $scriptDir "valentina_v2_clean_baseline"
$manifestPath = Join-Path $snapDir "MANIFEST.json"
$repoRoot = Resolve-Path (Join-Path $scriptDir "..\..\..")

if (-not (Test-Path $manifestPath)) {
    throw "No se encontro MANIFEST.json en $snapDir"
}

$manifest = Get-Content -Path $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$restored = 0

foreach ($entry in $manifest.files) {
    $sub = [string]$entry.snapshot
    $isMeta = ($sub -like "combat_assets/valentina_v2_planar/*/parts_5/parts_5_meta.json") `
        -or ($sub -eq "combat_assets/valentina_v2_planar/heads/heads_metadata.json") `
        -or ($sub -eq "combat_assets/valentina_v2_planar/body_metrics.json") `
        -or ($sub -like "proto/leg_*_persp_mask.png")
    $isShader = ($sub -like "*.gdshader") `
        -or ($sub -like "shaders/*.gdshaderinc") `
        -or ($sub -like "data/styles/*.tres")

    if ($MetaOnly -and -not $isMeta) { continue }
    if ($ShadersOnly -and -not $isShader) { continue }

    $srcFile = Join-Path $snapDir $sub
    $dstFile = Join-Path $repoRoot $entry.source
    if (-not (Test-Path $srcFile)) {
        Write-Warning "Archivo faltante en snapshot: $srcFile"
        continue
    }

    if ($DryRun) {
        Write-Host "[DRY-RUN] Restauraria: $($entry.source)"
    } else {
        $dstParent = Split-Path -Parent $dstFile
        if (-not (Test-Path $dstParent)) {
            New-Item -ItemType Directory -Force -Path $dstParent | Out-Null
        }
        Copy-Item -Path $srcFile -Destination $dstFile -Force
    }
    $restored++
}

$mode = if ($MetaOnly) { "MetaOnly" } elseif ($ShadersOnly) { "ShadersOnly" } else { "Completo" }
Write-Host "Restauracion ($mode) finalizada: $restored archivos procesados."
