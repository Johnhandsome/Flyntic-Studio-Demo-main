# Implementation Backlog (Execution-Ready)

This backlog is ordered by business impact and release risk.

## Immediate Next Sprint (Roadmap Phase C & D Closure)

- [x] Add wind model v2 with altitude-layer turbulence profile in `Godot/services/EnvironmentPhysicsService.gd`.
- [x] Add EMI model v2 with sensor-specific channels (GPS drift, magnetometer bias, gyro jitter) exposed by environment/sensor services.
- [x] Add deterministic weather/lighting presets with explicit seed control.
- [x] Add physics profile presets (`low_hardware`, `balanced`, `high_fidelity`) and wire profile selection through runtime configuration + telemetry manifest.
- [x] Add benchmark scenario and acceptance script for Phase A metrics.
- [x] Add benchmark scenario and acceptance script for Phase B metrics.
- [x] Add Swarm Formation Manager (Line, V, Circle, Custom offsets) to `SwarmController`.
- [x] Add Collision avoidance envelope and separation tuning (Boids separation) constraint.
- [x] Add Multi-agent telemetry labeling (record state per drone ID in swarm).
- [x] Add benchmark scenario and acceptance script for Phase C metrics (8-12 drones low_hardware stable, collision threshold pass).
- [x] Add end-to-end Dataset export bundler (ZIPPacker) for Telemetry JSONL + CSV + Manifest.
- [x] Add benchmark scenario and acceptance script for Phase D metrics (Dataset generation and validator reproducibility).

## P0 - Must complete before charging broadly

- [x] Align product positioning docs with current workspace reality.
- [ ] Refactor monolithic `Godot/Main.gd` into focused controllers.
- [x] Add autosave + crash recovery snapshots.
- [x] Add schema version + migration for `.flyntic` project files.
- [x] Add end-to-end save/load round-trip test cases.
- [x] Add release smoke test checklist for every build.

## P1 - Must complete for strong paid value

- [x] Unify wiring validation rules between connection flow and preflight.
- [x] Add severity model (Error/Warning/Info) to diagnostics.
- [x] Add guided remediation actions for top 10 preflight failures.
- [x] Add analytics for onboarding and simulation funnel.
- [x] Add RC checklist and rollback playbook.

## P2 - Scale and monetization maturity

- [ ] Add account + entitlement backend integration.
- [ ] Add free/pro/team feature flags in app.
- [ ] Add team workspace and role permissions.
- [ ] Add usage-based insights for pricing optimization.

## P3 - Autonomous and Data Platform

- [x] Add modular environment physics (wind/EMI/light) with low-hardware profile.
- [x] Add baseline swarm drone controller.
- [x] Add physics telemetry recorder (JSONL/CSV sessions).
- [x] Add deterministic replay runner from telemetry + seed.
- [x] Add mission planner for autonomous workflows.
- [x] Add sensor-model plugins (GPS/IMU/barometer/vision) with profile-gated fidelity.
- [x] Add geofence + failsafe safety layer (RTL and emergency land) for autonomous runs.
- [x] Add telemetry session manifest (seed/profile metadata) for deterministic replay context.
- [x] Add telemetry quality validator (row/monotonic/outlier checks).
- [x] Upgrade mission planner to mission-graph flow with geofence return-home branch.
- [x] Add controller mode cycle (manual assist / auto mission / adaptive hover).
- [x] Add swarm behavior presets (leader-follower / area sweep / relay chain).

## Suggested Sprint Mapping

## Sprint 1 (Week 1-2)
- [x] Doc alignment
- [x] Architecture split design doc
- [x] Save/load schema versioning

## Sprint 2 (Week 3-4)
- [x] Autosave and recovery
- [x] Preflight diagnostics severity
- [x] Save/load regression tests

## Sprint 3 (Week 5-6)
- [x] Wiring rule engine unification
- [x] Remediation quick-fix actions
- [x] CI quality gates

## Sprint 4 (Week 7-8)
- [x] Analytics instrumentation
- [x] Dashboard baseline
- [x] Beta release checklist

## Sprint 5 (Week 9-10)
- [ ] Entitlement integration
- [ ] Plan gating (Free/Pro)
- [ ] Paid beta launch prep

## Sprint 6 (Week 11-12)
- [x] Environment module integration
- [x] Swarm baseline integration
- [x] Telemetry recorder integration
- [x] Deterministic replay tool
- [x] Mission planner MVP
- [x] Sensor model plugin integration
- [x] Safety layer (geofence/failsafe) integration
- [x] Telemetry manifest + quality validator integration
- [x] Mission graph return-home branch integration
- [x] Controller mode + swarm behavior preset integration

## Architecture Stabilization Delta

- [x] Extract runtime mode orchestration into `Godot/RuntimeModeService.gd`.
- [x] Extract kinematic wind/control assist logic into `Godot/FlightAssistService.gd`.
- [ ] Continue splitting `Main.gd` into scene assembly, simulation loop, and UI interaction controllers.
