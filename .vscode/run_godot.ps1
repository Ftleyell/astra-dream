# PowerShell runner for Godot tasks in VS Code
param (
    [Parameter(Mandatory = $true)]
    [ValidateSet("projectless", "development", "cmdless_development", "production", "cmdless_production")]
    [string]$Mode,

    [string]$ProjectPath = "",
    [string]$GodotPath = ""
)

# 1. Resolve Project Root
if (-not $ProjectPath -or $ProjectPath.StartsWith("`${")) {
    $ProjectPath = Resolve-Path (Join-Path $PSScriptRoot "..")
} else {
    $ProjectPath = Resolve-Path $ProjectPath
}

# 2. Resolve Godot Executable
function Find-GodotExecutable {
    param ([string]$CandidatePath)

    # Check candidate if valid
    if ($CandidatePath -and -not $CandidatePath.StartsWith("`${") -and (Test-Path $CandidatePath)) {
        return (Resolve-Path $CandidatePath).Path
    }

    # Check .vscode/settings.json
    $settingsPath = Join-Path $PSScriptRoot "settings.json"
    if (Test-Path $settingsPath) {
        try {
            $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
            if ($settings.'godot.executablePath' -and (Test-Path $settings.'godot.executablePath')) {
                return (Resolve-Path $settings.'godot.executablePath').Path
            }
            if ($settings.'godotTools.editorPath.godot4' -and (Test-Path $settings.'godotTools.editorPath.godot4')) {
                return (Resolve-Path $settings.'godotTools.editorPath.godot4').Path
            }
        } catch {}
    }

    # Check PATH
    $cmd = Get-Command godot -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    # Check Known Windows Locations (WinGet, standard installs)
    $knownLocations = @(
        "C:\Users\Ervum\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe",
        "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe",
        "C:\Program Files\Godot\Godot.exe",
        "C:\Godot\Godot.exe"
    )

    foreach ($loc in $knownLocations) {
        if ($loc -and (Test-Path $loc)) {
            return (Resolve-Path $loc).Path
        }
    }

    return $null
}

$ResolvedGodot = Find-GodotExecutable -CandidatePath $GodotPath

if (-not $ResolvedGodot) {
    Write-Error "Could not find Godot executable. Please set 'godot.executablePath' in .vscode/settings.json or add Godot to PATH."
    exit 1
}

# 3. Execute according to chosen mode
switch ($Mode) {
    "projectless" {
        # 1. Starts Godot with no project (Project Manager)
        Start-Process -FilePath $ResolvedGodot -ArgumentList "--project-manager"
    }

    "development" {
        # 2. Starts Godot with the project to be edited (Visible CMD / Attached)
        & $ResolvedGodot -e --path "$ProjectPath"
    }

    "cmdless_development" {
        # 3. Starts Godot with the project to be edited but no visible CMD (Detached)
        Start-Process -FilePath $ResolvedGodot -ArgumentList "-e", "--path", "`"$ProjectPath`""
    }

    "production" {
        # 4. Starts Godot with the project to be played (Visible CMD / Attached)
        & $ResolvedGodot --path "$ProjectPath"
    }

    "cmdless_production" {
        # 5. Starts Godot with the project to be played but no visible CMD (Detached)
        Start-Process -FilePath $ResolvedGodot -ArgumentList "--path", "`"$ProjectPath`""
    }
}
