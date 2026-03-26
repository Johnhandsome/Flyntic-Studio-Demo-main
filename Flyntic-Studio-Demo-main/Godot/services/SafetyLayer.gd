extends RefCounted

const MODE_NONE := "none"
const MODE_RTL := "rtl"
const MODE_LAND := "land"

var _enabled := true
var _home := Vector3.ZERO
var _geofence_radius := 12.0
var _rtl_altitude := 2.8
var _land_rate := 1.2
var _battery_rtl_threshold := 0.18
var _signal_land_threshold := 0.25

var _active := false
var _mode := MODE_NONE
var _reason := ""

func configure(config: Dictionary):
	_enabled = bool(config.get("enabled", _enabled))
	_geofence_radius = float(config.get("geofence_radius", _geofence_radius))
	_rtl_altitude = float(config.get("rtl_altitude", _rtl_altitude))
	_land_rate = float(config.get("land_rate", _land_rate))
	_battery_rtl_threshold = float(config.get("battery_rtl_threshold", _battery_rtl_threshold))
	_signal_land_threshold = float(config.get("signal_land_threshold", _signal_land_threshold))

func set_enabled(enabled: bool):
	_enabled = enabled

func arm(home: Vector3):
	_home = home
	_active = false
	_mode = MODE_NONE
	_reason = ""

func disarm():
	_active = false
	_mode = MODE_NONE
	_reason = ""

func update(delta: float, current_pos: Vector3, desired_target: Vector3, battery_ratio: float, sensor_health: float) -> Dictionary:
	if not _enabled:
		return {
			"active": false,
			"mode": MODE_NONE,
			"reason": "disabled",
			"target": desired_target,
		}

	var horizontal_offset = Vector2(current_pos.x - _home.x, current_pos.z - _home.z)
	if not _active:
		if battery_ratio <= _battery_rtl_threshold:
			_active = true
			_mode = MODE_RTL
			_reason = "battery_low"
		elif horizontal_offset.length() > _geofence_radius:
			_active = true
			_mode = MODE_RTL
			_reason = "geofence_breach"
		elif sensor_health <= _signal_land_threshold:
			_active = true
			_mode = MODE_LAND
			_reason = "sensor_health_low"

	var target = desired_target
	if _active and _mode == MODE_RTL:
		target = _home + Vector3(0, _rtl_altitude, 0)
		var rtl_offset = Vector2(current_pos.x - _home.x, current_pos.z - _home.z)
		if rtl_offset.length() <= 0.8:
			_mode = MODE_LAND
			_reason = "rtl_arrived"

	if _active and _mode == MODE_LAND:
		target = Vector3(_home.x, max(current_pos.y - _land_rate * delta, 0.0), _home.z)
		if current_pos.y <= 0.15:
			_active = false
			_mode = MODE_NONE
			_reason = "landed"

	return {
		"active": _active,
		"mode": _mode,
		"reason": _reason,
		"target": target,
		"geofence_radius": _geofence_radius,
	}