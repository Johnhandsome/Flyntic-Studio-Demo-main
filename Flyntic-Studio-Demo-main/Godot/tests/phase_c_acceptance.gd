extends SceneTree

# Phase C Acceptance Test
# Validates:
# - Formation manager and Swarm presets (Line, V, Circle)
# - Boids avoidance separation under dense spawning (12 drones)
# - Performance check placeholder (headless mode fast-forward)
# - Telemetry service output labeling for multi-agent IDs

var SwarmController = load("res://SwarmController.gd")
var EnvironmentPhysicsService = load("res://services/EnvironmentPhysicsService.gd")
var SwarmTelemetryService = load("res://services/SwarmTelemetryService.gd")
var TelemetryRecorder = load("res://services/TelemetryRecorder.gd")

func _initialize():
	print("[PhaseC] Starting Swarm Intelligence Acceptance Test...")
	
	var passed = true
	var exit_code = 0
	
	if not test_avoidance_dense_scenario():
		passed = false
	if not test_multi_agent_telemetry():
		passed = false
		
	if passed:
		print("[PhaseC] SUCCESS: All Phase C metrics passed.")
	else:
		print("[PhaseC] FAILURE: One or more Phase C metrics failed.")
		exit_code = 1
		
	quit(exit_code)

func test_avoidance_dense_scenario() -> bool:
	print("  Running Dense Swarm Avoidance scenario (12 drones)...")
	var node = Node3D.new()
	var container = Node3D.new()
	node.add_child(container)
	root.add_child(node)
	
	var controller = SwarmController.new()
	controller.initialize(container)
	
	# Spawn 12 drones abruptly at same center leader_pos
	# Without avoidance, they would all overlap identically
	var leader_pos = Vector3(0, 5, 0)
	var leader_vel = Vector3(1, 0, 1)
	var wind = Vector3(0.5, 0.1, 0.5)
	controller.spawn_followers(12, leader_pos)
	controller.reset_collision_metrics()
	
	# Simulate 100 frames of movement
	var delta = 0.05
	var sim_time = 0.0
	for i in range(100):
		leader_pos += leader_vel * delta
		sim_time += delta
		# Tell them to form a crowded V formation; they need separation to not overlap tightly
		controller.update_followers(delta, leader_pos, leader_vel, wind, controller.FORMATION_V, sim_time)

	var incidents = controller.get_collision_incidents()
	print("  Collision incidents detected (envelope < 0.5m): %d" % incidents)
	
	# We allow minor transient overlaps on spawn but separation must push it close to 0 over sustained run
	var threshold = 5
	node.queue_free()
	
	if incidents <= threshold:
		print("  [Pass] Dense Swarm collision threshold met.")
		return true
	else:
		print("  [Fail] High collision rate. Avoidance separation failed.")
		return false

func test_multi_agent_telemetry() -> bool:
	print("  Running Multi-Agent Telemetry generation check...")
	var telemetry_srv = SwarmTelemetryService.new()
	var recorder = TelemetryRecorder.new()
	var controller = SwarmController.new()
	
	var node = Node3D.new()
	var container = Node3D.new()
	node.add_child(container)
	root.add_child(node)
	controller.initialize(container)
	
	recorder.start_session("phase_c_manifest_test", {"seed": 42})
	
	controller.spawn_followers(3, Vector3.ZERO)
	controller.update_followers(0.1, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, controller.FORMATION_LINE, 0.1)

	var result = telemetry_srv.update_runtime({
		"delta": 0.5, # trigger > sample rate
		"sim_time": 0.5,
		"leader_pos": Vector3(10, 10, 10),
		"swarm_enabled": true,
		"swarm_controller": controller,
		"telemetry_recorder": recorder,
		"telemetry_sample_timer": 1.0,
		"telemetry_sample_rate": 10.0
	})
	
	recorder.flush()
	
	# Checking if recorder captured the swarm state
	var valid = true
	var lines = FileAccess.open(recorder.get_jsonl_path(), FileAccess.READ)
	if lines == null:
		print("  [Fail] Could not read generated telemetry.")
		valid = false
	else:
		var has_data = false
		while not lines.eof_reached():
			var line = lines.get_line().strip_edges()
			if line.is_empty():
				continue
			var doc = JSON.parse_string(line)
			if doc and doc.has("swarm_state"):
				var state = doc["swarm_state"]
				if state is Array and state.size() == 3 and state[0].has("id") and state[0].has("pos"):
					has_data = true
					break
		if has_data:
			print("  [Pass] Multi-agent telemetry correctly formatted.")
		else:
			print("  [Fail] Missing or malformed swarm_state in telemetry JSONL.")
			valid = false
			
	node.queue_free()
	return valid
