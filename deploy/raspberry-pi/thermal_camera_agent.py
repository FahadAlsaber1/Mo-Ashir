#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import signal
import subprocess
import time
from datetime import datetime, timezone
from typing import Any
from urllib.parse import urlencode
from urllib.request import Request, urlopen


SUPABASE_URL = os.environ.get("SUPABASE_URL", "").strip().rstrip("/")
SUPABASE_SERVICE_ROLE_KEY = os.environ.get(
    "SUPABASE_SERVICE_ROLE_KEY", ""
).strip()
DEVICE_ID = os.environ.get(
    "MOASHIR_THERMAL_CAMERA_DEVICE_ID", "hospital-main"
).strip() or "hospital-main"
CAMERA_SERVICE = os.environ.get(
    "MOASHIR_THERMAL_CAMERA_SERVICE", "moashir-thermal-camera.service"
).strip() or "moashir-thermal-camera.service"
POLL_SECONDS = max(
    1.0,
    float(os.environ.get("MOASHIR_THERMAL_CAMERA_POLL_SECONDS", "2")),
)

_running = True


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _headers(*, prefer: str | None = None) -> dict[str, str]:
    headers = {
        "apikey": SUPABASE_SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_ROLE_KEY}",
        "Content-Type": "application/json",
    }
    if prefer:
        headers["Prefer"] = prefer
    return headers


def _request(
    method: str,
    table: str,
    *,
    query: dict[str, str] | None = None,
    payload: Any = None,
    prefer: str | None = None,
) -> Any:
    suffix = f"?{urlencode(query)}" if query else ""
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    request = Request(
        f"{SUPABASE_URL}/rest/v1/{table}{suffix}",
        data=data,
        method=method,
        headers=_headers(prefer=prefer),
    )
    with urlopen(request, timeout=15) as response:
        body = response.read()
    return json.loads(body) if body else None


def _service_state() -> tuple[str, str | None]:
    result = subprocess.run(
        ["systemctl", "is-active", CAMERA_SERVICE],
        capture_output=True,
        text=True,
        timeout=10,
        check=False,
    )
    status = result.stdout.strip()
    if status == "active":
        return "on", None
    if status in {"inactive", "failed", "deactivating", "unknown"}:
        error = result.stderr.strip() or None
        return "off", error
    return "unknown", result.stderr.strip() or f"Unexpected service state: {status}"


def _publish_state(actual_state: str, error: str | None = None) -> None:
    now = _now()
    _request(
        "POST",
        "thermal_camera_devices",
        query={"on_conflict": "device_id"},
        payload={
            "device_id": DEVICE_ID,
            "actual_state": actual_state,
            "last_seen": now,
            "last_error": error,
            "updated_at": now,
        },
        prefer="resolution=merge-duplicates,return=minimal",
    )


def _next_command() -> dict[str, Any] | None:
    rows = _request(
        "GET",
        "thermal_camera_commands",
        query={
            "select": "id,desired_state",
            "device_id": f"eq.{DEVICE_ID}",
            "status": "eq.pending",
            "order": "requested_at.asc",
            "limit": "1",
        },
    )
    return rows[0] if isinstance(rows, list) and rows else None


def _recover_processing_commands() -> None:
    _request(
        "PATCH",
        "thermal_camera_commands",
        query={"device_id": f"eq.{DEVICE_ID}", "status": "eq.processing"},
        payload={"status": "pending", "error_message": None},
        prefer="return=minimal",
    )


def _claim_command(command_id: str) -> bool:
    rows = _request(
        "PATCH",
        "thermal_camera_commands",
        query={"id": f"eq.{command_id}", "status": "eq.pending"},
        payload={"status": "processing"},
        prefer="return=representation",
    )
    return isinstance(rows, list) and bool(rows)


def _finish_command(
    command_id: str,
    *,
    status: str,
    error: str | None = None,
) -> None:
    _request(
        "PATCH",
        "thermal_camera_commands",
        query={"id": f"eq.{command_id}"},
        payload={
            "status": status,
            "acknowledged_at": _now(),
            "error_message": error,
        },
        prefer="return=minimal",
    )


def _apply_command(command: dict[str, Any]) -> None:
    command_id = str(command["id"])
    desired_state = str(command["desired_state"])
    if not _claim_command(command_id):
        return

    action = "start" if desired_state == "on" else "stop"
    try:
        result = subprocess.run(
            ["systemctl", action, CAMERA_SERVICE],
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
        actual_state, state_error = _service_state()
        expected_state = "on" if desired_state == "on" else "off"
        if result.returncode != 0 or actual_state != expected_state:
            error = (
                result.stderr.strip()
                or state_error
                or f"Camera service did not reach {expected_state}."
            )
            _publish_state("error", error)
            _finish_command(command_id, status="failed", error=error)
            return

        _publish_state(actual_state)
        _finish_command(command_id, status="applied")
        print(f"Applied thermal camera command: {desired_state}", flush=True)
    except Exception as exc:
        error = str(exc)
        _publish_state("error", error)
        _finish_command(command_id, status="failed", error=error)


def _stop(_signum: int, _frame: Any) -> None:
    global _running
    _running = False


def main() -> None:
    if not SUPABASE_URL or not SUPABASE_SERVICE_ROLE_KEY:
        raise SystemExit(
            "SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required in "
            "/etc/moashir/thermal-camera.env"
        )

    signal.signal(signal.SIGTERM, _stop)
    signal.signal(signal.SIGINT, _stop)
    print(f"Starting thermal camera command agent for {DEVICE_ID}", flush=True)
    _recover_processing_commands()

    while _running:
        try:
            actual_state, error = _service_state()
            _publish_state(actual_state, error)
            command = _next_command()
            if command:
                _apply_command(command)
        except Exception as exc:
            print(f"Thermal camera agent error: {exc}", flush=True)
        time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    main()
