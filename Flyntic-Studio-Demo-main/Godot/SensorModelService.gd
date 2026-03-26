extends RefCounted

var _seed := 1337
var _gps_noise := 0.22
var _imu_noise := 0.06
var _baro_noise := 0.12

func configure(config: Dictionary):
	_seed = int(config.get("seed", _seed))
	_gps_noise = float(config.get("gps_noise", _gps_noise))
	_imu_noise = float(config.get("imu_noise", _imu_noise))
	_baro_noise = float(config.get("baro_noise", _baro_noise))

func _noise3(t: float, scale: float, offset: float) -> Vector3:
	return Vector3(
		sin(t * 1.73 + offset + float(_seed) * 0.001),
		cos(t * 1.37 + offset * 1.7 + float(_seed) * 0.002),
		sin(t * 2.03 + offset * 0.6 + float(_seed) * 0.003)
	) * scale

func sample(sim_time: float, true_pos: Vector3, true_vel: Vector3, true_accel: Vector3, env_emi: Vector3) -> Dictionary:
	var gps_bias = _noise3(sim_time, _gps_noise, 0.3) + env_emi * 0.1
	var imu_bias = _noise3(sim_time, _imu_noise, 0.9) + env_emi * 0.15
	var baro = true_pos.y + sin(sim_time * 1.11 + float(_seed) * 0.01) * _baro_noise + env_emi.y * 0.03
	return {
		"gps_pos": true_pos + gps_bias,
		"imu_vel": true_vel + imu_bias,
		"imu_accel": true_accel + _noise3(sim_time, _imu_noise * 0.6, 1.4),
		"baro_alt": baro,
		"health": clamp(1.0 - env_emi.length() * 0.2, 0.0, 1.0),
	}
