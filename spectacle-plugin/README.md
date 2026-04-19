# Spectacle Upload Plugin (Standalone)

This is a standalone Purpose `Export` plugin for Spectacle.
It does not depend on `spectacle-imgur.sh`.

## What It Does

- Accepts a screenshot file from Spectacle's Export flow.
- Uploads to Imgur, 0x0, or Catbox.
- Returns the public URL back to Spectacle.

## Install (User-Local, Immutable-Friendly)

```bash
chmod +x install.sh
./install.sh
```

The plugin is installed into:

```text
~/.local/share/kpackage/Purpose/spectacle-upload-plugin
```

Restart Spectacle after installing.

## Uninstall

```bash
chmod +x uninstall.sh
./uninstall.sh
```

## Configuration

Set environment variables before launching Spectacle:

- `SPECTACLE_PLUGIN_PROVIDER` (`imgur`, `0x0`, or `catbox`, default `imgur`)
- `SPECTACLE_PLUGIN_IMGUR_AUTH_MODE` (`auto`, `anonymous`, `login`; default `auto`)
- `SPECTACLE_PLUGIN_IMGUR_CLIENT_ID` (required for anonymous Imgur mode)
- `SPECTACLE_PLUGIN_IMGUR_ACCESS_TOKEN` (required for login Imgur mode)
- `SPECTACLE_PLUGIN_IMGUR_API_URL` (default `https://api.imgur.com/3/image`)
- `SPECTACLE_PLUGIN_ZEROX0_API_URL` (default `https://0x0.st`)
- `SPECTACLE_PLUGIN_CATBOX_API_URL` (default `https://catbox.moe/user/api.php`)
- `SPECTACLE_PLUGIN_CATBOX_USERHASH` (optional, enables account-bound Catbox uploads)
- `SPECTACLE_PLUGIN_CATBOX_MAX_RETRIES` (default `1`, one retry after first empty response)
- `SPECTACLE_PLUGIN_CATBOX_HTTP1_FALLBACK` (`1` enables a second request style, default `1`)

Example:

```bash
export SPECTACLE_PLUGIN_PROVIDER=imgur
export SPECTACLE_PLUGIN_IMGUR_AUTH_MODE=anonymous
export SPECTACLE_PLUGIN_IMGUR_CLIENT_ID='your_client_id'
spectacle
```

Catbox example:

```bash
export SPECTACLE_PLUGIN_PROVIDER=catbox
spectacle
```

## Notes

- This plugin handles upload only.
- Capture behavior is still driven by Spectacle.
