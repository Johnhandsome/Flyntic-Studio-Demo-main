extends RefCounted

var _analytics_dir: String
var _events_path: String

func _init(analytics_dir: String, events_path: String):
	_analytics_dir = analytics_dir
	_events_path = events_path

func initialize() -> int:
	var mk_err = DirAccess.make_dir_recursive_absolute(_analytics_dir)
	if mk_err != OK and mk_err != ERR_ALREADY_EXISTS:
		return mk_err
	return OK

func track_event(name: String, payload: Dictionary = {}) -> bool:
	var file = FileAccess.open(_events_path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(_events_path, FileAccess.WRITE)
	if file == null:
		return false

	file.seek_end()
	var evt = {
		"name": name,
		"ts": Time.get_unix_time_from_system(),
		"payload": payload,
	}
	file.store_line(JSON.stringify(evt))
	file.close()
	return true

func summarize_events() -> Dictionary:
	if not FileAccess.file_exists(_events_path):
		return {"ok": false, "reason": "no_file"}

	var file = FileAccess.open(_events_path, FileAccess.READ)
	if file == null:
		return {"ok": false, "reason": "open_failed"}

	var total := 0
	var counts := {}
	var first_ts := 0.0
	var last_ts := 0.0

	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line == "":
			continue
		var json = JSON.new()
		if json.parse(line) != OK:
			continue
		if typeof(json.data) != TYPE_DICTIONARY:
			continue
		var evt: Dictionary = json.data
		var name = str(evt.get("name", "unknown"))
		counts[name] = int(counts.get(name, 0)) + 1
		total += 1
		var ts = float(evt.get("ts", 0.0))
		if ts > 0.0:
			if first_ts == 0.0 or ts < first_ts:
				first_ts = ts
			if ts > last_ts:
				last_ts = ts

	file.close()
	return {
		"ok": true,
		"total": total,
		"counts": counts,
		"first_ts": first_ts,
		"last_ts": last_ts,
	}
