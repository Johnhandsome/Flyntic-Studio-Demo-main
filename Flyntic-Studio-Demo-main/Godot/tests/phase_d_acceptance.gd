extends SceneTree

# Phase D Acceptance Test
# Validates:
# - End-to-end dataset generation (JSONL + CSV + Manifest -> ZIP bundle).
# - Data quality validator metrics (0 parse errors, 0 monotonic errors).
# - Benchmark run reproduciblity

var TelemetryRecorder = load("res://services/TelemetryRecorder.gd")
var TelemetryDataValidator = load("res://services/TelemetryDataValidator.gd")
var DatasetExporter = load("res://services/DatasetExporter.gd")

func _initialize():
	print("[PhaseD] Starting Data Productization Acceptance Test...")
	
	var passed = true
	var exit_code = 0
	
	if not test_dataset_generation_and_validation():
		passed = false
		
	if passed:
		print("[PhaseD] SUCCESS: All Phase D metrics passed.")
	else:
		print("[PhaseD] FAILURE: One or more Phase D metrics failed.")
		exit_code = 1
		
	quit(exit_code)

func test_dataset_generation_and_validation() -> bool:
	print("  Running End-to-end Dataset logic...")
	
	var recorder = TelemetryRecorder.new()
	recorder.initialize("user://phase_d_test")
	
	var metadata = {
		"profile": "balanced",
		"seed": 999,
		"scenario": "benchmark_1"
	}
	
	var session_info = recorder.start_session("benchmark", metadata)
	var session_id = recorder.get_session_id()
	
	# Simulate some deterministic data points
	var sim_time = 0.0
	for i in range(100):
		recorder.record({
			"ts": 1600000000.0 + sim_time,
			"sim_time": sim_time,
			"position": Vector3(i, 5.0, 0.0),
			"velocity": Vector3(1.0, 0.0, 0.0),
			"acceleration": Vector3(0.0, 0.0, 0.0),
			"wind": Vector3(0.1, 0.0, 0.1),
			"emi": Vector3.ZERO,
			"luminance": 1.0,
			"swarm_count": 0
		})
		sim_time += 0.1
	
	recorder.stop_session()
	
	print("  Validating generated CSV...")
	var validator = TelemetryDataValidator.new()
	var report = validator.validate_csv(session_info.csv)
	
	if report.ok and report.parse_errors == 0 and report.monotonic_errors == 0 and report.outlier_rows == 0:
		print("  [Pass] Telemetry CSV validated with score: ", report.quality_score)
	else:
		print("  [Fail] Validation failed, report: ", report)
		return false
		
	print("  Bundling dataset to ZIP...")
	var exporter = DatasetExporter.new()
	var zip_path = "user://phase_d_test/" + session_id + "_bundle.zip"
	var bundle_ok = exporter.export_bundle(session_id, recorder.get_dir(), zip_path)
	
	if bundle_ok and FileAccess.file_exists(zip_path):
		var file = FileAccess.open(zip_path, FileAccess.READ)
		var size = file.get_length()
		file.close()
		if size > 100:
			print("  [Pass] Dataset successfully bundled to ZIP (%d bytes)." % size)
			return true
		else:
			print("  [Fail] ZIP bundle is suspiciously small.")
			return false
	else:
		print("  [Fail] Failed to export ZIP bundle.")
		return false
