#!/bin/sh

set -eu

SCRIPT_NAME=${0##*/}
SPECTACLE_BIN=${SPECTACLE_BIN:-spectacle}
UPLOAD_PROVIDER=${UPLOAD_PROVIDER:-}
IMGUR_AUTH_MODE=${IMGUR_AUTH_MODE:-}
IMGUR_CLIENT_ID=${IMGUR_CLIENT_ID:-}
IMGUR_ACCESS_TOKEN=${IMGUR_ACCESS_TOKEN:-}
IMGUR_API_URL=${IMGUR_API_URL:-https://api.imgur.com/3/image}
ZEROX0_API_URL=${ZEROX0_API_URL:-https://0x0.st}
CATBOX_API_URL=${CATBOX_API_URL:-https://catbox.moe/user/api.php}
CATBOX_USERHASH=${CATBOX_USERHASH:-}
CATBOX_MAX_RETRIES=${CATBOX_MAX_RETRIES:-1}
CATBOX_HTTP1_FALLBACK=${CATBOX_HTTP1_FALLBACK:-1}
COPY_BIN=${COPY_BIN:-wl-copy}

# Set DEBUG=1 for verbose tracing (runtime env + clipboard stderr capture).
DEBUG=${DEBUG:-0}
SAVE_SCREENSHOT_TO_DESKTOP=${SAVE_SCREENSHOT_TO_DESKTOP:-$DEBUG}

die() {
    printf '%s: %s\n' "$SCRIPT_NAME" "$*" >&2
    exit 1
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

ensure_clipboard_cmd() {
    if command -v "$COPY_BIN" >/dev/null 2>&1; then
        return 0
    fi

    if [ "$COPY_BIN" != "wl-copy" ]; then
        die "missing clipboard command: $COPY_BIN"
    fi

    if ! command -v brew >/dev/null 2>&1; then
        cat >&2 <<'EOF'
missing clipboard command: wl-copy
Install it from your OS package manager and rerun.

Fedora / Bazzite: sudo dnf install wl-clipboard
Debian / Ubuntu:  sudo apt install wl-clipboard
Arch / Manjaro:   sudo pacman -S wl-clipboard
EOF
        return 1
    fi

    printf '%s\n' "wl-copy not found; installing wl-clipboard with Homebrew..." >&2
    if ! brew install wl-clipboard >/dev/null; then
        cat >&2 <<'EOF'
Homebrew install for wl-clipboard failed (formula not available in this tap).
Install it from your OS package manager and rerun, or set COPY_BIN to a compatible command.

Fedora / Bazzite: sudo dnf install wl-clipboard
Debian / Ubuntu:  sudo apt install wl-clipboard
Arch / Manjaro:   sudo pacman -S wl-clipboard
EOF
        return 1
    fi

    command -v "$COPY_BIN" >/dev/null 2>&1 || die "Homebrew install completed, but wl-copy is still not on PATH"
}

prompt_for_client_id() {
    printf '%s' "Imgur client ID: " >&2
    IFS= read -r IMGUR_CLIENT_ID || die "failed to read Imgur client ID"
    [ -n "$IMGUR_CLIENT_ID" ] || die "Imgur client ID is required"
}

prompt_for_access_token() {
    printf '%s' "Imgur access token: " >&2
    IFS= read -r IMGUR_ACCESS_TOKEN || die "failed to read Imgur access token"
    [ -n "$IMGUR_ACCESS_TOKEN" ] || die "Imgur access token is required"
}

is_interactive() {
    [ -t 0 ]
}

ensure_imgur_client_id() {
    [ -n "$IMGUR_CLIENT_ID" ] && return 0

    if is_interactive; then
        prompt_for_client_id
        return 0
    fi

    die "IMGUR_CLIENT_ID is required for IMGUR_AUTH_MODE=anonymous in non-interactive mode"
}

ensure_imgur_access_token() {
    [ -n "$IMGUR_ACCESS_TOKEN" ] && return 0

    if is_interactive; then
        prompt_for_access_token
        return 0
    fi

    die "IMGUR_ACCESS_TOKEN is required for IMGUR_AUTH_MODE=login in non-interactive mode"
}

prompt_for_upload_provider() {
    printf '%s\n' "Upload provider:" >&2
    printf '%s\n' "  1) Imgur" >&2
    printf '%s\n' "  2) 0x0 (anonymous, no API key)" >&2
    printf '%s\n' "  3) Catbox (anonymous, no API key)" >&2
    printf '%s' "Choose provider [1]: " >&2

    if ! IFS= read -r choice; then
        choice=""
        log_debug "stdin read failed for upload provider prompt; defaulting to 1 (imgur)"
    fi
    choice=$(printf '%s' "$choice" | tr '[:upper:]' '[:lower:]')

    case "$choice" in
        ""|1|imgur)
            UPLOAD_PROVIDER=imgur
            ;;
        2|0x0|0x0.st|zerox0)
            UPLOAD_PROVIDER=0x0
            ;;
        3|catbox|catbox.moe)
            UPLOAD_PROVIDER=catbox
            ;;
        *)
            die "invalid upload provider choice: $choice"
            ;;
    esac
}

prompt_for_imgur_auth_mode() {
    printf '%s\n' "Imgur mode:" >&2
    printf '%s\n' "  1) Anonymous (Client ID)" >&2
    printf '%s\n' "  2) Login (Access token)" >&2
    printf '%s' "Choose Imgur mode [1]: " >&2

    if ! IFS= read -r choice; then
        choice=""
        log_debug "stdin read failed for imgur auth mode prompt; defaulting to 1 (anonymous)"
    fi
    choice=$(printf '%s' "$choice" | tr '[:upper:]' '[:lower:]')

    case "$choice" in
        ""|1|anonymous)
            IMGUR_AUTH_MODE=anonymous
            ;;
        2|login)
            IMGUR_AUTH_MODE=login
            ;;
        *)
            die "invalid Imgur mode choice: $choice"
            ;;
    esac
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
    case "$IMGUR_AUTH_MODE" in
        auto)
            if [ -n "$IMGUR_ACCESS_TOKEN" ]; then
                auth_header="Authorization: Bearer $IMGUR_ACCESS_TOKEN"
                imgur_auth_mode=login
            else
                ensure_imgur_client_id
                auth_header="Authorization: Client-ID $IMGUR_CLIENT_ID"
                imgur_auth_mode=anonymous
            fi
            ;;
        anonymous)
            ensure_imgur_client_id
            auth_header="Authorization: Client-ID $IMGUR_CLIENT_ID"
            imgur_auth_mode=anonymous
            ;;
        login)
            ensure_imgur_access_token
            auth_header="Authorization: Bearer $IMGUR_ACCESS_TOKEN"
            imgur_auth_mode=login
            ;;
        *)
            die "unsupported IMGUR_AUTH_MODE: $IMGUR_AUTH_MODE (use: auto, anonymous, login)"
            ;;
    esac

    response_file=$tmp_dir/imgur-response.json
    http_code=$(curl -sS -o "$response_file" -w '%{http_code}' \
        -H "$auth_header" \
        -F "image=@$shot_file" \
        "$IMGUR_API_URL") || die "Imgur upload request failed"

    if [ "$http_code" -lt 200 ] || [ "$http_code" -ge 300 ]; then
        api_error=$(json_get_error <"$response_file" || true)

        case "$http_code" in
            401)
                die "Imgur login token is invalid or expired (HTTP 401). Refresh IMGUR_ACCESS_TOKEN.${api_error:+ API says: $api_error}"
                ;;
            403)
                if [ "$imgur_auth_mode" = "login" ]; then
                    die "Imgur rejected the login token (HTTP 403). Check token scopes and account status.${api_error:+ API says: $api_error}"
                fi

                die "Imgur rejected the Client ID (HTTP 403). Use the app's Client ID value.${api_error:+ API says: $api_error}"
                ;;
            429)
                if [ "$imgur_auth_mode" = "login" ]; then
                    die "Imgur rate limit hit for the logged-in account (HTTP 429). Wait and retry.${api_error:+ API says: $api_error}"
                fi

                die "Imgur rate limit hit (HTTP 429). Wait and retry, or use a different Client ID.${api_error:+ API says: $api_error}"
                ;;
            *)
                die "Imgur upload failed (HTTP $http_code).${api_error:+ API says: $api_error}"
                ;;
        esac
    fi

    imgur_url=$(json_get_link <"$response_file") || die "failed to parse Imgur response"

    printf '%s' "$imgur_url"
}

