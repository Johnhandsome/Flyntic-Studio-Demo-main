extends RefCounted

func canvas_active(tab_index: int) -> bool:
	return tab_index == 0

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
		actions.append("cycle_physics_profile")
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

func resolve_mouse_button(payload: Dictionary) -> Dictionary:
	var button_index = int(payload.get("button_index", 0))
	var pressed = bool(payload.get("pressed", false))
	var in_canvas = bool(payload.get("in_canvas", false))
	var sim_locked = bool(payload.get("sim_locked", false))
	var ghost_active = bool(payload.get("ghost_active", false))

	if button_index == MOUSE_BUTTON_LEFT:
		if not pressed:
			return {
				"action": "left_release",
				"orbiting": false,
				"panning": false,
			}
		if sim_locked:
			return {
				"action": "orbit_only",
				"orbiting": in_canvas,
				"panning": false,
			}
		if ghost_active and in_canvas:
			return {
				"action": "place_ghost",
				"orbiting": false,
				"panning": false,
			}
		if in_canvas:
			return {
				"action": "pick_or_orbit",
				"orbiting": false,
				"panning": false,
			}
		return {
			"action": "noop",
			"orbiting": false,
			"panning": false,
		}

	if button_index == MOUSE_BUTTON_RIGHT or button_index == MOUSE_BUTTON_MIDDLE:
		return {
			"action": "set_pan",
			"orbiting": false,
			"panning": pressed and in_canvas,
		}

	if button_index == MOUSE_BUTTON_WHEEL_UP:
		return {
			"action": "zoom",
			"zoom_delta": -1.5 if in_canvas else 0.0,
		}
	if button_index == MOUSE_BUTTON_WHEEL_DOWN:
		return {
			"action": "zoom",
			"zoom_delta": 1.5 if in_canvas else 0.0,
		}

	return {
		"action": "noop",
	}

func resolve_mouse_motion(payload: Dictionary) -> Dictionary:
	var rel: Vector2 = payload.get("relative", Vector2.ZERO)
	var orbiting = bool(payload.get("orbiting", false))
	var panning = bool(payload.get("panning", false))
	var zoom = float(payload.get("zoom", 10.0))

	if orbiting:
		return {
			"action": "orbit",
			"yaw_delta": -rel.x * 0.005,
			"pitch_delta": -rel.y * 0.005,
		}

	if panning:
		var pan_speed = zoom * 0.001
		return {
			"action": "pan",
			"pan_x": -rel.x * pan_speed,
			"pan_y": rel.y * pan_speed,
		}

	return {
		"action": "noop",
	}
