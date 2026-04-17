# Dan's Super Awesome Spectacle Imgur Upload Script

## Scope

- This repo is a single self-contained shell script plus docs for Dan on Bazzite KDE.
- Target flow is KDE Plasma on Wayland using Spectacle region capture.
- The script should stay dependency-light and avoid repo-specific build steps.

## Verified Command Flow

- Spectacle region capture: `spectacle -b -n -r -o <file>`
- `-b` takes the screenshot in background mode.
- `-n` suppresses Spectacle's notification.
- `-r` opens rectangular region selection.

## Required Runtime Pieces

- `spectacle`
- `curl`
- `python3` for JSON parsing
- `wl-copy` for clipboard copy on Wayland

On Bazzite KDE, `spectacle`, `curl`, and `python3` are assumed to already be present. `wl-copy` is the only dependency expected to come from Homebrew.

## Editing Rules

- Keep the script self-contained in one file unless there is a strong reason not to.
- Prefer small, explicit shell functions over extra helper files.
- Document any non-obvious environment variable at the top of the script and in `README.md`.

## Main Reference Files

- `README.md` for usage and setup
- `spectacle-imgur.sh` for the actual workflow
