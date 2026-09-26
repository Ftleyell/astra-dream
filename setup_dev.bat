@echo off
setlocal
title Astra Dream // Developer Setup ^& Git Hooks
cd /d "%~dp0"

echo ========================================================================
echo         ASTRA DREAM // CONFIGURACION DE ENTORNO DE DESARROLLO
echo ========================================================================
echo.

REM 1. Verificar Git
where git >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [!] ERROR: Git no esta instalado o no esta en el PATH.
    echo     Por favor instala Git desde https://git-scm.com/
    pause
    exit /b 1
)

REM 2. Configurar Git Hooks automaticos (.githooks)...
echo [*] Configurando Git Hooks automaticos (.githooks)...
git config core.hooksPath .githooks
if %ERRORLEVEL% equ 0 (
    echo [+] Hooks activados: 'git pull' y 'git checkout' sincronizaran assets automaticamente.
) else (
    echo [!] Advertencia: No se pudo configurar core.hooksPath.
)
echo.

REM 3. Configurar e inicializar Git LFS
echo [*] Verificando e instalando Git LFS...
where git-lfs >nul 2>&1
if %ERRORLEVEL% equ 0 (
    git lfs install --skip-repo
    echo [+] Filtros Git LFS configurados correctamente.
) else (
    echo [!] ADVERTENCIA: Git LFS no esta instalado.
    echo     Instala Git LFS desde https://git-lfs.com/ para que las imagenes
    echo     y modelos 3D se descarguen completos y no como punteros de texto.
)
echo.

REM 4. Ejecutar sincronizacion inicial de assets y cache de Godot
echo [*] Ejecutando sincronizacion inicial de assets y reconstruccion de cache...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\sync_assets.ps1"

echo.
echo ========================================================================
echo   [+] CONFIGURACION COMPLETADA CON EXITO!
echo.
echo   De ahora en adelante:
echo   - Cada vez que hagas 'git pull', los assets se descargaran y se
echo     reimportaran solos en Godot.
echo   - Puedes lanzar el juego para desarrollo ejecutando: dev_run.bat
echo   - O manualmente sincronizar en cualquier momento: tools\sync_assets.ps1
echo ========================================================================
echo.
pause
exit /b 0