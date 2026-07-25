from __future__ import annotations

from functools import lru_cache

from supabase import Client, create_client

from .config import get_settings


@lru_cache(maxsize=2)
def get_supabase_client(use_service_role: bool = False) -> Client:
    settings = get_settings()
    key = (
        settings.supabase_service_role_key
        if use_service_role and settings.supabase_service_role_key
        else settings.supabase_anon_key
    )

    if not settings.supabase_url or not key:
        raise RuntimeError("Supabase URL and key are required.")

    return create_client(settings.supabase_url, key)
