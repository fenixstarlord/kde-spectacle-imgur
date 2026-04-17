# Dan's Super Awesome Spectacle Imgur Upload Script

Single-file Wayland workflow for Dan on Bazzite KDE:

1. Open Spectacle in region-select mode.
1. Capture a screenshot to a temp file.
1. Upload the file to Imgur.
1. Copy the Imgur URL to the clipboard.

## Requirements

- `wl-copy`

Bazzite KDE already provides `spectacle`, `curl`, and `python3`.

## Install wl-copy

Install `wl-copy` with Homebrew:

```bash
brew install wl-clipboard
```

If your shell does not see `wl-copy` right away, make sure Homebrew's `bin` is on `PATH`.

## Setup

Set your Imgur client id:

```bash
export IMGUR_CLIENT_ID='your-client-id'
```

Optional overrides:

- `SPECTACLE_BIN` defaults to `spectacle`
- `IMGUR_API_URL` defaults to `https://api.imgur.com/3/image`
- `COPY_BIN` defaults to `wl-copy`

## Usage

```bash
chmod +x spectacle-imgur.sh
./spectacle-imgur.sh
```

The script prints the uploaded Imgur URL and copies it to the clipboard.

## Notes

- This is the Spectacle CLI path verified for Wayland: `spectacle -b -n -r -o <file>`.
- This script assumes Dan is running Bazzite KDE.
- The script expects KDE Plasma's Spectacle capture flow, not a generic screenshot backend.
- If you later want a native Spectacle integration, this script can serve as the capture/upload reference implementation.
