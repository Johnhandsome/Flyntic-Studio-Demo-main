extends Control
## Flyntic Studio — Godot Drone Assembly & Simulation
## Ported from web demo (Three.js) with full physics preview

# ──────────────────────────── NODE REFS ────────────────────────────
# These paths EXACTLY match Main.tscn node tree

# Left sidebar
@onready var comp_list: ItemList = $Root/Content/Left/CompPanel/V/CompList
@onready var hier_tree: Tree   = $Root/Content/Left/HierarchyPanel/V/Tree
@onready var hier_del_btn: Button = $Root/Content/Left/HierarchyPanel/V/H/DelBtn

# 3D scene nodes
@onready var scene_root: Node3D     = $Root/Content/CenterRight/Center/Tabs/Canvas/VPC/VP/Scene
@onready var pivot: Node3D           = $Root/Content/CenterRight/Center/Tabs/Canvas/VPC/VP/Scene/Pivot
@onready var camera: Camera3D        = $Root/Content/CenterRight/Center/Tabs/Canvas/VPC/VP/Scene/Pivot/Camera
@onready var components_group: Node3D = $Root/Content/CenterRight/Center/Tabs/Canvas/VPC/VP/Scene/Components
@onready var snap_hints: Node3D      = $Root/Content/CenterRight/Center/Tabs/Canvas/VPC/VP/Scene/SnapHints
@onready var wires_group: Node3D     = $Root/Content/CenterRight/Center/Tabs/Canvas/VPC/VP/Scene/Components/Wires
@onready var viewport: SubViewport   = $Root/Content/CenterRight/Center/Tabs/Canvas/VPC/VP

# Console & monitors
@onready var log_box: RichTextLabel = $Root/Content/CenterRight/Center/Console/V/Log
@onready var weight_val: Label = $Root/Content/CenterRight/Right/Scroll/V/Perf/Weight/Val
@onready var thrust_val: Label = $Root/Content/CenterRight/Right/Scroll/V/Perf/Thrust/Val
@onready var twr_val: Label    = $Root/Content/CenterRight/Right/Scroll/V/Perf/TWR/Val
@onready var cap_val: Label    = $Root/Content/CenterRight/Right/Scroll/V/Perf/Capability/Val
@onready var bat_val: Label    = $Root/Content/CenterRight/Right/Scroll/V/Power/Battery/Val
@onready var ft_val: Label     = $Root/Content/CenterRight/Right/Scroll/V/Power/FlightTime/Val
@onready var diag_text: RichTextLabel = $Root/Content/CenterRight/Right/Scroll/V/Diag/DiagText
@onready var comp_count: Label = $Root/StatusBar/H/Comp
@onready var tabs: TabContainer = $Root/Content/CenterRight/Center/Tabs
@onready var console_panel: Panel = $Root/Content/CenterRight/Center/Console
@onready var topbar_menus: HBoxContainer = $Root/TopBar/H/Menus
@onready var vpc: SubViewportContainer = $Root/Content/CenterRight/Center/Tabs/Canvas/VPC
@onready var content_split: HSplitContainer = $Root/Content
@onready var left_panel: VBoxContainer = $Root/Content/Left
@onready var center_right_split: HSplitContainer = $Root/Content/CenterRight
@onready var right_panel: Panel = $Root/Content/CenterRight/Right
@onready var right_scroll: ScrollContainer = $Root/Content/CenterRight/Right/Scroll

# Blocks UI
@onready var workspace: Panel = $Root/Content/CenterRight/Center/Tabs/Blocks/MainH/Workspace
@onready var toolbox: Panel = $Root/Content/CenterRight/Center/Tabs/Blocks/MainH/Toolbox
@onready var toolbox_v: VBoxContainer = $Root/Content/CenterRight/Center/Tabs/Blocks/MainH/Toolbox/V
@onready var blocks_sidebar: Panel = $Root/Content/CenterRight/Center/Tabs/Blocks/MainH/Sidebar
@onready var block_script = preload("res://Block.gd")

# Simulation buttons
@onready var play_btn: Button  = $Root/Content/CenterRight/Right/Scroll/V/SimPanel/PlayBtn
@onready var pause_btn: Button = $Root/Content/CenterRight/Right/Scroll/V/SimPanel/PauseBtn
@onready var stop_btn: Button  = $Root/Content/CenterRight/Right/Scroll/V/SimPanel/StopBtn
@onready var sim_label: Label  = $Root/Content/CenterRight/Right/Scroll/V/SimPanel/StatusLbl
@onready var topbar_status: Label = $Root/TopBar/H/Status

# Wiring screen (created dynamically)
var wiring_canvas: Control = null
var wiring_graph: GraphEdit = null
var wiring_connections: Array[Dictionary] = []  # {from_node, from_port, to_node, to_port}

# Scale factors for components
const OBJ_SCALE := 0.01 # convert mm to Godot units
const MAX_LOG_LINES := 200 # Console log auto-trim threshold

# Physics bridge
var bridge: Node = null
var bridge_connected := false
var use_bridge_physics := true  # Set false to force kinematic fallback

var CATEGORIES := {
	"FRAME": [
		"PVC Pipe Frame",
		"Carbon Fiber Body",
		"X8 Carbon Frame",
		"Mini 3-inch Frame",
	],
	"MOTOR": [
		"Motor 2205 2300KV",
		"Motor 2207 2400KV",
		"Motor 2212 920KV",
		"Motor 2806.5 1300KV",
		"Motor 1507 3800KV",
	],
	"PROPELLER": ["Propeller 5045", "Propeller 6045", "Propeller 7035", "Propeller 3028"],
	"BATTERY": ["Lipo 4S 1500mAh", "Lipo 6S 1300mAh", "Lipo 4S 2200mAh", "Li-Ion 4S 3000mAh"],
	"ELECTRONICS": [
		"Power Distribution Board",
		"F4 Flight Controller",
		"F7 Flight Controller",
		"4-in-1 ESC",
		"BLHeli_32 ESC 45A",
		"Matek PDB XT60",
		"Current Sensor Module",
		"Buzzer + LED Module",
		"Capacitor 1000uF",
		"5V BEC Module",
		"ELRS Receiver",
	],
	"NAV / FPV": [
		"GPS + Compass Module",
		"GPS M10 Module",
		"FPV Camera",
		"Digital FPV Camera",
		"5.8GHz VTX",
		"915MHz Telemetry Radio",
		"Rangefinder ToF",
	],
}

var COMPONENTS := {
	"PVC Pipe Frame": {
		"type": "Frame", "weight": 250, "thrust": 0, "capacity": 0,
		"color": Color(0.9, 0.9, 0.85),
		"use_obj": true, "obj_path": "res://Components/quad_pvc_frame.obj",
		"ports": [
			{"name": "fl", "pos": Vector3(2.28, 2.01, 2.28), "slot": true, "allowed": ["Motor"]},
			{"name": "fr", "pos": Vector3(2.28, 2.01, -2.28), "slot": true, "allowed": ["Motor"]},
			{"name": "bl", "pos": Vector3(-2.28, 2.01, 2.28), "slot": true, "allowed": ["Motor"]},
			{"name": "br", "pos": Vector3(-2.28, 2.01, -2.28), "slot": true, "allowed": ["Motor"]},
			{"name": "stack_top", "pos": Vector3(0, 1.72, 0), "slot": true, "allowed": ["FC", "PDB", "ESC"]},
			{"name": "stack_mid", "pos": Vector3(0, 1.58, 0), "slot": true, "allowed": ["FC", "PDB", "ESC", "RX", "BEC"]},
			{"name": "stack_low", "pos": Vector3(0, 1.44, 0), "slot": true, "allowed": ["FC", "PDB", "ESC", "RX", "BEC"]},
			{"name": "battery_tray", "pos": Vector3(0, 0.52, 0), "slot": true, "allowed": ["Battery", "PDB", "BEC"]},
			{"name": "rx_side", "pos": Vector3(-0.85, 1.55, 0.35), "slot": true, "allowed": ["RX", "BEC"]},
			{"name": "gps_mast", "pos": Vector3(0, 1.98, 0), "slot": true, "allowed": ["GPS"]},
			{"name": "cam_front", "pos": Vector3(0, 1.42, -1.35), "slot": true, "allowed": ["Camera"]},
			{"name": "vtx_rear", "pos": Vector3(0, 1.42, 1.35), "slot": true, "allowed": ["VTX"]},
		]
	},
	"Carbon Fiber Body": {
		"type": "Frame", "weight": 180, "thrust": 0, "capacity": 0,
		"color": Color(0.4, 0.4, 0.42),
		"use_obj": false,
		"ports": [
			{"name": "fl", "pos": Vector3(2, 1.5, 2), "slot": true, "allowed": ["Motor"]},
			{"name": "fr", "pos": Vector3(2, 1.5, -2), "slot": true, "allowed": ["Motor"]},
			{"name": "bl", "pos": Vector3(-2, 1.5, 2), "slot": true, "allowed": ["Motor"]},
			{"name": "br", "pos": Vector3(-2, 1.5, -2), "slot": true, "allowed": ["Motor"]},
			{"name": "stack_top", "pos": Vector3(0, 1.12, 0), "slot": true, "allowed": ["FC", "ESC", "PDB"]},
			{"name": "stack_mid", "pos": Vector3(0, 0.98, 0), "slot": true, "allowed": ["FC", "ESC", "PDB", "RX", "BEC"]},
			{"name": "battery_tray", "pos": Vector3(0, 0.62, 0), "slot": true, "allowed": ["Battery", "PDB", "BEC"]},
			{"name": "gps_mast", "pos": Vector3(0, 1.28, 0), "slot": true, "allowed": ["GPS"]},
			{"name": "cam_front", "pos": Vector3(0, 1.0, -1.2), "slot": true, "allowed": ["Camera"]},
			{"name": "vtx_rear", "pos": Vector3(0, 1.0, 1.2), "slot": true, "allowed": ["VTX"]},
		]
	},
	"X8 Carbon Frame": {
		"type": "Frame", "weight": 330, "thrust": 0, "capacity": 0,
		"color": Color(0.34, 0.34, 0.38),
		"use_obj": false,
		"ports": [
			{"name": "fl", "pos": Vector3(2.5, 1.7, 2.5), "slot": true, "allowed": ["Motor"]},
			{"name": "fr", "pos": Vector3(2.5, 1.7, -2.5), "slot": true, "allowed": ["Motor"]},
			{"name": "bl", "pos": Vector3(-2.5, 1.7, 2.5), "slot": true, "allowed": ["Motor"]},
			{"name": "br", "pos": Vector3(-2.5, 1.7, -2.5), "slot": true, "allowed": ["Motor"]},
			{"name": "stack_top", "pos": Vector3(0, 1.22, 0), "slot": true, "allowed": ["FC", "ESC", "PDB"]},
			{"name": "stack_mid", "pos": Vector3(0, 1.04, 0), "slot": true, "allowed": ["FC", "ESC", "PDB", "RX", "BEC"]},
			{"name": "battery_tray", "pos": Vector3(0, 0.62, 0), "slot": true, "allowed": ["Battery", "PDB", "BEC"]},
			{"name": "gps_mast", "pos": Vector3(0, 1.45, 0), "slot": true, "allowed": ["GPS"]},
			{"name": "cam_front", "pos": Vector3(0, 1.05, -1.45), "slot": true, "allowed": ["Camera"]},
			{"name": "vtx_rear", "pos": Vector3(0, 1.05, 1.45), "slot": true, "allowed": ["VTX"]},
		]
	},
	"Mini 3-inch Frame": {
		"type": "Frame", "weight": 120, "thrust": 0, "capacity": 0,
		"color": Color(0.46, 0.46, 0.5),
		"use_obj": false,
		"ports": [
			{"name": "fl", "pos": Vector3(1.5, 1.1, 1.5), "slot": true, "allowed": ["Motor"]},
			{"name": "fr", "pos": Vector3(1.5, 1.1, -1.5), "slot": true, "allowed": ["Motor"]},
			{"name": "bl", "pos": Vector3(-1.5, 1.1, 1.5), "slot": true, "allowed": ["Motor"]},
			{"name": "br", "pos": Vector3(-1.5, 1.1, -1.5), "slot": true, "allowed": ["Motor"]},
			{"name": "stack_top", "pos": Vector3(0, 0.86, 0), "slot": true, "allowed": ["FC", "ESC", "PDB"]},
			{"name": "stack_mid", "pos": Vector3(0, 0.74, 0), "slot": true, "allowed": ["FC", "ESC", "PDB", "RX", "BEC"]},
			{"name": "battery_tray", "pos": Vector3(0, 0.45, 0), "slot": true, "allowed": ["Battery", "PDB", "BEC"]},
			{"name": "gps_mast", "pos": Vector3(0, 1.08, 0), "slot": true, "allowed": ["GPS"]},
			{"name": "cam_front", "pos": Vector3(0, 0.82, -1.0), "slot": true, "allowed": ["Camera"]},
			{"name": "vtx_rear", "pos": Vector3(0, 0.82, 1.0), "slot": true, "allowed": ["VTX"]},
		]
	},
	"Motor 2205 2300KV": {
		"type": "Motor", "weight": 35, "thrust": 850, "capacity": 0,
		"color": Color(0.6, 0.25, 0.25),
		"ports": [{"name": "prop", "pos": Vector3(0, 0.5, 0), "slot": true, "allowed": ["Propeller"]}]
	},
	"Motor 2207 2400KV": {
		"type": "Motor", "weight": 42, "thrust": 1100, "capacity": 0,
		"color": Color(0.25, 0.45, 0.8),
		"ports": [{"name": "prop", "pos": Vector3(0, 0.5, 0), "slot": true, "allowed": ["Propeller"]}]
	},
	"Motor 2212 920KV": {
		"type": "Motor", "weight": 56, "thrust": 980, "capacity": 0,
		"color": Color(0.8, 0.55, 0.1),
		"ports": [{"name": "prop", "pos": Vector3(0, 0.5, 0), "slot": true, "allowed": ["Propeller"]}]
	},
	"Motor 2806.5 1300KV": {
		"type": "Motor", "weight": 69, "thrust": 1450, "capacity": 0,
		"color": Color(0.76, 0.3, 0.22),
		"ports": [{"name": "prop", "pos": Vector3(0, 0.5, 0), "slot": true, "allowed": ["Propeller"]}]
	},
	"Motor 1507 3800KV": {
		"type": "Motor", "weight": 24, "thrust": 620, "capacity": 0,
		"color": Color(0.32, 0.68, 0.9),
		"ports": [{"name": "prop", "pos": Vector3(0, 0.5, 0), "slot": true, "allowed": ["Propeller"]}]
	},
	"Propeller 5045": {
		"type": "Propeller", "weight": 8, "thrust": 0, "capacity": 0,
		"color": Color(0.8, 0.1, 0.1), "ports": []
	},
	"Propeller 6045": {
		"type": "Propeller", "weight": 12, "thrust": 0, "capacity": 0,
		"color": Color(0.1, 0.1, 0.8), "ports": []
	},
	"Propeller 7035": {
		"type": "Propeller", "weight": 15, "thrust": 0, "capacity": 0,
		"color": Color(0.95, 0.48, 0.15), "ports": []
	},
	"Propeller 3028": {
		"type": "Propeller", "weight": 5, "thrust": 0, "capacity": 0,
		"color": Color(0.25, 0.75, 0.45), "ports": []
	},
	"Lipo 4S 1500mAh": {
		"type": "Battery", "weight": 185, "thrust": 0, "capacity": 1500,
		"color": Color(0.85, 0.7, 0.15), "ports": []
	},
	"Lipo 6S 1300mAh": {
		"type": "Battery", "weight": 215, "thrust": 0, "capacity": 1300,
		"color": Color(0.9, 0.66, 0.12), "ports": []
	},
	"Lipo 4S 2200mAh": {
		"type": "Battery", "weight": 248, "thrust": 0, "capacity": 2200,
		"color": Color(0.88, 0.72, 0.2), "ports": []
	},
	"Li-Ion 4S 3000mAh": {
		"type": "Battery", "weight": 280, "thrust": 0, "capacity": 3000,
		"color": Color(0.7, 0.72, 0.45), "ports": []
	},
	"5V BEC Module": {
		"type": "BEC", "weight": 12, "thrust": 0, "capacity": 0,
		"color": Color(0.2, 0.6, 0.6), "ports": []
	},
	"Power Distribution Board": {
		"type": "PDB", "weight": 20, "thrust": 0, "capacity": 0,
		"color": Color(0.25, 0.25, 0.3), "ports": []
	},
	"F4 Flight Controller": {
		"type": "FC", "weight": 7, "thrust": 0, "capacity": 0,
		"color": Color(0.0, 0.35, 0.0), "ports": []
	},
	"F7 Flight Controller": {
		"type": "FC", "weight": 9, "thrust": 0, "capacity": 0,
		"color": Color(0.12, 0.5, 0.12), "ports": []
	},
	"4-in-1 ESC": {
		"type": "ESC", "weight": 15, "thrust": 0, "capacity": 0,
		"color": Color(0.0, 0.0, 0.5), "ports": []
	},
	"BLHeli_32 ESC 45A": {
		"type": "ESC", "weight": 18, "thrust": 0, "capacity": 0,
		"color": Color(0.05, 0.15, 0.58), "ports": []
	},
	"Matek PDB XT60": {
		"type": "PDB", "weight": 24, "thrust": 0, "capacity": 0,
		"color": Color(0.32, 0.32, 0.36), "ports": []
	},
	"Current Sensor Module": {
		"type": "PDB", "weight": 8, "thrust": 0, "capacity": 0,
		"color": Color(0.42, 0.42, 0.48), "ports": []
	},
	"Buzzer + LED Module": {
		"type": "BEC", "weight": 6, "thrust": 0, "capacity": 0,
		"color": Color(0.85, 0.45, 0.2), "ports": []
	},
	"Capacitor 1000uF": {
		"type": "BEC", "weight": 5, "thrust": 0, "capacity": 0,
		"color": Color(0.45, 0.75, 0.75), "ports": []
	},
	"ELRS Receiver": {
		"type": "RX", "weight": 4, "thrust": 0, "capacity": 0,
		"color": Color(0.55, 0.2, 0.7), "ports": []
	},
	"GPS + Compass Module": {
		"type": "GPS", "weight": 18, "thrust": 0, "capacity": 0,
		"color": Color(0.2, 0.45, 0.75), "ports": []
	},
	"GPS M10 Module": {
		"type": "GPS", "weight": 14, "thrust": 0, "capacity": 0,
		"color": Color(0.18, 0.52, 0.8), "ports": []
	},
	"FPV Camera": {
		"type": "Camera", "weight": 10, "thrust": 0, "capacity": 0,
		"color": Color(0.4, 0.4, 0.45), "ports": []
	},
	"Digital FPV Camera": {
		"type": "Camera", "weight": 18, "thrust": 0, "capacity": 0,
		"color": Color(0.52, 0.52, 0.56), "ports": []
	},
	"5.8GHz VTX": {
		"type": "VTX", "weight": 15, "thrust": 0, "capacity": 0,
		"color": Color(0.75, 0.3, 0.2), "ports": []
	},
	"915MHz Telemetry Radio": {
		"type": "RX", "weight": 11, "thrust": 0, "capacity": 0,
		"color": Color(0.58, 0.28, 0.82), "ports": []
	},
	"Rangefinder ToF": {
		"type": "GPS", "weight": 9, "thrust": 0, "capacity": 0,
		"color": Color(0.2, 0.62, 0.86), "ports": []
	},
}

# Runtime state
var placed: Array[Dictionary] = []
var ghost: Node3D = null
var _uid_counter := 0  # Monotonic UID counter (avoids tick collision)
var cur_id := ""
var _cam_yaw_vel := 0.0
var _cam_pitch_vel := 0.0
var ghost_rot := 0.0
var orbiting := false
var panning := false
var zoom := 12.0
var camera_rot := Vector2(-0.5, 0.0) # Vertical (X) and Horizontal (Y) rotation
var sim_state := "stopped" # stopped | playing | paused
var sim_time := 0.0
var sim_sequence: Array[Dictionary] = []
var sim_step_idx := 0
var sim_step_timer := 0.0
var sim_target_pos := Vector3.ZERO
var sim_target_rot := Vector3.ZERO
var trash_panel: Panel = null
var _wire_mat: StandardMaterial3D = null  # Cached wire material
var _snap_hint_mat: StandardMaterial3D = null  # Cached snap hint material
var dragging_comp_uid := -1  # 3D drag-reposition
var dragging_comp_offset := Vector3.ZERO
var _moving_component_uid := -1
var _moving_component_snapshot: Dictionary = {}
var _toolbox_drag_active := false
var _toolbox_drag_moved := false
var _toolbox_drag_start_mouse := Vector2.ZERO
var _toolbox_drag_payload: Dictionary = {}
var _toolbox_drag_block: Panel = null
var _active_block_category := "events"
var _variables_placeholder: Label = null
var _comp_category_collapsed: Dictionary = {}
const TOOLBOX_DRAG_THRESHOLD := 8.0

# Undo/Redo
var _undo_stack: Array[Dictionary] = []  # {action, data}
var _redo_stack: Array[Dictionary] = []
const MAX_UNDO := 50

# Properties panel refs (created dynamically)
var props_panel: Panel = null
var props_name_lbl: Label = null
var props_type_lbl: Label = null
var props_weight_lbl: Label = null
var props_thrust_lbl: Label = null
var props_pos_lbl: Label = null
var _selected_uid := -1

# Onboarding UI refs/state
var _onboarding_seen := false
var _onboarding_active := false
var _onboarding_step_idx := 0
var _onboarding_steps: Array[Dictionary] = []
var _onboarding_overlay: Control = null
var _onboarding_focus_ring: Panel = null
var _onboarding_card: PanelContainer = null
var _onboarding_step_title: Label = null
var _onboarding_step_body: RichTextLabel = null
var _onboarding_progress_lbl: Label = null
var _onboarding_prev_btn: Button = null
var _onboarding_next_btn: Button = null
var _onboarding_skip_btn: Button = null

# Port compatibility rules for wiring validation
const WIRING_RULES := {
	"FC": ["ESC", "Battery", "PDB", "BEC", "RX", "GPS", "VTX"],
	"ESC": ["Motor", "FC", "Battery", "PDB"],
	"Motor": ["ESC"],
	"Battery": ["FC", "ESC", "PDB", "BEC"],
	"PDB": ["Battery", "ESC", "FC", "RX", "GPS", "Camera", "VTX", "BEC"],
	"BEC": ["Battery", "PDB", "FC", "RX", "GPS", "Camera", "VTX"],
	"RX": ["FC", "PDB", "BEC"],
	"GPS": ["FC", "PDB", "BEC"],
	"Camera": ["VTX", "PDB", "BEC"],
	"VTX": ["Camera", "FC", "PDB", "BEC"],
	"Propeller": ["Motor"],
	"Frame": [],
}

const COMPONENT_TYPE_FRAME := "Frame"
const COMPONENT_TYPE_FC := "FC"
const PROJECT_SCHEMA_VERSION := 2
const AUTOSAVE_INTERVAL_SEC := 20.0
const AUTOSAVE_DIR := "user://autosave"
const AUTOSAVE_LATEST_PATH := "user://autosave/latest.flyntic"
const AUTOSAVE_MAX_SNAPSHOTS := 5
const ANALYTICS_DIR := "user://analytics"
const ANALYTICS_EVENTS_PATH := "user://analytics/events.jsonl"
const TELEMETRY_DIR := "user://telemetry"
const DIAG_SEV_ERROR := "error"
const DIAG_SEV_WARNING := "warning"
const DIAG_SEV_INFO := "info"
const CTRL_MODE_MANUAL_ASSIST := "manual_assist"
const CTRL_MODE_AUTO_MISSION := "auto_mission"
const CTRL_MODE_ADAPTIVE_HOVER := "adaptive_hover"
const SWARM_BEHAVIOR_LEADER_FOLLOWER := "leader_follower"
const SWARM_BEHAVIOR_AREA_SWEEP := "area_sweep"
const SWARM_BEHAVIOR_RELAY_CHAIN := "relay_chain"
const PHYSICS_PROFILE_LOW_HARDWARE := "low_hardware"
const PHYSICS_PROFILE_BALANCED := "balanced"
const PHYSICS_PROFILE_HIGH_FIDELITY := "high_fidelity"
const WEATHER_PRESET_CLEAR_DAY := "clear_day"
const WEATHER_PRESET_WINDY_EVENING := "windy_evening"
const WEATHER_PRESET_STORM := "storm"

var _autosave_enabled := true
var _autosave_timer := 0.0
var _autosave_last_hash := 0
var _autosave_bootstrapped := false
var _autosave_restore_prompted := false
var _analytics_enabled := true
var _analytics_service: RefCounted = null
var _module_loader_service: RefCounted = null
var _diagnostics_service: RefCounted = null
var _environment_service: RefCounted = null
var _swarm_controller: RefCounted = null
var _telemetry_recorder: RefCounted = null
var _telemetry_validator: RefCounted = null
var _runtime_mode_service: RefCounted = null
var _runtime_input_service: RefCounted = null
var _flight_assist_service: RefCounted = null
var _simulation_coordinator_service: RefCounted = null
var _mission_runtime_service: RefCounted = null
var _swarm_telemetry_service: RefCounted = null
var _mission_planner: RefCounted = null
var _sensor_model: RefCounted = null
var _replay_runner: RefCounted = null
var _safety_layer: RefCounted = null
var _swarm_enabled := false
var _swarm_count := 0
var _swarm_behavior := SWARM_BEHAVIOR_LEADER_FOLLOWER
var _low_hardware_mode := true
var _physics_profile := PHYSICS_PROFILE_LOW_HARDWARE
var _weather_preset := WEATHER_PRESET_CLEAR_DAY
var _environment_seed := 1337
var _safety_enabled := true
var _flight_control_mode := CTRL_MODE_MANUAL_ASSIST
var _telemetry_sample_timer := 0.0
var _telemetry_sample_rate := 12.0
var _mission_active := false
var _replay_active := false
var _last_telemetry_csv := ""
var _last_telemetry_manifest := ""
var _estimated_flight_minutes := 0.0
var _prev_leader_pos := Vector3.ZERO
var _prev_leader_vel := Vector3.ZERO
var _sensor_state := {
	"gps_pos": Vector3.ZERO,
	"imu_vel": Vector3.ZERO,
	"imu_accel": Vector3.ZERO,
	"baro_alt": 0.0,
	"health": 1.0,
}
var _env_state := {
	"wind": Vector3.ZERO,
	"drag": Vector3.ZERO,
	"emi": Vector3.ZERO,
	"emi_channels": {
		"gps_drift": Vector3.ZERO,
		"magnetometer_bias": Vector3.ZERO,
		"gyro_jitter": Vector3.ZERO,
	},
	"luminance": 1.0,
}
var _safety_state := {
	"active": false,
	"mode": "none",
	"reason": "",
	"target": Vector3.ZERO,
}
func _maybe_prompt_restore_autosave():
	if _autosave_restore_prompted:
		return
	_autosave_restore_prompted = true
	var cd = ConfirmationDialog.new()
	cd.title = "Restore Autosave"
	cd.dialog_text = "A recent autosave was found. Restore it now?"
	add_child(cd)
	cd.confirmed.connect(func():
		var normalized = _read_normalized_project_file(AUTOSAVE_LATEST_PATH)
		if normalized.is_empty():
			_log("Autosave restore failed", "error")
			cd.queue_free()
			return
		_apply_loaded_project_data(normalized)
		_log("Autosave restored", "success")
		cd.queue_free()
	)
	cd.canceled.connect(func(): cd.queue_free())
	cd.popup_centered(Vector2i(460, 180))

