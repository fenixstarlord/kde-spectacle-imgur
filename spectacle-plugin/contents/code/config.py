#!/usr/bin/env python3

from __future__ import annotations

import os
from dataclasses import dataclass


class ConfigError(ValueError):
    pass


@dataclass(frozen=True)
class Config:
    provider: str
    imgur_auth_mode: str
    imgur_client_id: str
    imgur_access_token: str
    imgur_api_url: str
    zerox0_api_url: str
    catbox_api_url: str
    catbox_userhash: str
    catbox_max_retries: int
    catbox_http1_fallback: int


def _env(name: str, default: str = "") -> str:
    value = os.environ.get(name, default)
    return value.strip() if isinstance(value, str) else default


def _env_int(name: str, default: int) -> int:
    raw = _env(name, str(default))
    try:
        value = int(raw)
    except ValueError:
        return default
    return value


def _env_bool(name: str, default: int) -> int:
    raw = _env(name, str(default)).strip()
    if raw not in ("0", "1"):
        return default
    return 1 if raw == "1" else 0


def load_config() -> Config:
    provider = _env("SPECTACLE_PLUGIN_PROVIDER", "imgur").lower()
    if provider in ("0x0.st", "zerox0"):
        provider = "0x0"
    if provider not in ("imgur", "0x0", "catbox"):
        raise ConfigError("SPECTACLE_PLUGIN_PROVIDER must be 'imgur', '0x0', or 'catbox'")

    catbox_max_retries = _env_int("SPECTACLE_PLUGIN_CATBOX_MAX_RETRIES", 1)
    if catbox_max_retries < 0:
        catbox_max_retries = 0

    auth_mode = _env("SPECTACLE_PLUGIN_IMGUR_AUTH_MODE", "auto").lower()
    if auth_mode not in ("auto", "anonymous", "login"):
        raise ConfigError("SPECTACLE_PLUGIN_IMGUR_AUTH_MODE must be auto, anonymous, or login")

    return Config(
        provider=provider,
        imgur_auth_mode=auth_mode,
        imgur_client_id=_env("SPECTACLE_PLUGIN_IMGUR_CLIENT_ID"),
        imgur_access_token=_env("SPECTACLE_PLUGIN_IMGUR_ACCESS_TOKEN"),
        imgur_api_url=_env("SPECTACLE_PLUGIN_IMGUR_API_URL", "https://api.imgur.com/3/image"),
        zerox0_api_url=_env("SPECTACLE_PLUGIN_ZEROX0_API_URL", "https://0x0.st"),
        catbox_api_url=_env("SPECTACLE_PLUGIN_CATBOX_API_URL", "https://catbox.moe/user/api.php"),
        catbox_userhash=_env("SPECTACLE_PLUGIN_CATBOX_USERHASH"),
        catbox_max_retries=catbox_max_retries,
        catbox_http1_fallback=_env_bool("SPECTACLE_PLUGIN_CATBOX_HTTP1_FALLBACK", 1),
    )
