@echo off
setlocal
title Astra Dream // Dev Runner
cd /d "%~dp0"

echo ========================================================================
echo               ASTRA DREAM // DEV LAUNCHER ^& ASSET SYNC
echo ========================================================================
echo.

where godot >nul 2>&1
if %ERRORLEVEL% equ 0 (
    set "GODOT_EXE=godot"
    goto :run_godot
)

for /f "delims=" %%i in ('powershell -NoProfile -Command "(Get-ChildItem -Path \"$env:LOCALAPPDATA\Microsoft\WinGet\Packages\" -Recurse -Filter \"*godot*.exe\" -ErrorAction SilentlyContinue | Select-Object -First 1).FullName"') do (
    set "GODOT_EXE=%%i"
)

if defined GODOT_EXE (
    if exist "%GODOT_EXE%" goto :run_godot
)

echo [!] ERROR: No se encontro el ejecutable de Godot en el PATH ni en WinGet.
echo     Asegurate de tener Godot 4.7+ instalado.
echo.
pause
exit /b 1

:run_godot
if exist "%~dp0tools\sync_assets.ps1" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\sync_assets.ps1"
) else (
    echo [*] Sincronizando e importando assets/scripts con Godot...
    "%GODOT_EXE%" --headless --path "%~dp0." --editor --quit >nul 2>&1
)

echo [+] Iniciando Astra Dream...
start "" "%GODOT_EXE%" --path "%~dp0."
exit /b 0