func _read_normalized_project_file(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json_text = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(json_text) != OK:
		return {}
	return _normalize_loaded_project(json.data)
func _diag_issue(severity: String, message: String, fix_hint := "") -> Dictionary:
	return {"severity": severity, "message": message, "fix_hint": fix_hint}

func _diag_severity_color(severity: String) -> String:
	match severity:
		DIAG_SEV_ERROR:
			return "#f44336"
		DIAG_SEV_WARNING:
			return "#ff9800"
		_:
			return "#4fc3f7"

func _diag_prefix(severity: String) -> String:
	match severity:
		DIAG_SEV_ERROR:
			return "ERROR"
		DIAG_SEV_WARNING:
			return "WARNING"
		_:
			return "INFO"

func _format_diagnostics(issues: Array[Dictionary]) -> String:
	var errors := 0
	var warnings := 0
	var infos := 0
	for issue in issues:
		match str(issue.get("severity", DIAG_SEV_INFO)):
			DIAG_SEV_ERROR:
				errors += 1
			DIAG_SEV_WARNING:
				warnings += 1
			_:
				infos += 1

	var lines: Array[String] = []
	lines.append("[color=#90caf9]Diagnostics: %d error(s), %d warning(s), %d info[/color]" % [errors, warnings, infos])
	for issue in issues:
		var sev = str(issue.get("severity", DIAG_SEV_INFO))
		var msg = str(issue.get("message", ""))
		var fix = str(issue.get("fix_hint", ""))
		lines.append("[color=%s][%s] %s[/color]" % [_diag_severity_color(sev), _diag_prefix(sev), msg])
		if fix != "":
			lines.append("[color=#9e9e9e]  Suggestion: %s[/color]" % fix)
	return "\n".join(lines)

# ──────────────────────────── INIT ────────────────────────────────
func _ready():
	# Keep UI at 1:1 pixel mapping to avoid blurry text from stretch scaling.
	var window = get_window()
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	window.content_scale_factor = 1.0
	get_viewport().gui_snap_controls_to_pixels = true
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	if is_instance_valid(vpc) and not vpc.resized.is_connected(_on_canvas_container_resized):
		vpc.resized.connect(_on_canvas_container_resized)
	call_deferred("_verify_window_mode")
	call_deferred("_sync_canvas_viewport_size")
	
	# Explicitly hook window resize to fix Godot anchor bugs & add safe margins
	get_tree().get_root().size_changed.connect(_on_window_resized)
	_on_window_resized()
	
	_build_comp_list()
	_build_floor()
	_build_grid()
	_place("PVC Pipe Frame", Vector3.ZERO)
	_update_all()
	_setup_topbar_menu_actions()
	play_btn.pressed.connect(_on_play)
	pause_btn.pressed.connect(_on_pause)
	stop_btn.pressed.connect(_on_stop)
	comp_list.item_selected.connect(_on_item_selected)
	if not comp_list.item_clicked.is_connected(_on_comp_item_clicked):
		comp_list.item_clicked.connect(_on_comp_item_clicked)
	hier_tree.item_selected.connect(_on_hier_item_selected)
	hier_del_btn.pressed.connect(_remove_selected)
	_ensure_blocks_toolbox_scroll()
	_setup_blocks()
	_create_trash_zone()
	# Pre-populate workspace with a standard 'When flag clicked' stack
	_create_block("start", "When ⚐ clicked", Color(0.85, 0.65, 0), Vector2(50, 50))
	# Initialize wiring tab
	_setup_wiring_tab()
	# Initialize properties panel
	_setup_properties_panel()
	# Initialize physics bridge
	_init_bridge()
	_setup_onboarding_ui()
	_load_ui_prefs()
	_init_autosave()
	_init_analytics()
	_weather_preset = _default_weather_for_profile(_physics_profile)
	_init_environment_modules()
	_init_telemetry()
	_track_event("app_started", {"schema": PROJECT_SCHEMA_VERSION})
	
	# Pro Graphics Settings
	var env = camera.environment
	if not env:
		env = Environment.new()
		camera.environment = env
	env.ssao_enabled = false
	env.glow_enabled = false
	
	_log("Flyntic Studio initialized", "success")
	if not _onboarding_seen:
		call_deferred("_start_onboarding")

func _init_analytics():
	if not _analytics_enabled:
		return
	if _analytics_service == null:
		var analytics_script = load("res://services/AnalyticsService.gd")
		if analytics_script == null:
			_log("Analytics service script missing", "warning")
			return
		_analytics_service = analytics_script.new(ANALYTICS_DIR, ANALYTICS_EVENTS_PATH)
	var mk_err = _analytics_service.initialize()
	if mk_err != OK:
		_log("Failed to initialize analytics directory", "warning")

func _track_event(name: String, payload: Dictionary = {}):
	if not _analytics_enabled:
		return
	if _analytics_service == null:
		_init_analytics()
	if _analytics_service == null:
		return
	_analytics_service.track_event(name, payload)

func _profile_to_low_hardware(profile_name: String) -> bool:
	return profile_name == PHYSICS_PROFILE_LOW_HARDWARE

func _default_weather_for_profile(profile_name: String) -> String:
	match profile_name:
		PHYSICS_PROFILE_BALANCED:
			return WEATHER_PRESET_WINDY_EVENING
		PHYSICS_PROFILE_HIGH_FIDELITY:
			return WEATHER_PRESET_STORM
		_:
			return WEATHER_PRESET_CLEAR_DAY

func _build_environment_runtime_config() -> Dictionary:
	return {
		"seed": _environment_seed,
		"physics_profile": _physics_profile,
		"weather_preset": _weather_preset,
		"low_hardware_mode": _low_hardware_mode,
	}

func _build_sensor_runtime_config() -> Dictionary:
	return {
		"seed": _environment_seed,
		"physics_profile": _physics_profile,
	}

func _apply_phase_a_runtime_config(log_change := false):
	_low_hardware_mode = _profile_to_low_hardware(_physics_profile)
	if _environment_service != null:
		_environment_service.configure(_build_environment_runtime_config())
	if _sensor_model != null:
		_sensor_model.configure(_build_sensor_runtime_config())
	if log_change:
		_log("Physics profile: %s | Weather: %s | Seed: %d" % [_physics_profile, _weather_preset, _environment_seed], "info")

func _cycle_physics_profile():
	var profiles = [PHYSICS_PROFILE_LOW_HARDWARE, PHYSICS_PROFILE_BALANCED, PHYSICS_PROFILE_HIGH_FIDELITY]
	var idx = profiles.find(_physics_profile)
	if idx < 0:
		idx = 0
	idx = (idx + 1) % profiles.size()
	_physics_profile = profiles[idx]
	_weather_preset = _default_weather_for_profile(_physics_profile)
	_apply_phase_a_runtime_config(true)
	_track_event("physics_profile_changed", {
		"profile": _physics_profile,
		"weather": _weather_preset,
		"seed": _environment_seed,
	})

func _init_environment_modules():
	if _module_loader_service == null:
		var loader_script = load("res://services/ModuleLoaderService.gd")
		if loader_script != null:
			_module_loader_service = loader_script.new()
		else:
			_log("Module loader service missing", "warning")

	if _diagnostics_service == null:
		var diagnostics_script = load("res://services/DiagnosticsService.gd")
		if diagnostics_script != null:
			_diagnostics_service = diagnostics_script.new()
		else:
			_log("Diagnostics service missing", "warning")

	if _module_loader_service == null:
		_log("Module loader unavailable, skipping module bootstrap", "warning")
		return

	var runtime_result = _module_loader_service.load_modules([
		{"key": "runtime_mode", "path": "res://services/RuntimeModeService.gd", "missing_msg": "Runtime mode service missing"},
		{"key": "runtime_input", "path": "res://services/RuntimeInputService.gd", "missing_msg": "Runtime input service missing"},
		{"key": "flight_assist", "path": "res://services/FlightAssistService.gd", "missing_msg": "Flight assist service missing"},
		{"key": "simulation_coordinator", "path": "res://services/SimulationCoordinatorService.gd", "missing_msg": "Simulation coordinator service missing"},
		{"key": "mission_runtime", "path": "res://services/MissionRuntimeService.gd", "missing_msg": "Mission runtime service missing"},
		{"key": "swarm_telemetry", "path": "res://services/SwarmTelemetryService.gd", "missing_msg": "Swarm telemetry service missing"},
		{"key": "environment", "path": "res://services/EnvironmentPhysicsService.gd", "missing_msg": "Environment physics module missing", "configure": _build_environment_runtime_config()},
		{"key": "swarm", "path": "res://SwarmController.gd", "missing_msg": "Swarm module missing"},
		{"key": "mission", "path": "res://MissionPlanner.gd", "missing_msg": "Mission planner module missing", "configure": {"arrival_radius": 0.8, "cruise_speed": 2.8}},
		{"key": "sensor", "path": "res://services/SensorModelService.gd", "missing_msg": "Sensor model module missing", "configure": _build_sensor_runtime_config()},
		{"key": "replay", "path": "res://ReplayRunner.gd", "missing_msg": "Replay runner module missing"},
		{"key": "safety", "path": "res://services/SafetyLayer.gd", "missing_msg": "Safety layer module missing", "configure": {
			"enabled": _safety_enabled,
			"geofence_radius": 14.0,
			"rtl_altitude": 2.8,
			"battery_rtl_threshold": 0.18,
		}},
	])

	for msg in runtime_result.get("warnings", []):
		_log(str(msg), "warning")

	var modules: Dictionary = runtime_result.get("modules", {})
	_runtime_mode_service = modules.get("runtime_mode", null)
	_runtime_input_service = modules.get("runtime_input", null)
	_flight_assist_service = modules.get("flight_assist", null)
	_simulation_coordinator_service = modules.get("simulation_coordinator", null)
	_mission_runtime_service = modules.get("mission_runtime", null)
	_swarm_telemetry_service = modules.get("swarm_telemetry", null)
	_environment_service = modules.get("environment", null)
	_swarm_controller = modules.get("swarm", null)
	_mission_planner = modules.get("mission", null)
	_sensor_model = modules.get("sensor", null)
	_replay_runner = modules.get("replay", null)
	_safety_layer = modules.get("safety", null)
	_apply_phase_a_runtime_config()

	if _swarm_controller != null:
		var swarm_root = components_group.get_node_or_null("SwarmFollowers") as Node3D
		if not is_instance_valid(swarm_root):
			swarm_root = Node3D.new()
			swarm_root.name = "SwarmFollowers"
			components_group.add_child(swarm_root)
		_swarm_controller.initialize(swarm_root)

func _init_telemetry():
	if _module_loader_service == null:
		var loader_script = load("res://services/ModuleLoaderService.gd")
		if loader_script != null:
			_module_loader_service = loader_script.new()
	if _module_loader_service == null:
		_log("Telemetry init skipped: module loader unavailable", "warning")
		return

	var telemetry_result = _module_loader_service.load_modules([
		{
			"key": "telemetry",
			"path": "res://services/TelemetryRecorder.gd",
			"missing_msg": "Telemetry recorder module missing",
			"post_init": func(instance):
				instance.initialize(TELEMETRY_DIR),
		},
		{
			"key": "validator",
			"path": "res://services/TelemetryDataValidator.gd",
			"missing_msg": "Telemetry validator module missing",
		},
	])

	for msg in telemetry_result.get("warnings", []):
		_log(str(msg), "warning")

	var modules: Dictionary = telemetry_result.get("modules", {})
	_telemetry_recorder = modules.get("telemetry", null)
	_telemetry_validator = modules.get("validator", null)

func _toggle_swarm():
	if _swarm_controller == null:
		_log("Swarm controller unavailable", "warning")
		return
	if _swarm_enabled:
		_swarm_controller.clear_followers()
		_swarm_enabled = false
		_swarm_count = 0
		_log("Swarm disabled", "info")
		_track_event("swarm_disabled")
		return
	_swarm_count = clampi(max(3, placed.size() / 2), 3, 12)
	_swarm_controller.spawn_followers(_swarm_count, components_group.global_position)
	_swarm_enabled = true
	_log("Swarm enabled: %d followers" % _swarm_count, "success")
	_track_event("swarm_enabled", {"count": _swarm_count, "behavior": _swarm_behavior})

func _cycle_swarm_behavior():
	if _runtime_mode_service != null:
		_swarm_behavior = _runtime_mode_service.cycle_swarm_behavior(_swarm_behavior)
	else:
		var modes = [SWARM_BEHAVIOR_LEADER_FOLLOWER, SWARM_BEHAVIOR_AREA_SWEEP, SWARM_BEHAVIOR_RELAY_CHAIN]
		var idx = modes.find(_swarm_behavior)
		idx = (idx + 1) % modes.size()
		_swarm_behavior = modes[idx]
	_log("Swarm behavior: " + _swarm_behavior, "info")
	_track_event("swarm_behavior_changed", {"behavior": _swarm_behavior})

func _cycle_flight_control_mode():
	if _runtime_mode_service != null:
		_flight_control_mode = _runtime_mode_service.cycle_control_mode(_flight_control_mode)
	else:
		var modes = [CTRL_MODE_MANUAL_ASSIST, CTRL_MODE_AUTO_MISSION, CTRL_MODE_ADAPTIVE_HOVER]
		var idx = modes.find(_flight_control_mode)
		idx = (idx + 1) % modes.size()
		_flight_control_mode = modes[idx]
	_log("Flight control mode: " + _flight_control_mode, "info")
	_track_event("flight_control_mode_changed", {"mode": _flight_control_mode})

func _toggle_telemetry_recording():
	if _telemetry_recorder == null:
		_log("Telemetry recorder unavailable", "warning")
		return
	if _telemetry_recorder.is_active():
		_telemetry_recorder.stop_session()
		_log("Telemetry recording stopped", "info")
		_track_event("telemetry_stopped")
		return
	var start_result = _telemetry_recorder.start_session("drone", _build_telemetry_session_metadata())
	if bool(start_result.get("ok", false)):
		_last_telemetry_csv = str(start_result.get("csv", ""))
		_last_telemetry_manifest = str(start_result.get("manifest", ""))
		_log("Telemetry recording started", "success")
		_track_event("telemetry_started", {"session": str(start_result.get("session_id", ""))})
	else:
		_log("Telemetry recording failed to start", "error")

func _toggle_autonomous_mission():
	if _mission_planner == null:
		_log("Mission planner unavailable", "warning")
		return
	if _mission_active:
		_mission_planner.stop()
		_mission_active = false
		_log("Autonomous mission disabled", "info")
		_track_event("mission_disabled")
		return
	_mission_planner.load_default_mission(components_group.global_position)
	_mission_planner.start()
	_mission_active = true
	_log("Autonomous mission enabled (%d waypoints)" % _mission_planner.waypoint_count(), "success")
	_track_event("mission_enabled", {"waypoints": _mission_planner.waypoint_count()})

func _toggle_replay_mode():
	if _replay_runner == null:
		_log("Replay runner unavailable", "warning")
		return
	if _replay_active:
		_replay_runner.stop()
		_replay_active = false
		_log("Replay mode disabled", "info")
		_track_event("replay_disabled")
		return
	if _last_telemetry_csv == "":
		_log("No telemetry session available for replay", "warning")
		return
	var load_result = _replay_runner.load_csv(_last_telemetry_csv)
	if not bool(load_result.get("ok", false)):
		_log("Replay load failed", "error")
		_track_event("replay_load_failed", {"reason": str(load_result.get("reason", "unknown"))})
		return
	_replay_runner.start()
	_replay_active = true
	_mission_active = false
	if _mission_planner != null:
		_mission_planner.stop()
	var manifest = load_result.get("manifest", {})
	if typeof(manifest) == TYPE_DICTIONARY and not manifest.is_empty():
		var metadata = manifest.get("metadata", {})
		var seed = "n/a"
		var profile = "n/a"
		var weather = "n/a"
		if typeof(metadata) == TYPE_DICTIONARY:
			seed = str(metadata.get("seed", "n/a"))
			profile = str(metadata.get("profile", "n/a"))
			weather = str(metadata.get("weather_preset", "n/a"))
		_log("Replay metadata: seed=%s profile=%s weather=%s" % [seed, profile, weather], "info")
	_log("Replay mode enabled (%d samples)" % int(load_result.get("count", 0)), "success")
	_track_event("replay_enabled", {"count": int(load_result.get("count", 0))})

func _validate_latest_telemetry():
	if _telemetry_validator == null:
		_log("Telemetry validator unavailable", "warning")
		return
	if _last_telemetry_csv == "":
		_log("No telemetry CSV available to validate", "warning")
		return
	var result = _telemetry_validator.validate_csv(_last_telemetry_csv)
	if not bool(result.get("ok", false)):
		_log("Telemetry validation failed: %s" % str(result.get("reason", "unknown")), "error")
		return
	var score = float(result.get("quality_score", 0.0))
	_log("Telemetry quality score: %.1f" % score, "info")
	_log(
		"Rows=%d, parse=%d, monotonic=%d, outliers=%d" % [
			int(result.get("rows", 0)),
			int(result.get("parse_errors", 0)),
			int(result.get("monotonic_errors", 0)),
			int(result.get("outlier_rows", 0)),
		],
		"info"
	)
	_track_event("telemetry_validated", {
		"score": score,
		"rows": int(result.get("rows", 0)),
		"parse_errors": int(result.get("parse_errors", 0)),
		"monotonic_errors": int(result.get("monotonic_errors", 0)),
		"outlier_rows": int(result.get("outlier_rows", 0)),
	})

func _build_telemetry_session_metadata() -> Dictionary:
	return {
		"seed": _environment_seed,
		"low_hardware_mode": _low_hardware_mode,
		"swarm_enabled": _swarm_enabled,
		"swarm_behavior": _swarm_behavior,
		"mission_active": _mission_active,
		"mission_graph": true,
		"control_mode": _flight_control_mode,
		"safety_enabled": _safety_enabled,
		"sample_rate_hz": _telemetry_sample_rate,
		"profile": _physics_profile,
		"weather_preset": _weather_preset,
	}

func _toggle_safety_layer():
	_safety_enabled = not _safety_enabled
	if _safety_layer != null:
		_safety_layer.set_enabled(_safety_enabled)
	if not _safety_enabled:
		_safety_state = {
			"active": false,
			"mode": "none",
			"reason": "disabled",
			"target": components_group.global_position,
		}
	_log("Safety layer: " + ("ON" if _safety_enabled else "OFF"), "info")
	_track_event("safety_toggled", {"enabled": _safety_enabled})

func _setup_topbar_menu_actions():
	if not is_instance_valid(topbar_menus):
		return
	if topbar_menus.get_node_or_null("Guide") == null:
		var guide_btn = Button.new()
		guide_btn.name = "Guide"
		guide_btn.text = "Guide"
		guide_btn.flat = true
		guide_btn.focus_mode = Control.FOCUS_NONE
		guide_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
		guide_btn.add_theme_color_override("font_hover_color", Color(0.9, 0.9, 0.9, 1))
		guide_btn.add_theme_font_size_override("font_size", 12)
		topbar_menus.add_child(guide_btn)
	if topbar_menus.get_node_or_null("Metrics") == null:
		var metrics_btn = Button.new()
		metrics_btn.name = "Metrics"
		metrics_btn.text = "Metrics"
		metrics_btn.flat = true
		metrics_btn.focus_mode = Control.FOCUS_NONE
		metrics_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
		metrics_btn.add_theme_color_override("font_hover_color", Color(0.9, 0.9, 0.9, 1))
		metrics_btn.add_theme_font_size_override("font_size", 12)
		topbar_menus.add_child(metrics_btn)
	for child in topbar_menus.get_children():
		if child is BaseButton and not child.pressed.is_connected(_on_topbar_menu_pressed.bind(child)):
			child.pressed.connect(_on_topbar_menu_pressed.bind(child))

func _on_topbar_menu_pressed(btn: BaseButton):
	if not is_instance_valid(btn):
		return
	if btn.name == "Guide":
		_start_onboarding(true)
		return
	if btn.name == "Metrics":
		_show_analytics_dashboard()
		return
	_log("Menu: " + btn.text, "info")

func _show_analytics_dashboard():
	if _analytics_service == null:
		_init_analytics()
	if _analytics_service == null:
		_log("Analytics service unavailable", "warning")
		return
	var summary = _analytics_service.summarize_events()
	if not bool(summary.get("ok", false)):
		_log("No analytics events yet", "info")
		return
	var total = int(summary.get("total", 0))
	var counts: Dictionary = summary.get("counts", {})
	var first_ts = float(summary.get("first_ts", 0.0))
	var last_ts = float(summary.get("last_ts", 0.0))

	var sim_started = int(counts.get("simulation_started", 0))
	var sim_stopped = int(counts.get("simulation_stopped", 0))
	var projects_saved = int(counts.get("project_saved", 0))
	var projects_loaded = int(counts.get("project_loaded", 0))
	var started_to_stopped = (float(sim_stopped) / float(max(sim_started, 1))) * 100.0

	_log("Analytics dashboard", "info")
	_log("Events total: %d" % total, "info")
	if first_ts > 0.0 and last_ts > 0.0:
		_log("Window: %s -> %s" % [Time.get_datetime_string_from_unix_time(first_ts), Time.get_datetime_string_from_unix_time(last_ts)], "info")
	for k in counts.keys():
		_log("- %s: %d" % [str(k), int(counts[k])], "info")
	_log("Simulation completion proxy: %.1f%% (%d/%d)" % [started_to_stopped, sim_stopped, sim_started], "info")
	_log("Projects saved/loaded: %d/%d" % [projects_saved, projects_loaded], "info")

func _sample_environment(delta: float):
	if _environment_service == null:
		return
	var leader_vel = (components_group.global_position - _prev_leader_pos) / max(delta, 0.0001)
	_env_state = _environment_service.sample_state(sim_time, components_group.global_position, leader_vel)
	if is_instance_valid(camera) and camera.environment != null:
		_environment_service.apply_environment_lighting(camera.environment, sim_time)

func _update_swarm_and_telemetry(delta: float):
	if _swarm_telemetry_service != null:
		var result = _swarm_telemetry_service.update_runtime({
			"delta": delta,
			"sim_time": sim_time,
			"leader_pos": components_group.global_position,
			"prev_pos": _prev_leader_pos,
			"prev_vel": _prev_leader_vel,
			"env_state": _env_state,
			"sensor_model": _sensor_model,
			"sensor_state": _sensor_state,
			"swarm_enabled": _swarm_enabled,
			"swarm_controller": _swarm_controller,
			"swarm_behavior": _swarm_behavior,
			"telemetry_recorder": _telemetry_recorder,
			"telemetry_sample_timer": _telemetry_sample_timer,
			"telemetry_sample_rate": _telemetry_sample_rate,
			"safety_state": _safety_state,
		})
		_sensor_state = result.get("sensor_state", _sensor_state)
		_telemetry_sample_timer = float(result.get("telemetry_sample_timer", _telemetry_sample_timer))
		_prev_leader_pos = result.get("prev_leader_pos", _prev_leader_pos)
		_prev_leader_vel = result.get("prev_leader_vel", _prev_leader_vel)
		return

	var leader_vel = (components_group.global_position - _prev_leader_pos) / max(delta, 0.0001)
	var accel = (leader_vel - _prev_leader_vel) / max(delta, 0.0001)
	if _sensor_model != null:
		_sensor_state = _sensor_model.sample(sim_time, components_group.global_position, leader_vel, accel, _env_state.get("emi_channels", _env_state.get("emi", Vector3.ZERO)))
	if _swarm_enabled and _swarm_controller != null:
		_swarm_controller.update_followers(
			delta,
			components_group.global_position,
			leader_vel,
			_env_state.get("wind", Vector3.ZERO),
			_swarm_behavior,
			sim_time
		)

	_telemetry_sample_timer += delta
	if _telemetry_recorder != null and _telemetry_recorder.is_active() and _telemetry_sample_timer >= (1.0 / max(_telemetry_sample_rate, 1.0)):
		_telemetry_sample_timer = 0.0
		_telemetry_recorder.record({
			"ts": Time.get_unix_time_from_system(),
			"sim_time": sim_time,
			"position": components_group.global_position,
			"velocity": leader_vel,
			"acceleration": accel,
			"sensor": _sensor_state,
			"wind": _env_state.get("wind", Vector3.ZERO),
			"emi": _env_state.get("emi", Vector3.ZERO),
			"luminance": float(_env_state.get("luminance", 1.0)),
			"swarm_count": _swarm_controller.follower_count() if _swarm_controller != null else 0,
			"safety": _safety_state,
		})

	_prev_leader_pos = components_group.global_position
	_prev_leader_vel = leader_vel

func _setup_onboarding_ui():
	_onboarding_steps = [
		{
			"title": "Thanh Menu & Dieu Huong",
			"body": "Day la thanh menu chinh. Ban co the mo lai huong dan bang nut Guide hoac phim F1 bat ky luc nao.",
			"target_path": "Root/TopBar",
			"tab": 0,
			"card_side": "bottom",
			"hint": "B1: Lam quen dieu huong",
		},
		{
			"title": "Hierarchy (Cau truc drone)",
			"body": "Panel nay hien cac phan da dat trong scene. Chon item de focus va dung nut x de xoa phan dang chon.",
			"target_path": "Root/Content/Left/HierarchyPanel",
			"tab": 0,
			"card_side": "right",
			"hint": "B2: Quan ly cau truc",
		},
		{
			"title": "Components + Canvas 3D",
			"body": "Chon linh kien o danh sach Components, sau do dat vao Canvas. Chuot trai: chon/dat. Chuot phai: pan. Con lan: zoom.",
			"target_path": "Root/Content/CenterRight/Center/Tabs/Canvas",
			"tab": 0,
			"card_side": "right",
			"hint": "B3: Lap rap tren Canvas",
		},
		{
			"title": "Tab Blocks (Lap trinh bay)",
			"body": "Sang tab Blocks de keo-tha lenh va tao chuoi hanh vi bay. Day la noi dinh nghia kich ban mo phong.",
			"target_path": "Root/Content/CenterRight/Center/Tabs/Blocks/MainH/Toolbox",
			"tab": 1,
			"card_side": "right",
			"hint": "B4: Tao kich ban",
		},
		{
			"title": "Run Simulation & Monitors",
			"body": "Dung Play/Pause/Stop de chay mo phong. Theo doi Weight, Thrust, Battery va Diagnostics o panel ben phai.",
			"target_path": "Root/Content/CenterRight/Right/Scroll/V/SimPanel",
			"tab": 0,
			"card_side": "left",
			"hint": "B5: Chay va theo doi",
		},
		{
			"title": "Tinh nang Nang cao (Hotkeys)",
			"body": "App ho tro nhieu tinh nang nang cao (bấm các phím F). F2: Doi hinh Swarm, F3: Che do dieu khien (Auto/Manual), F5: Bat Failsafe an toan, F8: Doi Profile vat ly (Low/High).",
			"target_path": "Root/Content/CenterRight/Center/Console",
			"tab": 0,
			"card_side": "top",
			"hint": "B6: Tinh nang nang cao & Moi truong",
		},
		{
			"title": "Du lieu (Telemetry & Replay)",
			"body": "Trong khi chay, bam F6 de ghi Telemetry, F4 de check chat luong Data. F10 de bat Auto Mission, F12 de Replay chuyen bay tu file data.",
			"target_path": "Root/Content/CenterRight/Right/Scroll/V/SimPanel",
			"tab": 0,
			"card_side": "left",
			"hint": "B7: Phanthich Data ML",
		}
	]

	_onboarding_overlay = Control.new()
	_onboarding_overlay.name = "OnboardingOverlay"
	_onboarding_overlay.visible = false
	_onboarding_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_onboarding_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$Root.add_child(_onboarding_overlay)

	var dim = ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.58)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_onboarding_overlay.add_child(dim)

	_onboarding_focus_ring = Panel.new()
	_onboarding_focus_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring_style = StyleBoxFlat.new()
	ring_style.bg_color = Color(0, 0, 0, 0)
	ring_style.border_color = Color(0.15, 0.72, 0.98, 1)
	ring_style.border_width_left = 2
	ring_style.border_width_top = 2
	ring_style.border_width_right = 2
	ring_style.border_width_bottom = 2
	ring_style.corner_radius_top_left = 8
	ring_style.corner_radius_top_right = 8
	ring_style.corner_radius_bottom_left = 8
	ring_style.corner_radius_bottom_right = 8
	_onboarding_focus_ring.add_theme_stylebox_override("panel", ring_style)
	_onboarding_overlay.add_child(_onboarding_focus_ring)

	_onboarding_card = PanelContainer.new()
	_onboarding_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_onboarding_card.custom_minimum_size = Vector2(380, 170)
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.085, 0.095, 0.12, 0.98)
	card_style.border_color = Color(0.2, 0.26, 0.36, 1)
	card_style.border_width_left = 1
	card_style.border_width_top = 1
	card_style.border_width_right = 1
	card_style.border_width_bottom = 1
	card_style.corner_radius_top_left = 12
	card_style.corner_radius_top_right = 12
	card_style.corner_radius_bottom_left = 12
	card_style.corner_radius_bottom_right = 12
	card_style.content_margin_left = 14
	card_style.content_margin_right = 14
	card_style.content_margin_top = 12
	card_style.content_margin_bottom = 10
	_onboarding_card.add_theme_stylebox_override("panel", card_style)
	_onboarding_overlay.add_child(_onboarding_card)

	var card_v = VBoxContainer.new()
	card_v.add_theme_constant_override("separation", 8)
	_onboarding_card.add_child(card_v)

	_onboarding_step_title = Label.new()
	_onboarding_step_title.add_theme_font_size_override("font_size", 16)
	_onboarding_step_title.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 1))
	_onboarding_step_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_v.add_child(_onboarding_step_title)

	_onboarding_step_body = RichTextLabel.new()
	_onboarding_step_body.bbcode_enabled = false
	_onboarding_step_body.fit_content = false
	_onboarding_step_body.scroll_active = false
	_onboarding_step_body.size_flags_vertical = Control.SIZE_FILL
	_onboarding_step_body.custom_minimum_size = Vector2(0, 64)
	_onboarding_step_body.add_theme_font_size_override("normal_font_size", 13)
	_onboarding_step_body.add_theme_color_override("default_color", Color(0.83, 0.87, 0.94, 1))
	card_v.add_child(_onboarding_step_body)

	var footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	card_v.add_child(footer)

	_onboarding_progress_lbl = Label.new()
	_onboarding_progress_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_onboarding_progress_lbl.add_theme_font_size_override("font_size", 12)
	_onboarding_progress_lbl.add_theme_color_override("font_color", Color(0.65, 0.73, 0.84, 1))
	footer.add_child(_onboarding_progress_lbl)

	_onboarding_skip_btn = Button.new()
	_onboarding_skip_btn.text = "Skip"
	_onboarding_skip_btn.focus_mode = Control.FOCUS_NONE
	_onboarding_skip_btn.pressed.connect(_on_onboarding_skip)
	footer.add_child(_onboarding_skip_btn)

	_onboarding_prev_btn = Button.new()
	_onboarding_prev_btn.text = "Previous"
	_onboarding_prev_btn.focus_mode = Control.FOCUS_NONE
	_onboarding_prev_btn.pressed.connect(_on_onboarding_prev)
	footer.add_child(_onboarding_prev_btn)

	_onboarding_next_btn = Button.new()
	_onboarding_next_btn.text = "Next"
	_onboarding_next_btn.focus_mode = Control.FOCUS_NONE
	_onboarding_next_btn.pressed.connect(_on_onboarding_next)
	footer.add_child(_onboarding_next_btn)

