# Dan's Super Awesome Spectacle Imgur Upload Script

Single-file Wayland workflow for Dan on Bazzite KDE:

1. Open Spectacle in region-select mode.
1. Capture a screenshot to a temp file.
1. Upload the file to Imgur.
1. Copy the Imgur URL to the clipboard.

## Requirements

- Bazzite KDE already provides `spectacle`, `curl`, and `python3`
- You only need to install `wl-copy`

## Install wl-copy

Install `wl-copy` with Homebrew:

```bash
brew install wl-clipboard
```

If your shell does not see `wl-copy` right away, make sure Homebrew's `bin` is on `PATH`.

## Get Imgur Client ID

Create an Imgur app here:

https://api.imgur.com/oauth2/addclient

Use the app's `Client ID` value, not the secret.

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

- The script asks for your Imgur `Client ID`
- Spectacle opens in region-select mode
- You drag to select the area you want
- The script uploads the screenshot to Imgur
- The Imgur URL is copied to your clipboard
- The script also prints the URL in the terminal

## Optional Settings

- `SPECTACLE_BIN` defaults to `spectacle`
- `IMGUR_API_URL` defaults to `https://api.imgur.com/3/image`
- `COPY_BIN` defaults to `wl-copy`

## Notes

- This is the Spectacle CLI path verified for Wayland: `spectacle -b -n -r -o <file>`.
- This script assumes Dan is running Bazzite KDE.
- The script expects KDE Plasma's Spectacle capture flow, not a generic screenshot backend.
- If you later want a native Spectacle integration, this script can serve as the capture/upload reference implementation.

## Troubleshooting

- `Imgur rejected the Client ID (HTTP 403)`: you likely entered the wrong value. Use the app's `Client ID`, not your Imgur username or the client secret.
- `Imgur rate limit hit (HTTP 429)`: anonymous uploads are rate-limited by Imgur. Wait a bit and retry, or use a different Client ID.
- `xdg_wm_base was destroyed before children` from Spectacle: this warning can appear on some KDE setups and usually does not block the upload flow.
