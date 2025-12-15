#!/usr/bin/env bash
set -euo pipefail

fonts=(
  font-martian-mono-nerd-font
  font-droid-sans-mono-nerd-font
)

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required to install Nerd Fonts on macOS. See https://brew.sh" >&2
  exit 1
fi

brew tap homebrew/cask-fonts

for font in "${fonts[@]}"; do
  echo "Installing ${font}..."
  brew install --cask "${font}"
done

echo "Nerd Fonts installation complete."
