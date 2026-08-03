from datetime import datetime, timedelta, timezone
import unittest

from backend.app.main import _thermal_camera_command_is_stale


class ThermalCameraCommandTimeoutTest(unittest.TestCase):
    def setUp(self) -> None:
        self.now = datetime(2026, 8, 3, 12, 0, tzinfo=timezone.utc)

    def test_fresh_command_is_not_stale(self) -> None:
        requested_at = self.now - timedelta(seconds=44)

        self.assertFalse(
            _thermal_camera_command_is_stale(
                requested_at.isoformat(),
                now=self.now,
            )
        )

    def test_old_command_is_stale(self) -> None:
        requested_at = self.now - timedelta(seconds=46)

        self.assertTrue(
            _thermal_camera_command_is_stale(
                requested_at.isoformat(),
                now=self.now,
            )
        )

    def test_missing_or_invalid_timestamp_is_stale(self) -> None:
        self.assertTrue(_thermal_camera_command_is_stale(None, now=self.now))
        self.assertTrue(_thermal_camera_command_is_stale("invalid", now=self.now))


if __name__ == "__main__":
    unittest.main()
