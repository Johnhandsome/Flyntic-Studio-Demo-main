$ErrorActionPreference = "Stop"

Write-Host "[QG] Starting quality gates..."

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

$requiredFiles = @(
    "IMPLEMENTATION_BACKLOG.md",
    "docs/release/RELEASE_SMOKE_CHECKLIST.md",
    "docs/release/RC_ROLLBACK_PLAYBOOK.md",
    "Godot/tests/run_tests.gd"
)

foreach ($f in $requiredFiles) {
    $fullPath = Join-Path $repoRoot $f
    if (-not (Test-Path $fullPath)) {
        throw "[QG] Missing required file: $f"
    }
}

$backlog = Get-Content (Join-Path $repoRoot "IMPLEMENTATION_BACKLOG.md") -Raw
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