func _load_ui_prefs():
	var cfg = ConfigFile.new()
	if cfg.load("user://flyntic_ui.cfg") == OK:
		_onboarding_seen = bool(cfg.get_value("onboarding", "seen", false))

func _save_ui_prefs():
	var cfg = ConfigFile.new()
	cfg.set_value("onboarding", "seen", _onboarding_seen)
	var err = cfg.save("user://flyntic_ui.cfg")
	if err != OK:
		_log("Failed to persist UI preferences", "warning")

func _start_onboarding(force := false):
	if not force and _onboarding_seen:
		return
	if not is_instance_valid(_onboarding_overlay):
		return
	_onboarding_active = true
	_onboarding_step_idx = 0
	_onboarding_overlay.visible = true
	_onboarding_apply_step()

func _finish_onboarding(mark_seen := true):
	_onboarding_active = false
	if is_instance_valid(_onboarding_overlay):
		_onboarding_overlay.visible = false
	if mark_seen:
		_onboarding_seen = true
		_save_ui_prefs()
		_track_event("onboarding_completed")
		_log("Guide completed. Press F1 or Guide to replay.", "success")
	else:
		_track_event("onboarding_skipped")
		_log("Guide skipped. Press F1 or Guide to replay.", "info")

func _onboarding_apply_step():
	if not _onboarding_active:
		return
	if _onboarding_steps.is_empty():
		_finish_onboarding(true)
		return

	_onboarding_step_idx = clampi(_onboarding_step_idx, 0, _onboarding_steps.size() - 1)
	var step = _onboarding_steps[_onboarding_step_idx]

	if step.has("tab") and is_instance_valid(tabs):
		tabs.current_tab = int(step.tab)

	if is_instance_valid(_onboarding_step_title):
		_onboarding_step_title.text = "B%02d/%02d - %s" % [_onboarding_step_idx + 1, _onboarding_steps.size(), str(step.title)]
	if is_instance_valid(_onboarding_step_body):
		_onboarding_step_body.clear()
		_onboarding_step_body.append_text(str(step.body))
	if is_instance_valid(_onboarding_progress_lbl):
		_onboarding_progress_lbl.text = str(step.get("hint", "Next/Previous de di chuyen, Skip de bo qua"))
	if is_instance_valid(_onboarding_prev_btn):
		_onboarding_prev_btn.disabled = _onboarding_step_idx == 0
	if is_instance_valid(_onboarding_next_btn):
		_onboarding_next_btn.text = "Finish" if _onboarding_step_idx == _onboarding_steps.size() - 1 else "Next"

	call_deferred("_onboarding_layout_current_step")

func _onboarding_layout_current_step():
	if not _onboarding_active:
		return
	var step = _onboarding_steps[_onboarding_step_idx]
	var target_path = str(step.get("target_path", ""))
	var card_side = str(step.get("card_side", "auto"))
	var target_ctrl = get_node_or_null(target_path) as Control
	var vp_size = get_viewport_rect().size
	var card_w = clamp(vp_size.x * 0.30, 320.0, 420.0)
	var card_h = clamp(vp_size.y * 0.22, 155.0, 220.0)
	if is_instance_valid(_onboarding_card):
		_onboarding_card.custom_minimum_size = Vector2(card_w, card_h)
		_onboarding_card.size = Vector2(card_w, card_h)

	if is_instance_valid(target_ctrl):
		var rect = target_ctrl.get_global_rect()
		if is_instance_valid(_onboarding_focus_ring):
			_onboarding_focus_ring.visible = true
			_onboarding_focus_ring.global_position = rect.position - Vector2(6, 6)
			_onboarding_focus_ring.size = rect.size + Vector2(12, 12)
		_onboarding_place_card_near(rect, vp_size, card_side)
	else:
		if is_instance_valid(_onboarding_focus_ring):
			_onboarding_focus_ring.visible = false
		if is_instance_valid(_onboarding_card):
			var card_size = _onboarding_card.size
			if card_size.x < 10.0 or card_size.y < 10.0:
				card_size = _onboarding_card.custom_minimum_size
			_onboarding_card.global_position = Vector2(
				(vp_size.x - card_size.x) * 0.5,
				(vp_size.y - card_size.y) * 0.5
			)

func _onboarding_place_card_near(target_rect: Rect2, vp_size: Vector2, side := "auto"):
	if not is_instance_valid(_onboarding_card):
		return
	var card_size = _onboarding_card.size
	if card_size.x < 10.0 or card_size.y < 10.0:
		card_size = _onboarding_card.custom_minimum_size

	var pad := 16.0
	var x = target_rect.position.x + target_rect.size.x * 0.5 - card_size.x * 0.5
	var y = target_rect.position.y + target_rect.size.y + pad

	match side:
		"right":
			x = target_rect.end.x + pad
			y = target_rect.position.y + (target_rect.size.y - card_size.y) * 0.5
		"left":
			x = target_rect.position.x - card_size.x - pad
			y = target_rect.position.y + (target_rect.size.y - card_size.y) * 0.5
		"top":
			x = target_rect.position.x + target_rect.size.x * 0.5 - card_size.x * 0.5
			y = target_rect.position.y - card_size.y - pad
		"bottom":
			x = target_rect.position.x + target_rect.size.x * 0.5 - card_size.x * 0.5
			y = target_rect.end.y + pad
		_:
			x = target_rect.position.x + target_rect.size.x * 0.5 - card_size.x * 0.5
			y = target_rect.end.y + pad

	x = clamp(x, 20.0, vp_size.x - card_size.x - 20.0)
	y = clamp(y, 20.0, vp_size.y - card_size.y - 20.0)
	_onboarding_card.global_position = Vector2(x, y)

func _on_onboarding_prev():
	if not _onboarding_active:
		return
	_onboarding_step_idx = max(0, _onboarding_step_idx - 1)
	_onboarding_apply_step()

func _on_onboarding_next():
	if not _onboarding_active:
		return
	if _onboarding_step_idx >= _onboarding_steps.size() - 1:
		_finish_onboarding(true)
		return
	_onboarding_step_idx += 1
	_onboarding_apply_step()

func _on_onboarding_skip():
	_finish_onboarding(false)

func _onboarding_handle_input(event) -> bool:
	if not _onboarding_active:
		if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
			_start_onboarding(true)
			return true
		return false

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_on_onboarding_skip()
			return true
		if event.keycode == KEY_LEFT:
			_on_onboarding_prev()
			return true
		if event.keycode == KEY_RIGHT or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			_on_onboarding_next()
			return true
	return false

func _init_bridge():
	var bridge_script = load("res://PhysicsBridge.gd")
	if bridge_script == null:
		_log("PhysicsBridge.gd not found — kinematic mode only", "warning")
		return
	bridge = Node.new()
	bridge.set_script(bridge_script)
	bridge.name = "PhysicsBridge"
	add_child(bridge)
	bridge.bridge_connected.connect(_on_bridge_connected)
	bridge.bridge_disconnected.connect(_on_bridge_disconnected)
	bridge.state_received.connect(_on_bridge_state)
	_log("Physics bridge initialized — connecting to TCP server...", "info")

func _on_bridge_connected():
	bridge_connected = true
	_log("Bridge: Connected (" + bridge.bridge_mode + " mode)", "success")

func _on_bridge_disconnected():
	bridge_connected = false
	_log("Bridge: Disconnected — using kinematic fallback", "warning")

func _setup_blocks():
	_setup_block_categories()
	# Wire up toolbox buttons to spawn blocks
	for child in toolbox_v.get_children():
		if is_instance_valid(child) and (child is Button or child is Panel):
			child.gui_input.connect(_on_toolbox_input.bind(child))

func _setup_block_categories():
	if not is_instance_valid(blocks_sidebar) or not is_instance_valid(toolbox_v):
		return

	var sidebar_v = blocks_sidebar.get_node_or_null("V") as VBoxContainer
	if not is_instance_valid(sidebar_v):
		return

	var btn_e = sidebar_v.get_node_or_null("BtnE") as BaseButton
	var btn_m = sidebar_v.get_node_or_null("BtnM") as BaseButton
	var btn_c = sidebar_v.get_node_or_null("BtnC") as BaseButton
	var btn_var = sidebar_v.get_node_or_null("Variables") as BaseButton

	if is_instance_valid(btn_e) and not btn_e.pressed.is_connected(_on_block_category_pressed.bind("events")):
		btn_e.pressed.connect(_on_block_category_pressed.bind("events"))
	if is_instance_valid(btn_m) and not btn_m.pressed.is_connected(_on_block_category_pressed.bind("motion")):
		btn_m.pressed.connect(_on_block_category_pressed.bind("motion"))
	if is_instance_valid(btn_c) and not btn_c.pressed.is_connected(_on_block_category_pressed.bind("control")):
		btn_c.pressed.connect(_on_block_category_pressed.bind("control"))
	if is_instance_valid(btn_var) and not btn_var.pressed.is_connected(_on_block_category_pressed.bind("variables")):
		btn_var.pressed.connect(_on_block_category_pressed.bind("variables"))

	if not is_instance_valid(_variables_placeholder):
		_variables_placeholder = Label.new()
		_variables_placeholder.name = "VariablesPlaceholder"
		_variables_placeholder.text = "No variable blocks yet"
		_variables_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_variables_placeholder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_variables_placeholder.add_theme_font_size_override("font_size", 11)
		_variables_placeholder.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65, 1))
		toolbox_v.add_child(_variables_placeholder)

	_apply_block_category("events")

func _on_block_category_pressed(category: String):
	_apply_block_category(category)

func _apply_block_category(category: String):
	if not is_instance_valid(toolbox_v):
		return
	_active_block_category = category

	var visible_nodes: Array[String] = []
	match category:
		"events":
			visible_nodes = ["Title", "b1"]
		"motion":
			visible_nodes = ["Title2", "bt1", "bm1", "bm2", "bm3", "bm4", "bm5", "bm6", "bm7", "bm8"]
		"control":
			visible_nodes = ["Title3", "bl1", "bl2", "bl3"]
		"variables":
			visible_nodes = ["VariablesPlaceholder"]

	for child in toolbox_v.get_children():
		if not is_instance_valid(child):
			continue
		child.visible = child.name in visible_nodes

	# Visual active state for category buttons.
	var sidebar_v = blocks_sidebar.get_node_or_null("V") as VBoxContainer
	if is_instance_valid(sidebar_v):
		var btn_map = {
			"events": sidebar_v.get_node_or_null("BtnE"),
			"motion": sidebar_v.get_node_or_null("BtnM"),
			"control": sidebar_v.get_node_or_null("BtnC"),
			"variables": sidebar_v.get_node_or_null("Variables"),
		}
		for key in btn_map.keys():
			var btn = btn_map[key] as BaseButton
			if not is_instance_valid(btn):
				continue
			if key == category:
				btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
				btn.modulate = Color(1, 1, 1, 1)
			else:
				btn.modulate = Color(0.8, 0.8, 0.85, 0.9)

func _ensure_blocks_toolbox_scroll():
	if not is_instance_valid(toolbox) or not is_instance_valid(toolbox_v):
		return

	# Prevent visual overflow outside Blocks panels.
	toolbox.clip_contents = true
	if is_instance_valid(workspace):
		workspace.clip_contents = true

	var sc = toolbox.get_node_or_null("ToolboxScroll") as ScrollContainer
	if sc == null:
		sc = ScrollContainer.new()
		sc.name = "ToolboxScroll"
		sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		sc.offset_left = 8
		sc.offset_top = 6
		sc.offset_right = 0
		sc.offset_bottom = -6
		sc.grow_horizontal = Control.GROW_DIRECTION_BOTH
		sc.grow_vertical = Control.GROW_DIRECTION_BOTH
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		sc.clip_contents = true
		toolbox.add_child(sc)

	_style_toolbox_scrollbar(sc)

	if toolbox_v.get_parent() != sc:
		var old_parent = toolbox_v.get_parent()
		if is_instance_valid(old_parent):
			old_parent.remove_child(toolbox_v)
		sc.add_child(toolbox_v)
		toolbox_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		toolbox_v.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		toolbox_v.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		toolbox_v.offset_bottom = 0

	toolbox_v.add_theme_constant_override("margin_left", 14)
	toolbox_v.add_theme_constant_override("margin_right", 10)

func _style_toolbox_scrollbar(sc: ScrollContainer):
	if not is_instance_valid(sc):
		return
	var vbar = sc.get_v_scroll_bar()
	if not is_instance_valid(vbar):
		return

	vbar.custom_minimum_size.x = 8

	var track = StyleBoxFlat.new()
	track.bg_color = Color(0.08, 0.09, 0.11, 0.95)
	track.corner_radius_top_left = 4
	track.corner_radius_top_right = 4
	track.corner_radius_bottom_left = 4
	track.corner_radius_bottom_right = 4

	var grabber = StyleBoxFlat.new()
	grabber.bg_color = Color(0.3, 0.38, 0.5, 1)
	grabber.corner_radius_top_left = 4
	grabber.corner_radius_top_right = 4
	grabber.corner_radius_bottom_left = 4
	grabber.corner_radius_bottom_right = 4

	var grabber_hover = grabber.duplicate()
	grabber_hover.bg_color = Color(0.38, 0.48, 0.64, 1)

	var grabber_press = grabber.duplicate()
	grabber_press.bg_color = Color(0.2, 0.65, 0.95, 1)

	vbar.add_theme_stylebox_override("scroll", track)
	vbar.add_theme_stylebox_override("grabber", grabber)
	vbar.add_theme_stylebox_override("grabber_highlight", grabber_hover)
	vbar.add_theme_stylebox_override("grabber_pressed", grabber_press)

func _resolve_toolbox_block_data(node: Control) -> Dictionary:
	var block_type = node.name.to_lower()
	var label = ""
	var color = Color(1, 0.7, 0)

	match block_type:
		"b1":
			label = "When ⚐ clicked"
			block_type = "start"
		"bt1":
			label = "Take Off"
			block_type = "take_off"
			color = Color(0.3, 0.6, 1.0)
		"bm1":
			label = "Forward [ 50 ] cm"
			block_type = "forward"
			color = Color(0.25, 0.55, 0.95)
		"bm2":
			label = "Hover (2s)"
			block_type = "hover"
			color = Color(0.2, 0.5, 0.9)
		"bm3":
			label = "Backward [ 50 ] cm"
			block_type = "backward"
			color = Color(0.25, 0.55, 0.95)
		"bm4":
			label = "Left [ 50 ] cm"
			block_type = "move_left"
			color = Color(0.25, 0.55, 0.95)
		"bm5":
			label = "Right [ 50 ] cm"
			block_type = "move_right"
			color = Color(0.25, 0.55, 0.95)
		"bm6":
			label = "Turn Left [ 90 ] °"
			block_type = "turn_left"
			color = Color(0.4, 0.3, 0.85)
		"bm7":
			label = "Turn Right [ 90 ] °"
			block_type = "turn_right"
			color = Color(0.4, 0.3, 0.85)
		"bm8":
			label = "Set Altitude [ 3 ] m"
			block_type = "set_altitude"
			color = Color(0.15, 0.6, 0.85)
		"bl1":
			label = "Land drone"
			block_type = "land"
			color = Color(0.9, 0.5, 0.1)
		"bl2":
			label = "Wait [ 2 ] seconds"
			block_type = "wait"
			color = Color(0.85, 0.55, 0.1)
		"bl3":
			label = "Repeat [ 3 ] times"
			block_type = "repeat"
			color = Color(0.7, 0.3, 0.7)
		_:
			return {}

	return {
		"type": block_type,
		"label": label,
		"color": color,
	}

func _toolbox_spawn_position() -> Vector2:
	return get_global_mouse_position() - workspace.global_position + Vector2(10, 0)

func _start_toolbox_drag(node: Control):
	_toolbox_drag_payload = _resolve_toolbox_block_data(node)
	if _toolbox_drag_payload.is_empty():
		return
	_toolbox_drag_active = true
	_toolbox_drag_moved = false
	_toolbox_drag_start_mouse = get_global_mouse_position()
	_toolbox_drag_block = null

func _end_toolbox_drag(cancel_preview := false):
	if cancel_preview and is_instance_valid(_toolbox_drag_block):
		_toolbox_drag_block.queue_free()
	_toolbox_drag_active = false
	_toolbox_drag_moved = false
	_toolbox_drag_payload.clear()
	_toolbox_drag_block = null

func _process_toolbox_drag(event) -> bool:
	if not _toolbox_drag_active:
		return false

	if tabs.current_tab != 1:
		_end_toolbox_drag(true)
		return false

	if event is InputEventMouseMotion:
		if not _toolbox_drag_moved and get_global_mouse_position().distance_to(_toolbox_drag_start_mouse) >= TOOLBOX_DRAG_THRESHOLD:
			_toolbox_drag_moved = true
			_toolbox_drag_block = _create_block(_toolbox_drag_payload.type, _toolbox_drag_payload.label, _toolbox_drag_payload.color, _toolbox_spawn_position())
		if _toolbox_drag_moved and is_instance_valid(_toolbox_drag_block):
			_toolbox_drag_block.position = _toolbox_spawn_position()
		return true

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if _toolbox_drag_moved:
			if is_instance_valid(_toolbox_drag_block):
				_check_snapping(_toolbox_drag_block)
		else:
			_create_block(_toolbox_drag_payload.type, _toolbox_drag_payload.label, _toolbox_drag_payload.color, _toolbox_spawn_position())
		_end_toolbox_drag()
		return true

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_end_toolbox_drag(true)
		return true

	return false

func _on_toolbox_input(event, node):
	if sim_state == "playing":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_start_toolbox_drag(node)
		accept_event()

func _style_value_block_label(block_label: Label):
	block_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	block_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	block_label.offset_left = 12
	block_label.offset_right = -92
	block_label.clip_text = true
	block_label.add_theme_font_size_override("font_size", 11)

func _add_block_unit_label(parent: Control, unit_text: String):
	var unit_label = Label.new()
	unit_label.text = unit_text
	unit_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	unit_label.layout_mode = 1
	unit_label.anchor_left = 1.0
	unit_label.anchor_right = 1.0
	unit_label.offset_left = -30
	unit_label.offset_right = -8
	unit_label.offset_top = 0
	unit_label.offset_bottom = 0
	unit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	unit_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	unit_label.add_theme_font_size_override("font_size", 11)
	unit_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	parent.add_child(unit_label)

