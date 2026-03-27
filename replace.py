import os

path = 'Flyntic-Studio-Demo-main/Godot/Main.gd'

with open(path, 'r', encoding='utf-8') as f:
    text = f.read()

old_swarm = '''\t_log("Swarm behavior: " + _swarm_behavior, "info")
\t_show_toast("Swarm behavior: %s" % _swarm_behavior.capitalize().replace("_", " "), "info")
\t_track_event("swarm_behavior_changed", {"behavior": _swarm_behavior})'''

new_swarm = '''\tvar desc = ""
\tmatch _swarm_behavior:
\t\tSWARM_BEHAVIOR_LEADER_FOLLOWER: desc = "Các drone di chuyển theo sau Leader."
\t\tSWARM_BEHAVIOR_AREA_SWEEP: desc = "Dàn hàng ngang để quét khu vực."
\t\tSWARM_BEHAVIOR_RELAY_CHAIN: desc = "Nối đuôi nhau để tiếp sóng tầm xa."
\t\t_: desc = ""
\t_log("Swarm behavior: " + _swarm_behavior + " - " + desc, "info")
\t_show_toast("Swarm behavior: %s\\n%s" % [_swarm_behavior.capitalize().replace("_", " "), desc], "info")
\t_track_event("swarm_behavior_changed", {"behavior": _swarm_behavior})'''

old_flight = '''\t_log("Flight control mode: " + _flight_control_mode, "info")
\t_show_toast("Flight mode: %s" % _flight_control_mode.capitalize().replace("_", " "), "info")
\t_track_event("flight_control_mode_changed", {"mode": _flight_control_mode})'''

new_flight = '''\tvar desc = ""
\tmatch _flight_control_mode:
\t\tCTRL_MODE_MANUAL_ASSIST: desc = "Bay thủ công với hệ thống hỗ trợ cân bằng."
\t\tCTRL_MODE_AUTO_MISSION: desc = "Bay tự động theo lộ trình/nhiệm vụ đã định."
\t\tCTRL_MODE_ADAPTIVE_HOVER: desc = "Tự động giữ vị trí và thích ứng với gió/va chạm."
\t\t_: desc = ""
\t_log("Flight control mode: " + _flight_control_mode + " - " + desc, "info")
\t_show_toast("Flight mode: %s\\n%s" % [_flight_control_mode.capitalize().replace("_", " "), desc], "info")
\t_track_event("flight_control_mode_changed", {"mode": _flight_control_mode})'''

if old_swarm in text and old_flight in text:
    text = text.replace(old_swarm, new_swarm)
    text = text.replace(old_flight, new_flight)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(text)
    print("Replacements successful.")
else:
    print("Could not find the exact strings to replace")
