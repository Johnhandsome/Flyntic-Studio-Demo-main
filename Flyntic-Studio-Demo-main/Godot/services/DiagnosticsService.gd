extends RefCounted

func build_issues(payload: Dictionary) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	var diag_error = str(payload.get("diag_error", "error"))
	var diag_warning = str(payload.get("diag_warning", "warning"))
	var diag_info = str(payload.get("diag_info", "info"))
	var placed: Array = payload.get("placed", [])
	var sim_state = str(payload.get("sim_state", "stopped"))
	var sim_time = float(payload.get("sim_time", 0.0))
	var sim_step_idx = int(payload.get("sim_step_idx", 0))
	var sim_sequence: Array = payload.get("sim_sequence", [])
	var position: Vector3 = payload.get("position", Vector3.ZERO)

	if sim_state == "playing" or sim_state == "paused":
		issues.append(_issue(diag_info, "SIM: %s | Time: %.1fs" % [sim_state.to_upper(), sim_time]))
		if sim_step_idx < sim_sequence.size():
			var step: Dictionary = sim_sequence[sim_step_idx]
			issues.append(_issue(diag_info, "Step %d/%d: %s" % [sim_step_idx + 1, sim_sequence.size(), str(step.get("type", "step"))]))
			issues.append(_issue(diag_info, "Alt: %.2fm | Pos: (%.1f, %.1f)" % [position.y, position.x, position.z]))
		else:
			issues.append(_issue(diag_info, "Flight plan completed"))
		return issues

	var has_bat := false
	var has_frame := false
	var motor_count := 0
	var prop_count := 0
	for c in placed:
		var c_type = str(c.get("type", ""))
		if c_type == "Battery":
			has_bat = true
		elif c_type == "Frame":
			has_frame = true
		elif c_type == "Motor":
			motor_count += 1
		elif c_type == "Propeller":
			prop_count += 1

	if not has_frame:
		issues.append(_issue(diag_error, "No frame detected", "Add one frame before simulation"))
	if not has_bat:
		issues.append(_issue(diag_error, "No battery placed", "Add a battery and wire power rails"))
	if motor_count == 0:
		issues.append(_issue(diag_error, "No motors installed", "Place at least 1 motor (4 recommended)"))
	elif motor_count < 4:
		issues.append(_issue(diag_warning, "Only %d motors (4 recommended)" % motor_count, "Place additional motors for stable quad behavior"))
	if prop_count < motor_count:
		issues.append(_issue(diag_warning, "%d motors missing propellers" % (motor_count - prop_count), "Attach propellers to all active motors"))

	if issues.size() == 0:
		issues.append(_issue(diag_info, "All systems nominal"))

	var wiring_issues: Array = payload.get("wiring_issues", [])
	for wi in wiring_issues:
		issues.append(wi)
	if wiring_issues.size() > 0:
		issues.append(_issue(diag_info, "Press F9 to auto-fix common wiring issues"))

	var env_state: Dictionary = payload.get("env_state", {})
	var wind: Vector3 = env_state.get("wind", Vector3.ZERO)
	var emi: Vector3 = env_state.get("emi", Vector3.ZERO)
	issues.append(_issue(
		diag_info,
		"Env wind=(%.2f, %.2f, %.2f), EMI=(%.2f, %.2f, %.2f), light=%.2f" % [
			wind.x,
			wind.y,
			wind.z,
			emi.x,
			emi.y,
			emi.z,
			float(env_state.get("luminance", 1.0)),
		]
	))

	issues.append(_issue(
		diag_info,
		"Swarm=%s (%d, %s), Telemetry=%s, LowHW=%s" % [
			"ON" if bool(payload.get("swarm_enabled", false)) else "OFF",
			int(payload.get("swarm_count", 0)),
			str(payload.get("swarm_behavior", "leader_follower")),
			"ON" if bool(payload.get("telemetry_active", false)) else "OFF",
			"ON" if bool(payload.get("low_hardware_mode", false)) else "OFF",
		]
	))

	issues.append(_issue(
		diag_info,
		"Mission=%s (%s), Control=%s, Replay=%s, SensorHealth=%.2f, Safety=%s" % [
			"ON" if bool(payload.get("mission_active", false)) else "OFF",
			str(payload.get("mission_mode", "n/a")),
			str(payload.get("flight_control_mode", "manual_assist")),
			"ON" if bool(payload.get("replay_active", false)) else "OFF",
			float(payload.get("sensor_health", 1.0)),
			"ON" if bool(payload.get("safety_enabled", false)) else "OFF",
		]
	))

	var safety_state: Dictionary = payload.get("safety_state", {})
	issues.append(_issue(
		diag_info,
		"Battery %.0f%%, SafetyMode=%s, Reason=%s" % [
			float(payload.get("battery_ratio", 1.0)) * 100.0,
			str(safety_state.get("mode", "none")).to_upper(),
			str(safety_state.get("reason", "")),
		]
	))

	return issues

func _issue(severity: String, message: String, fix_hint: String = "") -> Dictionary:
	return {
		"severity": severity,
		"message": message,
		"fix_hint": fix_hint,
	}
