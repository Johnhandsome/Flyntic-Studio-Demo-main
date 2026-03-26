# Architecture Refactor Progress

This file tracks decomposition of `Godot/Main.gd` into focused services.

## Current Status

- Date: 2026-03-26
- Strategy: incremental extraction with fallback wiring in `Main.gd`.
- Goal: reduce monolith risk while preserving runtime behavior.

## Completed Extractions

- [x] `Godot/services/RuntimeModeService.gd`
  - Responsibility: cycle runtime control/swarm modes.
- [x] `Godot/services/FlightAssistService.gd`
  - Responsibility: control-mode wind compensation and adaptive hover target shaping.
- [x] `Godot/services/MissionRuntimeService.gd`
  - Responsibility: mission update orchestration and mission status outputs.
- [x] `Godot/services/SwarmTelemetryService.gd`
  - Responsibility: sensor sampling, swarm update dispatch, telemetry record step.
- [x] `Godot/services/RuntimeInputService.gd`
  - Responsibility: hotkey-to-action routing for runtime input shortcuts.
- [x] `Godot/services/SimulationCoordinatorService.gd`
  - Responsibility: replay handling, safety mediation, simulation step label orchestration.

## Folder Cleanup

- [x] Consolidated service scripts into `Godot/services/`.
- [x] Updated `Main.gd` loader paths to `res://services/*.gd`.

## Main.gd Integration Pattern

- Services are loaded in `_init_environment_modules()`.
- `Main.gd` delegates to service first.
- If service missing, fallback logic in `Main.gd` preserves behavior.

## Remaining High-Value Splits

- [x] SimulationCoordinator
  - Move `_simulate`, bridge/kinematic routing, and step orchestration.
  - Status: replay/safety/step-label + prop-spin + cannot-fly settle + bridge-land decision + bridge/kinematic top-level routing + bridge step-start command dispatch + shared step transition state handling + kinematic per-step action transform moved.
  - Remaining: minor orchestration glue in `Main.gd` (optional cleanup only).
- [x] RuntimeInputController
  - Mouse/canvas intent routing extracted to `RuntimeInputService`; `Main.gd` now applies action results.
- [x] DiagnosticsService
  - Diagnostics issue assembly moved to `Godot/services/DiagnosticsService.gd`.
- [x] ModuleLoaderService
  - Script load/init/config flow consolidated in `Godot/services/ModuleLoaderService.gd` and wired from `Main.gd`.

## Notes

- Keep extraction granularity small to avoid regressions.
- Run `./scripts/quality_gate.ps1` after each extraction step.
