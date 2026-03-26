extends RefCounted

var _rows: Array[Dictionary] = []
var _active := false
var _cursor := 0

func load_csv(path: String) -> Dictionary:
	_rows.clear()
	_cursor = 0
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
	return {"ok": true, "count": _rows.size()}

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
