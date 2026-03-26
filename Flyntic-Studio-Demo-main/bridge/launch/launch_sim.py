#!/usr/bin/env python3
"""
ROS2 Launch file for Flyntic Studio simulation.
Launches Gazebo Harmonic world + the physics bridge server.
"""

import os
from pathlib import Path

from launch import LaunchDescription
from launch.actions import (
    DeclareLaunchArgument,
    ExecuteProcess,
    IncludeLaunchDescription,
    SetEnvironmentVariable,
)
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node


def generate_launch_description():
    bridge_dir = Path(__file__).resolve().parent.parent
    models_dir = bridge_dir / "models"
    worlds_dir = bridge_dir / "worlds"
    bridge_script = bridge_dir / "ros_gz_bridge.py"

    world_file = str(worlds_dir / "flyntic_world.sdf")

    return LaunchDescription([
        # Set Gazebo model path
        SetEnvironmentVariable(
            name="GZ_SIM_RESOURCE_PATH",
            value=str(models_dir),
        ),

        # Declare arguments
        DeclareLaunchArgument(
            "world", default_value=world_file,
            description="Path to the Gazebo world SDF"
        ),
        DeclareLaunchArgument(
            "standalone", default_value="false",
            description="Run bridge in standalone mode (no Gazebo)"
        ),

        # Launch Gazebo Harmonic
        ExecuteProcess(
            cmd=[
                "gz", "sim", "-r",
                LaunchConfiguration("world"),
            ],
            output="screen",
            name="gazebo",
        ),

        # Launch ros_gz_bridge for ROS2↔Gazebo topic bridging
        Node(
            package="ros_gz_bridge",
            executable="parameter_bridge",
            arguments=[
                "/flyntic/cmd_vel@geometry_msgs/msg/Twist@gz.msgs.Twist",
                "/flyntic/odom@nav_msgs/msg/Odometry@gz.msgs.Odometry",
                "/flyntic/imu@sensor_msgs/msg/Imu@gz.msgs.IMU",
                "/model/flyntic_drone/command/motor_speed@actuator_msgs/msg/Actuators@gz.msgs.Actuators",
            ],
            output="screen",
            name="ros_gz_bridge",
        ),

        # Launch the Python TCP bridge server
        ExecuteProcess(
            cmd=[
                "python3", str(bridge_script),
            ],
            output="screen",
            name="flyntic_bridge",
        ),
    ])
