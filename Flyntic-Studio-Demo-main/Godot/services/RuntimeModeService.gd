extends RefCounted

const CTRL_MODE_MANUAL_ASSIST := "manual_assist"
const CTRL_MODE_AUTO_MISSION := "auto_mission"
const CTRL_MODE_ADAPTIVE_HOVER := "adaptive_hover"
const SWARM_BEHAVIOR_LEADER_FOLLOWER := "leader_follower"
const SWARM_BEHAVIOR_AREA_SWEEP := "area_sweep"
const SWARM_BEHAVIOR_RELAY_CHAIN := "relay_chain"

var _control_modes := [
	CTRL_MODE_MANUAL_ASSIST,
	CTRL_MODE_AUTO_MISSION,
	CTRL_MODE_ADAPTIVE_HOVER,
]

var _swarm_behaviors := [
	SWARM_BEHAVIOR_LEADER_FOLLOWER,
	SWARM_BEHAVIOR_AREA_SWEEP,
	SWARM_BEHAVIOR_RELAY_CHAIN,
]

func cycle_control_mode(current: String) -> String:
	return _cycle(current, _control_modes)

func cycle_swarm_behavior(current: String) -> String:
	return _cycle(current, _swarm_behaviors)

func _cycle(current: String, values: Array) -> String:
	if values.is_empty():
		return current
	var idx = values.find(current)
	if idx < 0:
		return str(values[0])
	return str(values[(idx + 1) % values.size()])
