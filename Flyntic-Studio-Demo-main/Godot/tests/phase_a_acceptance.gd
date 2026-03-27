extends SceneTree

const PROFILE_LOW_HARDWARE := "low_hardware"
const PROFILE_BALANCED := "balanced"
const PROFILE_HIGH_FIDELITY := "high_fidelity"

const WEATHER_CLEAR_DAY := "clear_day"
const WEATHER_WINDY_EVENING := "windy_evening"
const WEATHER_STORM := "storm"

const STEP_DT := 1.0 / 60.0
const FPS_TARGET_LOW_HARDWARE := 60.0
const TRAJECTORY_RMSE_THRESHOLD := 0.0001
const SIM_DURATION_LOW_HARDWARE := 30.0
const SIM_DURATION_OTHER := 12.0

var _failures: Array[String] = []

func _initialize():
	print("[PHASE_A] Starting acceptance run...")
	var env_script = load("res://services/EnvironmentPhysicsService.gd")
	var sensor_script = load("res://services/SensorModelService.gd")
	var recorder_script = load("res://services/TelemetryRecorder.gd")
	var validator_script = load("res://services/TelemetryDataValidator.gd")

	_assert_true("EnvironmentPhysicsService.gd load", env_script != null)
	_assert_true("SensorModelService.gd load", sensor_script != null)
	_assert_true("TelemetryRecorder.gd load", recorder_script != null)
	_assert_true("TelemetryDataValidator.gd load", validator_script != null)
	if not _failures.is_empty():
		_finish()
		return

	var out_dir = "user://telemetry_phase_a"
	DirAccess.make_dir_recursive_absolute(out_dir)

	var low = _run_profile_case(
		env_script,
		sensor_script,
		recorder_script,
		validator_script,
		PROFILE_LOW_HARDWARE,
		WEATHER_CLEAR_DAY,
		1337,
		SIM_DURATION_LOW_HARDWARE
	)
	var balanced = _run_profile_case(
		env_script,
		sensor_script,
		recorder_script,
		validator_script,
		PROFILE_BALANCED,
		WEATHER_WINDY_EVENING,
		2337,
		SIM_DURATION_OTHER
	)
	var high = _run_profile_case(
		env_script,
		sensor_script,
		recorder_script,
		validator_script,
		PROFILE_HIGH_FIDELITY,
		WEATHER_STORM,
		3337,
		SIM_DURATION_OTHER
	)

	_assert_true("low_hardware case ok", bool(low.get("ok", false)))
	_assert_true("balanced case ok", bool(balanced.get("ok", false)))
	_assert_true("high_fidelity case ok", bool(high.get("ok", false)))

	if bool(low.get("ok", false)):
		var low_fps = float(low.get("sim_fps", 0.0))
		print("[PHASE_A] low_hardware sim_fps=%.2f" % low_fps)
		_assert_true(
			"low_hardware reaches >= 60 sim updates/s",
			low_fps >= FPS_TARGET_LOW_HARDWARE
		)

	var deterministic = _run_determinism_check(
		env_script,
		sensor_script,
		recorder_script,
		PROFILE_LOW_HARDWARE,
		WEATHER_CLEAR_DAY,
		4444,
		12.0
	)
	_assert_true("determinism check ok", bool(deterministic.get("ok", false)))
	if bool(deterministic.get("ok", false)):
		var rmse = float(deterministic.get("rmse", 999.0))
		print("[PHASE_A] deterministic trajectory RMSE=%.8f" % rmse)
		_assert_true("deterministic trajectory RMSE threshold", rmse <= TRAJECTORY_RMSE_THRESHOLD)

	_finish()

func _assert_true(name: String, cond: bool):
	if not cond:
		_failures.append(name)

func _finish():
	if _failures.is_empty():
		print("[PHASE_A] PASS")
		quit(0)
		return
	print("[PHASE_A] FAIL: %d checks failed" % _failures.size())
	for f in _failures:
		print(" - " + f)
	quit(1)

func _default_metadata(profile_name: String, weather: String, seed: int) -> Dictionary:
	return {
		"seed": seed,
		"profile": profile_name,
		"weather_preset": weather,
		"sample_rate_hz": 60.0,
	}

