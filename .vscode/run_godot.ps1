# PowerShell runner for Godot tasks in VS Code / Antigravity IDE
param (
    [Parameter(Mandatory = $true)]
    [ValidateSet(
        "projectless",
        "development",
        "external_development",
        "cmdless_development",
        "production",
        "external_production",
        "cmdless_production"
    )]
    [string]$Mode,

    [string]$ProjectPath = "",
    [string]$GodotPath = ""
)

# 1. Resolve Project Root
if (-not $ProjectPath -or $ProjectPath.StartsWith("`${")) {
    $ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
} else {
    $ProjectPath = (Resolve-Path $ProjectPath).Path
}

# 2. Resolve Godot Executables (both GUI and Console counterparts)
function Resolve-GodotExecutables {
    param ([string]$CandidatePath)

    $resolvedBase = $null

    # A. Check explicit candidate argument
    if ($CandidatePath -and -not $CandidatePath.StartsWith("`${") -and (Test-Path $CandidatePath)) {
        $resolvedBase = (Resolve-Path $CandidatePath).Path
    }

    # B. Check .vscode/settings.json
    if (-not $resolvedBase) {
        $settingsPath = Join-Path $PSScriptRoot "settings.json"
        if (Test-Path $settingsPath) {
            try {
                $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
                if ($settings.'godot.consoleExecutablePath' -and (Test-Path $settings.'godot.consoleExecutablePath')) {
                    $resolvedBase = (Resolve-Path $settings.'godot.consoleExecutablePath').Path
                } elseif ($settings.'godot.executablePath' -and (Test-Path $settings.'godot.executablePath')) {
                    $resolvedBase = (Resolve-Path $settings.'godot.executablePath').Path
                } elseif ($settings.'godotTools.editorPath.godot4' -and (Test-Path $settings.'godotTools.editorPath.godot4')) {
                    $resolvedBase = (Resolve-Path $settings.'godotTools.editorPath.godot4').Path
                }
            } catch {}
        }
    }

    # C. Check PATH
    if (-not $resolvedBase) {
        $cmdConsole = Get-Command godot_console -ErrorAction SilentlyContinue
        if ($cmdConsole) {
            $resolvedBase = $cmdConsole.Source
        } else {
            $cmd = Get-Command godot -ErrorAction SilentlyContinue
            if ($cmd) {
                $resolvedBase = $cmd.Source
            }
        }
    }

    # D. Check Known Windows Locations (WinGet, standard installs)
    if (-not $resolvedBase) {
        $knownLocations = @(
            "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe",
            "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe",
            "C:\Users\Ervum\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe",
            "C:\Users\Ervum\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe",
            "$env:LOCALAPPDATA\Microsoft\WinGet\Links\godot_console.exe",
            "$env:LOCALAPPDATA\Microsoft\WinGet\Links\godot.exe",
            "C:\Program Files\Godot\godot_console.exe",
            "C:\Program Files\Godot\Godot.exe",
            "C:\Godot\godot_console.exe",
            "C:\Godot\Godot.exe"
        )

        foreach ($loc in $knownLocations) {
            if ($loc -and (Test-Path $loc)) {
                $resolvedBase = (Resolve-Path $loc).Path
                break
            }
        }
    }

    if (-not $resolvedBase) {
        return $null
    }

    $guiPath = $resolvedBase
    $consolePath = $resolvedBase

    $dir = Split-Path $resolvedBase
    $fileName = Split-Path $resolvedBase -Leaf

    if ($fileName -match "_console\.exe$") {
        $consolePath = $resolvedBase
        $guiCandidates = @(
            ($fileName -replace "_console\.exe$", ".exe"),
            ($fileName -replace "_win64_console\.exe$", "_win64.exe"),
            ($fileName -replace "_win32_console\.exe$", "_win32.exe"),
            "godot.exe"
        )
        foreach ($gc in $guiCandidates) {
            $gcPath = Join-Path $dir $gc
            if (Test-Path $gcPath) {
                $guiPath = (Resolve-Path $gcPath).Path
                break
            }
        }
    } else {
        $consoleCandidates = @(
            ($fileName -replace "_win64\.exe$", "_win64_console.exe"),
            ($fileName -replace "_win32\.exe$", "_win32_console.exe"),
            ($fileName -replace "\.exe$", "_console.exe"),
            "godot_console.exe"
        )
        foreach ($cand in $consoleCandidates) {
            $candPath = Join-Path $dir $cand
            if (Test-Path $candPath) {
                $consolePath = (Resolve-Path $candPath).Path
                break
            }
        }

        if ($consolePath -eq $guiPath) {
            $linkPath = "$env:LOCALAPPDATA\Microsoft\WinGet\Links\godot_console.exe"
            if (Test-Path $linkPath) {
                $consolePath = (Resolve-Path $linkPath).Path
            } else {
                $cmdConsole = Get-Command godot_console -ErrorAction SilentlyContinue
                if ($cmdConsole) {
                    $consolePath = $cmdConsole.Source
                }
            }
        }
    }

    return [PSCustomObject]@{
        Gui     = $guiPath
        Console = $consolePath
    }
}

