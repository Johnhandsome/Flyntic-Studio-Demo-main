extends RefCounted

func resolve_key_actions(event: InputEventKey, sim_locked: bool, ghost_active: bool) -> Array[String]:
	var actions: Array[String] = []
	if not event.pressed:
		return actions

	if not sim_locked:
		if event.keycode == KEY_R and ghost_active:
			actions.append("rotate_ghost")
		if event.keycode == KEY_ESCAPE:
			actions.append("cancel_ghost")
		if event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			actions.append("remove_selected")

	if event.ctrl_pressed and event.keycode == KEY_Z:
		actions.append("undo")
	if event.ctrl_pressed and event.keycode == KEY_Y:
		actions.append("redo")
	if event.ctrl_pressed and event.keycode == KEY_S:
		actions.append("save")
	if event.ctrl_pressed and event.keycode == KEY_O:
		actions.append("load")

	if event.keycode == KEY_HOME:
		actions.append("reset_camera")
	if event.keycode == KEY_F6:
		actions.append("toggle_telemetry")
	if event.keycode == KEY_F4:
		actions.append("validate_telemetry")
	if event.keycode == KEY_F3:
		actions.append("cycle_control_mode")
	if event.keycode == KEY_F2 and not sim_locked:
		actions.append("cycle_swarm_behavior")
	if event.keycode == KEY_F7 and not sim_locked:
		actions.append("toggle_swarm")
	if event.keycode == KEY_F8:
		actions.append("toggle_low_hardware")
	if event.keycode == KEY_F5:
		actions.append("toggle_safety")
	if event.keycode == KEY_F10 and not sim_locked:
		actions.append("toggle_mission")
	if event.keycode == KEY_F12 and not sim_locked:
		actions.append("toggle_replay")
	if event.keycode == KEY_F9 and not sim_locked:
		actions.append("run_remediation")
	if event.keycode == KEY_F and not sim_locked:
		actions.append("focus_selected")
	if event.keycode == KEY_F11:
		actions.append("toggle_fullscreen")

	return actions
