# Dan's Super Awesome Spectacle Imgur Upload Script

Single-file Wayland workflow for Dan on Bazzite KDE:

1. Open Spectacle in region-select mode.
1. Capture a screenshot to a temp file.
1. Upload the file to Imgur or 0x0.
1. Copy the returned URL to the clipboard.

## Requirements

- Bazzite KDE already provides `spectacle` and `curl`
- `wl-copy` from `wl-clipboard` (the script can auto-install this with Homebrew if missing)
- `python3` is only required when using the Imgur provider

## Install wl-copy

Install `wl-copy` with Homebrew:

```bash
brew install wl-clipboard
```

If your shell does not see `wl-copy` right away, make sure Homebrew's `bin` is on `PATH`.

If `wl-copy` is missing and `brew` exists, the script will try to run `brew install wl-clipboard` automatically.

## Get Imgur Client ID (Anonymous Imgur Mode)

Create an Imgur app here:

https://api.imgur.com/oauth2/addclient

Use the app's `Client ID` value, not the secret.

## Imgur Login Mode (OAuth Access Token)

If you want uploads tied to your Imgur account, use a user access token:

```bash
IMGUR_AUTH_MODE=login IMGUR_ACCESS_TOKEN='your_access_token' ./spectacle-imgur.sh
```

In `imgur` provider mode:

- `IMGUR_AUTH_MODE=auto` (default): use `IMGUR_ACCESS_TOKEN` when set, otherwise use `IMGUR_CLIENT_ID`
- `IMGUR_AUTH_MODE=anonymous`: force Client ID mode
- `IMGUR_AUTH_MODE=login`: force Bearer token mode

When no terminal prompt is available (for example from a keybind or script), missing Imgur credentials now fail fast with a clear error instead of trying to prompt.

## Download

Copy and paste this code into your terminal:

```bash
curl -fsSL -o spectacle-imgur.sh \
  https://raw.githubusercontent.com/fenixstarlord/kde-spectacle-imgur/main/spectacle-imgur.sh
chmod +x spectacle-imgur.sh
```

What these commands do:

- `curl -fsSL -o spectacle-imgur.sh ...` downloads the script into a file named `spectacle-imgur.sh`
- `chmod +x spectacle-imgur.sh` makes the script runnable

## How To Use It

```bash
./spectacle-imgur.sh
```

What happens next:

- The script shows a menu to choose upload provider (`imgur` or `0x0`)
- If you choose Imgur, it shows a second menu for Imgur mode (`anonymous` or `login`)
- Spectacle opens in region-select mode
- You drag to select the area you want
- The script uploads the screenshot to the selected provider
- The returned URL is copied to your clipboard
- The script also prints the URL in the terminal

You can still skip the menu by setting environment variables before running the script.

### Anonymous Provider (No Client ID)

Use 0x0 for an anonymous upload flow with no API key:

```bash
UPLOAD_PROVIDER=0x0 ./spectacle-imgur.sh
```

## Optional Settings

- `SPECTACLE_BIN` defaults to `spectacle`
- `UPLOAD_PROVIDER` defaults to `imgur` (supported values: `imgur`, `0x0`)
- `IMGUR_AUTH_MODE` defaults to `auto` (supported values: `auto`, `anonymous`, `login`)
- `IMGUR_API_URL` defaults to `https://api.imgur.com/3/image`
- `IMGUR_ACCESS_TOKEN` is optional and used for Imgur login mode
- `ZEROX0_API_URL` defaults to `https://0x0.st`
- `COPY_BIN` defaults to `wl-copy`

## Non-Interactive Usage (Skip Menus)

Use env vars for scripts, keybinds, or automation:

```bash
# Imgur anonymous mode
UPLOAD_PROVIDER=imgur IMGUR_AUTH_MODE=anonymous IMGUR_CLIENT_ID='your_client_id' ./spectacle-imgur.sh

# Imgur login mode
UPLOAD_PROVIDER=imgur IMGUR_AUTH_MODE=login IMGUR_ACCESS_TOKEN='your_access_token' ./spectacle-imgur.sh

# 0x0 anonymous mode
UPLOAD_PROVIDER=0x0 ./spectacle-imgur.sh
```

## Notes

- This is the Spectacle CLI path verified for Wayland: `spectacle -b -n -r -o <file>`.
- This script assumes Dan is running Bazzite KDE.
- The script expects KDE Plasma's Spectacle capture flow, not a generic screenshot backend.
- If you later want a native Spectacle integration, this script can serve as the capture/upload reference implementation.

## Troubleshooting

- `Imgur rejected the Client ID (HTTP 403)`: you likely entered the wrong value. Use the app's `Client ID`, not your Imgur username or the client secret.
- `Imgur login token is invalid or expired (HTTP 401)`: refresh `IMGUR_ACCESS_TOKEN`.
- `Imgur rate limit hit (HTTP 429)`: anonymous uploads are rate-limited by Imgur. Wait a bit and retry, or use a different Client ID.
- `unsupported UPLOAD_PROVIDER`: use `imgur` or `0x0`.
- `xdg_wm_base was destroyed before children` from Spectacle: this warning can appear on some KDE setups and usually does not block the upload flow.

## Standalone Spectacle Plugin

This repo also includes a standalone Purpose plugin in `spectacle-plugin/`.
It is a separate program and does not depend on `spectacle-imgur.sh`.

Install it user-local (good for immutable systems like Bazzite):

```bash
cd spectacle-plugin
chmod +x install.sh
./install.sh
```

Uninstall:

```bash
cd spectacle-plugin
chmod +x uninstall.sh
./uninstall.sh
```

See `spectacle-plugin/README.md` for plugin configuration and environment variables.

## Smoke Test

To validate both upload-script behavior and plugin install/uninstall locally (without real network calls):

```bash
./smoke-test.sh
```

The script uses lightweight command fakes and verifies:

- `imgur` upload success path
- `0x0` upload success path
- clipboard copy warning path when copy command returns non-zero
- plugin installer and uninstaller lifecycle in an isolated `XDG_DATA_HOME`
