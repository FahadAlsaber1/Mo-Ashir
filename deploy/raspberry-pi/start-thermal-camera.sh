#!/bin/sh
set -eu

: "${MOASHIR_THERMAL_CAMERA_COMMAND:=python3 /opt/moashir/thermal_camera_bridge.py --host 0.0.0.0 --port 9000}"

echo "Starting MO'ASHIR thermal camera bridge"
echo "Command: ${MOASHIR_THERMAL_CAMERA_COMMAND}"

exec sh -c "${MOASHIR_THERMAL_CAMERA_COMMAND}"
