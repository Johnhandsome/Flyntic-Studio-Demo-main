# RC and Rollback Playbook

This playbook defines how to validate release candidates and how to roll back safely.

## 1. RC Gate

Release Candidate can proceed only if all are true:

- Smoke checklist is fully green.
- No open blocker bug with severity critical/high.
- Save/Load, Wiring, Simulation scenarios pass on target OS.
- Autosave restore works from previous session snapshot.

## 2. Pre-Release Steps

- Freeze feature changes after RC cut.
- Tag the candidate build in source control.
- Archive export artifacts with versioned folder name.
- Capture baseline analytics summary from Metrics button.

## 3. Incident Severity

- Sev-1: App cannot start, data loss, crash loop.
- Sev-2: Core flow broken (save/load/sim/wiring).
- Sev-3: Non-blocking UX/regression issue.

## 4. Rollback Triggers

Rollback immediately when:

- Sev-1 issue is confirmed.
- Sev-2 issue affects more than one core flow.
- Save or load integrity cannot be guaranteed.

## 5. Rollback Procedure

- Stop rollout of the current RC/build.
- Re-publish previous known-good artifact.
- Update release notes with rollback advisory.
- Collect diagnostics and analytics logs from affected runs.
- Open postmortem task with root cause and fix owner.

## 6. Post-Rollback Verification

- Confirm previous build starts and runs stable.
- Re-run smoke checklist on rolled-back build.
- Verify autosave and project load integrity.
- Confirm no new high-severity errors in console.

## 7. Beta Release Checklist

- RC gate passed.
- Rollback artifact tested and ready.
- Known limitations documented.
- User-facing update notes published.
- Support contact and response window prepared.
