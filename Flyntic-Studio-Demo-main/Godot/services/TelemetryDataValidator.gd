extends RefCounted

func validate_csv(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "reason": "missing"}

	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"ok": false, "reason": "open_failed"}

	var header = ""
	if not f.eof_reached():
		header = f.get_line().strip_edges()
	if header == "":
		f.close()
		return {"ok": false, "reason": "empty"}

	var rows := 0
	var parse_errors := 0
	var monotonic_errors := 0
	var outlier_rows := 0
	var prev_sim_time := -1.0

	while not f.eof_reached():
		var line = f.get_line().strip_edges()
		if line == "":
			continue
		var p = line.split(",")
		if p.size() < 19:
			parse_errors += 1
			continue

		var sim_time = float(p[1])
		var vx = float(p[5])
		var vy = float(p[6])
		var vz = float(p[7])
		if is_nan(sim_time) or is_nan(vx) or is_nan(vy) or is_nan(vz):
			parse_errors += 1
			continue

		if prev_sim_time >= 0.0 and sim_time < prev_sim_time:
			monotonic_errors += 1
		prev_sim_time = sim_time

		# Lightweight outlier heuristic for low-hardware simulation profiles.
		if abs(vx) > 80.0 or abs(vy) > 80.0 or abs(vz) > 80.0:
			outlier_rows += 1

		rows += 1

	f.close()

	return {
		"ok": true,
		"rows": rows,
		"parse_errors": parse_errors,
		"monotonic_errors": monotonic_errors,
		"outlier_rows": outlier_rows,
		"quality_score": _quality_score(rows, parse_errors, monotonic_errors, outlier_rows),
	}

func _quality_score(rows: int, parse_errors: int, monotonic_errors: int, outlier_rows: int) -> float:
	if rows <= 0:
		return 0.0
	var penalty = float(parse_errors * 4 + monotonic_errors * 6 + outlier_rows)
	var score = 100.0 - (penalty * 100.0 / float(rows))
	return clamp(score, 0.0, 100.0)
