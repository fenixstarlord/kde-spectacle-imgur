#!/usr/bin/env python3

"""Minimal CBOR decoder for Purpose external process payloads.

This decoder intentionally supports only the subset we need for Purpose data:
- unsigned and negative integers
- byte and text strings
- arrays and maps (definite length)
- booleans, null, and float16/32/64
"""

from __future__ import annotations

import struct


class CborDecodeError(ValueError):
    pass


class _Reader:
    def __init__(self, payload: bytes):
        self.payload = payload
        self.offset = 0

    def read(self, size: int) -> bytes:
        end = self.offset + size
        if end > len(self.payload):
            raise CborDecodeError("unexpected end of CBOR payload")
        chunk = self.payload[self.offset : end]
        self.offset = end
        return chunk

    def read_u8(self) -> int:
        return self.read(1)[0]


def _decode_length(reader: _Reader, additional: int) -> int:
    if additional < 24:
        return additional
    if additional == 24:
        return reader.read_u8()
    if additional == 25:
        return struct.unpack(">H", reader.read(2))[0]
    if additional == 26:
        return struct.unpack(">I", reader.read(4))[0]
    if additional == 27:
        return struct.unpack(">Q", reader.read(8))[0]
    raise CborDecodeError("indefinite length is not supported")


def _decode_float16(value: int) -> float:
    sign = -1.0 if (value & 0x8000) else 1.0
    exponent = (value >> 10) & 0x1F
    fraction = value & 0x03FF
    if exponent == 0:
        if fraction == 0:
            return sign * 0.0
        return sign * (2 ** -14) * (fraction / 1024.0)
    if exponent == 31:
        if fraction == 0:
            return sign * float("inf")
        return float("nan")
    return sign * (2 ** (exponent - 15)) * (1.0 + (fraction / 1024.0))


def _decode_item(reader: _Reader):
    initial = reader.read_u8()
    major = initial >> 5
    additional = initial & 0x1F

    if major == 0:
        return _decode_length(reader, additional)

    if major == 1:
        return -1 - _decode_length(reader, additional)

    if major == 2:
        size = _decode_length(reader, additional)
        return reader.read(size)

    if major == 3:
        size = _decode_length(reader, additional)
        return reader.read(size).decode("utf-8")

    if major == 4:
        size = _decode_length(reader, additional)
        return [_decode_item(reader) for _ in range(size)]

    if major == 5:
        size = _decode_length(reader, additional)
        result = {}
        for _ in range(size):
            key = _decode_item(reader)
            value = _decode_item(reader)
            result[key] = value
        return result

    if major == 7:
        if additional == 20:
            return False
        if additional == 21:
            return True
        if additional == 22:
            return None
        if additional == 25:
            return _decode_float16(struct.unpack(">H", reader.read(2))[0])
        if additional == 26:
            return struct.unpack(">f", reader.read(4))[0]
        if additional == 27:
            return struct.unpack(">d", reader.read(8))[0]
        raise CborDecodeError(f"unsupported simple value (additional={additional})")

    raise CborDecodeError(f"unsupported major type: {major}")


def decode(payload: bytes):
    reader = _Reader(payload)
    value = _decode_item(reader)
    if reader.offset != len(payload):
        raise CborDecodeError("trailing bytes in CBOR payload")
    return value
