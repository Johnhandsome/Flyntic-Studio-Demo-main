#!/usr/bin/env python3
"""
Flyntic Studio — ROS/Gazebo Physics Bridge Server
==================================================
TCP bridge between Godot and Gazebo Harmonic for realistic drone physics.

Modes:
  --standalone   Run with built-in Python physics (no ROS2/Gazebo needed)
  (default)      Attempt ROS2/Gazebo, fallback to standalone if unavailable

Protocol: JSON over TCP, newline-delimited.
"""

import argparse
import json
import math
import os
import select
import socket
import sys
import threading
import time
import traceback
from pathlib import Path

import numpy as np
import yaml

# ─────────────────────────── CONFIG ───────────────────────────────

def load_config():
    cfg_path = Path(__file__).parent / "config.yaml"
    if cfg_path.exists():
        with open(cfg_path) as f:
            return yaml.safe_load(f)
    # Defaults
    return {
        "tcp": {"host": "0.0.0.0", "port": 9090, "max_clients": 4},
        "physics": {"update_rate": 50, "sim_step": 0.002, "gravity": -9.81},
        "drone_defaults": {
            "mass": 0.55, "arm_length": 0.22, "motor_count": 4,
            "max_thrust_per_motor": 4.5, "drag_coefficient": 0.1,
            "angular_drag": 0.3, "inertia_xx": 0.005,
            "inertia_yy": 0.009, "inertia_zz": 0.005,
        },
    }

# ─────────────────────── STANDALONE PHYSICS ───────────────────────

