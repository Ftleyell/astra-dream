# ==============================================================================
# ASTRA DREAM // Herramienta de Sincronización de Assets y Caché de Godot
# Sincroniza Git LFS, purga cachés residuales y reimporta assets en Godot
# ==============================================================================

$ErrorActionPreference = "Continue"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = (Resolve-Path "$ScriptDir\..").Path

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  ASTRA DREAM // SINCRONIZADOR DE ASSETS Y CACHÉ GODOT   " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Asegurar descarga de binarios LFS reales
if (Get-Command git-lfs -ErrorAction SilentlyContinue) {
    Write-Host "`n[*] Sincronizando objetos Git LFS..." -ForegroundColor Yellow
    Push-Location $ProjectRoot
    try {
        git lfs pull
        Write-Host "[+] Objetos Git LFS al día." -ForegroundColor Green
    } catch {
        Write-Host "[!] Aviso al ejecutar git lfs pull: $($_.Exception.Message)" -ForegroundColor Yellow
    } finally {
        Pop-Location
    }
}

# 2. Detectar y purgar texturas .ctex corruptas (< 1 KB) generadas a partir de punteros LFS viejos
$ImportedDir = "$ProjectRoot\.godot\imported"
if (Test-Path $ImportedDir) {
    $StaleCtex = Get-ChildItem -Path $ImportedDir -Filter "*.ctex" -ErrorAction SilentlyContinue | Where-Object { $_.Length -lt 1000 -and $_.Name -notlike "*icon*" }
    if ($StaleCtex -and $StaleCtex.Count -gt 0) {
        Write-Host "`n[*] Detectadas $($StaleCtex.Count) texturas corruptas/dummy en caché. Purgando..." -ForegroundColor Yellow
        foreach ($f in $StaleCtex) {
            Remove-Item -Path $f.FullName -Force -ErrorAction SilentlyContinue
            $md5Path = $f.FullName -replace '\.ctex$', '.md5'
            if (Test-Path $md5Path) {
                Remove-Item -Path $md5Path -Force -ErrorAction SilentlyContinue
            }
        }
        Write-Host "[+] Caché corrupta purgada con éxito." -ForegroundColor Green
    }
}

# 3. Localizar ejecutable de Godot Engine (4.7+)
$GodotExe = $null

# Chequeo 1: En raíz del proyecto
$RootGodot = Get-ChildItem -Path $ProjectRoot -Filter "*godot*console*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $RootGodot) {
    $RootGodot = Get-ChildItem -Path $ProjectRoot -Filter "*godot*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
}
if ($RootGodot) {
    $GodotExe = $RootGodot.FullName
}

# Chequeo 2: En PATH global
if (-not $GodotExe) {
    $PathGodot = Get-Command godot -ErrorAction SilentlyContinue
    if ($PathGodot) {
        $GodotExe = $PathGodot.Source
    }
}

# Chequeo 3: En WinGet Packages
if (-not $GodotExe) {
    $WinGetCandidate = Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter "*godot*console*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $WinGetCandidate) {
        $WinGetCandidate = Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter "*godot*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    if ($WinGetCandidate) {
        $GodotExe = $WinGetCandidate.FullName
    }
}

if (-not $GodotExe) {
    Write-Host "`n[!] ADVERTENCIA: No se localizó el ejecutable de Godot en el PATH ni en WinGet." -ForegroundColor Red
    Write-Host "    Asegúrate de tener Godot 4.7+ instalado para que el reimport funcione." -ForegroundColor Yellow
    exit 0
}

# 4. Ejecutar reimportación en segundo plano (headless editor scan)
Write-Host "`n[*] Ejecutando reimportación headless en Godot Engine..." -ForegroundColor Yellow
Write-Host "    Binario: $GodotExe" -ForegroundColor DarkGray

try {
    $proc = Start-Process -FilePath $GodotExe -ArgumentList "--headless", "--path", "`"$ProjectRoot`"", "--editor", "--quit" -NoNewWindow -PassThru -Wait
    Write-Host "[+] Reimportación completada. Caché .godot/imported/ actualizada al 100%." -ForegroundColor Green
} catch {
    Write-Host "[!] Error al ejecutar Godot: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "==========================================================" -ForegroundColor Cyan
