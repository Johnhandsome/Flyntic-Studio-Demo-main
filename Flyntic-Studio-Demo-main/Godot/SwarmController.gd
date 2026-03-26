extends RefCounted

var _container: Node3D = null
var _followers: Array[Dictionary] = []
var _formation_radius := 4.0
var _max_speed := 5.5
var _max_force := 1.2

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

func update_followers(delta: float, leader_pos: Vector3, leader_vel: Vector3, wind: Vector3):
	if _followers.is_empty():
		return
	for i in range(_followers.size()):
		var f = _followers[i]
		var n: Node3D = f.get("node")
		if not is_instance_valid(n):
			continue
		var target_angle = float(i) / float(_followers.size()) * TAU
		var target = leader_pos + Vector3(cos(target_angle), 0.8 + float(i % 3) * 0.25, sin(target_angle)) * _formation_radius
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