func _create_block(type: String, text: String, color: Color, pos: Vector2):
	var b = Panel.new()
	b.set_script(block_script)
	b.custom_minimum_size = Vector2(200, 52) # Taller for premium look
	b.block_type = type
	
	# Derive accent colors for premium look
	var darker = Color(color.r * 0.7, color.g * 0.7, color.b * 0.7)
	var border_color = Color(color.r * 0.5, color.g * 0.5, color.b * 0.5, 0.8)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	# Shadow for depth
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(1, 2)
	# Subtle border for separation
	sb.border_width_left = 2
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 2
	sb.border_color = darker
	b.add_theme_stylebox_override("panel", sb)
	
	# Color accent stripe on left edge
	var accent = Panel.new()
	accent.custom_minimum_size = Vector2(5, 44)
	var accent_sb = StyleBoxFlat.new()
	accent_sb.bg_color = Color(min(color.r * 1.5, 1.0), min(color.g * 1.5, 1.0), min(color.b * 1.5, 1.0))
	accent_sb.corner_radius_top_left = 6
	accent_sb.corner_radius_bottom_left = 6
	accent.add_theme_stylebox_override("panel", accent_sb)
	accent.position = Vector2(4, 4)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(accent)
	
	# Visual Connector: Top Cutout (Darker overlay) — improved
	if type != "start":
		var cutout = Panel.new()
		cutout.custom_minimum_size = Vector2(28, 9)
		var csb = StyleBoxFlat.new()
		csb.bg_color = Color(0.12, 0.12, 0.14) # Match workspace bg
		csb.corner_radius_bottom_left = 7
		csb.corner_radius_bottom_right = 7
		cutout.add_theme_stylebox_override("panel", csb)
		cutout.position = Vector2(25, -2)
		cutout.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(cutout)
	else:
		# "Start" block gets a hat-shaped top
		sb.corner_radius_top_left = 18
		sb.corner_radius_top_right = 18

	# Visual Connector: Bottom Notch — improved
	var notch = Panel.new()
	notch.custom_minimum_size = Vector2(28, 9)
	var nsb = StyleBoxFlat.new()
	nsb.bg_color = color
	nsb.corner_radius_bottom_left = 7
	nsb.corner_radius_bottom_right = 7
	nsb.shadow_color = Color(0, 0, 0, 0.25)
	nsb.shadow_size = 2
	notch.add_theme_stylebox_override("panel", nsb)
	notch.position = Vector2(25, 51)
	notch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(notch)
	
	var block_label = Label.new()
	block_label.name = "L"
	block_label.text = text
	block_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	block_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	block_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	block_label.clip_text = true
	block_label.add_theme_font_size_override("font_size", 12)
	block_label.add_theme_color_override("font_color", Color(1, 1, 1))
	block_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.4))
	b.add_child(block_label)

	# Editable Input for blocks with values
	if type in ["forward", "backward", "move_left", "move_right"]:
		_style_value_block_label(block_label)
		var prefix = type.capitalize().replace("_", " ")
		block_label.text = prefix
		_add_block_unit_label(b, "cm")
		
		# White circular background for input
		var input_bg = Panel.new()
		input_bg.custom_minimum_size = Vector2(50, 24)
		input_bg.position = Vector2(122, 12)
		var ibsb = StyleBoxFlat.new()
		ibsb.bg_color = Color(1, 1, 1)
		ibsb.corner_radius_top_left = 12
		ibsb.corner_radius_top_right = 12
		ibsb.corner_radius_bottom_left = 12
		ibsb.corner_radius_bottom_right = 12
		input_bg.name = "input_bg"
		input_bg.add_theme_stylebox_override("panel", ibsb)
		b.add_child(input_bg)

		var input = LineEdit.new()
		input.name = "Input"
		input.text = "50"
		input.alignment = HORIZONTAL_ALIGNMENT_CENTER
		input.add_theme_font_size_override("font_size", 11)
		input.add_theme_color_override("font_color", Color(0, 0, 0))
		input.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var empty_sb = StyleBoxEmpty.new()
		input.add_theme_stylebox_override("normal", empty_sb)
		input.add_theme_stylebox_override("focus", empty_sb)
		input_bg.add_child(input)
	elif type in ["turn_left", "turn_right"]:
		_style_value_block_label(block_label)
		var prefix = "Turn Left" if type == "turn_left" else "Turn Right"
		block_label.text = prefix
		_add_block_unit_label(b, "°")
		var input_bg = Panel.new()
		input_bg.custom_minimum_size = Vector2(50, 24)
		input_bg.position = Vector2(122, 12)
		var ibsb = StyleBoxFlat.new()
		ibsb.bg_color = Color(1, 1, 1)
		ibsb.corner_radius_top_left = 12
		ibsb.corner_radius_top_right = 12
		ibsb.corner_radius_bottom_left = 12
		ibsb.corner_radius_bottom_right = 12
		input_bg.name = "input_bg"
		input_bg.add_theme_stylebox_override("panel", ibsb)
		b.add_child(input_bg)
		var input = LineEdit.new()
		input.name = "Input"
		input.text = "90"
		input.alignment = HORIZONTAL_ALIGNMENT_CENTER
		input.add_theme_font_size_override("font_size", 11)
		input.add_theme_color_override("font_color", Color(0, 0, 0))
		input.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var empty_sb = StyleBoxEmpty.new()
		input.add_theme_stylebox_override("normal", empty_sb)
		input.add_theme_stylebox_override("focus", empty_sb)
		input_bg.add_child(input)
	elif type == "set_altitude":
		_style_value_block_label(block_label)
		block_label.text = "Set Altitude"
		_add_block_unit_label(b, "m")
		var input_bg = Panel.new()
		input_bg.custom_minimum_size = Vector2(50, 24)
		input_bg.position = Vector2(122, 12)
		var ibsb = StyleBoxFlat.new()
		ibsb.bg_color = Color(1, 1, 1)
		ibsb.corner_radius_top_left = 12
		ibsb.corner_radius_top_right = 12
		ibsb.corner_radius_bottom_left = 12
		ibsb.corner_radius_bottom_right = 12
		input_bg.name = "input_bg"
		input_bg.add_theme_stylebox_override("panel", ibsb)
		b.add_child(input_bg)
		var input = LineEdit.new()
		input.name = "Input"
		input.text = "3"
		input.alignment = HORIZONTAL_ALIGNMENT_CENTER
		input.add_theme_font_size_override("font_size", 11)
		input.add_theme_color_override("font_color", Color(0, 0, 0))
		input.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var empty_sb = StyleBoxEmpty.new()
		input.add_theme_stylebox_override("normal", empty_sb)
		input.add_theme_stylebox_override("focus", empty_sb)
		input_bg.add_child(input)
	elif type == "wait":
		_style_value_block_label(block_label)
		block_label.text = "Wait"
		_add_block_unit_label(b, "s")
		var input_bg = Panel.new()
		input_bg.custom_minimum_size = Vector2(50, 24)
		input_bg.position = Vector2(78, 12)
		var ibsb = StyleBoxFlat.new()
		ibsb.bg_color = Color(1, 1, 1)
		ibsb.corner_radius_top_left = 12
		ibsb.corner_radius_top_right = 12
		ibsb.corner_radius_bottom_left = 12
		ibsb.corner_radius_bottom_right = 12
		input_bg.name = "input_bg"
		input_bg.add_theme_stylebox_override("panel", ibsb)
		b.add_child(input_bg)
		var input = LineEdit.new()
		input.name = "Input"
		input.text = "2"
		input.alignment = HORIZONTAL_ALIGNMENT_CENTER
		input.add_theme_font_size_override("font_size", 11)
		input.add_theme_color_override("font_color", Color(0, 0, 0))
		input.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var empty_sb = StyleBoxEmpty.new()
		input.add_theme_stylebox_override("normal", empty_sb)
		input.add_theme_stylebox_override("focus", empty_sb)
		input_bg.add_child(input)
	elif type == "repeat":
		_style_value_block_label(block_label)
		block_label.text = "Repeat"
		_add_block_unit_label(b, "x")
		var input_bg = Panel.new()
		input_bg.custom_minimum_size = Vector2(50, 24)
		input_bg.position = Vector2(78, 12)
		var ibsb = StyleBoxFlat.new()
		ibsb.bg_color = Color(1, 1, 1)
		ibsb.corner_radius_top_left = 12
		ibsb.corner_radius_top_right = 12
		ibsb.corner_radius_bottom_left = 12
		ibsb.corner_radius_bottom_right = 12
		input_bg.name = "input_bg"
		input_bg.add_theme_stylebox_override("panel", ibsb)
		b.add_child(input_bg)
		var input = LineEdit.new()
		input.name = "Input"
		input.text = "3"
		input.alignment = HORIZONTAL_ALIGNMENT_CENTER
		input.add_theme_font_size_override("font_size", 11)
		input.add_theme_color_override("font_color", Color(0, 0, 0))
		input.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var empty_sb = StyleBoxEmpty.new()
		input.add_theme_stylebox_override("normal", empty_sb)
		input.add_theme_stylebox_override("focus", empty_sb)
		input_bg.add_child(input)

	workspace.add_child(b)
	b.position = pos
	
	b.drag_started.connect(func(): if is_instance_valid(trash_panel): trash_panel.visible = true)
	b.drag_ended.connect(func(): 
		if is_instance_valid(trash_panel): trash_panel.visible = false
		_check_snapping(b)
	)
	return b

func _create_trash_zone():
	trash_panel = Panel.new()
	trash_panel.name = "TrashZone"
	trash_panel.visible = false
	var tsb = StyleBoxFlat.new()
	tsb.bg_color = Color(0.8, 0.2, 0.1, 0.4)
	tsb.border_width_left = 2
	tsb.border_width_top = 2
	tsb.border_width_right = 2
	tsb.border_width_bottom = 2
	tsb.border_color = Color(1, 0, 0, 0.8)
	trash_panel.add_theme_stylebox_override("panel", tsb)
	trash_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var label = Label.new()
	label.text = "DROP HERE TO DELETE"
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.add_theme_font_size_override("font_size", 14)
	trash_panel.add_child(label)
	
	toolbox.add_child(trash_panel)

func _check_snapping(moving_block: Panel):
	if not is_instance_valid(moving_block): return
	if trash_panel: trash_panel.visible = false
	var mpos = get_global_mouse_position()
	
	# 1. FIXED DELETION: Use the global rect of the toolbox panel
	if is_instance_valid(toolbox) and toolbox.get_global_rect().has_point(mpos):
		moving_block.queue_free()
		_log("Block deleted", "warning")
		return

	# 2. Preparation: Temporarily move to workspace for world-space calculation
	var old_pos = moving_block.global_position
	if moving_block.get_parent() != workspace:
		moving_block.get_parent().remove_child(moving_block)
		workspace.add_child(moving_block)
		moving_block.global_position = old_pos

	# 3. MULTI-BLOCK SNAPPING: Find the LEAF (last block) in the chain
	# This ensures blocks always snap to the END of a sequence, supporting N+ chains
	var best_parent = null
	var min_dist = 50.0 # Snap range
	
	var all_blocks = _get_all_blocks(workspace)
	for other in all_blocks:
		if not is_instance_valid(other): continue
		if other == moving_block: continue
		if other.is_ancestor_of(moving_block): continue
		if moving_block.is_ancestor_of(other): continue # prevent circular
		
		# Find the leaf of this block's chain (deepest child block)
		var leaf = _get_chain_leaf(other)
		var leaf_bottom_global = leaf.global_position + Vector2(0, leaf.size.y)
		var d = moving_block.global_position.distance_to(leaf_bottom_global)
		
		# Also check horizontal alignment (Scratch-style)
		var dx = abs(moving_block.global_position.x - leaf.global_position.x)
		
		if d < min_dist and dx < 60:
			min_dist = d
			best_parent = leaf
	
	if best_parent and is_instance_valid(best_parent):
		# Check best_parent doesn't already have a block child (avoid branching)
		var has_block_child := false
		for ch in best_parent.get_children():
			if is_instance_valid(ch) and "block_type" in ch:
				has_block_child = true
				break
		if has_block_child:
			# Snap to the leaf instead
			best_parent = _get_chain_leaf(best_parent)
		
		workspace.remove_child(moving_block)
		best_parent.add_child(moving_block)
		moving_block.position = Vector2(0, best_parent.size.y)
		_log("Snapped to stack", "success")

# Find the deepest block child in a chain
func _get_chain_leaf(block) -> Panel:
	for child in block.get_children():
		if is_instance_valid(child) and "block_type" in child:
			return _get_chain_leaf(child)
	return block

# Helper to find all blocks regardless of nesting
func _get_all_blocks(parent_node) -> Array:
	var list = []
	if not is_instance_valid(parent_node): return list
	for child in parent_node.get_children():
		if is_instance_valid(child):
			if "block_type" in child:
				list.append(child)
			list.append_array(_get_all_blocks(child))
	return list

# ──────────────────────────── UI BUILD ────────────────────────────
func _build_comp_list():
	comp_list.clear()
	for cat in CATEGORIES.keys():
		if not _comp_category_collapsed.has(cat):
			_comp_category_collapsed[cat] = false
		var collapsed := bool(_comp_category_collapsed[cat])
		var cat_items: Array = CATEGORIES[cat]
		var marker = "▸" if collapsed else "▾"
		var ci = comp_list.add_item("%s %s (%d)" % [marker, cat, cat_items.size()])
		comp_list.set_item_metadata(ci, {"kind": "category", "name": cat})
		comp_list.set_item_custom_fg_color(ci, Color(0.5, 0.5, 0.5))
		if collapsed:
			continue
		for cid in cat_items:
			if COMPONENTS.has(cid):
				var ii = comp_list.add_item("   " + cid)
				comp_list.set_item_metadata(ii, {"kind": "component", "id": cid})
				var c = COMPONENTS[cid]
				# Tooltip with component specs
				var tip = cid + "\nType: " + c.type + "\nWeight: " + str(c.weight) + "g"
				if c.thrust > 0: tip += "\nThrust: " + str(c.thrust) + "g"
				if c.get("capacity", 0) > 0: tip += "\nCapacity: " + str(c.capacity) + "mAh"
				comp_list.set_item_tooltip(ii, tip)
				match c.type:
					"Motor": comp_list.set_item_custom_fg_color(ii, Color(0.9, 0.4, 0.4))
					"Battery": comp_list.set_item_custom_fg_color(ii, Color(0.9, 0.8, 0.2))
					"Frame": comp_list.set_item_custom_fg_color(ii, Color(0.7, 0.7, 0.7))
					_: comp_list.set_item_custom_fg_color(ii, Color(0.6, 0.7, 0.8))

func _on_comp_item_clicked(index: int, _at_position: Vector2, mouse_button_index: int):
	if mouse_button_index != MOUSE_BUTTON_LEFT:
		return
	if index < 0 or index >= comp_list.item_count:
		return
	var meta = comp_list.get_item_metadata(index)
	if typeof(meta) == TYPE_DICTIONARY and str(meta.get("kind", "")) == "category":
		var cat = str(meta.get("name", ""))
		if cat != "":
			_comp_category_collapsed[cat] = not bool(_comp_category_collapsed.get(cat, false))
			_build_comp_list()
			comp_list.deselect_all()

func _build_floor():
	var m = MeshInstance3D.new()
	var p = PlaneMesh.new()
	p.size = Vector2(100, 100)
	m.mesh = p
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.14, 0.14, 0.16) # Darker, more neutral
	mat.metallic = 0.0
	mat.roughness = 1.0 # Pure matte
	mat.specular = 0.0 # No reflections
	m.material_override = mat
	scene_root.add_child(m)

func _build_grid():
	# Optimized grid: single ImmediateMesh instead of 202 individual nodes
	var grid_size := 50
	var span = float(grid_size)
	var y = 0.005
	
	var grid_mesh = ImmediateMesh.new()
	var mi = MeshInstance3D.new()
	mi.mesh = grid_mesh
	var mat = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = false
	mi.material_override = mat
	
	var grid_color = Color(0.25, 0.25, 0.28, 0.3)
	var x_axis_color = Color(0.8, 0.2, 0.2, 0.6)
	var z_axis_color = Color(0.2, 0.6, 0.8, 0.6)
	
	grid_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(-grid_size, grid_size + 1):
		var c = grid_color
		# X-axis line (Z direction)
		if i == 0:
			c = x_axis_color
		grid_mesh.surface_set_color(c)
		grid_mesh.surface_add_vertex(Vector3(-span, y, float(i)))
		grid_mesh.surface_add_vertex(Vector3(span, y, float(i)))
		
		# Z-axis line (X direction)
		var cz = grid_color
		if i == 0:
			cz = z_axis_color
		grid_mesh.surface_set_color(cz)
		grid_mesh.surface_add_vertex(Vector3(float(i), y, -span))
		grid_mesh.surface_add_vertex(Vector3(float(i), y, span))
	grid_mesh.surface_end()
	scene_root.add_child(mi)

# ──────────────────────────── INPUT ───────────────────────────────
func _input(event):
	if _onboarding_handle_input(event):
		return
	if _onboarding_active:
		return

	if _process_toolbox_drag(event):
		return

	var is_canvas_tab = tabs.current_tab == 0
	if _runtime_input_service != null:
		is_canvas_tab = _runtime_input_service.canvas_active(tabs.current_tab)

	# CRITICAL: Ignore 3D interactions if we are not on Canvas tab
	if not is_canvas_tab:
		orbiting = false
		panning = false
		return

	# During simulation only camera interactions are allowed.
	var sim_locked = sim_state == "playing"

	if event is InputEventMouseButton:
		var in_canvas = vpc.get_global_rect().has_point(get_global_mouse_position())
		var mouse_rt: Dictionary = {}
		if _runtime_input_service != null:
			mouse_rt = _runtime_input_service.resolve_mouse_button({
				"button_index": event.button_index,
				"pressed": event.pressed,
				"in_canvas": in_canvas,
				"sim_locked": sim_locked,
				"ghost_active": ghost != null,
			})
		else:
			mouse_rt = {"action": "noop"}

		var mouse_action = str(mouse_rt.get("action", "noop"))
		if mouse_action == "left_release":
			orbiting = false
			panning = false
		elif mouse_action == "orbit_only":
			orbiting = bool(mouse_rt.get("orbiting", false))
			panning = false
		elif mouse_action == "place_ghost":
			var snap = _find_snap()
			if snap:
				var moving_uid = _moving_component_uid
				_place(cur_id, snap.pos, snap.port, snap.parent_uid, moving_uid, moving_uid == -1, moving_uid == -1)
				_moving_component_uid = -1
				_moving_component_snapshot.clear()
				_cancel_ghost()
			else:
				var mpos = viewport.get_mouse_position()
				var ro = camera.project_ray_origin(mpos)
				var rd = camera.project_ray_normal(mpos)
				var gp = Plane(Vector3.UP, 0)
				var ghit = gp.intersects_ray(ro, rd)
				if ghit:
					var moving_uid = _moving_component_uid
					_place(cur_id, ghit + Vector3(0, 0.5, 0), "", -1, moving_uid, moving_uid == -1, moving_uid == -1)
					_moving_component_uid = -1
					_moving_component_snapshot.clear()
					_cancel_ghost()
		elif mouse_action == "pick_or_orbit":
			_pick_existing()
			if not ghost:
				orbiting = true
		elif mouse_action == "set_pan":
			panning = bool(mouse_rt.get("panning", false))
		elif mouse_action == "zoom":
			var zoom_delta = float(mouse_rt.get("zoom_delta", 0.0))
			if zoom_delta != 0.0:
				zoom = clamp(zoom + zoom_delta, 1.0, 60.0)
		else:
			# Fallback behavior when runtime input service is unavailable.
			match event.button_index:
				MOUSE_BUTTON_LEFT:
					if event.pressed and in_canvas:
						orbiting = true
					else:
						orbiting = false
						panning = false
				MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
					panning = event.pressed and in_canvas
				MOUSE_BUTTON_WHEEL_UP:
					if in_canvas:
						zoom = max(1.0, zoom - 1.5)
				MOUSE_BUTTON_WHEEL_DOWN:
					if in_canvas:
						zoom = min(60.0, zoom + 1.5)

	if event is InputEventMouseMotion:
		if _runtime_input_service != null:
			var motion_rt = _runtime_input_service.resolve_mouse_motion({
				"relative": event.relative,
				"orbiting": orbiting,
				"panning": panning,
				"zoom": zoom,
			})
			var motion_action = str(motion_rt.get("action", "noop"))
			if motion_action == "orbit":
				_cam_yaw_vel += float(motion_rt.get("yaw_delta", 0.0))
				_cam_pitch_vel += float(motion_rt.get("pitch_delta", 0.0))
			elif motion_action == "pan":
				var cam_basis = camera.global_transform.basis
				pivot.global_position += cam_basis.x * float(motion_rt.get("pan_x", 0.0))
				pivot.global_position += cam_basis.y * float(motion_rt.get("pan_y", 0.0))
		else:
			if orbiting:
				_cam_yaw_vel -= event.relative.x * 0.005
				_cam_pitch_vel -= event.relative.y * 0.005
			elif panning:
				var pan_speed = zoom * 0.001
				var cam_basis = camera.global_transform.basis
				pivot.global_position -= cam_basis.x * event.relative.x * pan_speed
				pivot.global_position += cam_basis.y * event.relative.y * pan_speed

	if event is InputEventKey and event.pressed:
		_handle_runtime_shortcuts(event, sim_locked)

func _handle_runtime_shortcuts(event: InputEventKey, sim_locked: bool):
	var actions: Array[String] = []
	if _runtime_input_service != null:
		actions = _runtime_input_service.resolve_key_actions(event, sim_locked, ghost != null)
	else:
		return

	for action in actions:
		match action:
			"rotate_ghost":
				ghost_rot += PI / 2
			"cancel_ghost":
				_cancel_ghost()
			"remove_selected":
				_remove_selected()
			"undo":
				_undo()
			"redo":
				_redo()
			"save":
				_track_event("save_shortcut_used")
				_save_project()
			"load":
				_track_event("load_shortcut_used")
				_load_project()
			"reset_camera":
				_reset_camera()
			"toggle_telemetry":
				_toggle_telemetry_recording()
			"validate_telemetry":
				_validate_latest_telemetry()
			"cycle_control_mode":
				_cycle_flight_control_mode()
			"cycle_swarm_behavior":
				_cycle_swarm_behavior()
			"toggle_swarm":
				_toggle_swarm()
			"cycle_physics_profile":
				_cycle_physics_profile()
			"toggle_safety":
				_toggle_safety_layer()
			"toggle_mission":
				_toggle_autonomous_mission()
			"toggle_replay":
				_toggle_replay_mode()
			"run_remediation":
				_run_guided_remediation()
			"focus_selected":
				_focus_selected()
			"toggle_fullscreen":
				if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				else:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

func _process(_delta):
	# Only process 3D camera/movement on Canvas tab
	if tabs.current_tab == 0:
		# WASD Movement support
		var move_vec = Vector3.ZERO
		if Input.is_key_pressed(KEY_W): move_vec += -camera.global_transform.basis.z
		if Input.is_key_pressed(KEY_S): move_vec += camera.global_transform.basis.z
		if Input.is_key_pressed(KEY_A): move_vec += -camera.global_transform.basis.x
		if Input.is_key_pressed(KEY_D): move_vec += camera.global_transform.basis.x
		if Input.is_key_pressed(KEY_Q): move_vec += Vector3.DOWN
		if Input.is_key_pressed(KEY_E): move_vec += Vector3.UP
		
		if move_vec.length() > 0:
			var speed = zoom * 0.8
			if Input.is_key_pressed(KEY_SHIFT): speed *= 3.0
			pivot.global_position += move_vec.normalized() * _delta * speed

		# Apply Camera Inertia
		if abs(_cam_yaw_vel) > 0.0001 or abs(_cam_pitch_vel) > 0.0001:
			camera_rot.y += _cam_yaw_vel
			camera_rot.x += _cam_pitch_vel
			camera_rot.x = clamp(camera_rot.x, -PI/2.1, PI/2.1)
			_cam_yaw_vel = lerp(_cam_yaw_vel, 0.0, 10.0 * _delta)
			_cam_pitch_vel = lerp(_cam_pitch_vel, 0.0, 10.0 * _delta)

		# Update camera transform based on rot/zoom
		pivot.rotation.y = camera_rot.y
		pivot.rotation.x = camera_rot.x
		camera.position.z = zoom
		camera.position.y = 0
	
		if is_instance_valid(ghost):
			_move_ghost()
	
	if sim_state == "playing":
		_simulate(_delta)
	_tick_autosave(_delta)

# ──────────────────────────── GHOST / PLACEMENT ───────────────────
func _on_item_selected(idx: int):
	if sim_state == "playing":
		comp_list.deselect_all()
		_log("Cannot add components during simulation!", "warning")
		return
	var meta = comp_list.get_item_metadata(idx)
	if meta == null:
		return
	var id := ""
	if typeof(meta) == TYPE_DICTIONARY:
		var kind = str(meta.get("kind", ""))
		if kind == "category":
			comp_list.deselect_all()
			return
		if kind == "component":
			id = str(meta.get("id", ""))
	elif typeof(meta) == TYPE_STRING:
		id = str(meta)

	if id == "":
		return
	if id == "PVC Pipe Frame" or id == "Carbon Fiber Body":
		for c in placed:
			if c.type == "Frame":
				_log("Only one frame allowed!", "error")
				return
	cur_id = id
	_cancel_ghost()
	ghost = _build_mesh(id, true)
	components_group.add_child(ghost)
	_show_snap_hints(id)
	
	# Deselect so it can be clicked again
	comp_list.deselect_all()

func _move_ghost():
	var mpos = viewport.get_mouse_position()
	var ro = camera.project_ray_origin(mpos)
	var rd = camera.project_ray_normal(mpos)
	
	var snap = _find_snap()
	if snap:
		ghost.global_position = snap.pos
		_ghost_tint(Color(0, 1, 0.5, 0.6))
	else:
		# Follow cursor on ground plane
		var plane = Plane(Vector3.UP, 0)
		var hit = plane.intersects_ray(ro, rd)
		if hit == null:
			return
		ghost.global_position = hit + Vector3(0, 0.5, 0)
		_ghost_tint(Color(1, 1, 1, 0.25))
	ghost.rotation.y = ghost_rot

func _find_snap() -> Variant:
	var mpos = viewport.get_mouse_position()
	var ro = camera.project_ray_origin(mpos)
	var rd = camera.project_ray_normal(mpos)
	# Cast ray against MULTIPLE planes at different heights to find snap points
	var best_d := 2.5  # Generous snap distance
	var best = null

	for hint in snap_hints.get_children():
		if not is_instance_valid(hint): continue
		# Cast ray on a plane at the SAME Y height as this hint
		var hint_y = hint.global_position.y
		var h_plane = Plane(Vector3.UP, hint_y)
		var hit = h_plane.intersects_ray(ro, rd)
		if hit == null:
			continue
		# Compare XZ distance only (ignore Y — we snap to the hint's exact Y)
		var dx = hit.x - hint.global_position.x
		var dz = hit.z - hint.global_position.z
		var d = sqrt(dx * dx + dz * dz)
		if d < best_d:
			best_d = d
			best = {
				"pos": hint.global_position, 
				"port": hint.name,
				"parent_uid": hint.get_meta("parent_uid", -1)
			}
	return best

func _show_snap_hints(id: String):
	_clear_children(snap_hints)
	var cdata = COMPONENTS[id]
	# Scan ALL placed components for matching ports
	for comp in placed:
		if not is_instance_valid(comp.get("node")): continue
		var ports = COMPONENTS[comp.id].get("ports", [])
		for port in ports:
			if port.get("slot", false) and port.get("allowed", []).has(cdata.type):
				# Check port not already occupied
				var occupied := false
				for other in placed:
					if other.get("port_name", "") == port.name and other.get("parent_id", -1) == comp.uid:
						occupied = true
						break
				if occupied:
					continue

				var hint = MeshInstance3D.new()
				var torus = TorusMesh.new()
				torus.inner_radius = 0.15
				torus.outer_radius = 0.25
				hint.mesh = torus
				hint.name = port.name
				# Reuse cached material for all snap hints
				if _snap_hint_mat == null:
					_snap_hint_mat = StandardMaterial3D.new()
					_snap_hint_mat.albedo_color = Color(0, 1, 0.8, 0.7)
					_snap_hint_mat.emission_enabled = true
					_snap_hint_mat.emission = Color(0, 1, 0.8)
					_snap_hint_mat.emission_energy_multiplier = 2.0
					_snap_hint_mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
				hint.material_override = _snap_hint_mat
				snap_hints.add_child(hint)
				hint.global_position = comp.node.global_transform * port.pos
				hint.set_meta("parent_uid", comp.uid)