func _run_profile_case(
	env_script,
	sensor_script,
	recorder_script,
	validator_script,
	profile_name: String,
	weather: String,
	seed: int,
	duration_sec: float
) -> Dictionary:
	var env = env_script.new()
	env.configure({
		"seed": seed,
		"physics_profile": profile_name,
		"weather_preset": weather,
	})
	var sensor = sensor_script.new()
	sensor.configure({
		"seed": seed,
		"physics_profile": profile_name,
	})
	var recorder = recorder_script.new()
	recorder.initialize("user://telemetry_phase_a")
	var validator = validator_script.new()

	var start_result = recorder.start_session("phase_a_%s" % profile_name, _default_metadata(profile_name, weather, seed))
	if not bool(start_result.get("ok", false)):
		return {"ok": false, "reason": "telemetry_start_failed"}

	var steps = maxi(1, int(duration_sec / STEP_DT))
	var prev_pos = _trajectory_position(0.0)
	var prev_vel = Vector3.ZERO
	var sim_time = 0.0

	var perf_start = Time.get_ticks_usec()
	for i in range(steps):
		sim_time = float(i) * STEP_DT
		var pos = _trajectory_position(sim_time)
		var vel = (pos - prev_pos) / STEP_DT
		var accel = (vel - prev_vel) / STEP_DT
		var env_state: Dictionary = env.sample_state(sim_time, pos, vel)
		var emi_channels = env_state.get("emi_channels", env_state.get("emi", Vector3.ZERO))
		var sensor_state = sensor.sample(sim_time, pos, vel, accel, emi_channels)

		recorder.record({
			"ts": Time.get_unix_time_from_system(),
			"sim_time": sim_time,
			"position": pos,
			"velocity": vel,
			"acceleration": accel,
			"sensor": sensor_state,
			"wind": env_state.get("wind", Vector3.ZERO),
			"emi": env_state.get("emi", Vector3.ZERO),
			"luminance": float(env_state.get("luminance", 1.0)),
			"swarm_count": 0,
		})

		prev_pos = pos
		prev_vel = vel
	var perf_end = Time.get_ticks_usec()
	recorder.stop_session()

	var elapsed_sec = max((perf_end - perf_start) / 1000000.0, 0.0001)
	var sim_fps = float(steps) / elapsed_sec

	var csv_path = str(start_result.get("csv", ""))
	var manifest_path = str(start_result.get("manifest", ""))
	if csv_path == "" or manifest_path == "":
		return {"ok": false, "reason": "telemetry_paths_missing"}

	var quality = validator.validate_csv(csv_path)
	if not bool(quality.get("ok", false)):
		return {"ok": false, "reason": "validator_failed"}
	if int(quality.get("parse_errors", 0)) != 0:
		return {"ok": false, "reason": "parse_errors"}
	if int(quality.get("monotonic_errors", 0)) != 0:
		return {"ok": false, "reason": "monotonic_errors"}
	if int(quality.get("rows", 0)) <= 0:
		return {"ok": false, "reason": "no_rows"}

	var manifest = _read_manifest(manifest_path)
	if manifest.is_empty():
		return {"ok": false, "reason": "manifest_missing"}
	var metadata: Dictionary = manifest.get("metadata", {})
	if str(metadata.get("profile", "")) != profile_name:
		return {"ok": false, "reason": "manifest_profile_mismatch"}
	if str(metadata.get("weather_preset", "")) != weather:
		return {"ok": false, "reason": "manifest_weather_mismatch"}
	if int(metadata.get("seed", -1)) != seed:
		return {"ok": false, "reason": "manifest_seed_mismatch"}

	return {
		"ok": true,
		"csv": csv_path,
		"manifest": manifest_path,
		"sim_fps": sim_fps,
		"quality": quality,
	}

