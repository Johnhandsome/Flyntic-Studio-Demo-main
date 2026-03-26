extends RefCounted

var _rows: Array[Dictionary] = []
var _active := false
var _cursor := 0
var _manifest: Dictionary = {}

func load_csv(path: String) -> Dictionary:
	_rows.clear()
	_cursor = 0
	_manifest.clear()
	if not FileAccess.file_exists(path):
		return {"ok": false, "reason": "missing"}
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"ok": false, "reason": "open_failed"}
	if f.eof_reached():
		f.close()
		return {"ok": false, "reason": "empty"}
	# header
	f.get_line()
	while not f.eof_reached():
		var line = f.get_line().strip_edges()
		if line == "":
			continue
		var p = line.split(",")
		if p.size() < 19:
			continue
		_rows.append({
			"sim_time": float(p[1]),
			"position": Vector3(float(p[2]), float(p[3]), float(p[4])),
			"velocity": Vector3(float(p[5]), float(p[6]), float(p[7])),
			"acceleration": Vector3(float(p[8]), float(p[9]), float(p[10])),
		})
	f.close()
	if _rows.is_empty():
		return {"ok": false, "reason": "no_rows"}
	var manifest_path = path.trim_suffix(".csv") + ".manifest.json"
	_manifest = _load_manifest(manifest_path)
	return {
		"ok": true,
		"count": _rows.size(),
		"manifest": _manifest,
	}

func start():
	if _rows.is_empty():
		return
	_active = true
	_cursor = 0

func stop():
	_active = false

func is_active() -> bool:
	return _active

func sample(sim_time: float) -> Dictionary:
	if not _active or _rows.is_empty():
		return {"ok": false}
	while _cursor + 1 < _rows.size() and float(_rows[_cursor + 1].sim_time) <= sim_time:
		_cursor += 1
	if _cursor >= _rows.size() - 1:
		_active = false
		return {"ok": true, "done": true, "row": _rows[_rows.size() - 1]}
	return {"ok": true, "done": false, "row": _rows[_cursor]}

func manifest() -> Dictionary:
	return _manifest

func _load_manifest(path: String) -> Dictionary:
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