func _cancel_ghost():
	if ghost:
		ghost.queue_free()
		ghost = null
	_clear_children(snap_hints)
	ghost_rot = 0.0
	# If we were moving an existing component and cancelled, restore it with same UID.
	if _moving_component_uid != -1 and not _moving_component_snapshot.is_empty():
		_place(
			_moving_component_snapshot.id,
			_moving_component_snapshot.pos,
			_moving_component_snapshot.get("port_name", ""),
			_moving_component_snapshot.get("parent_id", -1),
			_moving_component_uid,
			false,
			false
		)
		_moving_component_uid = -1
		_moving_component_snapshot.clear()

func _ghost_tint(c: Color):
	if not ghost:
		return
	for ch in ghost.get_children():
		if not is_instance_valid(ch): continue
		if ch is MeshInstance3D and ch.material_override:
			ch.material_override.albedo_color = c
		# Handle nested children from OBJ imports
		for sub in ch.get_children():
			if is_instance_valid(sub) and sub is MeshInstance3D and sub.material_override:
				sub.material_override.albedo_color = c

# ──────────────────────────── PLACE & WIRE ────────────────────────
func _place(id: String, pos: Vector3, port_name: String = "", parent_uid: int = -1, forced_uid: int = -1, push_undo_entry := true, auto_wire := true):
	var node = _build_mesh(id, false)

	var uid = forced_uid
	if uid == -1:
		_uid_counter += 1
		uid = _uid_counter  # Monotonic unique ID (no tick collision risk)
	else:
		_uid_counter = max(_uid_counter, uid)
	var cdata = COMPONENTS[id]
	var entry := {
		"uid": uid, "id": id, "type": cdata.type,
		"node": node, "port_name": port_name,
		"parent_id": parent_uid,
	}

	# Link hierarchy
	if parent_uid != -1:
		for p in placed:
			if p.uid == parent_uid:
				p.node.add_child(node)
				node.global_position = pos
				break
	else:
		components_group.add_child(node)
		node.global_position = pos

	placed.append(entry)
	# Push to undo stack
	var pos_vec = node.global_position
	if push_undo_entry:
		_push_undo("place", {"uid": uid, "id": id, "pos_x": pos_vec.x, "pos_y": pos_vec.y, "pos_z": pos_vec.z, "port_name": port_name, "parent_id": parent_uid})
	if auto_wire:
		_auto_wire_component(entry)
	_rebuild_wires()
	_update_all()
	if tabs.current_tab < tabs.get_tab_count() and tabs.get_tab_title(tabs.current_tab) == "Wiring":
		_refresh_wiring_view()
	_log("Assembled: " + id, "success")

func _pick_existing():
	var mpos = viewport.get_mouse_position()
	var ro = camera.project_ray_origin(mpos)
	var rd = camera.project_ray_normal(mpos)
	
	var best_uid := -1
	var best_d := 1000.0
	
	for c in placed:
		if not is_instance_valid(c.node): continue
		if c.type == "Frame": continue # Don't pick frame
		# check if ray passes near the node
		var to_node = c.node.global_position - ro
		var projection = to_node.dot(rd)
		if projection > 0:
			var closest_point = ro + rd * projection
			var dist = closest_point.distance_to(c.node.global_position)
			if dist < 1.0 and dist < best_d:
				best_d = dist
				best_uid = c.uid
	
	if best_uid != -1:
		# Find the entry
		for i in range(placed.size()):
			if placed[i].uid == best_uid:
				var c = placed[i]
				cur_id = c.id
				_moving_component_uid = c.uid
				_moving_component_snapshot = {
					"id": c.id,
					"pos": c.node.global_position,
					"port_name": c.get("port_name", ""),
					"parent_id": c.get("parent_id", -1),
				}
				c.node.queue_free()
				placed.remove_at(i)
				_rebuild_wires()
				_update_all()
				# Convert to ghost
				ghost = _build_mesh(cur_id, true)
				components_group.add_child(ghost)
				ghost.global_position = _moving_component_snapshot.pos
				_show_snap_hints(cur_id)
				_log("Picking up: " + cur_id, "info")
				return

func _rebuild_wires():
	if sim_state == "playing":
		return # Block wiring changes during simulation
	_clear_children(wires_group)
	# Find frame center for wiring hub
	var center = Vector3.ZERO
	var frame_node = null
	for f in placed:
		if is_instance_valid(f.get("node")) and f.type == "Frame":
			frame_node = f.node
			center = f.node.global_position + Vector3(0, 1.2, 0)
			break
	if not is_instance_valid(frame_node): return
	# Draw wires from each motor to the center hub
	for c in placed:
		if is_instance_valid(c.get("node")) and c.type == "Motor" and c.get("port_name", "") != "":
			_add_wire(c.node.global_position, center)

func _add_wire(from: Vector3, to: Vector3):
	if sim_state == "playing":
		return # Block adding wires during simulation
	var dist = from.distance_to(to)
	if dist < 0.1:
		return
	# Build a curved wire using multiple segments
	var wire_root = Node3D.new()
	var segments = 8
	var sag = max(0.1, dist * 0.15)
	var mid = (from + to) / 2.0
	mid.y -= sag
	# Simple 3-point curve
	for i in range(segments):
		var t0 = float(i) / segments
		var t1 = float(i + 1) / segments
		var p0 = _bezier3(from, mid, to, t0)
		var p1 = _bezier3(from, mid, to, t1)
		var seg_dist = p0.distance_to(p1)
		var cyl = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		cm.top_radius = 0.03
		cm.bottom_radius = 0.03
		cm.height = seg_dist
		cyl.mesh = cm
		# Reuse cached wire material
		if _wire_mat == null:
			_wire_mat = StandardMaterial3D.new()
			_wire_mat.albedo_color = Color(0.1, 0.1, 0.1)
			_wire_mat.metallic = 0.3
		cyl.material_override = _wire_mat
		wire_root.add_child(cyl)
		cyl.look_at_from_position((p0 + p1) / 2.0, p1, Vector3.UP)
		cyl.rotate_object_local(Vector3.RIGHT, PI / 2)
	wires_group.add_child(wire_root)

func _bezier3(a: Vector3, b: Vector3, c: Vector3, t: float) -> Vector3:
	var ab = a.lerp(b, t)
	var bc = b.lerp(c, t)
	return ab.lerp(bc, t)

# ──────────────────────────── BUILD MESH ──────────────────────────
func _build_mesh(id: String, is_ghost: bool) -> Node3D:
	var cdata = COMPONENTS[id]
	var root = Node3D.new()

	# Check if this component uses an OBJ model file
	if cdata.get("use_obj", false):
		_build_frame_from_obj(root, cdata)
	else:
		match cdata.type:
			"Frame":
				_build_frame_procedural(root)
			"Motor":
				_build_motor(root)
			"Propeller":
				_build_propeller(root)
			"Battery":
				_build_battery(root)
			"PDB":
				_build_pdb(root)
			"BEC":
				_build_bec(root)
			"FC":
				_build_fc(root)
			"ESC":
				_build_esc(root)
			"RX":
				_build_rx(root)
			"GPS":
				_build_gps(root)
			"Camera":
				_build_fpv_camera(root)
			"VTX":
				_build_vtx(root)
			_:
				var m = MeshInstance3D.new()
				m.mesh = BoxMesh.new()
				root.add_child(m)

	var mat = StandardMaterial3D.new()
	if is_ghost:
		mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0, 1, 0.8, 0.3)
	else:
		var raw_c = cdata.color
		# Make it pop even more
		mat.albedo_color = Color(min(raw_c.r * 1.3, 1.0), min(raw_c.g * 1.3, 1.0), min(raw_c.b * 1.3, 1.0))
		mat.metallic = 0.0 # No reflections to avoid black artifacts
		mat.roughness = 0.5 # Balanced matte
		mat.specular = 0.3

	_apply_material_recursive(root, mat)
	return root

func _apply_material_recursive(node: Node, mat: Material):
	for ch in node.get_children():
		if ch is MeshInstance3D:
			ch.material_override = mat
		if ch.get_child_count() > 0:
			_apply_material_recursive(ch, mat)

func _build_frame_from_obj(root: Node3D, cdata: Dictionary):
	# Load the real OBJ model
	var obj_path = cdata.get("obj_path", "")
	var mesh_res = load(obj_path)
	if mesh_res == null:
		_log("Failed to load OBJ: " + obj_path + ", using procedural frame", "warning")
		_build_frame_procedural(root)
		return

	var mi = MeshInstance3D.new()
	mi.mesh = mesh_res
	mi.scale = Vector3(OBJ_SCALE, OBJ_SCALE, OBJ_SCALE) 
	root.add_child(mi)

	_log("Loaded PVC Pipe Frame from OBJ model", "info")

func _build_frame_procedural(root: Node3D):
	var arm_mat = StandardMaterial3D.new()
	arm_mat.albedo_color = Color(0.18, 0.18, 0.18)
	arm_mat.metallic = 0.3
	arm_mat.roughness = 0.5

	# 4 diagonal arms
	for i in range(4):
		var arm = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(4.5, 0.4, 0.4) 
		arm.mesh = bm
		arm.material_override = arm_mat
		root.add_child(arm)
		var angle = PI / 4.0 + i * PI / 2.0
		arm.rotation.y = angle
		arm.position = Vector3(cos(angle) * 2, 0.75, -sin(angle) * 2)

		# Motor mount at tip
		var mount = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		cm.top_radius = 0.45
		cm.bottom_radius = 0.45
		cm.height = 0.2
		mount.mesh = cm
		mount.material_override = arm_mat
		root.add_child(mount)
		mount.position = Vector3(cos(angle) * 4, 0.85, -sin(angle) * 4)

	# Top plate (main chassis)
	var top = MeshInstance3D.new()
	top.mesh = BoxMesh.new()
	top.mesh.size = Vector3(2.6, 0.15, 5.0) 
	top.position.y = 1.0
	root.add_child(top)

	# Bottom plate
	var bot = MeshInstance3D.new()
	bot.mesh = BoxMesh.new()
	bot.mesh.size = Vector3(2.3, 0.15, 4.5)
	bot.position.y = 0.5
	root.add_child(bot)

	# Landing skids
	for side in [-1.0, 1.0]:
		var runner = MeshInstance3D.new()
		var rcyl = CylinderMesh.new()
		rcyl.top_radius = 0.06
		rcyl.bottom_radius = 0.06
		rcyl.height = 3.5
		runner.mesh = rcyl
		runner.rotation.x = PI / 2
		runner.position = Vector3(side * 1.3, -0.5, 0)
		root.add_child(runner)

	# Status LEDs
	var led_r = MeshInstance3D.new()
	led_r.mesh = BoxMesh.new()
	led_r.mesh.size = Vector3(0.1, 0.05, 0.1)
	var led_mat_r = StandardMaterial3D.new()
	led_mat_r.albedo_color = Color(0.2, 0, 0)
	led_mat_r.emission_enabled = true
	led_mat_r.emission = Color.RED
	led_mat_r.emission_energy_multiplier = 3.0
	led_r.material_override = led_mat_r
	led_r.position = Vector3(0.8, 1.06, 2.0)
	root.add_child(led_r)

	var led_g = MeshInstance3D.new()
	led_g.mesh = BoxMesh.new()
	led_g.mesh.size = Vector3(0.1, 0.05, 0.1)
	var led_mat_g = StandardMaterial3D.new()
	led_mat_g.albedo_color = Color(0, 0.2, 0)
	led_mat_g.emission_enabled = true
	led_mat_g.emission = Color.GREEN
	led_mat_g.emission_energy_multiplier = 3.0
	led_g.material_override = led_mat_g
	led_g.position = Vector3(-0.8, 1.06, 2.0)
	root.add_child(led_g)

	root.position.y = 0.7

func _build_motor(root: Node3D):
	# Stator
	var st = MeshInstance3D.new()
	st.mesh = CylinderMesh.new()
	st.mesh.top_radius = 0.4
	st.mesh.bottom_radius = 0.4
	st.mesh.height = 0.5
	root.add_child(st)
	# Bell/Rotor
	var bell = MeshInstance3D.new()
	bell.mesh = CylinderMesh.new()
	bell.mesh.top_radius = 0.45
	bell.mesh.bottom_radius = 0.45
	bell.mesh.height = 0.2
	bell.position.y = 0.25
	root.add_child(bell)
	# Shaft
	var shaft = MeshInstance3D.new()
	shaft.mesh = CylinderMesh.new()
	shaft.mesh.top_radius = 0.1
	shaft.mesh.bottom_radius = 0.1
	shaft.mesh.height = 0.3
	shaft.position.y = 0.5
	root.add_child(shaft)

func _build_propeller(root: Node3D):
	var blade = MeshInstance3D.new()
	blade.mesh = BoxMesh.new()
	blade.mesh.size = Vector3(4.5, 0.04, 0.25)
	blade.name = "prop_blade"
	root.add_child(blade)
	var hub = MeshInstance3D.new()
	hub.mesh = CylinderMesh.new()
	hub.mesh.top_radius = 0.12
	hub.mesh.bottom_radius = 0.12
	hub.mesh.height = 0.08
	root.add_child(hub)

func _build_battery(root: Node3D):
	var body = MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	body.mesh.size = Vector3(1.0, 0.45, 2.1)
	root.add_child(body)

func _build_pdb(root: Node3D):
	var pcb = MeshInstance3D.new()
	pcb.mesh = BoxMesh.new()
	pcb.mesh.size = Vector3(0.95, 0.05, 0.95)
	root.add_child(pcb)

func _build_bec(root: Node3D):
	var body = MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	body.mesh.size = Vector3(0.7, 0.12, 0.5)
	root.add_child(body)

func _build_fc(root: Node3D):
	var pcb = MeshInstance3D.new()
	pcb.mesh = BoxMesh.new()
	pcb.mesh.size = Vector3(0.82, 0.06, 0.82)
	root.add_child(pcb)

func _build_esc(root: Node3D):
	var body = MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	body.mesh.size = Vector3(0.9, 0.1, 0.95)
	root.add_child(body)

func _build_rx(root: Node3D):
	var board = MeshInstance3D.new()
	board.mesh = BoxMesh.new()
	board.mesh.size = Vector3(0.5, 0.08, 0.45)
	root.add_child(board)
	for s in [-1.0, 1.0]:
		var ant = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		cm.top_radius = 0.015
		cm.bottom_radius = 0.015
		cm.height = 0.5
		ant.mesh = cm
		ant.position = Vector3(0.18 * s, 0.26, -0.15)
		ant.rotation.z = deg_to_rad(35.0 * s)
		root.add_child(ant)

func _build_gps(root: Node3D):
	var module = MeshInstance3D.new()
	module.mesh = BoxMesh.new()
	module.mesh.size = Vector3(0.8, 0.16, 0.8)
	root.add_child(module)
	var mast = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 0.03
	cm.bottom_radius = 0.03
	cm.height = 0.5
	mast.mesh = cm
	mast.position = Vector3(0, -0.28, 0)
	root.add_child(mast)

func _build_fpv_camera(root: Node3D):
	var cam = MeshInstance3D.new()
	cam.mesh = BoxMesh.new()
	cam.mesh.size = Vector3(0.46, 0.38, 0.38)
	root.add_child(cam)
	var lens = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 0.1
	cm.bottom_radius = 0.1
	cm.height = 0.16
	lens.mesh = cm
	lens.position = Vector3(0, 0, -0.24)
	lens.rotation.x = PI / 2
	root.add_child(lens)

func _build_vtx(root: Node3D):
	var board = MeshInstance3D.new()
	board.mesh = BoxMesh.new()
	board.mesh.size = Vector3(0.72, 0.08, 0.58)
	root.add_child(board)
	var ant = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 0.02
	cm.bottom_radius = 0.02
	cm.height = 0.7
	ant.mesh = cm
	ant.position = Vector3(0, 0.42, 0.16)
	root.add_child(ant)

# ──────────────────────────── SIMULATION ──────────────────────────
func _on_play():
	# Resume from pause without restarting
	if sim_state == "paused":
		sim_state = "playing"
		sim_label.text = "Flying..."
		topbar_status.text = "playing"
		_log("Simulation resumed", "info")
		if _bridge_active():
			bridge.cmd_hover()  # Resume bridge
		return

	var check = _preflight_check()
	# Only block play if basic structure is missing
	if check.reason == "No frame" or check.reason == "No battery":
		_log("SYSTEM ERROR: " + check.reason, "error")
		_track_event("simulation_start_blocked", {"reason": check.reason})
		sim_label.text = "ERROR"
		return

	# Lock UI during simulation (all modes)
	_set_ui_locked(true)
	
	# Find the 'start' block and build the sequence
	sim_sequence = []
	var start_block = null
	for child in workspace.get_children():
		if is_instance_valid(child) and "block_type" in child and child.block_type == "start":
			start_block = child
			break
	
	if start_block:
		_parse_block_stack(start_block)
	
	if sim_sequence.size() == 0:
		_log("No sequence to execute. Connect blocks to 'When flag clicked'!", "warning")
		_track_event("simulation_start_blocked", {"reason": "no_sequence"})
		_set_ui_locked(false)
		return

	_log("Executing Flight Plan: " + str(sim_sequence.size()) + " steps", "info")
	_track_event("simulation_started", {"steps": sim_sequence.size(), "bridge": _bridge_active()})
	
	# Initialize simulation state (single init, no duplication)
	sim_state = "playing"
	sim_time = 0.0
	sim_step_idx = 0
	sim_step_timer = 0.0
	sim_target_pos = Vector3.ZERO
	sim_target_rot = Vector3.ZERO
	_estimated_flight_minutes = _estimate_flight_minutes()
	sim_label.text = "Step 1/" + str(sim_sequence.size()) + ": " + sim_sequence[0].type
	topbar_status.text = "playing"
	_prev_leader_pos = components_group.global_position
	_prev_leader_vel = Vector3.ZERO
	if _safety_layer != null:
		_safety_layer.arm(components_group.global_position)
		_safety_layer.set_enabled(_safety_enabled)
	_safety_state = {
		"active": false,
		"mode": "none",
		"reason": "",
		"target": components_group.global_position,
	}
	if _replay_active:
		_replay_active = false
		if _replay_runner != null:
			_replay_runner.stop()
	if _telemetry_recorder != null and not _telemetry_recorder.is_active():
		var start_result = _telemetry_recorder.start_session("drone", _build_telemetry_session_metadata())
		if bool(start_result.get("ok", false)):
			_last_telemetry_csv = str(start_result.get("csv", ""))
			_last_telemetry_manifest = str(start_result.get("manifest", ""))
			_track_event("telemetry_started", {"session": str(start_result.get("session_id", "")), "auto": true})
	
	# ── PhysicsBridge: Configure and arm ──
	if _bridge_active():
		var tw := 0.0
		var tt := 0.0
		var motor_with_prop_count := 0
		
		# Identify all propellers and find their parent motor IDs
		var prop_parents = []
		for c in placed:
			if c.type == "Propeller":
				prop_parents.append(c.parent_id)
		
		for c in placed:
			var d = COMPONENTS[c.id]
			tw += d.weight
			tt += d.thrust
			if d.type == "Motor":
				if c.uid in prop_parents:
					motor_with_prop_count += 1
		
		bridge.cmd_set_drone(tw / 1000.0, motor_with_prop_count, tt / 1000.0 * 9.81)
		bridge.cmd_arm()
		_log("Bridge: Drone configured (%.0fg, %d functional motors) & armed" % [tw, motor_with_prop_count], "info")

func _parse_block_stack(block):
	if not is_instance_valid(block): return
	# Follow Godot hierarchy to find connected blocks
	for child in block.get_children():
		if is_instance_valid(child) and "block_type" in child:
			var val = 0.0
			# STRICT search for Input field only within this block's immediate UI
			var input_node = child.get_node_or_null("input_bg/Input")
				
			if is_instance_valid(input_node) and input_node is LineEdit:
				val = input_node.text.to_float()
				if val <= 0.0: val = 50.0 # Default fallback
			
			# Calculate duration based on distance to maintain constant speed
			var duration = max(1.0, (val * 0.05) / 2.0)
			# Special durations for non-distance blocks
			if child.block_type == "turn_left" or child.block_type == "turn_right":
				duration = max(0.5, val / 90.0)
			elif child.block_type == "set_altitude":
				duration = max(1.0, val / 2.0)
			elif child.block_type == "wait":
				duration = val if val > 0 else 2.0
			elif child.block_type == "take_off":
				duration = 2.0
			elif child.block_type == "land":
				duration = 2.5
			elif child.block_type == "hover":
				duration = 2.0
			
			if child.block_type == "repeat":
				# Repeat: re-run all PREVIOUS steps N times
				var repeat_count = int(val) if val > 0 else 3
				var existing = sim_sequence.duplicate()
				for _i in range(repeat_count - 1):
					sim_sequence.append_array(existing)
			else:
				sim_sequence.append({
					"type": child.block_type,
					"value": val,
					"duration": duration,
					"node_ref": child
				})
			_parse_block_stack(child)

func _on_pause():
	if sim_state == "playing":
		sim_state = "paused"
		sim_label.text = "⏸ Paused (Step " + str(sim_step_idx + 1) + "/" + str(sim_sequence.size()) + ")"
		topbar_status.text = "paused"
		if _bridge_active():
			bridge.cmd_hover()  # Hold position while paused
		_log("Simulation paused", "info")

func _on_stop():
	sim_state = "stopped"
	sim_label.text = "Ready"
	topbar_status.text = "stopped"
	# Reset positions
	components_group.rotation = Vector3.ZERO
	components_group.position = Vector3.ZERO
	sim_step_idx = 0
	# CRITICAL: Rebuild wires at home position to prevent "bulging"
	_rebuild_wires()
	# Stop bridge simulation
	if _bridge_active():
		bridge.cmd_stop()
		_log("Bridge: Simulation stopped & reset", "info")
	_track_event("simulation_stopped", {"elapsed": sim_time})
	if _telemetry_recorder != null and _telemetry_recorder.is_active():
		_telemetry_recorder.stop_session()
		_track_event("telemetry_stopped", {"auto": true})
	if _mission_planner != null:
		_mission_planner.stop()
	_mission_active = false
	if _safety_layer != null:
		_safety_layer.disarm()
	_safety_state = {
		"active": false,
		"mode": "none",
		"reason": "",
		"target": components_group.global_position,
	}
	
	# Unlock UI (all modes)
	_set_ui_locked(false)

func _simulate(delta: float):
	sim_time += delta
	if _simulation_coordinator_service != null:
		var replay_state = _simulation_coordinator_service.handle_replay({
			"replay_active": _replay_active,
			"replay_runner": _replay_runner,
			"sim_time": sim_time,
			"current_pos": components_group.global_position,
		})
		if bool(replay_state.get("handled", false)):
			components_group.global_position = replay_state.get("position", components_group.global_position)
			var look_dir: Vector3 = replay_state.get("look_dir", Vector3.ZERO)
			if look_dir.length() > 0.01:
				components_group.look_at(components_group.global_position + look_dir, Vector3.UP)
			if bool(replay_state.get("done", false)):
				_track_event("replay_completed")
			_replay_active = bool(replay_state.get("replay_active", _replay_active))
			_update_swarm_and_telemetry(delta)
			_update_diagnostics()
			return
	elif _replay_active and _replay_runner != null:
		var replay = _replay_runner.sample(sim_time)
		if bool(replay.get("ok", false)):
			var row: Dictionary = replay.get("row", {})
			components_group.global_position = row.get("position", components_group.global_position)
			var rv: Vector3 = row.get("velocity", Vector3.ZERO)
			if rv.length() > 0.01:
				components_group.look_at(components_group.global_position + rv.normalized(), Vector3.UP)
		if bool(replay.get("done", false)):
			_replay_active = false
			_track_event("replay_completed")
		_update_swarm_and_telemetry(delta)
		_update_diagnostics()
		return
	_sample_environment(delta)
	var check = _preflight_check()
	if _simulation_coordinator_service != null:
		var safety_rt = _simulation_coordinator_service.apply_safety({
			"safety_layer": _safety_layer,
			"delta": delta,
			"current_pos": components_group.global_position,
			"sim_target_pos": sim_target_pos,
			"battery_ratio": _estimate_remaining_battery_ratio(sim_time),
			"sensor_health": float(_sensor_state.get("health", 1.0)),
			"mission_active": _mission_active,
			"mission_planner": _mission_planner,
			"safety_state": _safety_state,
		})
		_safety_state = safety_rt.get("safety_state", _safety_state)
		sim_target_pos = safety_rt.get("sim_target_pos", sim_target_pos)
		_mission_active = bool(safety_rt.get("mission_active", _mission_active))
		if bool(safety_rt.get("triggered", false)):
			_log("Safety trigger: %s" % str(safety_rt.get("trigger_reason", "unknown")), "warning")
			_track_event("safety_triggered", {
				"mode": str(safety_rt.get("trigger_mode", "none")),
				"reason": str(safety_rt.get("trigger_reason", "unknown")),
			})
	elif _safety_layer != null:
		var battery_ratio = _estimate_remaining_battery_ratio(sim_time)
		var sensor_health = float(_sensor_state.get("health", 1.0))
		var previous_active = bool(_safety_state.get("active", false))
		_safety_state = _safety_layer.update(
			delta,
			components_group.global_position,
			sim_target_pos,
			battery_ratio,
			sensor_health
		)
		if bool(_safety_state.get("active", false)):
			sim_target_pos = _safety_state.get("target", sim_target_pos)
			if _mission_active and _mission_planner != null:
				_mission_planner.stop()
				_mission_active = false
			if not previous_active:
				_log("Safety trigger: %s" % str(_safety_state.get("reason", "unknown")), "warning")
				_track_event("safety_triggered", {
					"mode": str(_safety_state.get("mode", "none")),
					"reason": str(_safety_state.get("reason", "unknown")),
				})
	
	# Live step progress indicator
	if sim_step_idx < sim_sequence.size():
		if _simulation_coordinator_service != null:
			var step_label = _simulation_coordinator_service.build_step_label(sim_step_idx, sim_sequence, sim_step_timer)
			if step_label != "":
				sim_label.text = step_label
		else:
			var step = sim_sequence[sim_step_idx]
			var pct = int((sim_step_timer / max(step.duration, 0.01)) * 100.0)
			sim_label.text = "Step %d/%d: %s (%d%%)" % [sim_step_idx + 1, sim_sequence.size(), step.type, min(pct, 100)]

	# 1. Propeller Spin — use bridge RPMs if available
	if sim_state == "playing":
		var bridge_rpms = []
		if _bridge_active():
			bridge_rpms = bridge.get_motor_rpms()
		if _simulation_coordinator_service != null:
			_simulation_coordinator_service.spin_propellers({
				"delta": delta,
				"placed": placed,
				"bridge_rpms": bridge_rpms,
			})
		else:
			var prop_idx := 0
			for comp in placed:
				if is_instance_valid(comp.get("node")) and comp.type == "Propeller":
					for ch in comp.node.get_children():
						if is_instance_valid(ch) and ch.name == "prop_blade":
							var spin_speed := 35.0
							if prop_idx < bridge_rpms.size() and bridge_rpms[prop_idx] > 0:
								spin_speed = bridge_rpms[prop_idx] / 150.0  # Increased multiplier for realism
							ch.rotation.y += delta * spin_speed
							prop_idx += 1

	if _simulation_coordinator_service != null:
		var route = _simulation_coordinator_service.decide_simulation_path({
			"capability": str(check.get("capability", "")),
			"bridge_active": _bridge_active(),
			"use_bridge_physics": use_bridge_physics,
			"current_pos": components_group.position,
			"safety_state": _safety_state,
		})
		var route_mode = str(route.get("mode", "kinematic"))
		if route_mode == "settle":
			components_group.position = route.get("position", components_group.position)
			_update_swarm_and_telemetry(delta)
			return
		if route_mode == "bridge":
			if bool(route.get("force_land", false)):
				bridge.cmd_land()
			_simulate_bridge(delta)
			_update_swarm_and_telemetry(delta)
			_update_diagnostics()  # Live diagnostics during sim
			return
		_simulate_kinematic(delta, check)
		_update_swarm_and_telemetry(delta)
		_update_diagnostics()  # Live diagnostics during sim
		return
	elif check.capability == "Cannot fly" and not _bridge_active():
		components_group.position.y = lerp(components_group.position.y, 0.0, 0.08)
		_update_swarm_and_telemetry(delta)
		return

	# ── BRIDGE PHYSICS MODE ──
	if _bridge_active() and use_bridge_physics:
		if bool(_safety_state.get("active", false)) and str(_safety_state.get("mode", "none")) == "land":
			bridge.cmd_land()
		_simulate_bridge(delta)
		_update_swarm_and_telemetry(delta)
		_update_diagnostics()  # Live diagnostics during sim
		return

	# ── KINEMATIC FALLBACK MODE ──
	_simulate_kinematic(delta, check)
	_update_swarm_and_telemetry(delta)
	_update_diagnostics()  # Live diagnostics during sim

