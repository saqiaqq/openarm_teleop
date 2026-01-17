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

# ======== Configuration ========
ARM_SIDE=${1:-right_arm}
CAN_IF=${2:-can0}
ARM_TYPE=${3:-v10}
TMPDIR="/tmp/openarm_urdf_gen"
URDF_NAME="${ARM_TYPE}_bimanual.urdf"
XACRO_FILE="${ARM_TYPE}.urdf.xacro"

# Find openarm_description path using ros2 pkg prefix
if ! OPENARM_DESC_PATH=$(ros2 pkg prefix openarm_description 2>/dev/null); then
    echo "[ERROR] Could not find package 'openarm_description'. Please ensure it is installed and sourced." >&2
    exit 1
fi

XACRO_PATH="$OPENARM_DESC_PATH/share/openarm_description/urdf/robot/$XACRO_FILE"
URDF_OUT="$TMPDIR/$URDF_NAME"

# Find binary path
# Priority:
# 1. Same directory as this script (installed scenario)
# 2. ~/openarm_teleop/build/gravity_comp (dev scenario fallback)

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
BIN_NAME="gravity_comp"
BIN_PATH=""

if [ -f "$DIR/$BIN_NAME" ]; then
    BIN_PATH="$DIR/$BIN_NAME"
elif [ -f "$DIR/$BIN_NAME.exe" ]; then
    BIN_PATH="$DIR/$BIN_NAME.exe"
else
    # Fallback for dev environment if not installed
    BIN_PATH=~/openarm_teleop/build/$BIN_NAME
fi

# ===============================

# Check xacro file
if [ ! -f "$XACRO_PATH" ]; then
    echo "[ERROR] Could not find ${XACRO_FILE} at $XACRO_PATH" >&2
    exit 1
fi

# Check build binary
if [ ! -f "$BIN_PATH" ]; then
    echo "[ERROR] Compiled binary not found at: $BIN_PATH"
    echo "Please build the package first."
    exit 1
fi

# Generate URDF
echo "[INFO] Generating URDF using xacro..."

mkdir -p "$TMPDIR"
if ! xacro "$XACRO_PATH" bimanual:=true -o "$URDF_OUT"; then
    echo "[ERROR] Failed to generate URDF."
    exit 1
fi

# Run gravity compensation binary
echo "[INFO] Launching gravity compensation..."
"$BIN_PATH" "$ARM_SIDE" "$CAN_IF" "$URDF_OUT"

# Cleanup
echo "[INFO] Cleaning up tmp dir..."
rm -rf "$TMPDIR"
