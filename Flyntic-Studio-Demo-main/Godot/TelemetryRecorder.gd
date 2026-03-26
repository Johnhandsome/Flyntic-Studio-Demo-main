extends RefCounted

var _dir := "user://telemetry"
var _session_id := ""
var _jsonl_path := ""
var _csv_path := ""
var _active := false

func initialize(output_dir: String):
	_dir = output_dir
	DirAccess.make_dir_recursive_absolute(_dir)

func start_session(prefix := "sim") -> Dictionary:
	if _active:
		stop_session()
	_session_id = "%s_%s" % [prefix, Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")]
	_jsonl_path = _dir + "/" + _session_id + ".jsonl"
	_csv_path = _dir + "/" + _session_id + ".csv"
	var csv = FileAccess.open(_csv_path, FileAccess.WRITE)
	if csv == null:
		return {"ok": false}
	csv.store_line("ts,sim_time,x,y,z,vx,vy,vz,ax,ay,az,wind_x,wind_y,wind_z,emi_x,emi_y,emi_z,luminance,swarm_count")
	csv.close()
	_active = true
	return {"ok": true, "session_id": _session_id, "jsonl": _jsonl_path, "csv": _csv_path}

func stop_session():
	_active = false

func is_active() -> bool:
	return _active

func record(sample: Dictionary):
	if not _active:
		return
	var jf = FileAccess.open(_jsonl_path, FileAccess.READ_WRITE)
	if jf != null:
		jf.seek_end()
		jf.store_line(JSON.stringify(sample))
		jf.close()

	var cf = FileAccess.open(_csv_path, FileAccess.READ_WRITE)
	if cf != null:
		cf.seek_end()
		var p: Vector3 = sample.get("position", Vector3.ZERO)
		var v: Vector3 = sample.get("velocity", Vector3.ZERO)
		var a: Vector3 = sample.get("acceleration", Vector3.ZERO)
		var wind: Vector3 = sample.get("wind", Vector3.ZERO)
		var emi: Vector3 = sample.get("emi", Vector3.ZERO)
		var line = "%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%d" % [
			float(sample.get("ts", 0.0)),
			float(sample.get("sim_time", 0.0)),
			p.x, p.y, p.z,
			v.x, v.y, v.z,
			a.x, a.y, a.z,
			wind.x, wind.y, wind.z,
			emi.x, emi.y, emi.z,
			float(sample.get("luminance", 0.0)),
			int(sample.get("swarm_count", 0)),
		]
		cf.store_line(line)
		cf.close()
