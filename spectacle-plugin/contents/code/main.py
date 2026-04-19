#!/usr/bin/env python3

from __future__ import annotations

import argparse
import os
import sys

from config import ConfigError, load_config
from purpose_io import PurposeConnection, PurposeIoError
from uploader import UploadError, upload


def _pick_input_url(payload) -> str:
    if not isinstance(payload, dict):
        raise UploadError("Purpose input payload must be a JSON object")

    urls = payload.get("urls")
    if isinstance(urls, list) and urls:
        candidate = urls[0]
        if isinstance(candidate, str) and candidate:
            return candidate

    fallback = payload.get("url")
    if isinstance(fallback, str) and fallback:
        return fallback

    raise UploadError("Purpose payload did not include a usable input URL")


def _run(server_path: str) -> int:
    conn = None

    def _try_send(payload: dict) -> None:
        if conn is None:
            return
        try:
            conn.send(payload)
        except Exception:
            pass

    try:
        conn = PurposeConnection(server_path)
        conn.send({"percent": 5})
        payload = conn.read_input()
        input_url = _pick_input_url(payload)

        conn.send({"percent": 20})
        config = load_config()

        conn.send({"percent": 40})
        output_url = upload(input_url, config)

        _try_send({"percent": 100, "output": {"url": output_url}})
        return 0
    except (PurposeIoError, ConfigError, UploadError) as exc:
        _try_send({"error": 1, "errorText": str(exc)})
        return 1
    except Exception as exc:  # defensive fallback for unexpected errors
        _try_send({"error": 1, "errorText": f"unexpected plugin failure: {exc}"})
        return 1
    finally:
        if conn is not None:
            conn.close()


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Purpose external-process uploader for Spectacle")
    parser.add_argument("--server", required=True, help="Purpose local socket path")
    parser.add_argument("--pluginType")
    parser.add_argument("--pluginPath")
    args = parser.parse_args(argv)

    if not args.server:
        sys.stderr.write("missing --server\n")
        return 2

    if not os.path.exists(args.server):
        sys.stderr.write(f"purpose server socket does not exist: {args.server}\n")
        return 2

    return _run(args.server)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
