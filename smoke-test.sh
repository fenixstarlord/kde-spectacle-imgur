#!/bin/sh

set -eu

WORKDIR=$(mktemp -d)
cleanup() {
    rm -rf "$WORKDIR"
}
trap cleanup EXIT

BIN_DIR="$WORKDIR/bin"
mkdir -p "$BIN_DIR"

cat >"$BIN_DIR/fake-spectacle" <<'EOF'
#!/bin/sh
set -eu

out_file=""
expect_next=""
for arg in "$@"; do
    if [ "$expect_next" = "1" ]; then
        out_file="$arg"
        expect_next=""
        continue
    fi

    case "$arg" in
        -o)
            expect_next="1"
            ;;
    esac
done

if [ -z "$out_file" ]; then
    echo "fake-spectacle: missing output path" >&2
    exit 1
fi

printf 'PNGDATA' > "$out_file"
EOF
chmod +x "$BIN_DIR/fake-spectacle"

cat >"$BIN_DIR/curl" <<'EOF'
#!/bin/sh
set -eu

output_file=""
target_url=""
expect_file=""
catbox_attempt_file=${CATBOX_RETRY_STATE_FILE-/tmp/catbox-attempts}

for arg in "$@"; do
    if [ "$expect_file" = "1" ]; then
        output_file="$arg"
        expect_file=""
        continue
    fi

    case "$arg" in
        -o)
            expect_file="1"
            ;;
        -*)
            :
            ;;
        *)
            target_url="$arg"
            ;;
    esac
done

if [ -z "$output_file" ]; then
    echo "fake curl: missing -o path" >&2
    exit 1
fi

if printf '%s' "$target_url" | grep -q 'api\.imgur\.com'; then
    printf '%s' '{"success":true,"data":{"link":"https://imgur.example.com/fake.png"}}' > "$output_file"
elif printf '%s' "$target_url" | grep -q '0x0\.st'; then
    printf '%s' 'https://0x0.example.com/fake.png' > "$output_file"
elif printf '%s' "$target_url" | grep -q 'catbox\.moe'; then
    if [ "${CATBOX_EMPTY_THEN_SUCCESS-}" = "1" ]; then
        attempt=1
        if [ -f "$catbox_attempt_file" ]; then
            attempt=$(cat "$catbox_attempt_file")
        fi
        case "$attempt" in ''|*[!0-9]*) attempt=1;; esac
        if [ "$attempt" -eq 1 ]; then
            : > "$output_file"
        else
            printf '%s' 'https://files.catbox.moe/fake.png' > "$output_file"
        fi
        attempt=$((attempt + 1))
        printf '%s' "$attempt" > "$catbox_attempt_file"
    else
        printf '%s' 'https://files.catbox.moe/fake.png' > "$output_file"
    fi
else
    printf '%s' '{"success":false}' > "$output_file"
fi

printf '200'
EOF
chmod +x "$BIN_DIR/curl"

PROJECT_DIR=$(cd "$(dirname "$0")" && pwd)
PATH="$BIN_DIR:$PATH"

echo "1/6: imgur success path"
IMGUR_STDOUT="$WORKDIR/imgur.out"
IMGUR_STDERR="$WORKDIR/imgur.err"
SPECTACLE_BIN="$BIN_DIR/fake-spectacle" \
UPLOAD_PROVIDER=imgur \
IMGUR_AUTH_MODE=anonymous \
IMGUR_CLIENT_ID=test-client \
COPY_BIN=true \
PATH="$BIN_DIR:$PATH" \
"$PROJECT_DIR/spectacle-imgur.sh" >"$IMGUR_STDOUT" 2>"$IMGUR_STDERR"

if ! grep -q 'https://imgur\.example\.com/fake\.png' "$IMGUR_STDOUT"; then
    echo "imgur smoke test failed" >&2
    cat "$IMGUR_STDOUT" "$IMGUR_STDERR" >&2
    exit 1
fi

echo "2/6: 0x0 success path"
ZERO_STDOUT="$WORKDIR/0x0.out"
ZERO_STDERR="$WORKDIR/0x0.err"
SPECTACLE_BIN="$BIN_DIR/fake-spectacle" \
UPLOAD_PROVIDER=0x0 \
COPY_BIN=true \
PATH="$BIN_DIR:$PATH" \
"$PROJECT_DIR/spectacle-imgur.sh" >"$ZERO_STDOUT" 2>"$ZERO_STDERR"

