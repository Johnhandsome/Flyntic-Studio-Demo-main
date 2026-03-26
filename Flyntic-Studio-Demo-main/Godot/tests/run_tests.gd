extends SceneTree

var _failures: Array[String] = []

func _initialize():
	print("[TEST] Starting Flyntic Godot tests...")
	_run_persistence_tests()

	if _failures.is_empty():
		print("[TEST] PASS: all tests succeeded")
		quit(0)
		return

	print("[TEST] FAIL: %d test(s) failed" % _failures.size())
	for f in _failures:
		print(" - " + f)
	quit(1)

func _assert_true(name: String, cond: bool):
	if not cond:
		_failures.append(name)

func _run_persistence_tests():
	var main_script = load("res://Main.gd")
	_assert_true("Main script load", main_script != null)
	if main_script == null:
		return

	var main = main_script.new()
	_assert_true("Main instance create", main != null)
	if main == null:
		return

	var v1_payload = {
		"placed": [
			{"id": "PVC Pipe Frame", "uid": 1, "port_name": "", "parent_id": -1},
			{"id": "Unknown Part", "uid": 2, "port_name": "", "parent_id": -1},
		],
		"wiring": [
			{"from_node": "10", "from_port": 2, "to_node": "20", "to_port": 1},
		],
		"blocks": [
			{"type": "start", "children": []},
		],
	}

	var normalized_v1 = main._normalize_loaded_project(v1_payload)
	_assert_true("v1 normalize returns dictionary", typeof(normalized_v1) == TYPE_DICTIONARY)
	_assert_true("v1 normalize schema upgraded", int(normalized_v1.get("schema_version", -1)) == int(main.PROJECT_SCHEMA_VERSION))
	_assert_true("v1 normalize filters unknown components", normalized_v1.get("placed", []).size() == 1)
	_assert_true("v1 normalize preserves wiring", normalized_v1.get("wiring", []).size() == 1)
	_assert_true("v1 normalize preserves blocks", normalized_v1.get("blocks", []).size() == 1)

	var v2_payload = {
		"schema_version": int(main.PROJECT_SCHEMA_VERSION),
		"placed": [
			{"id": "PVC Pipe Frame", "uid": 11, "port_name": "", "parent_id": -1},
			{"id": "Lipo 4S 1500mAh", "uid": 12, "port_name": "battery_tray", "parent_id": 11},
		],
		"wiring": [
			{"from_node": "12", "from_port": 0, "to_node": "30", "to_port": 0},
		],
		"blocks": [
			{"type": "start", "children": [{"type": "take_off", "children": []}]},
		],
	}

	var json_str = JSON.stringify(v2_payload)
	var parsed = JSON.new()
	var parse_err = parsed.parse(json_str)
	_assert_true("v2 parse json", parse_err == OK)
	if parse_err != OK:
		return

	var normalized_v2 = main._normalize_loaded_project(parsed.data)
	_assert_true("v2 normalize keeps 2 components", normalized_v2.get("placed", []).size() == 2)
	_assert_true("v2 normalize keeps 1 wiring", normalized_v2.get("wiring", []).size() == 1)
	_assert_true("v2 normalize keeps block chain", normalized_v2.get("blocks", []).size() == 1)

	var future_payload = v2_payload.duplicate(true)
	future_payload["schema_version"] = int(main.PROJECT_SCHEMA_VERSION) + 5
	var normalized_future = main._normalize_loaded_project(future_payload)
	_assert_true("future normalize still loads", normalized_future.get("placed", []).size() == 2)