func _bridge_active() -> bool:
	"""Check if bridge is available and connected."""
	return bridge != null and bridge_connected and is_instance_valid(bridge)

func _simulate_bridge(delta: float):
	"""Simulation driven by real physics from bridge (Gazebo/standalone)."""
	# Step processing: send commands to bridge based on block sequence
	if sim_state == "playing" and sim_step_idx < sim_sequence.size():
		var step = sim_sequence[sim_step_idx]
		sim_step_timer += delta
		
		# Send bridge commands only when step starts or changes
		if sim_step_timer <= delta * 2:  # First frame of step
			if _simulation_coordinator_service != null:
				var action = _simulation_coordinator_service.build_bridge_step_start_action({
					"sim_step_timer": sim_step_timer,
					"delta": delta,
					"step_type": str(step.type),
					"step_value": float(step.value),
					"step_duration": float(step.duration),
					"forward_basis_z": components_group.global_transform.basis.z,
				})
				if bool(action.get("has_action", false)):
					var cmd = str(action.get("command", ""))
					match cmd:
						"takeoff":
							bridge.cmd_takeoff(float(action.get("height", 2.5)))
						"move":
							bridge.cmd_move(float(action.get("vx", 0.0)), float(action.get("vy", 0.0)), float(action.get("vz", 0.0)))
						"hover":
							bridge.cmd_hover()
						"land":
							bridge.cmd_land()
					var log_line = str(action.get("log", ""))
					if log_line != "":
						_log(log_line, "info")
			else:
				match step.type:
					"take_off":
						bridge.cmd_takeoff(2.5)
						_log("Bridge → Takeoff to 2.5m", "info")
					"forward":
						var speed = step.value * 0.05 / step.duration
						var fwd = -components_group.global_transform.basis.z.normalized()
						fwd.y = 0; fwd = fwd.normalized()
						bridge.cmd_move(fwd.x * speed, 0.0, fwd.z * speed)
						_log("Bridge → Move forward %.1f cm (%.2f m/s)" % [step.value, speed], "info")
					"hover":
						bridge.cmd_hover()
						_log("Bridge → Hover", "info")
					"land":
						bridge.cmd_land()
						_log("Bridge → Land", "info")

		if _simulation_coordinator_service != null:
			var advance_rt = _simulation_coordinator_service.advance_step_state({
				"sim_step_idx": sim_step_idx,
				"sim_step_timer": sim_step_timer,
				"sim_sequence": sim_sequence,
				"sim_time": sim_time,
				"completion_suffix": " — hovering",
			})
			sim_step_idx = int(advance_rt.get("sim_step_idx", sim_step_idx))
			sim_step_timer = float(advance_rt.get("sim_step_timer", sim_step_timer))
			if bool(advance_rt.get("advanced", false)):
				if bool(advance_rt.get("has_next", false)):
					_log(str(advance_rt.get("next_step_log", "")), "info")
				elif bool(advance_rt.get("completed", false)):
					bridge.cmd_hover()  # Hold position after program ends
					_log(str(advance_rt.get("completion_log", "✓ Flight plan completed")), "success")
					sim_label.text = str(advance_rt.get("finished_label", "✓ Finished"))
		elif sim_step_timer >= step.duration:
			sim_step_idx += 1
			sim_step_timer = 0.0
			if sim_step_idx < sim_sequence.size():
				var next_step = sim_sequence[sim_step_idx]
				_log("Step %d/%d: %s" % [sim_step_idx + 1, sim_sequence.size(), next_step.type], "info")
			else:
				bridge.cmd_hover()  # Hold position after program ends
				_log("✓ Flight plan completed (%.1fs) — hovering" % sim_time, "success")
				sim_label.text = "✓ Finished (" + str(sim_sequence.size()) + " steps)"

	# Position/rotation update happens in _on_bridge_state callback

func _on_bridge_state(state: Dictionary):
	# Update sim diagnostics in paused mode
	if sim_state == "paused":
		_update_diagnostics()
	"""Callback: apply physics state from bridge to the 3D drone visual."""
	if sim_state != "playing" and sim_state != "paused":
		return
	
	var pos_arr = state.get("pos", [0, 0, 0])
	var rot_arr = state.get("rot", [0, 0, 0, 1])
	
	# Apply position from physics engine
	var target_pos = Vector3(pos_arr[0], pos_arr[1], pos_arr[2])
	target_pos += _env_state.get("wind", Vector3.ZERO) * 0.05
	components_group.position = components_group.position.lerp(target_pos, 0.3)
	
	# Apply quaternion rotation from physics engine
	var quat = Quaternion(rot_arr[0], rot_arr[1], rot_arr[2], rot_arr[3])
	var target_euler = quat.get_euler()
	target_euler += _env_state.get("emi", Vector3.ZERO) * 0.06
	components_group.rotation = components_group.rotation.lerp(target_euler, 0.3)
	
	# Update status display
	var status_text = state.get("status", "unknown")
	if sim_state == "playing":
		sim_label.text = status_text.capitalize()

func _simulate_kinematic(delta: float, check: Dictionary):
	"""Original kinematic simulation as fallback when bridge is not connected."""
	var current_vel = (components_group.global_position - _prev_leader_pos) / max(delta, 0.0001)
	if _mission_active and _mission_planner != null:
		if _mission_runtime_service != null:
			var mission_rt = _mission_runtime_service.update_mission({
				"mission_active": _mission_active,
				"mission_planner": _mission_planner,
				"current_pos": components_group.global_position,
				"current_vel": current_vel,
				"delta": delta,
				"safety_state": _safety_state,
				"sim_target_pos": sim_target_pos,
			})
			_mission_active = bool(mission_rt.get("mission_active", _mission_active))
			sim_target_pos = mission_rt.get("sim_target_pos", sim_target_pos)
			var status_text = str(mission_rt.get("status_text", ""))
			if status_text != "":
				sim_label.text = status_text
			if bool(mission_rt.get("completed", false)):
				var rth_used = bool(mission_rt.get("rth_used", false))
				_log("Autonomous mission completed" + (" (RTH branch)" if rth_used else ""), "success")
				_track_event("mission_completed")
		else:
			var mission = _mission_planner.compute_target(
				components_group.global_position,
				current_vel,
				delta,
				{
					"geofence_breached": str(_safety_state.get("reason", "")) == "geofence_breach",
				}
			)
			if bool(mission.get("active", false)):
				sim_target_pos = mission.get("predicted", sim_target_pos)
				var mode = str(mission.get("mode", _mission_planner.mode()))
				sim_label.text = "AUTO %s %d/%d" % [mode.to_upper(), _mission_planner.current_index() + 1, _mission_planner.waypoint_count()]
			elif bool(mission.get("completed", false)):
				_mission_active = false
				var rth_used = bool(mission.get("rth_used", false))
				_log("Autonomous mission completed" + (" (RTH branch)" if rth_used else ""), "success")
				_track_event("mission_completed")

	# 2. Logic Step Processing
	if sim_state == "playing" and sim_step_idx < sim_sequence.size():
		var step = sim_sequence[sim_step_idx]
		sim_step_timer += delta

		if _simulation_coordinator_service != null:
			var step_rt = _simulation_coordinator_service.apply_kinematic_step_action({
				"step_type": str(step.type),
				"step_value": float(step.value),
				"step_duration": float(step.duration),
				"delta": delta,
				"sim_target_pos": sim_target_pos,
				"sim_target_rot": sim_target_rot,
				"basis_x": components_group.global_transform.basis.x,
				"basis_z": components_group.global_transform.basis.z,
			})
			sim_target_pos = step_rt.get("sim_target_pos", sim_target_pos)
			sim_target_rot = step_rt.get("sim_target_rot", sim_target_rot)
		else:
			match step.type:
				"take_off":
					sim_target_pos.y = 2.5
				"forward":
					var target_dist = step.value * 0.05
					var forward_dir = -components_group.global_transform.basis.z
					forward_dir.y = 0
					forward_dir = forward_dir.normalized()
					sim_target_pos += forward_dir * target_dist * (delta / step.duration)
					if sim_target_pos.y < 2.0: sim_target_pos.y = 2.5
				"backward":
					var target_dist = step.value * 0.05
					var back_dir = components_group.global_transform.basis.z
					back_dir.y = 0
					back_dir = back_dir.normalized()
					sim_target_pos += back_dir * target_dist * (delta / step.duration)
					if sim_target_pos.y < 2.0: sim_target_pos.y = 2.5
				"move_left":
					var target_dist = step.value * 0.05
					var left_dir = -components_group.global_transform.basis.x
					left_dir.y = 0
					left_dir = left_dir.normalized()
					sim_target_pos += left_dir * target_dist * (delta / step.duration)
					if sim_target_pos.y < 2.0: sim_target_pos.y = 2.5
				"move_right":
					var target_dist = step.value * 0.05
					var right_dir = components_group.global_transform.basis.x
					right_dir.y = 0
					right_dir = right_dir.normalized()
					sim_target_pos += right_dir * target_dist * (delta / step.duration)
					if sim_target_pos.y < 2.0: sim_target_pos.y = 2.5
				"turn_left":
					var angle_total = deg_to_rad(step.value)
					sim_target_rot.y += angle_total * (delta / step.duration)
				"turn_right":
					var angle_total = deg_to_rad(step.value)
					sim_target_rot.y -= angle_total * (delta / step.duration)
				"set_altitude":
					sim_target_pos.y = step.value
				"hover", "wait":
					pass
				"land":
					sim_target_pos.y = 0.0
		
		if _simulation_coordinator_service != null:
			var advance_rt = _simulation_coordinator_service.advance_step_state({
				"sim_step_idx": sim_step_idx,
				"sim_step_timer": sim_step_timer,
				"sim_sequence": sim_sequence,
				"sim_time": sim_time,
			})
			sim_step_idx = int(advance_rt.get("sim_step_idx", sim_step_idx))
			sim_step_timer = float(advance_rt.get("sim_step_timer", sim_step_timer))
			if bool(advance_rt.get("advanced", false)):
				if bool(advance_rt.get("has_next", false)):
					var next_step: Dictionary = advance_rt.get("next_step", {})
					_log(str(advance_rt.get("next_step_log", "")), "info")
					_highlight_block(next_step)
				elif bool(advance_rt.get("completed", false)):
					_clear_block_highlights()
					_log(str(advance_rt.get("completion_log", "✓ Flight plan completed")), "success")
					sim_label.text = str(advance_rt.get("finished_label", "✓ Finished"))
		elif sim_step_timer >= step.duration:
			sim_step_idx += 1
			sim_step_timer = 0.0
			if sim_step_idx < sim_sequence.size():
				var next_step = sim_sequence[sim_step_idx]
				_log("Step %d/%d: %s" % [sim_step_idx + 1, sim_sequence.size(), next_step.type], "info")
				_highlight_block(next_step)
			else:
				_clear_block_highlights()
				_log("✓ Flight plan completed (%.1fs)" % sim_time, "success")
				sim_label.text = "✓ Finished (" + str(sim_sequence.size()) + " steps)"

	# 3. Physics & Visuals
	var final_target = sim_target_pos
	if check.capability == "Cannot fly":
		final_target.y = 0.0
	var wind = _env_state.get("wind", Vector3.ZERO)
	if _flight_assist_service != null:
		final_target = _flight_assist_service.apply_control_mode(
			_flight_control_mode,
			final_target,
			wind,
			delta,
			sim_sequence,
			sim_step_idx,
			components_group.position,
			sim_target_pos
		)
	else:
		match _flight_control_mode:
			CTRL_MODE_ADAPTIVE_HOVER:
				final_target += wind * delta * 0.18
				if sim_sequence.size() == 0 or (sim_step_idx < sim_sequence.size() and (sim_sequence[sim_step_idx].type == "hover" or sim_sequence[sim_step_idx].type == "wait")):
					final_target = final_target.lerp(Vector3(components_group.position.x, sim_target_pos.y, components_group.position.z), 0.35)
			CTRL_MODE_AUTO_MISSION:
				final_target += wind * delta * 0.30
			_:
				final_target += wind * delta * 0.45
	
	components_group.position = components_group.position.lerp(final_target, 0.05)
	
	# Apply yaw rotation from turn blocks
	components_group.rotation.y = lerp(components_group.rotation.y, sim_target_rot.y, 0.1)
	
	# DYNAMIC TILT: Drone must pitch DOWN to go forward
	var displacement = (sim_target_pos - components_group.position)
	var dynamic_pitch = clamp(displacement.z * 0.3, -0.3, 0.3)
	var dynamic_roll = clamp(-displacement.x * 0.3, -0.3, 0.3)
	
	var tilt_x = check.tilt_x * 0.2 + dynamic_pitch + sin(sim_time*1.5)*0.01
	var tilt_z = check.tilt_z * 0.2 + dynamic_roll + cos(sim_time*1.5)*0.01
	tilt_x += _env_state.get("emi", Vector3.ZERO).x * 0.04
	tilt_z += _env_state.get("emi", Vector3.ZERO).z * 0.04
	
	components_group.rotation.x = lerp(components_group.rotation.x, tilt_x, 0.1)
	components_group.rotation.z = lerp(components_group.rotation.z, tilt_z, 0.1)

func _preflight_check() -> Dictionary:
	var motors_with_props = []
	var motors_total = 0
	var has_frame := false
	var has_battery := false

	# O(n) pre-build prop parent lookup
	var prop_parent_uids := {}
	for c in placed:
		if c.type == "Propeller":
			prop_parent_uids[c.parent_id] = true

	for c in placed:
		var c_type = c["type"]
		if c_type == "Frame": has_frame = true
		elif c_type == "Battery": has_battery = true
		elif c_type == "Motor":
			motors_total += 1
			if c.uid in prop_parent_uids:
				motors_with_props.append(c)

	if not has_frame:
		return {"capability": "Cannot fly", "reason": "No frame", "tilt_x": 0, "tilt_z": 0}
	if not has_battery:
		return {"capability": "Cannot fly", "reason": "No battery", "tilt_x": 0, "tilt_z": 0}
	if motors_with_props.size() == 0:
		return {"capability": "Cannot fly", "reason": "No motors with props", "tilt_x": 0, "tilt_z": 0}

	# Real Physics: Each motor provides lift at its position
	# Calculate total net force and torque
	var total_lift := motors_with_props.size()
	var torque_x := 0.0
	var torque_z := 0.0
	
	for m in motors_with_props:
		if is_instance_valid(m.node):
			# Use LOCAL position for torque calculation
			var lpos = m.node.position 
			torque_x += lpos.z * 0.5
			torque_z -= lpos.x * 0.5

	var tilt_x = torque_x / max(total_lift, 1)
	var tilt_z = torque_z / max(total_lift, 1)

	var cap = "Stable"
	if motors_with_props.size() < 4:
		cap = "Unstable"
		if motors_with_props.size() < 2:
			return {"capability": "Cannot fly", "reason": "Asymmetric lift", "tilt_x": tilt_x, "tilt_z": tilt_z}
	
	if abs(tilt_x) > 1.0 or abs(tilt_z) > 1.0:
		cap = "Unstable"

	return {"capability": cap, "reason": "", "tilt_x": tilt_x, "tilt_z": tilt_z}

# ──────────────────────────── UPDATE UI ───────────────────────────
func _update_all():
	var tw := 0.0
	var tt := 0.0
	var bat_cap := 0
	for c in placed:
		var d = COMPONENTS[c.id]
		tw += d.weight
		tt += d.thrust
		bat_cap += d.get("capacity", 0)

	weight_val.text = "%.1f g" % tw
	thrust_val.text = "%.2f kg" % (tt / 1000.0)
	var ratio = (tt / tw) if tw > 0 else 0.0
	twr_val.text = "%.2f:1" % ratio

	# Capability badge
	if ratio >= 2.0:
		cap_val.text = "Good"
		cap_val.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
	elif ratio >= 1.5:
		cap_val.text = "Marginal"
		cap_val.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
	else:
		cap_val.text = "N/A"
		cap_val.remove_theme_color_override("font_color")

	bat_val.text = str(bat_cap) + " mAh"
	var ft_min = _estimate_flight_minutes()
	ft_val.text = "%.1f min" % ft_min

	comp_count.text = "  Components: " + str(placed.size())

	# Diagnostics
	_update_diagnostics()

	# Hierarchy tree sync
	hier_tree.clear()
	var root_item = hier_tree.create_item()
	root_item.set_text(0, "Drone")
	# root_item.set_icon(0, preload("res://icon_chip.png")) # If we had one
	
	for c in placed:
		if not is_instance_valid(c.get("node")): continue
		var item = hier_tree.create_item(root_item)
		item.set_text(0, c.id)
		item.set_metadata(0, c.uid)
		# item.set_icon(0, preload("res://icon_box.png")) # If we had one

func _on_hier_item_selected():
	var item = hier_tree.get_selected()
	if item:
		var uid = item.get_metadata(0)
		_highlight_component(uid)
		_update_properties(uid)
		_log("Selected: " + item.get_text(0), "info")

func _highlight_component(uid: int):
	for c in placed:
		if c.uid == uid:
			var node = c.node
			# Create a temporary pulse animation
			var tween = create_tween()
			
			# Attempt to find meshes and pulse their emission
			for child in node.get_children():
				if child is MeshInstance3D:
					var mat = child.material_override
					if mat:
						var base_scale: Vector3 = child.scale
						tween.tween_property(mat, "emission_enabled", true, 0)
						tween.tween_property(mat, "emission", Color(0, 0.8, 1), 0.2)
						tween.tween_property(mat, "emission_energy_multiplier", 10.0, 0.2)
						tween.parallel().tween_property(child, "scale", base_scale * 1.08, 0.2)
						tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.4)
						tween.parallel().tween_property(child, "scale", base_scale, 0.4)
						tween.tween_property(mat, "emission_enabled", false, 0)
						# Keep explicit reset without reconnecting duplicate finished signal.
						tween.tween_callback(_restore_mesh_scale.bind(weakref(child), base_scale))
			return

func _restore_mesh_scale(mesh_ref: WeakRef, target_scale: Vector3):
	var mesh: Node3D = mesh_ref.get_ref() as Node3D
	if is_instance_valid(mesh):
		mesh.scale = target_scale

func _remove_selected():
	if sim_state == "playing":
		_log("Cannot remove components during simulation!", "warning")
		return
	var item = hier_tree.get_selected()
	if item and item.get_parent(): # Don't delete root
		var uid = item.get_metadata(0)
		_remove_component(uid)

func _remove_component(uid: int):
	var found_idx = -1
	for i in range(placed.size()):
		if placed[i].uid == uid:
			found_idx = i
			break
	
	if found_idx != -1:
		var comp = placed[found_idx]
		if comp.type == "Frame":
			_remove_main_frame_and_dependents(comp.id)
			return
			
		_log("Removed: " + comp.id, "warning")
		# Push to undo stack
		var pos_vec = comp.node.global_position if is_instance_valid(comp.node) else Vector3.ZERO
		_push_undo("remove", {"uid": comp.uid, "id": comp.id, "pos_x": pos_vec.x, "pos_y": pos_vec.y, "pos_z": pos_vec.z, "port_name": comp.get("port_name", ""), "parent_id": comp.get("parent_id", -1)})
		comp.node.queue_free()
		placed.remove_at(found_idx)
		_prune_invalid_wiring_connections()
		
		_rebuild_wires()
		_update_all()
		if tabs.current_tab < tabs.get_tab_count() and tabs.get_tab_title(tabs.current_tab) == "Wiring":
			_refresh_wiring_view()
	else:
		_log("Nothing selected to delete", "info")

func _remove_main_frame_and_dependents(frame_id: String):
	_cancel_ghost()
	for c in placed:
		if is_instance_valid(c.get("node")):
			c.node.queue_free()
	placed.clear()
	_selected_uid = -1
	_clear_children(wires_group)
	_clear_wiring_connections()
	_update_all()
	if tabs.current_tab < tabs.get_tab_count() and tabs.get_tab_title(tabs.current_tab) == "Wiring":
		_refresh_wiring_view()
	_log("Removed main frame (%s) and cleared assembly. You can place a new frame now." % frame_id, "warning")

func _run_guided_remediation():
	if sim_state == "playing":
		_log("Cannot run remediation during simulation", "warning")
		return
	for c in placed:
		if c.type == "Frame" or c.type == "Propeller":
			continue
		_auto_wire_component(c)
	_prune_invalid_wiring_connections()
	if tabs.current_tab < tabs.get_tab_count() and tabs.get_tab_title(tabs.current_tab) == "Wiring":
		_refresh_wiring_view()
	_update_all()
	_log("Guided remediation applied (common wiring fixes)", "success")
	_track_event("guided_remediation_applied", {"connections": wiring_connections.size()})

func _update_diagnostics():
	var issues: Array[Dictionary] = []
	if _diagnostics_service != null:
		issues = _diagnostics_service.build_issues({
			"diag_error": DIAG_SEV_ERROR,
			"diag_warning": DIAG_SEV_WARNING,
			"diag_info": DIAG_SEV_INFO,
			"placed": placed,
			"sim_state": sim_state,
			"sim_time": sim_time,
			"sim_step_idx": sim_step_idx,
			"sim_sequence": sim_sequence,
			"position": components_group.position,
			"wiring_issues": _check_wiring_for_preflight(),
			"env_state": _env_state,
			"swarm_enabled": _swarm_enabled,
			"swarm_count": _swarm_controller.follower_count() if _swarm_controller != null else 0,
			"swarm_behavior": _swarm_behavior,
			"telemetry_active": _telemetry_recorder != null and _telemetry_recorder.is_active(),
			"low_hardware_mode": _low_hardware_mode,
			"mission_active": _mission_active,
			"mission_mode": _mission_planner.mode() if _mission_planner != null else "n/a",
			"flight_control_mode": _flight_control_mode,
			"replay_active": _replay_active,
			"sensor_health": float(_sensor_state.get("health", 1.0)),
			"safety_enabled": _safety_enabled,
			"battery_ratio": _estimate_remaining_battery_ratio(sim_time),
			"safety_state": _safety_state,
		})
		diag_text.text = _format_diagnostics(issues)
		return

	issues.append(_diag_issue(DIAG_SEV_WARNING, "Diagnostics service unavailable", "Reload services or restart app"))
	diag_text.text = _format_diagnostics(issues)

func _estimate_flight_minutes() -> float:
	var total_thrust := 0.0
	var battery_capacity := 0
	for c in placed:
		var d = COMPONENTS[c.id]
		total_thrust += float(d.get("thrust", 0.0))
		battery_capacity += int(d.get("capacity", 0))
	if battery_capacity <= 0:
		return 0.0
	var draw_a = total_thrust * 0.001 * 30.0
	if draw_a <= 0.0:
		return 0.0
	return (float(battery_capacity) / 1000.0) * 60.0 / draw_a

func _estimate_remaining_battery_ratio(elapsed_sec: float) -> float:
	var total_minutes = _estimated_flight_minutes
	if total_minutes <= 0.0:
		total_minutes = _estimate_flight_minutes()
	if total_minutes <= 0.0:
		return 0.0
	return clamp(1.0 - (elapsed_sec / (total_minutes * 60.0)), 0.0, 1.0)

# ──────────────────────────── UTILS ───────────────────────────────
func _clear_children(n: Node):
	if not is_instance_valid(n): return
	for c in n.get_children():
		if is_instance_valid(c):
			c.queue_free()

# ──────────────────────────── TOAST & HIGHLIGHT ───────────────────────
var _active_highlighted_block: Control = null

func _highlight_block(step_data: Dictionary):
	_clear_block_highlights()
	if step_data.has("node_ref") and is_instance_valid(step_data.node_ref):
		_active_highlighted_block = step_data.node_ref
		var bg = _active_highlighted_block.get_node_or_null("bg")
		if bg:
			var sb = bg.get_theme_stylebox("panel").duplicate()
			sb.border_width_left = 3
			sb.border_width_right = 3
			sb.border_width_top = 3
			sb.border_width_bottom = 3
			sb.border_color = Color(1.0, 0.9, 0.2, 1.0)
			bg.add_theme_stylebox_override("panel", sb)

func _clear_block_highlights():
	if is_instance_valid(_active_highlighted_block):
		var bg = _active_highlighted_block.get_node_or_null("bg")
		if bg:
			bg.remove_theme_stylebox_override("panel")
	_active_highlighted_block = null