upload_to_0x0() {
    response_file=$tmp_dir/0x0-response.txt
    http_code=$(curl -sS -o "$response_file" -w '%{http_code}' \
        -F "file=@$shot_file" \
        "$ZEROX0_API_URL") || die "0x0 upload request failed"

    if [ "$http_code" -lt 200 ] || [ "$http_code" -ge 300 ]; then
        upload_response=$(tr -d '\r' <"$response_file")
        die "0x0 upload failed (HTTP $http_code).${upload_response:+ Response: $upload_response}"
    fi

    IFS= read -r upload_url <"$response_file" || true

    [ -n "$upload_url" ] || die "0x0 upload succeeded but returned an empty URL"

    printf '%s' "$upload_url"
}

upload_to_catbox() {
    response_file=$tmp_dir/catbox-response.txt
    header_file=$tmp_dir/catbox-headers.txt

    max_retries=$CATBOX_MAX_RETRIES
    case "$max_retries" in
        ''|*[!0-9]*)
            max_retries=1
            ;;
    esac
    [ "$max_retries" -ge 0 ] || max_retries=0

    attempt=0
    while :; do
        attempt=$((attempt + 1))

        use_http1=0
        if [ "$attempt" -gt 1 ] && [ "$CATBOX_HTTP1_FALLBACK" = "1" ]; then
            use_http1=1
        fi

        if [ "$DEBUG" = "1" ]; then
            if [ "$use_http1" -eq 1 ]; then
                log_debug "catbox retry $attempt/$((max_retries + 1)): forcing --http1.1"
            else
                log_debug "catbox attempt $attempt/$((max_retries + 1)): default curl settings"
            fi
        fi

        : >"$header_file"
        if [ "$use_http1" -eq 1 ]; then
            http_code=$(curl --http1.1 -sS -D "$header_file" -o "$response_file" -w '%{http_code}' \
                -F "reqtype=fileupload" \
                ${CATBOX_USERHASH:+-F "userhash=$CATBOX_USERHASH"} \
                -F "fileToUpload=@$shot_file" \
                "$CATBOX_API_URL") || die "Catbox upload request failed"
        else
            http_code=$(curl -sS -D "$header_file" -o "$response_file" -w '%{http_code}' \
                -F "reqtype=fileupload" \
                ${CATBOX_USERHASH:+-F "userhash=$CATBOX_USERHASH"} \
                -F "fileToUpload=@$shot_file" \
                "$CATBOX_API_URL") || die "Catbox upload request failed"
        fi

        [ "$DEBUG" = "1" ] && log_debug "catbox shot file size: $(wc -c <"$shot_file") bytes"
        response_size=$(wc -c <"$response_file")
        header_status=$(head -n 1 "$header_file" 2>/dev/null || true)
        header_content_type=$(grep -i '^content-type:' "$header_file" 2>/dev/null | head -n 1 | tr -d '\r')

        if [ "$DEBUG" = "1" ]; then
            log_debug "catbox response status line: ${header_status:-<missing>}"
            log_debug "catbox response content-type: ${header_content_type:-<missing>}"
            log_debug "catbox response size: ${response_size:-0} bytes"
            log_debug "catbox response: $(tr -d '\r' <"$response_file" | head -c 240)"
        fi

        if [ "$http_code" -lt 200 ] || [ "$http_code" -ge 300 ]; then
            upload_response=$(tr -d '\r' <"$response_file")
            die "Catbox upload failed (HTTP $http_code).${upload_response:+ Response: $upload_response}"
        fi

        upload_response=$(tr -d '\r' <"$response_file")
        upload_url=$(printf '%s\n' "$upload_response" | grep -Eo 'https?://[^[:space:]]+' | head -n 1 || true)

        if [ -n "$upload_url" ]; then
            printf '%s' "$upload_url"
            return 0
        fi

        if [ -n "$upload_response" ]; then
            die "Catbox upload returned a non-URL response (HTTP $http_code). Response: $upload_response"
        fi

        if [ "$attempt" -le "$max_retries" ]; then
            [ "$DEBUG" = "1" ] && log_debug "Catbox upload returned an empty response; retrying"
            continue
        fi

        die "Catbox upload succeeded but returned an empty URL"
    done
}

