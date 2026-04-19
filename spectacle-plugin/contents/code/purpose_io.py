#!/usr/bin/env python3

from __future__ import annotations

import json
import socket

from cbor_min import decode as decode_cbor


class PurposeIoError(RuntimeError):
    pass


class PurposeConnection:
    def __init__(self, server_path: str):
        self._sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self._sock.connect(server_path)
        self._reader = self._sock.makefile("rb")

    def close(self) -> None:
        try:
            self._reader.close()
        except Exception:
            pass
        finally:
            try:
                self._sock.close()
            except Exception:
                pass

    def read_input(self):
        line = self._reader.readline()
        if not line:
            raise PurposeIoError("purpose socket closed before input length was read")
        try:
            expected = int(line.strip() or b"0")
        except ValueError as exc:
            raise PurposeIoError("invalid purpose input length") from exc

        payload = self._reader.read(expected)
        if len(payload) != expected:
            raise PurposeIoError("incomplete purpose CBOR payload")

        return decode_cbor(payload)

    def send(self, payload: dict) -> None:
        data = (json.dumps(payload, separators=(",", ":")) + "\n").encode("utf-8")
        self._sock.sendall(data)
