from __future__ import annotations

import os
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[2]
ROOT_ENV_PATH = ROOT_DIR / ".env"


def _read_env_file(path: Path) -> dict[str, str]:
    if not path.exists():
        return {}

    values: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def _env(name: str, env_file: dict[str, str], default: str = "") -> str:
    return os.environ.get(name, env_file.get(name, default)).strip()


def _looks_like_placeholder(value: str) -> bool:
    lowered = value.lower()
    return any(
        token in lowered
        for token in ("[your-pass", "your-", "replace-me", "password")
    )


@dataclass(frozen=True)
class Settings:
    supabase_url: str
    supabase_anon_key: str
    supabase_service_role_key: str
    database_url: str
    host: str
    port: int

    @property
    def supabase_configured(self) -> bool:
        return bool(self.supabase_url and self.supabase_anon_key)

    @property
    def service_role_configured(self) -> bool:
        return bool(self.supabase_service_role_key)

    @property
    def database_url_configured(self) -> bool:
        return bool(self.database_url and not _looks_like_placeholder(self.database_url))


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    env_file = _read_env_file(ROOT_ENV_PATH)
    port = _env("PYTHON_BACKEND_PORT", env_file, "8000")
    return Settings(
        supabase_url=_env("SUPABASE_URL", env_file),
        supabase_anon_key=_env("SUPABASE_ANON_KEY", env_file),
        supabase_service_role_key=_env("SUPABASE_SERVICE_ROLE_KEY", env_file),
        database_url=_env("DATABASE_URL", env_file),
        host=_env("PYTHON_BACKEND_HOST", env_file, "127.0.0.1"),
        port=int(port) if port.isdigit() else 8000,
    )
