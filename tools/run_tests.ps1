# PowerShell Headless Test Harness — Astra Dream
[CmdletBinding()]
param(
    [string]$Test = "",
    [string]$Filter = "",
    [int]$TimeoutSeconds = 15,
    [switch]$CoreOnly,
    [switch]$VerboseOutput
)

# 1. Determinar ejecutable de Godot
$godot = $null
$vscodeSettings = Join-Path $PSScriptRoot "..\.vscode\settings.json"
if (Test-Path $vscodeSettings) {
    try {
        $json = Get-Content $vscodeSettings -Raw | ConvertFrom-Json
        if ($json.'godot.consoleExecutablePath' -and (Test-Path $json.'godot.consoleExecutablePath')) {
            $godot = $json.'godot.consoleExecutablePath'
        } elseif ($json.'godot.executablePath' -and (Test-Path $json.'godot.executablePath')) {
            $godot = $json.'godot.executablePath'
        }
    } catch {}
}

if (-not $godot) {
    $wingetCandidate = "C:\Users\$env:USERNAME\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"
    if (Test-Path $wingetCandidate) {
        $godot = $wingetCandidate
    }
}

if (-not $godot) {
    $cmd = Get-Command godot -ErrorAction SilentlyContinue
    if ($cmd) { $godot = $cmd.Source }
}

if (-not $godot) {
    Write-Error "[ERROR] No se pudo encontrar el ejecutable de Godot 4."
    exit 1
}

$testsDir = Join-Path $PSScriptRoot "..\tests"
$runners = @()

# 2. Seleccionar que tests ejecutar
if ($Test) {
    if (Test-Path (Join-Path $testsDir $Test)) {
        $runners += Get-Item (Join-Path $testsDir $Test)
    } elseif (Test-Path $Test) {
        $runners += Get-Item $Test
    } else {
        $runners = Get-ChildItem $testsDir -Filter "*$Test*"
    }
} elseif ($Filter) {
    $runners = Get-ChildItem $testsDir -Filter "*$Filter*.tscn"
} elseif ($CoreOnly) {
    # Conjunto clave de regresion rapida para iteracion de agentes
    $coreNames = @(
        "test_weapons_runner.tscn",
        "test_run_stats_and_shop_inventory_runner.tscn",
        "test_satellite_items_runner.tscn",
        "test_chest_economy_runner.tscn",
        "test_hybrid_chest_economy_runner.tscn",
        "test_proc_coefficients_and_osp_runner.tscn",
        "test_pause_arbitrator_runner.tscn",
        "test_persistence_runner.tscn",
        "test_slot_machine_and_gacha_runner.tscn",
        "test_weapon_swap_and_hud_runner.tscn",
        "test_level_up_queue_runner.tscn",
        "test_boss_runner.tscn",
        "test_dialogue_skip_runner.tscn",
        "test_tomes_and_infinite_weapons_runner.tscn",
        "test_phase1_ui_polish_runner.tscn"
    )
    foreach ($cn in $coreNames) {
        $p = Join-Path $testsDir $cn
        if (Test-Path $p) { $runners += Get-Item $p }
    }
} else {
    $runners = Get-ChildItem $testsDir -Filter "*runner*.tscn"
}

if ($runners.Count -eq 0) {
    Write-Warning "[WARN] No se encontraron tests que coincidan con los criterios."
    exit 0
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Astra Dream -- Ejecutor Headless de Pruebas Automatizadas" -ForegroundColor Cyan
Write-Host "   Godot: $godot" -ForegroundColor Gray
Write-Host "   Total suites a ejecutar: $($runners.Count)" -ForegroundColor Gray
Write-Host "   Timeout por suite: $TimeoutSeconds s" -ForegroundColor Gray
Write-Host "==========================================================" -ForegroundColor Cyan

$passed = @()
$failed = @()
$timedOut = @()

$swTotal = [System.Diagnostics.Stopwatch]::StartNew()

foreach ($r in $runners) {
    $rName = $r.Name
    Write-Host "▶ Ejecutando $rName... " -NoNewline

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $godot
    $psi.Arguments = "--headless `"$($r.FullName)`""
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    [void]$proc.Start()

    $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
    $stderrTask = $proc.StandardError.ReadToEndAsync()

    $exited = $proc.WaitForExit($TimeoutSeconds * 1000)
    $sw.Stop()

    if (-not $exited) {
        try { $proc.Kill() } catch {}
        Write-Host ("TIMEOUT / COLGADO (" + $TimeoutSeconds + "s)") -ForegroundColor Red
        $timedOut += $rName
        continue
    }

    [void][System.Threading.Tasks.Task]::WaitAll($stdoutTask, $stderrTask)
    $stdout = $stdoutTask.Result
    $stderr = $stderrTask.Result

    $hasScriptError = $stdout.Contains("SCRIPT ERROR:") -or $stderr.Contains("SCRIPT ERROR:")
    $hasFatalError = $stdout.Contains("ASSERTION FAILURE") -or $stderr.Contains("ASSERTION FAILURE")

    $elapsedSec = [math]::Round($sw.Elapsed.TotalSeconds, 2)
    if ($proc.ExitCode -eq 0 -and -not $hasScriptError -and -not $hasFatalError) {
        Write-Host ("PASS (" + $elapsedSec + "s)") -ForegroundColor Green
        $passed += $rName
        if ($VerboseOutput) {
            Write-Host $stdout -ForegroundColor DarkGray
        }
    } else {
        Write-Host ("FAIL (Codigo: " + $proc.ExitCode + ")") -ForegroundColor Yellow
        $failed += $rName
        $combined = $stdout + "`n" + $stderr
        $lines = $combined -split "`r?`n"
        $errLines = $lines | Where-Object { $_ -match "SCRIPT ERROR|Assertion failed|ASSERTION FAILURE|ERROR:" }
        foreach ($el in $errLines | Select-Object -First 3) {
            Write-Host "   $el" -ForegroundColor Red
        }
    }
}

$swTotal.Stop()
$totalElapsed = [math]::Round($swTotal.Elapsed.TotalSeconds, 2)
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ("RESUMEN FINAL (" + $totalElapsed + "s):") -ForegroundColor Cyan
Write-Host ("   Pasados: " + $passed.Count) -ForegroundColor Green
Write-Host ("   Fallidos: " + $failed.Count) -ForegroundColor Yellow
Write-Host ("   Colgados/Timeout: " + $timedOut.Count) -ForegroundColor Red
Write-Host "==========================================================" -ForegroundColor Cyan

if ($failed.Count -gt 0 -or $timedOut.Count -gt 0) {
    exit 1
}
exit 0
