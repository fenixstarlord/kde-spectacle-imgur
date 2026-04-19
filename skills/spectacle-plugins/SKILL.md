---
name: spectacle-plugins
description: >
  Build and maintain standalone KDE Spectacle upload integrations using Purpose
  Export plugins. Use this skill when creating or updating plugins under
  spectacle-plugin/, installer scripts, plugin metadata, or Purpose protocol
  bridge code.
---

# Spectacle Plugins

Build standalone Spectacle integrations through KDE Purpose plugin packages.
This repo keeps script and plugin programs separate.

## Mandatory docs step

Every time you work on the plugin package, you MUST read Purpose docs from source:

```bash
curl -s https://raw.githubusercontent.com/KDE/purpose/master/README.md
```

Never truncate this output with `head`, `tail`, `sed -n`, or similar commands.

## Package shape

Use this exact folder layout:

```text
spectacle-plugin/
  metadata.json
  install.sh
  uninstall.sh
  contents/
    code/
      main.py
      purpose_io.py
      uploader.py
      config.py
      cbor_min.py
    config/
      config.qml
```

## Installation target

Always install user-local for immutable systems:

```text
${XDG_DATA_HOME:-$HOME/.local/share}/kpackage/Purpose/<plugin-id>
```

Do not require root access, RPM layering, or system package writes.

## Plugin metadata rules

`metadata.json` must include:

- `KPlugin.Id` with a stable plugin id
- `X-Purpose-PluginTypes` containing `Export`
- `X-Purpose-ActionDisplay` text
- `X-Purpose-Constraints` with mime guards for supported images

## Runtime protocol rules

Purpose external-process plugins communicate over a local socket:

1. Read one line containing CBOR payload byte length.
2. Read exactly that many bytes.
3. Decode payload and process first `urls` entry.
4. Send newline-delimited JSON progress and result objects.

Success payload must include:

```json
{"output":{"url":"https://..."}}
```

Failure payload must include:

```json
{"error":1,"errorText":"..."}
```

## Validation commands

Run these checks before finishing:

```bash
python3 -m py_compile spectacle-plugin/contents/code/*.py
sh -n spectacle-plugin/install.sh
sh -n spectacle-plugin/uninstall.sh
```

## Non-goals

- Do not couple plugin runtime to `spectacle-imgur.sh`.
- Do not move capture logic into the plugin; Spectacle owns capture.