class DronePhysics:
    """
    Simplified rigid-body quadrotor physics for standalone mode.
    Uses Euler integration with substeps for stability.
    """

    def __init__(self, cfg: dict):
        d = cfg.get("drone_defaults", {})
        self.mass = d.get("mass", 0.55)
        self.arm_length = d.get("arm_length", 0.22)
        self.motor_count = d.get("motor_count", 4)
        self.max_thrust = d.get("max_thrust_per_motor", 4.5)
        self.drag_coeff = d.get("drag_coefficient", 0.1)
        self.ang_drag = d.get("angular_drag", 0.3)
        self.gravity = cfg.get("physics", {}).get("gravity", -9.81)
        self.sim_step = cfg.get("physics", {}).get("sim_step", 0.002)

        # Inertia tensor (diagonal)
        self.I = np.array([
            d.get("inertia_xx", 0.005),
            d.get("inertia_yy", 0.009),
            d.get("inertia_zz", 0.005),
        ])

        self.reset()

    def reset(self):
        self.pos = np.array([0.0, 0.0, 0.0])  # x, y(up), z
        self.vel = np.array([0.0, 0.0, 0.0])
        self.rot = np.array([0.0, 0.0, 0.0, 1.0])  # quaternion (x,y,z,w)
        self.ang_vel = np.array([0.0, 0.0, 0.0])
        self.motor_rpms = np.zeros(self.motor_count)
        self.motor_thrusts = np.zeros(self.motor_count)  # 0..1 normalized
        self.armed = False
        self.sim_time = 0.0
        self.status = "idle"

        # PID controllers for autonomous flight
        self._target_altitude = 0.0
        self._target_velocity = np.array([0.0, 0.0, 0.0])
        self._mode = "idle"  # idle, takeoff, hover, move, land
        self._alt_integral = 0.0
        self._alt_prev_error = 0.0

    def configure(self, mass=None, motor_count=None, max_thrust=None):
        if mass is not None:
            self.mass = mass
        if motor_count is not None:
            self.motor_count = max(1, motor_count)
            self.motor_rpms = np.zeros(self.motor_count)
            self.motor_thrusts = np.zeros(self.motor_count)
        if max_thrust is not None:
            self.max_thrust = max_thrust

    def arm(self):
        self.armed = True
        self.status = "armed"

    def disarm(self):
        self.armed = False
        self.motor_thrusts = np.zeros(self.motor_count)
        self.status = "idle"

    def takeoff(self, altitude: float):
        if not self.armed:
            self.arm()
        self._target_altitude = altitude
        self._mode = "takeoff"
        self.status = "taking_off"

    def land(self):
        self._target_altitude = 0.0
        self._mode = "land"
        self.status = "landing"

    def move(self, vx: float, vy: float, vz: float):
        self._target_velocity = np.array([vx, vy, vz])
        self._mode = "move"
        self.status = "flying"

    def hover(self):
        self._target_velocity = np.array([0.0, 0.0, 0.0])
        self._mode = "hover"
        self.status = "hovering"

    def stop(self):
        self.disarm()
        self._mode = "idle"
        self.reset()

    def step(self, dt: float):
        """Advance physics by dt seconds using substeps."""
        if not self.armed:
            return

        n_substeps = max(1, int(dt / self.sim_step))
        sub_dt = dt / n_substeps

        for _ in range(n_substeps):
            self._substep(sub_dt)

        self.sim_time += dt

    def _substep(self, dt: float):
        # ── Autopilot: compute desired motor thrusts ──
        self._run_autopilot(dt)

        # ── Forces ──
        # Gravity
        F_gravity = np.array([0.0, self.gravity * self.mass, 0.0])

        # Total thrust (along body-up axis, rotated by quaternion)
        total_thrust_mag = np.sum(self.motor_thrusts) * self.max_thrust
        body_up = self._quat_rotate(self.rot, np.array([0.0, 1.0, 0.0]))
        F_thrust = body_up * total_thrust_mag

        # Aerodynamic drag
        speed = np.linalg.norm(self.vel)
        if speed > 0.001:
            F_drag = -self.drag_coeff * speed * self.vel
        else:
            F_drag = np.zeros(3)

        # Net force
        F_net = F_gravity + F_thrust + F_drag

        # Linear acceleration & integration
        accel = F_net / self.mass
        self.vel += accel * dt
        self.pos += self.vel * dt

        # ── Torques ──
        torque = np.zeros(3)
        if self.motor_count >= 4:
            # Simplified X-config torque model
            # Motor layout: FL(0), FR(1), BL(2), BR(3)
            L = self.arm_length
            t = self.motor_thrusts * self.max_thrust

            # Roll (x-axis): right motors vs left motors
            if len(t) >= 4:
                torque[0] = L * (t[1] + t[3] - t[0] - t[2])
                # Pitch (z-axis): front motors vs back motors
                torque[2] = L * (t[2] + t[3] - t[0] - t[1])
                # Yaw (y-axis): CW vs CCW motors (simplified)
                yaw_coeff = 0.01
                torque[1] = yaw_coeff * (t[0] + t[3] - t[1] - t[2])

        # Angular drag
        torque -= self.ang_drag * self.ang_vel

        # Angular acceleration
        ang_accel = torque / self.I
        self.ang_vel += ang_accel * dt

        # Quaternion integration
        self.rot = self._quat_integrate(self.rot, self.ang_vel, dt)
        self.rot = self._quat_normalize(self.rot)

        # ── Ground collision ──
        if self.pos[1] < 0.0:
            self.pos[1] = 0.0
            self.vel[1] = max(0.0, self.vel[1])
            # Dampen horizontal velocity on ground
            self.vel[0] *= 0.95
            self.vel[2] *= 0.95
            self.ang_vel *= 0.9

            if self._mode == "land" and abs(self.vel[1]) < 0.05:
                self.disarm()
                self.status = "landed"
                self._mode = "idle"

        # Update motor RPMs for visual feedback
        self.motor_rpms = self.motor_thrusts * 25000  # rough RPM mapping

    def _run_autopilot(self, dt: float):
        """Simple PID altitude + velocity controller."""
        if self._mode == "idle":
            self.motor_thrusts = np.zeros(self.motor_count)
            return

        # ── Altitude PID ──
        hover_thrust = (-self.gravity * self.mass) / (self.motor_count * self.max_thrust)

        alt_error = self._target_altitude - self.pos[1]
        self._alt_integral += alt_error * dt
        self._alt_integral = np.clip(self._alt_integral, -2.0, 2.0)
        alt_derivative = (alt_error - self._alt_prev_error) / max(dt, 1e-6)
        self._alt_prev_error = alt_error

        # PID gains
        kp, ki, kd = 1.2, 0.3, 0.8
        alt_correction = kp * alt_error + ki * self._alt_integral + kd * alt_derivative

        base_thrust = hover_thrust + alt_correction
        base_thrust = np.clip(base_thrust, 0.0, 1.0)

        # ── Velocity control (attitude-based) ──
        # Desired pitch/roll for horizontal movement
        desired_pitch = 0.0
        desired_roll = 0.0

        if self._mode == "move":
            vx_err = self._target_velocity[0] - self.vel[0]
            vz_err = self._target_velocity[2] - self.vel[2]
            vel_kp = 0.15
            desired_pitch = np.clip(-vz_err * vel_kp, -0.3, 0.3)
            desired_roll = np.clip(vx_err * vel_kp, -0.3, 0.3)

        # ── Attitude stabilization via differential thrust ──
        # Get current euler angles
        euler = self._quat_to_euler(self.rot)
        roll_err = desired_roll - euler[0]
        pitch_err = desired_pitch - euler[2]

        att_kp = 0.4
        att_kd = 0.15

        roll_corr = att_kp * roll_err - att_kd * self.ang_vel[0]
        pitch_corr = att_kp * pitch_err - att_kd * self.ang_vel[2]

        # Always calculate for 4-motor X-config
        full_thrusts = np.array([
            base_thrust - roll_corr - pitch_corr,  # FL (0)
            base_thrust + roll_corr - pitch_corr,  # FR (1)
            base_thrust - roll_corr + pitch_corr,  # BL (2)
            base_thrust + roll_corr + pitch_corr,  # BR (3)
        ])
        
        # Apply mask: only motors reported as 'functional' provide thrust
        # For simplicity, we fill from index 0 up to motor_count
        # If motor_count < 4, motors 3, 2... will have 0 thrust
        self.motor_thrusts = np.zeros(self.motor_count if self.motor_count > 4 else 4)
        for i in range(len(self.motor_thrusts)):
            if i < self.motor_count:
                self.motor_thrusts[i] = np.clip(full_thrusts[i] if i < 4 else base_thrust, 0.0, 1.0)
            else:
                self.motor_thrusts[i] = 0.0

    def get_state(self) -> dict:
        return {
            "type": "state",
            "pos": self.pos.tolist(),
            "rot": self.rot.tolist(),
            "vel": self.vel.tolist(),
            "motors": self.motor_rpms.tolist(),
            "battery": 100.0,  # placeholder
            "armed": self.armed,
            "status": self.status,
            "sim_time": round(self.sim_time, 3),
        }

    # ── Quaternion helpers ──
    @staticmethod
    def _quat_rotate(q, v):
        """Rotate vector v by quaternion q = (x,y,z,w)."""
        qx, qy, qz, qw = q
        # q * v * q_conjugate
        t = 2.0 * np.cross(q[:3], v)
        return v + qw * t + np.cross(q[:3], t)

    @staticmethod
    def _quat_integrate(q, omega, dt):
        """Integrate quaternion by angular velocity."""
        qx, qy, qz, qw = q
        wx, wy, wz = omega * 0.5 * dt
        dq = np.array([
            qw * wx + qy * wz - qz * wy,
            qw * wy + qz * wx - qx * wz,
            qw * wz + qx * wy - qy * wx,
            -qx * wx - qy * wy - qz * wz,
        ])
        return q + dq

    @staticmethod
    def _quat_normalize(q):
        n = np.linalg.norm(q)
        if n < 1e-10:
            return np.array([0.0, 0.0, 0.0, 1.0])
        return q / n

    @staticmethod
    def _quat_to_euler(q):
        """Quaternion (x,y,z,w) → Euler (roll, yaw, pitch)."""
        x, y, z, w = q
        # Roll (x-axis)
        sinr = 2.0 * (w * x + y * z)
        cosr = 1.0 - 2.0 * (x * x + y * y)
        roll = math.atan2(sinr, cosr)
        # Pitch (y-axis — yaw in Godot)
        siny = 2.0 * (w * y - z * x)
        yaw = math.asin(np.clip(siny, -1.0, 1.0))
        # Yaw (z-axis — pitch in our frame)
        sinp = 2.0 * (w * z + x * y)
        cosp = 1.0 - 2.0 * (y * y + z * z)
        pitch = math.atan2(sinp, cosp)
        return np.array([roll, yaw, pitch])

