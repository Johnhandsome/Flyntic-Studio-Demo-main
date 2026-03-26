#!/bin/bash
# ============================================================
# Flyntic Studio — Physics Bridge Startup Script
# ============================================================
# Usage:
#   bash start_bridge.sh              # Auto-detect ROS2/Gazebo
#   bash start_bridge.sh --standalone # Force standalone mode
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"
STANDALONE=false

for arg in "$@"; do
    case $arg in
        --standalone) STANDALONE=true ;;
    esac
done

echo "╔═══════════════════════════════════════════════╗"
echo "║   Flyntic Studio — Physics Bridge             ║"
echo "╚═══════════════════════════════════════════════╝"

# ── Cleanup on exit ──
GZ_PID=""
ROS_BRIDGE_PID=""
BRIDGE_PID=""
cleanup() {
    echo ""
    echo "[*] Shutting down..."
    [ -n "$BRIDGE_PID" ] && kill "$BRIDGE_PID" 2>/dev/null
    [ -n "$GZ_PID" ] && kill "$GZ_PID" 2>/dev/null
    [ -n "$ROS_BRIDGE_PID" ] && kill "$ROS_BRIDGE_PID" 2>/dev/null
    exit 0
}
trap cleanup SIGINT SIGTERM EXIT

# ── Kill any existing bridge on port 9090 ──
echo "[*] Checking for existing bridge on port 9090..."
EXISTING_PID=$(lsof -ti tcp:9090 2>/dev/null || true)
if [ -n "$EXISTING_PID" ]; then
    echo "[!] Killing existing process on port 9090 (PID: $EXISTING_PID)"
    kill -9 $EXISTING_PID 2>/dev/null || true
    sleep 1
fi

# ── Setup Python virtual environment ──
echo "[*] Setting up Python environment..."
if [ ! -d "$VENV_DIR" ]; then
    echo "[*] Creating virtual environment at $VENV_DIR ..."
    python3 -m venv "$VENV_DIR"
fi
source "$VENV_DIR/bin/activate"

echo "[*] Installing Python dependencies..."
pip install -q -r "$SCRIPT_DIR/requirements.txt" 2>&1 | grep -v "already satisfied" || true
echo "[✓] Python environment ready"

# ── Try to source ROS2 ──
ROS2_AVAILABLE=false
if [ "$STANDALONE" = false ]; then
    if [ -f /opt/ros/humble/setup.bash ]; then
        echo "[*] Sourcing ROS2 Humble..."
        source /opt/ros/humble/setup.bash
        ROS2_AVAILABLE=true
    elif [ -f /opt/ros/jazzy/setup.bash ]; then
        echo "[*] Sourcing ROS2 Jazzy..."
        source /opt/ros/jazzy/setup.bash
        ROS2_AVAILABLE=true
    elif [ -f /opt/ros/rolling/setup.bash ]; then
        echo "[*] Sourcing ROS2 Rolling..."
        source /opt/ros/rolling/setup.bash
        ROS2_AVAILABLE=true
    else
        echo "[!] ROS2 not found — will use standalone mode"
    fi
fi

# ── Launch Gazebo if ROS2 available ──
if [ "$ROS2_AVAILABLE" = true ] && [ "$STANDALONE" = false ]; then
    # Check if Gazebo is available
    if command -v gz &> /dev/null; then
        echo "[*] Starting Gazebo Harmonic..."
        export GZ_SIM_RESOURCE_PATH="$SCRIPT_DIR/models:${GZ_SIM_RESOURCE_PATH:-}"

        gz sim -r "$SCRIPT_DIR/worlds/flyntic_world.sdf" &
        GZ_PID=$!
        sleep 3

        # Start ros_gz_bridge if available
        if ros2 pkg list 2>/dev/null | grep -q "ros_gz_bridge"; then
            echo "[*] Starting ros_gz_bridge..."
            ros2 run ros_gz_bridge parameter_bridge \
                /flyntic/cmd_vel@geometry_msgs/msg/Twist@gz.msgs.Twist \
                /flyntic/odom@nav_msgs/msg/Odometry@gz.msgs.Odometry \
                /flyntic/imu@sensor_msgs/msg/Imu@gz.msgs.IMU &
            ROS_BRIDGE_PID=$!
        else
            echo "[!] ros_gz_bridge package not found, skipping"
        fi

        echo "[✓] Gazebo launched (PID: $GZ_PID)"
    else
        echo "[!] Gazebo (gz) not found — using standalone mode"
        STANDALONE=true
    fi
fi

# ── Start the Python TCP bridge ──
echo ""
if [ "$STANDALONE" = true ] || [ "$ROS2_AVAILABLE" = false ]; then
    echo "[*] Starting TCP bridge in STANDALONE mode (built-in physics)..."
    echo "[*] Godot can connect to 127.0.0.1:9090"
    echo ""
    python3 "$SCRIPT_DIR/ros_gz_bridge.py" --standalone &
    BRIDGE_PID=$!
else
    echo "[*] Starting TCP bridge in ROS2 mode..."
    echo "[*] Godot can connect to 127.0.0.1:9090"
    echo ""
    python3 "$SCRIPT_DIR/ros_gz_bridge.py" &
    BRIDGE_PID=$!
fi

# Wait for bridge process
wait $BRIDGE_PID
