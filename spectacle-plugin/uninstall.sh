#!/bin/sh

set -eu

PLUGIN_ID="spectacle-upload-plugin"
TARGET_BASE="${XDG_DATA_HOME:-$HOME/.local/share}/kpackage/Purpose"
TARGET_DIR="$TARGET_BASE/$PLUGIN_ID"

if [ -d "$TARGET_DIR" ]; then
    rm -rf "$TARGET_DIR"
    printf '%s\n' "Removed Spectacle plugin from: $TARGET_DIR"
else
    printf '%s\n' "Plugin is not installed at: $TARGET_DIR"
fi