# ─────────────────────── ROS2/GAZEBO BRIDGE ───────────────────────

class ROS2Bridge:
    """
    ROS2 bridge node that publishes commands to Gazebo and subscribes
    to sensor data. Only loaded when ROS2 is available.
    """

    def __init__(self, cfg: dict):
        self.cfg = cfg
        self.available = False
        self.node = None
        self._latest_pose = None
        self._latest_imu = None
        self._spin_thread = None

        try:
            import rclpy
            from rclpy.node import Node
            from geometry_msgs.msg import Twist
            from nav_msgs.msg import Odometry
            from sensor_msgs.msg import Imu
            from std_msgs.msg import Float64MultiArray
            self._rclpy = rclpy
            self._Node = Node
            self._Twist = Twist
            self._Odometry = Odometry
            self._Imu = Imu
            self._Float64MultiArray = Float64MultiArray
            self.available = True
            print("[ROS2Bridge] ROS2 packages found — ROS2 mode available")
        except ImportError:
            print("[ROS2Bridge] ROS2 not found — standalone mode only")
            self.available = False

    def start(self):
        if not self.available:
            return False

        try:
            self._rclpy.init()
            ns = self.cfg.get("ros2", {}).get("namespace", "/flyntic")
            topics = self.cfg.get("ros2", {}).get("topics", {})

            self.node = self._Node("flyntic_bridge", namespace=ns)

            # Publishers
            self.cmd_vel_pub = self.node.create_publisher(
                self._Twist, topics.get("cmd_vel", "cmd_vel"), 10
            )
            self.cmd_thrust_pub = self.node.create_publisher(
                self._Float64MultiArray, topics.get("cmd_thrust", "cmd_thrust"), 10
            )

            # Subscribers
            self.node.create_subscription(
                self._Odometry, topics.get("pose", "odom"),
                self._on_odom, 10
            )
            self.node.create_subscription(
                self._Imu, topics.get("imu", "imu"),
                self._on_imu, 10
            )

            # Spin in background thread
            self._spin_thread = threading.Thread(
                target=self._rclpy.spin, args=(self.node,), daemon=True
            )
            self._spin_thread.start()
            print("[ROS2Bridge] ROS2 node started")
            return True

        except Exception as e:
            print(f"[ROS2Bridge] Failed to start: {e}")
            self.available = False
            return False

    def stop(self):
        if self.node:
            self.node.destroy_node()
        if self.available:
            try:
                self._rclpy.shutdown()
            except Exception:
                pass

    def _on_odom(self, msg):
        p = msg.pose.pose.position
        q = msg.pose.pose.orientation
        v = msg.twist.twist.linear
        self._latest_pose = {
            "pos": [p.x, p.z, -p.y],  # ROS→Godot coordinate transform
            "rot": [q.x, q.z, -q.y, q.w],
            "vel": [v.x, v.z, -v.y],
        }

    def _on_imu(self, msg):
        a = msg.linear_acceleration
        g = msg.angular_velocity
        self._latest_imu = {
            "accel": [a.x, a.z, -a.y],
            "gyro": [g.x, g.z, -g.y],
        }

    def send_cmd_vel(self, vx, vy, vz, yaw_rate=0.0):
        if not self.available or not self.node:
            return
        msg = self._Twist()
        msg.linear.x = float(vx)
        msg.linear.y = float(-vz)  # Godot→ROS
        msg.linear.z = float(vy)
        msg.angular.z = float(yaw_rate)
        self.cmd_vel_pub.publish(msg)

    def send_thrust(self, thrusts: list):
        if not self.available or not self.node:
            return
        msg = self._Float64MultiArray()
        msg.data = [float(t) for t in thrusts]
        self.cmd_thrust_pub.publish(msg)

    def get_state(self) -> dict | None:
        if self._latest_pose:
            state = {
                "type": "state",
                "pos": self._latest_pose["pos"],
                "rot": self._latest_pose["rot"],
                "vel": self._latest_pose["vel"],
                "motors": [0, 0, 0, 0],
                "battery": 100.0,
                "armed": True,
                "status": "flying",
                "sim_time": 0.0,
            }
            return state
        return None

    def get_imu(self) -> dict | None:
        if self._latest_imu:
            return {"type": "imu", **self._latest_imu}
        return None


