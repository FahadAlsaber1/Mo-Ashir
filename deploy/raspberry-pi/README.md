# Raspberry Pi Thermal Camera Control

The hospital dashboard sends on/off commands through Supabase. The Raspberry Pi
agent polls those commands, controls the local camera systemd service, and sends
the actual state and a heartbeat back to the dashboard. The Pi only needs an
outbound internet connection; no public port or inbound tunnel is required.

## Install

Copy this folder to the Raspberry Pi, then run:

```sh
cd deploy/raspberry-pi
chmod +x install-thermal-camera-service.sh
./install-thermal-camera-service.sh
```

## Configure The Camera Command

Edit:

```sh
sudo nano /etc/moashir/thermal-camera.env
```

Set `MOASHIR_THERMAL_CAMERA_COMMAND` to the real command that starts your thermal camera bridge.
Set `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` to the same project used by
the DigitalOcean backend. Keep the service-role key only in this root-owned file.
Use the same `MOASHIR_THERMAL_CAMERA_DEVICE_ID` in DigitalOcean and on the Pi.

Example:

```sh
MOASHIR_THERMAL_CAMERA_COMMAND="python3 /opt/moashir/thermal_camera_bridge.py --host 0.0.0.0 --port 9000"
SUPABASE_URL="https://your-project-ref.supabase.co"
SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"
MOASHIR_THERMAL_CAMERA_DEVICE_ID="hospital-main"
```

The bridge endpoint must return JSON like:

```json
{
  "temperature_c": 37.2,
  "face_recognition_confirmed": true,
  "captured_at": "2026-07-31T12:00:00Z"
}
```

## Check Status

```sh
sudo systemctl status moashir-thermal-camera-agent.service
journalctl -u moashir-thermal-camera-agent.service -f
```

## Stop Or Restart

```sh
sudo systemctl restart moashir-thermal-camera-agent.service
sudo systemctl stop moashir-thermal-camera-agent.service
```

## Connect Flutter

Build the Flutter web app with the Pi endpoint:

```sh
flutter build web --release --dart-define=THERMAL_CAMERA_API_URL=http://RASPBERRY_PI_IP:9000
```

Replace `RASPBERRY_PI_IP` with the Pi address on the hospital network.

The camera bridge remains off after boot until the hospital dashboard sends an
on command. Heartbeats are published every two seconds, and the dashboard marks
the station offline after 20 seconds without a heartbeat.
