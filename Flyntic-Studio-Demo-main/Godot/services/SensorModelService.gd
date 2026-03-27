extends RefCounted

var _seed := 1337
var _physics_profile := "low_hardware"
var _gps_noise := 0.22
var _imu_noise := 0.06
var _baro_noise := 0.12
var _mag_noise := 0.04

func _apply_profile(profile_name: String):
	_physics_profile = profile_name
	match profile_name:
		"high_fidelity":
			_gps_noise = 0.18
			_imu_noise = 0.05
			_baro_noise = 0.08
			_mag_noise = 0.03
		"balanced":
			_gps_noise = 0.22
			_imu_noise = 0.06
			_baro_noise = 0.12
			_mag_noise = 0.04
		_:
			_physics_profile = "low_hardware"
			_gps_noise = 0.27
			_imu_noise = 0.08
			_baro_noise = 0.16
			_mag_noise = 0.05

func configure(config: Dictionary):
	_seed = int(config.get("seed", _seed))
	_apply_profile(str(config.get("physics_profile", _physics_profile)))
	_gps_noise = float(config.get("gps_noise", _gps_noise))
	_imu_noise = float(config.get("imu_noise", _imu_noise))
	_baro_noise = float(config.get("baro_noise", _baro_noise))
	_mag_noise = float(config.get("mag_noise", _mag_noise))

func _noise3(t: float, scale: float, offset: float) -> Vector3:
	return Vector3(
		sin(t * 1.73 + offset + float(_seed) * 0.001),
		cos(t * 1.37 + offset * 1.7 + float(_seed) * 0.002),
		sin(t * 2.03 + offset * 0.6 + float(_seed) * 0.003)
	) * scale

func sample(sim_time: float, true_pos: Vector3, true_vel: Vector3, true_accel: Vector3, env_emi) -> Dictionary:
	var emi_vec := Vector3.ZERO
	var gps_emi := Vector3.ZERO
	var mag_emi := Vector3.ZERO
	var gyro_emi := Vector3.ZERO

	if typeof(env_emi) == TYPE_VECTOR3:
		emi_vec = env_emi
		gps_emi = env_emi
		mag_emi = env_emi * 0.7
		gyro_emi = env_emi * 1.1
	elif typeof(env_emi) == TYPE_DICTIONARY:
		var channels: Dictionary = env_emi
		gps_emi = channels.get("gps_drift", Vector3.ZERO)
		mag_emi = channels.get("magnetometer_bias", Vector3.ZERO)
		gyro_emi = channels.get("gyro_jitter", Vector3.ZERO)
		emi_vec = (gps_emi + mag_emi + gyro_emi) / 3.0

	var gps_bias = _noise3(sim_time, _gps_noise, 0.3) + gps_emi * 0.35 + emi_vec * 0.05
	var imu_bias = _noise3(sim_time, _imu_noise, 0.9) + gyro_emi * 0.25
	var mag_bias = _noise3(sim_time, _mag_noise, 1.8) + mag_emi * 0.30
	var baro = true_pos.y + sin(sim_time * 1.11 + float(_seed) * 0.01) * _baro_noise + emi_vec.y * 0.03
	return {
		"gps_pos": true_pos + gps_bias,
		"imu_vel": true_vel + imu_bias,
		"imu_accel": true_accel + _noise3(sim_time, _imu_noise * 0.6, 1.4) + gyro_emi * 0.2,
		"baro_alt": baro,
		"mag_bias": mag_bias,
		"gyro_jitter": gyro_emi,
		"health": clamp(1.0 - emi_vec.length() * 0.2, 0.0, 1.0),
		"profile": _physics_profile,
	}