upload_screenshot() {
    case "$UPLOAD_PROVIDER" in
        imgur)
            upload_to_imgur
            ;;
        0x0)
            upload_to_0x0
            ;;
        catbox)
            upload_to_catbox
            ;;
        *)
            die "unsupported UPLOAD_PROVIDER: $UPLOAD_PROVIDER (use: imgur, 0x0, or catbox)"
            ;;
    esac
}

copy_to_clipboard() {
    if command -v "$COPY_BIN" >/dev/null 2>&1; then
        copy_stderr_file="$tmp_dir/clipboard-stderr"
        : >"$copy_stderr_file"

        if printf '%s' "$1" | "$COPY_BIN" 2>"$copy_stderr_file"; then
            copy_status=0
        else
            copy_status=$?
        fi

        if [ "$DEBUG" = "1" ] && [ -s "$copy_stderr_file" ]; then
            log_debug "clipboard command stderr from $COPY_BIN:"
            while IFS= read -r copy_line; do
                log_debug "$copy_line"
            done <"$copy_stderr_file"
        fi

        return "$copy_status"
    fi

    printf '%s\n' "missing clipboard command: $COPY_BIN" >&2
    printf '%s\n' "Install it from your OS package manager, or set COPY_BIN to a compatible command." >&2
    printf '%s\n' "Fedora / Bazzite: sudo dnf install wl-clipboard" >&2
    printf '%s\n' "Debian / Ubuntu:  sudo apt install wl-clipboard" >&2
    printf '%s\n' "Arch / Manjaro:   sudo pacman -S wl-clipboard" >&2
    return 1
}

