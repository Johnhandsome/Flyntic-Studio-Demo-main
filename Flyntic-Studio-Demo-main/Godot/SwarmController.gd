extends RefCounted

var _container: Node3D = null
var _followers: Array[Dictionary] = []
var _formation_radius := 9.0
var _max_speed := 5.5
var _max_force := 1.2

const BEHAVIOR_LEADER_FOLLOWER := "leader_follower" # Same as circle
const BEHAVIOR_AREA_SWEEP := "area_sweep"
const BEHAVIOR_RELAY_CHAIN := "relay_chain"
const FORMATION_V := "formation_v"
const FORMATION_LINE := "formation_line"
const FORMATION_CUSTOM := "formation_custom"

var _separation_radius := 4.5
var _separation_weight := 2.5
var _collision_incidents := 0

func initialize(container: Node3D):
	_container = container

func spawn_followers(count: int, leader_position: Vector3):
	clear_followers()
	if _container == null:
		return
	for i in range(max(count, 0)):
		var n = Node3D.new()
		n.name = "SwarmFollower_%d" % i
		
		var body = MeshInstance3D.new()
		var mesh_res = load("res://Components/quad_pvc_frame.obj")
		if mesh_res != null:
			body.mesh = mesh_res
			body.scale = Vector3(0.01, 0.01, 0.01) # scale to match Main drone
		else:
			var m = SphereMesh.new()
			m.radius = 0.18
			m.height = 0.36
			body.mesh = m
		
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.9, 0.9, 0.85)
		mat.emission_enabled = true
		mat.emission = Color(0.1, 0.6, 0.8)
		mat.emission_energy_multiplier = 1.2
		body.material_override = mat
		n.add_child(body)
		
		var angle = float(i) / float(max(count, 1)) * TAU
		_container.add_child(n)
		n.global_position = leader_position + Vector3(cos(angle), 0.4 + float(i % 3) * 0.25, sin(angle)) * _formation_radius
		_followers.append({"id": "swarm_%d" % i, "node": n, "vel": Vector3.ZERO, "custom_offset": Vector3.ZERO})

func set_highlight(idx: int):
	for i in range(_followers.size()):
		var n = _followers[i].get("node")
		if is_instance_valid(n) and n.get_child_count() > 0:
			var body = n.get_child(0)
			if body is MeshInstance3D and body.material_override != null:
				var mat = body.material_override
				if i == idx:
					mat.emission = Color(0.9, 0.8, 0.2)
					mat.albedo_color = Color(0.9, 0.8, 0.2, 0.95)
				else:
					mat.emission = Color(0.1, 0.6, 0.8)
					mat.albedo_color = Color(0.2, 0.9, 0.9, 0.85)

func clear_followers():
	for f in _followers:
		var n = f.get("node")
		if is_instance_valid(n):
			n.queue_free()
	_followers.clear()

func is_active() -> bool:
	return _followers.size() > 0

func follower_count() -> int:
	return _followers.size()

func get_collision_incidents() -> int:
	return _collision_incidents

func reset_collision_metrics():
	_collision_incidents = 0

func get_followers_state() -> Array:
	var state = []
	for i in range(_followers.size()):
		var n: Node3D = _followers[i].get("node")
		if is_instance_valid(n):
			state.append({
				"id": _followers[i].get("id"),
				"pos": n.global_position,
				"vel": _followers[i].get("vel")
			})
	return state

func set_custom_offset(idx: int, offset: Vector3):
	if idx >= 0 and idx < _followers.size():
		_followers[idx]["custom_offset"] = offset

func update_followers(delta: float, leader_pos: Vector3, leader_vel: Vector3, wind: Vector3, behavior := BEHAVIOR_LEADER_FOLLOWER, sim_time := 0.0):
	if _followers.is_empty():
		return
		
	# Precompute positions for separation
	var all_positions = []
	for f in _followers:
		var n = f.get("node")
		if is_instance_valid(n):
			all_positions.append(n.global_position)
		else:
			all_positions.append(Vector3.ZERO)
			
	for i in range(_followers.size()):
		var f = _followers[i]
		var n: Node3D = f.get("node")
		if not is_instance_valid(n):
			continue
			
		var target = _target_for_behavior(i, leader_pos, behavior, sim_time)
		var desired = (target - n.global_position)
		if desired.length() > 0.01:
			desired = desired.normalized() * _max_speed
			
		var vel: Vector3 = f.get("vel", Vector3.ZERO)
		var steer = (desired - vel).limit_length(_max_force)
		
		# Avoidance (Separation)
		var separation: Vector3 = Vector3.ZERO
		var close_count = 0
		for j in range(all_positions.size()):
			if i != j:
				var dist = n.global_position.distance_to(all_positions[j])
				if dist < 0.5: # Hard collision envelope tracking
					_collision_incidents += 1
				if dist > 0 and dist < _separation_radius:
					var diff = (n.global_position - all_positions[j]).normalized()
					separation += (diff / dist)
					close_count += 1
		if close_count > 0:
			separation = (separation / close_count).normalized() * _max_speed
			var sep_steer = (separation - vel).limit_length(_max_force)
			steer += sep_steer * _separation_weight
		
		# Disturbance & Leader correlation
		steer += wind * 0.18
		steer += leader_vel * 0.08
		
		vel = (vel + steer * delta).limit_length(_max_speed)
		n.global_position += vel * delta
		if vel.length() > 0.01:
			n.look_at(n.global_position + vel.normalized(), Vector3.UP)
		_followers[i]["vel"] = vel

func _target_for_behavior(i: int, leader_pos: Vector3, behavior: String, sim_time: float) -> Vector3:
	if _followers.is_empty():
		return leader_pos

	var spacing = 4.5
	match behavior:
		BEHAVIOR_AREA_SWEEP:
			var row_width = max(3, int(ceil(sqrt(_followers.size()))))
			var row = i / row_width
			var col = i % row_width
			var sweep = sin(sim_time * 0.7 + float(row) * 0.6) * 1.4
			return leader_pos + Vector3((float(col) - float(row_width - 1) * 0.5) * spacing + sweep, 0.9 + float(row) * 0.2, -2.0 - float(row) * spacing)
		BEHAVIOR_RELAY_CHAIN:
			var side = -1.0 if (i % 2 == 0) else 1.0
			return leader_pos + Vector3(side * 0.9, 0.8 + float(i % 3) * 0.2, float(i + 1) * 4.0)
		FORMATION_V:
			var depth = int((i + 1) / 2)
			var side = -1.0 if (i % 2 == 0) else 1.0
			if i == 0:
				side = 0.0
				depth = 0
			return leader_pos + Vector3(side * depth * spacing, 0.5 + depth * 0.2, -depth * spacing)
		FORMATION_LINE:
			var col = i - (_followers.size() / 2)
			return leader_pos + Vector3(float(col) * spacing, 0.5, -2.0)
		FORMATION_CUSTOM:
			var offset: Vector3 = _followers[i].get("custom_offset", Vector3.ZERO)
			return leader_pos + offset
		_: # Default / Circle (LEADER_FOLLOWER)
			var target_angle = float(i) / float(_followers.size()) * TAU
			return leader_pos + Vector3(cos(target_angle), 0.8 + float(i % 3) * 0.25, sin(target_angle)) * _formation_radius
