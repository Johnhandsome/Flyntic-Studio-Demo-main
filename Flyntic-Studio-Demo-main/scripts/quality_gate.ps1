$ErrorActionPreference = "Stop"

Write-Host "[QG] Starting quality gates..."

$requiredFiles = @(
    "IMPLEMENTATION_BACKLOG.md",
    "RELEASE_SMOKE_CHECKLIST.md",
    "RC_ROLLBACK_PLAYBOOK.md",
    "Godot/tests/run_tests.gd"
)

foreach ($f in $requiredFiles) {
    if (-not (Test-Path $f)) {
        throw "[QG] Missing required file: $f"
    }
}

$backlog = Get-Content "IMPLEMENTATION_BACKLOG.md" -Raw
$mustHave = @(
    "Add end-to-end save/load round-trip test cases.",
    "CI quality gates"
)

foreach ($item in $mustHave) {
    if ($backlog -notmatch [regex]::Escape($item)) {
        throw "[QG] Backlog item not found: $item"
    }
}

Write-Host "[QG] Static checks passed"
