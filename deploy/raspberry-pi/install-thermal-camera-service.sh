#!/bin/sh
set -eu

INSTALL_DIR="/opt/moashir/raspberry-pi"
ENV_DIR="/etc/moashir"
ENV_FILE="${ENV_DIR}/thermal-camera.env"
SERVICE_FILE="/etc/systemd/system/moashir-thermal-camera.service"
AGENT_SERVICE_FILE="/etc/systemd/system/moashir-thermal-camera-agent.service"

sudo mkdir -p "${INSTALL_DIR}" "${ENV_DIR}"
sudo cp ./start-thermal-camera.sh "${INSTALL_DIR}/start-thermal-camera.sh"
sudo cp ./moashir-thermal-camera.service "${SERVICE_FILE}"
sudo cp ./thermal_camera_agent.py "${INSTALL_DIR}/thermal_camera_agent.py"
sudo cp ./moashir-thermal-camera-agent.service "${AGENT_SERVICE_FILE}"
sudo chmod +x "${INSTALL_DIR}/start-thermal-camera.sh"
sudo chmod +x "${INSTALL_DIR}/thermal_camera_agent.py"

if [ ! -f "${ENV_FILE}" ]; then
  sudo tee "${ENV_FILE}" >/dev/null <<'EOF'
# Replace this with the command that starts your real Raspberry Pi thermal camera bridge.
# The bridge should expose an HTTP endpoint that returns:
# {"temperature_c": 37.2, "face_recognition_confirmed": true, "captured_at": "2026-07-31T12:00:00Z"}
MOASHIR_THERMAL_CAMERA_COMMAND="python3 /opt/moashir/thermal_camera_bridge.py --host 0.0.0.0 --port 9000"
SUPABASE_URL="https://your-project-ref.supabase.co"
SUPABASE_SERVICE_ROLE_KEY="replace-with-your-service-role-key"
MOASHIR_THERMAL_CAMERA_DEVICE_ID="hospital-main"
EOF
fi

if ! sudo grep -q '^SUPABASE_URL=' "${ENV_FILE}"; then
  echo 'SUPABASE_URL="https://your-project-ref.supabase.co"' | sudo tee -a "${ENV_FILE}" >/dev/null
fi
if ! sudo grep -q '^SUPABASE_SERVICE_ROLE_KEY=' "${ENV_FILE}"; then
  echo 'SUPABASE_SERVICE_ROLE_KEY="replace-with-your-service-role-key"' | sudo tee -a "${ENV_FILE}" >/dev/null
fi
if ! sudo grep -q '^MOASHIR_THERMAL_CAMERA_DEVICE_ID=' "${ENV_FILE}"; then
  echo 'MOASHIR_THERMAL_CAMERA_DEVICE_ID="hospital-main"' | sudo tee -a "${ENV_FILE}" >/dev/null
fi
sudo chmod 600 "${ENV_FILE}"

sudo systemctl daemon-reload
sudo systemctl disable --now moashir-thermal-camera.service || true
sudo systemctl enable moashir-thermal-camera-agent.service
sudo systemctl restart moashir-thermal-camera-agent.service
sudo systemctl status moashir-thermal-camera-agent.service --no-pager
