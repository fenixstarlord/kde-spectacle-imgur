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

prompt_for_client_id() {
    printf '%s' "Imgur client ID: " >&2
    IFS= read -r IMGUR_CLIENT_ID || die "failed to read Imgur client ID"
    [ -n "$IMGUR_CLIENT_ID" ] || die "Imgur client ID is required"
}

json_get_link() {
    python3 -c 'import json, sys
data = json.load(sys.stdin)
if not data.get("success"):
    raise SystemExit(data)
print(data["data"]["link"])
'
}

json_get_error() {
    python3 -c 'import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    raise SystemExit(1)

if not isinstance(data, dict):
    raise SystemExit(1)

payload = data.get("data")
if isinstance(payload, dict):
    err = payload.get("error")
    if isinstance(err, dict):
        err = err.get("message")
    if err:
        print(err)
        raise SystemExit(0)

raise SystemExit(1)
'
}

upload_to_imgur() {
    response_file=$tmp_dir/imgur-response.json
    http_code=$(curl -sS -o "$response_file" -w '%{http_code}' \
        -H "Authorization: Client-ID $IMGUR_CLIENT_ID" \
        -F "image=@$shot_file" \
        "$IMGUR_API_URL") || die "Imgur upload request failed"

    upload_response=$(cat "$response_file")

    if [ "$http_code" -lt 200 ] || [ "$http_code" -ge 300 ]; then
        api_error=$(printf '%s' "$upload_response" | json_get_error || true)

        case "$http_code" in
            403)
                die "Imgur rejected the Client ID (HTTP 403). Use the app's Client ID value.${api_error:+ API says: $api_error}"
                ;;
            429)
                die "Imgur rate limit hit (HTTP 429). Wait and retry, or use a different Client ID.${api_error:+ API says: $api_error}"
                ;;
            *)
                die "Imgur upload failed (HTTP $http_code).${api_error:+ API says: $api_error}"
                ;;
        esac
    fi

    printf '%s' "$upload_response"
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

[ -n "$IMGUR_CLIENT_ID" ] || prompt_for_client_id

printf '%s\n' "Select a region in Spectacle..." >&2
if ! "$SPECTACLE_BIN" -b -n -r -o "$shot_file"; then
    die "Spectacle capture failed or was cancelled"
fi

[ -s "$shot_file" ] || die "Spectacle did not create an image file"

upload_response=$(upload_to_imgur)

imgur_url=$(printf '%s' "$upload_response" | json_get_link) || die "failed to parse Imgur response"

copy_to_clipboard "$imgur_url"

printf '%s\n' "$imgur_url"
