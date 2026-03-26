extends RefCounted

func update_mission(payload: Dictionary) -> Dictionary:
	var mission_active = bool(payload.get("mission_active", false))
	var mission_planner: RefCounted = payload.get("mission_planner", null)
	var current_pos: Vector3 = payload.get("current_pos", Vector3.ZERO)
	var current_vel: Vector3 = payload.get("current_vel", Vector3.ZERO)
	var delta = float(payload.get("delta", 0.0))
	var safety_state: Dictionary = payload.get("safety_state", {})
	var sim_target_pos: Vector3 = payload.get("sim_target_pos", current_pos)

	if not mission_active or mission_planner == null:
		return {
			"mission_active": mission_active,
			"sim_target_pos": sim_target_pos,
			"status_text": "",
			"completed": false,
			"rth_used": false,
		}

	var mission = mission_planner.compute_target(
		current_pos,
		current_vel,
		delta,
		{
			"geofence_breached": str(safety_state.get("reason", "")) == "geofence_breach",
		}
	)

	if bool(mission.get("active", false)):
		sim_target_pos = mission.get("predicted", sim_target_pos)
		var mode = str(mission.get("mode", mission_planner.mode()))
		return {
			"mission_active": true,
			"sim_target_pos": sim_target_pos,
			"status_text": "AUTO %s %d/%d" % [mode.to_upper(), mission_planner.current_index() + 1, mission_planner.waypoint_count()],
			"completed": false,
			"rth_used": false,
		}

	if bool(mission.get("completed", false)):
		return {
			"mission_active": false,
			"sim_target_pos": sim_target_pos,
			"status_text": "",
			"completed": true,
			"rth_used": bool(mission.get("rth_used", false)),
		}

	return {
		"mission_active": mission_active,
		"sim_target_pos": sim_target_pos,
		"status_text": "",
		"completed": false,
		"rth_used": false,
	}
