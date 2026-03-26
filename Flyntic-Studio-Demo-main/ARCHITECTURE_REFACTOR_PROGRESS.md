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

## Folder Cleanup

- [x] Consolidated service scripts into `Godot/services/`.
- [x] Updated `Main.gd` loader paths to `res://services/*.gd`.

## Main.gd Integration Pattern

- Services are loaded in `_init_environment_modules()`.
- `Main.gd` delegates to service first.
- If service missing, fallback logic in `Main.gd` preserves behavior.

## Remaining High-Value Splits

- [ ] SimulationCoordinator
  - Move `_simulate`, bridge/kinematic routing, and step orchestration.
- [ ] RuntimeInputController
  - Keep reducing direct input logic in `_input` (mouse/canvas branches remain).
- [ ] DiagnosticsService
  - Move diagnostics issue assembly and formatting orchestration.
- [ ] ModuleLoaderService
  - Consolidate script load/init pattern currently repeated in `Main.gd`.

## Notes

- Keep extraction granularity small to avoid regressions.
- Run `./scripts/quality_gate.ps1` after each extraction step.
