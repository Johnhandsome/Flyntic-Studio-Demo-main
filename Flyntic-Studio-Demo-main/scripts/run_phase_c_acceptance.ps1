param (
    [string]$GodotCmd = ""
)

$ErrorActionPreference = "Stop"

if ($GodotCmd -eq "") {
    if ([bool]$env:GODOT_CMD) {
        $GodotCmd = $env:GODOT_CMD
    } else {
        # Try to find godot in PATH or common locations
        $candidates = @("godot", "godot4", "Godot_v4.3-stable_win64", "Godot_v4.2-stable_win64")
        foreach ($c in $candidates) {
            if (Get-Command $c -ErrorAction SilentlyContinue) {
                $GodotCmd = $c
                break
            }
        }
    }
}

if ($GodotCmd -eq "") {
    Write-Host "[PhaseC] Godot executable not found. Set -GodotCmd or GODOT_CMD environment variable." -ForegroundColor Yellow
    exit 1
}

Write-Host "[PhaseC] Running Phase C Acceptance Test with Godot: $GodotCmd" -ForegroundColor Cyan

# Run Godot headlessly to execute the test script
$testScriptFullPath = Resolve-Path "Godot/tests/phase_c_acceptance.gd" | Select-Object -ExpandProperty Path
$projectPath = Resolve-Path "Godot" | Select-Object -ExpandProperty Path

try {
    Push-Location $projectPath
    
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = $GodotCmd
    $processInfo.Arguments = "--headless --script `"$testScriptFullPath`""
    $processInfo.RedirectStandardOutput = $true
    $processInfo.RedirectStandardError = $true
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true
    
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $processInfo
    $p.Start() | Out-Null
    
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    
    $p.WaitForExit()
    
    if ($stdout) { Write-Host $stdout }
    if ($stderr) { Write-Host $stderr -ForegroundColor Red }
    
    Pop-Location
    
    if ($p.ExitCode -eq 0) {
        Write-Host "[PhaseC] ACCEPTED. Phase C metrics have been fully met." -ForegroundColor Green
        exit 0
    } else {
        Write-Host "[PhaseC] FAILED. Acceptance test returned exit code: $($p.ExitCode)" -ForegroundColor Red
        exit $p.ExitCode
    }
} catch {
    Write-Host "[PhaseC] Execution error: $_" -ForegroundColor Red
    Pop-Location
    exit 1
}
