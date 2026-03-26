# Architecture Split Plan (Main.gd Decomposition)

Goal: reduce complexity in `Godot/Main.gd` by moving domain concerns into dedicated services/controllers.

## Proposed Modules

- `Godot/AnalyticsService.gd`
  - event tracking and dashboard summary from `events.jsonl`
- `Godot/PersistenceService.gd`
  - schema versioning, normalize/migrate, autosave file operations
- `Godot/WiringService.gd`
  - wiring rule checks, normalization, auto-fix/remediation helpers
- `Godot/DiagnosticsService.gd`
  - severity model formatting and issue aggregation

## Incremental Migration Steps

1. Extract analytics from Main (done).
2. Extract persistence read/write and normalization paths.
3. Extract wiring validation + graph normalization.
4. Extract diagnostics rendering and message formatting.
5. Keep Main as orchestration layer only.

## Acceptance Criteria

- Main keeps user interaction orchestration and scene/node wiring.
- Domain logic is testable via headless scripts without scene dependencies.
- Existing behavior remains backward-compatible for save/load and simulation controls.
