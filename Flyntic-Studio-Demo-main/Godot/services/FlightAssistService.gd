extends RefCounted

func apply_control_mode(mode: String, base_target: Vector3, wind: Vector3, delta: float, sim_sequence: Array, sim_step_idx: int, current_pos: Vector3, sim_target_pos: Vector3) -> Vector3:
	var final_target = base_target
	match mode:
		"adaptive_hover":
			final_target += wind * delta * 0.18
			if sim_sequence.size() == 0 or (sim_step_idx < sim_sequence.size() and (sim_sequence[sim_step_idx].type == "hover" or sim_sequence[sim_step_idx].type == "wait")):
				final_target = final_target.lerp(Vector3(current_pos.x, sim_target_pos.y, current_pos.z), 0.35)
		"auto_mission":
			final_target += wind * delta * 0.30
		_:
			final_target += wind * delta * 0.45
	return final_target
