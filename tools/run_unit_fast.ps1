# PowerShell Fast Unit Test Runner con Circuit Breaker (<15s) — Astra Dream
[CmdletBinding()]
param(
    [string]$Test = "",
    [string]$Filter = "",
    [int]$TimeoutSeconds = 8,
    [switch]$VerboseOutput
)

# 1. Resolver ejecutable de Godot
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

$unitDir = Join-Path $PSScriptRoot "..\tests\unit"
if (-not (Test-Path $unitDir)) {
    New-Item -ItemType Directory -Force -Path $unitDir | Out-Null
}

$runners = @()

if ($Test) {
    if (Test-Path (Join-Path $unitDir $Test)) {
        $runners += Get-Item (Join-Path $unitDir $Test)
    } elseif (Test-Path $Test) {
        $runners += Get-Item $Test
    } else {
        $runners = Get-ChildItem $unitDir -Filter "*$Test*"
    }
} elseif ($Filter) {
    $runners = Get-ChildItem $unitDir -Filter "*$Filter*.tscn"
} else {
    $runners = Get-ChildItem $unitDir -Filter "*.tscn"
}

if ($runners.Count -eq 0) {
    Write-Host "[WARN] No se encontraron micro-tests unitarios para ejecutar en $unitDir" -ForegroundColor Yellow
    exit 0
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Astra Dream -- Fast Unit Runner (Circuit Breaker Activo)" -ForegroundColor Cyan
Write-Host "   Total micro-tests: $($runners.Count)" -ForegroundColor Gray
Write-Host "   Timeout duro por test: $TimeoutSeconds s" -ForegroundColor Gray
Write-Host "==========================================================" -ForegroundColor Cyan

$passed = @()
$failed = @()
$timedOut = @()
$swTotal = [System.Diagnostics.Stopwatch]::StartNew()

foreach ($runner in $runners) {
    $rName = $runner.Name
    Write-Host -NoNewline "▶ $rName... "

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $godot
    $psi.Arguments = "--headless --disable-render-loop --path `"$PSScriptRoot\..`" `"res://tests/unit/$rName`""
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
        Write-Host "CIRCUIT BREAKER ACTIVADO / TIMEOUT ($($TimeoutSeconds)s)" -ForegroundColor Red
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
        Write-Host "PASS ($($elapsedSec)s)" -ForegroundColor Green
        $passed += $rName
        if ($VerboseOutput) {
            Write-Host $stdout -ForegroundColor DarkGray
        }
    } else {
        Write-Host "FAIL (Codigo: $($proc.ExitCode))" -ForegroundColor Yellow
        $failed += $rName
        $combined = $stdout + "`n" + $stderr
        $lines = $combined -split "`r?`n"
        $errLines = $lines | Where-Object { ($_ -match "SCRIPT ERROR|Assertion failed|ASSERTION FAILURE|ERROR:") -and ($_ -notmatch "RID allocations") }
        foreach ($el in $errLines | Select-Object -First 5) {
            Write-Host "   $el" -ForegroundColor Red
        }
    }
}

$swTotal.Stop()
$totalElapsed = [math]::Round($swTotal.Elapsed.TotalSeconds, 2)
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "RESUMEN FAST RUNNER ($($totalElapsed)s):" -ForegroundColor Cyan
Write-Host "   Pasados: $($passed.Count)" -ForegroundColor Green
Write-Host "   Fallidos: $($failed.Count)" -ForegroundColor Yellow
Write-Host "   Circuit Breaker / Timeout: $($timedOut.Count)" -ForegroundColor Red
Write-Host "==========================================================" -ForegroundColor Cyan

if ($failed.Count -gt 0 -or $timedOut.Count -gt 0) {
    exit 1
}
exit 0
