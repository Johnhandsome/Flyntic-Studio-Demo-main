extends RefCounted

var _waypoints: Array[Vector3] = []
var _active := false
var _idx := 0
var _arrival_radius := 0.7
var _cruise_speed := 2.4

func configure(config: Dictionary):
	_arrival_radius = float(config.get("arrival_radius", _arrival_radius))
	_cruise_speed = float(config.get("cruise_speed", _cruise_speed))

func load_default_mission(origin: Vector3):
	_waypoints.clear()
	_waypoints.append(origin + Vector3(0, 2.5, 0))
	_waypoints.append(origin + Vector3(4.0, 2.8, -3.0))
	_waypoints.append(origin + Vector3(-4.0, 3.2, -2.0))
	_waypoints.append(origin + Vector3(-3.0, 2.6, 3.5))
	_waypoints.append(origin + Vector3(3.5, 2.4, 3.0))
	_waypoints.append(origin + Vector3(0, 1.2, 0))
	_idx = 0

func start():
	if _waypoints.is_empty():
		return
	_active = true
	_idx = 0

func stop():
	_active = false

func is_active() -> bool:
	return _active

func waypoint_count() -> int:
	return _waypoints.size()

func current_index() -> int:
	return _idx

func compute_target(current_pos: Vector3, current_vel: Vector3, delta: float) -> Dictionary:
	if not _active or _waypoints.is_empty():
		return {"active": false}
	if _idx >= _waypoints.size():
		_active = false
		return {"active": false, "completed": true}

	var wp = _waypoints[_idx]
	var to_wp = wp - current_pos
	var dist = to_wp.length()
	if dist <= _arrival_radius:
		_idx += 1
		if _idx >= _waypoints.size():
			_active = false
			return {"active": false, "completed": true}
		wp = _waypoints[_idx]
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
		"remaining": _waypoints.size() - _idx,
	}
