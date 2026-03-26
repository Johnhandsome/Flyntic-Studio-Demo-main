extends RefCounted

func handle_replay(payload: Dictionary) -> Dictionary:
	var replay_active = bool(payload.get("replay_active", false))
	var replay_runner: RefCounted = payload.get("replay_runner", null)
	var sim_time = float(payload.get("sim_time", 0.0))
	var current_pos: Vector3 = payload.get("current_pos", Vector3.ZERO)

	if not replay_active or replay_runner == null:
		return {
			"handled": false,
			"replay_active": replay_active,
		}

	var sample = replay_runner.sample(sim_time)
	var pos = current_pos
	var look_dir = Vector3.ZERO
	if bool(sample.get("ok", false)):
		var row: Dictionary = sample.get("row", {})
		pos = row.get("position", current_pos)
		var rv: Vector3 = row.get("velocity", Vector3.ZERO)
		if rv.length() > 0.01:
			look_dir = rv.normalized()

	var done = bool(sample.get("done", false))
	return {
		"handled": true,
		"position": pos,
		"look_dir": look_dir,
		"done": done,
		"replay_active": false if done else true,
	}

func apply_safety(payload: Dictionary) -> Dictionary:
	var safety_layer: RefCounted = payload.get("safety_layer", null)
	var delta = float(payload.get("delta", 0.0))
	var current_pos: Vector3 = payload.get("current_pos", Vector3.ZERO)
	var sim_target_pos: Vector3 = payload.get("sim_target_pos", current_pos)
	var battery_ratio = float(payload.get("battery_ratio", 1.0))
	var sensor_health = float(payload.get("sensor_health", 1.0))
	var mission_active = bool(payload.get("mission_active", false))
	var mission_planner: RefCounted = payload.get("mission_planner", null)
	var safety_state: Dictionary = payload.get("safety_state", {})

	if safety_layer == null:
		return {
			"safety_state": safety_state,
			"sim_target_pos": sim_target_pos,
			"mission_active": mission_active,
			"triggered": false,
		}

	var previous_active = bool(safety_state.get("active", false))
	safety_state = safety_layer.update(delta, current_pos, sim_target_pos, battery_ratio, sensor_health)
	if bool(safety_state.get("active", false)):
		sim_target_pos = safety_state.get("target", sim_target_pos)
		if mission_active and mission_planner != null:
			mission_planner.stop()
			mission_active = false

	return {
		"safety_state": safety_state,
		"sim_target_pos": sim_target_pos,
		"mission_active": mission_active,
		"triggered": bool(safety_state.get("active", false)) and not previous_active,
		"trigger_mode": str(safety_state.get("mode", "none")),
		"trigger_reason": str(safety_state.get("reason", "unknown")),
	}

func build_step_label(sim_step_idx: int, sim_sequence: Array, sim_step_timer: float) -> String:
	if sim_step_idx < 0 or sim_step_idx >= sim_sequence.size():
		return ""
	var step: Dictionary = sim_sequence[sim_step_idx]
	var duration = float(step.get("duration", 0.01))
	var pct = int((sim_step_timer / max(duration, 0.01)) * 100.0)
	return "Step %d/%d: %s (%d%%)" % [sim_step_idx + 1, sim_sequence.size(), str(step.get("type", "step")), min(pct, 100)]
