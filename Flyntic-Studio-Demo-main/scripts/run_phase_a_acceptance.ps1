param(
    [string]$GodotCmd = "",
    [string]$ProjectPath = "Godot",
    [string]$TestScript = "res://tests/phase_a_acceptance.gd"
)

$ErrorActionPreference = "Stop"

function Resolve-GodotCommand {
    param([string]$Requested)

    if ($Requested -ne "") {
        return $Requested
    }

    if ($env:GODOT_CMD -and $env:GODOT_CMD.Trim() -ne "") {
        return $env:GODOT_CMD
    }

    $candidates = @(
        "godot",
        "godot4",
        "Godot_v4.3-stable_win64",
        "Godot_v4.2.2-stable_win64"
    )

    foreach ($candidate in $candidates) {
        $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
        if ($null -ne $cmd) {
            return $cmd.Path
        }
    }

    throw "[PhaseA] Godot executable not found. Set -GodotCmd or GODOT_CMD environment variable."
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$godot = Resolve-GodotCommand -Requested $GodotCmd

Write-Host "[PhaseA] Running acceptance script with: $godot"
Push-Location $repoRoot
try {
    & $godot --headless --path $ProjectPath --script $TestScript
    if ($LASTEXITCODE -ne 0) {
        throw "[PhaseA] Acceptance failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

Write-Host "[PhaseA] Acceptance passed"
