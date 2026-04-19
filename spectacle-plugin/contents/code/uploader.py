#!/usr/bin/env python3

from __future__ import annotations

import json
import mimetypes
import os
import secrets
import urllib.error
import urllib.request
from urllib.parse import urlparse, unquote

from config import Config


class UploadError(RuntimeError):
    pass


def _as_file_path(url_or_path: str) -> str:
    parsed = urlparse(url_or_path)
    if parsed.scheme == "file":
        path = unquote(parsed.path)
    elif parsed.scheme == "":
        path = url_or_path
    else:
        raise UploadError(f"unsupported URL scheme for upload input: {parsed.scheme}")

    if not path:
        raise UploadError("upload input path is empty")

    normalized = os.path.abspath(path)
    if not os.path.isfile(normalized):
        raise UploadError(f"upload input file does not exist: {normalized}")
    return normalized


def _build_multipart(field_name: str, file_path: str) -> tuple[bytes, str]:
    boundary = f"----spectacle-plugin-{secrets.token_hex(12)}"
    filename = os.path.basename(file_path)
    content_type = mimetypes.guess_type(filename)[0] or "application/octet-stream"

    with open(file_path, "rb") as fh:
        file_bytes = fh.read()

    parts = [
        f"--{boundary}\r\n".encode("utf-8"),
        (
            f'Content-Disposition: form-data; name="{field_name}"; filename="{filename}"\r\n'
        ).encode("utf-8"),
        f"Content-Type: {content_type}\r\n\r\n".encode("utf-8"),
        file_bytes,
        b"\r\n",
        f"--{boundary}--\r\n".encode("utf-8"),
    ]

    return b"".join(parts), boundary


def _request(url: str, headers: dict[str, str], body: bytes) -> tuple[int, bytes]:
    req = urllib.request.Request(url=url, data=body, method="POST", headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=45) as response:
            return response.status, response.read()
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read()
    except urllib.error.URLError as exc:
        raise UploadError(f"network error while uploading: {exc.reason}") from exc


def _json_error(payload: bytes) -> str:
    try:
        data = json.loads(payload.decode("utf-8", errors="replace"))
    except Exception:
        return ""

    if not isinstance(data, dict):
        return ""
    nested = data.get("data")
    if isinstance(nested, dict):
        err = nested.get("error")
        if isinstance(err, dict):
            err = err.get("message")
        if isinstance(err, str):
            return err
    return ""


def _upload_imgur(config: Config, file_path: str) -> str:
    if config.imgur_auth_mode == "login" or (
        config.imgur_auth_mode == "auto" and config.imgur_access_token
    ):
        token = config.imgur_access_token
        if not token:
            raise UploadError(
                "SPECTACLE_PLUGIN_IMGUR_ACCESS_TOKEN is required for imgur login mode"
            )
        auth_header = f"Bearer {token}"
        using_login = True
    else:
        client_id = config.imgur_client_id
        if not client_id:
            raise UploadError(
                "SPECTACLE_PLUGIN_IMGUR_CLIENT_ID is required for imgur anonymous mode"
            )
        auth_header = f"Client-ID {client_id}"
        using_login = False

    body, boundary = _build_multipart("image", file_path)
    status, response = _request(
        config.imgur_api_url,
        {
            "Authorization": auth_header,
            "Content-Type": f"multipart/form-data; boundary={boundary}",
        },
        body,
    )

    if status < 200 or status >= 300:
        api_error = _json_error(response)
        suffix = f" API says: {api_error}" if api_error else ""
        if status == 401:
            raise UploadError(
                "Imgur login token is invalid or expired (HTTP 401)."
                " Refresh SPECTACLE_PLUGIN_IMGUR_ACCESS_TOKEN."
                f"{suffix}"
            )
        if status == 403:
            if using_login:
                raise UploadError(
                    "Imgur rejected the login token (HTTP 403)."
                    " Check token scopes and account status."
                    f"{suffix}"
                )
            raise UploadError(
                "Imgur rejected the Client ID (HTTP 403)."
                " Use the app Client ID value."
                f"{suffix}"
            )
        if status == 429:
            mode = "logged-in account" if using_login else "anonymous upload"
            raise UploadError(f"Imgur rate limit hit for {mode} (HTTP 429).{suffix}")
        raise UploadError(f"Imgur upload failed (HTTP {status}).{suffix}")

    try:
        data = json.loads(response.decode("utf-8", errors="replace"))
        link = data["data"]["link"]
    except Exception as exc:
        raise UploadError("failed to parse Imgur upload response") from exc

    if not isinstance(link, str) or not link.startswith(("http://", "https://")):
        raise UploadError("Imgur upload returned an invalid URL")
    return link


def _upload_zerox0(config: Config, file_path: str) -> str:
    body, boundary = _build_multipart("file", file_path)
    status, response = _request(
        config.zerox0_api_url,
        {"Content-Type": f"multipart/form-data; boundary={boundary}"},
        body,
    )

    text = response.decode("utf-8", errors="replace").strip()
    if status < 200 or status >= 300:
        suffix = f" Response: {text}" if text else ""
        raise UploadError(f"0x0 upload failed (HTTP {status}).{suffix}")
    if not text.startswith(("http://", "https://")):
        raise UploadError("0x0 upload returned an invalid URL")
    return text.splitlines()[0]


def upload(input_url: str, config: Config) -> str:
    file_path = _as_file_path(input_url)
    if config.provider == "imgur":
        return _upload_imgur(config, file_path)
    if config.provider == "0x0":
        return _upload_zerox0(config, file_path)
    raise UploadError(f"unsupported provider: {config.provider}")
