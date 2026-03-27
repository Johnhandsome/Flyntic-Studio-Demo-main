extends RefCounted

func update_runtime(payload: Dictionary) -> Dictionary:
	var delta = float(payload.get("delta", 0.0))
	var sim_time = float(payload.get("sim_time", 0.0))
	var leader_pos: Vector3 = payload.get("leader_pos", Vector3.ZERO)
	var prev_pos: Vector3 = payload.get("prev_pos", leader_pos)
	var prev_vel: Vector3 = payload.get("prev_vel", Vector3.ZERO)
	var env_state: Dictionary = payload.get("env_state", {})
	var sensor_model: RefCounted = payload.get("sensor_model", null)
	var sensor_state: Dictionary = payload.get("sensor_state", {})
	var swarm_enabled = bool(payload.get("swarm_enabled", false))
	var swarm_controller: RefCounted = payload.get("swarm_controller", null)
	var swarm_behavior = str(payload.get("swarm_behavior", "leader_follower"))
	var telemetry_recorder: RefCounted = payload.get("telemetry_recorder", null)
	var telemetry_timer = float(payload.get("telemetry_sample_timer", 0.0))
	var telemetry_rate = float(payload.get("telemetry_sample_rate", 12.0))
	var safety_state: Dictionary = payload.get("safety_state", {})

	var leader_vel = (leader_pos - prev_pos) / max(delta, 0.0001)
	var accel = (leader_vel - prev_vel) / max(delta, 0.0001)

	if sensor_model != null:
		sensor_state = sensor_model.sample(sim_time, leader_pos, leader_vel, accel, env_state.get("emi_channels", env_state.get("emi", Vector3.ZERO)))

	if swarm_enabled and swarm_controller != null:
		swarm_controller.update_followers(
			delta,
			leader_pos,
			leader_vel,
			env_state.get("wind", Vector3.ZERO),
			swarm_behavior,
			sim_time
		)

	telemetry_timer += delta
	if telemetry_recorder != null and telemetry_recorder.is_active() and telemetry_timer >= (1.0 / max(telemetry_rate, 1.0)):
		telemetry_timer = 0.0
		telemetry_recorder.record({
			"ts": Time.get_unix_time_from_system(),
			"sim_time": sim_time,
			"position": leader_pos,
			"velocity": leader_vel,
			"acceleration": accel,
			"sensor": sensor_state,
			"wind": env_state.get("wind", Vector3.ZERO),
			"emi": env_state.get("emi", Vector3.ZERO),
			"luminance": float(env_state.get("luminance", 1.0)),
			"swarm_count": swarm_controller.follower_count() if swarm_controller != null else 0,
			"safety": safety_state,
		})

	return {
		"sensor_state": sensor_state,
		"telemetry_sample_timer": telemetry_timer,
		"prev_leader_pos": leader_pos,
		"prev_leader_vel": leader_vel,
	}
