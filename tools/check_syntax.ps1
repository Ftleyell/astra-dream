# PowerShell Fast GDScript Syntax Checker — Astra Dream
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Files
)

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

$validatorScene = "res://tools/validate_gdscript.tscn"
$fileArgs = ($Files | ForEach-Object { "`"$_`"" }) -join " "

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $godot
$psi.Arguments = "--headless `"$validatorScene`" -- $fileArgs"
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true

$proc = New-Object System.Diagnostics.Process
$proc.StartInfo = $psi
[void]$proc.Start()

$stdoutTask = $proc.StandardOutput.ReadToEndAsync()
$stderrTask = $proc.StandardError.ReadToEndAsync()

$exited = $proc.WaitForExit(10000)
if (-not $exited) {
    try { $proc.Kill() } catch {}
    Write-Host "[ERROR] Timeout al validar scripts." -ForegroundColor Red
    exit 1
}

[void][System.Threading.Tasks.Task]::WaitAll($stdoutTask, $stderrTask)
$stdout = $stdoutTask.Result
$stderr = $stderrTask.Result

$combined = $stdout + "`n" + $stderr
$hasError = ($proc.ExitCode -ne 0) -or ($combined -match "SCRIPT ERROR|COMPILE ERROR|Compilation failed")

if ($hasError) {
    Write-Host "[ERROR DE SINTAXIS / COMPILACION]" -ForegroundColor Red
    $lines = $combined -split "`r?`n"
    $errLines = $lines | Where-Object { $_ -match "SCRIPT ERROR|COMPILE ERROR|Compilation failed|Parse Error" }
    foreach ($line in $errLines) {
        Write-Host "   $line" -ForegroundColor Red
    }
    exit 1
}

Write-Host "[SINTAXIS CORRECTA]" -ForegroundColor Green
foreach ($f in $Files) {
    Write-Host "   OK: $f" -ForegroundColor Green
}
exit 0