func _show_toast(msg: String, type: String = "info"):
	var toast = PanelContainer.new()
	toast.top_level = true
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.z_index = 100
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	if type == "error": sb.bg_color = Color(0.6, 0.1, 0.1, 0.9)
	elif type == "success": sb.bg_color = Color(0.1, 0.5, 0.2, 0.9)
	elif type == "warning": sb.bg_color = Color(0.6, 0.4, 0.1, 0.9)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	toast.add_theme_stylebox_override("panel", sb)
	
	var lbl = Label.new()
	lbl.text = msg
	lbl.add_theme_font_size_override("font_size", 13)
	toast.add_child(lbl)
	
	add_child(toast)
	var vp_size = get_viewport_rect().size
	toast.custom_minimum_size = Vector2(300, 40)
	toast.position = Vector2(vp_size.x / 2 - 150, vp_size.y - 80)
	toast.modulate.a = 0.0
	
	var tw = create_tween()
	tw.tween_property(toast, "modulate:a", 1.0, 0.2)
	tw.tween_property(toast, "position:y", toast.position.y - 30, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.5)
	tw.tween_property(toast, "modulate:a", 0.0, 0.5)
	tw.tween_callback(toast.queue_free)

# ──────────────────────────── LOGGING ─────────────────────────────
func _log(msg: String, type: String = "info"):
	var c = "#aaa"
	match type:
		"success": c = "#4caf50"
		"error": c = "#f44336"
		"warning": c = "#ff9800"
		
	var t = Time.get_time_string_from_system()
	if is_instance_valid(log_box):
		log_box.append_text("[color=%s][%s] %s[/color]\n" % [c, t, msg])
		# Auto-trim log to prevent unbounded growth
		if log_box.get_line_count() > MAX_LOG_LINES:
			var full = log_box.get_parsed_text()
			var lines = full.split("\n")
			if lines.size() > MAX_LOG_LINES:
				var trimmed = "\n".join(lines.slice(lines.size() - MAX_LOG_LINES))
				log_box.clear()
				log_box.append_text(trimmed)
	
	if type == "success" or type == "error":
		_show_toast(msg, type)

func _set_ui_locked(locked: bool):
	"""Lock/unlock all component manipulation UI during simulation."""
	comp_list.visible = !locked  # Hide instead of disable for cleaner UX
	hier_del_btn.disabled = locked
	for btn in toolbox_v.get_children():
		if btn is Button: btn.disabled = locked
	if locked:
		_cancel_ghost()
		_log("UI locked during simulation", "info")
	else:
		comp_list.visible = true

# ──────────────────────────── WIRING SCREEN (TODO #4) ─────────────
func _setup_wiring_tab():
	if not is_instance_valid(tabs): return
	
	wiring_graph = GraphEdit.new()
	wiring_graph.name = "Wiring" # Keep name 'Wiring' so tab logic works
	wiring_graph.right_disconnects = true
	wiring_graph.connection_lines_curvature = 0.5
	wiring_graph.minimap_enabled = true
	wiring_graph.snapping_distance = 20
	wiring_graph.snapping_enabled = true
	
	# Add custom theme for professional look
	var bg_sb = StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.1, 0.1, 0.12)
	wiring_graph.add_theme_stylebox_override("panel", bg_sb)
	
	tabs.add_child(wiring_graph)
	
	# Handle Connections
	wiring_graph.connection_request.connect(_on_graph_connection_request)
	wiring_graph.disconnection_request.connect(_on_graph_disconnection_request)
	
	tabs.tab_changed.connect(func(tab_idx):
		if tabs.get_tab_title(tab_idx) == "Wiring":
			_refresh_wiring_view()
	)

func _get_pin_color(type: int) -> Color:
	match type:
		0: return Color(0.9, 0.2, 0.2) # VCC
		1: return Color(0.1, 0.1, 0.1) # GND
		2: return Color(0.9, 0.8, 0.2) # PWM
		3: return Color(0.2, 0.4, 0.9) # Phase
		4: return Color(0.2, 0.8, 0.95) # UART/MSP
		5: return Color(0.7, 0.35, 0.95) # SBUS/CRSF
		6: return Color(0.95, 0.45, 0.2) # VIDEO
	return Color(1, 1, 1)

func _find_first_uid_by_type(comp_type: String) -> int:
	for c in placed:
		if c.type == comp_type and is_instance_valid(c.get("node")):
			return c.uid
	return -1

func _get_comp_type_by_uid_int(uid: int) -> String:
	for c in placed:
		if c.uid == uid:
			return c.type
	return ""

func _find_power_source_uid() -> int:
	var pdb_uid = _find_first_uid_by_type("PDB")
	if pdb_uid != -1:
		return pdb_uid
	var bec_uid = _find_first_uid_by_type("BEC")
	if bec_uid != -1:
		return bec_uid
	return _find_first_uid_by_type("Battery")

func _wiring_connection_exists(from_uid: int, from_port: int, to_uid: int, to_port: int) -> bool:
	var from_id = str(from_uid)
	var to_id = str(to_uid)
	for w in wiring_connections:
		if w.from_node == from_id and w.from_port == from_port and w.to_node == to_id and w.to_port == to_port:
			return true
	return false

func _append_wiring_connection(from_uid: int, from_port: int, to_uid: int, to_port: int):
	if from_uid == -1 or to_uid == -1:
		return
	if from_port < 0 or to_port < 0:
		return
	if _wiring_connection_exists(from_uid, from_port, to_uid, to_port):
		return
	var conn = {
		"from_node": str(from_uid),
		"from_port": from_port,
		"to_node": str(to_uid),
		"to_port": to_port,
	}
	if is_instance_valid(wiring_graph) and wiring_graph.has_node(conn.from_node) and wiring_graph.has_node(conn.to_node):
		var from_gnode := wiring_graph.get_node(conn.from_node) as GraphNode
		var to_gnode := wiring_graph.get_node(conn.to_node) as GraphNode
		if not _is_valid_graph_connection(from_gnode, from_port, to_gnode, to_port):
			return
		if _get_graph_output_type(from_gnode, from_port) != _get_graph_input_type(to_gnode, to_port):
			return
		if not wiring_graph.is_node_connected(StringName(conn.from_node), from_port, StringName(conn.to_node), to_port):
			wiring_graph.connect_node(StringName(conn.from_node), from_port, StringName(conn.to_node), to_port)
	wiring_connections.append(conn)

func _find_free_fc_pwm_port(fc_uid: int) -> int:
	for port in [2, 3, 4, 5]:
		var used = false
		for w in wiring_connections:
			if w.from_node == str(fc_uid) and w.from_port == port:
				used = true
				break
		if not used:
			return port
	return 2

func _find_free_esc_motor_port(esc_uid: int) -> int:
	for port in [0, 1, 2, 3]:
		var used = false
		for w in wiring_connections:
			if w.from_node == str(esc_uid) and w.from_port == port:
				used = true
				break
		if not used:
			return port
	return -1

func _auto_power_connection_to(target_uid: int, target_power_port: int = 0, target_gnd_port: int = 1):
	var src_uid = _find_power_source_uid()
	if src_uid == -1:
		return
	var src_type = _get_comp_type_by_uid_int(src_uid)
	match src_type:
		"PDB":
			_append_wiring_connection(src_uid, 6, target_uid, target_power_port)
			_append_wiring_connection(src_uid, 7, target_uid, target_gnd_port)
		"BEC":
			_append_wiring_connection(src_uid, 2, target_uid, target_power_port)
			_append_wiring_connection(src_uid, 3, target_uid, target_gnd_port)
		"Battery":
			_append_wiring_connection(src_uid, 0, target_uid, target_power_port)
			_append_wiring_connection(src_uid, 1, target_uid, target_gnd_port)

func _auto_wire_component(entry: Dictionary):
	if not entry.has("type"):
		return
	var uid = entry.uid
	var ctype = entry.type

	var battery_uid = _find_first_uid_by_type("Battery")
	var esc_uid = _find_first_uid_by_type("ESC")
	var fc_uid = _find_first_uid_by_type("FC")
	var pdb_uid = _find_first_uid_by_type("PDB")
	var bec_uid = _find_first_uid_by_type("BEC")
	var rx_uid = _find_first_uid_by_type("RX")
	var gps_uid = _find_first_uid_by_type("GPS")
	var cam_uid = _find_first_uid_by_type("Camera")
	var vtx_uid = _find_first_uid_by_type("VTX")

	match ctype:
		"Battery":
			if pdb_uid != -1:
				_append_wiring_connection(uid, 0, pdb_uid, 0)
				_append_wiring_connection(uid, 1, pdb_uid, 1)
			if bec_uid != -1:
				_append_wiring_connection(uid, 0, bec_uid, 0)
				_append_wiring_connection(uid, 1, bec_uid, 1)
			if esc_uid != -1:
				_append_wiring_connection(uid, 0, esc_uid, 0)
				_append_wiring_connection(uid, 1, esc_uid, 1)
			if fc_uid != -1:
				_append_wiring_connection(uid, 0, fc_uid, 0)
				_append_wiring_connection(uid, 1, fc_uid, 1)
		"PDB":
			if battery_uid != -1:
				_append_wiring_connection(battery_uid, 0, uid, 0)
				_append_wiring_connection(battery_uid, 1, uid, 1)
			if esc_uid != -1:
				_append_wiring_connection(uid, 2, esc_uid, 0)
				_append_wiring_connection(uid, 3, esc_uid, 1)
			if fc_uid != -1:
				_append_wiring_connection(uid, 4, fc_uid, 0)
				_append_wiring_connection(uid, 5, fc_uid, 1)
			for aux_uid in [rx_uid, gps_uid, cam_uid, vtx_uid]:
				if aux_uid != -1:
					_append_wiring_connection(uid, 6, aux_uid, 0)
					_append_wiring_connection(uid, 7, aux_uid, 1)
		"BEC":
			if battery_uid != -1:
				_append_wiring_connection(battery_uid, 0, uid, 0)
				_append_wiring_connection(battery_uid, 1, uid, 1)
			if fc_uid != -1:
				_append_wiring_connection(uid, 2, fc_uid, 0)
				_append_wiring_connection(uid, 3, fc_uid, 1)
			for aux_uid in [rx_uid, gps_uid, cam_uid, vtx_uid]:
				if aux_uid != -1:
					_append_wiring_connection(uid, 2, aux_uid, 0)
					_append_wiring_connection(uid, 3, aux_uid, 1)
		"ESC":
			if pdb_uid != -1:
				_append_wiring_connection(pdb_uid, 2, uid, 0)
				_append_wiring_connection(pdb_uid, 3, uid, 1)
			elif battery_uid != -1:
				_append_wiring_connection(battery_uid, 0, uid, 0)
				_append_wiring_connection(battery_uid, 1, uid, 1)
			if fc_uid != -1:
				_append_wiring_connection(fc_uid, _find_free_fc_pwm_port(fc_uid), uid, 2)
			# If motors were already placed before ESC, wire them now.
			for c in placed:
				if c.type != "Motor" or not is_instance_valid(c.get("node")):
					continue
				var motor_uid: int = int(c.uid)
				var already_connected := false
				for w in wiring_connections:
					if w.to_node == str(motor_uid) and int(w.to_port) == 0:
						already_connected = true
						break
				if already_connected:
					continue
				var motor_port := _find_free_esc_motor_port(uid)
				if motor_port == -1:
					break
				_append_wiring_connection(uid, motor_port, motor_uid, 0)
		"FC":
			if pdb_uid != -1:
				_append_wiring_connection(pdb_uid, 4, uid, 0)
				_append_wiring_connection(pdb_uid, 5, uid, 1)
			elif bec_uid != -1:
				_append_wiring_connection(bec_uid, 2, uid, 0)
				_append_wiring_connection(bec_uid, 3, uid, 1)
			elif battery_uid != -1:
				_append_wiring_connection(battery_uid, 0, uid, 0)
				_append_wiring_connection(battery_uid, 1, uid, 1)
			if esc_uid != -1:
				_append_wiring_connection(uid, _find_free_fc_pwm_port(uid), esc_uid, 2)
			if rx_uid != -1:
				_append_wiring_connection(rx_uid, 2, uid, 6)
			if gps_uid != -1:
				_append_wiring_connection(gps_uid, 2, uid, 7)
				_append_wiring_connection(uid, 8, gps_uid, 3)
			if vtx_uid != -1:
				_append_wiring_connection(uid, 9, vtx_uid, 3)
		"Motor":
			if esc_uid != -1:
				var esc_motor_port := _find_free_esc_motor_port(esc_uid)
				if esc_motor_port != -1:
					_append_wiring_connection(esc_uid, esc_motor_port, uid, 0)
		"RX":
			_auto_power_connection_to(uid, 0, 1)
			if fc_uid != -1:
				_append_wiring_connection(uid, 2, fc_uid, 6)
		"GPS":
			_auto_power_connection_to(uid, 0, 1)
			if fc_uid != -1:
				_append_wiring_connection(uid, 2, fc_uid, 7)
				_append_wiring_connection(fc_uid, 8, uid, 3)
		"Camera":
			_auto_power_connection_to(uid, 0, 1)
			if vtx_uid != -1:
				_append_wiring_connection(uid, 2, vtx_uid, 2)
		"VTX":
			_auto_power_connection_to(uid, 0, 1)
			if cam_uid != -1:
				_append_wiring_connection(cam_uid, 2, uid, 2)
			if fc_uid != -1:
				_append_wiring_connection(fc_uid, 9, uid, 3)

func _prune_invalid_wiring_connections(skip_uid: int = -1):
	var valid := {}
	for c in placed:
		if c.type != "Frame" and c.type != "Propeller":
			valid[str(c.uid)] = true

	for i in range(wiring_connections.size() - 1, -1, -1):
		var w = wiring_connections[i]
		var from_node = w.from_node
		var to_node = w.to_node
		if skip_uid != -1 and (from_node == str(skip_uid) or to_node == str(skip_uid)):
			continue
		if not valid.has(from_node) or not valid.has(to_node):
			wiring_connections.remove_at(i)

func _pick_free_esc_motor_port_from_used(used_ports: PackedInt32Array) -> int:
	for port in [0, 1, 2, 3]:
		if not used_ports.has(port):
			return port
	return -1

func _normalize_esc_motor_connections():
	var normalized: Array[Dictionary] = []
	var seen := {}
	var used_by_esc := {} # esc_uid_str -> PackedInt32Array

	for w in wiring_connections:
		var from_id := str(w.get("from_node", ""))
		var to_id := str(w.get("to_node", ""))
		var from_port := int(w.get("from_port", -1))
		var to_port := int(w.get("to_port", -1))
		if from_id == "" or to_id == "" or from_port < 0 or to_port < 0:
			continue

		var from_uid := int(from_id)
		var to_uid := int(to_id)
		var from_type := _get_comp_type_by_uid_int(from_uid)
		var to_type := _get_comp_type_by_uid_int(to_uid)

		# Normalize reversed legacy direction: Motor -> ESC  ==>  ESC -> Motor
		if from_type == "Motor" and to_type == "ESC":
			var tmp_id := from_id
			from_id = to_id
			to_id = tmp_id
			from_uid = int(from_id)
			to_uid = int(to_id)
			from_type = "ESC"
			to_type = "Motor"
			from_port = to_port
			to_port = 0

		if from_type == "ESC" and to_type == "Motor":
			to_port = 0
			var used_ports: PackedInt32Array = used_by_esc.get(from_id, PackedInt32Array())
			# Migrate legacy slot-based indices (3..6) to GraphEdit output-port indices (0..3).
			if from_port >= 3 and from_port <= 6:
				from_port -= 3
			if from_port < 0 or from_port > 3 or used_ports.has(from_port):
				from_port = _pick_free_esc_motor_port_from_used(used_ports)
				if from_port == -1:
					continue
			used_ports.append(from_port)
			used_by_esc[from_id] = used_ports

		var key := "%s:%d>%s:%d" % [from_id, from_port, to_id, to_port]
		if seen.has(key):
			continue
		seen[key] = true
		normalized.append({
			"from_node": from_id,
			"from_port": from_port,
			"to_node": to_id,
			"to_port": to_port,
		})

	wiring_connections = normalized

func _refresh_wiring_view():
	if not is_instance_valid(wiring_graph): return
	wiring_graph.clear_connections()
	_prune_invalid_wiring_connections(_moving_component_uid)
	_normalize_esc_motor_connections()
	
	var had_old_nodes := false
	for child in wiring_graph.get_children():
		if child is GraphNode:
			had_old_nodes = true
			child.queue_free()
	# Wait until deferred frees are applied to avoid name/slot conflicts on rebuild.
	if had_old_nodes:
		await get_tree().process_frame
	
	if placed.size() == 0:
		return
	
	var x_offset := 60.0
	var y_offset := 40.0
	var col_width := 250.0
	var row_height := 180.0
	var comp_idx := 0
	var cols := 3
	
	# Create Nodes
	for comp in placed:
		if not is_instance_valid(comp.get("node")): continue
		if comp.type == "Frame" or comp.type == "Propeller": continue
		var cdata = COMPONENTS[comp.id]
		
		var col = comp_idx % cols
		var row = comp_idx / cols
		var bx = x_offset + col * col_width
		var by = y_offset + row * row_height
		
		var gnode = GraphNode.new()
		gnode.name = str(comp.uid)
		gnode.title = comp.id
		gnode.position_offset = Vector2(bx, by)
		gnode.set_meta("input_types", PackedInt32Array())
		gnode.set_meta("output_types", PackedInt32Array())
		
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(cdata.color.r * 0.4, cdata.color.g * 0.4, cdata.color.b * 0.4, 0.9)
		sb.corner_radius_top_left = 4
		sb.corner_radius_top_right = 4
		gnode.add_theme_stylebox_override("titlebar", sb)
		
		var port_idx := 0
		match cdata.type:
			"Battery":
				_add_graph_port(gnode, port_idx, "Outputs", false, 0, true, 0, _get_pin_color(0), _get_pin_color(0))
				port_idx += 1
				_add_graph_port(gnode, port_idx, "", false, 0, true, 1, _get_pin_color(1), _get_pin_color(1))
			"PDB":
				_add_graph_port(gnode, port_idx, "BAT +", true, 0, false, 0, _get_pin_color(0), Color())
				port_idx += 1
				_add_graph_port(gnode, port_idx, "BAT -", true, 1, false, 0, _get_pin_color(1), Color())
				port_idx += 1
				_add_graph_port(gnode, port_idx, "ESC +", false, 0, true, 0, Color(), _get_pin_color(0))
				port_idx += 1
				_add_graph_port(gnode, port_idx, "ESC -", false, 0, true, 1, Color(), _get_pin_color(1))
				port_idx += 1
				_add_graph_port(gnode, port_idx, "FC 5V", false, 0, true, 0, Color(), _get_pin_color(0))
				port_idx += 1
				_add_graph_port(gnode, port_idx, "FC GND", false, 0, true, 1, Color(), _get_pin_color(1))
				port_idx += 1
				_add_graph_port(gnode, port_idx, "AUX 5V", false, 0, true, 0, Color(), _get_pin_color(0))
				port_idx += 1
				_add_graph_port(gnode, port_idx, "AUX GND", false, 0, true, 1, Color(), _get_pin_color(1))
			"BEC":
				_add_graph_port(gnode, port_idx, "VIN +", true, 0, false, 0, _get_pin_color(0), Color())
				port_idx += 1
				_add_graph_port(gnode, port_idx, "VIN -", true, 1, false, 0, _get_pin_color(1), Color())
				port_idx += 1
				_add_graph_port(gnode, port_idx, "5V OUT", false, 0, true, 0, Color(), _get_pin_color(0))
				port_idx += 1
				_add_graph_port(gnode, port_idx, "GND OUT", false, 0, true, 1, Color(), _get_pin_color(1))
			"ESC":
				_add_graph_port(gnode, port_idx, "Power In", true, 0, false, 0, _get_pin_color(0), Color())
				port_idx+=1
				_add_graph_port(gnode, port_idx, "GND In", true, 1, false, 0, _get_pin_color(1), Color())
				port_idx+=1
				_add_graph_port(gnode, port_idx, "PWM In", true, 2, false, 0, _get_pin_color(2), Color())
				port_idx+=1
				_add_graph_port(gnode, port_idx, "Motor 1", false, 0, true, 3, Color(), _get_pin_color(3))
				port_idx+=1
				_add_graph_port(gnode, port_idx, "Motor 2", false, 0, true, 3, Color(), _get_pin_color(3))
				port_idx+=1
				_add_graph_port(gnode, port_idx, "Motor 3", false, 0, true, 3, Color(), _get_pin_color(3))
				port_idx+=1
				_add_graph_port(gnode, port_idx, "Motor 4", false, 0, true, 3, Color(), _get_pin_color(3))
			COMPONENT_TYPE_FC:
				_add_graph_port(gnode, port_idx, "Power In", true, 0, false, 0, _get_pin_color(0), Color())
				port_idx+=1
				_add_graph_port(gnode, port_idx, "GND In", true, 1, false, 0, _get_pin_color(1), Color())
				port_idx+=1
				_add_graph_port(gnode, port_idx, "PWM 1", false, 0, true, 2, Color(), _get_pin_color(2))
				port_idx+=1
				_add_graph_port(gnode, port_idx, "PWM 2", false, 0, true, 2, Color(), _get_pin_color(2))
				port_idx+=1
				_add_graph_port(gnode, port_idx, "PWM 3", false, 0, true, 2, Color(), _get_pin_color(2))
				port_idx+=1
				_add_graph_port(gnode, port_idx, "PWM 4", false, 0, true, 2, Color(), _get_pin_color(2))
				port_idx+=1
				_add_graph_port(gnode, port_idx, "SBUS In", true, 5, false, 0, _get_pin_color(5), Color())
				port_idx+=1
				_add_graph_port(gnode, port_idx, "GPS RX", true, 4, false, 0, _get_pin_color(4), Color())
				port_idx+=1
				_add_graph_port(gnode, port_idx, "GPS TX", false, 0, true, 4, Color(), _get_pin_color(4))
				port_idx+=1
				_add_graph_port(gnode, port_idx, "VTX TX", false, 0, true, 4, Color(), _get_pin_color(4))
			"Motor":
				_add_graph_port(gnode, port_idx, "Phase In", true, 3, false, 0, _get_pin_color(3), Color())
			"RX":
				_add_graph_port(gnode, port_idx, "5V", true, 0, false, 0, _get_pin_color(0), Color())
				port_idx+=1
				_add_graph_port(gnode, port_idx, "GND", true, 1, false, 0, _get_pin_color(1), Color())
				port_idx+=1
				_add_graph_port(gnode, port_idx, "SBUS Out", false, 0, true, 5, Color(), _get_pin_color(5))
			"GPS":
				_add_graph_port(gnode, port_idx, "5V", true, 0, false, 0, _get_pin_color(0), Color())
				port_idx+=1
				_add_graph_port(gnode, port_idx, "GND", true, 1, false, 0, _get_pin_color(1), Color())
				port_idx+=1
				_add_graph_port(gnode, port_idx, "TX", false, 0, true, 4, Color(), _get_pin_color(4))
				port_idx+=1
				_add_graph_port(gnode, port_idx, "RX", true, 4, false, 0, _get_pin_color(4), Color())
			"Camera":
				_add_graph_port(gnode, port_idx, "5V", true, 0, false, 0, _get_pin_color(0), Color())
				port_idx+=1
				_add_graph_port(gnode, port_idx, "GND", true, 1, false, 0, _get_pin_color(1), Color())
				port_idx+=1
				_add_graph_port(gnode, port_idx, "Video Out", false, 0, true, 6, Color(), _get_pin_color(6))
			"VTX":
				_add_graph_port(gnode, port_idx, "5V", true, 0, false, 0, _get_pin_color(0), Color())
				port_idx+=1
				_add_graph_port(gnode, port_idx, "GND", true, 1, false, 0, _get_pin_color(1), Color())
				port_idx+=1
				_add_graph_port(gnode, port_idx, "Video In", true, 6, false, 0, _get_pin_color(6), Color())
				port_idx+=1
				_add_graph_port(gnode, port_idx, "SmartAudio", true, 4, false, 0, _get_pin_color(4), Color())
		
		wiring_graph.add_child(gnode)
		comp_idx += 1
	
	# Await 1 frame to let GraphEdit add nodes before connecting
	await get_tree().process_frame

	for w in wiring_connections:
		var from_id := str(w.get("from_node", ""))
		var to_id := str(w.get("to_node", ""))
		var from_port := int(w.get("from_port", -1))
		var to_port := int(w.get("to_port", -1))
		if from_id == "" or to_id == "" or from_port < 0 or to_port < 0:
			continue
		if not wiring_graph.has_node(from_id) or not wiring_graph.has_node(to_id):
			continue
		var from_gnode := wiring_graph.get_node(from_id) as GraphNode
		var to_gnode := wiring_graph.get_node(to_id) as GraphNode
		if not _is_valid_graph_connection(from_gnode, from_port, to_gnode, to_port):
			continue
		var from_type := _get_graph_output_type(from_gnode, from_port)
		var to_type := _get_graph_input_type(to_gnode, to_port)
		if from_type != to_type:
			continue
		if not wiring_graph.is_node_connected(StringName(from_id), from_port, StringName(to_id), to_port):
			wiring_graph.connect_node(StringName(from_id), from_port, StringName(to_id), to_port)

func _get_graph_input_type(node: GraphNode, port: int) -> int:
	var input_types: PackedInt32Array = node.get_meta("input_types", PackedInt32Array())
	if port < 0 or port >= input_types.size():
		return -1
	return input_types[port]

func _get_graph_output_type(node: GraphNode, port: int) -> int:
	var output_types: PackedInt32Array = node.get_meta("output_types", PackedInt32Array())
	if port < 0 or port >= output_types.size():
		return -1
	return output_types[port]

func _is_valid_graph_connection(from_node: GraphNode, from_port: int, to_node: GraphNode, to_port: int) -> bool:
	if not is_instance_valid(from_node) or not is_instance_valid(to_node):
		return false
	if from_port < 0 or to_port < 0:
		return false
	# Connections must always be Output(Right) -> Input(Left) using GraphEdit port-order indices.
	var output_types: PackedInt32Array = from_node.get_meta("output_types", PackedInt32Array())
	var input_types: PackedInt32Array = to_node.get_meta("input_types", PackedInt32Array())
	if from_port >= output_types.size():
		return false
	if to_port >= input_types.size():
		return false
	return true

func _is_wiring_type_allowed(from_type: String, to_type: String) -> bool:
	if from_type == "" or to_type == "":
		return false
	if not WIRING_RULES.has(from_type):
		return false
	return to_type in WIRING_RULES[from_type]