tmp_dir=$(mktemp -d 2>/dev/null || mktemp -d -t spectacle-imgur)
cleanup() {
    rm -rf "$tmp_dir"
}

log_debug() {
    [ "$DEBUG" = "1" ] || return 0
    printf 'DEBUG: %s\n' "$*" >&2
}

log_env_debug() {
    [ "$DEBUG" = "1" ] || return 0
    {
        printf '%s\n' '--- runtime debug ---'
        printf 'SCRIPT_NAME=%s\n' "$SCRIPT_NAME"
        printf 'SPECTACLE_BIN=%s\n' "$SPECTACLE_BIN"
        printf 'UPLOAD_PROVIDER=%s\n' "$UPLOAD_PROVIDER"
        printf 'IMGUR_AUTH_MODE=%s\n' "$IMGUR_AUTH_MODE"
        printf 'CATBOX_API_URL=%s\n' "$CATBOX_API_URL"
        printf 'CATBOX_MAX_RETRIES=%s\n' "$CATBOX_MAX_RETRIES"
        printf 'CATBOX_HTTP1_FALLBACK=%s\n' "$CATBOX_HTTP1_FALLBACK"
        printf 'COPY_BIN=%s\n' "$COPY_BIN"
        printf 'SAVE_SCREENSHOT_TO_DESKTOP=%s\n' "$SAVE_SCREENSHOT_TO_DESKTOP"
        printf 'XDG_SESSION_TYPE=%s\n' "${XDG_SESSION_TYPE-}"
        printf 'WAYLAND_DISPLAY=%s\n' "${WAYLAND_DISPLAY-}"
        printf 'XDG_RUNTIME_DIR=%s\n' "${XDG_RUNTIME_DIR-}"
        printf 'DISPLAY=%s\n' "${DISPLAY-}"
        printf 'TMP_DIR=%s\n' "$tmp_dir"
        printf 'SHOT_FILE=%s\n' "$shot_file"
        printf '%s\n' '--------------------'
    } >&2
}

