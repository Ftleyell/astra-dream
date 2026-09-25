# ==============================================================================
# ASTRA DREAM // AUTO-LAUNCHER
# Compatible con Windows 10 y 11 Out-Of-The-Box (sin requerir Git ni Python)
# ==============================================================================

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
$Host.UI.RawUI.WindowTitle = "Astra Dream // Auto-Launcher"

function Show-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "  ========================================================================" -ForegroundColor Cyan
    Write-Host "                    *  ASTRA DREAM // AUTO-LAUNCHER  *                    " -ForegroundColor Cyan
    Write-Host "                 Sincronizador Automatico de Versiones (Master)           " -ForegroundColor DarkCyan
    Write-Host "  ========================================================================" -ForegroundColor Cyan
    Write-Host ""
}

Show-Banner

# Determinar directorios clave
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "$ScriptDir\..\project.godot") {
    $GameDir = (Resolve-Path "$ScriptDir\..").Path
} elseif (Test-Path "$ScriptDir\project.godot") {
    $GameDir = (Resolve-Path "$ScriptDir").Path
} else {
    $GameDir = (Resolve-Path "$ScriptDir").Path
}

$VersionFile = "$GameDir\version.sha"
$RepoOwner = "Ftleyell"
$RepoName = "astra-dream"
$Branch = "master"
$ApiUrl = "https://api.github.com/repos/$RepoOwner/$RepoName/commits/$Branch"
$ZipUrl = "https://github.com/$RepoOwner/$RepoName/archive/refs/heads/$Branch.zip"

Write-Host "  [1/2] Verificando parches en GitHub (origin/$Branch)..." -ForegroundColor Yellow

$RemoteSha = $null
$CommitMsg = ""

# 1. Comprobar si se ejecuta dentro de un repositorio Git con CLI disponible
$HasGit = (Test-Path "$GameDir\.git") -and (Get-Command git -ErrorAction SilentlyContinue)

if ($HasGit) {
    Write-Host "        Entorno de desarrollo Git detectado. Sincronizando..." -ForegroundColor Gray
    try {
        Push-Location $GameDir
        git pull origin $Branch --quiet
        if (Get-Command git-lfs -ErrorAction SilentlyContinue) {
            git lfs pull *>$null
        }
        $RemoteSha = (git rev-parse HEAD).Trim()
        Pop-Location
        Write-Host "  [+] Repositorio Git sincronizado al ultimo commit: $($RemoteSha.Substring(0,7))" -ForegroundColor Green
    } catch {
        Write-Host "  [!] Aviso: No se pudo ejecutar git pull. Continuando con archivos locales..." -ForegroundColor Yellow
    }
} else {
    # 2. Modo Portatil / Out-Of-The-Box (Sin Git instalado)
    try {
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent", "AstraDreamLauncher")
        $wc.Headers.Add("Accept", "application/vnd.github.v3+json")
        $jsonStr = $wc.DownloadString($ApiUrl)
        $wc.Dispose()

        if ($jsonStr) {
            $parsed = ConvertFrom-Json $jsonStr
            if ($parsed -and $parsed.sha) {
                $RemoteSha = $parsed.sha
                if ($parsed.commit -and $parsed.commit.message) {
                    $lines = $parsed.commit.message -split "`r`n|`r|`n"
                    $CommitMsg = $lines[0]
                }
            }
        }
    } catch {
        Write-Host "  [!] No se pudo conectar con GitHub ($($_.Exception.Message))." -ForegroundColor Yellow
        Write-Host "      Iniciando el juego con la version local disponible..." -ForegroundColor Gray
    }

    if ($RemoteSha) {
        $LocalSha = ""
        if (Test-Path $VersionFile) {
            $LocalSha = (Get-Content $VersionFile -Raw).Trim()
        }

        if ($LocalSha -eq $RemoteSha) {
            Write-Host "  [+] El juego esta al dia con la version mas reciente de GitHub!" -ForegroundColor Green
            Write-Host "      Version instalada: $($RemoteSha.Substring(0,7))" -ForegroundColor DarkGray
        } else {
            Write-Host "  [*] NUEVO PARCHE DETECTADO EN GITHUB!" -ForegroundColor Magenta
            Write-Host "      Ultimo Commit: $($RemoteSha.Substring(0,7)) - $CommitMsg" -ForegroundColor Cyan
            Write-Host "      Descargando actualizacion automatica desde master..." -ForegroundColor Yellow

            $TempZip = "$GameDir\_patch_temp.zip"
            $TempExtract = "$GameDir\_patch_extracted"

            try {
                $downloader = New-Object System.Net.WebClient
                $downloader.Headers.Add("User-Agent", "AstraDreamLauncher")
                $downloader.DownloadFile($ZipUrl, $TempZip)
                $downloader.Dispose()

                Write-Host "      Extrayendo archivos del parche..." -ForegroundColor Gray
                if (Test-Path $TempExtract) {
                    Remove-Item -Recurse -Force $TempExtract
                }
                Expand-Archive -Path $TempZip -DestinationPath $TempExtract -Force

                $ExtractedRoot = "$TempExtract\$RepoName-$Branch"
                if (Test-Path $ExtractedRoot) {
                    Copy-Item -Path "$ExtractedRoot\*" -Destination $GameDir -Recurse -Force
                }

                Set-Content -Path $VersionFile -Value $RemoteSha -Force

                Write-Host "  [+] Juego actualizado con exito a la version $($RemoteSha.Substring(0,7))!" -ForegroundColor Green
            } catch {
                Write-Host "  [!] Error al descargar o aplicar el parche: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "      Continuando con los archivos locales..." -ForegroundColor Gray
            } finally {
                if (Test-Path $TempZip) { Remove-Item -Force $TempZip -ErrorAction SilentlyContinue }
                if (Test-Path $TempExtract) { Remove-Item -Recurse -Force $TempExtract -ErrorAction SilentlyContinue }
            }
        }
    }
}

