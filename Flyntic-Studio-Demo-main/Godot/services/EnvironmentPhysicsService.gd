extends RefCounted

const PROFILE_LOW_HARDWARE := "low_hardware"
const PROFILE_BALANCED := "balanced"
const PROFILE_HIGH_FIDELITY := "high_fidelity"

var low_hardware_mode := true
var physics_profile := PROFILE_LOW_HARDWARE
var weather_preset := "clear_day"
var seed := 1337
var wind_base_strength := 0.45
var wind_gust_strength := 0.85
var emi_strength := 0.08
var drag_coefficient := 0.035
var day_cycle_speed := 0.015
var vertical_wind_strength := 0.10
var turbulence_scale := 1.0
var weather_wind_multiplier := 1.0
var weather_emi_multiplier := 1.0
var ambient_energy_min := 0.28
var ambient_energy_max := 1.05
var fog_density_min := 0.0015
var fog_density_max := 0.005

var _phase_a := 0.0
var _phase_b := 0.0
var _phase_c := 0.0

func configure(config: Dictionary):
	seed = int(config.get("seed", seed))
	_phase_a = float(seed % 97) * 0.017
	_phase_b = float(seed % 61) * 0.031
	_phase_c = float(seed % 43) * 0.047

	var requested_profile = str(config.get("physics_profile", physics_profile))
	if requested_profile == "":
		requested_profile = PROFILE_LOW_HARDWARE if bool(config.get("low_hardware_mode", low_hardware_mode)) else PROFILE_BALANCED
	_apply_profile(requested_profile)

	weather_preset = str(config.get("weather_preset", weather_preset))
	_apply_weather_preset(weather_preset)

	# Allow explicit overrides for tuning and experiments.
	wind_base_strength = float(config.get("wind_base_strength", wind_base_strength))
	wind_gust_strength = float(config.get("wind_gust_strength", wind_gust_strength))
	emi_strength = float(config.get("emi_strength", emi_strength))
	drag_coefficient = float(config.get("drag_coefficient", drag_coefficient))
	day_cycle_speed = float(config.get("day_cycle_speed", day_cycle_speed))
	vertical_wind_strength = float(config.get("vertical_wind_strength", vertical_wind_strength))
	turbulence_scale = float(config.get("turbulence_scale", turbulence_scale))

func _apply_profile(requested_profile: String):
	match requested_profile:
		PROFILE_LOW_HARDWARE:
			physics_profile = PROFILE_LOW_HARDWARE
			low_hardware_mode = true
			wind_base_strength = 0.42
			wind_gust_strength = 0.70
			emi_strength = 0.07
			drag_coefficient = 0.032
			day_cycle_speed = 0.012
			vertical_wind_strength = 0.08
			turbulence_scale = 0.80
		PROFILE_HIGH_FIDELITY:
			physics_profile = PROFILE_HIGH_FIDELITY
			low_hardware_mode = false
			wind_base_strength = 0.62
			wind_gust_strength = 1.35
			emi_strength = 0.12
			drag_coefficient = 0.040
			day_cycle_speed = 0.020
			vertical_wind_strength = 0.16
			turbulence_scale = 1.30
		_:
			physics_profile = PROFILE_BALANCED
			low_hardware_mode = false
			wind_base_strength = 0.50
			wind_gust_strength = 1.00
			emi_strength = 0.09
			drag_coefficient = 0.036
			day_cycle_speed = 0.015
			vertical_wind_strength = 0.11
			turbulence_scale = 1.00

func _apply_weather_preset(preset_name: String):
	match preset_name:
		"windy_evening":
			weather_preset = "windy_evening"
			weather_wind_multiplier = 1.35
			weather_emi_multiplier = 1.05
			ambient_energy_min = 0.20
			ambient_energy_max = 0.80
			fog_density_min = 0.002
			fog_density_max = 0.007
		"storm":
			weather_preset = "storm"
			weather_wind_multiplier = 1.75
			weather_emi_multiplier = 1.45
			ambient_energy_min = 0.14
			ambient_energy_max = 0.62
			fog_density_min = 0.004
			fog_density_max = 0.012
		_:
			weather_preset = "clear_day"
			weather_wind_multiplier = 1.0
			weather_emi_multiplier = 1.0
			ambient_energy_min = 0.28
			ambient_energy_max = 1.05
			fog_density_min = 0.0015
			fog_density_max = 0.005

