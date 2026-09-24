@echo off
setlocal enabledelayedexpansion
title Astra Dream // Launcher
cd /d "%~dp0"

if exist "%~dp0tools\launcher.ps1" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\launcher.ps1"
) else if exist "%~dp0launcher.ps1" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0launcher.ps1"
) else (
    echo.
    echo ========================================================================
    echo   [!] ERROR: No se encontro el archivo launcher.ps1.
    echo       Asegurate de descomprimir todos los archivos del juego juntos.
    echo ========================================================================
    echo.
    pause
)
endlocal
