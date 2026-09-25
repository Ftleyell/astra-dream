# ==============================================================================
# Script para compilar AstraLauncher.exe autocontenido
# Empaqueta AstraDream.exe + AstraDream.pck + version.sha en un solo .exe
# ==============================================================================
param(
    [switch]$SkipExport = $false
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = (Resolve-Path "$ScriptDir\..").Path
$BuildsDir = "$ProjectRoot\builds"
$PreAlphaDir = "$BuildsDir\AstraDream_PreAlpha"
$CscPath = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "         COMPILADOR DE ASTRALAUNCHER (STANDALONE)         " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Exportar PCK actualizado si no se omite
if (-not $SkipExport) {
    Write-Host "`n[1/4] Exportando nuevo AstraDream.pck con Godot..." -ForegroundColor Yellow
    $GodotExe = "$ProjectRoot\Godot_v4.7.2-stable_win64_console.exe"
    if (-not (Test-Path $GodotExe)) {
        $WinGetCandidate = (Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter "*godot*console*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
        if ($WinGetCandidate -and (Test-Path $WinGetCandidate)) {
            $GodotExe = $WinGetCandidate
        } else {
            $GodotExe = "godot"
        }
    }
    Write-Host "    Usando Godot: $GodotExe" -ForegroundColor Gray
    & $GodotExe --headless --export-pack "Windows Desktop" "$PreAlphaDir\AstraDream.pck"
    Write-Host "[+] AstraDream.pck exportado con exito." -ForegroundColor Green
} else {
    Write-Host "`n[1/4] Omitiendo exportacion de PCK (usando existente)..." -ForegroundColor Gray
}

# 2. Actualizar version.sha
Write-Host "`n[2/4] Registrando version de commit..." -ForegroundColor Yellow
$Sha = "unknown"
try {
    $Sha = (git rev-parse HEAD).Trim()
} catch {
    if (Test-Path "$PreAlphaDir\version.sha") {
        $Sha = (Get-Content "$PreAlphaDir\version.sha" -Raw).Trim()
    }
}
Set-Content -Path "$PreAlphaDir\version.sha" -Value $Sha
Write-Host "[+] Version SHA: $Sha" -ForegroundColor Green

# 3. Empaquetar payload.zip
Write-Host "`n[3/4] Creando payload comprimido (Zip)..." -ForegroundColor Yellow
$PayloadZip = "$BuildsDir\payload.zip"
if (Test-Path $PayloadZip) { Remove-Item -Force $PayloadZip }

$FilesToZip = @(
    "$PreAlphaDir\AstraDream.exe",
    "$PreAlphaDir\AstraDream.pck",
    "$PreAlphaDir\version.sha",
    "$PreAlphaDir\LEEME_PLAYTEST.txt"
)

Compress-Archive -Path $FilesToZip -DestinationPath $PayloadZip -CompressionLevel Optimal
$ZipSizeMB = [math]::Round(((Get-Item $PayloadZip).Length / 1MB), 2)
Write-Host "[+] Payload generado: $ZipSizeMB MB" -ForegroundColor Green

# 4. Compilar C# AstraLauncher.exe
Write-Host "`n[4/4] Compilando AstraLauncher.exe autocontenido con csc.exe..." -ForegroundColor Yellow
$LauncherSource = "$ProjectRoot\tools\AstraLauncher.cs"
$TargetExe = "$BuildsDir\AstraLauncher.exe"

$IcoPath = "$ProjectRoot\assets\icon.ico"
$IconArg = if (Test-Path $IcoPath) { "/win32icon:$IcoPath" } else { "" }

& $CscPath /target:exe /optimize+ `
    /r:System.dll /r:System.Core.dll /r:System.IO.Compression.dll /r:System.IO.Compression.FileSystem.dll `
    "/resource:$PayloadZip,payload.zip" `
    $IconArg `
    "/out:$TargetExe" `
    "$LauncherSource"

if (Test-Path $TargetExe) {
    Copy-Item $TargetExe -Destination "$PreAlphaDir\AstraLauncher.exe" -Force
    Copy-Item $TargetExe -Destination "$ProjectRoot\AstraLauncher.exe" -Force
    $ExeSizeMB = [math]::Round(((Get-Item $TargetExe).Length / 1MB), 2)
    Write-Host "`n==========================================================" -ForegroundColor Green
    Write-Host "[SUCCESS] AstraLauncher.exe generado exitosamente!" -ForegroundColor Green
    Write-Host "Tamano final del ejecutable autocontenido: $ExeSizeMB MB" -ForegroundColor Cyan
    Write-Host "Ubicaciones:" -ForegroundColor Gray
    Write-Host " - $TargetExe" -ForegroundColor Gray
    Write-Host " - $PreAlphaDir\AstraLauncher.exe" -ForegroundColor Gray
    Write-Host " - $ProjectRoot\AstraLauncher.exe" -ForegroundColor Gray
    Write-Host "==========================================================" -ForegroundColor Green
} else {
    Write-Host "`n[ERROR] Fallo la generacion de AstraLauncher.exe" -ForegroundColor Red
}