Write-Host ""
Write-Host "  [2/2] Buscando ejecutable de Astra Dream..." -ForegroundColor Yellow

# Buscar el ejecutable en orden de prioridad
$ExecutablesToTry = @(
    "$GameDir\AstraDream.exe",
    "$GameDir\builds\AstraDream_PreAlpha\AstraDream.exe",
    "$GameDir\builds\AstraDream.exe",
    "$GameDir\AstraDream_Console.exe"
)

$FoundExe = $null
foreach ($exe in $ExecutablesToTry) {
    if (Test-Path $exe) {
        $FoundExe = (Resolve-Path $exe).Path
        break
    }
}

if ($FoundExe) {
    Write-Host "  [+] Ejecutable encontrado: $(Split-Path -Leaf $FoundExe)" -ForegroundColor Green
    Write-Host "  >> Iniciando Astra Dream... Que disfrutes la partida!" -ForegroundColor Cyan
    Write-Host ""

    Start-Process -FilePath $FoundExe -WorkingDirectory (Split-Path -Parent $FoundExe)
    Start-Sleep -Seconds 2
} else {
    $GodotExe = "godot"
    $GodotCmd = Get-Command godot -ErrorAction SilentlyContinue
    if (-not $GodotCmd) {
        $WinGetCandidate = (Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter "*godot*console*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
        if (-not $WinGetCandidate) {
            $WinGetCandidate = (Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter "*godot*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
        }
        if ($WinGetCandidate -and (Test-Path $WinGetCandidate)) {
            $GodotExe = $WinGetCandidate
            $GodotCmd = $true
        }
    }
    if ($GodotCmd) {
        Write-Host "  [*] Sincronizando e importando assets con el motor Godot..." -ForegroundColor Yellow
        & $GodotExe --headless --path $GameDir --editor --quit
        Write-Host "  [+] Godot listo. Lanzando Astra Dream..." -ForegroundColor Green
        Start-Process -FilePath $GodotExe -ArgumentList "--path `"$GameDir`"" -WorkingDirectory $GameDir
        Start-Sleep -Seconds 2
    } else {
        Write-Host "  [!] No se encontro AstraDream.exe en esta carpeta." -ForegroundColor Red
        Write-Host "      Por favor coloca AstraDream.exe en la misma carpeta que el launcher." -ForegroundColor Yellow
        Write-Host ""
        Read-Host "  Presiona ENTER para cerrar el launcher..."
    }
}