func _smoothstep(edge0: float, edge1: float, x: float) -> float:
	var t = clamp((x - edge0) / max(edge1 - edge0, 0.0001), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func _layered_wind(sim_time: float, position: Vector3) -> Vector3:
	var altitude = max(position.y, 0.0)
	var low_w = 1.0 - _smoothstep(2.0, 14.0, altitude)
	var mid_w = _smoothstep(4.0, 18.0, altitude) * (1.0 - _smoothstep(20.0, 40.0, altitude))
	var high_w = _smoothstep(18.0, 45.0, altitude)

	var low_dir = Vector3(
		sin(sim_time * 0.35 + position.z * 0.06 + _phase_a),
		sin(sim_time * 0.51 + _phase_b) * vertical_wind_strength,
		cos(sim_time * 0.29 + position.x * 0.05 + _phase_c)
	)
	var mid_dir = Vector3(
		sin(sim_time * 0.63 + position.z * 0.09 + _phase_b),
		sin(sim_time * 0.77 + _phase_c) * vertical_wind_strength * 1.25,
		cos(sim_time * 0.57 + position.x * 0.08 + _phase_a)
	)
	var high_dir = Vector3(
		sin(sim_time * 0.92 + position.z * 0.12 + _phase_c),
		sin(sim_time * 1.06 + _phase_a) * vertical_wind_strength * 1.65,
		cos(sim_time * 0.88 + position.x * 0.11 + _phase_b)
	)

	var turbulence = Vector3(
		sin(sim_time * 2.7 + position.x * 0.21 + _phase_b),
		sin(sim_time * 3.1 + position.y * 0.17 + _phase_c),
		cos(sim_time * 2.4 + position.z * 0.18 + _phase_a)
	) * wind_gust_strength * 0.20 * turbulence_scale

	var layered = low_dir * low_w + mid_dir * mid_w * 1.12 + high_dir * high_w * 1.20
	return (layered * wind_base_strength + turbulence) * weather_wind_multiplier

func sample_state(sim_time: float, position: Vector3, velocity: Vector3) -> Dictionary:
	var wind = _layered_wind(sim_time, position)

	var speed = velocity.length()
	var drag = velocity * (-drag_coefficient * speed)

	var emi_channels = {
		"gps_drift": Vector3(
			sin(sim_time * 1.35 + position.x * 0.16 + _phase_a),
			cos(sim_time * 1.18 + position.y * 0.12 + _phase_b),
			sin(sim_time * 1.27 + position.z * 0.19 + _phase_c)
		) * emi_strength * weather_emi_multiplier,
		"magnetometer_bias": Vector3(
			cos(sim_time * 0.82 + position.z * 0.07 + _phase_b),
			sin(sim_time * 0.71 + position.x * 0.09 + _phase_c),
			cos(sim_time * 0.66 + position.y * 0.11 + _phase_a)
		) * emi_strength * weather_emi_multiplier * 0.75,
		"gyro_jitter": Vector3(
			sin(sim_time * 2.8 + position.x * 0.23 + _phase_c),
			cos(sim_time * 2.4 + position.y * 0.21 + _phase_a),
			sin(sim_time * 3.0 + position.z * 0.17 + _phase_b)
		) * emi_strength * weather_emi_multiplier * 1.15,
	}
	var emi = (emi_channels["gps_drift"] + emi_channels["magnetometer_bias"] + emi_channels["gyro_jitter"]) / 3.0

	var light_phase = 0.5 + 0.5 * sin(sim_time * day_cycle_speed + _phase_a)
	var luminance = lerp(ambient_energy_min, ambient_energy_max, light_phase)

	return {
		"wind": wind,
		"drag": drag,
		"emi": emi,
		"emi_channels": emi_channels,
		"luminance": luminance,
		"physics_profile": physics_profile,
		"weather_preset": weather_preset,
		"seed": seed,
	}

func apply_environment_lighting(env: Environment, sim_time: float):
	if env == null:
		return
	var light_phase = 0.5 + 0.5 * sin(sim_time * day_cycle_speed + _phase_a)
	env.ambient_light_energy = lerp(ambient_energy_min, ambient_energy_max, light_phase)
	if not low_hardware_mode:
		env.fog_enabled = true
		env.fog_density = lerp(fog_density_min, fog_density_max, 1.0 - light_phase)
	else:
		env.fog_enabled = false
