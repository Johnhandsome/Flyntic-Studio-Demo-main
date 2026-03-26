extends RefCounted

const MODE_PATH := "path"
const MODE_RTH := "return_home"

var _nodes: Array[Dictionary] = []
var _active := false
var _idx := 0
var _arrival_radius := 0.7
var _cruise_speed := 2.4
var _home := Vector3.ZERO
var _mode := MODE_PATH
var _rth_used := false

func configure(config: Dictionary):
	_arrival_radius = float(config.get("arrival_radius", _arrival_radius))
	_cruise_speed = float(config.get("cruise_speed", _cruise_speed))

func load_default_mission(origin: Vector3):
	_home = origin
	_mode = MODE_PATH
	_rth_used = false
	_nodes.clear()
	_nodes.append({"name": "takeoff", "pos": origin + Vector3(0, 2.5, 0), "next": 1})
	_nodes.append({"name": "survey_1", "pos": origin + Vector3(4.0, 2.8, -3.0), "next": 2})
	_nodes.append({"name": "survey_2", "pos": origin + Vector3(-4.0, 3.2, -2.0), "next": 3})
	_nodes.append({"name": "survey_3", "pos": origin + Vector3(-3.0, 2.6, 3.5), "next": 4})
	_nodes.append({"name": "survey_4", "pos": origin + Vector3(3.5, 2.4, 3.0), "next": 5})
	_nodes.append({"name": "land_home", "pos": origin + Vector3(0, 1.2, 0), "next": -1})
	_idx = 0

func start():
	if _nodes.is_empty():
		return
	_active = true
	_idx = 0
	_mode = MODE_PATH
	_rth_used = false

func stop():
	_active = false

func is_active() -> bool:
	return _active

func waypoint_count() -> int:
	return _nodes.size()

func current_index() -> int:
	return _idx

func mode() -> String:
	return _mode

func compute_target(current_pos: Vector3, current_vel: Vector3, delta: float, context: Dictionary = {}) -> Dictionary:
	if not _active or _nodes.is_empty():
		return {"active": false}

	var geofence_breached = bool(context.get("geofence_breached", false))
	if geofence_breached and _mode != MODE_RTH:
		_activate_return_home()

	if _idx < 0 or _idx >= _nodes.size():
		_active = false
		return {"active": false, "completed": true, "rth_used": _rth_used}

	var node: Dictionary = _nodes[_idx]
	var wp: Vector3 = node.get("pos", current_pos)
	var to_wp = wp - current_pos
	var dist = to_wp.length()
	if dist <= _arrival_radius:
		var next_idx = int(node.get("next", -1))
		if next_idx < 0 or next_idx >= _nodes.size():
			_active = false
			return {"active": false, "completed": true, "rth_used": _rth_used}
		_idx = next_idx
		node = _nodes[_idx]
		wp = node.get("pos", current_pos)
		to_wp = wp - current_pos
		dist = to_wp.length()

	var desired_vel = Vector3.ZERO
	if dist > 0.001:
		desired_vel = to_wp.normalized() * _cruise_speed
	var accel_cmd = (desired_vel - current_vel).limit_length(2.0)
	var predicted = current_pos + (current_vel + accel_cmd * delta) * delta
	return {
		"active": true,
		"target": wp,
		"predicted": predicted,
		"accel_cmd": accel_cmd,
		"remaining": _nodes.size() - _idx,
		"mode": _mode,
		"node": str(node.get("name", "")),
		"rth_used": _rth_used,
	}

func _activate_return_home():
	_mode = MODE_RTH
	_rth_used = true
	_nodes.clear()
	_nodes.append({"name": "rth_climb", "pos": _home + Vector3(0, 3.0, 0), "next": 1})
	_nodes.append({"name": "rth_land", "pos": _home + Vector3(0, 1.0, 0), "next": -1})
	_idx = 0