if ! grep -q 'https://0x0\.example\.com/fake\.png' "$ZERO_STDOUT"; then
    echo "0x0 smoke test failed" >&2
    cat "$ZERO_STDOUT" "$ZERO_STDERR" >&2
    exit 1
fi

echo "3/6: catbox success path"
CATBOX_STDOUT="$WORKDIR/catbox.out"
CATBOX_STDERR="$WORKDIR/catbox.err"
SPECTACLE_BIN="$BIN_DIR/fake-spectacle" \
UPLOAD_PROVIDER=catbox \
COPY_BIN=true \
PATH="$BIN_DIR:$PATH" \
"$PROJECT_DIR/spectacle-imgur.sh" >"$CATBOX_STDOUT" 2>"$CATBOX_STDERR"

if ! grep -q 'https://files\.catbox\.moe/fake\.png' "$CATBOX_STDOUT"; then
    echo "catbox smoke test failed" >&2
    cat "$CATBOX_STDOUT" "$CATBOX_STDERR" >&2
    exit 1
fi

echo "4/6: catbox retry on empty response"
CATBOX_RETRY_STDOUT="$WORKDIR/catbox-retry.out"
CATBOX_RETRY_STDERR="$WORKDIR/catbox-retry.err"
CATBOX_RETRY_STATE="$WORKDIR/catbox-retry-state"
SPECTACLE_BIN="$BIN_DIR/fake-spectacle" \
UPLOAD_PROVIDER=catbox \
COPY_BIN=true \
CATBOX_EMPTY_THEN_SUCCESS=1 \
CATBOX_RETRY_STATE_FILE="$CATBOX_RETRY_STATE" \
PATH="$BIN_DIR:$PATH" \
"$PROJECT_DIR/spectacle-imgur.sh" >"$CATBOX_RETRY_STDOUT" 2>"$CATBOX_RETRY_STDERR"

if ! grep -q 'https://files\.catbox\.moe/fake\.png' "$CATBOX_RETRY_STDOUT"; then
    echo "catbox retry smoke test failed" >&2
    cat "$CATBOX_RETRY_STDOUT" "$CATBOX_RETRY_STDERR" >&2
    exit 1
fi

if [ "$(cat "$CATBOX_RETRY_STATE")" != "3" ]; then
    echo "catbox retry attempt count was not two attempts" >&2
    cat "$CATBOX_RETRY_STDOUT" "$CATBOX_RETRY_STDERR" >&2
    exit 1
fi

echo "5/6: clipboard failure path"
CLIP_STDOUT="$WORKDIR/clipboard.out"
CLIP_STDERR="$WORKDIR/clipboard.err"
SPECTACLE_BIN="$BIN_DIR/fake-spectacle" \
UPLOAD_PROVIDER=0x0 \
COPY_BIN=false \
PATH="$BIN_DIR:$PATH" \
"$PROJECT_DIR/spectacle-imgur.sh" >"$CLIP_STDOUT" 2>"$CLIP_STDERR"

if ! grep -q 'Warning: failed to copy URL to clipboard with false' "$CLIP_STDERR"; then
    echo "clipboard warning test failed" >&2
    cat "$CLIP_STDOUT" "$CLIP_STDERR" >&2
    exit 1
fi

echo "6/6: plugin install/uninstall lifecycle"
PLUGIN_ROOT="$PROJECT_DIR/spectacle-plugin"
XDG_TMP="$WORKDIR/plugin-home"
TARGET_DIR="$XDG_TMP/kpackage/Purpose/spectacle-upload-plugin"

cd "$PLUGIN_ROOT"
chmod +x install.sh uninstall.sh
XDG_DATA_HOME="$XDG_TMP" ./install.sh >/dev/null

if [ ! -x "$TARGET_DIR/contents/code/main.py" ] || [ ! -f "$TARGET_DIR/metadata.json" ]; then
    echo "plugin install validation failed" >&2
    exit 1
fi

XDG_DATA_HOME="$XDG_TMP" ./uninstall.sh >/dev/null

if [ -e "$TARGET_DIR" ]; then
    echo "plugin uninstall validation failed" >&2
    exit 1
fi

echo "SMOKE TEST PASSED"
