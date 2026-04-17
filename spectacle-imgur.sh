#!/bin/sh

set -eu

SCRIPT_NAME=${0##*/}
SPECTACLE_BIN=${SPECTACLE_BIN:-spectacle}
IMGUR_CLIENT_ID=${IMGUR_CLIENT_ID:-}
IMGUR_API_URL=${IMGUR_API_URL:-https://api.imgur.com/3/image}
COPY_BIN=${COPY_BIN:-wl-copy}

die() {
    printf '%s: %s\n' "$SCRIPT_NAME" "$*" >&2
    exit 1
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

json_get_link() {
    python3 -c 'import json, sys
data = json.load(sys.stdin)
if not data.get("success"):
    raise SystemExit(data)
print(data["data"]["link"])
'
}

copy_to_clipboard() {
    if command -v "$COPY_BIN" >/dev/null 2>&1; then
        printf '%s' "$1" | "$COPY_BIN"
        return 0
    fi

    die "missing clipboard command: $COPY_BIN (install it with: brew install wl-clipboard)"
}

tmp_dir=$(mktemp -d 2>/dev/null || mktemp -d -t spectacle-imgur)
cleanup() {
    rm -rf "$tmp_dir"
}
trap cleanup EXIT HUP INT TERM

shot_file=$tmp_dir/spectacle-region.png

require_cmd "$SPECTACLE_BIN"
require_cmd curl
require_cmd python3
require_cmd "$COPY_BIN"

[ -n "$IMGUR_CLIENT_ID" ] || die "set IMGUR_CLIENT_ID to an Imgur client id"

printf '%s\n' "Select a region in Spectacle..." >&2
if ! "$SPECTACLE_BIN" -b -n -r -o "$shot_file"; then
    die "Spectacle capture failed or was cancelled"
fi

[ -s "$shot_file" ] || die "Spectacle did not create an image file"

upload_response=$(curl -fsS \
    -H "Authorization: Client-ID $IMGUR_CLIENT_ID" \
    -F "image=@$shot_file" \
    "$IMGUR_API_URL") || die "Imgur upload failed"

imgur_url=$(printf '%s' "$upload_response" | json_get_link) || die "failed to parse Imgur response"

copy_to_clipboard "$imgur_url"

printf '%s\n' "$imgur_url"
