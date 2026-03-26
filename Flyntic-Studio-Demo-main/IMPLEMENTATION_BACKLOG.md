# Implementation Backlog (Execution-Ready)

This backlog is ordered by business impact and release risk.

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
