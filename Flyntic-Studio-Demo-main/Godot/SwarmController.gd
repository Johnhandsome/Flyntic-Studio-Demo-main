extends RefCounted

var _container: Node3D = null
var _followers: Array[Dictionary] = []
var _formation_radius := 4.0
var _max_speed := 5.5
var _max_force := 1.2

const BEHAVIOR_LEADER_FOLLOWER := "leader_follower"
const BEHAVIOR_AREA_SWEEP := "area_sweep"
const BEHAVIOR_RELAY_CHAIN := "relay_chain"

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
		n.global_position = leader_position + Vector3(cos(angle), 0.4 + float(i % 3) * 0.25, sin(angle)) * _formation_radius
		_container.add_child(n)
		_followers.append({"node": n, "vel": Vector3.ZERO})

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

func update_followers(delta: float, leader_pos: Vector3, leader_vel: Vector3, wind: Vector3, behavior := BEHAVIOR_LEADER_FOLLOWER, sim_time := 0.0):
	if _followers.is_empty():
		return
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

	match behavior:
		BEHAVIOR_AREA_SWEEP:
			var row_width = max(3, int(ceil(sqrt(_followers.size()))))
			var row = i / row_width
			var col = i % row_width
			var spacing = 1.6
			var sweep = sin(sim_time * 0.7 + float(row) * 0.6) * 1.4
			return leader_pos + Vector3((float(col) - float(row_width - 1) * 0.5) * spacing + sweep, 0.9 + float(row) * 0.2, -2.0 - float(row) * spacing)
		BEHAVIOR_RELAY_CHAIN:
			var spacing = 1.8
			var side = -1.0 if (i % 2 == 0) else 1.0
			return leader_pos + Vector3(side * 0.9, 0.8 + float(i % 3) * 0.2, float(i + 1) * spacing)
		_:
			var target_angle = float(i) / float(_followers.size()) * TAU
			return leader_pos + Vector3(cos(target_angle), 0.8 + float(i % 3) * 0.25, sin(target_angle)) * _formation_radius
