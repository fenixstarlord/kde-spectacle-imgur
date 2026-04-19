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


def _env(name: str, default: str = "") -> str:
    value = os.environ.get(name, default)
    return value.strip() if isinstance(value, str) else default


def load_config() -> Config:
    provider = _env("SPECTACLE_PLUGIN_PROVIDER", "imgur").lower()
    if provider in ("0x0.st", "zerox0"):
        provider = "0x0"
    if provider not in ("imgur", "0x0"):
        raise ConfigError("SPECTACLE_PLUGIN_PROVIDER must be 'imgur' or '0x0'")

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
    )
