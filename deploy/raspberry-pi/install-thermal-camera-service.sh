#!/bin/sh
set -eu

INSTALL_DIR="/opt/moashir/raspberry-pi"
ENV_DIR="/etc/moashir"
ENV_FILE="${ENV_DIR}/thermal-camera.env"
SERVICE_FILE="/etc/systemd/system/moashir-thermal-camera.service"

sudo mkdir -p "${INSTALL_DIR}" "${ENV_DIR}"
sudo cp ./start-thermal-camera.sh "${INSTALL_DIR}/start-thermal-camera.sh"
sudo cp ./moashir-thermal-camera.service "${SERVICE_FILE}"
sudo chmod +x "${INSTALL_DIR}/start-thermal-camera.sh"

if [ ! -f "${ENV_FILE}" ]; then
  sudo tee "${ENV_FILE}" >/dev/null <<'EOF'
# Replace this with the command that starts your real Raspberry Pi thermal camera bridge.
# The bridge should expose an HTTP endpoint that returns:
# {"temperature_c": 37.2, "face_recognition_confirmed": true, "captured_at": "2026-07-31T12:00:00Z"}
MOASHIR_THERMAL_CAMERA_COMMAND="python3 /opt/moashir/thermal_camera_bridge.py --host 0.0.0.0 --port 9000"
EOF
fi

sudo systemctl daemon-reload
sudo systemctl enable moashir-thermal-camera.service
sudo systemctl restart moashir-thermal-camera.service
sudo systemctl status moashir-thermal-camera.service --no-pager
