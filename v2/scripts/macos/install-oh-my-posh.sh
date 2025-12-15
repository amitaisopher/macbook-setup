#!/usr/bin/env bash
set -euo pipefail

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required to install oh-my-posh on macOS. See https://brew.sh" >&2
  exit 1
fi

echo "Installing oh-my-posh via Homebrew..."
brew install jandedobbeleer/oh-my-posh/oh-my-posh

echo "oh-my-posh installed. Configure shells separately as needed."
