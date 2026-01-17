#!/bin/bash
#
# Copyright 2025 Enactic, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# ========= Configuration =========
ARM_SIDE=${1:-right_arm} # Required: left_arm or right_arm
LEADER_CAN_IF=$2         # Optional: leader CAN interface
FOLLOWER_CAN_IF=$3       # Optional: follower CAN interface
ARM_TYPE="v10"           # Fixed for now
TMPDIR="/tmp/openarm_urdf_gen"

# Validate arm side
if [[ "$ARM_SIDE" != "right_arm" && "$ARM_SIDE" != "left_arm" ]]; then
    echo "[ERROR] Invalid arm_side: $ARM_SIDE"
    echo "Usage: $0 <arm_side: right_arm|left_arm> [leader_can_if] [follower_can_if]"
    exit 1
fi

# Set default CAN interfaces if not provided
if [ -z "$LEADER_CAN_IF" ]; then
    if [ "$ARM_SIDE" = "right_arm" ]; then
        LEADER_CAN_IF="can0"
    else
        LEADER_CAN_IF="can1"
    fi
fi

if [ -z "$FOLLOWER_CAN_IF" ]; then
    if [ "$ARM_SIDE" = "right_arm" ]; then
        FOLLOWER_CAN_IF="can2"
    else
        FOLLOWER_CAN_IF="can3"
    fi
fi

# Find openarm_description path using ros2 pkg prefix
if ! OPENARM_DESC_PATH=$(ros2 pkg prefix openarm_description 2>/dev/null); then
    echo "[ERROR] Could not find package 'openarm_description'. Please ensure it is installed and sourced." >&2
    exit 1
fi

XACRO_FILE="$ARM_TYPE.urdf.xacro"
XACRO_PATH="$OPENARM_DESC_PATH/share/openarm_description/urdf/robot/$XACRO_FILE"
LEADER_URDF_PATH="$TMPDIR/${ARM_TYPE}_leader.urdf"
FOLLOWER_URDF_PATH="$TMPDIR/${ARM_TYPE}_follower.urdf"

# Find binary path
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
BIN_NAME="bilateral_control"
BIN_PATH=""

if [ -f "$DIR/$BIN_NAME" ]; then
    BIN_PATH="$DIR/$BIN_NAME"
elif [ -f "$DIR/$BIN_NAME.exe" ]; then
    BIN_PATH="$DIR/$BIN_NAME.exe"
else
    # Fallback for dev environment
    BIN_PATH=~/openarm_teleop/build/$BIN_NAME
fi

# ================================

# Check xacro file
if [ ! -f "$XACRO_PATH" ]; then
    echo "[ERROR] Could not find ${XACRO_FILE} at $XACRO_PATH" >&2
    exit 1
fi

# Check binary
if [ ! -f "$BIN_PATH" ]; then
    echo "[ERROR] Compiled binary not found at: $BIN_PATH"
    echo "Please build the package first."
    exit 1
fi

# Generate URDFs
echo "[INFO] Generating URDFs using xacro..."
mkdir -p "$TMPDIR"
if ! xacro "$XACRO_PATH" bimanual:=true -o "$LEADER_URDF_PATH"; then
    echo "[ERROR] Failed to generate URDFs."
    exit 1
fi
cp "$LEADER_URDF_PATH" "$FOLLOWER_URDF_PATH"

# Run binary
echo "[INFO] Launching bilateral control..."
"$BIN_PATH" "$LEADER_URDF_PATH" "$FOLLOWER_URDF_PATH" "$ARM_SIDE" "$LEADER_CAN_IF" "$FOLLOWER_CAN_IF"

# Cleanup
echo "[INFO] Cleaning up temporary files..."
rm -rf "$TMPDIR"
