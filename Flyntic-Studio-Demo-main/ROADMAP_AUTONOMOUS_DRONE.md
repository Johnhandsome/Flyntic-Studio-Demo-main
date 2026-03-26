# Autonomous Drone Simulator Roadmap (Low Hardware First)

This roadmap consolidates productization and architecture planning with focus on realistic simulation, swarm capability, and telemetry-grade data collection.

## Vision

- Build a desktop simulator that behaves like a practical autonomous-drone R&D tool.
- Keep hardware requirements low by default while allowing high-fidelity modes.
- Generate reproducible flight datasets from physically grounded virtual flights.

## Current Baseline

- Environment module integrated: wind, drag approximation, EMI noise, dynamic luminance.
- Swarm module integrated: follower drones with lightweight formation behavior.
- Telemetry recorder integrated: JSONL + CSV session capture.
- Mission planner MVP integrated: waypoint-based autonomous target generation.
- Mission graph baseline integrated: waypoint chain with geofence-triggered return-home branch.
- Sensor model plugin integrated: GPS/IMU/barometer synthetic sampling with EMI-influenced noise.
- Replay runner integrated: deterministic replay from recorded telemetry CSV sessions.
- Safety layer integrated: geofence monitoring with failsafe RTL/emergency land modes.
- Controller mode cycle integrated: manual assist, auto mission, adaptive hover.
- Swarm behavior presets integrated: leader-follower, area sweep, relay chain.
- Telemetry manifest integrated: session metadata includes seed/profile for reproducibility context.
- Telemetry validator integrated: in-app data quality checks for monotonicity/parse/outlier signals.
- Analytics instrumentation and in-app metrics summary available.
- Save/load schema versioning, autosave, recovery flow already in place.

## Phase A - Physical Fidelity Core (Now -> +4 weeks)

### Objectives
- Improve realism without requiring high-end GPU/CPU.
- Stabilize deterministic replay and telemetry quality.

### Deliverables
- Wind model v2: layered turbulence profile by altitude.
- EMI model v2: sensor-specific noise channels (GPS drift, magnetometer bias, gyro jitter).
- Lighting/weather presets with deterministic seeds.
- Physics profile presets:
  - `low_hardware` (default)
  - `balanced`
  - `high_fidelity`

### Success Metrics
- 60 FPS on low-hardware profile for standard single-drone scenario.
- Telemetry session files generated with no schema violations.
- Repeat run with same seed produces near-identical trajectories.

## Phase B - Autonomous Stack ( +4 -> +8 weeks )

### Objectives
- Enable complex autonomous workflows in simulator.

### Deliverables
- Mission graph (waypoints, geofence, return-home).
- Safety layer (failsafe triggers, emergency land, battery thresholds).
- Sensor abstraction layer (GPS/IMU/barometer/vision placeholders).
- Controller modes:
  - manual assist
  - auto mission
  - adaptive hover under wind disturbances

### Success Metrics
- Autonomous mission completion rate >= 90% in balanced profile.
- Failsafe triggers execute correctly in all predefined fault cases.

## Phase C - Swarm Intelligence ( +8 -> +12 weeks )

### Objectives
- Support multi-drone coordination under constrained compute.

### Deliverables
- Formation manager (line, V, circle, custom offsets).
- Collision avoidance envelope and separation tuning.
- Swarm behavior presets:
  - leader-follower
  - area sweep
  - relay chain
- Multi-agent telemetry labeling for each drone ID.

### Success Metrics
- 8-12 drones in low-hardware profile with stable update loop.
- Collision incidents reduced below defined threshold in standard scenarios.

## Phase D - Data Productization ( +12 -> +16 weeks )

### Objectives
- Turn simulator output into research and model-training grade data.

### Deliverables
- Dataset export bundles (CSV/JSONL + metadata manifest + seed + profile config).
- Replay runner for deterministic re-simulation.
- Data quality validator (missing fields, outliers, timestamp monotonicity).
- Scenario library for autonomous + swarm benchmark runs.

### Success Metrics
- End-to-end dataset generation and validation in one command.
- Reproducibility pass for benchmark scenarios.

## Low-Hardware Strategy (Always-On)

- Keep expensive rendering disabled by default.
- Use lightweight proxy meshes for swarm members.
- Decouple telemetry sampling rate from render frame rate.
- Prefer deterministic math and fixed-step updates where possible.
- Make high-fidelity effects optional and profile-gated.

## Repo Operating Rules

- Keep backlog execution in `IMPLEMENTATION_BACKLOG.md`.
- Keep release gates in `docs/release/RELEASE_SMOKE_CHECKLIST.md` and `docs/release/RC_ROLLBACK_PLAYBOOK.md`.
- Keep this roadmap as the single strategic source for autonomous/swarm/data direction.