# ─────────────────────── TCP SERVER ───────────────────────────────

class BridgeServer:
    """
    Main TCP server that bridges Godot and the physics backend
    (either ROS2/Gazebo or standalone Python physics).
    """

    def __init__(self, cfg: dict, standalone: bool = False):
        self.cfg = cfg
        self.standalone = standalone
        self.running = False

        tcp_cfg = cfg.get("tcp", {})
        self.host = tcp_cfg.get("host", "0.0.0.0")
        self.port = tcp_cfg.get("port", 9090)
        self.max_clients = tcp_cfg.get("max_clients", 4)
        self.update_rate = cfg.get("physics", {}).get("update_rate", 50)

        # Physics backends
        self.physics = DronePhysics(cfg)
        # Only probe ROS2 if not forced standalone
        if not standalone:
            self.ros2 = ROS2Bridge(cfg)
        else:
            self.ros2 = None

        # Client management
        self.clients: list[socket.socket] = []
        self.clients_lock = threading.Lock()

        self._use_ros2 = False

    def start(self):
        # Try ROS2 if not forced standalone
        if not self.standalone and self.ros2 and self.ros2.available:
            if self.ros2.start():
                self._use_ros2 = True
                print("[Bridge] Using ROS2/Gazebo physics backend")
            else:
                print("[Bridge] ROS2 init failed, falling back to standalone")
                self._use_ros2 = False
        else:
            print("[Bridge] Using standalone Python physics")

        # Start TCP server with retry for stale sockets
        self.server_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.server_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        for attempt in range(5):
            try:
                self.server_sock.bind((self.host, self.port))
                break
            except OSError as e:
                if attempt < 4:
                    print(f"[Bridge] Port {self.port} busy, retrying in 2s... ({e})")
                    time.sleep(2)
                else:
                    raise
        self.server_sock.listen(self.max_clients)
        self.server_sock.setblocking(False)

        self.running = True
        mode_str = "ROS2/Gazebo" if self._use_ros2 else "Standalone"
        print(f"[Bridge] TCP server listening on {self.host}:{self.port} ({mode_str})")
        print(f"[Bridge] State update rate: {self.update_rate} Hz")

        # Start physics + broadcast thread
        self._physics_thread = threading.Thread(target=self._physics_loop, daemon=True)
        self._physics_thread.start()

        # Accept loop (main thread)
        try:
            self._accept_loop()
        except KeyboardInterrupt:
            print("\n[Bridge] Shutting down...")
        finally:
            self.stop()

    def stop(self):
        self.running = False
        with self.clients_lock:
            for c in self.clients:
                try:
                    c.close()
                except Exception:
                    pass
            self.clients.clear()
        try:
            self.server_sock.close()
        except Exception:
            pass
        self.ros2.stop() if self.ros2 else None
        print("[Bridge] Stopped.")

    def _accept_loop(self):
        while self.running:
            readable, _, _ = select.select([self.server_sock], [], [], 0.5)
            for s in readable:
                try:
                    conn, addr = s.accept()
                    conn.setblocking(False)
                    with self.clients_lock:
                        self.clients.append(conn)
                    print(f"[Bridge] Client connected: {addr}")
                    # Send initial status
                    self._send_to(conn, {
                        "type": "status",
                        "connected": True,
                        "mode": "ros2" if self._use_ros2 else "standalone",
                        "sim_time": 0.0,
                    })
                    # Start receiver thread for this client
                    threading.Thread(
                        target=self._client_recv_loop,
                        args=(conn, addr),
                        daemon=True,
                    ).start()
                except Exception:
                    pass

    def _client_recv_loop(self, conn: socket.socket, addr):
        buffer = ""
        while self.running:
            try:
                readable, _, _ = select.select([conn], [], [], 0.5)
                if not readable:
                    continue
                data = conn.recv(4096)
                if not data:
                    break
                buffer += data.decode("utf-8", errors="replace")
                while "\n" in buffer:
                    line, buffer = buffer.split("\n", 1)
                    line = line.strip()
                    if line:
                        self._handle_command(conn, line)
            except (ConnectionResetError, BrokenPipeError, OSError):
                break
            except Exception as e:
                print(f"[Bridge] Client {addr} error: {e}")
                break

        print(f"[Bridge] Client disconnected: {addr}")
        with self.clients_lock:
            if conn in self.clients:
                self.clients.remove(conn)
        try:
            conn.close()
        except Exception:
            pass

    def _handle_command(self, conn: socket.socket, raw: str):
        try:
            cmd = json.loads(raw)
        except json.JSONDecodeError:
            self._send_to(conn, {"type": "error", "msg": "Invalid JSON"})
            return

        action = cmd.get("cmd", "")
        print(f"[Bridge] Command: {action} | {cmd}")

        if action == "arm":
            self.physics.arm()
            if self._use_ros2:
                pass  # Would send arm service call

        elif action == "disarm":
            self.physics.disarm()

        elif action == "takeoff":
            alt = cmd.get("altitude", 2.0)
            self.physics.takeoff(alt)
            if self._use_ros2:
                self.ros2.send_cmd_vel(0, alt * 0.5, 0)

        elif action == "land":
            self.physics.land()
            if self._use_ros2:
                self.ros2.send_cmd_vel(0, -0.5, 0)

        elif action == "move":
            vx = cmd.get("vx", 0.0)
            vy = cmd.get("vy", 0.0)
            vz = cmd.get("vz", 0.0)
            self.physics.move(vx, vy, vz)
            if self._use_ros2:
                self.ros2.send_cmd_vel(vx, vy, vz)

        elif action == "hover":
            self.physics.hover()
            if self._use_ros2:
                self.ros2.send_cmd_vel(0, 0, 0)

        elif action == "stop":
            self.physics.stop()

        elif action == "set_drone":
            self.physics.configure(
                mass=cmd.get("mass"),
                motor_count=cmd.get("motor_count"),
                max_thrust=cmd.get("max_thrust"),
            )

        elif action == "ping":
            self._send_to(conn, {"type": "pong", "time": time.time()})

        else:
            self._send_to(conn, {
                "type": "error",
                "msg": f"Unknown command: {action}",
            })

    def _physics_loop(self):
        """Step physics and broadcast state at the configured rate."""
        interval = 1.0 / self.update_rate
        last_time = time.monotonic()

        while self.running:
            now = time.monotonic()
            dt = now - last_time
            last_time = now

            # Step physics (standalone)
            if not self._use_ros2:
                self.physics.step(dt)
                state = self.physics.get_state()
            else:
                ros_state = self.ros2.get_state()
                if ros_state:
                    state = ros_state
                else:
                    # Fallback if Gazebo hasn't sent data yet
                    self.physics.step(dt)
                    state = self.physics.get_state()

            # Broadcast to all clients
            self._broadcast(state)

            # Also send IMU if available from ROS2
            if self._use_ros2:
                imu = self.ros2.get_imu()
                if imu:
                    self._broadcast(imu)

            # Sleep for remaining interval
            elapsed = time.monotonic() - now
            sleep_time = max(0.0, interval - elapsed)
            if sleep_time > 0:
                time.sleep(sleep_time)

    def _broadcast(self, data: dict):
        msg = (json.dumps(data, separators=(",", ":")) + "\n").encode("utf-8")
        dead = []
        with self.clients_lock:
            for c in self.clients:
                try:
                    c.sendall(msg)
                except (BrokenPipeError, ConnectionResetError, OSError):
                    dead.append(c)
            for c in dead:
                self.clients.remove(c)
                try:
                    c.close()
                except Exception:
                    pass

    def _send_to(self, conn: socket.socket, data: dict):
        try:
            msg = (json.dumps(data, separators=(",", ":")) + "\n").encode("utf-8")
            conn.sendall(msg)
        except (BrokenPipeError, ConnectionResetError, OSError):
            pass


# ─────────────────────── MAIN ─────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Flyntic Studio — ROS/Gazebo Physics Bridge"
    )
    parser.add_argument(
        "--standalone", action="store_true",
        help="Force standalone mode (no ROS2/Gazebo)"
    )
    parser.add_argument(
        "--port", type=int, default=None,
        help="Override TCP port (default: from config.yaml)"
    )
    args = parser.parse_args()

    cfg = load_config()

    if args.port:
        cfg.setdefault("tcp", {})["port"] = args.port

    server = BridgeServer(cfg, standalone=args.standalone)
    server.start()


if __name__ == "__main__":
    main()