save_screenshot_to_desktop() {
    [ "$SAVE_SCREENSHOT_TO_DESKTOP" = "1" ] || return 0

    desktop_dir="${XDG_DESKTOP_DIR:-${HOME:-/tmp}/Desktop}"
    if [ ! -d "$desktop_dir" ] && ! mkdir -p "$desktop_dir"; then
        log_debug "desktop directory does not exist and could not be created: $desktop_dir"
        return 0
    fi

    if [ ! -d "$desktop_dir" ]; then
        log_debug "desktop directory is not available: $desktop_dir"
        return 0
    fi

    shot_basename="spectacle-region-$(date +%Y%m%d-%H%M%S).png"
    shot_copy="$desktop_dir/$shot_basename"

    if cp "$shot_file" "$shot_copy"; then
        log_debug "saved screenshot copy for debugging: $shot_copy"
        printf '%s\n' "Debug: saved screenshot copy to: $shot_copy"
    else
        log_debug "failed to save screenshot copy to desktop: $shot_copy"
    fi
}
trap cleanup EXIT HUP INT TERM

shot_file=$tmp_dir/spectacle-region.png

log_debug "temporary directory: $tmp_dir"
log_debug "screenshot path: $shot_file"

require_cmd "$SPECTACLE_BIN"
require_cmd curl
ensure_clipboard_cmd

if [ -z "$UPLOAD_PROVIDER" ]; then
    if is_interactive; then
        prompt_for_upload_provider
    else
        UPLOAD_PROVIDER=imgur
    fi
fi

case "$UPLOAD_PROVIDER" in
    imgur)
        require_cmd python3
        if [ -z "$IMGUR_AUTH_MODE" ]; then
            if is_interactive; then
                prompt_for_imgur_auth_mode
            else
                IMGUR_AUTH_MODE=auto
            fi
        fi
        ;;
    0x0|0x0.st|zerox0)
        UPLOAD_PROVIDER=0x0
        ;;
    catbox|catbox.moe)
        UPLOAD_PROVIDER=catbox
        ;;
    *)
        die "unsupported UPLOAD_PROVIDER: $UPLOAD_PROVIDER (use: imgur, 0x0, or catbox)"
        ;;
esac

log_env_debug

log_debug "resolved upload provider: $UPLOAD_PROVIDER"
log_debug "resolved imgur auth mode: $IMGUR_AUTH_MODE"

printf '%s\n' "Select a region in Spectacle..." >&2
if ! "$SPECTACLE_BIN" -b -n -r -o "$shot_file"; then
    die "Spectacle capture failed or was cancelled"
fi

[ -s "$shot_file" ] || die "Spectacle did not create an image file"

save_screenshot_to_desktop

upload_url=$(upload_screenshot)
log_debug "upload_url: $upload_url"

case "$upload_url" in
    http://*|https://*)
        ;;
    *)
        die "upload succeeded but returned an invalid URL: $upload_url"
        ;;
esac

printf '%s\n' "$upload_url"

if ! copy_to_clipboard "$upload_url"; then
    printf '%s\n' "Warning: failed to copy URL to clipboard with $COPY_BIN" >&2
fi

exit 0
