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

func spin_propellers(payload: Dictionary):
	var delta = float(payload.get("delta", 0.0))
	var placed: Array = payload.get("placed", [])
	var bridge_rpms: Array = payload.get("bridge_rpms", [])

	var prop_idx := 0
	for comp in placed:
		if not is_instance_valid(comp.get("node")) or str(comp.get("type", "")) != "Propeller":
			continue
		for ch in comp.node.get_children():
			if not is_instance_valid(ch) or ch.name != "prop_blade":
				continue
			var spin_speed := 35.0
			if prop_idx < bridge_rpms.size() and float(bridge_rpms[prop_idx]) > 0.0:
				spin_speed = float(bridge_rpms[prop_idx]) / 150.0
			ch.rotation.y += delta * spin_speed
			prop_idx += 1

func settle_cannot_fly(payload: Dictionary) -> Dictionary:
	var capability = str(payload.get("capability", ""))
	var bridge_active = bool(payload.get("bridge_active", false))
	var current_pos: Vector3 = payload.get("current_pos", Vector3.ZERO)
	if capability != "Cannot fly" or bridge_active:
		return {"handled": false, "position": current_pos}

	current_pos.y = lerp(current_pos.y, 0.0, 0.08)
	return {"handled": true, "position": current_pos}

func should_force_bridge_land(safety_state: Dictionary) -> bool:
	return bool(safety_state.get("active", false)) and str(safety_state.get("mode", "none")) == "land"

func decide_simulation_path(payload: Dictionary) -> Dictionary:
	var capability = str(payload.get("capability", ""))
	var bridge_active = bool(payload.get("bridge_active", false))
	var use_bridge_physics = bool(payload.get("use_bridge_physics", false))
	var current_pos: Vector3 = payload.get("current_pos", Vector3.ZERO)
	var safety_state: Dictionary = payload.get("safety_state", {})

	var settle = settle_cannot_fly({
		"capability": capability,
		"bridge_active": bridge_active,
		"current_pos": current_pos,
	})
	if bool(settle.get("handled", false)):
		return {
			"mode": "settle",
			"position": settle.get("position", current_pos),
			"force_land": false,
		}

	if bridge_active and use_bridge_physics:
		return {
			"mode": "bridge",
			"position": current_pos,
			"force_land": should_force_bridge_land(safety_state),
		}

	return {
		"mode": "kinematic",
		"position": current_pos,
		"force_land": false,
	}

func build_bridge_step_start_action(payload: Dictionary) -> Dictionary:
	var sim_step_timer = float(payload.get("sim_step_timer", 0.0))
	var delta = float(payload.get("delta", 0.0))
	if sim_step_timer > delta * 2.0:
		return {"has_action": false}

	var step_type = str(payload.get("step_type", ""))
	var step_value = float(payload.get("step_value", 0.0))
	var step_duration = float(payload.get("step_duration", 0.01))
	var forward_basis_z: Vector3 = payload.get("forward_basis_z", Vector3.FORWARD)

	match step_type:
		"take_off":
			return {
				"has_action": true,
				"command": "takeoff",
				"height": 2.5,
				"log": "Bridge → Takeoff to 2.5m",
			}
		"forward":
			var speed = step_value * 0.05 / max(step_duration, 0.01)
			var fwd = -forward_basis_z.normalized()
			fwd.y = 0.0
			fwd = fwd.normalized()
			return {
				"has_action": true,
				"command": "move",
				"vx": fwd.x * speed,
				"vy": 0.0,
				"vz": fwd.z * speed,
				"log": "Bridge → Move forward %.1f cm (%.2f m/s)" % [step_value, speed],
			}
		"hover":
			return {
				"has_action": true,
				"command": "hover",
				"log": "Bridge → Hover",
			}
		"land":
			return {
				"has_action": true,
				"command": "land",
				"log": "Bridge → Land",
			}

	return {"has_action": false}
