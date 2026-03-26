extends RefCounted

var low_hardware_mode := true
var wind_base_strength := 0.45
var wind_gust_strength := 0.85
var emi_strength := 0.08
var drag_coefficient := 0.035
var day_cycle_speed := 0.015

func configure(config: Dictionary):
	low_hardware_mode = bool(config.get("low_hardware_mode", low_hardware_mode))
	wind_base_strength = float(config.get("wind_base_strength", wind_base_strength))
	wind_gust_strength = float(config.get("wind_gust_strength", wind_gust_strength))
	emi_strength = float(config.get("emi_strength", emi_strength))
	drag_coefficient = float(config.get("drag_coefficient", drag_coefficient))
	day_cycle_speed = float(config.get("day_cycle_speed", day_cycle_speed))

func sample_state(sim_time: float, position: Vector3, velocity: Vector3) -> Dictionary:
	var wx = sin(sim_time * 0.41 + position.z * 0.07) * wind_base_strength
	var wz = cos(sim_time * 0.33 + position.x * 0.05) * wind_base_strength
	var gust = sin(sim_time * 2.2 + position.y * 0.3) * wind_gust_strength
	var wind = Vector3(wx + gust * 0.25, sin(sim_time * 0.57) * 0.1, wz + gust * 0.25)

	var speed = velocity.length()
	var drag = velocity * (-drag_coefficient * speed)

	var emi = Vector3(
		sin(sim_time * 1.8 + position.x * 0.2),
		cos(sim_time * 1.4 + position.y * 0.3),
		sin(sim_time * 1.1 + position.z * 0.2)
	) * emi_strength

	var light_phase = 0.5 + 0.5 * sin(sim_time * day_cycle_speed)
	var luminance = lerp(0.25, 1.0, light_phase)

	return {
		"wind": wind,
		"drag": drag,
		"emi": emi,
		"luminance": luminance,
	}

func apply_environment_lighting(env: Environment, sim_time: float):
	if env == null:
		return
	var light_phase = 0.5 + 0.5 * sin(sim_time * day_cycle_speed)
	env.ambient_light_energy = lerp(0.28, 1.05, light_phase)
	if not low_hardware_mode:
		env.fog_enabled = true
		env.fog_density = lerp(0.002, 0.006, 1.0 - light_phase)
