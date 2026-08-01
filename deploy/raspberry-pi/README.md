# Raspberry Pi Thermal Camera Auto-Start

Use this to start the MO'ASHIR thermal camera bridge automatically whenever the Raspberry Pi boots.

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

Example:

```sh
MOASHIR_THERMAL_CAMERA_COMMAND="python3 /opt/moashir/thermal_camera_bridge.py --host 0.0.0.0 --port 9000"
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
sudo systemctl status moashir-thermal-camera.service
journalctl -u moashir-thermal-camera.service -f
```

## Stop Or Restart

```sh
sudo systemctl restart moashir-thermal-camera.service
sudo systemctl stop moashir-thermal-camera.service
```

## Connect Flutter

Build the Flutter web app with the Pi endpoint:

```sh
flutter build web --release --dart-define=THERMAL_CAMERA_API_URL=http://RASPBERRY_PI_IP:9000
```

Replace `RASPBERRY_PI_IP` with the Pi address on the hospital network.
