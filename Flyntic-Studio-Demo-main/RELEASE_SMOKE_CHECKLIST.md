# Release Smoke Checklist

Use this checklist for every release candidate and beta build.

## Build and Packaging

- [ ] Godot export completes without errors.
- [ ] Build metadata is updated (version, date, changelog link).
- [ ] Startup reaches main screen in less than 10 seconds on target machine.

## Core User Flows

- [ ] New session can place frame, battery, motor, propeller.
- [ ] Wiring tab loads and allows valid connections.
- [ ] Invalid wiring is rejected with clear error.
- [ ] Simulation Play, Pause, Stop all work.
- [ ] Save project and load project are successful.

## Data Safety

- [ ] Autosave file is created at `user://autosave/latest.flyntic`.
- [ ] Restore prompt appears on startup when autosave exists.
- [ ] Restored project matches last known user state.
- [ ] Old project schema files still load.

## Diagnostics and Remediation

- [ ] Diagnostics panel shows Error/Warning/Info summary.
- [ ] F9 remediation resolves common wiring issues.
- [ ] Preflight blocking errors are clearly visible.

## Analytics and Observability

- [ ] Events append to `user://analytics/events.jsonl`.
- [ ] Metrics button shows event summary in console.
- [ ] Simulation start/stop and save/load events are present.

## Exit Criteria

- [ ] No P0/P1 known blocker.
- [ ] Zero crash in 30-minute exploratory test.
- [ ] Release notes prepared and reviewed.