func _run_determinism_check(env_script, sensor_script, recorder_script, profile_name: String, weather: String, seed: int, duration_sec: float) -> Dictionary:
	var a = _run_determinism_trace(env_script, sensor_script, recorder_script, profile_name, weather, seed, duration_sec, "det_a")
	if not bool(a.get("ok", false)):
		return {"ok": false, "reason": "trace_a_failed"}
	var b = _run_determinism_trace(env_script, sensor_script, recorder_script, profile_name, weather, seed, duration_sec, "det_b")
	if not bool(b.get("ok", false)):
		return {"ok": false, "reason": "trace_b_failed"}

	var csv_a = str(a.get("csv", ""))
	var csv_b = str(b.get("csv", ""))
	if csv_a == "" or csv_b == "":
		return {"ok": false, "reason": "trace_paths_missing"}

	var path_a = _read_positions(csv_a)
	var path_b = _read_positions(csv_b)
	if path_a.size() == 0 or path_b.size() == 0:
		return {"ok": false, "reason": "empty_trace"}
	if path_a.size() != path_b.size():
		return {"ok": false, "reason": "trace_size_mismatch"}

	var sum_sq := 0.0
	for i in range(path_a.size()):
		var da: Vector3 = path_a[i]
		var db: Vector3 = path_b[i]
		sum_sq += da.distance_squared_to(db)
	var rmse = sqrt(sum_sq / float(path_a.size()))
	return {
		"ok": true,
		"rmse": rmse,
		"points": path_a.size(),
	}

func _run_determinism_trace(env_script, sensor_script, recorder_script, profile_name: String, weather: String, seed: int, duration_sec: float, tag: String) -> Dictionary:
	var env = env_script.new()
	env.configure({
		"seed": seed,
		"physics_profile": profile_name,
		"weather_preset": weather,
	})
	var sensor = sensor_script.new()
	sensor.configure({
		"seed": seed,
		"physics_profile": profile_name,
	})
	var recorder = recorder_script.new()
	recorder.initialize("user://telemetry_phase_a")
	var start_result = recorder.start_session("phase_a_%s_%s" % [profile_name, tag], _default_metadata(profile_name, weather, seed))
	if not bool(start_result.get("ok", false)):
		return {"ok": false, "reason": "start_failed"}

	var steps = maxi(1, int(duration_sec / STEP_DT))
	var prev_pos = _trajectory_position(0.0)
	var prev_vel = Vector3.ZERO
	for i in range(steps):
		var t = float(i) * STEP_DT
		var pos = _trajectory_position(t)
		var vel = (pos - prev_pos) / STEP_DT
		var accel = (vel - prev_vel) / STEP_DT
		var env_state: Dictionary = env.sample_state(t, pos, vel)
		var emi_channels = env_state.get("emi_channels", env_state.get("emi", Vector3.ZERO))
		var sensor_state = sensor.sample(t, pos, vel, accel, emi_channels)
		recorder.record({
			"ts": Time.get_unix_time_from_system(),
			"sim_time": t,
			"position": pos,
			"velocity": vel,
			"acceleration": accel,
			"sensor": sensor_state,
			"wind": env_state.get("wind", Vector3.ZERO),
			"emi": env_state.get("emi", Vector3.ZERO),
			"luminance": float(env_state.get("luminance", 1.0)),
			"swarm_count": 0,
		})
		prev_pos = pos
		prev_vel = vel
	recorder.stop_session()
	return {
		"ok": true,
		"csv": str(start_result.get("csv", "")),
	}

func _trajectory_position(t: float) -> Vector3:
	var x = sin(t * 0.52) * 4.2
	var y = 2.2 + sin(t * 0.19) * 0.65 + cos(t * 0.07) * 0.25
	var z = cos(t * 0.47 + 0.4) * 3.9
	return Vector3(x, y, z)

func _read_manifest(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text = f.get_as_text()
	f.close()
	var json = JSON.new()
	if json.parse(text) != OK:
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return json.data

func _read_positions(csv_path: String) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if not FileAccess.file_exists(csv_path):
		return out
	var f = FileAccess.open(csv_path, FileAccess.READ)
	if f == null:
		return out
	if not f.eof_reached():
		f.get_line()
	while not f.eof_reached():
		var line = f.get_line().strip_edges()
		if line == "":
			continue
		var p = line.split(",")
		if p.size() < 5:
			continue
		out.append(Vector3(float(p[2]), float(p[3]), float(p[4])))
	f.close()
	return out
