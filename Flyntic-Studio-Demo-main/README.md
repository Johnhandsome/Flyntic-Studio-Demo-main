# Flyntic Studio

Flyntic Studio is a Godot-based drone assembly and simulation demo. It provides an interactive workspace to place components, wire systems, run preflight checks, and execute block-based flight sequences.

## Features
- **Drone Assembly Management:** Create, edit, and manage drone assemblies with customizable components.
- **Simulation & Diagnostics:** Run simulation steps, monitor capability checks, and validate wiring constraints.
- **Block Programming UI:** Build and execute command chains for drone behavior.
- **Project Save/Load:** Persist projects via `.flyntic` files.
- **Environment Physics:** Wind/EMI/light effects with low-hardware-friendly defaults.
- **Swarm Baseline:** Lightweight multi-drone follower formation mode.
- **Swarm Behaviors:** Leader-follower, area sweep, and relay-chain presets.
- **Flight Control Modes:** Manual assist, auto mission, and adaptive hover.
- **Telemetry Capture:** Session data export to JSONL/CSV for analysis and model development.
- **Dataset Reproducibility:** Per-session telemetry manifest (seed/profile metadata) and in-app quality validation.

## Project Structure
- `Godot/`: Main Godot project, scripts, scenes, and assets.
- `Godot/services/`: Extracted runtime services (input, telemetry, mission, assist, analytics, safety).
- `TODO_GODOT.md`: Functional TODO list focused on Godot scope.
- `IMPLEMENTATION_BACKLOG.md`: Prioritized sprint-ready backlog.
- `ROADMAP_AUTONOMOUS_DRONE.md`: Unified roadmap for realistic physics, swarm, and autonomous data platform.

## Runtime Controls
- `F2`: Cycle swarm behavior preset.
- `F3`: Cycle flight control mode.
- `F4`: Validate latest telemetry CSV quality (row integrity, monotonic timestamps, outlier scan).
- `F5`: Toggle safety layer (geofence + failsafe RTL/land).
- `F6`: Toggle telemetry recording session.
- `F7`: Toggle swarm follower drones.
- `F8`: Toggle low-hardware mode.
- `F9`: Guided remediation for common wiring issues.
- `F10`: Toggle autonomous mission planner.
- `F12`: Toggle deterministic replay mode from latest telemetry CSV.

## Getting Started
1. **Clone the repository:**
   ```bash
   git clone https://github.com/Eau-Claire/Flyntic-Studio-Demo.git
   ```
2. **Open the Godot project:**
   - Open Godot Engine.
   - Import `Godot/project.godot`.
3. **Run the project:**
   - Use the editor Run button.

## Requirements
- Godot 4.x

## License
MIT License