$GodotExecutables = Resolve-GodotExecutables -CandidatePath $GodotPath

if (-not $GodotExecutables) {
    Write-Error "Could not find Godot executable. Please set 'godot.executablePath' in .vscode/settings.json or add Godot to PATH."
    exit 1
}

# 3. Execute according to chosen mode
switch ($Mode) {
    "projectless" {
        # 1. Starts Godot with no project (Project Manager, detached GUI, no CMD)
        Write-Host "Starting Godot Project Manager..." -ForegroundColor Magenta
        Start-Process -FilePath $GodotExecutables.Gui -ArgumentList "--project-manager"
    }

    "development" {
        # 2. Starts Godot with the project to be edited (Attached inside integrated IDE terminal)
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host "  Astra Dream - Godot Development Runner" -ForegroundColor Cyan
        Write-Host "  Mode:       Editor with Integrated Terminal Output" -ForegroundColor Cyan
        Write-Host "  Project:    $ProjectPath" -ForegroundColor DarkGray
        Write-Host "  Executable: $($GodotExecutables.Console)" -ForegroundColor DarkGray
        Write-Host "============================================================" -ForegroundColor Cyan
        & $GodotExecutables.Console -e --path "$ProjectPath"
        if ($LASTEXITCODE -ne $null -and $LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
    }

    "external_development" {
        # 3. Starts Godot with the project to be edited (External separate CMD window)
        Write-Host "Starting Godot Editor in external CMD window..." -ForegroundColor Cyan
        $cmdArgs = "/c title Astra Dream [Godot Editor Console] & `"$($GodotExecutables.Console)`" -e --path `"$ProjectPath`" & if errorlevel 1 pause"
        Start-Process -FilePath "cmd.exe" -ArgumentList $cmdArgs
    }

    "cmdless_development" {
        # 4. Starts Godot with the project to be edited but no visible CMD (Detached GUI)
        Write-Host "Starting Godot Editor (detached, no CMD)..." -ForegroundColor Yellow
        Start-Process -FilePath $GodotExecutables.Gui -ArgumentList "-e", "--path", "`"$ProjectPath`""
    }

    "production" {
        # 5. Starts Godot with the project to be played (Attached inside integrated IDE terminal)
        Write-Host "============================================================" -ForegroundColor Green
        Write-Host "  Astra Dream - Godot Production Runner" -ForegroundColor Green
        Write-Host "  Mode:       Game with Integrated Terminal Output" -ForegroundColor Green
        Write-Host "  Project:    $ProjectPath" -ForegroundColor DarkGray
        Write-Host "  Executable: $($GodotExecutables.Console)" -ForegroundColor DarkGray
        Write-Host "============================================================" -ForegroundColor Green
        & $GodotExecutables.Console --path "$ProjectPath"
        if ($LASTEXITCODE -ne $null -and $LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
    }

    "external_production" {
        # 6. Starts Godot with the project to be played (External separate CMD window)
        Write-Host "Starting Godot Game in external CMD window..." -ForegroundColor Green
        $cmdArgs = "/c title Astra Dream [Godot Game Console] & `"$($GodotExecutables.Console)`" --path `"$ProjectPath`" & if errorlevel 1 pause"
        Start-Process -FilePath "cmd.exe" -ArgumentList $cmdArgs
    }

    "cmdless_production" {
        # 7. Starts Godot with the project to be played but no visible CMD (Detached GUI)
        Write-Host "Starting Godot Game (detached, no CMD)..." -ForegroundColor Yellow
        Start-Process -FilePath $GodotExecutables.Gui -ArgumentList "--path", "`"$ProjectPath`""
    }
}