func _add_graph_port(node: GraphNode, idx: int, text: String, left_en: bool, left_type: int, right_en: bool, right_type: int, left_col: Color, right_col: Color):
	var lbl = Label.new()
	lbl.text = "  " + text + "  "
	lbl.add_theme_font_size_override("font_size", 11)
	if right_en and not left_en:
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	node.add_child(lbl)
	node.set_slot(idx, left_en, left_type, left_col, right_en, right_type, right_col)
	var input_types: PackedInt32Array = node.get_meta("input_types", PackedInt32Array())
	var output_types: PackedInt32Array = node.get_meta("output_types", PackedInt32Array())
	if left_en:
		input_types.append(left_type)
	if right_en:
		output_types.append(right_type)
	node.set_meta("input_types", input_types)
	node.set_meta("output_types", output_types)

func _on_graph_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int):
	if sim_state == "playing": return
	
	var enode = wiring_graph.get_node(str(to_node)) as GraphNode
	var snode = wiring_graph.get_node(str(from_node)) as GraphNode
	if not is_instance_valid(enode) or not is_instance_valid(snode):
		_log("Invalid wiring endpoint selected", "warning")
		return

	var src_node: StringName = from_node
	var src_port: int = from_port
	var src_gnode: GraphNode = snode
	var dst_node: StringName = to_node
	var dst_port: int = to_port
	var dst_gnode: GraphNode = enode

	if not _is_valid_graph_connection(src_gnode, src_port, dst_gnode, dst_port):
		# Support dragging either direction by normalizing to Output -> Input.
		if _is_valid_graph_connection(dst_gnode, dst_port, src_gnode, src_port):
			var tmp_node := src_node
			var tmp_port := src_port
			var tmp_gnode := src_gnode
			src_node = dst_node
			src_port = dst_port
			src_gnode = dst_gnode
			dst_node = tmp_node
			dst_port = tmp_port
			dst_gnode = tmp_gnode
		else:
			_log("Invalid pin direction. Connect from output pin to input pin.", "error")
			return

	if wiring_graph.is_node_connected(src_node, src_port, dst_node, dst_port):
		return

	var src_comp_type = _get_comp_type_by_uid(str(src_node))
	var dst_comp_type = _get_comp_type_by_uid(str(dst_node))
	if not _is_wiring_type_allowed(src_comp_type, dst_comp_type):
		_log("Invalid wiring rule: %s cannot connect to %s" % [src_comp_type, dst_comp_type], "error")
		_track_event("wiring_connection_rejected", {"reason": "type_rule", "from": src_comp_type, "to": dst_comp_type})
		return

	var from_type = _get_graph_output_type(src_gnode, src_port)
	var to_type = _get_graph_input_type(dst_gnode, dst_port)
	
	if from_type != to_type:
		_log("Pin type mismatch! (Use matching colors)", "error")
		_track_event("wiring_connection_rejected", {"reason": "pin_type_mismatch", "from_port": src_port, "to_port": dst_port})
		return
		
	for w in wiring_connections:
		if w.from_node == str(src_node) and int(w.from_port) == src_port and w.to_node == str(dst_node) and int(w.to_port) == dst_port:
			return
			
	wiring_graph.connect_node(src_node, src_port, dst_node, dst_port)
	wiring_connections.append({
		"from_node": str(src_node),
		"from_port": src_port,
		"to_node": str(dst_node),
		"to_port": dst_port
	})
	_log("Wired nodes successfully", "success")
	_track_event("wiring_connected", {"from": str(src_node), "to": str(dst_node)})

func _on_graph_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int):
	if sim_state == "playing": return
		
	wiring_graph.disconnect_node(from_node, from_port, to_node, to_port)
	for i in range(wiring_connections.size() - 1, -1, -1):
		var w = wiring_connections[i]
		if w.from_node == str(from_node) and w.from_port == from_port and w.to_node == str(to_node) and w.to_port == to_port:
			wiring_connections.remove_at(i)
			_log("Disconnected wire", "info")
			break

func _clear_wiring_connections():
	wiring_connections.clear()
	_refresh_wiring_view()
	_log("All wiring connections cleared", "warning")

# ──────────────────────────── SAVE / LOAD ─────────────────────────
func _init_autosave():
	var mk_err = DirAccess.make_dir_recursive_absolute(AUTOSAVE_DIR)
	if mk_err != OK and mk_err != ERR_ALREADY_EXISTS:
		_log("Failed to initialize autosave directory", "warning")
	if FileAccess.file_exists(AUTOSAVE_LATEST_PATH):
		_log("Autosave snapshot available", "info")
		_maybe_prompt_restore_autosave()

func _tick_autosave(delta: float):
	if not _autosave_enabled:
		return
	_autosave_timer += delta
	if _autosave_timer < AUTOSAVE_INTERVAL_SEC:
		return
	_autosave_timer = 0.0

	var data = _build_project_data()
	var sig = hash(JSON.stringify(data))
	if not _autosave_bootstrapped:
		_autosave_bootstrapped = true
		_autosave_last_hash = sig
		return
	if sig == _autosave_last_hash:
		return
	if _write_project_file(AUTOSAVE_LATEST_PATH, data, false):
		_autosave_last_hash = sig
		_write_snapshot_copy(data)

func _write_snapshot_copy(data: Dictionary):
	var dt = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var snapshot_path = AUTOSAVE_DIR + "/snapshot_" + dt + ".flyntic"
	_write_project_file(snapshot_path, data, false)

	var dir = DirAccess.open(AUTOSAVE_DIR)
	if dir == null:
		return
	var snapshots: Array[String] = []
	dir.list_dir_begin()
	var name = dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.begins_with("snapshot_") and name.ends_with(".flyntic"):
			snapshots.append(name)
		name = dir.get_next()
	dir.list_dir_end()
	snapshots.sort()
	if snapshots.size() > AUTOSAVE_MAX_SNAPSHOTS:
		for i in range(snapshots.size() - AUTOSAVE_MAX_SNAPSHOTS):
			DirAccess.remove_absolute(AUTOSAVE_DIR + "/" + snapshots[i])

func _build_project_data() -> Dictionary:
	var data = {
		"schema_version": PROJECT_SCHEMA_VERSION,
		"saved_at_unix": Time.get_unix_time_from_system(),
		"placed": [],
		"wiring": [],
		"blocks": [],
	}
	for c in placed:
		data.placed.append({
			"id": c.id,
			"uid": c.uid,
			"port_name": c.get("port_name", ""),
			"parent_id": c.get("parent_id", -1),
		})
	for w in wiring_connections:
		data.wiring.append({
			"from_node": str(w.get("from_node", "")),
			"from_port": int(w.get("from_port", 0)),
			"to_node": str(w.get("to_node", "")),
			"to_port": int(w.get("to_port", 0)),
		})
	for child in workspace.get_children():
		if is_instance_valid(child) and "block_type" in child:
			data.blocks.append(_serialize_block(child))
	return data

func _write_project_file(path: String, data: Dictionary, log_success := true) -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_log("Failed to write project: " + path, "error")
		_track_event("project_save_failed", {"path": path})
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	if log_success:
		_log("Project saved: " + path, "success")
		_track_event("project_saved", {"path": path, "components": data.get("placed", []).size()})
	return true

func _normalize_loaded_project(raw_data: Variant) -> Dictionary:
	if typeof(raw_data) != TYPE_DICTIONARY:
		return {}
	var src: Dictionary = raw_data
	var version = int(src.get("schema_version", 1))
	if version > PROJECT_SCHEMA_VERSION:
		_log("Project file is from a newer version. Attempting compatibility load.", "warning")

	var normalized = {
		"schema_version": PROJECT_SCHEMA_VERSION,
		"placed": [],
		"wiring": [],
		"blocks": [],
	}

	for c in src.get("placed", []):
		if typeof(c) != TYPE_DICTIONARY:
			continue
		var cid = str(c.get("id", ""))
		if not COMPONENTS.has(cid):
			continue
		normalized.placed.append({
			"id": cid,
			"uid": int(c.get("uid", -1)),
			"port_name": str(c.get("port_name", "")),
			"parent_id": int(c.get("parent_id", -1)),
		})

	for w in src.get("wiring", []):
		if typeof(w) != TYPE_DICTIONARY:
			continue
		normalized.wiring.append({
			"from_node": str(w.get("from_node", "")),
			"from_port": int(w.get("from_port", 0)),
			"to_node": str(w.get("to_node", "")),
			"to_port": int(w.get("to_port", 0)),
		})

	for b in src.get("blocks", []):
		if typeof(b) == TYPE_DICTIONARY:
			normalized.blocks.append(b)

	if version < PROJECT_SCHEMA_VERSION:
		_log("Upgraded project schema from v%d to v%d" % [version, PROJECT_SCHEMA_VERSION], "info")

	return normalized

func _apply_loaded_project_data(data: Dictionary):
	# Clear current state fully before load
	_cancel_ghost()
	for c in placed:
		if is_instance_valid(c.get("node")):
			c.node.queue_free()
	placed.clear()
	_clear_children(wires_group)
	_selected_uid = -1

	# Resolve frame from saved project (fallback to default)
	var saved_frame_id = "PVC Pipe Frame"
	for c_data in data.get("placed", []):
		if COMPONENTS.has(c_data.id) and COMPONENTS[c_data.id].type == COMPONENT_TYPE_FRAME:
			saved_frame_id = c_data.id
			break
	_place(saved_frame_id, Vector3.ZERO, "", -1, -1, true, false)

	# Reload placed components
	for c_data in data.get("placed", []):
		if COMPONENTS.has(c_data.id) and COMPONENTS[c_data.id].type != COMPONENT_TYPE_FRAME:
			var pos = Vector3.ZERO
			if c_data.parent_id != -1:
				for p in placed:
					if p.uid == c_data.parent_id and is_instance_valid(p.node):
						var ports = COMPONENTS[p.id].get("ports", [])
						for port in ports:
							if port.name == c_data.port_name:
								pos = p.node.global_transform * port.pos
								break
			_place(c_data.id, pos, c_data.get("port_name", ""), c_data.get("parent_id", -1), -1, true, false)

	# Reload blocks
	_clear_children(workspace)
	for b_data in data.get("blocks", []):
		_deserialize_block(b_data, null)

	# Reload wiring
	wiring_connections.clear()
	for w in data.get("wiring", []):
		wiring_connections.append(w)

	_undo_stack.clear()
	_redo_stack.clear()
	_update_all()
	_autosave_last_hash = hash(JSON.stringify(_build_project_data()))
	_autosave_bootstrapped = true

func _save_project():
	var fd = FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.filters = PackedStringArray(["*.flyntic ; Flyntic Project"])
	fd.title = "Save Project"
	add_child(fd)
	fd.file_selected.connect(func(path):
		var data = _build_project_data()
		_write_project_file(path, data, true)
		_autosave_last_hash = hash(JSON.stringify(data))
		_autosave_bootstrapped = true
		fd.queue_free()
	)
	fd.canceled.connect(func(): fd.queue_free())
	fd.popup_centered(Vector2i(600, 400))

func _serialize_block(block) -> Dictionary:
	var d = {"type": block.block_type, "pos_x": block.position.x, "pos_y": block.position.y, "value": ""}
	var input = block.get_node_or_null("input_bg/Input")
	if is_instance_valid(input) and input is LineEdit:
		d.value = input.text
	# Serialize children blocks
	var children = []
	for ch in block.get_children():
		if is_instance_valid(ch) and "block_type" in ch:
			children.append(_serialize_block(ch))
	d["children"] = children
	return d

func _load_project():
	var fd = FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.filters = PackedStringArray(["*.flyntic ; Flyntic Project"])
	fd.title = "Load Project"
	add_child(fd)
	fd.file_selected.connect(func(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if not file:
			_log("Failed to open: " + path, "error")
			fd.queue_free()
			return
		var json_text = file.get_as_text()
		file.close()
		var json = JSON.new()
		if json.parse(json_text) != OK:
			_log("Invalid project file!", "error")
			fd.queue_free()
			return
		var normalized = _normalize_loaded_project(json.data)
		if normalized.is_empty():
			_log("Invalid project schema!", "error")
			_track_event("project_load_failed", {"path": path, "reason": "schema_invalid"})
			fd.queue_free()
			return
		_apply_loaded_project_data(normalized)
		_log("Project loaded: " + path, "success")
		_track_event("project_loaded", {"path": path, "components": normalized.get("placed", []).size()})
		fd.queue_free()
	)
	fd.canceled.connect(func(): fd.queue_free())
	fd.popup_centered(Vector2i(600, 400))

func _deserialize_block(data: Dictionary, parent_block):
	var color = Color(1, 0.7, 0)
	match data.type:
		"start": color = Color(0.85, 0.65, 0)
		"take_off": color = Color(0.3, 0.6, 1.0)
		"forward", "backward", "move_left", "move_right": color = Color(0.25, 0.55, 0.95)
		"turn_left", "turn_right": color = Color(0.4, 0.3, 0.85)
		"set_altitude": color = Color(0.15, 0.6, 0.85)
		"hover": color = Color(0.2, 0.5, 0.9)
		"land": color = Color(0.9, 0.5, 0.1)
		"wait": color = Color(0.85, 0.55, 0.1)
		"repeat": color = Color(0.7, 0.3, 0.7)
	var label = data.type.capitalize().replace("_", " ")
	var pos = Vector2(data.get("pos_x", 50), data.get("pos_y", 50))
	var block = _create_block(data.type, label, color, pos)
	# Set value
	if data.get("value", "") != "":
		var input = block.get_node_or_null("input_bg/Input")
		if is_instance_valid(input) and input is LineEdit:
			input.text = data.value
	# Parent to another block if needed
	if parent_block and is_instance_valid(parent_block):
		workspace.remove_child(block)
		parent_block.add_child(block)
		block.position = Vector2(0, parent_block.size.y)
	# Recurse children
	for ch_data in data.get("children", []):
		_deserialize_block(ch_data, block)

# ──────────────────────────── UNDO / REDO ─────────────────────────
func _push_undo(action: String, data: Dictionary):
	_undo_stack.append({"action": action, "data": data})
	if _undo_stack.size() > MAX_UNDO:
		_undo_stack.pop_front()
	_redo_stack.clear()

func _undo():
	if _undo_stack.size() == 0:
		_log("Nothing to undo", "info")
		return
	var cmd = _undo_stack.pop_back()
	_redo_stack.append(cmd)
	match cmd.action:
		"place":
			_remove_component(cmd.data.uid)
			_log("Undo: removed " + cmd.data.id, "info")
		"remove":
			var d = cmd.data
			_place(d.id, Vector3(d.pos_x, d.pos_y, d.pos_z), d.get("port_name", ""), d.get("parent_id", -1))
			_log("Undo: restored " + d.id, "info")

func _redo():
	if _redo_stack.size() == 0:
		_log("Nothing to redo", "info")
		return
	var cmd = _redo_stack.pop_back()
	_undo_stack.append(cmd)
	match cmd.action:
		"place":
			var d = cmd.data
			_place(d.id, Vector3(d.pos_x, d.pos_y, d.pos_z), d.get("port_name", ""), d.get("parent_id", -1))
			_log("Redo: placed " + d.id, "info")
		"remove":
			_remove_component(cmd.data.uid)
			_log("Redo: removed " + cmd.data.id, "info")

# ──────────────────────────── CAMERA ──────────────────────────────
func _reset_camera():
	camera_rot = Vector2(-0.5, 0.0)
	zoom = 12.0
	pivot.global_position = Vector3.ZERO
	_log("Camera reset", "info")

func _focus_selected():
	if _selected_uid == -1: return
	for c in placed:
		if c.uid == _selected_uid and is_instance_valid(c.node):
			var tween = create_tween()
			tween.tween_property(pivot, "global_position", c.node.global_position, 0.3).set_ease(Tween.EASE_OUT)
			zoom = 6.0
			_log("Focused on: " + c.id, "info")
			return

# ──────────────────────────── PROPERTIES INSPECTOR ────────────────
func _setup_properties_panel():
	"""Create a properties panel at bottom of right sidebar."""
	var right_scroll_v = $Root/Content/CenterRight/Right/Scroll/V
	if not is_instance_valid(right_scroll_v): return
	
	# Properties section header
	var header = Label.new()
	header.text = " 📋 PROPERTIES"
	header.add_theme_font_size_override("font_size", 10)
	header.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	right_scroll_v.add_child(header)
	
	props_panel = Panel.new()
	props_panel.custom_minimum_size = Vector2(0, 120)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.08)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.12, 0.12, 0.15)
	props_panel.add_theme_stylebox_override("panel", sb)
	right_scroll_v.add_child(props_panel)
	
	var vb = VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 4)
	props_panel.add_child(vb)
	
	props_name_lbl = Label.new()
	props_name_lbl.text = "  Select a component"
	props_name_lbl.add_theme_font_size_override("font_size", 11)
	props_name_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	vb.add_child(props_name_lbl)
	
	props_type_lbl = Label.new()
	props_type_lbl.text = "  Type: —"
	props_type_lbl.add_theme_font_size_override("font_size", 10)
	props_type_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	vb.add_child(props_type_lbl)
	
	props_weight_lbl = Label.new()
	props_weight_lbl.text = "  Weight: —"
	props_weight_lbl.add_theme_font_size_override("font_size", 10)
	props_weight_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	vb.add_child(props_weight_lbl)
	
	props_thrust_lbl = Label.new()
	props_thrust_lbl.text = "  Thrust: —"
	props_thrust_lbl.add_theme_font_size_override("font_size", 10)
	props_thrust_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	vb.add_child(props_thrust_lbl)
	
	props_pos_lbl = Label.new()
	props_pos_lbl.text = "  Position: —"
	props_pos_lbl.add_theme_font_size_override("font_size", 10)
	props_pos_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	vb.add_child(props_pos_lbl)

func _update_properties(uid: int):
	_selected_uid = uid
	if not is_instance_valid(props_panel): return
	for c in placed:
		if c.uid == uid:
			var cdata = COMPONENTS[c.id]
			props_name_lbl.text = "  " + c.id
			props_type_lbl.text = "  Type: " + cdata.type
			props_weight_lbl.text = "  Weight: %dg" % cdata.weight
			props_thrust_lbl.text = "  Thrust: %dg" % cdata.thrust
			if is_instance_valid(c.node):
				var p = c.node.global_position
				props_pos_lbl.text = "  Pos: (%.1f, %.1f, %.1f)" % [p.x, p.y, p.z]
			return

# ──────────────────────────── WIRING → PREFLIGHT ──────────────────
func _get_comp_type_by_uid(uid_str: String) -> String:
	var uid = uid_str.to_int()
	for c in placed:
		if c.uid == uid:
			return COMPONENTS[c.id].type
	return ""

func _check_wiring_for_preflight() -> Array[Dictionary]:
	"""Check realistic wiring connections for problems."""
	var issues: Array[Dictionary] = []
	var has_fc := false
	var has_esc := false
	var has_motor := false
	var has_battery := false
	var has_power_source := false # PDB/BEC/Battery
	var has_rx := false
	var has_gps := false
	var has_camera := false
	var has_vtx := false

	for c in placed:
		match c.type:
			"FC": has_fc = true
			"ESC": has_esc = true
			"Motor": has_motor = true
			"Battery": has_battery = true
			"PDB", "BEC": has_power_source = true
			"RX": has_rx = true
			"GPS": has_gps = true
			"Camera": has_camera = true
			"VTX": has_vtx = true

	if has_battery and not has_power_source:
		has_power_source = true

	var esc_to_fc := false
	var motor_to_esc := false
	var power_to_fc := false
	var power_to_esc := false
	var rx_to_fc := false
	var gps_to_fc := false
	var camera_to_vtx := false

	for w in wiring_connections:
		var f_type = _get_comp_type_by_uid(w.from_node)
		var t_type = _get_comp_type_by_uid(w.to_node)

		if (f_type == "ESC" and t_type == COMPONENT_TYPE_FC) or (f_type == COMPONENT_TYPE_FC and t_type == "ESC"):
			esc_to_fc = true
		if (f_type == "ESC" and t_type == "Motor") or (f_type == "Motor" and t_type == "ESC"):
			motor_to_esc = true
		if (f_type == "Battery" and t_type == COMPONENT_TYPE_FC) or (f_type == "PDB" and t_type == COMPONENT_TYPE_FC) or (f_type == "BEC" and t_type == COMPONENT_TYPE_FC):
			power_to_fc = true
		if (f_type == "Battery" and t_type == "ESC") or (f_type == "PDB" and t_type == "ESC"):
			power_to_esc = true
		if (f_type == "RX" and t_type == COMPONENT_TYPE_FC) or (f_type == COMPONENT_TYPE_FC and t_type == "RX"):
			rx_to_fc = true
		if (f_type == "GPS" and t_type == COMPONENT_TYPE_FC) or (f_type == COMPONENT_TYPE_FC and t_type == "GPS"):
			gps_to_fc = true
		if (f_type == "Camera" and t_type == "VTX") or (f_type == "VTX" and t_type == "Camera"):
			camera_to_vtx = true

	if has_fc and not has_esc:
		issues.append(_diag_issue(DIAG_SEV_WARNING, "Missing ESC (FC needs ESC for motor drive)", "Add ESC and connect PWM from FC"))
	if has_esc and not esc_to_fc:
		issues.append(_diag_issue(DIAG_SEV_WARNING, "ESC signal not wired to Flight Controller PWM", "Connect FC PWM output to ESC PWM input"))
	if has_motor and has_esc and not motor_to_esc:
		issues.append(_diag_issue(DIAG_SEV_WARNING, "Motors not wired to ESC motor outputs", "Connect ESC motor ports to each motor phase input"))
	if has_fc and not power_to_fc:
		issues.append(_diag_issue(DIAG_SEV_ERROR, "Flight Controller has no power wiring (Battery/PDB/BEC)", "Provide FC power and GND from Battery/PDB/BEC"))
	if has_esc and not power_to_esc:
		issues.append(_diag_issue(DIAG_SEV_ERROR, "ESC has no battery/PDB power wiring", "Connect ESC power and GND to Battery/PDB"))
	if has_rx and not rx_to_fc:
		issues.append(_diag_issue(DIAG_SEV_WARNING, "Receiver not wired to FC serial/SBUS input", "Connect RX SBUS/CRSF to FC serial input"))
	if has_gps and not gps_to_fc:
		issues.append(_diag_issue(DIAG_SEV_WARNING, "GPS not wired to FC UART", "Wire GPS TX/RX to FC UART RX/TX"))
	if has_camera and has_vtx and not camera_to_vtx:
		issues.append(_diag_issue(DIAG_SEV_WARNING, "FPV Camera video is not wired to VTX", "Connect Camera video output to VTX video input"))
	if has_vtx and not has_camera:
		issues.append(_diag_issue(DIAG_SEV_WARNING, "VTX installed without FPV Camera video source", "Add camera or remove VTX"))
	return issues

# ──────────────────────────── BLOCK DETACH ────────────────────────
func _setup_block_detach():
	"""Allow right-click on blocks to detach from chain."""
	# This is handled via _input — check for right click on blocks
	pass

# ──────────────────────────── REPEAT SUPPORT ──────────────────────
# Override _parse_block_stack is already in the file, but we need repeat support

func _on_window_resized():
	# Use viewport size (not window pixel size) to stay correct under canvas scaling.
	var ws = get_viewport_rect().size
	self.position = Vector2.ZERO
	self.size = ws
	if has_node("Root"):
		var r = $Root
		r.position = Vector2.ZERO
		r.size = ws

	_apply_responsive_layout(ws)

	if is_instance_valid(left_panel):
		if left_panel.custom_minimum_size.x < 130:
			left_panel.custom_minimum_size.x = 130

	if is_instance_valid(right_panel):
		if right_panel.custom_minimum_size.x < 130:
			right_panel.custom_minimum_size.x = 130

	if is_instance_valid(right_scroll):
		right_scroll.offset_left = 10
		right_scroll.offset_top = 6
		right_scroll.offset_right = -10
		right_scroll.offset_bottom = -6

	# Restore left sidebar if collapsed after mode/scale changes.
	if is_instance_valid(content_split) and is_instance_valid(left_panel):
		if left_panel.size.x < 150:
			content_split.split_offset = int(left_panel.custom_minimum_size.x + 20)

	# Restore right sidebar if split was collapsed or pushed out after mode/scale changes.
	if is_instance_valid(center_right_split) and is_instance_valid(right_panel):
		if right_panel.size.x < 120:
			center_right_split.split_offset = -int(right_panel.custom_minimum_size.x)

	if _onboarding_active:
		call_deferred("_onboarding_layout_current_step")

	call_deferred("_sync_canvas_viewport_size")

func _apply_responsive_layout(ws: Vector2):
	var width = max(640.0, ws.x)

	# Scale key columns with viewport width to avoid cramped/overlapping layouts on small displays.
	var left_w = clamp(width * 0.17, 130.0, 240.0)
	var right_w = clamp(width * 0.18, 130.0, 240.0)
	var blocks_sidebar_w = clamp(width * 0.055, 46.0, 70.0)
	var toolbox_w = clamp(width * 0.14, 108.0, 180.0)

	if width < 1100.0:
		right_w = clamp(width * 0.16, 120.0, 190.0)
		toolbox_w = clamp(width * 0.13, 102.0, 160.0)

	if width < 920.0:
		left_w = clamp(width * 0.16, 115.0, 170.0)
		right_w = clamp(width * 0.14, 105.0, 155.0)
		toolbox_w = clamp(width * 0.12, 96.0, 130.0)

	if is_instance_valid(left_panel):
		left_panel.custom_minimum_size.x = left_w
	if is_instance_valid(right_panel):
		right_panel.custom_minimum_size.x = right_w
	if is_instance_valid(blocks_sidebar):
		blocks_sidebar.custom_minimum_size.x = blocks_sidebar_w
	if is_instance_valid(toolbox):
		toolbox.custom_minimum_size.x = toolbox_w

	if is_instance_valid(content_split):
		content_split.split_offset = int(left_w + 20.0)
	if is_instance_valid(center_right_split):
		center_right_split.split_offset = -int(right_w)

func _verify_window_mode():
	var mode = DisplayServer.window_get_mode()
	if mode != DisplayServer.WINDOW_MODE_FULLSCREEN and mode != DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		await get_tree().process_frame
		mode = DisplayServer.window_get_mode()
		if mode != DisplayServer.WINDOW_MODE_FULLSCREEN and mode != DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			_log("Fullscreen is being overridden by host window. In Godot Editor, disable 'Embed Game on Play' (Editor Settings > Run > Window Placement).", "warning")

func _on_canvas_container_resized():
	_sync_canvas_viewport_size()

func _sync_canvas_viewport_size():
	if not is_instance_valid(vpc) or not is_instance_valid(viewport):
		return
	var target = vpc.size.floor()
	if target.x < 2.0 or target.y < 2.0:
		return
	var target_size = Vector2i(int(target.x), int(target.y))
	if viewport.size != target_size:
		viewport.size = target_size
