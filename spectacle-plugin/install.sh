#!/bin/sh

set -eu

die() {
    printf '%s\n' "$*" >&2
    exit 1
}

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PLUGIN_ID="spectacle-upload-plugin"
TARGET_BASE="${XDG_DATA_HOME:-$HOME/.local/share}/kpackage/Purpose"
TARGET_DIR="$TARGET_BASE/$PLUGIN_ID"
BACKUP_DIR="$TARGET_DIR.bak.$$"
TMP_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t spectacle-plugin.XXXXXX)
WORK_DIR="$TMP_DIR/$PLUGIN_ID"

mkdir -p "$WORK_DIR"

mkdir -p "$TARGET_BASE"

if ! cp "$SCRIPT_DIR/metadata.json" "$WORK_DIR/metadata.json"; then
    rm -rf "$TMP_DIR"
    die "failed to copy metadata.json"
fi

if ! cp -R "$SCRIPT_DIR/contents" "$WORK_DIR/"; then
    rm -rf "$TMP_DIR"
    die "failed to copy plugin contents"
fi

chmod +x "$WORK_DIR/contents/code/main.py" || {
    rm -rf "$TMP_DIR"
    die "failed to set executable bit on main.py"
}

if [ -d "$TARGET_DIR" ]; then
    if ! mv "$TARGET_DIR" "$BACKUP_DIR"; then
        rm -rf "$TMP_DIR"
        die "failed to backup existing plugin at $TARGET_DIR"
    fi
fi

if ! mv "$WORK_DIR" "$TARGET_DIR"; then
    if [ -d "$BACKUP_DIR" ]; then
        mv "$BACKUP_DIR" "$TARGET_DIR" || true
    fi
    rm -rf "$TMP_DIR"
    die "failed to install plugin to $TARGET_DIR"
fi

rm -rf "$BACKUP_DIR"
rm -rf "$TMP_DIR"

printf '%s\n' "Installed Spectacle plugin to: $TARGET_DIR"
printf '%s\n' "Restart Spectacle to load the new plugin."
