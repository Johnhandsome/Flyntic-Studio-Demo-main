# Implementation Backlog (Execution-Ready)

This backlog is ordered by business impact and release risk.

## P0 - Must complete before charging broadly

- [ ] Align product positioning docs with current workspace reality.
- [ ] Refactor monolithic `Godot/Main.gd` into focused controllers.
- [ ] Add autosave + crash recovery snapshots.
- [ ] Add schema version + migration for `.flyntic` project files.
- [ ] Add end-to-end save/load round-trip test cases.
- [ ] Add release smoke test checklist for every build.

## P1 - Must complete for strong paid value

- [ ] Unify wiring validation rules between connection flow and preflight.
- [ ] Add severity model (Error/Warning/Info) to diagnostics.
- [ ] Add guided remediation actions for top 10 preflight failures.
- [ ] Add analytics for onboarding and simulation funnel.
- [ ] Add RC checklist and rollback playbook.

## P2 - Scale and monetization maturity

- [ ] Add account + entitlement backend integration.
- [ ] Add free/pro/team feature flags in app.
- [ ] Add team workspace and role permissions.
- [ ] Add usage-based insights for pricing optimization.

## Suggested Sprint Mapping

## Sprint 1 (Week 1-2)
- [ ] Doc alignment
- [ ] Architecture split design doc
- [ ] Save/load schema versioning

## Sprint 2 (Week 3-4)
- [ ] Autosave and recovery
- [ ] Preflight diagnostics severity
- [ ] Save/load regression tests

## Sprint 3 (Week 5-6)
- [ ] Wiring rule engine unification
- [ ] Remediation quick-fix actions
- [ ] CI quality gates

## Sprint 4 (Week 7-8)
- [ ] Analytics instrumentation
- [ ] Dashboard baseline
- [ ] Beta release checklist

## Sprint 5 (Week 9-10)
- [ ] Entitlement integration
- [ ] Plan gating (Free/Pro)
- [ ] Paid beta launch prep
