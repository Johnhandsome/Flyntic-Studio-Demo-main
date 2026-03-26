extends Node
## PhysicsBridge — TCP client for ROS/Gazebo physics communication
## Connects to the Python bridge server and exchanges drone state

# ─── Signals ───
signal bridge_connected
signal bridge_disconnected
signal state_received(state: Dictionary)
signal imu_received(imu_data: Dictionary)
signal status_received(status: Dictionary)

# ─── Configuration ───
@export var host: String = "127.0.0.1"
@export var port: int = 9090
@export var auto_connect: bool = true
@export var reconnect_delay: float = 2.0

# ─── State ───
var connected: bool = false
var bridge_mode: String = "unknown"  # "standalone" or "ros2"
var latest_state: Dictionary = {}
var latest_imu: Dictionary = {}
var sim_time: float = 0.0

# ─── Internals ───
var _tcp: StreamPeerTCP = StreamPeerTCP.new()
var _recv_buffer: String = ""
var _reconnect_timer: float = 0.0
var _was_connected: bool = false
var _connect_attempts: int = 0
var _max_reconnect_delay: float = 10.0

func _ready():
	set_process(true)
	if auto_connect:
		connect_to_bridge()

func _process(delta: float):
	_tcp.poll()

	var status = _tcp.get_status()

	match status:
		StreamPeerTCP.STATUS_NONE:
			if _was_connected:
				_was_connected = false
				connected = false
				bridge_disconnected.emit()
				print("[PhysicsBridge] Disconnected")
			# Auto-reconnect
			if auto_connect:
				_reconnect_timer -= delta
				if _reconnect_timer <= 0:
					connect_to_bridge()

		StreamPeerTCP.STATUS_CONNECTING:
			pass  # Wait

		StreamPeerTCP.STATUS_CONNECTED:
			if not _was_connected:
				_was_connected = true
				connected = true
				_connect_attempts = 0
				bridge_connected.emit()
				print("[PhysicsBridge] Connected to %s:%d" % [host, port])
			_read_data()

		StreamPeerTCP.STATUS_ERROR:
			if _was_connected:
				_was_connected = false
				connected = false
				bridge_disconnected.emit()
				print("[PhysicsBridge] Connection error")
			_tcp = StreamPeerTCP.new()
			_reconnect_timer = min(
				reconnect_delay * pow(1.5, _connect_attempts),
				_max_reconnect_delay
			)
			_connect_attempts += 1

func connect_to_bridge():
	if _tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		return
	_tcp = StreamPeerTCP.new()
	var err = _tcp.connect_to_host(host, port)
	if err != OK:
		_reconnect_timer = reconnect_delay
		print("[PhysicsBridge] Connect failed (err=%d), retry in %.1fs" % [err, _reconnect_timer])

func disconnect_from_bridge():
	auto_connect = false
	_tcp.disconnect_from_host()
	connected = false
	_was_connected = false

# ─── Send Commands ───

func send_command(cmd: Dictionary):
	"""Send a JSON command to the bridge."""
	if not connected:
		return
	var json_str = JSON.stringify(cmd) + "\n"
	_tcp.put_data(json_str.to_utf8_buffer())

func cmd_arm():
	send_command({"cmd": "arm"})

func cmd_disarm():
	send_command({"cmd": "disarm"})

func cmd_takeoff(altitude: float = 2.5):
	send_command({"cmd": "takeoff", "altitude": altitude})

func cmd_land():
	send_command({"cmd": "land"})

func cmd_move(vx: float, vy: float = 0.0, vz: float = 0.0):
	send_command({"cmd": "move", "vx": vx, "vy": vy, "vz": vz})

func cmd_hover():
	send_command({"cmd": "hover"})

func cmd_stop():
	send_command({"cmd": "stop"})

func cmd_set_drone(mass: float, motor_count: int, max_thrust: float):
	send_command({
		"cmd": "set_drone",
		"mass": mass,
		"motor_count": motor_count,
		"max_thrust": max_thrust,
	})

func cmd_ping():
	send_command({"cmd": "ping"})

# ─── Receive Data ───

func _read_data():
	var available = _tcp.get_available_bytes()
	if available <= 0:
		return

	var result = _tcp.get_data(available)
	if result[0] != OK:
		return

	var raw = result[1] as PackedByteArray
	_recv_buffer += raw.get_string_from_utf8()

	# Process complete lines
	while "\n" in _recv_buffer:
		var idx = _recv_buffer.find("\n")
		var line = _recv_buffer.substr(0, idx).strip_edges()
		_recv_buffer = _recv_buffer.substr(idx + 1)

		if line.length() > 0:
			_parse_message(line)

func _parse_message(raw: String):
	var json = JSON.new()
	var err = json.parse(raw)
	if err != OK:
		return

	var data: Dictionary = json.data
	var msg_type = data.get("type", "")

	match msg_type:
		"state":
			latest_state = data
			sim_time = data.get("sim_time", 0.0)
			state_received.emit(data)

		"imu":
			latest_imu = data
			imu_received.emit(data)

		"status":
			bridge_mode = data.get("mode", "unknown")
			status_received.emit(data)

		"pong":
			var rtt = Time.get_unix_time_from_system() - data.get("time", 0.0)
			print("[PhysicsBridge] Pong — RTT: %.1fms" % (rtt * 1000.0))

		"error":
			push_warning("[PhysicsBridge] Server error: " + data.get("msg", ""))

# ─── Utility ───

func get_position() -> Vector3:
	"""Get latest drone position in Godot coordinates."""
	var pos = latest_state.get("pos", [0, 0, 0])
	return Vector3(pos[0], pos[1], pos[2])

func get_quaternion() -> Quaternion:
	"""Get latest drone rotation as Godot Quaternion."""
	var rot = latest_state.get("rot", [0, 0, 0, 1])
	return Quaternion(rot[0], rot[1], rot[2], rot[3])

func get_velocity() -> Vector3:
	"""Get latest drone velocity."""
	var vel = latest_state.get("vel", [0, 0, 0])
	return Vector3(vel[0], vel[1], vel[2])

func get_motor_rpms() -> Array:
	"""Get motor RPMs array."""
	return latest_state.get("motors", [0, 0, 0, 0])

func is_armed() -> bool:
	return latest_state.get("armed", false)

func get_status_text() -> String:
	return latest_state.get("status", "idle")
